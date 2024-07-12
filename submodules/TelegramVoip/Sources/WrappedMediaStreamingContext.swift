import Foundation
import SwiftSignalKit
import TgVoipWebrtc
import TelegramCore
import Network
import Postbox
import FFMpegBinding


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
public final class ExternalMediaStreamingContext {
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
    }
    
    private let queue = Queue()
    let id: CallSessionInternalId
    private let impl: QueueLocalObject<Impl>
    private var hlsServerDisposable: Disposable?
    
    public init(id: CallSessionInternalId, rejoinNeeded: @escaping () -> Void) {
        self.id = id
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, rejoinNeeded: rejoinNeeded)
        })
        
        self.hlsServerDisposable = SharedHLSServer.shared.registerPlayer(streamingContext: self)
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
}
@available(iOS 12.0, macOS 14.0, *)
public final class SharedHLSServer {
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
    
    private final class ContextReference {
        weak var streamingContext: ExternalMediaStreamingContext?
        
        init(streamingContext: ExternalMediaStreamingContext) {
            self.streamingContext = streamingContext
        }
    }
    @available(iOS 12.0, macOS 14.0, *)
    private final class Impl {
        private let queue: Queue
        
        private let port: NWEndpoint.Port
        private var listener: NWListener?
        
        private var contextReferences = Bag<ContextReference>()
        
        init(queue: Queue, port: UInt16) {
            self.queue = queue
            self.port = NWEndpoint.Port(rawValue: port)!
            self.start()
        }
        
        func start() {
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
            
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else {
                    return
                }
                switch state {
                case .ready:
                    Logger.shared.log("SharedHLSServer", "Server is ready on port \(self.port)")
                case let .failed(error):
                    Logger.shared.log("SharedHLSServer", "Server failed with error: \(error)")
                    self.listener?.cancel()
                    
                    self.listener?.start(queue: self.queue.queue)
                default:
                    break
                }
            }
            
            listener.start(queue: self.queue.queue)
        }
        
        private func handleConnection(connection: NWConnection) {
            connection.start(queue: self.queue.queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024, completion: { [weak self] data, _, isComplete, error in
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
            
            guard let firstSlash = requestPath.range(of: "/") else {
                self.sendErrorAndClose(connection: connection, error: .notFound)
                return
            }
            guard let streamId = UUID(uuidString: String(requestPath[requestPath.startIndex ..< firstSlash.lowerBound])) else {
                self.sendErrorAndClose(connection: connection)
                return
            }
            guard let streamingContext = self.contextReferences.copyItems().first(where: { $0.streamingContext?.id == streamId })?.streamingContext else {
                self.sendErrorAndClose(connection: connection)
                return
            }
            
            let filePath = String(requestPath[firstSlash.upperBound...])
            if filePath == "master.m3u8" {
                let _ = (streamingContext.masterPlaylistData()
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
                
                let _ = (streamingContext.playlistData(quality: levelIndex)
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
                let _ = (streamingContext.partData(index: partIndex, quality: levelIndex)
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
            } else {
                self.sendErrorAndClose(connection: connection, error: .notFound)
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
        
        private func sendResponseAndClose(connection: NWConnection, data: Data) {
            let responseHeaders = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nConnection: close\r\n\r\n"
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
        
        func registerPlayer(streamingContext: ExternalMediaStreamingContext) -> Disposable {
            let queue = self.queue
            let index = self.contextReferences.add(ContextReference(streamingContext: streamingContext))
            
            return ActionDisposable { [weak self] in
                queue.async {
                    guard let self else {
                        return
                    }
                    self.contextReferences.remove(index)
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
    
    fileprivate func registerPlayer(streamingContext: ExternalMediaStreamingContext) -> Disposable {
        let disposable = MetaDisposable()
        
        self.impl.with { impl in
            disposable.set(impl.registerPlayer(streamingContext: streamingContext))
        }
        
        return disposable
    }
}
