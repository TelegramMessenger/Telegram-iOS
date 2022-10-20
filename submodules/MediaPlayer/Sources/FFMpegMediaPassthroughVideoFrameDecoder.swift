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
        
        let bytes = malloc(Int(frame.packet.size))!
        memcpy(bytes, frame.packet.data, Int(frame.packet.size))
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: bytes, blockLength: Int(frame.packet.size), blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: Int(frame.packet.size), flags: 0, blockBufferOut: &blockBuffer) == noErr else {
            free(bytes)
            return nil
        }
        
        var timingInfo = CMSampleTimingInfo(duration: frame.duration, presentationTimeStamp: frame.pts, decodeTimeStamp: frame.dts)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = Int(frame.packet.size)
        guard CMSampleBufferCreate(allocator: nil, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self.videoFormat, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        
        let resetDecoder = self.resetDecoderOnNextFrame
        if self.resetDecoderOnNextFrame {
            self.resetDecoderOnNextFrame = false
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, createIfNecessary: true)! as NSArray
            let dict = attachments[0] as! NSMutableDictionary
            
            dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding as NSString as String)
        }
        
        return MediaTrackFrame(type: .video, sampleBuffer: sampleBuffer!, resetDecoder: resetDecoder, decoded: false, rotationAngle: self.rotationAngle)
    }
    
    func takeQueuedFrame() -> MediaTrackFrame? {
        return nil
    }
    
    func takeRemainingFrame() -> MediaTrackFrame? {
        return nil
    }
    
    func reset() {
        self.resetDecoderOnNextFrame = true
    }
}
