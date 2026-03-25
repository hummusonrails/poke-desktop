import XCTest
@testable import PokeDesktop

final class MessageSenderTests: XCTestCase {
    func testTextScript() {
        let script = MessageSender.buildTextScript(handle: "+15551234567", text: "Hello Poke")
        XCTAssertTrue(script.contains("send \"Hello Poke\""))
        XCTAssertTrue(script.contains("+15551234567"))
    }

    func testTextScriptEscapesQuotes() {
        let script = MessageSender.buildTextScript(handle: "+15551234567", text: "He said \"hello\"")
        XCTAssertTrue(script.contains("He said \\\"hello\\\""))
    }

    func testAttachmentScript() {
        let script = MessageSender.buildAttachmentScript(handle: "+15551234567", filePath: "/tmp/screenshot.png")
        XCTAssertTrue(script.contains("POSIX file \"/tmp/screenshot.png\""))
    }
}
