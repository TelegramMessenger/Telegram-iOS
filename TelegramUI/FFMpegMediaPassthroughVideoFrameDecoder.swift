import CoreMedia

final class FFMpegMediaPassthroughVideoFrameDecoder: MediaTrackFrameDecoder {
    private let videoFormat: CMVideoFormatDescription
    private let rotationAngle: Double
    private var resetDecoderOnNextFrame = true
    
    init(videoFormat: CMVideoFormatDescription, rotationAngle: Double) {
        self.videoFormat = videoFormat
        self.rotationAngle = rotationAngle
    }
    
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame? {
        var blockBuffer: CMBlockBuffer?
        
        let bytes = malloc(Int(frame.packet.packet.size))!
        memcpy(bytes, frame.packet.packet.data, Int(frame.packet.packet.size))
        guard CMBlockBufferCreateWithMemoryBlock(nil, bytes, Int(frame.packet.packet.size), nil, nil, 0, Int(frame.packet.packet.size), 0, &blockBuffer) == noErr else {
            free(bytes)
            return nil
        }
        
        var timingInfo = CMSampleTimingInfo(duration: frame.duration, presentationTimeStamp: frame.pts, decodeTimeStamp: frame.dts)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = Int(frame.packet.packet.size)
        guard CMSampleBufferCreate(nil, blockBuffer, true, nil, nil, self.videoFormat, 1, 1, &timingInfo, 1, &sampleSize, &sampleBuffer) == noErr else {
            return nil
        }
        
        let resetDecoder = self.resetDecoderOnNextFrame
        if self.resetDecoderOnNextFrame {
            self.resetDecoderOnNextFrame = false
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, true)! as NSArray
            let dict = attachments[0] as! NSMutableDictionary
            
            dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding as NSString as String)
        }
        
        return MediaTrackFrame(type: .video, sampleBuffer: sampleBuffer!, resetDecoder: resetDecoder, decoded: false, rotationAngle: self.rotationAngle)
    }
    
    func takeRemainingFrame() -> MediaTrackFrame? {
        return nil
    }
    
    func reset() {
        self.resetDecoderOnNextFrame = true
    }
}
