import XCTest
@testable import PokeDesktop

@MainActor
final class VoiceEngineTests: XCTestCase {
    func testSpeechQueueProcessesInOrder() {
        let engine = VoiceEngine()
        engine.speak("First")  // starts speaking immediately, removed from queue
        engine.speak("Second") // queued (isSpeaking is true)
        engine.speak("Third")  // queued
        // first was dequeued and sent to synthesizer, so 2 remain in queue
        XCTAssertEqual(engine.speechQueue.count, 2)
    }

    func testCancelClearsQueue() {
        let engine = VoiceEngine()
        engine.speak("Hello")
        engine.speak("World")
        engine.cancelSpeech()
        XCTAssertTrue(engine.speechQueue.isEmpty)
    }
}
