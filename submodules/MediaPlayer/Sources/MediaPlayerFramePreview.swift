import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import FFMpegBinding
import VideoToolbox

public enum FramePreviewResult {
    case image(UIImage)
    case waitingForData
}

public protocol FramePreview {
    var generatedFrames: Signal<FramePreviewResult, NoError> { get }

    func generateFrame(at timestamp: Double)
    func cancelPendingFrames()
}

private final class FramePreviewContext {
    let source: UniversalSoftwareVideoSource
    
    init(source: UniversalSoftwareVideoSource) {
        self.source = source
    }
}

private func initializedPreviewContext(queue: Queue, postbox: Postbox, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, fileReference: FileMediaReference) -> Signal<QueueLocalObject<FramePreviewContext>, NoError> {
    return Signal { subscriber in
        let source = UniversalSoftwareVideoSource(mediaBox: postbox.mediaBox, source: .file(userLocation: userLocation, userContentType: userContentType, fileReference: fileReference))
        let readyDisposable = (source.ready
        |> filter { $0 }).start(next: { _ in
            subscriber.putNext(QueueLocalObject(queue: queue, generate: {
                return FramePreviewContext(source: source)
            }))
        })
        
        return ActionDisposable {
            readyDisposable.dispose()
        }
    }
}

private final class MediaPlayerFramePreviewImpl {
    private let queue: Queue
    private let context: Promise<QueueLocalObject<FramePreviewContext>>
    private let currentFrameDisposable = MetaDisposable()
    private var currentFrameTimestamp: Double?
    private var nextFrameTimestamp: Double?
    fileprivate let framePipe = ValuePipe<FramePreviewResult>()
    
    init(queue: Queue, postbox: Postbox, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, fileReference: FileMediaReference) {
        self.queue = queue
        self.context = Promise()
        self.context.set(initializedPreviewContext(queue: queue, postbox: postbox, userLocation: userLocation, userContentType: userContentType, fileReference: fileReference))
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.currentFrameDisposable.dispose()
    }
    
    func generateFrame(at timestamp: Double) {
        if self.currentFrameTimestamp != nil {
            self.nextFrameTimestamp = timestamp
            return
        }
        self.currentFrameTimestamp = timestamp
        
        let queue = self.queue
        let takeDisposable = MetaDisposable()
        let disposable = (self.context.get()
        |> take(1)).start(next: { [weak self] context in
            queue.justDispatch {
                guard context.queue === queue else {
                    return
                }
                context.with { context in
                    let disposable = context.source.takeFrame(at: timestamp).start(next: { result in
                        queue.async {
                            guard let strongSelf = self else {
                                return
                            }
                            switch result {
                            case .waitingForData:
                                strongSelf.framePipe.putNext(.waitingForData)
                            case let .image(image):
                                if let image = image {
                                    strongSelf.framePipe.putNext(.image(image))
                                }
                                strongSelf.currentFrameTimestamp = nil
                                if let nextFrameTimestamp = strongSelf.nextFrameTimestamp {
                                    strongSelf.nextFrameTimestamp = nil
                                    strongSelf.generateFrame(at: nextFrameTimestamp)
                                }
                            }
                        }
                    })
                    takeDisposable.set(disposable)
                }
            }
        })
        self.currentFrameDisposable.set(ActionDisposable {
            queue.async {
                takeDisposable.dispose()
                disposable.dispose()
            }
        })
    }
    
    func cancelPendingFrames() {
        self.nextFrameTimestamp = nil
        self.currentFrameTimestamp = nil
        self.currentFrameDisposable.set(nil)
    }
}

public final class MediaPlayerFramePreview: FramePreview {
    private let queue: Queue
    private let impl: QueueLocalObject<MediaPlayerFramePreviewImpl>
    
    public var generatedFrames: Signal<FramePreviewResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.framePipe.signal().start(next: { result in
                    subscriber.putNext(result)
                }))
            }
            return disposable
        }
    }
    
    public init(postbox: Postbox, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, fileReference: FileMediaReference) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return MediaPlayerFramePreviewImpl(queue: queue, postbox: postbox, userLocation: userLocation, userContentType: userContentType, fileReference: fileReference)
        })
    }
    
    public func generateFrame(at timestamp: Double) {
        self.impl.with { impl in
            impl.generateFrame(at: timestamp)
        }
    }
    
    public func cancelPendingFrames() {
        self.impl.with { impl in
            impl.cancelPendingFrames()
        }
    }
}

public final class MediaPlayerFramePreviewHLS: FramePreview {
    private final class Impl {
        private struct Part {
            var timestamp: Int
            var duration: Int
            var range: Range<Int>
            
            init(timestamp: Int, duration: Int, range: Range<Int>) {
                self.timestamp = timestamp
                self.duration = duration
                self.range = range
            }
        }
        
        private final class Playlist {
            let dataFile: FileMediaReference
            let initializationPart: Part
            let parts: [Part]
            
            init(dataFile: FileMediaReference, initializationPart: Part, parts: [Part]) {
                self.dataFile = dataFile
                self.initializationPart = initializationPart
                self.parts = parts
            }
        }
        
        let queue: Queue
        let postbox: Postbox
        let userLocation: MediaResourceUserLocation
        let userContentType: MediaResourceUserContentType
        let playlistFile: FileMediaReference
        let mainDataFile: FileMediaReference
        let alternativeQualities: [(playlist: FileMediaReference, dataFile: FileMediaReference)]
        
        private var playlist: Playlist?
        private var alternativePlaylists: [Playlist] = []
        private var fetchPlaylistDisposable: Disposable?
        private var playlistDisposable: Disposable?
        
        private var pendingFrame: (Int, FFMpegLookahead)?
        private let nextRequestedFrame: Atomic<Double?>
        
        let framePipe = ValuePipe<FramePreviewResult>()
        
        init(
            queue: Queue,
            postbox: Postbox,
            userLocation: MediaResourceUserLocation,
            userContentType: MediaResourceUserContentType,
            playlistFile: FileMediaReference,
            mainDataFile: FileMediaReference,
            alternativeQualities: [(playlist: FileMediaReference, dataFile: FileMediaReference)],
            nextRequestedFrame: Atomic<Double?>
        ) {
            self.queue = queue
            self.postbox = postbox
            self.userLocation = userLocation
            self.userContentType = userContentType
            self.playlistFile = playlistFile
            self.mainDataFile = mainDataFile
            self.alternativeQualities = alternativeQualities
            self.nextRequestedFrame = nextRequestedFrame
            
            self.loadPlaylist()
        }
        
        deinit {
            self.fetchPlaylistDisposable?.dispose()
            self.playlistDisposable?.dispose()
        }
        
        func generateFrame() {
            if self.pendingFrame != nil {
                return
            }
            
            self.updateFrameRequest()
        }
        
        func cancelPendingFrames() {
            self.pendingFrame = nil
        }
        
        private func loadPlaylist() {
            if self.fetchPlaylistDisposable != nil {
                return
            }
            
            let loadPlaylist: (FileMediaReference, FileMediaReference) -> Signal<Playlist?, NoError> = { playlistFile, dataFile in
                return self.postbox.mediaBox.resourceData(playlistFile.media.resource)
                |> mapToSignal { data -> Signal<Playlist?, NoError> in
                    if !data.complete {
                        return .never()
                    }
                    
                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                        return .single(nil)
                    }
                    guard let playlistString = String(data: data, encoding: .utf8) else {
                        return .single(nil)
                    }
                    
                    var durations: [Int] = []
                    var byteRanges: [Range<Int>] = []
                    
                    let extinfRegex = try! NSRegularExpression(pattern: "EXTINF:(\\d+)", options: [])
                    let byteRangeRegex = try! NSRegularExpression(pattern: "EXT-X-BYTERANGE:(\\d+)@(\\d+)", options: [])
                    
                    let extinfResults = extinfRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
                    for result in extinfResults {
                        if let durationRange = Range(result.range(at: 1), in: playlistString) {
                            if let duration = Int(String(playlistString[durationRange])) {
                                durations.append(duration)
                            }
                        }
                    }
                    
                    let byteRangeResults = byteRangeRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
                    for result in byteRangeResults {
                        if let lengthRange = Range(result.range(at: 1), in: playlistString), let upperBoundRange = Range(result.range(at: 2), in: playlistString) {
                            if let length = Int(String(playlistString[lengthRange])), let lowerBound = Int(String(playlistString[upperBoundRange])) {
                                byteRanges.append(lowerBound ..< (lowerBound + length))
                            }
                        }
                    }
                    
                    if durations.count != byteRanges.count {
                        return .single(nil)
                    }
                    
                    var durationOffset = 0
                    var initializationPart: Part?
                    var parts: [Part] = []
                    for i in 0 ..< durations.count {
                        let part = Part(timestamp: durationOffset, duration: durations[i], range: byteRanges[i])
                        if i == 0 {
                            initializationPart = Part(timestamp: 0, duration: 0, range: 0 ..< byteRanges[i].lowerBound)
                        }
                        parts.append(part)
                        durationOffset += durations[i]
                    }
                    
                    if let initializationPart {
                        return .single(Playlist(dataFile: dataFile, initializationPart: initializationPart, parts: parts))
                    } else {
                        return .single(nil)
                    }
                }
            }
            
            let fetchPlaylist: (FileMediaReference) -> Signal<Never, NoError> = { playlistFile in
                return fetchedMediaResource(
                    mediaBox: self.postbox.mediaBox,
                    userLocation: self.userLocation,
                    userContentType: self.userContentType,
                    reference: playlistFile.resourceReference(playlistFile.media.resource)
                )
                |> ignoreValues
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            }
            
            var fetchSignals: [Signal<Never, NoError>] = []
            fetchSignals.append(fetchPlaylist(self.playlistFile))
            for quality in self.alternativeQualities {
                fetchSignals.append(fetchPlaylist(quality.playlist))
            }
            self.fetchPlaylistDisposable = combineLatest(fetchSignals).startStrict()
            
            self.playlistDisposable = (combineLatest(queue: self.queue,
                loadPlaylist(self.playlistFile, self.mainDataFile),
                combineLatest(self.alternativeQualities.map {
                    return loadPlaylist($0.playlist, $0.dataFile)
                })
            )
            |> deliverOn(self.queue)).startStrict(next: { [weak self] mainPlaylist, alternativePlaylists in
                guard let self else {
                    return
                }
                
                self.playlist = mainPlaylist
                self.alternativePlaylists = alternativePlaylists.compactMap{ $0 }
            })
        }
        
        private func updateFrameRequest() {
            guard let playlist = self.playlist else {
                return
            }
            if self.pendingFrame != nil {
                return
            }
            guard let nextRequestedFrame = self.nextRequestedFrame.swap(nil) else {
                return
            }
            
            var allPlaylists: [Playlist] = [playlist]
            allPlaylists.append(contentsOf: self.alternativePlaylists)
            outer: for playlist in allPlaylists {
                if let dataFileSize = playlist.dataFile.media.size, let part = playlist.parts.first(where: { $0.timestamp <= Int(nextRequestedFrame) && ($0.timestamp + $0.duration) > Int(nextRequestedFrame) }) {
                    let mappedRanges: [Range<Int64>] = [
                        Int64(playlist.initializationPart.range.lowerBound) ..< Int64(playlist.initializationPart.range.upperBound),
                        Int64(part.range.lowerBound) ..< Int64(part.range.upperBound)
                    ]
                    for mappedRange in mappedRanges {
                        if !self.postbox.mediaBox.internal_resourceDataIsCached(id: playlist.dataFile.media.resource.id, size: dataFileSize, in: mappedRange) {
                            continue outer
                        }
                    }
                    
                    if let directReader = FFMpegFileReader(
                        source: .resource(mediaBox: self.postbox.mediaBox, resource: playlist.dataFile.media.resource, resourceSize: dataFileSize, mappedRanges: mappedRanges),
                        useHardwareAcceleration: false,
                        selectedStream: .mediaType(.video),
                        seek: .direct(position: nextRequestedFrame),
                        maxReadablePts: nil
                    ) {
                        var lastFrame: CMSampleBuffer?
                        findFrame: while true {
                            switch directReader.readFrame() {
                            case let .frame(frame):
                                if lastFrame == nil {
                                    lastFrame = frame.sampleBuffer
                                } else if CMSampleBufferGetPresentationTimeStamp(frame.sampleBuffer).seconds > nextRequestedFrame {
                                    break findFrame
                                } else {
                                    lastFrame = frame.sampleBuffer
                                }
                            default:
                                break findFrame
                            }
                        }
                        if let lastFrame {
                            if let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame) {
                                var cgImage: CGImage?
                                VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &cgImage)
                                if let cgImage {
                                    self.framePipe.putNext(.image(UIImage(cgImage: cgImage)))
                                }
                            }
                        }
                    }
                    
                    self.updateFrameRequest()
                    return
                }
            }
            
            let initializationPart = playlist.initializationPart
            guard let part = playlist.parts.first(where: { $0.timestamp <= Int(nextRequestedFrame) && ($0.timestamp + $0.duration) > Int(nextRequestedFrame) }) else {
                return
            }
            guard let dataFileSize = self.mainDataFile.media.size else {
                return
            }
            
            let resource = self.mainDataFile.media.resource
            let postbox = self.postbox
            let userLocation = self.userLocation
            let userContentType = self.userContentType
            let dataFile = self.mainDataFile
            
            let partRange: Range<Int64> = Int64(part.range.lowerBound) ..< Int64(part.range.upperBound)
            
            let mappedRanges: [Range<Int64>] = [
                Int64(initializationPart.range.lowerBound) ..< Int64(initializationPart.range.upperBound),
                partRange
            ]
            var mappedSize: Int64 = 0
            for range in mappedRanges {
                mappedSize += range.upperBound - range.lowerBound
            }
            
            let queue = self.queue
            let updateState: (FFMpegLookahead.State) -> Void = { [weak self] state in
                queue.async {
                    guard let self else {
                        return
                    }
                    if self.pendingFrame?.0 != part.timestamp {
                        return
                    }
                    guard let video = state.video else {
                        return
                    }
                    
                    if let directReader = FFMpegFileReader(
                        source: .resource(mediaBox: postbox.mediaBox, resource: resource, resourceSize: dataFileSize, mappedRanges: mappedRanges),
                        useHardwareAcceleration: false,
                        selectedStream: .index(video.info.index),
                        seek: .stream(streamIndex: state.seek.streamIndex, pts: state.seek.pts),
                        maxReadablePts: (video.info.index, video.readableToTime.value, state.isEnded)
                    ) {
                        switch directReader.readFrame() {
                        case let .frame(frame):
                            if let imageBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer) {
                                var cgImage: CGImage?
                                VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &cgImage)
                                if let cgImage {
                                    self.framePipe.putNext(.image(UIImage(cgImage: cgImage)))
                                }
                            }
                        default:
                            break
                        }
                    }
                    
                    self.pendingFrame = nil
                    self.updateFrameRequest()
                }
            }
            
            let lookahead = FFMpegLookahead(
                seekToTimestamp: 0.0,
                lookaheadDuration: 0.0,
                updateState: updateState,
                fetchInRange: { fetchRange in
                    let disposable = DisposableSet()
                    
                    let readCount = fetchRange.upperBound - fetchRange.lowerBound
                    var readingPosition = fetchRange.lowerBound
                    
                    var bufferOffset = 0
                    let doRead: (Range<Int64>) -> Void = { range in
                        disposable.add(fetchedMediaResource(
                            mediaBox: postbox.mediaBox,
                            userLocation: userLocation,
                            userContentType: userContentType,
                            reference: dataFile.resourceReference(dataFile.media.resource),
                            range: (range, .elevated),
                            statsCategory: .video,
                            preferBackgroundReferenceRevalidation: false
                        ).startStrict())
                        let count = Int(range.upperBound - range.lowerBound)
                        bufferOffset += count
                        readingPosition += Int64(count)
                    }
                    
                    var mappedRangePosition: Int64 = 0
                    for mappedRange in mappedRanges {
                        let bytesToRead = readCount - Int64(bufferOffset)
                        if bytesToRead <= 0 {
                            break
                        }
                        
                        let mappedRangeSize = mappedRange.upperBound - mappedRange.lowerBound
                        let mappedRangeReadingPosition = readingPosition - mappedRangePosition
                        
                        if mappedRangeReadingPosition >= 0 && mappedRangeReadingPosition < mappedRangeSize {
                            let mappedRangeAvailableBytesToRead = mappedRangeSize - mappedRangeReadingPosition
                            let mappedRangeBytesToRead = min(bytesToRead, mappedRangeAvailableBytesToRead)
                            if mappedRangeBytesToRead > 0 {
                                let mappedReadRange = (mappedRange.lowerBound + mappedRangeReadingPosition) ..< (mappedRange.lowerBound + mappedRangeReadingPosition + mappedRangeBytesToRead)
                                doRead(mappedReadRange)
                            }
                        }
                        
                        mappedRangePosition += mappedRangeSize
                    }
                    
                    return disposable
                },
                getDataInRange: { getRange, completion in
                    var signals: [Signal<(Data, Bool), NoError>] = []
                    
                    let readCount = getRange.upperBound - getRange.lowerBound
                    var readingPosition = getRange.lowerBound
                    
                    var bufferOffset = 0
                    let doRead: (Range<Int64>) -> Void = { range in
                        signals.append(postbox.mediaBox.resourceData(resource, size: dataFileSize, in: range, mode: .complete))
                        
                        let readSize = Int(range.upperBound - range.lowerBound)
                        let effectiveReadSize = max(0, min(Int(readCount) - bufferOffset, readSize))
                        let count = effectiveReadSize
                        bufferOffset += count
                        readingPosition += Int64(count)
                    }
                    
                    var mappedRangePosition: Int64 = 0
                    for mappedRange in mappedRanges {
                        let bytesToRead = readCount - Int64(bufferOffset)
                        if bytesToRead <= 0 {
                            break
                        }
                        
                        let mappedRangeSize = mappedRange.upperBound - mappedRange.lowerBound
                        let mappedRangeReadingPosition = readingPosition - mappedRangePosition
                        
                        if mappedRangeReadingPosition >= 0 && mappedRangeReadingPosition < mappedRangeSize {
                            let mappedRangeAvailableBytesToRead = mappedRangeSize - mappedRangeReadingPosition
                            let mappedRangeBytesToRead = min(bytesToRead, mappedRangeAvailableBytesToRead)
                            if mappedRangeBytesToRead > 0 {
                                let mappedReadRange = (mappedRange.lowerBound + mappedRangeReadingPosition) ..< (mappedRange.lowerBound + mappedRangeReadingPosition + mappedRangeBytesToRead)
                                doRead(mappedReadRange)
                            }
                        }
                        
                        mappedRangePosition += mappedRangeSize
                    }
                    
                    let singal = combineLatest(signals)
                    |> map { results -> Data? in
                        var result = Data()
                        for (partData, partIsComplete) in results {
                            if !partIsComplete {
                                return nil
                            }
                            result.append(partData)
                        }
                        return result
                    }
                    
                    return singal.start(next: { result in
                        completion(result)
                    })
                },
                isDataCachedInRange: { cachedRange in
                    let readCount = cachedRange.upperBound - cachedRange.lowerBound
                    var readingPosition = cachedRange.lowerBound
                    
                    var allDataIsCached = true
                    
                    var bufferOffset = 0
                    let doRead: (Range<Int64>) -> Void = { range in
                        let isCached = postbox.mediaBox.internal_resourceDataIsCached(
                            id: resource.id,
                            size: dataFileSize,
                            in: range
                        )
                        if !isCached {
                            allDataIsCached = false
                        }
                        
                        let effectiveReadSize = Int(range.upperBound - range.lowerBound)
                        let count = effectiveReadSize
                        bufferOffset += count
                        readingPosition += Int64(count)
                    }
                    
                    var mappedRangePosition: Int64 = 0
                    for mappedRange in mappedRanges {
                        let bytesToRead = readCount - Int64(bufferOffset)
                        if bytesToRead <= 0 {
                            break
                        }
                        
                        let mappedRangeSize = mappedRange.upperBound - mappedRange.lowerBound
                        let mappedRangeReadingPosition = readingPosition - mappedRangePosition
                        
                        if mappedRangeReadingPosition >= 0 && mappedRangeReadingPosition < mappedRangeSize {
                            let mappedRangeAvailableBytesToRead = mappedRangeSize - mappedRangeReadingPosition
                            let mappedRangeBytesToRead = min(bytesToRead, mappedRangeAvailableBytesToRead)
                            if mappedRangeBytesToRead > 0 {
                                let mappedReadRange = (mappedRange.lowerBound + mappedRangeReadingPosition) ..< (mappedRange.lowerBound + mappedRangeReadingPosition + mappedRangeBytesToRead)
                                doRead(mappedReadRange)
                            }
                        }
                        
                        mappedRangePosition += mappedRangeSize
                    }
                    
                    return allDataIsCached
                },
                size: mappedSize
            )
            
            self.pendingFrame = (part.timestamp, lookahead)
            
            lookahead.updateCurrentTimestamp(timestamp: 0.0)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var generatedFrames: Signal<FramePreviewResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.framePipe.signal().start(next: { result in
                    subscriber.putNext(result)
                }))
            }
            return disposable
        }
    }
    
    private let nextRequestedFrame = Atomic<Double?>(value: nil)
    
    public init(
        postbox: Postbox,
        userLocation: MediaResourceUserLocation,
        userContentType: MediaResourceUserContentType,
        playlistFile: FileMediaReference,
        mainDataFile: FileMediaReference,
        alternativeQualities: [(playlist: FileMediaReference, dataFile: FileMediaReference)]
    ) {
        let queue = Queue()
        self.queue = queue
        let nextRequestedFrame = self.nextRequestedFrame
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(
                queue: queue,
                postbox: postbox,
                userLocation: userLocation,
                userContentType: userContentType,
                playlistFile: playlistFile,
                mainDataFile: mainDataFile,
                alternativeQualities: alternativeQualities,
                nextRequestedFrame: nextRequestedFrame
            )
        })
    }
    
    public func generateFrame(at timestamp: Double) {
        let _ = self.nextRequestedFrame.swap(timestamp)
        self.impl.with { impl in
            impl.generateFrame()
        }
    }
    
    public func cancelPendingFrames() {
        self.impl.with { impl in
            impl.cancelPendingFrames()
        }
    }
}

public final class MediaPlayerFramePreviewHLSThumbnails: FramePreview {
    private final class Impl {
        let queue: Queue
        let postbox: Postbox
        let userLocation: MediaResourceUserLocation
        let userContentType: MediaResourceUserContentType
        let file: FileMediaReference
        let fileMap: FileMediaReference
        
        private var fileDisposable: Disposable?
        
        let framePipe = ValuePipe<FramePreviewResult>()
        private let nextRequestedFrame: Atomic<Double?>
        
        private var mapData: (image: UIImage, frames: [(Double, CGRect)])?
        private var currentFrame: Double?
        
        init(
            queue: Queue,
            postbox: Postbox,
            userLocation: MediaResourceUserLocation,
            userContentType: MediaResourceUserContentType,
            file: FileMediaReference,
            fileMap: FileMediaReference,
            nextRequestedFrame: Atomic<Double?>
        ) {
            self.queue = queue
            self.postbox = postbox
            self.userLocation = userLocation
            self.userContentType = userContentType
            self.file = file
            self.fileMap = fileMap
            self.nextRequestedFrame = nextRequestedFrame
            
            self.loadFiles()
        }
        
        deinit {
            self.fileDisposable?.dispose()
        }
        
        func generateFrame() {
            self.updateFrameRequest()
        }
        
        func cancelPendingFrames() {
        }
        
        private func loadFiles() {
            if self.fileDisposable != nil {
                return
            }
            
            let fetchDisposables = DisposableSet()
            self.fileDisposable = fetchDisposables
            
            fetchDisposables.add(fetchedMediaResource(
                mediaBox: self.postbox.mediaBox,
                userLocation: self.userLocation,
                userContentType: self.userContentType,
                reference: self.fileMap.resourceReference(self.fileMap.media.resource)
            ).startStrict())
            fetchDisposables.add(fetchedMediaResource(
                mediaBox: self.postbox.mediaBox,
                userLocation: self.userLocation,
                userContentType: self.userContentType,
                reference: self.file.resourceReference(self.file.media.resource)
            ).startStrict())
            
            fetchDisposables.add((combineLatest(queue: .mainQueue(),
                self.postbox.mediaBox.resourceData(self.fileMap.media.resource) |> filter { $0.complete } |> take(1),
                self.postbox.mediaBox.resourceData(self.file.media.resource) |> filter { $0.complete } |> take(1)
            )
            |> deliverOn(self.queue)).startStrict(next: { [weak self] fileMap, file in
                guard let self else {
                    return
                }
                guard let fileMapData = try? Data(contentsOf: URL(fileURLWithPath: fileMap.path)) else {
                    return
                }
                guard let fileMapString = String(data: fileMapData, encoding: .utf8) else {
                    return
                }
                let mapLines = fileMapString.components(separatedBy: "\n")
                
                /*
                 file=mtproto:5330572490471112705
                 frame_width=80
                 frame_height=144
                 0,0,0
                 5,80,0
                 10,160,0
                 15,240,0
                 20,320,0
                 */
                var frameWidth: Int?
                var frameHeight: Int?
                var frames: [(Double, CGRect)] = []
                for line in mapLines {
                    if line.hasPrefix("file=") {
                    } else if line.hasPrefix("frame_width=") {
                        frameWidth = Int(line[line.index(line.startIndex, offsetBy: "frame_width=".count)...])
                    } else if line.hasPrefix("frame_height=") {
                        frameHeight = Int(line[line.index(line.startIndex, offsetBy: "frame_height=".count)...])
                    } else {
                        let components = line.components(separatedBy: ",")
                        if components.count == 3 {
                            let offset = Double(components[0])
                            let x = Int(components[1])
                            let y = Int(components[2])
                            
                            if let offset, let x, let y {
                                if let frameWidth, let frameHeight {
                                    let frameWidth = min(frameWidth, 1024)
                                    let frameHeight = min(frameHeight, 1024)
                                    
                                    frames.append((offset, CGRect(origin: CGPoint(x: CGFloat(x), y: CGFloat(y)), size: CGSize(width: CGFloat(frameWidth), height: CGFloat(frameHeight)))))
                                }
                            }
                        }
                    }
                }
                
                if let image = UIImage(contentsOfFile: file.path) {
                    self.mapData = (image, frames)
                }
                
                self.updateFrameRequest()
            }))
        }
        
        private func updateFrameRequest() {
            guard let mapData = self.mapData else {
                return
            }
            if let timestamp = self.nextRequestedFrame.swap(nil) {
                if self.currentFrame == timestamp {
                    return
                }
                self.currentFrame = timestamp
                
                for (offset, rect) in mapData.frames {
                    if offset >= timestamp {
                        let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: rect.size))
                        let image = renderer.image { context in
                            UIGraphicsPushContext(context.cgContext)
                            context.cgContext.setFillColor(UIColor.black.cgColor)
                            context.cgContext.fill(CGRect(origin: CGPoint(), size: rect.size))
                            mapData.image.draw(in: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: mapData.image.size))
                            UIGraphicsPopContext()
                        }
                        self.framePipe.putNext(FramePreviewResult.image(image))
                        
                        break
                    }
                }
            }
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var generatedFrames: Signal<FramePreviewResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.framePipe.signal().start(next: { result in
                    subscriber.putNext(result)
                }))
            }
            return disposable
        }
    }
    
    private let nextRequestedFrame = Atomic<Double?>(value: nil)
    
    public init(
        postbox: Postbox,
        userLocation: MediaResourceUserLocation,
        userContentType: MediaResourceUserContentType,
        file: FileMediaReference,
        fileMap: FileMediaReference
    ) {
        let queue = Queue()
        self.queue = queue
        let nextRequestedFrame = self.nextRequestedFrame
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(
                queue: queue,
                postbox: postbox,
                userLocation: userLocation,
                userContentType: userContentType,
                file: file,
                fileMap: fileMap,
                nextRequestedFrame: nextRequestedFrame
            )
        })
    }
    
    public func generateFrame(at timestamp: Double) {
        let _ = self.nextRequestedFrame.swap(timestamp)
        self.impl.with { impl in
            impl.generateFrame()
        }
    }
    
    public func cancelPendingFrames() {
        self.impl.with { impl in
            impl.cancelPendingFrames()
        }
    }
}

