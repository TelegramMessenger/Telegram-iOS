#if !os(macOS)
import UIKit
#else
import AppKit
import TGUIKit
#endif
import CoreMedia
import Accelerate
import FFMpegBinding
import YuvConversion

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
    
    private let videoFrame: FFMpegAVFrame?
    private var resetDecoderOnNextFrame = true
    private var isError = false
    
    private var defaultDuration: CMTime?
    private var defaultTimescale: CMTimeScale?
    
    private var pixelBufferPool: CVPixelBufferPool?
    
    public var reusesPixelBuffers: Bool = false
    private var reusablePixelBufferPool: (pool: CVPixelBufferPool, width: Int32, height: Int32, pixelFormat: OSType, alignment: Int32)?
    
    private var delayedFrames: [MediaTrackFrame] = []
    
    private var uvPlane: (UnsafeMutablePointer<UInt8>, Int)?
    // Reused 420 scratch frame for `planarFrameFor420Conversion`. ARC-owned; the
    // decoder emits one size per stream, so this is allocated once.
    private var downsampled420Frame: FFMpegAVFrame?
    
    public init(codecContext: FFMpegAVCodecContext) {
        self.codecContext = codecContext
        self.videoFrame = FFMpegAVFrame()
    }
    
    deinit {
        if let (dstPlane, _) = self.uvPlane {
            free(dstPlane)
        }
    }
    
    func decodeInternal(frame: MediaTrackDecodableFrame) {
    }
    
    public func decode() -> MediaTrackFrame? {
        return self.decode(ptsOffset: nil)
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
    
    public func receiveFromDecoder(ptsOffset: CMTime?, displayImmediately: Bool = true) -> ReceiveResult {
        guard let videoFrame = self.videoFrame else {
            return .error
        }
        if self.isError {
            return .error
        }
        guard let defaultTimescale = self.defaultTimescale, let defaultDuration = self.defaultDuration else {
            return .error
        }
        
        let receiveResult = self.codecContext.receive(into: videoFrame)
        switch receiveResult {
        case .success:
            if videoFrame.width * videoFrame.height > 4 * 1024 * 4 * 1024 {
                self.isError = true
                return .error
            }
            
            var pts = CMTimeMake(value: videoFrame.pts, timescale: defaultTimescale)
            if let ptsOffset = ptsOffset {
                pts = CMTimeAdd(pts, ptsOffset)
            }
            if let convertedFrame = convertVideoFrame(videoFrame, pts: pts, dts: pts, duration: videoFrame.duration > 0 ? CMTimeMake(value: videoFrame.duration, timescale: defaultTimescale) : defaultDuration, displayImmediately: displayImmediately) {
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
    
    public func send(frame: MediaTrackDecodableFrame) -> Bool {
        let status = frame.packet.send(toDecoder: self.codecContext)
        if status == 0 {
            self.defaultDuration = frame.duration
            self.defaultTimescale = frame.pts.timescale
            return true
        } else {
            return false
        }
    }
    
    public func decode(ptsOffset: CMTime?, forceARGB: Bool = false, unpremultiplyAlpha: Bool = true, displayImmediately: Bool = true) -> MediaTrackFrame? {
        guard let videoFrame = self.videoFrame else {
            return nil
        }
        if self.isError {
            return nil
        }
        guard let defaultDuration = self.defaultDuration, let defaultTimescale = self.defaultTimescale else {
            return nil
        }
        
        if self.codecContext.receive(into: videoFrame) == .success {
            if videoFrame.width * videoFrame.height > 4 * 1024 * 4 * 1024 {
                self.isError = true
                return nil
            }
            
            var pts = CMTimeMake(value: videoFrame.pts, timescale: defaultTimescale)
            if let ptsOffset = ptsOffset {
                pts = CMTimeAdd(pts, ptsOffset)
            }
            return convertVideoFrame(videoFrame, pts: pts, dts: pts, duration: defaultDuration, forceARGB: forceARGB, unpremultiplyAlpha: unpremultiplyAlpha, displayImmediately: displayImmediately)
        }
        
        return nil
    }
    
    public func receiveRemainingFrames(ptsOffset: CMTime?) -> [MediaTrackFrame] {
        guard let videoFrame = self.videoFrame else {
            return []
        }
        guard let defaultTimescale = self.defaultTimescale, let defaultDuration = self.defaultDuration else {
            return []
        }
        if self.isError {
            return []
        }
        
        var result: [MediaTrackFrame] = []
        result.append(contentsOf: self.delayedFrames)
        self.delayedFrames.removeAll()
        
        while true {
            if case .success = self.codecContext.receive(into: videoFrame) {
                if videoFrame.width * videoFrame.height > 4 * 1024 * 4 * 1024 {
                    self.isError = true
                    return []
                }
                
                var pts = CMTimeMake(value: videoFrame.pts, timescale: defaultTimescale)
                if let ptsOffset = ptsOffset {
                    pts = CMTimeAdd(pts, ptsOffset)
                }
                if let convertedFrame = convertVideoFrame(videoFrame, pts: pts, dts: pts, duration: videoFrame.duration > 0 ? CMTimeMake(value: videoFrame.duration, timescale: defaultTimescale) : defaultDuration) {
                    result.append(convertedFrame)
                }
            } else {
                break
            }
        }
        return result
    }
    
    public func render(frame: MediaTrackDecodableFrame) -> UIImage? {
        guard let videoFrame = self.videoFrame else {
            return nil
        }
        let status = frame.packet.send(toDecoder: self.codecContext)
        if status == 0 {
            if case .success = self.codecContext.receive(into: videoFrame) {
                if videoFrame.width * videoFrame.height > 4 * 1024 * 4 * 1024 {
                    self.isError = true
                    return nil
                }
                
                return convertVideoFrameToImage(videoFrame)
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
    
    private static func isPlanarYUV420Safe(_ frame: FFMpegAVFrame) -> Bool {
        // Layout must be a planar YUV/YUVA 420 variant. Anything else (BGRA, NV12, gray8,
        // YUV422P, …) must not reach the planar 420 vImage conversion or the planar copy
        // path that force-unwraps data[1]/data[2].
        let format = frame.pixelFormat
        guard format == .YUV || format == .YUVA else {
            return false
        }
        // Reject bottom-up / negative-stride frames before any row-copy loop — ffmpeg
        // rawdec flips linesize[0] for codec_tag WRAW/cyuv/BottomUp, and other decoders
        // (dxtory, mimic, mjpegdec, scpr) flip the chroma planes too.
        if frame.lineSize[0] < 0 || frame.lineSize[1] < 0 || frame.lineSize[2] < 0 {
            return false
        }
        if format == .YUVA && frame.lineSize[3] < 0 {
            return false
        }
        if frame.data[0] == nil || frame.data[1] == nil || frame.data[2] == nil {
            return false
        }
        if format == .YUVA && frame.data[3] == nil {
            return false
        }
        if frame.width <= 0 || frame.height <= 0 {
            return false
        }
        return true
    }

    // Folds an under-subsampled planar frame — 4:2:2 (YUV422P/YUVJ422P/YUVA422P) or 4:4:4
    // (YUV444P/YUVJ444P/YUVA444P), i.e. H.264 High 4:2:2 / 4:4:4 Predictive — down to the
    // 420 layout every path below requires, and passes 420 input through untouched.
    // Without this the decoder produces perfectly good frames that every consumer then
    // rejects, which reads as an undecodable file.
    //
    // Chroma goes through vImage rather than a hand-written loop: this module builds
    // -Onone in debug, where a per-pixel Swift loop over a full-resolution plane costs
    // orders of magnitude more than the library call.
    private func planarFrameFor420Conversion(_ frame: FFMpegAVFrame) -> FFMpegAVFrame? {
        let width = Int(frame.width)
        let height = Int(frame.height)
        guard width > 0 && height > 0 else {
            return nil
        }

        // Luma and alpha are full resolution in every layout here; only chroma differs, so
        // all that varies is the size of the source chroma plane vImage samples from.
        let targetFormat: FFMpegAVFramePixelFormat
        let sourceChromaWidth: Int
        let sourceChromaHeight: Int
        switch frame.pixelFormat {
        case .YUV422, .YUVA422:
            targetFormat = frame.pixelFormat == .YUVA422 ? .YUVA : .YUV
            // Already half width; only the vertical axis needs halving.
            sourceChromaWidth = (width + 1) / 2
            sourceChromaHeight = height
        case .YUV444, .YUVA444:
            targetFormat = frame.pixelFormat == .YUVA444 ? .YUVA : .YUV
            sourceChromaWidth = width
            sourceChromaHeight = height
        default:
            return frame
        }
        let hasAlpha = targetFormat == .YUVA
        let planeCount = hasAlpha ? 4 : 3
        // Reject missing planes and bottom-up / negative strides before any copy, for the
        // same reasons `isPlanarYUV420Safe` does.
        for i in 0 ..< planeCount {
            if frame.lineSize[i] <= 0 || frame.data[i] == nil {
                return nil
            }
        }

        let chromaWidth = (width + 1) / 2
        let chromaHeight = (height + 1) / 2

        let target: FFMpegAVFrame
        if let existing = self.downsampled420Frame, Int(existing.width) == width, Int(existing.height) == height, existing.pixelFormat == targetFormat {
            target = existing
        } else {
            guard let created = FFMpegAVFrame(pixelFormat: targetFormat, width: Int32(width), height: Int32(height)) else {
                return nil
            }
            // `initWithPixelFormat:` ignores the result of `av_frame_get_buffer`, so an
            // allocation failure arrives here as null planes rather than a nil frame.
            for i in 0 ..< planeCount {
                if created.lineSize[i] <= 0 || created.data[i] == nil {
                    return nil
                }
            }
            // Zero the stride padding once. The row copies below write only the visible
            // width, while the downstream copy into the CVPixelBuffer moves whole strides.
            FFMpegMediaVideoFrameDecoder.zeroRowPadding(created.data[0]!, Int(created.lineSize[0]), width, height)
            FFMpegMediaVideoFrameDecoder.zeroRowPadding(created.data[1]!, Int(created.lineSize[1]), chromaWidth, chromaHeight)
            FFMpegMediaVideoFrameDecoder.zeroRowPadding(created.data[2]!, Int(created.lineSize[2]), chromaWidth, chromaHeight)
            if hasAlpha {
                FFMpegMediaVideoFrameDecoder.zeroRowPadding(created.data[3]!, Int(created.lineSize[3]), width, height)
            }
            self.downsampled420Frame = created
            target = created
        }

        // The scratch frame is allocated colour-range-less; a full-range (YUVJ*) source must
        // carry its range across or `convertVideoFrameToImage` picks limited-range coefficients.
        target.copyColorRange(from: frame)

        // Luma and alpha are full resolution in both layouts.
        FFMpegMediaVideoFrameDecoder.copyPlane(src: frame.data[0]!, srcLineSize: Int(frame.lineSize[0]), dst: target.data[0]!, dstLineSize: Int(target.lineSize[0]), width: width, height: height)
        if hasAlpha {
            FFMpegMediaVideoFrameDecoder.copyPlane(src: frame.data[3]!, srcLineSize: Int(frame.lineSize[3]), dst: target.data[3]!, dstLineSize: Int(target.lineSize[3]), width: width, height: height)
        }

        for planeIndex in 1 ... 2 {
            var src = vImage_Buffer(data: UnsafeMutableRawPointer(frame.data[planeIndex]!), height: vImagePixelCount(sourceChromaHeight), width: vImagePixelCount(sourceChromaWidth), rowBytes: Int(frame.lineSize[planeIndex]))
            var dst = vImage_Buffer(data: UnsafeMutableRawPointer(target.data[planeIndex]!), height: vImagePixelCount(chromaHeight), width: vImagePixelCount(chromaWidth), rowBytes: Int(target.lineSize[planeIndex]))
            if vImageScale_Planar8(&src, &dst, nil, vImage_Flags(kvImageDoNotTile)) != kvImageNoError {
                return nil
            }
        }

        return target
    }

    private static func copyPlane(src: UnsafeMutablePointer<UInt8>, srcLineSize: Int, dst: UnsafeMutablePointer<UInt8>, dstLineSize: Int, width: Int, height: Int) {
        if srcLineSize == dstLineSize {
            memcpy(dst, src, srcLineSize * height)
        } else {
            var srcRow = src
            var dstRow = dst
            for _ in 0 ..< height {
                memcpy(dstRow, srcRow, width)
                srcRow = srcRow.advanced(by: srcLineSize)
                dstRow = dstRow.advanced(by: dstLineSize)
            }
        }
    }

    private static func zeroRowPadding(_ data: UnsafeMutablePointer<UInt8>, _ lineSize: Int, _ width: Int, _ height: Int) {
        guard lineSize > width else {
            return
        }
        var row = data
        for _ in 0 ..< height {
            memset(row.advanced(by: width), 0, lineSize - width)
            row = row.advanced(by: lineSize)
        }
    }

    private func convertVideoFrameToImage(_ frame: FFMpegAVFrame) -> UIImage? {
        guard let frame = self.planarFrameFor420Conversion(frame) else {
            return nil
        }
        guard FFMpegMediaVideoFrameDecoder.isPlanarYUV420Safe(frame) else {
            return nil
        }
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
    
    private func reusablePixelBufferPool(width: Int32, height: Int32, pixelFormat: OSType, alignment: Int32) -> CVPixelBufferPool? {
        if let current = self.reusablePixelBufferPool, current.width == width, current.height == height, current.pixelFormat == pixelFormat, current.alignment == alignment {
            return current.pool
        }
        let ioSurfaceProperties = NSMutableDictionary()
        ioSurfaceProperties["IOSurfaceIsGlobal"] = true as NSNumber
        let attributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: Int(width) as NSNumber,
            kCVPixelBufferHeightKey as String: Int(height) as NSNumber,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat as NSNumber,
            kCVPixelBufferBytesPerRowAlignmentKey as String: alignment as NSNumber,
            kCVPixelBufferIOSurfacePropertiesKey as String: ioSurfaceProperties
        ]
        var pool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess, let pool else {
            return nil
        }
        self.reusablePixelBufferPool = (pool, width, height, pixelFormat, alignment)
        return pool
    }
    
    private func convertVideoFrame(_ frame: FFMpegAVFrame, pts: CMTime, dts: CMTime, duration: CMTime, forceARGB: Bool = false, unpremultiplyAlpha: Bool = true, displayImmediately: Bool = true) -> MediaTrackFrame? {
        if frame.nativePixelFormat() == FFMpegAVFrameNativePixelFormat.videoToolbox {
            guard let pixelBufferRef = frame.data[3] else {
                return nil
            }
            let unmanagedPixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(UnsafeRawPointer(pixelBufferRef))
            let pixelBuffer = unmanagedPixelBuffer.takeUnretainedValue()
            
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
            
            if displayImmediately {
                dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DisplayImmediately as NSString as String)
            }
            
            return MediaTrackFrame(type: .video, sampleBuffer: sampleBuffer!, resetDecoder: resetDecoder, decoded: true)
        }
        
        guard let frame = self.planarFrameFor420Conversion(frame) else {
            return nil
        }
        guard FFMpegMediaVideoFrameDecoder.isPlanarYUV420Safe(frame) else {
            return nil
        }
        if frame.lineSize[1] != frame.lineSize[2] {
            return nil
        }
        
        var pixelBufferRef: CVPixelBuffer?
        
        let pixelFormat: OSType
        var hasAlpha = false
        if forceARGB {
            pixelFormat = kCVPixelFormatType_32ARGB
            switch frame.pixelFormat {
                case .YUV:
                    hasAlpha = false
                case .YUVA:
                    hasAlpha = true
                default:
                    hasAlpha = false
            }
        } else {
            switch frame.pixelFormat {
                case .YUV:
                    pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                case .YUVA:
                    pixelFormat = kCVPixelFormatType_420YpCbCr8VideoRange_8A_TriPlanar
                default:
                    pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            }
        }
        
        if let pixelBufferPool = self.pixelBufferPool {
            let auxAttributes: [String: Any] = [kCVPixelBufferPoolAllocationThresholdKey as String: bufferCount as NSNumber];
            let err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pixelBufferPool, auxAttributes as CFDictionary, &pixelBufferRef)
            if err == kCVReturnWouldExceedAllocationThreshold {
                print("kCVReturnWouldExceedAllocationThreshold, dropping frame")
                return nil
            }
        } else if self.reusesPixelBuffers, let pool = self.reusablePixelBufferPool(width: frame.width, height: frame.height, pixelFormat: pixelFormat, alignment: frame.lineSize[0]) {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferRef)
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

        let status = CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if status != kCVReturnSuccess {
            return nil
        }

        var base: UnsafeMutableRawPointer
        if pixelFormat == kCVPixelFormatType_32ARGB {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            decodeYUVAPlanesToRGBA(frame.data[0], Int32(frame.lineSize[0]), frame.data[1], Int32(frame.lineSize[1]), frame.data[2], Int32(frame.lineSize[2]), hasAlpha, frame.data[3], CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self), Int32(frame.width), Int32(frame.height), Int32(bytesPerRow), unpremultiplyAlpha)
        } else {
            let srcPlaneSize = Int(frame.lineSize[1]) * Int(frame.height / 2)
            let uvPlaneSize = srcPlaneSize * 2

            let uvPlane: UnsafeMutablePointer<UInt8>
            if let (existingUvPlane, existingUvPlaneSize) = self.uvPlane, existingUvPlaneSize == uvPlaneSize {
                uvPlane = existingUvPlane
            } else {
                if let (existingDstPlane, _) = self.uvPlane {
                    free(existingDstPlane)
                }
                uvPlane = malloc(uvPlaneSize)!.assumingMemoryBound(to: UInt8.self)
                self.uvPlane = (uvPlane, uvPlaneSize)
            }
                    
            fillDstPlane(uvPlane, frame.data[1]!, frame.data[2]!, srcPlaneSize)

            let bytesPerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
            let bytesPerRowA = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 2)

            var requiresAlphaMultiplication = false
            
            if pixelFormat == kCVPixelFormatType_420YpCbCr8VideoRange_8A_TriPlanar {
                requiresAlphaMultiplication = true
                
                base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2)!
                if bytesPerRowA == frame.lineSize[3] {
                    memcpy(base, frame.data[3]!, bytesPerRowA * Int(frame.height))
                } else {
                    var dest = base
                    var src = frame.data[3]!
                    let lineSize = Int(frame.lineSize[3])
                    for _ in 0 ..< Int(frame.height) {
                        memcpy(dest, src, lineSize)
                        dest = dest.advanced(by: bytesPerRowA)
                        src = src.advanced(by: lineSize)
                    }
                }
            }
            
            base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!
            if bytesPerRowY == frame.lineSize[0] {
                memcpy(base, frame.data[0]!, bytesPerRowY * Int(frame.height))
            } else {
                var dest = base
                var src = frame.data[0]!
                let lineSize = Int(frame.lineSize[0])
                for _ in 0 ..< Int(frame.height) {
                    memcpy(dest, src, lineSize)
                    dest = dest.advanced(by: bytesPerRowY)
                    src = src.advanced(by: lineSize)
                }
            }
            
            if requiresAlphaMultiplication {
                var y = vImage_Buffer(data: CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!, height: vImagePixelCount(frame.height), width: vImagePixelCount(bytesPerRowY), rowBytes: bytesPerRowY)
                var a = vImage_Buffer(data: CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2)!, height: vImagePixelCount(frame.height), width: vImagePixelCount(bytesPerRowY), rowBytes: bytesPerRowA)
                let _ = vImagePremultiplyData_Planar8(&y, &a, &y, vImage_Flags(kvImageDoNotTile))
            }

            base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)!
            if bytesPerRowUV == frame.lineSize[1] * 2 {
                memcpy(base, uvPlane, Int(frame.height / 2) * bytesPerRowUV)
            } else {
                var dest = base
                var src = uvPlane
                let lineSize = Int(frame.lineSize[1]) * 2
                for _ in 0 ..< Int(frame.height / 2) {
                    memcpy(dest, src, lineSize)
                    dest = dest.advanced(by: bytesPerRowUV)
                    src = src.advanced(by: lineSize)
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
        
        if displayImmediately {
            dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DisplayImmediately as NSString as String)
        }
        
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
        
    public func reset() {
        self.codecContext.flushBuffers()
        self.resetDecoderOnNextFrame = true
    }
}
