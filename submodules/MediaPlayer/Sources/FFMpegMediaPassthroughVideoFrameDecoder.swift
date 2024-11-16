import CoreMedia

final class FFMpegMediaPassthroughVideoFrameDecoder: MediaTrackFrameDecoder {
    final class VideoFormatData {
        let codecType: CMVideoCodecType
        let width: Int32
        let height: Int32
        let extraData: Data
        
        init(codecType: CMVideoCodecType, width: Int32, height: Int32, extraData: Data) {
            self.codecType = codecType
            self.width = width
            self.height = height
            self.extraData = extraData
        }
    }
    
    private let videoFormatData: VideoFormatData
    private var videoFormat: CMVideoFormatDescription?
    private let rotationAngle: Double
    private var resetDecoderOnNextFrame = true
    
    private var sentFrameQueue: [MediaTrackDecodableFrame] = []
    
    init(videoFormatData: VideoFormatData, rotationAngle: Double) {
        self.videoFormatData = videoFormatData
        self.rotationAngle = rotationAngle
    }
    
    func send(frame: MediaTrackDecodableFrame) -> Bool {
        self.sentFrameQueue.append(frame)
        return true
    }
    
    func decode() -> MediaTrackFrame? {
        guard let frame = self.sentFrameQueue.first else {
            return nil
        }
        self.sentFrameQueue.removeFirst()
        
        if self.videoFormat == nil {
            if self.videoFormatData.codecType == kCMVideoCodecType_MPEG4Video {
                self.videoFormat = FFMpegMediaFrameSourceContextHelpers.createFormatDescriptionFromMpeg4CodecData(UInt32(kCMVideoCodecType_MPEG4Video), self.videoFormatData.width, self.videoFormatData.height, self.videoFormatData.extraData)
            } else if self.videoFormatData.codecType == kCMVideoCodecType_H264 {
                self.videoFormat = FFMpegMediaFrameSourceContextHelpers.createFormatDescriptionFromAVCCodecData(UInt32(kCMVideoCodecType_H264), self.videoFormatData.width, self.videoFormatData.height, self.videoFormatData.extraData)
            } else if self.videoFormatData.codecType == kCMVideoCodecType_HEVC {
                self.videoFormat = FFMpegMediaFrameSourceContextHelpers.createFormatDescriptionFromHEVCCodecData(UInt32(kCMVideoCodecType_HEVC), self.videoFormatData.width, self.videoFormatData.height, self.videoFormatData.extraData)
            } else if self.videoFormatData.codecType == kCMVideoCodecType_AV1 {
                self.videoFormat = FFMpegMediaFrameSourceContextHelpers.createFormatDescriptionFromAV1CodecData(UInt32(kCMVideoCodecType_AV1), self.videoFormatData.width, self.videoFormatData.height, self.videoFormatData.extraData, frameData: frame.copyPacketData())
            }
        }
        
        if self.videoFormat == nil {
            return nil
        }
        
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
    
    func sendEndToDecoder() -> Bool {
        return true
    }
}
