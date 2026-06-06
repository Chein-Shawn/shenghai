import Foundation

public struct PitchSample: Codable, Equatable, Sendable {
    public var time: TimeInterval
    public var frequencyHz: Double?
    public var confidence: Double

    public init(time: TimeInterval, frequencyHz: Double?, confidence: Double) {
        self.time = time
        self.frequencyHz = frequencyHz
        self.confidence = confidence
    }
}

public struct TargetPitchPoint: Codable, Equatable, Sendable {
    public var time: TimeInterval
    public var duration: TimeInterval
    public var midi: Int
    public var partID: String?
    public var measureNumber: String?
    public var noteID: String?
    public var startTick: Int
    public var durationTick: Int

    public init(
        time: TimeInterval,
        midi: Int,
        duration: TimeInterval = 0,
        partID: String? = nil,
        measureNumber: String? = nil,
        noteID: String? = nil,
        startTick: Int = 0,
        durationTick: Int = 0
    ) {
        self.time = time
        self.duration = duration
        self.midi = midi
        self.partID = partID
        self.measureNumber = measureNumber
        self.noteID = noteID
        self.startTick = startTick
        self.durationTick = durationTick
    }
}

public struct PitchDeviation: Codable, Equatable, Sendable {
    public enum Quality: String, Codable, Sendable {
        case inTune
        case sharp
        case flat
        case lowConfidence
        case missingTarget
    }

    public var time: TimeInterval
    public var sungFrequencyHz: Double?
    public var targetMidi: Int?
    public var cents: Double?
    public var confidence: Double
    public var quality: Quality

    public init(
        time: TimeInterval,
        sungFrequencyHz: Double?,
        targetMidi: Int?,
        cents: Double?,
        confidence: Double,
        quality: Quality
    ) {
        self.time = time
        self.sungFrequencyHz = sungFrequencyHz
        self.targetMidi = targetMidi
        self.cents = cents
        self.confidence = confidence
        self.quality = quality
    }
}

public enum AudioSourceKind: String, Codable, Sendable {
    case localFile
    case userRecording
    case licensedRemoteAudio
    case youtubeReference
}

public struct AudioSourceReference: Codable, Equatable, Sendable {
    public var kind: AudioSourceKind
    public var identifier: String
    public var displayName: String?
    public var isEditable: Bool

    public init(kind: AudioSourceKind, identifier: String, displayName: String? = nil, isEditable: Bool) {
        self.kind = kind
        self.identifier = identifier
        self.displayName = displayName
        self.isEditable = isEditable
    }
}

public struct AudioScoreSyncAnchor: Codable, Equatable, Sendable {
    public var scoreTime: TimeInterval
    public var audioTime: TimeInterval
    public var confidence: Double

    public init(scoreTime: TimeInterval, audioTime: TimeInterval, confidence: Double) {
        self.scoreTime = scoreTime
        self.audioTime = audioTime
        self.confidence = confidence
    }
}

public struct PerformanceDifference: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case pitch
        case timing
        case missingPitch
        case extraPitch
        case articulation
    }

    public enum AnnotationColor: String, Codable, Sendable {
        case blue
        case red
        case orange
    }

    public var kind: Kind
    public var target: TargetPitchPoint
    public var audioTime: TimeInterval
    public var cents: Double?
    public var timingOffset: TimeInterval?
    public var confidence: Double
    public var annotationColor: AnnotationColor

    public init(
        kind: Kind,
        target: TargetPitchPoint,
        audioTime: TimeInterval,
        cents: Double?,
        timingOffset: TimeInterval?,
        confidence: Double,
        annotationColor: AnnotationColor = .blue
    ) {
        self.kind = kind
        self.target = target
        self.audioTime = audioTime
        self.cents = cents
        self.timingOffset = timingOffset
        self.confidence = confidence
        self.annotationColor = annotationColor
    }
}

public struct AudioEditProposal: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case pitchShift
        case timeStretch
    }

    public var kind: Kind
    public var target: TargetPitchPoint
    public var cents: Double?
    public var timingOffset: TimeInterval?
    public var confidence: Double

    public init(
        kind: Kind,
        target: TargetPitchPoint,
        cents: Double?,
        timingOffset: TimeInterval?,
        confidence: Double
    ) {
        self.kind = kind
        self.target = target
        self.cents = cents
        self.timingOffset = timingOffset
        self.confidence = confidence
    }
}

public protocol PitchTracking: Sendable {
    func trackPitch(samples: [Float], sampleRate: Double) async throws -> [PitchSample]
}

public protocol PitchContourSmoothing: Sendable {
    func smooth(_ samples: [PitchSample]) -> [PitchSample]
}

public struct MedianPitchContourSmoother: PitchContourSmoothing {
    public var windowSize: Int
    public var minimumConfidence: Double

    public init(windowSize: Int = 5, minimumConfidence: Double = 0.5) {
        self.windowSize = max(1, windowSize)
        self.minimumConfidence = minimumConfidence
    }

    public func smooth(_ samples: [PitchSample]) -> [PitchSample] {
        samples.indices.map { index in
            let lowerBound = max(samples.startIndex, index - windowSize / 2)
            let upperBound = min(samples.endIndex, index + windowSize / 2 + 1)
            let frequencies = samples[lowerBound..<upperBound]
                .filter { $0.confidence >= minimumConfidence }
                .compactMap(\.frequencyHz)
                .sorted()

            guard !frequencies.isEmpty else {
                return PitchSample(
                    time: samples[index].time,
                    frequencyHz: nil,
                    confidence: samples[index].confidence
                )
            }

            let median = frequencies[frequencies.count / 2]
            return PitchSample(
                time: samples[index].time,
                frequencyHz: median,
                confidence: samples[index].confidence
            )
        }
    }
}

public struct PitchDeviationAnalyzer: Sendable {
    public var toleranceCents: Double
    public var minimumConfidence: Double

    public init(toleranceCents: Double = 35, minimumConfidence: Double = 0.5) {
        self.toleranceCents = toleranceCents
        self.minimumConfidence = minimumConfidence
    }

    public func analyze(sung samples: [PitchSample], against targets: [TargetPitchPoint]) -> [PitchDeviation] {
        samples.map { sample in
            guard sample.confidence >= minimumConfidence, let frequencyHz = sample.frequencyHz else {
                return PitchDeviation(
                    time: sample.time,
                    sungFrequencyHz: sample.frequencyHz,
                    targetMidi: nearestTarget(to: sample.time, in: targets)?.midi,
                    cents: nil,
                    confidence: sample.confidence,
                    quality: .lowConfidence
                )
            }

            guard let target = nearestTarget(to: sample.time, in: targets) else {
                return PitchDeviation(
                    time: sample.time,
                    sungFrequencyHz: frequencyHz,
                    targetMidi: nil,
                    cents: nil,
                    confidence: sample.confidence,
                    quality: .missingTarget
                )
            }

            let cents = Self.centsDifference(frequencyHz: frequencyHz, targetMidi: target.midi)
            let quality: PitchDeviation.Quality
            if abs(cents) <= toleranceCents {
                quality = .inTune
            } else if cents > 0 {
                quality = .sharp
            } else {
                quality = .flat
            }

            return PitchDeviation(
                time: sample.time,
                sungFrequencyHz: frequencyHz,
                targetMidi: target.midi,
                cents: cents,
                confidence: sample.confidence,
                quality: quality
            )
        }
    }

    public static func frequencyHz(forMIDI midi: Int) -> Double {
        440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    public static func centsDifference(frequencyHz: Double, targetMidi: Int) -> Double {
        1200.0 * log2(frequencyHz / Self.frequencyHz(forMIDI: targetMidi))
    }

    private func nearestTarget(to time: TimeInterval, in targets: [TargetPitchPoint]) -> TargetPitchPoint? {
        if let activeTarget = targets.first(where: { target in
            guard target.duration > 0 else {
                return false
            }
            return time >= target.time && time < target.time + target.duration
        }) {
            return activeTarget
        }

        return targets.min { lhs, rhs in
            abs(lhs.time - time) < abs(rhs.time - time)
        }
    }
}

public struct ScoreAudioAlignmentAnalyzer: Sendable {
    public var pitchToleranceCents: Double
    public var timingTolerance: TimeInterval
    public var minimumConfidence: Double
    public var analysisWindowPadding: TimeInterval

    public init(
        pitchToleranceCents: Double = 35,
        timingTolerance: TimeInterval = 0.08,
        minimumConfidence: Double = 0.55,
        analysisWindowPadding: TimeInterval = 0.08
    ) {
        self.pitchToleranceCents = pitchToleranceCents
        self.timingTolerance = timingTolerance
        self.minimumConfidence = minimumConfidence
        self.analysisWindowPadding = analysisWindowPadding
    }

    public func differences(
        targets: [TargetPitchPoint],
        audioSamples: [PitchSample],
        anchors: [AudioScoreSyncAnchor] = []
    ) -> [PerformanceDifference] {
        let sortedSamples = audioSamples.sorted { $0.time < $1.time }
        return targets.flatMap { target -> [PerformanceDifference] in
            let expectedAudioTime = mappedAudioTime(forScoreTime: target.time, anchors: anchors)
            let targetEnd = expectedAudioTime + max(target.duration, timingTolerance)
            let windowStart = expectedAudioTime - analysisWindowPadding
            let windowEnd = targetEnd + analysisWindowPadding
            let windowSamples = sortedSamples.filter { sample in
                sample.time >= windowStart && sample.time <= windowEnd
            }
            let confidentSamples = windowSamples.filter { sample in
                sample.confidence >= minimumConfidence && sample.frequencyHz != nil
            }

            guard !confidentSamples.isEmpty else {
                return [
                    PerformanceDifference(
                        kind: .missingPitch,
                        target: target,
                        audioTime: expectedAudioTime,
                        cents: nil,
                        timingOffset: nil,
                        confidence: 0,
                        annotationColor: .blue
                    )
                ]
            }

            var differences: [PerformanceDifference] = []
            let medianFrequency = median(confidentSamples.compactMap(\.frequencyHz))
            let medianConfidence = median(confidentSamples.map(\.confidence)) ?? 0

            if let medianFrequency {
                let cents = PitchDeviationAnalyzer.centsDifference(
                    frequencyHz: medianFrequency,
                    targetMidi: target.midi
                )
                if abs(cents) > pitchToleranceCents {
                    differences.append(
                        PerformanceDifference(
                            kind: .pitch,
                            target: target,
                            audioTime: medianTime(confidentSamples),
                            cents: cents,
                            timingOffset: nil,
                            confidence: medianConfidence,
                            annotationColor: .blue
                        )
                    )
                }
            }

            if let onsetSample = confidentSamples.first {
                let timingOffset = onsetSample.time - expectedAudioTime
                if abs(timingOffset) > timingTolerance {
                    differences.append(
                        PerformanceDifference(
                            kind: .timing,
                            target: target,
                            audioTime: onsetSample.time,
                            cents: nil,
                            timingOffset: timingOffset,
                            confidence: onsetSample.confidence,
                            annotationColor: .blue
                        )
                    )
                }
            }

            return differences
        }
    }

    public func editProposals(for differences: [PerformanceDifference]) -> [AudioEditProposal] {
        differences.compactMap { difference in
            switch difference.kind {
            case .pitch:
                AudioEditProposal(
                    kind: .pitchShift,
                    target: difference.target,
                    cents: difference.cents.map { -$0 },
                    timingOffset: nil,
                    confidence: difference.confidence
                )
            case .timing:
                AudioEditProposal(
                    kind: .timeStretch,
                    target: difference.target,
                    cents: nil,
                    timingOffset: difference.timingOffset.map { -$0 },
                    confidence: difference.confidence
                )
            case .missingPitch, .extraPitch, .articulation:
                nil
            }
        }
    }

    private func mappedAudioTime(forScoreTime scoreTime: TimeInterval, anchors: [AudioScoreSyncAnchor]) -> TimeInterval {
        let sortedAnchors = anchors.sorted { $0.scoreTime < $1.scoreTime }
        guard !sortedAnchors.isEmpty else {
            return scoreTime
        }

        if let exact = sortedAnchors.first(where: { abs($0.scoreTime - scoreTime) < 0.000_1 }) {
            return exact.audioTime
        }

        guard let next = sortedAnchors.first(where: { $0.scoreTime > scoreTime }) else {
            let last = sortedAnchors[sortedAnchors.count - 1]
            return last.audioTime + scoreTime - last.scoreTime
        }

        guard let previous = sortedAnchors.last(where: { $0.scoreTime < scoreTime }) else {
            return next.audioTime - (next.scoreTime - scoreTime)
        }

        let scoreSpan = next.scoreTime - previous.scoreTime
        guard scoreSpan > 0 else {
            return previous.audioTime
        }

        let progress = (scoreTime - previous.scoreTime) / scoreSpan
        return previous.audioTime + progress * (next.audioTime - previous.audioTime)
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func medianTime(_ samples: [PitchSample]) -> TimeInterval {
        median(samples.map(\.time)) ?? samples[0].time
    }
}

public struct ScoreTimelineBuilder: Sendable {
    public var includeRepeats: Bool

    public init(includeRepeats: Bool = true) {
        self.includeRepeats = includeRepeats
    }

    public func targetPitchTimeline(for score: ScoreDocument, partIndex: Int = 0) -> [TargetPitchPoint] {
        guard score.parts.indices.contains(partIndex) else {
            return []
        }

        let part = score.parts[partIndex]
        let secondsPerTick = 60.0 / Double(max(score.tempoBPM, 1)) / Double(max(score.ticksPerQuarter, 1))
        var absoluteTick = 0
        var targets: [TargetPitchPoint] = []

        for measure in measureSequence(for: part) {
            let originalMeasureStartTick = measure.notes
                .map(\.startTick)
                .min() ?? 0
            let measureDuration = measure.notes
                .map { $0.startTick + $0.durationTick - originalMeasureStartTick }
                .max() ?? 0

            for note in measure.notes where !note.isRest {
                guard let midi = note.midi else {
                    continue
                }
                let startTick = absoluteTick + note.startTick - originalMeasureStartTick
                targets.append(
                    TargetPitchPoint(
                        time: Double(startTick) * secondsPerTick,
                        midi: midi,
                        duration: Double(note.durationTick) * secondsPerTick,
                        partID: part.id,
                        measureNumber: measure.number,
                        noteID: note.id,
                        startTick: startTick,
                        durationTick: note.durationTick
                    )
                )
            }

            absoluteTick += measureDuration
        }

        return targets
    }

    public func measureSequence(for part: ScorePart) -> [ScoreMeasure] {
        guard includeRepeats else {
            return part.measures
        }

        var sequence: [ScoreMeasure] = []
        var repeatStartIndex = 0

        for index in part.measures.indices {
            let measure = part.measures[index]
            if measure.repeatStart {
                repeatStartIndex = index
            }

            sequence.append(measure)

            if measure.repeatEnd, repeatStartIndex <= index {
                sequence.append(contentsOf: part.measures[repeatStartIndex...index])
                repeatStartIndex = index + 1
            }
        }

        return sequence
    }
}
