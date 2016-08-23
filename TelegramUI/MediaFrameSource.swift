import Foundation
import SwiftSignalKit
import CoreMedia

enum MediaTrackEvent {
    case frames([MediaTrackDecodableFrame])
}

struct MediaFrameSourceSeekResult {
    let buffers: MediaPlaybackBuffers
    let timestamp: CMTime
}

enum MediaFrameSourceSeekError {
    case generic
}

protocol MediaFrameSource {
    func addEventSink(_ f: @escaping (MediaTrackEvent) -> Void) -> Int
    func removeEventSink(_ index: Int)
    func generateFrames(until timestamp: Double)
    func seek(timestamp: Double) -> Signal<MediaFrameSourceSeekResult, MediaFrameSourceSeekError>
}
