import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import AvatarComponent
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import PeerListItemComponent

private final class CommunitiesScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peerId: EnginePeer.Id?

    init(context: AccountContext, peerId: EnginePeer.Id?) {
        self.context = context
        self.peerId = peerId
    }

    static func ==(lhs: CommunitiesScreenComponent, rhs: CommunitiesScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        return true
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    private struct CommunityListEntry {
        let peer: EnginePeer
        let cachedData: CachedCommunityData?
    }

    private static func canAddChats(to peer: EnginePeer) -> Bool {
        guard case let .community(community) = peer else {
            return false
        }
        return community.hasPermission(.manageLinkedPeers)
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView

        private let avatarShadow = UIImageView()
        private let peerAvatar = ComponentView<Empty>()
        private let navigationTitle = ComponentView<Empty>()
        private let titleTransformContainer: UIView
        private let subtitle = ComponentView<Empty>()
        private let createSection = ComponentView<Empty>()
        private let communitiesSection = ComponentView<Empty>()

        private var component: CommunitiesScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        private var isUpdating = false
        private var ignoreScrolling = false
        private var didRequestRefresh = false
        private var isActionInProgress = false
        private weak var createCommunityController: ViewController?

        private var subjectPeer: EnginePeer?
        private var communities: [CommunityListEntry] = []
        private var requestedCachedCommunityIds = Set<EnginePeer.Id>()
        private var subjectPeerDisposable: Disposable?
        private var communitiesDisposable: Disposable?
        private var actionDisposable = MetaDisposable()

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

            self.titleTransformContainer = UIView()
            self.titleTransformContainer.isUserInteractionEnabled = false
            
            self.avatarShadow.image = UIImage(bundleImageName: "Components/CommunityShadow")
            
            super.init(frame: frame)

            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.titleTransformContainer.removeFromSuperview()
            self.subjectPeerDisposable?.dispose()
            self.communitiesDisposable?.dispose()
            self.actionDisposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment else {
                return
            }

            let titleCenterY: CGFloat = environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) * 0.5
            let titleTransformDistance: CGFloat = 20.0
            let titleY: CGFloat = max(titleCenterY, self.titleTransformContainer.center.y - self.scrollView.contentOffset.y)

            transition.setSublayerTransform(view: self.titleTransformContainer, transform: CATransform3DMakeTranslation(0.0, titleY - self.titleTransformContainer.center.y, 0.0))

            let titleYDistance: CGFloat = titleY - titleCenterY
            let titleTransformFraction: CGFloat = 1.0 - max(0.0, min(1.0, titleYDistance / titleTransformDistance))
            let titleMinScale: CGFloat = 17.0 / 24.0
            let titleScale: CGFloat = 1.0 * (1.0 - titleTransformFraction) + titleMinScale * titleTransformFraction
            if let navigationTitleView = self.navigationTitle.view {
                transition.setScale(view: navigationTitleView, scale: titleScale)
            }

            if let controller = environment.controller(), let navigationBar = controller.navigationBar {
                let edgeEffectAlphaDistance = max(1.0, self.titleTransformContainer.center.y - titleCenterY)
                let edgeEffectAlpha = max(0.0, min(1.0, self.scrollView.contentOffset.y / edgeEffectAlphaDistance))
                navigationBar.setBackdropAlpha(edgeEffectAlpha, transition: transition.containedViewLayoutTransition)
            }
        }

        private func ensureSubjectPeerSignal(component: CommunitiesScreenComponent) {
            guard let peerId = component.peerId else {
                if self.subjectPeer != nil {
                    self.subjectPeer = nil
                    self.state?.updated(transition: .immediate)
                }
                return
            }
            if self.subjectPeerDisposable == nil {
                self.subjectPeerDisposable = (component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                    guard let self else {
                        return
                    }
                    self.subjectPeer = peer
                    self.state?.updated(transition: .spring(duration: 0.4))
                })
            }
        }

        private func ensureCommunitiesSignal(component: CommunitiesScreenComponent) {
            if self.communitiesDisposable == nil {
                self.communitiesDisposable = (component.context.engine.peers.updatedCommunitiesState()
                |> mapToSignal { state -> Signal<[CommunityListEntry], NoError> in
                    guard let communityIds = state.communityIds else {
                        return .single([])
                    }
                    return combineLatest(
                        component.context.engine.data.subscribe(
                            EngineDataMap(communityIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                        ),
                        component.context.engine.data.subscribe(
                            EngineDataMap(communityIds.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
                        )
                    )
                    |> map { peersById, cachedDataById -> [CommunityListEntry] in
                        var result: [CommunityListEntry] = []
                        for id in communityIds {
                            if let maybePeer = peersById[id], let peer = maybePeer {
                                if !CommunitiesScreenComponent.canAddChats(to: peer) {
                                    continue
                                }
                                var cachedCommunityData: CachedCommunityData?
                                if let maybeCachedData = cachedDataById[id], let cachedData = maybeCachedData {
                                    cachedCommunityData = cachedData as? CachedCommunityData
                                }
                                result.append(CommunityListEntry(peer: peer, cachedData: cachedCommunityData))
                            }
                        }
                        return result
                    }
                }
                |> deliverOnMainQueue).startStrict(next: { [weak self, context = component.context] communities in
                    guard let self else {
                        return
                    }
                    for community in communities {
                        if !self.requestedCachedCommunityIds.contains(community.peer.id) {
                            self.requestedCachedCommunityIds.insert(community.peer.id)
                            context.account.viewTracker.forceUpdateCachedPeerData(peerId: community.peer.id)
                        }
                    }
                    self.communities = communities
                    self.state?.updated(transition: .spring(duration: 0.4))
                })
            }

            if !self.didRequestRefresh {
                self.didRequestRefresh = true
                let _ = component.context.engine.peers.joinedCommunities().startStandalone()
            }
        }

        private func dismissController(additionalController: ViewController? = nil) {
            guard let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                additionalController?.dismiss()
                return
            }
            var viewControllers = navigationController.viewControllers
            viewControllers = viewControllers.filter { c in
                if c is CommunitiesScreen || c is PeerInfoScreen || c === additionalController {
                    return false
                } else {
                    return true
                }
            }
            navigationController.setViewControllers(viewControllers, animated: true)
            
            Queue.mainQueue().after(0.1, {
                for controller in viewControllers.reversed() {
                    if let chatController = controller as? ChatController {
                        chatController.playConfettiAnimation()
                        break
                    }
                }
            })
        }

        private func openCreateCommunity(component: CommunitiesScreenComponent) {
            guard let peerId = component.peerId, let environment = self.environment else {
                return
            }
            
            let controller = component.context.sharedContext.makeCommunityEditScreen(
                context: component.context,
                mode: .create(peerId: peerId),
                completed: { [weak self] in
                    self?.dismissController(additionalController: self?.createCommunityController)
                }
            )
            self.createCommunityController = controller
            controller.navigationPresentation = .modal
            if let navigationController = environment.controller()?.navigationController as? NavigationController {
                navigationController.pushViewController(controller)
            } else {
                environment.controller()?.present(controller, in: .window(.root))
            }
        }

        private func linkCommunity(component: CommunitiesScreenComponent, community: EnginePeer) {
            guard let peerId = component.peerId, let environment = self.environment else {
                return
            }
            if self.isActionInProgress {
                return
            }

            let controller = component.context.sharedContext.makeCommunityAddScreen(
                context: component.context,
                communityId: community.id,
                peerId: peerId,
                completed: { [weak self] immediate in
                    self?.dismissController()
                }
            )
            environment.controller()?.present(controller, in: .window(.root))
        }

        func update(component: CommunitiesScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            var transition = transition
            if "".isEmpty {
                transition = .immediate
            }

            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            self.component = component
            self.state = state

            self.ensureSubjectPeerSignal(component: component)
            self.ensureCommunitiesSignal(component: component)

            let theme = environment.theme
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let sideInset: CGFloat = 16.0
            let sectionSpacing: CGFloat = 24.0
            // iPhone Duo: the content keeps to the band beside the side strip and is centered in it. With equal
            // side insets (every other device) the band is the full width, as before.
            let bandMinX: CGFloat = environment.safeInsets.left != environment.safeInsets.right ? environment.safeInsets.left : 0.0
            let bandWidth: CGFloat = environment.safeInsets.left != environment.safeInsets.right ? availableSize.width - environment.safeInsets.left - environment.safeInsets.right : availableSize.width

            self.backgroundColor = theme.list.blocksBackgroundColor
            self.scrollView.backgroundColor = theme.list.blocksBackgroundColor

            var contentHeight = environment.navigationHeight - 26.0
            if let subjectPeer = self.subjectPeer {
                let avatarSize = self.peerAvatar.update(
                    transition: transition,
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        theme: theme,
                        peer: subjectPeer,
                        clipStyle: .roundedRect
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                if let avatarView = self.peerAvatar.view {
                    if avatarView.superview == nil {
                        self.scrollView.addSubview(self.avatarShadow)
                        self.scrollView.addSubview(avatarView)
                    }
                    let avatarFrame = CGRect(
                        origin: CGPoint(
                            x: bandMinX + floorToScreenPixels((bandWidth - avatarSize.width) / 2.0),
                            y: contentHeight
                        ),
                        size: avatarSize
                    )
                    transition.setFrame(view: avatarView, frame: avatarFrame)
                    
                    if let shadowImage = self.avatarShadow.image {
                        self.avatarShadow.tintColor = theme.list.freeTextColor
                        
                        let aspectRatio = shadowImage.size.width / shadowImage.size.height
                        let shadowSize = CGSize(width: avatarSize.width * aspectRatio, height: avatarSize.width)
                        let shadowFrame = shadowSize.centered(around: avatarFrame.center).offsetBy(dx: -13.0, dy: 0.0)
                        transition.setFrame(view: self.avatarShadow, frame: shadowFrame)
                    }
                }

                contentHeight += avatarSize.height + 18.0
            }

            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Community_List_Title,
                        font: Font.bold(24.0),
                        textColor: theme.rootController.navigationBar.primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: bandWidth - 32.0, height: 44.0)
            )
            let navigationTitleFrame = CGRect(
                origin: CGPoint(
                    x: bandMinX + floorToScreenPixels((bandWidth - navigationTitleSize.width) / 2.0),
                    y: contentHeight
                ),
                size: navigationTitleSize
            )
            let overlaySuperview: UIView?
            if let controller = environment.controller(), let navigationBar = controller.navigationBar, let navigationBarSuperview = navigationBar.view.superview {
                overlaySuperview = navigationBarSuperview
            } else {
                overlaySuperview = self
            }
            if let overlaySuperview {
                if self.titleTransformContainer.superview !== overlaySuperview {
                    self.titleTransformContainer.removeFromSuperview()
                    if let controller = environment.controller(), let navigationBar = controller.navigationBar, overlaySuperview === navigationBar.view.superview {
                        overlaySuperview.insertSubview(self.titleTransformContainer, aboveSubview: navigationBar.view)
                    } else {
                        overlaySuperview.addSubview(self.titleTransformContainer)
                    }
                }
            }
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview !== self.titleTransformContainer {
                    navigationTitleView.removeFromSuperview()
                    self.titleTransformContainer.addSubview(navigationTitleView)
                }
                transition.setPosition(view: self.titleTransformContainer, position: navigationTitleFrame.center)
                transition.setBounds(view: self.titleTransformContainer, bounds: CGRect(origin: CGPoint(), size: navigationTitleFrame.size))
                transition.setBounds(view: navigationTitleView, bounds: CGRect(origin: CGPoint(), size: navigationTitleFrame.size))
                transition.setPosition(
                    view: navigationTitleView,
                    position: CGPoint(
                        x: navigationTitleFrame.size.width * 0.5,
                        y: navigationTitleFrame.size.height * 0.5
                    )
                )
            }
            contentHeight += navigationTitleSize.height + 13.0

            var subtitleText: String = environment.strings.Community_List_SubtitleGroup
            if case let .channel(channel) = self.subjectPeer, case .broadcast = channel.info {
                subtitleText = environment.strings.Community_List_SubtitleChannel
            } else if case .user = self.subjectPeer {
                subtitleText = environment.strings.Community_List_SubtitleBot
            }
            
            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: subtitleText,
                        font: Font.regular(15.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.25
                )),
                environment: {},
                containerSize: CGSize(width: bandWidth - sideInset * 2.0 - 48.0, height: 1000.0)
            )
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.scrollView.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: CGRect(
                    origin: CGPoint(
                        x: bandMinX + floorToScreenPixels((bandWidth - subtitleSize.width) / 2.0),
                        y: contentHeight
                    ),
                    size: subtitleSize
                ))
            }
            contentHeight += subtitleSize.height + 27.0

            if component.peerId != nil {
                let createItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: "create", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Community_List_CreateCommunity,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Item List/AddCommunityIcon", tintColor: theme.list.itemAccentColor))), false),
                        accessory: nil,
                        action: { [weak self] _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            if self.isActionInProgress {
                                return
                            }
                            self.openCreateCommunity(component: component)
                        },
                        highlighting: self.isActionInProgress ? .disabled : .default
                    )))
                ]
                let createSectionSize = self.createSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: createItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: bandWidth - sideInset * 2.0, height: 1000.0)
                )
                if let createSectionView = self.createSection.view {
                    if createSectionView.superview == nil {
                        self.scrollView.addSubview(createSectionView)
                    }
                    transition.setFrame(view: createSectionView, frame: CGRect(origin: CGPoint(x: bandMinX + sideInset, y: contentHeight), size: createSectionSize))
                    transition.setAlpha(view: createSectionView, alpha: 1.0)
                }
                contentHeight += createSectionSize.height + sectionSpacing
            } else if let createSectionView = self.createSection.view {
                transition.setAlpha(view: createSectionView, alpha: 0.0, completion: { [weak createSectionView] _ in
                    createSectionView?.removeFromSuperview()
                })
            }

            var communityItems: [AnyComponentWithIdentity<Empty>] = []
            for (index, community) in self.communities.enumerated() {
                let chatCountText: String?
                if let chatCount = community.cachedData?.linkedPeers.count {
                    chatCountText = environment.strings.Community_List_ChatCount(Int32(clamping: chatCount))
                } else {
                    chatCountText = nil
                }

                let _ = index
                
                let canSelectCommunity = component.peerId != nil
                communityItems.append(AnyComponentWithIdentity(id: community.peer.id, component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    style: .generic,
                    sideInset: 0.0,
                    title: community.peer.compactDisplayTitle,
                    peer: community.peer,
                    subtitle: chatCountText.flatMap { PeerListItemComponent.Subtitle(text: $0, color: .neutral) },
                    subtitleAccessory: .none,
                    presence: nil,
                    rightAccessory: .none,
                    selectionState: .none,
                    isEnabled: !canSelectCommunity || !self.isActionInProgress,
                    hasNext: false, // index != self.communities.count - 1,
                    extractedTheme: PeerListItemComponent.ExtractedTheme(
                        inset: 2.0,
                        background: theme.list.itemBlocksBackgroundColor
                    ),
                    insets: UIEdgeInsets(top: -1.0, left: 0.0, bottom: -1.0, right: 0.0),
                    action: canSelectCommunity ? { [weak self] peer, _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.linkCommunity(component: component, community: peer)
                    } : nil
                ))))
            }

            if !communityItems.isEmpty {
                let communitiesSectionSize = self.communitiesSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Community_List_AddToExistingHeader,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: communityItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: bandWidth - sideInset * 2.0, height: 1000.0)
                )
                if let communitiesSectionView = self.communitiesSection.view {
                    if communitiesSectionView.superview == nil {
                        self.scrollView.addSubview(communitiesSectionView)
                    }
                    transition.setFrame(view: communitiesSectionView, frame: CGRect(origin: CGPoint(x: bandMinX + sideInset, y: contentHeight), size: communitiesSectionSize))
                }
                contentHeight += communitiesSectionSize.height
            }

            contentHeight += 32.0 + environment.safeInsets.bottom

            let contentSize = CGSize(width: availableSize.width, height: max(contentHeight, availableSize.height + 1.0))
            self.ignoreScrolling = true
            if self.scrollView.frame.size != availableSize {
                self.scrollView.frame = CGRect(origin: .zero, size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
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

public final class CommunitiesScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, peerId: EnginePeer.Id?) {
        super.init(
            context: context,
            component: CommunitiesScreenComponent(context: context, peerId: peerId),
            navigationBarAppearance: .default,
            theme: .default,
            updatedPresentationData: nil
        )

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)

        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? CommunitiesScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
