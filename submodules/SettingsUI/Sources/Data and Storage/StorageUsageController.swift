import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import ItemListPeerItem
import DeleteChatPeerActionSheetItem
import UndoUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode

private func totalDiskSpace() -> Int64 {
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        return (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value ?? 0
    } catch {
        return 0
    }
}

private func freeDiskSpace() -> Int64 {
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        return (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    } catch {
        return 0
    }
}

private final class StorageUsageControllerArguments {
    let context: AccountContext
    let updateKeepMediaTimeout: (Int32) -> Void
    let updateMaximumCacheSize: (Int32) -> Void
    let openClearAll: () -> Void
    let openPeerMedia: (PeerId) -> Void
    let clearPeerMedia: (PeerId) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    
    init(context: AccountContext, updateKeepMediaTimeout: @escaping (Int32) -> Void, updateMaximumCacheSize: @escaping (Int32) -> Void, openClearAll: @escaping () -> Void, openPeerMedia: @escaping (PeerId) -> Void, clearPeerMedia: @escaping (PeerId) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void) {
        self.context = context
        self.updateKeepMediaTimeout = updateKeepMediaTimeout
        self.updateMaximumCacheSize = updateMaximumCacheSize
        self.openClearAll = openClearAll
        self.openPeerMedia = openPeerMedia
        self.clearPeerMedia = clearPeerMedia
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
    }
}

private enum StorageUsageSection: Int32 {
    case keepMedia
    case maximumSize
    case storage
    case peers
}

private enum StorageUsageEntry: ItemListNodeEntry {
    case keepMediaHeader(PresentationTheme, String)
    case keepMedia(PresentationTheme, PresentationStrings, Int32)
    case keepMediaInfo(PresentationTheme, String)
    
    case maximumSizeHeader(PresentationTheme, String)
    case maximumSize(PresentationTheme, PresentationStrings, Int32)
    case maximumSizeInfo(PresentationTheme, String)
    
    case storageHeader(PresentationTheme, String)
    case storageUsage(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, [StorageUsageCategory])
    case collecting(PresentationTheme, String)
    case clearAll(PresentationTheme, String, Bool)
    
    case peersHeader(PresentationTheme, String)
    case peer(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Peer, Peer?, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .keepMediaHeader, .keepMedia, .keepMediaInfo:
                return StorageUsageSection.keepMedia.rawValue
            case .maximumSizeHeader, .maximumSize, .maximumSizeInfo:
                return StorageUsageSection.maximumSize.rawValue
            case .storageHeader, .storageUsage, .collecting, .clearAll:
                return StorageUsageSection.storage.rawValue
            case .peersHeader, .peer:
                return StorageUsageSection.peers.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .keepMediaHeader:
                return 0
            case .keepMedia:
                return 1
            case .keepMediaInfo:
                return 2
            case .maximumSizeHeader:
                return 3
            case .maximumSize:
                return 4
            case .maximumSizeInfo:
                return 5
            case .storageHeader:
                return 6
            case .storageUsage:
                return 7
            case .collecting:
                return 8
            case .clearAll:
                return 9
            case .peersHeader:
                return 10
            case let .peer(index, _, _, _, _, _, _, _, _):
                return 11 + index
        }
    }
    
    static func ==(lhs: StorageUsageEntry, rhs: StorageUsageEntry) -> Bool {
        switch lhs {
            case let .keepMediaHeader(lhsTheme, lhsText):
                if case let .keepMediaHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .keepMedia(lhsTheme, lhsStrings, lhsValue):
                if case let .keepMedia(rhsTheme, rhsStrings, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .keepMediaInfo(lhsTheme, lhsText):
                if case let .keepMediaInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .maximumSizeHeader(lhsTheme, lhsText):
                if case let .maximumSizeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .maximumSize(lhsTheme, lhsStrings, lhsValue):
                if case let .maximumSize(rhsTheme, rhsStrings, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .maximumSizeInfo(lhsTheme, lhsText):
                if case let .maximumSizeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .storageHeader(lhsTheme, lhsText):
                if case let .storageHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .storageUsage(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsCategories):
                if case let .storageUsage(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsCategories) = rhs, lhsTheme === rhsTheme, lhsStrings == rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsCategories == rhsCategories {
                    return true
                } else {
                    return false
                }
            case let .collecting(lhsTheme, lhsText):
                if case let .collecting(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .clearAll(lhsTheme, lhsText, lhsEnabled):
                if case let .clearAll(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .peersHeader(lhsTheme, lhsText):
                if case let .peersHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsPeer, lhsChatPeer, lhsValue, lhsRevealed):
                if case let .peer(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsPeer, rhsChatPeer, rhsValue, rhsRevealed) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameOrder != rhsNameOrder {
                        return false
                    }
                    if !arePeersEqual(lhsPeer, rhsPeer) {
                        return false
                    }
                    if !arePeersEqual(lhsChatPeer, rhsChatPeer) {
                        return false
                    }
                    if lhsValue != rhsValue {
                        return false
                    }
                    if lhsRevealed != rhsRevealed {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: StorageUsageEntry, rhs: StorageUsageEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! StorageUsageControllerArguments
        switch self {
            case let .keepMediaHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .keepMedia(theme, strings, value):
                return KeepMediaDurationPickerItem(theme: theme, strings: strings, value: value, sectionId: self.section, updated: { updatedValue in
                    arguments.updateKeepMediaTimeout(updatedValue)
                })
            case let .keepMediaInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .maximumSizeHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .maximumSize(theme, strings, value):
                return MaximumCacheSizePickerItem(theme: theme, strings: strings, value: value, sectionId: self.section, updated: { updatedValue in
                    arguments.updateMaximumCacheSize(updatedValue)
                })
            case let .maximumSizeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .storageHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .storageUsage(theme, strings, dateTimeFormat, categories):
                return StorageUsageItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, categories: categories, sectionId: self.section)
            case let .collecting(theme, text):
                return CalculatingCacheSizeItem(theme: theme, title: text, sectionId: self.section, style: .blocks)
            case let .clearAll(_, text, enabled):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if enabled {
                        arguments.openClearAll()
                    }
                })
            case let .peersHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .peer(_, _, strings, dateTimeFormat, nameDisplayOrder, peer, chatPeer, value, revealed):
                let options: [ItemListPeerItemRevealOption] = [ItemListPeerItemRevealOption(type: .destructive, title: strings.ClearCache_Clear, action: {
                    arguments.clearPeerMedia(peer.id)
                })]
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(peer), aliasHandling: .threatSelfAsSaved, nameColor: chatPeer == nil ? .primary : .secret, presence: nil, text: .none, label: .disclosure(value), editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealed), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    let resolvedPeer = chatPeer ?? peer
                    arguments.openPeerMedia(resolvedPeer.id)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { _ in
                })
        }
    }
}

private struct StorageUsageState: Equatable {
    let peerIdWithRevealedOptions: PeerId?

    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> StorageUsageState {
        return StorageUsageState(peerIdWithRevealedOptions: peerIdWithRevealedOptions)
    }
}

private func storageUsageControllerEntries(presentationData: PresentationData, cacheSettings: CacheStorageSettings, cacheStats: CacheUsageStatsResult?, state: StorageUsageState) -> [StorageUsageEntry] {
    var entries: [StorageUsageEntry] = []
    
    entries.append(.keepMediaHeader(presentationData.theme, presentationData.strings.Cache_KeepMedia.uppercased()))
    entries.append(.keepMedia(presentationData.theme, presentationData.strings, cacheSettings.defaultCacheStorageTimeout))
    entries.append(.keepMediaInfo(presentationData.theme, presentationData.strings.Cache_KeepMediaHelp))
    
    entries.append(.maximumSizeHeader(presentationData.theme, presentationData.strings.Cache_MaximumCacheSize.uppercased()))
    entries.append(.maximumSize(presentationData.theme, presentationData.strings, cacheSettings.defaultCacheStorageLimitGigabytes))
    entries.append(.maximumSizeInfo(presentationData.theme, presentationData.strings.Cache_MaximumCacheSizeHelp))
    
    var addedHeader = false
    
    entries.append(.storageHeader(presentationData.theme, presentationData.strings.ClearCache_StorageTitle(stringForDeviceType().uppercased()).string))
    if let cacheStats = cacheStats, case let .result(stats) = cacheStats {
        var peerSizes: Int64 = 0
        var statsByPeerId: [(PeerId, Int64)] = []
        var peerIndices: [PeerId: Int] = [:]
        for (peerId, categories) in stats.media {
            var updatedPeerId = peerId
            if let group = stats.peers[peerId] as? TelegramGroup, let migrationReference = group.migrationReference, let channel = stats.peers[migrationReference.peerId] {
                updatedPeerId = channel.id
            }
            var combinedSize: Int64 = 0
            for (_, media) in categories {
                for (_, size) in media {
                    combinedSize += size
                }
            }
            if let index = peerIndices[updatedPeerId] {
                statsByPeerId[index].1 += combinedSize
            } else {
                peerIndices[updatedPeerId] = statsByPeerId.count
                statsByPeerId.append((updatedPeerId, combinedSize))
            }
            peerSizes += combinedSize
        }
        
        let telegramCacheSize = Int64(peerSizes + stats.otherSize + stats.cacheSize + stats.tempSize)
        let totalTelegramSize = telegramCacheSize + stats.immutableSize
        
        var categories: [StorageUsageCategory] = []
        let totalSpace = max(totalDiskSpace(), 1)
        let freeSpace = freeDiskSpace()
        let otherAppsSpace = totalSpace - freeSpace - totalTelegramSize
        
        let totalSpaceValue = CGFloat(totalSpace)
        
        if telegramCacheSize > 0 {
            categories.append(StorageUsageCategory(title: presentationData.strings.ClearCache_StorageCache, size: totalTelegramSize, fraction: CGFloat(totalTelegramSize) / totalSpaceValue, color: presentationData.theme.list.itemBarChart.color1))
        } else {
            categories.append(StorageUsageCategory(title: presentationData.strings.ClearCache_StorageServiceFiles, size: totalTelegramSize, fraction: CGFloat(totalTelegramSize) / totalSpaceValue, color: presentationData.theme.list.itemBarChart.color1))
        }
        categories.append(StorageUsageCategory(title: presentationData.strings.ClearCache_StorageOtherApps, size: otherAppsSpace, fraction: CGFloat(otherAppsSpace) / totalSpaceValue, color: presentationData.theme.list.itemBarChart.color2))
        categories.append(StorageUsageCategory(title: presentationData.strings.ClearCache_StorageFree, size: freeSpace, fraction: CGFloat(freeSpace) / totalSpaceValue, color: presentationData.theme.list.itemBarChart.color3))
        
        entries.append(.storageUsage(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, categories))
        
        entries.append(.clearAll(presentationData.theme, presentationData.strings.ClearCache_ClearCache, telegramCacheSize > 0))
        
        var index: Int32 = 0
        for (peerId, size) in statsByPeerId.sorted(by: { $0.1 > $1.1 }) {
            if size >= 32 * 1024 {
                if let peer = stats.peers[peerId] {
                    if !addedHeader {
                        addedHeader = true
                        entries.append(.peersHeader(presentationData.theme, presentationData.strings.Cache_ByPeerHeader))
                    }
                    var mainPeer = peer
                    var chatPeer: Peer?
                    if let associatedPeerId = peer.associatedPeerId, let associatedPeer = stats.peers[associatedPeerId] {
                        chatPeer = mainPeer
                        mainPeer = associatedPeer
                    }
                    entries.append(.peer(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, mainPeer, chatPeer, dataSizeString(size, formatting: DataSizeStringFormatting(presentationData: presentationData)), state.peerIdWithRevealedOptions == peer.id))
                    index += 1
                }
            }
        }
    } else {
        entries.append(.collecting(presentationData.theme, presentationData.strings.Cache_Indexing))
    }
    
    return entries
}

private func stringForCategory(strings: PresentationStrings, category: PeerCacheUsageCategory) -> String {
    switch category {
        case .image:
            return strings.Cache_Photos
        case .video:
            return strings.Cache_Videos
        case .audio:
            return strings.Cache_Music
        case .file:
            return strings.Cache_Files
    }
}

func cacheUsageStats(context: AccountContext) -> Signal<CacheUsageStatsResult?, NoError> {
    let containerPath = context.sharedContext.applicationBindings.containerPath
    let additionalPaths: [String] = [
        NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0],
        containerPath + "/Documents/files",
        containerPath + "/Documents/video",
        containerPath + "/Documents/audio",
        containerPath + "/Documents/mediacache",
        containerPath + "/Documents/tempcache_v1/store",
    ]
    return .single(nil)
    |> then(context.engine.resources.collectCacheUsageStats(additionalCachePaths: additionalPaths, logFilesPath: context.sharedContext.applicationBindings.containerPath + "/telegram-data/logs")
    |> map(Optional.init))
}

public func storageUsageController(context: AccountContext, cacheUsagePromise: Promise<CacheUsageStatsResult?>? = nil, isModal: Bool = false) -> ViewController {
    let statePromise = ValuePromise(StorageUsageState(peerIdWithRevealedOptions: nil))
    let stateValue = Atomic(value: StorageUsageState(peerIdWithRevealedOptions: nil))
    let updateState: ((StorageUsageState) -> StorageUsageState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let cacheSettingsPromise = Promise<CacheStorageSettings>()
    cacheSettingsPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
    |> map { sharedData -> CacheStorageSettings in
        let cacheSettings: CacheStorageSettings
        if let value = sharedData.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) {
            cacheSettings = value
        } else {
            cacheSettings = CacheStorageSettings.defaultSettings
        }
        
        return cacheSettings
    })
    
    var presentControllerImpl: ((ViewController, PresentationContextType, Any?) -> Void)?
    
    var statsPromise: Promise<CacheUsageStatsResult?>
    if let cacheUsagePromise = cacheUsagePromise {
        statsPromise = cacheUsagePromise
    } else {
        statsPromise = Promise<CacheUsageStatsResult?>()
        statsPromise.set(cacheUsageStats(context: context))
    }
    
    let resetStats: () -> Void = {
        statsPromise.set(cacheUsageStats(context: context))
    }
    
    let actionDisposables = DisposableSet()
    
    let clearDisposable = MetaDisposable()
    actionDisposables.add(clearDisposable)
    
    let arguments = StorageUsageControllerArguments(context: context, updateKeepMediaTimeout: { value in
        let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedDefaultCacheStorageTimeout(value)
        }).start()
    }, updateMaximumCacheSize: { value in
        let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedDefaultCacheStorageLimitGigabytes(value)
        }).start()
    }, openClearAll: {
        let _ = (statsPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak statsPromise] result in
            if let result = result, case let .result(stats) = result {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                
                var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
                var otherSize: (Bool, Int64) = (true, 0)
                
                for (_, categories) in stats.media {
                    for (category, media) in categories {
                        var combinedSize: Int64 = 0
                        for (_, size) in media {
                            combinedSize += size
                        }
                        if combinedSize != 0 {
                            sizeIndex[category] = (true, (sizeIndex[category]?.1 ?? 0) + combinedSize)
                        }
                    }
                }
                
                if stats.cacheSize + stats.otherSize + stats.tempSize > 10 * 1024 {
                    otherSize = (true, stats.cacheSize + stats.otherSize + stats.tempSize)
                }
                
                var itemIndex = 0
                
                var selectedSize: Int64 = 0
                let updateTotalSize: () -> Void = { [weak controller] in
                    controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                        let title: String
                        var filteredSize = sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
                        if otherSize.0 {
                            filteredSize += otherSize.1
                        }
                        selectedSize = filteredSize
                        
                        if filteredSize == 0 {
                            title = presentationData.strings.Cache_ClearNone
                        } else {
                            title = presentationData.strings.Cache_Clear("\(dataSizeString(filteredSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string
                        }
                        
                        if let item = item as? ActionSheetButtonItem {
                            return ActionSheetButtonItem(title: title, color: filteredSize != 0 ? .accent : .disabled, enabled: filteredSize != 0, action: item.action)
                        }
                        return item
                    })
                }
                
                let toggleCheck: (PeerCacheUsageCategory?, Int) -> Void = { [weak controller] category, itemIndex in
                    if let category = category {
                        if let (value, size) = sizeIndex[category] {
                            sizeIndex[category] = (!value, size)
                        }
                    } else {
                        otherSize = (!otherSize.0, otherSize.1)
                    }
                    controller?.updateItem(groupIndex: 0, itemIndex: itemIndex + 1, { item in
                        if let item = item as? ActionSheetCheckboxItem {
                            return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                        }
                        return item
                    })
                    updateTotalSize()
                }
                var items: [ActionSheetItem] = []
                
                let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file]
                
                var totalSize: Int64 = 0
                
                items.append(ActionSheetTextItem(title: presentationData.strings.ClearCache_ClearDescription))
                
                for categoryId in validCategories {
                    if let (_, size) = sizeIndex[categoryId] {
                        let categorySize: Int64 = size
                        totalSize += categorySize
                        let index = itemIndex
                        items.append(ActionSheetCheckboxItem(title: stringForCategory(strings: presentationData.strings, category: categoryId), label: dataSizeString(categorySize, formatting: DataSizeStringFormatting(presentationData: presentationData)), value: true, action: { value in
                            toggleCheck(categoryId, index)
                        }))
                        itemIndex += 1
                    }
                }
                
                if otherSize.1 != 0 {
                    totalSize += otherSize.1
                    let index = itemIndex
                    items.append(ActionSheetCheckboxItem(title: presentationData.strings.Localization_LanguageOther, label: dataSizeString(otherSize.1, formatting: DataSizeStringFormatting(presentationData: presentationData)), value: true, action: { value in
                        toggleCheck(nil, index)
                    }))
                    itemIndex += 1
                }
                selectedSize = totalSize
                
                if !items.isEmpty {
                    var cancelImpl: (() -> Void)?
                    
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_Clear("\(dataSizeString(totalSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string, action: { [weak controller] in
                        if let statsPromise = statsPromise {
                            let clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
                            
                            var clearMediaIds = Set<MediaId>()
                            
                            var media = stats.media
                            for (peerId, categories) in stats.media {
                                var categories = categories
                                for category in clearCategories {
                                    if let contents = categories[category] {
                                        for (mediaId, _) in contents {
                                            clearMediaIds.insert(mediaId)
                                        }
                                    }
                                    categories.removeValue(forKey: category)
                                }
                                
                                media[peerId] = categories
                            }
                            
                            var clearResourceIds = Set<MediaResourceId>()
                            for id in clearMediaIds {
                                if let ids = stats.mediaResourceIds[id] {
                                    for resourceId in ids {
                                        clearResourceIds.insert(resourceId)
                                    }
                                }
                            }
                            
                            var updatedOtherPaths = stats.otherPaths
                            var updatedOtherSize = stats.otherSize
                            var updatedCacheSize = stats.cacheSize
                            var updatedTempPaths = stats.tempPaths
                            var updatedTempSize = stats.tempSize
                            
                            var signal: Signal<Float, NoError> = context.engine.resources.clearCachedMediaResources(mediaResourceIds: clearResourceIds)
                            if otherSize.0 {
                                let removeTempFiles: Signal<Float, NoError> = Signal { subscriber in
                                    let fileManager = FileManager.default
                                    var count: Int = 0
                                    let totalCount = stats.tempPaths.count
                                    
                                    let reportProgress: (Int) -> Void = { count in
                                        Queue.mainQueue().async {
                                            subscriber.putNext(min(1.0, Float(count) / Float(totalCount)))
                                        }
                                    }
                                    
                                    if totalCount == 0 {
                                        subscriber.putNext(1.0)
                                        subscriber.putCompletion()
                                        return EmptyDisposable
                                    }
                                    
                                    for path in stats.tempPaths {
                                        let _ = try? fileManager.removeItem(atPath: path)
                                        count += 1
                                        reportProgress(count)
                                    }
                                    
                                    subscriber.putCompletion()
                                    return EmptyDisposable
                                } |> runOn(Queue.concurrentDefaultQueue())
                                signal = (signal |> map { $0 * 0.7 })
                                |> then(context.account.postbox.mediaBox.removeOtherCachedResources(paths: stats.otherPaths) |> map { 0.7 + 0.2 * $0 })
                                |> then(removeTempFiles |> map { 0.9 + 0.1 * $0 })
                            }
                            
                            if otherSize.0 {
                                updatedOtherPaths = []
                                updatedOtherSize = 0
                                updatedCacheSize = 0
                                updatedTempPaths = []
                                updatedTempSize = 0
                            }
                            
                            let progressPromise = ValuePromise<Float>(0.0)
                            let overlayNode = StorageUsageClearProgressOverlayNode(presentationData: presentationData)
                            overlayNode.setProgressSignal(progressPromise.get())
                            controller?.setItemGroupOverlayNode(groupIndex: 0, node: overlayNode)
                            
                            let resultStats = CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers, otherSize: updatedOtherSize, otherPaths: updatedOtherPaths, cacheSize: updatedCacheSize, tempPaths: updatedTempPaths, tempSize: updatedTempSize, immutableSize: stats.immutableSize)
                            
                            cancelImpl = {
                                clearDisposable.set(nil)
                                resetStats()
                            }
                            statsPromise.set(.single(.result(resultStats)))
                            clearDisposable.set((signal
                            |> deliverOnMainQueue).start(next: { progress in
                                progressPromise.set(progress)
                            }, completed: {
                                statsPromise.set(.single(.result(resultStats)))
                                progressPromise.set(1.0)
                                Queue.mainQueue().after(1.0) {
                                    dismissAction()
                                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(selectedSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))", stringForDeviceType()).string), elevatedLayout: false, action: { _ in return false }), .current, nil)
                                }
                            }))
                        }
                    }))
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: {
                            cancelImpl?()
                            dismissAction()
                        })])
                    ])
                    presentControllerImpl?(controller, .window(.root), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            }
        })
    }, openPeerMedia: { peerId in
        let _ = (statsPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak statsPromise] result in
            if let result = result, case let .result(stats) = result {
                var additionalPeerId: PeerId?
                if var categories = stats.media[peerId], let peer = stats.peers[peerId] {
                    if let channel = peer as? TelegramChannel, case .group = channel.info {
                        for (_, peer) in stats.peers {
                            if let group = peer as? TelegramGroup, let migrationReference = group.migrationReference, migrationReference.peerId == peerId {
                                if let additionalCategories = stats.media[group.id] {
                                    additionalPeerId = group.id
                                    categories.merge(additionalCategories, uniquingKeysWith: { lhs, rhs in
                                        return lhs.merging(rhs, uniquingKeysWith: { lhs, rhs in
                                            return lhs + rhs
                                        })
                                    })
                                }
                            }
                        }
                    }
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = ActionSheetController(presentationData: presentationData)
                    let dismissAction: () -> Void = { [weak controller] in
                        controller?.dismissAnimated()
                    }
                    
                    var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
                    
                    var itemIndex = 1
                    
                    var selectedSize: Int64 = 0
                    let updateTotalSize: () -> Void = { [weak controller] in
                        controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                            let title: String
                            let filteredSize = sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
                            selectedSize = filteredSize
                            
                            if filteredSize == 0 {
                                title = presentationData.strings.Cache_ClearNone
                            } else {
                                title = presentationData.strings.Cache_Clear("\(dataSizeString(filteredSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string
                            }
                            
                            if let item = item as? ActionSheetButtonItem {
                                return ActionSheetButtonItem(title: title, color: filteredSize != 0 ? .accent : .disabled, enabled: filteredSize != 0, action: item.action)
                            }
                            return item
                        })
                    }
                    
                    let toggleCheck: (PeerCacheUsageCategory, Int) -> Void = { [weak controller] category, itemIndex in
                        if let (value, size) = sizeIndex[category] {
                            sizeIndex[category] = (!value, size)
                        }
                        controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                            if let item = item as? ActionSheetCheckboxItem {
                                return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                            }
                            return item
                        })
                        updateTotalSize()
                    }
                    var items: [ActionSheetItem] = []
                    
                    items.append(DeleteChatPeerActionSheetItem(context: context, peer: EnginePeer(peer), chatPeer: EnginePeer(peer), action: .clearCache, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder))
                    
                    let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file]

                    var totalSize: Int64 = 0
                    
                    for categoryId in validCategories {
                        if let media = categories[categoryId] {
                            var categorySize: Int64 = 0
                            for (_, size) in media {
                                categorySize += size
                            }
                            sizeIndex[categoryId] = (true, categorySize)
                            totalSize += categorySize
                            if categorySize > 1024 {
                                let index = itemIndex
                                items.append(ActionSheetCheckboxItem(title: stringForCategory(strings: presentationData.strings, category: categoryId), label: dataSizeString(categorySize, formatting: DataSizeStringFormatting(presentationData: presentationData)), value: true, action: { value in
                                    toggleCheck(categoryId, index)
                                }))
                                itemIndex += 1
                            }
                        }
                    }
                    selectedSize = totalSize
                    
                    if !items.isEmpty {
                        var cancelImpl: (() -> Void)?
                        
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_Clear("\(dataSizeString(totalSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string, action: { [weak controller] in
                            if let statsPromise = statsPromise {
                                let clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
                                var clearMediaIds = Set<MediaId>()
                                
                                var media = stats.media
                                if var categories = media[peerId] {
                                    for category in clearCategories {
                                        if let contents = categories[category] {
                                            for (mediaId, _) in contents {
                                                clearMediaIds.insert(mediaId)
                                            }
                                        }
                                        categories.removeValue(forKey: category)
                                    }
                                    
                                    media[peerId] = categories
                                }
                                if let additionalPeerId = additionalPeerId {
                                    if var categories = media[additionalPeerId] {
                                        for category in clearCategories {
                                            if let contents = categories[category] {
                                                for (mediaId, _) in contents {
                                                    clearMediaIds.insert(mediaId)
                                                }
                                            }
                                            categories.removeValue(forKey: category)
                                        }
                                        
                                        media[additionalPeerId] = categories
                                    }
                                }
                                
                                var clearResourceIds = Set<MediaResourceId>()
                                for id in clearMediaIds {
                                    if let ids = stats.mediaResourceIds[id] {
                                        for resourceId in ids {
                                            clearResourceIds.insert(resourceId)
                                        }
                                    }
                                }
                                
                                let signal = context.engine.resources.clearCachedMediaResources(mediaResourceIds: clearResourceIds)
                                
                                let progressPromise = ValuePromise<Float>(0.0)
                                let overlayNode = StorageUsageClearProgressOverlayNode(presentationData: presentationData)
                                overlayNode.setProgressSignal(progressPromise.get())
                                controller?.setItemGroupOverlayNode(groupIndex: 0, node: overlayNode)
                                
                                let resultStats = CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers, otherSize: stats.otherSize, otherPaths: stats.otherPaths, cacheSize: stats.cacheSize, tempPaths: stats.tempPaths, tempSize: stats.tempSize, immutableSize: stats.immutableSize)
                                
                                cancelImpl = {
                                    clearDisposable.set(nil)
                                    resetStats()
                                }
                                clearDisposable.set((signal
                                |> deliverOnMainQueue).start(next: { progress in
                                    progressPromise.set(progress)
                                }, completed: {
                                    statsPromise.set(.single(.result(resultStats)))
                                    progressPromise.set(1.0)
                                    Queue.mainQueue().after(1.0) {
                                        dismissAction()
                                        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(selectedSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))", stringForDeviceType()).string), elevatedLayout: false, action: { _ in return false }), .current, nil)
                                    }
                                }))
                            }
                        }))
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: {
                                cancelImpl?()
                                dismissAction()
                            })])
                        ])
                        presentControllerImpl?(controller, .window(.root), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }
                }
            }
        })
    }, clearPeerMedia: { peerId in
        let _ = (statsPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak statsPromise] result in
            if let result = result, case let .result(stats) = result {
                var additionalPeerId: PeerId?
                if var categories = stats.media[peerId], let peer = stats.peers[peerId] {
                    if let channel = peer as? TelegramChannel, case .group = channel.info {
                        for (_, peer) in stats.peers {
                            if let group = peer as? TelegramGroup, let migrationReference = group.migrationReference, migrationReference.peerId == peerId {
                                if let additionalCategories = stats.media[group.id] {
                                    additionalPeerId = group.id
                                    categories.merge(additionalCategories, uniquingKeysWith: { lhs, rhs in
                                        return lhs.merging(rhs, uniquingKeysWith: { lhs, rhs in
                                            return lhs + rhs
                                        })
                                    })
                                }
                            }
                        }
                    }
                    
                    var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
                    let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file]

                    var totalSize: Int64 = 0
                    
                    for categoryId in validCategories {
                        if let media = categories[categoryId] {
                            var categorySize: Int64 = 0
                            for (_, size) in media {
                                categorySize += size
                            }
                            sizeIndex[categoryId] = (true, categorySize)
                            totalSize += categorySize
                        }
                    }
                    
                    if let statsPromise = statsPromise {
                        let clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
                        var clearMediaIds = Set<MediaId>()
                        
                        var media = stats.media
                        if var categories = media[peerId] {
                            for category in clearCategories {
                                if let contents = categories[category] {
                                    for (mediaId, _) in contents {
                                        clearMediaIds.insert(mediaId)
                                    }
                                }
                                categories.removeValue(forKey: category)
                            }
                            
                            media[peerId] = categories
                        }
                        if let additionalPeerId = additionalPeerId {
                            if var categories = media[additionalPeerId] {
                                for category in clearCategories {
                                    if let contents = categories[category] {
                                        for (mediaId, _) in contents {
                                            clearMediaIds.insert(mediaId)
                                        }
                                    }
                                    categories.removeValue(forKey: category)
                                }
                                
                                media[additionalPeerId] = categories
                            }
                        }
                        
                        var clearResourceIds = Set<MediaResourceId>()
                        for id in clearMediaIds {
                            if let ids = stats.mediaResourceIds[id] {
                                for resourceId in ids {
                                    clearResourceIds.insert(resourceId)
                                }
                            }
                        }
                        
                        var signal = context.engine.resources.clearCachedMediaResources(mediaResourceIds: clearResourceIds)
                        
                        let resultStats = CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers, otherSize: stats.otherSize, otherPaths: stats.otherPaths, cacheSize: stats.cacheSize, tempPaths: stats.tempPaths, tempSize: stats.tempSize, immutableSize: stats.immutableSize)
                        
                        var cancelImpl: (() -> Void)?
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                cancelImpl?()
                            }))
                            presentControllerImpl?(controller, .window(.root), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        signal = signal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        cancelImpl = {
                            clearDisposable.set(nil)
                            resetStats()
                        }
                        clearDisposable.set((signal
                        |> deliverOnMainQueue).start(completed: {
                            statsPromise.set(.single(.result(resultStats)))
                            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(totalSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))", stringForDeviceType()).string), elevatedLayout: false, action: { _ in return false }), .current, nil)
                        }))
                    }
                }
            }
        })
        
        updateState { state in
            return state.withUpdatedPeerIdWithRevealedOptions(nil)
        }
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    })
    
    var dismissImpl: (() -> Void)?
    
    let signal = combineLatest(context.sharedContext.presentationData, cacheSettingsPromise.get(), statsPromise.get(), statePromise.get()) |> deliverOnMainQueue
        |> map { presentationData, cacheSettings, cacheStats, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let leftNavigationButton = isModal ? ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            }) : nil
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Cache_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: storageUsageControllerEntries(presentationData: presentationData, cacheSettings: cacheSettings, cacheStats: cacheStats, state: state), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionDisposables.dispose()
        }
    
    let controller = ItemListController(context: context, state: signal)
    if isModal {
        controller.navigationPresentation = .modal
        controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    presentControllerImpl = { [weak controller] c, contextType, a in
        controller?.present(c, in: contextType, with: a)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}

private class StorageUsageClearProgressOverlayNode: ASDisplayNode, ActionSheetGroupOverlayNode {
    private let presentationData: PresentationData
    
    private let animationNode: AnimatedStickerNode
    private let progressTextNode: ImmediateTextNode
    private let descriptionTextNode: ImmediateTextNode
    private let progressBackgroundNode: ASDisplayNode
    private let progressForegroundNode: ASDisplayNode
    
    private let progressDisposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ClearCache"), width: 256, height: 256, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.progressTextNode = ImmediateTextNode()
        self.progressTextNode.textAlignment = .center
        
        self.descriptionTextNode = ImmediateTextNode()
        self.descriptionTextNode.textAlignment = .center
        self.descriptionTextNode.maximumNumberOfLines = 0
        
        self.progressBackgroundNode = ASDisplayNode()
        self.progressBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.controlAccentColor.withMultipliedAlpha(0.2)
        self.progressBackgroundNode.cornerRadius = 3.0
        
        self.progressForegroundNode = ASDisplayNode()
        self.progressForegroundNode.backgroundColor = self.presentationData.theme.actionSheet.controlAccentColor
        self.progressForegroundNode.cornerRadius = 3.0
        
        super.init()
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.progressTextNode)
        self.addSubnode(self.descriptionTextNode)
        self.addSubnode(self.progressBackgroundNode)
        self.addSubnode(self.progressForegroundNode)
    }
    
    deinit {
        self.progressDisposable.dispose()
    }
    
    func setProgressSignal(_ signal: Signal<Float, NoError>) {
        self.progressDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] progress in
            if let strongSelf = self {
                strongSelf.setProgress(progress)
            }
        }))
    }
    
    private var progress: Float = 0.0
    private func setProgress(_ progress: Float) {
        self.progress = progress
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.5, curve: .linear))
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let inset: CGFloat = 24.0
        let progressHeight: CGFloat = 6.0
        let spacing: CGFloat = 16.0
        
        let progressFrame = CGRect(x: inset, y: size.height - inset - progressHeight, width: size.width - inset * 2.0, height: progressHeight)
        self.progressBackgroundNode.frame = progressFrame
        let progressForegroundFrame = CGRect(x: inset, y: size.height - inset - progressHeight, width: floorToScreenPixels(progressFrame.width * CGFloat(self.progress)), height: progressHeight)
        if !self.progressForegroundNode.frame.origin.x.isZero {
            transition.updateFrame(node: self.progressForegroundNode, frame: progressForegroundFrame, beginWithCurrentState: true)
        } else {
            self.progressForegroundNode.frame = progressForegroundFrame
        }
        
        self.descriptionTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.ClearCache_KeepOpenedDescription, font: Font.regular(15.0), textColor: self.presentationData.theme.actionSheet.secondaryTextColor)
        let descriptionTextSize = self.descriptionTextNode.updateLayout(CGSize(width: size.width - inset * 3.0, height: size.height))
        var descriptionTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - descriptionTextSize.width) / 2.0), y: progressFrame.minY - spacing - 9.0 - descriptionTextSize.height), size: descriptionTextSize)
       
        self.progressTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.ClearCache_Progress(Int(progress * 100.0)).string, font: Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers]), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
        let progressTextSize = self.progressTextNode.updateLayout(size)
        var progressTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - progressTextSize.width) / 2.0), y: descriptionTextFrame.minY - spacing - progressTextSize.height), size: progressTextSize)
        
        let availableHeight = progressTextFrame.minY
        if availableHeight < 100.0 {
            let offset = availableHeight / 2.0 - spacing
            descriptionTextFrame = descriptionTextFrame.offsetBy(dx: 0.0, dy: -offset)
            progressTextFrame = progressTextFrame.offsetBy(dx: 0.0, dy: -offset)
            self.animationNode.alpha = 0.0
        } else {
            self.animationNode.alpha = 1.0
        }
        
        self.progressTextNode.frame = progressTextFrame
        self.descriptionTextNode.frame = descriptionTextFrame
        
        let imageSide = min(160.0, availableHeight - 30.0)
        let imageSize = CGSize(width: imageSide, height: imageSide)
        
        let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floorToScreenPixels((progressTextFrame.minY - imageSize.height) / 2.0)), size: imageSize)
        self.animationNode.frame = animationFrame
        self.animationNode.updateLayout(size: imageSize)
    }
}
