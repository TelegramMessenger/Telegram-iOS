import TelegramUIPrivateModule
import CoreMedia
import Accelerate

private let bufferCount = 32

final class FFMpegMediaVideoFrameDecoder: MediaTrackFrameDecoder {
    private let codecContext: UnsafeMutablePointer<AVCodecContext>
    
    private let videoFrame: UnsafeMutablePointer<AVFrame>
    private var resetDecoderOnNextFrame = true
    
    private var pixelBufferPool: CVPixelBufferPool?
    
    private var delayedFrames: [MediaTrackFrame] = []
    
    init(codecContext: UnsafeMutablePointer<AVCodecContext>) {
        self.codecContext = codecContext
        self.videoFrame = av_frame_alloc()
        
        /*var sourcePixelBufferOptions: [String: Any] = [:]
        sourcePixelBufferOptions[kCVPixelBufferPixelFormatTypeKey as String] = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange as NSNumber
        
        sourcePixelBufferOptions[kCVPixelBufferWidthKey as String] = codecContext.pointee.width as NSNumber
        sourcePixelBufferOptions[kCVPixelBufferHeightKey as String] = codecContext.pointee.height as NSNumber
        sourcePixelBufferOptions[kCVPixelBufferBytesPerRowAlignmentKey as String] = 128 as NSNumber
        sourcePixelBufferOptions[kCVPixelBufferPlaneAlignmentKey as String] = 128 as NSNumber
        
        let ioSurfaceProperties = NSMutableDictionary()
        ioSurfaceProperties["IOSurfaceIsGlobal"] = true as NSNumber
        
        sourcePixelBufferOptions[kCVPixelBufferIOSurfacePropertiesKey as String] = ioSurfaceProperties
        
        var pixelBufferPoolOptions: [String: Any] = [:]
        pixelBufferPoolOptions[kCVPixelBufferPoolMinimumBufferCountKey as String] = bufferCount as NSNumber
        
        var pixelBufferPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, pixelBufferPoolOptions as CFDictionary, sourcePixelBufferOptions as CFDictionary, &pixelBufferPool)
        
        self.pixelBufferPool = pixelBufferPool*/
    }
    
    deinit {
        av_frame_unref(self.videoFrame)
        
        var codecContextRef: UnsafeMutablePointer<AVCodecContext>? = codecContext
        avcodec_free_context(&codecContextRef)
    }
    
    func decodeInternal(frame: MediaTrackDecodableFrame) {
    
    }
    
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame? {
        return self.decode(frame: frame, ptsOffset: nil)
    }
    
    func decode(frame: MediaTrackDecodableFrame, ptsOffset: CMTime?) -> MediaTrackFrame? {
        var status = avcodec_send_packet(self.codecContext, frame.packet)
        if status == 0 {
            status = avcodec_receive_frame(self.codecContext, self.videoFrame)
            if status == 0 {
                var pts = CMTimeMake(self.videoFrame.pointee.pts, frame.pts.timescale)
                if let ptsOffset = ptsOffset {
                    pts = CMTimeAdd(pts, ptsOffset)
                }
                return convertVideoFrame(self.videoFrame, pts: pts, dts: pts, duration: frame.duration)
            }
        }
        
        return nil
    }
    
    func takeRemainingFrame() -> MediaTrackFrame? {
        if !self.delayedFrames.isEmpty {
            var minFrameIndex = 0
            var minPosition = self.delayedFrames[0].position
            for i in 1 ..< self.delayedFrames.count {
                if CMTimeCompare(self.delayedFrames[i].position, minPosition) < 0 {
                    minFrameIndex = i
                    minPosition = self.delayedFrames[i].position
                }
            }
            return self.delayedFrames.remove(at: minFrameIndex)
        } else {
            return nil
        }
    }
    
    private func convertVideoFrame(_ frame: UnsafeMutablePointer<AVFrame>, pts: CMTime, dts: CMTime, duration: CMTime) -> MediaTrackFrame? {
        if frame.pointee.data.0 == nil {
            return nil
        }
        if frame.pointee.linesize.1 != frame.pointee.linesize.2 {
            return nil
        }
        
        var pixelBufferRef: CVPixelBuffer?
        if let pixelBufferPool = self.pixelBufferPool {
            let auxAttributes: [String: Any] = [kCVPixelBufferPoolAllocationThresholdKey as String: bufferCount as NSNumber];
            let err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pixelBufferPool, auxAttributes as CFDictionary, &pixelBufferRef)
            if err == kCVReturnWouldExceedAllocationThreshold {
                print("kCVReturnWouldExceedAllocationThreshold, dropping frame")
                return nil
            }
        } else {
            let ioSurfaceProperties = NSMutableDictionary()
            ioSurfaceProperties["IOSurfaceIsGlobal"] = true as NSNumber
            
            var options: [String: Any] = [kCVPixelBufferBytesPerRowAlignmentKey as String: frame.pointee.linesize.0 as NSNumber]
            if #available(iOSApplicationExtension 9.0, *) {
                options[kCVPixelBufferOpenGLESTextureCacheCompatibilityKey as String] = true as NSNumber
            }
            options[kCVPixelBufferIOSurfacePropertiesKey as String] = ioSurfaceProperties
            
            CVPixelBufferCreate(kCFAllocatorDefault,
                                          Int(frame.pointee.width),
                                          Int(frame.pointee.height),
                                          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                          options as CFDictionary,
                                          &pixelBufferRef)
        }
        
        guard let pixelBuffer = pixelBufferRef else {
            return nil
        }
        
        let srcPlaneSize = Int(frame.pointee.linesize.1) * Int(frame.pointee.height / 2)
        let dstPlaneSize = srcPlaneSize * 2
        
        let dstPlane = malloc(dstPlaneSize)!.assumingMemoryBound(to: UInt8.self)
        defer {
            free(dstPlane)
        }
        
        for i in 0 ..< srcPlaneSize {
            dstPlane[2 * i] = frame.pointee.data.1![i]
            dstPlane[2 * i + 1] = frame.pointee.data.2![i]
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        
        let bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        
        let bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        
        var base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        memcpy(base, frame.pointee.data.0!, bytePerRowY * Int(frame.pointee.height))
        
        base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        memcpy(base, dstPlane, bytesPerRowUV * Int(frame.pointee.height) / 2)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        var formatRef: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatRef)
        
        guard let format = formatRef, formatStatus == 0 else {
            return nil
        }
        
        var timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: pts)
        var sampleBuffer: CMSampleBuffer?
        
        guard CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixelBuffer, format, &timingInfo, &sampleBuffer) == noErr else {
            return nil
        }
        
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, true)! as NSArray
        let dict = attachments[0] as! NSMutableDictionary
        
        let resetDecoder = self.resetDecoderOnNextFrame
        if self.resetDecoderOnNextFrame {
            self.resetDecoderOnNextFrame = false
            //dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding as NSString as String)
        }
        
        dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DisplayImmediately as NSString as String)
        
        let decodedFrame = MediaTrackFrame(type: .video, sampleBuffer: sampleBuffer!, resetDecoder: resetDecoder, decoded: true)
        
        self.delayedFrames.append(decodedFrame)
        
        if self.delayedFrames.count >= 1 {
            var minFrameIndex = 0
            var minPosition = self.delayedFrames[0].position
            for i in 1 ..< self.delayedFrames.count {
                if CMTimeCompare(self.delayedFrames[i].position, minPosition) < 0 {
                    minFrameIndex = i
                    minPosition = self.delayedFrames[i].position
                }
            }
            if minFrameIndex != 0 {
                assert(true)
            }
            return self.delayedFrames.remove(at: minFrameIndex)
        } else {
            return nil
        }
    }
    
    func decodeImage() {

    }
    
    func reset() {
        avcodec_flush_buffers(self.codecContext)
        self.resetDecoderOnNextFrame = true
    }
}
