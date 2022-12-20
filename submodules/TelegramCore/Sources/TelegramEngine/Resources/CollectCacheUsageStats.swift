import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

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

public struct StorageUsageStats: Equatable {
    public enum CategoryKey: Hashable {
        case photos
        case videos
        case files
        case music
        case stickers
        case avatars
        case misc
    }
    
    public struct CategoryData: Equatable {
        public var size: Int64
        
        public init(size: Int64) {
            self.size = size
        }
    }
    
    public var categories: [CategoryKey: CategoryData]
    
    public init(categories: [CategoryKey: CategoryData]) {
        self.categories = categories
    }
}

public struct AllStorageUsageStats: Equatable {
    public struct PeerStats: Equatable {
        public var peer: EnginePeer
        public var stats: StorageUsageStats
        
        public init(peer: EnginePeer, stats: StorageUsageStats) {
            self.peer = peer
            self.stats = stats
        }
    }
    
    public var totalStats: StorageUsageStats
    public var peers: [EnginePeer.Id: PeerStats]
    
    public init(totalStats: StorageUsageStats, peers: [EnginePeer.Id: PeerStats]) {
        self.totalStats = totalStats
        self.peers = peers
    }
}

func _internal_collectStorageUsageStats(account: Account) -> Signal<AllStorageUsageStats, NoError> {
    let additionalStats = Signal<Int64, NoError> { subscriber in
        DispatchQueue.global().async {
            var totalSize: Int64 = 0
            
            let additionalPaths: [String] = [
                "cache",
                "animation-cache",
                "short-cache",
            ]
            
            for path in additionalPaths {
                let fullPath: String
                if path.isEmpty {
                    fullPath = account.postbox.mediaBox.basePath
                } else {
                    fullPath = account.postbox.mediaBox.basePath + "/\(path)"
                }
                
                var s = darwin_dirstat()
                var result = dirstat_np(fullPath, 1, &s, MemoryLayout<darwin_dirstat>.size)
                if result != -1 {
                    totalSize += Int64(s.total_size)
                } else {
                    result = dirstat_np(fullPath, 0, &s, MemoryLayout<darwin_dirstat>.size)
                    if result != -1 {
                        totalSize += Int64(s.total_size)
                        print(s.descendants)
                    }
                }
            }
            
            subscriber.putNext(totalSize)
            subscriber.putCompletion()
        }
        
        return EmptyDisposable
    }
    
    return combineLatest(
        additionalStats,
        account.postbox.mediaBox.storageBox.getStats()
    )
    |> deliverOnMainQueue
    |> mapToSignal { additionalStats, allStats -> Signal<AllStorageUsageStats, NoError> in
        var mappedCategories: [StorageUsageStats.CategoryKey: StorageUsageStats.CategoryData] = [:]
        for (key, value) in allStats.contentTypes {
            let mappedCategory: StorageUsageStats.CategoryKey
            switch key {
            case MediaResourceUserContentType.image.rawValue:
                mappedCategory = .photos
            case MediaResourceUserContentType.video.rawValue:
                mappedCategory = .videos
            case MediaResourceUserContentType.file.rawValue:
                mappedCategory = .files
            case MediaResourceUserContentType.audio.rawValue:
                mappedCategory = .music
            case MediaResourceUserContentType.avatar.rawValue:
                mappedCategory = .avatars
            case MediaResourceUserContentType.sticker.rawValue:
                mappedCategory = .stickers
            default:
                mappedCategory = .misc
            }
            mappedCategories[mappedCategory] = StorageUsageStats.CategoryData(size: value)
        }
        
        if additionalStats != 0 {
            mappedCategories[.misc, default: StorageUsageStats.CategoryData(size: 0)].size += additionalStats
        }
        
        return .single(AllStorageUsageStats(
            totalStats: StorageUsageStats(categories: mappedCategories),
            peers: [:]
        ))
    }
}

func _internal_collectCacheUsageStats(account: Account, peerId: PeerId? = nil, additionalCachePaths: [String] = [], logFilesPath: String? = nil) -> Signal<CacheUsageStatsResult, NoError> {
    return account.postbox.mediaBox.storageBox.all()
    |> mapToSignal { entries -> Signal<CacheUsageStatsResult, NoError> in
        final class IncrementalState {
            var startIndex: Int = 0
            
            var media: [PeerId: [PeerCacheUsageCategory: [MediaId: Int64]]] = [:]
            var mediaResourceIds: [MediaId: [MediaResourceId]] = [:]
            var totalSize: Int64 = 0
            var mediaSize: Int64 = 0
            
            var processedResourceIds = Set<String>()
            
            var otherSize: Int64 = 0
            var otherPaths: [String] = []
            
            var peers: [PeerId: Peer] = [:]
        }
        
        let mediaBox = account.postbox.mediaBox
        
        let queue = Queue()
        return Signal<CacheUsageStatsResult, NoError> { subscriber in
            var isCancelled: Bool = false
            
            let state = Atomic<IncrementalState>(value: IncrementalState())
            
            var processNextBatchPtr: (() -> Void)?
            let processNextBatch: () -> Void = {
                if isCancelled {
                    return
                }
                
                let _ = (account.postbox.transaction { transaction -> Void in
                    state.with { state in
                        if state.startIndex >= entries.count {
                            return
                        }
                        
                        let batchCount = 5000
                        let endIndex = min(state.startIndex + batchCount, entries.count)
                        for i in state.startIndex ..< endIndex {
                            let entry = entries[i]
                            
                            guard let resourceIdString = String(data: entry.id, encoding: .utf8) else {
                                continue
                            }
                            let resourceId = MediaResourceId(resourceIdString)
                            if state.processedResourceIds.contains(resourceId.stringRepresentation) {
                                continue
                            }
                            
                            let resourceSize = mediaBox.resourceUsage(id: resourceId)
                            if resourceSize != 0 {
                                state.totalSize += resourceSize
                                
                                for reference in entry.references {
                                    if reference.peerId == 0 {
                                        state.otherSize += resourceSize
                                        
                                        let storePaths = mediaBox.storePathsForId(resourceId)
                                        state.otherPaths.append(storePaths.complete)
                                        state.otherPaths.append(storePaths.partial)
                                        
                                        continue
                                    }
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
                                                state.mediaSize += resourceSize
                                                state.processedResourceIds.insert(resourceId.stringRepresentation)
                                                
                                                state.media[PeerId(reference.peerId), default: [:]][category, default: [:]][mediaId, default: 0] += resourceSize
                                                if let index = state.mediaResourceIds.index(forKey: mediaId) {
                                                    if !state.mediaResourceIds[index].value.contains(resourceId) {
                                                        state.mediaResourceIds[mediaId]?.append(resourceId)
                                                    }
                                                } else {
                                                    state.mediaResourceIds[mediaId] = [resourceId]
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        state.startIndex = endIndex
                    }
                }).start(completed: {
                    if isCancelled {
                        return
                    }
                    let isFinished = state.with { state -> Bool in
                        return state.startIndex >= entries.count
                    }
                    if !isFinished {
                        queue.async {
                            processNextBatchPtr?()
                        }
                    } else {
                        let _ = (account.postbox.transaction { transaction -> Void in
                            state.with { state in
                                for peerId in state.media.keys {
                                    if let peer = transaction.getPeer(peerId) {
                                        state.peers[peer.id] = peer
                                    }
                                }
                            }
                        }).start(completed: {
                            queue.async {
                                let state = state.with { $0 }
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
                                
                                var cacheSize: Int64 = 0
                                let basePath = account.postbox.mediaBox.basePath
                                if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: basePath + "/cache"), includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                                    loop: for url in enumerator {
                                        if let url = url as? URL {
                                            if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                                state.otherPaths.append("cache/" + url.lastPathComponent)
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
                                                    state.otherPaths.append("\(subdirectoryPath)/" + url.lastPathComponent)
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
                                                state.otherPaths.append("short-cache/" + url.lastPathComponent)
                                                cacheSize += Int64(value)
                                            }
                                        }
                                    }
                                }
                                
                                subscriber.putNext(.result(CacheUsageStats(
                                    media: state.media,
                                    mediaResourceIds: state.mediaResourceIds,
                                    peers: state.peers,
                                    otherSize: state.otherSize,
                                    otherPaths: state.otherPaths,
                                    cacheSize: cacheSize,
                                    tempPaths: tempPaths,
                                    tempSize: tempSize,
                                    immutableSize: immutableSize
                                )))
                                subscriber.putCompletion()
                            }
                        })
                    }
                })
            }
            processNextBatchPtr = {
                processNextBatch()
            }
            
            processNextBatch()
            
            return ActionDisposable {
                isCancelled = true
            }
        }
        |> runOn(queue)
    }
    
    /*let initialState = CacheUsageStatsState()
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
    }*/
}

func _internal_clearCachedMediaResources(account: Account, mediaResourceIds: Set<MediaResourceId>) -> Signal<Float, NoError> {
    return account.postbox.mediaBox.removeCachedResources(Array(mediaResourceIds))
}
