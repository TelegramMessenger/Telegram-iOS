import Foundation
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore
import FFMpegBinding

private struct StreamContext {
    let index: Int
    let codecContext: FFMpegAVCodecContext?
    let fps: CMTime
    let timebase: CMTime
    let startTime: CMTime
    let duration: CMTime
    let decoder: MediaTrackFrameDecoder
    let rotationAngle: Double
    let aspect: Double
}

struct FFMpegMediaFrameSourceDescription {
    let startTime: CMTime
    let duration: CMTime
    let decoder: MediaTrackFrameDecoder
    let rotationAngle: Double
    let aspect: Double
}

struct FFMpegMediaFrameSourceDescriptionSet {
    let audio: FFMpegMediaFrameSourceDescription?
    let video: FFMpegMediaFrameSourceDescription?
    let extraVideoFrames: [MediaTrackDecodableFrame]
}

private final class InitializedState {
    fileprivate let avIoContext: FFMpegAVIOContext?
    fileprivate let avFormatContext: FFMpegAVFormatContext
    
    fileprivate let audioStream: StreamContext?
    fileprivate let videoStream: StreamContext?
    
    init(avIoContext: FFMpegAVIOContext?, avFormatContext: FFMpegAVFormatContext, audioStream: StreamContext?, videoStream: StreamContext?) {
        self.avIoContext = avIoContext
        self.avFormatContext = avFormatContext
        self.audioStream = audioStream
        self.videoStream = videoStream
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

private var maxOffset: Int = 0

private func readPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    let context = Unmanaged<FFMpegMediaFrameSourceContext>.fromOpaque(userData!).takeUnretainedValue()
    guard let postbox = context.postbox, let resourceReference = context.resourceReference, let streamable = context.streamable else {
        return 0
    }
    
    var fetchedCount: Int32 = 0
    var fetchedData: Data?
    
    var resourceSize: Int64 = resourceReference.resource.size ?? (Int64.max - 1)
    if let limitedFileRange = context.limitedFileRange {
        resourceSize = min(resourceSize, limitedFileRange.upperBound)
    }
    let readCount = max(0, min(resourceSize - context.readingOffset, Int64(bufferSize)))
    let requestRange: Range<Int64> = context.readingOffset ..< (context.readingOffset + readCount)
    
    assert(readCount < 16 * 1024 * 1024)
    
    if let maximumFetchSize = context.maximumFetchSize {
        context.touchedRanges.insert(integersIn: Int(requestRange.lowerBound) ..< Int(requestRange.upperBound))
        var totalCount = 0
        for range in context.touchedRanges.rangeView {
            totalCount += range.count
        }
        if totalCount > maximumFetchSize {
            context.readingError = true
            return FFMPEG_CONSTANT_AVERROR_EOF
        }
    }
    
    if streamable {
        let data: Signal<(Data, Bool), NoError>
        data = postbox.mediaBox.resourceData(resourceReference.resource, size: resourceSize, in: requestRange, mode: .complete)
        if readCount == 0 {
            fetchedData = Data()
        } else {
            if let tempFilePath = context.tempFilePath, let fileData = (try? Data(contentsOf: URL(fileURLWithPath: tempFilePath), options: .mappedRead))?.subdata(in: Int(requestRange.lowerBound) ..< Int(requestRange.upperBound)) {
                fetchedData = fileData
            } else {
                let semaphore = DispatchSemaphore(value: 0)
                let _ = context.currentSemaphore.swap(semaphore)
                var completedRequest = false
                let disposable = data.start(next: { result in
                    let (data, isComplete) = result
                    if data.count == readCount || isComplete {
                        precondition(data.count <= readCount)
                        fetchedData = data
                        completedRequest = true
                        semaphore.signal()
                    }
                })
                semaphore.wait()
                let _ = context.currentSemaphore.swap(nil)
                disposable.dispose()
                if !completedRequest {
                    context.readingError = true
                    return FFMPEG_CONSTANT_AVERROR_EOF
                }
            }
        }
    } else {
        if let tempFilePath = context.tempFilePath, let fileSize = fileSize(tempFilePath) {
            let fd = open(tempFilePath, O_RDONLY, S_IRUSR)
            if fd >= 0 {
                let readingOffset = context.readingOffset
                let readCount = max(0, min(fileSize - readingOffset, Int64(bufferSize)))
                let range = readingOffset ..< (readingOffset + readCount)
                assert(readCount < 16 * 1024 * 1024)
                
                lseek(fd, off_t(range.lowerBound), SEEK_SET)
                var data = Data(count: Int(readCount))
                data.withUnsafeMutableBytes { bytes -> Void in
                    precondition(bytes.baseAddress != nil)
                    let readBytes = read(fd, bytes.baseAddress, Int(readCount))
                    precondition(readBytes <= readCount)
                }
                fetchedData = data
                close(fd)
            }
        } else {
            let data = postbox.mediaBox.resourceData(resourceReference.resource, pathExtension: nil, option: .complete(waitUntilFetchStatus: false))
            let semaphore = DispatchSemaphore(value: 0)
            let _ = context.currentSemaphore.swap(semaphore)
            let readingOffset = context.readingOffset
            var completedRequest = false
            let disposable = data.start(next: { next in
                if next.complete {
                    let readCount = max(0, min(next.size - readingOffset, Int64(bufferSize)))
                    let range = readingOffset ..< (readingOffset + readCount)
                    
                    assert(readCount < 16 * 1024 * 1024)
                    
                    let fd = open(next.path, O_RDONLY, S_IRUSR)
                    if fd >= 0 {
                        lseek(fd, off_t(range.lowerBound), SEEK_SET)
                        var data = Data(count: Int(readCount))
                        data.withUnsafeMutableBytes { bytes -> Void in
                            precondition(bytes.baseAddress != nil)
                            let readBytes = read(fd, bytes.baseAddress, Int(readCount))
                            assert(readBytes <= readCount)
                            precondition(readBytes <= readCount)
                        }
                        fetchedData = data
                        close(fd)
                    }
                    completedRequest = true
                    semaphore.signal()
                }
            })
            semaphore.wait()
            let _ = context.currentSemaphore.swap(nil)
            disposable.dispose()
            if !completedRequest {
                context.readingError = true
                return FFMPEG_CONSTANT_AVERROR_EOF
            }
        }
    }
    if let fetchedData = fetchedData {
        assert(fetchedData.count <= readCount)
        fetchedData.withUnsafeBytes { bytes -> Void in
            precondition(bytes.baseAddress != nil)
            memcpy(buffer, bytes.baseAddress, min(fetchedData.count, Int(readCount)))
        }
        fetchedCount = Int32(fetchedData.count)
        context.readingOffset += Int64(fetchedCount)
        
        if fetchedCount == 0 {
            return FFMPEG_CONSTANT_AVERROR_EOF
        }
    }
    
    if context.closed {
        context.readingError = true
        return FFMPEG_CONSTANT_AVERROR_EOF
    }
    return fetchedCount
}

private func seekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<FFMpegMediaFrameSourceContext>.fromOpaque(userData!).takeUnretainedValue()
    guard let postbox = context.postbox, let resourceReference = context.resourceReference, let streamable = context.streamable, let userLocation = context.userLocation, let userContentType = context.userContentType, let statsCategory = context.statsCategory else {
        return 0
    }
    
    var result: Int64 = offset
    
    var resourceSize: Int64
    if let size = resourceReference.resource.size {
        resourceSize = size
    } else {
        if !streamable {
            if let tempFilePath = context.tempFilePath, let fileSize = fileSize(tempFilePath) {
                resourceSize = fileSize
            } else {
                var resultSize: Int64 = Int64.max - 1
                let data = postbox.mediaBox.resourceData(resourceReference.resource, pathExtension: nil, option: .complete(waitUntilFetchStatus: false))
                let semaphore = DispatchSemaphore(value: 0)
                let _ = context.currentSemaphore.swap(semaphore)
                var completedRequest = false
                let disposable = data.start(next: { next in
                    if next.complete {
                        resultSize = next.size
                        completedRequest = true
                        semaphore.signal()
                    }
                })
                semaphore.wait()
                let _ = context.currentSemaphore.swap(nil)
                disposable.dispose()
                if !completedRequest {
                    context.readingError = true
                    return 0
                }
                resourceSize = resultSize
            }
        } else {
            resourceSize = Int64.max - 1
        }
    }
    if let limitedFileRange = context.limitedFileRange {
        resourceSize = min(resourceSize, limitedFileRange.upperBound)
    }
    
    if (whence & FFMPEG_AVSEEK_SIZE) != 0 {
        result = Int64(resourceSize == Int(Int32.max - 1) ? 0 : resourceSize)
    } else {
        context.readingOffset = min(Int64(resourceSize), offset)
        
        if context.readingOffset != context.requestedDataOffset {
            context.requestedDataOffset = context.readingOffset
            
            if context.readingOffset >= resourceSize {
                context.fetchedDataDisposable.set(nil)
            } else {
                if streamable {
                    if context.tempFilePath == nil {
                        let fetchRange: Range<Int64>?
                        if let limitedFileRange = context.limitedFileRange {
                            if context.readingOffset < limitedFileRange.upperBound {
                                fetchRange = context.readingOffset ..< limitedFileRange.upperBound
                            } else {
                                fetchRange = nil
                            }
                        } else {
                            fetchRange = context.readingOffset ..< Int64.max
                        }
                        if let fetchRange {
                            context.fetchedDataDisposable.set(fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: userLocation, userContentType: userContentType, reference: resourceReference, range: (fetchRange, .elevated), statsCategory: statsCategory, preferBackgroundReferenceRevalidation: streamable).start())
                        }
                    }
                } else if !context.requestedCompleteFetch && context.fetchAutomatically && context.limitedFileRange == nil {
                    context.requestedCompleteFetch = true
                    if context.tempFilePath == nil {
                        context.fetchedDataDisposable.set(fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: userLocation, userContentType: userContentType, reference: resourceReference, statsCategory: statsCategory, preferBackgroundReferenceRevalidation: streamable).start())
                    }
                }
            }
        }
    }
    
    if context.closed {
        context.readingError = true
        return 0
    }
    
    return result
}

final class FFMpegMediaFrameSourceContext: NSObject {
    private let thread: Thread
    
    var closed = false
    
    fileprivate var postbox: Postbox?
    fileprivate var userLocation: MediaResourceUserLocation?
    fileprivate var userContentType: MediaResourceUserContentType?
    fileprivate var resourceReference: MediaResourceReference?
    fileprivate var tempFilePath: String?
    fileprivate var limitedFileRange: Range<Int64>?
    fileprivate var streamable: Bool?
    fileprivate var statsCategory: MediaResourceStatsCategory?
    
    fileprivate var readingOffset: Int64 = 0
    
    fileprivate var requestedDataOffset: Int64?
    fileprivate let fetchedDataDisposable = MetaDisposable()
    fileprivate let keepDataDisposable = MetaDisposable()
    fileprivate let fetchedFullDataDisposable = MetaDisposable()
    fileprivate let autosaveDisposable = MetaDisposable()
    fileprivate var requestedCompleteFetch = false
    
    fileprivate var readingError = false {
        didSet {
            self.fetchedDataDisposable.dispose()
            self.fetchedFullDataDisposable.dispose()
            self.keepDataDisposable.dispose()
        }
    }
    
    private var initializedState: InitializedState?
    private var packetQueue: [FFMpegPacket] = []
    
    private var preferSoftwareDecoding: Bool = false
    fileprivate var fetchAutomatically: Bool = true
    fileprivate var maximumFetchSize: Int? = nil
    fileprivate var touchedRanges = IndexSet()
    
    let currentSemaphore = Atomic<DispatchSemaphore?>(value: nil)
    
    init(thread: Thread) {
        self.thread = thread
    }
    
    deinit {
        assert(Thread.current === self.thread)
        
        self.fetchedDataDisposable.dispose()
        self.fetchedFullDataDisposable.dispose()
        self.keepDataDisposable.dispose()
        self.autosaveDisposable.dispose()
    }
    
    func initializeState(postbox: Postbox, userLocation: MediaResourceUserLocation, resourceReference: MediaResourceReference, tempFilePath: String?, limitedFileRange: Range<Int64>?, streamable: Bool, isSeekable: Bool, video: Bool, preferSoftwareDecoding: Bool, fetchAutomatically: Bool, maximumFetchSize: Int?, storeAfterDownload: (() -> Void)?, isAudioVideoMessage: Bool) {
        if self.readingError || self.initializedState != nil {
            return
        }
        
        let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
        
        var streamable = streamable
        if limitedFileRange != nil {
            streamable = true
        }
        
        self.postbox = postbox
        self.resourceReference = resourceReference
        self.tempFilePath = tempFilePath
        self.limitedFileRange = limitedFileRange
        self.streamable = streamable
        self.statsCategory = video ? .video : .audio
        self.userLocation = userLocation
        self.userContentType = video ? .video : .audio
        switch resourceReference {
        case let .media(media, _):
            switch media {
            case .story:
                self.userContentType = .story
            default:
                break
            }
        default:
            break
        }
        self.preferSoftwareDecoding = preferSoftwareDecoding
        self.fetchAutomatically = fetchAutomatically
        self.maximumFetchSize = maximumFetchSize
        
        if self.tempFilePath == nil {
            self.keepDataDisposable.set(postbox.mediaBox.keepResource(id: resourceReference.resource.id).start())
        }
        
        if let storeAfterDownload = storeAfterDownload {
            self.autosaveDisposable.set((postbox.mediaBox.resourceData(resourceReference.resource)
            |> take(1)
            |> mapToSignal { initialData -> Signal<Bool, NoError> in
                if initialData.complete {
                    return .single(false)
                } else {
                    return postbox.mediaBox.resourceData(resourceReference.resource)
                    |> filter { $0.complete }
                    |> take(1)
                    |> map { _ -> Bool in return true }
                }
            }
            |> deliverOnMainQueue).start(next: { shouldSave in
                if shouldSave {
                    storeAfterDownload()
                }
            }))
        }
        
        if streamable {
            if self.tempFilePath == nil && limitedFileRange == nil {
                self.fetchedDataDisposable.set(fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: self.userLocation ?? .other, userContentType: self.userContentType ?? .other, reference: resourceReference, range: (0 ..< Int64.max, .elevated), statsCategory: self.statsCategory ?? .generic, preferBackgroundReferenceRevalidation: streamable).start())
            }
        } else if !self.requestedCompleteFetch && self.fetchAutomatically {
            self.requestedCompleteFetch = true
            if self.tempFilePath == nil {
                self.fetchedFullDataDisposable.set(fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: self.userLocation ?? .other, userContentType: self.userContentType ?? .other, reference: resourceReference, statsCategory: self.statsCategory ?? .generic, preferBackgroundReferenceRevalidation: streamable).start())
            }
        }
        
        var directFilePath: String?
        if !streamable && isAudioVideoMessage {
            let data = postbox.mediaBox.resourceData(resourceReference.resource, pathExtension: nil, option: .complete(waitUntilFetchStatus: false))
            let semaphore = DispatchSemaphore(value: 0)
            let _ = self.currentSemaphore.swap(semaphore)
            var resultFilePath: String?
            let disposable = data.start(next: { next in
                if next.complete {
                    resultFilePath = next.path
                    semaphore.signal()
                }
            })
            semaphore.wait()
            let _ = self.currentSemaphore.swap(nil)
            disposable.dispose()
            
            if let resultFilePath {
                directFilePath = resultFilePath
            } else {
                self.readingError = true
                return
            }
        }
        
        let avFormatContext = FFMpegAVFormatContext()
        
        var avIoContext: FFMpegAVIOContext?
        if directFilePath == nil {
            guard let avIoContextValue = FFMpegAVIOContext(bufferSize: 64 * 1024, opaqueContext: Unmanaged.passUnretained(self).toOpaque(), readPacket: readPacketCallback, writePacket: nil, seek: seekCallback, isSeekable: isSeekable) else {
                self.readingError = true
                return
            }
            avIoContext = avIoContextValue
            avFormatContext.setIO(avIoContextValue)
        }
        
        if !avFormatContext.openInput(withDirectFilePath: directFilePath) {
            self.readingError = true
            return
        }
        
        if !avFormatContext.findStreamInfo() {
            self.readingError = true;
            return
        }
        
        var videoStream: StreamContext?
        var audioStream: StreamContext?
        
        for streamIndexNumber in avFormatContext.streamIndices(for: FFMpegAVFormatStreamTypeVideo) {
            let streamIndex = streamIndexNumber.int32Value
            if avFormatContext.isAttachedPic(atStreamIndex: streamIndex) {
                continue
            }
            
            let codecId = avFormatContext.codecId(atStreamIndex: streamIndex)
            
            let fpsAndTimebase = avFormatContext.fpsAndTimebase(forStreamIndex: streamIndex, defaultTimeBase: CMTimeMake(value: 1, timescale: 40000))
            let (fps, timebase) = (fpsAndTimebase.fps, fpsAndTimebase.timebase)
            
            var duration = CMTimeMake(value: avFormatContext.duration(atStreamIndex: streamIndex), timescale: timebase.timescale)
            if !isSeekable {
                duration = CMTimeMake(value: Int64.min, timescale: duration.timescale)
            }
            
            let startTime: CMTime
            let rawStartTime = avFormatContext.startTime(atStreamIndex: streamIndex)
            if rawStartTime == Int64(bitPattern: 0x8000000000000000 as UInt64) {
                startTime = CMTime(value: 0, timescale: timebase.timescale)
            } else {
                startTime = CMTimeMake(value: rawStartTime, timescale: timebase.timescale)
            }
            
            let metrics = avFormatContext.metricsForStream(at: streamIndex)
            
            let rotationAngle: Double = metrics.rotationAngle
            let aspect = Double(metrics.width) / Double(metrics.height)
            
            if self.preferSoftwareDecoding {
                if let codec = FFMpegAVCodec.find(forId: codecId) {
                    let codecContext = FFMpegAVCodecContext(codec: codec)
                    if avFormatContext.codecParams(atStreamIndex: streamIndex, to: codecContext) {
                        if codecContext.open() {
                            videoStream = StreamContext(index: Int(streamIndex), codecContext: codecContext, fps: fps, timebase: timebase, startTime: startTime, duration: duration, decoder: FFMpegMediaVideoFrameDecoder(codecContext: codecContext), rotationAngle: rotationAngle, aspect: aspect)
                            break
                        }
                    }
                }
            } else {
                var videoFormatData: FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData?
                if codecId == FFMpegCodecIdMPEG4 {
                    videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_MPEG4Video, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                } else if codecId == FFMpegCodecIdH264 {
                    videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_H264, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                } else if codecId == FFMpegCodecIdHEVC {
                    videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_HEVC, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                } else if codecId == FFMpegCodecIdAV1 {
                    videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_AV1, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                }
                if let videoFormatData {
                    videoStream = StreamContext(index: Int(streamIndex), codecContext: nil, fps: fps, timebase: timebase, startTime: startTime, duration: duration, decoder: FFMpegMediaPassthroughVideoFrameDecoder(videoFormatData: videoFormatData, rotationAngle: rotationAngle), rotationAngle: rotationAngle, aspect: aspect)
                }
            }
        }
        
        for streamIndexNumber in avFormatContext.streamIndices(for: FFMpegAVFormatStreamTypeAudio) {
            let streamIndex = streamIndexNumber.int32Value
            let codecId = avFormatContext.codecId(atStreamIndex: streamIndex)
            
            var codec: FFMpegAVCodec?
            
            if codec == nil {
                codec = FFMpegAVCodec.find(forId: codecId)
            }
            
            if let codec = codec {
                let codecContext = FFMpegAVCodecContext(codec: codec)
                if avFormatContext.codecParams(atStreamIndex: streamIndex, to: codecContext) {
                    if codecContext.open() {
                        let fpsAndTimebase = avFormatContext.fpsAndTimebase(forStreamIndex: streamIndex, defaultTimeBase: CMTimeMake(value: 1, timescale: 40000))
                        let (fps, timebase) = (fpsAndTimebase.fps, fpsAndTimebase.timebase)
                        
                        var duration = CMTimeMake(value: avFormatContext.duration(atStreamIndex: streamIndex), timescale: timebase.timescale)
                        if !isSeekable {
                            duration = CMTimeMake(value: Int64.min, timescale: duration.timescale)
                        }
                        
                        let startTime: CMTime
                        let rawStartTime = avFormatContext.startTime(atStreamIndex: streamIndex)
                        if rawStartTime == Int64(bitPattern: 0x8000000000000000 as UInt64) {
                            startTime = CMTime(value: 0, timescale: timebase.timescale)
                        } else {
                            startTime = CMTimeMake(value: rawStartTime, timescale: timebase.timescale)
                        }
                        
                        audioStream = StreamContext(index: Int(streamIndex), codecContext: codecContext, fps: fps, timebase: timebase, startTime: startTime, duration: duration, decoder: FFMpegAudioFrameDecoder(codecContext: codecContext), rotationAngle: 0.0, aspect: 1.0)
                        break
                    }
                }
            }
        }
        
        self.initializedState = InitializedState(avIoContext: avIoContext, avFormatContext: avFormatContext, audioStream: audioStream, videoStream: videoStream)
        
        if streamable && limitedFileRange == nil {
            if self.tempFilePath == nil {
                self.fetchedFullDataDisposable.set(fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: self.userLocation ?? .other, userContentType: self.userContentType ?? .other, reference: resourceReference, range: (0 ..< Int64.max, .default), statsCategory: self.statsCategory ?? .generic, preferBackgroundReferenceRevalidation: streamable).start())
            }
            self.requestedCompleteFetch = true
        }
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
        if initializedState.avFormatContext.readFrame(into: packet) {
            return packet
        } else {
            return nil
        }
    }
    
    func takeFrames(until: Double, types: [MediaTrackFrameType]) -> (frames: [MediaTrackDecodableFrame], endOfStream: Bool) {
        if self.readingError {
            return ([], true)
        }
        
        guard let initializedState = self.initializedState else {
            return ([], true)
        }
        
        var videoTimestamp: Double?
        if initializedState.videoStream == nil || !types.contains(.video) {
            videoTimestamp = Double.infinity
        }
        
        var audioTimestamp: Double?
        if initializedState.audioStream == nil || !types.contains(.audio) {
            audioTimestamp = Double.infinity
        }
        
        var frames: [MediaTrackDecodableFrame] = []
        var endOfStream = false
        
        while !self.readingError && ((videoTimestamp == nil || videoTimestamp!.isLess(than: until)) || (audioTimestamp == nil || audioTimestamp!.isLess(than: until))) {
            if let packet = self.readPacket() {
                if let videoStream = initializedState.videoStream, Int(packet.streamIndex) == videoStream.index {
                    let frame = videoFrameFromPacket(packet, videoStream: videoStream)
                    frames.append(frame)
                    
                    if videoTimestamp == nil || videoTimestamp! < CMTimeGetSeconds(frame.pts) {
                        videoTimestamp = CMTimeGetSeconds(frame.pts)
                        //print("read video at \(CMTimeGetSeconds(frame.pts))")
                    }
                } else if let audioStream = initializedState.audioStream, Int(packet.streamIndex) == audioStream.index {
                    let packetPts = packet.pts
                    
                    let pts = CMTimeMake(value: packetPts, timescale: audioStream.timebase.timescale)
                    let dts = CMTimeMake(value: packet.dts, timescale: audioStream.timebase.timescale)
                    
                    let duration: CMTime
                    
                    let frameDuration = packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(value: frameDuration * audioStream.timebase.value, timescale: audioStream.timebase.timescale)
                    } else {
                        duration = audioStream.fps
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .audio, packet: packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                    
                    if audioTimestamp == nil || audioTimestamp! < CMTimeGetSeconds(pts) {
                        audioTimestamp = CMTimeGetSeconds(pts)
                        //print("read audio at \(CMTimeGetSeconds(pts))")
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
    
    func seek(timestamp: Double, completed: ((FFMpegMediaFrameSourceDescriptionSet, CMTime)?) -> Void) {
        if let initializedState = self.initializedState {
            self.packetQueue.removeAll()
            
            for stream in [initializedState.videoStream, initializedState.audioStream] {
                if let stream = stream {
                    let pts = CMTimeMakeWithSeconds(timestamp, preferredTimescale: stream.timebase.timescale)
                    #if DEBUG && false
                    let startTime = CFAbsoluteTimeGetCurrent()
                    #endif
                    initializedState.avFormatContext.seekFrame(forStreamIndex: Int32(stream.index), pts: pts.value, positionOnKeyframe: true)
                    #if DEBUG && false
                    print("Seek time: \(CFAbsoluteTimeGetCurrent() - startTime) s")
                    #endif
                    break
                }
            }
            
            var audioDescription: FFMpegMediaFrameSourceDescription?
            var videoDescription: FFMpegMediaFrameSourceDescription?
            
            if let audioStream = initializedState.audioStream {
                audioDescription = FFMpegMediaFrameSourceDescription(startTime: audioStream.startTime, duration: audioStream.duration, decoder: audioStream.decoder, rotationAngle: 0.0, aspect: 1.0)
            }
            
            if let videoStream = initializedState.videoStream {
                videoDescription = FFMpegMediaFrameSourceDescription(startTime: videoStream.startTime, duration: videoStream.duration, decoder: videoStream.decoder, rotationAngle: videoStream.rotationAngle, aspect: videoStream.aspect)
            }
            
            var actualPts: CMTime = CMTimeMake(value: 0, timescale: 1)
            var extraVideoFrames: [MediaTrackDecodableFrame] = []
            if timestamp.isZero || initializedState.videoStream == nil {
                for _ in 0 ..< 24 {
                    if let packet = self.readPacketInternal() {
                        if let videoStream = initializedState.videoStream, Int(packet.streamIndex) == videoStream.index {
                            self.packetQueue.append(packet)
                            let pts = CMTimeMake(value: packet.pts, timescale: videoStream.timebase.timescale)
                            actualPts = pts
                            break
                        } else if let audioStream = initializedState.audioStream, Int(packet.streamIndex) == audioStream.index {
                            self.packetQueue.append(packet)
                            let pts = CMTimeMake(value: packet.pts, timescale: audioStream.timebase.timescale)
                            actualPts = pts
                            break
                        }
                    } else {
                        break
                    }
                }
            } else if let videoStream = initializedState.videoStream {
                let targetPts = CMTimeMakeWithSeconds(Float64(timestamp), preferredTimescale: videoStream.timebase.timescale)
                let limitPts = CMTimeMakeWithSeconds(Float64(timestamp + 0.5), preferredTimescale: videoStream.timebase.timescale)
                var audioPackets: [FFMpegPacket] = []
                while !self.readingError {
                    if let packet = self.readPacket() {
                        if let videoStream = initializedState.videoStream, Int(packet.streamIndex) == videoStream.index {
                            let frame = videoFrameFromPacket(packet, videoStream: videoStream)
                            extraVideoFrames.append(frame)
                            
                            if CMTimeCompare(frame.dts, limitPts) >= 0 && CMTimeCompare(frame.pts, limitPts) >= 0 {
                                break
                            }
                        } else if let audioStream = initializedState.audioStream, Int(packet.streamIndex) == audioStream.index {
                            audioPackets.append(packet)
                        }
                    } else {
                        break
                    }
                }
                if !extraVideoFrames.isEmpty {
                    var closestFrame: MediaTrackDecodableFrame?
                    for frame in extraVideoFrames {
                        if CMTimeCompare(frame.pts, targetPts) >= 0 {
                            if let closestFrameValue = closestFrame {
                                if CMTimeCompare(frame.pts, closestFrameValue.pts) < 0 {
                                    closestFrame = frame
                                }
                            } else {
                                closestFrame = frame
                            }
                        }
                    }
                    if let closestFrame = closestFrame {
                        actualPts = closestFrame.pts
                    } else {
                        if let videoStream = initializedState.videoStream {
                            actualPts = videoStream.duration
                        } else {
                            actualPts = extraVideoFrames.last!.pts
                        }
                    }
                }
                if let audioStream = initializedState.audioStream {
                    self.packetQueue.append(contentsOf: audioPackets.filter({ packet in
                        let pts = CMTimeMake(value: packet.pts, timescale: audioStream.timebase.timescale)
                        if CMTimeCompare(pts, actualPts) >= 0 {
                            return true
                        } else {
                            return false
                        }
                    }))
                }
            }
            
            completed((FFMpegMediaFrameSourceDescriptionSet(audio: audioDescription, video: videoDescription, extraVideoFrames: extraVideoFrames), actualPts))
        } else {
            completed(nil)
        }
    }
    
    func close() {
        self.closed = true
    }
}

private func videoFrameFromPacket(_ packet: FFMpegPacket, videoStream: StreamContext) -> MediaTrackDecodableFrame {
    let packetPts = packet.pts
    
    let pts = CMTimeMake(value: packetPts, timescale: videoStream.timebase.timescale)
    let dts = CMTimeMake(value: packet.dts, timescale: videoStream.timebase.timescale)
    
    let duration: CMTime
    
    let frameDuration = packet.duration
    if frameDuration != 0 {
        duration = CMTimeMake(value: frameDuration * videoStream.timebase.value, timescale: videoStream.timebase.timescale)
    } else {
        duration = CMTimeMake(value: Int64(videoStream.fps.timescale), timescale: Int32(videoStream.fps.value))
    }
    
    return MediaTrackDecodableFrame(type: .video, packet: packet, pts: pts, dts: dts, duration: duration)
}
