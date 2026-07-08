import AVFoundation
import Foundation
import Combine
#if canImport(VocalDiveCore)
import VocalDiveCore
#endif

@MainActor
final class LivePitchCaptureService: ObservableObject {
    private let engine = AVAudioEngine()
    private let tracker = YINPitchTracker(frameSize: 2048, hopSize: 512, minimumFrequency: 70, maximumFrequency: 1_100)
    private let smoother = MedianPitchContourSmoother(windowSize: 5, minimumConfidence: 0.45)

    @Published var isRunning = false
    @Published var samples: [PitchSample] = []
    @Published var errorMessage: String?

    var latestSample: PitchSample? {
        samples.last
    }

    func start() {
        guard !isRunning else {
            return
        }

        Task {
            do {
                try await requestPermission()
                try startEngine()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                stop()
            }
        }
    }

    func stop() {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        isRunning = false
    }

    private func requestPermission() async throws {
        #if os(iOS)
        let granted = await AVAudioApplication.requestRecordPermission()
        if !granted {
            throw LivePitchCaptureError.microphonePermissionDenied
        }
        #else
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            throw LivePitchCaptureError.microphonePermissionDenied
        }
        #endif
    }

    private func startEngine() throws {
        samples = []

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else {
                return
            }

            let sampleRate = format.sampleRate
            let frameCount = Int(buffer.frameLength)
            guard let channel = buffer.floatChannelData?.pointee, frameCount > 0 else {
                return
            }

            let monoSamples = Array(UnsafeBufferPointer(start: channel, count: frameCount))
            Task {
                let pitchSamples = try? await self.tracker.trackPitch(samples: monoSamples, sampleRate: sampleRate)
                await MainActor.run {
                    guard let pitchSamples, !pitchSamples.isEmpty else {
                        return
                    }
                    self.samples.append(contentsOf: self.smoother.smooth(pitchSamples))
                    if self.samples.count > 240 {
                        self.samples.removeFirst(self.samples.count - 240)
                    }
                }
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }
}

enum LivePitchCaptureError: LocalizedError {
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return L10n.tr("Microphone permission is required for live pitch tracking.")
        }
    }
}
