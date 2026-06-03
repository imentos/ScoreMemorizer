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

    func start() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            startEngine()
        case .denied:
            state = .unavailable("Microphone permission denied")
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
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
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        state = .idle
        level = 0
    }

    private func startEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                let rms = Self.rmsLevel(from: buffer)
                Task { @MainActor in
                    self?.level = rms
                    self?.onLevel?(rms)
                }
            }

            engine.prepare()
            try engine.start()
            state = .listening
        } catch {
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
