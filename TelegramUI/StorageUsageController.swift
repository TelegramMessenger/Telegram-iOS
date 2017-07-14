import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class StorageUsageControllerArguments {
    let account: Account
    let updateKeepMedia: () -> Void
    let openPeerMedia: (PeerId) -> Void
    
    init(account: Account, updateKeepMedia: @escaping () -> Void, openPeerMedia: @escaping (PeerId) -> Void) {
        self.account = account
        self.updateKeepMedia = updateKeepMedia
        self.openPeerMedia = openPeerMedia
    }
}

private enum StorageUsageSection: Int32 {
    case keepMedia
    case peers
}

private enum StorageUsageEntry: ItemListNodeEntry {
    case keepMedia(PresentationTheme, String, String)
    case keepMediaInfo(PresentationTheme, String)
    
    case collecting(PresentationTheme, String)
    case peersHeader(PresentationTheme, String)
    case peer(Int32, PresentationTheme, PresentationStrings, Peer, String)
    
    var section: ItemListSectionId {
        switch self {
            case .keepMedia, .keepMediaInfo:
                return StorageUsageSection.keepMedia.rawValue
            case .collecting, .peersHeader, .peer:
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
            case .peersHeader:
                return 3
            case let .peer(index, _, _, _, _):
                return 4 + index
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
            case let .peersHeader(lhsTheme, lhsText):
                if case let .peersHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsTheme, lhsStrings, lhsPeer, lhsValue):
                if case let .peer(rhsIndex, rhsTheme, rhsStrings, rhsPeer, rhsValue) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if !arePeersEqual(lhsPeer, rhsPeer) {
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
                return ItemListActivityTextItem(displayActivity: true, text: NSAttributedString(string: text, textColor: theme.list.freeTextColor), sectionId: self.section)
            case let .peersHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .peer(_, theme, strings, peer, value):
                return ItemListPeerItem(theme: theme, strings: strings, account: arguments.account, peer: peer, presence: nil, text: .none, label: .disclosure(value), editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, sectionId: self.section, action: {
                    arguments.openPeerMedia(peer.id)
                }, setPeerIdWithRevealedOptions: { previousId, id in
                    
                }, removePeer: { _ in
                    
                })
        }
    }
}

private func stringForKeepMediaTimeout(_ timeout: Int32) -> String {
    if timeout <= 7 * 24 * 60 * 60 {
        return "1 week"
    } else if timeout <= 1 * 31 * 24 * 60 * 60 {
        return "1 month"
    } else {
        return "Forever"
    }
}

private func storageUsageControllerEntries(presentationData: PresentationData, cacheSettings: CacheStorageSettings, cacheStats: CacheUsageStatsResult?) -> [StorageUsageEntry] {
    var entries: [StorageUsageEntry] = []
    
    entries.append(.keepMedia(presentationData.theme, "Keep Media", stringForKeepMediaTimeout(cacheSettings.defaultCacheStorageTimeout)))
    entries.append(.keepMediaInfo(presentationData.theme, "Photos, videos and other files from cloud chats that you have **not accessed** during this period will be removed from this device to save disk space.\n\nAll media will stay in the Telegram cloud and can be re-downloaded if you need it again."))
    
    var addedHeader = false
    
    if let cacheStats = cacheStats, case let .result(stats) = cacheStats {
        var statsByPeerId: [(PeerId, Int64)] = []
        for (peerId, categories) in stats.media {
            var combinedSize: Int64 = 0
            for (_, media) in categories {
                for (_, size) in media {
                    combinedSize += size
                }
            }
            statsByPeerId.append((peerId, combinedSize))
        }
        var index: Int32 = 0
        for (peerId, size) in statsByPeerId.sorted(by: { $0.1 > $1.1 }) {
            if size >= 32 * 1024 {
                if let peer = stats.peers[peerId] {
                    if !addedHeader {
                        addedHeader = true
                        entries.append(.peersHeader(presentationData.theme, "CHATS"))
                    }
                    entries.append(.peer(index, presentationData.theme, presentationData.strings, peer, dataSizeString(Int(size))))
                    index += 1
                }
            }
        }
    } else {
        entries.append(.collecting(presentationData.theme, "Calculating current cache size..."))
    }
    
    return entries
}

private func stringForCategory(_ category: PeerCacheUsageCategory) -> String {
    switch category {
        case .image:
            return "Photos"
        case .video:
            return "Videos"
        case .audio:
            return "Audio"
        case .file:
            return "Documents"
    }
}

func storageUsageController(account: Account) -> ViewController {
    let cacheSettingsPromise = Promise<CacheStorageSettings>()
    cacheSettingsPromise.set(account.postbox.preferencesView(keys: [PreferencesKeys.cacheStorageSettings])
        |> map { view -> CacheStorageSettings in
            let cacheSettings: CacheStorageSettings
            if let value = view.values[PreferencesKeys.cacheStorageSettings] as? CacheStorageSettings {
                cacheSettings = value
            } else {
                cacheSettings = CacheStorageSettings.defaultSettings
            }
            
            return cacheSettings
        })
    
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let statsPromise = Promise<CacheUsageStatsResult?>()
    statsPromise.set(.single(nil) |> then(collectCacheUsageStats(account: account) |> map { Optional($0) }))
    
    let actionDisposables = DisposableSet()
    
    let clearDisposable = MetaDisposable()
    actionDisposables.add(clearDisposable)
    
    let arguments = StorageUsageControllerArguments(account: account, updateKeepMedia: {
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let timeoutAction: (Int32) -> Void = { timeout in
            let _ = updateCacheStorageSettingsInteractively(postbox: account.postbox, { current in
                return current.withUpdatedDefaultCacheStorageTimeout(timeout)
            }).start()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "1 week", action: {
                    dismissAction()
                    timeoutAction(7 * 24 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "1 month", action: {
                    dismissAction()
                    timeoutAction(1 * 31 * 24 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "Forever", action: {
                    dismissAction()
                    timeoutAction(Int32.max)
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
        ])
        presentControllerImpl?(controller)
    }, openPeerMedia: { peerId in
        let _ = (statsPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak statsPromise] result in
            if let result = result, case let .result(stats) = result {
                if let categories = stats.media[peerId] {
                    let controller = ActionSheetController()
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
                                title = "Clear"
                            } else {
                                title = "Clear (\(dataSizeString(Int(filteredSize))))"
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
                            let index = itemIndex
                            items.append(ActionSheetCheckboxItem(title: stringForCategory(categoryId), label: dataSizeString(Int(categorySize)), value: true, action: { value in
                                toggleCheck(categoryId, index)
                            }))
                            itemIndex += 1
                        }
                    }
                    
                    if !items.isEmpty {
                        items.append(ActionSheetButtonItem(title: "Clear (\(dataSizeString(Int(totalSize))))", action: {
                            if let statsPromise = statsPromise {
                                var clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
                                //var clearSize: Int64 = 0
                                
                                var clearMediaIds = Set<MediaId>()
                                
                                var media = stats.media
                                if var categories = media[peerId] {
                                    for category in clearCategories {
                                        if let contents = categories[category] {
                                            for (mediaId, size) in contents {
                                                clearMediaIds.insert(mediaId)
                                                //clearSize += size
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
                                
                                statsPromise.set(.single(.result(CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers))))
                                
                                clearDisposable.set(clearCachedMediaResources(account: account, mediaResourceIds: clearResourceIds).start())
                            }
                            
                            dismissAction()
                        }))
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
                        ])
                        presentControllerImpl?(controller)
                    }
                }
            }
        })
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, cacheSettingsPromise.get(), statsPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, cacheSettings, cacheStats -> (ItemListControllerState, (ItemListNodeState<StorageUsageEntry>, StorageUsageEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Storage Usage"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: "Back"), animateChanges: false)
            let listState = ItemListNodeState(entries: storageUsageControllerEntries(presentationData: presentationData, cacheSettings: cacheSettings, cacheStats: cacheStats), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionDisposables.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    return controller
}
