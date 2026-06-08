import Foundation
import Testing
@testable import ShenghaiCore

struct ShenghaiCoreTests {
    @Test func composesMusicXMLAndImportsItBack() throws {
        let composed = ComposedScore(
            title: "Shenghai Draft",
            partName: "Alto",
            tempoBPM: 88,
            beats: 4,
            beatType: 4,
            notes: [
                ComposedScoreNote(pitch: ComposedPitch(step: .C, octave: 4), value: .quarter),
                ComposedScoreNote(pitch: ComposedPitch(step: .D, alter: 1, octave: 4), value: .quarter),
                ComposedScoreNote(pitch: nil, value: .half),
                ComposedScoreNote(pitch: ComposedPitch(step: .E, octave: 4), value: .whole)
            ]
        )

        let generated = MusicXMLComposer.makeScoreDocument(from: composed)
        let xml = MusicXMLComposer.makeMusicXML(from: composed)
        let imported = try MusicXMLImporter().importDocument(data: Data(xml.utf8))

        #expect(xml.contains("<work-title>Shenghai Draft</work-title>"))
        #expect(generated.sourceFormat == "Shenghai Composer")
        #expect(generated.parts[0].measures.count == 2)
        #expect(generated.parts[0].measures[0].notes[0].midi == 60)
        #expect(generated.parts[0].measures[0].notes[2].isRest)
        #expect(imported.tempoBPM == 88)
        #expect(imported.parts[0].name == "Alto")
        #expect(imported.parts[0].measures.count == 2)
        #expect(imported.parts[0].measures[0].notes.map(\.midi) == [60, 63, nil])
        #expect(imported.parts[0].measures[0].notes[2].isRest)
        #expect(imported.parts[0].measures[1].notes.first?.midi == 64)
        #expect(imported.parts[0].measures[1].notes[0].durationTick == 1_920)
    }

    @Test func importsSimpleMusicXML() throws {
        let score = try MusicXMLImporter().importDocument(data: Data(Self.twinkleMusicXML.utf8))

        #expect(score.parts.count == 1)
        #expect(score.parts[0].name == "Voice")
        #expect(score.parts[0].measures.count == 2)
        #expect(score.parts[0].measures[0].notes.count == 4)
        #expect(score.parts[0].measures[0].notes[0].midi == 60)
        #expect(score.parts[0].measures[1].notes[2].durationTick == 960)
    }

    @Test func importsMusicXMLLyricsMetadataAndDirectionsForScanReview() throws {
        let score = try MusicXMLImporter().importDocument(data: Data(Self.lyricDirectionMusicXML.utf8))

        #expect(score.metadata.title == "Birthday Scan")
        #expect(score.metadata.composer == "Traditional")
        #expect(score.metadata.lyricist == "Public domain")
        #expect(score.parts[0].measures[0].directions.map(\.value).contains("rit."))
        #expect(score.parts[0].measures[0].directions.map(\.value).contains("mf"))
        #expect(score.parts[0].measures[0].notes[0].lyrics.first?.text == "Hap")
        #expect(score.parts[0].measures[0].notes[0].lyrics.first?.syllabic == "begin")
        #expect(score.parts[0].measures[0].notes[1].lyrics.first?.text == "py")
        #expect(score.parts[0].measures[0].notes[1].lyrics.first?.syllabic == "end")

        let candidate = OMRMusicXMLCandidateBuilder.makeCandidate(
            sourceName: "birthday.png",
            inputKind: .image,
            provider: .homr,
            score: score
        )

        #expect(candidate.canEnterPracticeWorkflow)
        #expect(candidate.recognizedElements.first(where: { $0.kind == .metadata })?.count == 3)
        #expect(candidate.recognizedElements.first(where: { $0.kind == .lyrics })?.count == 2)
        #expect(candidate.recognizedElements.first(where: { $0.kind == .directions })?.count == 2)
        #expect(candidate.reviewChecklist.first?.contains("every staff") == true)
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

    @Test func importsTempoMeterRepeatsAndBuildsTargetTimeline() throws {
        let score = try MusicXMLImporter().importDocument(data: Data(Self.repeatedMusicXML.utf8))

        #expect(score.tempoBPM == 120)
        #expect(score.parts[0].measures[0].beats == 2)
        #expect(score.parts[0].measures[0].beatType == 4)
        #expect(score.parts[0].measures[0].repeatStart)
        #expect(score.parts[0].measures[1].repeatEnd)

        let timeline = ScoreTimelineBuilder().targetPitchTimeline(for: score)

        #expect(timeline.map(\.midi) == [60, 62, 60, 62])
        #expect(timeline.map(\.measureNumber) == ["1", "2", "1", "2"])
        #expect(timeline[0].time == 0)
        #expect(abs(timeline[1].time - 0.5) < 0.001)
        #expect(abs(timeline[2].time - 1.0) < 0.001)
        #expect(abs(timeline[3].time - 1.5) < 0.001)
        #expect(abs(timeline[0].duration - 0.5) < 0.001)
        #expect(timeline[0].partID == "P1")
        #expect(timeline[0].noteID?.contains("P1-1") == true)
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

    @Test func detectsScoreAudioPitchAndTimingDifferences() {
        let target = TargetPitchPoint(
            time: 1.0,
            midi: 60,
            duration: 0.45,
            partID: "P1",
            measureNumber: "8",
            noteID: "P1-8-1",
            startTick: 960,
            durationTick: 480
        )
        let sharpFrequency = PitchDeviationAnalyzer.frequencyHz(forMIDI: 60) * pow(2.0, 55.0 / 1200.0)
        let samples = [
            PitchSample(time: 1.12, frequencyHz: sharpFrequency, confidence: 0.92),
            PitchSample(time: 1.22, frequencyHz: sharpFrequency, confidence: 0.91),
            PitchSample(time: 1.32, frequencyHz: sharpFrequency, confidence: 0.90)
        ]
        let analyzer = ScoreAudioAlignmentAnalyzer(
            pitchToleranceCents: 35,
            timingTolerance: 0.08,
            minimumConfidence: 0.6,
            analysisWindowPadding: 0.15
        )

        let differences = analyzer.differences(targets: [target], audioSamples: samples)
        let proposals = analyzer.editProposals(for: differences)

        #expect(differences.map(\.kind).contains(.pitch))
        #expect(differences.map(\.kind).contains(.timing))
        #expect(differences.allSatisfy { $0.annotationColor == .blue })
        #expect(differences.first?.target.measureNumber == "8")
        #expect(proposals.map(\.kind).contains(.pitchShift))
        #expect(proposals.map(\.kind).contains(.timeStretch))
        #expect(proposals.first(where: { $0.kind == .pitchShift })?.cents ?? 0 < -50)
        #expect(proposals.first(where: { $0.kind == .timeStretch })?.timingOffset ?? 0 < -0.08)
    }

    @Test func mapsScoreAudioAnchorsWhenComparingReferenceAudio() {
        let target = TargetPitchPoint(time: 2.0, midi: 64, duration: 0.3)
        let expectedFrequency = PitchDeviationAnalyzer.frequencyHz(forMIDI: 64)
        let samples = [
            PitchSample(time: 3.0, frequencyHz: expectedFrequency, confidence: 0.95)
        ]
        let anchors = [
            AudioScoreSyncAnchor(scoreTime: 0.0, audioTime: 1.0, confidence: 0.9),
            AudioScoreSyncAnchor(scoreTime: 2.0, audioTime: 3.0, confidence: 0.9)
        ]

        let differences = ScoreAudioAlignmentAnalyzer()
            .differences(targets: [target], audioSamples: samples, anchors: anchors)

        #expect(differences.isEmpty)
    }

    @Test func summarizesUsageByDayAndFeature() {
        var ledger = UsageAnalyticsLedger()
        let start = Date(timeIntervalSince1970: 1_788_000_000)

        ledger.switchTo(.scoreWorkspace, at: start)
        ledger.switchTo(.practice, at: start.addingTimeInterval(120))
        ledger.closeActiveEvent(at: start.addingTimeInterval(300))

        let summaries = ledger.dailySummaries(calendar: Calendar(identifier: .gregorian))
        let featureDurations = ledger.featureDurationsIncludingActive(now: start.addingTimeInterval(300))

        #expect(summaries.count == 1)
        #expect(summaries[0].totalDuration == 300)
        #expect(summaries[0].featureDurations[.scoreWorkspace] == 120)
        #expect(summaries[0].featureDurations[.practice] == 180)
        #expect(featureDurations[.scoreWorkspace] == 120)
        #expect(featureDurations[.practice] == 180)
    }

    @Test func experimentalSingingSupportFeatureKeepsMedicalSafetyBoundaries() {
        let feature = ExperimentalFeatureCatalog.singingSupportLab
        let sessionPlan = ExperimentalFeatureCatalog.makeSingingSupportSessionPlan()

        #expect(feature.id == "singing-support-lab")
        #expect(feature.status == .prototype)
        #expect(feature.safetyNotice.localizedCaseInsensitiveContains("not a cure"))
        #expect(feature.notIntendedUse.contains("Curing autism or any disease."))
        #expect(feature.protocolSteps.map(\.id) == [
            "consent",
            "baseline",
            "hum",
            "listen",
            "respond",
            "feedback",
            "post"
        ])
        #expect(feature.trackedMetrics.contains("sensoryComfort"))
        #expect(feature.evidenceReferences.contains { $0.domain == .autismCommunication })
        #expect(feature.evidenceReferences.contains { $0.domain == .respiratoryHealth })
        #expect(sessionPlan.protocolName == "Gentle Call-and-Response")
        #expect(sessionPlan.estimatedDurationSeconds > 0)
        #expect(sessionPlan.requiredConsentPrompts.count == 3)
    }

    @Test func experimentalSingToDismissAlarmStatesPlatformBoundaries() {
        let feature = ExperimentalFeatureCatalog.singToDismissAlarm
        let plan = ExperimentalFeatureCatalog.makeSingToDismissAlarmPlan()

        #expect(feature.id == "sing-to-dismiss-alarm")
        #expect(ExperimentalFeatureCatalog.all.map(\.id).contains("sing-to-dismiss-alarm"))
        #expect(feature.status == .concept)
        #expect(feature.safetyNotice.localizedCaseInsensitiveContains("cannot guarantee"))
        #expect(feature.notIntendedUse.contains("Life-critical alarms, medication reminders, safety reminders, or emergency wake-up use."))
        #expect(feature.notIntendedUse.contains("Continuous background microphone listening while the app is closed."))
        #expect(feature.protocolSteps.map(\.id) == [
            "schedule",
            "notify",
            "open",
            "sing",
            "unlock",
            "bypass"
        ])
        #expect(plan.songTitle == "Happy Birthday")
        #expect(plan.targetTimeline.count == 25)
        #expect(plan.platformLimitation.localizedCaseInsensitiveContains("cannot force"))
        #expect(plan.requiredConsentPrompts.count == 3)
    }

    @Test func singToDismissAlarmRequiresFullSongCoverage() {
        let plan = ExperimentalFeatureCatalog.makeSingToDismissAlarmPlan(
            challengeTargetCoverageRatio: 0.90,
            requiredInTuneRatio: 0.70
        )
        let evaluator = SingToDismissAlarmEvaluator()

        let partialSamples = plan.targetTimeline.prefix(6).map { target in
            PitchSample(
                time: target.time + min(target.duration / 2, 0.2),
                frequencyHz: PitchDeviationAnalyzer.frequencyHz(forMIDI: target.midi),
                confidence: 0.92
            )
        }
        let partialEvaluation = evaluator.evaluate(samples: partialSamples, against: plan)

        #expect(!partialEvaluation.isDismissalUnlocked)
        #expect(partialEvaluation.coveredNoteCount == 6)
        #expect(partialEvaluation.coveredTargetRatio < 0.90)

        let completeSamples = plan.targetTimeline.map { target in
            PitchSample(
                time: target.time + min(target.duration / 2, 0.2),
                frequencyHz: PitchDeviationAnalyzer.frequencyHz(forMIDI: target.midi),
                confidence: 0.96
            )
        }
        let completeEvaluation = evaluator.evaluate(samples: completeSamples, against: plan)

        #expect(completeEvaluation.isDismissalUnlocked)
        #expect(completeEvaluation.coveredNoteCount == plan.targetTimeline.count)
        #expect(completeEvaluation.inTuneRatio == 1)
        #expect(completeEvaluation.requiredNoteCount == Int(ceil(0.90 * Double(plan.targetTimeline.count))))
    }

    @Test func textRhythmSpeechLabKeepsRightsAndMedicalBoundaries() {
        let feature = ExperimentalFeatureCatalog.textRhythmSpeechLab
        let plan = ExperimentalFeatureCatalog.makeTextRhythmSpeechPlan(category: .science, tempoBPM: 96)

        #expect(feature.id == "text-rhythm-speech-lab")
        #expect(ExperimentalFeatureCatalog.all.map(\.id).contains("text-rhythm-speech-lab"))
        #expect(feature.safetyNotice.localizedCaseInsensitiveContains("not a cure"))
        #expect(feature.notIntendedUse.contains("Claiming that a user is cured of autism, aphasia, stuttering, dysarthria, or any disease."))
        #expect(feature.notIntendedUse.contains("Using copyrighted articles, books, lyrics, or news text without permission."))
        #expect(feature.protocolSteps.map(\.id) == [
            "rights",
            "category",
            "rhythm",
            "guided",
            "unguided",
            "review"
        ])
        #expect(plan.prompt.category == .science)
        #expect(plan.tempoBPM == 96)
        #expect(plan.cues.count == plan.prompt.text.split(separator: " ").count)
        #expect(plan.cues.first?.isStrongBeat == true)
        #expect(plan.requiredConsentPrompts.count == 3)
        #expect(feature.evidenceReferences.contains { $0.domain == .speechRhythmAndProsody })
    }

    @Test func textRhythmSpeechEvaluatorScoresGuidedReadingAttempt() {
        let plan = ExperimentalFeatureCatalog.makeTextRhythmSpeechPlan(category: .poem, tempoBPM: 100)
        let spoken = plan.cues.map { cue in
            SpokenToken(
                token: cue.token,
                startTime: cue.startTime + 0.03,
                duration: cue.duration * 0.65,
                confidence: 0.88
            )
        }
        let evaluation = TextRhythmSpeechEvaluator().evaluate(spokenTokens: spoken, against: plan)

        #expect(evaluation.clarityScore == 1)
        #expect(evaluation.completionScore == 1)
        #expect(evaluation.rhythmScore > 0.80)
        #expect(evaluation.rateScore > 0.60)
        #expect(evaluation.overallPracticeScore > 0.78)

        let incomplete = Array(spoken.prefix(3))
        let incompleteEvaluation = TextRhythmSpeechEvaluator().evaluate(spokenTokens: incomplete, against: plan)

        #expect(incompleteEvaluation.completionScore < 0.50)
        #expect(incompleteEvaluation.overallPracticeScore < evaluation.overallPracticeScore)
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

    @Test func createsSelectableOMRProviderPlans() {
        let homrPlan = OMRProviderCommandPlan(
            provider: .homr,
            inputPath: "/tmp/choir score.png",
            outputPath: "/tmp/choir.musicxml"
        )
        let oemerPlan = OMRProviderCommandPlan(
            provider: .oemer,
            inputPath: "/tmp/choir score.png",
            outputPath: "/tmp/choir.musicxml"
        )
        let pipeline = OMRPipelinePlan.mvpBaseline(inputKind: .image, provider: .oemer)

        #expect(OMRProvider.allCases == [.homr, .oemer])
        #expect(homrPlan.commandName == "homr")
        #expect(homrPlan.arguments == ["/tmp/choir score.png", "--output", "/tmp/choir.musicxml"])
        #expect(homrPlan.shellPreview.contains("'"))
        #expect(oemerPlan.commandName == "oemer")
        #expect(oemerPlan.arguments == ["-o", "/tmp/choir.musicxml", "/tmp/choir score.png"])
        #expect(pipeline.provider == .oemer)
        #expect(pipeline.stages.first(where: { $0.stage == .omrRecognition })?.note.contains("oemer") == true)
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

    private static let lyricDirectionMusicXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <score-partwise version="4.0">
      <work><work-title>Birthday Scan</work-title></work>
      <identification>
        <creator type="composer">Traditional</creator>
        <creator type="lyricist">Public domain</creator>
      </identification>
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
              <beats>2</beats>
              <beat-type>4</beat-type>
            </time>
          </attributes>
          <direction placement="above">
            <direction-type>
              <words>rit.</words>
              <dynamics><mf/></dynamics>
            </direction-type>
          </direction>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
            <lyric number="1"><syllabic>begin</syllabic><text>Hap</text></lyric>
          </note>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
            <lyric number="1"><syllabic>end</syllabic><text>py</text></lyric>
          </note>
        </measure>
      </part>
    </score-partwise>
    """

    private static let repeatedMusicXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <score-partwise version="4.0">
      <part-list>
        <score-part id="P1">
          <part-name>Voice</part-name>
        </score-part>
      </part-list>
      <part id="P1">
        <measure number="1">
          <direction>
            <sound tempo="120"/>
          </direction>
          <attributes>
            <divisions>1</divisions>
            <time>
              <beats>2</beats>
              <beat-type>4</beat-type>
            </time>
          </attributes>
          <barline location="left">
            <repeat direction="forward"/>
          </barline>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
        </measure>
        <measure number="2">
          <note>
            <pitch><step>D</step><octave>4</octave></pitch>
            <duration>1</duration><type>quarter</type>
          </note>
          <barline location="right">
            <repeat direction="backward"/>
          </barline>
        </measure>
      </part>
    </score-partwise>
    """
}
