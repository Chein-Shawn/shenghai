import AVFoundation
import Foundation

@MainActor
final class MIDIPlaybackService {
    private var player: AVMIDIPlayer?

    func play(data: Data, completion: @escaping @MainActor () -> Void) throws {
        stop()
        let player = try AVMIDIPlayer(data: data, soundBankURL: nil)
        player.prepareToPlay()
        self.player = player
        player.play {
            Task { @MainActor in
                completion()
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
