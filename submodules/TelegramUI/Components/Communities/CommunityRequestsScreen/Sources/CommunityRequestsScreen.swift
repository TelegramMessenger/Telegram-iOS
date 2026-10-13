import Foundation
import LottieSettings
import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import Markdown
import ListSectionComponent
import PeerListItemComponent
import AlertComponent
import ButtonComponent
import EdgeEffect
import CommunityEditScreen
import CommunityPrivateChatScreen
import UndoUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode

private struct CommunityRequestRow: Equatable {
    let request: CommunityPeerRequest
    let peer: EnginePeer
    let requestedBy: EnginePeer?
    let memberCount: Int32?
    let isPrivate: Bool
    let isVisible: Bool
}

private struct PendingCommunityRequestAction {
    let request: CommunityPeerRequest
    let approve: Bool
    var isCommitted: Bool
}

private final class CommunityRequestsEmptyPlaceholderView: UIView {
    private let animationNode: AnimatedStickerNode
    private let title = ComponentView<Empty>()
    private let text = ComponentView<Empty>()

    private let lottieSettings: LottieRenderingSettings

    init(frame: CGRect, lottieSettings: LottieRenderingSettings) {
        self.lottieSettings = lottieSettings
        self.animationNode = DefaultAnimatedStickerNodeImpl(lottieSettings: lottieSettings)
        self.animationNode.setup(
            source: AnimatedStickerNodeLocalFileSource(name: "TwoFactorSetupRememberSuccess"),
            width: 192,
            height: 192,
            playbackMode: .once,
            mode: .direct(cachePathPrefix: nil)
        )
        self.animationNode.visibility = true

        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.addSubview(self.animationNode.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(theme: PresentationTheme, strings: PresentationStrings, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
        let imageSpacing: CGFloat = 10.0
        let textSpacing: CGFloat = 8.0
        let imageSize = CGSize(width: 112.0, height: 112.0)
        let imageHeight = availableSize.width < availableSize.height ? imageSize.height + imageSpacing : 0.0

        let textWidth = availableSize.width - 80.0
        let titleSize = self.title.update(
            transition: transition,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: strings.Community_Request_EmptyTitle,
                    font: Font.bold(17.0),
                    textColor: theme.list.freeTextColor
                )),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: textWidth, height: max(1.0, availableSize.height))
        )
        let textSize = self.text.update(
            transition: transition,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: strings.Community_Request_EmptyText,
                    font: Font.regular(14.0),
                    textColor: theme.list.freeTextColor
                )),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: textWidth, height: max(1.0, availableSize.height))
        )

        let totalHeight = imageHeight + titleSize.height + textSpacing + textSize.height
        let topOffset = floorToScreenPixels(max(0.0, (availableSize.height - totalHeight) / 2.0))

        self.animationNode.updateLayout(size: imageSize)
        transition.setFrame(view: self.animationNode.view, frame: CGRect(
            origin: CGPoint(
                x: floorToScreenPixels((availableSize.width - imageSize.width) / 2.0),
                y: topOffset
            ),
            size: imageSize
        ))
        transition.setAlpha(view: self.animationNode.view, alpha: imageHeight > 0.0 ? 1.0 : 0.0)

        if let titleView = self.title.view {
            if titleView.superview == nil {
                self.addSubview(titleView)
            }
            transition.setFrame(view: titleView, frame: CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0),
                    y: topOffset + imageHeight
                ),
                size: titleSize
            ))
        }
        if let textView = self.text.view {
            if textView.superview == nil {
                self.addSubview(textView)
            }
            transition.setFrame(view: textView, frame: CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - textSize.width) / 2.0),
                    y: topOffset + imageHeight + titleSize.height + textSpacing
                ),
                size: textSize
            ))
        }

        return CGSize(width: availableSize.width, height: max(1.0, totalHeight))
    }
}

private final class CommunityRequestsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let communityId: EnginePeer.Id
    let requestsContext: CommunityPeerLinkRequestsContext

    init(context: AccountContext, communityId: EnginePeer.Id, requestsContext: CommunityPeerLinkRequestsContext) {
        self.context = context
        self.communityId = communityId
        self.requestsContext = requestsContext
    }

    static func ==(lhs: CommunityRequestsScreenComponent, rhs: CommunityRequestsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
            return false
        }
        if lhs.requestsContext !== rhs.requestsContext {
            return false
        }
        return true
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        private let approvalInfoText = ComponentView<Empty>()
        private let requestsSection = ComponentView<Empty>()
        private var emptyPlaceholderView: CommunityRequestsEmptyPlaceholderView?
        private let declineAllButton = ComponentView<Empty>()
        private let addAllButton = ComponentView<Empty>()
        private let bottomEdgeEffectView = EdgeEffectView()

        private var component: CommunityRequestsScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        private var ignoreScrolling = false

        private var community: TelegramCommunity?
        private var requests: [CommunityPeerRequest]?
        private var peers: [EnginePeer.Id: EnginePeer] = [:]
        private var cachedPeerData: [EnginePeer.Id: EngineCachedPeerData] = [:]
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        private var pendingRequestActions: [EnginePeer.Id: PendingCommunityRequestAction] = [:]
        private weak var currentRequestUndoOverlayController: UndoOverlayController?

        private var communityDisposable: Disposable?
        private var loadDisposable: Disposable?
        private var cachedDataDisposable: Disposable?
        private var cachedDataPeerIds = Set<EnginePeer.Id>()
        private var requestedCachedPeerIds = Set<EnginePeer.Id>()

        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.scrollView.delegate = self
            self.addSubview(self.scrollView)

            self.bottomEdgeEffectView.isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.commitPendingRequestActions()
            self.currentRequestUndoOverlayController?.dismiss()
            self.communityDisposable?.dispose()
            self.loadDisposable?.dispose()
            self.cachedDataDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
            if scrollView.contentOffset.y + scrollView.bounds.height > scrollView.contentSize.height - 200.0 {
                self.component?.requestsContext.loadMore(limit: 100)
            }
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let navigationBar = controller.navigationBar, let edgeEffectView = navigationBar.edgeEffectView else {
                return
            }
            let alphaDistance: CGFloat = 16.0
            let edgeEffectAlpha = max(0.0, min(1.0, self.scrollView.contentOffset.y / alphaDistance))
            transition.setAlpha(view: edgeEffectView, alpha: edgeEffectAlpha)
        }

        private var rows: [CommunityRequestRow] {
            guard let requests = self.requests else {
                return []
            }
            var result: [CommunityRequestRow] = []
            for request in requests {
                if self.pendingRequestActions[request.peerId] != nil {
                    continue
                }
                if let peer = self.peers[request.peerId] {
                    result.append(CommunityRequestRow(
                        request: request,
                        peer: peer,
                        requestedBy: self.peers[request.requestedBy],
                        memberCount: self.memberCount(peerId: request.peerId),
                        isPrivate: self.isPrivate(peer),
                        isVisible: request.isVisible
                    ))
                }
            }
            return result
        }

        private func memberCount(peerId: EnginePeer.Id) -> Int32? {
            guard let cachedData = self.cachedPeerData[peerId] else {
                return nil
            }
            if let cachedData = cachedData as? CachedChannelData {
                return cachedData.participantsSummary.memberCount
            } else if let cachedData = cachedData as? CachedGroupData, let participants = cachedData.participants {
                return Int32(participants.participants.count)
            } else {
                return nil
            }
        }

        private func isPrivate(_ peer: EnginePeer) -> Bool {
            if let addressName = peer.addressName, !addressName.isEmpty {
                return false
            }
            if peer.usernames.contains(where: { $0.flags.contains(.isActive) && !$0.username.isEmpty }) {
                return false
            }
            return true
        }

        private var displaysApprovalInfo: Bool {
            return self.community?.defaultBannedRights?.flags.contains(.banManageLinkedPeers) == true
        }

        private func ensureCommunitySignal(component: CommunityRequestsScreenComponent) {
            if self.communityDisposable != nil {
                return
            }
            self.communityDisposable = (component.context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.communityId)
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self else {
                    return
                }
                if let peer, case let .community(community) = peer {
                    self.community = community
                } else {
                    self.community = nil
                }
                self.state?.updated(transition: .spring(duration: 0.35))
            })
        }

        private func ensureLoaded(component: CommunityRequestsScreenComponent) {
            if self.loadDisposable != nil {
                return
            }
            self.loadDisposable = (component.requestsContext.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                self.requests = result.hasLoadedOnce ? result.requests : nil
                self.peers = result.peers
                self.prunePendingRequestActions()
                self.ensureCachedData(component: component)
                self.state?.updated(transition: .spring(duration: 0.35))
            })
            component.requestsContext.loadMore(limit: 100)
        }

        private func ensureCachedData(component: CommunityRequestsScreenComponent) {
            guard let requests = self.requests else {
                return
            }

            var orderedPeerIds: [EnginePeer.Id] = []
            var peerIds = Set<EnginePeer.Id>()
            for request in requests {
                if !peerIds.contains(request.peerId) {
                    peerIds.insert(request.peerId)
                    orderedPeerIds.append(request.peerId)
                }
            }

            if peerIds == self.cachedDataPeerIds {
                return
            }
            self.cachedDataPeerIds = peerIds

            if orderedPeerIds.isEmpty {
                self.cachedDataDisposable?.dispose()
                self.cachedDataDisposable = nil
                self.cachedPeerData = [:]
                return
            }

            for peerId in orderedPeerIds {
                if !self.requestedCachedPeerIds.contains(peerId) {
                    self.requestedCachedPeerIds.insert(peerId)
                    component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerId)
                }
            }

            self.cachedDataDisposable?.dispose()
            self.cachedDataDisposable = (component.context.engine.data.subscribe(
                EngineDataMap(orderedPeerIds.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] cachedDataById in
                guard let self else {
                    return
                }
                var cachedPeerData: [EnginePeer.Id: EngineCachedPeerData] = [:]
                for peerId in orderedPeerIds {
                    if let maybeCachedData = cachedDataById[peerId], let cachedData = maybeCachedData {
                        cachedPeerData[peerId] = cachedData
                    }
                }
                self.cachedPeerData = cachedPeerData
                self.state?.updated(transition: .spring(duration: 0.35))
            })
        }

        private func alertText(_ text: String, boldText: String, presentationData: PresentationData) -> NSAttributedString {
            let result = NSMutableAttributedString(string: text, font: Font.regular(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
            if let range = text.range(of: boldText) {
                result.addAttribute(.font, value: Font.semibold(13.0), range: NSRange(range, in: text))
            }
            return result
        }

        private func openCommunitySettings() {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            if let navigationController = controller.navigationController as? NavigationController {
                if let editController = navigationController.viewControllers.last(where: { $0 is CommunityEditScreen }) {
                    let _ = navigationController.popToViewController(editController, animated: true)
                } else {
                    let editController = component.context.sharedContext.makeCommunityEditScreen(context: component.context, communityId: component.communityId)
                    navigationController.pushViewController(editController)
                }
            } else {
                let editController = component.context.sharedContext.makeCommunityEditScreen(context: component.context, communityId: component.communityId)
                controller.present(editController, in: .window(.root))
            }
        }

        private func presentBulkConfirmation(approve: Bool, count: Int) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            self.commitCurrentRequestUndoOverlay(animateAsReplacement: false)

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let countText = presentationStringsFormattedNumber(Int32(clamping: count), presentationData.dateTimeFormat.groupingSeparator)
            let title: String
            let text: String
            let actionTitle: String
            let actionType: AlertScreen.Action.ActionType
            if approve {
                title = environment.strings.Community_Request_AddAllChats
                text = environment.strings.Community_Request_AddAllConfirmation(countText).string
                actionTitle = environment.strings.Community_Request_Add
                actionType = .default
            } else {
                title = environment.strings.Community_Request_DeclineAll
                text = environment.strings.Community_Request_DeclineAllConfirmation(countText).string
                actionTitle = environment.strings.Community_Request_Decline
                actionType = .defaultDestructive
            }

            environment.controller()?.present(AlertScreen(
                context: component.context,
                content: [
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(AlertTitleComponent(title: title))
                    ),
                    AnyComponentWithIdentity(
                        id: "text",
                        component: AnyComponent(AlertTextComponent(
                            content: .attributed(self.alertText(text, boldText: countText, presentationData: presentationData))
                        ))
                    )
                ],
                actions: [
                    AlertScreen.Action(title: environment.strings.Common_Cancel),
                    AlertScreen.Action(title: actionTitle, type: actionType, action: { [weak self] in
                        self?.performBulkApproval(approve: approve)
                    })
                ]
            ), in: .window(.root))
        }

        private func performBulkApproval(approve: Bool) {
            guard let component = self.component else {
                return
            }
            self.commitCurrentRequestUndoOverlay(animateAsReplacement: false)
            component.requestsContext.updateAll(action: approve ? .approve : .deny)
        }

        private func prunePendingRequestActions() {
            guard let requests = self.requests else {
                return
            }
            let requestIds = Set(requests.map(\.peerId))
            for peerId in Array(self.pendingRequestActions.keys) {
                if !requestIds.contains(peerId) {
                    self.pendingRequestActions.removeValue(forKey: peerId)
                }
            }
        }

        private func commitPendingRequestAction(peerId: EnginePeer.Id) {
            guard var pendingAction = self.pendingRequestActions[peerId], !pendingAction.isCommitted else {
                return
            }
            guard let component = self.component else {
                return
            }
            pendingAction.isCommitted = true
            self.pendingRequestActions[peerId] = pendingAction
            component.requestsContext.update(pendingAction.request, action: pendingAction.approve ? .approve : .deny)
            self.state?.updated(transition: .spring(duration: 0.35))
        }

        private func commitPendingRequestActions() {
            let peerIds = Array(self.pendingRequestActions.keys)
            for peerId in peerIds {
                self.commitPendingRequestAction(peerId: peerId)
            }
        }

        @discardableResult
        private func commitCurrentRequestUndoOverlay(animateAsReplacement: Bool) -> Bool {
            guard let currentRequestUndoOverlayController = self.currentRequestUndoOverlayController else {
                return false
            }
            if animateAsReplacement {
                currentRequestUndoOverlayController.dismissWithCommitActionAndReplacementAnimation()
            } else {
                currentRequestUndoOverlayController.dismissWithCommitAction()
            }
            self.currentRequestUndoOverlayController = nil
            return true
        }

        private func setRequestApproval(request: CommunityPeerRequest, peer: EnginePeer, approve: Bool) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }

            let animateInAsReplacement = self.commitCurrentRequestUndoOverlay(animateAsReplacement: true)

            let peerId = request.peerId
            self.pendingRequestActions[peerId] = PendingCommunityRequestAction(
                request: request,
                approve: approve,
                isCommitted: false
            )
            self.state?.updated(transition: .spring(duration: 0.35))

            let title: String = peer.compactDisplayTitle
            let text: String
            if approve {
                text = environment.strings.Community_Request_ApprovedToast
            } else {
                text = environment.strings.Community_Request_DeclinedToast
            }

            let undoController = UndoOverlayController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                content: .invitedToVoiceChat(
                    context: component.context,
                    peer: peer,
                    title: title,
                    text: text,
                    action: environment.strings.Undo_Undo,
                    duration: 3.0
                ),
                elevatedLayout: false,
                animateInAsReplacement: animateInAsReplacement,
                action: { [weak self] action in
                    guard let self else {
                        return false
                    }
                    switch action {
                    case .commit:
                        self.commitPendingRequestAction(peerId: peerId)
                        return true
                    case .undo:
                        if let pendingAction = self.pendingRequestActions[peerId], !pendingAction.isCommitted {
                            self.pendingRequestActions.removeValue(forKey: peerId)
                            self.state?.updated(transition: .spring(duration: 0.35))
                        }
                        return true
                    case .info:
                        return false
                    }
                }
            )
            self.currentRequestUndoOverlayController = undoController
            controller.present(undoController, in: .current)
        }

        private func openPeer(_ peer: EnginePeer) {
            guard let component = self.component, let environment = self.environment, let navigationController = environment.controller()?.navigationController as? NavigationController else {
                return
            }
            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: component.context,
                chatLocation: .peer(peer),
                keepStack: .always,
                forceOpenChat: true
            ))
        }

        private func openRequest(row: CommunityRequestRow) {
            if !row.isPrivate {
                self.openPeer(row.peer)
                return
            }

            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = CommunityPrivateChatScreen(
                context: component.context,
                chatPeer: row.peer,
                requestedByPeer: row.requestedBy,
                memberCount: row.memberCount,
                messageOwner: { [weak self, requestedBy = row.requestedBy] in
                    if let requestedBy {
                        self?.openPeer(requestedBy)
                    }
                }
            )
            environment.controller()?.present(controller, in: .window(.root))
        }

        private func requestItem(component: CommunityRequestsScreenComponent, row: CommunityRequestRow, hasNext: Bool, theme: PresentationTheme, presentationData: PresentationData) -> AnyComponentWithIdentity<Empty> {
            return AnyComponentWithIdentity(id: row.request.peerId, component: AnyComponent(CommunityRequestItemComponent(
                context: component.context,
                theme: theme,
                strings: presentationData.strings,
                chatPeer: row.peer,
                requestedByPeer: row.requestedBy,
                memberCount: row.memberCount,
                isPrivate: row.isPrivate,
                isVisible: row.isVisible,
                isEnabled: true,
                declineDisplaysProgress: false,
                addDisplaysProgress: false,
                hasNext: hasNext,
                open: { [weak self] _ in
                    self?.openRequest(row: row)
                },
                add: { [weak self] _ in
                    self?.setRequestApproval(request: row.request, peer: row.peer, approve: true)
                },
                decline: { [weak self] _ in
                    self?.setRequestApproval(request: row.request, peer: row.peer, approve: false)
                }
            )))
        }

        func update(component: CommunityRequestsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment

            self.ensureCommunitySignal(component: component)
            self.ensureLoaded(component: component)
            self.ensureCachedData(component: component)

            let theme = environment.theme
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let sideInset: CGFloat = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let contentWidth = availableSize.width - sideInset * 2.0

            self.backgroundColor = theme.list.blocksBackgroundColor
            self.scrollView.backgroundColor = theme.list.blocksBackgroundColor

            var contentHeight = environment.navigationHeight + 16.0

            if self.displaysApprovalInfo {
                contentHeight += 2.0

                var transition = transition
                if self.approvalInfoText.view == nil {
                    transition = .immediate
                }

                if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== theme {
                    if let chevronImage = generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.list.itemAccentColor) {
                        self.cachedChevronImage = (chevronImage, theme)
                    }
                }

                let linkAttributeKey = NSAttributedString.Key(rawValue: "URL")
                let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.freeTextColor)
                let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemAccentColor)
                let approvalInfoRawText = environment.strings.Community_Request_ApprovalInfo.replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                let approvalInfoAttributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(approvalInfoRawText, attributes: MarkdownAttributes(
                    body: body,
                    bold: body,
                    link: link,
                    linkAttribute: { contents in
                        return ("URL", contents)
                    }
                )))
                if let range = approvalInfoAttributedText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                    approvalInfoAttributedText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: approvalInfoAttributedText.string))
                }

                let approvalInfoSize = self.approvalInfoText.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(approvalInfoAttributedText),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2,
                        highlightColor: theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[linkAttributeKey] {
                                return linkAttributeKey
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            if let _ = attributes[linkAttributeKey] {
                                self?.openCommunitySettings()
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth - 32.0, height: 10000.0)
                )
                if let approvalInfoView = self.approvalInfoText.view {
                    if approvalInfoView.superview == nil {
                        self.scrollView.addSubview(approvalInfoView)
                    }
                    transition.setFrame(view: approvalInfoView, frame: CGRect(
                        origin: CGPoint(x: sideInset + 16.0, y: contentHeight),
                        size: approvalInfoSize
                    ))
                    transition.setAlpha(view: approvalInfoView, alpha: 1.0)
                }
                contentHeight += approvalInfoSize.height + 26.0
            } else if let approvalInfoView = self.approvalInfoText.view {
                transition.setAlpha(view: approvalInfoView, alpha: 0.0, completion: { [weak approvalInfoView] _ in
                    approvalInfoView?.removeFromSuperview()
                })
            }

            let rows = self.rows
            let displaysBulkActions = rows.count > 1
            let bottomButtonHeight: CGFloat = 50.0
            let bottomButtonSpacing: CGFloat = 10.0
            let bottomButtonSideInset: CGFloat = 30.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let bottomPanelHeight: CGFloat = displaysBulkActions ? (16.0 + bottomButtonHeight + 12.0 + environment.safeInsets.bottom) : 0.0

            if !rows.isEmpty {
                var items: [AnyComponentWithIdentity<Empty>] = []
                for i in 0 ..< rows.count {
                    items.append(self.requestItem(
                        component: component,
                        row: rows[i],
                        hasNext: i != rows.count - 1,
                        theme: theme,
                        presentationData: presentationData
                    ))
                }

                let requestsSectionTitle = environment.strings.Community_Request_SectionTitle(Int32(clamping: rows.count))

                var sectionTransition = transition
                if self.requestsSection.view == nil {
                    sectionTransition = .immediate
                }

                let sectionSize = self.requestsSection.update(
                    transition: sectionTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: requestsSectionTitle,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        footer: nil,
                        items: items
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth, height: 10000.0)
                )
                if let sectionView = self.requestsSection.view {
                    if sectionView.superview == nil {
                        sectionView.alpha = 0.0
                        self.scrollView.addSubview(sectionView)
                    }
                    sectionTransition.setFrame(view: sectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: sectionSize))
                    transition.setAlpha(view: sectionView, alpha: 1.0)
                }
                if let emptyPlaceholderView = self.emptyPlaceholderView {
                    transition.setAlpha(view: emptyPlaceholderView, alpha: 0.0, completion: { [weak emptyPlaceholderView] _ in
                        emptyPlaceholderView?.removeFromSuperview()
                    })
                    self.emptyPlaceholderView = nil
                }
                contentHeight += sectionSize.height + 24.0
            } else {
                if let sectionView = self.requestsSection.view {
                    transition.setAlpha(view: sectionView, alpha: 0.0, completion: { [weak sectionView] _ in
                        sectionView?.removeFromSuperview()
                    })
                }

                if let _ = self.requests {
                    var emptyPlaceholderTransition = transition
                    let emptyPlaceholderView: CommunityRequestsEmptyPlaceholderView
                    if let current = self.emptyPlaceholderView {
                        emptyPlaceholderView = current
                    } else {
                        emptyPlaceholderTransition = .immediate
                        
                        emptyPlaceholderView = CommunityRequestsEmptyPlaceholderView(frame: CGRect(), lottieSettings: component.context.lottieRenderingSettings)
                        emptyPlaceholderView.alpha = 0.0
                        self.emptyPlaceholderView = emptyPlaceholderView
                        self.scrollView.addSubview(emptyPlaceholderView)
                    }

                    let placeholderTop = contentHeight
                    let placeholderHeight = max(1.0, availableSize.height - placeholderTop - environment.safeInsets.bottom)
                    let placeholderWidth = max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right)
                    let _ = emptyPlaceholderView.update(
                        theme: theme,
                        strings: environment.strings,
                        availableSize: CGSize(width: placeholderWidth, height: placeholderHeight),
                        transition: emptyPlaceholderTransition
                    )
                    let placeholderFrame = CGRect(
                        origin: CGPoint(x: environment.safeInsets.left, y: placeholderTop),
                        size: CGSize(width: placeholderWidth, height: placeholderHeight)
                    )
                    emptyPlaceholderTransition.setFrame(view: emptyPlaceholderView, frame: placeholderFrame)
                    transition.setAlpha(view: emptyPlaceholderView, alpha: 1.0)
                    contentHeight = max(contentHeight, placeholderFrame.maxY + 24.0)
                }
            }

            if displaysBulkActions {
                let bottomEdgeEffectFrame = CGRect(
                    origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight),
                    size: CGSize(width: availableSize.width, height: bottomPanelHeight)
                )
                transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
                self.bottomEdgeEffectView.update(
                    content: theme.list.blocksBackgroundColor,
                    blur: true,
                    alpha: 1.0,
                    rect: bottomEdgeEffectFrame,
                    edge: .bottom,
                    edgeSize: bottomPanelHeight,
                    transition: transition
                )
                if self.bottomEdgeEffectView.superview == nil {
                    self.addSubview(self.bottomEdgeEffectView)
                }
                transition.setAlpha(view: self.bottomEdgeEffectView, alpha: 1.0)

                var buttonsTransition = transition
                if self.declineAllButton.view == nil {
                    buttonsTransition = .immediate
                }

                let buttonY = availableSize.height - environment.safeInsets.bottom - 12.0 - bottomButtonHeight
                let buttonsWidth = availableSize.width - bottomButtonSideInset * 2.0
                let buttonWidth = floorToScreenPixels((buttonsWidth - bottomButtonSpacing) / 2.0)
                let declineButtonSize = self.declineAllButton.update(
                    transition: buttonsTransition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                            foreground: theme.list.itemPrimaryTextColor,
                            pressedColor: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.16),
                            cornerRadius: 25.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(ButtonTextContentComponent(
                                text: environment.strings.Community_Request_DeclineAll,
                                badge: 0,
                                textColor: theme.list.itemPrimaryTextColor,
                                badgeBackground: theme.list.itemPrimaryTextColor,
                                badgeForeground: theme.list.blocksBackgroundColor
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            self?.presentBulkConfirmation(approve: false, count: rows.count)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: buttonWidth, height: bottomButtonHeight)
                )
                let addButtonSize = self.addAllButton.update(
                    transition: buttonsTransition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                            cornerRadius: 25.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(ButtonTextContentComponent(
                                text: environment.strings.Community_Request_AddAll,
                                badge: 0,
                                textColor: theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                badgeForeground: theme.list.itemCheckColors.fillColor
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            self?.presentBulkConfirmation(approve: true, count: rows.count)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: buttonWidth, height: bottomButtonHeight)
                )

                if let declineButtonView = self.declineAllButton.view {
                    if declineButtonView.superview == nil {
                        self.addSubview(declineButtonView)
                    }
                    buttonsTransition.setFrame(view: declineButtonView, frame: CGRect(
                        origin: CGPoint(x: bottomButtonSideInset, y: buttonY),
                        size: CGSize(width: buttonWidth, height: declineButtonSize.height)
                    ))
                    transition.setAlpha(view: declineButtonView, alpha: 1.0)
                }
                if let addButtonView = self.addAllButton.view {
                    if addButtonView.superview == nil {
                        self.addSubview(addButtonView)
                    }
                    buttonsTransition.setFrame(view: addButtonView, frame: CGRect(
                        origin: CGPoint(x: bottomButtonSideInset + buttonWidth + bottomButtonSpacing, y: buttonY),
                        size: CGSize(width: buttonWidth, height: addButtonSize.height)
                    ))
                    transition.setAlpha(view: addButtonView, alpha: 1.0)
                }
            } else {
                if let declineButtonView = self.declineAllButton.view {
                    transition.setAlpha(view: declineButtonView, alpha: 0.0, completion: { [weak declineButtonView] _ in
                        declineButtonView?.removeFromSuperview()
                    })
                }
                if let addButtonView = self.addAllButton.view {
                    transition.setAlpha(view: addButtonView, alpha: 0.0, completion: { [weak addButtonView] _ in
                        addButtonView?.removeFromSuperview()
                    })
                }
                transition.setAlpha(view: self.bottomEdgeEffectView, alpha: 0.0, completion: { [weak self] _ in
                    self?.bottomEdgeEffectView.removeFromSuperview()
                })
            }

            contentHeight += 24.0 + (displaysBulkActions ? bottomPanelHeight : environment.safeInsets.bottom)

            let contentSize = CGSize(width: availableSize.width, height: max(contentHeight, availableSize.height + 1.0))
            self.ignoreScrolling = true
            if self.scrollView.frame.size != availableSize {
                self.scrollView.frame = CGRect(origin: .zero, size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: bottomPanelHeight, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            self.ignoreScrolling = false

            self.updateScrolling(transition: transition)

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class CommunityRequestsScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, communityId: EnginePeer.Id, existingContext: CommunityPeerLinkRequestsContext? = nil) {
        let requestsContext = existingContext ?? context.engine.peers.communityPeerLinkRequestsContext(communityId: communityId, initialLimit: 100)
        super.init(
            context: context,
            component: CommunityRequestsScreenComponent(context: context, communityId: communityId, requestsContext: requestsContext),
            navigationBarAppearance: .default,
            theme: .default,
            updatedPresentationData: nil
        )

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = presentationData.strings.Community_Request_Title
        self.navigationItem.title = presentationData.strings.Community_Request_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? CommunityRequestsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
