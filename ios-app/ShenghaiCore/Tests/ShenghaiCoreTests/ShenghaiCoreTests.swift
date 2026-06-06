import Foundation
import Testing
@testable import ShenghaiCore

struct ShenghaiCoreTests {
    @Test func importsSimpleMusicXML() throws {
        let score = try MusicXMLImporter().importDocument(data: Data(Self.twinkleMusicXML.utf8))

        #expect(score.parts.count == 1)
        #expect(score.parts[0].name == "Voice")
        #expect(score.parts[0].measures.count == 2)
        #expect(score.parts[0].measures[0].notes.count == 4)
        #expect(score.parts[0].measures[0].notes[0].midi == 60)
        #expect(score.parts[0].measures[1].notes[2].durationTick == 960)
    }

    @Test func createsPlaybackEventsAndMIDIData() throws {
        let score = try MusicXMLImporter().importDocument(data: Data(Self.twinkleMusicXML.utf8))
        let events = MIDIWriter.playbackEvents(for: score)
        let midiData = MIDIWriter.makeMIDIData(score: score)

        #expect(events.count == 14)
        #expect(events.first?.tick == 0)
        #expect(events.first?.midi == 60)
        #expect(String(data: midiData.prefix(4), encoding: .ascii) == "MThd")
        #expect(midiData.count > 40)
    }

    @Test func analyzesPitchDeviationWithConfidence() {
        let analyzer = PitchDeviationAnalyzer(toleranceCents: 25, minimumConfidence: 0.6)
        let samples = [
            PitchSample(time: 0.0, frequencyHz: 440.0, confidence: 0.95),
            PitchSample(time: 0.5, frequencyHz: 452.0, confidence: 0.90),
            PitchSample(time: 1.0, frequencyHz: nil, confidence: 0.20)
        ]
        let targets = [
            TargetPitchPoint(time: 0.0, midi: 69),
            TargetPitchPoint(time: 0.5, midi: 69),
            TargetPitchPoint(time: 1.0, midi: 69)
        ]

        let deviations = analyzer.analyze(sung: samples, against: targets)

        #expect(deviations[0].quality == .inTune)
        #expect(deviations[1].quality == .sharp)
        #expect(deviations[2].quality == .lowConfidence)
    }

    @Test func yinPitchTrackerDetectsSyntheticA4() async throws {
        let sampleRate = 44_100.0
        let frequency = 440.0
        let samples = (0..<4096).map { index in
            Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate))
        }

        let tracker = YINPitchTracker(frameSize: 2048, hopSize: 1024, minimumFrequency: 80, maximumFrequency: 900)
        let tracked = try await tracker.trackPitch(samples: samples, sampleRate: sampleRate)
        let detected = tracked.compactMap(\.frequencyHz).first ?? 0

        #expect(abs(detected - frequency) < 3)
        #expect((tracked.first?.confidence ?? 0) > 0.7)
    }

    @Test func createsAudiverisCommandPlan() {
        let plan = AudiverisCommandPlan(
            inputPath: "/tmp/score sample.pdf",
            outputDirectory: "/tmp/musicxml"
        )

        #expect(plan.arguments == [
            "-batch",
            "-transcribe",
            "-export",
            "-output",
            "/tmp/musicxml",
            "/tmp/score sample.pdf"
        ])
        #expect(plan.shellPreview.contains("-transcribe"))
        #expect(OMRPipelinePlan.mvpBaseline(inputKind: .pdf).stages.count == OMRPipelineStage.allCases.count)
    }

    private static let twinkleMusicXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <score-partwise version="4.0">
      <part-list>
        <score-part id="P1">
          <part-name>Voice</part-name>
        </score-part>
      </part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time>
              <beats>4</beats>
              <beat-type>4</beat-type>
            </time>
          </attributes>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
          <note>
            <pitch><step>G</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
          <note>
            <pitch><step>G</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
        </measure>
        <measure number="2">
          <note>
            <pitch><step>A</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
          <note>
            <pitch><step>A</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
          <note>
            <pitch><step>G</step><octave>4</octave></pitch>
            <duration>2</duration><type>half</type>
          </note>
        </measure>
      </part>
    </score-partwise>
    """
}
