import Foundation
import SwiftSignalKit
import UniversalMediaPlayer

// The ChunkMediaPlayerV2 source for the native HLS player: parts go in through `partsPromise`, and the player's seeks
// and positions come out to the playback controller, on the main queue.
final class HLSNativePlayerSource: ChunkMediaPlayerSourceImpl {
    let partsPromise = Promise<ChunkMediaPlayerPartsState>(ChunkMediaPlayerPartsState(duration: nil, content: .parts([])))
    let partsState: Signal<ChunkMediaPlayerPartsState, NoError>
    
    var onSeek: ((Double) -> Void)?
    // Only when the position moved by at least 0.25 s or the playing state changed.
    var onPlaybackState: ((_ position: Double, _ isPlaying: Bool) -> Void)?
    
    private var lastReported: (position: Double, isPlaying: Bool)?
    
    init() {
        self.partsState = self.partsPromise.get()
    }
    
    // The player calls these on the main queue (its parts subscription and its update timer), up to 60 times a second
    // while playing, so a position is deduplicated here and only a report that passes is dispatched. The hop is a real
    // dispatch, not Queue.mainQueue().async (which runs inline on main): the player calls these from inside its own
    // state update, which must not re-enter through a parts change. FIFO keeps seeks and positions in order.
    func seek(id: Int, position: Double) {
        self.lastReported = nil
        DispatchQueue.main.async { [weak self] in
            self?.onSeek?(position)
        }
    }
    
    func updatePlaybackState(seekTimestamp: Double, position: Double, isPlaying: Bool) {
        if let lastReported = self.lastReported, lastReported.isPlaying == isPlaying, abs(lastReported.position - position) < 0.25 {
            return
        }
        self.lastReported = (position, isPlaying)
        DispatchQueue.main.async { [weak self] in
            self?.onPlaybackState?(position, isPlaying)
        }
    }
}
