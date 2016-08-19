import Foundation
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCorePrivateModule

private struct StreamContext {
    private let index: Int
    private let codecContext: UnsafeMutablePointer<AVCodecContext>?
    private let fps: CMTime
    private let timebase: CMTime
    private let duration: CMTime
    private let decoder: MediaTrackFrameDecoder
    
    func close() {
    }
}

struct FFMpegMediaFrameSourceDescription {
    let duration: CMTime
    let decoder: MediaTrackFrameDecoder
}

struct FFMpegMediaFrameSourceDescriptionSet {
    let audio: FFMpegMediaFrameSourceDescription?
    let video: FFMpegMediaFrameSourceDescription?
}

private struct InitializedState {
    private let avIoContext: UnsafeMutablePointer<AVIOContext>
    private let avFormatContext: UnsafeMutablePointer<AVFormatContext>
    
    private let audioStream: StreamContext?
    private let videoStream: StreamContext?
    
    func close() {
        self.videoStream?.close()
        self.audioStream?.close()
    }
}

struct FFMpegMediaFrameSourceStreamContextInfo {
    let duration: CMTime
    let decoder: MediaTrackFrameDecoder
}

struct FFMpegMediaFrameSourceContextInfo {
    let audioStream: FFMpegMediaFrameSourceStreamContextInfo?
    let videoStream: FFMpegMediaFrameSourceStreamContextInfo?
}

/*private func getFormatCallback(codecContext: UnsafeMutablePointer<AVCodecContext>?, formats: UnsafePointer<AVPixelFormat>?) -> AVPixelFormat {
    var formats = formats!
    while formats.pointee != AV_PIX_FMT_NONE {
        let desc = av_pix_fmt_desc_get(formats.pointee)!
        
        if formats.pointee == AV_PIX_FMT_VIDEOTOOLBOX {
            let result = av_videotoolbox_default_init(codecContext!)
            if (result < 0) {
                print("av_videotoolbox_default_init failed (\(result))")
                formats = formats.successor()
                continue
            }
            
            return formats.pointee;
        } else if (desc.pointee.flags & UInt64(AV_PIX_FMT_FLAG_HWACCEL)) == 0 {
            return formats.pointee
        }
        formats = formats.successor()
    }
    return formats.pointee
}*/

private func readPacketCallback(userData: UnsafeMutablePointer<Void>?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    let context = Unmanaged<FFMpegMediaFrameSourceContext>.fromOpaque(userData!).takeUnretainedValue()
    guard let account = context.account, let resource = context.resource else {
        return 0
    }
    
    var fetchedCount: Int32 = 0
    
    let readCount = min(resource.size - context.readingOffset, Int(bufferSize))
    let data = account.postbox.mediaBox.resourceData(resource, in: context.readingOffset ..< (context.readingOffset + readCount), mode: .complete)
    var fetchedData: Data?
    let semaphore = DispatchSemaphore(value: 0)
    let _ = data.start(next: { data in
        if data.count == readCount {
            fetchedData = data
            semaphore.signal()
        }
    })
    semaphore.wait()
    if let fetchedData = fetchedData {
        fetchedData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            memcpy(buffer, bytes, fetchedData.count)
        }
        fetchedCount = Int32(fetchedData.count)
        context.readingOffset += Int(fetchedCount)
    }
    
    return fetchedCount
}

private func seekCallback(userData: UnsafeMutablePointer<Void>?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<FFMpegMediaFrameSourceContext>.fromOpaque(userData!).takeUnretainedValue()
    guard let account = context.account, let resource = context.resource else {
        return 0
    }
    
    var result: Int64 = offset
    
    if (whence & AVSEEK_SIZE) != 0 {
        result = Int64(resource.size)
    } else {
        context.readingOffset = Int(min(Int64(resource.size), offset))
        
        if context.readingOffset != context.requestedDataOffset {
            context.requestedDataOffset = context.readingOffset
            
            if context.readingOffset >= resource.size {
                context.fetchedDataDisposable.set(nil)
            } else {
                context.fetchedDataDisposable.set(account.postbox.mediaBox.fetchedResourceData(resource, in: context.readingOffset ..< resource.size).start())
            }
        }
    }
    
    return result
}

final class FFMpegMediaFrameSourceContext: NSObject {
    private let thread: Thread
    
    var closed = false
    
    private var account: Account?
    private var resource: MediaResource?
    
    private let ioBufferSize = 64 * 1024
    private var readingOffset = 0
    
    private var requestedDataOffset: Int?
    private let fetchedDataDisposable = MetaDisposable()
    
    private var readingError = false
    
    private var initializedState: InitializedState?
    private var packetQueue: [FFMpegPacket] = []
    
    init(thread: Thread) {
        self.thread = thread
    }
    
    deinit {
        assert(Thread.current === self.thread)
        
        fetchedDataDisposable.dispose()
    }
    
    func initializeState(account: Account, resource: MediaResource) {
        if self.readingError || self.initializedState != nil {
            return
        }
        
        let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
        
        self.account = account
        self.resource = resource
        
        self.fetchedDataDisposable.set(account.postbox.mediaBox.fetchedResourceData(resource, in: 0 ..< resource.size).start())
        
        var avFormatContextRef = avformat_alloc_context()
        guard let avFormatContext = avFormatContextRef else {
            self.readingError = true
            return
        }
        
        let avIoBuffer = av_malloc(self.ioBufferSize)!
        let avIoContextRef = avio_alloc_context(UnsafeMutablePointer<UInt8>(avIoBuffer), Int32(self.ioBufferSize), 0, Unmanaged.passUnretained(self).toOpaque(), readPacketCallback, nil, seekCallback)
        
        guard let avIoContext = avIoContextRef else {
            self.readingError = true
            return
        }
        
        avFormatContext.pointee.pb = avIoContext
        
        guard avformat_open_input(&avFormatContextRef, nil, nil, nil) >= 0 else {
            self.readingError = true
            return
        }
        
        guard avformat_find_stream_info(avFormatContext, nil) >= 0 else {
            self.readingError = true
            return
        }
        
        var videoStream: StreamContext?
        var audioStream: StreamContext?
        
        for streamIndex in FFMpegMediaFrameSourceContextHelpers.streamIndices(formatContext: avFormatContext, codecType: AVMEDIA_TYPE_VIDEO) {
            if (avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.disposition & Int32(AV_DISPOSITION_ATTACHED_PIC)) == 0 {
                
                let codecPar = avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.codecpar!
                
                if codecPar.pointee.codec_id == AV_CODEC_ID_H264 {
                    if let videoFormat = FFMpegMediaFrameSourceContextHelpers.createFormatDescriptionFromCodecData(UInt32(kCMVideoCodecType_H264), codecPar.pointee.width, codecPar.pointee.height, codecPar.pointee.extradata, codecPar.pointee.extradata_size, 0x43637661) {
                        let (fps, timebase) = FFMpegMediaFrameSourceContextHelpers.streamFpsAndTimeBase(stream: avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!, defaultTimeBase: CMTimeMake(1, 1000))
                        
                        let duration = CMTimeMake(avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.duration, timebase.timescale)
                        
                        videoStream = StreamContext(index: streamIndex, codecContext: nil, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegMediaPassthroughVideoFrameDecoder(videoFormat: videoFormat))
                        break
                    }
                }
            }
        }
        
        for streamIndex in FFMpegMediaFrameSourceContextHelpers.streamIndices(formatContext: avFormatContext, codecType: AVMEDIA_TYPE_AUDIO) {
            if let codec = avcodec_find_decoder(avFormatContext.pointee.streams[streamIndex]!.pointee.codecpar.pointee.codec_id) {
                if let codecContext = avcodec_alloc_context3(codec) {
                    if avcodec_parameters_to_context(codecContext, avFormatContext.pointee.streams[streamIndex]!.pointee.codecpar) >= 0 {
                        if avcodec_open2(codecContext, codec, nil) >= 0 {
                            let (fps, timebase) = FFMpegMediaFrameSourceContextHelpers.streamFpsAndTimeBase(stream: avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!, defaultTimeBase: CMTimeMake(1, 40000))
                            
                            let duration = CMTimeMake(avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.duration, timebase.timescale)
                            
                            audioStream = StreamContext(index: streamIndex, codecContext: codecContext, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegAudioFrameDecoder(codecContext: codecContext))
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
        
        self.initializedState = InitializedState(avIoContext: avIoContext, avFormatContext: avFormatContext, audioStream: audioStream, videoStream: videoStream)
    }
    
    private func readPacket() -> FFMpegPacket? {
        if !self.packetQueue.isEmpty {
            return self.packetQueue.remove(at: 0)
        } else {
            return self.readPacketInternal()
        }
    }
    
    private func readPacketInternal() -> FFMpegPacket? {
        guard let initializedState = self.initializedState else {
            return nil
        }
        
        let packet = FFMpegPacket()
        if av_read_frame(initializedState.avFormatContext, &packet.packet) < 0 {
            return nil
        } else {
            return packet
        }
    }
    
    func takeFrames(until: Double) -> [MediaTrackDecodableFrame] {
        if self.readingError {
            return []
        }
        
        guard let initializedState = self.initializedState else {
            return []
        }
        
        var videoTimestamp: Double?
        if initializedState.videoStream == nil {
            videoTimestamp = Double.infinity
        }
        
        var audioTimestamp: Double?
        if initializedState.audioStream == nil {
            audioTimestamp = Double.infinity
        }
        
        var frames: [MediaTrackDecodableFrame] = []
        
        while !self.readingError && ((videoTimestamp == nil || videoTimestamp!.isLess(than: until)) || (audioTimestamp == nil || audioTimestamp!.isLess(than: until))) {
            
            if let packet = self.readPacket() {
                if let videoStream = initializedState.videoStream, Int(packet.packet.stream_index) == videoStream.index {
                    let avNoPtsRawValue: UInt64 = 0x8000000000000000
                    let avNoPtsValue = unsafeBitCast(avNoPtsRawValue, to: Int64.self)
                    let packetPts = packet.packet.pts == avNoPtsValue ? packet.packet.dts : packet.packet.pts
                    
                    let pts = CMTimeMake(packetPts, videoStream.timebase.timescale)
                    let dts = CMTimeMake(packet.packet.dts, videoStream.timebase.timescale)
                    
                    let duration: CMTime
                    
                    let frameDuration = packet.packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(frameDuration * videoStream.timebase.value, videoStream.timebase.timescale)
                    } else {
                        duration = videoStream.fps
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .video, packet: &packet.packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                    
                    if videoTimestamp == nil || videoTimestamp! < CMTimeGetSeconds(pts) {
                        videoTimestamp = CMTimeGetSeconds(pts)
                    }
                } else if let audioStream = initializedState.audioStream, Int(packet.packet.stream_index) == audioStream.index {
                    let avNoPtsRawValue: UInt64 = 0x8000000000000000
                    let avNoPtsValue = unsafeBitCast(avNoPtsRawValue, to: Int64.self)
                    let packetPts = packet.packet.pts == avNoPtsValue ? packet.packet.dts : packet.packet.pts
                    
                    let pts = CMTimeMake(packetPts, audioStream.timebase.timescale)
                    let dts = CMTimeMake(packet.packet.dts, audioStream.timebase.timescale)
                    
                    let duration: CMTime
                    
                    let frameDuration = packet.packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(frameDuration * audioStream.timebase.value, audioStream.timebase.timescale)
                    } else {
                        duration = audioStream.fps
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .audio, packet: &packet.packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                    
                    if audioTimestamp == nil || audioTimestamp! < CMTimeGetSeconds(pts) {
                        audioTimestamp = CMTimeGetSeconds(pts)
                    }
                }
            } else {
                break
            }
        }
        
        return frames
    }
    
    func contextInfo() -> FFMpegMediaFrameSourceContextInfo? {
        if let initializedState = self.initializedState {
            var audioStreamContext: FFMpegMediaFrameSourceStreamContextInfo?
            var videoStreamContext: FFMpegMediaFrameSourceStreamContextInfo?
            
            if let audioStream = initializedState.audioStream {
                audioStreamContext = FFMpegMediaFrameSourceStreamContextInfo(duration: audioStream.duration, decoder: audioStream.decoder)
            }
            
            if let videoStream = initializedState.videoStream {
                videoStreamContext = FFMpegMediaFrameSourceStreamContextInfo(duration: videoStream.duration, decoder: videoStream.decoder)
            }
            
            return FFMpegMediaFrameSourceContextInfo(audioStream: audioStreamContext, videoStream: videoStreamContext)
        }
        return nil
    }
    
    func seek(timestamp: Double, completed: (FFMpegMediaFrameSourceDescriptionSet, CMTime) -> Void) {
        if let initializedState = self.initializedState {
            self.packetQueue.removeAll()
            
            for stream in [initializedState.videoStream, initializedState.audioStream] {
                if let stream = stream {
                    let pts = CMTimeMakeWithSeconds(timestamp, stream.timebase.timescale)
                    av_seek_frame(initializedState.avFormatContext, Int32(stream.index), pts.value, AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_FRAME)
                    break
                }
            }
            
            var audioDescription: FFMpegMediaFrameSourceDescription?
            var videoDescription: FFMpegMediaFrameSourceDescription?
            
            if let audioStream = initializedState.audioStream {
                audioDescription = FFMpegMediaFrameSourceDescription(duration: audioStream.duration, decoder: audioStream.decoder)
            }
            
            if let videoStream = initializedState.videoStream {
                videoDescription = FFMpegMediaFrameSourceDescription(duration: videoStream.duration, decoder: videoStream.decoder)
            }
            
            let actualPts: CMTime
            if let packet = self.readPacketInternal() {
                self.packetQueue.append(packet)
                if let videoStream = initializedState.videoStream, Int(packet.packet.stream_index) == videoStream.index {
                    actualPts = CMTimeMake(packet.pts, videoStream.timebase.timescale)
                } else if let audioStream = initializedState.audioStream, Int(packet.packet.stream_index) == audioStream.index {
                    actualPts = CMTimeMake(packet.pts, audioStream.timebase.timescale)
                } else {
                    actualPts = CMTimeMake(0, 1)
                }
            } else {
                actualPts = CMTimeMake(0, 1)
            }
            
            completed(FFMpegMediaFrameSourceDescriptionSet(audio: audioDescription, video: videoDescription), actualPts)
        }
    }
}
