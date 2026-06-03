import SwiftUI
import UIKit

struct ContentView: View {
    @State private var session = PracticeSession()
    @State private var mic = MicActivityDetector()
    @State private var sound = CueSoundPlayer()
    @State private var isShowingSettings = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    AppTopBar(
                        tempoText: "\(session.bpm) BPM",
                        settingsAction: { isShowingSettings = true }
                    )

                    DrillStage(session: session, mic: mic)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 118)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DrillControls(session: session)
        }
        .sheet(isPresented: $isShowingSettings) {
            PracticeSettingsView(session: session, mic: mic)
                .presentationDetents([.large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            mic.onLevel = { level in
                session.handleSoundLevel(level)
            }
            session.onSoundCue = { cue in
                sound.play(cue)
            }
        }
    }

}

private struct AppTopBar: View {
    let tempoText: String
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("ScoreMemorizer")
                    .font(.title2.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(tempoText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appSecondaryText)
            }

            Spacer(minLength: 8)

            Button(action: settingsAction) {
                Image(systemName: "gearshape.fill")
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Settings")
        }
        .foregroundStyle(Color.appText)
        .padding(14)
        .background(Color.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PracticeSettingsView: View {
    let session: PracticeSession
    let mic: MicActivityDetector

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SettingsCard(title: "Drill") {
                        SettingStepperRow(title: "Tempo", value: "\(session.bpm) BPM") {
                            StepIconButton(systemImage: "minus", action: { session.bpm = max(40, session.bpm - 2) })
                            StepIconButton(systemImage: "plus", action: { session.bpm = min(180, session.bpm + 2) })
                        }

                        SettingPickerRow(title: "Time signature", value: timeSignatureText) {
                            Picker("Time signature", selection: beatsBinding) {
                                Text("3/4").tag(3)
                                Text("4/4").tag(4)
                                Text("6/8").tag(6)
                            }
                        }

                        SettingStepperRow(title: "Freeze length", value: session.freezeLengthText) {
                            StepIconButton(systemImage: "minus", action: { session.freezeBars = max(1, session.freezeBars - 1) })
                            StepIconButton(systemImage: "plus", action: { session.freezeBars = min(8, session.freezeBars + 1) })
                        }

                        SettingPickerRow(title: "Freeze frequency", value: session.freezeDensityLabel) {
                            Picker("Freeze frequency", selection: freezeChanceBinding) {
                                Text("Low").tag(0.08)
                                Text("Medium").tag(0.18)
                                Text("High").tag(0.34)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 48)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var timeSignatureText: String {
        session.beatsPerBar == 6 ? "6/8" : "\(session.beatsPerBar)/4"
    }

    private var beatsBinding: Binding<Int> {
        Binding(get: { session.beatsPerBar }, set: { session.beatsPerBar = $0 })
    }

    private var freezeChanceBinding: Binding<Double> {
        Binding(get: { session.freezeChance }, set: { session.freezeChance = $0 })
    }

}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.headline.weight(.semibold))
            content
        }
        .foregroundStyle(Color.appText)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SettingStepperRow<Controls: View>: View {
    let title: String
    let value: String
    @ViewBuilder let controls: Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingHeader(title: title, value: value)
            HStack(spacing: 12) {
                controls
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

private struct SettingPickerRow<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingHeader(title: title, value: value)
            content
                .pickerStyle(.segmented)
        }
        .padding(.vertical, 2)
    }
}

private struct SettingHeader: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.body.weight(.medium))
            Spacer(minLength: 12)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.appSecondaryText)
        }
    }
}

private struct StepIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 44, height: 40)
        }
        .buttonStyle(.bordered)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(systemImage == "plus" ? "Increase" : "Decrease")
    }
}

private struct DrillStage: View {
    let session: PracticeSession
    let mic: MicActivityDetector

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                Spacer(minLength: 12)

                RuntimePills(session: session, mic: mic)

                if session.mode != .freeze {
                    Text(session.lastCue)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(cueColor)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }

                BeatDisplay(currentBeat: session.currentBeat, beatsPerBar: session.beatsPerBar, mode: session.mode)

                Text(session.feedback)
                    .font(.title3.weight(.semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(feedbackColor)
                    .padding(.horizontal, 8)

                RuntimeScoreLine(session: session)

                Spacer(minLength: 12)
            }
            .foregroundStyle(Color.appText)
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.stageBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if session.mode == .freeze {
                FreezeOverlay(countdownBeats: session.countdownBeats)
            }
        }
    }

    private var cueColor: Color {
        switch session.mode {
        case .freeze: .freezeAccent
        case .go: .goAccent
        case .ready, .paused: .appText
        }
    }

    private var feedbackColor: Color {
        if session.feedback.contains("early") || session.feedback.contains("continued") || session.feedback.contains("stop") {
            return .wrongAccent
        }
        return .appText
    }
}

private struct RuntimePills: View {
    let session: PracticeSession
    let mic: MicActivityDetector

    var body: some View {
        HStack(spacing: 8) {
            Pill(text: session.progressText, systemImage: "music.note")
            Pill(text: micStatus, systemImage: micIcon)
        }
        .frame(maxWidth: .infinity)
    }

    private var micStatus: String {
        switch mic.state {
        case .idle: "Mic off"
        case .listening: session.isSounding ? "Playing" : "Quiet"
        case .unavailable: "No mic"
        }
    }

    private var micIcon: String {
        if case .listening = mic.state { return "waveform" }
        return "mic.slash"
    }
}

private struct RuntimeScoreLine: View {
    let session: PracticeSession

    var body: some View {
        HStack(spacing: 12) {
            Label("\(session.cleanStops)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.goAccent)
            Label("\(session.earlyStarts + session.missedStops)", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(Color.wrongAccent)
            Label("\(session.freezeCount)", systemImage: "snowflake")
                .foregroundStyle(Color.freezeAccent)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.panelBackground.opacity(0.78))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clean stops \(session.cleanStops), mistakes \(session.earlyStarts + session.missedStops), freezes \(session.freezeCount)")
    }
}

private struct Pill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.panelBackground.opacity(0.82))
            .clipShape(Capsule())
    }
}

private struct BeatDisplay: View {
    let currentBeat: Int
    let beatsPerBar: Int
    let mode: PracticeSession.Mode

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...beatsPerBar, id: \.self) { beat in
                Circle()
                    .fill(beat == currentBeat ? activeColor : Color.panelBackground)
                    .overlay(
                        Text("\(beat)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(beat == currentBeat ? Color.white : Color.appSecondaryText)
                    )
                    .frame(width: 54, height: 54)
            }
        }
        .padding(10)
        .background(Color.panelBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var activeColor: Color {
        mode == .freeze ? .freezeAccent : .goAccent
    }
}

private struct SoundMeter: View {
    let level: Float
    let threshold: Float
    let isListening: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sound activity")
                Spacer()
                Text(isListening ? (level >= threshold ? "Playing" : "Silent") : "Mic off")
                    .fontWeight(.semibold)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level >= threshold ? Color.goAccent : Color.freezeAccent.opacity(0.55))
                        .frame(width: max(8, proxy.size.width * CGFloat(min(level / 0.15, 1))))
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 2)
                        .offset(x: proxy.size.width * CGFloat(min(threshold / 0.15, 1)))
                }
            }
            .frame(height: 18)
        }
        .font(.subheadline)
        .padding(12)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FreezeOverlay: View {
    let countdownBeats: Int

    var body: some View {
        VStack(spacing: 14) {
            Text("Freeze")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text("Stop hands. Keep counting inside.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("\(max(countdownBeats, 0))")
                .font(.system(size: 72, weight: .black, design: .rounded))
            Text("Go returns on the beat")
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DrillControls: View {
    let session: PracticeSession

    var body: some View {
        HStack(spacing: 10) {
            Button {
                session.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Reset")

            Button {
                if session.mode == .go {
                    session.pause()
                } else {
                    session.go()
                }
            } label: {
                Label(session.mode == .go ? "Pause" : "Go", systemImage: session.mode == .go ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)

            Button {
                session.manualFreeze()
            } label: {
                Text("Freeze")
                    .frame(width: 82, height: 50)
            }
            .buttonStyle(.bordered)
            .disabled(session.mode != .go)
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(Color.controlBarBackground)
    }
}

private extension Color {
    static let appBackground = Color(light: UIColor(red: 0.96, green: 0.97, blue: 0.95, alpha: 1), dark: UIColor(red: 0.07, green: 0.09, blue: 0.08, alpha: 1))
    static let panelBackground = Color(light: .white, dark: UIColor(red: 0.14, green: 0.16, blue: 0.15, alpha: 1))
    static let stageBackground = Color(light: UIColor(red: 0.93, green: 0.95, blue: 0.92, alpha: 1), dark: UIColor(red: 0.10, green: 0.13, blue: 0.12, alpha: 1))
    static let controlBarBackground = Color(light: UIColor(white: 1, alpha: 0.94), dark: UIColor(red: 0.10, green: 0.11, blue: 0.11, alpha: 0.96))
    static let appText = Color(light: UIColor(red: 0.05, green: 0.06, blue: 0.055, alpha: 1), dark: UIColor(red: 0.94, green: 0.96, blue: 0.93, alpha: 1))
    static let appSecondaryText = Color(light: UIColor(red: 0.35, green: 0.38, blue: 0.36, alpha: 1), dark: UIColor(red: 0.70, green: 0.74, blue: 0.70, alpha: 1))
    static let goAccent = Color(light: UIColor(red: 0.06, green: 0.47, blue: 0.34, alpha: 1), dark: UIColor(red: 0.24, green: 0.78, blue: 0.58, alpha: 1))
    static let freezeAccent = Color(light: UIColor(red: 0.82, green: 0.19, blue: 0.18, alpha: 1), dark: UIColor(red: 1.00, green: 0.38, blue: 0.36, alpha: 1))
    static let wrongAccent = Color(light: UIColor(red: 0.74, green: 0.08, blue: 0.12, alpha: 1), dark: UIColor(red: 1.00, green: 0.46, blue: 0.50, alpha: 1))

    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
