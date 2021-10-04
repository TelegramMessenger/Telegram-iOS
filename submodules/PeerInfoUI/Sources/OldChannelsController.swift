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
            string = strings.OldChannels_GroupFormat(participantsCount) + string
        } else {
            string = strings.OldChannels_GroupEmptyFormat + string
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
    case info(String, String)
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
        case let .info(title, text):
            if case .info(title, text) = rhs {
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
        case let .info(title, text):
            return ItemListInfoItem(presentationData: presentationData, title: title, text: .plain(text), style: .blocks, sectionId: self.section, closeAction: nil)
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

private func oldChannelsEntries(presentationData: PresentationData, state: OldChannelsState, peers: [InactiveChannel]?, intent: OldChannelsControllerIntent) -> [OldChannelsEntry] {
    var entries: [OldChannelsEntry] = []
    
    let noticeText: String
    switch intent {
    case .join:
        noticeText = presentationData.strings.OldChannels_NoticeText
    case .create:
        noticeText = presentationData.strings.OldChannels_NoticeCreateText
    case .upgrade:
        noticeText = presentationData.strings.OldChannels_NoticeUpgradeText
    }
    entries.append(.info(presentationData.strings.OldChannels_NoticeTitle, noticeText))
    
    if let peers = peers, !peers.isEmpty {
        entries.append(.peersHeader(presentationData.strings.OldChannels_ChannelsHeader))
        
        for peer in peers {
            entries.append(.peer(entries.count, peer, state.selectedPeers.contains(peer.peer.id)))
        }
    }
    
    return entries
}

private final class OldChannelsActionPanelNode: ASDisplayNode {
    private let separatorNode: ASDisplayNode
    let buttonNode: SolidRoundedButtonNode
    
    init(presentationData: ItemListPresentationData, leaveAction: @escaping () -> Void) {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.buttonNode = SolidRoundedButtonNode(title: "", icon: nil, theme: SolidRoundedButtonTheme(theme: presentationData.theme), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        super.init()
        
        self.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.pressed = {
            leaveAction()
        }
    }
    
    func updatePresentationData(_ presentationData: ItemListPresentationData) {
        self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
    }
    
    func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        let sideInset: CGFloat = 16.0
        let verticalInset: CGFloat = 16.0
        let buttonHeight: CGFloat = 50.0
        
        let insets = layout.insets(options: [.input])
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        let _ = self.buttonNode.updateLayout(width: layout.size.width - sideInset * 2.0, transition: transition)
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: CGSize(width: layout.size.width, height: buttonHeight)))
        
        return buttonHeight + verticalInset * 2.0 + insets.bottom
    }
}

private final class OldChannelsControllerImpl: ItemListController {
    private let panelNode: OldChannelsActionPanelNode
    
    private var displayPanel: Bool = false
    private var validLayout: ContainerViewLayout?
    
    private var presentationData: ItemListPresentationData
    private var presentationDataDisposable: Disposable?
    
    var leaveAction: (() -> Void)?
    
    override init<ItemGenerationArguments>(presentationData: ItemListPresentationData, updatedPresentationData: Signal<ItemListPresentationData, NoError>, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>?) {
        self.presentationData = presentationData
        
        var leaveActionImpl: (() -> Void)?
        self.panelNode = OldChannelsActionPanelNode(presentationData: presentationData, leaveAction: {
            leaveActionImpl?()
        })
        
        super.init(presentationData: presentationData, updatedPresentationData: updatedPresentationData, state: state, tabBarItem: tabBarItem)
        
        self.presentationDataDisposable = (updatedPresentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self else {
                return
            }
            strongSelf.presentationData = presentationData
            strongSelf.panelNode.updatePresentationData(presentationData)
        })
        
        leaveActionImpl = { [weak self] in
            self?.leaveAction?()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override var navigationBarRequiresEntireLayoutUpdate: Bool {
        return false
    }
    
    override func loadDisplayNode() {
        super.loadDisplayNode()
        
        self.displayNode.addSubnode(self.panelNode)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        let panelHeight = self.panelNode.updateLayout(layout, transition: transition)
        
        var additionalInsets = UIEdgeInsets()
        additionalInsets.bottom = max(layout.intrinsicInsets.bottom, panelHeight)
        
        self.additionalInsets = additionalInsets
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        transition.updateFrame(node: self.panelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.displayPanel ? (layout.size.height - panelHeight) : layout.size.height), size: CGSize(width: layout.size.width, height: panelHeight)), beginWithCurrentState: true)
    }
    
    func updatePanelPeerCount(_ value: Int) {
        self.panelNode.buttonNode.title = self.presentationData.strings.OldChannels_Leave(Int32(value))
        
        if self.displayPanel != (value != 0) {
            self.displayPanel = (value != 0)
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
    }
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
    
    var updateSelectedPeersImpl: ((Int) -> Void)?
    
    var dismissImpl: (() -> Void)?
    var setDisplayNavigationBarImpl: ((Bool) -> Void)?
    
    var ensurePeerVisibleImpl: ((PeerId) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = OldChannelsItemArguments(
        context: context,
        togglePeer: { peerId, ensureVisible in
            var selectedPeerCount = 0
            var didSelect = false
            updateState { state in
                var state = state
                if state.selectedPeers.contains(peerId) {
                    state.selectedPeers.remove(peerId)
                } else {
                    state.selectedPeers.insert(peerId)
                    didSelect = true
                }
                selectedPeerCount = state.selectedPeers.count
                return state
            }
            updateSelectedPeersImpl?(selectedPeerCount)
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
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(
        queue: Queue.mainQueue(),
        presentationData,
        statePromise.get(),
        peersPromise.get()
    )
    |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
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
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: oldChannelsEntries(presentationData: presentationData, state: state, peers: peers, intent: intent), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, initialScrollToItem: ListViewScrollToItem(index: 0, position: .top(-navigationBarSearchContentHeight), animated: false, curve: .Default(duration: 0.0), directionHint: .Up), crossfadeState: peersAreEmptyUpdated, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = OldChannelsControllerImpl(context: context, state: signal)
    controller.navigationPresentation = .modal
    
    updateSelectedPeersImpl = { [weak controller] value in
        controller?.updatePanelPeerCount(value)
    }
    
    controller.leaveAction = {
        let state = stateValue.with { $0 }
        let _ = (peersPromise.get()
        |> take(1)
        |> mapToSignal { peers -> Signal<Never, NoError> in
            let peers = peers ?? []
            return context.account.postbox.transaction { transaction -> Void in
                for peer in peers {
                    if state.selectedPeers.contains(peer.peer.id) {
                        if transaction.getPeer(peer.peer.id) == nil {
                            updatePeers(transaction: transaction, peers: [peer.peer], update: { _, updated in
                                return updated
                            })
                        }
                    }
                }
            }
            |> ignoreValues
            |> then(context.engine.peers.removePeerChats(peerIds: Array(peers.map(\.peer.id))))
        }
        |> deliverOnMainQueue).start(completed: {
            completed(true)
            dismissImpl?()
        })
    }
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
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
