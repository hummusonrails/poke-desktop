import XCTest
@testable import PokeDesktop

final class MessageStoreTests: XCTestCase {
    func testExtractTextFromAttributedBody() {
        let testString = "Hello from Poke"
        let prefix = Data([0x04, 0x0B, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6D])
        let body = prefix + Data([0x01]) + Data(testString.utf8) + Data([0x00])
        let result = MessageStore.extractText(fromAttributedBody: body)
        XCTAssertNotNil(result)
    }

    func testExtractTextReturnsNilForGarbage() {
        let garbage = Data([0xFF, 0xFE, 0x00, 0x01])
        let result = MessageStore.extractText(fromAttributedBody: garbage)
        XCTAssertNil(result)
    }

    func testChatDateConversion() {
        let nanoseconds: Int64 = 0
        let date = MessageStore.dateFromChatDB(nanoseconds)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, 0, accuracy: 1.0)
    }
}
