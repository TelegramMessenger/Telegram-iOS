import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import FFMpegBinding
import RangeSet
import CoreMedia

private func FFMpegLookaheadReader_readPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    let context = Unmanaged<FFMpegLookaheadReader>.fromOpaque(userData!).takeUnretainedValue()
    
    let readCount = min(256 * 1024, Int64(bufferSize))
    let requestRange: Range<Int64> = context.readingOffset ..< (context.readingOffset + readCount)
    
    var fetchedData: Data?
    let fetchDisposable = MetaDisposable()
    
    let semaphore = DispatchSemaphore(value: 0)
    let disposable = context.params.getDataInRange(requestRange, { data in
        if let data {
            fetchedData = data
            semaphore.signal()
        }
    })
    var isCancelled = false
    let cancelDisposable = context.params.cancel.start(next: { _ in
        isCancelled = true
        semaphore.signal()
    })
    semaphore.wait()
    
    if isCancelled {
        context.isCancelled = true
    }
    
    disposable.dispose()
    cancelDisposable.dispose()
    fetchDisposable.dispose()
    
    if let fetchedData = fetchedData {
        fetchedData.withUnsafeBytes { byteBuffer -> Void in
            guard let bytes = byteBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            memcpy(buffer, bytes, fetchedData.count)
        }
        let fetchedCount = Int32(fetchedData.count)
        //print("Fetched from \(context.readingOffset) (\(fetchedCount) bytes)")
        context.setReadingOffset(offset: context.readingOffset + Int64(fetchedCount))
        if fetchedCount == 0 {
            return FFMPEG_CONSTANT_AVERROR_EOF
        }
        return fetchedCount
    } else {
        return FFMPEG_CONSTANT_AVERROR_EOF
    }
}

private func FFMpegLookaheadReader_seekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<FFMpegLookaheadReader>.fromOpaque(userData!).takeUnretainedValue()
    if (whence & FFMPEG_AVSEEK_SIZE) != 0 {
        return context.params.size
    } else {
        context.setReadingOffset(offset: offset)
        
        return offset
    }
}

private func range(_ outer: Range<Int64>, fullyContains inner: Range<Int64>) -> Bool {
    return inner.lowerBound >= outer.lowerBound && inner.upperBound <= outer.upperBound
}

private final class FFMpegLookaheadReader {
    let params: FFMpegLookaheadThread.Params
    
    var avIoContext: FFMpegAVIOContext?
    var avFormatContext: FFMpegAVFormatContext?
    
    var audioStream: FFMpegFileReader.StreamInfo?
    var videoStream: FFMpegFileReader.StreamInfo?
    
    var seekInfo: FFMpegLookahead.State.Seek?
    var maxReadPts: FFMpegLookahead.State.Seek?
    var audioStreamState: FFMpegLookahead.StreamState?
    var videoStreamState: FFMpegLookahead.StreamState?
    
    var reportedState: FFMpegLookahead.State?
    
    var readingOffset: Int64 = 0
    var isCancelled: Bool = false
    var isEnded: Bool = false
    
    private var currentFetchRange: Range<Int64>?
    private var currentFetchDisposable: Disposable?
    
    var currentTimestamp: Double?
    
    init?(params: FFMpegLookaheadThread.Params) {
        self.params = params
        
        let ioBufferSize = 64 * 1024
        
        guard let avIoContext = FFMpegAVIOContext(bufferSize: Int32(ioBufferSize), opaqueContext: Unmanaged.passUnretained(self).toOpaque(), readPacket: FFMpegLookaheadReader_readPacketCallback, writePacket: nil, seek: FFMpegLookaheadReader_seekCallback, isSeekable: true) else {
            return nil
        }
        self.avIoContext = avIoContext
        
        let avFormatContext = FFMpegAVFormatContext()
        avFormatContext.setIO(avIoContext)
        
        self.setReadingOffset(offset: 0)
        
        if !avFormatContext.openInput(withDirectFilePath: nil) {
            return nil
        }
        if !avFormatContext.findStreamInfo() {
            return nil
        }
        
        self.avFormatContext = avFormatContext
        
        var audioStream: FFMpegFileReader.StreamInfo?
        var videoStream: FFMpegFileReader.StreamInfo?
        
        for streamType in 0 ..< 2 {
            let isVideo = streamType == 0
            for streamIndexNumber in avFormatContext.streamIndices(for: isVideo ? FFMpegAVFormatStreamTypeVideo : FFMpegAVFormatStreamTypeAudio) {
                let streamIndex = streamIndexNumber.int32Value
                if avFormatContext.isAttachedPic(atStreamIndex: streamIndex) {
                    continue
                }
                
                let codecId = avFormatContext.codecId(atStreamIndex: streamIndex)
                
                let fpsAndTimebase = avFormatContext.fpsAndTimebase(forStreamIndex: streamIndex, defaultTimeBase: CMTimeMake(value: 1, timescale: 40000))
                let (fps, timebase) = (fpsAndTimebase.fps, fpsAndTimebase.timebase)
                
                let startTime: CMTime
                let rawStartTime = avFormatContext.startTime(atStreamIndex: streamIndex)
                if rawStartTime == Int64(bitPattern: 0x8000000000000000 as UInt64) {
                    startTime = CMTime(value: 0, timescale: timebase.timescale)
                } else {
                    startTime = CMTimeMake(value: rawStartTime, timescale: timebase.timescale)
                }
                var duration = CMTimeMake(value: avFormatContext.duration(atStreamIndex: streamIndex), timescale: timebase.timescale)
                duration = CMTimeMaximum(CMTime(value: 0, timescale: duration.timescale), CMTimeSubtract(duration, startTime))
                
                //let metrics = avFormatContext.metricsForStream(at: streamIndex)
                //let rotationAngle: Double = metrics.rotationAngle
                //let aspect = Double(metrics.width) / Double(metrics.height)
                
                let stream = FFMpegFileReader.StreamInfo(
                    index: streamIndexNumber.intValue,
                    codecId: codecId,
                    startTime: startTime,
                    duration: duration,
                    timeBase: timebase.value,
                    timeScale: timebase.timescale,
                    fps: fps
                )
                
                if isVideo {
                    videoStream = stream
                } else {
                    audioStream = stream
                }
            }
        }
        
        self.audioStream = audioStream
        self.videoStream = videoStream
        
        if let preferredStream = self.videoStream ?? self.audioStream {
            let pts = CMTimeMakeWithSeconds(params.seekToTimestamp, preferredTimescale: preferredStream.timeScale)
            self.seekInfo = FFMpegLookahead.State.Seek(streamIndex: preferredStream.index, pts: pts.value)
            avFormatContext.seekFrame(forStreamIndex: Int32(preferredStream.index), pts: pts.value, positionOnKeyframe: true)
        }
        
        self.updateCurrentTimestamp()
    }
    
    deinit {
        self.currentFetchDisposable?.dispose()
    }
    
    func setReadingOffset(offset: Int64) {
        self.readingOffset = offset
        
        let readRange: Range<Int64> = offset ..< (offset + 512 * 1024)
        if !self.params.isDataCachedInRange(readRange) {
            if let currentFetchRange = self.currentFetchRange {
                if currentFetchRange.overlaps(readRange) {
                    if !range(currentFetchRange, fullyContains: readRange) {
                        self.setFetchRange(range: currentFetchRange.lowerBound ..< max(currentFetchRange.upperBound, readRange.upperBound + 2 * 1024 * 1024))
                    }
                } else {
                    self.setFetchRange(range: offset ..< (offset + 2 * 1024 * 1024))
                }
            } else {
                self.setFetchRange(range: offset ..< (offset + 2 * 1024 * 1024))
            }
        }
    }
    
    private func setFetchRange(range: Range<Int64>) {
        if self.currentFetchRange != range {
            self.currentFetchRange = range
            
            self.currentFetchDisposable?.dispose()
            self.currentFetchDisposable = self.params.fetchInRange(range)
        }
    }
    
    func updateCurrentTimestamp() {
        self.currentTimestamp = self.params.currentTimestamp.with({ $0 })
        
        self.updateReadIfNeeded()
    }
    
    private func updateReadIfNeeded() {
        guard let avFormatContext = self.avFormatContext else {
            return
        }
        guard let currentTimestamp = self.currentTimestamp else {
            return
        }
        
        let maxPtsSeconds = max(self.params.seekToTimestamp, currentTimestamp) + self.params.lookaheadDuration
        
        var currentAudioPtsSecondsAdvanced: Double = 0.0
        var currentVideoPtsSecondsAdvanced: Double = 0.0
        
        let packet = FFMpegPacket()
        while !self.isCancelled && !self.isEnded {
            var audioAlreadyRead: Bool = false
            var videoAlreadyRead: Bool = false
            
            if let audioStreamState = self.audioStreamState {
                if audioStreamState.readableToTime.seconds >= maxPtsSeconds {
                    audioAlreadyRead = true
                }
            } else if self.audioStream == nil {
                audioAlreadyRead = true
            }
            
            if let videoStreamState = self.videoStreamState {
                if videoStreamState.readableToTime.seconds >= maxPtsSeconds {
                    videoAlreadyRead = true
                }
            } else if self.videoStream == nil {
                videoAlreadyRead = true
            }
            
            if audioAlreadyRead && videoAlreadyRead {
                break
            }
            
            if !avFormatContext.readFrame(into: packet) {
                self.isEnded = true
                break
            }
            
            self.maxReadPts = FFMpegLookahead.State.Seek(streamIndex: Int(packet.streamIndex), pts: packet.pts)
            
            if let audioStream = self.audioStream, Int(packet.streamIndex) == audioStream.index {
                let pts = CMTimeMake(value: packet.pts, timescale: audioStream.timeScale)
                if let audioStreamState = self.audioStreamState {
                    currentAudioPtsSecondsAdvanced += pts.seconds - audioStreamState.readableToTime.seconds
                }
                self.audioStreamState = FFMpegLookahead.StreamState(
                    info: audioStream,
                    readableToTime: pts
                )
            } else if let videoStream = self.videoStream, Int(packet.streamIndex) == videoStream.index {
                let pts = CMTimeMake(value: packet.pts, timescale: videoStream.timeScale)
                if let videoStreamState = self.videoStreamState {
                    currentVideoPtsSecondsAdvanced += pts.seconds - videoStreamState.readableToTime.seconds
                }
                self.videoStreamState = FFMpegLookahead.StreamState(
                    info: videoStream,
                    readableToTime: pts
                )
            }
            
            if min(currentAudioPtsSecondsAdvanced, currentVideoPtsSecondsAdvanced) >= 0.1 {
                self.reportStateIfNeeded()
            }
        }
        
        self.reportStateIfNeeded()
    }
    
    private func reportStateIfNeeded() {
        guard let seekInfo = self.seekInfo else {
            return
        }
        var stateIsFullyInitialised = true
        if self.audioStream != nil && self.audioStreamState == nil {
            stateIsFullyInitialised = false
        }
        if self.videoStream != nil && self.videoStreamState == nil {
            stateIsFullyInitialised = false
        }
        
        let state = FFMpegLookahead.State(
            seek: seekInfo,
            maxReadablePts: self.maxReadPts,
            audio: (stateIsFullyInitialised && self.maxReadPts != nil) ? self.audioStreamState : nil,
            video: (stateIsFullyInitialised && self.maxReadPts != nil) ? self.videoStreamState : nil,
            isEnded: self.isEnded
        )
        if self.reportedState != state {
            self.reportedState = state
            self.params.updateState(state)
        }
    }
}

private final class FFMpegLookaheadThread: NSObject {
    final class Params: NSObject {
        let seekToTimestamp: Double
        let lookaheadDuration: Double
        let updateState: (FFMpegLookahead.State) -> Void
        let fetchInRange: (Range<Int64>) -> Disposable
        let getDataInRange: (Range<Int64>, @escaping (Data?) -> Void) -> Disposable
        let isDataCachedInRange: (Range<Int64>) -> Bool
        let size: Int64
        let cancel: Signal<Void, NoError>
        let currentTimestamp: Atomic<Double?>
        
        init(
            seekToTimestamp: Double,
            lookaheadDuration: Double,
            updateState: @escaping (FFMpegLookahead.State) -> Void,
            fetchInRange: @escaping (Range<Int64>) -> Disposable,
            getDataInRange: @escaping (Range<Int64>, @escaping (Data?) -> Void) -> Disposable,
            isDataCachedInRange: @escaping (Range<Int64>) -> Bool,
            size: Int64,
            cancel: Signal<Void, NoError>,
            currentTimestamp: Atomic<Double?>
        ) {
            self.seekToTimestamp = seekToTimestamp
            self.lookaheadDuration = lookaheadDuration
            self.updateState = updateState
            self.fetchInRange = fetchInRange
            self.getDataInRange = getDataInRange
            self.isDataCachedInRange = isDataCachedInRange
            self.size = size
            self.cancel = cancel
            self.currentTimestamp = currentTimestamp
        }
    }
    
    @objc static func entryPoint(_ params: Params) {
        let runLoop = RunLoop.current
        
        let timer = Timer(fireAt: .distantFuture, interval: 0.0, target: FFMpegLookaheadThread.self, selector: #selector(FFMpegLookaheadThread.none), userInfo: nil, repeats: false)
        runLoop.add(timer, forMode: .common)
        
        Thread.current.threadDictionary["FFMpegLookaheadThread_reader"] = FFMpegLookaheadReader(params: params)
        
        while true {
            runLoop.run(mode: .default, before: .distantFuture)
            if Thread.current.threadDictionary["FFMpegLookaheadThread_stop"] != nil {
                break
            }
        }
        
        Thread.current.threadDictionary.removeObject(forKey: "FFMpegLookaheadThread_params")
    }
    
    @objc static func none() {
    }
    
    @objc static func stop() {
        Thread.current.threadDictionary["FFMpegLookaheadThread_stop"] = "true"
    }
    
    @objc static func updateCurrentTimestamp() {
        if let reader = Thread.current.threadDictionary["FFMpegLookaheadThread_reader"] as? FFMpegLookaheadReader {
            reader.updateCurrentTimestamp()
        }
    }
}

final class FFMpegLookahead {
    struct StreamState: Equatable {
        let info: FFMpegFileReader.StreamInfo
        let readableToTime: CMTime
        
        init(info: FFMpegFileReader.StreamInfo, readableToTime: CMTime) {
            self.info = info
            self.readableToTime = readableToTime
        }
    }
    
    struct State: Equatable {
        struct Seek: Equatable {
            var streamIndex: Int
            var pts: Int64
            
            init(streamIndex: Int, pts: Int64) {
                self.streamIndex = streamIndex
                self.pts = pts
            }
        }
        
        let seek: Seek
        let maxReadablePts: Seek?
        let audio: StreamState?
        let video: StreamState?
        let isEnded: Bool
        
        init(seek: Seek, maxReadablePts: Seek?, audio: StreamState?, video: StreamState?, isEnded: Bool) {
            self.seek = seek
            self.maxReadablePts = maxReadablePts
            self.audio = audio
            self.video = video
            self.isEnded = isEnded
        }
    }
    
    private let cancel = Promise<Void>()
    private let currentTimestamp = Atomic<Double?>(value: nil)
    private let thread: Thread
    
    init(
        seekToTimestamp: Double,
        lookaheadDuration: Double,
        updateState: @escaping (FFMpegLookahead.State) -> Void,
        fetchInRange: @escaping (Range<Int64>) -> Disposable,
        getDataInRange: @escaping (Range<Int64>, @escaping (Data?) -> Void) -> Disposable,
        isDataCachedInRange: @escaping (Range<Int64>) -> Bool,
        size: Int64
    ) {
        self.thread = Thread(
            target: FFMpegLookaheadThread.self,
            selector: #selector(FFMpegLookaheadThread.entryPoint(_:)),
            object: FFMpegLookaheadThread.Params(
                seekToTimestamp: seekToTimestamp,
                lookaheadDuration: lookaheadDuration,
                updateState: updateState,
                fetchInRange: fetchInRange,
                getDataInRange: getDataInRange,
                isDataCachedInRange: isDataCachedInRange,
                size: size,
                cancel: self.cancel.get(),
                currentTimestamp: self.currentTimestamp
            )
        )
        self.thread.name = "FFMpegLookahead"
        self.thread.start()
    }
    
    deinit {
        self.cancel.set(.single(Void()))
        FFMpegLookaheadThread.self.perform(#selector(FFMpegLookaheadThread.stop), on: self.thread, with: nil, waitUntilDone: false)
    }
    
    func updateCurrentTimestamp(timestamp: Double) {
        let _ = self.currentTimestamp.swap(timestamp)
        FFMpegLookaheadThread.self.perform(#selector(FFMpegLookaheadThread.updateCurrentTimestamp), on: self.thread, with: timestamp as NSNumber, waitUntilDone: false)
    }
}

final class ChunkMediaPlayerDirectFetchSourceImpl: ChunkMediaPlayerSourceImpl {
    private let resource: ChunkMediaPlayerV2.SourceDescription.ResourceDescription
    
    private let partsStateValue = Promise<ChunkMediaPlayerPartsState>()
    var partsState: Signal<ChunkMediaPlayerPartsState, NoError> {
        return self.partsStateValue.get()
    }
    
    private var resourceSizeDisposable: Disposable?
    private var completeFetchDisposable: Disposable?
    
    private var seekTimestamp: Double?
    private var currentLookaheadId: Int = 0
    private var lookahead: FFMpegLookahead?
    
    private var resolvedResourceSize: Int64?
    private var pendingSeek: (id: Int, position: Double)?
    
    init(resource: ChunkMediaPlayerV2.SourceDescription.ResourceDescription) {
        self.resource = resource
        
        if resource.fetchAutomatically {
            self.completeFetchDisposable = fetchedMediaResource(
                mediaBox: resource.postbox.mediaBox,
                userLocation: resource.userLocation,
                userContentType: resource.userContentType,
                reference: resource.reference,
                statsCategory: resource.statsCategory,
                preferBackgroundReferenceRevalidation: true
            ).startStrict()
        }
    }
    
    deinit {
        self.resourceSizeDisposable?.dispose()
        self.completeFetchDisposable?.dispose()
    }
    
    func seek(id: Int, position: Double) {
        if self.resource.size == 0 && self.resolvedResourceSize == nil {
            self.pendingSeek = (id, position)
            
            if self.resourceSizeDisposable == nil {
                self.resourceSizeDisposable = (self.resource.postbox.mediaBox.resourceData(self.resource.reference.resource, option: .complete(waitUntilFetchStatus: false))
                |> deliverOnMainQueue).start(next: { [weak self] data in
                    guard let self else {
                        return
                    }
                    if data.complete {
                        if self.resolvedResourceSize == nil {
                            self.resolvedResourceSize = data.size
                            
                            if let pendingSeek = self.pendingSeek {
                                self.seek(id: pendingSeek.id, position: pendingSeek.position)
                            }
                        }
                    }
                })
            }
            
            return
        }
        
        self.seekTimestamp = position
        
        self.currentLookaheadId += 1
        let lookaheadId = self.currentLookaheadId
        
        let resource = self.resource
        let resourceSize = self.resolvedResourceSize ?? Int64(resource.size)
        
        let updateState: (FFMpegLookahead.State) -> Void = { [weak self] state in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                if self.currentLookaheadId != lookaheadId {
                    return
                }
                guard let mainTrack = state.video ?? state.audio else {
                    self.partsStateValue.set(.single(ChunkMediaPlayerPartsState(
                        duration: nil,
                        content: .directReader(ChunkMediaPlayerPartsState.DirectReader(
                            id: id,
                            seekPosition: position,
                            availableUntilPosition: position,
                            bufferedUntilEnd: true,
                            impl: nil
                        ))
                    )))
                    
                    return
                }
                
                var minAvailableUntilPosition: Double?
                if let audio = state.audio {
                    if let minAvailableUntilPositionValue = minAvailableUntilPosition {
                        minAvailableUntilPosition = min(minAvailableUntilPositionValue, audio.readableToTime.seconds)
                    } else {
                        minAvailableUntilPosition = audio.readableToTime.seconds
                    }
                }
                if let video = state.video {
                    if let minAvailableUntilPositionValue = minAvailableUntilPosition {
                        minAvailableUntilPosition = min(minAvailableUntilPositionValue, video.readableToTime.seconds)
                    } else {
                        minAvailableUntilPosition = video.readableToTime.seconds
                    }
                }
                
                self.partsStateValue.set(.single(ChunkMediaPlayerPartsState(
                    duration: mainTrack.info.duration.seconds,
                    content: .directReader(ChunkMediaPlayerPartsState.DirectReader(
                        id: id,
                        seekPosition: position,
                        availableUntilPosition: minAvailableUntilPosition ?? position,
                        bufferedUntilEnd: state.isEnded,
                        impl: ChunkMediaPlayerPartsState.DirectReader.Impl(
                            video: state.video.flatMap { media -> ChunkMediaPlayerPartsState.DirectReader.Stream? in
                                guard let maxReadablePts = state.maxReadablePts else {
                                    return nil
                                }
                                
                                return ChunkMediaPlayerPartsState.DirectReader.Stream(
                                    mediaBox: resource.postbox.mediaBox,
                                    resource: resource.reference.resource,
                                    size: resourceSize,
                                    index: media.info.index,
                                    seek: (streamIndex: state.seek.streamIndex, pts: state.seek.pts),
                                    maxReadablePts: (streamIndex: maxReadablePts.streamIndex, pts: maxReadablePts.pts, isEnded: state.isEnded),
                                    codecName: resolveFFMpegCodecName(id: media.info.codecId)
                                )
                            },
                            audio: state.audio.flatMap { media -> ChunkMediaPlayerPartsState.DirectReader.Stream? in
                                guard let maxReadablePts = state.maxReadablePts else {
                                    return nil
                                }
                                return ChunkMediaPlayerPartsState.DirectReader.Stream(
                                    mediaBox: resource.postbox.mediaBox,
                                    resource: resource.reference.resource,
                                    size: resource.size,
                                    index: media.info.index,
                                    seek: (streamIndex: state.seek.streamIndex, pts: state.seek.pts),
                                    maxReadablePts: (streamIndex: maxReadablePts.streamIndex, pts: maxReadablePts.pts, isEnded: state.isEnded),
                                    codecName: resolveFFMpegCodecName(id: media.info.codecId)
                                )
                            }
                        )
                    ))
                )))
            }
        }
        
        self.lookahead = FFMpegLookahead(
            seekToTimestamp: position,
            lookaheadDuration: 10.0,
            updateState: updateState,
            fetchInRange: { range in
                return fetchedMediaResource(
                    mediaBox: resource.postbox.mediaBox,
                    userLocation: resource.userLocation,
                    userContentType: resource.userContentType,
                    reference: resource.reference,
                    range: (range, .elevated),
                    statsCategory: resource.statsCategory,
                    preferBackgroundReferenceRevalidation: true
                ).startStrict()
            },
            getDataInRange: { range, completion in
                return resource.postbox.mediaBox.resourceData(resource.reference.resource, size: resourceSize, in: range, mode: .complete).start(next: { result, isComplete in
                    completion(isComplete ? result : nil)
                })
            },
            isDataCachedInRange: { range in
                return resource.postbox.mediaBox.internal_resourceDataIsCached(
                    id: resource.reference.resource.id,
                    size: resourceSize,
                    in: range
                )
            },
            size: resourceSize
        )
    }
    
    func updatePlaybackState(seekTimestamp: Double, position: Double, isPlaying: Bool) {
        if self.seekTimestamp == seekTimestamp {
            self.lookahead?.updateCurrentTimestamp(timestamp: position)
        }
    }
}
