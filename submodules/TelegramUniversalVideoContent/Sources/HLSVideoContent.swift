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
import HLSPlayback

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
        // The preload quality: one rule for the chat preload, the bubble thumbnail and the player's start.
        guard let quality = HLSLevels.preloadQualityKey(keys: Array(qualitySet.qualityFiles.keys)), let qualityFile = qualitySet.qualityFiles[quality], let playlistFile = qualitySet.playlistFiles[quality] else {
            return nil
        }
        return (playlistFile, qualityFile)
    }
    
    public static func minimizedHLSQualityPreloadData(postbox: Postbox, file: FileMediaReference, userLocation: MediaResourceUserLocation, prefixSeconds: Int, autofetchPlaylist: Bool, codecConfiguration: HLSCodecConfiguration) -> Signal<(FileMediaReference, Range<Int64>)?, NoError> {
        guard let fileSet = minimizedHLSQuality(file: file, codecConfiguration: codecConfiguration) else {
            return .single(nil)
        }
        
        let playlistData: Signal<Range<Int64>?, NoError> = Signal { subscriber in
            var fetchDisposable: Disposable?
            if autofetchPlaylist {
                // There is no timeout: the fetch waits for the server for as long as it takes. A failure is never
                // terminal: a failed fetch is started again after 2 s, 4 s, 6 s, … at most 30 s.
                fetchDisposable = (freeMediaFileResourceInteractiveFetched(postbox: postbox, userLocation: userLocation, fileReference: fileSet.playlist, resource: fileSet.playlist.media.resource)
                |> retry(2.0, maxDelay: 30.0, onQueue: Queue.concurrentDefaultQueue())).start()
            }
            let dataDisposable = postbox.mediaBox.resourceData(fileSet.playlist.media.resource).start(next: { data in
                if !data.complete {
                    return
                }
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)), let text = String(data: data, encoding: .utf8), let playlist = try? HLSMediaPlaylist.parse(text) else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                subscriber.putNext(playlist.prefixRange(seconds: Double(prefixSeconds)))
                subscriber.putCompletion()
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
    let captureProtected: Bool
    let codecConfiguration: HLSCodecConfiguration
    // Where playback will start (a tapped timecode or a stored position), when the caller knows it before playing.
    let startTimestamp: Double?
    // Only for the base-file fallback in `makeContentNode`, as NativeVideoContent takes them.
    let continuePlayingWithoutSoundOnLostAudioSession: Bool
    let placeholderColor: UIColor
    let storeAfterDownload: (() -> Void)?
    
    public init(id: NativeVideoContentId, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool = false, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true, onlyFullSizeThumbnail: Bool = false, useLargeThumbnail: Bool = false, autoFetchFullSizeThumbnail: Bool = false, captureProtected: Bool = false, codecConfiguration: HLSCodecConfiguration, startTimestamp: Double? = nil, continuePlayingWithoutSoundOnLostAudioSession: Bool = false, placeholderColor: UIColor = .white, storeAfterDownload: (() -> Void)? = nil) {
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
        self.captureProtected = captureProtected
        self.codecConfiguration = codecConfiguration
        self.startTimestamp = startTimestamp
        self.continuePlayingWithoutSoundOnLostAudioSession = continuePlayingWithoutSoundOnLostAudioSession
        self.placeholderColor = placeholderColor
        self.storeAfterDownload = storeAfterDownload
    }
    
    public func makeContentNode(context: AccountContext, postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        guard let qualities = HLSVideoNativeContentNode.qualityFiles(file: self.fileReference, codecConfiguration: self.codecConfiguration) else {
            // Nothing to play adaptively: play the base file rather than nothing.
            return NativeVideoContent(id: self.nativeId, userLocation: self.userLocation, fileReference: self.fileReference, streamVideo: .conservative, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically, onlyFullSizeThumbnail: self.onlyFullSizeThumbnail, useLargeThumbnail: self.useLargeThumbnail, autoFetchFullSizeThumbnail: self.autoFetchFullSizeThumbnail, startTimestamp: self.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: self.continuePlayingWithoutSoundOnLostAudioSession, placeholderColor: self.placeholderColor, captureProtected: self.captureProtected, storeAfterDownload: self.storeAfterDownload).makeContentNode(context: context, postbox: postbox, audioSession: audioSession)
        }
        let thumbnailVideoReference = HLSVideoContent.minimizedHLSQuality(file: self.fileReference, codecConfiguration: self.codecConfiguration)?.file ?? self.fileReference
        let thumbnail = internalMediaGridMessageVideo(postbox: postbox, userLocation: self.userLocation, videoReference: thumbnailVideoReference, previewSourceFileReference: self.fileReference, imageReference: nil, onlyFullSize: self.onlyFullSizeThumbnail, useLargeThumbnail: self.useLargeThumbnail, autoFetchFullSizeThumbnail: self.autoFetchFullSizeThumbnail || self.fileReference.media.isInstantVideo)
        return HLSVideoNativeContentNode(context: context, audioSessionManager: audioSession, userLocation: self.userLocation, fileReference: self.fileReference, levels: qualities.levels, qualityFiles: qualities.files, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, captureProtected: self.captureProtected, startTimestamp: self.startTimestamp, thumbnail: thumbnail)
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
