import Foundation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

enum ScoreFormatting {
    static func noteName(_ note: ScoreNote) -> String {
        if note.isRest {
            return L10n.tr("text.rest")
        }

        guard let step = note.step, let octave = note.octave else {
            return L10n.tr("text.unknown")
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
            return L10n.tr("%d ticks", ticks)
        }

        let beats = Double(ticks) / Double(ticksPerQuarter)
        return L10n.tr("text.decimal2_beats", beats)
    }
}
