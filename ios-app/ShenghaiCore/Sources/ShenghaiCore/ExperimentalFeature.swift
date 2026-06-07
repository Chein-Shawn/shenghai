import Foundation

public enum ExperimentalFeatureStatus: String, Codable, Sendable {
    case concept
    case prototype
    case pilotReady
    case clinicianReviewRequired
}

public enum ExperimentalEvidenceDomain: String, Codable, CaseIterable, Sendable {
    case autismCommunication
    case auditoryMotorMapping
    case aphasiaRehabilitation
    case speechRhythmAndProsody
    case respiratoryHealth
    case parkinsonVoice
    case moodAndParticipation
    case painAndWellbeing

    public var displayName: String {
        switch self {
        case .autismCommunication:
            return "Autism communication support"
        case .auditoryMotorMapping:
            return "Auditory-motor mapping"
        case .aphasiaRehabilitation:
            return "Aphasia rehabilitation"
        case .speechRhythmAndProsody:
            return "Speech rhythm and prosody"
        case .respiratoryHealth:
            return "Respiratory health"
        case .parkinsonVoice:
            return "Parkinson voice"
        case .moodAndParticipation:
            return "Mood and participation"
        case .painAndWellbeing:
            return "Pain and wellbeing"
        }
    }
}

public struct ExperimentalEvidenceReference: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var domain: ExperimentalEvidenceDomain
    public var finding: String
    public var appUse: String
    public var sourceURL: URL

    public init(
        id: String,
        title: String,
        domain: ExperimentalEvidenceDomain,
        finding: String,
        appUse: String,
        sourceURL: URL
    ) {
        self.id = id
        self.title = title
        self.domain = domain
        self.finding = finding
        self.appUse = appUse
        self.sourceURL = sourceURL
    }
}

public struct ExperimentalProtocolStep: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var instruction: String
    public var targetMetric: String?
    public var durationSeconds: TimeInterval?

    public init(
        id: String,
        title: String,
        instruction: String,
        targetMetric: String? = nil,
        durationSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.targetMetric = targetMetric
        self.durationSeconds = durationSeconds
    }
}

public struct ExperimentalFeature: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var status: ExperimentalFeatureStatus
    public var safetyNotice: String
    public var intendedUse: [String]
    public var notIntendedUse: [String]
    public var protocolSteps: [ExperimentalProtocolStep]
    public var trackedMetrics: [String]
    public var evidenceReferences: [ExperimentalEvidenceReference]

    public init(
        id: String,
        title: String,
        subtitle: String,
        status: ExperimentalFeatureStatus,
        safetyNotice: String,
        intendedUse: [String],
        notIntendedUse: [String],
        protocolSteps: [ExperimentalProtocolStep],
        trackedMetrics: [String],
        evidenceReferences: [ExperimentalEvidenceReference]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.safetyNotice = safetyNotice
        self.intendedUse = intendedUse
        self.notIntendedUse = notIntendedUse
        self.protocolSteps = protocolSteps
        self.trackedMetrics = trackedMetrics
        self.evidenceReferences = evidenceReferences
    }
}

public struct SingingSupportSessionPlan: Codable, Equatable, Sendable {
    public var featureID: String
    public var protocolName: String
    public var comfortLevel: String
    public var estimatedDurationSeconds: TimeInterval
    public var steps: [ExperimentalProtocolStep]
    public var requiredConsentPrompts: [String]

    public init(
        featureID: String,
        protocolName: String,
        comfortLevel: String,
        estimatedDurationSeconds: TimeInterval,
        steps: [ExperimentalProtocolStep],
        requiredConsentPrompts: [String]
    ) {
        self.featureID = featureID
        self.protocolName = protocolName
        self.comfortLevel = comfortLevel
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.steps = steps
        self.requiredConsentPrompts = requiredConsentPrompts
    }
}

public struct SingToDismissAlarmPlan: Codable, Equatable, Sendable {
    public var featureID: String
    public var alarmName: String
    public var songTitle: String
    public var scheduledHour: Int
    public var scheduledMinute: Int
    public var challengeTargetCoverageRatio: Double
    public var requiredInTuneRatio: Double
    public var minimumConfidence: Double
    public var pitchToleranceCents: Double
    public var platformLimitation: String
    public var dismissalPolicy: String
    public var targetTimeline: [TargetPitchPoint]
    public var requiredConsentPrompts: [String]

    public init(
        featureID: String,
        alarmName: String,
        songTitle: String,
        scheduledHour: Int,
        scheduledMinute: Int,
        challengeTargetCoverageRatio: Double,
        requiredInTuneRatio: Double,
        minimumConfidence: Double,
        pitchToleranceCents: Double,
        platformLimitation: String,
        dismissalPolicy: String,
        targetTimeline: [TargetPitchPoint],
        requiredConsentPrompts: [String]
    ) {
        self.featureID = featureID
        self.alarmName = alarmName
        self.songTitle = songTitle
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.challengeTargetCoverageRatio = challengeTargetCoverageRatio
        self.requiredInTuneRatio = requiredInTuneRatio
        self.minimumConfidence = minimumConfidence
        self.pitchToleranceCents = pitchToleranceCents
        self.platformLimitation = platformLimitation
        self.dismissalPolicy = dismissalPolicy
        self.targetTimeline = targetTimeline
        self.requiredConsentPrompts = requiredConsentPrompts
    }
}

public struct SingToDismissAlarmEvaluation: Codable, Equatable, Sendable {
    public var isDismissalUnlocked: Bool
    public var coveredTargetRatio: Double
    public var inTuneRatio: Double
    public var coveredNoteCount: Int
    public var requiredNoteCount: Int
    public var attemptedSampleCount: Int
    public var summary: String

    public init(
        isDismissalUnlocked: Bool,
        coveredTargetRatio: Double,
        inTuneRatio: Double,
        coveredNoteCount: Int,
        requiredNoteCount: Int,
        attemptedSampleCount: Int,
        summary: String
    ) {
        self.isDismissalUnlocked = isDismissalUnlocked
        self.coveredTargetRatio = coveredTargetRatio
        self.inTuneRatio = inTuneRatio
        self.coveredNoteCount = coveredNoteCount
        self.requiredNoteCount = requiredNoteCount
        self.attemptedSampleCount = attemptedSampleCount
        self.summary = summary
    }
}

public struct SingToDismissAlarmEvaluator: Sendable {
    public init() {}

    public func evaluate(samples: [PitchSample], against plan: SingToDismissAlarmPlan) -> SingToDismissAlarmEvaluation {
        let validSamples = samples.filter { $0.confidence >= plan.minimumConfidence && $0.frequencyHz != nil }
        let targets = plan.targetTimeline

        guard !targets.isEmpty else {
            return SingToDismissAlarmEvaluation(
                isDismissalUnlocked: false,
                coveredTargetRatio: 0,
                inTuneRatio: 0,
                coveredNoteCount: 0,
                requiredNoteCount: 0,
                attemptedSampleCount: validSamples.count,
                summary: "No target song is configured."
            )
        }

        var coveredNoteCount = 0
        var inTuneNoteCount = 0

        for target in targets {
            let noteDuration = max(target.duration, 0.25)
            let windowStart = target.time - 0.12
            let windowEnd = target.time + noteDuration + 0.12
            let samplesInWindow = validSamples.filter { sample in
                sample.time >= windowStart && sample.time <= windowEnd
            }

            guard !samplesInWindow.isEmpty else {
                continue
            }

            coveredNoteCount += 1

            if samplesInWindow.contains(where: { sample in
                guard let frequencyHz = sample.frequencyHz else {
                    return false
                }
                return abs(PitchDeviationAnalyzer.centsDifference(frequencyHz: frequencyHz, targetMidi: target.midi)) <= plan.pitchToleranceCents
            }) {
                inTuneNoteCount += 1
            }
        }

        let targetCount = targets.count
        let coveredTargetRatio = Double(coveredNoteCount) / Double(targetCount)
        let inTuneRatio = coveredNoteCount == 0 ? 0 : Double(inTuneNoteCount) / Double(coveredNoteCount)
        let requiredNoteCount = Int(ceil(plan.challengeTargetCoverageRatio * Double(targetCount)))
        let isDismissalUnlocked = coveredTargetRatio >= plan.challengeTargetCoverageRatio
            && inTuneRatio >= plan.requiredInTuneRatio

        let summary = isDismissalUnlocked
            ? "Dismissal unlocked after a complete enough full-song performance."
            : "Keep singing: the app-level alarm remains unresolved until coverage and pitch targets are met."

        return SingToDismissAlarmEvaluation(
            isDismissalUnlocked: isDismissalUnlocked,
            coveredTargetRatio: coveredTargetRatio,
            inTuneRatio: inTuneRatio,
            coveredNoteCount: coveredNoteCount,
            requiredNoteCount: requiredNoteCount,
            attemptedSampleCount: validSamples.count,
            summary: summary
        )
    }
}

public enum TextPromptCategory: String, Codable, CaseIterable, Sendable {
    case fiction
    case news
    case science
    case poem
    case random

    public var displayName: String {
        switch self {
        case .fiction:
            return "Fiction"
        case .news:
            return "News"
        case .science:
            return "Science"
        case .poem:
            return "Poem"
        case .random:
            return "Random"
        }
    }
}

public struct TextRhythmPrompt: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var category: TextPromptCategory
    public var text: String
    public var rightsNote: String

    public init(id: String, title: String, category: TextPromptCategory, text: String, rightsNote: String) {
        self.id = id
        self.title = title
        self.category = category
        self.text = text
        self.rightsNote = rightsNote
    }
}

public struct RhythmCue: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var token: String
    public var beatIndex: Int
    public var startTime: TimeInterval
    public var duration: TimeInterval
    public var isStrongBeat: Bool

    public init(
        id: String,
        token: String,
        beatIndex: Int,
        startTime: TimeInterval,
        duration: TimeInterval,
        isStrongBeat: Bool
    ) {
        self.id = id
        self.token = token
        self.beatIndex = beatIndex
        self.startTime = startTime
        self.duration = duration
        self.isStrongBeat = isStrongBeat
    }
}

public struct TextRhythmSpeechPlan: Codable, Equatable, Sendable {
    public var featureID: String
    public var prompt: TextRhythmPrompt
    public var tempoBPM: Int
    public var rhythmEnabled: Bool
    public var cues: [RhythmCue]
    public var trackedMetrics: [String]
    public var requiredConsentPrompts: [String]

    public init(
        featureID: String,
        prompt: TextRhythmPrompt,
        tempoBPM: Int,
        rhythmEnabled: Bool,
        cues: [RhythmCue],
        trackedMetrics: [String],
        requiredConsentPrompts: [String]
    ) {
        self.featureID = featureID
        self.prompt = prompt
        self.tempoBPM = tempoBPM
        self.rhythmEnabled = rhythmEnabled
        self.cues = cues
        self.trackedMetrics = trackedMetrics
        self.requiredConsentPrompts = requiredConsentPrompts
    }
}

public struct SpokenToken: Codable, Equatable, Sendable {
    public var token: String
    public var startTime: TimeInterval
    public var duration: TimeInterval
    public var confidence: Double

    public init(token: String, startTime: TimeInterval, duration: TimeInterval, confidence: Double) {
        self.token = token
        self.startTime = startTime
        self.duration = duration
        self.confidence = confidence
    }
}

public struct TextRhythmSpeechEvaluation: Codable, Equatable, Sendable {
    public var clarityScore: Double
    public var rateScore: Double
    public var rhythmScore: Double
    public var completionScore: Double
    public var overallPracticeScore: Double
    public var wordsPerMinute: Double
    public var matchedWordCount: Int
    public var totalWordCount: Int
    public var summary: String

    public init(
        clarityScore: Double,
        rateScore: Double,
        rhythmScore: Double,
        completionScore: Double,
        overallPracticeScore: Double,
        wordsPerMinute: Double,
        matchedWordCount: Int,
        totalWordCount: Int,
        summary: String
    ) {
        self.clarityScore = clarityScore
        self.rateScore = rateScore
        self.rhythmScore = rhythmScore
        self.completionScore = completionScore
        self.overallPracticeScore = overallPracticeScore
        self.wordsPerMinute = wordsPerMinute
        self.matchedWordCount = matchedWordCount
        self.totalWordCount = totalWordCount
        self.summary = summary
    }
}

public struct TextRhythmSpeechEvaluator: Sendable {
    public var targetWordsPerMinuteRange: ClosedRange<Double>
    public var rhythmToleranceSeconds: TimeInterval
    public var minimumSpeechConfidence: Double

    public init(
        targetWordsPerMinuteRange: ClosedRange<Double> = 95...155,
        rhythmToleranceSeconds: TimeInterval = 0.18,
        minimumSpeechConfidence: Double = 0.55
    ) {
        self.targetWordsPerMinuteRange = targetWordsPerMinuteRange
        self.rhythmToleranceSeconds = rhythmToleranceSeconds
        self.minimumSpeechConfidence = minimumSpeechConfidence
    }

    public func evaluate(spokenTokens: [SpokenToken], against plan: TextRhythmSpeechPlan) -> TextRhythmSpeechEvaluation {
        let expectedTokens = plan.cues.map(\.token)
        let validTokens = spokenTokens.filter { $0.confidence >= minimumSpeechConfidence }
        let matchedWordCount = zip(expectedTokens, validTokens).filter { expected, spoken in
            Self.normalized(expected) == Self.normalized(spoken.token)
        }.count

        guard !expectedTokens.isEmpty else {
            return TextRhythmSpeechEvaluation(
                clarityScore: 0,
                rateScore: 0,
                rhythmScore: 0,
                completionScore: 0,
                overallPracticeScore: 0,
                wordsPerMinute: 0,
                matchedWordCount: 0,
                totalWordCount: 0,
                summary: "No text prompt is configured."
            )
        }

        let completionScore = Double(min(validTokens.count, expectedTokens.count)) / Double(expectedTokens.count)
        let clarityScore = Double(matchedWordCount) / Double(expectedTokens.count)
        let duration = max((validTokens.last?.startTime ?? 0) + (validTokens.last?.duration ?? 0), 1)
        let wordsPerMinute = Double(validTokens.count) / duration * 60
        let rateScore = Self.scoreRate(wordsPerMinute, targetRange: targetWordsPerMinuteRange)
        let rhythmScore = Self.scoreRhythm(validTokens: validTokens, cues: plan.cues, tolerance: rhythmToleranceSeconds)
        let overallPracticeScore = 0.34 * clarityScore + 0.22 * rateScore + 0.22 * rhythmScore + 0.22 * completionScore
        let summary = overallPracticeScore >= 0.78
            ? "Strong practice attempt. Try turning the rhythm guide off and compare whether clarity and rate remain stable."
            : "Keep practicing with the rhythm guide, then retest without the guide to measure transfer."

        return TextRhythmSpeechEvaluation(
            clarityScore: clarityScore,
            rateScore: rateScore,
            rhythmScore: rhythmScore,
            completionScore: completionScore,
            overallPracticeScore: overallPracticeScore,
            wordsPerMinute: wordsPerMinute,
            matchedWordCount: matchedWordCount,
            totalWordCount: expectedTokens.count,
            summary: summary
        )
    }

    private static func normalized(_ token: String) -> String {
        token
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "'" }
    }

    private static func scoreRate(_ wordsPerMinute: Double, targetRange: ClosedRange<Double>) -> Double {
        if targetRange.contains(wordsPerMinute) {
            return 1
        }

        let nearest = wordsPerMinute < targetRange.lowerBound ? targetRange.lowerBound : targetRange.upperBound
        let distance = abs(wordsPerMinute - nearest)
        return max(0, 1 - distance / 80)
    }

    private static func scoreRhythm(validTokens: [SpokenToken], cues: [RhythmCue], tolerance: TimeInterval) -> Double {
        let pairs = zip(validTokens, cues)
        var count = 0
        var accumulatedScore = 0.0

        for (spoken, cue) in pairs {
            count += 1
            let offset = abs(spoken.startTime - cue.startTime)
            accumulatedScore += max(0, 1 - offset / tolerance)
        }

        return count == 0 ? 0 : accumulatedScore / Double(count)
    }
}

public enum ExperimentalFeatureCatalog {
    public static let singingSupportLab = ExperimentalFeature(
        id: "singing-support-lab",
        title: "Singing Support Lab",
        subtitle: "Experimental singing tasks for regulation, communication practice, and gentle voice/breath awareness.",
        status: .prototype,
        safetyNotice: "Experimental only. This is not a cure, diagnosis, medical device, or replacement for professional care. Stop if singing causes distress, dizziness, pain, panic, sensory overload, or breathing difficulty.",
        intendedUse: [
            "Gentle self-practice or caregiver-supported singing routines.",
            "Short call-and-response vocal imitation sessions.",
            "Tracking practice signals such as completion, pitch closeness, timing consistency, mood, and breath comfort.",
            "Future research workflows with clinician or music therapist review."
        ],
        notIntendedUse: [
            "Curing autism or any disease.",
            "Replacing speech therapy, occupational therapy, psychotherapy, pulmonary rehabilitation, neurology care, or music therapy.",
            "Diagnosing developmental, psychiatric, respiratory, or neurological conditions.",
            "Forcing eye contact, speech, singing, or social behavior."
        ],
        protocolSteps: [
            ExperimentalProtocolStep(
                id: "consent",
                title: "Consent and comfort check",
                instruction: "Confirm the user wants to try a short singing-support session and can stop anytime.",
                targetMetric: "consentConfirmed"
            ),
            ExperimentalProtocolStep(
                id: "baseline",
                title: "Pre-session check-in",
                instruction: "Record mood, breath comfort, and sensory comfort before singing.",
                targetMetric: "preSessionSelfReport",
                durationSeconds: 20
            ),
            ExperimentalProtocolStep(
                id: "hum",
                title: "Gentle hum",
                instruction: "Hum a comfortable pitch softly for a few seconds without strain.",
                targetMetric: "vocalizationDuration",
                durationSeconds: 20
            ),
            ExperimentalProtocolStep(
                id: "listen",
                title: "Listen to target",
                instruction: "Play one short syllable or phrase target with a predictable rhythm.",
                targetMetric: "targetPlayed",
                durationSeconds: 15
            ),
            ExperimentalProtocolStep(
                id: "respond",
                title: "Call-and-response",
                instruction: "Invite the user to vocalize, sing, hum, or skip the response.",
                targetMetric: "responseAttempted",
                durationSeconds: 60
            ),
            ExperimentalProtocolStep(
                id: "feedback",
                title: "Non-judgmental feedback",
                instruction: "Show pitch closeness, timing consistency, completed/skipped state, and confidence.",
                targetMetric: "practiceFeedback",
                durationSeconds: 30
            ),
            ExperimentalProtocolStep(
                id: "post",
                title: "Post-session check-in",
                instruction: "Record mood, breath comfort, and sensory comfort after the session.",
                targetMetric: "postSessionSelfReport",
                durationSeconds: 20
            )
        ],
        trackedMetrics: [
            "sessionCompleted",
            "userStoppedOrSkipped",
            "pitchCloseness",
            "timingConsistency",
            "vocalizationDuration",
            "preMood",
            "postMood",
            "preBreathComfort",
            "postBreathComfort",
            "sensoryComfort"
        ],
        evidenceReferences: [
            ExperimentalEvidenceReference(
                id: "cochrane-autism-music-therapy",
                title: "Music therapy for autistic people",
                domain: .autismCommunication,
                finding: "Moderate-certainty evidence supports global improvement and quality of life, but communication outcomes remain uncertain.",
                appUse: "Use supportive practice language and avoid promises about autism improvement.",
                sourceURL: URL(string: "https://www.cochrane.org/evidence/CD004381_music-therapy-autistic-people")!
            ),
            ExperimentalEvidenceReference(
                id: "ammt-autism-2022",
                title: "Auditory-motor mapping training for minimally verbal children with autism",
                domain: .auditoryMotorMapping,
                finding: "Intonation-based speech work uses structured listen-imitate vocal mapping.",
                appUse: "Model short call-and-response exercises with pitch and timing tracking.",
                sourceURL: URL(string: "https://pubmed.ncbi.nlm.nih.gov/35754007/")!
            ),
            ExperimentalEvidenceReference(
                id: "aphasia-mit-meta-analysis",
                title: "Melodic Intonation Therapy for aphasia",
                domain: .aphasiaRehabilitation,
                finding: "Melody and rhythmic pacing are studied in post-stroke aphasia rehabilitation.",
                appUse: "Keep aphasia-facing workflows clinician-supervised in future versions.",
                sourceURL: URL(string: "https://pubmed.ncbi.nlm.nih.gov/35918503/")!
            ),
            ExperimentalEvidenceReference(
                id: "cochrane-copd-singing",
                title: "Singing for adults with COPD",
                domain: .respiratoryHealth,
                finding: "Singing may resemble breathing exercise, but stronger trials and longer follow-up are needed.",
                appUse: "Offer only gentle breath comfort check-ins, not pulmonary claims.",
                sourceURL: URL(string: "https://www.cochrane.org/evidence/CD012296_singing-copd")!
            ),
            ExperimentalEvidenceReference(
                id: "parkinson-singing-review",
                title: "Singing interventions for people living with Parkinson's",
                domain: .parkinsonVoice,
                finding: "Evidence is mixed, with possible indications for some vocal loudness outcomes.",
                appUse: "Future voice-practice features should measure loudness and phrase duration, not only pitch.",
                sourceURL: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC12645629/")!
            )
        ]
    )

    public static let singToDismissAlarm = ExperimentalFeature(
        id: "sing-to-dismiss-alarm",
        title: "Sing-to-Dismiss Alarm",
        subtitle: "A wake-up challenge that asks the user to sing a whole song before Shenghai marks the alarm resolved.",
        status: .concept,
        safetyNotice: "Experimental only. Shenghai can schedule an alert and run the singing challenge after the app opens, but it cannot guarantee an alarm keeps ringing, records, or remains impossible to stop while the app is closed, locked, powered off, muted, or blocked by system settings.",
        intendedUse: [
            "Motivational wake-up practice for users who want singing to be part of their morning routine.",
            "A full-song pitch and coverage challenge inside Shenghai before the app-level alarm state is marked resolved.",
            "Future AlarmKit exploration on newer iOS versions where Apple permits more alarm-like presentations."
        ],
        notIntendedUse: [
            "Life-critical alarms, medication reminders, safety reminders, or emergency wake-up use.",
            "Preventing the user from silencing the device, powering off the device, disabling notifications, or using system-level dismissal controls.",
            "Continuous background microphone listening while the app is closed.",
            "Punitive practice, sleep deprivation, or forcing singing when the user feels unwell."
        ],
        protocolSteps: [
            ExperimentalProtocolStep(
                id: "schedule",
                title: "Schedule wake-up challenge",
                instruction: "Choose a wake time, song template, and difficulty threshold.",
                targetMetric: "alarmScheduled"
            ),
            ExperimentalProtocolStep(
                id: "notify",
                title: "Receive alert",
                instruction: "Use a system notification now; evaluate AlarmKit later for iOS versions that support it.",
                targetMetric: "alarmAlertDelivered"
            ),
            ExperimentalProtocolStep(
                id: "open",
                title: "Open Shenghai challenge",
                instruction: "The user opens Shenghai from the alert and starts the singing challenge.",
                targetMetric: "challengeStarted"
            ),
            ExperimentalProtocolStep(
                id: "sing",
                title: "Sing the whole song",
                instruction: "Sing the selected song while Shenghai tracks note coverage and pitch closeness.",
                targetMetric: "songCoverage"
            ),
            ExperimentalProtocolStep(
                id: "unlock",
                title: "Unlock app-level dismissal",
                instruction: "Mark the alarm resolved only when the sung performance reaches the configured coverage and pitch thresholds.",
                targetMetric: "dismissalUnlocked"
            ),
            ExperimentalProtocolStep(
                id: "bypass",
                title: "Emergency bypass",
                instruction: "Keep a deliberate bypass path for safety, accessibility, illness, and shared-device situations.",
                targetMetric: "emergencyBypassUsed"
            )
        ],
        trackedMetrics: [
            "alarmScheduled",
            "alarmAlertDelivered",
            "challengeStarted",
            "songCoverage",
            "inTuneRatio",
            "attemptCount",
            "dismissalUnlocked",
            "emergencyBypassUsed"
        ],
        evidenceReferences: []
    )

    public static let textRhythmSpeechLab = ExperimentalFeature(
        id: "text-rhythm-speech-lab",
        title: "Text Rhythm Speech Lab",
        subtitle: "Turn legally usable paragraphs into rhythm-guided chanting or speech practice, then compare clarity, rate, rhythm, and completion with the guide on or off.",
        status: .concept,
        safetyNotice: "Experimental only. This is speech and rhythm practice, not a cure, diagnosis, medical device, or replacement for a speech-language pathologist, music therapist, physician, psychologist, or other professional care.",
        intendedUse: [
            "Import public-domain, licensed, or user-owned text for rhythm-guided speech practice.",
            "Practice paragraphs by category, including fiction, news, science, poem, or random prompts.",
            "Measure practice signals such as clarity proxy, speaking rate, rhythm alignment, completion, and guide-off transfer.",
            "Support future speech-language or music-therapy research workflows with professional review."
        ],
        notIntendedUse: [
            "Claiming that a user is cured of autism, aphasia, stuttering, dysarthria, or any disease.",
            "Replacing speech therapy, language therapy, occupational therapy, psychotherapy, medical treatment, or music therapy.",
            "Using copyrighted articles, books, lyrics, or news text without permission.",
            "Forcing speech, singing, reading aloud, social behavior, or eye contact."
        ],
        protocolSteps: [
            ExperimentalProtocolStep(
                id: "rights",
                title: "Confirm text rights",
                instruction: "Use only public-domain, licensed, or user-owned text.",
                targetMetric: "rightsConfirmed"
            ),
            ExperimentalProtocolStep(
                id: "category",
                title: "Choose category",
                instruction: "Pick fiction, news, science, poem, or random to shape the reading style.",
                targetMetric: "promptCategory"
            ),
            ExperimentalProtocolStep(
                id: "rhythm",
                title: "Generate rhythm guide",
                instruction: "Convert words into beats with strong-beat accents and optional melodic chanting.",
                targetMetric: "rhythmGuideGenerated"
            ),
            ExperimentalProtocolStep(
                id: "guided",
                title: "Practice with guide",
                instruction: "Speak, chant, hum, or sing the paragraph while following the rhythm.",
                targetMetric: "guidedAttemptCompleted"
            ),
            ExperimentalProtocolStep(
                id: "unguided",
                title: "Retest without guide",
                instruction: "Turn the guide off and compare whether clarity, rate, and rhythm remain stable.",
                targetMetric: "guideOffTransfer"
            ),
            ExperimentalProtocolStep(
                id: "review",
                title: "Review scores",
                instruction: "Show clarity, rate, rhythm alignment, completion, and trend over time.",
                targetMetric: "practiceFeedback"
            )
        ],
        trackedMetrics: [
            "clarityScore",
            "wordsPerMinute",
            "rateScore",
            "rhythmAlignment",
            "completionScore",
            "guideOffTransfer",
            "category",
            "userStoppedOrSkipped"
        ],
        evidenceReferences: [
            ExperimentalEvidenceReference(
                id: "mit-meta-analysis-2022",
                title: "Melodic Intonation Therapy for aphasia: multi-level meta-analysis",
                domain: .aphasiaRehabilitation,
                finding: "MIT research studies speech, rhythm, intonation, and formulaic language, but transfer and generalization should be interpreted cautiously.",
                appUse: "Treat rhythm-guided paragraph reading as practice tracking, not proof of clinical recovery.",
                sourceURL: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC9804200/")!
            ),
            ExperimentalEvidenceReference(
                id: "rhythm-disordered-speech-entrainment",
                title: "Rhythm as a Coordinating Device: Entrainment With Disordered Speech",
                domain: .speechRhythmAndProsody,
                finding: "External rhythm can coordinate timing in speech tasks, but individual response varies.",
                appUse: "Offer rhythm scaffolding and guide-off transfer tests instead of a single pass/fail label.",
                sourceURL: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC4084711/")!
            ),
            ExperimentalEvidenceReference(
                id: "speech-envelope-entrainment",
                title: "Speech intelligibility predicted from neural entrainment of the speech envelope",
                domain: .speechRhythmAndProsody,
                finding: "Speech intelligibility relates to temporal envelope tracking in perception research.",
                appUse: "Use rhythm and rate metrics as speech-practice signals while avoiding diagnostic claims.",
                sourceURL: URL(string: "https://pubmed.ncbi.nlm.nih.gov/29464412/")!
            )
        ]
    )

    public static let all: [ExperimentalFeature] = [
        singingSupportLab,
        singToDismissAlarm,
        textRhythmSpeechLab
    ]

    public static func makeSingingSupportSessionPlan(comfortLevel: String = "low") -> SingingSupportSessionPlan {
        SingingSupportSessionPlan(
            featureID: singingSupportLab.id,
            protocolName: "Gentle Call-and-Response",
            comfortLevel: comfortLevel,
            estimatedDurationSeconds: singingSupportLab.protocolSteps.compactMap(\.durationSeconds).reduce(0, +),
            steps: singingSupportLab.protocolSteps,
            requiredConsentPrompts: [
                "I understand this is experimental and not medical treatment.",
                "I can stop or skip any step.",
                "I will stop if I feel distress, dizziness, pain, panic, sensory overload, or breathing difficulty."
            ]
        )
    }

    public static func makeSingToDismissAlarmPlan(
        scheduledHour: Int = 7,
        scheduledMinute: Int = 30,
        challengeTargetCoverageRatio: Double = 0.92,
        requiredInTuneRatio: Double = 0.72
    ) -> SingToDismissAlarmPlan {
        SingToDismissAlarmPlan(
            featureID: singToDismissAlarm.id,
            alarmName: "Morning Singing Alarm",
            songTitle: "Happy Birthday",
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            challengeTargetCoverageRatio: challengeTargetCoverageRatio,
            requiredInTuneRatio: requiredInTuneRatio,
            minimumConfidence: 0.58,
            pitchToleranceCents: 80,
            platformLimitation: "On iOS 17/macOS 14, Shenghai can use notifications and in-app pitch tracking, but cannot force microphone tracking or unstoppable ringing while the app is closed or the screen is off.",
            dismissalPolicy: "The app-level alarm is resolved only after the user covers the full song and reaches the configured in-tune ratio. A safety bypass remains available.",
            targetTimeline: happyBirthdayTargetTimeline(),
            requiredConsentPrompts: [
                "I understand this is a motivational challenge, not a life-critical alarm.",
                "I understand the system alert can still be affected by notification, Focus, mute, battery, and OS settings.",
                "I can use the emergency bypass if singing is unsafe, uncomfortable, or impossible."
            ]
        )
    }

    private static func happyBirthdayTargetTimeline() -> [TargetPitchPoint] {
        let notes: [(midi: Int, duration: TimeInterval)] = [
            (60, 0.38), (60, 0.38), (62, 0.72), (60, 0.72), (65, 0.72), (64, 1.10),
            (60, 0.38), (60, 0.38), (62, 0.72), (60, 0.72), (67, 0.72), (65, 1.10),
            (60, 0.38), (60, 0.38), (72, 0.72), (69, 0.72), (65, 0.72), (64, 0.72), (62, 1.10),
            (70, 0.38), (70, 0.38), (69, 0.72), (65, 0.72), (67, 0.72), (65, 1.25)
        ]

        var time: TimeInterval = 0
        return notes.enumerated().map { index, note in
            defer { time += note.duration }
            return TargetPitchPoint(
                time: time,
                midi: note.midi,
                duration: note.duration,
                partID: "happy-birthday",
                measureNumber: String(index / 4 + 1),
                noteID: "happy-birthday-\(index + 1)",
                startTick: Int((time * 960).rounded()),
                durationTick: Int((note.duration * 960).rounded())
            )
        }
    }

    public static func makeTextRhythmSpeechPlan(
        category: TextPromptCategory = .science,
        tempoBPM: Int = 96,
        rhythmEnabled: Bool = true
    ) -> TextRhythmSpeechPlan {
        let prompt = sampleTextRhythmPrompt(category: category)
        let secondsPerBeat = 60.0 / Double(max(tempoBPM, 40))
        let tokens = prompt.text.split(separator: " ").map(String.init)
        let cues = tokens.enumerated().map { index, token in
            RhythmCue(
                id: "cue-\(index + 1)",
                token: token,
                beatIndex: index,
                startTime: Double(index) * secondsPerBeat,
                duration: secondsPerBeat,
                isStrongBeat: index.isMultiple(of: 4)
            )
        }

        return TextRhythmSpeechPlan(
            featureID: textRhythmSpeechLab.id,
            prompt: prompt,
            tempoBPM: tempoBPM,
            rhythmEnabled: rhythmEnabled,
            cues: cues,
            trackedMetrics: textRhythmSpeechLab.trackedMetrics,
            requiredConsentPrompts: [
                "I understand this is experimental practice feedback, not a cure or diagnosis.",
                "I have permission to use this text.",
                "I can stop, skip, or turn off the rhythm guide at any time."
            ]
        )
    }

    private static func sampleTextRhythmPrompt(category: TextPromptCategory) -> TextRhythmPrompt {
        switch category {
        case .fiction:
            return TextRhythmPrompt(
                id: "sample-fiction",
                title: "A Clear Morning",
                category: .fiction,
                text: "The morning light crossed the quiet room and made every small sound feel gentle.",
                rightsNote: "Original Shenghai sample text."
            )
        case .news:
            return TextRhythmPrompt(
                id: "sample-news",
                title: "Local Practice Notice",
                category: .news,
                text: "The choir will meet tonight to rehearse entrances dynamics and final consonants.",
                rightsNote: "Original Shenghai sample text."
            )
        case .science:
            return TextRhythmPrompt(
                id: "sample-science",
                title: "Sound and Motion",
                category: .science,
                text: "A steady rhythm can help speech movements become easier to plan and repeat.",
                rightsNote: "Original Shenghai sample text."
            )
        case .poem:
            return TextRhythmPrompt(
                id: "sample-poem",
                title: "Small Wave",
                category: .poem,
                text: "Voice rises softly then returns like water resting after song.",
                rightsNote: "Original Shenghai sample text."
            )
        case .random:
            return TextRhythmPrompt(
                id: "sample-random",
                title: "Warm Up",
                category: .random,
                text: "Read slowly breathe gently follow the pulse then speak freely again.",
                rightsNote: "Original Shenghai sample text."
            )
        }
    }
}
