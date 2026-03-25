import Foundation
import AppKit

enum SendError: Error, LocalizedError {
    case messagesNotRunning
    case scriptError(String)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .messagesNotRunning: return "Messages.app is not running"
        case .scriptError(let msg): return msg
        case .unknownError: return "Failed to send message"
        }
    }
}

class MessageSender {
    private let handleIdentifier: String

    init(handleIdentifier: String) {
        self.handleIdentifier = handleIdentifier
    }

    // MARK: - send

    func sendText(_ text: String) async throws {
        let script = Self.buildTextScript(handle: handleIdentifier, text: text)
        try executeAppleScript(script)
    }

    func sendAttachment(filePath: String) async throws {
        let script = Self.buildAttachmentScript(handle: handleIdentifier, filePath: filePath)
        try executeAppleScript(script)
    }

    func sendMessage(text: String?, attachments: [Attachment]) async throws {
        if let text = text, !text.isEmpty {
            try await sendText(text)
        }
        for attachment in attachments {
            try await sendAttachment(filePath: attachment.filePath)
        }
    }

    // MARK: - script building

    static func buildTextScript(handle: String, text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(handle)" of targetService
            send "\(escaped)" to targetBuddy
        end tell
        """
    }

    static func buildAttachmentScript(handle: String, filePath: String) -> String {
        return """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(handle)" of targetService
            send POSIX file "\(filePath)" to targetBuddy
        end tell
        """
    }

    // MARK: - execution

    private func executeAppleScript(_ source: String) throws {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MobileSMS").first != nil else {
            throw SendError.messagesNotRunning
        }

        let script = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            throw SendError.scriptError(message)
        }
    }
}
