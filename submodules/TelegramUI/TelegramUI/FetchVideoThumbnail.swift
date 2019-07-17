import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import CoreMedia
import TelegramUIPrivateModule
import Display
import UIKit
import VideoToolbox
import FFMpeg

/*
private func readPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    guard let buffer = buffer else {
        return 0
    }
    let context = Unmanaged<FetchVideoThumbnailSource>.fromOpaque(userData!).takeUnretainedValue()
    while !context.cancelled && !context.readingError {
        if !RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: .distantFuture) {
            break
        }
    }
    return -1
    //return Int32(bufferPointer)
}

private func seekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<FetchVideoThumbnailSource>.fromOpaque(userData!).takeUnretainedValue()
    if (whence & FFMPEG_AVSEEK_SIZE) != 0 {
        return Int64(context.size)
    } else {
        context.readOffset = Int(offset)
        return offset
    }
}

private final class SoftwareVideoStream {
    let index: Int
    let fps: CMTime
    let timebase: CMTime
    let duration: CMTime
    let decoder: FFMpegMediaVideoFrameDecoder
    let rotationAngle: Double
    let aspect: Double
    
    init(index: Int, fps: CMTime, timebase: CMTime, duration: CMTime, decoder: FFMpegMediaVideoFrameDecoder, rotationAngle: Double, aspect: Double) {
        self.index = index
        self.fps = fps
        self.timebase = timebase
        self.duration = duration
        self.decoder = decoder
        self.rotationAngle = rotationAngle
        self.aspect = aspect
    }
}

private final class FetchVideoThumbnailSource {
    fileprivate let mediaBox: MediaBox
    fileprivate let resourceReference: MediaResourceReference
    fileprivate let size: Int32
    fileprivate var readOffset: Int = 0
    
    fileprivate var cancelled = false
    fileprivate var readingError = false
    
    private var videoStream: SoftwareVideoStream?
    private var avIoContext: UnsafeMutablePointer<FFMpegAVIOContext>?
    private var avFormatContext: UnsafeMutablePointer<FFMpegAVFormatContext>?
 
//    init(mediaBox: MediaBox, resourceReference: MediaResourceReference, size: Int32) {
        let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
        
        self.mediaBox = mediaBox
        self.resourceReference = resourceReference
        self.size = size
 
        var avFormatContextRef = avformat_alloc_context()
        guard let avFormatContext = avFormatContextRef else {
            self.readingError = true
            return
        }
        
        let ioBufferSize = 8 * 1024
        let avIoBuffer = av_malloc(ioBufferSize)!
        let avIoContextRef = avio_alloc_context(avIoBuffer.assumingMemoryBound(to: UInt8.self), Int32(ioBufferSize), 0, Unmanaged.passUnretained(self).toOpaque(), readPacketCallback, nil, seekCallback)
        self.avIoContext = avIoContextRef
 
        avFormatContext.pointee.pb = self.avIoContext
        
        guard avformat_open_input(&avFormatContextRef, nil, nil, nil) >= 0 else {
            self.readingError = true
            return
        }
        
        guard avformat_find_stream_info(avFormatContext, nil) >= 0 else {
            self.readingError = true
            return
        }
 
        self.avFormatContext = avFormatContext
        
        var videoStream: SoftwareVideoStream?
        
        for streamIndex in FFMpegMediaFrameSourceContextHelpers.streamIndices(formatContext: avFormatContext, codecType: AVMEDIA_TYPE_VIDEO) {
            if (avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.disposition & Int32(AV_DISPOSITION_ATTACHED_PIC)) == 0 {
                
                let codecPar = avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.codecpar!
                
                if let codec = avcodec_find_decoder(codecPar.pointee.codec_id) {
                    if let codecContext = avcodec_alloc_context3(codec) {
                        if avcodec_parameters_to_context(codecContext, avFormatContext.pointee.streams[streamIndex]!.pointee.codecpar) >= 0 {
                            if avcodec_open2(codecContext, codec, nil) >= 0 {
                                let (fps, timebase) = FFMpegMediaFrameSourceContextHelpers.streamFpsAndTimeBase(stream: avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!, defaultTimeBase: CMTimeMake(1, 24))
                                
                                let duration = CMTimeMake(avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.duration, timebase.timescale)
 
                                var rotationAngle: Double = 0.0
                                if let rotationInfo = av_dict_get(avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.metadata, "rotate", nil, 0), let value = rotationInfo.pointee.value {
                                    if strcmp(value, "0") != 0 {
                                        if let angle = Double(String(cString: value)) {
                                            rotationAngle = angle * Double.pi / 180.0
                                        }
                                    }
                                }
                                
                                let aspect = Double(codecPar.pointee.width) / Double(codecPar.pointee.height)
                                
                                videoStream = SoftwareVideoStream(index: streamIndex, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegMediaVideoFrameDecoder(codecContext: codecContext), rotationAngle: rotationAngle, aspect: aspect)
                                break
                            } else {
                                var codecContextRef: UnsafeMutablePointer<AVCodecContext>? = codecContext
                                avcodec_free_context(&codecContextRef)
                            }
                        } else {
                            var codecContextRef: UnsafeMutablePointer<AVCodecContext>? = codecContext
                            avcodec_free_context(&codecContextRef)
                        }
                    }
                }
            }
        }
        
        self.videoStream = videoStream
        if self.videoStream == nil {
            self.readingError = true
        }
    }
    
    deinit {
        if let avIoContext = self.avIoContext {
            if avIoContext.pointee.buffer != nil {
                av_free(avIoContext.pointee.buffer)
            }
            av_free(avIoContext)
        }
        if let avFormatContext = self.avFormatContext {
            avformat_free_context(avFormatContext)
        }
    }
    
    private func readPacketInternal() -> FFMpegPacket? {
        guard let avFormatContext = self.avFormatContext else {
            return nil
        }
        
        let packet = FFMpegPacket()
        if av_read_frame(avFormatContext, &packet.packet) < 0 {
            return nil
        } else {
            return packet
        }
    }
    
    func readDecodableFrame() -> MediaTrackDecodableFrame? {
        var frames: [MediaTrackDecodableFrame] = []
        
        while !self.readingError && frames.isEmpty {
            if let packet = self.readPacketInternal() {
                if let videoStream = videoStream, Int(packet.streamIndex) == videoStream.index {
                    let avNoPtsRawValue: UInt64 = 0x8000000000000000
                    let avNoPtsValue = Int64(bitPattern: avNoPtsRawValue)
                    let packetPts = packet.pts == avNoPtsValue ? packet.dts : packet.pts
 
                    let pts = CMTimeMake(packetPts, videoStream.timebase.timescale)
                    let dts = CMTimeMake(packet.dts, videoStream.timebase.timescale)
 
                    let duration: CMTime
                    
                    let frameDuration = packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(frameDuration * videoStream.timebase.value, videoStream.timebase.timescale)
                    } else {
                        duration = videoStream.fps
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .video, packet: packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                }
            } else {
                self.readingError = true
            }
        }
 
        return frames.first
    }
    
    func readFrame() -> (frame: MediaTrackFrame, rotationAngle: CGFloat, aspect: CGFloat)? {
        guard let videoStream = self.videoStream else {
            return nil
        }
        guard let decodableFrame = self.readDecodableFrame() else {
            return nil
        }
        guard let decodedFrame = videoStream.decoder.decode(frame: decodableFrame, ptsOffset: nil) else {
            return nil
        }
        
        return (decodedFrame, CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect))
    }
}

private final class FetchVideoThumbnailSourceParameters: NSObject {
    let mediaBox: MediaBox
    let resourceReference: MediaResourceReference
    let size: Int32
    
    init(mediaBox: MediaBox, resourceReference: MediaResourceReference, size: Int32) {
        self.mediaBox = mediaBox
        self.resourceReference = resourceReference
        self.size = size
    }
}

private final class FetchVideoThumbnailSourceTimerTarget: NSObject {
    @objc func noop() {
    }
}

private let threadContextKey = "FetchVideoThumbnailSourceThreadContext"

private final class FetchVideoThumbnailSourceThreadContext {
    
}

private final class FetchVideoThumbnailSourceThreadImpl: NSObject {
    private var timer: Foundation.Timer
    private var disposed = false
    
    override init() {
        self.timer = Foundation.Timer.scheduledTimer(timeInterval: .greatestFiniteMagnitude, target: FetchVideoThumbnailSourceTimerTarget(), selector: #selector(FetchVideoThumbnailSourceTimerTarget.noop), userInfo: nil, repeats: true)
        
        super.init()
    }
    
    @objc func dispose() {
        self.disposed = true
        self.timer.invalidate()
    }
    
    @objc func entryPoint() {
        Thread.current.threadDictionary[threadContextKey] = FetchVideoThumbnailSourceThreadContext()
        RunLoop.current.add(self.timer, forMode: RunLoopMode.defaultRunLoopMode)
        while !self.disposed {
            if !RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: .distantFuture) {
                break
            }
        }
    }
 
    @objc func fetch(_ parameters: FetchVideoThumbnailSourceParameters) {
        let source = FetchVideoThumbnailSource(mediaBox: parameters.mediaBox, resourceReference: parameters.resourceReference, size: parameters.size)
        let _ = source.readFrame()
    }
}

private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        return nil
    }
    var maybeImage: CGImage?
    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
        guard VTCreateCGImageFromCVPixelBuffer(imageBuffer, nil, &maybeImage) == noErr, let image = maybeImage else {
            return nil
        }
        return UIImage(cgImage: image)
    } else {
        return nil
    }
    
    /*CVPixelBufferLockBaseAddress(imageBuffer, [])
    defer {
        CVPixelBufferUnlockBaseAddress(imageBuffer, [])
    }
    
    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
    guard let yBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)?.assumingMemoryBound(to: UInt8.self) else {
        return nil
    }
    let yPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
    guard let cbCrBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1)?.assumingMemoryBound(to: UInt8.self) else {
        return nil
    }
    let cbCrPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1)
    
    let bytesPerPixel = 4
    let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, clear: false)
    let rgbBuffer = context.bytes.assumingMemoryBound(to: UInt8.self)
    
    for y in 0 ..< height {
        let rgbBufferLine = rgbBuffer.advanced(by: y * width * bytesPerPixel)
        let yBufferLine = yBuffer.advanced(by: y * yPitch)
        let cbCrBufferLine = cbCrBuffer.advanced(by: y * 2 * cbCrPitch)
        
        for x in 0 ..< width {
            let y = UInt16(yBufferLine[x])
            let cb = UInt16(cbCrBufferLine[x & ~1]) - 128
            let cr = UInt16(cbCrBufferLine[x | 1]) - 128
            
            let rgbOutput = rgbBufferLine.advanced(by: x * bytesPerPixel)
            
            let r = UInt16(round(Float(y) + Float(cr) * 1.4))
            let g = UInt16(round(Float(y) + Float(cb) * -0.343 + Float(cr) * -0.711))
            let b = UInt16(round(Float(y) + Float(cb) * 1.765))
            
            rgbOutput[0] = 0xff
            rgbOutput[1] = UInt8(clamping: b > 255 ? 255 : (b < 0 ? 0 : b))
            rgbOutput[2] = UInt8(clamping: g > 255 ? 255 : (g < 0 ? 0 : g))
            rgbOutput[3] = UInt8(clamping: r > 255 ? 255 : (r < 0 ? 0 : r))
        }
    }
    
    
    return context.generateImage()*/
}

private let headerSize = 250 * 1024
private let tailSize = 16 * 1024

func fetchedPartialVideoThumbnailData(postbox: Postbox, fileReference: FileMediaReference) -> Signal<Void, NoError> {
    return Signal { subscriber in
        guard let size = fileReference.media.size else {
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let fetchedHead = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource), range: (0 ..< min(size, headerSize), .elevated), statsCategory: .video, reportResultStatus: false, preferBackgroundReferenceRevalidation: false).start()
        let fetchedTail = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource), range: (max(0, size - tailSize) ..< size, .elevated), statsCategory: .video, reportResultStatus: false, preferBackgroundReferenceRevalidation: false).start()
        
        return ActionDisposable {
            fetchedHead.dispose()
            fetchedTail.dispose()
        }
    }
}

private func partialVideoThumbnailData(postbox: Postbox, resource: MediaResource) -> Signal<(Data, Int, Data), NoError> {
    guard let size = resource.size else {
        return .complete()
    }
    return combineLatest(postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, headerSize)), postbox.mediaBox.resourceData(resource, size: size, in: max(0, size - tailSize) ..< size))
    |> mapToSignal { header, tail -> Signal<(Data, Int, Data), NoError> in
        return .single((header, max(0, size - header.count - tail.count), tail))
    }
}

func fetchedStreamingVideoThumbnail(postbox: Postbox, fileReference: FileMediaReference) -> Signal<Never, NoError> {
    return Signal { subscriber in
        let resourceReference = fileReference.resourceReference(fileReference.media.resource)
        guard let size = resourceReference.resource.size else {
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let impl = FetchVideoThumbnailSourceThreadImpl()
        let thread = Thread(target: impl, selector: #selector(impl.entryPoint), object: nil)
        thread.name = "fetchedStreamingVideoThumbnail"
        impl.perform(#selector(impl.fetch(_:)), on: thread, with: FetchVideoThumbnailSourceParameters(mediaBox: postbox.mediaBox, resourceReference: resourceReference, size: Int32(size)), waitUntilDone: false)
        thread.start()
        
        return ActionDisposable {
            impl.perform(#selector(impl.dispose), on: thread, with: nil, waitUntilDone: false)
        }
    }
}

func streamingVideoThumbnail(postbox: Postbox, fileReference: FileMediaReference) -> Signal<Data?, NoError> {
    return Signal { subscriber in
        let impl = FetchVideoThumbnailSourceThreadImpl()
        let thread = Thread(target: impl, selector: #selector(impl.entryPoint), object: nil)
        thread.name = "streamingVideoThumbnail"
        //impl.perform(#selector(impl.fetch(_:)), on: thread, with: FetchVideoThumbnailSourceParameters(), waitUntilDone: false)
        thread.start()
        
        return ActionDisposable {
            impl.perform(#selector(impl.dispose), on: thread, with: nil, waitUntilDone: false)
        }
    }
}










//func fetchPartialVideoThumbnail(postbox: Postbox, resource: MediaResource) -> Signal<Data?, NoError> {
//    return partialVideoThumbnailData(postbox: postbox, resource: resource)
//    |> take(1)
//    |> mapToSignal { header, spacing, tail -> Signal<Data?, NoError> in
//        return Signal { subscriber in
//            let source = FetchVideoThumbnailSource(header: header, spacing: spacing, tail: tail)
//            guard let (frame, rotationAngle, aspect) = source.readFrame() else {
//                subscriber.putNext(nil)
//                subscriber.putCompletion()
//                return EmptyDisposable
//            }
//            guard let image = imageFromSampleBuffer(sampleBuffer: frame.sampleBuffer) else {
//                subscriber.putNext(nil)
//                subscriber.putCompletion()
//                return EmptyDisposable
//            }
//            guard let data = UIImageJPEGRepresentation(image, 0.7) else {
//                subscriber.putNext(nil)
//                subscriber.putCompletion()
//                return EmptyDisposable
//            }
//            subscriber.putNext(data)
//            subscriber.putCompletion()
//            return EmptyDisposable
//        }
//    }
//    /*return Signal { subscriber in
//        let impl = FetchVideoThumbnailSourceThreadImpl()
//        let thread = Thread(target: impl, selector: #selector(impl.entryPoint), object: nil)
//        thread.name = "fetchPartialVideoThumbnail"
//        impl.perform(#selector(impl.fetch(_:)), on: thread, with: FetchVideoThumbnailSourceParameters(), waitUntilDone: false)
//        thread.start()
//
//        return ActionDisposable {
//            impl.perform(#selector(impl.dispose), on: thread, with: nil, waitUntilDone: false)
//        }
//    }*/
//}
//
//func fetchedStreamingVideoThumbnail(postbox: Postbox, fileReference: FileMediaReference) -> Signal<Never, NoError> {
//    return Signal { subscriber in
//        let resourceReference = fileReference.resourceReference(fileReference.media.resource)
//        guard let size = resourceReference.resource.size else {
//            subscriber.putCompletion()
//            return EmptyDisposable
//        }
//        let impl = FetchVideoThumbnailSourceThreadImpl()
//        let thread = Thread(target: impl, selector: #selector(impl.entryPoint), object: nil)
//        thread.name = "fetchedStreamingVideoThumbnail"
//        impl.perform(#selector(impl.fetch(_:)), on: thread, with: FetchVideoThumbnailSourceParameters(mediaBox: postbox.mediaBox, resourceReference: resourceReference, size: Int32(size)), waitUntilDone: false)
//        thread.start()
//
//        return ActionDisposable {
//            impl.perform(#selector(impl.dispose), on: thread, with: nil, waitUntilDone: false)
//        }
//    }
//}
//
////func streamingVideoThumbnail(postbox: Postbox, fileReference: FileMediaReference) -> Signal<Data?, NoError> {
////    return Signal { subscriber in
////        let impl = FetchVideoThumbnailSourceThreadImpl()
////        let thread = Thread(target: impl, selector: #selector(impl.entryPoint), object: nil)
////        thread.name = "streamingVideoThumbnail"
////        impl.perform(#selector(impl.fetch(_:)), on: thread, with: FetchVideoThumbnailSourceParameters(), waitUntilDone: false)
////        thread.start()
////
////        return ActionDisposable {
////            impl.perform(#selector(impl.dispose), on: thread, with: nil, waitUntilDone: false)
////        }
////    }
////}
*/
