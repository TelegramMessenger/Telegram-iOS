import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerActionItem
import ItemListAvatarAndNameInfoItem
import ItemListPeerItem

private enum MediaType {
    case photo
    case video
}

private final class SaveIncomingMediaControllerArguments {
    let context: AccountContext
    let toggle: (MediaType) -> Void
    let updateMaximumVideoSize: (Int64) -> Void
    let openAddException: () -> Void
    let openPeerMenu: (EnginePeer) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let deletePeer: (EnginePeer.Id) -> Void
    let deleteAllExceptions: () -> Void
    
    init(context: AccountContext, toggle: @escaping (MediaType) -> Void, updateMaximumVideoSize: @escaping (Int64) -> Void, openAddException: @escaping () -> Void, openPeerMenu: @escaping (EnginePeer) -> Void, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, deletePeer: @escaping (EnginePeer.Id) -> Void, deleteAllExceptions: @escaping () -> Void) {
        self.context = context
        self.toggle = toggle
        self.updateMaximumVideoSize = updateMaximumVideoSize
        self.openAddException = openAddException
        self.openPeerMenu = openPeerMenu
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.deletePeer = deletePeer
        self.deleteAllExceptions = deleteAllExceptions
    }
}

enum SaveIncomingMediaSection: ItemListSectionId {
    case peer
    case mediaTypes
    case videoSize
    case exceptions
    case deleteAllExceptions
}

private enum SaveIncomingMediaEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case peer
        
        case typesHeader
        case typePhotos
        case typeVideos
        case typesInfo
        
        case videoSizeHeader
        case videoSize
        case videoInfo
        
        case exceptionsHeader
        case addException
        case exceptionItem(EnginePeer.Id)
        
        case deleteAllExceptions
    }
    
    case peer(peer: EnginePeer, presence: EnginePeer.Presence?)
    
    case typesHeader(String)
    case typePhotos(String, Bool)
    case typeVideos(String, Bool)
    case typesInfo(String)
    
    case videoSizeHeader(String)
    case videoSize(decimalSeparator: String, text: String, value: Int64)
    case videoInfo(String)
    
    case exceptionsHeader(String)
    case addException(String)
    case exceptionItem(index: Int, peer: EnginePeer, label: String)
    
    case deleteAllExceptions(String)
    
    var section: ItemListSectionId {
        switch self {
        case .peer:
            return SaveIncomingMediaSection.peer.rawValue
        case .typesHeader, .typePhotos, .typeVideos, .typesInfo:
            return SaveIncomingMediaSection.mediaTypes.rawValue
        case .videoSizeHeader, .videoSize, .videoInfo:
            return SaveIncomingMediaSection.videoSize.rawValue
        case .exceptionsHeader, .addException, .exceptionItem:
            return SaveIncomingMediaSection.exceptions.rawValue
        case .deleteAllExceptions:
            return SaveIncomingMediaSection.deleteAllExceptions.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .peer:
            return .peer
        case .typesHeader:
            return .typesHeader
        case .typePhotos:
            return .typePhotos
        case .typeVideos:
            return .typeVideos
        case .typesInfo:
            return .typesInfo
        case .videoSizeHeader:
            return .videoSizeHeader
        case .videoSize:
            return .videoSize
        case .videoInfo:
            return .videoInfo
        case .exceptionsHeader:
            return .exceptionsHeader
        case .addException:
            return .addException
        case let .exceptionItem(_, peer, _):
            return .exceptionItem(peer.id)
        case .deleteAllExceptions:
            return .deleteAllExceptions
        }
    }
    
    var sortIndex: Int {
        switch self {
        case .peer:
            return 0
        case .typesHeader:
            return 1
        case .typePhotos:
            return 2
        case .typeVideos:
            return 3
        case .typesInfo:
            return 4
        case .videoSizeHeader:
            return 5
        case .videoSize:
            return 6
        case .videoInfo:
            return 7
        case .exceptionsHeader:
            return 8
        case .addException:
            return 9
        case let .exceptionItem(index, _, _):
            return 100 + index
        case .deleteAllExceptions:
            return 100000
        }
    }
    
    static func <(lhs: SaveIncomingMediaEntry, rhs: SaveIncomingMediaEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SaveIncomingMediaControllerArguments
        switch self {
        case let .peer(peer, presence):
            return ItemListAvatarAndNameInfoItem(
                accountContext: arguments.context,
                presentationData: presentationData,
                dateTimeFormat: PresentationDateTimeFormat(),
                mode: .generic,
                peer: peer,
                presence: presence,
                memberCount: nil,
                state: ItemListAvatarAndNameInfoItemState(),
                sectionId: self.section,
                style: .blocks(withTopInset: true, withExtendedBottomInset: false),
                editingNameUpdated: { _ in
                },
                avatarTapped: {
                }
            )
        case let .typesHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .typePhotos(title, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/DataPhotos"), title: title, value: value, sectionId: self.section, style: .blocks, updated: { _ in
                arguments.toggle(.photo)
            })
        case let .typeVideos(title, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/DataVideo"), title: title, value: value, sectionId: self.section, style: .blocks, updated: { _ in
                arguments.toggle(.video)
            })
        case let .typesInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .videoSizeHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .videoSize(decimalSeparator, text, size):
            return AutodownloadSizeLimitItem(theme: presentationData.theme, strings: presentationData.strings, decimalSeparator: decimalSeparator, text: text, value: size, range: nil/*2 * 1024 * 1024 ..< (4 * 1024 * 1024 * 1024)*/, sectionId: self.section, updated: { value in
                arguments.updateMaximumVideoSize(value)
            })
        case let .videoInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .exceptionsHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .addException(title):
            let icon: UIImage? = PresentationResourcesItemList.createGroupIcon(presentationData.theme)
            return ItemListPeerActionItem(presentationData: presentationData, icon: icon, title: title, alwaysPlain: false, sectionId: self.section, editing: false, action: {
                arguments.openAddException()
            })
        case let .exceptionItem(_, peer, label):
            return ItemListPeerItem(
                presentationData: presentationData,
                dateTimeFormat: PresentationDateTimeFormat(),
                nameDisplayOrder: .firstLast,
                context: arguments.context,
                peer: peer,
                height: .generic,
                aliasHandling: .threatSelfAsSaved,
                nameColor: .primary,
                presence: nil,
                text: .text(label, .secondary),
                label: .none,
                editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: false),
                revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                    arguments.deletePeer(peer.id)
                })]),
                switchValue: nil,
                enabled: true,
                selectable: true,
                sectionId: self.section,
                action: {
                    arguments.openPeerMenu(peer)
                },
                setPeerIdWithRevealedOptions: { lhs, rhs in
                    arguments.setPeerIdWithRevealedOptions(lhs, rhs)
                },
                removePeer: { id in
                    arguments.deletePeer(id)
                }
            )
            /*return ItemListDisclosureItem(presentationData: presentationData, icon: nil, context: arguments.context, iconPeer: peer, title: peer.displayTitle(strings: presentationData.strings, displayOrder: .firstLast), enabled: true, titleFont: .bold, label: label, labelStyle: .detailText, additionalDetailLabel: nil, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.openPeerMenu(peer)
            }, tag: nil)*/
        case let .deleteAllExceptions(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.deleteAllExceptions()
            })
        }
    }
}

private func saveIncomingMediaControllerEntries(presentationData: PresentationData, scope: SaveIncomingMediaScope, state: SaveIncomingMediaControllerState, peer: EnginePeer?, peerPresence: EnginePeer.Presence?, configuration: MediaAutoSaveConfiguration, exceptions: [MediaAutoSaveSettings.ExceptionItem], autosaveExceptionPeers: [EnginePeer.Id: EnginePeer?]) -> [SaveIncomingMediaEntry] {
    var entries: [SaveIncomingMediaEntry] = []
    
    if case .peer = scope, let peer {
        entries.append(.peer(peer: peer, presence: peerPresence))
    }
    
    entries.append(.typesHeader(presentationData.strings.Autosave_TypesSection))
    
    entries.append(.typePhotos(presentationData.strings.Autosave_TypePhoto, configuration.photo))
    entries.append(.typeVideos(presentationData.strings.Autosave_TypeVideo, configuration.video))
    entries.append(.typesInfo(presentationData.strings.Autosave_TypesInfo))
    
    if configuration.video {
        let sizeText: String
        if configuration.maximumVideoSize == Int64.max {
            sizeText = autodownloadDataSizeString(1536 * 1024 * 1024, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
        } else {
            sizeText = autodownloadDataSizeString(configuration.maximumVideoSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
        }
        
        let text = presentationData.strings.AutoDownloadSettings_UpTo(sizeText).string
        
        entries.append(.videoSizeHeader(presentationData.strings.Autosave_VideoSizeSection))
        entries.append(.videoSize(decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, text: text, value: configuration.maximumVideoSize))
        entries.append(.videoInfo(presentationData.strings.Autosave_VideoInfo(sizeText).string))
    }
    
    if case let .peerType(peerType) = scope {
        var filteredExceptions: [(EnginePeer, MediaAutoSaveConfiguration)] = []
        for exception in exceptions {
            guard let maybeExceptionPeer = autosaveExceptionPeers[exception.id], let exceptionPeer = maybeExceptionPeer else {
                continue
            }
            let peerTypeValue: AutomaticSaveIncomingPeerType
            switch exceptionPeer {
            case .user, .secretChat:
                peerTypeValue = .privateChats
            case .legacyGroup:
                peerTypeValue = .groups
            case let .channel(channel):
                if case .broadcast = channel.info {
                    peerTypeValue = .channels
                } else {
                    peerTypeValue = .groups
                }
            }
            
            if peerTypeValue == peerType {
                filteredExceptions.append((exceptionPeer, exception.configuration))
            }
        }
        
        if filteredExceptions.isEmpty {
            entries.append(.exceptionsHeader(presentationData.strings.Autosave_ExceptionsSection))
        } else {
            entries.append(.exceptionsHeader(presentationData.strings.Notifications_CategoryExceptions(Int32(filteredExceptions.count)).uppercased()))
        }
        
        entries.append(.addException(presentationData.strings.Autosave_AddException))
        
        var index = 0
        for (exceptionPeer, exceptionConfiguration) in filteredExceptions {
            var label = ""
            if exceptionConfiguration.photo {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaPhoto)
            } else {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaNoPhoto)
            }
            if exceptionConfiguration.video {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaVideo(dataSizeString(Int(exceptionConfiguration.maximumVideoSize), formatting: DataSizeStringFormatting(presentationData: presentationData))).string)
            } else {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaNoVideo)
            }
            
            entries.append(.exceptionItem(index: index, peer: exceptionPeer, label: label))
            index += 1
        }
        
        if !filteredExceptions.isEmpty {
            entries.append(.deleteAllExceptions(presentationData.strings.Autosave_DeleteAllExceptions))
        }
    }
    
    return entries
}

enum SaveIncomingMediaScope {
    case peer(EnginePeer.Id)
    case addPeer(id: EnginePeer.Id, completion: (MediaAutoSaveConfiguration) -> Void)
    case peerType(AutomaticSaveIncomingPeerType)
}

private struct SaveIncomingMediaControllerState: Equatable {
    var pendingConfiguration: MediaAutoSaveConfiguration = .default
    var peerIdWithOptions: EnginePeer.Id?
}

func saveIncomingMediaController(context: AccountContext, scope: SaveIncomingMediaScope) -> ViewController {
    let stateValue = Atomic(value: SaveIncomingMediaControllerState())
    let statePromise = ValuePromise<SaveIncomingMediaControllerState>(stateValue.with { $0 })
    let updateState: ((SaveIncomingMediaControllerState) -> SaveIncomingMediaControllerState) -> Void = { f in
        var changed = false
        let value = stateValue.modify { current in
            let updated = f(current)
            if updated != current {
                changed = true
            }
            return updated
        }
        if changed {
            statePromise.set(value)
        }
    }
    
    var pushController: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var dismiss: (() -> Void)?
    
    let arguments = SaveIncomingMediaControllerArguments(
        context: context,
        toggle: { type in
            if case .addPeer = scope {
                updateState { state in
                    var state = state
                    
                    switch type {
                    case .photo:
                        state.pendingConfiguration.photo = !state.pendingConfiguration.photo
                    case .video:
                        state.pendingConfiguration.video = !state.pendingConfiguration.video
                    }
                    
                    return state
                }
            } else {
                let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                    var settings = settings
                    
                    switch scope {
                    case let .peer(peerId):
                        if let index = settings.exceptions.firstIndex(where: { $0.id == peerId }) {
                            switch type {
                            case .photo:
                                settings.exceptions[index].configuration.photo = !settings.exceptions[index].configuration.photo
                            case .video:
                                settings.exceptions[index].configuration.video = !settings.exceptions[index].configuration.video
                            }
                        }
                    case .addPeer:
                        break
                    case let .peerType(peerType):
                        let mappedType: MediaAutoSaveSettings.PeerType
                        switch peerType {
                        case .privateChats:
                            mappedType = .users
                        case .groups:
                            mappedType = .groups
                        case .channels:
                            mappedType = .channels
                        }
                        var current = settings.configurations[mappedType] ?? .default
                        
                        switch type {
                        case .photo:
                            current.photo = !current.photo
                        case .video:
                            current.video = !current.video
                        }
                        
                        settings.configurations[mappedType] = current
                    }
                    
                    return settings
                }).start()
            }
        },
        updateMaximumVideoSize: { value in
            if case .addPeer = scope {
                updateState { state in
                    var state = state
                    
                    state.pendingConfiguration.maximumVideoSize = value
                    
                    return state
                }
            } else {
                let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                    var settings = settings
                    
                    switch scope {
                    case let .peer(peerId):
                        if let index = settings.exceptions.firstIndex(where: { $0.id == peerId }) {
                            settings.exceptions[index].configuration.maximumVideoSize = value
                        }
                    case .addPeer:
                        break
                    case let .peerType(peerType):
                        let mappedType: MediaAutoSaveSettings.PeerType
                        switch peerType {
                        case .privateChats:
                            mappedType = .users
                        case .groups:
                            mappedType = .groups
                        case .channels:
                            mappedType = .channels
                        }
                        var current = settings.configurations[mappedType] ?? .default
                        current.maximumVideoSize = value
                        settings.configurations[mappedType] = current
                    }
                    
                    return settings
                }).start()
            }
        },
        openAddException: {
            guard case let .peerType(peerType) = scope else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var filter: ChatListNodePeersFilter = [.excludeRecent, .doNotSearchMessages, .removeSearchHeader]
            switch peerType {
            case .groups:
                filter.insert(.onlyGroups)
            case .privateChats:
                filter.insert(.onlyPrivateChats)
                filter.insert(.excludeSecretChats)
            case .channels:
                filter.insert(.onlyChannels)
            }
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter, hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
            controller.peerSelected = { [weak controller] peer, _ in
                let peerId = peer.id
                
                let preferencesKey: PostboxViewKey = .preferences(keys: Set([ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings]))
                let preferences = context.account.postbox.combinedView(keys: [preferencesKey])
                |> map { views -> MediaAutoSaveSettings in
                    guard let view = views.views[preferencesKey] as? PreferencesView else {
                        return .default
                    }
                    return view.values[ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings]?.get(MediaAutoSaveSettings.self) ?? MediaAutoSaveSettings.default
                }
                
                let _ = (preferences
                |> take(1)
                |> deliverOnMainQueue).start(next: { settings in
                    if settings.exceptions.contains(where: { $0.id == peerId }) {
                        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
                            return
                        }
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { item in
                            if item === controller {
                                return false
                            }
                            return true
                        }
                        controllers.append(saveIncomingMediaController(context: context, scope: .peer(peerId)))
                        navigationController.setViewControllers(controllers, animated: true)
                    } else {
                        var dismissAll: (() -> Void)?
                        let exceptionController = saveIncomingMediaController(context: context, scope: .addPeer(id: peerId, completion: { configuration in
                            let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                                var settings = settings
                                
                                settings.exceptions.removeAll(where: { $0.id == peerId })
                                settings.exceptions.insert(MediaAutoSaveSettings.ExceptionItem(id: peerId, configuration: configuration), at: 0)
                                
                                return settings
                            }).start()
                            
                            dismissAll?()
                        }))
                        controller?.push(exceptionController)
                        
                        dismissAll = { [weak exceptionController] in
                            guard let exceptionController = exceptionController else {
                                return
                            }
                            guard let navigationController = exceptionController.navigationController as? NavigationController else {
                                return
                            }
                            var controllers = navigationController.viewControllers
                            controllers = controllers.filter { item in
                                if item === exceptionController || item === controller {
                                    return false
                                }
                                return true
                            }
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }
                })
            }
            pushController?(controller)
        },
        openPeerMenu: { peer in
            pushController?(saveIncomingMediaController(context: context, scope: .peer(peer.id)))
        },
        setPeerIdWithRevealedOptions: { itemId, fromItemId in
            updateState { state in
                var state = state
                if (itemId == nil && fromItemId == state.peerIdWithOptions) || (itemId != nil && fromItemId == nil) {
                    state.peerIdWithOptions = itemId
                }
                return state
            }
        },
        deletePeer: { id in
            let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                var settings = settings
                
                settings.exceptions.removeAll(where: { $0.id == id })
                
                return settings
            }).start()
        },
        deleteAllExceptions: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Autosave_DeleteAllExceptions, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                        var settings = settings
                        
                        settings.exceptions.removeAll()
                        
                        return settings
                    }).start()
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            presentControllerImpl?(actionSheet)
        }
    )
    
    let preferencesKey: PostboxViewKey = .preferences(keys: Set([ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings]))
    let preferences = context.account.postbox.combinedView(keys: [preferencesKey])
    |> map { views -> MediaAutoSaveSettings in
        guard let view = views.views[preferencesKey] as? PreferencesView else {
            return .default
        }
        return view.values[ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings]?.get(MediaAutoSaveSettings.self) ?? MediaAutoSaveSettings.default
    }
    
    let peer: Signal<(EnginePeer?, EnginePeer.Presence?), NoError>
    switch scope {
    case let .peer(id):
        peer = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: id),
            TelegramEngine.EngineData.Item.Peer.Presence(id: id)
        )
    case let .addPeer(id, _):
        peer = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: id),
            TelegramEngine.EngineData.Item.Peer.Presence(id: id)
        )
    default:
        peer = .single((nil, nil))
    }
    
    let autosaveExceptionPeers: Signal<[EnginePeer.Id: EnginePeer?], NoError> = preferences
    |> mapToSignal { mediaAutoSaveSettings -> Signal<[EnginePeer.Id: EnginePeer?], NoError> in
        let peerIds = mediaAutoSaveSettings.exceptions.map(\.id)
        return context.engine.data.get(EngineDataMap(
            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
        ))
    }
    
    struct StoredState {
        var entryCount: Int
        var hasVideo: Bool
    }
    
    let previousState = Atomic<StoredState?>(value: nil)
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), preferences, peer, autosaveExceptionPeers)
    |> deliverOnMainQueue
    |> map { presentationData, state, mediaAutoSaveSettings, peer, autosaveExceptionPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var rightButton: ItemListNavigationButton?
        
        switch scope {
        case .peer, .addPeer:
            rightButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                switch scope {
                case let .addPeer(_, completion):
                    let configuration = stateValue.with({ $0 }).pendingConfiguration
                    completion(configuration)
                default:
                    dismiss?()
                }
            })
        default:
            break
        }
        
        let configuration: MediaAutoSaveConfiguration
        var exceptions: [MediaAutoSaveSettings.ExceptionItem] = []
        let title: String
        switch scope {
        case let .peer(id):
            if let data = mediaAutoSaveSettings.exceptions.first(where: { $0.id == id }) {
                configuration = data.configuration
            } else {
                configuration = .default
            }
            title = presentationData.strings.Autosave_Exception
        case .addPeer:
            configuration = state.pendingConfiguration
            title = presentationData.strings.Autosave_AddException
        case let .peerType(peerType):
            exceptions = mediaAutoSaveSettings.exceptions
            switch peerType {
            case .privateChats:
                configuration = mediaAutoSaveSettings.configurations[.users] ?? .default
                title = presentationData.strings.Notifications_PrivateChats
            case .groups:
                configuration = mediaAutoSaveSettings.configurations[.groups] ?? .default
                title = presentationData.strings.Notifications_GroupChats
            case .channels:
                configuration = mediaAutoSaveSettings.configurations[.channels] ?? .default
                title = presentationData.strings.Notifications_Channels
            }
        }
        
        let entries = saveIncomingMediaControllerEntries(presentationData: presentationData, scope: scope, state: state, peer: peer.0, peerPresence: peer.1, configuration: configuration, exceptions: exceptions, autosaveExceptionPeers: autosaveExceptionPeers)
        
        var animateChanges = false
        let storedState = StoredState(
            entryCount: entries.count,
            hasVideo: entries.contains(where: { entry in
                switch entry {
                case .videoSize:
                    return true
                default:
                    return false
                }
            })
        )
        if let previous = previousState.swap(storedState) {
            if previous.entryCount > storedState.entryCount || previous.hasVideo != storedState.hasVideo {
                animateChanges = true
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    switch scope {
    case .peer, .addPeer:
        controller.navigationPresentation = .modal
    default:
        break
    }
    
    pushController = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismiss = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}

