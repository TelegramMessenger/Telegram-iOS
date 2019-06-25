import Foundation
import SwiftSignalKit
import CoreMedia

public enum MediaTrackEvent {
    case frames([MediaTrackDecodableFrame])
    case endOfStream
}

public final class MediaFrameSourceSeekResult {
    public let buffers: MediaPlaybackBuffers
    public let extraDecodedVideoFrames: [MediaTrackFrame]
    public let timestamp: CMTime
    
    public init(buffers: MediaPlaybackBuffers, extraDecodedVideoFrames: [MediaTrackFrame], timestamp: CMTime) {
        self.buffers = buffers
        self.extraDecodedVideoFrames = extraDecodedVideoFrames
        self.timestamp = timestamp
    }
}

public enum MediaFrameSourceSeekError {
    case generic
}

public protocol MediaFrameSource {
    func addEventSink(_ f: @escaping (MediaTrackEvent) -> Void) -> Int
    func removeEventSink(_ index: Int)
    func generateFrames(until timestamp: Double)
    func seek(timestamp: Double) -> Signal<QueueLocalObject<MediaFrameSourceSeekResult>, MediaFrameSourceSeekError>
}
