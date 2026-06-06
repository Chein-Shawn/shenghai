import Foundation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

enum ScoreFormatting {
    static func noteName(_ note: ScoreNote) -> String {
        if note.isRest {
            return "Rest"
        }

        guard let step = note.step, let octave = note.octave else {
            return "Unknown"
        }

        let accidental: String
        if note.alter > 0 {
            accidental = String(repeating: "#", count: note.alter)
        } else if note.alter < 0 {
            accidental = String(repeating: "b", count: abs(note.alter))
        } else {
            accidental = ""
        }

        return "\(step)\(accidental)\(octave)"
    }

    static func durationLabel(ticks: Int, ticksPerQuarter: Int) -> String {
        guard ticksPerQuarter > 0 else {
            return "\(ticks) ticks"
        }

        let beats = Double(ticks) / Double(ticksPerQuarter)
        return String(format: "%.2f beats", beats)
    }
}
