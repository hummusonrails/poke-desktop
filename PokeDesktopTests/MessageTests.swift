import XCTest
@testable import PokeDesktop

final class MessageTests: XCTestCase {
    func testMessageCreation() {
        let msg = Message(
            rowId: 42,
            text: "Hello from Poke",
            isFromMe: false,
            date: Date(),
            attachments: [],
            sendStatus: .sent
        )
        XCTAssertEqual(msg.rowId, 42)
        XCTAssertEqual(msg.text, "Hello from Poke")
        XCTAssertFalse(msg.isFromMe)
        XCTAssertEqual(msg.sendStatus, .sent)
    }

    func testFailedMessageRetry() {
        var msg = Message(
            rowId: 0,
            text: "test",
            isFromMe: true,
            date: Date(),
            attachments: [],
            sendStatus: .failed(error: "Messages.app not running")
        )
        XCTAssertTrue(msg.canRetry)
        msg.sendStatus = .sending
        XCTAssertFalse(msg.canRetry)
    }
}
