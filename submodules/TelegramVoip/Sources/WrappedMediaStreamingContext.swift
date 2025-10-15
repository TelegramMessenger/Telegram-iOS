import Foundation
import SwiftSignalKit
import TgVoipWebrtc
import TelegramCore
import Network
import Postbox
import FFMpegBinding
import ManagedFile

@available(iOS 12.0, macOS 14.0, *)
public final class WrappedMediaStreamingContext {
    private final class Impl {
        let queue: Queue
        let context: MediaStreamingContext
        
        private let broadcastPartsSource = Atomic<BroadcastPartSource?>(value: nil)
        
        init(queue: Queue, rejoinNeeded: @escaping () -> Void) {
            self.queue = queue
            
            var getBroadcastPartsSource: (() -> BroadcastPartSource?)?
            
            self.context = MediaStreamingContext(
                queue: ContextQueueImpl(queue: queue),
                requestCurrentTime: { completion in
                    let disposable = MetaDisposable()

                    queue.async {
                        if let source = getBroadcastPartsSource?() {
                            disposable.set(source.requestTime(completion: completion))
                        } else {
                            completion(0)
                        }
                    }

                    return OngoingGroupCallBroadcastPartTaskImpl(disposable: disposable)
                },
                requestAudioBroadcastPart: { timestampMilliseconds, durationMilliseconds, completion in
                    let disposable = MetaDisposable()
                    
                    queue.async {
                        disposable.set(getBroadcastPartsSource?()?.requestPart(timestampMilliseconds: timestampMilliseconds, durationMilliseconds: durationMilliseconds, subject: .audio, completion: completion, rejoinNeeded: {
                            rejoinNeeded()
                        }))
                    }
                    
                    return OngoingGroupCallBroadcastPartTaskImpl(disposable: disposable)
                },
                requestVideoBroadcastPart: { timestampMilliseconds, durationMilliseconds, channelId, quality, completion in
                    let disposable = MetaDisposable()

                    queue.async {
                        let mappedQuality: OngoingGroupCallContext.VideoChannel.Quality
                        switch quality {
                        case .thumbnail:
                            mappedQuality = .thumbnail
                        case .medium:
                            mappedQuality = .medium
                        case .full:
                            mappedQuality = .full
                        @unknown default:
                            mappedQuality = .thumbnail
                        }
                        disposable.set(getBroadcastPartsSource?()?.requestPart(timestampMilliseconds: timestampMilliseconds, durationMilliseconds: durationMilliseconds, subject: .video(channelId: channelId, quality: mappedQuality), completion: completion, rejoinNeeded: {
                            rejoinNeeded()
                        }))
                    }

                    return OngoingGroupCallBroadcastPartTaskImpl(disposable: disposable)
                }
            )
            
            let broadcastPartsSource = self.broadcastPartsSource
            getBroadcastPartsSource = {
                return broadcastPartsSource.with { $0 }
            }
        }
        
        deinit {
        }
        
        func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
            if let audioStreamData = audioStreamData {
                let broadcastPartsSource = NetworkBroadcastPartSource(queue: self.queue, engine: audioStreamData.engine, callId: audioStreamData.callId, accessHash: audioStreamData.accessHash, isExternalStream: audioStreamData.isExternalStream)
                let _ = self.broadcastPartsSource.swap(broadcastPartsSource)
                self.context.start()
            }
        }

        func video() -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
            let queue = self.queue
            return Signal { [weak self] subscriber in
                let disposable = MetaDisposable()

                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    let innerDisposable = strongSelf.context.addVideoOutput() { videoFrameData in
                        subscriber.putNext(OngoingGroupCallContext.VideoFrameData(frameData: videoFrameData))
                    }
                    disposable.set(ActionDisposable {
                        innerDisposable.dispose()
                    })
                }

                return disposable
            }
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<Impl>
    
    public init(rejoinNeeded: @escaping () -> Void) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, rejoinNeeded: rejoinNeeded)
        })
    }
    
    public func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
        self.impl.with { impl in
            impl.setAudioStreamData(audioStreamData: audioStreamData)
        }
    }

    public func video() -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.video().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
@available(iOS 12.0, macOS 14.0, *)
public final class ExternalMediaStreamingContext: SharedHLSServerSource {
    private final class Impl {
        let queue: Queue
        
        private var broadcastPartsSource: BroadcastPartSource?
        
        private let resetPlaylistDisposable = MetaDisposable()
        private let updatePlaylistDisposable = MetaDisposable()
        
        let masterPlaylistData = Promise<String>()
        let playlistData = Promise<String>()
        let mediumPlaylistData = Promise<String>()
        
        init(queue: Queue, rejoinNeeded: @escaping () -> Void) {
            self.queue = queue
        }
        
        deinit {
            self.updatePlaylistDisposable.dispose()
        }
        
        func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
            if let audioStreamData {
                let broadcastPartsSource = NetworkBroadcastPartSource(queue: self.queue, engine: audioStreamData.engine, callId: audioStreamData.callId, accessHash: audioStreamData.accessHash, isExternalStream: audioStreamData.isExternalStream)
                self.broadcastPartsSource = broadcastPartsSource
                
                self.updatePlaylistDisposable.set(nil)
                
                let queue = self.queue
                self.resetPlaylistDisposable.set(broadcastPartsSource.requestTime(completion: { [weak self] timestamp in
                    queue.async {
                        guard let self else {
                            return
                        }
                        
                        let segmentDuration: Int64 = 1000
                        
                        var adjustedTimestamp: Int64 = 0
                        if timestamp > 0 {
                            adjustedTimestamp = timestamp / segmentDuration * segmentDuration - 4 * segmentDuration
                        }
                        
                        if adjustedTimestamp > 0 {
                            var masterPlaylistData = "#EXTM3U\n" +
                            "#EXT-X-VERSION:6\n" +
                            "#EXT-X-STREAM-INF:BANDWIDTH=3300000,RESOLUTION=1280x720,CODECS=\"avc1.64001f,mp4a.40.2\"\n" +
                            "hls_level_0.m3u8\n"
                            
                            masterPlaylistData += "#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360,CODECS=\"avc1.64001f,mp4a.40.2\"\n" +
                            "hls_level_1.m3u8\n"
                            
                            self.masterPlaylistData.set(.single(masterPlaylistData))
                            
                            self.beginUpdatingPlaylist(initialHeadTimestamp: adjustedTimestamp)
                        }
                    }
                }))
            }
        }
        
        private func beginUpdatingPlaylist(initialHeadTimestamp: Int64) {
            let segmentDuration: Int64 = 1000
            
            var timestamp = initialHeadTimestamp
            self.updatePlaylist(headTimestamp: timestamp, quality: 0)
            self.updatePlaylist(headTimestamp: timestamp, quality: 1)
            
            self.updatePlaylistDisposable.set((
                Signal<Void, NoError>.single(Void())
                |> delay(1.0, queue: self.queue)
                |> restart
                |> deliverOn(self.queue)
            ).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                
                timestamp += segmentDuration
                self.updatePlaylist(headTimestamp: timestamp, quality: 0)
                self.updatePlaylist(headTimestamp: timestamp, quality: 1)
            }))
        }
        
        private func updatePlaylist(headTimestamp: Int64, quality: Int) {
            let segmentDuration: Int64 = 1000
            let headIndex = headTimestamp / segmentDuration
            let minIndex = headIndex - 20
            
            var playlistData = "#EXTM3U\n" +
            "#EXT-X-VERSION:6\n" +
            "#EXT-X-TARGETDURATION:1\n" +
            "#EXT-X-MEDIA-SEQUENCE:\(minIndex)\n" +
            "#EXT-X-INDEPENDENT-SEGMENTS\n"
            
            for index in minIndex ... headIndex {
                playlistData.append("#EXTINF:1.000000,\n")
                playlistData.append("hls_stream\(quality)_\(index).ts\n")
            }
            
            //print("Player: updating playlist \(quality) \(minIndex) ... \(headIndex)")
            
            if quality == 0 {
                self.playlistData.set(.single(playlistData))
            } else {
                self.mediumPlaylistData.set(.single(playlistData))
            }
        }
        
        func partData(index: Int, quality: Int) -> Signal<Data?, NoError> {
            let segmentDuration: Int64 = 1000
            let timestamp = Int64(index) * segmentDuration
            
            print("Player: request part(q: \(quality)) \(index) -> \(timestamp)")
            
            guard let broadcastPartsSource = self.broadcastPartsSource else {
                return .single(nil)
            }
            
            return Signal { subscriber in
                return broadcastPartsSource.requestPart(
                    timestampMilliseconds: timestamp,
                    durationMilliseconds: segmentDuration,
                    subject: .video(channelId: 1, quality: quality == 0 ? .full : .medium),
                    completion: { part in
                        var data = part.oggData
                        if data.count > 32 {
                            data = data.subdata(in: 32 ..< data.count)
                        }
                        subscriber.putNext(data)
                    },
                    rejoinNeeded: {
                        //TODO
                    }
                )
            }
        }
        
        func fileData(id: Int64, range: Range<Int>) -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError> {
            return .never()
        }
    }
    
    private let queue = Queue()
    let internalId: CallSessionInternalId
    private let impl: QueueLocalObject<Impl>
    private var hlsServerDisposable: Disposable?
    
    public var id: String {
        return self.internalId.uuidString
    }
    
    public init(id: CallSessionInternalId, rejoinNeeded: @escaping () -> Void) {
        self.internalId = id
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, rejoinNeeded: rejoinNeeded)
        })
        
        self.hlsServerDisposable = SharedHLSServer.shared.registerPlayer(source: self, completion: {})
    }
    
    deinit {
        self.hlsServerDisposable?.dispose()
    }
    
    public func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
        self.impl.with { impl in
            impl.setAudioStreamData(audioStreamData: audioStreamData)
        }
    }
    
    public func masterPlaylistData() -> Signal<String, NoError> {
        return self.impl.signalWith { impl, subscriber in
            impl.masterPlaylistData.get().start(next: subscriber.putNext)
        }
    }
    
    public func playlistData(quality: Int) -> Signal<String, NoError> {
        return self.impl.signalWith { impl, subscriber in
            if quality == 0 {
                impl.playlistData.get().start(next: subscriber.putNext)
            } else {
                impl.mediumPlaylistData.get().start(next: subscriber.putNext)
            }
        }
    }
    
    public func partData(index: Int, quality: Int) -> Signal<Data?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            impl.partData(index: index, quality: quality).start(next: subscriber.putNext)
        }
    }
    
    public func fileData(id: Int64, range: Range<Int>) -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            impl.fileData(id: id, range: range).start(next: subscriber.putNext)
        }
    }
    
    public func arbitraryFileData(path: String) -> Signal<(data: Data, contentType: String)?, NoError> {
        return .single(nil)
    }
}

public final class DirectMediaStreamingContext {
    public struct Playlist: Equatable {
        public struct Part: Equatable {
            public let index: Int
            public let timestamp: Double
            public let duration: Double
            
            public init(index: Int, timestamp: Double, duration: Double) {
                self.index = index
                self.timestamp = timestamp
                self.duration = duration
            }
        }
        
        public var parts: [Part]
        
        public init(parts: [Part]) {
            self.parts = parts
        }
    }
    
    private final class Impl {
        let queue: Queue
        
        private var broadcastPartsSource: BroadcastPartSource?
        
        private let resetPlaylistDisposable = MetaDisposable()
        private let updatePlaylistDisposable = MetaDisposable()
        
        let playlistData = Promise<Playlist>()
        
        init(queue: Queue, rejoinNeeded: @escaping () -> Void) {
            self.queue = queue
        }
        
        deinit {
            self.updatePlaylistDisposable.dispose()
        }
        
        func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
            if let audioStreamData {
                let broadcastPartsSource = NetworkBroadcastPartSource(queue: self.queue, engine: audioStreamData.engine, callId: audioStreamData.callId, accessHash: audioStreamData.accessHash, isExternalStream: audioStreamData.isExternalStream)
                self.broadcastPartsSource = broadcastPartsSource
                
                self.updatePlaylistDisposable.set(nil)
                
                let queue = self.queue
                self.resetPlaylistDisposable.set(broadcastPartsSource.requestTime(completion: { [weak self] timestamp in
                    queue.async {
                        guard let self else {
                            return
                        }
                        
                        let segmentDuration: Int64 = 1000
                        
                        var adjustedTimestamp: Int64 = 0
                        if timestamp > 0 {
                            adjustedTimestamp = timestamp / segmentDuration * segmentDuration - 4 * segmentDuration
                        }
                        
                        if adjustedTimestamp > 0 {
                            self.beginUpdatingPlaylist(initialHeadTimestamp: adjustedTimestamp)
                        }
                    }
                }))
            }
        }
        
        private func beginUpdatingPlaylist(initialHeadTimestamp: Int64) {
            let segmentDuration: Int64 = 1000
            
            var timestamp = initialHeadTimestamp
            self.updatePlaylist(headTimestamp: timestamp)
            
            self.updatePlaylistDisposable.set((
                Signal<Void, NoError>.single(Void())
                |> delay(1.0, queue: self.queue)
                |> restart
                |> deliverOn(self.queue)
            ).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                
                timestamp += segmentDuration
                self.updatePlaylist(headTimestamp: timestamp)
            }))
        }
        
        private func updatePlaylist(headTimestamp: Int64) {
            let segmentDuration: Int64 = 1000
            let headIndex = headTimestamp / segmentDuration
            let minIndex = headIndex - 20
            
            var parts: [Playlist.Part] = []
            for index in minIndex ... headIndex {
                parts.append(DirectMediaStreamingContext.Playlist.Part(
                    index: Int(index),
                    timestamp: Double(index),
                    duration: 1.0
                ))
            }
            
            self.playlistData.set(.single(Playlist(parts: parts)))
        }
        
        func partData(index: Int) -> Signal<Data?, NoError> {
            let segmentDuration: Int64 = 1000
            let timestamp = Int64(index) * segmentDuration
            
            //print("Player: request part(q: \(quality)) \(index) -> \(timestamp)")
            
            guard let broadcastPartsSource = self.broadcastPartsSource else {
                return .single(nil)
            }
            
            return Signal { subscriber in
                return broadcastPartsSource.requestPart(
                    timestampMilliseconds: timestamp,
                    durationMilliseconds: segmentDuration,
                    subject: .video(channelId: 1, quality: .full),
                    completion: { part in
                        var data = part.oggData
                        if data.count > 32 {
                            data = data.subdata(in: 32 ..< data.count)
                        }
                        subscriber.putNext(data)
                    },
                    rejoinNeeded: {
                        //TODO
                    }
                )
            }
        }
    }
    
    private let queue = Queue()
    let internalId: CallSessionInternalId
    private let impl: QueueLocalObject<Impl>
    private var hlsServerDisposable: Disposable?
    
    public init(id: CallSessionInternalId, rejoinNeeded: @escaping () -> Void) {
        self.internalId = id
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, rejoinNeeded: rejoinNeeded)
        })
    }
    
    deinit {
    }
    
    public func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
        self.impl.with { impl in
            impl.setAudioStreamData(audioStreamData: audioStreamData)
        }
    }
    
    public func playlistData() -> Signal<Playlist, NoError> {
        return self.impl.signalWith { impl, subscriber in
            impl.playlistData.get().start(next: subscriber.putNext)
        }
    }
    
    public func partData(index: Int) -> Signal<Data?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            impl.partData(index: index).start(next: subscriber.putNext)
        }
    }
}

public protocol SharedHLSServerSource: AnyObject {
    var id: String { get }
    
    func masterPlaylistData() -> Signal<String, NoError>
    func playlistData(quality: Int) -> Signal<String, NoError>
    func partData(index: Int, quality: Int) -> Signal<Data?, NoError>
    func fileData(id: Int64, range: Range<Int>) -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError>
    func arbitraryFileData(path: String) -> Signal<(data: Data, contentType: String)?, NoError>
}

@available(iOS 12.0, macOS 14.0, *)
public final class SharedHLSServer {
    public typealias Source = SharedHLSServerSource
    
    public static let shared: SharedHLSServer = {
        return SharedHLSServer()
    }()
    
    private enum ResponseError {
        case badRequest
        case notFound
        case internalServerError
        
        var httpString: String {
            switch self {
            case .badRequest:
                return "400 Bad Request"
            case .notFound:
                return "404 Not Found"
            case .internalServerError:
                return "500 Internal Server Error"
            }
        }
    }
    
    private final class SourceReference {
        weak var source: SharedHLSServerSource?
        
        init(source: SharedHLSServerSource) {
            self.source = source
        }
    }
    @available(iOS 12.0, macOS 14.0, *)
    private final class Impl {
        private let queue: Queue
        
        private let port: NWEndpoint.Port
        private var listener: NWListener?
        
        private var sourceReferences = Bag<SourceReference>()
        private var referenceCheckTimer: SwiftSignalKit.Timer?
        private var shutdownTimer: SwiftSignalKit.Timer?
        
        init(queue: Queue, port: UInt16) {
            self.queue = queue
            self.port = NWEndpoint.Port(rawValue: port)!
        }
        
        deinit {
            self.referenceCheckTimer?.invalidate()
            self.shutdownTimer?.invalidate()
        }
        
        private func updateNeedsListener() {
            var isEmpty = true
            for item in self.sourceReferences.copyItems() {
                if let _ = item.source {
                    isEmpty = false
                    break
                }
            }
            
            if isEmpty {
                if self.listener != nil {
                    if self.shutdownTimer == nil {
                        self.shutdownTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.shutdownTimer = nil
                            self.stopListener()
                        }, queue: self.queue)
                        self.shutdownTimer?.start()
                    }
                }
                if let referenceCheckTimer = self.referenceCheckTimer {
                    self.referenceCheckTimer = nil
                    referenceCheckTimer.invalidate()
                }
            } else {
                if let shutdownTimer = self.shutdownTimer {
                    self.shutdownTimer = nil
                    shutdownTimer.invalidate()
                }
                if self.listener == nil {
                    self.startListener()
                }
                if self.referenceCheckTimer == nil {
                    self.referenceCheckTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.updateNeedsListener()
                    }, queue: self.queue)
                    self.referenceCheckTimer?.start()
                }
            }
        }
        
        private func startListener() {
            let listener: NWListener
            do {
                listener = try NWListener(using: .tcp, on: self.port)
            } catch {
                Logger.shared.log("SharedHLSServer", "Failed to create listener: \(error)")
                return
            }
            self.listener = listener
            
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else {
                    return
                }
                self.handleConnection(connection: connection)
            }
            
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self, let listener else {
                    return
                }
                switch state {
                case .ready:
                    Logger.shared.log("SharedHLSServer", "Server is ready on port \(self.port)")
                case let .failed(error):
                    Logger.shared.log("SharedHLSServer", "Server failed with error: \(error)")
                    listener.cancel()
                    
                    listener.start(queue: self.queue.queue)
                default:
                    break
                }
            }
            
            listener.start(queue: self.queue.queue)
        }
        
        private func stopListener() {
            guard let listener = self.listener else {
                return
            }
            self.listener = nil
            listener.cancel()
        }
        
        private func handleConnection(connection: NWConnection) {
            connection.start(queue: self.queue.queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024, completion: { [weak self] data, _, isComplete, error in
                guard let self else {
                    return
                }
                if let data, !data.isEmpty {
                    self.handleRequest(data: data, connection: connection)
                } else if isComplete {
                    connection.cancel()
                } else if let error = error {
                    Logger.shared.log("SharedHLSServer", "Error on connection: \(error)")
                    connection.cancel()
                }
            })
        }
        
        private func handleRequest(data: Data, connection: NWConnection) {
            guard let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            if !requestString.hasPrefix("GET /") {
                self.sendErrorAndClose(connection: connection)
                return
            }
            guard let firstCrLf = requestString.range(of: "\r\n") else {
                self.sendErrorAndClose(connection: connection)
                return
            }
            let firstLine = String(requestString[requestString.index(requestString.startIndex, offsetBy: "GET /".count) ..< firstCrLf.lowerBound])
            if !(firstLine.hasSuffix(" HTTP/1.0") || firstLine.hasSuffix(" HTTP/1.1")) {
                self.sendErrorAndClose(connection: connection)
                return
            }
            
            let requestPath = String(firstLine[firstLine.startIndex ..< firstLine.index(firstLine.endIndex, offsetBy: -" HTTP/1.1".count)])
            var requestRange: Range<Int>?
            if let rangeRange = requestString.range(of: "Range: bytes=") {
                if let endRange = requestString.range(of: "\r\n", range: rangeRange.upperBound ..< requestString.endIndex) {
                    let rangeString = String(requestString[rangeRange.upperBound ..< endRange.lowerBound])
                    if let dashRange = rangeString.range(of: "-") {
                        let lowerBoundString = String(rangeString[rangeString.startIndex ..< dashRange.lowerBound])
                        let upperBoundString = String(rangeString[dashRange.upperBound ..< rangeString.endIndex])
                        
                        if let lowerBound = Int(lowerBoundString), let upperBound = Int(upperBoundString) {
                            requestRange = lowerBound ..< upperBound
                        }
                    }
                }
            }
            
            guard let firstSlash = requestPath.range(of: "/") else {
                self.sendErrorAndClose(connection: connection, error: .notFound)
                return
            }
            let streamId = String(requestPath[requestPath.startIndex ..< firstSlash.lowerBound])
            guard let source = self.sourceReferences.copyItems().first(where: { $0.source?.id == streamId })?.source else {
                self.sendErrorAndClose(connection: connection)
                return
            }
            
            let filePath = String(requestPath[firstSlash.upperBound...])
            if filePath == "master.m3u8" {
                let _ = (source.masterPlaylistData()
                |> deliverOn(self.queue)
                |> take(1)).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    
                    self.sendResponseAndClose(connection: connection, data: result.data(using: .utf8)!)
                })
            } else if filePath.hasPrefix("hls_level_") && filePath.hasSuffix(".m3u8") {
                guard let levelIndex = Int(String(filePath[filePath.index(filePath.startIndex, offsetBy: "hls_level_".count) ..< filePath.index(filePath.endIndex, offsetBy: -".m3u8".count)])) else {
                    self.sendErrorAndClose(connection: connection)
                    return
                }
                
                let _ = (source.playlistData(quality: levelIndex)
                |> deliverOn(self.queue)
                |> take(1)).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    
                    self.sendResponseAndClose(connection: connection, data: result.data(using: .utf8)!)
                })
            } else if filePath.hasPrefix("hls_stream") && filePath.hasSuffix(".ts") {
                let fileId = String(filePath[filePath.index(filePath.startIndex, offsetBy: "hls_stream".count) ..< filePath.index(filePath.endIndex, offsetBy: -".ts".count)])
                guard let underscoreRange = fileId.range(of: "_") else {
                    self.sendErrorAndClose(connection: connection)
                    return
                }
                guard let levelIndex = Int(String(fileId[fileId.startIndex ..< underscoreRange.lowerBound])) else {
                    self.sendErrorAndClose(connection: connection)
                    return
                }
                guard let partIndex = Int(String(fileId[underscoreRange.upperBound...])) else {
                    self.sendErrorAndClose(connection: connection)
                    return
                }
                let _ = (source.partData(index: partIndex, quality: levelIndex)
                |> deliverOn(self.queue)
                |> take(1)).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    
                    if let result {
                        let sourceTempFile = TempBox.shared.tempFile(fileName: "part.mp4")
                        let tempFile = TempBox.shared.tempFile(fileName: "part.ts")
                        defer {
                            TempBox.shared.dispose(sourceTempFile)
                            TempBox.shared.dispose(tempFile)
                        }
                        
                        guard let _ = try? result.write(to: URL(fileURLWithPath: sourceTempFile.path)) else {
                            self.sendErrorAndClose(connection: connection, error: .internalServerError)
                            return
                        }
                        
                        let sourcePath = sourceTempFile.path
                        FFMpegLiveMuxer.remux(sourcePath, to: tempFile.path, offsetSeconds: Double(partIndex))
                        
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path)) {
                            self.sendResponseAndClose(connection: connection, data: data)
                        } else {
                            self.sendErrorAndClose(connection: connection, error: .internalServerError)
                        }
                    } else {
                        self.sendErrorAndClose(connection: connection, error: .notFound)
                    }
                })
            } else if filePath.hasPrefix("partfile") && filePath.hasSuffix(".mp4") {
                let fileId = String(filePath[filePath.index(filePath.startIndex, offsetBy: "partfile".count) ..< filePath.index(filePath.endIndex, offsetBy: -".mp4".count)])
                guard let fileIdValue = Int64(fileId) else {
                    self.sendErrorAndClose(connection: connection)
                    return
                }
                guard let requestRange else {
                    self.sendErrorAndClose(connection: connection)
                    return
                }
                let _ = (source.fileData(id: fileIdValue, range: requestRange.lowerBound ..< requestRange.upperBound + 1)
                |> deliverOn(self.queue)
                //|> timeout(5.0, queue: self.queue, alternate: .single(nil))
                |> take(1)).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    
                    if let (tempFile, tempFileRange, totalSize) = result {
                        self.sendResponseFileAndClose(connection: connection, file: tempFile, fileRange: tempFileRange, range: requestRange, totalSize: totalSize)
                    } else {
                        self.sendErrorAndClose(connection: connection, error: .internalServerError)
                    }
                })
            } else {
                let _ = (source.arbitraryFileData(path: filePath)
                |> deliverOn(self.queue)
                |> take(1)).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    
                    if let result {
                        self.sendResponseAndClose(connection: connection, data: result.data, contentType: result.contentType)
                    } else {
                        self.sendErrorAndClose(connection: connection, error: .notFound)
                    }
                })
            }
        }
        
        private func sendErrorAndClose(connection: NWConnection, error: ResponseError = .badRequest) {
            let errorResponse = "HTTP/1.1 \(error.httpString)\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
            connection.send(content: errorResponse.data(using: .utf8), completion: .contentProcessed { error in
                if let error {
                    Logger.shared.log("SharedHLSServer", "Failed to send response: \(error)")
                }
                connection.cancel()
            })
        }
        
        private func sendResponseAndClose(connection: NWConnection, data: Data, contentType: String = "application/octet-stream", range: Range<Int>? = nil, totalSize: Int? = nil) {
            var responseHeaders = "HTTP/1.1 200 OK\r\n"
            responseHeaders.append("Content-Length: \(data.count)\r\n")
            if let range, let totalSize {
                responseHeaders.append("Content-Range: bytes \(range.lowerBound)-\(range.upperBound)/\(totalSize)\r\n")
            }
            
            responseHeaders.append("Content-Type: \(contentType)\r\n")
            responseHeaders.append("Connection: close\r\n")
            responseHeaders.append("Access-Control-Allow-Origin: *\r\n")
            responseHeaders.append("\r\n")
            var responseData = Data()
            responseData.append(responseHeaders.data(using: .utf8)!)
            responseData.append(data)
            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error {
                    Logger.shared.log("SharedHLSServer", "Failed to send response: \(error)")
                }
                connection.cancel()
            })
        }
        
        private static func sendRemainingFileRange(queue: Queue, connection: NWConnection, tempFile: TempBoxFile, managedFile: ManagedFile, remainingRange: Range<Int>, fileSize: Int) -> Void {
            let blockSize = 256 * 1024
            
            let clippedLowerBound = min(remainingRange.lowerBound, fileSize)
            var clippedUpperBound = min(remainingRange.upperBound, fileSize)
            clippedUpperBound = min(clippedUpperBound, clippedLowerBound + blockSize)
            
            if clippedUpperBound == clippedLowerBound {
                TempBox.shared.dispose(tempFile)
                connection.cancel()
            } else {
                let _ = managedFile.seek(position: Int64(clippedLowerBound))
                let data = managedFile.readData(count: Int(clippedUpperBound - clippedLowerBound))
                let nextRange = clippedUpperBound ..< remainingRange.upperBound
                
                connection.send(content: data, completion: .contentProcessed { error in
                    queue.async {
                        if let error {
                            Logger.shared.log("SharedHLSServer", "Failed to send response: \(error)")
                            connection.cancel()
                            TempBox.shared.dispose(tempFile)
                        } else {
                            sendRemainingFileRange(queue: queue, connection: connection, tempFile: tempFile, managedFile: managedFile, remainingRange: nextRange, fileSize: fileSize)
                        }
                    }
                })
            }
        }
        
        private func sendResponseFileAndClose(connection: NWConnection, file: TempBoxFile, fileRange: Range<Int>, range: Range<Int>, totalSize: Int) {
            let queue = self.queue
            
            guard let managedFile = ManagedFile(queue: nil, path: file.path, mode: .read), let fileSize = managedFile.getSize() else {
                self.sendErrorAndClose(connection: connection, error: .internalServerError)
                TempBox.shared.dispose(file)
                return
            }
            
            var responseHeaders = "HTTP/1.1 200 OK\r\n"
            responseHeaders.append("Content-Length: \(fileRange.upperBound - fileRange.lowerBound)\r\n")
            responseHeaders.append("Content-Range: bytes \(range.lowerBound)-\(range.upperBound)/\(totalSize)\r\n")
            responseHeaders.append("Content-Type: application/octet-stream\r\n")
            responseHeaders.append("Connection: close\r\n")
            responseHeaders.append("Access-Control-Allow-Origin: *\r\n")
            responseHeaders.append("\r\n")
            
            connection.send(content: responseHeaders.data(using: .utf8)!, completion: .contentProcessed({ _ in }))
            
            Impl.sendRemainingFileRange(queue: queue, connection: connection, tempFile: file, managedFile: managedFile, remainingRange: fileRange, fileSize: Int(fileSize))
        }
        
        func registerPlayer(source: SharedHLSServerSource, completion: @escaping () -> Void) -> Disposable {
            let queue = self.queue
            let index = self.sourceReferences.add(SourceReference(source: source))
            self.updateNeedsListener()
            completion()
            
            return ActionDisposable { [weak self] in
                queue.async {
                    guard let self else {
                        return
                    }
                    self.sourceReferences.remove(index)
                    self.updateNeedsListener()
                }
            }
        }
    }
    
    private static let queue = Queue(name: "SharedHLSServer")
    public let port: UInt16 = 8016
    private let impl: QueueLocalObject<Impl>
    
    private init() {
        let queue = SharedHLSServer.queue
        let port = self.port
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, port: port)
        })
    }
    
    public func registerPlayer(source: SharedHLSServerSource, completion: @escaping () -> Void) -> Disposable {
        let disposable = MetaDisposable()
        
        self.impl.with { impl in
            disposable.set(impl.registerPlayer(source: source, completion: completion))
        }
        
        return disposable
    }
}
