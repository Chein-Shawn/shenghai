import Foundation

public struct YINPitchTracker: PitchTracking {
    public var frameSize: Int
    public var hopSize: Int
    public var minimumFrequency: Double
    public var maximumFrequency: Double
    public var threshold: Double
    public var minimumRMS: Float

    public init(
        frameSize: Int = 2048,
        hopSize: Int = 512,
        minimumFrequency: Double = 70,
        maximumFrequency: Double = 1_100,
        threshold: Double = 0.15,
        minimumRMS: Float = 0.01
    ) {
        self.frameSize = max(256, frameSize)
        self.hopSize = max(128, hopSize)
        self.minimumFrequency = minimumFrequency
        self.maximumFrequency = maximumFrequency
        self.threshold = threshold
        self.minimumRMS = minimumRMS
    }

    public func trackPitch(samples: [Float], sampleRate: Double) async throws -> [PitchSample] {
        guard sampleRate > 0, samples.count >= frameSize else {
            return []
        }

        var output: [PitchSample] = []
        var frameStart = 0

        while frameStart + frameSize <= samples.count {
            let frame = Array(samples[frameStart..<frameStart + frameSize])
            let time = Double(frameStart) / sampleRate
            output.append(analyzeFrame(frame, sampleRate: sampleRate, time: time))
            frameStart += hopSize
        }

        return output
    }

    private func analyzeFrame(_ frame: [Float], sampleRate: Double, time: TimeInterval) -> PitchSample {
        guard rms(frame) >= minimumRMS else {
            return PitchSample(time: time, frequencyHz: nil, confidence: 0)
        }

        let minimumTau = max(2, Int(sampleRate / maximumFrequency))
        let maximumTau = min(frame.count / 2, Int(sampleRate / minimumFrequency))
        guard minimumTau < maximumTau else {
            return PitchSample(time: time, frequencyHz: nil, confidence: 0)
        }

        var difference = Array(repeating: 0.0, count: maximumTau + 1)
        for tau in 1...maximumTau {
            var sum = 0.0
            let comparisonCount = frame.count - tau
            for index in 0..<comparisonCount {
                let delta = Double(frame[index] - frame[index + tau])
                sum += delta * delta
            }
            difference[tau] = sum
        }

        var cumulativeMean = Array(repeating: 1.0, count: maximumTau + 1)
        var runningSum = 0.0
        for tau in 1...maximumTau {
            runningSum += difference[tau]
            cumulativeMean[tau] = runningSum == 0 ? 1 : difference[tau] * Double(tau) / runningSum
        }

        var chosenTau: Int?
        var tau = minimumTau
        while tau <= maximumTau {
            if cumulativeMean[tau] < threshold {
                while tau + 1 <= maximumTau, cumulativeMean[tau + 1] < cumulativeMean[tau] {
                    tau += 1
                }
                chosenTau = tau
                break
            }
            tau += 1
        }

        if chosenTau == nil {
            chosenTau = (minimumTau...maximumTau).min { cumulativeMean[$0] < cumulativeMean[$1] }
        }

        guard let tauValue = chosenTau else {
            return PitchSample(time: time, frequencyHz: nil, confidence: 0)
        }

        let refinedTau = parabolicTau(around: tauValue, values: cumulativeMean)
        guard refinedTau > 0 else {
            return PitchSample(time: time, frequencyHz: nil, confidence: 0)
        }

        let frequency = sampleRate / refinedTau
        guard frequency >= minimumFrequency, frequency <= maximumFrequency else {
            return PitchSample(time: time, frequencyHz: nil, confidence: 0)
        }

        let confidence = max(0, min(1, 1 - cumulativeMean[tauValue]))
        return PitchSample(time: time, frequencyHz: frequency, confidence: confidence)
    }

    private func rms(_ frame: [Float]) -> Float {
        guard !frame.isEmpty else {
            return 0
        }

        let sum = frame.reduce(Float.zero) { partial, sample in
            partial + sample * sample
        }
        return sqrt(sum / Float(frame.count))
    }

    private func parabolicTau(around tau: Int, values: [Double]) -> Double {
        guard tau > 0, tau + 1 < values.count else {
            return Double(tau)
        }

        let left = values[tau - 1]
        let center = values[tau]
        let right = values[tau + 1]
        let denominator = left - 2 * center + right
        guard abs(denominator) > .ulpOfOne else {
            return Double(tau)
        }

        return Double(tau) + 0.5 * (left - right) / denominator
    }
}
