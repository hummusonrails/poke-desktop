import Foundation
import SQLite3

class MessageStore: ObservableObject {
    @Published var messages: [Message] = []
    @Published var hasFullDiskAccess = false

    // called on main queue when new messages arrive from polling, not from initial load or loadmore
    var onNewMessages: (([Message]) -> Void)?

    private var db: OpaquePointer?
    private var chatId: Int64 = 0
    private var handleId: Int64 = 0
    private var lastSeenRowId: Int64 = 0
    private var oldestLoadedRowId: Int64 = Int64.max
    private var pollTimer: DispatchSourceTimer?
    private var fastPollUntil: Date?
    private let prefs: PreferencesManager
    private let pollQueue = DispatchQueue(label: "com.poke.desktop.poll", qos: .utility)

    private static let chatDBPath = NSHomeDirectory() + "/Library/Messages/chat.db"

    init(prefs: PreferencesManager) {
        self.prefs = prefs
        self.lastSeenRowId = prefs.lastSeenRowId
    }

    // MARK: - database connection

    func openDatabase() -> Bool {
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(Self.chatDBPath, &dbPointer, flags, nil)
        guard result == SQLITE_OK, let db = dbPointer else {
            DispatchQueue.main.async { self.hasFullDiskAccess = false }
            return false
        }
        self.db = db
        DispatchQueue.main.async { self.hasFullDiskAccess = true }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        return true
    }

    func close() {
        pollTimer?.cancel()
        pollTimer = nil
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - handle discovery

    // returns recent conversations as handle rowid, handle identifier, chat_id
    func fetchRecentHandles() -> [(rowId: Int64, identifier: String, chatId: Int64)] {
        guard let db = db else { return [] }
        let sql = """
            SELECT h.ROWID, h.id, c.ROWID
            FROM handle h
            JOIN chat_handle_join chj ON h.ROWID = chj.handle_id
            JOIN chat c ON chj.chat_id = c.ROWID
            ORDER BY c.last_read_message_timestamp DESC
            LIMIT 20
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var handles: [(Int64, String, Int64)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(stmt, 0)
            let id = String(cString: sqlite3_column_text(stmt, 1))
            let chatId = sqlite3_column_int64(stmt, 2)
            handles.append((rowId, id, chatId))
        }
        return handles
    }

    func setHandle(_ handleId: Int64, chatId: Int64) {
        self.handleId = handleId
        self.chatId = chatId
        prefs.pokeHandleId = handleId
    }

    // MARK: - initial load + pagination

    func loadInitialMessages() {
        pollQueue.async { [weak self] in
            guard let self = self, let db = self.db, self.chatId > 0 else {
                return
            }
            let sql = """
                SELECT m.ROWID, m.text, m.attributedBody, m.date, m.is_from_me, m.cache_has_attachments, m.associated_message_type
                FROM message m
                JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
                WHERE cmj.chat_id = ?
                ORDER BY m.ROWID DESC
                LIMIT 50
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, self.chatId)

            var loaded: [Message] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let msg = self.parseRow(stmt) {
                    loaded.append(msg)
                }
            }
            let reversed = Array(loaded.reversed())
            let minRowId = reversed.first?.rowId ?? Int64.max
            let maxRowId = reversed.last?.rowId ?? 0
            // set oldestloadedrowid on pollqueue before dispatching to main
            self.oldestLoadedRowId = minRowId
            self.lastSeenRowId = maxRowId
            DispatchQueue.main.async {
                self.messages = reversed
                if maxRowId > 0 {
                    self.prefs.lastSeenRowId = maxRowId
                }
            }
        }
    }

    // load 50 older messages for backward pagination
    func loadMore() {
        pollQueue.async { [weak self] in
            guard let self = self, let db = self.db, self.chatId > 0 else {
                return
            }
            let sql = """
                SELECT m.ROWID, m.text, m.attributedBody, m.date, m.is_from_me, m.cache_has_attachments, m.associated_message_type
                FROM message m
                JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
                WHERE cmj.chat_id = ? AND m.ROWID < ?
                ORDER BY m.ROWID DESC
                LIMIT 50
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, self.chatId)
            sqlite3_bind_int64(stmt, 2, self.oldestLoadedRowId)

            var older: [Message] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let msg = self.parseRow(stmt) {
                    older.append(msg)
                }
            }
            let reversed = Array(older.reversed())
            if let minRowId = reversed.first?.rowId {
                self.oldestLoadedRowId = minRowId
            }
            DispatchQueue.main.async {
                self.messages.insert(contentsOf: reversed, at: 0)
            }
        }
    }

    // MARK: - polling background queue

    func startPolling() {
        pollTimer?.cancel()
        schedulePoll()
    }

    func enterFastPollMode() {
        fastPollUntil = Date().addingTimeInterval(30)
        pollTimer?.cancel()
        schedulePoll()
    }

    private func schedulePoll() {
        let interval: TimeInterval
        if let fastUntil = fastPollUntil, Date() < fastUntil {
            interval = 1.5
        } else {
            fastPollUntil = nil
            interval = 3.0
        }

        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.pollForNewMessages()
            self?.schedulePoll()
        }
        timer.resume()
        pollTimer = timer
    }

    private func pollForNewMessages() {
        guard let db = db, chatId > 0 else { return }
        let sql = """
            SELECT m.ROWID, m.text, m.attributedBody, m.date, m.is_from_me, m.cache_has_attachments, m.associated_message_type
            FROM message m
            JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            WHERE cmj.chat_id = ? AND m.ROWID > ?
            ORDER BY m.ROWID ASC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, chatId)
        sqlite3_bind_int64(stmt, 2, lastSeenRowId)

        var newMessages: [Message] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let msg = parseRow(stmt) {
                newMessages.append(msg)
                lastSeenRowId = msg.rowId
            }
        }

        if !newMessages.isEmpty {
            let captured = newMessages
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(contentsOf: captured)
                self?.prefs.lastSeenRowId = captured.last!.rowId
                self?.onNewMessages?(captured)
            }
        }
    }

    // MARK: - parsing

    private func parseRow(_ stmt: OpaquePointer?) -> Message? {
        guard let stmt = stmt else { return nil }
        let rowId = sqlite3_column_int64(stmt, 0)

        var text: String?
        if let cText = sqlite3_column_text(stmt, 1) {
            let rawText = String(cString: cText)
            // skip placeholder characters u+fffc object replacement char
            let cleaned = rawText.replacingOccurrences(of: "\u{fffc}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                text = cleaned
            }
        }
        if text == nil {
            if let blobPtr = sqlite3_column_blob(stmt, 2) {
                let blobLen = Int(sqlite3_column_bytes(stmt, 2))
                let data = Data(bytes: blobPtr, count: blobLen)
                text = Self.extractText(fromAttributedBody: data)
            }
        }

        let dateValue = sqlite3_column_int64(stmt, 3)
        let isFromMe = sqlite3_column_int(stmt, 4) == 1
        let hasAttachments = sqlite3_column_int(stmt, 5) == 1
        let associatedMessageType = sqlite3_column_int(stmt, 6)

        // skip tapback reactions, associated_message_type 2000-2005 add reaction 3000-3005 remove
        if associatedMessageType >= 2000 && associatedMessageType <= 5005 {
            return nil
        }

        var attachments: [Attachment] = []
        if hasAttachments {
            attachments = fetchAttachments(forMessageRowId: rowId)
        }

        return Message(
            rowId: rowId,
            text: text ?? "[unable to decode message]",
            isFromMe: isFromMe,
            date: Self.dateFromChatDB(dateValue),
            attachments: attachments,
            sendStatus: .sent
        )
    }

    private func fetchAttachments(forMessageRowId messageRowId: Int64) -> [Attachment] {
        guard let db = db else { return [] }
        let sql = """
            SELECT a.filename, a.mime_type
            FROM attachment a
            JOIN message_attachment_join maj ON a.ROWID = maj.attachment_id
            WHERE maj.message_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, messageRowId)

        var attachments: [Attachment] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cPath = sqlite3_column_text(stmt, 0) {
                let path = String(cString: cPath).replacingOccurrences(of: "~", with: NSHomeDirectory())
                let mime = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                attachments.append(Attachment(filePath: path, mimeType: mime))
            }
        }
        return attachments
    }

    // MARK: - utilities

    static func extractText(fromAttributedBody data: Data) -> String? {
        guard data.count > 10 else { return nil }

        // method 1 try nskeyedunarchiver
        if let text = extractViaUnarchiver(data) {
            return text
        }

        // method 2 try typedstream format
        if let text = extractViaStreamScan(data) {
            return text
        }

        return nil
    }

    private static func extractViaUnarchiver(_ data: Data) -> String? {
        // try nskeyedunarchiver
        do {
            if let attrStr = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSAttributedString.self, NSString.self, NSMutableAttributedString.self,
                           NSMutableString.self, NSDictionary.self, NSArray.self, NSNumber.self,
                           NSMutableDictionary.self, NSMutableArray.self, NSURL.self,
                           NSData.self, NSSet.self, NSMutableSet.self],
                from: data
            ) as? NSAttributedString {
                let text = attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            }
        } catch {
        }

        // try the raw typedstream approach
        if let text = extractFromTypedStream(data) {
            return text
        }

        return nil
    }

    private static func extractFromTypedStream(_ data: Data) -> String? {
        // typedstream format for attributedbody
        // after the last nsstring class descriptor find 0x2b marker then read length and utf8 text
        let bytes = [UInt8](data)

        // find the first 0x2b marker preceded by 0x01
        for i in 1..<bytes.count {
            if bytes[i] == 0x2b && bytes[i-1] == 0x01 {
                var pos = i + 1
                guard pos < bytes.count else { return nil }

                // read length
                let length: Int
                if bytes[pos] < 0x80 {
                    // single byte length
                    length = Int(bytes[pos])
                    pos += 1
                } else if bytes[pos] == 0x81 && pos + 2 < bytes.count {
                    // two-byte big-endian length
                    length = Int(bytes[pos+1]) << 8 | Int(bytes[pos+2])
                    pos += 3
                } else if bytes[pos] == 0x82 && pos + 4 < bytes.count {
                    // four-byte big-endian length
                    length = Int(bytes[pos+1]) << 24 | Int(bytes[pos+2]) << 16 | Int(bytes[pos+3]) << 8 | Int(bytes[pos+4])
                    pos += 5
                } else {
                    continue
                }

                guard length > 0 && pos + length <= bytes.count else { continue }

                let textData = Data(bytes[pos..<pos+length])
                if let text = String(data: textData, encoding: .utf8) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }

        return nil
    }

    private static func extractViaStreamScan(_ data: Data) -> String? {
        // old typedstream format scan for longest valid utf-8 chunk between null bytes
        var chunks: [Data] = []
        var current = Data()
        for byte in data {
            if byte == 0x00 {
                if !current.isEmpty {
                    chunks.append(current)
                    current = Data()
                }
            } else {
                current.append(byte)
            }
        }
        if !current.isEmpty { chunks.append(current) }

        var bestString = ""
        for chunk in chunks {
            guard let str = String(data: chunk, encoding: .utf8) else { continue }
            let printable = str.trimmingCharacters(in: .controlCharacters)
            if printable.count > bestString.count && printable.count >= 2 {
                if !printable.hasPrefix("NS") && !printable.hasPrefix("@\"") {
                    bestString = printable
                }
            }
        }

        let trimmed = bestString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func dateFromChatDB(_ nanoseconds: Int64) -> Date {
        let seconds = TimeInterval(nanoseconds) / 1_000_000_000.0
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}
