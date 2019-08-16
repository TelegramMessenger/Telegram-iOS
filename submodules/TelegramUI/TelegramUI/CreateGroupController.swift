import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import LegacyComponents
import ItemListUI
import AccountContext
import AlertUI
import MediaResources
import PhotoResources
import LegacyUI
import LocationUI
import ItemListPeerItem
import ItemListAvatarAndNameInfoItem
import WebSearchUI
import Geocoding
import PeerInfoUI
import MapResourceToAvatarSizes
import ItemListAddressItem

private struct CreateGroupArguments {
    let account: Account
    
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let done: () -> Void
    let changeProfilePhoto: () -> Void
    let changeLocation: () -> Void
}

private enum CreateGroupSection: Int32 {
    case info
    case members
    case location
}

private enum CreateGroupEntryTag: ItemListItemTag {
    case info
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CreateGroupEntryTag {
            switch self {
                case .info:
                    if case .info = other {
                        return true
                    } else {
                        return false
                    }
            }
        } else {
            return false
        }
    }
}

private enum CreateGroupEntry: ItemListNodeEntry {
    case groupInfo(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer?, ItemListAvatarAndNameInfoItemState, ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case setProfilePhoto(PresentationTheme, String)
    case member(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Peer, PeerPresence?)
    case locationHeader(PresentationTheme, String)
    case location(PresentationTheme, PeerGeoLocation)
    case changeLocation(PresentationTheme, String)
    case locationInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .groupInfo, .setProfilePhoto:
                return CreateGroupSection.info.rawValue
            case .member:
                return CreateGroupSection.members.rawValue
            case .locationHeader, .location, .changeLocation, .locationInfo:
                return CreateGroupSection.location.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .groupInfo:
                return 0
            case .setProfilePhoto:
                return 1
            case let .member(index, _, _, _, _, _, _):
                return 2 + index
            case .locationHeader:
                return 10000
            case .location:
                return 10001
            case .changeLocation:
                return 10002
            case .locationInfo:
                return 10003
        }
    }
    
    static func ==(lhs: CreateGroupEntry, rhs: CreateGroupEntry) -> Bool {
        switch lhs {
            case let .groupInfo(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsEditingState, lhsAvatar):
                if case let .groupInfo(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsEditingState, rhsAvatar) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer != nil) != (rhsPeer != nil) {
                        return false
                    }
                    if lhsEditingState != rhsEditingState {
                        return false
                    }
                    if lhsAvatar != rhsAvatar {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .setProfilePhoto(lhsTheme, lhsText):
                if case let .setProfilePhoto(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .member(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameDisplayOrder, lhsPeer, lhsPresence):
                if case let .member(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameDisplayOrder, rhsPeer, rhsPresence) = rhs {
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
                    if lhsNameDisplayOrder != rhsNameDisplayOrder {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if !lhsPresence.isEqual(to: rhsPresence) {
                            return false
                        }
                    } else if (lhsPresence != nil) != (rhsPresence != nil) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .locationHeader(lhsTheme, lhsTitle):
                if case let .locationHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .location(lhsTheme, lhsLocation):
                if case let .location(rhsTheme, rhsLocation) = rhs, lhsTheme === rhsTheme, lhsLocation == rhsLocation {
                    return true
                } else {
                    return false
                }
            case let .changeLocation(lhsTheme, lhsTitle):
                if case let .changeLocation(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .locationInfo(lhsTheme, lhsText):
                if case let .locationInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: CreateGroupEntry, rhs: CreateGroupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: CreateGroupArguments) -> ListViewItem {
        switch self {
            case let .groupInfo(theme, strings, dateTimeFormat, peer, state, avatar):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer, presence: nil, cachedData: nil, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false, withExtendedBottomInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                }, updatingImage: avatar, tag: CreateGroupEntryTag.info)
            case let .setProfilePhoto(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .member(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer, presence):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.account, peer: peer, presence: presence, text: .presence, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
            case let .locationHeader(theme, title):
                return ItemListSectionHeaderItem(theme: theme, text: title, sectionId: self.section)
            case let .location(theme, location):
                let imageSignal = chatMapSnapshotImage(account: arguments.account, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
                return ItemListAddressItem(theme: theme, label: "", text: location.address.replacingOccurrences(of: ", ", with: "\n"), imageSignal: imageSignal, selected: nil, sectionId: self.section, style: .blocks, action: nil)
            case let .changeLocation(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeLocation()
                }, clearHighlightAutomatically: false)
            case let .locationInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct CreateGroupState: Equatable {
    var creating: Bool
    var editingName: ItemListAvatarAndNameInfoItemName
    var avatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    var location: PeerGeoLocation?
    
    static func ==(lhs: CreateGroupState, rhs: CreateGroupState) -> Bool {
        if lhs.creating != rhs.creating {
            return false
        }
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.avatar != rhs.avatar {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        return true
    }
}

private func createGroupEntries(presentationData: PresentationData, state: CreateGroupState, peerIds: [PeerId], view: MultiplePeersView) -> [CreateGroupEntry] {
    var entries: [CreateGroupEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: PeerId(namespace: -1, id: 0), title: state.editingName.composedTitle, photo: [], participantCount: 0, role: .creator(rank: nil), membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    
    entries.append(.groupInfo(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, groupInfoState, state.avatar))
    entries.append(.setProfilePhoto(presentationData.theme, presentationData.strings.GroupInfo_SetGroupPhoto))
    
    var peers: [Peer] = []
    for peerId in peerIds {
        if let peer = view.peers[peerId] {
            peers.append(peer)
        }
    }
    
    peers.sort(by: { lhs, rhs in
        let lhsPresence = view.presences[lhs.id] as? TelegramUserPresence
        let rhsPresence = view.presences[rhs.id] as? TelegramUserPresence
        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
            if lhsPresence.status < rhsPresence.status {
                return false
            } else if lhsPresence.status > rhsPresence.status {
                return true
            } else {
                return lhs.id < rhs.id
            }
        } else if let _ = lhsPresence {
            return true
        } else if let _ = rhsPresence {
            return false
        } else {
            return lhs.id < rhs.id
        }
    })
    
    for i in 0 ..< peers.count {
        entries.append(.member(Int32(i), presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, peers[i], view.presences[peers[i].id]))
    }
    
    if let location = state.location {
        entries.append(.locationHeader(presentationData.theme, presentationData.strings.Group_Location_Title.uppercased()))
        entries.append(.location(presentationData.theme, location))
        entries.append(.changeLocation(presentationData.theme, presentationData.strings.Group_Location_ChangeLocation))
        entries.append(.locationInfo(presentationData.theme, presentationData.strings.Group_Location_Info))
    }
    
    return entries
}

public func createGroupControllerImpl(context: AccountContext, peerIds: [PeerId], initialTitle: String? = nil, mode: CreateGroupMode = .generic, completion: ((PeerId, @escaping () -> Void) -> Void)? = nil) -> ViewController {
    var location: PeerGeoLocation?
    if case let .locatedGroup(latitude, longitude, address) = mode {
        location = PeerGeoLocation(latitude: latitude, longitude: longitude, address: address ?? "")
    }
    
    let initialState = CreateGroupState(creating: false, editingName: .title(title: initialTitle ?? "", type: .group), avatar: nil, location: location)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGroupState) -> CreateGroupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var endEditingImpl: (() -> Void)?
    var clearHighlightImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    let uploadedAvatar = Promise<UploadedPeerPhotoData>()
    
    let addressPromise = Promise<String?>(nil)
    if case let .locatedGroup(latitude, longitude, address) = mode {
        if let address = address {
            addressPromise.set(.single(address))
        } else {
            addressPromise.set(reverseGeocodeLocation(latitude: latitude, longitude: longitude)
            |> map { placemark in
                return placemark?.fullAddress ?? "\(latitude), \(longitude)"
            })
        }
    }
    
    let arguments = CreateGroupArguments(account: context.account, updateEditingName: { editingName in
        updateState { current in
            var current = current
            current.editingName = editingName
            return current
        }
    }, done: {
        let (creating, title, location) = stateValue.with { state -> (Bool, String, PeerGeoLocation?) in
            return (state.creating, state.editingName.composedTitle, state.location)
        }
        
        if !creating && !title.isEmpty {
            updateState { current in
                var current = current
                current.creating = true
                return current
            }
            endEditingImpl?()
            
            let createSignal: Signal<PeerId?, CreateGroupError>
            switch mode {
                case .generic:
                    createSignal = createGroup(account: context.account, title: title, peerIds: peerIds)
                case .supergroup:
                    createSignal = createSupergroup(account: context.account, title: title, description: nil)
                    |> map(Optional.init)
                    |> mapError { error -> CreateGroupError in
                        switch error {
                            case .generic:
                                return .generic
                            case .restricted:
                                return .restricted
                            case .tooMuchJoined:
                                return .tooMuchJoined
                            case .tooMuchLocationBasedGroups:
                                return .tooMuchLocationBasedGroups
                            case let .serverProvided(error):
                                return .serverProvided(error)
                        }
                    }
                case .locatedGroup:
                    guard let location = location else {
                        return
                    }
                    
                    createSignal = addressPromise.get()
                    |> introduceError(CreateGroupError.self)
                    |> mapToSignal { address -> Signal<PeerId?, CreateGroupError> in
                        guard let address = address else {
                            return .complete()
                        }
                        return createSupergroup(account: context.account, title: title, description: nil, location: (location.latitude, location.longitude, address))
                        |> map(Optional.init)
                        |> mapError { error -> CreateGroupError in
                            switch error {
                                case .generic:
                                    return .generic
                                case .restricted:
                                    return .restricted
                                case .tooMuchJoined:
                                    return .tooMuchJoined
                                case .tooMuchLocationBasedGroups:
                                    return .tooMuchLocationBasedGroups
                                case let .serverProvided(error):
                                    return .serverProvided(error)
                            }
                        }
                    }
            }
            
            actionsDisposable.add((createSignal
            |> mapToSignal { peerId -> Signal<PeerId?, CreateGroupError> in
                guard let peerId = peerId else {
                    return .single(nil)
                }
                let updatingAvatar = stateValue.with {
                    return $0.avatar
                }
                if let _ = updatingAvatar {
                    return updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.account.peerId, peerId: peerId, photo: uploadedAvatar.get(), mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                    })
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, CreateGroupError> in
                        return .complete()
                    }
                    |> mapToSignal { _ -> Signal<PeerId?, CreateGroupError> in
                        return .complete()
                    }
                    |> then(.single(peerId))
                } else {
                    return .single(peerId)
                }
            }
            |> deliverOnMainQueue
            |> afterDisposed {
                Queue.mainQueue().async {
                    updateState { current in
                        var current = current
                        current.creating = false
                        return current
                    }
                }
            }).start(next: { peerId in
                if let peerId = peerId {
                    if let completion = completion {
                        completion(peerId, {
                            dismissImpl?()
                        })
                    } else {
                        let controller = ChatControllerImpl(context: context, chatLocation: .peer(peerId))
                        replaceControllerImpl?(controller)
                    }
                }
            }, error: { error in
                if case .serverProvided = error {
                    return
                }

                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text: String?
                switch error {
                    case .privacy:
                        text = presentationData.strings.Privacy_GroupsAndChannels_InviteToChannelMultipleError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                    case .restricted:
                        text = presentationData.strings.Common_ActionNotAllowedError
                    case .tooMuchJoined:
                        text = presentationData.strings.CreateGroup_ChannelsTooMuch
                    case .tooMuchLocationBasedGroups:
                        text = presentationData.strings.CreateGroup_ErrorLocatedGroupsTooMuch
                    default:
                        text = nil
                }
                
                if let text = text {
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            }))
        }
    }, changeProfilePhoto: {
        endEditingImpl?()
        
        let title = stateValue.with { state -> String in
            return state.editingName.composedTitle
        }
        
        let _ = (context.account.postbox.transaction { transaction -> (Peer?, SearchBotsConfiguration) in
            return (transaction.getPeer(context.account.peerId), currentSearchBotsConfiguration(transaction: transaction))
        }
        |> deliverOnMainQueue).start(next: { peer, searchBotsConfiguration in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
            legacyController.statusBar.statusBarStyle = .Ignore
            
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
            
            legacyController.bind(controller: navigationController)
            
            endEditingImpl?()
            presentControllerImpl?(legacyController, nil)
            
            let completedImpl: (UIImage) -> Void = { image in
                if let data = image.jpegData(compressionQuality: 0.6) {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    let representation = TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), resource: resource)
                    uploadedAvatar.set(uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource))
                    updateState { current in
                        var current = current
                        current.avatar = .image(representation, false)
                        return current
                    }
                }
            }
            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: stateValue.with({ $0.avatar }) != nil, hasViewButton: false, personalPhoto: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: false)!
            let _ = currentAvatarMixin.swap(mixin)
            mixin.requestSearchController = { assetsController in
                let controller = WebSearchController(context: context, peer: peer, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: title, completion: { result in
                    assetsController?.dismiss()
                    completedImpl(result)
                }))
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
            mixin.didFinishWithImage = { image in
                if let image = image {
                    completedImpl(image)
                }
            }
            if stateValue.with({ $0.avatar }) != nil {
                mixin.didFinishWithDelete = {
                    updateState { current in
                        var current = current
                        current.avatar = nil
                        return current
                    }
                    uploadedAvatar.set(.never())
                }
            }
            mixin.didDismiss = { [weak legacyController] in
                let _ = currentAvatarMixin.swap(nil)
                legacyController?.dismiss()
            }
            let menuController = mixin.present()
            if let menuController = menuController {
                menuController.customRemoveFromParentViewController = { [weak legacyController] in
                    legacyController?.dismiss()
                }
            }
        })
    }, changeLocation: {
        endEditingImpl?()
        
        let peer = TelegramChannel(id: PeerId(0), accessHash: nil, title: "", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(TelegramChannelGroupInfo(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = legacyLocationPickerController(context: context, selfPeer: peer, peer: peer, sendLocation: { coordinate, _, address in
            let addressSignal: Signal<String, NoError>
            if let address = address {
                addressSignal = .single(address)
            } else {
                addressSignal = reverseGeocodeLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                |> map { placemark in
                    if let placemark = placemark {
                        return placemark.fullAddress
                    } else {
                        return "\(coordinate.latitude), \(coordinate.longitude)"
                    }
                }
            }
            
            let _ = (addressSignal
            |> deliverOnMainQueue).start(next: { address in
                addressPromise.set(.single(address))
                updateState { current in
                    var current = current
                    current.location = PeerGeoLocation(latitude: coordinate.latitude, longitude: coordinate.longitude, address: address)
                    return current
                }
            })
        }, sendLiveLocation: { _, _ in }, theme: presentationData.theme, customLocationPicker: true, presentationCompleted: {
            clearHighlightImpl?()
        })
        presentControllerImpl?(controller, nil)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), context.account.postbox.multiplePeersView(peerIds), .single(nil) |> then(addressPromise.get()))
    |> map { presentationData, state, view, address -> (ItemListControllerState, (ItemListNodeState<CreateGroupEntry>, CreateGroupEntry.ItemGenerationArguments)) in
        
        let rightNavigationButton: ItemListNavigationButton
        if state.creating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Compose_Create), style: .bold, enabled: !state.editingName.composedTitle.isEmpty, action: {
                arguments.done()
            })
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Compose_NewGroupTitle), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: createGroupEntries(presentationData: presentationData, state: state, peerIds: peerIds, view: view), style: .blocks, focusItemTag: CreateGroupEntryTag.info)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    replaceControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceAllButRootController(value, animated: true)
    }
    dismissImpl = { [weak controller] in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.filterController(controller, animated: true)
        }
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    controller.willDisappear = { _ in
        endEditingImpl?()
    }
    endEditingImpl = {
        [weak controller] in
        controller?.view.endEditing(true)
    }
    clearHighlightImpl = { [weak controller] in
        controller?.clearItemNodesHighlight(animated: true)
    }
    return controller
}
