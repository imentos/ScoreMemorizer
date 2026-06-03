import Foundation

struct PracticeNote: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let midi: UInt8
    let beat: Double
    let duration: Double
}

struct PracticeSong: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let notes: [PracticeNote]
}

enum SongLibrary {
    static let songs: [PracticeSong] = [
        PracticeSong(
            id: "scale",
            title: "C Major Memory Run",
            notes: makeNotes(["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"])
        ),
        PracticeSong(
            id: "twinkle",
            title: "Twinkle Opening",
            notes: makeNotes(["C4", "C4", "G4", "G4", "A4", "A4", "G4", "F4", "F4", "E4", "E4", "D4", "D4", "C4"])
        ),
        PracticeSong(
            id: "arpeggio",
            title: "Broken Chord Focus",
            notes: makeNotes(["C4", "E4", "G4", "C5", "G4", "E4", "C4", "G3", "C4", "E4", "G4", "C5"])
        )
    ]

    static func makeNotes(_ names: [String]) -> [PracticeNote] {
        names.enumerated().compactMap { index, name in
            guard let midi = midiNumber(for: name) else { return nil }
            return PracticeNote(name: name, midi: midi, beat: Double(index) + 1, duration: 1)
        }
    }

    static func midiNumber(for noteName: String) -> UInt8? {
        let pattern = #"^([A-G])([#b]?)(-?\d+)$"#
        guard let match = noteName.range(of: pattern, options: .regularExpression) else { return nil }
        let raw = String(noteName[match])
        let pitch = raw.prefix { $0.isLetter }
        let remainder = raw.dropFirst(pitch.count)
        let accidental = remainder.prefix { $0 == "#" || $0 == "b" }
        let octaveText = remainder.dropFirst(accidental.count)
        guard let octave = Int(octaveText) else { return nil }

        let base: Int
        switch pitch {
        case "C": base = 0
        case "D": base = 2
        case "E": base = 4
        case "F": base = 5
        case "G": base = 7
        case "A": base = 9
        case "B": base = 11
        default: return nil
        }

        let offset = accidental == "#" ? 1 : accidental == "b" ? -1 : 0
        let value = (octave + 1) * 12 + base + offset
        guard (0...127).contains(value) else { return nil }
        return UInt8(value)
    }
}

