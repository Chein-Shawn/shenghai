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

    public static let all: [ExperimentalFeature] = [
        singingSupportLab
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
}
