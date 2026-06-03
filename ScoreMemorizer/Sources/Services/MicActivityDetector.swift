import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class MicActivityDetector {
    enum State {
        case idle
        case listening
        case unavailable(String)
    }

    var state: State = .idle
    var level: Float = 0
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var isTapInstalled = false
    @ObservationIgnored
    private lazy var levelRelay = MicLevelRelay(detector: self)

    func start() {
        guard stateIsNotListening else { return }

        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            startEngine()
        case .denied:
            state = .unavailable("Microphone permission denied")
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.startEngine()
                    } else {
                        self?.state = .unavailable("Microphone permission denied")
                    }
                }
            }
        @unknown default:
            state = .unavailable("Microphone permission unavailable")
        }
    }

    func stop() {
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        engine.stop()
        engine.reset()
        state = .idle
        level = 0
    }

    private var stateIsNotListening: Bool {
        if case .listening = state { return false }
        return true
    }

    private func startEngine() {
        do {
            if engine.isRunning {
                stop()
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP])
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                state = .unavailable("Microphone input is not available")
                return
            }

            if isTapInstalled {
                input.removeTap(onBus: 0)
                isTapInstalled = false
            }

            let relay = levelRelay
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                relay.publish(Self.rmsLevel(from: buffer))
            }
            isTapInstalled = true

            engine.prepare()
            try engine.start()
            state = .listening
        } catch {
            if isTapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            engine.stop()
            state = .unavailable(error.localizedDescription)
        }
    }

    private static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channel = channelData[0]
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frameCount {
            let sample = channel[index]
            sum += sample * sample
        }
        return sqrt(sum / Float(frameCount))
    }
}

private final class MicLevelRelay: @unchecked Sendable {
    private weak var detector: MicActivityDetector?

    @MainActor
    init(detector: MicActivityDetector) {
        self.detector = detector
    }

    func publish(_ level: Float) {
        Task { @MainActor [weak detector] in
            detector?.level = level
            detector?.onLevel?(level)
        }
    }
}
