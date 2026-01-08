import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import LegacyChatHeaderPanelComponent
import HorizontalPeerItem
import MergeLists
import ContextUI
import AnimationCache
import MultiAnimationRenderer
import TelegramUIPreferences
import AvatarNode

private struct RecentChatsEntry: Comparable, Identifiable {
    let index: Int
    let context: AccountContext
    let peer: EnginePeer
    let presence: EnginePeer.Presence?
    let unreadBadge: (Int32, Bool)?
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    var stableId: EnginePeer.Id {
        return self.peer.id
    }
    
    static func ==(lhs: RecentChatsEntry, rhs: RecentChatsEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.presence != rhs.presence {
            return false
        }
        if lhs.unreadBadge?.0 != rhs.unreadBadge?.0 {
            return false
        }
        if lhs.unreadBadge?.1 != rhs.unreadBadge?.1 {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    static func <(lhs: RecentChatsEntry, rhs: RecentChatsEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(
        accountPeerId: EnginePeer.Id,
        postbox: Postbox,
        network: Network,
        energyUsageSettings: EnergyUsageSettings,
        contentSettings: ContentSettings,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        resolveInlineStickers: @escaping ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>,
        peerSelected: @escaping (EnginePeer) -> Void,
        isPeerSelected: @escaping (EnginePeer.Id) -> Bool,
        itemWidth: CGFloat
    ) -> ListViewItem {
        return RecentChatCapsuleItem(
            context: self.context,
            theme: self.theme,
            strings: self.strings,
            peer: self.peer,
            isSelected: isPeerSelected(self.peer.id),
            action: peerSelected,
            itemWidth: itemWidth
        )
    }
}

private final class RecentChatCapsuleItem: ListViewItem {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer
    let isSelected: Bool
    let action: (EnginePeer) -> Void
    let itemWidth: CGFloat
    let panelHeight: CGFloat

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        isSelected: Bool,
        action: @escaping (EnginePeer) -> Void,
        itemWidth: CGFloat,
        panelHeight: CGFloat = 50.0
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.isSelected = isSelected
        self.action = action
        self.itemWidth = itemWidth
        self.panelHeight = panelHeight
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = RecentChatCapsuleNode()
            let (layout, apply) = node.asyncLayout()(self, params)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply()
                    })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? RecentChatCapsuleNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

private final class RecentChatCapsuleNode: ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    
    private var item: RecentChatCapsuleItem?
    private var normalBackgroundColor: UIColor?
    private var highlightedBackgroundColor: UIColor?

    init() {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor(white: 1.0, alpha: 0.5) // Liquid glass base
        self.backgroundNode.cornerRadius = 18.0
        self.backgroundNode.clipsToBounds = false // Allow shadow to spill out
        // Add a subtle border for glass effect
        self.backgroundNode.borderColor = UIColor(white: 1.0, alpha: 0.8).cgColor
        self.backgroundNode.borderWidth = 1.0
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 13.0))
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 26.0, height: 26.0))
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false)
        
        // Transform for horizontal listing
        self.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.titleNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                item.action(item.peer)
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if let highlightedBackgroundColor = self.highlightedBackgroundColor {
            self.backgroundNode.backgroundColor = highlightedBackgroundColor
        }
        UIView.animate(withDuration: 0.1) {
            self.containerNode.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
            self.containerNode.alpha = 0.8
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if let normalBackgroundColor = self.normalBackgroundColor {
            UIView.animate(withDuration: 0.2) {
                self.backgroundNode.backgroundColor = normalBackgroundColor
            }
        }
        UIView.animate(withDuration: 0.15) {
            self.containerNode.transform = CATransform3DIdentity
            self.containerNode.alpha = 1.0
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        if let normalBackgroundColor = self.normalBackgroundColor {
            UIView.animate(withDuration: 0.2) {
                self.backgroundNode.backgroundColor = normalBackgroundColor
            }
        }
        UIView.animate(withDuration: 0.15) {
            self.containerNode.transform = CATransform3DIdentity
            self.containerNode.alpha = 1.0
        }
    }

    func asyncLayout() -> (RecentChatCapsuleItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params in
            // Visual Specs (Screen Coordinates)
            let visualItemWidth = item.itemWidth // Screen Width Chunk
            let visualPanelHeight = item.panelHeight // Screen Height (50.0)
            
            // Layout Specs (List Coordinates - Rotated -90deg)
            let listContentSize = CGSize(width: visualPanelHeight, height: visualItemWidth)
            
            // Content Specs
            let capsuleHeight: CGFloat = 36.0
            
            // Styling based on Theme
            let isDark = item.theme.overallDarkAppearance
            let glassColor = isDark ? UIColor(white: 1.0, alpha: 0.2) : UIColor(white: 1.0, alpha: 0.5)
            
            // Border Color Logic
            let borderColor: CGColor
            let borderWidth: CGFloat
            let shadowColor: CGColor?
            let shadowOpacity: Float
            let shadowRadius: CGFloat
            
            if item.isSelected {
                // Green Glowing Border
                borderColor = UIColor.green.cgColor
                borderWidth = 2.0
                shadowColor = UIColor.green.cgColor
                shadowOpacity = 0.6
                shadowRadius = 8.0
            } else {
                // Standard Glass Border
                borderColor = isDark ? UIColor(white: 1.0, alpha: 0.3).cgColor : UIColor(white: 1.0, alpha: 0.8).cgColor
                borderWidth = 1.0
                shadowColor = nil
                shadowOpacity = 0.0
                shadowRadius = 0.0
            }

            let textColor: UIColor = isDark ? .white : .black
            
            // Build title string
            let peerTitle = item.peer.displayTitle(strings: item.strings, displayOrder: .firstLast)
            let titleString = NSAttributedString(string: peerTitle, font: Font.bold(12.0), textColor: textColor)
            
            // Visual Layout inside container
            let sideMargin: CGFloat = 2.0
            let capsuleWidth = visualItemWidth - (sideMargin * 2.0)
            
            // Max text width
            // 26 (avatar) + 12 (margins/spacing)
            // Left offset: 5 (margin) + 26 (avatar) + 6 (spacing) = 37.0
            // Right offset requested: ~5.0
            // Total deduction: 37 + 5 = 42.0
            let maxTextWidth = capsuleWidth - 42.0
            
            // Ensure width is at least something to avoid empty constraints
            // Ensure width is at least something to avoid empty constraints
            let textConstrainedWidth = max(1.0, maxTextWidth)
            
            // Highlight Color Logic
            let highlightedGlassColor = isDark ? UIColor(white: 1.0, alpha: 0.3) : UIColor(white: 1.0, alpha: 0.7)
            
            // Truncation: No "..." (Clipping behavior via empty token)
            let (titleLayout, titleApply) = TextNode.asyncLayout(self?.titleNode)(TextNodeLayoutArguments(attributedString: titleString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textConstrainedWidth, height: capsuleHeight), customTruncationToken: NSAttributedString(string: "")))
            
            return (ListViewItemNodeLayout(contentSize: listContentSize, insets: UIEdgeInsets()), {
                guard let strongSelf = self else { return }
                strongSelf.item = item
                
                // containerNode represents the Visual Item (Screen Coords)
                strongSelf.containerNode.bounds = CGRect(origin: .zero, size: CGSize(width: visualItemWidth, height: visualPanelHeight))
                strongSelf.containerNode.position = CGPoint(x: listContentSize.width / 2.0, y: listContentSize.height / 2.0)
                
                // Now layout inside containerNode
                let capsuleY = (visualPanelHeight - capsuleHeight) / 2.0
                let capsuleX = sideMargin
                
                let containerFrame = CGRect(x: capsuleX, y: capsuleY, width: capsuleWidth, height: capsuleHeight)
                
                strongSelf.backgroundNode.frame = containerFrame
                strongSelf.backgroundNode.cornerRadius = capsuleHeight / 2.0
                strongSelf.backgroundNode.backgroundColor = glassColor
                
                strongSelf.normalBackgroundColor = glassColor
                strongSelf.highlightedBackgroundColor = highlightedGlassColor
                
                // Apply Border & Shadow
                strongSelf.backgroundNode.borderColor = borderColor
                strongSelf.backgroundNode.borderWidth = borderWidth
                strongSelf.backgroundNode.layer.shadowColor = shadowColor
                strongSelf.backgroundNode.layer.shadowOpacity = shadowOpacity
                strongSelf.backgroundNode.layer.shadowRadius = shadowRadius
                strongSelf.backgroundNode.layer.shadowOffset = CGSize(width: 0, height: 0)
                
                let avatarSize: CGFloat = 26.0
                let avatarFrame = CGRect(x: containerFrame.minX + 5.0, y: containerFrame.minY + (capsuleHeight - avatarSize) / 2.0, width: avatarSize, height: avatarSize)
                strongSelf.avatarNode.frame = avatarFrame
                
                let titleFrame = CGRect(x: avatarFrame.maxX + 6.0, y: containerFrame.minY + (capsuleHeight - titleLayout.size.height) / 2.0, width: titleLayout.size.width, height: titleLayout.size.height)
                strongSelf.titleNode.frame = titleFrame
                
                let _ = titleApply()
                strongSelf.avatarNode.setPeer(context: item.context, theme: item.theme, peer: item.peer, synchronousLoad: false, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
            })
        }
    }
}

private struct RecentChatsTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let firstTime: Bool
    let animated: Bool
}

private func preparedRecentChatsTransition(
    accountPeerId: EnginePeer.Id,
    postbox: Postbox,
    network: Network,
    energyUsageSettings: EnergyUsageSettings,
    contentSettings: ContentSettings,
    animationCache: AnimationCache,
    animationRenderer: MultiAnimationRenderer,
    resolveInlineStickers: @escaping ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>,
    peerSelected: @escaping (EnginePeer) -> Void,
    isPeerSelected: @escaping (EnginePeer.Id) -> Bool,
    itemWidth: CGFloat,
    from fromEntries: [RecentChatsEntry],
    to toEntries: [RecentChatsEntry],
    firstTime: Bool,
    animated: Bool
) -> RecentChatsTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(
        accountPeerId: accountPeerId,
        postbox: postbox,
        network: network,
        energyUsageSettings: energyUsageSettings,
        contentSettings: contentSettings,
        animationCache: animationCache,
        animationRenderer: animationRenderer,
        resolveInlineStickers: resolveInlineStickers,
        peerSelected: peerSelected,
        isPeerSelected: isPeerSelected,
        itemWidth: itemWidth
    ), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(
        accountPeerId: accountPeerId,
        postbox: postbox,
        network: network,
        energyUsageSettings: energyUsageSettings,
        contentSettings: contentSettings,
        animationCache: animationCache,
        animationRenderer: animationRenderer,
        resolveInlineStickers: resolveInlineStickers,
        peerSelected: peerSelected,
        isPeerSelected: isPeerSelected,
        itemWidth: itemWidth
    ), directionHint: nil) }
    
    return RecentChatsTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, animated: animated)
}

final class RecentChatsPanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let listView: ListView
    private let peerSelected: (EnginePeer) -> Void
    
    private let disposable = MetaDisposable()
    private var queuedTransitions: [RecentChatsTransition] = []
    
    private var theme: PresentationTheme?
    private var strings: PresentationStrings?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    
    private var currentEntries: [RecentChatsEntry] = []
    private var currentItemWidth: CGFloat = 80.0
    
    private var currentPeers: ([EnginePeer], [EnginePeer.Id: (Int32, Bool)], [EnginePeer.Id: EnginePeer.Presence])?
    
    init(context: AccountContext, animationCache: AnimationCache?, animationRenderer: MultiAnimationRenderer?, peerSelected: @escaping (EnginePeer) -> Void) {
        self.context = context
        self.peerSelected = peerSelected
        
        self.listView = ListView()
        self.listView.preloadPages = false
        self.listView.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                self.listView.scrollEnabled = true
        self.listView.backgroundColor = .clear
        
        // Hide scroll indicators
        self.listView.scroller.showsVerticalScrollIndicator = false
        self.listView.scroller.showsHorizontalScrollIndicator = false
        
        super.init()
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.addSubnode(self.listView)
        
        // Use tailChatListView to get the actual chat list (users + groups)
        let recent = context.account.postbox.tailChatListView(
            groupId: .root,
            count: 50,
            summaryComponents: ChatListEntrySummaryComponents()
        )
        |> map { viewUpdate -> [EnginePeer] in
            let view = viewUpdate.0
            var peers: [EnginePeer] = []
            for entry in view.entries.reversed() {
                if case let .MessageEntry(entryData) = entry {
                    if let peer = entryData.renderedPeer.peer {
                        if peer.id == context.account.peerId {
                            continue
                        }
                        peers.append(EnginePeer(peer))
                    }
                }
            }
            return peers
        }
        
        self.disposable.set(
            (recent 
            |> distinctUntilChanged 
            |> mapToSignal { (peers: [EnginePeer]) -> Signal<([EnginePeer], [EnginePeer.Id: (Int32, Bool)], [EnginePeer.Id: EnginePeer.Presence]), NoError> in
                if peers.isEmpty {
                    return .single(([], [:], [:]) as ([EnginePeer], [EnginePeer.Id: (Int32, Bool)], [EnginePeer.Id: EnginePeer.Presence]))
                }
                
                let signals: [Signal<PeerView, NoError>] = peers.map {
                    context.account.postbox.peerView(id: $0.id)
                }
                
                return combineLatest(queue: .mainQueue(), signals)
                |> mapToSignal { (peerViews: [PeerView]) -> Signal<([EnginePeer], [EnginePeer.Id: (Int32, Bool)], [EnginePeer.Id: EnginePeer.Presence]), NoError> in
                    return context.account.postbox.combinedView(keys: peerViews.map { item -> PostboxViewKey in
                        let key = PostboxViewKey.unreadCounts(items: [UnreadMessageCountsItem.peer(id: item.peerId, handleThreads: true)])
                        return key
                    })
                    |> map { views -> [EnginePeer.Id: Int] in
                        var result: [EnginePeer.Id: Int] = [:]
                        for item in peerViews {
                            let key = PostboxViewKey.unreadCounts(items: [UnreadMessageCountsItem.peer(id: item.peerId, handleThreads: true)])
                            
                            if let view = views.views[key] as? UnreadMessageCountsView {
                                result[item.peerId] = Int(view.count(for: .peer(id: item.peerId, handleThreads: true)) ?? 0)
                            } else {
                                result[item.peerId] = 0
                            }
                        }
                        return result
                    }
                    |> map { unreadCounts in
                        var peers: [EnginePeer] = []
                        var unread: [EnginePeer.Id: (Int32, Bool)] = [:]
                        var presences: [EnginePeer.Id: EnginePeer.Presence] = [:]
                        for peerView in peerViews {
                            if let peer = peerViewMainPeer(peerView) {
                                var isMuted: Bool = false
                                if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                    switch notificationSettings.muteState {
                                    case .muted:
                                        isMuted = true
                                    default:
                                        break
                                    }
                                }
                                
                                let unreadCount = unreadCounts[peerView.peerId]
                                if let unreadCount, unreadCount > 0 {
                                    unread[peerView.peerId] = (Int32(unreadCount), isMuted)
                                }
                                
                                if let presence = peerView.peerPresences[peer.id] {
                                    presences[peer.id] = EnginePeer.Presence(presence)
                                }
                                
                                peers.append(EnginePeer(peer))
                            }
                        }
                        return (peers, unread, presences)
                    }
                }
            }
            |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                guard let self = self else { return }
                self.currentPeers = peers
                self.updateList()
            })
        )
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private var currentInterfaceState: ChatPresentationInterfaceState?
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        self.currentInterfaceState = interfaceState
        
        var themeUpdated = false
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            themeUpdated = true
        }
        if self.strings !== interfaceState.strings {
            self.strings = interfaceState.strings
            themeUpdated = true
        }
        
        if themeUpdated {
            self.updateList()
        }
        
        // Panel setup
        let panelHeight: CGFloat = 50.0 
        let topPadding: CGFloat = 4.0
        
        // Exact division for distribution
        let itemWidth = width / 4.0
        self.currentItemWidth = itemWidth
        
        // Configure ListView:
        // Position: X centered, Y pushed down by topPadding + half height
        // Bounds: Width=Height(50), Height=Width(Screen) to account for -90 rotation
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: panelHeight, height: width)
        self.listView.position = CGPoint(x: width / 2.0, y: topPadding + (panelHeight / 2.0))
        
        // Add 4px padding to left/right for the container (which are Top/Bottom in rotated list)
        // Rotated Map: Top=Left, Bottom=Right
        let verticalInsets = UIEdgeInsets(top: leftInset + 4.0, left: 0.0, bottom: rightInset + 4.0, right: 0.0)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: panelHeight, height: width), insets: verticalInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })

        return LayoutResult(backgroundHeight: panelHeight + topPadding, insetHeight: panelHeight + topPadding, hitTestSlop: 0.0)
    }
    
    private func updateList() {
        guard let peers = self.currentPeers, let theme = self.theme, let strings = self.strings else {
            return
        }
        
        var entries: [RecentChatsEntry] = []
        for peer in peers.0 {
            entries.append(RecentChatsEntry(index: entries.count, context: self.context, peer: peer, presence: peers.2[peer.id], unreadBadge: peers.1[peer.id], theme: theme, strings: strings))
        }
        
        let transition = preparedRecentChatsTransition(
            accountPeerId: self.context.account.peerId,
            postbox: self.context.account.postbox,
            network: self.context.account.network,
            energyUsageSettings: self.context.sharedContext.energyUsageSettings,
            contentSettings: self.context.currentContentSettings.with { $0 },
            animationCache: self.context.animationCache,
            animationRenderer: self.context.animationRenderer,
            resolveInlineStickers: { _ in return .single([:]) },
            peerSelected: self.peerSelected,
            isPeerSelected: { [weak self] peerId in
                return self?.currentInterfaceState?.chatLocation.peerId == peerId
            },
            itemWidth: self.currentItemWidth,
            from: self.currentEntries,
            to: entries,
            firstTime: self.currentEntries.isEmpty,
            animated: !self.currentEntries.isEmpty
        )
        
        self.currentEntries = entries
        self.enqueueTransition(transition)
    }
    
    private func enqueueTransition(_ transition: RecentChatsTransition) {
        self.queuedTransitions.append(transition)
        self.dequeueTransitions()
    }
    
    private func dequeueTransitions() {
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.firstTime {
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
                options.insert(.Synchronous)
                options.insert(.LowLatency)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            }
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { _ in })
        }
    }
}
