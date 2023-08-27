import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import DarwinDirStat

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

public final class StorageUsageStats {
    public enum CategoryKey: Hashable {
        case photos
        case videos
        case files
        case music
        case stickers
        case avatars
        case misc
        case stories
    }
    
    public struct CategoryData {
        public var size: Int64
        public var messages: [EngineMessage.Id: Int64]
        
        public init(size: Int64, messages: [EngineMessage.Id: Int64]) {
            self.size = size
            self.messages = messages
        }
    }
    
    public fileprivate(set) var categories: [CategoryKey: CategoryData]
    
    public init(categories: [CategoryKey: CategoryData]) {
        self.categories = categories
    }
}

public final class AllStorageUsageStats {
    public final class PeerStats {
        public let peer: EnginePeer
        public let stats: StorageUsageStats
        
        public init(peer: EnginePeer, stats: StorageUsageStats) {
            self.peer = peer
            self.stats = stats
        }
    }
    
    public var deviceAvailableSpace: Int64
    public var deviceFreeSpace: Int64
    public fileprivate(set) var totalStats: StorageUsageStats
    public fileprivate(set) var peers: [EnginePeer.Id: PeerStats]
    
    public init(deviceAvailableSpace: Int64, deviceFreeSpace: Int64, totalStats: StorageUsageStats, peers: [EnginePeer.Id: PeerStats]) {
        self.deviceAvailableSpace = deviceAvailableSpace
        self.deviceFreeSpace = deviceFreeSpace
        self.totalStats = totalStats
        self.peers = peers
    }
}

private extension StorageUsageStats {
    convenience init(_ stats: StorageBox.Stats) {
        var mappedCategories: [StorageUsageStats.CategoryKey: StorageUsageStats.CategoryData] = [:]
        for (key, value) in stats.contentTypes {
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
            case MediaResourceUserContentType.other.rawValue:
                mappedCategory = .misc
            case MediaResourceUserContentType.audioVideoMessage.rawValue:
                mappedCategory = .misc
            case MediaResourceUserContentType.story.rawValue:
                mappedCategory = .stories
            default:
                mappedCategory = .misc
            }
            if mappedCategories[mappedCategory] == nil {
                mappedCategories[mappedCategory] = StorageUsageStats.CategoryData(size: value.size, messages: value.messages)
            } else {
                mappedCategories[mappedCategory]?.size += value.size
                mappedCategories[mappedCategory]?.messages.merge(value.messages, uniquingKeysWith: { lhs, _ in lhs})
            }
        }
        
        self.init(categories: mappedCategories)
    }
}

private func statForDirectory(path: String) -> Int64 {
    if #available(macOS 10.13, *) {
        var s = darwin_dirstat()
        var result = dirstat_np(path, 1, &s, MemoryLayout<darwin_dirstat>.size)
        if result != -1 {
            return Int64(s.total_size)
        } else {
            result = dirstat_np(path, 0, &s, MemoryLayout<darwin_dirstat>.size)
            if result != -1 {
                return Int64(s.total_size)
            } else {
                return 0
            }
        }
    } else {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: path)
        var folderSize: Int64 = 0
        if let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: []) {
            for file in files {
                folderSize += (fileSize(file.path) ?? 0)
            }
        }
        return folderSize
    }
}

private func collectDirectoryUsageReportRecursive(path: String, indent: String, log: inout String) {
    guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .isSymbolicLinkKey], options: .skipsSubdirectoryDescendants) else {
        return
    }
    for url in enumerator {
        guard let url = url as? URL else {
            continue
        }
        if let isDirectoryValue = (try? url.resourceValues(forKeys: Set([.isDirectoryKey])))?.isDirectory, isDirectoryValue {
            let subdirectorySize = statForDirectory(path: url.path)
            log.append("\(indent)+ \(url.lastPathComponent): \(subdirectorySize)\n")
            collectDirectoryUsageReportRecursive(path: url.path, indent: indent + "  ", log: &log)
        } else if let fileSizeValue = (try? url.resourceValues(forKeys: Set([.fileAllocatedSizeKey])))?.fileAllocatedSize {
            if let isSymbolicLinkValue = (try? url.resourceValues(forKeys: Set([.isSymbolicLinkKey])))?.isSymbolicLink, isSymbolicLinkValue {
                log.append("\(indent)\(url.lastPathComponent): SYMLINK\n")
            } else {
                log.append("\(indent)\(url.lastPathComponent): \(fileSizeValue)\n")
            }
        }
    }
}

public func collectRawStorageUsageReport(containerPath: String) -> String {
    var log = ""
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let documentsSize = statForDirectory(path: documentsPath)
    log.append("Documents (\(documentsPath)): \(documentsSize)\n")
    collectDirectoryUsageReportRecursive(path: documentsPath, indent: "  ", log: &log)
    
    let systemCachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
    let systemCacheSize = statForDirectory(path: systemCachePath)
    log.append("System Cache (\(systemCachePath)): \(systemCacheSize)\n")
    
    let containerSize = statForDirectory(path: containerPath)
    log.append("Container (\(containerPath)): \(containerSize)\n")
    collectDirectoryUsageReportRecursive(path: containerPath, indent: "  ", log: &log)
    
    return log
}

func _internal_collectStorageUsageStats(account: Account) -> Signal<AllStorageUsageStats, NoError> {
    let additionalStats = account.postbox.mediaBox.cacheStorageBox.totalSize() |> take(1)
    
    return combineLatest(
        additionalStats,
        account.postbox.mediaBox.storageBox.getAllStats()
    )
    |> deliverOnMainQueue
    |> mapToSignal { additionalStats, allStats -> Signal<AllStorageUsageStats, NoError> in
        return account.postbox.transaction { transaction -> AllStorageUsageStats in
            let total = StorageUsageStats(allStats.total)
            if additionalStats != 0 {
                if total.categories[.misc] == nil {
                    total.categories[.misc] = StorageUsageStats.CategoryData(size: 0, messages: [:])
                }
                total.categories[.misc]?.size += additionalStats
            }
            
            var peers: [EnginePeer.Id: AllStorageUsageStats.PeerStats] = [:]
            
            for (peerId, peerStats) in allStats.peers {
                if peerId.id._internalGetInt64Value() == 0 {
                    continue
                }
                
                var peerSize: Int64 = 0
                for (_, contentValue) in peerStats.contentTypes {
                    peerSize += contentValue.size
                }
                if peerSize == 0 {
                    continue
                }
                
                if let peer = transaction.getPeer(peerId), transaction.getPeerChatListIndex(peerId) != nil {
                    peers[peerId] = AllStorageUsageStats.PeerStats(
                        peer: EnginePeer(peer),
                        stats: StorageUsageStats(peerStats)
                    )
                }
            }
            
            let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
            let deviceAvailableSpace = (systemAttributes?[FileAttributeKey.systemSize] as? NSNumber)?.int64Value ?? 0
            let deviceFreeSpace = (systemAttributes?[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            
            return AllStorageUsageStats(
                deviceAvailableSpace: deviceAvailableSpace,
                deviceFreeSpace: deviceFreeSpace,
                totalStats: total,
                peers: peers
            )
        }
    }
}

func _internal_renderStorageUsageStatsMessages(account: Account, stats: StorageUsageStats, categories: [StorageUsageStats.CategoryKey], existingMessages: [EngineMessage.Id: Message]) -> Signal<[EngineMessage.Id: Message], NoError> {
    return account.postbox.transaction { transaction -> [EngineMessage.Id: Message] in
        var result: [EngineMessage.Id: Message] = [:]
        var peerInChatList: [EnginePeer.Id: Bool] = [:]
        for (category, value) in stats.categories {
            if !categories.contains(category) {
                continue
            }
            
            for (id, _) in value.messages.sorted(by: { $0.value >= $1.value }).prefix(1000) {
                if result[id] == nil {
                    if let message = existingMessages[id] {
                        result[id] = message
                    } else {
                        var matches = false
                        if let peerInChatListValue = peerInChatList[id.peerId] {
                            if peerInChatListValue {
                                matches = true
                            }
                        } else {
                            let peerInChatListValue = transaction.getPeerChatListIndex(id.peerId) != nil
                            peerInChatList[id.peerId] = peerInChatListValue
                            if peerInChatListValue {
                                matches = true
                            }
                        }
                        
                        if matches, let message = transaction.getMessage(id) {
                            result[id] = message
                        }
                    }
                }
            }
        }
        
        return result
    }
}

func _internal_clearStorage(account: Account, peerId: EnginePeer.Id?, categories: [StorageUsageStats.CategoryKey], includeMessages: [Message], excludeMessages: [Message]) -> Signal<Float, NoError> {
    let mediaBox = account.postbox.mediaBox
    return Signal { subscriber in
        var includeResourceIds = Set<MediaResourceId>()
        for message in includeMessages {
            extractMediaResourceIds(message: message, resourceIds: &includeResourceIds)
        }
        var includeIds: [Data] = []
        for resourceId in includeResourceIds {
            if let data = resourceId.stringRepresentation.data(using: .utf8) {
                includeIds.append(data)
            }
        }
        
        var excludeResourceIds = Set<MediaResourceId>()
        for message in excludeMessages {
            extractMediaResourceIds(message: message, resourceIds: &excludeResourceIds)
        }
        var excludeIds: [Data] = []
        for resourceId in excludeResourceIds {
            if let data = resourceId.stringRepresentation.data(using: .utf8) {
                excludeIds.append(data)
            }
        }
        
        var mappedContentTypes: [UInt8] = []
        for item in categories {
            switch item {
            case .photos:
                mappedContentTypes.append(MediaResourceUserContentType.image.rawValue)
            case .videos:
                mappedContentTypes.append(MediaResourceUserContentType.video.rawValue)
            case .files:
                mappedContentTypes.append(MediaResourceUserContentType.file.rawValue)
            case .music:
                mappedContentTypes.append(MediaResourceUserContentType.audio.rawValue)
            case .stickers:
                mappedContentTypes.append(MediaResourceUserContentType.sticker.rawValue)
            case .avatars:
                mappedContentTypes.append(MediaResourceUserContentType.avatar.rawValue)
            case .misc:
                mappedContentTypes.append(MediaResourceUserContentType.other.rawValue)
                mappedContentTypes.append(MediaResourceUserContentType.audioVideoMessage.rawValue)
                
                // Legacy value for Gif
                mappedContentTypes.append(5)
            case .stories:
                mappedContentTypes.append(MediaResourceUserContentType.story.rawValue)
            }
        }
        
        mediaBox.storageBox.remove(peerId: peerId, contentTypes: mappedContentTypes, includeIds: includeIds, excludeIds: excludeIds, completion: { ids in
            var resourceIds: [MediaResourceId] = []
            for id in ids {
                if let value = String(data: id, encoding: .utf8) {
                    resourceIds.append(MediaResourceId(value))
                }
            }
            let _ = mediaBox.removeCachedResources(resourceIds).start(next: { progress in
                subscriber.putNext(progress)
            }, completed: {
                if peerId == nil && categories.contains(.misc) {
                    let additionalPaths: [String] = [
                        "cache",
                        "animation-cache",
                        "short-cache",
                    ]
                    
                    for item in additionalPaths {
                        let fullPath = mediaBox.basePath + "/\(item)"
                        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: fullPath), includingPropertiesForKeys: [.isDirectoryKey], options: .skipsSubdirectoryDescendants) {
                            for url in enumerator {
                                guard let url = url as? URL else {
                                    continue
                                }
                                let _ = try? FileManager.default.removeItem(at: url)
                            }
                        }
                    }
                    
                    mediaBox.cacheStorageBox.reset()
                    
                    subscriber.putCompletion()
                } else {
                    subscriber.putCompletion()
                }
            })
        })
        
        return ActionDisposable {
        }
    }
}

func _internal_clearStorage(account: Account, peerIds: Set<EnginePeer.Id>, includeMessages: [Message], excludeMessages: [Message]) -> Signal<Float, NoError> {
    let mediaBox = account.postbox.mediaBox
    return Signal { subscriber in
        var includeResourceIds = Set<MediaResourceId>()
        for message in includeMessages {
            extractMediaResourceIds(message: message, resourceIds: &includeResourceIds)
        }
        var includeIds: [Data] = []
        for resourceId in includeResourceIds {
            if let data = resourceId.stringRepresentation.data(using: .utf8) {
                includeIds.append(data)
            }
        }
        
        var excludeResourceIds = Set<MediaResourceId>()
        for message in excludeMessages {
            extractMediaResourceIds(message: message, resourceIds: &excludeResourceIds)
        }
        var excludeIds: [Data] = []
        for resourceId in excludeResourceIds {
            if let data = resourceId.stringRepresentation.data(using: .utf8) {
                excludeIds.append(data)
            }
        }
        
        mediaBox.storageBox.remove(peerIds: peerIds, includeIds: includeIds, excludeIds: excludeIds, completion: { ids in
            var resourceIds: [MediaResourceId] = []
            
            for id in ids {
                if let value = String(data: id, encoding: .utf8) {
                    resourceIds.append(MediaResourceId(value))
                }
            }
            let _ = mediaBox.removeCachedResources(resourceIds).start(next: { progress in
                subscriber.putNext(progress)
            }, completed: {
                subscriber.putCompletion()
            })
        })
        
        return ActionDisposable {
        }
    }
}

private func extractMediaResourceIds(message: Message, resourceIds: inout Set<MediaResourceId>) {
    for media in message.media {
        if let image = media as? TelegramMediaImage {
            for representation in image.representations {
                resourceIds.insert(representation.resource.id)
            }
        } else if let file = media as? TelegramMediaFile {
            for representation in file.previewRepresentations {
                resourceIds.insert(representation.resource.id)
            }
            resourceIds.insert(file.resource.id)
        } else if let webpage = media as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                if let image = content.image {
                    for representation in image.representations {
                        resourceIds.insert(representation.resource.id)
                    }
                }
                if let file = content.file {
                    for representation in file.previewRepresentations {
                        resourceIds.insert(representation.resource.id)
                    }
                    resourceIds.insert(file.resource.id)
                }
            }
        } else if let game = media as? TelegramMediaGame {
            if let image = game.image {
                for representation in image.representations {
                    resourceIds.insert(representation.resource.id)
                }
            }
            if let file = game.file {
                for representation in file.previewRepresentations {
                    resourceIds.insert(representation.resource.id)
                }
                resourceIds.insert(file.resource.id)
            }
        }
    }
}

func _internal_clearStorage(account: Account, messages: [Message]) -> Signal<Never, NoError> {
    let mediaBox = account.postbox.mediaBox
    
    return Signal { subscriber in
        DispatchQueue.global().async {
            var resourceIds = Set<MediaResourceId>()
            for message in messages {
                extractMediaResourceIds(message: message, resourceIds: &resourceIds)
            }
            
            var removeIds: [Data] = []
            for resourceId in resourceIds {
                if let id = resourceId.stringRepresentation.data(using: .utf8) {
                    removeIds.append(id)
                }
            }
            
            mediaBox.storageBox.remove(ids: removeIds)
            let _ = mediaBox.removeCachedResources(Array(resourceIds)).start(completed: {
                subscriber.putCompletion()
            })
        }
        
        return ActionDisposable {
        }
    }
}

func _internal_reindexCacheInBackground(account: Account, lowImpact: Bool) -> Signal<Never, NoError> {
    let postbox = account.postbox
    
    let queue = Queue(name: "ReindexCacheInBackground")
    return Signal { subscriber in
        let isCancelled = Atomic<Bool>(value: false)
        
        func process(lowerBound: MessageIndex?) {
            if isCancelled.with({ $0 }) {
                return
            }
            
            let _ = (postbox.transaction { transaction -> (messagesByMediaId: [MediaId: [MessageId]], mediaMap: [MediaId: Media], nextLowerBound: MessageIndex?) in
                return transaction.enumerateMediaMessages(lowerBound: lowerBound, upperBound: nil, limit: 1000)
            }
            |> deliverOn(queue)).start(next: { result in
                Logger.shared.log("ReindexCacheInBackground", "process batch of \(result.mediaMap.count) media")
                
                var storageItems: [(reference: StorageBox.Reference, id: Data, contentType: UInt8, size: Int64)] = []
                
                let mediaBox = postbox.mediaBox
                
                let processResource: ([MessageId], MediaResource, MediaResourceUserContentType) -> Void = { messageIds, resource, contentType in
                    let size = mediaBox.fileSizeForId(resource.id)
                    if size != 0 {
                        if let itemId = resource.id.stringRepresentation.data(using: .utf8) {
                            for messageId in messageIds {
                                storageItems.append((reference: StorageBox.Reference(peerId: messageId.peerId.toInt64(), messageNamespace: UInt8(clamping: messageId.namespace), messageId: messageId.id), id: itemId, contentType: contentType.rawValue, size: size))
                            }
                        }
                    }
                }
                
                for (_, media) in result.mediaMap {
                    guard let mediaId = media.id else {
                        continue
                    }
                    guard let mediaMessages = result.messagesByMediaId[mediaId] else {
                        continue
                    }
                    
                    if let image = media as? TelegramMediaImage {
                        for representation in image.representations {
                            processResource(mediaMessages, representation.resource, .image)
                        }
                    } else if let file = media as? TelegramMediaFile {
                        for representation in file.previewRepresentations {
                            processResource(mediaMessages, representation.resource, MediaResourceUserContentType(file: file))
                        }
                        processResource(mediaMessages, file.resource, MediaResourceUserContentType(file: file))
                    } else if let webpage = media as? TelegramMediaWebpage {
                        if case let .Loaded(content) = webpage.content {
                            if let image = content.image {
                                for representation in image.representations {
                                    processResource(mediaMessages, representation.resource, .image)
                                }
                            }
                            if let file = content.file {
                                for representation in file.previewRepresentations {
                                    processResource(mediaMessages, representation.resource, MediaResourceUserContentType(file: file))
                                }
                                processResource(mediaMessages, file.resource, MediaResourceUserContentType(file: file))
                            }
                        }
                    } else if let game = media as? TelegramMediaGame {
                        if let image = game.image {
                            for representation in image.representations {
                                processResource(mediaMessages, representation.resource, .image)
                            }
                        }
                        if let file = game.file {
                            for representation in file.previewRepresentations {
                                processResource(mediaMessages, representation.resource, MediaResourceUserContentType(file: file))
                            }
                            processResource(mediaMessages, file.resource, MediaResourceUserContentType(file: file))
                        }
                    }
                }
                
                if !storageItems.isEmpty {
                    mediaBox.storageBox.batchAdd(items: storageItems)
                }
                
                if let nextLowerBound = result.nextLowerBound {
                    if lowImpact {
                        queue.after(0.4, {
                            process(lowerBound: nextLowerBound)
                        })
                    } else {
                        process(lowerBound: nextLowerBound)
                    }
                } else {
                    subscriber.putCompletion()
                }
            })
        }
        
        process(lowerBound: nil)
        
        return ActionDisposable {
            let _ = isCancelled.swap(true)
        }
    }
    |> runOn(queue)
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
