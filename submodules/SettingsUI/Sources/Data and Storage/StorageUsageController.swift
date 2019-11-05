import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import OverlayStatusController
import AccountContext
import ItemListPeerItem

private final class StorageUsageControllerArguments {
    let account: Account
    let updateKeepMedia: () -> Void
    let openClearAll: () -> Void
    let openPeerMedia: (PeerId) -> Void
    
    init(account: Account, updateKeepMedia: @escaping () -> Void, openClearAll: @escaping () -> Void, openPeerMedia: @escaping (PeerId) -> Void) {
        self.account = account
        self.updateKeepMedia = updateKeepMedia
        self.openClearAll = openClearAll
        self.openPeerMedia = openPeerMedia
    }
}

private enum StorageUsageSection: Int32 {
    case keepMedia
    case immutableSize
    case all
    case peers
}

private enum StorageUsageEntry: ItemListNodeEntry {
    case keepMedia(PresentationTheme, String, String)
    case keepMediaInfo(PresentationTheme, String)
    
    case collecting(PresentationTheme, String)
    
    case immutableSize(PresentationTheme, String, String)
    
    case clearAll(PresentationTheme, String, String, Bool)
    
    case peersHeader(PresentationTheme, String)
    case peer(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Peer, Peer?, String)
    
    var section: ItemListSectionId {
        switch self {
            case .keepMedia, .keepMediaInfo:
                return StorageUsageSection.keepMedia.rawValue
            case .immutableSize:
                return StorageUsageSection.immutableSize.rawValue
            case .collecting, .clearAll:
                return StorageUsageSection.all.rawValue
            case .peersHeader, .peer:
                return StorageUsageSection.peers.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .keepMedia:
                return 0
            case .keepMediaInfo:
                return 1
            case .collecting:
                return 2
            case .immutableSize:
                return 3
            case .clearAll:
                return 4
            case .peersHeader:
                return 5
            case let .peer(index, _, _, _, _, _, _, _):
                return 6 + index
        }
    }
    
    static func ==(lhs: StorageUsageEntry, rhs: StorageUsageEntry) -> Bool {
        switch lhs {
            case let .keepMedia(lhsTheme, lhsText, lhsValue):
                if case let .keepMedia(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .collecting(lhsTheme, lhsText):
                if case let .collecting(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .immutableSize(lhsTheme, lhsText, lhsValue):
                if case let .immutableSize(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .clearAll(lhsTheme, lhsText, lhsValue, lhsEnabled):
                if case let .clearAll(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
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
        case let .peer(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsPeer, lhsChatPeer, lhsValue):
                if case let .peer(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsPeer, rhsChatPeer, rhsValue) = rhs {
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
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: StorageUsageEntry, rhs: StorageUsageEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: StorageUsageControllerArguments) -> ListViewItem {
        switch self {
            case let .keepMedia(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.updateKeepMedia()
                })
            case let .keepMediaInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
            case let .collecting(theme, text):
                return CalculatingCacheSizeItem(theme: theme, title: text, sectionId: self.section, style: .blocks)
            case let .immutableSize(theme, title, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: title, enabled: false, titleColor: .primary, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .peersHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .clearAll(theme, text, value, enabled):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: text, enabled: enabled, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openClearAll()
                })
            case let .peer(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer, chatPeer, value):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.account, peer: peer, aliasHandling: .threatSelfAsSaved, nameColor: chatPeer == nil ? .primary : .secret, presence: nil, text: .none, label: .disclosure(value), editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    let resolvedPeer = chatPeer ?? peer
                    arguments.openPeerMedia(resolvedPeer.id)
                }, setPeerIdWithRevealedOptions: { previousId, id in
                    
                }, removePeer: { _ in
                    
                })
        }
    }
}

private func stringForKeepMediaTimeout(strings: PresentationStrings, timeout: Int32) -> String {
    if timeout > 1 * 31 * 24 * 60 * 60 {
        return strings.MessageTimer_Forever
    } else {
        return timeIntervalString(strings: strings, value: timeout)
    }
}

private func storageUsageControllerEntries(presentationData: PresentationData, cacheSettings: CacheStorageSettings, cacheStats: CacheUsageStatsResult?) -> [StorageUsageEntry] {
    var entries: [StorageUsageEntry] = []
    
    entries.append(.keepMedia(presentationData.theme, presentationData.strings.Cache_KeepMedia, stringForKeepMediaTimeout(strings: presentationData.strings, timeout: cacheSettings.defaultCacheStorageTimeout)))
    entries.append(.keepMediaInfo(presentationData.theme, presentationData.strings.Cache_Help))
    
    var addedHeader = false
    
    if let cacheStats = cacheStats, case let .result(stats) = cacheStats {
        entries.append(.immutableSize(presentationData.theme, presentationData.strings.Cache_ServiceFiles, dataSizeString(stats.immutableSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
        
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
        
        let totalSize = Int64(peerSizes + stats.otherSize + stats.cacheSize + stats.tempSize)
        
        entries.append(.clearAll(presentationData.theme, presentationData.strings.Cache_ClearCache, totalSize > 0 ? dataSizeString(totalSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) : presentationData.strings.Cache_ClearEmpty, totalSize > 0))
        
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
                    entries.append(.peer(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, mainPeer, chatPeer, dataSizeString(size, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
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

public func storageUsageController(context: AccountContext, isModal: Bool = false) -> ViewController {
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
    
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let statsPromise = Promise<CacheUsageStatsResult?>()
    let resetStats: () -> Void = {
        let containerPath = context.sharedContext.applicationBindings.containerPath
        let additionalPaths: [String] = [
            NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0],
            containerPath + "/Documents/files",
            containerPath + "/Documents/video",
            containerPath + "/Documents/audio",
            containerPath + "/Documents/mediacache",
            containerPath + "/Documents/tempcache_v1/store",
        ]
        statsPromise.set(.single(nil)
        |> then(collectCacheUsageStats(account: context.account, additionalCachePaths: additionalPaths, logFilesPath: context.sharedContext.applicationBindings.containerPath + "/telegram-data/logs")
        |> map(Optional.init)))
    }
    resetStats()
    
    let actionDisposables = DisposableSet()
    
    let clearDisposable = MetaDisposable()
    actionDisposables.add(clearDisposable)
    
    let arguments = StorageUsageControllerArguments(account: context.account, updateKeepMedia: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let timeoutAction: (Int32) -> Void = { timeout in
            let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current.withUpdatedDefaultCacheStorageTimeout(timeout)
            }).start()
        }
        var values: [Int32] = [
            3 * 24 * 60 * 60,
            7 * 24 * 60 * 60,
            1 * 31 * 24 * 60 * 60,
            Int32.max
        ]
        #if DEBUG
        values.insert(60 * 60, at: 0)
        #endif
        let timeoutItems: [ActionSheetItem] = values.map { value in
            return ActionSheetButtonItem(title: stringForKeepMediaTimeout(strings: presentationData.strings, timeout: value), action: {
                dismissAction()
                timeoutAction(value)
            })
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: timeoutItems),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller)
    }, openClearAll: {
        let _ = (statsPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak statsPromise] result in
            if let result = result, case let .result(stats) = result {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let controller = ActionSheetController(presentationTheme: presentationData.theme)
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
                
                let updateTotalSize: () -> Void = { [weak controller] in
                    controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                        let title: String
                        var filteredSize = sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
                        
                        if otherSize.0 {
                            filteredSize += otherSize.1
                        }
                        
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
                                let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings,  type: .loading(cancelled: {
                                    cancelImpl?()
                                }))
                                presentControllerImpl?(controller)
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
                            }))
                        }
                        
                        dismissAction()
                    }))
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                    presentControllerImpl?(controller)
                }
            }
        })
    }, openPeerMedia: { peerId in
        let _ = (statsPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak statsPromise] result in
            if let result = result, case let .result(stats) = result {
                var additionalPeerId: PeerId?
                if var categories = stats.media[peerId] {
                    if let channel = stats.peers[peerId] as? TelegramChannel, case .group = channel.info {
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
                    let controller = ActionSheetController(presentationTheme: presentationData.theme)
                    let dismissAction: () -> Void = { [weak controller] in
                        controller?.dismissAnimated()
                    }
                    
                    var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
                    
                    var itemIndex = 0
                    
                    let updateTotalSize: () -> Void = { [weak controller] in
                        controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                            let title: String
                            let filteredSize = sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
                            
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
                                    let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings,  type: .loading(cancelled: {
                                        cancelImpl?()
                                    }))
                                    presentControllerImpl?(controller)
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
                                }))
                            }
                            
                            dismissAction()
                        }))
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                        presentControllerImpl?(controller)
                    }
                }
            }
        })
    })
    
    var dismissImpl: (() -> Void)?
    
    let signal = combineLatest(context.sharedContext.presentationData, cacheSettingsPromise.get(), statsPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, cacheSettings, cacheStats -> (ItemListControllerState, (ItemListNodeState<StorageUsageEntry>, StorageUsageEntry.ItemGenerationArguments)) in
            let leftNavigationButton = isModal ? ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            }) : nil
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Cache_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: storageUsageControllerEntries(presentationData: presentationData, cacheSettings: cacheSettings, cacheStats: cacheStats), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionDisposables.dispose()
        }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}
