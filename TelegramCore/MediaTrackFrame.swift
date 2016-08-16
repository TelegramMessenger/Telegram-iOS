import Foundation
import CoreMedia

final class MediaTrackFrame {
    let type: MediaTrackFrameType
    let sampleBuffer: CMSampleBuffer
    let resetDecoder: Bool
    
    init(type: MediaTrackFrameType, sampleBuffer: CMSampleBuffer, resetDecoder: Bool) {
        self.type = type
        self.sampleBuffer = sampleBuffer
        self.resetDecoder = resetDecoder
    }
    
    var position: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self.sampleBuffer)
    }
    
    var duration: CMTime {
        return CMSampleBufferGetDuration(self.sampleBuffer)
    }
}
