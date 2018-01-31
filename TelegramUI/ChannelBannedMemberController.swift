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
    case info(PresentationTheme, PresentationStrings, Peer, TelegramUserPresence?)
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
        case let .info(lhsTheme, lhsStrings, lhsPeer, lhsPresence):
            if case let .info(rhsTheme, rhsStrings, rhsPeer, rhsPresence) = rhs {
                if lhsTheme !== rhsTheme {
                    return false
                }
                if lhsStrings !== rhsStrings {
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
            case let .info(theme, strings, peer, presence):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, mode: .generic, peer: peer, presence: presence, cachedData: nil, state: ItemListAvatarAndNameInfoItemState(), sectionId: self.section, style: .blocks(withTopInset: true), editingNameUpdated: { _ in
                }, avatarTapped: {
                })
            case let .rightItem(theme, _, text, right, flags, value, enabled):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { _ in
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
    let updatedFlags: TelegramChannelBannedRightsFlags?
    let updatedTimeout: Int32?
    let updating: Bool
    
    init(updatedFlags: TelegramChannelBannedRightsFlags? = nil, updatedTimeout: Int32? = nil, updating: Bool = false) {
        self.updatedFlags = updatedFlags
        self.updatedTimeout = updatedTimeout
        self.updating = updating
    }
    
    static func ==(lhs: ChannelBannedMemberControllerState, rhs: ChannelBannedMemberControllerState) -> Bool {
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
        return ChannelBannedMemberControllerState(updatedFlags: updatedFlags, updatedTimeout: self.updatedTimeout, updating: self.updating)
    }
    
    func withUpdatedUpdatedTimeout(_ updatedTimeoyt: Int32?) -> ChannelBannedMemberControllerState {
        return ChannelBannedMemberControllerState(updatedFlags: self.updatedFlags, updatedTimeout: updatedTimeout, updating: self.updating)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> ChannelBannedMemberControllerState {
        return ChannelBannedMemberControllerState(updatedFlags: self.updatedFlags, updatedTimeout: self.updatedTimeout, updating: updating)
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

private func rightDependencies(_ right: TelegramChannelBannedRightsFlags) -> [TelegramChannelBannedRightsFlags] {
    if right.contains(.banReadMessages) {
        return []
    } else if right.contains(.banSendMessages) {
        return [.banReadMessages]
    } else if right.contains(.banSendMedia) {
        return [.banReadMessages, .banSendMessages]
    } else if right.contains(.banSendStickers) {
        return [.banReadMessages, .banSendMessages]
    } else if right.contains(.banEmbedLinks) {
        return [.banReadMessages, .banSendMessages]
    } else {
        return []
    }
}

private func channelBannedMemberControllerEntries(presentationData: PresentationData, state: ChannelBannedMemberControllerState, accountPeerId: PeerId, channelView: PeerView, memberView: PeerView, initialParticipant: ChannelParticipant?) -> [ChannelBannedMemberEntry] {
    var entries: [ChannelBannedMemberEntry] = []
    
    if let _ = channelView.peers[channelView.peerId] as? TelegramChannel, let member = memberView.peers[memberView.peerId] {
        entries.append(.info(presentationData.theme, presentationData.strings, member, memberView.peerPresences[member.id] as? TelegramUserPresence))
            
        let currentRightsFlags: TelegramChannelBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = [.banSendMessages, .banSendGifs, .banSendGames, .banSendInline, .banSendStickers, .banSendMedia, .banEmbedLinks]
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo) = initialParticipant, let banInfo = maybeBanInfo {
            currentTimeout = banInfo.rights.untilDate
        } else {
            currentTimeout = Int32.max
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
            entries.append(.rightItem(presentationData.theme, index, stringForRight(strings: presentationData.strings, right: right), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating))
            index += 1
        }
        
        
    }
    
    return entries
}

public func channelBannedMemberController(account: Account, peerId: PeerId, memberId: PeerId, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChannelBannedRights) -> Void) -> ViewController {
    let statePromise = ValuePromise(ChannelBannedMemberControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelBannedMemberControllerState())
    let updateState: ((ChannelBannedMemberControllerState) -> ChannelBannedMemberControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateRightsDisposable = MetaDisposable()
    actionsDisposable.add(updateRightsDisposable)
    
    var dismissImpl: (() -> Void)?
    
    let arguments = ChannelBannedMemberControllerArguments(account: account, toggleRight: { right, flags in
        updateState { current in
            var updated = flags
            if flags.contains(right) {
                updated.remove(right)
            } else {
                updated.insert(right)
            }
            return current.withUpdatedUpdatedFlags(updated)
        }
    }, openTimeout: {
        
    })
    
    let combinedView = account.postbox.combinedView(keys: [.peer(peerId: peerId), .peer(peerId: memberId)])
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), combinedView)
        |> deliverOnMainQueue
        |> map { presentationData, state, combinedView -> (ItemListControllerState, (ItemListNodeState<ChannelBannedMemberEntry>, ChannelBannedMemberEntry.ItemGenerationArguments)) in
            let channelView = combinedView.views[.peer(peerId: peerId)] as! PeerView
            let memberView = combinedView.views[.peer(peerId: memberId)] as! PeerView
            
            let leftNavigationButton: ItemListNavigationButton
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            var rightNavigationButton: ItemListNavigationButton?
            if state.updating {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    /*if let _ = initialParticipant {
                        var updateFlags: TelegramChannelBannedMemberRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            if let _ = updateFlags {
                                return current.withUpdatedUpdating(true)
                            } else {
                                return current
                            }
                        }
                        
                        if let updateFlags = updateFlags {
                            updateRightsDisposable.set((updatePeerAdminRights(account: account, peerId: peerId, adminId: adminId, rights: TelegramChannelBannedMemberRights(flags: updateFlags)) |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(TelegramChannelBannedMemberRights(flags: updateFlags))
                                dismissImpl?()
                            }))
                        }
                    } else if canEdit, let channel = channelView.peers[channelView.peerId] as? TelegramChannel {
                        var updateFlags: TelegramChannelBannedMemberRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            return current.withUpdatedUpdating(true)
                        }
                        
                        if updateFlags == nil {
                            let maskRightsFlags: TelegramChannelBannedMemberRightsFlags
                            switch channel.info {
                            case .broadcast:
                                maskRightsFlags = .broadcastSpecific
                            case .group:
                                maskRightsFlags = .groupSpecific
                            }
                            
                            if channel.flags.contains(.isCreator) {
                                updateFlags = maskRightsFlags.subtracting(.canAddAdmins)
                            } else if let adminRights = channel.adminRights {
                                updateFlags = maskRightsFlags.intersection(adminRights.flags).subtracting(.canAddAdmins)
                            } else {
                                updateFlags = []
                            }
                        }
                        
                        if let updateFlags = updateFlags {
                            updateRightsDisposable.set((updatePeerAdminRights(account: account, peerId: peerId, adminId: adminId, rights: TelegramChannelBannedMemberRights(flags: updateFlags)) |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(TelegramChannelBannedMemberRights(flags: updateFlags))
                                dismissImpl?()
                            }))
                        }
                    }*/
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
    return controller
}
