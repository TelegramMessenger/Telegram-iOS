import Foundation
import AVFoundation
import SwiftSignalKit
import UniversalMediaPlayer
import Postbox
import TelegramCore
import UIKit
import AsyncDisplayKit
import AccountContext
import TelegramAudio
import Display
import PhotoResources
import TelegramVoip
import RangeSet
import AppBundle
import ManagedFile
import FFMpegBinding
import RangeSet

private func parseRange(from rangeString: String) -> Range<Int>? {
    guard rangeString.hasPrefix("bytes=") else {
        return nil
    }
    
    let rangeValues = rangeString.dropFirst("bytes=".count).split(separator: "-")
    
    guard rangeValues.count == 2,
          let start = Int(rangeValues[0]),
          let end = Int(rangeValues[1]) else {
        return nil
    }
    return start ..< end
}

final class HLSJSServerSource: SharedHLSServer.Source {
    let id: String
    let postbox: Postbox
    let userLocation: MediaResourceUserLocation
    let playlistFiles: [Int: FileMediaReference]
    let qualityFiles: [Int: FileMediaReference]
    
    private var playlistFetchDisposables: [Int: Disposable] = [:]
    
    init(accountId: Int64, fileId: Int64, postbox: Postbox, userLocation: MediaResourceUserLocation, playlistFiles: [Int: FileMediaReference], qualityFiles: [Int: FileMediaReference]) {
        self.id = "\(UInt64(bitPattern: accountId))_\(fileId)"
        self.postbox = postbox
        self.userLocation = userLocation
        self.playlistFiles = playlistFiles
        self.qualityFiles = qualityFiles
    }
    
    deinit {
        for (_, disposable) in self.playlistFetchDisposables {
            disposable.dispose()
        }
    }
    
    func arbitraryFileData(path: String) -> Signal<(data: Data, contentType: String)?, NoError> {
        return Signal { subscriber in
            let bundle = Bundle(for: HLSJSServerSource.self)
            
            let bundlePath = bundle.bundlePath + "/HlsBundle.bundle"
            if let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath + "/" + path)) {
                let mimeType: String
                let pathExtension = (path as NSString).pathExtension
                if pathExtension == "html" {
                    mimeType = "text/html"
                } else if pathExtension == "html" {
                    mimeType = "application/javascript"
                } else {
                    mimeType = "application/octet-stream"
                }
                subscriber.putNext((data, mimeType))
            } else {
                subscriber.putNext(nil)
            }
            
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    func masterPlaylistData() -> Signal<String, NoError> {
        var playlistString: String = ""
        playlistString.append("#EXTM3U\n")
        
        for (quality, file) in self.qualityFiles.sorted(by: { $0.key > $1.key }) {
            let width = file.media.dimensions?.width ?? 1280
            let height = file.media.dimensions?.height ?? 720
            
            let bandwidth: Int
            if let size = file.media.size, let duration = file.media.duration, duration != 0.0 {
                bandwidth = Int(Double(size) / duration) * 8
            } else {
                bandwidth = 1000000
            }
            
            playlistString.append("#EXT-X-STREAM-INF:BANDWIDTH=\(bandwidth),RESOLUTION=\(width)x\(height)\n")
            playlistString.append("hls_level_\(quality).m3u8\n")
        }
        return .single(playlistString)
    }
    
    func playlistData(quality: Int) -> Signal<String, NoError> {
        guard let playlistFile = self.playlistFiles[quality] else {
            return .never()
        }
        if self.playlistFetchDisposables[quality] == nil {
            self.playlistFetchDisposables[quality] = freeMediaFileResourceInteractiveFetched(postbox: self.postbox, userLocation: self.userLocation, fileReference: playlistFile, resource: playlistFile.media.resource).startStrict()
        }
        
        return self.postbox.mediaBox.resourceData(playlistFile.media.resource)
        |> filter { data in
            return data.complete
        }
        |> map { data -> String in
            guard data.complete else {
                return ""
            }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                return ""
            }
            guard var playlistString = String(data: data, encoding: .utf8) else {
                return ""
            }
            let partRegex = try! NSRegularExpression(pattern: "mtproto:([\\d]+)", options: [])
            let results = partRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
            for result in results.reversed() {
                if let range = Range(result.range, in: playlistString) {
                    if let fileIdRange = Range(result.range(at: 1), in: playlistString) {
                        let fileId = String(playlistString[fileIdRange])
                        playlistString.replaceSubrange(range, with: "partfile\(fileId).mp4")
                    }
                }
            }
            return playlistString
        }
    }
    
    func partData(index: Int, quality: Int) -> Signal<Data?, NoError> {
        return .never()
    }
    
    func fileData(id: Int64, range: Range<Int>) -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError> {
        guard let (quality, file) = self.qualityFiles.first(where: { $0.value.media.fileId.id == id }) else {
            return .single(nil)
        }
        
        guard let size = file.media.size else {
            return .single(nil)
        }
        
        let postbox = self.postbox
        let userLocation = self.userLocation
        
        let playlistPreloadRange = self.playlistData(quality: quality)
        |> mapToSignal { playlistString -> Signal<Range<Int64>?, NoError> in
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
            
            let prefixSeconds = 10
            var rangeUpperBound: Int64 = 0
            if durations.count == byteRanges.count {
                var remainingSeconds = prefixSeconds
                
                for i in 0 ..< durations.count {
                    if remainingSeconds <= 0 {
                        break
                    }
                    let duration = durations[i]
                    let byteRange = byteRanges[i]
                    
                    remainingSeconds -= duration
                    rangeUpperBound = max(rangeUpperBound, Int64(byteRange.upperBound))
                }
            }

            if rangeUpperBound != 0 {
                return .single(0 ..< rangeUpperBound)
            } else {
                return .single(nil)
            }
        }
        
        let mappedRange: Range<Int64> = Int64(range.lowerBound) ..< Int64(range.upperBound)
        
        let queue = postbox.mediaBox.dataQueue
        let fetchFromRemote: Signal<(TempBoxFile, Range<Int>, Int)?, NoError> = playlistPreloadRange
        |> mapToSignal { preloadRange -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError> in
            return Signal { subscriber in
                let partialFile = TempBox.shared.tempFile(fileName: "data")
                
                if let cachedData = postbox.mediaBox.internal_resourceData(id: file.media.resource.id, size: size, in: Int64(range.lowerBound) ..< Int64(range.upperBound)) {
                    #if DEBUG
                    print("Fetched \(quality)p part from cache")
                    #endif
                    
                    let outputFile = ManagedFile(queue: nil, path: partialFile.path, mode: .readwrite)
                    if let outputFile {
                        let blockSize = 128 * 1024
                        var tempBuffer = Data(count: blockSize)
                        var blockOffset = 0
                        while blockOffset < cachedData.length {
                            let currentBlockSize = min(cachedData.length - blockOffset, blockSize)
                            
                            tempBuffer.withUnsafeMutableBytes { bytes -> Void in
                                let _ = cachedData.file.read(bytes.baseAddress!, currentBlockSize)
                                let _ = outputFile.write(bytes.baseAddress!, count: currentBlockSize)
                            }
                            
                            blockOffset += blockSize
                        }
                        outputFile._unsafeClose()
                        subscriber.putNext((partialFile, 0 ..< cachedData.length, Int(size)))
                        subscriber.putCompletion()
                    } else {
                        #if DEBUG
                        print("Error writing cached file to disk")
                        #endif
                    }
                    
                    return EmptyDisposable
                }
                
                guard let fetchResource = postbox.mediaBox.fetchResource else {
                    return EmptyDisposable
                }
                
                let location = MediaResourceStorageLocation(userLocation: userLocation, reference: file.resourceReference(file.media.resource))
                let params = MediaResourceFetchParameters(
                    tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video),
                    info: TelegramCloudMediaResourceFetchInfo(reference: file.resourceReference(file.media.resource), preferBackgroundReferenceRevalidation: true, continueInBackground: true),
                    location: location,
                    contentType: .video,
                    isRandomAccessAllowed: true
                )
                
                let completeFile = TempBox.shared.tempFile(fileName: "data")
                let metaFile = TempBox.shared.tempFile(fileName: "data")
                
                guard let fileContext = MediaBoxFileContextV2Impl(
                    queue: queue,
                    manager: postbox.mediaBox.dataFileManager,
                    storageBox: nil,
                    resourceId: file.media.resource.id.stringRepresentation.data(using: .utf8)!,
                    path: completeFile.path,
                    partialPath: partialFile.path,
                    metaPath: metaFile.path
                ) else {
                    return EmptyDisposable
                }
                
                let fetchDisposable = fileContext.fetched(
                    range: mappedRange,
                    priority: .default,
                    fetch: { intervals in
                        return fetchResource(file.media.resource, intervals, params)
                    },
                    error: { _ in
                    },
                    completed: {
                    }
                )
                
                #if DEBUG
                let startTime = CFAbsoluteTimeGetCurrent()
                #endif
                
                let dataDisposable = fileContext.data(
                    range: mappedRange,
                    waitUntilAfterInitialFetch: true,
                    next: { result in
                        if result.complete {
                            #if DEBUG
                            let fetchTime = CFAbsoluteTimeGetCurrent() - startTime
                            print("Fetching \(quality)p part took \(fetchTime * 1000.0) ms")
                            #endif
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: partialFile.path), options: .alwaysMapped) {
                                let subData = data.subdata(in: Int(result.offset) ..< Int(result.offset + result.size))
                                postbox.mediaBox.storeResourceData(file.media.resource.id, range: Int64(range.lowerBound) ..< Int64(range.upperBound), data: subData)
                            }
                            subscriber.putNext((partialFile, Int(result.offset) ..< Int(result.offset + result.size), Int(size)))
                            subscriber.putCompletion()
                        }
                    }
                )
                
                return ActionDisposable {
                    queue.async {
                        fetchDisposable.dispose()
                        dataDisposable.dispose()
                        fileContext.cancelFullRangeFetches()
                        
                        TempBox.shared.dispose(completeFile)
                        TempBox.shared.dispose(metaFile)
                    }
                }
            }
            |> runOn(queue)
        }
        
        return fetchFromRemote
    }
}

protocol HLSJSContext: AnyObject {
    func evaluateJavaScript(_ string: String)
}

private final class SharedHLSVideoJSContext: NSObject {
    private final class ContextReference {
        weak var contentNode: HLSVideoJSNativeContentNode?
        
        init(contentNode: HLSVideoJSNativeContentNode?) {
            self.contentNode = contentNode
        }
    }
    
    private enum ResponseError {
       case badRequest
       case notFound
       case internalServerError
       
       var httpStatus: (Int, String) {
           switch self {
           case .badRequest:
               return (400, "Bad Request")
           case .notFound:
               return (404, "Not Found")
           case .internalServerError:
               return (500, "Internal Server Error")
           }
       }
    }
    
    static let shared: SharedHLSVideoJSContext = SharedHLSVideoJSContext()
    
    private var contextReferences: [Int: ContextReference] = [:]
    
    var jsContext: HLSJSContext?
    
    var videoElements: [Int: VideoElement] = [:]
    var mediaSources: [Int: MediaSource] = [:]
    var sourceBuffers: [Int: SourceBuffer] = [:]
    
    private var isJsContextReady: Bool = false
    private var pendingInitializeInstanceIds: [(id: Int, urlPrefix: String)] = []
    
    private var tempTasks: [Int: URLSessionTask] = [:]
    
    private var emptyTimer: Foundation.Timer?
    
    override init() {
        super.init()
    }
    
    deinit {
        self.emptyTimer?.invalidate()
    }
    
    private func createJsContext() {
        let handleScriptMessage: ([String: Any]) -> Void = {  [weak self] message in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                
                guard let eventName = message["event"] as? String else {
                    return
                }
                
                switch eventName {
                case "windowOnLoad":
                    self.isJsContextReady = true
                    
                    self.initializePendingInstances()
                case "bridgeInvoke":
                    guard let eventData = message["data"] as? [String: Any] else {
                        return
                    }
                    guard let bridgeId = eventData["bridgeId"] as? Int else {
                        return
                    }
                    guard let callbackId = eventData["callbackId"] as? Int else {
                        return
                    }
                    guard let className = eventData["className"] as? String else {
                        return
                    }
                    guard let methodName = eventData["methodName"] as? String else {
                        return
                    }
                    guard let params = eventData["params"] as? [String: Any] else {
                        return
                    }
                    self.bridgeInvoke(
                        bridgeId: bridgeId,
                        className: className,
                        methodName: methodName,
                        params: params,
                        completion: { [weak self] result in
                            guard let self else {
                                return
                            }
                            let jsonResult = try! JSONSerialization.data(withJSONObject: result)
                            let jsonResultString = String(data: jsonResult, encoding: .utf8)!
                            self.jsContext?.evaluateJavaScript("window.bridgeInvokeCallback(\(callbackId), \(jsonResultString));")
                        }
                    )
                case "playerStatus":
                    guard let instanceId = message["instanceId"] as? Int else {
                        return
                    }
                    guard let instance = self.contextReferences[instanceId]?.contentNode else {
                        self.contextReferences.removeValue(forKey: instanceId)
                        return
                    }
                    guard let eventData = message["data"] as? [String: Any] else {
                        return
                    }
                    
                    instance.onPlayerStatusUpdated(eventData: eventData)
                case "playerCurrentTime":
                    guard let instanceId = message["instanceId"] as? Int else {
                        return
                    }
                    guard let instance = self.contextReferences[instanceId]?.contentNode else {
                        self.contextReferences.removeValue(forKey: instanceId)
                        self.cleanupContextsIfEmpty()
                        return
                    }
                    guard let eventData = message["data"] as? [String: Any] else {
                        return
                    }
                    guard let value = eventData["value"] as? Double else {
                        return
                    }
                    
                    instance.onPlayerUpdatedCurrentTime(currentTime: value)
                    
                    var bandwidthEstimate = eventData["bandwidthEstimate"] as? Double
                    if let bandwidthEstimateValue = bandwidthEstimate, bandwidthEstimateValue.isNaN || bandwidthEstimateValue.isInfinite {
                        bandwidthEstimate = nil
                    }
                    
                    HLSVideoJSNativeContentNode.sharedBandwidthEstimate = bandwidthEstimate
                default:
                    break
                }
            }
        }
        
        self.isJsContextReady = false
        
        //#if DEBUG
        self.jsContext = WebViewNativeJSContextImpl(handleScriptMessage: handleScriptMessage)
        /*#else
        self.jsContext = WebViewHLSJSContextImpl(handleScriptMessage: handleScriptMessage)
        #endif*/
    }
    
    private func disposeJsContext() {
        if let _ = self.jsContext {
            self.jsContext = nil
        }
        self.isJsContextReady = false
        
        self.videoElements.removeAll()
        self.mediaSources.removeAll()
        self.sourceBuffers.removeAll()
    }
    
    private func bridgeInvoke(
        bridgeId: Int,
        className: String,
        methodName: String,
        params: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        if (className == "VideoElement") {
            if (methodName == "constructor") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                let videoElement = VideoElement(instanceId: instanceId)
                SharedHLSVideoJSContext.shared.videoElements[bridgeId] = videoElement
                completion([:])
            } else if (methodName == "setMediaSource") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let mediaSourceId = params["mediaSourceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == instanceId }) else {
                    return
                }
                videoElement.mediaSourceId = mediaSourceId
            } else if (methodName == "setCurrentTime") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let currentTime = params["currentTime"] as? Double else {
                    assertionFailure()
                    return
                }
                
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onSetCurrentTime(timestamp: currentTime)
                }
                
                completion([:])
            } else if (methodName == "setPlaybackRate") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let playbackRate = params["playbackRate"] as? Double else {
                    assertionFailure()
                    return
                }
                
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onSetPlaybackRate(playbackRate: playbackRate)
                }
                
                completion([:])
            } else if (methodName == "play") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onPlay()
                }
                
                completion([:])
            } else if (methodName == "pause") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onPause()
                }
                
                completion([:])
            }
        } else if (className == "MediaSource") {
            if (methodName == "constructor") {
                let mediaSource = MediaSource()
                SharedHLSVideoJSContext.shared.mediaSources[bridgeId] = mediaSource
                completion([:])
            } else if (methodName == "setDuration") {
                guard let duration = params["duration"] as? Double else {
                    assertionFailure()
                    return
                }
                guard let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[bridgeId] else {
                    assertionFailure()
                    return
                }
                var durationUpdated = false
                if mediaSource.duration != duration {
                    mediaSource.duration = duration
                    durationUpdated = true
                }
                
                guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.mediaSourceId == bridgeId }) else {
                    return
                }
                
                if let instance = self.contextReferences[videoElement.instanceId]?.contentNode {
                    if durationUpdated {
                        instance.onMediaSourceDurationUpdated()
                    }
                }
                completion([:])
            } else if (methodName == "updateSourceBuffers") {
                guard let ids = params["ids"] as? [Int] else {
                    assertionFailure()
                    return
                }
                guard let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[bridgeId] else {
                    assertionFailure()
                    return
                }
                mediaSource.sourceBufferIds = ids
                
                guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.mediaSourceId == bridgeId }) else {
                    return
                }
                
                if let instance = self.contextReferences[videoElement.instanceId]?.contentNode {
                    instance.onMediaSourceBuffersUpdated()
                }
            }
        } else if (className == "SourceBuffer") {
            if (methodName == "constructor") {
                guard let mediaSourceId = params["mediaSourceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let mimeType = params["mimeType"] as? String else {
                    assertionFailure()
                    return
                }
                let sourceBuffer = SourceBuffer(mediaSourceId: mediaSourceId, mimeType: mimeType)
                SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] = sourceBuffer
                
                completion([:])
            } else if (methodName == "appendBuffer") {
                guard let base64Data = params["data"] as? String else {
                    assertionFailure()
                    return
                }
                guard let data = Data(base64Encoded: base64Data.data(using: .utf8)!) else {
                    assertionFailure()
                    return
                }
                guard let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.appendBuffer(data: data, completion: { bufferedRanges in
                    completion(["ranges": serializeRanges(bufferedRanges)])
                })
            } else if methodName == "remove" {
                guard let start = params["start"] as? Double, let end = params["end"] as? Double else {
                    assertionFailure()
                    return
                }
                guard let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.remove(start: start, end: end, completion: { bufferedRanges in
                    completion(["ranges": serializeRanges(bufferedRanges)])
                })
            } else if methodName == "abort" {
                guard let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.abortOperation()
                completion([:])
            }
        } else if className == "XMLHttpRequest" {
            if methodName == "load" {
                guard let id = params["id"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let url = params["url"] as? String else {
                    assertionFailure()
                    return
                }
                guard let requestHeaders = params["requestHeaders"] as? [String: String] else {
                    assertionFailure()
                    return
                }
                guard let parsedUrl = URL(string: url) else {
                    assertionFailure()
                    return
                }
                guard let host = parsedUrl.host, host == "server" else {
                    completion(["error": 1])
                    return
                }
                
                var requestPath = parsedUrl.path
                if requestPath.hasPrefix("/") {
                    requestPath = String(requestPath[requestPath.index(after: requestPath.startIndex) ..< requestPath.endIndex])
                }
                
                guard let firstSlash = requestPath.range(of: "/") else {
                    completion(["error": 1])
                    return
                }
                
                var requestRange: Range<Int>?
                if let rangeString = requestHeaders["Range"] {
                    requestRange = parseRange(from: rangeString)
                }
                
                let streamId = String(requestPath[requestPath.startIndex ..< firstSlash.lowerBound])
                
                var handlerFound = false
                for (_, contextReference) in self.contextReferences {
                    if let context = contextReference.contentNode, let source = context.playerSource, source.id == streamId {
                        handlerFound = true
                        
                        let filePath = String(requestPath[firstSlash.upperBound...])
                        if filePath == "master.m3u8" {
                            let _ = (source.masterPlaylistData()
                            |> take(1)).start(next: { result in
                                SharedHLSVideoJSContext.sendResponseAndClose(id: id, data: result.data(using: .utf8)!, completion: completion)
                            })
                        } else if filePath.hasPrefix("hls_level_") && filePath.hasSuffix(".m3u8") {
                            guard let levelIndex = Int(String(filePath[filePath.index(filePath.startIndex, offsetBy: "hls_level_".count) ..< filePath.index(filePath.endIndex, offsetBy: -".m3u8".count)])) else {
                                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .notFound, completion: completion)
                                return
                            }
                            
                            let _ = (source.playlistData(quality: levelIndex)
                            |> deliverOn(.mainQueue())
                            |> take(1)).start(next: { result in
                                SharedHLSVideoJSContext.sendResponseAndClose(id: id, data: result.data(using: .utf8)!, completion: completion)
                            })
                        } else if filePath.hasPrefix("partfile") && filePath.hasSuffix(".mp4") {
                            let fileId = String(filePath[filePath.index(filePath.startIndex, offsetBy: "partfile".count) ..< filePath.index(filePath.endIndex, offsetBy: -".mp4".count)])
                            guard let fileIdValue = Int64(fileId) else {
                                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .notFound, completion: completion)
                                return
                            }
                            guard let requestRange else {
                                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .badRequest, completion: completion)
                                return
                            }
                            let _ = (source.fileData(id: fileIdValue, range: requestRange.lowerBound ..< requestRange.upperBound + 1)
                            |> deliverOn(.mainQueue())
                            //|> timeout(5.0, queue: self.queue, alternate: .single(nil))
                            |> take(1)).start(next: { result in
                                if let (tempFile, tempFileRange, totalSize) = result {
                                    SharedHLSVideoJSContext.sendResponseFileAndClose(id: id, file: tempFile, fileRange: tempFileRange, range: requestRange, totalSize: totalSize, completion: completion)
                                } else {
                                    SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .internalServerError, completion: completion)
                                }
                            })
                        }
                        
                        break
                    }
                }
                
                if (!handlerFound) {
                    completion(["error": 1])
                }
            } else if methodName == "abort" {
                guard let id = params["id"] as? Int else {
                    assertionFailure()
                    return
                }
                
                if let task = self.tempTasks.removeValue(forKey: id) {
                    task.cancel()
                }
                
                completion([:])
            }
        }
    }
    
    private static func sendErrorAndClose(id: Int, error: ResponseError, completion: @escaping ([String: Any]) -> Void) {
        let (code, status) = error.httpStatus
        completion([
            "status": code,
            "statusText": status,
            "responseData": "",
            "responseHeaders": [
                "Content-Type": "text/html"
            ] as [String: String]
        ])
    }
    
    private static func sendResponseAndClose(id: Int, data: Data, contentType: String = "application/octet-stream", completion: @escaping ([String: Any]) -> Void) {
        completion([
            "status": 200,
            "statusText": "OK",
            "responseData": data.base64EncodedString(),
            "responseHeaders": [
                "Content-Type": contentType,
                "Content-Length": "\(data.count)"
            ] as [String: String]
        ])
    }
    
    private static func sendResponseFileAndClose(id: Int, file: TempBoxFile, fileRange: Range<Int>, range: Range<Int>, totalSize: Int, completion: @escaping ([String: Any]) -> Void) {
        Queue.concurrentDefaultQueue().async {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: file.path), options: .mappedIfSafe).subdata(in: fileRange) {
                completion([
                    "status": 200,
                    "statusText": "OK",
                    "responseData": data.base64EncodedString(),
                    "responseHeaders": [
                        "Content-Type": "application/octet-stream",
                        "Content-Range": "bytes \(range.lowerBound)-\(range.upperBound)/\(totalSize)",
                        "Content-Length": "\(fileRange.upperBound - fileRange.lowerBound)"
                    ] as [String: String]
                ])
            } else {
                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .internalServerError, completion: completion)
            }
        }
    }
    
    func register(context: HLSVideoJSNativeContentNode) -> Disposable {
        let contextInstanceId = context.instanceId
        self.contextReferences[contextInstanceId] = ContextReference(contentNode: context)
        
        if self.jsContext == nil {
            self.createJsContext()
        }
        
        if let emptyTimer = self.emptyTimer {
            self.emptyTimer = nil
            emptyTimer.invalidate()
        }
        
        return ActionDisposable { [weak self, weak context] in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.pendingInitializeInstanceIds.removeAll(where: { $0.id == contextInstanceId })
                
                if let current = self.contextReferences[contextInstanceId] {
                    if let value = current.contentNode {
                        if let context, context === value {
                            self.contextReferences.removeValue(forKey: contextInstanceId)
                        }
                    } else {
                        self.contextReferences.removeValue(forKey: contextInstanceId)
                    }
                }
                
                self.jsContext?.evaluateJavaScript("window.hlsPlayer_destroyInstance(\(contextInstanceId));")
                
                self.cleanupContextsIfEmpty()
            }
        }
    }
    
    private func cleanupContextsIfEmpty() {
        if self.contextReferences.isEmpty {
            if self.emptyTimer == nil {
                let disposeTimeout: Double
                #if DEBUG
                disposeTimeout = 0.5
                #else
                disposeTimeout = 10.0
                #endif
                
                self.emptyTimer = Foundation.Timer.scheduledTimer(withTimeInterval: disposeTimeout, repeats: false, block: { [weak self] timer in
                    guard let self else {
                        return
                    }
                    if self.emptyTimer === timer {
                        self.emptyTimer = nil
                    }
                    if self.contextReferences.isEmpty {
                        self.disposeJsContext()
                    }
                })
            }
        }
    }
    
    func initializeWhenReady(context: HLSVideoJSNativeContentNode, urlPrefix: String) {
        self.pendingInitializeInstanceIds.append((context.instanceId, urlPrefix))
        
        if self.isJsContextReady {
            self.initializePendingInstances()
        }
    }
    
    private func initializePendingInstances() {
        let pendingInitializeInstanceIds = self.pendingInitializeInstanceIds
        self.pendingInitializeInstanceIds.removeAll()
        
        if pendingInitializeInstanceIds.isEmpty {
            return
        }
        
        let isDebug: Bool
        #if DEBUG
        isDebug = true
        #else
        isDebug = false
        #endif
        
        var userScriptJs = ""
        for (instanceId, urlPrefix) in pendingInitializeInstanceIds {
            guard let _ = self.contextReferences[instanceId]?.contentNode else {
                self.contextReferences.removeValue(forKey: instanceId)
                self.cleanupContextsIfEmpty()
                continue
            }
            userScriptJs.append("window.hlsPlayer_makeInstance(\(instanceId));\n")
            userScriptJs.append("""
            window.hlsPlayer_instances[\(instanceId)].playerInitialize({
                'debug': \(isDebug),
                'bandwidthEstimate': \(HLSVideoJSNativeContentNode.sharedBandwidthEstimate ?? 500000.0),
                'urlPrefix': '\(urlPrefix)'
            });\n
            """)
        }
        
        self.jsContext?.evaluateJavaScript(userScriptJs)
    }
}

final class HLSVideoJSNativeContentNode: ASDisplayNode, UniversalVideoContentNode {
    fileprivate struct Level {
        let bitrate: Int
        let width: Int
        let height: Int
        
        init(bitrate: Int, width: Int, height: Int) {
            self.bitrate = bitrate
            self.width = width
            self.height = height
        }
    }
    
    private struct VideoQualityState: Equatable {
        var current: Int
        var preferred: UniversalVideoContentVideoQuality
        var available: [Int]
        
        init(current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int]) {
            self.current = current
            self.preferred = preferred
            self.available = available
        }
    }
    
    fileprivate static var sharedBandwidthEstimate: Double?
    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize
    
    private var enableSound: Bool
    private let codecConfiguration: HLSCodecConfiguration

    private let audioSessionManager: ManagedAudioSession
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    fileprivate let playerSource: HLSJSServerSource?
    private var serverDisposable: Disposable?
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
    private var isBuffering = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    var isNativePictureInPictureActive: Signal<Bool, NoError> {
        return .single(false)
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private static var nextInstanceId: Int = 0
    fileprivate let instanceId: Int
    
    private let imageNode: TransformImageNode
    
    private let player: ChunkMediaPlayer
    private let playerNode: MediaPlayerNode
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: (size: CGSize, actualSize: CGSize)?
    
    private var statusTimer: Foundation.Timer?
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    
    fileprivate var playerIsReady: Bool = false
    fileprivate var playerIsPlaying: Bool = false
    fileprivate var playerRate: Double = 0.0
    fileprivate var playerDefaultRate: Double = 1.0
    fileprivate var playerTime: Double = 0.0
    
    fileprivate var playerAvailableLevels: [Int: Level] = [:]
    fileprivate var playerCurrentLevelIndex: Int?
   
    private var videoQualityStateValue: VideoQualityState?
    private let videoQualityStatePromise = Promise<VideoQualityState?>(nil)
    
    private var hasRequestedPlayerLoad: Bool = false
    
    private var requestedBaseRate: Double = 1.0
    private var requestedLevelIndex: Int?
    
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?
    
    private let chunkPlayerPartsState = Promise<ChunkMediaPlayerPartsState>(ChunkMediaPlayerPartsState(duration: nil, content: .parts([])))
    private var sourceBufferStateDisposable: Disposable?
    
    private var playerStatusDisposable: Disposable?
    
    private var contextDisposable: Disposable?
    
    init(context: AccountContext, postbox: Postbox, audioSessionManager: ManagedAudioSession, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool, onlyFullSizeThumbnail: Bool, useLargeThumbnail: Bool, autoFetchFullSizeThumbnail: Bool, codecConfiguration: HLSCodecConfiguration) {
        self.instanceId = HLSVideoJSNativeContentNode.nextInstanceId
        HLSVideoJSNativeContentNode.nextInstanceId += 1
        
        self.postbox = postbox
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.audioSessionManager = audioSessionManager
        self.userLocation = userLocation
        self.requestedBaseRate = baseRate
        self.enableSound = enableSound
        self.codecConfiguration = codecConfiguration
        
        if var dimensions = fileReference.media.dimensions {
            if let thumbnail = fileReference.media.previewRepresentations.first {
                let dimensionsVertical = dimensions.width < dimensions.height
                let thumbnailVertical = thumbnail.dimensions.width < thumbnail.dimensions.height
                if dimensionsVertical != thumbnailVertical {
                    dimensions = PixelDimensions(width: dimensions.height, height: dimensions.width)
                }
            }
            self.dimensions = dimensions.cgSize
        } else {
            self.dimensions = CGSize(width: 128.0, height: 128.0)
        }
        
        self.imageNode = TransformImageNode()
        
        var playerSource: HLSJSServerSource?
        if let qualitySet = HLSQualitySet(baseFile: fileReference, codecConfiguration: codecConfiguration) {
            let playerSourceValue = HLSJSServerSource(accountId: context.account.id.int64, fileId: fileReference.media.fileId.id, postbox: postbox, userLocation: userLocation, playlistFiles: qualitySet.playlistFiles, qualityFiles: qualitySet.qualityFiles)
            playerSource = playerSourceValue
        }
        self.playerSource = playerSource
        
        let mediaDimensions = fileReference.media.dimensions?.cgSize ?? CGSize(width: 480.0, height: 320.0)
        var intrinsicDimensions = mediaDimensions.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
        
        intrinsicDimensions.width = floor(intrinsicDimensions.width / UIScreenScale)
        intrinsicDimensions.height = floor(intrinsicDimensions.height / UIScreenScale)
        self.intrinsicDimensions = intrinsicDimensions
        
        self.playerNode = MediaPlayerNode()
        
        var onSeeked: (() -> Void)?
        self.player = ChunkMediaPlayerV2(
            params: ChunkMediaPlayerV2.MediaDataReaderParams(context: context),
            audioSessionManager: audioSessionManager,
            source: .externalParts(self.chunkPlayerPartsState.get()),
            video: true,
            enableSound: self.enableSound,
            baseRate: baseRate,
            onSeeked: {
                onSeeked?()
            },
            playerNode: self.playerNode
        )
        
        super.init()
        
        self.contextDisposable = SharedHLSVideoJSContext.shared.register(context: self)
        
        self.playerNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        
        var didProcessFramesToDisplay = false
        self.playerNode.isHidden = true
        self.playerNode.hasSentFramesToDisplay = { [weak self] in
            guard let self, !didProcessFramesToDisplay else {
                return
            }
            didProcessFramesToDisplay = true
            self.playerNode.isHidden = false
        }

        let thumbnailVideoReference = HLSVideoContent.minimizedHLSQuality(file: fileReference, codecConfiguration: self.codecConfiguration)?.file ?? fileReference
        
        self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, userLocation: userLocation, videoReference: thumbnailVideoReference, previewSourceFileReference: fileReference, imageReference: nil, onlyFullSize: onlyFullSizeThumbnail, useLargeThumbnail: useLargeThumbnail, autoFetchFullSizeThumbnail: autoFetchFullSizeThumbnail || fileReference.media.isInstantVideo) |> map { [weak self] getSize, getData in
            Queue.mainQueue().async {
                if let strongSelf = self, strongSelf.dimensions == nil {
                    if let dimensions = getSize() {
                        strongSelf.dimensions = dimensions
                        strongSelf.dimensionsPromise.set(dimensions)
                        if let validLayout = strongSelf.validLayout {
                            strongSelf.updateLayout(size: validLayout.size, actualSize: validLayout.actualSize, transition: .immediate)
                        }
                    }
                }
            }
            return getData
        })
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self._bufferingStatus.set(.single(nil))
        
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            let _ = self
        })
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            let _ = self
        })
        
        self.playerStatusDisposable = (self.player.status
        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
            guard let self else {
                return
            }
            self.updatePlayerStatus(status: status)
        })
        
        self.statusTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 25.0, repeats: true, block: { [weak self] _ in
            guard let self else {
                return
            }
            self.updateStatus()
        })
        
        onSeeked = { [weak self] in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("window.hlsPlayer_instances[\(self.instanceId)].playerNotifySeekedOnNextStatusUpdate();")
            }
        }
        
        if let playerSource {
            SharedHLSVideoJSContext.shared.initializeWhenReady(context: self, urlPrefix: "http://server/\(playerSource.id)/")
        }
    }
    
    deinit {
        if let didBecomeActiveObserver = self.didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let willResignActiveObserver = self.willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
        
        self.serverDisposable?.dispose()
        self.audioSessionDisposable.dispose()
        
        self.statusTimer?.invalidate()
        
        self.sourceBufferStateDisposable?.dispose()
        self.playerStatusDisposable?.dispose()
        
        self.contextDisposable?.dispose()
    }
    
    fileprivate func onPlayerStatusUpdated(eventData: [String: Any]) {
        if let isReady = eventData["isReady"] as? Bool {
            self.playerIsReady = isReady
        } else {
            self.playerIsReady = false
        }
        if let isPlaying = eventData["isPlaying"] as? Bool {
            self.playerIsPlaying = isPlaying
        } else {
            self.playerIsPlaying = false
        }
        if let rate = eventData["rate"] as? Double {
            self.playerRate = rate
        } else {
            self.playerRate = 0.0
        }
        if let defaultRate = eventData["defaultRate"] as? Double {
            self.playerDefaultRate = defaultRate
        } else {
            self.playerDefaultRate = 0.0
        }
        if let levels = eventData["levels"] as? [[String: Any]] {
            self.playerAvailableLevels.removeAll()
            
            for level in levels {
                guard let levelIndex = level["index"] as? Int else {
                    continue
                }
                guard let levelBitrate = level["bitrate"] as? Int else {
                    continue
                }
                guard let levelWidth = level["width"] as? Int else {
                    continue
                }
                guard let levelHeight = level["height"] as? Int else {
                    continue
                }
                self.playerAvailableLevels[levelIndex] = HLSVideoJSNativeContentNode.Level(
                    bitrate: levelBitrate,
                    width: levelWidth,
                    height: levelHeight
                )
            }
        } else {
            self.playerAvailableLevels.removeAll()
        }
        
        if let currentLevel = eventData["currentLevel"] as? Int {
            if self.playerAvailableLevels[currentLevel] != nil {
                self.playerCurrentLevelIndex = currentLevel
            } else {
                self.playerCurrentLevelIndex = nil
            }
        } else {
            self.playerCurrentLevelIndex = nil
        }
        
        self.updateVideoQualityState()
        
        if self.playerIsReady {
            if !self.hasRequestedPlayerLoad {
                if !self.playerAvailableLevels.isEmpty {
                    var selectedLevelIndex: Int?
                    
                    if let qualityFiles = HLSQualitySet(baseFile: self.fileReference, codecConfiguration: self.codecConfiguration)?.qualityFiles.values, let maxQualityFile = qualityFiles.max(by: { lhs, rhs in
                        if let lhsDimensions = lhs.media.dimensions, let rhsDimensions = rhs.media.dimensions {
                            return lhsDimensions.width < rhsDimensions.width
                        } else {
                            return lhs.media.fileId.id < rhs.media.fileId.id
                        }
                    }), let dimensions = maxQualityFile.media.dimensions {
                        if self.postbox.mediaBox.completedResourcePath(maxQualityFile.media.resource) != nil {
                            for (index, level) in self.playerAvailableLevels {
                                if level.height == Int(dimensions.height) {
                                    selectedLevelIndex = index
                                    break
                                }
                            }
                        }
                    }
                    
                    if selectedLevelIndex == nil {
                        if let minimizedQualityFile = HLSVideoContent.minimizedHLSQuality(file: self.fileReference, codecConfiguration: self.codecConfiguration)?.file {
                            if let dimensions = minimizedQualityFile.media.dimensions {
                                for (index, level) in self.playerAvailableLevels {
                                    if level.height == Int(dimensions.height) {
                                        selectedLevelIndex = index
                                        break
                                    }
                                }
                            }
                        }
                    }
                    if selectedLevelIndex == nil {
                        selectedLevelIndex = self.playerAvailableLevels.sorted(by: { $0.value.height > $1.value.height }).first?.key
                    }
                    if let selectedLevelIndex {
                        var effectiveSelectedLevelIndex = selectedLevelIndex
                        if !self.enableSound {
                            effectiveSelectedLevelIndex = self.resolveCurrentLevelIndex() ?? -1
                        }
                        
                        self.hasRequestedPlayerLoad = true
                        SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("""
                        window.hlsPlayer_instances[\(self.instanceId)].playerSetCapAutoLevel(\(self.resolveCurrentLevelIndex() ?? -1));
                        window.hlsPlayer_instances[\(self.instanceId)].playerLoad(\(effectiveSelectedLevelIndex));
                        """)
                    }
                }
            }
            
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("window.hlsPlayer_instances[\(self.instanceId)].playerSetBaseRate(\(self.requestedBaseRate));")
        }
        
        self.updateStatus()
    }
    
    fileprivate func onPlayerUpdatedCurrentTime(currentTime: Double) {
        self.playerTime = currentTime
        
        self.updateStatus()
    }
    
    fileprivate func onSetCurrentTime(timestamp: Double) {
        self.player.seek(timestamp: timestamp, play: nil)
    }
    
    fileprivate func onSetPlaybackRate(playbackRate: Double) {
        self.player.setBaseRate(playbackRate)
    }
    
    fileprivate func onPlay() {
        self.player.play()
    }
    
    fileprivate func onPause() {
        self.player.pause()
    }
    
    fileprivate func onMediaSourceDurationUpdated() {
        guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) else {
            return
        }
        guard let mediaSourceId = videoElement.mediaSourceId, let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[mediaSourceId] else {
            return
        }
        guard let sourceBufferId = mediaSource.sourceBufferIds.first, let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[sourceBufferId] else {
            return
        }
        
        self.chunkPlayerPartsState.set(.single(ChunkMediaPlayerPartsState(duration: mediaSource.duration, content: .parts(sourceBuffer.items))))
    }
    
    fileprivate func onMediaSourceBuffersUpdated() {
        guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) else {
            return
        }
        guard let mediaSourceId = videoElement.mediaSourceId, let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[mediaSourceId] else {
            return
        }
        guard let sourceBufferId = mediaSource.sourceBufferIds.first, let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[sourceBufferId] else {
            return
        }

        self.chunkPlayerPartsState.set(.single(ChunkMediaPlayerPartsState(duration: mediaSource.duration, content: .parts(sourceBuffer.items))))
        if self.sourceBufferStateDisposable == nil {
            self.sourceBufferStateDisposable = (sourceBuffer.updated.signal()
            |> deliverOnMainQueue).startStrict(next: { [weak self, weak sourceBuffer] _ in
                guard let self, let sourceBuffer else {
                    return
                }
                guard let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[sourceBuffer.mediaSourceId] else {
                    return
                }
                self.chunkPlayerPartsState.set(.single(ChunkMediaPlayerPartsState(duration: mediaSource.duration, content: .parts(sourceBuffer.items))))
                
                self.updateBuffered()
            })
        }
    }
    
    private func updatePlayerStatus(status: MediaPlayerStatus) {
        self._status.set(status)
        
        if let (bridgeId, _) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) {
            var isPlaying: Bool = false
            var isBuffering = false
            switch status.status {
            case .playing:
                isPlaying = true
            case .paused:
                break
            case let .buffering(_, whilePlaying, _, _):
                isPlaying = whilePlaying
                isBuffering = true
            }
            
            let result: [String: Any] = [
                "isPlaying": isPlaying,
                "isWaiting": isBuffering,
                "currentTime": status.timestamp
            ]
            
            let jsonResult = try! JSONSerialization.data(withJSONObject: result)
            let jsonResultString = String(data: jsonResult, encoding: .utf8)!
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("window.bridgeObjectMap[\(bridgeId)].bridgeUpdateStatus(\(jsonResultString));")
        }
    }
    
    private func updateBuffered() {
        guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) else {
            return
        }
        guard let mediaSourceId = videoElement.mediaSourceId, let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[mediaSourceId] else {
            return
        }
        guard let sourceBufferId = mediaSource.sourceBufferIds.first, let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[sourceBufferId] else {
            return
        }
        
        let bufferedRanges = sourceBuffer.ranges
        
        if let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) {
            if let mediaSourceId = videoElement.mediaSourceId, let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[mediaSourceId] {
                if let duration = mediaSource.duration {
                    var mappedRanges = RangeSet<Int64>()
                    for range in bufferedRanges.ranges {
                        let rangeLower = max(0.0, range.lowerBound - 0.2)
                        let rangeUpper = min(duration, range.upperBound + 0.2)
                        mappedRanges.formUnion(RangeSet<Int64>(Int64(rangeLower * 1000.0) ..< Int64(rangeUpper * 1000.0)))
                    }
                    self._bufferingStatus.set(.single((mappedRanges, Int64(duration * 1000.0))))
                }
            }
        }
    }
    
    private func updateStatus() {
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(node: self.playerNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(node: self.playerNode, scale: size.width / self.intrinsicDimensions.width)
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        if let dimensions = self.dimensions {
            let imageSize = CGSize(width: floor(dimensions.width / 2.0), height: floor(dimensions.height / 2.0))
            let makeLayout = self.imageNode.asyncLayout()
            let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
            applyLayout()
        }
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: self.requestedBaseRate, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: self.enableSound))
        }
        self.player.play()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.togglePlayPause(faded: false)
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if self.enableSound != value {
            self.enableSound = value
            if value {
                self.player.playOnceWithSound(playAndRecord: false, seek: .none)
            } else {
                self.player.continuePlayingWithoutSound(seek: .none)
            }
            self.updateInternalQualityLevel()
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        
        SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("window.hlsPlayer_instances[\(self.instanceId)].playerSeek(\(timestamp));")
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        self.enableSound = true
        switch actionAtEnd {
        case .loop:
            self.player.actionAtEnd = .loop({})
        case .loopDisablingSound:
            self.player.actionAtEnd = .loopDisablingSound(action)
        case .stop:
            self.player.actionAtEnd = .action(action)
        case .repeatIfNeeded:
            let _ = (self.player.status
            |> deliverOnMainQueue
            |> take(1)).start(next: { [weak self] status in
                guard let strongSelf = self else {
                    return
                }
                if status.timestamp > status.duration * 0.1 {
                    strongSelf.player.actionAtEnd = .loop({ [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.player.actionAtEnd = .loopDisablingSound(action)
                    })
                } else {
                    strongSelf.player.actionAtEnd = .loopDisablingSound(action)
                }
            })
        }
        
        self.player.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
        self.updateInternalQualityLevel()
    }
    
    func setSoundMuted(soundMuted: Bool) {
        self.player.setSoundMuted(soundMuted: soundMuted)
    }
    
    func continueWithOverridingAmbientMode(isAmbient: Bool) {
        self.player.continueWithOverridingAmbientMode(isAmbient: isAmbient)
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        assert(Queue.mainQueue().isCurrent())
        self.player.setForceAudioToSpeaker(forceAudioToSpeaker)
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        self.enableSound = false
        switch actionAtEnd {
            case .loop:
                self.player.actionAtEnd = .loop({})
            case .loopDisablingSound, .repeatIfNeeded:
                self.player.actionAtEnd = .loopDisablingSound(action)
            case .stop:
                self.player.actionAtEnd = .action(action)
        }
        self.player.continuePlayingWithoutSound(seek: .none)
        self.updateInternalQualityLevel()
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        self.player.setContinuePlayingWithoutSoundOnLostAudioSession(value)
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.requestedBaseRate = baseRate
        if self.playerIsReady {
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("window.hlsPlayer_instances[\(self.instanceId)].playerSetBaseRate(\(self.requestedBaseRate));")
        }
        self.updateStatus()
    }
    
    private func resolveCurrentLevelIndex() -> Int? {
        if self.enableSound {
            return self.requestedLevelIndex
        } else {
            var foundIndex: Int?
            if let minQualityFile = HLSVideoContent.minimizedHLSQuality(file: self.fileReference, codecConfiguration: self.codecConfiguration)?.file, let dimensions = minQualityFile.media.dimensions {
                for (index, level) in self.playerAvailableLevels {
                    if level.width == Int(dimensions.width) && level.height == Int(dimensions.height) {
                        foundIndex = index
                        break
                    }
                }
            }
            return foundIndex
        }
    }
    
    private func updateInternalQualityLevel() {
        if self.playerIsReady {
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("""
            window.hlsPlayer_instances[\(self.instanceId)].playerSetCapAutoLevel(\(self.resolveCurrentLevelIndex() ?? -1));
            """)
        }
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        
        let resolvedVideoQuality = self.preferredVideoQuality
        switch resolvedVideoQuality {
        case .auto:
            self.requestedLevelIndex = nil
        case let .quality(quality):
            if let level = self.playerAvailableLevels.first(where: { min($0.value.width, $0.value.height) == quality }) {
                self.requestedLevelIndex = level.key
            } else {
                self.requestedLevelIndex = nil
            }
        }
        
        self.updateVideoQualityState()
        
        if self.playerIsReady {
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript("""
            window.hlsPlayer_instances[\(self.instanceId)].playerSetLevel(\(self.requestedLevelIndex ?? -1));
            """)
        }
    }
    
    private func updateVideoQualityState() {
        var videoQualityState: VideoQualityState?
        if let value = self.videoQualityState() {
            videoQualityState = VideoQualityState(current: value.current, preferred: value.preferred, available: value.available)
        }
        if self.videoQualityStateValue != videoQualityState {
            self.videoQualityStateValue = videoQualityState
            self.videoQualityStatePromise.set(.single(videoQualityState))
        }
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        if self.playerAvailableLevels.isEmpty {
            if let qualitySet = HLSQualitySet(baseFile: self.fileReference, codecConfiguration: self.codecConfiguration), let minQualityFile = HLSVideoContent.minimizedHLSQuality(file: self.fileReference, codecConfiguration: self.codecConfiguration)?.file {
                let sortedFiles = qualitySet.qualityFiles.sorted(by: { $0.key > $1.key })
                if let minQuality = sortedFiles.first(where: { $0.value.media.fileId == minQualityFile.media.fileId }) {
                    return (minQuality.key, .auto, sortedFiles.map(\.key))
                }
            }
        }
        
        let currentLevelIndex: Int
        if let playerCurrentLevelIndex = self.playerCurrentLevelIndex {
            currentLevelIndex = playerCurrentLevelIndex
        } else {
            if let minQualityFile = HLSVideoContent.minimizedHLSQuality(file: self.fileReference, codecConfiguration: self.codecConfiguration)?.file, let dimensions = minQualityFile.media.dimensions {
                var foundIndex: Int?
                for (index, level) in self.playerAvailableLevels {
                    if level.width == Int(dimensions.width) && level.height == Int(dimensions.height) {
                        foundIndex = index
                        break
                    }
                }
                if let foundIndex {
                    currentLevelIndex = foundIndex
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        guard let currentLevel = self.playerAvailableLevels[currentLevelIndex] else {
            return nil
        }
        
        var available = self.playerAvailableLevels.values.map { min($0.width, $0.height) }
        available.sort(by: { $0 > $1 })
        
        return (min(currentLevel.width, currentLevel.height), self.preferredVideoQuality, available)
    }
    
    public func videoQualityStateSignal() -> Signal<(current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])?, NoError> {
        return self.videoQualityStatePromise.get()
        |> map { value -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? in
            guard let value else {
                return nil
            }
            return (value.current, value.preferred, value.available)
        }
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
    }
    
    func notifyPlaybackControlsHidden(_ hidden: Bool) {
    }

    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
        self.playerNode.setCanPlaybackWithoutHierarchy(canPlaybackWithoutHierarchy)
    }
    
    func enterNativePictureInPicture() -> Bool {
        return false
    }
    
    func exitNativePictureInPicture() {
    }
    
    func setNativePictureInPictureIsActive(_ value: Bool) {
        self.imageNode.isHidden = !value
    }
}

private func serializeRanges(_ ranges: RangeSet<Double>) -> [Double] {
    var result: [Double] = []
    for range in ranges.ranges {
        result.append(range.lowerBound)
        result.append(range.upperBound)
    }
    return result
}

private final class VideoElement {
    let instanceId: Int
    
    var mediaSourceId: Int?
    
    init(instanceId: Int) {
        self.instanceId = instanceId
    }
}

private final class MediaSource {
    var duration: Double?
    var sourceBufferIds: [Int] = []
    
    init() {
    }
}

private final class SourceBuffer {
    private static let sharedQueue = Queue(name: "SourceBuffer")
    
    final class Item {
        let tempFile: TempBoxFile
        let asset: AVURLAsset
        let startTime: Double
        let endTime: Double
        let rawData: Data
        
        var clippedStartTime: Double
        var clippedEndTime: Double
        
        init(tempFile: TempBoxFile, asset: AVURLAsset, startTime: Double, endTime: Double, rawData: Data) {
            self.tempFile = tempFile
            self.asset = asset
            self.startTime = startTime
            self.endTime = endTime
            self.rawData = rawData
            
            self.clippedStartTime = startTime
            self.clippedEndTime = endTime
        }
        
        func removeRange(start: Double, end: Double) {
            //TODO
        }
    }
    
    let mediaSourceId: Int
    let mimeType: String
    var initializationData: Data?
    var items: [ChunkMediaPlayerPart] = []
    var ranges = RangeSet<Double>()
    
    let updated = ValuePipe<Void>()
    
    private var currentUpdateId: Int = 0
    
    init(mediaSourceId: Int, mimeType: String) {
        self.mediaSourceId = mediaSourceId
        self.mimeType = mimeType
    }
    
    func abortOperation() {
        self.currentUpdateId += 1
    }
    
    func appendBuffer(data: Data, completion: @escaping (RangeSet<Double>) -> Void) {
        let initializationData = self.initializationData
        self.currentUpdateId += 1
        let updateId = self.currentUpdateId
        
        SourceBuffer.sharedQueue.async { [weak self] in
            let tempFile = TempBox.shared.tempFile(fileName: "data.mp4")
            
            var combinedData = Data()
            if let initializationData {
                combinedData.append(initializationData)
            }
            combinedData.append(data)
            guard let _ = try? combinedData.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) else {
                Queue.mainQueue().async {
                    guard let self else {
                        completion(RangeSet())
                        return
                    }
                    
                    if self.currentUpdateId != updateId {
                        return
                    }
                    
                    completion(self.ranges)
                }
                return
            }
            
            if let fragmentInfoSet = extractFFMpegMediaInfo(path: tempFile.path), let fragmentInfo = fragmentInfoSet.audio ?? fragmentInfoSet.video {
                Queue.mainQueue().async {
                    guard let self else {
                        completion(RangeSet())
                        return
                    }
                    
                    if self.currentUpdateId != updateId {
                        return
                    }
                    
                    if fragmentInfo.duration.value == 0 {
                        self.initializationData = data
                        
                        completion(self.ranges)
                    } else {
                        let videoCodecName: String? = fragmentInfoSet.video?.codecName
                        
                        let item = ChunkMediaPlayerPart(
                            startTime: fragmentInfo.startTime.seconds,
                            endTime: fragmentInfo.startTime.seconds + fragmentInfo.duration.seconds,
                            content: ChunkMediaPlayerPart.TempFile(file: tempFile),
                            codecName: videoCodecName,
                            offsetTime: 0.0
                        )
                        self.items.append(item)
                        self.updateRanges()
                        
                        completion(self.ranges)
                        
                        self.updated.putNext(Void())
                    }
                }
            } else {
                assertionFailure()
                Queue.mainQueue().async {
                    guard let self else {
                        completion(RangeSet())
                        return
                    }
                    
                    if self.currentUpdateId != updateId {
                        return
                    }
                    
                    completion(self.ranges)
                }
                return
            }
        }
    }
    
    func remove(start: Double, end: Double, completion: @escaping (RangeSet<Double>) -> Void) {
        self.items.removeAll(where: { item in
            if item.startTime + 0.5 >= start && item.endTime - 0.5 <= end {
                return true
            } else {
                return false
            }
        })
        self.updateRanges()
        completion(self.ranges)
        
        self.updated.putNext(Void())
    }
    
    private func updateRanges() {
        self.ranges = RangeSet()
        for item in self.items {
            let itemStartTime = round(item.startTime * 1000.0) / 1000.0
            let itemEndTime = round(item.endTime * 1000.0) / 1000.0
            self.ranges.formUnion(RangeSet<Double>(itemStartTime ..< itemEndTime))
        }
    }
}

private func parseFragment(filePath: String) -> (offset: CMTime, duration: CMTime)? {
    let source = SoftwareVideoSource(path: filePath, hintVP9: false, unpremultiplyAlpha: false)
    return source.readTrackInfo()
}
