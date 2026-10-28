import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem
import MergeLists
import ItemListUI
import PeerInfoVisualMediaPaneNode
import ChatControllerInteraction
import MultilineTextComponent
import Markdown
import ButtonComponent
import EdgeEffect
import ComponentDisplayAdapters
import LottieComponent
import PeerInfoPaneNode

private struct RecommendedPeersListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let animated: Bool
}

private enum RecommendedPeersListEntryStableId: Hashable {
    case addMember
    case peer(EnginePeer.Id)
}

private enum RecommendedPeersListEntry: Comparable, Identifiable {
    case peer(theme: PresentationTheme, index: Int, peer: EnginePeer, subscribers: Int32)
        
    var stableId: RecommendedPeersListEntryStableId {
        switch self {
        case let .peer(_, _, peer, _):
            return .peer(peer.id)
        }
    }
    
    static func ==(lhs: RecommendedPeersListEntry, rhs: RecommendedPeersListEntry) -> Bool {
        switch lhs {
        case let .peer(lhsTheme, lhsIndex, lhsPeer, lhsSubscribers):
            if case let .peer(rhsTheme, rhsIndex, rhsPeer, rhsSubscribers) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsPeer == rhsPeer, lhsSubscribers == rhsSubscribers {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: RecommendedPeersListEntry, rhs: RecommendedPeersListEntry) -> Bool {
        switch lhs {
        case let .peer(_, lhsIndex, _, _):
            switch rhs {
            case let .peer(_, rhsIndex, _, _):
                return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, action: @escaping (EnginePeer) -> Void, openPeerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void) -> ListViewItem {
        switch self {
        case let .peer(_, _, peer, subscribers):
            let text: ItemListPeerItemText
            if subscribers > 0 {
                if peer.id.namespace == Namespaces.Peer.CloudChannel {
                    text = .text(presentationData.strings.SharedMedia_SimilarChannel_Subscribers(subscribers), .secondary)
                } else {
                    text = .text(presentationData.strings.SharedMedia_SimilarBot_Users(subscribers), .secondary)
                }
            } else if let addressName = peer.addressName {
                text = .text("@\(addressName)", .secondary)
            } else {
                text = .none
            }
            return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: peer, presence: nil, text: text, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: 0, action: {
                action(peer)
            }, setPeerIdWithRevealedOptions: { _, _ in
            }, removePeer: { _ in
            }, contextAction: { node, gesture in
                openPeerContextAction(peer, node, gesture)
            }, hasTopStripe: false, noInsets: true, noCorners: true, style: .plain, disableInteractiveTransitionIfNecessary: true)
        }
    }
}

private func preparedTransition(from fromEntries: [RecommendedPeersListEntry], to toEntries: [RecommendedPeersListEntry], context: AccountContext, presentationData: PresentationData, action: @escaping (EnginePeer) -> Void, openPeerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void) -> RecommendedPeersListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, action: action, openPeerContextAction: openPeerContextAction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, action: action, openPeerContextAction: openPeerContextAction), directionHint: nil) }
    
    return RecommendedPeersListTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: toEntries.count < fromEntries.count)
}

private protocol RecommendedPeers {
    
}

extension RecommendedChannels: RecommendedPeers {
    
}

extension RecommendedBots: RecommendedPeers {
    
}

final class PeerInfoRecommendedPeersPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let chatControllerInteraction: ChatControllerInteraction
    private let openPeerContextAction: (Bool, EnginePeer, ASDisplayNode, ContextGesture?) -> Void
    
    weak var parentController: ViewController?
    
    private let listNode: ListView
    private var currentEntries: [RecommendedPeersListEntry] = []
    private var enqueuedTransactions: [RecommendedPeersListTransaction] = []
    private var currentState: (RecommendedPeers?, Bool)?
    
    private var unlockBackground: EdgeEffectView?
    private var unlockText: ComponentView<Empty>?
    private var unlockButton: ComponentView<Empty>?
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private let presentationDataPromise = Promise<PresentationData>()
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }
    
    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    var tabBarOffset: CGFloat {
        return 0.0
    }
        
    private var disposable: Disposable?
    
    init(context: AccountContext, peerId: EnginePeer.Id, chatControllerInteraction: ChatControllerInteraction, openPeerContextAction: @escaping (Bool, EnginePeer, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.chatControllerInteraction = chatControllerInteraction
        self.openPeerContextAction = openPeerContextAction
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.listNode = ListViewImpl()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        let signal: Signal<RecommendedPeers?, NoError>
        if peerId.namespace == Namespaces.Peer.CloudUser {
            signal = context.engine.peers.recommendedBots(peerId: peerId)
            |> map {
                $0 as RecommendedPeers?
            }
        } else {
            signal = context.engine.peers.recommendedChannels(peerId: peerId)
            |> map {
                $0 as RecommendedPeers?
            }
        }
            
        self.disposable = (combineLatest(queue: .mainQueue(),
            self.presentationDataPromise.get(),
            signal,
            context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                return peer?.isPremium ?? false
            }
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData, recommendedPeers, isPremium in
            guard let self else {
                return
            }
            self.currentState = (recommendedPeers, isPremium)
            self.updateState(recommendedPeers: recommendedPeers, isPremium: isPremium, presentationData: presentationData)
        })
                
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            if let self {
                self.layoutUnlockPanel(transition: .animated(duration: 0.4, curve: .spring))
            }
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func ensureMessageIsVisible(id: EngineMessage.Id) {
    }
    
    func scrollToTop() -> Bool {
        if !self.listNode.scrollToOffsetFromTop(0.0, animated: true) {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            return true
        } else {
            return false
        }
    }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.currentParams == nil
        self.currentParams = (size, sideInset, bottomInset, isScrollingLockedAtTop, presentationData)
        self.presentationDataPromise.set(.single(presentationData))
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)

        var scrollToItem: ListViewScrollToItem?
        if isScrollingLockedAtTop {
            switch self.listNode.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            default:
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: duration), directionHint: .Up)
            }
        }
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
        
        if isFirstLayout, let (recommendedPeers, isPremium) = self.currentState {
            self.updateState(recommendedPeers: recommendedPeers, isPremium: isPremium, presentationData: presentationData)
        }
    }
    
    @objc private func unlockPressed() {
        let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .ads, forceDark: false, dismissed: nil)
        self.chatControllerInteraction.navigationController()?.pushViewController(controller)
    }
    
    private func updateState(recommendedPeers: RecommendedPeers?, isPremium: Bool, presentationData: PresentationData) {
        if let recommendedChannels = recommendedPeers as? RecommendedChannels {
            self.updateState(recommendedChannels: recommendedChannels, isPremium: isPremium, presentationData: presentationData)
        } else if let recommendedBots = recommendedPeers as? RecommendedBots {
            self.updateState(recommendedBots: recommendedBots, isPremium: isPremium, presentationData: presentationData)
        }
    }
    
    private func updateState(recommendedChannels: RecommendedChannels?, isPremium: Bool, presentationData: PresentationData) {
        var entries: [RecommendedPeersListEntry] = []
                                
        if let channels = recommendedChannels?.channels {
            for channel in channels {
                entries.append(.peer(theme: presentationData.theme, index: entries.count, peer: channel.peer, subscribers: channel.subscribers))
            }
        }
        
        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, action: { [weak self] peer in
            self?.chatControllerInteraction.openPeer(peer, .default, nil, .default)
        }, openPeerContextAction: { [weak self] peer, node, gesture in
            self?.openPeerContextAction(true, peer, node, gesture)
        })
        
        self.currentEntries = entries
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
        
        if let recommendedChannels {
            self.statusPromise.set(.single(
                PeerInfoStatusData(text: presentationData.strings.SharedMedia_SimilarChannelCount(recommendedChannels.count), isActivity: true, key: .similarChannels)
            ))
        }
    }
    
    private func updateState(recommendedBots: RecommendedBots?, isPremium: Bool, presentationData: PresentationData) {
        var entries: [RecommendedPeersListEntry] = []
                                
        if let bots = recommendedBots?.bots {
            for bot in bots {
                var subscriberCount: Int32 = 0
                if case let .user(user) = bot {
                    subscriberCount = user.subscriberCount ?? 0
                }
                entries.append(.peer(theme: presentationData.theme, index: entries.count, peer: bot, subscribers: subscriberCount))
            }
        }
        
        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, action: { [weak self] peer in
            self?.chatControllerInteraction.openPeer(peer, .info(nil), nil, .default)
        }, openPeerContextAction: { [weak self] peer, node, gesture in
            self?.openPeerContextAction(true, peer, node, gesture)
        })
        
        self.currentEntries = entries
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
        
        if let recommendedBots {
            self.statusPromise.set(.single(
                PeerInfoStatusData(text: presentationData.strings.SharedMedia_SimilarBotCount(recommendedBots.count), isActivity: true, key: .similarBots)
            ))
        }
    }
    
    private func layoutUnlockPanel(transition: ContainedViewLayoutTransition) {
        guard let (_, isPremium) = self.currentState, let currentParams = self.currentParams else {
            return
        }
        if !isPremium {
            var transition = transition
            let size = currentParams.size
            let sideInset = currentParams.sideInset
            let bottomInset = currentParams.bottomInset
            let presentationData = currentParams.presentationData
          
            let unlockText: ComponentView<Empty>
            let unlockBackground: EdgeEffectView
            let unlockButton: ComponentView<Empty>
            if let current = self.unlockText {
                unlockText = current
            } else {
                unlockText = ComponentView<Empty>()
                self.unlockText = unlockText
                transition = .immediate
            }
            
            if let current = self.unlockBackground {
                unlockBackground = current
            } else {
                unlockBackground = EdgeEffectView()
                self.view.addSubview(unlockBackground)
                self.unlockBackground = unlockBackground
            }
            
            var isBots = false
            if let (state, _) = self.currentState, state is RecommendedBots {
                isBots = true
            }
                                    
            if let current = self.unlockButton {
                unlockButton = current
            } else {
                unlockButton = ComponentView<Empty>()
                self.unlockButton = unlockButton
            }
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = presentationData.theme.list.itemSecondaryTextColor
            let linkColor = presentationData.theme.list.itemAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor), linkAttribute: { _ in
                return nil
            })
            
            var scrollOffset: CGFloat = 0.0
            if case let .known(offset) = self.listNode.visibleBottomContentOffset() {
                scrollOffset = min(0.0, offset + bottomInset + 80.0)
            }
            
            let unlockSize = unlockText.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .markdown(text: isBots ? presentationData.strings.PeerInfo_SimilarBots_ShowMoreInfo : presentationData.strings.Channel_SimilarChannels_ShowMoreInfo, attributes: markdownAttributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - 32.0, height: 200.0)
            )
            if let view = unlockText.view {
                if view.superview == nil {
                    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.unlockPressed)))
                    self.view.addSubview(view)
                }
                transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((size.width - unlockSize.width) / 2.0), y: size.height - bottomInset - unlockSize.height - 13.0 + scrollOffset), size: unlockSize))
            }
            
            let buttonForegroundColor = presentationData.theme.list.itemCheckColors.foregroundColor
            let buttonSideInset = sideInset + 30.0
            let buttonSize = unlockButton.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: presentationData.theme.list.itemCheckColors.fillColor,
                        foreground: buttonForegroundColor,
                        pressedColor: presentationData.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(Text(text: isBots ? presentationData.strings.PeerInfo_SimilarBots_ShowMore : presentationData.strings.Channel_SimilarChannels_ShowMore, font: Font.semibold(17.0), color: buttonForegroundColor))),
                            AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(LottieComponent(
                                content: LottieComponent.AppBundleContent(name: "premium_unlock"),
                                color: buttonForegroundColor,
                                startingPosition: .begin,
                                size: CGSize(width: 30.0, height: 30.0),
                                loop: true
                            )))
                        ], spacing: 4.0)
                    )),
                    action: { [weak self] in
                        self?.unlockPressed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: size.width - buttonSideInset * 2.0, height: 52.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: buttonSideInset, y: size.height - bottomInset - unlockSize.height - buttonSize.height - 26.0 + scrollOffset), size: buttonSize)
            
            let edgeEffectInset: CGFloat = 24.0
            let edgeEffectFrame = CGRect(x: 0.0, y: buttonFrame.minY - edgeEffectInset, width: size.width, height: size.height + scrollOffset - buttonFrame.minY + edgeEffectInset)
            transition.updateFrame(view: unlockBackground, frame: edgeEffectFrame)
            unlockBackground.update(
                content: presentationData.theme.list.plainBackgroundColor,
                blur: true,
                alpha: 1.0,
                rect: edgeEffectFrame,
                edge: .bottom,
                edgeSize: edgeEffectInset + floor(buttonSize.height * 0.5),
                transition: ComponentTransition(transition)
            )
            
            if let buttonView = unlockButton.view {
                if buttonView.superview == nil {
                    self.view.addSubview(buttonView)
                }
                transition.updateFrame(view: buttonView, frame: buttonFrame)
            }
        } else {
            self.unlockBackground?.removeFromSuperview()
            self.unlockBackground = nil
            
            self.unlockButton?.view?.removeFromSuperview()
            self.unlockButton = nil
                        
            self.unlockText?.view?.removeFromSuperview()
            self.unlockText = nil
        }
    }
    
    private func dequeueTransaction() {
        guard let _ = self.currentParams, let transaction = self.enqueuedTransactions.first else {
            return
        }
        
        self.enqueuedTransactions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if transaction.animated {
            options.insert(.AnimateInsertion)
        } else {
            options.insert(.Synchronous)
        }
        
        self.listNode.transaction(deleteIndices: transaction.deletions, insertIndicesAndItems: transaction.insertions, updateIndicesAndItems: transaction.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.didSetReady {
                strongSelf.didSetReady = true
                strongSelf.ready.set(.single(true))
            }
        })
    }
    
    func findLoadedMessage(id: EngineMessage.Id) -> EngineMessage? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
    
    func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
            self.listNode.transferVelocity(velocity)
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: EngineMessage.Id, media: EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func addToTransitionSurface(view: UIView) {
    }
    
    func updateSelectedMessages(animated: Bool) {
    }
}
