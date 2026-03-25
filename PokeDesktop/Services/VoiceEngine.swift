import Foundation
import AVFoundation
import Speech

@MainActor
class VoiceEngine: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcribedText = ""
    var speechQueue: [String] = []

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var isSpeaking = false
    private var sayProcess: Process?

    // MARK: - text-to-speech via say command

    func speak(_ text: String) {
        speechQueue.append(text)
        if !isSpeaking {
            speakNext()
        }
    }

    func cancelSpeech() {
        speechQueue.removeAll()
        sayProcess?.terminate()
        sayProcess = nil
        isSpeaking = false
    }

    private func speakNext() {
        guard !speechQueue.isEmpty else {
            isSpeaking = false
            return
        }
        isSpeaking = true
        let text = speechQueue.removeFirst()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = [text]
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.sayProcess = nil
                self?.speakNext()
            }
        }

        do {
            sayProcess = process
            try process.run()
        } catch {
            isSpeaking = false
        }
    }

    // MARK: - speech-to-text

    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return
        }

        SFSpeechRecognizer.requestAuthorization { _ in }

        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        }

        cancelSpeech()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            transcribedText = ""
        } catch {
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }
                _ = error
            }
        }
    }

    func stopListening() -> String {
        let text = transcribedText
        stopListeningInternal()
        return text
    }

    private func stopListeningInternal() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
}
