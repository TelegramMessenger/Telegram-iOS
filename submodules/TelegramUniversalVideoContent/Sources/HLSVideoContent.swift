import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AVFoundation
import UniversalMediaPlayer
import TelegramAudio
import AccountContext
import PhotoResources
import RangeSet
import TelegramVoip
import ManagedFile
import AppBundle

public struct HLSCodecConfiguration {
    public var isHardwareAv1Supported: Bool
    public var isSoftwareAv1Supported: Bool
    
    public init(isHardwareAv1Supported: Bool, isSoftwareAv1Supported: Bool) {
        self.isHardwareAv1Supported = isHardwareAv1Supported
        self.isSoftwareAv1Supported = isSoftwareAv1Supported
    }
}

public extension HLSCodecConfiguration {
    init(context: AccountContext) {
        var isSoftwareAv1Supported = false
        var isHardwareAv1Supported = false
        
        var length: Int = 4
        var cpuCount: UInt32 = 0
        sysctlbyname("hw.ncpu", &cpuCount, &length, nil, 0)
        if cpuCount >= 6 {
            isSoftwareAv1Supported = true
        }
        
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ios_enable_hardware_av1"] as? Double {
            isHardwareAv1Supported = value != 0.0
        }
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ios_enable_software_av1"] as? Double {
            isSoftwareAv1Supported = value != 0.0
        }
        
        self.init(isHardwareAv1Supported: isHardwareAv1Supported, isSoftwareAv1Supported: isSoftwareAv1Supported)
    }
}

public final class HLSQualitySet {
    public let qualityFiles: [Int: FileMediaReference]
    public let playlistFiles: [Int: FileMediaReference]
    public let thumbnails: [Int: (file: FileMediaReference, fileMap: FileMediaReference)]
    
    public init?(baseFile: FileMediaReference, codecConfiguration: HLSCodecConfiguration) {
        var qualityFiles: [Int: FileMediaReference] = [:]
        var thumbnailFiles: [FileMediaReference] = []
        var thumbnailFileMaps: [Int: (mapFile: FileMediaReference, thumbnailFileId: Int64)] = [:]
        
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            let alternativeFile = alternativeRepresentation
            if alternativeFile.mimeType == "application/x-tgstoryboard" {
                thumbnailFiles.append(baseFile.withMedia(alternativeFile))
            } else if alternativeFile.mimeType == "application/x-tgstoryboardmap" {
                var qualityId: Int?
                for attribute in alternativeFile.attributes {
                    switch attribute {
                    case let .ImageSize(size):
                        qualityId = Int(min(size.width, size.height))
                    default:
                        break
                    }
                }
                
                if let qualityId, let fileName = alternativeFile.fileName {
                    if fileName.hasPrefix("mtproto:") {
                        if let fileId = Int64(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...]) {
                            thumbnailFileMaps[qualityId] = (mapFile: baseFile.withMedia(alternativeFile), thumbnailFileId: fileId)
                        }
                    }
                }
            } else {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        if let videoCodec, NativeVideoContent.isVideoCodecSupported(videoCodec: videoCodec, isHardwareAv1Supported: codecConfiguration.isHardwareAv1Supported, isSoftwareAv1Supported: codecConfiguration.isSoftwareAv1Supported) {
                            let key = Int(min(size.width, size.height))
                            if let currentFile = qualityFiles[key] {
                                var currentCodec: String?
                                for attribute in currentFile.media.attributes {
                                    if case let .Video(_, _, _, _, _, videoCodec) = attribute {
                                        currentCodec = videoCodec
                                    }
                                }
                                if let currentCodec, (currentCodec == "av1" || currentCodec == "av01") {
                                } else {
                                    qualityFiles[key] = baseFile.withMedia(alternativeFile)
                                }
                            } else {
                                qualityFiles[key] = baseFile.withMedia(alternativeFile)
                            }
                        }
                    }
                }
            }
        }
        
        var playlistFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            let alternativeFile = alternativeRepresentation
            if alternativeFile.mimeType == "application/x-mpegurl" {
                if let fileName = alternativeFile.fileName {
                    if fileName.hasPrefix("mtproto:") {
                        let fileIdString = String(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...])
                        if let fileId = Int64(fileIdString) {
                            for (quality, file) in qualityFiles {
                                if file.media.fileId.id == fileId {
                                    playlistFiles[quality] = baseFile.withMedia(alternativeFile)
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        if !playlistFiles.isEmpty && playlistFiles.keys == qualityFiles.keys {
            self.qualityFiles = qualityFiles
            self.playlistFiles = playlistFiles
            
            var thumbnails: [Int: (file: FileMediaReference, fileMap: FileMediaReference)] = [:]
            for (quality, thubmailMap) in thumbnailFileMaps {
                for file in thumbnailFiles {
                    if file.media.fileId.id == thubmailMap.thumbnailFileId {
                        thumbnails[quality] = (
                            file: file,
                            fileMap: thubmailMap.mapFile
                        )
                    }
                }
            }
            self.thumbnails = thumbnails
        } else {
            return nil
        }
    }
}

public final class HLSVideoContent: UniversalVideoContent {
    public static func minimizedHLSQuality(file: FileMediaReference, codecConfiguration: HLSCodecConfiguration) -> (playlist: FileMediaReference, file: FileMediaReference)? {
        guard let qualitySet = HLSQualitySet(baseFile: file, codecConfiguration: codecConfiguration) else {
            return nil
        }
        let sortedQualities = qualitySet.qualityFiles.sorted(by: { $0.key < $1.key })
        for (quality, qualityFile) in sortedQualities {
            if quality >= 600 {
                guard let playlistFile = qualitySet.playlistFiles[quality] else {
                    return nil
                }
                return (playlistFile, qualityFile)
            }
        }
        if let (quality, qualityFile) = sortedQualities.first {
            guard let playlistFile = qualitySet.playlistFiles[quality] else {
                return nil
            }
            return (playlistFile, qualityFile)
        }
        
        return nil
    }
    
    public static func minimizedHLSQualityPreloadData(postbox: Postbox, file: FileMediaReference, userLocation: MediaResourceUserLocation, prefixSeconds: Int, autofetchPlaylist: Bool, codecConfiguration: HLSCodecConfiguration) -> Signal<(FileMediaReference, Range<Int64>)?, NoError> {
        guard let fileSet = minimizedHLSQuality(file: file, codecConfiguration: codecConfiguration) else {
            return .single(nil)
        }
        
        let playlistData: Signal<Range<Int64>?, NoError> = Signal { subscriber in
            var fetchDisposable: Disposable?
            if autofetchPlaylist {
                fetchDisposable = freeMediaFileResourceInteractiveFetched(postbox: postbox, userLocation: userLocation, fileReference: fileSet.playlist, resource: fileSet.playlist.media.resource).start()
            }
            let dataDisposable = postbox.mediaBox.resourceData(fileSet.playlist.media.resource).start(next: { data in
                if !data.complete {
                    return
                }
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                guard let playlistString = String(data: data, encoding: .utf8) else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
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
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                
                var rangeUpperBound: Int64 = 0
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
                
                if rangeUpperBound != 0 {
                    subscriber.putNext(0 ..< rangeUpperBound)
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
                
                return
            })
            
            return ActionDisposable {
                fetchDisposable?.dispose()
                dataDisposable.dispose()
            }
        }
        
        return playlistData
        |> map { range -> (FileMediaReference, Range<Int64>)? in
            guard let range else {
                return nil
            }
            return (fileSet.file, range)
        }
    }
    
    public let id: AnyHashable
    public let nativeId: NativeVideoContentId
    public let userLocation: MediaResourceUserLocation
    public let fileReference: FileMediaReference
    public let dimensions: CGSize
    public let duration: Double
    let streamVideo: Bool
    let loopVideo: Bool
    let enableSound: Bool
    let baseRate: Double
    let fetchAutomatically: Bool
    let onlyFullSizeThumbnail: Bool
    let useLargeThumbnail: Bool
    let autoFetchFullSizeThumbnail: Bool
    let codecConfiguration: HLSCodecConfiguration
    
    public init(id: NativeVideoContentId, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool = false, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true, onlyFullSizeThumbnail: Bool = false, useLargeThumbnail: Bool = false, autoFetchFullSizeThumbnail: Bool = false, codecConfiguration: HLSCodecConfiguration) {
        self.id = id
        self.userLocation = userLocation
        self.nativeId = id
        self.fileReference = fileReference
        self.dimensions = self.fileReference.media.dimensions?.cgSize ?? CGSize(width: 480, height: 320)
        self.duration = self.fileReference.media.duration ?? 0.0
        self.streamVideo = streamVideo
        self.loopVideo = loopVideo
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
        self.onlyFullSizeThumbnail = onlyFullSizeThumbnail
        self.useLargeThumbnail = useLargeThumbnail
        self.autoFetchFullSizeThumbnail = autoFetchFullSizeThumbnail
        self.codecConfiguration = codecConfiguration
    }
    
    public func makeContentNode(context: AccountContext, postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return HLSVideoJSNativeContentNode(context: context, postbox: postbox, audioSessionManager: audioSession, userLocation: self.userLocation, fileReference: self.fileReference, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically, onlyFullSizeThumbnail: self.onlyFullSizeThumbnail, useLargeThumbnail: self.useLargeThumbnail, autoFetchFullSizeThumbnail: self.autoFetchFullSizeThumbnail, codecConfiguration: self.codecConfiguration)
    }
    
    public func isEqual(to other: UniversalVideoContent) -> Bool {
        if let other = other as? NativeVideoContent {
            if case let .message(stableId, _) = self.nativeId {
                if case .message(stableId, _) = other.nativeId {
                    if self.fileReference.media.isInstantVideo {
                        return true
                    }
                }
            }
        }
        return false
    }
}

final class HLSServerSource: SharedHLSServer.Source {
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
            if path == "index.html" {
                if let path = getAppBundle().path(forResource: "HLSVideoPlayer", ofType: "html"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    subscriber.putNext((data, "text/html"))
                } else {
                    subscriber.putNext(nil)
                }
            } else if path == "hls.js" {
                if let path = getAppBundle().path(forResource: "hls", ofType: "js"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    subscriber.putNext((data, "application/javascript"))
                } else {
                    subscriber.putNext(nil)
                }
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
        let _ = quality
        guard let size = file.media.size else {
            return .single(nil)
        }
        
        let postbox = self.postbox
        let userLocation = self.userLocation
        
        let mappedRange: Range<Int64> = Int64(range.lowerBound) ..< Int64(range.upperBound)
        
        let queue = postbox.mediaBox.dataQueue
        let fetchFromRemote: Signal<(TempBoxFile, Range<Int>, Int)?, NoError> = Signal { subscriber in
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
        
        return fetchFromRemote
    }
}
