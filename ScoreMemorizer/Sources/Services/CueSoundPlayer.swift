import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class CueSoundPlayer {
    private var players: [PracticeSession.SoundCue: AVAudioPlayer] = [:]

    init() {
        players[.beat] = makePlayer(frequency: 880, duration: 0.045, volume: 0.28)
        players[.strongBeat] = makePlayer(frequency: 1320, duration: 0.055, volume: 0.38)
        players[.freeze] = makePlayer(frequency: 220, duration: 0.18, volume: 0.75)
        players[.go] = makePlayer(frequency: 1046, duration: 0.15, volume: 0.62)
    }

    func play(_ cue: PracticeSession.SoundCue) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            // If audio-session setup fails, still try to play; AVAudioPlayer may already be usable.
        }

        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(frequency: Double, duration: Double, volume: Float) -> AVAudioPlayer? {
        guard let data = Self.makeWavTone(frequency: frequency, duration: duration, volume: volume) else { return nil }
        do {
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    private static func makeWavTone(frequency: Double, duration: Double, volume: Float) -> Data? {
        let sampleRate = 44_100
        let frameCount = max(1, Int(Double(sampleRate) * duration))
        let byteRate = sampleRate * 2
        let dataByteCount = frameCount * 2
        var data = Data()

        func appendString(_ string: String) {
            data.append(contentsOf: string.utf8)
        }

        func appendUInt16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        func appendUInt32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        appendString("RIFF")
        appendUInt32(UInt32(36 + dataByteCount))
        appendString("WAVE")
        appendString("fmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(byteRate))
        appendUInt16(2)
        appendUInt16(16)
        appendString("data")
        appendUInt32(UInt32(dataByteCount))

        for frame in 0..<frameCount {
            let t = Double(frame) / Double(sampleRate)
            let fadeIn = min(1.0, Double(frame) / 80.0)
            let fadeOut = min(1.0, Double(frameCount - frame) / 220.0)
            let envelope = fadeIn * fadeOut
            let wave = sin(2.0 * .pi * frequency * t)
            let sample = Int16(max(-1.0, min(1.0, wave * envelope * Double(volume))) * Double(Int16.max))
            var little = sample.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        return data
    }
}
