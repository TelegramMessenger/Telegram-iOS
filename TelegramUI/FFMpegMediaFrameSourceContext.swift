import Foundation
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramUIPrivateModule
import TelegramCore

private struct StreamContext {
    let index: Int
    let codecContext: UnsafeMutablePointer<AVCodecContext>?
    let fps: CMTime
    let timebase: CMTime
    let duration: CMTime
    let decoder: MediaTrackFrameDecoder
    let rotationAngle: Double
    let aspect: Double
}

struct FFMpegMediaFrameSourceDescription {
    let duration: CMTime
    let decoder: MediaTrackFrameDecoder
    let rotationAngle: Double
    let aspect: Double
}

struct FFMpegMediaFrameSourceDescriptionSet {
    let audio: FFMpegMediaFrameSourceDescription?
    let video: FFMpegMediaFrameSourceDescription?
}

private final class InitializedState {
    fileprivate let avIoContext: UnsafeMutablePointer<AVIOContext>
    fileprivate let avFormatContext: UnsafeMutablePointer<AVFormatContext>
    
    fileprivate let audioStream: StreamContext?
    fileprivate let videoStream: StreamContext?
    
    init(avIoContext: UnsafeMutablePointer<AVIOContext>, avFormatContext: UnsafeMutablePointer<AVFormatContext>, audioStream: StreamContext?, videoStream: StreamContext?) {
        self.avIoContext = avIoContext
        self.avFormatContext = avFormatContext
        self.audioStream = audioStream
        self.videoStream = videoStream
    }
    
    deinit {
        let avIoContext = Optional(self.avIoContext)
        if self.avIoContext.pointee.buffer != nil {
            av_free(self.avIoContext.pointee.buffer)
        }
        av_free(avIoContext)
        
        var avFormatContext = Optional(self.avFormatContext)
        avformat_close_input(&avFormatContext)
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

private func readPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    let context = Unmanaged<FFMpegMediaFrameSourceContext>.fromOpaque(userData!).takeUnretainedValue()
    guard let postbox = context.postbox, let resourceReference = context.resourceReference, let streamable = context.streamable else {
        return 0
    }
    
    var fetchedCount: Int32 = 0
    
    var fetchedData: Data?
    
    if streamable {
        let data: Signal<Data, NoError>
        let resourceSize: Int = resourceReference.resource.size ?? Int(Int32.max - 1)
        let readCount = min(resourceSize - context.readingOffset, Int(bufferSize))
        data = postbox.mediaBox.resourceData(resourceReference.resource, size: resourceSize, in: context.readingOffset ..< (context.readingOffset + readCount), mode: .complete)
        let semaphore = DispatchSemaphore(value: 0)
        if readCount == 0 {
            fetchedData = Data()
        } else {
            let disposable = data.start(next: { data in
                if data.count == readCount {
                    fetchedData = data
                    semaphore.signal()
                }
            })
            semaphore.wait()
            disposable.dispose()
        }
    } else {
        let data = postbox.mediaBox.resourceData(resourceReference.resource, pathExtension: nil, option: .complete(waitUntilFetchStatus: false))
        let semaphore = DispatchSemaphore(value: 0)
        let readingOffset = context.readingOffset
        let disposable = data.start(next: { next in
            if next.complete {
                let readCount = max(0, min(next.size - readingOffset, Int(bufferSize)))
                let range = readingOffset ..< (readingOffset + readCount)
                
                let fd = open(next.path, O_RDONLY, S_IRUSR)
                if fd >= 0 {
                    lseek(fd, off_t(range.lowerBound), SEEK_SET)
                    var data = Data(count: readCount)
                    data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                        let readBytes = read(fd, bytes, readCount)
                        assert(readBytes <= readCount)
                    }
                    fetchedData = data
                    close(fd)
                }
                semaphore.signal()
            }
        })
        semaphore.wait()
        disposable.dispose()
    }
    if let fetchedData = fetchedData {
        fetchedData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            memcpy(buffer, bytes, fetchedData.count)
        }
        fetchedCount = Int32(fetchedData.count)
        context.readingOffset += Int(fetchedCount)
    }
    
    return fetchedCount
}

private func seekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<FFMpegMediaFrameSourceContext>.fromOpaque(userData!).takeUnretainedValue()
    guard let postbox = context.postbox, let resourceReference = context.resourceReference, let streamable = context.streamable, let statsCategory = context.statsCategory else {
        return 0
    }
    
    var result: Int64 = offset
    
    let resourceSize: Int
    if let size = resourceReference.resource.size {
        resourceSize = size
    } else {
        if !streamable {
            var resultSize: Int = Int(Int32.max - 1)
            let data = postbox.mediaBox.resourceData(resourceReference.resource, pathExtension: nil, option: .complete(waitUntilFetchStatus: false))
            let semaphore = DispatchSemaphore(value: 0)
            let disposable = data.start(next: { next in
                if next.complete {
                    resultSize = Int(next.size)
                    semaphore.signal()
                }
            })
            semaphore.wait()
            disposable.dispose()
            resourceSize = resultSize
        } else {
            resourceSize = Int(Int32.max - 1)
        }
    }
    
    if (whence & AVSEEK_SIZE) != 0 {
        result = Int64(resourceSize == Int(Int32.max - 1) ? -1 : resourceSize)
    } else {
        context.readingOffset = Int(min(Int64(resourceSize), offset))
        
        if context.readingOffset != context.requestedDataOffset {
            context.requestedDataOffset = context.readingOffset
            
            if context.readingOffset >= resourceSize {
                context.fetchedDataDisposable.set(nil)
                context.requestedCompleteFetch = false
            } else {
                if streamable {
                    context.fetchedDataDisposable.set(fetchedMediaResource(postbox: postbox, reference: resourceReference, range: context.readingOffset ..< resourceSize, statsCategory: statsCategory, preferBackgroundReferenceRevalidation: streamable).start())
                } else if !context.requestedCompleteFetch && context.fetchAutomatically {
                    context.requestedCompleteFetch = true
                    context.fetchedDataDisposable.set(fetchedMediaResource(postbox: postbox, reference: resourceReference, statsCategory: statsCategory, preferBackgroundReferenceRevalidation: streamable).start())
                }
            }
        }
    }
    
    return result
}

final class FFMpegMediaFrameSourceContext: NSObject {
    private let thread: Thread
    
    var closed = false
    
    fileprivate var postbox: Postbox?
    fileprivate var resourceReference: MediaResourceReference?
    fileprivate var streamable: Bool?
    fileprivate var statsCategory: MediaResourceStatsCategory?
    
    private let ioBufferSize = 64 * 1024
    fileprivate var readingOffset = 0
    
    fileprivate var requestedDataOffset: Int?
    fileprivate let fetchedDataDisposable = MetaDisposable()
    fileprivate var requestedCompleteFetch = false
    
    fileprivate var readingError = false
    
    private var initializedState: InitializedState?
    private var packetQueue: [FFMpegPacket] = []
    
    private var preferSoftwareDecoding: Bool = false
    fileprivate var fetchAutomatically: Bool = true
    
    init(thread: Thread) {
        self.thread = thread
    }
    
    deinit {
        assert(Thread.current === self.thread)
        
        fetchedDataDisposable.dispose()
    }
    
    func initializeState(postbox: Postbox, resourceReference: MediaResourceReference, streamable: Bool, video: Bool, preferSoftwareDecoding: Bool, fetchAutomatically: Bool) {
        if self.readingError || self.initializedState != nil {
            return
        }
        
        let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
        
        self.postbox = postbox
        self.resourceReference = resourceReference
        self.streamable = streamable
        self.statsCategory = video ? .video : .audio
        self.preferSoftwareDecoding = preferSoftwareDecoding
        self.fetchAutomatically = fetchAutomatically
        
        let resourceSize: Int = resourceReference.resource.size ?? Int(Int32.max - 1)
        
        if streamable {
            self.fetchedDataDisposable.set(fetchedMediaResource(postbox: postbox, reference: resourceReference, range: 0 ..< resourceSize, statsCategory: self.statsCategory ?? .generic, preferBackgroundReferenceRevalidation: streamable).start())
        } else if !self.requestedCompleteFetch && self.fetchAutomatically {
            self.requestedCompleteFetch = true
            self.fetchedDataDisposable.set(fetchedMediaResource(postbox: postbox, reference: resourceReference, statsCategory: self.statsCategory ?? .generic, preferBackgroundReferenceRevalidation: streamable).start())
        }
        
        var avFormatContextRef = avformat_alloc_context()
        guard let avFormatContext = avFormatContextRef else {
            self.readingError = true
            return
        }
        
        let avIoBuffer = av_malloc(self.ioBufferSize)!
        let avIoContextRef = avio_alloc_context(avIoBuffer.assumingMemoryBound(to: UInt8.self), Int32(self.ioBufferSize), 0, Unmanaged.passUnretained(self).toOpaque(), readPacketCallback, nil, seekCallback)
        
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
                
                if self.preferSoftwareDecoding {
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
                                    
                                    videoStream = StreamContext(index: streamIndex, codecContext: codecContext, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegMediaVideoFrameDecoder(codecContext: codecContext), rotationAngle: rotationAngle, aspect: aspect)
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
                } else if codecPar.pointee.codec_id == AV_CODEC_ID_H264 {
                    if let videoFormat = FFMpegMediaFrameSourceContextHelpers.createFormatDescriptionFromAVCCodecData(UInt32(kCMVideoCodecType_H264), codecPar.pointee.width, codecPar.pointee.height, codecPar.pointee.extradata, codecPar.pointee.extradata_size) {
                        let (fps, timebase) = FFMpegMediaFrameSourceContextHelpers.streamFpsAndTimeBase(stream: avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!, defaultTimeBase: CMTimeMake(1, 1000))
                        
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
                        
                        videoStream = StreamContext(index: streamIndex, codecContext: nil, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegMediaPassthroughVideoFrameDecoder(videoFormat: videoFormat, rotationAngle: rotationAngle), rotationAngle: rotationAngle, aspect: aspect)
                        break
                    }
                } else if codecPar.pointee.codec_id == AV_CODEC_ID_HEVC {
                    if let videoFormat = FFMpegMediaFrameSourceContextHelpers.createFormatDescriptionFromHEVCCodecData(UInt32(kCMVideoCodecType_HEVC), codecPar.pointee.width, codecPar.pointee.height, codecPar.pointee.extradata, codecPar.pointee.extradata_size) {
                        let (fps, timebase) = FFMpegMediaFrameSourceContextHelpers.streamFpsAndTimeBase(stream: avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!, defaultTimeBase: CMTimeMake(1, 1000))
                        
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
                        
                        videoStream = StreamContext(index: streamIndex, codecContext: nil, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegMediaPassthroughVideoFrameDecoder(videoFormat: videoFormat, rotationAngle: rotationAngle), rotationAngle: rotationAngle, aspect: aspect)
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
                            
                            audioStream = StreamContext(index: streamIndex, codecContext: codecContext, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegAudioFrameDecoder(codecContext: codecContext), rotationAngle: 0.0, aspect: 1.0)
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
    
    func takeFrames(until: Double) -> (frames: [MediaTrackDecodableFrame], endOfStream: Bool) {
        if self.readingError {
            return ([], true)
        }
        
        guard let initializedState = self.initializedState else {
            return ([], true)
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
        var endOfStream = false
        
        while !self.readingError && ((videoTimestamp == nil || videoTimestamp!.isLess(than: until)) || (audioTimestamp == nil || audioTimestamp!.isLess(than: until))) {
            
            if let packet = self.readPacket() {
                if let videoStream = initializedState.videoStream, Int(packet.packet.stream_index) == videoStream.index {
                    let avNoPtsRawValue: UInt64 = 0x8000000000000000
                    let avNoPtsValue = Int64(bitPattern: avNoPtsRawValue)
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
                    
                    let frame = MediaTrackDecodableFrame(type: .video, packet: packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                    
                    if videoTimestamp == nil || videoTimestamp! < CMTimeGetSeconds(pts) {
                        videoTimestamp = CMTimeGetSeconds(pts)
                    }
                } else if let audioStream = initializedState.audioStream, Int(packet.packet.stream_index) == audioStream.index {
                    let avNoPtsRawValue: UInt64 = 0x8000000000000000
                    let avNoPtsValue = Int64(bitPattern: avNoPtsRawValue)
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
                    
                    let frame = MediaTrackDecodableFrame(type: .audio, packet: packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                    
                    if audioTimestamp == nil || audioTimestamp! < CMTimeGetSeconds(pts) {
                        audioTimestamp = CMTimeGetSeconds(pts)
                    }
                }
            } else {
                endOfStream = true
                break
            }
        }
        
        return (frames, endOfStream)
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
                audioDescription = FFMpegMediaFrameSourceDescription(duration: audioStream.duration, decoder: audioStream.decoder, rotationAngle: 0.0, aspect: 1.0)
            }
            
            if let videoStream = initializedState.videoStream {
                videoDescription = FFMpegMediaFrameSourceDescription(duration: videoStream.duration, decoder: videoStream.decoder, rotationAngle: videoStream.rotationAngle, aspect: videoStream.aspect)
            }
            
            var actualPts: CMTime = CMTimeMake(0, 1)
            for _ in 0 ..< 24 {
                if let packet = self.readPacketInternal() {
                    if let videoStream = initializedState.videoStream, Int(packet.packet.stream_index) == videoStream.index {
                        self.packetQueue.append(packet)
                        actualPts = CMTimeMake(packet.pts, videoStream.timebase.timescale)
                        break
                    } else if let audioStream = initializedState.audioStream, Int(packet.packet.stream_index) == audioStream.index {
                        self.packetQueue.append(packet)
                        actualPts = CMTimeMake(packet.pts, audioStream.timebase.timescale)
                        break
                    }
                } else {
                    break
                }
            }
            
            completed(FFMpegMediaFrameSourceDescriptionSet(audio: audioDescription, video: videoDescription), actualPts)
        }
    }
}
