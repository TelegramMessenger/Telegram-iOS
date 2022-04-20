import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import MergeLists
import AccountContext
import SearchBarNode
import SearchUI
import ItemListPeerItem
import ContactsPeerItem
import ChatListSearchItemHeader
import ChatListUI
import ItemListPeerActionItem
import TelegramStringFormatting

private final class NotificationExceptionState : Equatable {
    let mode: NotificationExceptionMode
    let isSearchMode: Bool
    let revealedPeerId: PeerId?
    let editing: Bool
    
    init(mode: NotificationExceptionMode, isSearchMode: Bool = false, revealedPeerId: PeerId? = nil, editing: Bool = false) {
        self.mode = mode
        self.isSearchMode = isSearchMode
        self.revealedPeerId = revealedPeerId
        self.editing = editing
    }
    
    func withUpdatedMode(_ mode: NotificationExceptionMode) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode, isSearchMode: self.isSearchMode, revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedSearchMode(_ isSearchMode: Bool) -> NotificationExceptionState {
        return NotificationExceptionState(mode: self.mode, isSearchMode: isSearchMode, revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> NotificationExceptionState {
        return NotificationExceptionState(mode: self.mode, isSearchMode: self.isSearchMode, revealedPeerId: self.revealedPeerId, editing: editing)
    }
    
    func withUpdatedRevealedPeerId(_ revealedPeerId: PeerId?) -> NotificationExceptionState {
        return NotificationExceptionState(mode: self.mode, isSearchMode: self.isSearchMode, revealedPeerId: revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerSound(_ peer: Peer, _ sound: PeerMessageSound) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerSound(peer, sound), isSearchMode: isSearchMode, revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerMuteInterval(_ peer: Peer, _ muteInterval: Int32?) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerMuteInterval(peer, muteInterval), isSearchMode: isSearchMode, revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerDisplayPreviews(_ peer: Peer, _ displayPreviews: PeerNotificationDisplayPreviews) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerDisplayPreviews(peer, displayPreviews), isSearchMode: isSearchMode, revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    static func == (lhs: NotificationExceptionState, rhs: NotificationExceptionState) -> Bool {
        return lhs.mode == rhs.mode && lhs.isSearchMode == rhs.isSearchMode && lhs.revealedPeerId == rhs.revealedPeerId && lhs.editing == rhs.editing
    }
}

public struct NotificationExceptionWrapper : Equatable {
    let settings: TelegramPeerNotificationSettings
    let date: TimeInterval?
    let peer: Peer
    init(settings: TelegramPeerNotificationSettings, peer: Peer, date: TimeInterval? = nil) {
        self.settings = settings
        self.date = date
        self.peer = peer
    }
    
    public static func ==(lhs: NotificationExceptionWrapper, rhs: NotificationExceptionWrapper) -> Bool {
        return lhs.settings == rhs.settings && lhs.date == rhs.date
    }
    
    func withUpdatedSettings(_ settings: TelegramPeerNotificationSettings) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: settings, peer: self.peer, date: self.date)
    }
    
    func updateSettings(_ f: (TelegramPeerNotificationSettings) -> TelegramPeerNotificationSettings) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: f(self.settings), peer: self.peer, date: self.date)
    }
    
    
    func withUpdatedDate(_ date: TimeInterval) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: self.settings, peer: self.peer, date: date)
    }
}



public enum NotificationExceptionMode : Equatable {
    fileprivate enum Mode {
        case users
        case groups
        case channels
    }
    
    public static func == (lhs: NotificationExceptionMode, rhs: NotificationExceptionMode) -> Bool {
        switch lhs {
            case let .users(lhsValue):
                if case let .users(rhsValue) = rhs {
                    return lhsValue == rhsValue
                } else {
                    return false
                }
            case let .groups(lhsValue):
                if case let .groups(rhsValue) = rhs {
                    return lhsValue == rhsValue
                } else {
                    return false
                }
            case let .channels(lhsValue):
                if case let .channels(rhsValue) = rhs {
                    return lhsValue == rhsValue
                } else {
                    return false
                }
        }
    }
    
    fileprivate var mode: Mode {
        switch self {
            case .users:
                return .users
            case .groups:
                return .groups
            case .channels:
                return .channels
        }
    }
    
    var isEmpty: Bool {
        switch self {
            case let .users(value), let .groups(value), let .channels(value):
                return value.isEmpty
        }
    }
    
    case users([PeerId : NotificationExceptionWrapper])
    case groups([PeerId : NotificationExceptionWrapper])
    case channels([PeerId : NotificationExceptionWrapper])
    
    func withUpdatedPeerSound(_ peer: Peer, _ sound: PeerMessageSound) -> NotificationExceptionMode {
        let apply:([PeerId : NotificationExceptionWrapper], PeerId, PeerMessageSound) -> [PeerId : NotificationExceptionWrapper] = { values, peerId, sound in
            var values = values
            if let value = values[peerId] {
                switch sound {
                    case .default:
                        switch value.settings.muteState {
                        case .default:
                            values.removeValue(forKey: peerId)
                        default:
                            values[peerId] = value.updateSettings({$0.withUpdatedMessageSound(sound)}).withUpdatedDate(Date().timeIntervalSince1970)
                        }
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedMessageSound(sound)}).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch sound {
                    case .default:
                        break
                    default:
                        values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .default, messageSound: sound, displayPreviews: .default), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
            case let .groups(values):
                return .groups(apply(values, peer.id, sound))
            case let .users(values):
                return .users(apply(values, peer.id, sound))
            case let .channels(values):
                return .channels(apply(values, peer.id, sound))
        }
    }
    
    func withUpdatedPeerMuteInterval(_ peer: Peer, _ muteInterval: Int32?) -> NotificationExceptionMode {
        let apply:([PeerId : NotificationExceptionWrapper], PeerId, PeerMuteState) -> [PeerId : NotificationExceptionWrapper] = { values, peerId, muteState in
            var values = values
            if let value = values[peerId] {
                switch muteState {
                    case .default:
                        switch value.settings.messageSound {
                            case .default:
                                values.removeValue(forKey: peerId)
                            default:
                                values[peerId] = value.updateSettings({$0.withUpdatedMuteState(muteState)}).withUpdatedDate(Date().timeIntervalSince1970)
                        }
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedMuteState(muteState)}).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch muteState {
                    case .default:
                        break
                    default:
                        values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: .default, displayPreviews: .default), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        let muteState: PeerMuteState
        if let muteInterval = muteInterval {
            if muteInterval == 0 {
                muteState = .unmuted
            } else {
                let absoluteUntil: Int32
                if muteInterval == Int32.max {
                    absoluteUntil = Int32.max
                } else {
                    absoluteUntil = muteInterval
                }
                muteState = .muted(until: absoluteUntil)
            }
        } else {
            muteState = .default
        }
        switch self {
            case let .groups(values):
                return .groups(apply(values, peer.id, muteState))
            case let .users(values):
                return .users(apply(values, peer.id, muteState))
            case let .channels(values):
                return .channels(apply(values, peer.id, muteState))
        }
    }
    
    func withUpdatedPeerDisplayPreviews(_ peer: Peer, _ displayPreviews: PeerNotificationDisplayPreviews) -> NotificationExceptionMode {
        let apply:([PeerId : NotificationExceptionWrapper], PeerId, PeerNotificationDisplayPreviews) -> [PeerId : NotificationExceptionWrapper] = { values, peerId, displayPreviews in
            var values = values
            if let value = values[peerId] {
                switch displayPreviews {
                case .default:
                    switch value.settings.displayPreviews {
                    case .default:
                        values.removeValue(forKey: peerId)
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedDisplayPreviews(displayPreviews)}).withUpdatedDate(Date().timeIntervalSince1970)
                    }
                default:
                    values[peerId] = value.updateSettings({$0.withUpdatedDisplayPreviews(displayPreviews)}).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch displayPreviews {
                case .default:
                    break
                default:
                    values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default, displayPreviews: displayPreviews), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
            case let .groups(values):
                return .groups(apply(values, peer.id, displayPreviews))
            case let .users(values):
                return .users(apply(values, peer.id, displayPreviews))
            case let .channels(values):
                return .channels(apply(values, peer.id, displayPreviews))
        }
    }
    
    var peerIds: [PeerId] {
        switch self {
        case let .users(settings), let .groups(settings), let .channels(settings):
            return settings.map {$0.key}
        }
    }
    
    var settings: [PeerId : NotificationExceptionWrapper] {
        switch self {
        case let .users(settings), let .groups(settings), let .channels(settings):
            return settings
        }
    }
}

private func notificationsExceptionEntries(presentationData: PresentationData, notificationSoundList: NotificationSoundList?, state: NotificationExceptionState, query: String? = nil, foundPeers: [RenderedPeer] = []) -> [NotificationExceptionEntry] {
    var entries: [NotificationExceptionEntry] = []
    
    if !state.isSearchMode {
        entries.append(.addException(presentationData.theme, presentationData.strings, state.mode.mode, state.editing))
    }
    
    var existingPeerIds = Set<PeerId>()
    
    var index: Int = 0
    for (_, value) in state.mode.settings.filter({ (_, value) in
        if let query = query, !query.isEmpty {
            return !EnginePeer(value.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).lowercased().components(separatedBy: " ").filter { $0.hasPrefix(query.lowercased())}.isEmpty
        } else {
            return true
        }
    }).sorted(by: { lhs, rhs in
        let lhsName = EnginePeer(lhs.value.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        let rhsName = EnginePeer(rhs.value.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        
        if let lhsDate = lhs.value.date, let rhsDate = rhs.value.date {
            return lhsDate > rhsDate
        } else if lhs.value.date != nil && rhs.value.date == nil {
            return true
        } else if lhs.value.date == nil && rhs.value.date != nil {
            return false
        }
        
        if let lhsPeer = lhs.value.peer as? TelegramUser, let rhsPeer = rhs.value.peer as? TelegramUser {
            if lhsPeer.botInfo != nil && rhsPeer.botInfo == nil {
                return false
            } else if lhsPeer.botInfo == nil && rhsPeer.botInfo != nil {
                return true
            }
        }
        
        return lhsName < rhsName
    }) {
        if !value.peer.isDeleted {
            var title: String
            var muted = false
            switch value.settings.muteState {
                case let .muted(until):
                    if until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                        if until < Int32.max - 1 {
                            let formatter = DateFormatter()
                            formatter.locale = Locale(identifier: presentationData.strings.baseLanguageCode)
                            
                            if Calendar.current.isDateInToday(Date(timeIntervalSince1970: Double(until))) {
                                formatter.dateFormat = "HH:mm"
                            } else {
                                formatter.dateFormat = "E, d MMM HH:mm"
                            }
                            
                            let dateString = formatter.string(from: Date(timeIntervalSince1970: Double(until)))
                            
                            title = presentationData.strings.Notification_Exceptions_MutedUntil(dateString).string
                        } else {
                            muted = true
                            title = presentationData.strings.Notification_Exceptions_AlwaysOff
                        }
                    } else {
                        title = presentationData.strings.Notification_Exceptions_AlwaysOn
                    }
                case .unmuted:
                    title = presentationData.strings.Notification_Exceptions_AlwaysOn
                default:
                    title = ""
            }
            if !muted {
                switch value.settings.messageSound {
                case .default:
                    break
                default:
                    if !title.isEmpty {
                        title.append(", ")
                    }
                    title.append(presentationData.strings.Notification_Exceptions_SoundCustom)
                }
                switch value.settings.displayPreviews {
                    case .default:
                        break
                    default:
                        if !title.isEmpty {
                            title += ", "
                        }
                        if case .show = value.settings.displayPreviews {
                            title += presentationData.strings.Notification_Exceptions_PreviewAlwaysOn
                        } else {
                            title += presentationData.strings.Notification_Exceptions_PreviewAlwaysOff
                        }
                }
            }
            existingPeerIds.insert(value.peer.id)
            entries.append(.peer(index: index, peer: value.peer, theme: presentationData.theme, strings: presentationData.strings, dateFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, description: title, notificationSettings: value.settings, revealed: state.revealedPeerId == value.peer.id, editing: state.editing, isSearching: state.isSearchMode))
            index += 1
        }
    }
    
    if state.isSearchMode {
        for renderedPeer in foundPeers {
            guard let peer = renderedPeer.chatMainPeer else {
                continue
            }
            switch state.mode {
                case .channels:
                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    } else {
                        continue
                    }
                case .groups:
                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    } else if peer is TelegramGroup {
                    } else {
                        continue
                    }
                case .users:
                    if peer is TelegramUser {
                    } else {
                        continue
                    }
            }
            if existingPeerIds.contains(peer.id) {
                continue
            }
            existingPeerIds.insert(peer.id)
            entries.append(.addPeer(index: index, peer: peer, theme: presentationData.theme, strings: presentationData.strings, dateFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder))
            index += 1
        }
    }
    
    if !state.isSearchMode && index != 0 {
        entries.append(.removeAll(presentationData.theme, presentationData.strings))
    }
    
    return entries
}

private final class NotificationExceptionArguments {
    let context: AccountContext
    let activateSearch:()->Void
    let openPeer: (Peer) -> Void
    let selectPeer: ()->Void
    let updateRevealedPeerId:(PeerId?)->Void
    let deletePeer:(Peer) -> Void
    let removeAll:() -> Void
    
    init(context: AccountContext, activateSearch:@escaping() -> Void, openPeer: @escaping(Peer) -> Void, selectPeer: @escaping()->Void, updateRevealedPeerId:@escaping(PeerId?)->Void, deletePeer: @escaping(Peer) -> Void, removeAll:@escaping() -> Void) {
        self.context = context
        self.activateSearch = activateSearch
        self.openPeer = openPeer
        self.selectPeer = selectPeer
        self.updateRevealedPeerId = updateRevealedPeerId
        self.deletePeer = deletePeer
        self.removeAll = removeAll
    }
}

private enum NotificationExceptionEntryId: Hashable {
    case search
    case peerId(Int64)
    case addException
    case removeAll
    
    static func <(lhs: NotificationExceptionEntryId, rhs: NotificationExceptionEntryId) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }
    
    static func ==(lhs: NotificationExceptionEntryId, rhs: NotificationExceptionEntryId) -> Bool {
        switch lhs {
            case .search:
                switch rhs {
                    case .search:
                        return true
                    default:
                        return false
                }
            case .addException:
                switch rhs {
                    case .addException:
                        return true
                    default:
                        return false
                }
            case let .peerId(lhsId):
                switch rhs {
                    case let .peerId(rhsId):
                        return lhsId == rhsId
                    default:
                        return false
                }
            case .removeAll:
                if case .removeAll = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum NotificationExceptionSectionId : ItemListSectionId {
    case general = 0
    case removeAll = 1
}

private enum NotificationExceptionEntry : ItemListNodeEntry {
    var section: ItemListSectionId {
        switch self {
            case .removeAll:
                return NotificationExceptionSectionId.removeAll.rawValue
            default:
                return NotificationExceptionSectionId.general.rawValue
        }
    }
    
    typealias ItemGenerationArguments = NotificationExceptionArguments
    
    case search(PresentationTheme, PresentationStrings)
    case peer(index: Int, peer: Peer, theme: PresentationTheme, strings: PresentationStrings, dateFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, description: String, notificationSettings: TelegramPeerNotificationSettings, revealed: Bool, editing: Bool, isSearching: Bool)
    case addPeer(index: Int, peer: Peer, theme: PresentationTheme, strings: PresentationStrings, dateFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder)
    case addException(PresentationTheme, PresentationStrings, NotificationExceptionMode.Mode, Bool)
    case removeAll(PresentationTheme, PresentationStrings)
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationExceptionArguments
        switch self {
            case let .search(theme, strings):
                return NotificationSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    arguments.activateSearch()
                })
            case let .addException(theme, strings, mode, editing):
                let icon: UIImage?
                switch mode {
                    case .users:
                        icon = PresentationResourcesItemList.addPersonIcon(theme)
                    case .groups:
                        icon = PresentationResourcesItemList.createGroupIcon(theme)
                    case .channels:
                        icon = PresentationResourcesItemList.addChannelIcon(theme)
                }
                return ItemListPeerActionItem(presentationData: presentationData, icon: icon, title: strings.Notification_Exceptions_AddException, alwaysPlain: true, sectionId: self.section, editing: editing, action: {
                    arguments.selectPeer()
                })
            case let .peer(_, peer, _, _, dateTimeFormat, nameDisplayOrder, value, _, revealed, editing, isSearching):
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(peer), presence: nil, text: .text(value, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: true, editing: editing, revealed: revealed), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openPeer(peer)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.updateRevealedPeerId(peerId)
                }, removePeer: { peerId in
                    arguments.deletePeer(peer)
                }, hasTopStripe: false, hasTopGroupInset: false, noInsets: isSearching)
            case let .addPeer(_, peer, theme, strings, _, nameDisplayOrder):
                return ContactsPeerItem(presentationData: presentationData, sortOrder: nameDisplayOrder, displayOrder: nameDisplayOrder, context: arguments.context, peerMode: .peer, peer: .peer(peer: EnginePeer(peer), chatPeer: EnginePeer(peer)), status: .none, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), options: [], actionIcon: .add, index: nil, header: ChatListSearchItemHeader(type: .addToExceptions, theme: theme, strings: strings, actionTitle: nil, action: nil), action: { _ in
                    arguments.openPeer(peer)
                }, setPeerIdWithRevealedOptions: { _, _ in
                })
            case let .removeAll(_, strings):
                return ItemListActionItem(presentationData: presentationData, title: strings.Notification_Exceptions_DeleteAll, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.removeAll()
                })
        }
    }
    
    var stableId: NotificationExceptionEntryId {
        switch self {
            case .search:
                return .search
            case .addException:
                return .addException
            case let .peer(_, peer, _, _, _, _, _, _, _, _, _):
                return .peerId(peer.id.toInt64())
            case let .addPeer(_, peer, _, _, _, _):
                return .peerId(peer.id.toInt64())
            case .removeAll:
                return .removeAll
        }
    }
    
    static func == (lhs: NotificationExceptionEntry, rhs: NotificationExceptionEntry) -> Bool {
        switch lhs {
            case let .search(lhsTheme, lhsStrings):
                switch rhs {
                    case let .search(rhsTheme, rhsStrings):
                        return lhsTheme === rhsTheme && lhsStrings === rhsStrings
                    default:
                        return false
                }
            case let .addException(lhsTheme, lhsStrings, lhsMode, lhsEditing):
                switch rhs {
                    case let .addException(rhsTheme, rhsStrings, rhsMode, rhsEditing):
                        return lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsMode == rhsMode && lhsEditing == rhsEditing
                    default:
                        return false
                }
            case let .peer(lhsIndex, lhsPeer, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsValue, lhsSettings, lhsRevealed, lhsEditing, lhsIsSearching):
                switch rhs {
                    case let .peer(rhsIndex, rhsPeer, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsValue, rhsSettings, rhsRevealed, rhsEditing, rhsIsSearching):
                        return lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsDateTimeFormat == rhsDateTimeFormat && lhsNameOrder == rhsNameOrder && lhsIndex == rhsIndex && lhsPeer.isEqual(rhsPeer) && lhsValue == rhsValue && lhsSettings == rhsSettings && lhsRevealed == rhsRevealed && lhsEditing == rhsEditing && lhsIsSearching == rhsIsSearching
                    default:
                        return false
                }
            case let .addPeer(lhsIndex, lhsPeer, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder):
                switch rhs {
                    case let .addPeer(rhsIndex, rhsPeer, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder):
                        return lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsDateTimeFormat == rhsDateTimeFormat && lhsNameOrder == rhsNameOrder && lhsIndex == rhsIndex && lhsPeer.isEqual(rhsPeer)
                    default:
                        return false
                }
            case let .removeAll(lhsTheme, lhsStrings):
                if case let .removeAll(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: NotificationExceptionEntry, rhs: NotificationExceptionEntry) -> Bool {
        switch lhs {
            case .search:
                return true
            case .addException:
                switch rhs {
                    case .search, .addException:
                        return false
                    default:
                        return true
                }
            case let .peer(lhsIndex, _, _, _, _, _, _, _, _, _, _):
                switch rhs {
                    case .search, .addException:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    case let .addPeer(rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    case .removeAll:
                        return true
                }
            case let .addPeer(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .search, .addException:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    case let .addPeer(rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    case .removeAll:
                        return true
                }
            case .removeAll:
                return false
        }
    }
}

private struct NotificationExceptionNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let firstTime: Bool
    let animated: Bool
}

private func preparedExceptionsListNodeTransition(presentationData: ItemListPresentationData, from fromEntries: [NotificationExceptionEntry], to toEntries: [NotificationExceptionEntry], arguments: NotificationExceptionArguments, firstTime: Bool, forceUpdate: Bool, animated: Bool) -> NotificationExceptionNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, arguments: arguments), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, arguments: arguments), directionHint: nil) }
    
    return NotificationExceptionNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, animated: animated)
}

private extension PeerMuteState {
    var timeInterval: Int32? {
        switch self {
            case .default:
                return nil
            case .unmuted:
                return 0
            case let .muted(until):
                return until
        }
    }
}

final class NotificationExceptionsControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let navigationBar: NavigationBar
    private let requestActivateSearch: () -> Void
    private let requestDeactivateSearch: (Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    private let pushController: (ViewController) -> Void
    private var didSetReady = false
    let _ready = ValuePromise<Bool>()
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    let listNode: ListView
    private var queuedTransitions: [NotificationExceptionNodeTransition] = []
    
    private var searchDisplayController: SearchDisplayController?
    
    private let presentationDataValue = Promise<(PresentationTheme, PresentationStrings)>()
    private var listDisposable: Disposable?
    private var fetchedSoundsDisposable: Disposable?
    
    private var arguments: NotificationExceptionArguments?
    private let stateValue: Atomic<NotificationExceptionState>
    private let statePromise: ValuePromise<NotificationExceptionState> = ValuePromise(ignoreRepeated: true)
    private let navigationActionDisposable = MetaDisposable()
    private let updateNotificationsDisposable = MetaDisposable()

    func addPressed() {
        self.arguments?.selectPeer()
    }
    
    init(context: AccountContext, presentationData: PresentationData, navigationBar: NavigationBar, mode: NotificationExceptionMode, updatedMode:@escaping(NotificationExceptionMode)->Void, requestActivateSearch: @escaping () -> Void, requestDeactivateSearch: @escaping (Bool) -> Void, updateCanStartEditing: @escaping (Bool?) -> Void, present: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataValue.set(.single((presentationData.theme, presentationData.strings)))
        self.navigationBar = navigationBar
        self.requestActivateSearch = requestActivateSearch
        self.requestDeactivateSearch = requestDeactivateSearch
        self.present = present
        self.pushController = pushController
        self.stateValue = Atomic(value: NotificationExceptionState(mode: mode))
        self.listNode = ListView()
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        let stateValue = self.stateValue
        let statePromise = self.statePromise
        statePromise.set(NotificationExceptionState(mode: mode))
        
        let updateState: ((NotificationExceptionState) -> NotificationExceptionState) -> Void = {  f in
            let result = stateValue.modify { f($0) }
            statePromise.set(result)
            updatedMode(result.mode)
        }
        
        let updateNotificationsDisposable = self.updateNotificationsDisposable
        var peerIds: Set<PeerId> = Set(mode.peerIds)
        
        let updateNotificationsView: (@escaping () -> Void) -> Void = { completion in
            updateState { current in
                peerIds = peerIds.union(current.mode.peerIds)
                let key: PostboxViewKey = .peerNotificationSettings(peerIds: peerIds)
                updateNotificationsDisposable.set((context.account.postbox.combinedView(keys: [key])
                |> deliverOnMainQueue).start(next: { view in
                    if let view = view.views[key] as? PeerNotificationSettingsView {
                        _ = context.account.postbox.transaction { transaction in
                            updateState { current in
                                var current = current
                                for (key, value) in view.notificationSettings {
                                    if let value = value as? TelegramPeerNotificationSettings {
                                        if let local = current.mode.settings[key]  {
                                            if !value.isEqual(to: local.settings), let peer = transaction.getPeer(key), let settings = transaction.getPeerNotificationSettings(key) as? TelegramPeerNotificationSettings, !settings.isEqual(to: local.settings) {
                                                current = current.withUpdatedPeerSound(peer, settings.messageSound).withUpdatedPeerMuteInterval(peer, settings.muteState.timeInterval).withUpdatedPeerDisplayPreviews(peer, settings.displayPreviews)
                                            }
                                        } else if let peer = transaction.getPeer(key) {
                                            if case .default = value.messageSound, case .unmuted = value.muteState, case .default = value.displayPreviews {
                                            } else {
                                                current = current.withUpdatedPeerSound(peer, value.messageSound).withUpdatedPeerMuteInterval(peer, value.muteState.timeInterval).withUpdatedPeerDisplayPreviews(peer, value.displayPreviews)
                                            }
                                        }
                                    }
                                }
                                return current
                            }
                        }.start(completed: {
                            completion()
                        })
                    } else {
                        completion()
                    }
                }))
                return current
            }
        }
        
        updateNotificationsView({})
        
        var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
        var dismissInputImpl: (() -> Void)?
        
        let presentationData = context.sharedContext.currentPresentationData.modify {$0}
        
        let updatePeerSound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
            return context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, sound: sound) |> deliverOnMainQueue
        }
        
        let updatePeerNotificationInterval: (PeerId, Int32?) -> Signal<Void, NoError> = { peerId, muteInterval in
            return context.engine.peers.updatePeerMuteSetting(peerId: peerId, muteInterval: muteInterval) |> deliverOnMainQueue
        }
        
        let updatePeerDisplayPreviews:(PeerId, PeerNotificationDisplayPreviews) -> Signal<Void, NoError> = {
            peerId, displayPreviews in
            return context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, displayPreviews: displayPreviews) |> deliverOnMainQueue
        }
        
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.addSubnode(self.listNode)
        
        let openSearch: () -> Void = {
            requestActivateSearch()
        }
        
        let presentPeerSettings: (PeerId, @escaping () -> Void) -> Void = { [weak self] peerId, completion in
            (self?.searchDisplayController?.contentNode as? NotificationExceptionsSearchContainerNode)?.listNode.clearHighlightAnimated(true)
            
            let _ = (context.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            |> deliverOnMainQueue).start(next: { peer in
                completion()
                
                guard let peer = peer else {
                    return
                }
                
                let mode = stateValue.with { $0.mode }
                
                dismissInputImpl?()
                presentControllerImpl?(notificationPeerExceptionController(context: context, peer: peer, mode: mode, updatePeerSound: { peerId, sound in
                    _ = updatePeerSound(peer.id, sound).start(next: { _ in
                        updateNotificationsDisposable.set(nil)
                        _ = combineLatest(updatePeerSound(peer.id, sound), context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { _, peer in
                            updateState { value in
                                return value.withUpdatedPeerSound(peer, sound)
                            }
                            updateNotificationsView({})
                        })
                    })
                }, updatePeerNotificationInterval: { peerId, muteInterval in
                    updateNotificationsDisposable.set(nil)
                    _ = combineLatest(updatePeerNotificationInterval(peerId, muteInterval), context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { _, peer in
                        updateState { value in
                            return value.withUpdatedPeerMuteInterval(peer, muteInterval)
                        }
                        updateNotificationsView({})
                    })
                }, updatePeerDisplayPreviews: { peerId, displayPreviews in
                    updateNotificationsDisposable.set(nil)
                    _ = combineLatest(updatePeerDisplayPreviews(peerId, displayPreviews), context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { _, peer in
                        updateState { value in
                            return value.withUpdatedPeerDisplayPreviews(peer, displayPreviews)
                        }
                        updateNotificationsView({})
                    })
                }, removePeerFromExceptions: {
                    let _ = (context.engine.peers.removeCustomNotificationSettings(peerIds: [peerId])
                    |> map { _ -> Peer? in }
                    |> then(context.account.postbox.transaction { transaction -> Peer? in
                        return transaction.getPeer(peerId)
                    })).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        updateState { value in
                            return value.withUpdatedPeerDisplayPreviews(peer, .default).withUpdatedPeerSound(peer, .default).withUpdatedPeerMuteInterval(peer, nil)
                        }
                        updateNotificationsView({})
                    })
                }, modifiedPeer: {
                    requestDeactivateSearch(false)
                }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        }
        
        let arguments = NotificationExceptionArguments(context: context, activateSearch: {
            openSearch()
        }, openPeer: { peer in
            presentPeerSettings(peer.id, {})
            /*if let strongSelf = self {
                _ = (strongSelf.context.account.postbox.transaction { transaction in
                    if transaction.getPeer(peer.id) == nil {
                        updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                            return updatedPeer
                        })
                    }
                } |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                        if let strongSelf = strongSelf, let infoController = peerInfoController(context: strongSelf.context, peer: peer) {
                            strongSelf.pushController(infoController)
                            strongSelf.requestDeactivateSearch()
                        }
                })
            }*/
        }, selectPeer: {
            var filter: ChatListNodePeersFilter = [.excludeRecent, .doNotSearchMessages, .removeSearchHeader]
            switch mode {
                case .groups:
                    filter.insert(.onlyGroups)
                case .users:
                    filter.insert(.onlyPrivateChats)
                    filter.insert(.excludeSavedMessages)
                    filter.insert(.excludeSecretChats)
                case .channels:
                    filter.insert(.onlyChannels)
            }
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter, hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
            controller.peerSelected = { [weak controller] peer in
                let peerId = peer.id
                
                presentPeerSettings(peerId, {
                    controller?.dismiss()
                })
            }
            dismissInputImpl?()
            pushController(controller)
        }, updateRevealedPeerId: { peerId in
            updateState { current in
                return current.withUpdatedRevealedPeerId(peerId)
            }
        }, deletePeer: { peer in
            _ = (context.account.postbox.transaction { transaction in
                if transaction.getPeer(peer.id) == nil {
                    updatePeers(transaction: transaction, peers: [peer], update: { _, updated in return updated})
                }
            } |> deliverOnMainQueue).start(completed: {
                updateNotificationsDisposable.set(nil)
                updateState { value in
                    return value.withUpdatedPeerMuteInterval(peer, nil).withUpdatedPeerSound(peer, .default).withUpdatedPeerDisplayPreviews(peer, .default)
                }
                let _ = (context.engine.peers.removeCustomNotificationSettings(peerIds: [peer.id])
                |> deliverOnMainQueue).start(completed: {
                    updateNotificationsView({})
                })
            })
        }, removeAll: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.Notification_Exceptions_DeleteAllConfirmation),
                ActionSheetButtonItem(title: presentationData.strings.Notification_Exceptions_DeleteAll, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    let values = stateValue.with { $0.mode.settings.values }
                    let _ = (context.account.postbox.transaction { transaction -> Void in
                        for value in values {
                            if transaction.getPeer(value.peer.id) == nil {
                                updatePeers(transaction: transaction, peers: [value.peer], update: { _, updated in
                                    updated
                                })
                            }
                        }
                    }
                    |> deliverOnMainQueue).start(completed: {
                        updateNotificationsDisposable.set(nil)
                        updateState { state in
                            var state = state
                            for value in values {
                                state = state.withUpdatedPeerMuteInterval(value.peer, nil).withUpdatedPeerSound(value.peer, .default).withUpdatedPeerDisplayPreviews(value.peer, .default)
                            }
                            return state
                        }
                        let _ = (context.engine.peers.removeCustomNotificationSettings(peerIds: values.map(\.peer.id))
                        |> deliverOnMainQueue).start(completed: {
                            updateNotificationsView({})
                        })
                    })
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            dismissInputImpl?()
            presentControllerImpl?(actionSheet, nil)
        })
        
        self.arguments = arguments
        
        presentControllerImpl = { [weak self] c, a in
            self?.present(c, a)
        }
        
        dismissInputImpl = { [weak self] in
            self?.view.endEditing(true)
        }
        
        let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
        
        let previousEntriesHolder = Atomic<([NotificationExceptionEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        
        self.listDisposable = (combineLatest(context.sharedContext.presentationData, statePromise.get(), preferences, context.engine.peers.notificationSoundList()) |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, prefs, notificationSoundList in
            let entries = notificationsExceptionEntries(presentationData: presentationData, notificationSoundList: notificationSoundList, state: state)
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))

            updateCanStartEditing(state.mode.peerIds.isEmpty ? nil : state.editing)
            
            var animated = true
            if let _ = previousEntriesAndPresentationData {
            } else {
                animated = false
            }
            
            let transition = preparedExceptionsListNodeTransition(presentationData: ItemListPresentationData(presentationData), from: previousEntriesAndPresentationData?.0 ?? [], to: entries, arguments: arguments, firstTime: previousEntriesAndPresentationData == nil, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings, animated: animated)
            
            self?.listNode.keepTopItemOverscrollBackground = entries.count <= 1 ? nil : ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
            
            
            self?.enqueueTransition(transition)
        })
        
        self.fetchedSoundsDisposable = ensureDownloadedNotificationSoundList(postbox: context.account.postbox).start()
    }
    
    deinit {
        self.listDisposable?.dispose()
        self.navigationActionDisposable.dispose()
        self.updateNotificationsDisposable.dispose()
        self.fetchedSoundsDisposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationDataValue.set(.single((presentationData.theme, presentationData.strings)))
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
        self.searchDisplayController?.updatePresentationData(self.presentationData)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        var listInsets = layout.insets(options: [.input])
        listInsets.top += navigationBarHeight
        listInsets.left += layout.safeInsets.left
        listInsets.right += layout.safeInsets.right
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        headerInsets.left += layout.safeInsets.left
        headerInsets.right += layout.safeInsets.right
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: listInsets, headerInsets: headerInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: NotificationExceptionNodeTransition) {
        self.queuedTransitions.append(transition)
        
        if self.containerLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        if self.containerLayout != nil {
            while !self.queuedTransitions.isEmpty {
                let transition = self.queuedTransitions.removeFirst()
                
                var options = ListViewDeleteAndInsertOptions()
                if transition.firstTime {
                    options.insert(.Synchronous)
                    options.insert(.LowLatency)
                } else if transition.animated {
                    options.insert(.Synchronous)
                    options.insert(.AnimateInsertion)
                }
                self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
                    if let strongSelf = self {
                        if !strongSelf.didSetReady {
                            strongSelf.didSetReady = true
                            strongSelf._ready.set(true)
                        }
                    }
                })
                
            }
        }
    }
    
    func toggleEditing() {
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(!$0.editing).withUpdatedRevealedPeerId(nil)}))
    }
    
    func removeAll() {
        self.arguments?.removeAll()
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight, _) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: NotificationExceptionsSearchContainerNode(context: self.context, mode: self.stateValue.modify {$0}.mode, arguments: self.arguments!), cancel: { [weak self] in
            self?.requestDeactivateSearch(true)
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: strongSelf.navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}


private struct NotificationExceptionsSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func preparedNotificationExceptionsSearchContainerTransition(presentationData: ItemListPresentationData, from fromEntries: [NotificationExceptionEntry], to toEntries: [NotificationExceptionEntry], arguments: NotificationExceptionArguments, isSearching: Bool, forceUpdate: Bool) -> NotificationExceptionsSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, arguments: arguments), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, arguments: arguments), directionHint: nil) }
    
    return NotificationExceptionsSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}


private final class NotificationExceptionsSearchContainerNode: SearchDisplayControllerContentNode {
    private let dimNode: ASDisplayNode
    let listNode: ListView
    
    private var enqueuedTransitions: [NotificationExceptionsSearchContainerTransition] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let updateNotificationsDisposable = MetaDisposable()
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    public override var hasDim: Bool {
        return true
    }
    
    init(context: AccountContext, mode: NotificationExceptionMode, arguments: NotificationExceptionArguments) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        let initialState = NotificationExceptionState(mode: mode, isSearchMode: true)
        let statePromise: ValuePromise<NotificationExceptionState> = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue:Atomic<NotificationExceptionState> = Atomic(value: initialState)
        
        let updateState: ((NotificationExceptionState) -> NotificationExceptionState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let updateNotificationsDisposable = self.updateNotificationsDisposable
        
        let updateNotificationsView: (@escaping () -> Void) -> Void = { completion in
            let key: PostboxViewKey = .peerNotificationSettings(peerIds: Set(mode.peerIds))
            
            updateNotificationsDisposable.set(context.account.postbox.combinedView(keys: [key]).start(next: { view in
                if let view = view.views[key] as? PeerNotificationSettingsView {
                    _ = context.account.postbox.transaction { transaction in
                        updateState { current in
                            var current = current
                            for (key, value) in view.notificationSettings {
                                if let value = value as? TelegramPeerNotificationSettings,let local = current.mode.settings[key] {
                                    if !value.isEqual(to: local.settings), let peer = transaction.getPeer(key), let settings = transaction.getPeerNotificationSettings(key) as? TelegramPeerNotificationSettings, !settings.isEqual(to: local.settings) {
                                        current = current.withUpdatedPeerSound(peer, settings.messageSound).withUpdatedPeerMuteInterval(peer, settings.muteState.timeInterval)
                                    }
                                }
                            }
                            return current
                        }
                    }.start(completed: {
                        completion()
                    })
                } else {
                    completion()
                }
            }))
        }
        
        updateNotificationsView({})
    
        let searchQuery = self.searchQuery.get()
        
        let stateAndPeers:Signal<(NotificationExceptionState, String?), NoError> = statePromise.get() |> mapToSignal { state -> Signal<(NotificationExceptionState, String?), NoError> in
            return searchQuery |> map { query -> (NotificationExceptionState, String?) in
                return (state, query)
            }
            
        }
        
        let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
        
        let previousEntriesHolder = Atomic<([NotificationExceptionEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        
        let stateQuery = stateAndPeers
        |> map { stateAndPeers -> String? in
            return stateAndPeers.1
        }
        |> distinctUntilChanged
        
        let searchSignal = stateQuery
        |> mapToSignal { query -> Signal<(PresentationData, NotificationSoundList?, (NotificationExceptionState, String?), PreferencesView, [RenderedPeer]), NoError> in
            var contactsSignal: Signal<[RenderedPeer], NoError> = .single([])
            if let query = query {
                contactsSignal = context.account.postbox.searchPeers(query: query)
            }
            return combineLatest(context.sharedContext.presentationData, context.engine.peers.notificationSoundList(), stateAndPeers, preferences, contactsSignal)
        }
        self.searchDisposable.set((searchSignal
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, notificationSoundList, state, prefs, foundPeers in
            let entries = notificationsExceptionEntries(presentationData: presentationData, notificationSoundList: notificationSoundList, state: state.0, query: state.1, foundPeers: foundPeers)
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            
            let transition = preparedNotificationExceptionsSearchContainerTransition(presentationData: ItemListPresentationData(presentationData), from: previousEntriesAndPresentationData?.0 ?? [], to: entries, arguments: arguments, isSearching: state.1 != nil && !state.1!.isEmpty, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings)
            
            self?.enqueueTransition(transition)
        }))
        
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                    strongSelf.themeAndStringsPromise.set(.single((presentationData.theme, presentationData.strings)))
                }
            }
        })
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.updateNotificationsDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: NotificationExceptionsSearchContainerTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
                self?.dimNode.isHidden = isSearching
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.hasValidLayout {
            self.hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}
