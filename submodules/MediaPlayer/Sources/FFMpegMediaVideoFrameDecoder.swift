
#if !os(macOS)
import UIKit
#else
import AppKit
#endif
import CoreMedia
import Accelerate
import FFMpegBinding

private let bufferCount = 32



#if os(macOS)
private let deviceColorSpace: CGColorSpace = {
    if #available(OSX 10.11.2, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()
#else
private let deviceColorSpace: CGColorSpace = {
    if #available(iOSApplicationExtension 9.3, iOS 9.3, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()
#endif
public final class FFMpegMediaVideoFrameDecoder: MediaTrackFrameDecoder {
    public enum ReceiveResult {
        case error
        case moreDataNeeded
        case result(MediaTrackFrame)
    }
    
    private let codecContext: FFMpegAVCodecContext
    
    private let videoFrame: FFMpegAVFrame
    private var resetDecoderOnNextFrame = true
    
    private var defaultDuration: CMTime?
    private var defaultTimescale: CMTimeScale?
    
    private var pixelBufferPool: CVPixelBufferPool?
    
    private var delayedFrames: [MediaTrackFrame] = []
    
    private var dstPlane: (UnsafeMutablePointer<UInt8>, Int)?
    
    public init(codecContext: FFMpegAVCodecContext) {
        self.codecContext = codecContext
        self.videoFrame = FFMpegAVFrame()
    }
    
    deinit {
        if let (dstPlane, _) = self.dstPlane {
            free(dstPlane)
        }
    }
    
    func decodeInternal(frame: MediaTrackDecodableFrame) {
    
    }
    
    public func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame? {
        return self.decode(frame: frame, ptsOffset: nil)
    }
    
    public func sendToDecoder(frame: MediaTrackDecodableFrame) -> Bool {
        self.defaultDuration = frame.duration
        self.defaultTimescale = frame.pts.timescale
        
        let status = frame.packet.send(toDecoder: self.codecContext)
        return status == 0
    }
    
    public func sendEndToDecoder() -> Bool {
        return self.codecContext.sendEnd()
    }
    
    public func receiveFromDecoder(ptsOffset: CMTime?) -> ReceiveResult {
        guard let defaultTimescale = self.defaultTimescale, let defaultDuration = self.defaultDuration else {
            return .error
        }
        
        let receiveResult = self.codecContext.receive(into: self.videoFrame)
        switch receiveResult {
        case .success:
            var pts = CMTimeMake(value: self.videoFrame.pts, timescale: defaultTimescale)
            if let ptsOffset = ptsOffset {
                pts = CMTimeAdd(pts, ptsOffset)
            }
            if let convertedFrame = convertVideoFrame(self.videoFrame, pts: pts, dts: pts, duration: self.videoFrame.duration > 0 ? CMTimeMake(value: self.videoFrame.duration, timescale: defaultTimescale) : defaultDuration) {
                return .result(convertedFrame)
            } else {
                return .error
            }
        case .notEnoughData:
            return .moreDataNeeded
        case .error:
            return .error
        @unknown default:
            return .error
        }
    }
    
    public func decode(frame: MediaTrackDecodableFrame, ptsOffset: CMTime?) -> MediaTrackFrame? {
        let status = frame.packet.send(toDecoder: self.codecContext)
        if status == 0 {
            self.defaultDuration = frame.duration
            self.defaultTimescale = frame.pts.timescale
            
            if self.codecContext.receive(into: self.videoFrame) == .success {
                var pts = CMTimeMake(value: self.videoFrame.pts, timescale: frame.pts.timescale)
                if let ptsOffset = ptsOffset {
                    pts = CMTimeAdd(pts, ptsOffset)
                }
                return convertVideoFrame(self.videoFrame, pts: pts, dts: pts, duration: frame.duration)
            }
        }
        
        return nil
    }
    
    public func receiveRemainingFrames(ptsOffset: CMTime?) -> [MediaTrackFrame] {
        guard let defaultTimescale = self.defaultTimescale, let defaultDuration = self.defaultDuration else {
            return []
        }
        
        var result: [MediaTrackFrame] = []
        result.append(contentsOf: self.delayedFrames)
        self.delayedFrames.removeAll()
        
        while true {
            if case .success = self.codecContext.receive(into: self.videoFrame) {
                var pts = CMTimeMake(value: self.videoFrame.pts, timescale: defaultTimescale)
                if let ptsOffset = ptsOffset {
                    pts = CMTimeAdd(pts, ptsOffset)
                }
                if let convertedFrame = convertVideoFrame(self.videoFrame, pts: pts, dts: pts, duration: self.videoFrame.duration > 0 ? CMTimeMake(value: self.videoFrame.duration, timescale: defaultTimescale) : defaultDuration) {
                    result.append(convertedFrame)
                }
            } else {
                break
            }
        }
        return result
    }
    
    public func render(frame: MediaTrackDecodableFrame) -> UIImage? {
        let status = frame.packet.send(toDecoder: self.codecContext)
        if status == 0 {
            if case .success = self.codecContext.receive(into: self.videoFrame) {
                return convertVideoFrameToImage(self.videoFrame)
            }
        }
        
        return nil
    }
    
    public func takeQueuedFrame() -> MediaTrackFrame? {
        return nil
    }
    
    public func takeRemainingFrame() -> MediaTrackFrame? {
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
    
    private func convertVideoFrameToImage(_ frame: FFMpegAVFrame) -> UIImage? {
        var info = vImage_YpCbCrToARGB()
        
        var pixelRange: vImage_YpCbCrPixelRange
        switch frame.colorRange {
        case .full:
            pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 0, CbCr_bias: 128, YpRangeMax: 255, CbCrRangeMax: 255, YpMax: 255, YpMin: 0, CbCrMax: 255, CbCrMin: 0)
        default:
            pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 16, CbCr_bias: 128, YpRangeMax: 235, CbCrRangeMax: 240, YpMax: 255, YpMin: 0, CbCrMax: 255, CbCrMin: 0)
        }
        var result = kvImageNoError
        result = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, &pixelRange, &info, kvImage420Yp8_Cb8_Cr8, kvImageARGB8888, 0)
        if result != kvImageNoError {
            return nil
        }
        
        var srcYp = vImage_Buffer(data: frame.data[0], height: vImagePixelCount(frame.height), width: vImagePixelCount(frame.width), rowBytes: Int(frame.lineSize[0]))
        var srcCb = vImage_Buffer(data: frame.data[1], height: vImagePixelCount(frame.height), width: vImagePixelCount(frame.width / 2), rowBytes: Int(frame.lineSize[1]))
        var srcCr = vImage_Buffer(data: frame.data[2], height: vImagePixelCount(frame.height), width: vImagePixelCount(frame.width / 2), rowBytes: Int(frame.lineSize[2]))
        
        let argbBytesPerRow = (4 * Int(frame.width) + 31) & (~31)
        let argbLength = argbBytesPerRow * Int(frame.height)
        let argb = malloc(argbLength)!
        guard let provider = CGDataProvider(dataInfo: argb, data: argb, size: argbLength, releaseData: { bytes, _, _ in
            free(bytes)
        }) else {
            return nil
        }
        
        var dst = vImage_Buffer(data: argb, height: vImagePixelCount(frame.height), width: vImagePixelCount(frame.width), rowBytes: argbBytesPerRow)
        
        var permuteMap: [UInt8] = [3, 2, 1, 0]
        
        result = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&srcYp, &srcCb, &srcCr, &dst, &info, &permuteMap, 0x00, 0)
        if result != kvImageNoError {
            return nil
        }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let image = CGImage(width: Int(frame.width), height: Int(frame.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: argbBytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        
        return UIImage(cgImage: image, scale: 1.0, orientation: .up)
    }
    
    private func convertVideoFrame(_ frame: FFMpegAVFrame, pts: CMTime, dts: CMTime, duration: CMTime) -> MediaTrackFrame? {
        if frame.data[0] == nil {
            return nil
        }
        if frame.lineSize[1] != frame.lineSize[2] {
            return nil
        }
        
        var pixelBufferRef: CVPixelBuffer?
        
        let pixelFormat: OSType
        switch frame.pixelFormat {
            case .YUV:
                pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            case .YUVA:
                pixelFormat = kCVPixelFormatType_420YpCbCr8VideoRange_8A_TriPlanar
            default:
                pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
        
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
            
            var options: [String: Any] = [kCVPixelBufferBytesPerRowAlignmentKey as String: frame.lineSize[0] as NSNumber]
            options[kCVPixelBufferIOSurfacePropertiesKey as String] = ioSurfaceProperties
  
            CVPixelBufferCreate(kCFAllocatorDefault,
                                          Int(frame.width),
                                          Int(frame.height),
                                          pixelFormat,
                                          options as CFDictionary,
                                          &pixelBufferRef)
        }
                
        guard let pixelBuffer = pixelBufferRef else {
            return nil
        }

        let srcPlaneSize = Int(frame.lineSize[1]) * Int(frame.height / 2)
        let dstPlaneSize = srcPlaneSize * 2

        let dstPlane: UnsafeMutablePointer<UInt8>
        if let (existingDstPlane, existingDstPlaneSize) = self.dstPlane, existingDstPlaneSize == dstPlaneSize {
            dstPlane = existingDstPlane
        } else {
            if let (existingDstPlane, _) = self.dstPlane {
                free(existingDstPlane)
            }
            dstPlane = malloc(dstPlaneSize)!.assumingMemoryBound(to: UInt8.self)
            self.dstPlane = (dstPlane, dstPlaneSize)
        }
                
        fillDstPlane(dstPlane, frame.data[1]!, frame.data[2]!, srcPlaneSize)

        let status = CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if status != kCVReturnSuccess {
            return nil
        }

        let bytesPerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        let bytesPerRowA = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 2)

        var base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!
        if bytesPerRowY == frame.lineSize[0] {
            memcpy(base, frame.data[0]!, bytesPerRowY * Int(frame.height))
        } else {
            var dest = base
            var src = frame.data[0]!
            let linesize = Int(frame.lineSize[0])
            for _ in 0 ..< Int(frame.height) {
                memcpy(dest, src, linesize)
                dest = dest.advanced(by: bytesPerRowY)
                src = src.advanced(by: linesize)
            }
        }

        base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)!
        if bytesPerRowUV == frame.lineSize[1] * 2 {
            memcpy(base, dstPlane, Int(frame.height / 2) * bytesPerRowUV)
        } else {
            var dest = base
            var src = dstPlane
            let linesize = Int(frame.lineSize[1]) * 2
            for _ in 0 ..< Int(frame.height / 2) {
                memcpy(dest, src, linesize)
                dest = dest.advanced(by: bytesPerRowUV)
                src = src.advanced(by: linesize)
            }
        }

        if case .YUVA = frame.pixelFormat {
            base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2)!
            if bytesPerRowA == frame.lineSize[3] {
                memcpy(base, frame.data[3]!, bytesPerRowA * Int(frame.height))
            } else {
                var dest = base
                var src = frame.data[3]!
                let linesize = Int(frame.lineSize[3])
                for _ in 0 ..< Int(frame.height) {
                    memcpy(dest, src, linesize)
                    dest = dest.advanced(by: bytesPerRowA)
                    src = src.advanced(by: linesize)
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        var formatRef: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatRef)
        
        guard let format = formatRef, formatStatus == 0 else {
            return nil
        }
        
        var timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: pts)
        var sampleBuffer: CMSampleBuffer?
        
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: format, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, createIfNecessary: true)! as NSArray
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
    
    public func reset() {
        self.codecContext.flushBuffers()
        self.resetDecoderOnNextFrame = true
    }
}
