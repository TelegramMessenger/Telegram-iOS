import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
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
    let openClearAll: () -> Void
    let openPeerMedia: (PeerId) -> Void
    let clearPeerMedia: (PeerId) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    
    init(context: AccountContext, updateKeepMediaTimeout: @escaping (Int32) -> Void, openClearAll: @escaping () -> Void, openPeerMedia: @escaping (PeerId) -> Void, clearPeerMedia: @escaping (PeerId) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void) {
        self.context = context
        self.updateKeepMediaTimeout = updateKeepMediaTimeout
        self.openClearAll = openClearAll
        self.openPeerMedia = openPeerMedia
        self.clearPeerMedia = clearPeerMedia
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
    }
}

private enum StorageUsageSection: Int32 {
    case keepMedia
    case storage
    case peers
}

private enum StorageUsageEntry: ItemListNodeEntry {
    case keepMediaHeader(PresentationTheme, String)
    case keepMedia(PresentationTheme, PresentationStrings, Int32)
    case keepMediaInfo(PresentationTheme, String)
    
    case storageHeader(PresentationTheme, String)
    case storageUsage(PresentationTheme, PresentationDateTimeFormat, [StorageUsageCategory])
    case collecting(PresentationTheme, String)
    case clearAll(PresentationTheme, String, Bool)
    
    case peersHeader(PresentationTheme, String)
    case peer(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Peer, Peer?, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .keepMediaHeader, .keepMedia, .keepMediaInfo:
                return StorageUsageSection.keepMedia.rawValue
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
            case .storageHeader:
                return 3
            case .storageUsage:
                return 4
            case .collecting:
                return 5
            case .clearAll:
                return 6
            case .peersHeader:
                return 7
            case let .peer(index, _, _, _, _, _, _, _, _):
                return 8 + index
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
            case let .storageHeader(lhsTheme, lhsText):
                if case let .storageHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .storageUsage(lhsTheme, lhsDateTimeFormat, lhsCategories):
                if case let .storageUsage(rhsTheme, rhsDateTimeFormat, rhsCategories) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsCategories == rhsCategories {
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
            case let .keepMediaHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .keepMedia(theme, strings, value):
                return KeepMediaDurationPickerItem(theme: theme, strings: strings, value: value, sectionId: self.section, updated: { updatedValue in
                        arguments.updateKeepMediaTimeout(updatedValue)
                    })
            case let .keepMediaInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .storageHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .storageUsage(theme, dateTimeFormat, categories):
                return StorageUsageItem(theme: theme, dateTimeFormat: dateTimeFormat, categories: categories, sectionId: self.section)
            case let .collecting(theme, text):
                return CalculatingCacheSizeItem(theme: theme, title: text, sectionId: self.section, style: .blocks)
            case let .clearAll(theme, text, enabled):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if enabled {
                        arguments.openClearAll()
                    }
                })
            case let .peersHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .peer(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer, chatPeer, value, revealed):
                var options: [ItemListPeerItemRevealOption] = [ItemListPeerItemRevealOption(type: .destructive, title: strings.ClearCache_Clear, action: {
                    arguments.clearPeerMedia(peer.id)
                })]
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer, aliasHandling: .threatSelfAsSaved, nameColor: chatPeer == nil ? .primary : .secret, presence: nil, text: .none, label: .disclosure(value), editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealed), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    let resolvedPeer = chatPeer ?? peer
                    arguments.openPeerMedia(resolvedPeer.id)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { _ in
                })
        }
    }
}

private struct StoragUsageState: Equatable {
    let peerIdWithRevealedOptions: PeerId?

    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> StoragUsageState {
        return StoragUsageState(peerIdWithRevealedOptions: peerIdWithRevealedOptions)
    }
}

private func storageUsageControllerEntries(presentationData: PresentationData, cacheSettings: CacheStorageSettings, cacheStats: CacheUsageStatsResult?, state: StoragUsageState) -> [StorageUsageEntry] {
    var entries: [StorageUsageEntry] = []
    
    entries.append(.keepMediaHeader(presentationData.theme, presentationData.strings.Cache_KeepMedia.uppercased()))
    entries.append(.keepMedia(presentationData.theme, presentationData.strings, cacheSettings.defaultCacheStorageTimeout))
    entries.append(.keepMediaInfo(presentationData.theme, presentationData.strings.Cache_Help))
    
    var addedHeader = false
    
    entries.append(.storageHeader(presentationData.theme, presentationData.strings.ClearCache_StorageTitle(stringForDeviceType().uppercased()).0))
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
        
        entries.append(.storageUsage(presentationData.theme, presentationData.dateTimeFormat, categories))
        
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
                    entries.append(.peer(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, mainPeer, chatPeer, dataSizeString(size, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), state.peerIdWithRevealedOptions == peer.id))
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
    |> then(collectCacheUsageStats(account: context.account, additionalCachePaths: additionalPaths, logFilesPath: context.sharedContext.applicationBindings.containerPath + "/telegram-data/logs")
    |> map(Optional.init))
}

public func storageUsageController(context: AccountContext, cacheUsagePromise: Promise<CacheUsageStatsResult?>? = nil, isModal: Bool = false) -> ViewController {
    let statePromise = ValuePromise(StoragUsageState(peerIdWithRevealedOptions: nil))
    let stateValue = Atomic(value: StoragUsageState(peerIdWithRevealedOptions: nil))
    let updateState: ((StoragUsageState) -> StoragUsageState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let cacheSettingsPromise = Promise<CacheStorageSettings>()
    cacheSettingsPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
    |> map { sharedData -> CacheStorageSettings in
        let cacheSettings: CacheStorageSettings
        if let value = sharedData.entries[SharedDataKeys.cacheStorageSettings] as? CacheStorageSettings {
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
                            title = presentationData.strings.Cache_Clear("\(dataSizeString(filteredSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))").0
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
                    controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
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
                
                for categoryId in validCategories {
                    if let (_, size) = sizeIndex[categoryId] {
                        let categorySize: Int64 = size
                        totalSize += categorySize
                        let index = itemIndex
                        items.append(ActionSheetCheckboxItem(title: stringForCategory(strings: presentationData.strings, category: categoryId), label: dataSizeString(categorySize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), value: true, action: { value in
                            toggleCheck(categoryId, index)
                        }))
                        itemIndex += 1
                    }
                }
                
                if otherSize.1 != 0 {
                    totalSize += otherSize.1
                    let index = itemIndex
                    items.append(ActionSheetCheckboxItem(title: presentationData.strings.Localization_LanguageOther, label: dataSizeString(otherSize.1, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), value: true, action: { value in
                        toggleCheck(nil, index)
                    }))
                    itemIndex += 1
                }
                selectedSize = totalSize
                
                if !items.isEmpty {
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_Clear("\(dataSizeString(totalSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))").0, action: {
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
                            
                            var clearResourceIds = Set<WrappedMediaResourceId>()
                            for id in clearMediaIds {
                                if let ids = stats.mediaResourceIds[id] {
                                    for resourceId in ids {
                                        clearResourceIds.insert(WrappedMediaResourceId(resourceId))
                                    }
                                }
                            }
                            
                            var updatedOtherPaths = stats.otherPaths
                            var updatedOtherSize = stats.otherSize
                            var updatedCacheSize = stats.cacheSize
                            var updatedTempPaths = stats.tempPaths
                            var updatedTempSize = stats.tempSize
                            
                            var signal: Signal<Void, NoError> = clearCachedMediaResources(account: context.account, mediaResourceIds: clearResourceIds)
                            if otherSize.0 {
                                let removeTempFiles: Signal<Void, NoError> = Signal { subscriber in
                                    let fileManager = FileManager.default
                                    for path in stats.tempPaths {
                                        let _ = try? fileManager.removeItem(atPath: path)
                                    }
                                    
                                    subscriber.putCompletion()
                                    return EmptyDisposable
                                } |> runOn(Queue.concurrentDefaultQueue())
                                signal = signal
                                |> then(context.account.postbox.mediaBox.removeOtherCachedResources(paths: stats.otherPaths))
                                |> then(removeTempFiles)
                            }
                            
                            if otherSize.0 {
                                updatedOtherPaths = []
                                updatedOtherSize = 0
                                updatedCacheSize = 0
                                updatedTempPaths = []
                                updatedTempSize = 0
                            }
                            
                            let resultStats = CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers, otherSize: updatedOtherSize, otherPaths: updatedOtherPaths, cacheSize: updatedCacheSize, tempPaths: updatedTempPaths, tempSize: updatedTempSize, immutableSize: stats.immutableSize)
                            
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
                                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(selectedSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))", stringForDeviceType()).0), elevatedLayout: false, action: { _ in return false }), .current, nil)
                            }))
                        }
                        
                        dismissAction()
                    }))
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
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
                                title = presentationData.strings.Cache_Clear("\(dataSizeString(filteredSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))").0
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
                    
                    items.append(DeleteChatPeerActionSheetItem(context: context, peer: peer, chatPeer: peer, action: .clearCache, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder))
                    
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
                                items.append(ActionSheetCheckboxItem(title: stringForCategory(strings: presentationData.strings, category: categoryId), label: dataSizeString(categorySize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), value: true, action: { value in
                                    toggleCheck(categoryId, index)
                                }))
                                itemIndex += 1
                            }
                        }
                    }
                    selectedSize = totalSize
                    
                    if !items.isEmpty {
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_Clear("\(dataSizeString(totalSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))").0, action: {
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
                                
                                var clearResourceIds = Set<WrappedMediaResourceId>()
                                for id in clearMediaIds {
                                    if let ids = stats.mediaResourceIds[id] {
                                        for resourceId in ids {
                                            clearResourceIds.insert(WrappedMediaResourceId(resourceId))
                                        }
                                    }
                                }
                                
                                var signal = clearCachedMediaResources(account: context.account, mediaResourceIds: clearResourceIds)
                                
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
                                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(selectedSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))", stringForDeviceType()).0), elevatedLayout: false, action: { _ in return false }), .current, nil)
                                }))
                            }
                            
                            dismissAction()
                        }))
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
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
                        
                        var clearResourceIds = Set<WrappedMediaResourceId>()
                        for id in clearMediaIds {
                            if let ids = stats.mediaResourceIds[id] {
                                for resourceId in ids {
                                    clearResourceIds.insert(WrappedMediaResourceId(resourceId))
                                }
                            }
                        }
                        
                        var signal = clearCachedMediaResources(account: context.account, mediaResourceIds: clearResourceIds)
                        
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
                            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(totalSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))", stringForDeviceType()).0), elevatedLayout: false, action: { _ in return false }), .current, nil)
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
