import Foundation
import CoreMedia

public final class MediaTrackFrame {
    public let type: MediaTrackFrameType
    public let sampleBuffer: CMSampleBuffer
    public let resetDecoder: Bool
    public let decoded: Bool
    public let rotationAngle: Double
    
    public init(type: MediaTrackFrameType, sampleBuffer: CMSampleBuffer, resetDecoder: Bool, decoded: Bool, rotationAngle: Double = 0.0) {
        self.type = type
        self.sampleBuffer = sampleBuffer
        self.resetDecoder = resetDecoder
        self.decoded = decoded
        self.rotationAngle = rotationAngle
    }
    
    public var position: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self.sampleBuffer)
    }
    
    public var duration: CMTime {
        return CMSampleBufferGetDuration(self.sampleBuffer)
    }
}
