import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelBannedMemberControllerArguments {
    let account: Account
    let toggleRight: (TelegramChannelBannedRightsFlags, TelegramChannelBannedRightsFlags) -> Void
    let openTimeout: () -> Void
    
    init(account: Account, toggleRight: @escaping (TelegramChannelBannedRightsFlags, TelegramChannelBannedRightsFlags) -> Void, openTimeout: @escaping () -> Void) {
        self.account = account
        self.toggleRight = toggleRight
        self.openTimeout = openTimeout
    }
}

private enum ChannelBannedMemberSection: Int32 {
    case info
    case rights
    case timeout
}

private enum ChannelBannedMemberEntryStableId: Hashable {
    case info
    case right(TelegramChannelBannedRightsFlags)
    case timeout
    
    var hashValue: Int {
        switch self {
            case .info:
                return 0
            case .timeout:
                return 1
            case let .right(flags):
                return flags.rawValue.hashValue
        }
    }
    
    static func ==(lhs: ChannelBannedMemberEntryStableId, rhs: ChannelBannedMemberEntryStableId) -> Bool {
        switch lhs {
            case .info:
                if case .info = rhs {
                    return true
                } else {
                    return false
                }
            case let right(flags):
                if case .right(flags) = rhs {
                    return true
                } else {
                    return false
                }
            case .timeout:
                if case .timeout = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum ChannelBannedMemberEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, TelegramUserPresence?)
    case rightItem(PresentationTheme, Int, String, TelegramChannelBannedRightsFlags, TelegramChannelBannedRightsFlags, Bool, Bool)
    case timeout(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return ChannelBannedMemberSection.info.rawValue
            case .rightItem:
                return ChannelBannedMemberSection.rights.rawValue
            case .timeout:
                return ChannelBannedMemberSection.timeout.rawValue
        }
    }
    
    var stableId: ChannelBannedMemberEntryStableId {
        switch self {
            case .info:
                return .info
            case let .rightItem(_, _, _, right, _, _, _):
                return .right(right)
            case .timeout:
                return .timeout
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
        case let .rightItem(lhsTheme, lhsIndex, lhsText, lhsRight, lhsFlags, lhsValue, lhsEnabled):
            if case let .rightItem(rhsTheme, rhsIndex, rhsText, rhsRight, rhsFlags, rhsValue, rhsEnabled) = rhs {
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
                if lhsFlags != rhsFlags {
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
            case let .rightItem(_, lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .info:
                        return false
                    case let .rightItem(_, rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
                }
            case .timeout:
                return false
        }
    }
    
    func item(_ arguments: ChannelBannedMemberControllerArguments) -> ListViewItem {
        switch self {
            case let .info(theme, strings, dateTimeFormat, peer, presence):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer, presence: presence, cachedData: nil, state: ItemListAvatarAndNameInfoItemState(), sectionId: self.section, style: .blocks(withTopInset: true), editingNameUpdated: { _ in
                }, avatarTapped: {
                })
            case let .rightItem(theme, _, text, right, flags, value, enabled):
                return ItemListSwitchItem(theme: theme, title: text, value: value, type: .icon, enabled: enabled, sectionId: self.section, style: .blocks, updated: { _ in
                    arguments.toggleRight(right, flags)
                })
            case let .timeout(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openTimeout()
                })
        }
    }
}

private struct ChannelBannedMemberControllerState: Equatable {
    let referenceTimestamp: Int32
    let updatedFlags: TelegramChannelBannedRightsFlags?
    let updatedTimeout: Int32?
    let updating: Bool
    
    init(referenceTimestamp: Int32, updatedFlags: TelegramChannelBannedRightsFlags? = nil, updatedTimeout: Int32? = nil, updating: Bool = false) {
        self.referenceTimestamp = referenceTimestamp
        self.updatedFlags = updatedFlags
        self.updatedTimeout = updatedTimeout
        self.updating = updating
    }
    
    static func ==(lhs: ChannelBannedMemberControllerState, rhs: ChannelBannedMemberControllerState) -> Bool {
        if lhs.referenceTimestamp != rhs.referenceTimestamp {
            return false
        }
        if lhs.updatedFlags != rhs.updatedFlags {
            return false
        }
        if lhs.updatedTimeout != rhs.updatedTimeout {
            return false
        }
        if lhs.updating != rhs.updating {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatedFlags(_ updatedFlags: TelegramChannelBannedRightsFlags?) -> ChannelBannedMemberControllerState {
        return ChannelBannedMemberControllerState(referenceTimestamp: self.referenceTimestamp, updatedFlags: updatedFlags, updatedTimeout: self.updatedTimeout, updating: self.updating)
    }
    
    func withUpdatedUpdatedTimeout(_ updatedTimeout: Int32?) -> ChannelBannedMemberControllerState {
        return ChannelBannedMemberControllerState(referenceTimestamp: self.referenceTimestamp, updatedFlags: self.updatedFlags, updatedTimeout: updatedTimeout, updating: self.updating)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> ChannelBannedMemberControllerState {
        return ChannelBannedMemberControllerState(referenceTimestamp: self.referenceTimestamp, updatedFlags: self.updatedFlags, updatedTimeout: self.updatedTimeout, updating: updating)
    }
}

private func stringForRight(strings: PresentationStrings, right: TelegramChannelBannedRightsFlags) -> String {
    if right.contains(.banReadMessages) {
        return strings.Channel_BanUser_PermissionReadMessages
    } else if right.contains(.banSendMessages) {
        return strings.Channel_BanUser_PermissionSendMessages
    } else if right.contains(.banSendMedia) {
        return strings.Channel_BanUser_PermissionSendMedia
    } else if right.contains(.banSendGifs) {
        return strings.Channel_BanUser_PermissionSendStickersAndGifs
    } else if right.contains(.banEmbedLinks) {
        return strings.Channel_BanUser_PermissionEmbedLinks
    } else {
        return ""
    }
}

private func rightDependencies(_ right: TelegramChannelBannedRightsFlags) -> TelegramChannelBannedRightsFlags {
    if right.contains(.banReadMessages) {
        return []
    } else if right.contains(.banSendMessages) {
        return [.banReadMessages]
    } else if right.contains(.banSendMedia) {
        return [.banReadMessages, .banSendMessages]
    } else if right.contains(.banSendGifs) {
        return [.banReadMessages, .banSendMessages, .banSendGifs, .banSendGames, .banSendInline]
    } else if right.contains(.banEmbedLinks) {
        return [.banReadMessages, .banSendMessages]
    } else {
        return []
    }
}

/*
 TelegramChannelBannedRightsFlags = [
 .banReadMessages,
 .banSendMessages,
 .banSendMedia,
 .banSendStickers, .banSendGifs, .banSendGames, .banSendInline,
 .banEmbedLinks
 ]
 */

private func rightReverseDependencies(_ right: TelegramChannelBannedRightsFlags) -> TelegramChannelBannedRightsFlags {
    if right.contains(.banReadMessages) {
        return [.banSendMessages, .banSendMedia, .banSendStickers, .banSendGifs, .banSendGames, .banSendInline, .banEmbedLinks]
    } else if right.contains(.banSendMessages) {
        return [.banSendMedia, .banSendStickers, .banSendGifs, .banSendGames, .banSendInline, .banEmbedLinks]
    } else if right.contains(.banSendMedia) {
        return []
    } else if right.contains(.banSendGifs) {
        return [.banSendStickers, .banSendGames, .banSendInline]
    } else if right.contains(.banEmbedLinks) {
        return []
    } else {
        return []
    }
}

private let initialRightFlags: TelegramChannelBannedRightsFlags = [.banReadMessages, .banSendMessages, .banSendGifs, .banSendGames, .banSendInline, .banSendStickers, .banSendMedia, .banEmbedLinks]

func maskedFlags(_ flags: TelegramChannelBannedRightsFlags) -> TelegramChannelBannedRightsFlags {
    return flags.intersection([
        .banReadMessages,
        .banSendMessages,
        .banSendMedia,
        .banSendStickers, .banSendGifs, .banSendGames, .banSendInline,
        .banEmbedLinks
    ])
}

private func channelBannedMemberControllerEntries(presentationData: PresentationData, state: ChannelBannedMemberControllerState, accountPeerId: PeerId, channelView: PeerView, memberView: PeerView, initialParticipant: ChannelParticipant?) -> [ChannelBannedMemberEntry] {
    var entries: [ChannelBannedMemberEntry] = []
    
    if let _ = channelView.peers[channelView.peerId] as? TelegramChannel, let member = memberView.peers[memberView.peerId] {
        entries.append(.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, member, memberView.peerPresences[member.id] as? TelegramUserPresence))
            
        let currentRightsFlags: TelegramChannelBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = initialRightFlags
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo) = initialParticipant, let banInfo = maybeBanInfo {
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
        
        let rightsOrder: [TelegramChannelBannedRightsFlags] = [
            .banReadMessages,
            .banSendMessages,
            .banSendMedia,
            .banSendGifs,
            .banEmbedLinks
        ]
        
        var index = 0
        for right in rightsOrder {
            entries.append(.rightItem(presentationData.theme, index, stringForRight(strings: presentationData.strings, right: right), right, currentRightsFlags, !currentRightsFlags.contains(right), !state.updating))
            index += 1
        }
        
        entries.append(.timeout(presentationData.theme, presentationData.strings.Channel_BanUser_BlockFor, currentTimeoutString))
    }
    
    return entries
}

public func channelBannedMemberController(account: Account, peerId: PeerId, memberId: PeerId, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChannelBannedRights) -> Void) -> ViewController {
    let initialState = ChannelBannedMemberControllerState(referenceTimestamp: Int32(Date().timeIntervalSince1970))
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
    
    let arguments = ChannelBannedMemberControllerArguments(account: account, toggleRight: { right, flags in
        updateState { current in
            var updated = flags
            let compositeFlags: TelegramChannelBannedRightsFlags
            switch right {
            case .banSendStickers, .banSendGifs, .banSendGames, .banSendInline:
                    compositeFlags = [.banSendStickers, .banSendGifs, .banSendGames, .banSendInline]
                default:
                    compositeFlags = right
                
            }
            if !flags.intersection(compositeFlags).isEmpty {
                updated = updated.subtracting(compositeFlags)
                updated = updated.subtracting(rightDependencies(right))
            } else {
                updated = updated.union(compositeFlags)
                updated = updated.union(rightReverseDependencies(right))
            }
            return current.withUpdatedUpdatedFlags(updated)
        }
    }, openTimeout: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        let intervals: [Int32] = [
            1 * 60 * 60 * 24,
            7 * 60 * 60 * 24
        ]
        let applyValue: (Int32?) -> Void = { value in
            updateState { state in
                let state = state.withUpdatedUpdatedTimeout(value)
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
        items.append(ActionSheetButtonItem(title: presentationData.strings.MessageTimer_Custom, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            presentControllerImpl?(PeerBanTimeoutController(account: account, currentValue: Int32(Date().timeIntervalSince1970), applyValue: { value in
                applyValue(value)
            }), nil)
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    })
    
    let combinedView = account.postbox.combinedView(keys: [.peer(peerId: peerId, components: .all), .peer(peerId: memberId, components: .all)])
    
    let canEdit = true
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), combinedView)
        |> deliverOnMainQueue
        |> map { presentationData, state, combinedView -> (ItemListControllerState, (ItemListNodeState<ChannelBannedMemberEntry>, ChannelBannedMemberEntry.ItemGenerationArguments)) in
            let channelView = combinedView.views[.peer(peerId: peerId, components: .all)] as! PeerView
            let memberView = combinedView.views[.peer(peerId: memberId, components: .all)] as! PeerView
            
            let leftNavigationButton: ItemListNavigationButton
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            var rightNavigationButton: ItemListNavigationButton?
            if state.updating {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    if let initialParticipant = initialParticipant {
                        var updateFlags: TelegramChannelBannedRightsFlags?
                        var updateTimeout: Int32?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            updateTimeout = current.updatedTimeout
                            return current
                        }
                        
                        if updateFlags == nil && updateTimeout == nil {
                            if case let .member(_, _, _, maybeBanInfo) = initialParticipant  {
                                if maybeBanInfo == nil {
                                    updateFlags = initialRightFlags
                                    updateTimeout = Int32.max
                                }
                            }
                        }
                        
                        if updateFlags != nil || updateTimeout != nil {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            
                            let currentRightsFlags: TelegramChannelBannedRightsFlags
                            if let updatedFlags = updateFlags {
                                currentRightsFlags = updatedFlags
                            } else if case let .member(_, _, _, maybeBanInfo) = initialParticipant, let banInfo = maybeBanInfo {
                                currentRightsFlags = banInfo.rights.flags
                            } else {
                                currentRightsFlags = initialRightFlags
                            }
                            
                            let currentTimeout: Int32
                            if let updateTimeout = updateTimeout {
                                currentTimeout = updateTimeout
                            } else if case let .member(_, _, _, maybeBanInfo) = initialParticipant, let banInfo = maybeBanInfo {
                                currentTimeout = banInfo.rights.untilDate
                            } else {
                                currentTimeout = Int32.max
                            }
                            
                            let rights = TelegramChannelBannedRights(flags: maskedFlags(currentRightsFlags), untilDate: currentTimeout)
                            
                            updateRightsDisposable.set((account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: memberId, bannedRights: rights)
                            |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(rights)
                                dismissImpl?()
                            }))
                        } else {
                            dismissImpl?()
                        }
                    } else if canEdit, let _ = channelView.peers[channelView.peerId] as? TelegramChannel {
                        var updateFlags: TelegramChannelBannedRightsFlags?
                        var updateTimeout: Int32?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            updateTimeout = current.updatedTimeout
                            return current.withUpdatedUpdating(true)
                        }
                        
                        if updateFlags == nil {
                            updateFlags = initialRightFlags
                        }
                        if updateTimeout == nil {
                            updateTimeout = Int32.max
                        }
                        
                        if let updateFlags = updateFlags, let updateTimeout = updateTimeout {
                            let rights = TelegramChannelBannedRights(flags: maskedFlags(updateFlags), untilDate: updateTimeout)
                            updateRightsDisposable.set((account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: memberId, bannedRights: rights)
                                |> deliverOnMainQueue).start(error: { _ in
                                    
                                }, completed: {
                                    updated(rights)
                                    dismissImpl?()
                                }))
                        }
                    } else {
                        dismissImpl?()
                    }
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Channel_BanUser_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            
            let listState = ItemListNodeState(entries: channelBannedMemberControllerEntries(presentationData: presentationData, state: state, accountPeerId: account.peerId, channelView: channelView, memberView: memberView, initialParticipant: initialParticipant), style: .blocks, emptyStateItem: nil, animateChanges: true)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    return controller
}
