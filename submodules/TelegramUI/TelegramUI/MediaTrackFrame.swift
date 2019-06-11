import Foundation
import CoreMedia

final class MediaTrackFrame {
    let type: MediaTrackFrameType
    let sampleBuffer: CMSampleBuffer
    let resetDecoder: Bool
    let decoded: Bool
    let rotationAngle: Double
    
    init(type: MediaTrackFrameType, sampleBuffer: CMSampleBuffer, resetDecoder: Bool, decoded: Bool, rotationAngle: Double = 0.0) {
        self.type = type
        self.sampleBuffer = sampleBuffer
        self.resetDecoder = resetDecoder
        self.decoded = decoded
        self.rotationAngle = rotationAngle
    }
    
    var position: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self.sampleBuffer)
    }
    
    var duration: CMTime {
        return CMSampleBufferGetDuration(self.sampleBuffer)
    }
}
