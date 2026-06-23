import Foundation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct ScoreReviewPage: Identifiable, Equatable {
    var id: Int { pageIndex }
    var pageIndex: Int
    var pixelWidth: Int
    var pixelHeight: Int
    var imageData: Data
    var status: NativeOMRPageRecognitionStatus
}

enum ScoreReviewSymbolKind: String, CaseIterable, Identifiable {
    case note
    case rest
    case lyric
    case clef
    case keySignature
    case timeSignature
    case direction
    case repeatStart
    case repeatEnd

    var id: String { rawValue }
}

struct ScoreReviewSymbol: Identifiable, Equatable {
    var id: String
    var kind: ScoreReviewSymbolKind
    var partID: String
    var measureNumber: String
    var noteID: String?
    var lyricID: String?
    var directionID: String?
    var pageIndex: Int?
    var bounds: NativeOMRNormalizedRect?
    var order: Int
}

struct ScoreReviewSession: Equatable {
    var sourceName: String
    var inputKind: OMRInputKind
    var pages: [ScoreReviewPage]
    var symbols: [ScoreReviewSymbol]
}

enum ScoreReviewSessionBuilder {
    static func make(
        sourceName: String,
        inputKind: OMRInputKind,
        score: ScoreDocument,
        pages: [ScoreReviewPage],
        scoreNotation: NativeOMRScoreNotation?
    ) -> ScoreReviewSession {
        var symbols: [ScoreReviewSymbol] = []
        var order = 0

        for part in score.parts {
            for (measureIndex, measure) in part.measures.enumerated() {
                let notationMeasure = scoreNotation?.mergedMeasures[safe: measureIndex]
                let pageIndex = notationMeasure?.pageIndex
                let measureBounds = notationMeasure?.bounds
                let noteEvents = notationMeasure.map { measureResult in
                    (scoreNotation?.mergedEvents ?? [])
                        .filter { $0.measureID == measureResult.id }
                        .sorted { $0.beatIndex < $1.beatIndex }
                } ?? []

                if measure.clefSign != nil || measureIndex == 0 {
                    symbols.append(
                        ScoreReviewSymbol(
                            id: "clef-\(part.id)-\(measure.number)",
                            kind: .clef,
                            partID: part.id,
                            measureNumber: measure.number,
                            noteID: nil,
                            lyricID: nil,
                            directionID: nil,
                            pageIndex: pageIndex,
                            bounds: derivedMeasureAnchor(from: measureBounds, x: 0.02, y: 0.08, width: 0.14, height: 0.46),
                            order: order
                        )
                    )
                    order += 1
                }

                if measure.keyFifths != nil || measureIndex == 0 {
                    symbols.append(
                        ScoreReviewSymbol(
                            id: "key-\(part.id)-\(measure.number)",
                            kind: .keySignature,
                            partID: part.id,
                            measureNumber: measure.number,
                            noteID: nil,
                            lyricID: nil,
                            directionID: nil,
                            pageIndex: pageIndex,
                            bounds: derivedMeasureAnchor(from: measureBounds, x: 0.16, y: 0.08, width: 0.16, height: 0.46),
                            order: order
                        )
                    )
                    order += 1
                }

                if (measure.beats != nil && measure.beatType != nil) || measureIndex == 0 {
                    symbols.append(
                        ScoreReviewSymbol(
                            id: "time-\(part.id)-\(measure.number)",
                            kind: .timeSignature,
                            partID: part.id,
                            measureNumber: measure.number,
                            noteID: nil,
                            lyricID: nil,
                            directionID: nil,
                            pageIndex: pageIndex,
                            bounds: derivedMeasureAnchor(from: measureBounds, x: 0.33, y: 0.08, width: 0.14, height: 0.46),
                            order: order
                        )
                    )
                    order += 1
                }

                if measure.repeatStart {
                    symbols.append(
                        ScoreReviewSymbol(
                            id: "repeat-start-\(part.id)-\(measure.number)",
                            kind: .repeatStart,
                            partID: part.id,
                            measureNumber: measure.number,
                            noteID: nil,
                            lyricID: nil,
                            directionID: nil,
                            pageIndex: pageIndex,
                            bounds: derivedMeasureAnchor(from: measureBounds, x: 0.01, y: 0.02, width: 0.08, height: 0.92),
                            order: order
                        )
                    )
                    order += 1
                }

                if measure.repeatEnd {
                    symbols.append(
                        ScoreReviewSymbol(
                            id: "repeat-end-\(part.id)-\(measure.number)",
                            kind: .repeatEnd,
                            partID: part.id,
                            measureNumber: measure.number,
                            noteID: nil,
                            lyricID: nil,
                            directionID: nil,
                            pageIndex: pageIndex,
                            bounds: derivedMeasureAnchor(from: measureBounds, x: 0.91, y: 0.02, width: 0.08, height: 0.92),
                            order: order
                        )
                    )
                    order += 1
                }

                for (directionIndex, direction) in measure.directions.enumerated() {
                    let offset = Double(directionIndex) * 0.12
                    symbols.append(
                        ScoreReviewSymbol(
                            id: "direction-\(direction.id)",
                            kind: .direction,
                            partID: part.id,
                            measureNumber: measure.number,
                            noteID: nil,
                            lyricID: nil,
                            directionID: direction.id,
                            pageIndex: pageIndex,
                            bounds: derivedMeasureAnchor(from: measureBounds, x: 0.1 + offset, y: 0.0, width: 0.24, height: 0.18),
                            order: order
                        )
                    )
                    order += 1
                }

                for (noteIndex, note) in measure.notes.enumerated() {
                    let eventBounds = noteEvents[safe: noteIndex]?.bounds
                    let noteSymbol = ScoreReviewSymbol(
                        id: "note-\(part.id)-\(measure.number)-\(note.id)",
                        kind: note.isRest ? .rest : .note,
                        partID: part.id,
                        measureNumber: measure.number,
                        noteID: note.id,
                        lyricID: nil,
                        directionID: nil,
                        pageIndex: pageIndex,
                        bounds: eventBounds ?? derivedMeasureNoteAnchor(from: measureBounds, noteIndex: noteIndex, total: max(measure.notes.count, 1)),
                        order: order
                    )
                    symbols.append(noteSymbol)
                    order += 1

                    for lyric in note.lyrics {
                        symbols.append(
                            ScoreReviewSymbol(
                                id: "lyric-\(lyric.id)",
                                kind: .lyric,
                                partID: part.id,
                                measureNumber: measure.number,
                                noteID: note.id,
                                lyricID: lyric.id,
                                directionID: nil,
                                pageIndex: pageIndex,
                                bounds: offsetLyricAnchor(from: noteSymbol.bounds),
                                order: order
                            )
                        )
                        order += 1
                    }
                }
            }
        }

        return ScoreReviewSession(
            sourceName: sourceName,
            inputKind: inputKind,
            pages: pages.sorted { $0.pageIndex < $1.pageIndex },
            symbols: symbols.sorted { $0.order < $1.order }
        )
    }

    private static func derivedMeasureAnchor(
        from measureBounds: NativeOMRNormalizedRect?,
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) -> NativeOMRNormalizedRect? {
        guard let measureBounds else {
            return nil
        }
        return NativeOMRNormalizedRect(
            x: measureBounds.x + measureBounds.width * x,
            y: measureBounds.y + measureBounds.height * y,
            width: measureBounds.width * width,
            height: measureBounds.height * height
        )
    }

    private static func derivedMeasureNoteAnchor(
        from measureBounds: NativeOMRNormalizedRect?,
        noteIndex: Int,
        total: Int
    ) -> NativeOMRNormalizedRect? {
        guard let measureBounds else {
            return nil
        }

        let usableWidth = measureBounds.width * 0.78
        let startX = measureBounds.x + measureBounds.width * 0.11
        let step = usableWidth / Double(max(total, 1))
        return NativeOMRNormalizedRect(
            x: startX + step * Double(noteIndex) + step * 0.1,
            y: measureBounds.y + measureBounds.height * 0.2,
            width: max(step * 0.65, 0.012),
            height: measureBounds.height * 0.46
        )
    }

    private static func offsetLyricAnchor(from noteBounds: NativeOMRNormalizedRect?) -> NativeOMRNormalizedRect? {
        guard let noteBounds else {
            return nil
        }
        return NativeOMRNormalizedRect(
            x: noteBounds.x,
            y: noteBounds.y + noteBounds.height * 0.88,
            width: noteBounds.width * 1.4,
            height: noteBounds.height * 0.48
        )
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
