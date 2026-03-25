import Foundation

enum SendStatus: Equatable {
    case sending
    case sent
    case failed(error: String)
}

struct Message: Identifiable, Equatable {
    let id: UUID
    let rowId: Int64
    let text: String
    let isFromMe: Bool
    let date: Date
    let attachments: [Attachment]
    var sendStatus: SendStatus

    var canRetry: Bool {
        if case .failed = sendStatus { return true }
        return false
    }

    init(rowId: Int64, text: String, isFromMe: Bool, date: Date, attachments: [Attachment], sendStatus: SendStatus) {
        self.id = UUID()
        self.rowId = rowId
        self.text = text
        self.isFromMe = isFromMe
        self.date = date
        self.attachments = attachments
        self.sendStatus = sendStatus
    }
}
