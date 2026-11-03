import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import ViewControllerComponent
import PeerListItemComponent
import MultilineTextComponent

// Shared renderer for the main grid and independently retained folder pages.
// Vertical scrolling and visible-item allocation remain owned by the sheet.
final class ShareScreenItemsView: UIView, UIScrollViewDelegate {
    let recommendations = UIScrollView()
    private let sectionTitle = ComponentView<Empty>()
    private let emptyLabel = ComponentView<Empty>()
    private let activity = UIActivityIndicatorView(style: .medium)
    var visibleItems: [String: ComponentView<Empty>] = [:]
    private(set) var contentHeight: CGFloat = 0.0
    private var component: ShareScreenContentComponent?
    private var environment: ViewControllerComponentContainer.Environment?
    private var visibleBounds: CGRect = .zero
    private var pagePeers: [EnginePeer] = []
    private var pageFilterId: Int32 = 0
    private var pageLoading = false
    private var isUpdating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.recommendations)
        self.addSubview(self.activity)
        self.recommendations.delegate = self
        self.recommendations.alwaysBounceHorizontal = true
        self.recommendations.disablesInteractiveTransitionGestureRecognizer = true
        self.recommendations.showsVerticalScrollIndicator = false
        self.recommendations.showsHorizontalScrollIndicator = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.isUpdating, let component = self.component, let environment = self.environment else { return }
        self.update(component: component, environment: environment, availableWidth: self.bounds.width, visibleBounds: self.visibleBounds, peers: self.pagePeers, filterId: self.pageFilterId, isLoading: self.pageLoading, transition: .immediate)
    }

    func update(component: ShareScreenContentComponent, environment: ViewControllerComponentContainer.Environment, availableWidth: CGFloat, visibleBounds: CGRect, peers: [EnginePeer], filterId: Int32, isLoading: Bool, transition: ComponentTransition) {
        self.isUpdating = true
        defer { self.isUpdating = false }
        let model = component.model
        let theme = environment.theme
        let strings = environment.strings
        self.component = component
        self.environment = environment
        self.visibleBounds = visibleBounds
        self.pagePeers = peers
        self.pageFilterId = filterId
        self.pageLoading = isLoading
        let width = availableWidth
        guard width > 0.0 else { return }
        let columns = max(3, Int(floor(width / 72.0)))
        let cellWidth = (width - 20.0) / CGFloat(columns)
        var validIds = Set<String>()
        let visible = visibleBounds.insetBy(dx: 0.0, dy: -120.0)
        let synchronousLoad = transition.userData(PeerListItemComponent.TransitionHint.self)?.synchronousLoad ?? false
        func makeItemTransition(_ item: ComponentView<Empty>) -> ComponentTransition {
            let isNew = item.view == nil
            return (isNew ? .immediate : transition).withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: synchronousLoad && isNew))
        }
        func gridItem(id: String, peer: EnginePeer?, story: Bool, frame: CGRect, parent: UIView) {
            validIds.insert(id)
            let item = self.visibleItems[id] ?? ComponentView<Empty>()
            let itemTransition = makeItemTransition(item)
            self.visibleItems[id] = item
            let communityChats: [EnginePeer]
            if let peer, case .community = peer {
                communityChats = model.selectedCommunityChats(peer.id)
            } else {
                communityChats = peer.flatMap { model.selection.topicPeers[$0.id] }.map { [$0] } ?? []
            }
            let title: String
            if story { title = strings.Share_RepostToStory }
            else if peer?.id == model.context.account.peerId { title = strings.DialogList_SavedMessages }
            else if communityChats.count == 1 { title = communityChats[0].compactDisplayTitle }
            else if communityChats.count > 1 { title = strings.FolderLinkPreview_TextAddChatsCount(Int32(clamping: communityChats.count)) }
            else { title = peer.map { model.displayPeer($0).compactDisplayTitle } ?? "" }
            var online = false
            if let peer, let presence = model.presences[peer.id], case let .present(until) = presence.status {
                online = until > Int32(Date().timeIntervalSince1970)
            }
            let _ = item.update(transition: itemTransition, component: AnyComponent(ShareScreenPeerComponent(context: model.context, theme: theme, peer: peer, title: title, avatarPeer: peer.map { model.displayPeer($0) }, topicData: peer.flatMap { model.selection.topicData[$0.id] }, communityChats: Array(communityChats.prefix(3)), isStory: story, playsStoryAnimation: story && !model.didPlayRepostAnimation, selected: !communityChats.isEmpty || (peer.map { model.selection.contains($0.id) } ?? false), online: online, requirement: peer.map { model.messagingRequirement(for: $0) } ?? ShareScreenMessagingRequirement(), action: { [weak self] in
                guard let self, let component = self.component else { return }
                if story { component.story?() } else if let peer { component.select(peer) }
            })), environment: {}, containerSize: frame.size)
            if story {
                model.didPlayRepostAnimation = true
            }
            if let view = item.view {
                let isNew = view.superview == nil
                if view.superview !== parent { parent.addSubview(view) }
                itemTransition.setFrame(view: view, frame: frame)
                if isNew, parent === self, let start = model.appearanceAnimationStart {
                    let now = CACurrentMediaTime()
                    if now - start < 1.0 {
                        let row = max(0.0, floor((frame.minY - 8.0) / 100.0))
                        let delay = max(0.0, start + 0.12 + row * 0.055 - now)
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: delay)
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: 26.0), to: .zero, duration: 0.4, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1.0), additive: true)
                    }
                }

            }
        }
        var y: CGFloat = 8.0
        if model.isSearching {
            y = 4.0
            let showsRecents = model.query.isEmpty && filterId == 0
            self.recommendations.isHidden = !showsRecents
            if !showsRecents { self.sectionTitle.view?.isHidden = true }
            if showsRecents {
                self.recommendations.frame = CGRect(x: 0.0, y: y, width: width, height: 106.0)
                let recommended = (model.recommendations.isEmpty ? Array(peers.prefix(8)) : model.recommendations).filter { $0.id != model.context.account.peerId }
                let recommendationBounds = self.recommendations.bounds.insetBy(dx: -84.0, dy: 0.0)
                let recommendedRange = visible.intersects(self.recommendations.frame) ? shareScreenVisibleItems(min: recommendationBounds.minX, max: recommendationBounds.maxX, origin: 0.0, stride: 84.0, count: recommended.count) : 0 ..< 0
                for index in recommendedRange {
                    let item = recommended[index]
                    gridItem(id: "recent-\(item.id)", peer: item, story: false, frame: CGRect(x: CGFloat(index) * 84.0, y: 0.0, width: 84.0, height: 100.0), parent: self.recommendations)
                }
                let recommendationsContentSize = CGSize(width: CGFloat(recommended.count) * 84.0, height: 106.0)
                if self.recommendations.contentSize != recommendationsContentSize {
                    self.recommendations.contentSize = recommendationsContentSize
                }
                y += 104.0
                shareScreenUpdateText(self.sectionTitle, parent: self, string: strings.ShareScreen_RecentChats, font: Font.semibold(17.0), color: theme.list.itemSecondaryTextColor, frame: CGRect(x: 16.0, y: y, width: width - 32.0, height: 30.0))
                y += 30.0
            }
            let visibleRange = shareScreenVisibleItems(min: visible.minY, max: visible.maxY, origin: y, stride: 60.0, count: peers.count)
            for index in visibleRange {
                let peer = peers[index]
                let frame = CGRect(x: 0.0, y: y + CGFloat(index) * 60.0, width: width, height: 60.0)
                let id = "list-\(peer.id)"
                validIds.insert(id)
                let item = self.visibleItems[id] ?? ComponentView<Empty>()
                let itemTransition = makeItemTransition(item)
                self.visibleItems[id] = item
                let isCommunity: Bool
                if case .community = peer { isCommunity = true } else { isCommunity = false }
                var subtitle = model.participantCounts[peer.id].map { PeerListItemComponent.Subtitle(text: strings.Conversation_StatusMembers(Int32($0)), color: .neutral) }
                var presence = model.presences[peer.id]
                if case let .user(user) = peer, user.botInfo != nil, let username = user.addressName, !username.isEmpty {
                    subtitle = PeerListItemComponent.Subtitle(text: "@\(username)", color: .neutral)
                    presence = nil
                }
                let _ = item.update(transition: itemTransition, component: AnyComponent(ShareScreenRestrictedRowComponent(content: AnyComponent(PeerListItemComponent(
                    context: model.context, theme: theme, strings: strings, style: .share, sideInset: 12.0,
                    title: peer.id == model.context.account.peerId ? strings.DialogList_SavedMessages : model.displayPeer(peer).displayTitle(strings: strings, displayOrder: model.context.sharedContext.currentPresentationData.with { $0.nameDisplayOrder }),
                    peer: peer, avatarPeer: model.displayPeer(peer), avatarOverrideImage: peer.id == model.context.account.peerId ? .savedMessagesIcon : nil, subtitle: subtitle, subtitleAccessory: .none, presence: presence,
                    rightAccessory: (isCommunity || peer._asPeer().isForumOrMonoForum) && !model.selection.contains(peer.id) ? .disclosure : .none,
                    selectionState: (isCommunity || peer._asPeer().isForumOrMonoForum) && !model.selection.contains(peer.id) || !model.query.isEmpty ? .none : .editing(isSelected: model.selection.contains(peer.id), isTinted: false), selectionPosition: .right, isEnabled: !model.messagingRequirement(for: peer).requiresPremium, hasNext: index != peers.count - 1,
                    action: { [weak self] peer, _, _ in self?.component?.select(peer) }
                )), theme: theme, requirement: model.messagingRequirement(for: peer))), environment: {}, containerSize: frame.size)
                if let view = item.view {
                    if view.superview == nil { self.addSubview(view) }
                    itemTransition.setFrame(view: view, frame: frame)
                    view.isAccessibilityElement = true
                    view.accessibilityLabel = peer.displayTitle(strings: strings, displayOrder: model.context.sharedContext.currentPresentationData.with { $0.nameDisplayOrder })
                    view.accessibilityTraits = model.selection.contains(peer.id) ? [.button, .selected] : .button

                }
            }
            y += CGFloat(peers.count) * 60.0
        } else {
            self.recommendations.isHidden = true
            self.sectionTitle.view?.isHidden = true
            var leadingPeers: [(EnginePeer?, Bool)] = []
            let showsLeadingItems = !model.defersItemsUntilFirstLoad || model.didCompleteFirstLoad
            if showsLeadingItems && component.story != nil { leadingPeers.append((nil, true)) }
            if showsLeadingItems, let peer = model.accountPeer { leadingPeers.append((peer, false)) }
            let itemCount = leadingPeers.count + peers.count
            let visibleRange = shareScreenVisibleItems(min: visible.minY, max: visible.maxY, origin: y, stride: 100.0, count: itemCount, columns: columns)
            for index in visibleRange {
                let item: (EnginePeer?, Bool) = index < leadingPeers.count ? leadingPeers[index] : (peers[index - leadingPeers.count], false)
                let frame = CGRect(x: 10.0 + CGFloat(index % columns) * cellWidth, y: y + CGFloat(index / columns) * 100.0, width: cellWidth, height: 100.0)
                if visible.intersects(frame) {
                    gridItem(id: "grid-\(item.0.map { String(describing: $0.id) } ?? "story")", peer: item.0, story: item.1, frame: frame, parent: self)
                }
            }
            y += CGFloat((itemCount + columns - 1) / columns) * 100.0
        }
        self.activity.center = CGPoint(x: width * 0.5, y: shareScreenActivityCenterY(contentBottom: y, visibleBounds: visibleBounds, bottomInset: component.bottomInset))
        self.activity.color = theme.list.itemSecondaryTextColor
        if isLoading && peers.isEmpty && model.isSearching { self.activity.startAnimating() } else { self.activity.stopAnimating() }
        shareScreenUpdateText(self.emptyLabel, parent: self, string: strings.ChatList_Search_NoResults, font: Font.regular(17.0), color: theme.list.itemSecondaryTextColor, alignment: .center, maximumNumberOfLines: 0, frame: CGRect(x: 24.0, y: y + 24.0, width: width - 48.0, height: 60.0), isHidden: !peers.isEmpty || isLoading)
        self.contentHeight = y + 16.0 + component.bottomInset
        self.bounds.size = CGSize(width: width, height: max(y + 100.0, self.contentHeight))

        for id in Array(self.visibleItems.keys) where !validIds.contains(id) {
            self.visibleItems.removeValue(forKey: id)?.view?.removeFromSuperview()
        }
    }
}

func shareScreenUpdateText(_ text: ComponentView<Empty>, parent: UIView, string: String, font: UIFont, color: UIColor, alignment: NSTextAlignment = .natural, maximumNumberOfLines: Int = 1, frame: CGRect, isHidden: Bool = false) {
    let size = text.update(
        transition: .immediate,
        component: AnyComponent(MultilineTextComponent(
            text: .plain(NSAttributedString(string: string, font: font, textColor: color)),
            horizontalAlignment: alignment,
            truncationType: .end,
            maximumNumberOfLines: maximumNumberOfLines
        )),
        environment: {},
        containerSize: frame.size
    )
    guard let view = text.view else { return }
    if view.superview !== parent {
        view.isUserInteractionEnabled = false
        parent.addSubview(view)
    }
    view.isHidden = isHidden
    let x: CGFloat
    switch alignment {
    case .center:
        x = frame.minX + floorToScreenPixels((frame.width - size.width) * 0.5)
    case .right:
        x = frame.maxX - size.width
    default:
        x = frame.minX
    }
    view.frame = CGRect(x: x, y: frame.minY + floorToScreenPixels((frame.height - size.height) * 0.5), width: size.width, height: size.height)
}
