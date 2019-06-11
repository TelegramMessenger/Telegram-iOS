import Foundation
import SwiftSignalKit

final class MediaPlaybackBuffers {
    let audioBuffer: MediaTrackFrameBuffer?
    let videoBuffer: MediaTrackFrameBuffer?
    
    init(audioBuffer: MediaTrackFrameBuffer?, videoBuffer: MediaTrackFrameBuffer?) {
        self.audioBuffer = audioBuffer
        self.videoBuffer = videoBuffer
    }
}
