import Foundation

public enum MIDIWriter {
    public static func playbackEvents(for score: ScoreDocument, partIndex: Int = 0) -> [PlaybackEvent] {
        guard score.parts.indices.contains(partIndex) else {
            return []
        }

        var events: [PlaybackEvent] = []
        for measure in score.parts[partIndex].measures {
            for note in measure.notes where !note.isRest {
                guard let midi = note.midi else {
                    continue
                }
                events.append(PlaybackEvent(tick: note.startTick, midi: midi, velocity: 84, kind: .noteOn))
                events.append(PlaybackEvent(tick: note.startTick + note.durationTick, midi: midi, velocity: 0, kind: .noteOff))
            }
        }

        return events.sorted { lhs, rhs in
            if lhs.tick == rhs.tick {
                return lhs.kind == .noteOff && rhs.kind == .noteOn
            }
            return lhs.tick < rhs.tick
        }
    }

    public static func makeMIDIData(score: ScoreDocument, partIndex: Int = 0) -> Data {
        let microsecondsPerQuarter = UInt32(60_000_000 / max(score.tempoBPM, 1))
        var track = Data()
        track.append(contentsOf: [0x00, 0xFF, 0x51, 0x03])
        track.append(UInt8((microsecondsPerQuarter >> 16) & 0xFF))
        track.append(UInt8((microsecondsPerQuarter >> 8) & 0xFF))
        track.append(UInt8(microsecondsPerQuarter & 0xFF))
        track.append(contentsOf: [0x00, 0xC0, 0x00])

        var previousTick = 0
        for event in playbackEvents(for: score, partIndex: partIndex) {
            track.append(contentsOf: variableLengthQuantity(event.tick - previousTick))
            switch event.kind {
            case .noteOn:
                track.append(contentsOf: [0x90, UInt8(event.midi), event.velocity])
            case .noteOff:
                track.append(contentsOf: [0x80, UInt8(event.midi), event.velocity])
            }
            previousTick = event.tick
        }

        track.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

        var data = Data()
        data.append("MThd".data(using: .ascii)!)
        data.append(bigEndianUInt32(6))
        data.append(bigEndianUInt16(0))
        data.append(bigEndianUInt16(1))
        data.append(bigEndianUInt16(UInt16(score.ticksPerQuarter)))
        data.append("MTrk".data(using: .ascii)!)
        data.append(bigEndianUInt32(UInt32(track.count)))
        data.append(track)
        return data
    }

    public static func writeMIDI(score: ScoreDocument, to url: URL, partIndex: Int = 0) throws {
        try makeMIDIData(score: score, partIndex: partIndex).write(to: url)
    }

    private static func variableLengthQuantity(_ value: Int) -> [UInt8] {
        var value = max(value, 0)
        var buffer = value & 0x7F
        value >>= 7

        while value > 0 {
            buffer <<= 8
            buffer |= (value & 0x7F) | 0x80
            value >>= 7
        }

        var output: [UInt8] = []
        while true {
            output.append(UInt8(buffer & 0xFF))
            if buffer & 0x80 == 0 {
                break
            }
            buffer >>= 8
        }
        return output
    }

    private static func bigEndianUInt16(_ value: UInt16) -> Data {
        Data([UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    }

    private static func bigEndianUInt32(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }
}
