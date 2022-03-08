import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramUIPreferences
import AccountContext
import UniversalMediaPlayer

public struct FetchManagerLocationEntryId: Hashable {
    public let location: FetchManagerLocation
    public let resourceId: MediaResourceId
    public let locationKey: FetchManagerLocationKey
    
    public static func ==(lhs: FetchManagerLocationEntryId, rhs: FetchManagerLocationEntryId) -> Bool {
        if lhs.location != rhs.location {
            return false
        }
        if lhs.resourceId != rhs.resourceId {
            return false
        }
        if lhs.locationKey != rhs.locationKey {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.resourceId.hashValue)
        hasher.combine(self.locationKey)
    }
}

private final class FetchManagerLocationEntry {
    let id: FetchManagerLocationEntryId
    let episode: Int32
    let mediaReference: AnyMediaReference?
    let resourceReference: MediaResourceReference
    let statsCategory: MediaResourceStatsCategory
    
    var userInitiated: Bool = false
    var storeToDownloadsPeerType: MediaAutoDownloadPeerType?
    let references = Bag<FetchManagerPriority>()
    let ranges = Bag<IndexSet>()
    var elevatedPriorityReferenceCount: Int32 = 0
    var userInitiatedPriorityIndices: [Int32] = []
    var isPaused: Bool = false
    
    var combinedRanges: IndexSet {
        var result = IndexSet()
        if self.userInitiated {
            result.insert(integersIn: 0 ..< Int(Int32.max))
        } else {
            for range in self.ranges.copyItems() {
                result.formUnion(range)
            }
        }
        return result
    }
    
    var priorityKey: FetchManagerPriorityKey? {
        if !self.references.isEmpty || self.userInitiated {
            return FetchManagerPriorityKey(locationKey: self.id.locationKey, hasElevatedPriority: self.elevatedPriorityReferenceCount > 0, userInitiatedPriority: userInitiatedPriorityIndices.last, topReference: self.references.copyItems().max())
        } else {
            return nil
        }
    }
    
    init(id: FetchManagerLocationEntryId, episode: Int32, mediaReference: AnyMediaReference?, resourceReference: MediaResourceReference, statsCategory: MediaResourceStatsCategory) {
        self.id = id
        self.episode = episode
        self.mediaReference = mediaReference
        self.resourceReference = resourceReference
        self.statsCategory = statsCategory
    }
}

private final class FetchManagerActiveContext {
    let userInitiated: Bool
    var ranges = IndexSet()
    var disposable: Disposable?
    
    init(userInitiated: Bool) {
        self.userInitiated = userInitiated
    }
}

private final class FetchManagerStatusContext {
    var disposable: Disposable?
    var originalStatus: MediaResourceStatus?
    var subscribers = Bag<(MediaResourceStatus) -> Void>()
    
    var hasEntry = false
    var isPaused = false
    
    var isEmpty: Bool {
        return !self.hasEntry && self.subscribers.isEmpty
    }
    
    var combinedStatus: MediaResourceStatus? {
        if let originalStatus = self.originalStatus {
            if case let .Remote(progress) = originalStatus, self.hasEntry {
                if self.isPaused {
                    return .Paused(progress: progress)
                } else {
                    return .Fetching(isActive: false, progress: progress)
                }
            } else if self.hasEntry {
                return originalStatus
            } else if case .Local = originalStatus {
                return originalStatus
            } else {
                return .Remote(progress: 0.0)
            }
        } else {
            return nil
        }
    }
}

private final class FetchManagerCategoryContext {
    private let postbox: Postbox
    private let storeManager: DownloadedMediaStoreManager?
    private let entryCompleted: (FetchManagerLocationEntryId) -> Void
    private let activeEntriesUpdated: () -> Void
    
    private var topEntryIdAndPriority: (FetchManagerLocationEntryId, FetchManagerPriorityKey)?
    private var entries: [FetchManagerLocationEntryId: FetchManagerLocationEntry] = [:]
    
    private var activeContexts: [FetchManagerLocationEntryId: FetchManagerActiveContext] = [:]
    private var statusContexts: [FetchManagerLocationEntryId: FetchManagerStatusContext] = [:]
    
    var hasActiveUserInitiatedEntries: Bool {
        for (_, context) in self.activeContexts {
            if context.userInitiated {
                return true
            }
        }
        return false
    }
    
    init(postbox: Postbox, storeManager: DownloadedMediaStoreManager?, entryCompleted: @escaping (FetchManagerLocationEntryId) -> Void, activeEntriesUpdated: @escaping () -> Void) {
        self.postbox = postbox
        self.storeManager = storeManager
        self.entryCompleted = entryCompleted
        self.activeEntriesUpdated = activeEntriesUpdated
    }
    
    func getActiveEntries() -> [FetchManagerLocationEntry] {
        return Array(self.entries.values)
    }
    
    func withEntry(id: FetchManagerLocationEntryId, takeNew: (() -> (AnyMediaReference?, MediaResourceReference, MediaResourceStatsCategory, Int32))?, _ f: (FetchManagerLocationEntry) -> Void) {
        let entry: FetchManagerLocationEntry
        let previousPriorityKey: FetchManagerPriorityKey?
        
        if let current = self.entries[id] {
            entry = current
            previousPriorityKey = entry.priorityKey
        } else if let takeNew = takeNew {
            previousPriorityKey = nil
            let (mediaReference, resourceReference, statsCategory, episode) = takeNew()
            entry = FetchManagerLocationEntry(id: id, episode: episode, mediaReference: mediaReference, resourceReference: resourceReference, statsCategory: statsCategory)
            self.entries[id] = entry
        } else {
            return
        }
        
        f(entry)
        
        var removedEntries = false
        
        let updatedPriorityKey = entry.priorityKey
        if previousPriorityKey != updatedPriorityKey {
            if let updatedPriorityKey = updatedPriorityKey {
                if let (topId, topPriority) = self.topEntryIdAndPriority {
                    if updatedPriorityKey < topPriority {
                        self.topEntryIdAndPriority = (entry.id, updatedPriorityKey)
                    } else if updatedPriorityKey > topPriority && topId == id {
                        self.topEntryIdAndPriority = nil
                    }
                } else {
                    self.topEntryIdAndPriority = (entry.id, updatedPriorityKey)
                }
            } else {
                if self.topEntryIdAndPriority?.0 == id {
                    self.topEntryIdAndPriority = nil
                }
                self.entries.removeValue(forKey: id)
                removedEntries = true
            }
        }
        
        var activeContextsUpdated = false
        let _ = activeContextsUpdated
        
        if self.maybeFindAndActivateNewTopEntry() {
            activeContextsUpdated = true
        }
        
        if removedEntries {
            var removedIds: [FetchManagerLocationEntryId] = []
            for (entryId, activeContext) in self.activeContexts {
                if self.entries[entryId] == nil {
                    removedIds.append(entryId)
                    activeContext.disposable?.dispose()
                }
            }
            for entryId in removedIds {
                self.activeContexts.removeValue(forKey: entryId)
                activeContextsUpdated = true
            }
        }
        
        let ranges = entry.combinedRanges
        
        if let activeContext = self.activeContexts[id] {
            if activeContext.disposable == nil || activeContext.ranges != ranges {
                if let entry = self.entries[id] {
                    activeContext.ranges = ranges
                    let entryCompleted = self.entryCompleted
                    let storeManager = self.storeManager
                    let parsedRanges: [(Range<Int>, MediaBoxFetchPriority)]?
                    if ranges.count == 1 && ranges.min() == 0 && ranges.max() == Int(Int32.max) {
                        parsedRanges = nil
                    } else {
                        var resultRanges: [(Range<Int>, MediaBoxFetchPriority)] = []
                        for range in ranges.rangeView {
                            resultRanges.append((range, .default))
                        }
                        parsedRanges = resultRanges
                    }
                    activeContext.disposable?.dispose()
                    let postbox = self.postbox
                    activeContext.disposable = (fetchedMediaResource(mediaBox: postbox.mediaBox, reference: entry.resourceReference, ranges: parsedRanges, statsCategory: entry.statsCategory, reportResultStatus: true, continueInBackground: entry.userInitiated)
                    |> mapToSignal { type -> Signal<FetchResourceSourceType, FetchResourceError> in
                        if filterDownloadStatsEntry(entry: entry), case let .message(message, _) = entry.mediaReference, let messageId = message.id, case .remote = type {
                            let _ = addRecentDownloadItem(postbox: postbox, item: RecentDownloadItem(messageId: messageId, resourceId: entry.resourceReference.resource.id.stringRepresentation, timestamp: Int32(Date().timeIntervalSince1970), isSeen: false)).start()
                        }
                        
                        if let storeManager = storeManager, let mediaReference = entry.mediaReference, case .remote = type, let peerType = entry.storeToDownloadsPeerType {
                            return storeDownloadedMedia(storeManager: storeManager, media: mediaReference, peerType: peerType)
                            |> castError(FetchResourceError.self)
                            |> mapToSignal { _ -> Signal<FetchResourceSourceType, FetchResourceError> in
                            }
                            |> then(.single(type))
                        }
                        return .single(type)
                    }
                    |> deliverOnMainQueue).start(next: { _ in
                        entryCompleted(id)
                    })
                } else {
                    assertionFailure()
                }
            }
        }
        
        if let statusContext = self.statusContexts[id] {
            let previousStatus = statusContext.combinedStatus
            if let entry = self.entries[id] {
                statusContext.hasEntry = true
                statusContext.isPaused = entry.isPaused
            } else {
                statusContext.hasEntry = false
                statusContext.isPaused = false
            }
            if let combinedStatus = statusContext.combinedStatus, combinedStatus != previousStatus {
                for f in statusContext.subscribers.copyItems() {
                    f(combinedStatus)
                }
            }
        }
        
        self.activeEntriesUpdated()
    }
    
    func maybeFindAndActivateNewTopEntry() -> Bool {
        if self.topEntryIdAndPriority == nil && !self.entries.isEmpty {
            var topEntryIdAndPriority: (FetchManagerLocationEntryId, FetchManagerPriorityKey)?
            for (id, entry) in self.entries {
                if entry.isPaused {
                    continue
                }
                if let entryPriorityKey = entry.priorityKey {
                    if let (_, topKey) = topEntryIdAndPriority {
                        if entryPriorityKey < topKey {
                            topEntryIdAndPriority = (id, entryPriorityKey)
                        }
                    } else {
                        topEntryIdAndPriority = (id, entryPriorityKey)
                    }
                } else {
                    assertionFailure()
                }
            }
            
            self.topEntryIdAndPriority = topEntryIdAndPriority
        }
        
        if let topEntryId = self.topEntryIdAndPriority?.0 {
            if let entry = self.entries[topEntryId] {
                let ranges = entry.combinedRanges
                
                let parsedRanges: [(Range<Int>, MediaBoxFetchPriority)]?
                
                var count = 0
                var isCompleteRange = false
                var isVideoPreload = false
                for range in ranges.rangeView {
                    count += 1
                    if range.lowerBound == 0 && range.upperBound == Int(Int32.max) {
                        isCompleteRange = true
                    }
                }
                
                if count == 2, let range = ranges.rangeView.first, range.lowerBound == 0 && range.upperBound == 2 * 1024 * 1024 {
                    isVideoPreload = true
                }
                
                if count == 1 && isCompleteRange {
                    parsedRanges = nil
                } else {
                    var resultRanges: [(Range<Int>, MediaBoxFetchPriority)] = []
                    for range in ranges.rangeView {
                        resultRanges.append((range, .default))
                    }
                    parsedRanges = resultRanges
                }
                
                let activeContext: FetchManagerActiveContext
                var restart = false
                if let current = self.activeContexts[topEntryId] {
                    activeContext = current
                    restart = activeContext.ranges != ranges
                } else {
                    activeContext = FetchManagerActiveContext(userInitiated: entry.userInitiated)
                    self.activeContexts[topEntryId] = activeContext
                    restart = true
                }
                
                if restart {
                    activeContext.ranges = ranges
                    
                    let entryCompleted = self.entryCompleted
                    let storeManager = self.storeManager
                    activeContext.disposable?.dispose()
                    if isVideoPreload {
                        activeContext.disposable = (preloadVideoResource(postbox: self.postbox, resourceReference: entry.resourceReference, duration: 4.0)
                        |> castError(FetchResourceError.self)
                        |> map { _ -> FetchResourceSourceType in }
                        |> then(.single(.local))
                        |> deliverOnMainQueue).start(next: { _ in
                            entryCompleted(topEntryId)
                        })
                    } else if ranges.isEmpty {
                    } else {
                        let postbox = self.postbox
                        activeContext.disposable = (fetchedMediaResource(mediaBox: postbox.mediaBox, reference: entry.resourceReference, ranges: parsedRanges, statsCategory: entry.statsCategory, reportResultStatus: true, continueInBackground: entry.userInitiated)
                        |> mapToSignal { type -> Signal<FetchResourceSourceType, FetchResourceError> in
                            if filterDownloadStatsEntry(entry: entry), case let .message(message, _) = entry.mediaReference, let messageId = message.id, case .remote = type {
                                let _ = addRecentDownloadItem(postbox: postbox, item: RecentDownloadItem(messageId: messageId, resourceId: entry.resourceReference.resource.id.stringRepresentation, timestamp: Int32(Date().timeIntervalSince1970), isSeen: false)).start()
                            }
                            
                            if let storeManager = storeManager, let mediaReference = entry.mediaReference, case .remote = type, let peerType = entry.storeToDownloadsPeerType {
                                return storeDownloadedMedia(storeManager: storeManager, media: mediaReference, peerType: peerType)
                                |> castError(FetchResourceError.self)
                                |> mapToSignal { _ -> Signal<FetchResourceSourceType, FetchResourceError> in
                                }
                                |> then(.single(type))
                            }
                            return .single(type)
                        }
                        |> deliverOnMainQueue).start(next: { _ in
                            entryCompleted(topEntryId)
                        })
                    }
                    return true
                } else {
                    return false
                }
            } else {
                assertionFailure()
                return false
            }
        } else {
            return false
        }
    }
    
    func getEntryId(resourceId: String) -> FetchManagerLocationEntryId? {
        for (id, _) in self.entries {
            if id.resourceId.stringRepresentation == resourceId {
                return id
            }
        }
        return nil
    }
    
    func cancelEntry(_ entryId: FetchManagerLocationEntryId, isCompleted: Bool) {
        var id: FetchManagerLocationEntryId = entryId
        if self.entries[id] == nil {
            for (key, _) in self.entries {
                if key.resourceId == entryId.resourceId {
                    id = key
                    break
                }
            }
        }
        
        var entriesRemoved = false
        let _ = entriesRemoved
        
        if let _ = self.entries[id] {
            self.entries.removeValue(forKey: id)
            entriesRemoved = true
            
            if let statusContext = self.statusContexts[id] {
                if statusContext.hasEntry {
                    if isCompleted {
                        statusContext.originalStatus = .Local
                    }
                    let previousStatus = statusContext.combinedStatus
                    statusContext.hasEntry = false
                    statusContext.isPaused = false
                    if let combinedStatus = statusContext.combinedStatus, combinedStatus != previousStatus {
                        for f in statusContext.subscribers.copyItems() {
                            f(combinedStatus)
                        }
                    }
                }
            }
        }
        
        var activeContextsUpdated = false
        let _ = activeContextsUpdated
        
        if let activeContext = self.activeContexts[id] {
            activeContext.disposable?.dispose()
            activeContext.disposable = nil
            self.activeContexts.removeValue(forKey: id)
            activeContextsUpdated = true
        }
        
        if self.topEntryIdAndPriority?.0 == id {
            self.topEntryIdAndPriority = nil
        }
        
        if self.maybeFindAndActivateNewTopEntry() {
            activeContextsUpdated = true
        }
        
        self.activeEntriesUpdated()
    }
    
    func toggleEntryPaused(_ entryId: FetchManagerLocationEntryId, isPaused: Bool) -> Bool {
        var id: FetchManagerLocationEntryId = entryId
        if self.entries[id] == nil {
            for (key, _) in self.entries {
                if key.resourceId == entryId.resourceId {
                    id = key
                    break
                }
            }
        }
        
        if let entry = self.entries[id] {
            if entry.isPaused == isPaused {
                return entry.isPaused
            }
            entry.isPaused = !entry.isPaused
            
            if entry.isPaused {
                if self.topEntryIdAndPriority?.0 == id {
                    self.topEntryIdAndPriority = nil
                }
                
                if let activeContext = self.activeContexts[id] {
                    activeContext.disposable?.dispose()
                    activeContext.disposable = nil
                    self.activeContexts.removeValue(forKey: id)
                }
            }
            
            if let statusContext = self.statusContexts[id] {
                let previousStatus = statusContext.combinedStatus
                statusContext.hasEntry = true
                statusContext.isPaused = entry.isPaused
                if let combinedStatus = statusContext.combinedStatus, combinedStatus != previousStatus {
                    for f in statusContext.subscribers.copyItems() {
                        f(combinedStatus)
                    }
                }
            }
            
            let _ = self.maybeFindAndActivateNewTopEntry()
            self.activeEntriesUpdated()
            
            return entry.isPaused
        } else {
            return false
        }
    }
    
    func raiseEntryPriority(_ entryId: FetchManagerLocationEntryId) {
        var id: FetchManagerLocationEntryId = entryId
        if self.entries[id] == nil {
            for (key, _) in self.entries {
                if key.resourceId == entryId.resourceId {
                    id = key
                    break
                }
            }
        }
        
        if self.entries[id] == nil {
            return
        }
        
        var topUserInitiatedPriority: Int32 = 0
        for (_, entry) in self.entries {
            for index in entry.userInitiatedPriorityIndices {
                topUserInitiatedPriority = min(topUserInitiatedPriority, index)
            }
        }
        
        self.withEntry(id: id, takeNew: nil, { entry in
            if entry.userInitiatedPriorityIndices.last == topUserInitiatedPriority {
                return
            }
            
            entry.userInitiatedPriorityIndices.removeAll()
            entry.userInitiatedPriorityIndices.append(topUserInitiatedPriority - 1)
        })
    }
    
    func withFetchStatusContext(_ id: FetchManagerLocationEntryId, _ f: (FetchManagerStatusContext) -> Void) {
        let statusContext: FetchManagerStatusContext
        if let current = self.statusContexts[id] {
            statusContext = current
        } else {
            statusContext = FetchManagerStatusContext()
            self.statusContexts[id] = statusContext
            if let entry = self.entries[id] {
                statusContext.hasEntry = true
                statusContext.isPaused = entry.isPaused
            }
        }
        
        f(statusContext)
        
        if statusContext.isEmpty {
            statusContext.disposable?.dispose()
            self.statusContexts.removeValue(forKey: id)
        }
    }
    
    var isEmpty: Bool {
        return self.entries.isEmpty && self.activeContexts.isEmpty && self.statusContexts.isEmpty
    }
}

public struct FetchManagerEntrySummary: Equatable {
    public let id: FetchManagerLocationEntryId
    public let mediaReference: AnyMediaReference?
    public let resourceReference: MediaResourceReference
    public let priority: FetchManagerPriorityKey
    public let isPaused: Bool
}

private extension FetchManagerEntrySummary {
    init?(entry: FetchManagerLocationEntry) {
        guard let priority = entry.priorityKey else {
            return nil
        }
        self.id = entry.id
        self.mediaReference = entry.mediaReference
        self.resourceReference = entry.resourceReference
        self.priority = priority
        self.isPaused = entry.isPaused
    }
}

private func filterDownloadStatsEntry(entry: FetchManagerLocationEntry) -> Bool {
    guard let mediaReference = entry.mediaReference else {
        return false
    }
    if !entry.userInitiated {
        return false
    }
    switch mediaReference {
    case let .message(_, media):
        switch media {
        case let file as TelegramMediaFile:
            if file.isVideo {
                if file.isAnimated {
                    return false
                }
            }
            if file.isInstantVideo {
                return false
            }
            if file.isSticker {
                return false
            }
            if file.isVoice {
                return false
            }
            return true
        default:
            return false
        }
    default:
        return false
    }
}

public final class FetchManagerImpl: FetchManager {
    public let queue = Queue.mainQueue()
    private let postbox: Postbox
    private let storeManager: DownloadedMediaStoreManager?
    private var nextEpisodeId: Int32 = 0
    private var nextUserInitiatedIndex: Int32 = 0
    
    private var categoryContexts: [FetchManagerCategory: FetchManagerCategoryContext] = [:]
    
    private let hasUserInitiatedEntriesValue = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var hasUserInitiatedEntries: Signal<Bool, NoError> {
        return self.hasUserInitiatedEntriesValue.get()
    }
    
    private let entriesSummaryValue = ValuePromise<[FetchManagerEntrySummary]>([], ignoreRepeated: true)
    public var entriesSummary: Signal<[FetchManagerEntrySummary], NoError> {
        return self.entriesSummaryValue.get()
    }
    
    public init(postbox: Postbox, storeManager: DownloadedMediaStoreManager?) {
        self.postbox = postbox
        self.storeManager = storeManager
    }
    
    private func takeNextEpisodeId() -> Int32 {
        let value = self.nextEpisodeId
        self.nextEpisodeId += 1
        return value
    }
    
    private func takeNextUserInitiatedIndex() -> Int32 {
        let value = self.nextUserInitiatedIndex
        self.nextUserInitiatedIndex += 1
        return value
    }
    
    private func withCategoryContext(_ key: FetchManagerCategory, _ f: (FetchManagerCategoryContext) -> Void) {
        assert(self.queue.isCurrent())
        let context: FetchManagerCategoryContext
        if let current = self.categoryContexts[key] {
            context = current
        } else {
            let queue = self.queue
            context = FetchManagerCategoryContext(postbox: self.postbox, storeManager: self.storeManager, entryCompleted: { [weak self] id in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.withCategoryContext(key, { context in
                        context.cancelEntry(id, isCompleted: true)
                    })
                }
            }, activeEntriesUpdated: { [weak self] in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    var hasActiveUserInitiatedEntries = false
                    var activeEntries: [FetchManagerEntrySummary] = []
                    for (_, context) in strongSelf.categoryContexts {
                        if context.hasActiveUserInitiatedEntries {
                            hasActiveUserInitiatedEntries = true
                        }
                        activeEntries.append(contentsOf: context.getActiveEntries().filter { entry in
                            return filterDownloadStatsEntry(entry: entry)
                        }.compactMap { entry -> FetchManagerEntrySummary? in
                            return FetchManagerEntrySummary(entry: entry)
                        })
                    }
                    strongSelf.hasUserInitiatedEntriesValue.set(hasActiveUserInitiatedEntries)
                    
                    let sortedEntries = activeEntries.sorted(by: { $0.priority < $1.priority })
                    
                    strongSelf.entriesSummaryValue.set(sortedEntries)
                }
            })
            self.categoryContexts[key] = context
        }
        
        f(context)
        
        if context.isEmpty {
            self.categoryContexts.removeValue(forKey: key)
        }
    }
    
    public func interactivelyFetched(category: FetchManagerCategory, location: FetchManagerLocation, locationKey: FetchManagerLocationKey, mediaReference: AnyMediaReference?, resourceReference: MediaResourceReference, ranges: IndexSet, statsCategory: MediaResourceStatsCategory, elevatedPriority: Bool, userInitiated: Bool, priority: FetchManagerPriority = .userInitiated, storeToDownloadsPeerType: MediaAutoDownloadPeerType?) -> Signal<Void, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                var assignedEpisode: Int32?
                var assignedUserInitiatedIndex: Int32?
                let _ = assignedUserInitiatedIndex
                
                var assignedReferenceIndex: Int?
                var assignedRangeIndex: Int?
                
                strongSelf.withCategoryContext(category, { context in
                    context.withEntry(id: FetchManagerLocationEntryId(location: location, resourceId: resourceReference.resource.id, locationKey: locationKey), takeNew: { return (mediaReference, resourceReference, statsCategory, strongSelf.takeNextEpisodeId()) }, { entry in
                        assignedEpisode = entry.episode
                        if userInitiated {
                            entry.userInitiated = true
                        }
                        let wasPaused = entry.isPaused
                        entry.isPaused = false
                        if let peerType = storeToDownloadsPeerType {
                            entry.storeToDownloadsPeerType = peerType
                        }
                        assignedReferenceIndex = entry.references.add(priority)
                        if elevatedPriority {
                            entry.elevatedPriorityReferenceCount += 1
                        }
                        assignedRangeIndex = entry.ranges.add(ranges)
                        if userInitiated && !wasPaused {
                            let userInitiatedIndex = strongSelf.takeNextUserInitiatedIndex()
                            assignedUserInitiatedIndex = userInitiatedIndex
                            entry.userInitiatedPriorityIndices.removeAll()
                            entry.userInitiatedPriorityIndices.append(userInitiatedIndex)
                            entry.userInitiatedPriorityIndices.sort()
                        }
                    })
                })
                
                assert(assignedReferenceIndex != nil)
                assert(assignedRangeIndex != nil)
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.withCategoryContext(category, { context in
                                context.withEntry(id: FetchManagerLocationEntryId(location: location, resourceId: resourceReference.resource.id, locationKey: locationKey), takeNew: nil, { entry in
                                    if entry.episode == assignedEpisode {
                                        if let assignedReferenceIndex = assignedReferenceIndex {
                                            let previousCount = entry.references.copyItems().count
                                            entry.references.remove(assignedReferenceIndex)
                                            assert(entry.references.copyItems().count < previousCount)
                                        }
                                        if let assignedRangeIndex = assignedRangeIndex {
                                            let previousCount = entry.ranges.copyItems().count
                                            entry.ranges.remove(assignedRangeIndex)
                                            assert(entry.ranges.copyItems().count < previousCount)
                                        }
                                        if elevatedPriority {
                                            entry.elevatedPriorityReferenceCount -= 1
                                            assert(entry.elevatedPriorityReferenceCount >= 0)
                                        }
                                        /*if let userInitiatedIndex = assignedUserInitiatedIndex {
                                            if let index = entry.userInitiatedPriorityIndices.firstIndex(of: userInitiatedIndex) {
                                                entry.userInitiatedPriorityIndices.remove(at: index)
                                            } else {
                                                assertionFailure()
                                            }
                                        }*/
                                    }
                                })
                            })
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(self.queue)
    }
    
    public func cancelInteractiveFetches(category: FetchManagerCategory, location: FetchManagerLocation, locationKey: FetchManagerLocationKey, resource: MediaResource) {
        self.queue.async {
            self.withCategoryContext(category, { context in
                context.cancelEntry(FetchManagerLocationEntryId(location: location, resourceId: resource.id, locationKey: locationKey), isCompleted: false)
            })
            
            self.postbox.mediaBox.cancelInteractiveResourceFetch(resource)
        }
    }
    
    public func cancelInteractiveFetches(resourceId: String) {
        self.queue.async {
            var removeCategories: [FetchManagerCategory] = []
            for (category, categoryContext) in self.categoryContexts {
                if let id = categoryContext.getEntryId(resourceId: resourceId) {
                    categoryContext.cancelEntry(id, isCompleted: false)
                    if categoryContext.isEmpty {
                        removeCategories.append(category)
                    }
                }
            }
            
            for category in removeCategories {
                self.categoryContexts.removeValue(forKey: category)
            }
            
            self.postbox.mediaBox.cancelInteractiveResourceFetch(resourceId: MediaResourceId(resourceId))
        }
    }
    
    public func toggleInteractiveFetchPaused(resourceId: String, isPaused: Bool) {
        self.queue.async {
            for (_, categoryContext) in self.categoryContexts {
                if let id = categoryContext.getEntryId(resourceId: resourceId) {
                    if categoryContext.toggleEntryPaused(id, isPaused: isPaused) {
                        self.postbox.mediaBox.cancelInteractiveResourceFetch(resourceId: MediaResourceId(resourceId))
                    }
                }
            }
        }
    }
    
    public func raisePriority(resourceId: String) {
        self.queue.async {
            for (_, categoryContext) in self.categoryContexts {
                if let id = categoryContext.getEntryId(resourceId: resourceId) {
                    categoryContext.raiseEntryPriority(id)
                }
            }
        }
    }
    
    public func fetchStatus(category: FetchManagerCategory, location: FetchManagerLocation, locationKey: FetchManagerLocationKey, resource: MediaResource) -> Signal<MediaResourceStatus, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                var assignedIndex: Int?
                
                let entryId = FetchManagerLocationEntryId(location: location, resourceId: resource.id, locationKey: locationKey)
                strongSelf.withCategoryContext(category, { context in
                    context.withFetchStatusContext(entryId, { statusContext in
                        assignedIndex = statusContext.subscribers.add({ status in
                            subscriber.putNext(status)
                            if case .Local = status {
                                subscriber.putCompletion()
                            }
                        })
                        if let status = statusContext.combinedStatus {
                            subscriber.putNext(status)
                            if case .Local = status {
                                subscriber.putCompletion()
                            }
                        }
                        if statusContext.disposable == nil {
                            statusContext.disposable = strongSelf.postbox.mediaBox.resourceStatus(resource).start(next: { status in
                                queue.async {
                                    if let strongSelf = self {
                                        strongSelf.withCategoryContext(category, { context in
                                            context.withFetchStatusContext(entryId, { statusContext in
                                                statusContext.originalStatus = status
                                                if let combinedStatus = statusContext.combinedStatus {
                                                    for f in statusContext.subscribers.copyItems() {
                                                        f(combinedStatus)
                                                    }
                                                }
                                            })
                                        })
                                    }
                                }
                            })
                        }
                    })
                })
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.withCategoryContext(category, { context in
                                context.withFetchStatusContext(entryId, { statusContext in
                                    if let assignedIndex = assignedIndex {
                                        statusContext.subscribers.remove(assignedIndex)
                                    }
                                })
                            })
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(self.queue)
    }
}
