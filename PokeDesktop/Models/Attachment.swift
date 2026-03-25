import Foundation
import AppKit

struct Attachment: Identifiable, Equatable {
    let id: UUID
    let filePath: String
    let mimeType: String?

    init(filePath: String, mimeType: String? = nil) {
        self.id = UUID()
        self.filePath = filePath
        self.mimeType = mimeType
    }

    var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    var thumbnail: NSImage? {
        NSImage(contentsOfFile: filePath)
    }
}
