import Foundation
import Observation

@Observable
@MainActor
final class PracticeSession {
    enum Mode {
        case ready
        case go
        case freeze
        case paused
    }

    enum SoundCue: Hashable {
        case beat
        case strongBeat
        case freeze
        case go
    }

    var mode: Mode = .ready
    var bpm = 80 {
        didSet {
            rescheduleTimerIfPlaying()
        }
    }
    var beatsPerBar = 4
    var freezeBars = 2
    var freezeChance = 0.18
    var micThreshold: Float = 0.035
    var feedback = "Set a tempo, tap Go, and play your own piece. ScoreMemorizer will call Freeze on the beat."

    var currentBeat = 1
    var currentBar = 1
    var countdownBeats = 0
    var lastCue = "Ready"

    var freezeCount = 0
    var cleanStops = 0
    var earlyStarts = 0
    var missedStops = 0
    var cleanResumes = 0
    var isSounding = false
    var soundLevel: Float = 0
    var onSoundCue: ((SoundCue) -> Void)?

    private var beatTimer: Timer?
    private var freezeStartedAt: Date?
    private var hasLoggedStopFailure = false
    private var hasLoggedEarlyStart = false
    private var waitingForResume = false

    var beatInterval: TimeInterval {
        60.0 / Double(max(bpm, 30))
    }

    var progressText: String {
        "Bar \(currentBar) / Beat \(currentBeat)"
    }

    var freezeLengthText: String {
        "\(freezeBars) bar\(freezeBars == 1 ? "" : "s")"
    }

    var freezeDensityLabel: String {
        switch freezeChance {
        case ..<0.12: "Low"
        case ..<0.26: "Medium"
        default: "High"
        }
    }

    func go() {
        beatTimer?.invalidate()
        mode = .go
        lastCue = "Go"
        feedback = "Go. Play in tempo and be ready to Freeze."
        countdownBeats = 0
        waitingForResume = true
        hasLoggedStopFailure = false
        hasLoggedEarlyStart = false
        playCue(.go)
        startBeatTimer()
    }

    func pause() {
        beatTimer?.invalidate()
        mode = .paused
        lastCue = "Paused"
        feedback = "Paused. Tap Go to continue the drill."
    }

    func reset() {
        beatTimer?.invalidate()
        mode = .ready
        currentBeat = 1
        currentBar = 1
        countdownBeats = 0
        lastCue = "Ready"
        feedback = "Set a tempo, tap Go, and play your own piece. ScoreMemorizer will call Freeze on the beat."
        freezeCount = 0
        cleanStops = 0
        earlyStarts = 0
        missedStops = 0
        cleanResumes = 0
        isSounding = false
        soundLevel = 0
        freezeStartedAt = nil
        hasLoggedStopFailure = false
        hasLoggedEarlyStart = false
        waitingForResume = false
    }

    func manualFreeze() {
        guard mode == .go else { return }
        startFreeze()
    }

    func handleSoundLevel(_ level: Float) {
        soundLevel = level
        let soundingNow = level >= micThreshold
        isSounding = soundingNow

        switch mode {
        case .go:
            if waitingForResume, soundingNow {
                cleanResumes += 1
                waitingForResume = false
                feedback = "Good Go. You resumed after the cue."
            }
        case .freeze:
            guard let freezeStartedAt else { return }
            let elapsed = Date().timeIntervalSince(freezeStartedAt)
            if soundingNow, elapsed > 0.45, !hasLoggedStopFailure {
                missedStops += 1
                hasLoggedStopFailure = true
                feedback = "Freeze means stop. Sound continued after the cue."
            }
        case .ready, .paused:
            break
        }
    }

    func markRecovery(_ wasClean: Bool) {
        if wasClean {
            feedback = "Recovery marked clean. Keep going."
        } else {
            feedback = "Recovery marked lost. Reset your place, then continue."
        }
    }

    private func startBeatTimer() {
        beatTimer?.invalidate()
        beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func rescheduleTimerIfPlaying() {
        guard mode == .go || mode == .freeze else { return }
        startBeatTimer()
    }

    private func tick() {
        switch mode {
        case .go:
            advanceBeat()
            if shouldFreezeOnThisBeat() {
                startFreeze()
            } else {
                playCue(currentBeat == 1 ? .strongBeat : .beat)
            }
        case .freeze:
            countdownBeats -= 1
            if isSounding, !hasLoggedEarlyStart, countdownBeats <= 1 {
                earlyStarts += 1
                hasLoggedEarlyStart = true
                feedback = "Wait for Go. You came in early."
            }
            if countdownBeats <= 0 {
                go()
            }
        case .ready, .paused:
            break
        }
    }

    private func advanceBeat() {
        if currentBeat >= beatsPerBar {
            currentBeat = 1
            currentBar += 1
        } else {
            currentBeat += 1
        }
    }

    private func startFreeze() {
        mode = .freeze
        lastCue = "Freeze"
        freezeCount += 1
        countdownBeats = max(1, freezeBars * beatsPerBar)
        freezeStartedAt = Date()
        hasLoggedStopFailure = false
        hasLoggedEarlyStart = false
        waitingForResume = false
        feedback = "Freeze. Stop hands and keep your place internally."
        playCue(.freeze)

        if !isSounding {
            cleanStops += 1
        }
    }

    private func shouldFreezeOnThisBeat() -> Bool {
        guard currentBar > 1 else { return false }
        guard currentBeat == 1 else { return false }
        return Double.random(in: 0...1) < freezeChance
    }

    private func playCue(_ cue: SoundCue) {
        onSoundCue?(cue)
    }
}
