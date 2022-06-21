import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import ItemListAvatarAndNameInfoItem

private final class ChannelBannedMemberControllerArguments {
    let context: AccountContext
    let toggleRight: (TelegramChatBannedRightsFlags, Bool) -> Void
    let toggleRightWhileDisabled: (TelegramChatBannedRightsFlags) -> Void
    let openTimeout: () -> Void
    let delete: () -> Void
    
    init(context: AccountContext, toggleRight: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, toggleRightWhileDisabled: @escaping (TelegramChatBannedRightsFlags) -> Void, openTimeout: @escaping () -> Void, delete: @escaping () -> Void) {
        self.context = context
        self.toggleRight = toggleRight
        self.toggleRightWhileDisabled = toggleRightWhileDisabled
        self.openTimeout = openTimeout
        self.delete = delete
    }
}

private enum ChannelBannedMemberSection: Int32 {
    case info
    case rights
    case timeout
    case delete
}

private enum ChannelBannedMemberEntryStableId: Hashable {
    case info
    case rightsHeader
    case right(TelegramChatBannedRightsFlags)
    case timeout
    case exceptionInfo
    case delete
}

private enum ChannelBannedMemberEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, TelegramUserPresence?)
    case rightsHeader(PresentationTheme, String)
    case rightItem(PresentationTheme, Int, String, TelegramChatBannedRightsFlags, Bool, Bool)
    case timeout(PresentationTheme, String, String)
    case exceptionInfo(PresentationTheme, String)
    case delete(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return ChannelBannedMemberSection.info.rawValue
            case .rightsHeader, .rightItem:
                return ChannelBannedMemberSection.rights.rawValue
            case .timeout, .exceptionInfo:
                return ChannelBannedMemberSection.timeout.rawValue
            case .delete:
                return ChannelBannedMemberSection.delete.rawValue
        }
    }
    
    var stableId: ChannelBannedMemberEntryStableId {
        switch self {
            case .info:
                return .info
            case .rightsHeader:
                return .rightsHeader
            case let .rightItem(_, _, _, right, _, _):
                return .right(right)
            case .timeout:
                return .timeout
            case .exceptionInfo:
                return .exceptionInfo
            case .delete:
                return .delete
        }
    }
    
    static func ==(lhs: ChannelBannedMemberEntry, rhs: ChannelBannedMemberEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsPresence):
                if case let .info(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsPresence) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if !arePeersEqual(lhsPeer, rhsPeer) {
                        return false
                    }
                    if lhsPresence != rhsPresence {
                        return false
                    }
                    
                    return true
                } else {
                    return false
                }
            case let .rightsHeader(theme, title):
                if case .rightsHeader(theme, title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .rightItem(lhsTheme, lhsIndex, lhsText, lhsRight, lhsValue, lhsEnabled):
                if case let .rightItem(rhsTheme, rhsIndex, rhsText, rhsRight, rhsValue, rhsEnabled) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsText != rhsText {
                        return false
                    }
                    if lhsRight != rhsRight {
                        return false
                    }
                    if lhsValue != rhsValue {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .timeout(lhsTheme, lhsText, lhsValue):
                if case let .timeout(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .exceptionInfo(theme, title):
                if case .exceptionInfo(theme, title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .delete(theme, title):
                if case .delete(theme, title) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelBannedMemberEntry, rhs: ChannelBannedMemberEntry) -> Bool {
        switch lhs {
            case .info:
                switch rhs {
                    case .info:
                        return false
                    default:
                        return true
                }
            case .rightsHeader:
                switch rhs {
                    case .info, .rightsHeader:
                        return false
                    default:
                        return true
                }
            case let .rightItem(_, lhsIndex, _, _, _, _):
                switch rhs {
                    case .info, .rightsHeader:
                        return false
                    case let .rightItem(_, rhsIndex, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
                }
            case .timeout:
                switch rhs {
                    case .delete, .exceptionInfo:
                        return true
                    default:
                        return false
                }
            case .exceptionInfo:
                switch rhs {
                    case .delete:
                        return true
                    default:
                        return false
                }
            case .delete:
                return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelBannedMemberControllerArguments
        switch self {
            case let .info(_, _, dateTimeFormat, peer, presence):
                return ItemListAvatarAndNameInfoItem(accountContext: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, mode: .generic, peer: EnginePeer(peer), presence: presence.flatMap(EnginePeer.Presence.init), memberCount: nil, state: ItemListAvatarAndNameInfoItemState(), sectionId: self.section, style: .blocks(withTopInset: true, withExtendedBottomInset: false), editingNameUpdated: { _ in
                }, avatarTapped: {
                })
            case let .rightsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .rightItem(_, _, text, right, value, enabled):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, type: .icon, enableInteractiveChanges: enabled, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleRight(right, value)
                }, activatedWhileDisabled: {
                    arguments.toggleRightWhileDisabled(right)
                })
            case let .timeout(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openTimeout()
                })
            case let .exceptionInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .delete(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.delete()
                })
        }
    }
}

private struct ChannelBannedMemberControllerState: Equatable {
    var referenceTimestamp: Int32
    var updatedFlags: TelegramChatBannedRightsFlags?
    var updatedTimeout: Int32?
    var updating: Bool = false
}

func completeRights(_ flags: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    var result = flags
    result.remove(.banReadMessages)
    if result.contains(.banSendGifs) {
        result.insert(.banSendStickers)
        result.insert(.banSendGifs)
        result.insert(.banSendGames)
        result.insert(.banSendInline)
    } else {
        result.remove(.banSendStickers)
        result.remove(.banSendGifs)
        result.remove(.banSendGames)
        result.remove(.banSendInline)
    }
    return result
}

private func channelBannedMemberControllerEntries(presentationData: PresentationData, state: ChannelBannedMemberControllerState, accountPeerId: PeerId, channelView: PeerView, memberView: PeerView, initialParticipant: ChannelParticipant?, initialBannedBy: Peer?) -> [ChannelBannedMemberEntry] {
    var entries: [ChannelBannedMemberEntry] = []
    
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel, let _ = channelView.cachedData as? CachedChannelData, let defaultBannedRights = channel.defaultBannedRights, let member = memberView.peers[memberView.peerId] {
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, member, memberView.peerPresences[member.id] as? TelegramUserPresence))
            
        let currentRightsFlags: TelegramChatBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = defaultBannedRights.flags
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentTimeout = banInfo.rights.untilDate
        } else {
            currentTimeout = Int32.max
        }
        
        let currentTimeoutString: String
        if currentTimeout == 0 || currentTimeout == Int32.max {
            currentTimeoutString = presentationData.strings.MessageTimer_Forever
        } else {
            let remainingTimeout = currentTimeout - state.referenceTimestamp
            currentTimeoutString = timeIntervalString(strings: presentationData.strings, value: remainingTimeout)
        }
        
        entries.append(.rightsHeader(presentationData.theme, presentationData.strings.GroupPermission_SectionTitle))
        
        var index = 0
        for (right, _) in allGroupPermissionList {
            let defaultEnabled = !defaultBannedRights.flags.contains(right) && channel.hasPermission(.banMembers)
            entries.append(.rightItem(presentationData.theme, index, stringForGroupPermission(strings: presentationData.strings, right: right), right, defaultEnabled && !currentRightsFlags.contains(right), defaultEnabled && !state.updating))
            index += 1
        }
        
        entries.append(.timeout(presentationData.theme, presentationData.strings.GroupPermission_Duration, currentTimeoutString))
        
        if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo?, _) = initialParticipant, let initialBannedBy = initialBannedBy {
            entries.append(.exceptionInfo(presentationData.theme, presentationData.strings.GroupPermission_AddedInfo(EnginePeer(initialBannedBy).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), stringForRelativeSymbolicTimestamp(strings: presentationData.strings, relativeTimestamp: banInfo.timestamp, relativeTo: state.referenceTimestamp, dateTimeFormat: presentationData.dateTimeFormat)).string))
            entries.append(.delete(presentationData.theme, presentationData.strings.GroupPermission_Delete))
        }
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup, let member = memberView.peers[memberView.peerId] {
        let defaultBannedRightsFlags = group.defaultBannedRights?.flags ?? []
        
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, member, memberView.peerPresences[member.id] as? TelegramUserPresence))
        
        let currentRightsFlags: TelegramChatBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = defaultBannedRightsFlags
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentTimeout = banInfo.rights.untilDate
        } else {
            currentTimeout = Int32.max
        }
        
        let currentTimeoutString: String
        if currentTimeout == 0 || currentTimeout == Int32.max {
            currentTimeoutString = presentationData.strings.MessageTimer_Forever
        } else {
            let remainingTimeout = currentTimeout - state.referenceTimestamp
            currentTimeoutString = timeIntervalString(strings: presentationData.strings, value: remainingTimeout)
        }
        
        entries.append(.rightsHeader(presentationData.theme, presentationData.strings.GroupPermission_SectionTitle))
        
        var index = 0
        for (right, _) in allGroupPermissionList {
            let defaultEnabled = !defaultBannedRightsFlags.contains(right)
            entries.append(.rightItem(presentationData.theme, index, stringForGroupPermission(strings: presentationData.strings, right: right), right, defaultEnabled && !currentRightsFlags.contains(right), defaultEnabled && !state.updating))
            index += 1
        }
        
        entries.append(.timeout(presentationData.theme, presentationData.strings.GroupPermission_Duration, currentTimeoutString))
        
        if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo?, _) = initialParticipant, let initialBannedBy = initialBannedBy {
            entries.append(.exceptionInfo(presentationData.theme, presentationData.strings.GroupPermission_AddedInfo(EnginePeer(initialBannedBy).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), stringForRelativeSymbolicTimestamp(strings: presentationData.strings, relativeTimestamp: banInfo.timestamp, relativeTo: state.referenceTimestamp, dateTimeFormat: presentationData.dateTimeFormat)).string))
            entries.append(.delete(presentationData.theme, presentationData.strings.GroupPermission_Delete))
        }
    }
    
    return entries
}

public func channelBannedMemberController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, memberId: PeerId, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChatBannedRights?) -> Void, upgradedToSupergroup: @escaping (PeerId, @escaping () -> Void) -> Void) -> ViewController {
    let initialState = ChannelBannedMemberControllerState(referenceTimestamp: Int32(Date().timeIntervalSince1970), updatedFlags: nil, updatedTimeout: nil, updating: false)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChannelBannedMemberControllerState) -> ChannelBannedMemberControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateRightsDisposable = MetaDisposable()
    actionsDisposable.add(updateRightsDisposable)
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let peerView = Promise<PeerView>()
    peerView.set(context.account.viewTracker.peerView(peerId))
    
    let arguments = ChannelBannedMemberControllerArguments(context: context, toggleRight: { rights, value in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            var defaultBannedRightsFlagsValue: TelegramChatBannedRightsFlags?
            guard let peer = view.peers[peerId] else {
                return
            }
            if let channel = peer as? TelegramChannel, let initialRightFlags = channel.defaultBannedRights?.flags {
                defaultBannedRightsFlagsValue = initialRightFlags
            } else if let group = peer as? TelegramGroup, let initialRightFlags = group.defaultBannedRights?.flags {
                defaultBannedRightsFlagsValue = initialRightFlags
            }
            guard let defaultBannedRightsFlags = defaultBannedRightsFlagsValue else {
                return
            }
            
            updateState { state in
                var state = state
                var effectiveRightsFlags: TelegramChatBannedRightsFlags
                if let updatedFlags = state.updatedFlags {
                    effectiveRightsFlags = updatedFlags
                } else if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo?, _) = initialParticipant {
                    effectiveRightsFlags = banInfo.rights.flags
                } else {
                    effectiveRightsFlags = defaultBannedRightsFlags
                }
                if value {
                    effectiveRightsFlags.remove(rights)
                    effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                } else {
                    effectiveRightsFlags.insert(rights)
                    for (right, _) in allGroupPermissionList {
                        if groupPermissionDependencies(right).contains(rights) {
                            effectiveRightsFlags.insert(right)
                        }
                    }
                }
                state.updatedFlags = effectiveRightsFlags
                return state
            }
        })
    }, toggleRightWhileDisabled: { right in
        let _ = (peerView.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            guard let channel = view.peers[view.peerId] as? TelegramChannel else {
                return
            }
            guard let defaultBannedRights = channel.defaultBannedRights else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let text: String
            if channel.hasPermission(.banMembers) {
                if defaultBannedRights.flags.contains(right) {
                    text = presentationData.strings.GroupPermission_PermissionDisabledByDefault
                } else {
                    text = presentationData.strings.GroupPermission_PermissionGloballyDisabled
                }
            } else {
                text = presentationData.strings.GroupPermission_EditingDisabled
            }
            presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        })
    }, openTimeout: {
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let intervals: [Int32] = [
            1 * 60 * 60 * 24,
            7 * 60 * 60 * 24,
            30 * 60 * 60 * 24
        ]
        let applyValue: (Int32?) -> Void = { value in
            updateState { state in
                var state = state
                state.updatedTimeout = value
                return state
            }
        }
        var items: [ActionSheetItem] = []
        for interval in intervals {
            items.append(ActionSheetButtonItem(title: timeIntervalString(strings: presentationData.strings, value: interval), color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                applyValue(initialState.referenceTimestamp + interval)
            }))
        }
        items.append(ActionSheetButtonItem(title: presentationData.strings.MessageTimer_Forever, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            applyValue(Int32.max)
        }))
        items.append(ActionSheetButtonItem(title: presentationData.strings.MessageTimer_Custom, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            presentControllerImpl?(PeerBanTimeoutController(context: context, updatedPresentationData: updatedPresentationData, currentValue: Int32(Date().timeIntervalSince1970), applyValue: { value in
                applyValue(value)
            }), nil)
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, delete: {
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: presentationData.strings.GroupPermission_Delete, color: .destructive, font: .default, enabled: true, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            updateState { state in
                var state = state
                state.updating = true
                return state
            }
            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: nil)
                |> deliverOnMainQueue).start(error: { _ in
                    
                }, completed: {
                    updated(nil)
                    dismissImpl?()
                }))
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    })
    
    var keys: [PostboxViewKey] = [.peer(peerId: peerId, components: .all), .peer(peerId: memberId, components: .all)]
    if let banInfo = initialParticipant?.banInfo {
        keys.append(.peer(peerId: banInfo.restrictedBy, components: []))
    }
    let combinedView = context.account.postbox.combinedView(keys: keys)
    
    let canEdit = true
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(presentationData, statePromise.get(), combinedView)
    |> deliverOnMainQueue
    |> map { presentationData, state, combinedView -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let channelView = combinedView.views[.peer(peerId: peerId, components: .all)] as! PeerView
        let memberView = combinedView.views[.peer(peerId: memberId, components: .all)] as! PeerView
        var initialBannedByPeer: Peer?
        if let banInfo = initialParticipant?.banInfo {
            initialBannedByPeer = (combinedView.views[.peer(peerId: banInfo.restrictedBy, components: [])] as? PeerView)?.peers[banInfo.restrictedBy]
        }
        
        let leftNavigationButton: ItemListNavigationButton
        leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        var rightNavigationButton: ItemListNavigationButton?
        if state.updating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.GroupPermission_ApplyAlertAction), style: .bold, enabled: true, action: {
                let _ = (peerView.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { view in
                    var defaultBannedRightsFlagsValue: TelegramChatBannedRightsFlags?
                    guard let peer = view.peers[peerId] else {
                        return
                    }
                    if let channel = peer as? TelegramChannel, let initialRightFlags = channel.defaultBannedRights?.flags {
                        defaultBannedRightsFlagsValue = initialRightFlags
                    } else if let group = peer as? TelegramGroup, let initialRightFlags = group.defaultBannedRights?.flags {
                        defaultBannedRightsFlagsValue = initialRightFlags
                    }
                    guard let defaultBannedRightsFlags = defaultBannedRightsFlagsValue else {
                        return
                    }
                    
                    
                    var resolvedRights: TelegramChatBannedRights?
                    if let initialParticipant = initialParticipant {
                        var updateFlags: TelegramChatBannedRightsFlags?
                        var updateTimeout: Int32?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            updateTimeout = current.updatedTimeout
                            return current
                        }
                        
                        if updateFlags == nil && updateTimeout == nil {
                            if case let .member(_, _, _, maybeBanInfo, _) = initialParticipant {
                                if maybeBanInfo == nil {
                                    updateFlags = defaultBannedRightsFlags
                                    updateTimeout = Int32.max
                                }
                            }
                        }
                        
                        if updateFlags != nil || updateTimeout != nil {
                            let currentRightsFlags: TelegramChatBannedRightsFlags
                            if let updatedFlags = updateFlags {
                                currentRightsFlags = updatedFlags
                            } else if case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
                                currentRightsFlags = banInfo.rights.flags
                            } else {
                                currentRightsFlags = defaultBannedRightsFlags
                            }
                            
                            let currentTimeout: Int32
                            if let updateTimeout = updateTimeout {
                                currentTimeout = updateTimeout
                            } else if case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
                                currentTimeout = banInfo.rights.untilDate
                            } else {
                                currentTimeout = Int32.max
                            }
                            
                            resolvedRights = TelegramChatBannedRights(flags: completeRights(currentRightsFlags), untilDate: currentTimeout)
                        }
                    } else if canEdit, let _ = channelView.peers[channelView.peerId] as? TelegramChannel {
                        var updateFlags: TelegramChatBannedRightsFlags?
                        var updateTimeout: Int32?
                        updateState { state in
                            var state = state
                            updateFlags = state.updatedFlags
                            updateTimeout = state.updatedTimeout
                            state.updating = false
                            return state
                        }
                        
                        if updateFlags == nil {
                            updateFlags = defaultBannedRightsFlags
                        }
                        if updateTimeout == nil {
                            updateTimeout = Int32.max
                        }
                        
                        if let updateFlags = updateFlags, let updateTimeout = updateTimeout {
                           resolvedRights = TelegramChatBannedRights(flags: completeRights(updateFlags), untilDate: updateTimeout)
                        }
                    }
                    
                    var previousRights: TelegramChatBannedRights?
                    if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo, _) = initialParticipant, banInfo != nil {
                        previousRights = banInfo?.rights
                    }
                    
                    if let resolvedRights = resolvedRights, previousRights != resolvedRights {
                        let cleanResolvedRightsFlags = resolvedRights.flags.union(defaultBannedRightsFlags)
                        let cleanResolvedRights = TelegramChatBannedRights(flags: cleanResolvedRightsFlags, untilDate: resolvedRights.untilDate)
                        
                        if cleanResolvedRights.flags.isEmpty && previousRights == nil {
                            dismissImpl?()
                        } else {
                            let applyRights: () -> Void = {
                                updateState { state in
                                    var state = state
                                    state.updating = true
                                    return state
                                }
                                
                                if peerId.namespace == Namespaces.Peer.CloudGroup {
                                    let signal = context.engine.peers.convertGroupToSupergroup(peerId: peerId)
                                    |> map(Optional.init)
                                    |> `catch` { error -> Signal<PeerId?, NoError> in
                                        switch error {
                                        case .tooManyChannels:
                                            Queue.mainQueue().async {
                                                pushControllerImpl?(oldChannelsController(context: context, updatedPresentationData: updatedPresentationData, intent: .upgrade))
                                            }
                                        default:
                                            break
                                        }
                                        return .single(nil)
                                    }
                                    |> mapToSignal { upgradedPeerId -> Signal<PeerId?, NoError> in
                                        guard let upgradedPeerId = upgradedPeerId else {
                                            return .single(nil)
                                        }
                                        return context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: upgradedPeerId, memberId: memberId, bannedRights: cleanResolvedRights)
                                        |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                            return .complete()
                                        }
                                        |> then(.single(upgradedPeerId))
                                    }
                                    |> deliverOnMainQueue
                                    
                                    updateState { current in
                                        var current = current
                                        current.updating = true
                                        return current
                                    }
                                    updateRightsDisposable.set(signal.start(next: { upgradedPeerId in
                                        if let upgradedPeerId = upgradedPeerId {
                                            upgradedToSupergroup(upgradedPeerId, {
                                                dismissImpl?()
                                            })
                                        } else {
                                            updateState { current in
                                                var current = current
                                                current.updating = false
                                                return current
                                            }
                                        }
                                    }, error: { _ in
                                    }))
                                } else {
                                    updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: cleanResolvedRights)
                                        |> deliverOnMainQueue).start(error: { _ in
                                            
                                        }, completed: {
                                            if previousRights == nil {
                                                let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                                                presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.GroupPermission_AddSuccess, false)), nil)
                                            }
                                            updated(cleanResolvedRights.flags.isEmpty ? nil : cleanResolvedRights)
                                            dismissImpl?()
                                        }))
                                }
                            }
                            
                            let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                            let actionSheet = ActionSheetController(presentationData: presentationData)
                            var items: [ActionSheetItem] = []
                            items.append(ActionSheetTextItem(title: presentationData.strings.GroupPermission_ApplyAlertText(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string))
                            items.append(ActionSheetButtonItem(title: presentationData.strings.GroupPermission_ApplyAlertAction, color: .accent, font: .default, enabled: true, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                applyRights()
                            }))
                            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])])
                            presentControllerImpl?(actionSheet, nil)
                        }
                    } else {
                        dismissImpl?()
                    }
                })
            })
        }
        
        let title: String
        if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo, _) = initialParticipant, banInfo != nil {
            title = presentationData.strings.GroupPermission_Title
        } else {
            title = presentationData.strings.GroupPermission_NewTitle
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelBannedMemberControllerEntries(presentationData: presentationData, state: state, accountPeerId: context.account.peerId, channelView: channelView, memberView: memberView, initialParticipant: initialParticipant, initialBannedBy: initialBannedByPeer), style: .blocks, emptyStateItem: nil, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
