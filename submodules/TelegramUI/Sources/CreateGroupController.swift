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
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import MediaResources
import PhotoResources
import LocationResources
import LegacyUI
import LocationUI
import ItemListPeerItem
import ItemListAvatarAndNameInfoItem
import WebSearchUI
import Geocoding
import PeerInfoUI
import MapResourceToAvatarSizes
import ItemListAddressItem
import ItemListVenueItem
import LegacyMediaPickerUI

private struct CreateGroupArguments {
    let context: AccountContext
    
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let done: () -> Void
    let changeProfilePhoto: () -> Void
    let changeLocation: () -> Void
    let updateWithVenue: (TelegramMediaMap) -> Void
}

private enum CreateGroupSection: Int32 {
    case info
    case members
    case location
    case venues
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
    case venueHeader(PresentationTheme, String)
    case venue(Int32, PresentationTheme, TelegramMediaMap)
    
    var section: ItemListSectionId {
        switch self {
            case .groupInfo, .setProfilePhoto:
                return CreateGroupSection.info.rawValue
            case .member:
                return CreateGroupSection.members.rawValue
            case .locationHeader, .location, .changeLocation, .locationInfo:
                return CreateGroupSection.location.rawValue
            case .venueHeader, .venue:
                return CreateGroupSection.venues.rawValue
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
            case .venueHeader:
                return 10004
            case let .venue(index, _, _):
                return 10005 + index
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
            case let .venueHeader(lhsTheme, lhsTitle):
                if case let .venueHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .venue(lhsIndex, lhsTheme, lhsVenue):
                if case let .venue(rhsIndex, rhsTheme, rhsVenue) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if !lhsVenue.isEqual(to: rhsVenue) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: CreateGroupEntry, rhs: CreateGroupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CreateGroupArguments
        switch self {
            case let .groupInfo(_, _, dateTimeFormat, peer, state, avatar):
                return ItemListAvatarAndNameInfoItem(accountContext: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, mode: .editSettings, peer: peer.flatMap(EnginePeer.init), presence: nil, memberCount: nil, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false, withExtendedBottomInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, editingNameCompleted: {
                    arguments.done()
                }, avatarTapped: {
                    arguments.changeProfilePhoto()
                }, updatingImage: avatar, tag: CreateGroupEntryTag.info)
            case let .setProfilePhoto(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .member(_, _, _, dateTimeFormat, nameDisplayOrder, peer, presence):
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(peer), presence: presence.flatMap(EnginePeer.Presence.init), text: .presence, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
            case let .locationHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .location(theme, location):
                let imageSignal = chatMapSnapshotImage(engine: arguments.context.engine, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
                return ItemListAddressItem(theme: theme, label: "", text: location.address.replacingOccurrences(of: ", ", with: "\n"), imageSignal: imageSignal, selected: nil, sectionId: self.section, style: .blocks, action: nil)
            case let .changeLocation(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeLocation()
                })
            case let .locationInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .venueHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .venue(_, _, venue):
                return ItemListVenueItem(presentationData: presentationData, engine: arguments.context.engine, venue: venue, sectionId: self.section, style: .blocks, action: {
                    arguments.updateWithVenue(venue)
                })
        }
    }
}

private struct CreateGroupState: Equatable {
    var creating: Bool
    var editingName: ItemListAvatarAndNameInfoItemName
    var nameSetFromVenue: Bool
    var avatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    var location: PeerGeoLocation?
    
    static func ==(lhs: CreateGroupState, rhs: CreateGroupState) -> Bool {
        if lhs.creating != rhs.creating {
            return false
        }
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.nameSetFromVenue != rhs.nameSetFromVenue {
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

private func createGroupEntries(presentationData: PresentationData, state: CreateGroupState, peerIds: [PeerId], view: MultiplePeersView, venues: [TelegramMediaMap]?) -> [CreateGroupEntry] {
    var entries: [CreateGroupEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: PeerId(namespace: .max, id: PeerId.Id._internalFromInt64Value(0)), title: state.editingName.composedTitle, photo: [], participantCount: 0, role: .creator(rank: nil), membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    
    entries.append(.groupInfo(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, groupInfoState, state.avatar))
    
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
        
        entries.append(.venueHeader(presentationData.theme, presentationData.strings.Group_Location_CreateInThisPlace.uppercased()))
        if let venues = venues {
            if !venues.isEmpty {
                var index: Int32 = 0
                for venue in venues {
                    entries.append(.venue(index, presentationData.theme, venue))
                    index += 1
                }
            } else {
                
            }
        } else {
            
        }
    }
    
    return entries
}

public func createGroupControllerImpl(context: AccountContext, peerIds: [PeerId], initialTitle: String? = nil, mode: CreateGroupMode = .generic, completion: ((PeerId, @escaping () -> Void) -> Void)? = nil) -> ViewController {
    var location: PeerGeoLocation?
    if case let .locatedGroup(latitude, longitude, address) = mode {
        location = PeerGeoLocation(latitude: latitude, longitude: longitude, address: address ?? "")
    }
    
    let initialState = CreateGroupState(creating: false, editingName: .title(title: initialTitle ?? "", type: .group), nameSetFromVenue: false, avatar: nil, location: location)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGroupState) -> CreateGroupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var endEditingImpl: (() -> Void)?
    var ensureItemVisibleImpl: ((CreateGroupEntryTag, Bool) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    let uploadedAvatar = Promise<UploadedPeerPhotoData>()
    var uploadedVideoAvatar: (Promise<UploadedPeerPhotoData?>, Double?)? = nil
    
    let addressPromise = Promise<String?>(nil)
    let venuesPromise = Promise<[TelegramMediaMap]?>(nil)
    if case let .locatedGroup(latitude, longitude, address) = mode {
        if let address = address {
            addressPromise.set(.single(address))
        } else {
            addressPromise.set(reverseGeocodeLocation(latitude: latitude, longitude: longitude)
            |> map { placemark in
                return placemark?.fullAddress ?? "\(latitude), \(longitude)"
            })
        }
        
        venuesPromise.set(nearbyVenues(context: context, latitude: latitude, longitude: longitude)
        |> map(Optional.init))
    }
    
    let arguments = CreateGroupArguments(context: context, updateEditingName: { editingName in
        updateState { current in
            var current = current
            current.editingName = editingName
            current.nameSetFromVenue = false
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
                    createSignal = context.engine.peers.createGroup(title: title, peerIds: peerIds)
                case .supergroup:
                    createSignal = context.engine.peers.createSupergroup(title: title, description: nil)
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
                    |> castError(CreateGroupError.self)
                    |> mapToSignal { address -> Signal<PeerId?, CreateGroupError> in
                        guard let address = address else {
                            return .complete()
                        }
                        return context.engine.peers.createSupergroup(title: title, description: nil, location: (location.latitude, location.longitude, address))
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
                    return context.engine.peers.updatePeerPhoto(peerId: peerId, photo: uploadedAvatar.get(), video: uploadedVideoAvatar?.0.get(), videoStartTimestamp: uploadedVideoAvatar?.1, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                    })
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, CreateGroupError> in
                        return .complete()
                    }
                    |> mapToSignal { _ -> Signal<PeerId?, CreateGroupError> in
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
                        let controller = ChatControllerImpl(context: context, chatLocation: .peer(id: peerId))
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
                        pushImpl?(oldChannelsController(context: context, intent: .create))
                        return
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
        
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
            TelegramEngine.EngineData.Item.Configuration.SearchBots()
        )
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
            
            let completedGroupPhotoImpl: (UIImage) -> Void = { image in
                if let data = image.jpegData(compressionQuality: 0.6) {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)
                    uploadedAvatar.set(context.engine.peers.uploadedPeerPhoto(resource: resource))
                    uploadedVideoAvatar = nil
                    updateState { current in
                        var current = current
                        current.avatar = .image(representation, false)
                        return current
                    }
                }
            }
            
            let completedGroupVideoImpl: (UIImage, Any?, TGVideoEditAdjustments?) -> Void = { image, asset, adjustments in
                if let data = image.jpegData(compressionQuality: 0.6) {
                    let photoResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                    let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil)
                    updateState { state in
                        var state = state
                        state.avatar = .image(representation, true)
                        return state
                    }
                    
                    var videoStartTimestamp: Double? = nil
                    if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
                        videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
                    }
                    
                    let signal = Signal<TelegramMediaResource?, UploadPeerPhotoError> { subscriber in
                        
                        let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                            if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                                return LegacyPaintEntityRenderer(account: context.account, adjustments: adjustments)
                            } else {
                                return nil
                            }
                        }
                        let uploadInterface = LegacyLiveUploadInterface(context: context)
                        let signal: SSignal
                        if let asset = asset as? AVAsset {
                            signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, watcher: uploadInterface, entityRenderer: entityRenderer)!
                        } else if let url = asset as? URL, let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
                            let durationSignal: SSignal = SSignal(generator: { subscriber in
                                let disposable = (entityRenderer.duration()).start(next: { duration in
                                    subscriber.putNext(duration)
                                    subscriber.putCompletion()
                                })
                                
                                return SBlockDisposable(block: {
                                    disposable.dispose()
                                })
                            })
                            signal = durationSignal.map(toSignal: { duration -> SSignal in
                                if let duration = duration as? Double {
                                    return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, watcher: nil, entityRenderer: entityRenderer)!
                                } else {
                                    return SSignal.single(nil)
                                }
                            })
                           
                        } else {
                            signal = SSignal.complete()
                        }
                        
                        let signalDisposable = signal.start(next: { next in
                            if let result = next as? TGMediaVideoConversionResult {
                                if let image = result.coverImage, let data = image.jpegData(compressionQuality: 0.7) {
                                    context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                                }
                                
                                if let timestamp = videoStartTimestamp {
                                    videoStartTimestamp = max(0.0, min(timestamp, result.duration - 0.05))
                                }
                                                                
                                var value = stat()
                                if stat(result.fileURL.path, &value) == 0 {
                                    if let data = try? Data(contentsOf: result.fileURL) {
                                        let resource: TelegramMediaResource
                                        if let liveUploadData = result.liveUploadData as? LegacyLiveUploadInterfaceResult {
                                            resource = LocalFileMediaResource(fileId: liveUploadData.id)
                                        } else {
                                            resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                        }
                                        context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                        subscriber.putNext(resource)
                                    }
                                }
                                subscriber.putCompletion()
                            }
                        }, error: { _ in
                        }, completed: nil)
                        
                        let disposable = ActionDisposable {
                            signalDisposable?.dispose()
                        }
                        
                        return ActionDisposable {
                            disposable.dispose()
                        }
                    }
                    
                    uploadedAvatar.set(context.engine.peers.uploadedPeerPhoto(resource: photoResource))
                    
                    let promise = Promise<UploadedPeerPhotoData?>()
                    promise.set(signal
                    |> `catch` { _ -> Signal<TelegramMediaResource?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { resource -> Signal<UploadedPeerPhotoData?, NoError> in
                        if let resource = resource {
                            return context.engine.peers.uploadedPeerVideo(resource: resource) |> map(Optional.init)
                        } else {
                            return .single(nil)
                        }
                    } |> afterNext { next in
                        if let next = next, next.isCompleted {
                            updateState { state in
                                var state = state
                                state.avatar = .image(representation, false)
                                return state
                            }
                        }
                    })
                    uploadedVideoAvatar = (promise, videoStartTimestamp)
                }
            }
            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: stateValue.with({ $0.avatar }) != nil, hasViewButton: false, personalPhoto: false, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: false)!
            let _ = currentAvatarMixin.swap(mixin)
            mixin.requestSearchController = { assetsController in
                let controller = WebSearchController(context: context, peer: peer, chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: title, completion: { result in
                    assetsController?.dismiss()
                    completedGroupPhotoImpl(result)
                }))
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
            mixin.didFinishWithImage = { image in
                if let image = image {
                    completedGroupPhotoImpl(image)
                }
            }
            mixin.didFinishWithVideo = { image, asset, adjustments in
                if let image = image, let asset = asset {
                    completedGroupVideoImpl(image, asset, adjustments)
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
                 
         let controller = LocationPickerController(context: context, mode: .pick, completion: { location, address in
             let addressSignal: Signal<String, NoError>
             if let address = address {
                 addressSignal = .single(address)
             } else {
                 addressSignal = reverseGeocodeLocation(latitude: location.latitude, longitude: location.longitude)
                 |> map { placemark in
                     if let placemark = placemark {
                         return placemark.fullAddress
                     } else {
                         return "\(location.latitude), \(location.longitude)"
                     }
                 }
             }
             
             let _ = (addressSignal
             |> deliverOnMainQueue).start(next: { address in
                 addressPromise.set(.single(address))
                 updateState { current in
                     var current = current
                     current.location = PeerGeoLocation(latitude: location.latitude, longitude: location.longitude, address: address)
                     return current
                 }
             })
         })
         pushImpl?(controller)
    }, updateWithVenue: { venue in
        guard let venueData = venue.venue else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        updateState { current in
            var current = current
            if current.editingName.isEmpty || current.nameSetFromVenue {
                current.editingName = .title(title: venueData.title, type: .group)
                current.nameSetFromVenue = true
            }
            current.location = PeerGeoLocation(latitude: venue.latitude, longitude: venue.longitude, address: presentationData.strings.Map_Locating + "\n\n")
            return current
        }
        
        let _ = (reverseGeocodeLocation(latitude: venue.latitude, longitude: venue.longitude)
        |> map { placemark -> String in
            if let placemark = placemark {
                return placemark.fullAddress
            } else {
                return venueData.address ?? ""
            }
        }
        |> deliverOnMainQueue).start(next: { address in
            addressPromise.set(.single(address))
            updateState { current in
                var current = current
                current.location = PeerGeoLocation(latitude: venue.latitude, longitude: venue.longitude, address: address)
                return current
            }
        })
        ensureItemVisibleImpl?(.info, true)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), context.account.postbox.multiplePeersView(peerIds), .single(nil) |> then(addressPromise.get()), .single(nil) |> then(venuesPromise.get()))
    |> map { presentationData, state, view, address, venues -> (ItemListControllerState, (ItemListNodeState, Any)) in
        
        let rightNavigationButton: ItemListNavigationButton
        if state.creating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Compose_Create), style: .bold, enabled: !state.editingName.composedTitle.isEmpty, action: {
                arguments.done()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Compose_NewGroupTitle), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createGroupEntries(presentationData: presentationData, state: state, peerIds: peerIds, view: view, venues: venues), style: .blocks, focusItemTag: CreateGroupEntryTag.info)
        
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
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    controller.willDisappear = { _ in
        endEditingImpl?()
    }
    endEditingImpl = {
        [weak controller] in
        controller?.view.endEditing(true)
    }
    ensureItemVisibleImpl = { [weak controller] targetTag, animated in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let _ = controller.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListItemNode {
                    if let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                        resultItemNode = itemNode as? ListViewItemNode
                        return true
                    }
                }
                return false
            })
            
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode, animated: animated)
            }
        })
    }
    return controller
}
