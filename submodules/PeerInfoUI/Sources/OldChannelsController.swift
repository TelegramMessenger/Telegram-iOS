import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import ContactsPeerItem
import SearchUI
import SolidRoundedButtonNode
import PremiumUI

func localizedOldChannelDate(peer: InactiveChannel, strings: PresentationStrings) -> String {
    let timestamp = peer.lastActivityDate
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    
    var t: time_t = time_t(TimeInterval(timestamp))
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    var string: String
    
    if timeinfoNow.tm_year == timeinfo.tm_year && timeinfoNow.tm_mon == timeinfo.tm_mon {
        //weeks
        let dif = Int(roundf(Float(timeinfoNow.tm_mday - timeinfo.tm_mday) / 7))
        string = strings.OldChannels_InactiveWeek(Int32(dif))
    } else if timeinfoNow.tm_year == timeinfo.tm_year  {
        //month
        let dif = Int(timeinfoNow.tm_mon - timeinfo.tm_mon)
        string = strings.OldChannels_InactiveMonth(Int32(dif))
    } else {
        //year
        var dif = Int(timeinfoNow.tm_year - timeinfo.tm_year)
        
        if Int(timeinfoNow.tm_mon - timeinfo.tm_mon) > 6 {
            dif += 1
        }
        string = strings.OldChannels_InactiveYear(Int32(dif))
    }
    
    if let channel = peer.peer as? TelegramChannel, case .group = channel.info {
        if let participantsCount = peer.participantsCount, participantsCount != 0 {
            string = strings.OldChannels_GroupFormat(participantsCount) + ", " + string
        } else {
            string = strings.OldChannels_GroupEmptyFormat + ", " + string
        }
    } else {
        string = strings.OldChannels_ChannelFormat + string
    }
    
    return string
}

private final class OldChannelsItemArguments {
    let context: AccountContext
    let togglePeer: (PeerId, Bool) -> Void
    
    init(
        context: AccountContext,
        togglePeer: @escaping (PeerId, Bool) -> Void
    ) {
        self.context = context
        self.togglePeer = togglePeer
    }
}

private enum OldChannelsSection: Int32 {
    case info
    case peers
}

private enum OldChannelsEntryId: Hashable {
    case info
    case peersHeader
    case peer(PeerId)
}

private enum OldChannelsEntry: ItemListNodeEntry {
    case info(Int32, Int32, Int32, String, Bool)
    case peersHeader(String)
    case peer(Int, InactiveChannel, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .info:
            return OldChannelsSection.info.rawValue
        case .peersHeader, .peer:
            return OldChannelsSection.peers.rawValue
        }
    }
    
    var stableId: OldChannelsEntryId {
        switch self {
        case .info:
            return .info
        case .peersHeader:
            return .peersHeader
        case let .peer(_, peer, _):
            return .peer(peer.peer.id)
        }
    }
    
    static func ==(lhs: OldChannelsEntry, rhs: OldChannelsEntry) -> Bool {
        switch lhs {
        case let .info(count, limit, premiumLimit, text, isPremiumDisabled):
            if case .info(count, limit, premiumLimit, text, isPremiumDisabled) = rhs {
                return true
            } else {
                return false
            }
        case let .peersHeader(title):
            if case .peersHeader(title) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(lhsIndex, lhsPeer, lhsSelected):
            if case let .peer(rhsIndex, rhsPeer, rhsSelected) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsSelected != rhsSelected {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: OldChannelsEntry, rhs: OldChannelsEntry) -> Bool {
        switch lhs {
        case .info:
            if case .info = rhs {
                return false
            } else {
                return true
            }
        case .peersHeader:
            switch rhs {
            case .info, .peersHeader:
                return false
            case .peer:
                return true
            }
        case let .peer(lhsIndex, _, _):
            switch rhs {
            case .info, .peersHeader:
                return false
            case let .peer(rhsIndex, _, _):
                return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! OldChannelsItemArguments
        switch self {
        case let .info(count, limit, premiumLimit, text, isPremiumDisabled):
            return IncreaseLimitHeaderItem(theme: presentationData.theme, strings: presentationData.strings, icon: .group, count: count, limit: limit, premiumCount: premiumLimit, text: text, isPremiumDisabled: isPremiumDisabled, sectionId: self.section)
        case let .peersHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .peer(_, peer, selected):
            return ContactsPeerItem(presentationData: presentationData, style: .blocks, sectionId: self.section, sortOrder: .firstLast, displayOrder: .firstLast, context: arguments.context, peerMode: .peer, peer: .peer(peer: EnginePeer(peer.peer), chatPeer: EnginePeer(peer.peer)), status: .custom(string: localizedOldChannelDate(peer: peer, strings: presentationData.strings), multiline: false), badge: nil, enabled: true, selection: ContactsPeerItemSelection.selectable(selected: selected), editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), options: [], actionIcon: .none, index: nil, header: nil, action: { _ in
                arguments.togglePeer(peer.peer.id, true)
            }, setPeerIdWithRevealedOptions: nil, deletePeer: nil, itemHighlighting: nil, contextAction: nil)
        }
    }
}

private struct OldChannelsState: Equatable {
    var selectedPeers: Set<PeerId> = Set()
    var isSearching: Bool = false
}

private func oldChannelsEntries(presentationData: PresentationData, state: OldChannelsState, isPremium: Bool, isPremiumDisabled: Bool, limit: Int32, premiumLimit: Int32, peers: [InactiveChannel]?, intent: OldChannelsControllerIntent) -> [OldChannelsEntry] {
    var entries: [OldChannelsEntry] = []
    
    let count = max(limit, Int32(peers?.count ?? 0))
    var text: String?
    if count >= premiumLimit {
        switch intent {
            case .create:
                text = presentationData.strings.OldChannels_TooManyCommunitiesCreateFinalText("\(premiumLimit)").string
            case .upgrade:
                text = presentationData.strings.OldChannels_TooManyCommunitiesUpgradeFinalText("\(premiumLimit)").string
            case .join:
                text = presentationData.strings.OldChannels_TooManyCommunitiesFinalText("\(premiumLimit)").string
        }
    } else if count >= limit {
        if isPremiumDisabled {
            switch intent {
                case .create:
                    text = presentationData.strings.OldChannels_TooManyCommunitiesCreateNoPremiumText("\(premiumLimit)").string
                case .upgrade:
                    text = presentationData.strings.OldChannels_TooManyCommunitiesUpgradeNoPremiumText("\(premiumLimit)").string
                case .join:
                    text = presentationData.strings.OldChannels_TooManyCommunitiesNoPremiumText("\(count)").string
            }
        } else {
            switch intent {
                case .create:
                    text = presentationData.strings.OldChannels_TooManyCommunitiesCreateText("\(count)", "\(premiumLimit)").string
                case .upgrade:
                    text = presentationData.strings.OldChannels_TooManyCommunitiesUpgradeText("\(count)", "\(premiumLimit)").string
                case .join:
                    text = presentationData.strings.OldChannels_TooManyCommunitiesText("\(count)", "\(premiumLimit)").string
            }
        }
    }
    
    if let text = text {
        entries.append(.info(count, limit, premiumLimit, text, isPremiumDisabled))
    }
    
    if let peers = peers, !peers.isEmpty {
        entries.append(.peersHeader(presentationData.strings.OldChannels_ChannelsHeader))
        
        for peer in peers {
            entries.append(.peer(entries.count, peer, state.selectedPeers.contains(peer.peer.id)))
        }
    }
    
    return entries
}


public enum OldChannelsControllerIntent {
    case join
    case create
    case upgrade
}

public func oldChannelsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, intent: OldChannelsControllerIntent, completed: @escaping (Bool) -> Void = { _ in }) -> ViewController {
    let initialState = OldChannelsState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((OldChannelsState) -> OldChannelsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
        
    var dismissImpl: (() -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var setDisplayNavigationBarImpl: ((Bool) -> Void)?
    
    var ensurePeerVisibleImpl: ((PeerId) -> Void)?
    
    var leaveActionImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = OldChannelsItemArguments(
        context: context,
        togglePeer: { peerId, ensureVisible in
            var didSelect = false
            updateState { state in
                var state = state
                if state.selectedPeers.contains(peerId) {
                    state.selectedPeers.remove(peerId)
                } else {
                    state.selectedPeers.insert(peerId)
                    didSelect = true
                }
                return state
            }
            if didSelect && ensureVisible {
                ensurePeerVisibleImpl?(peerId)
            }
        }
    )
    
    let selectedPeerIds = statePromise.get()
    |> map { $0.selectedPeers }
    |> distinctUntilChanged
    
    let peersSignal: Signal<[InactiveChannel]?, NoError> = .single(nil)
    |> then(
        context.engine.peers.inactiveChannelList()
        |> map { peers -> [InactiveChannel]? in
            return peers.sorted(by: { lhs, rhs in
                return lhs.lastActivityDate < rhs.lastActivityDate
            })
        }
    )
    
    let peersPromise = Promise<[InactiveChannel]?>()
    peersPromise.set(peersSignal)
    
    var previousPeersWereEmpty = true
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(
        queue: Queue.mainQueue(),
        presentationData,
        statePromise.get(),
        peersPromise.get(),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        )
    )
    |> map { presentationData, state, peers, limits -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let (accountPeer, limits, premiumLimits) = limits
        let isPremium = accountPeer?.isPremium ?? false
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.OldChannels_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        
        var searchItem: OldChannelsSearchItem?
        searchItem = OldChannelsSearchItem(context: context, theme: presentationData.theme, placeholder: presentationData.strings.Common_Search, activated: state.isSearching, updateActivated: { value in
            if !value {
                setDisplayNavigationBarImpl?(true)
            }
            updateState { state in
                var state = state
                state.isSearching = value
                return state
            }
            if value {
                setDisplayNavigationBarImpl?(false)
            }
        }, peers: peersPromise.get() |> map { $0 ?? [] }, selectedPeerIds: selectedPeerIds, togglePeer: { peerId in
            arguments.togglePeer(peerId, false)
        })
        
        let peersAreEmpty = peers == nil
        let peersAreEmptyUpdated = previousPeersWereEmpty != peersAreEmpty
        previousPeersWereEmpty = peersAreEmpty
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if peersAreEmpty {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let buttonText: String
        let colorful: Bool
        if state.selectedPeers.count > 0 {
            buttonText = presentationData.strings.OldChannels_LeaveCommunities(Int32(state.selectedPeers.count))
            colorful = false
        } else {
            buttonText = presentationData.strings.Premium_IncreaseLimit
            colorful = true
        }
        
        let footerItem: IncreaseLimitFooterItem?
        if (state.isSearching || premiumConfiguration.isPremiumDisabled) && state.selectedPeers.count == 0 {
            footerItem = nil
        } else {
            footerItem = IncreaseLimitFooterItem(theme: presentationData.theme, title: buttonText, colorful: colorful, action: {
                if state.selectedPeers.count > 0 {
                    leaveActionImpl?()
                } else {
                    let controller = PremiumIntroScreen(context: context, source: .groupsAndChannels)
                    pushImpl?(controller)
                }
            })
        }
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: oldChannelsEntries(presentationData: presentationData, state: state, isPremium: isPremium, isPremiumDisabled: premiumConfiguration.isPremiumDisabled, limit: limits.maxChannelsCount, premiumLimit: premiumLimits.maxChannelsCount, peers: peers, intent: intent), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, footerItem: footerItem, initialScrollToItem: ListViewScrollToItem(index: 0, position: .top(-navigationBarSearchContentHeight), animated: false, curve: .Default(duration: 0.0), directionHint: .Up), crossfadeState: peersAreEmptyUpdated, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    
    leaveActionImpl = {
        let state = stateValue.with { $0 }
        let _ = (peersPromise.get()
        |> take(1)
        |> mapToSignal { peers -> Signal<Never, NoError> in
            let peers = peers ?? []
            
            let ensureStoredPeers = peers.map { $0.peer }.filter { state.selectedPeers.contains($0.id) }
            let ensureStoredPeersSignal: Signal<Never, NoError> = context.engine.peers.ensurePeersAreLocallyAvailable(peers: ensureStoredPeers.map(EnginePeer.init))
            
            return ensureStoredPeersSignal
            |> then(context.engine.peers.removePeerChats(peerIds: Array(ensureStoredPeers.map(\.id))))
        }
        |> deliverOnMainQueue).start(completed: {
            completed(true)
            dismissImpl?()
        })
    }
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    setDisplayNavigationBarImpl = { [weak controller] display in
        controller?.setDisplayNavigationBar(display, transition: .animated(duration: 0.5, curve: .spring))
    }
    ensurePeerVisibleImpl = { [weak controller] peerId in
        guard let controller = controller else {
            return
        }
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ContactsPeerItemNode, let peer = itemNode.chatPeer, peer.id == peerId {
                controller.ensureItemNodeVisible(itemNode, curve: .Spring(duration: 0.3))
            }
        }
    }
    
    return controller
}
