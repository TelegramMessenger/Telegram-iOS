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
import ContextUI
import ChatTimerScreen
import AsyncDisplayKit
import TextFormat
import AvatarEditorScreen
import SendInviteLinkScreen

private struct CreateGroupArguments {
    let context: AccountContext
    
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let done: () -> Void
    let changeProfilePhoto: () -> Void
    let changeLocation: () -> Void
    let updateWithVenue: (TelegramMediaMap) -> Void
    let updateAutoDelete: () -> Void
    let updatePublicLinkText: (String) -> Void
    let openAuction: (String) -> Void
}

private enum CreateGroupSection: Int32 {
    case info
    case username
    case topics
    case autoDelete
    case members
    case location
    case venues
}

private enum CreateGroupEntryTag: ItemListItemTag {
    case info
    case autoDelete
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CreateGroupEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum CreateGroupEntry: ItemListNodeEntry {
    case groupInfo(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer?, ItemListAvatarAndNameInfoItemState, ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case setProfilePhoto(PresentationTheme, String)
    case usernameHeader(PresentationTheme, String)
    case username(PresentationTheme, String, String)
    case usernameStatus(PresentationTheme, String, AddressNameValidationStatus, String, String)
    case usernameInfo(PresentationTheme, String)
    case topics(PresentationTheme, String)
    case topicsInfo(PresentationTheme, String)
    case autoDelete(title: String, value: String)
    case autoDeleteInfo(String)
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
            case .usernameHeader, .username, .usernameStatus, .usernameInfo:
                return CreateGroupSection.username.rawValue
            case .topics, .topicsInfo:
                return CreateGroupSection.topics.rawValue
            case .autoDelete, .autoDeleteInfo:
                return CreateGroupSection.autoDelete.rawValue
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
            case .usernameHeader:
                return 2
            case .username:
                return 3
            case .usernameStatus:
                return 4
            case .usernameInfo:
                return 5
            case .topics:
                return 6
            case .topicsInfo:
                return 7
            case .autoDelete:
                return 8
            case .autoDeleteInfo:
                return 9
            case let .member(index, _, _, _, _, _, _):
                return 10 + index
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
            
            case let .usernameHeader(lhsTheme, lhsText):
                if case let .usernameHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .username(lhsTheme, lhsText, lhsValue):
                if case let .username(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .usernameStatus(lhsTheme, lhsAddressName, lhsStatus, lhsText, lhsUsername):
                if case let .usernameStatus(rhsTheme, rhsAddressName, rhsStatus, rhsText, rhsUsername) = rhs, lhsTheme === rhsTheme, lhsAddressName == rhsAddressName, lhsStatus == rhsStatus, lhsText == rhsText, lhsUsername == rhsUsername {
                    return true
                } else {
                    return false
                }
            case let .usernameInfo(lhsTheme, lhsText):
                if case let .usernameInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .topics(lhsTheme, lhsText):
                if case let .topics(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .topicsInfo(lhsTheme, lhsText):
                if case let .topicsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .autoDelete(title, value):
                if case .autoDelete(title, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .autoDeleteInfo(text):
                if case .autoDeleteInfo(text) = rhs {
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
            case let .usernameHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .username(theme, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "t.me/", textColor: theme.list.itemPrimaryTextColor), text: text, placeholder: placeholder, type: .username, clearType: .always, tag: nil, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(updatedText)
                }, action: {
                })
            case let .usernameStatus(_, _, status, text, username):
                var displayActivity = false
                let textColor: ItemListActivityTextItem.TextColor
                switch status {
                case .invalidFormat:
                    textColor = .destructive
                case let .availability(availability):
                    switch availability {
                    case .available:
                        textColor = .constructive
                    case .purchaseAvailable:
                        textColor = .generic
                    case .invalid, .taken:
                        textColor = .destructive
                    }
                case .checking:
                    textColor = .generic
                    displayActivity = true
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, presentationData: presentationData, text: text, color: textColor, linkAction: { _ in
                    arguments.openAuction(username)
                }, sectionId: self.section)
            case let .usernameInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .topics(_, text):
                return ItemListSwitchItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Topics")?.precomposed(), title: text, value: true, enabled: false, sectionId: self.section, style: .blocks, updated: { _ in })
            case let .topicsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .autoDelete(text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .optionArrows, action: {
                    arguments.updateAutoDelete()
                }, tag: CreateGroupEntryTag.autoDelete)
            case let .autoDeleteInfo(text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
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
    var autoremoveTimeout: Int32?
    var editingPublicLinkText: String?
    var addressNameValidationStatus: AddressNameValidationStatus?
}

private func createGroupEntries(presentationData: PresentationData, state: CreateGroupState, peerIds: [PeerId], view: MultiplePeersView, venues: [TelegramMediaMap]?, globalAutoremoveTimeout: Int32, requestPeer: ReplyMarkupButtonRequestPeerType.Group?) -> [CreateGroupEntry] {
    var entries: [CreateGroupEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: PeerId(namespace: .max, id: PeerId.Id._internalFromInt64Value(0)), title: state.editingName.composedTitle, photo: [], participantCount: 0, role: .creator(rank: nil), membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    
    entries.append(.groupInfo(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, groupInfoState, state.avatar))
    
    if let requestPeer {
        if let hasUsername = requestPeer.hasUsername, hasUsername {
            let currentUsername = state.editingPublicLinkText ?? ""
            entries.append(.usernameHeader(presentationData.theme, presentationData.strings.CreateGroup_PublicLinkTitle.uppercased()))
            entries.append(.username(presentationData.theme, presentationData.strings.Group_PublicLink_Placeholder, currentUsername))
            
            if let status = state.addressNameValidationStatus {
                let statusText: String
                switch status {
                    case let .invalidFormat(error):
                        switch error {
                            case .startsWithDigit:
                                statusText = presentationData.strings.Username_InvalidStartsWithNumber
                            case .startsWithUnderscore:
                                statusText = presentationData.strings.Username_InvalidStartsWithUnderscore
                            case .endsWithUnderscore:
                                statusText = presentationData.strings.Username_InvalidEndsWithUnderscore
                            case .invalidCharacters:
                                statusText = presentationData.strings.Username_InvalidCharacters
                            case .tooShort:
                                statusText = presentationData.strings.Username_InvalidTooShort
                        }
                    case let .availability(availability):
                        switch availability {
                            case .available:
                            statusText = presentationData.strings.Username_UsernameIsAvailable(currentUsername).string
                            case .invalid:
                                statusText = presentationData.strings.Username_InvalidCharacters
                            case .taken:
                                statusText = presentationData.strings.Username_InvalidTaken
                            case .purchaseAvailable:
                                var markdownString = presentationData.strings.Username_UsernamePurchaseAvailable
                                let entities = generateTextEntities(markdownString, enabledTypes: [.mention])
                                if let entity = entities.first {
                                    markdownString.insert(contentsOf: "]()", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.upperBound))
                                    markdownString.insert(contentsOf: "[", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.lowerBound))
                                }
                                statusText = markdownString
                        }
                    case .checking:
                        statusText = presentationData.strings.Username_CheckingUsername
                }
                entries.append(.usernameStatus(presentationData.theme, currentUsername, status, statusText, currentUsername))
            }
            
            entries.append(.usernameInfo(presentationData.theme, presentationData.strings.CreateGroup_PublicLinkInfo))
        }
        if let isForum = requestPeer.isForum, isForum {
            entries.append(.topics(presentationData.theme, presentationData.strings.PeerInfo_OptionTopics))
            entries.append(.topicsInfo(presentationData.theme, presentationData.strings.PeerInfo_OptionTopicsText))
        }
    } else {
        let autoremoveTimeout = state.autoremoveTimeout ?? globalAutoremoveTimeout
        let autoRemoveText: String
        if autoremoveTimeout == 0 {
            autoRemoveText = presentationData.strings.Autoremove_OptionOff
        } else {
            autoRemoveText = timeIntervalString(strings: presentationData.strings, value: autoremoveTimeout)
        }
        entries.append(.autoDelete(title: presentationData.strings.CreateGroup_AutoDeleteTitle, value: autoRemoveText))
        entries.append(.autoDeleteInfo(presentationData.strings.CreateGroup_AutoDeleteText))
    }
    
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

public func createGroupControllerImpl(context: AccountContext, peerIds: [PeerId], initialTitle: String? = nil, mode: CreateGroupMode = .generic, willComplete: @escaping (String, @escaping () -> Void) -> Void = { _, complete in complete() }, completion: ((PeerId, @escaping () -> Void) -> Void)? = nil) -> ViewController {
    var location: PeerGeoLocation?
    if case let .locatedGroup(latitude, longitude, address) = mode {
        location = PeerGeoLocation(latitude: latitude, longitude: longitude, address: address ?? "")
    }
    
    let initialState = CreateGroupState(creating: false, editingName: .title(title: initialTitle ?? "", type: .group), nameSetFromVenue: false, avatar: nil, location: location, autoremoveTimeout: nil, editingPublicLinkText: nil, addressNameValidationStatus: nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGroupState) -> CreateGroupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var presentInGlobalOverlay: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var endEditingImpl: (() -> Void)?
    var ensureItemVisibleImpl: ((CreateGroupEntryTag, Bool) -> Void)?
    var findAutoremoveReferenceNode: (() -> ItemListDisclosureItemNode?)?
    var selectTitleImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    let uploadedAvatar = Promise<UploadedPeerPhotoData>()
    var uploadedVideoAvatar: (Promise<UploadedPeerPhotoData?>, Double?)? = nil
    
    if initialTitle == nil && peerIds.count > 0 && peerIds.count < 5 {
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
            EngineDataList(
                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
            )
        )
        |> deliverOnMainQueue).start(next: { accountPeer, peers in
            var allNames: [String] = []
            if case let .user(user) = accountPeer, let firstName = user.firstName, !firstName.isEmpty {
                allNames.append(firstName)
            }
            for peer in peers {
                if case let .user(user) = peer, let firstName = user.firstName, !firstName.isEmpty {
                    allNames.append(firstName)
                }
            }
            
            if allNames.count > 1 {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var title: String = ""
                for i in 0 ..< allNames.count {
                    if i == 0 {
                    } else if i < allNames.count - 1 {
                        title.append(presentationData.strings.CreateGroup_PeersTitleDelimeter)
                    } else {
                        title.append(presentationData.strings.CreateGroup_PeersTitleLastDelimeter)
                    }
                    title.append(allNames[i])
                }
                
                updateState { current in
                    var current = current
                    current.editingName = .title(title: title, type: .group)
                    return current
                }
                
                Queue.mainQueue().after(0.3) {
                    selectTitleImpl?()
                }
            }
        })
    }
    
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
        let (creating, title, location, publicLink) = stateValue.with { state -> (Bool, String, PeerGeoLocation?, String?) in
            return (state.creating, state.editingName.composedTitle, state.location, state.editingPublicLinkText)
        }
        
        if !creating && !title.isEmpty {
            willComplete(title, {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.GlobalAutoremoveTimeout())
                |> deliverOnMainQueue).start(next: { maybeGlobalAutoremoveTimeout in
                    updateState { current in
                        var current = current
                        current.creating = true
                        return current
                    }
                    endEditingImpl?()
                    
                    let globalAutoremoveTimeout: Int32 = maybeGlobalAutoremoveTimeout ?? 0
                    let autoremoveTimeout = stateValue.with({ $0 }).autoremoveTimeout ?? globalAutoremoveTimeout
                    let ttlPeriod: Int32? = autoremoveTimeout == 0 ? nil : autoremoveTimeout
                    
                    var createSignal: Signal<CreateGroupResult?, CreateGroupError>
                    switch mode {
                    case .generic:
                        createSignal = context.engine.peers.createGroup(title: title, peerIds: peerIds, ttlPeriod: ttlPeriod)
                    case .supergroup:
                        createSignal = context.engine.peers.createSupergroup(title: title, description: nil)
                        |> map { peerId -> CreateGroupResult? in
                            return CreateGroupResult(peerId: peerId, failedToInvitePeerIds: [])
                        }
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
                        |> mapToSignal { address -> Signal<CreateGroupResult?, CreateGroupError> in
                            guard let address = address else {
                                return .complete()
                            }
                            return context.engine.peers.createSupergroup(title: title, description: nil, location: (location.latitude, location.longitude, address))
                            |> map { peerId -> CreateGroupResult? in
                                return CreateGroupResult(peerId: peerId, failedToInvitePeerIds: [])
                            }
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
                    case let .requestPeer(group):
                        var isForum = false
                        if let isForumRequested = group.isForum, isForumRequested {
                            isForum = true
                        }
                        
                        let createGroupSignal: (Bool) -> Signal<CreateGroupResult?, CreateGroupError> = { isForum in
                            return context.engine.peers.createSupergroup(title: title, description: nil, isForum: isForum)
                            |> map { peerId -> CreateGroupResult? in
                                return CreateGroupResult(peerId: peerId, failedToInvitePeerIds: [])
                            }
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
                        if let publicLink, !publicLink.isEmpty {
                            createSignal = createGroupSignal(isForum)
                            |> mapToSignal { result in
                                if let result = result {
                                    return context.engine.peers.updateAddressName(domain: .peer(result.peerId), name: publicLink)
                                    |> mapError { _ in
                                        return .generic
                                    }
                                    |> map { _ -> CreateGroupResult? in
                                        return result
                                    }
                                } else {
                                    return .fail(.generic)
                                }
                            }
                        } else if isForum || group.userAdminRights != nil {
                            createSignal = createGroupSignal(isForum)
                        } else {
                            createSignal = context.engine.peers.createGroup(title: title, peerIds: peerIds, ttlPeriod: nil)
                        }

                        if group.userAdminRights?.rights.contains(.canBeAnonymous) == true {
                            createSignal = createSignal
                            |> mapToSignal { result in
                                if let result = result {
                                    return context.engine.peers.updateChannelAdminRights(peerId: result.peerId, adminId: context.account.peerId, rights: TelegramChatAdminRights(rights: .canBeAnonymous), rank: nil)
                                    |> mapError { _ in
                                        return .generic
                                    }
                                    |> map { _ in
                                        return result
                                    }
                                } else {
                                    return .fail(.generic)
                                }
                            }
                        }
                    }
                    
                    let _ = createSignal
                    let _ = replaceControllerImpl
                    let _ = dismissImpl
                    let _ = uploadedVideoAvatar
                    
                    actionsDisposable.add((createSignal
                    |> mapToSignal { result -> Signal<CreateGroupResult?, CreateGroupError> in
                        guard let result = result else {
                            return .single(nil)
                        }
                        let updatingAvatar = stateValue.with {
                            return $0.avatar
                        }
                        if let _ = updatingAvatar {
                            return context.engine.peers.updatePeerPhoto(peerId: result.peerId, photo: uploadedAvatar.get(), video: uploadedVideoAvatar?.0.get(), videoStartTimestamp: uploadedVideoAvatar?.1, mapResourceToAvatarSizes: { resource, representations in
                                return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                            })
                            |> ignoreValues
                            |> `catch` { _ -> Signal<Never, CreateGroupError> in
                                return .complete()
                            }
                            |> mapToSignal { _ -> Signal<CreateGroupResult?, CreateGroupError> in
                            }
                            |> then(.single(result))
                        } else {
                            return .single(result)
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
                    }).start(next: { result in
                        if let result = result {
                            if let completion = completion {
                                completion(result.peerId, {
                                    dismissImpl?()
                                })
                            } else {
                                let controller = ChatControllerImpl(context: context, chatLocation: .peer(id: result.peerId))
                                replaceControllerImpl?(controller)
                                
                                if !result.failedToInvitePeerIds.isEmpty {
                                    context.account.viewTracker.forceUpdateCachedPeerData(peerId: result.peerId)
                                    let _ = (context.engine.data.subscribe(
                                        TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: result.peerId)
                                    )
                                    |> filter { $0 != nil }
                                    |> take(1)
                                    |> timeout(1.0, queue: .mainQueue(), alternate: .single(nil))
                                    |> deliverOnMainQueue).start(next: { [weak controller] exportedInvitation in
                                        let _ = (context.engine.data.get(
                                            TelegramEngine.EngineData.Item.Peer.Peer(id: result.peerId)
                                        )
                                        |> deliverOnMainQueue).start(next: { peer in
                                            let _ = controller
                                            let _ = exportedInvitation
                                            
                                            if let peer, let exportedInvitation, let link = exportedInvitation.link {
                                                let _ = (context.engine.data.get(
                                                    EngineDataList(result.failedToInvitePeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                                                )
                                                |> deliverOnMainQueue).start(next: { peerItems in
                                                    guard let controller else {
                                                        return
                                                    }
                                                    let _ = controller
                                                    let _ = peerItems
                                                    
                                                    let peers = peerItems.compactMap { $0 }
                                                    if !peers.isEmpty {
                                                        let inviteScreen = SendInviteLinkScreen(context: context, peer: peer, link: link, peers: peers)
                                                        controller.push(inviteScreen)
                                                    }
                                                })
                                            }
                                        })
                                    })
                                }
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
                })
            })
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
                    let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
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
                    let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
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
                        
                        let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                        let uploadInterface = LegacyLiveUploadInterface(context: context)
                        let signal: SSignal
                        if let url = asset as? URL, url.absoluteString.hasSuffix(".jpg"), let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
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
                                    return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, path: tempFile.path, watcher: nil, entityRenderer: entityRenderer)!
                                } else {
                                    return SSignal.single(nil)
                                }
                            })
                           
                        } else if let asset = asset as? AVAsset {
                            signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, path: tempFile.path, watcher: uploadInterface, entityRenderer: entityRenderer)!
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
                                        
                                        EngineTempBox.shared.dispose(tempFile)
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
            
            let keyboardInputData = Promise<AvatarKeyboardInputData>()
            keyboardInputData.set(AvatarEditorScreen.inputData(context: context, isGroup: true))
            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: stateValue.with({ $0.avatar }) != nil, hasViewButton: false, personalPhoto: false, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: false, forum: false, title: nil, isSuggesting: false)!
            mixin.stickersContext = LegacyPaintStickersContext(context: context)
            let _ = currentAvatarMixin.swap(mixin)
            mixin.requestSearchController = { assetsController in
                let controller = WebSearchController(context: context, peer: peer, chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: title, completion: { result in
                    assetsController?.dismiss()
                    completedGroupPhotoImpl(result)
                }))
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
            mixin.requestAvatarEditor = { imageCompletion, videoCompletion in
                guard let imageCompletion, let videoCompletion else {
                    return
                }
                let controller = AvatarEditorScreen(context: context, inputData: keyboardInputData.get(), peerType: .group, markup: nil)
                controller.imageCompletion = imageCompletion
                controller.videoCompletion = videoCompletion
                pushImpl?(controller)
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
    }, updateAutoDelete: {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.GlobalAutoremoveTimeout())
        |> deliverOnMainQueue).start(next: { maybeGlobalAutoremoveTimeout in
            var subItems: [ContextMenuItem] = []
            
            let globalAutoremoveTimeout: Int32 = maybeGlobalAutoremoveTimeout ?? 0
            let currentValue: Int32 = stateValue.with({ $0 }).autoremoveTimeout ?? globalAutoremoveTimeout
            
            let applyValue: (Int32) -> Void = { value in
                updateState { state in
                    var state = state
                    state.autoremoveTimeout = value
                    return state
                }
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Autoremove_OptionOff, icon: { theme in
                if currentValue == 0 {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                } else {
                    return nil
                }
            }, action: { _, f in
                applyValue(0)
                f(.default)
            })))
            subItems.append(.separator)
            
            var presetValues: [Int32] = [
                1 * 24 * 60 * 60,
                7 * 24 * 60 * 60,
                31 * 24 * 60 * 60
            ]
            if currentValue != 0 && !presetValues.contains(currentValue) {
                presetValues.append(currentValue)
                presetValues.sort()
            }
            
            for value in presetValues {
                subItems.append(.action(ContextMenuActionItem(text: timeIntervalString(strings: presentationData.strings, value: value), icon: { theme in
                    if currentValue == value {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    } else {
                        return nil
                    }
                }, action: { _, f in
                    applyValue(value)
                    f(.default)
                })))
            }
            
            subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Autoremove_SetCustomTime, icon: { _ in
                return nil
            }, action: { _, f in
                f(.default)
                
                let controller = ChatTimerScreen(context: context, updatedPresentationData: nil, style: .default, mode: .autoremove, currentTime: currentValue == 0 ? nil : currentValue, dismissByTapOutside: true, completion: { value in
                    applyValue(value)
                })
                endEditingImpl?()
                presentControllerImpl?(controller, nil)
            })))
            
            if let sourceNode = findAutoremoveReferenceNode?() {
                let items: Signal<ContextController.Items, NoError> = .single(ContextController.Items(content: .list(subItems)))
                let source: ContextContentSource = .reference(CreateGroupContextReferenceContentSource(sourceView: sourceNode.labelNode.view))
                
                let contextController = ContextController(
                    account: context.account,
                    presentationData: presentationData,
                    source: source,
                    items: items,
                    gesture: nil
                )
                sourceNode.updateHasContextMenu(hasContextMenu: true)
                contextController.dismissed = { [weak sourceNode] in
                    sourceNode?.updateHasContextMenu(hasContextMenu: false)
                }
                presentInGlobalOverlay?(contextController)
            }
        })
    }, updatePublicLinkText: { text in
        if text.isEmpty {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                var updated = state
                updated.editingPublicLinkText = text
                updated.addressNameValidationStatus = nil
                return updated
            }
        } else {
            updateState { state in
                var updated = state
                updated.editingPublicLinkText = text
                return updated
            }
            
            checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(0))), name: text)
            |> deliverOnMainQueue).start(next: { result in
                updateState { state in
                    var updated = state
                    updated.addressNameValidationStatus = result
                    return updated
                }
            }))
        }
    }, openAuction: { username in
        endEditingImpl?()
        
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://fragment.com/username/\(username)", forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
    })
    
    var requestPeer: ReplyMarkupButtonRequestPeerType.Group?
    if case let .requestPeer(peerType) = mode {
        requestPeer = peerType
    }
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        context.account.postbox.multiplePeersView(peerIds),
        .single(nil) |> then(addressPromise.get()),
        .single(nil) |> then(venuesPromise.get()),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.GlobalAutoremoveTimeout())
    )
    |> map { presentationData, state, view, address, venues, globalAutoremoveTimeout -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let rightNavigationButton: ItemListNavigationButton
        if state.creating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            var isEnabled = true
            if state.editingName.composedTitle.isEmpty {
                isEnabled = false
            }
            if case let .requestPeer(peerType) = mode, let hasUsername = peerType.hasUsername, hasUsername, (state.editingPublicLinkText ?? "").isEmpty {
                isEnabled = false
            }
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Compose_Create), style: .bold, enabled: isEnabled, action: {
                arguments.done()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Compose_NewGroupTitle), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createGroupEntries(presentationData: presentationData, state: state, peerIds: peerIds, view: view, venues: venues, globalAutoremoveTimeout: globalAutoremoveTimeout ?? 0, requestPeer: requestPeer), style: .blocks, focusItemTag: CreateGroupEntryTag.info)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.beganInteractiveDragging = {
        endEditingImpl?()
    }
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
    presentInGlobalOverlay = { [weak controller] c in
        controller?.presentInGlobalOverlay(c, with: nil)
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
    
    findAutoremoveReferenceNode = { [weak controller] in
        guard let controller else {
            return nil
        }
        
        let targetTag: CreateGroupEntryTag = .autoDelete
        var resultItemNode: ItemListItemNode?
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListItemNode {
                if let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                    resultItemNode = itemNode
                    return
                }
            }
        }
        
        if let resultItemNode = resultItemNode as? ItemListDisclosureItemNode {
            return resultItemNode
        } else {
            return nil
        }
    }
    
    selectTitleImpl = { [weak controller] in
        controller?.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                itemNode.selectAll()
            }
        })
    }
    
    return controller
}

private final class CreateGroupContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}
