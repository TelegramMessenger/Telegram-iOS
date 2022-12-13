import Foundation
import Postbox
import SwiftSignalKit


public enum PeerCacheUsageCategory: Int32 {
    case image = 0
    case video
    case audio
    case file
}

public struct CacheUsageStats {
    public let media: [PeerId: [PeerCacheUsageCategory: [MediaId: Int64]]]
    public let mediaResourceIds: [MediaId: [MediaResourceId]]
    public let peers: [PeerId: Peer]
    public let otherSize: Int64
    public let otherPaths: [String]
    public let cacheSize: Int64
    public let tempPaths: [String]
    public let tempSize: Int64
    public let immutableSize: Int64
    
    public init(media: [PeerId: [PeerCacheUsageCategory: [MediaId: Int64]]], mediaResourceIds: [MediaId: [MediaResourceId]], peers: [PeerId: Peer], otherSize: Int64, otherPaths: [String], cacheSize: Int64, tempPaths: [String], tempSize: Int64, immutableSize: Int64) {
        self.media = media
        self.mediaResourceIds = mediaResourceIds
        self.peers = peers
        self.otherSize = otherSize
        self.otherPaths = otherPaths
        self.cacheSize = cacheSize
        self.tempPaths = tempPaths
        self.tempSize = tempSize
        self.immutableSize = immutableSize
    }
}

public enum CacheUsageStatsResult {
    case progress(Float)
    case result(CacheUsageStats)
}

private enum CollectCacheUsageStatsError {
    case done(CacheUsageStats)
    case generic
}

private final class CacheUsageStatsState {
    var media: [PeerId: [PeerCacheUsageCategory: [MediaId: Int64]]] = [:]
    var mediaResourceIds: [MediaId: [MediaResourceId]] = [:]
    var allResourceIds = Set<MediaResourceId>()
    var lowerBound: MessageIndex?
    var upperBound: MessageIndex?
}

func _internal_collectCacheUsageStats(account: Account, peerId: PeerId? = nil, additionalCachePaths: [String] = [], logFilesPath: String? = nil) -> Signal<CacheUsageStatsResult, NoError> {
    if "".isEmpty {
        return account.postbox.mediaBox.collectAllResourceUsage()
        |> mapToSignal { resourceList -> Signal<CacheUsageStatsResult, NoError> in
            return account.postbox.mediaBox.storageBox.get(ids: resourceList.compactMap { item -> Data? in
                return item.id?.data(using: .utf8)
            })
            |> mapToSignal { entries -> Signal<CacheUsageStatsResult, NoError> in
                return account.postbox.transaction { transaction -> CacheUsageStatsResult in
                    var media: [PeerId: [PeerCacheUsageCategory: [MediaId: Int64]]] = [:]
                    var mediaResourceIds: [MediaId: [MediaResourceId]] = [:]
                    
                    media.removeAll()
                    mediaResourceIds.removeAll()
                    
                    let mediaBox = account.postbox.mediaBox
                    
                    var totalSize: Int64 = 0
                    var mediaSize: Int64 = 0
                    
                    var processedResourceIds = Set<String>()
                    
                    for entry in entries {
                        let resourceId = MediaResourceId(String(data: entry.id, encoding: .utf8)!)
                        let resourceSize = mediaBox.resourceUsage(id: resourceId)
                        if resourceSize != 0 {
                            totalSize += resourceSize
                            
                            for reference in entry.references {
                                if let message = transaction.getMessage(MessageId(peerId: PeerId(reference.peerId), namespace: MessageId.Namespace(reference.messageNamespace), id: reference.messageId)) {
                                    for mediaItem in message.media {
                                        guard let mediaId = mediaItem.id else {
                                            continue
                                        }
                                        var category: PeerCacheUsageCategory?
                                        if let _ = mediaItem as? TelegramMediaImage {
                                            category = .image
                                        } else if let mediaItem = mediaItem as? TelegramMediaFile {
                                            if mediaItem.isMusic || mediaItem.isVoice {
                                                category = .audio
                                            } else if mediaItem.isVideo {
                                                category = .video
                                            } else {
                                                category = .file
                                            }
                                        }
                                        if let category = category {
                                            mediaSize += resourceSize
                                            processedResourceIds.insert(resourceId.stringRepresentation)
                                            
                                            media[PeerId(reference.peerId), default: [:]][category, default: [:]][mediaId, default: 0] += resourceSize
                                            if let index = mediaResourceIds.index(forKey: mediaId) {
                                                if !mediaResourceIds[index].value.contains(resourceId) {
                                                    mediaResourceIds[mediaId]?.append(resourceId)
                                                }
                                            } else {
                                                mediaResourceIds[mediaId] = [resourceId]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    var peers: [PeerId: Peer] = [:]
                    for peerId in media.keys {
                        if let peer = transaction.getPeer(peerId) {
                            peers[peer.id] = peer
                        }
                    }
                    
                    var tempPaths: [String] = []
                    var tempSize: Int64 = 0
                    #if os(iOS)
                        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: NSTemporaryDirectory()), includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .isSymbolicLinkKey]) {
                            for url in enumerator {
                                if let url = url as? URL {
                                    if let isDirectoryValue = (try? url.resourceValues(forKeys: Set([.isDirectoryKey])))?.isDirectory, isDirectoryValue {
                                        tempPaths.append(url.path)
                                    } else if let fileSizeValue = (try? url.resourceValues(forKeys: Set([.fileAllocatedSizeKey])))?.fileAllocatedSize {
                                        tempPaths.append(url.path)
                                        
                                        if let isSymbolicLinkValue = (try? url.resourceValues(forKeys: Set([.isSymbolicLinkKey])))?.isSymbolicLink, isSymbolicLinkValue {
                                        } else {
                                            tempSize += Int64(fileSizeValue)
                                        }
                                    }
                                }
                            }
                        }
                    #endif
                    
                    var immutableSize: Int64 = 0
                    if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: account.basePath + "/postbox/db"), includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: []) {
                        for url in files {
                            if let fileSize = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize {
                                immutableSize += Int64(fileSize)
                            }
                        }
                    }
                    if let logFilesPath = logFilesPath, let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: logFilesPath), includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: []) {
                        for url in files {
                            if let fileSize = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize {
                                immutableSize += Int64(fileSize)
                            }
                        }
                    }
                    
                    for additionalPath in additionalCachePaths {
                        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: additionalPath), includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .isSymbolicLinkKey]) {
                            for url in enumerator {
                                if let url = url as? URL {
                                    if let isDirectoryValue = (try? url.resourceValues(forKeys: Set([.isDirectoryKey])))?.isDirectory, isDirectoryValue {
                                    } else if let fileSizeValue = (try? url.resourceValues(forKeys: Set([.fileAllocatedSizeKey])))?.fileAllocatedSize {
                                        tempPaths.append(url.path)

                                        if let isSymbolicLinkValue = (try? url.resourceValues(forKeys: Set([.isSymbolicLinkKey])))?.isSymbolicLink, isSymbolicLinkValue {
                                        } else {
                                            tempSize += Int64(fileSizeValue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    var otherSize: Int64 = 0
                    var otherPaths: [String] = []
                    
                    for (id, name, size) in resourceList {
                        if size == 0 {
                            continue
                        }
                        if let id = id, processedResourceIds.contains(id) {
                            continue
                        }
                        otherSize += size
                        otherPaths.append(name)
                    }
                    
                    var cacheSize: Int64 = 0
                    let basePath = account.postbox.mediaBox.basePath
                    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: basePath + "/cache"), includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                        loop: for url in enumerator {
                            if let url = url as? URL {
                                if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                    otherPaths.append("cache/" + url.lastPathComponent)
                                    cacheSize += Int64(value)
                                }
                            }
                        }
                    }
                    
                    func processRecursive(directoryPath: String, subdirectoryPath: String) {
                        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: directoryPath), includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                            loop: for url in enumerator {
                                if let url = url as? URL {
                                    if let isDirectory = (try? url.resourceValues(forKeys: Set([.isDirectoryKey])))?.isDirectory, isDirectory {
                                        processRecursive(directoryPath: url.path, subdirectoryPath: subdirectoryPath + "/\(url.lastPathComponent)")
                                    } else if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                        otherPaths.append("\(subdirectoryPath)/" + url.lastPathComponent)
                                        cacheSize += Int64(value)
                                    }
                                }
                            }
                        }
                    }
                    
                    processRecursive(directoryPath: basePath + "/animation-cache", subdirectoryPath: "animation-cache")
                    
                    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: basePath + "/short-cache"), includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                        loop: for url in enumerator {
                            if let url = url as? URL {
                                if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                    otherPaths.append("short-cache/" + url.lastPathComponent)
                                    cacheSize += Int64(value)
                                }
                            }
                        }
                    }
                    
                    return .result(CacheUsageStats(
                        media: media,
                        mediaResourceIds: mediaResourceIds,
                        peers: peers,
                        otherSize: otherSize,
                        otherPaths: otherPaths,
                        cacheSize: 0,
                        tempPaths: tempPaths,
                        tempSize: tempSize,
                        immutableSize: immutableSize
                    ))
                }
            }
        }
    }
    
    let initialState = CacheUsageStatsState()
    if let peerId = peerId {
        initialState.lowerBound = MessageIndex.lowerBound(peerId: peerId)
        initialState.upperBound = MessageIndex.upperBound(peerId: peerId)
    }
    
    let state = Atomic<CacheUsageStatsState>(value: initialState)
    
    let excludeResourceIds = account.postbox.transaction { transaction -> Set<MediaResourceId> in
        var result = Set<MediaResourceId>()
        transaction.enumeratePreferencesEntries({ entry in
            result.formUnion(entry.relatedResources)
            return true
        })
        return result
    }
    
    return excludeResourceIds
    |> mapToSignal { excludeResourceIds -> Signal<CacheUsageStatsResult, NoError> in
        let fetch = account.postbox.transaction { transaction -> ([PeerId : Set<MediaId>], [MediaId : Media], MessageIndex?) in
            return transaction.enumerateMedia(lowerBound: state.with { $0.lowerBound }, upperBound: state.with { $0.upperBound }, limit: 1000)
        }
        |> mapError { _ -> CollectCacheUsageStatsError in }
        
        let process: ([PeerId : Set<MediaId>], [MediaId : Media], MessageIndex?) -> Signal<CacheUsageStatsResult, CollectCacheUsageStatsError> = { mediaByPeer, mediaRefs, updatedLowerBound in
            var mediaIdToPeerId: [MediaId: PeerId] = [:]
            for (peerId, mediaIds) in mediaByPeer {
                for id in mediaIds {
                    mediaIdToPeerId[id] = peerId
                }
            }
            
            var resourceIdToMediaId: [MediaResourceId: (MediaId, PeerCacheUsageCategory)] = [:]
            var mediaResourceIds: [MediaId: [MediaResourceId]] = [:]
            var resourceIds: [MediaResourceId] = []
            for (id, media) in mediaRefs {
                mediaResourceIds[id] = []
                var parsedMedia: [Media] = []
                switch media {
                    case let image as TelegramMediaImage:
                        parsedMedia.append(image)
                    case let file as TelegramMediaFile:
                        parsedMedia.append(file)
                    case let webpage as TelegramMediaWebpage:
                        if case let .Loaded(content) = webpage.content {
                            if let image = content.image {
                                parsedMedia.append(image)
                            }
                            if let file = content.file {
                                parsedMedia.append(file)
                            }
                        }
                    default:
                        break
                }
                for media in parsedMedia {
                    if let image = media as? TelegramMediaImage {
                        for representation in image.representations {
                            resourceIds.append(representation.resource.id)
                            resourceIdToMediaId[representation.resource.id] = (id, .image)
                            mediaResourceIds[id]!.append(representation.resource.id)
                        }
                    } else if let file = media as? TelegramMediaFile {
                        var category: PeerCacheUsageCategory = .file
                        loop: for attribute in file.attributes {
                            switch attribute {
                                case .Video:
                                    category = .video
                                    break loop
                                case .Audio:
                                    category = .audio
                                    break loop
                                default:
                                    break
                            }
                        }
                        for representation in file.previewRepresentations {
                            resourceIds.append(representation.resource.id)
                            resourceIdToMediaId[representation.resource.id] = (id, category)
                            mediaResourceIds[id]!.append(representation.resource.id)
                        }
                        resourceIds.append(file.resource.id)
                        resourceIdToMediaId[file.resource.id] = (id, category)
                        mediaResourceIds[id]!.append(file.resource.id)
                    }
                }
            }
            return account.postbox.mediaBox.collectResourceCacheUsage(resourceIds)
            |> mapError { _ -> CollectCacheUsageStatsError in }
            |> mapToSignal { result -> Signal<CacheUsageStatsResult, CollectCacheUsageStatsError> in
                state.with { state -> Void in
                    state.lowerBound = updatedLowerBound
                    for (wrappedId, size) in result {
                        if let (id, category) = resourceIdToMediaId[wrappedId] {
                            if let peerId = mediaIdToPeerId[id] {
                                if state.media[peerId] == nil {
                                    state.media[peerId] = [:]
                                }
                                if state.media[peerId]![category] == nil {
                                    state.media[peerId]![category] = [:]
                                }
                                var currentSize: Int64 = 0
                                if let current = state.media[peerId]![category]![id] {
                                    currentSize = current
                                }
                                state.media[peerId]![category]![id] = currentSize + size
                            }
                        }
                    }
                    for (id, ids) in mediaResourceIds {
                        state.mediaResourceIds[id] = ids
                        for resourceId in ids {
                            state.allResourceIds.insert(resourceId)
                        }
                    }
                }
                if updatedLowerBound == nil {
                    if peerId != nil {
                        let (finalMedia, finalMediaResourceIds, _) = state.with { state -> ([PeerId: [PeerCacheUsageCategory: [MediaId: Int64]]], [MediaId: [MediaResourceId]], Set<MediaResourceId>) in
                            return (state.media, state.mediaResourceIds, state.allResourceIds)
                        }
                         return account.postbox.transaction { transaction -> CacheUsageStats in
                           var peers: [PeerId: Peer] = [:]
                           for peerId in finalMedia.keys {
                               if let peer = transaction.getPeer(peerId) {
                                   peers[peer.id] = peer
                                   if let associatedPeerId = peer.associatedPeerId, let associatedPeer = transaction.getPeer(associatedPeerId) {
                                       peers[associatedPeer.id] = associatedPeer
                                   }
                               }
                           }
                           return CacheUsageStats(media: finalMedia, mediaResourceIds: finalMediaResourceIds, peers: peers, otherSize: 0, otherPaths: [], cacheSize: 0, tempPaths: [], tempSize: 0, immutableSize: 0)
                       } |> mapError { _ -> CollectCacheUsageStatsError in }
                       |> mapToSignal { stats -> Signal<CacheUsageStatsResult, CollectCacheUsageStatsError> in
                           return .fail(.done(stats))
                       }
                    }
                    
                    let (finalMedia, finalMediaResourceIds, allResourceIds) = state.with { state -> ([PeerId: [PeerCacheUsageCategory: [MediaId: Int64]]], [MediaId: [MediaResourceId]], Set<MediaResourceId>) in
                        return (state.media, state.mediaResourceIds, state.allResourceIds)
                    }
                    
                    return account.postbox.mediaBox.collectOtherResourceUsage(excludeIds: excludeResourceIds, combinedExcludeIds: allResourceIds.union(excludeResourceIds))
                    |> mapError { _ -> CollectCacheUsageStatsError in }
                    |> mapToSignal { otherSize, otherPaths, cacheSize in
                        var tempPaths: [String] = []
                        var tempSize: Int64 = 0
                        #if os(iOS)
                            if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: NSTemporaryDirectory()), includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .isSymbolicLinkKey]) {
                                for url in enumerator {
                                    if let url = url as? URL {
                                        if let isDirectoryValue = (try? url.resourceValues(forKeys: Set([.isDirectoryKey])))?.isDirectory, isDirectoryValue {
                                            tempPaths.append(url.path)
                                        } else if let fileSizeValue = (try? url.resourceValues(forKeys: Set([.fileAllocatedSizeKey])))?.fileAllocatedSize {
                                            tempPaths.append(url.path)
                                            
                                            if let isSymbolicLinkValue = (try? url.resourceValues(forKeys: Set([.isSymbolicLinkKey])))?.isSymbolicLink, isSymbolicLinkValue {
                                            } else {
                                                tempSize += Int64(fileSizeValue)
                                            }
                                        }
                                    }
                                }
                            }
                        #endif
                        
                        var immutableSize: Int64 = 0
                        if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: account.basePath + "/postbox/db"), includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: []) {
                            for url in files {
                                if let fileSize = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize {
                                    immutableSize += Int64(fileSize)
                                }
                            }
                        }
                        if let logFilesPath = logFilesPath, let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: logFilesPath), includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: []) {
                            for url in files {
                                if let fileSize = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize {
                                    immutableSize += Int64(fileSize)
                                }
                            }
                        }
                        
                        for additionalPath in additionalCachePaths {
                            if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: additionalPath), includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .isSymbolicLinkKey]) {
                                for url in enumerator {
                                    if let url = url as? URL {
                                        if let isDirectoryValue = (try? url.resourceValues(forKeys: Set([.isDirectoryKey])))?.isDirectory, isDirectoryValue {
                                        } else if let fileSizeValue = (try? url.resourceValues(forKeys: Set([.fileAllocatedSizeKey])))?.fileAllocatedSize {
                                            tempPaths.append(url.path)

                                            if let isSymbolicLinkValue = (try? url.resourceValues(forKeys: Set([.isSymbolicLinkKey])))?.isSymbolicLink, isSymbolicLinkValue {
                                            } else {
                                                tempSize += Int64(fileSizeValue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        return account.postbox.transaction { transaction -> CacheUsageStats in
                            var peers: [PeerId: Peer] = [:]
                            for peerId in finalMedia.keys {
                                if let peer = transaction.getPeer(peerId) {
                                    peers[peer.id] = peer
                                    if let associatedPeerId = peer.associatedPeerId, let associatedPeer = transaction.getPeer(associatedPeerId) {
                                        peers[associatedPeer.id] = associatedPeer
                                    }
                                }
                            }
                            return CacheUsageStats(media: finalMedia, mediaResourceIds: finalMediaResourceIds, peers: peers, otherSize: otherSize, otherPaths: otherPaths, cacheSize: cacheSize, tempPaths: tempPaths, tempSize: tempSize, immutableSize: immutableSize)
                        } |> mapError { _ -> CollectCacheUsageStatsError in }
                        |> mapToSignal { stats -> Signal<CacheUsageStatsResult, CollectCacheUsageStatsError> in
                            return .fail(.done(stats))
                        }
                    }
                } else {
                    return .complete()
                }
            }
        }
        
        let signal = (fetch |> mapToSignal { mediaByPeer, mediaRefs, updatedLowerBound -> Signal<CacheUsageStatsResult, CollectCacheUsageStatsError> in
            return process(mediaByPeer, mediaRefs, updatedLowerBound)
        })
        |> restart
        
        return signal |> `catch` { error in
            switch error {
                case let .done(result):
                    return .single(.result(result))
                case .generic:
                    return .complete()
            }
        }
    }
}

func _internal_clearCachedMediaResources(account: Account, mediaResourceIds: Set<MediaResourceId>) -> Signal<Float, NoError> {
    return account.postbox.mediaBox.removeCachedResources(Array(mediaResourceIds))
}
