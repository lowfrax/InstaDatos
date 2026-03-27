import Foundation
import AVFoundation
import Speech

@MainActor
final class SpeechTranscriber: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case denied(String)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var transcript: String = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermissionsIfNeeded() async -> Bool {
        if case .denied = state { return false }
        state = .requestingPermission

        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAllowed else {
            state = .denied("Permiso de reconocimiento de voz no concedido.")
            return false
        }

        let micAllowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { ok in
                continuation.resume(returning: ok)
            }
        }

        guard micAllowed else {
            state = .denied("Permiso de micrófono no concedido.")
            return false
        }

        state = .idle
        return true
    }

    func start() async {
        if case .listening = state { return }
        let ok = await requestPermissionsIfNeeded()
        guard ok else { return }

        transcript = ""
        do {
            try configureAudioSession()
            try startRecognition()
            state = .listening
        } catch {
            stop()
            state = .error(error.localizedDescription)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        if case .listening = state {
            state = .idle
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechTranscriber", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reconocedor no disponible ahora."])
        }

        request?.endAudio()
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request!) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            if let error {
                Task { @MainActor in
                    self.stop()
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
}

