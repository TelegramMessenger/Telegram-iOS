import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import Postbox
import MultilineTextComponent
import PresentationDataUtils
import ButtonComponent
import TokenListTextField
import AvatarNode
import LocalizedPeerData
import PeerListItemComponent
import LottieComponent
import TooltipUI
import OverlayStatusController
import Markdown
import TelegramUIPreferences
import UndoUI
import TelegramStringFormatting

final class ShareWithPeersScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let stateContext: ShareWithPeersScreen.StateContext
    let initialPrivacy: EngineStoryPrivacy
    let initialSendAsPeerId: EnginePeer.Id?
    let screenshot: Bool
    let pin: Bool
    let timeout: Int
    let mentions: [String]
    let categoryItems: [CategoryItem]
    let optionItems: [OptionItem]
    let coverItem: CoverItem?
    let completion: (EnginePeer.Id?, EngineStoryPrivacy, Bool, Bool, [EnginePeer], Bool) -> Void
    let editCategory: (EngineStoryPrivacy, Bool, Bool) -> Void
    let editBlockedPeers: (EngineStoryPrivacy, Bool, Bool) -> Void
    let editCover: () -> Void
    let peerCompletion: (EnginePeer.Id) -> Void
    
    init(
        context: AccountContext,
        stateContext: ShareWithPeersScreen.StateContext,
        initialPrivacy: EngineStoryPrivacy,
        initialSendAsPeerId: EnginePeer.Id?,
        screenshot: Bool,
        pin: Bool,
        timeout: Int,
        mentions: [String],
        categoryItems: [CategoryItem],
        optionItems: [OptionItem],
        coverItem: CoverItem?,
        completion: @escaping (EnginePeer.Id?, EngineStoryPrivacy, Bool, Bool, [EnginePeer], Bool) -> Void,
        editCategory: @escaping (EngineStoryPrivacy, Bool, Bool) -> Void,
        editBlockedPeers: @escaping (EngineStoryPrivacy, Bool, Bool) -> Void,
        editCover: @escaping () -> Void,
        peerCompletion: @escaping (EnginePeer.Id) -> Void
    ) {
        self.context = context
        self.stateContext = stateContext
        self.initialPrivacy = initialPrivacy
        self.initialSendAsPeerId = initialSendAsPeerId
        self.screenshot = screenshot
        self.pin = pin
        self.timeout = timeout
        self.mentions = mentions
        self.categoryItems = categoryItems
        self.optionItems = optionItems
        self.coverItem = coverItem
        self.completion = completion
        self.editCategory = editCategory
        self.editBlockedPeers = editBlockedPeers
        self.editCover = editCover
        self.peerCompletion = peerCompletion
    }
    
    static func ==(lhs: ShareWithPeersScreenComponent, rhs: ShareWithPeersScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.stateContext !== rhs.stateContext {
            return false
        }
        if lhs.initialPrivacy != rhs.initialPrivacy {
            return false
        }
        if lhs.initialSendAsPeerId != rhs.initialSendAsPeerId {
            return false
        }
        if lhs.screenshot != rhs.screenshot {
            return false
        }
        if lhs.pin != rhs.pin {
            return false
        }
        if lhs.timeout != rhs.timeout {
            return false
        }
        if lhs.mentions != rhs.mentions {
            return false
        }
        if lhs.categoryItems != rhs.categoryItems {
            return false
        }
        if lhs.optionItems != rhs.optionItems {
            return false
        }
        if lhs.coverItem != rhs.coverItem {
            return false
        }
        return true
    }
    
    enum Style {
        case plain
        case blocks
    }
    
    private struct ItemLayout: Equatable {
        struct Section: Equatable {
            var id: Int
            var insets: UIEdgeInsets
            var itemHeight: CGFloat
            var itemCount: Int
            
            var totalHeight: CGFloat
            
            init(
                id: Int,
                insets: UIEdgeInsets,
                itemHeight: CGFloat,
                itemCount: Int
            ) {
                self.id = id
                self.insets = insets
                self.itemHeight = itemHeight
                self.itemCount = itemCount
                
                self.totalHeight = insets.top + itemHeight * CGFloat(itemCount) + insets.bottom
            }
        }
        
        var style: ShareWithPeersScreenComponent.Style
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        var sideInset: CGFloat
        var navigationHeight: CGFloat
        var sections: [Section]
        
        var contentHeight: CGFloat
        
        init(style: ShareWithPeersScreenComponent.Style, containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, navigationHeight: CGFloat, sections: [Section]) {
            self.style = style
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.navigationHeight = navigationHeight
            self.sections = sections
            
            var contentHeight: CGFloat = 0.0
            contentHeight += navigationHeight
            for section in sections {
                contentHeight += section.totalHeight
            }
            contentHeight += bottomInset
            self.contentHeight = contentHeight
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class AnimationHint {
        let contentReloaded: Bool
        
        init(
            contentReloaded: Bool
        ) {
            self.contentReloaded = contentReloaded
        }
    }
    
    enum CategoryColor {
        case blue
        case yellow
        case green
        case purple
        case red
        case violet
    }
    
    enum CategoryId: Int, Hashable {
        case everyone = 0
        case contacts = 1
        case closeFriends = 2
        case selectedContacts = 3
    }
    
    final class CategoryItem: Equatable {
        let id: CategoryId
        let title: String
        let icon: String?
        let iconColor: CategoryColor
        let actionTitle: String?
        
        init(
            id: CategoryId,
            title: String,
            icon: String?,
            iconColor: CategoryColor,
            actionTitle: String?
        ) {
            self.id = id
            self.title = title
            self.icon = icon
            self.iconColor = iconColor
            self.actionTitle = actionTitle
        }
        
        static func ==(lhs: CategoryItem, rhs: CategoryItem) -> Bool {
            if lhs === rhs {
                return true
            }
            return false
        }
    }
    
    enum OptionId: Int, Hashable {
        case screenshot = 0
        case pin = 1
    }
    
    final class OptionItem: Equatable {
        let id: OptionId
        let title: String
        
        init(
            id: OptionId,
            title: String
        ) {
            self.id = id
            self.title = title
        }
        
        static func ==(lhs: OptionItem, rhs: OptionItem) -> Bool {
            if lhs === rhs {
                return true
            }
            return false
        }
    }
    
    enum CoverId: Int, Hashable {
        case choose = 0
    }
    
    final class CoverItem: Equatable {
        let id: CoverId
        let title: String
        let image: UIImage?
        
        init(
            id: CoverId,
            title: String,
            image: UIImage?
        ) {
            self.id = id
            self.title = title
            self.image = image
        }
        
        static func ==(lhs: CoverItem, rhs: CoverItem) -> Bool {
            if lhs === rhs {
                return true
            }
            return false
        }
    }
        
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundView: UIImageView
        
        private let navigationContainerView: UIView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationTitle = ComponentView<Empty>()
        private let navigationLeftButton = ComponentView<Empty>()
        private let navigationRightButton = ComponentView<Empty>()
        private let navigationSeparatorLayer: SimpleLayer
        private let navigationTextFieldState = TokenListTextField.ExternalState()
        private let navigationTextField = ComponentView<Empty>()
        private let textFieldSeparatorLayer: SimpleLayer
        
        private let emptyResultsTitle = ComponentView<Empty>()
        private let emptyResultsText = ComponentView<Empty>()
        private let emptyResultsAnimation = ComponentView<Empty>()
        
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let bottomBackgroundView: BlurredBackgroundView
        private let bottomSeparatorLayer: SimpleLayer
        private let actionButton = ComponentView<Empty>()
        
        private let categoryTemplateItem = ComponentView<Empty>()
        private let peerTemplateItem = ComponentView<Empty>()
        private let optionTemplateItem = ComponentView<Empty>()
        private let footerTemplateItem = ComponentView<Empty>()
        
        private let itemContainerView: UIView
        private var visibleSectionHeaders: [Int: ComponentView<Empty>] = [:]
        private var visibleItems: [AnyHashable: ComponentView<Empty>] = [:]
        private var visibleSectionBackgrounds: [Int: UIView] = [:]
        private var visibleSectionFooters: [Int: ComponentView<Empty>] = [:]
        private var itemSizes: [AnyHashable: CGSize] = [:]
        
        private var ignoreScrolling: Bool = false
        private var isDismissed: Bool = false
        
        private var sendAsPeerId: EnginePeer.Id?
        private var isCustomTarget = false
        
        private var selectedPeers: [EnginePeer.Id] = []
        private var selectedGroups: [EnginePeer.Id] = []
        private var groupPeersMap: [EnginePeer.Id: [EnginePeer.Id]] = [:]

        private var peersMap: [EnginePeer.Id: EnginePeer] = [:]
        
        private var selectedCategories = Set<CategoryId>()
        private var selectedOptions = Set<OptionId>()
        
        private var component: ShareWithPeersScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var defaultStateValue: ShareWithPeersScreen.State?
        private var stateDisposable: Disposable?
        
        private var searchStateContext: ShareWithPeersScreen.StateContext?
        private var searchStateDisposable: Disposable?
        
        private let postingAvailabilityDisposable = MetaDisposable()
        
        private let hapticFeedback = HapticFeedback()
        
        private var effectiveStateValue: ShareWithPeersScreen.State? {
            return self.searchStateContext?.stateValue ?? self.defaultStateValue
        }
        
        private struct DismissPanState: Equatable {
            var translation: CGFloat
            
            init(translation: CGFloat) {
                self.translation = translation
            }
        }
        
        private var dismissPanGesture: UIPanGestureRecognizer?
        private var dismissPanState: DismissPanState?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = SparseContainerView()
            
            self.backgroundView = UIImageView()
            
            self.navigationContainerView = SparseContainerView()
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationSeparatorLayer = SimpleLayer()
            self.textFieldSeparatorLayer = SimpleLayer()
            
            self.bottomBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.bottomSeparatorLayer = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.itemContainerView = UIView()
            self.itemContainerView.clipsToBounds = true
            self.itemContainerView.layer.cornerRadius = 10.0
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.backgroundView)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.containerView.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.scrollContentView.addSubview(self.itemContainerView)
            
            self.containerView.addSubview(self.navigationContainerView)
            self.navigationContainerView.addSubview(self.navigationBackgroundView)
            self.navigationContainerView.layer.addSublayer(self.navigationSeparatorLayer)
            
            self.containerView.addSubview(self.bottomBackgroundView)
            self.containerView.layer.addSublayer(self.bottomSeparatorLayer)
            
            let dismissPanGesture = UIPanGestureRecognizer(target: self, action: #selector(self.dismissPanGesture(_:)))
            self.containerView.addGestureRecognizer(dismissPanGesture)
            self.dismissPanGesture = dismissPanGesture
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.endEditing(true)
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            if scrollView.contentOffset.y <= -100.0 && velocity.y <= -2.0 {
            } else {
                var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
                if topOffset > 0.0 {
                    topOffset = max(0.0, topOffset)
                    
                    if topOffset < topOffsetDistance {
                        //targetContentOffset.pointee.y = scrollView.contentOffset.y
                        //scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
                    }
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundView.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationContainerView.hitTest(self.convert(point, to: self.navigationContainerView), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                    return
                }
                controller.requestDismiss()
            }
        }
        
        @objc private func dismissPanGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let controller = self.environment?.controller() as? ShareWithPeersScreen, let component = self.component else {
                return
            }
            switch recognizer.state {
            case .began:
                controller.dismissAllTooltips()
                
                self.dismissPanState = DismissPanState(translation: 0.0)
                self.state?.updated(transition: .immediate)
            case .changed:
                let translation = recognizer.translation(in: self)
                self.dismissPanState = DismissPanState(translation: translation.y)
                self.state?.updated(transition: .immediate)
                
                self.updateModalOverlayTransition(transition: .immediate)
            case .cancelled, .ended:
                if self.dismissPanState != nil {
                    let translation = recognizer.translation(in: self)
                    let velocity = recognizer.velocity(in: self)
                    
                    self.dismissPanState = nil
                
                    if translation.y > 100.0 || velocity.y > 10.0 {
                        controller.requestDismiss()
                        if case .members = component.stateContext.subject {
                        } else if case .channels = component.stateContext.subject {
                        } else {
                            Queue.mainQueue().justDispatch {
                                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .spring))
                            }
                        }
                    } else {
                        let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                        self.state?.updated(transition: transition)
                        self.updateModalOverlayTransition(transition: transition)
                    }
                }
            default:
                break
            }
        }
        
        private func presentOptionsTooltip(optionId: OptionId) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let animationName: String
            let text: String
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            switch optionId {
            case .screenshot:
                if self.selectedOptions.contains(.screenshot) {
                    if self.selectedCategories.contains(.everyone) {
                        animationName = "anim_savemedia"
                        text = presentationData.strings.Story_Privacy_TooltipSharingEnabledPublic
                    } else {
                        animationName = "anim_savemedia"
                        text = presentationData.strings.Story_Privacy_TooltipSharingEnabled
                    }
                } else {
                    if self.selectedCategories.contains(.everyone) {
                        animationName = "premium_unlock"
                        text = presentationData.strings.Story_Privacy_TooltipSharingDisabledPublic
                    } else {
                        animationName = "premium_unlock"
                        text = presentationData.strings.Story_Privacy_TooltipSharingDisabled
                    }
                }
            case .pin:
                if self.selectedOptions.contains(.pin) {
                    animationName = "anim_profileadd"
                    if let sendAsPeerId = self.sendAsPeerId, sendAsPeerId.isGroupOrChannel {
                        if let selectedPeer = self.effectiveStateValue?.sendAsPeers.first(where: { $0.id == sendAsPeerId }), case let .channel(channel) = selectedPeer, case .group = channel.info {
                            text = presentationData.strings.Story_Privacy_TooltipStoryArchivedGroup
                        } else {
                            text = presentationData.strings.Story_Privacy_TooltipStoryArchivedChannel
                        }
                    } else {
                        text = presentationData.strings.Story_Privacy_TooltipStoryArchived
                    }
                } else {
                    animationName = "anim_autoremove_on"
                    text = presentationData.strings.Story_Privacy_TooltipStoryExpires
                }
            }
            
            let tooltipScreen = TooltipScreen(
                context: component.context,
                account: component.context.account,
                sharedContext: component.context.sharedContext,
                text: .markdown(text: text),
                style: .wide,
                icon: .animation(name: animationName, delay: 0.0, tintColor: .white),
                location: .top,
                displayDuration: .custom(4.0),
                shouldDismissOnTouch: { point, _ in
                    return .ignore
                }
            )
            
            controller.window?.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss(inPlace: true)
                }
            })
            
            controller.present(tooltipScreen, in: .window(.root))
        }
        
        private weak var progressController: ViewController?
        private func toggleGroupPeer(_ peer: EnginePeer) {
            guard let component = self.component, let environment = self.environment, let controller = self.environment?.controller() else {
                return
            }
            
            let countLimit = 200
            var groupTooLarge = false
            if case let .legacyGroup(group) = peer, group.participantCount > countLimit {
                groupTooLarge = true
            } else if let stateValue = self.effectiveStateValue, let count = stateValue.participants[peer.id], count > countLimit {
                groupTooLarge = true
            }
            
            let showCountLimitAlert = { [weak controller, weak environment, weak component] in
                guard let controller, let environment, let component else {
                    return
                }
                let alertController = textAlertController(
                    context: component.context,
                    forceTheme: defaultDarkColorPresentationTheme,
                    title: environment.strings.Story_Privacy_GroupTooLarge,
                    text: environment.strings.Story_Privacy_GroupParticipantsLimit,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {})
                    ],
                    actionLayout: .vertical
                )
                controller.present(alertController, in: .window(.root))
            }
            
            var append = false
            if let index = self.selectedGroups.firstIndex(of: peer.id) {
                self.selectedGroups.remove(at: index)
            } else {
                if groupTooLarge {
                    showCountLimitAlert()
                    return
                }
                
                self.selectedGroups.append(peer.id)
                append = true
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let progressSignal = Signal<Never, NoError> { [weak self, weak controller] subscriber in
                let progressController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                controller?.present(progressController, in: .window(.root))
                
                self?.progressController = progressController
                
                return ActionDisposable { [weak progressController, weak self] in
                    Queue.mainQueue().async() {
                        progressController?.dismiss()
                        
                        self?.progressController = nil
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.15, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.start()
            
            let processPeers: ([EnginePeer]) -> Void = { [weak self] peers in
                guard let self else {
                    return
                }
                
                progressDisposable.dispose()
                 
                var peerIds = Set<EnginePeer.Id>()
                for peer in peers {
                    self.peersMap[peer.id] = peer
                    peerIds.insert(peer.id)
                }
                var existingPeerIds = Set<EnginePeer.Id>()
                for peerId in self.selectedPeers {
                    existingPeerIds.insert(peerId)
                }
                if append {
                    if peers.count > countLimit {
                        showCountLimitAlert()
                        return
                    }
                    var groupPeerIds: [EnginePeer.Id] = []
                    for peer in peers {
                        guard !peer.isDeleted else {
                            continue
                        }
                        if !existingPeerIds.contains(peer.id) {
                            self.selectedPeers.append(peer.id)
                            existingPeerIds.insert(peer.id)
                        }
                        groupPeerIds.append(peer.id)
                    }
                    self.groupPeersMap[peer.id] = groupPeerIds
                } else {
                    self.selectedPeers = self.selectedPeers.filter { !peerIds.contains($0) }
                }
                let transition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
                self.state?.updated(transition: transition)
            }
                        
            let context = component.context
            if peer.id.namespace == Namespaces.Peer.CloudGroup {
                let _ = (context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.LegacyGroupParticipants(id: peer.id)
                )
                |> mapToSignal { participants -> Signal<[EnginePeer], NoError> in
                    if case let .known(participants) = participants {
                        return context.engine.data.get(
                            EngineDataMap(participants.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0.peerId) })
                        )
                        |> map { peers in
                            var result: [EnginePeer] = []
                            for participant in participants {
                                if let peer = peers[participant.peerId], let peer {
                                    if peer.id == context.account.peerId {
                                        continue
                                    }
                                    if case let .user(user) = peer, user.botInfo != nil {
                                        continue
                                    }
                                    result.append(peer)
                                }
                            }
                            return result
                        }
                    } else {
                        return .complete()
                    }
                }
                |> take(1)
                |> deliverOnMainQueue).start(next: { peers in
                    processPeers(peers)
                })
            } else if peer.id.namespace == Namespaces.Peer.CloudChannel {
                let participants: Signal<[EnginePeer], NoError> = Signal { subscriber in
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peer.id, requestUpdate: true, count: 200, updated: { list in
                        var peers: [EnginePeer] = []
                        for item in list.list {
                            if item.peer.id == context.account.peerId {
                                continue
                            }
                            if let user = item.peer as? TelegramUser, user.botInfo != nil {
                                continue
                            }
                            peers.append(EnginePeer(item.peer))
                        }
                        if !list.list.isEmpty {
                            subscriber.putNext(peers)
                            subscriber.putCompletion()
                        }
                    })
                    return disposable
                }
                
                let _ = (participants
                |> take(1)
                |> deliverOnMainQueue).start(next: { peers in
                    processPeers(peers)
                })
            }
        }
        
        private func updateSelectedGroupPeers() {
            var unselectedGroupIds: [EnginePeer.Id] = []
            for groupPeerId in self.selectedGroups {
                if let groupPeers = self.groupPeersMap[groupPeerId] {
                    var hasAnyGroupPeerSelected = false
                    for peerId in groupPeers {
                        if self.selectedPeers.contains(peerId) {
                            hasAnyGroupPeerSelected = true
                            break
                        }
                    }
                    if !hasAnyGroupPeerSelected {
                        unselectedGroupIds.append(groupPeerId)
                    }
                }
            }
            self.selectedGroups.removeAll(where: { unselectedGroupIds.contains($0) })
        }
        
        private func presentSendAsPeer() {
            guard let component = self.component else {
                return
            }
            
            let stateContext = ShareWithPeersScreen.StateContext(
                context: component.context,
                subject: .peers(peers: self.effectiveStateValue?.sendAsPeers ?? [], peerId: self.sendAsPeerId),
                editing: false
            )
            
            let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                let peersController = ShareWithPeersScreen(
                    context: component.context,
                    initialPrivacy: EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: []),
                    stateContext: stateContext,
                    completion: { _, _, _, _, _, _ in },
                    editCategory: { _, _, _ in },
                    editBlockedPeers: { _, _, _ in },
                    peerCompletion: { [weak self] peerId in
                        guard let self else {
                            return
                        }
                        self.sendAsPeerId = peerId
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                )
                if let controller = self.environment?.controller() as? ShareWithPeersScreen {
                    controller.dismissAllTooltips()
                    controller.push(peersController)
                }
            })
        }
        
        private func updateModalOverlayTransition(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment, let itemLayout = self.itemLayout, !self.isDismissed else {
                return
            }
            
            if case .members = component.stateContext.subject {
                return
            } else if case .channels = component.stateContext.subject {
                return
            }
            
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            if let dismissPanState = self.dismissPanState {
                topOffset += dismissPanState.translation
            }
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            if let controller = environment.controller() as? ShareWithPeersScreen {
                Queue.mainQueue().justDispatch {
                    var transition = transition
                    if controller.modalStyleOverlayTransitionFactor.isZero && transitionFactor > 0.0, transition.animation.isImmediate {
                        transition = .spring(duration: 0.4)
                    }
                    controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
                }
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment, let itemLayout = self.itemLayout else {
                return
            }
            guard let stateValue = self.effectiveStateValue else {
                return
            }
            
            var isSendAsGroup = false
            if let sendAsPeerId = self.sendAsPeerId, sendAsPeerId.isGroupOrChannel == true {
                if let selectedPeer = stateValue.sendAsPeers.first(where: { $0.id == sendAsPeerId }) {
                    if case let .channel(channel) = selectedPeer, case .group = channel.info {
                        isSendAsGroup = true
                    }
                }
            }
            
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundView.layer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            transition.setPosition(view: self.navigationContainerView, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let bottomDistance = itemLayout.contentHeight - self.scrollView.bounds.maxY
            let bottomAlphaDistance: CGFloat = 30.0
            var bottomAlpha: CGFloat = bottomDistance / bottomAlphaDistance
            bottomAlpha = max(0.0, min(1.0, bottomAlpha))
            
            self.updateModalOverlayTransition(transition: transition)
            
            var visibleBounds = self.scrollView.bounds
            visibleBounds.origin.y -= itemLayout.topInset
            visibleBounds.size.height += itemLayout.topInset
            
            var visibleFrame = self.scrollView.frame
            visibleFrame.origin.x = 0.0
            visibleFrame.origin.y -= itemLayout.topInset
            visibleFrame.size.height += itemLayout.topInset
            
            var validIds: [AnyHashable] = []
            var validSectionHeaders: [AnyHashable] = []
            var validSectionBackgrounds: [AnyHashable] = []
            var sectionOffset: CGFloat = itemLayout.navigationHeight
            
            var hasCategories = false
            if case .stories = component.stateContext.subject {
                if let peerId = self.sendAsPeerId, peerId.isGroupOrChannel {
                } else {
                    hasCategories = true
                }
            }
            
            for sectionIndex in 0 ..< itemLayout.sections.count {
                let section = itemLayout.sections[sectionIndex]
                
                if section.id == 2 && !hasCategories {
                    continue
                }
                
                if case .blocks = itemLayout.style {
                    let sectionBackgroundFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top), size: CGSize(width: itemLayout.containerSize.width, height: section.totalHeight - section.insets.top))
                    
                    if visibleFrame.intersects(sectionBackgroundFrame) {
                        validSectionBackgrounds.append(section.id)
                        
                        var sectionBackground: UIView
                        var sectionBackgroundTransition = transition
                        if let current = self.visibleSectionBackgrounds[section.id] {
                            sectionBackground = current
                        } else {
                            if !transition.animation.isImmediate {
                                sectionBackgroundTransition = .immediate
                            }
                            sectionBackground = UIView()
                            sectionBackground.backgroundColor = environment.theme.list.itemModalBlocksBackgroundColor
                            sectionBackground.layer.cornerRadius = 10.0
                            self.visibleSectionBackgrounds[section.id] = sectionBackground
                        }
                        
                        if sectionBackground.superview == nil {
                            sectionBackground.isUserInteractionEnabled = false
                            self.itemContainerView.addSubview(sectionBackground)
                        }
                        sectionBackgroundTransition.setFrame(view: sectionBackground, frame: sectionBackgroundFrame)
                    }
                }
                
                var minSectionHeader: UIView?
                do {
                    var sectionHeaderFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: itemLayout.containerInset + sectionOffset - self.scrollView.bounds.minY + itemLayout.topInset), size: CGSize(width: itemLayout.containerSize.width, height: section.insets.top))
                    if case .stories = component.stateContext.subject {
                        sectionHeaderFrame = CGRect(origin: CGPoint(x: sectionHeaderFrame.minX, y: sectionOffset), size: sectionHeaderFrame.size)
                    } else {
                        let sectionHeaderMinY = topOffset + itemLayout.containerInset + itemLayout.navigationHeight
                        let sectionHeaderMaxY = itemLayout.containerInset + sectionOffset - self.scrollView.bounds.minY + itemLayout.topInset + section.totalHeight - 28.0
                        
                        sectionHeaderFrame.origin.y = max(sectionHeaderFrame.origin.y, sectionHeaderMinY)
                        sectionHeaderFrame.origin.y = min(sectionHeaderFrame.origin.y, sectionHeaderMaxY)
                    }
                    
                    if visibleFrame.intersects(sectionHeaderFrame) {
                        validSectionHeaders.append(section.id)
                        let sectionHeader: ComponentView<Empty>
                        var sectionHeaderTransition = transition
                        if let current = self.visibleSectionHeaders[section.id] {
                            sectionHeader = current
                        } else {
                            if !transition.animation.isImmediate {
                                sectionHeaderTransition = .immediate
                            }
                            sectionHeader = ComponentView()
                            self.visibleSectionHeaders[section.id] = sectionHeader
                        }
                        
                        let sectionTitle: String
                        if section.id == 0, case let .stories(_, count) = component.stateContext.subject {
                            if component.coverItem == nil {
                                if count > 1 {
                                    sectionTitle = environment.strings.Story_Privacy_PostStoriesAsHeader
                                } else {
                                    sectionTitle = environment.strings.Story_Privacy_PostStoryAsHeader
                                }
                            } else {
                                sectionTitle = ""
                            }
                        } else if section.id == 2 {
                            if case let .stories(_, count) = component.stateContext.subject, count > 1 {
                                sectionTitle = environment.strings.Story_Privacy_WhoCanViewStoriesHeader
                            } else {
                                sectionTitle = environment.strings.Story_Privacy_WhoCanViewHeader
                            }
                        } else if section.id == 1 {
                            if case let .members(isGroup, _, _) = component.stateContext.subject {
                                sectionTitle = isGroup ? environment.strings.BoostGift_Members_SectionTitle : environment.strings.BoostGift_Subscribers_SectionTitle
                            } else if case let .channels(isGroup, _, _) = component.stateContext.subject {
                                sectionTitle = isGroup ? environment.strings.BoostGift_GroupsOrChannels_SectionTitle : environment.strings.BoostGift_ChannelsOrGroups_SectionTitle
                            } else {
                                sectionTitle = environment.strings.Story_Privacy_ContactsHeader
                            }
                        } else {
                            sectionTitle = ""
                        }
                        
                        let _ = sectionHeader.update(
                            transition: sectionHeaderTransition,
                            component: AnyComponent(SectionHeaderComponent(
                                theme: environment.theme,
                                style: itemLayout.style,
                                title: sectionTitle,
                                actionTitle: (section.id == 1 && !self.selectedPeers.isEmpty) ? environment.strings.Contacts_DeselectAll : nil,
                                action: { [weak self] in
                                    if let self {
                                        self.selectedPeers = []
                                        self.selectedGroups = []
                                        let transition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
                                        self.state?.updated(transition: transition)
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: sectionHeaderFrame.size
                        )
                        if let sectionHeaderView = sectionHeader.view {
                            if sectionHeaderView.superview == nil {
                                if case .stories = component.stateContext.subject {
                                    self.itemContainerView.addSubview(sectionHeaderView)
                                } else {
                                    self.scrollContentClippingView.addSubview(sectionHeaderView)
                                }
                                
                                if !transition.animation.isImmediate {
                                    sectionHeaderView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                }
                            }
                            let sectionXOffset: CGFloat
                            if case .stories = component.stateContext.subject {
                                sectionXOffset = 0.0
                            } else {
                                sectionXOffset = self.scrollView.frame.minX
                            }
                            if minSectionHeader == nil {
                                minSectionHeader = sectionHeaderView
                            }
                            sectionHeaderTransition.setFrame(view: sectionHeaderView, frame: sectionHeaderFrame.offsetBy(dx: sectionXOffset, dy: 0.0))
                        }
                    }
                }
                
                if section.id == 0 {
                    var peers = stateValue.sendAsPeers
                    if case .stories = component.stateContext.subject {
                        if let peerId = self.sendAsPeerId, let selectedPeer = stateValue.sendAsPeers.first(where: { $0.id == peerId }) {
                            peers = [selectedPeer]
                        } else if let peer = peers.first {
                            peers = [peer]
                        }
                    }
                    for i in 0 ..< peers.count {
                        let peer = peers[i]
                        let itemId = AnyHashable(peer.id)
                                                
                        let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        let subtitle: String?
                        if case .user = peer {
                            subtitle = environment.strings.VoiceChat_PersonalAccount
                        } else {
                            if case let .channel(channel) = peer {
                                if case .broadcast = channel.info {
                                    if let count = component.stateContext.stateValue?.participants[peer.id] {
                                        subtitle = environment.strings.Conversation_StatusSubscribers(Int32(max(1, count)))
                                    } else {
                                        subtitle = environment.strings.Channel_Status
                                    }
                                } else {
                                    if let count = component.stateContext.stateValue?.participants[peer.id] {
                                        subtitle = environment.strings.Conversation_StatusMembers(Int32(max(1, count)))
                                    } else {
                                        subtitle = environment.strings.Group_Status
                                    }
                                }
                            } else {
                                subtitle = nil
                            }
                        }
                        
                        var isStories = false
                        var accessory: PeerListItemComponent.RightAccessory
                        if case .stories = component.stateContext.subject {
                            accessory = self.isCustomTarget ? .none : .disclosure
                            isStories = true
                        } else {
                            if let selectedPeerId = self.sendAsPeerId {
                                accessory = selectedPeerId == peer.id ? .check : .none
                            } else {
                                accessory = component.context.account.peerId == peer.id ? .check : .none
                            }
                        }
                        
                        let itemSize = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(PeerListItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                style: .generic,
                                sideInset: itemLayout.sideInset,
                                title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                                peer: peer,
                                subtitle: subtitle.flatMap { PeerListItemComponent.Subtitle(text: $0, color: .neutral) },
                                subtitleAccessory: .none,
                                presence: nil,
                                rightAccessory: accessory,
                                selectionState: .none,
                                hasNext: i < peers.count - 1,
                                action: { [weak self] peer, _, _ in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    if isStories {
                                        if !self.isCustomTarget {
                                            let _ = self.presentSendAsPeer()
                                        }
                                    } else {
                                        if peer.id.namespace == Namespaces.Peer.CloudUser {
                                            self.component?.peerCompletion(peer.id)
                                            self.environment?.controller()?.dismiss()
                                            
                                            self.hapticFeedback.impact(.light)
                                        } else {
                                            self.postingAvailabilityDisposable.set((component.context.engine.messages.checkStoriesUploadAvailability(target: .peer(peer.id))
                                            |> deliverOnMainQueue).start(next: { [weak self] status in
                                                guard let self, let component = self.component else {
                                                    return
                                                }
                                                switch status {
                                                case .available:
                                                    component.peerCompletion(peer.id)
                                                    self.environment?.controller()?.dismiss()
                                                case .channelBoostRequired:
                                                    let _ = combineLatest(
                                                        queue: Queue.mainQueue(),
                                                        component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)),
                                                        component.context.engine.peers.getChannelBoostStatus(peerId: peer.id),
                                                        component.context.engine.peers.getMyBoostStatus()
                                                    ).start(next: { [weak self] peer, boostStatus, myBoostStatus in
                                                        guard let self, let component = self.component, let peer, let boostStatus, let myBoostStatus else {
                                                            return
                                                        }
                                                        
                                                        if let navigationController = self.environment?.controller()?.navigationController as? NavigationController {
                                                            if let previousController = navigationController.viewControllers.last as? ShareWithPeersScreen {
                                                                previousController.dismiss()
                                                            }
                                                            let controller = component.context.sharedContext.makePremiumBoostLevelsController(context: component.context, peerId: peer.id, subject: .stories, boostStatus: boostStatus, myBoostStatus: myBoostStatus, forceDark: true, openStats: nil)
                                                            navigationController.pushViewController(controller)
                                                        }
                                                        self.hapticFeedback.impact(.light)
                                                    })
                                                default:
                                                    break
                                                }
                                            }))
                                        }
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        self.itemSizes[itemId] = itemSize
                        
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                self.itemContainerView.addSubview(itemView)
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                    if hasCategories {
                        sectionOffset += 24.0
                    }
                } else if section.id == 2 {
                    for i in 0 ..< component.categoryItems.count {
                        let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        
                        let item = component.categoryItems[i]
                        let categoryId = item.id
                        let itemId = AnyHashable(item.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(CategoryListItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                title: item.title,
                                color: item.iconColor,
                                iconName: item.icon,
                                subtitle: item.actionTitle,
                                selectionState: .editing(isSelected: self.selectedCategories.contains(item.id), isTinted: false),
                                hasNext: i != component.categoryItems.count - 1,
                                action: { [weak self] in
                                    guard let self, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                                        return
                                    }
                                    if self.selectedCategories.contains(categoryId) {
                                    } else {
                                        let base: EngineStoryPrivacy.Base
                                        switch categoryId {
                                        case .everyone:
                                            base = .everyone
                                        case .contacts:
                                            base = .contacts
                                        case .closeFriends:
                                            base = .closeFriends
                                        case .selectedContacts:
                                            base = .nobody
                                        }
                                        let selectedPeers = component.stateContext.stateValue?.savedSelectedPeers[base] ?? []
                                        
                                        self.selectedCategories.removeAll()
                                        self.selectedCategories.insert(categoryId)
                                        
                                        let closeFriends = self.component?.stateContext.stateValue?.closeFriendsPeers ?? []
                                        if categoryId == .selectedContacts && selectedPeers.isEmpty {
                                            component.editCategory(
                                                EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: []),
                                                self.selectedOptions.contains(.screenshot),
                                                self.selectedOptions.contains(.pin)
                                            )
                                            controller.dismissAllTooltips()
                                            controller.dismiss()
                                        } else if categoryId == .closeFriends && closeFriends.isEmpty {
                                            component.editCategory(
                                                EngineStoryPrivacy(base: .closeFriends, additionallyIncludePeers: []),
                                                self.selectedOptions.contains(.screenshot),
                                                self.selectedOptions.contains(.pin)
                                            )
                                            controller.dismissAllTooltips()
                                            controller.dismiss()
                                        }
                                    }
                                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.35, curve: .spring)))
                                },
                                secondaryAction: { [weak self] in
                                    guard let self, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                                        return
                                    }
                                    let base: EngineStoryPrivacy.Base
                                    switch categoryId {
                                    case .everyone:
                                        base = .everyone
                                    case .contacts:
                                        base = .contacts
                                    case .closeFriends:
                                        base = .closeFriends
                                    case .selectedContacts:
                                        base = .nobody
                                    }
                                    let selectedPeers = component.stateContext.stateValue?.savedSelectedPeers[base] ?? []
                                    
                                    component.editCategory(
                                        EngineStoryPrivacy(base: base, additionallyIncludePeers: selectedPeers),
                                        self.selectedOptions.contains(.screenshot),
                                        self.selectedOptions.contains(.pin)
                                    )
                                    controller.dismissAllTooltips()
                                    controller.dismiss()
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                if let minSectionHeader {
                                    self.itemContainerView.insertSubview(itemView, belowSubview: minSectionHeader)
                                } else {
                                    self.itemContainerView.addSubview(itemView)
                                }
                                
                                if !transition.animation.isImmediate {
                                    itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                    
                    let sectionFooter: ComponentView<Empty>
                    var sectionFooterTransition = transition
                    if let current = self.visibleSectionFooters[section.id] {
                        sectionFooter = current
                    } else {
                        if !transition.animation.isImmediate {
                            sectionFooterTransition = .immediate
                        }
                        sectionFooter = ComponentView()
                        self.visibleSectionFooters[section.id] = sectionFooter
                    }
                    
                    let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)
                    let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor)
                    let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor)
                    
                    let footerText: String
                    if let grayListPeers = component.stateContext.stateValue?.grayListPeers, !grayListPeers.isEmpty {
                        let footerValue = environment.strings.Story_Privacy_GrayListPeople(Int32(grayListPeers.count))
                        footerText = environment.strings.Story_Privacy_GrayListSelected(footerValue).string
                    } else {
                        footerText = environment.strings.Story_Privacy_GrayListSelect
                    }
                    let footerSize = sectionFooter.update(
                        transition: sectionFooterTransition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .markdown(text: footerText, attributes: MarkdownAttributes(
                                body: body,
                                bold: bold,
                                link: link,
                                linkAttribute: { url in
                                    return ("URL", url)
                                }
                            )),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1,
                            highlightColor: UIColor(rgb: 0x007aff, alpha: 0.2),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                                    return NSAttributedString.Key(rawValue: "URL")
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { [weak self] _, _ in
                                guard let self, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                                    return
                                }
                                let base: EngineStoryPrivacy.Base
                                if self.selectedCategories.contains(.everyone) {
                                    base = .everyone
                                } else if self.selectedCategories.contains(.closeFriends) {
                                    base = .closeFriends
                                } else if self.selectedCategories.contains(.contacts) {
                                    base = .contacts
                                } else if self.selectedCategories.contains(.selectedContacts) {
                                    base = .nobody
                                } else {
                                    base = .nobody
                                }
                                component.editBlockedPeers(
                                    EngineStoryPrivacy(base: base, additionallyIncludePeers: self.selectedPeers),
                                    self.selectedOptions.contains(.screenshot),
                                    self.selectedOptions.contains(.pin)
                                )
                                controller.dismissAllTooltips()
                                controller.dismiss()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.containerSize.width - 16.0 * 2.0, height: itemLayout.contentHeight)
                    )
                    let footerFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset + 16.0, y: sectionOffset + section.totalHeight + 7.0), size: footerSize)
                    if let footerView = sectionFooter.view {
                        if footerView.superview == nil {
                            self.itemContainerView.addSubview(footerView)
                        }
                        sectionFooterTransition.setFrame(view: footerView, frame: footerFrame)
                    }
                    
                    sectionOffset += footerSize.height
                } else if section.id == 1 {
                    for i in 0 ..< stateValue.peers.count {
                        let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        
                        let peer = stateValue.peers[i]
                        let itemId = AnyHashable(peer.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        let subtitle: String?
                        if case let .legacyGroup(group) = peer {
                            subtitle = environment.strings.Conversation_StatusMembers(Int32(max(1, group.participantCount)))
                        } else if case let .channel(channel) = peer {
                            if let count = stateValue.participants[peer.id] {
                                if case .broadcast = channel.info {
                                    subtitle = environment.strings.Conversation_StatusSubscribers(Int32(max(1, count)))
                                } else {
                                    subtitle = environment.strings.Conversation_StatusMembers(Int32(max(1, count)))
                                }
                            } else {
                                subtitle = nil
                            }
                        } else {
                            if case .members = component.stateContext.subject {
                                if let invitedAt = stateValue.invitedAt[peer.id] {
                                    subtitle = environment.strings.BoostGift_Subscribers_Joined(stringForMediumDate(timestamp: invitedAt, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat)).string
                                } else {
                                    subtitle = nil
                                }
                            } else {
                                subtitle = nil
                            }
                        }
                        
                        let isSelected = self.selectedPeers.contains(peer.id) || self.selectedGroups.contains(peer.id)
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(PeerListItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                style: .generic,
                                sideInset: itemLayout.sideInset,
                                title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                                peer: peer,
                                subtitle: subtitle.flatMap { PeerListItemComponent.Subtitle(text: $0, color: .neutral) },
                                subtitleAccessory: .none,
                                presence: stateValue.presences[peer.id],
                                selectionState: .editing(isSelected: isSelected, isTinted: false),
                                hasNext: true,
                                action: { [weak self] peer, _, _ in
                                    guard let self, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                                        return
                                    }
                                    let update = {
                                        let transition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
                                        self.state?.updated(transition: transition)
                                        
                                        if self.searchStateContext != nil {
                                            if let navigationTextFieldView = self.navigationTextField.view as? TokenListTextField.View {
                                                navigationTextFieldView.clearText()
                                            }
                                        }
                                    }
                                    
                                    let index = self.selectedPeers.firstIndex(of: peer.id)
                                    let togglePeer = {
                                        if let index {
                                            self.selectedPeers.remove(at: index)
                                            self.updateSelectedGroupPeers()
                                        } else {
                                            self.selectedPeers.append(peer.id)
                                        }
                                        update()
                                    }
                                    if peer.id.isGroupOrChannel {
                                        if case .channels = component.stateContext.subject, self.selectedPeers.count >= component.context.userLimits.maxGiveawayChannelsCount, index == nil {
                                            self.hapticFeedback.error()
                                            
                                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                            controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: environment.strings.BoostGift_Channels_MaximumReached("\(component.context.userLimits.maxGiveawayChannelsCount)").string, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                            return
                                        }
                                        if case .channels = component.stateContext.subject {
                                            if case let .channel(channel) = peer, channel.addressName == nil, index == nil {
                                                let title: String
                                                let text: String
                                                
                                                switch channel.info {
                                                case .broadcast:
                                                    title = environment.strings.BoostGift_Channels_PrivateChannel_Title
                                                    text = environment.strings.BoostGift_Channels_PrivateChannel_Text
                                                case .group:
                                                    title = environment.strings.BoostGift_Groups_PrivateGroup_Title
                                                    text = environment.strings.BoostGift_Groups_PrivateGroup_Text
                                                }
                                                
                                                let alertController = textAlertController(
                                                    context: component.context,
                                                    forceTheme: environment.theme,
                                                    title: title,
                                                    text: text,
                                                    actions: [
                                                        TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                                                        TextAlertAction(type: .defaultAction, title: environment.strings.BoostGift_Channels_PrivateChannel_Add, action: {
                                                            togglePeer()
                                                        })
                                                    ]
                                                )
                                                controller.present(alertController, in: .window(.root))
                                            } else {
                                                togglePeer()
                                            }
                                        } else {
                                            self.toggleGroupPeer(peer)
                                            update()
                                        }
                                    } else {
                                        if case let .members(isGroup, _, _) = component.stateContext.subject, self.selectedPeers.count >= 10, index == nil {
                                            self.hapticFeedback.error()
                                            
                                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                            controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: isGroup ? environment.strings.BoostGift_Members_MaximumReached("\(10)").string : environment.strings.BoostGift_Subscribers_MaximumReached("\(10)").string, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                            return
                                        }
                                        togglePeer()
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                self.itemContainerView.addSubview(itemView)
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                } else if section.id == 3 && section.itemCount > 0 {
                    for i in 0 ..< component.optionItems.count {
                        let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        
                        let item = component.optionItems[i]
                        let optionId = item.id
                        let itemId = AnyHashable(item.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        var title = item.title
                        if item.id == .pin && !hasCategories {
                            title = isSendAsGroup ? environment.strings.Story_Privacy_KeepOnGroupPage : environment.strings.Story_Privacy_KeepOnChannelPage
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(OptionListItemComponent(
                                theme: environment.theme,
                                title: title,
                                hasNext: i != component.optionItems.count - 1,
                                selected: self.selectedOptions.contains(item.id),
                                selectionChanged: { [weak self] selected in
                                    if let self {
                                        if selected {
                                            self.selectedOptions.insert(optionId)
                                        } else {
                                            self.selectedOptions.remove(optionId)
                                        }
                                        let transition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
                                        self.state?.updated(transition: transition)
                                        
                                        self.presentOptionsTooltip(optionId: optionId)
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                if let minSectionHeader {
                                    self.itemContainerView.insertSubview(itemView, belowSubview: minSectionHeader)
                                } else {
                                    self.itemContainerView.addSubview(itemView)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                    
                    let sectionFooter: ComponentView<Empty>
                    var sectionFooterTransition = transition
                    if let current = self.visibleSectionFooters[section.id] {
                        sectionFooter = current
                    } else {
                        if !transition.animation.isImmediate {
                            sectionFooterTransition = .immediate
                        }
                        sectionFooter = ComponentView()
                        self.visibleSectionFooters[section.id] = sectionFooter
                    }
                    
                    let footerValue = environment.strings.Story_Privacy_KeepOnMyPageHours(Int32(component.timeout / 3600))
                    var footerText: String
                    if case let .stories(_, count) = component.stateContext.subject, count > 1 {
                        if let sendAsPeerId = self.sendAsPeerId, sendAsPeerId.isGroupOrChannel == true {
                            footerText = isSendAsGroup ? environment.strings.Story_Privacy_KeepOnGroupPageManyInfo(footerValue).string : environment.strings.Story_Privacy_KeepOnChannelPageManyInfo(footerValue).string
                        } else {
                            footerText = environment.strings.Story_Privacy_KeepOnMyPageManyInfo(footerValue).string
                        }
                    } else {
                        if let sendAsPeerId = self.sendAsPeerId, sendAsPeerId.isGroupOrChannel == true {
                            footerText = isSendAsGroup ? environment.strings.Story_Privacy_KeepOnGroupPageInfo(footerValue).string : environment.strings.Story_Privacy_KeepOnChannelPageInfo(footerValue).string
                        } else {
                            footerText = environment.strings.Story_Privacy_KeepOnMyPageInfo(footerValue).string
                        }
                    }
                                        
                    let footerSize = sectionFooter.update(
                        transition: sectionFooterTransition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.containerSize.width - 16.0 * 2.0, height: itemLayout.contentHeight)
                    )
                    let footerFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset + 16.0, y: sectionOffset + section.totalHeight + 7.0), size: footerSize)
                    if let footerView = sectionFooter.view {
                        if footerView.superview == nil {
                            self.itemContainerView.addSubview(footerView)
                        }
                        sectionFooterTransition.setFrame(view: footerView, frame: footerFrame)
                    }
                    sectionOffset += footerSize.height
                } else if section.id == 4 && section.itemCount > 0 {
                    if let item = component.coverItem {
                        let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(0) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        
                        let itemId = AnyHashable(item.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(CoverListItemComponent(
                                theme: environment.theme,
                                title: item.title,
                                image: item.image,
                                hasNext: false,
                                action: { [weak self] in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.editCover()
                                    self.saveAndDismiss()
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                if let minSectionHeader {
                                    self.itemContainerView.insertSubview(itemView, belowSubview: minSectionHeader)
                                } else {
                                    self.itemContainerView.addSubview(itemView)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                    
                    let sectionFooter: ComponentView<Empty>
                    var sectionFooterTransition = transition
                    if let current = self.visibleSectionFooters[section.id] {
                        sectionFooter = current
                    } else {
                        if !transition.animation.isImmediate {
                            sectionFooterTransition = .immediate
                        }
                        sectionFooter = ComponentView()
                        self.visibleSectionFooters[section.id] = sectionFooter
                    }
                    
                    var footerText = environment.strings.Story_Privacy_ChooseCoverInfo
                    if let sendAsPeerId = self.sendAsPeerId, sendAsPeerId.isGroupOrChannel == true {
                        footerText = isSendAsGroup ? environment.strings.Story_Privacy_ChooseCoverGroupInfo : environment.strings.Story_Privacy_ChooseCoverChannelInfo
                    }
                    
                    let footerSize = sectionFooter.update(
                        transition: sectionFooterTransition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.containerSize.width - 16.0 * 2.0, height: itemLayout.contentHeight)
                    )
                    let footerFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset + 16.0, y: sectionOffset + section.totalHeight + 7.0), size: footerSize)
                    if let footerView = sectionFooter.view {
                        if footerView.superview == nil {
                            self.itemContainerView.addSubview(footerView)
                        }
                        sectionFooterTransition.setFrame(view: footerView, frame: footerFrame)
                    }
                }
                sectionOffset += section.totalHeight
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            var removeSectionHeaderIds: [Int] = []
            for (id, item) in self.visibleSectionHeaders {
                if !validSectionHeaders.contains(id) {
                    removeSectionHeaderIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeSectionHeaderIds {
                self.visibleSectionHeaders.removeValue(forKey: id)
            }
            
            var removeSectionBackgroundIds: [Int] = []
            var removeSectionFooterIds: [Int] = []
            for (id, item) in self.visibleSectionBackgrounds {
                if !validSectionBackgrounds.contains(id) {
                    removeSectionBackgroundIds.append(id)
                    if !transition.animation.isImmediate {
                        item.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                            item.removeFromSuperview()
                        })
                    } else {
                        item.removeFromSuperview()
                    }
                }
            }
            for (id, item) in self.visibleSectionFooters {
                if !validSectionBackgrounds.contains(id) {
                    removeSectionFooterIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeSectionBackgroundIds {
                self.visibleSectionBackgrounds.removeValue(forKey: id)
            }
            for id in removeSectionFooterIds {
                self.visibleSectionFooters.removeValue(forKey: id)
            }
            
            let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            
            var searchQuery: String?
            var searchResultsAreEmpty = false
            if let searchStateContext = self.searchStateContext, let value = searchStateContext.stateValue {
                if case let .contactsSearch(query, _) = searchStateContext.subject {
                    searchQuery = query
                } else if case let .members(_, _, query) = searchStateContext.subject {
                    searchQuery = query
                } else if case let .channels(_, _, query) = searchStateContext.subject {
                    searchQuery = query
                }
                searchResultsAreEmpty = value.peers.isEmpty
            }
            
            if let searchQuery, searchResultsAreEmpty {
                let sideInset: CGFloat = 44.0
                let emptyAnimationHeight = 148.0
                let topInset: CGFloat = topOffset + itemLayout.containerInset + 40.0
                let bottomInset: CGFloat = max(environment.safeInsets.bottom, environment.inputHeight)
                let visibleHeight = visibleFrame.height
                let emptyAnimationSpacing: CGFloat = 8.0
                let emptyTextSpacing: CGFloat = 8.0
                
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Contacts_Search_NoResults, font: Font.semibold(17.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: visibleFrame.size
                )
                let emptyResultsTextSize = self.emptyResultsText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Contacts_Search_NoResultsQueryDescription(searchQuery).string, font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: visibleFrame.width - sideInset * 2.0, height: visibleFrame.height)
                )
                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                    )),
                    environment: {},
                    containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
                )
      
                let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyResultsTitleSize.height + emptyResultsTextSize.height + emptyTextSpacing
                let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
                
                let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
                
                let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsTitleSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyAnimationSpacing), size: emptyResultsTitleSize)
                
                let emptyResultsTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsTextSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsTextSize)
                
                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                        view.playOnce()
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    transition.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
                if let view = self.emptyResultsText.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTextFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTextFrame.center)
                }
            } else {
                if let view = self.emptyResultsAnimation.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsText.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundView.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationContainerView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomBackgroundView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomSeparatorLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            guard let component = self.component else {
                return
            }
            self.isDismissed = true
            
            if let controller = self.environment?.controller() as? ShareWithPeersScreen {
                if case .members = component.stateContext.subject {
                } else if case .channels = component.stateContext.subject {
                } else {
                    controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
                }
            }
            
            var animateOffset: CGFloat = self.bounds.height - self.backgroundView.frame.minY
            if self.scrollView.contentOffset.y < 0.0 {
                animateOffset += -self.scrollView.contentOffset.y
            }
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationContainerView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomBackgroundView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomSeparatorLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
        }
        
        private var hasBlocksStyle: Bool {
            guard let component = self.component else {
                return false
            }
            if case .stories = component.stateContext.subject {
                return true
            } else if case .peers = component.stateContext.subject {
                return true
            } else {
                return false
            }
        }
        
        private var currentHasChannels: Bool?
        private var currentHasCover: Bool?
        
        func saveAndDismiss() {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                return
            }
            let base: EngineStoryPrivacy.Base
            if self.selectedCategories.contains(.everyone) {
                base = .everyone
            } else if self.selectedCategories.contains(.closeFriends) {
                base = .closeFriends
            } else if self.selectedCategories.contains(.contacts) {
                base = .contacts
            } else if self.selectedCategories.contains(.selectedContacts) {
                base = .nobody
            } else {
                base = .nobody
            }
            component.completion(
                self.sendAsPeerId,
                EngineStoryPrivacy(
                    base: base,
                    additionallyIncludePeers: self.selectedPeers
                ),
                self.selectedOptions.contains(.screenshot),
                self.selectedOptions.contains(.pin),
                self.component?.stateContext.stateValue?.peers.filter { self.selectedPeers.contains($0.id) } ?? [],
                false
            )
            controller.requestDismiss()
        }
        
        func update(component: ShareWithPeersScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            guard !self.isDismissed else {
                return availableSize
            }
            let animationHint = transition.userData(AnimationHint.self)
            
            var contentTransition = transition
            if let animationHint, animationHint.contentReloaded, !transition.animation.isImmediate {
                contentTransition = .immediate
            }
            
            var hasCategories = false
            var hasChannels = false
            var hasCover = false
            if case .stories = component.stateContext.subject {
                if let peerId = self.sendAsPeerId, peerId.isGroupOrChannel {
                } else {
                    hasCategories = true
                }
                let sendAsPeersCount = component.stateContext.stateValue?.sendAsPeers.count ?? 1
                if sendAsPeersCount > 1 {
                    hasChannels = true
                }
                if let currentHasChannels = self.currentHasChannels, currentHasChannels != hasChannels {
                    contentTransition = .spring(duration: 0.4)
                }
                self.currentHasChannels = hasChannels
                
                if self.selectedOptions.contains(.pin) && component.coverItem != nil {
                    hasCover = true
                }
                if let currentHasCover = self.currentHasCover, currentHasCover != hasCover {
                    contentTransition = .spring(duration: 0.4)
                }
                self.currentHasCover = hasCover
            } else if case .members = component.stateContext.subject {
                self.dismissPanGesture?.isEnabled = false
            } else if case .channels = component.stateContext.subject {
                self.dismissPanGesture?.isEnabled = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            var sideInset: CGFloat = 0.0
            if case .stories = component.stateContext.subject {
                sideInset = 16.0
                if availableSize.width < 393.0 && hasCover {
                    self.scrollView.isScrollEnabled = true
                    self.dismissPanGesture?.isEnabled = false
                } else {
                    self.scrollView.isScrollEnabled = false
                    self.dismissPanGesture?.isEnabled = true
                }
            } else if case .peers = component.stateContext.subject {
                sideInset = 16.0
                self.dismissPanGesture?.isEnabled = false
            } else {
                self.scrollView.bounces = true
                self.dismissPanGesture?.isEnabled = false
            }
            
            let containerWidth: CGFloat
            if environment.metrics.isTablet {
                containerWidth = 414.0
            } else {
                containerWidth = availableSize.width
            }
            let containerSideInset = floorToScreenPixels((availableSize.width - containerWidth) / 2.0)
            
            if self.component == nil {
                if let sendAsPeerId = component.initialSendAsPeerId {
                    self.sendAsPeerId = sendAsPeerId
                    self.isCustomTarget = true
                }
                
                switch component.initialPrivacy.base {
                case .everyone:
                    self.selectedCategories.insert(.everyone)
                case .closeFriends:
                    self.selectedCategories.insert(.closeFriends)
                case .contacts:
                    self.selectedCategories.insert(.contacts)
                case .nobody:
                    self.selectedCategories.insert(.selectedContacts)
                }
                
                if component.screenshot {
                    self.selectedOptions.insert(.screenshot)
                }
                if component.pin {
                    self.selectedOptions.insert(.pin)
                }
                
                var applyState = false
                self.defaultStateValue = component.stateContext.stateValue
                self.selectedPeers = Array(component.stateContext.initialPeerIds)
                if case let .peers(_, peerId) = component.stateContext.subject {
                    self.sendAsPeerId = peerId
                }
                
                self.stateDisposable = (component.stateContext.state
                |> deliverOnMainQueue).start(next: { [weak self] stateValue in
                    guard let self else {
                        return
                    }
                    self.defaultStateValue = stateValue
                    if applyState {
                        self.state?.updated(transition: .immediate)
                    }
                })
                applyState = true
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                
                self.scrollView.indicatorStyle = environment.theme.overallDarkAppearance ? .white : .black
                
                self.backgroundView.image = generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    if self.hasBlocksStyle {
                        context.setFillColor(environment.theme.list.modalBlocksBackgroundColor.cgColor)
                    } else {
                        context.setFillColor(environment.theme.list.plainBackgroundColor.cgColor)
                    }
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                    context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height * 0.5), size: CGSize(width: size.width, height: size.height * 0.5)))
                })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 19)
                
                if self.hasBlocksStyle {
                    self.navigationBackgroundView.updateColor(color: environment.theme.list.modalBlocksBackgroundColor, transition: .immediate)
                    self.navigationSeparatorLayer.backgroundColor = UIColor.clear.cgColor
                    self.bottomBackgroundView.updateColor(color: environment.theme.list.modalBlocksBackgroundColor, transition: .immediate)
                    self.bottomSeparatorLayer.backgroundColor = UIColor.clear.cgColor
                } else {
                    self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                    self.navigationSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
                    self.bottomBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                    self.bottomSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
                }
                
                self.textFieldSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            let itemLayoutStyle: ShareWithPeersScreenComponent.Style
            let itemsContainerWidth: CGFloat
            let navigationTextFieldSize: CGSize
            if self.hasBlocksStyle {
                itemLayoutStyle = .blocks
                itemsContainerWidth = containerWidth - sideInset * 2.0
                navigationTextFieldSize = .zero
            } else {
                itemLayoutStyle = .plain
                itemsContainerWidth = containerWidth
                
                var tokens: [TokenListTextField.Token] = []
                for peerId in self.selectedPeers {
                    guard let stateValue = self.defaultStateValue else {
                        continue
                    }
                    var peer: EnginePeer?
                    if let peerValue = self.peersMap[peerId] {
                        peer = peerValue
                    } else if let peerValue = stateValue.peers.first(where: { $0.id == peerId }) {
                        peer = peerValue
                    }
                    
                    guard let peer else {
                        continue
                    }
                    
                    tokens.append(TokenListTextField.Token(
                        id: AnyHashable(peerId),
                        title: peer.compactDisplayTitle,
                        fixedPosition: nil,
                        content: .peer(peer)
                    ))
                }
                
                let placeholder: String
                switch component.stateContext.subject {
                case let .members(isGroup, _, _):
                    placeholder = isGroup ? environment.strings.BoostGift_Members_Search : environment.strings.BoostGift_Subscribers_Search
                case let .channels(isGroup, _, _):
                    placeholder = isGroup ? environment.strings.BoostGift_GroupsOrChannels_Search : environment.strings.BoostGift_ChannelsOrGroups_Search
                case .chats:
                    placeholder = environment.strings.Story_Privacy_SearchChats
                default:
                    placeholder = environment.strings.Story_Privacy_SearchContacts
                }
                self.navigationTextField.parentState = state
                navigationTextFieldSize = self.navigationTextField.update(
                    transition: transition,
                    component: AnyComponent(TokenListTextField(
                        externalState: self.navigationTextFieldState,
                        context: component.context,
                        theme: environment.theme,
                        placeholder: placeholder,
                        tokens: tokens,
                        sideInset: sideInset,
                        deleteToken: { [weak self] tokenId in
                            guard let self else {
                                return
                            }
                            if let categoryId = tokenId.base as? CategoryId {
                                self.selectedCategories.remove(categoryId)
                            } else if let peerId = tokenId.base as? EnginePeer.Id {
                                self.selectedPeers.removeAll(where: { $0 == peerId })
                                self.updateSelectedGroupPeers()
                            }
                            if self.selectedCategories.isEmpty {
                                self.selectedCategories.insert(.everyone)
                            }
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.35, curve: .spring)))
                        },
                        isFocusedUpdated: { [weak self] isFocused in
                            guard let self else {
                                return
                            }
                            if isFocused {
                                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.scrollView.contentInset.top), animated: true)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: containerWidth, height: 1000.0)
                )
                
                let searchQuery = self.navigationTextFieldState.text
                if !searchQuery.isEmpty {
                    var onlyContacts = false
                    if component.initialPrivacy.base == .closeFriends || component.initialPrivacy.base == .contacts {
                        onlyContacts = true
                    }
                    
                    let searchSubject: ShareWithPeersScreen.StateContext.Subject
                    switch component.stateContext.subject {
                    case let .channels(isGroup, exclude, _):
                        searchSubject = .channels(isGroup: isGroup, exclude: exclude, searchQuery: searchQuery)
                    case let .members(isGroup, peerId, _):
                        searchSubject = .members(isGroup: isGroup, peerId: peerId, searchQuery: searchQuery)
                    default:
                        searchSubject = .contactsSearch(query: searchQuery, onlyContacts: onlyContacts)
                    }
                    
                    
                    if let searchStateContext = self.searchStateContext, searchStateContext.subject == searchSubject {
                    } else {
                        self.searchStateDisposable?.dispose()
                        let searchStateContext = ShareWithPeersScreen.StateContext(context: component.context, subject: searchSubject)
                        var applyState = false
                        self.searchStateDisposable = (searchStateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.searchStateContext = searchStateContext
                            if applyState {
                                self.state?.updated(transition: ComponentTransition(animation: .none).withUserData(AnimationHint(contentReloaded: true)))
                            }
                        })
                        applyState = true
                    }
                } else if let _ = self.searchStateContext {
                    self.searchStateContext = nil
                    self.searchStateDisposable?.dispose()
                    self.searchStateDisposable = nil
                    
                    contentTransition = contentTransition.withUserData(AnimationHint(contentReloaded: true))
                }
            }
                
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            if case .members = component.stateContext.subject {
                self.dimView.isHidden = true
            } else if case .channels = component.stateContext.subject {
                self.dimView.isHidden = true
            } else {
                self.dimView.isHidden = false
            }
            
            let categoryItemSize = self.categoryTemplateItem.update(
                transition: .immediate,
                component: AnyComponent(CategoryListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    title: "Title",
                    color: .blue,
                    iconName: nil,
                    subtitle: nil,
                    selectionState: .editing(isSelected: false, isTinted: false),
                    hasNext: true,
                    action: {},
                    secondaryAction: {}
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
            var isContactsSearch = false
            if let searchStateContext = self.searchStateContext, case .contactsSearch(_, true) = searchStateContext.subject {
                isContactsSearch = true
            }
            let peerItemSize = self.peerTemplateItem.update(
                transition: transition,
                component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    style: .generic,
                    sideInset: sideInset,
                    title: "Name",
                    peer: nil,
                    subtitle: PeerListItemComponent.Subtitle(text: isContactsSearch ? "" : "sub", color: .neutral),
                    subtitleAccessory: .none,
                    presence: nil,
                    selectionState: .editing(isSelected: false, isTinted: false),
                    hasNext: true,
                    action: { _, _, _ in
                    }
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
            let optionItemSize = self.optionTemplateItem.update(
                transition: transition,
                component: AnyComponent(OptionListItemComponent(
                    theme: environment.theme,
                    title: "Title",
                    hasNext: true,
                    selected: false,
                    selectionChanged: { _ in }
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
                        
            var footersTotalHeight: CGFloat = 0.0
            if case let .stories(editing, _) = component.stateContext.subject {
                let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor)
                let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor)
                
                let footerInset: CGFloat = 7.0
                if hasCategories {
                    let firstFooterText: String
                    if let grayListPeers = component.stateContext.stateValue?.grayListPeers, !grayListPeers.isEmpty {
                        let footerValue = environment.strings.Story_Privacy_GrayListPeople(Int32(grayListPeers.count))
                        firstFooterText = environment.strings.Story_Privacy_GrayListSelected(footerValue).string
                    } else {
                        firstFooterText = environment.strings.Story_Privacy_GrayListSelect
                    }
                    
                    let firstFooterSize = self.footerTemplateItem.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .markdown(text: firstFooterText, attributes: MarkdownAttributes(
                                body: body,
                                bold: bold,
                                link: link,
                                linkAttribute: { url in
                                    return ("URL", url)
                                }
                            )),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1,
                            highlightColor: .clear,
                            highlightAction: { _ in
                                return nil
                            },
                            tapAction: { _, _ in
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemsContainerWidth - 16.0 * 2.0, height: 1000.0)
                    )
                    footersTotalHeight += firstFooterSize.height + footerInset
                }
                
                if !editing {
                    let footerValue = environment.strings.Story_Privacy_KeepOnMyPageHours(Int32(component.timeout / 3600))
                    let secondFooterText = environment.strings.Story_Privacy_KeepOnMyPageInfo(footerValue).string
                    let secondFooterSize = self.footerTemplateItem.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .markdown(text: secondFooterText, attributes: MarkdownAttributes(
                                body: body,
                                bold: bold,
                                link: link,
                                linkAttribute: { url in
                                    return ("URL", url)
                                }
                            )),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1,
                            highlightColor: .clear,
                            highlightAction: { _ in
                                return nil
                            },
                            tapAction: { _, _ in
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemsContainerWidth - 16.0 * 2.0, height: 1000.0)
                    )
                    footersTotalHeight += secondFooterSize.height + footerInset
                }
            }
            
            var sections: [ItemLayout.Section] = []
            if let stateValue = self.effectiveStateValue {
                if case let .peers(peers, _) = component.stateContext.subject {
                    sections.append(ItemLayout.Section(
                        id: 0,
                        insets: UIEdgeInsets(top: 12.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: peerItemSize.height,
                        itemCount: peers.count
                    ))
                } else if case let .stories(editing, _) = component.stateContext.subject {
                    if !editing && hasChannels {
                        sections.append(ItemLayout.Section(
                            id: 0,
                            insets: UIEdgeInsets(top: component.coverItem == nil ? 28.0 : 12.0, left: 0.0, bottom: 0.0, right: 0.0),
                            itemHeight: peerItemSize.height,
                            itemCount: 1
                        ))
                    }
                    if hasCategories {
                        sections.append(ItemLayout.Section(
                            id: 2,
                            insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                            itemHeight: categoryItemSize.height,
                            itemCount: component.categoryItems.count
                        ))
                    }
                    sections.append(ItemLayout.Section(
                        id: 3,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: optionItemSize.height,
                        itemCount: component.optionItems.count
                    ))
                    
                    if hasCover {
                        sections.append(ItemLayout.Section(
                            id: 4,
                            insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                            itemHeight: optionItemSize.height,
                            itemCount: 1
                        ))
                    }
                } else {
                    sections.append(ItemLayout.Section(
                        id: 1,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: peerItemSize.height,
                        itemCount: stateValue.peers.count
                    ))
                }
            }
            
            var containerInset: CGFloat = environment.statusBarHeight
            if case .members = component.stateContext.subject {
            } else if case .channels = component.stateContext.subject {
            } else {
                containerInset += 10.0
            }
                        
            var navigationHeight: CGFloat = 56.0
            let navigationSideInset: CGFloat = 16.0
            var navigationButtonsWidth: CGFloat = 0.0
            
            let navigationLeftButtonSize = self.navigationLeftButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.saveAndDismiss()
                    }
                ).minSize(CGSize(width: navigationHeight, height: navigationHeight))),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: navigationHeight)
            )
            let navigationLeftButtonFrame = CGRect(origin: CGPoint(x: containerSideInset + navigationSideInset, y: floor((navigationHeight - navigationLeftButtonSize.height) * 0.5)), size: navigationLeftButtonSize)
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if navigationLeftButtonView.superview == nil {
                    self.navigationContainerView.addSubview(navigationLeftButtonView)
                }
                transition.setFrame(view: navigationLeftButtonView, frame: navigationLeftButtonFrame)
            }
            navigationButtonsWidth += navigationLeftButtonSize.width + navigationSideInset
            
            var actionButtonTitle = environment.strings.Story_Privacy_SaveList
            let title: String
            var subtitle: String?
            switch component.stateContext.subject {
            case .peers:
                title = environment.strings.Story_Privacy_PostStoryAs
            case let .stories(editing, count):
                if editing {
                    title = environment.strings.Story_Privacy_EditStory
                } else {
                    if count > 1 {
                        title = environment.strings.Story_Privacy_ShareStories
                        actionButtonTitle = environment.strings.Story_Privacy_PostStories(count)
                    } else {
                        title = environment.strings.Story_Privacy_ShareStory
                        actionButtonTitle = environment.strings.Story_Privacy_PostStory
                    }
                }
            case let .chats(grayList):
                if grayList {
                    title = environment.strings.Story_Privacy_HideMyStoriesFrom
                } else {
                    title = environment.strings.Story_Privacy_CategorySelectedContacts
                }
            case let .contacts(category):
                switch category {
                case .closeFriends:
                    title = environment.strings.Story_Privacy_CategoryCloseFriends
                case .contacts:
                    title = environment.strings.Story_Privacy_ExcludedPeople
                case .nobody:
                    title = environment.strings.Story_Privacy_CategorySelectedContacts
                case .everyone:
                    title = environment.strings.Story_Privacy_ExcludedPeople
                }
            case .contactsSearch:
                title = ""
            case let .members(isGroup, _, _):
                title = environment.strings.BoostGift_Subscribers_Title
                subtitle = isGroup ? environment.strings.BoostGift_Members_Subtitle("\(10)").string : environment.strings.BoostGift_Subscribers_Subtitle("\(10)").string
                actionButtonTitle = environment.strings.BoostGift_Subscribers_Save
            case let .channels(isGroup, _, _):
                title = isGroup ? environment.strings.BoostGift_GroupsOrChannels_Title : environment.strings.BoostGift_ChannelsOrGroups_Title
                subtitle = isGroup ? environment.strings.BoostGift_GroupsOrChannels_Subtitle("\(component.context.userLimits.maxGiveawayChannelsCount)").string : environment.strings.BoostGift_ChannelsOrGroups_Subtitle("\(component.context.userLimits.maxGiveawayChannelsCount)").string
                actionButtonTitle = isGroup ? environment.strings.BoostGift_GroupsOrChannels_Save : environment.strings.BoostGift_ChannelsOrGroups_Save
            }
            
            let titleComponent: AnyComponent<Empty>
            if let subtitle {
                titleComponent = AnyComponent(
                    List([
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(Text(text: title, font: Font.semibold(17.0), color: environment.theme.rootController.navigationBar.primaryTextColor))
                        ),
                        AnyComponentWithIdentity(
                            id: "subtitle",
                            component: AnyComponent(Text(text: subtitle, font: Font.regular(13.0), color: environment.theme.rootController.navigationBar.secondaryTextColor))
                        )
                    ],
                    centerAlignment: true)
                )
            } else {
                titleComponent = AnyComponent(Text(text: title, font: Font.semibold(17.0), color: environment.theme.rootController.navigationBar.primaryTextColor))
            }
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: .immediate,
                component: titleComponent,
                environment: {},
                containerSize: CGSize(width: containerWidth - navigationButtonsWidth, height: navigationHeight)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: containerSideInset + floor((containerWidth - navigationTitleSize.width) * 0.5), y: floor((navigationHeight - navigationTitleSize.height) * 0.5)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    self.navigationContainerView.addSubview(navigationTitleView)
                }
                transition.setPosition(view: navigationTitleView, position: navigationTitleFrame.center)
                navigationTitleView.bounds = CGRect(origin: CGPoint(), size: navigationTitleFrame.size)
            }
            
            let navigationTextFieldFrame = CGRect(origin: CGPoint(x: containerSideInset, y: navigationHeight), size: navigationTextFieldSize)
            if let navigationTextFieldView = self.navigationTextField.view {
                if navigationTextFieldView.superview == nil {
                    self.navigationContainerView.addSubview(navigationTextFieldView)
                    self.navigationContainerView.layer.addSublayer(self.textFieldSeparatorLayer)
                }
                transition.setFrame(view: navigationTextFieldView, frame: navigationTextFieldFrame)
                transition.setFrame(layer: self.textFieldSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset, y: navigationTextFieldFrame.maxY), size: CGSize(width: navigationTextFieldFrame.width, height: UIScreenPixel)))
            }
            navigationHeight += navigationTextFieldFrame.height
            
//            if case .stories = component.stateContext.subject {
//                navigationHeight += 16.0
//            }
            
            let topInset: CGFloat
            if environment.inputHeight != 0.0 || !self.navigationTextFieldState.text.isEmpty {
                topInset = 0.0
            } else {
                var inset: CGFloat
                if case .members = component.stateContext.subject {
                    inset = 1000.0
                } else if case .channels = component.stateContext.subject {
                    inset = 1000.0
                } else if case let .stories(editing, _) = component.stateContext.subject {
                    if editing {
                        inset = 351.0
                        inset += 10.0 + environment.safeInsets.bottom + 50.0 + footersTotalHeight
                    } else {
                        if !hasCategories {
                            if self.selectedOptions.contains(.pin) {
                                inset = 422.0
                            } else {
                                inset = 314.0
                            }
                            inset += 10.0 + environment.safeInsets.bottom + 50.0 + footersTotalHeight
                        } else {
                            if hasChannels {
                                if environment.metrics.isTablet {
                                    inset = 725.0
                                } else {
                                    inset = 1000.0
                                }
                            } else {
                                if self.selectedOptions.contains(.pin) {
                                    inset = 1000.0
                                } else {
                                    inset = 464.0
                                    inset += 10.0 + environment.safeInsets.bottom + 50.0 + footersTotalHeight
                                }
                            }
                        }
                    }
                } else if case .peers = component.stateContext.subject {
                    inset = 480.0
                } else {
                    inset = 600.0
                }
                topInset = max(0.0, availableSize.height - containerInset - inset)
            }
            
            self.navigationBackgroundView.update(size: CGSize(width: containerWidth, height: navigationHeight), cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.navigationBackgroundView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: navigationHeight)))
            
            transition.setFrame(layer: self.navigationSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset, y: navigationHeight), size: CGSize(width: containerWidth, height: UIScreenPixel)))
            
            var bottomPanelHeight: CGFloat = 0.0
            var bottomPanelInset: CGFloat = 0.0
            if case .peers = component.stateContext.subject {
                bottomPanelInset = environment.safeInsets.bottom
            } else {
                let badge: Int
                if case .stories = component.stateContext.subject {
                    badge = 0
                } else {
                    badge = self.selectedPeers.count
                }
                
                let actionButtonSize = self.actionButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            color: environment.theme.list.itemCheckColors.fillColor,
                            foreground: environment.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(
                            id: actionButtonTitle,
                            component: AnyComponent(ButtonTextContentComponent(
                                text: actionButtonTitle,
                                badge: badge,
                                textColor: environment.theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                                badgeForeground: environment.theme.list.itemCheckColors.fillColor,
                                combinedAlignment: true
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component, let environment = self.environment, let controller = self.environment?.controller() as? ShareWithPeersScreen else {
                                return
                            }
                            
                            let base: EngineStoryPrivacy.Base
                            if self.selectedCategories.contains(.everyone) {
                                base = .everyone
                            } else if self.selectedCategories.contains(.closeFriends) {
                                base = .closeFriends
                            } else if self.selectedCategories.contains(.contacts) {
                                base = .contacts
                            } else if self.selectedCategories.contains(.selectedContacts) {
                                base = .nobody
                            } else {
                                base = .nobody
                            }
                            
                            let proceed = {
                                var savePeers = true
                                if component.stateContext.editing {
                                    savePeers = false
                                } else if base == .closeFriends {
                                    savePeers = false
                                } else {
                                    if case .stories = component.stateContext.subject {
                                        savePeers = false
                                    } else if case .chats(true) = component.stateContext.subject {
                                        savePeers = false
                                    }
                                }
                                
                                var selectedPeers = self.selectedPeers
                                if case .stories = component.stateContext.subject {
                                    if case .closeFriends = base {
                                        selectedPeers = []
                                    } else {
                                        selectedPeers = component.stateContext.stateValue?.savedSelectedPeers[base] ?? []
                                    }
                                }
                                
                                let complete = {
                                    let peers = component.context.engine.data.get(EngineDataMap(selectedPeers.map { id in
                                        return TelegramEngine.EngineData.Item.Peer.Peer(id: id)
                                    }))
                                    
                                    let _ = (peers
                                    |> deliverOnMainQueue).start(next: { [weak controller, weak component] peers in
                                        guard let controller, let component else {
                                            return
                                        }
                                        component.completion(
                                            self.sendAsPeerId,
                                            EngineStoryPrivacy(
                                                base: base,
                                                additionallyIncludePeers: selectedPeers
                                            ),
                                            self.selectedOptions.contains(.screenshot),
                                            self.selectedOptions.contains(.pin),
                                            peers.values.compactMap { $0 },
                                            true
                                        )
                                        
                                        controller.dismissAllTooltips()
                                        controller.dismiss()
                                    })
                                    
                                }
                                if savePeers {
                                    let _ = (updatePeersListStoredState(engine: component.context.engine, base: base, peerIds: self.selectedPeers)
                                    |> deliverOnMainQueue).start(completed: {
                                        complete()
                                    })
                                } else {
                                    complete()
                                }
                            }
                            
                            if let sendAsPeerId = self.sendAsPeerId, sendAsPeerId.isGroupOrChannel {
                                proceed()
                            } else {
                                let presentAlert: ([String]) -> Void = { usernames in
                                    let usernamesString = String(usernames.map { "@\($0)" }.joined(separator: ", "))
                                    let alertController = textAlertController(
                                        context: component.context,
                                        forceTheme: defaultDarkColorPresentationTheme,
                                        title: environment.strings.Story_Privacy_MentionRestrictedTitle,
                                        text: environment.strings.Story_Privacy_MentionRestrictedText(usernamesString).string,
                                        actions: [
                                            TextAlertAction(type: .defaultAction, title: environment.strings.Story_Privacy_MentionRestrictedProceed, action: {
                                                proceed()
                                            }),
                                            TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {})
                                        ],
                                        actionLayout: .vertical
                                    )
                                    controller.present(alertController, in: .window(.root))
                                }
                                
                                func matchingUsername(user: TelegramUser, usernames: Set<String>) -> String? {
                                    for username in user.usernames {
                                        if usernames.contains(username.username) {
                                            return username.username
                                        }
                                    }
                                    if let username = user.username {
                                        if usernames.contains(username) {
                                            return username
                                        }
                                    }
                                    return nil
                                }
                                
                                let context = component.context
                                let selectedPeerIds = self.selectedPeers
                                
                                if case .stories = component.stateContext.subject {
                                    if component.mentions.isEmpty {
                                        proceed()
                                    } else if case .nobody = base {
                                        if selectedPeerIds.isEmpty {
                                            presentAlert(component.mentions)
                                        } else {
                                            let _ = (context.account.postbox.transaction { transaction in
                                                var filteredMentions = Set(component.mentions)
                                                for peerId in selectedPeerIds {
                                                    if let peer = transaction.getPeer(peerId) {
                                                        if let user = peer as? TelegramUser {
                                                            if let username = matchingUsername(user: user, usernames: filteredMentions) {
                                                                filteredMentions.remove(username)
                                                            }
                                                        } else {
                                                            if let username = peer.addressName {
                                                                filteredMentions.remove(username)
                                                            }
                                                        }
                                                    }
                                                }
                                                return Array(filteredMentions)
                                            }
                                            |> deliverOnMainQueue).start(next: { mentions in
                                                if mentions.isEmpty {
                                                    proceed()
                                                } else {
                                                    presentAlert(mentions)
                                                }
                                            })
                                        }
                                    } else if case .contacts = base {
                                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
                                        |> map { contacts -> [String] in
                                            var filteredMentions = Set(component.mentions)
                                            let peers = contacts.peers
                                            for peer in peers {
                                                if selectedPeerIds.contains(peer.id) {
                                                    continue
                                                }
                                                if case let .user(user) = peer, let username = matchingUsername(user: user, usernames: filteredMentions) {
                                                    filteredMentions.remove(username)
                                                }
                                            }
                                            return Array(filteredMentions)
                                        }
                                                 |> deliverOnMainQueue).start(next: { mentions in
                                            if mentions.isEmpty {
                                                proceed()
                                            } else {
                                                presentAlert(mentions)
                                            }
                                        })
                                    } else if case .closeFriends = base {
                                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
                                                 |> map { contacts -> [String] in
                                            var filteredMentions = Set(component.mentions)
                                            let peers = contacts.peers
                                            for peer in peers {
                                                if case let .user(user) = peer, user.flags.contains(.isCloseFriend), let username = matchingUsername(user: user, usernames: filteredMentions) {
                                                    filteredMentions.remove(username)
                                                }
                                            }
                                            return Array(filteredMentions)
                                        }
                                                 |> deliverOnMainQueue).start(next: { mentions in
                                            if mentions.isEmpty {
                                                proceed()
                                            } else {
                                                presentAlert(mentions)
                                            }
                                        })
                                    } else {
                                        proceed()
                                    }
                                } else {
                                    proceed()
                                }
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: containerWidth - navigationSideInset * 2.0, height: 50.0)
                )
                
                if environment.inputHeight != 0.0 {
                    bottomPanelHeight += environment.inputHeight + 8.0 + actionButtonSize.height
                } else {
                    bottomPanelHeight += 10.0 + environment.safeInsets.bottom + actionButtonSize.height
                }
                let actionButtonFrame = CGRect(origin: CGPoint(x: containerSideInset + navigationSideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
                if let actionButtonView = self.actionButton.view {
                    if actionButtonView.superview == nil {
                        self.containerView.addSubview(actionButtonView)
                    }
                    transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
                }
                
                bottomPanelInset = 8.0
                transition.setFrame(view: self.bottomBackgroundView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: availableSize.height - bottomPanelHeight - 8.0), size: CGSize(width: containerWidth, height: bottomPanelHeight + bottomPanelInset)))
                self.bottomBackgroundView.update(size: self.bottomBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
                transition.setFrame(layer: self.bottomSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset, y: availableSize.height - bottomPanelHeight - bottomPanelInset - UIScreenPixel), size: CGSize(width: containerWidth, height: UIScreenPixel)))
            }
                        
            let itemContainerSize = CGSize(width: itemsContainerWidth, height: availableSize.height)
            let itemLayout = ItemLayout(style: itemLayoutStyle, containerSize: itemContainerSize, containerInset: containerInset, bottomInset: footersTotalHeight, topInset: topInset, sideInset: sideInset, navigationHeight: navigationHeight, sections: sections)
            let previousItemLayout = self.itemLayout
            self.itemLayout = itemLayout
            
            contentTransition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: itemLayout.contentHeight + footersTotalHeight)))
            
            let scrollContentHeight = max(topInset + itemLayout.contentHeight + containerInset + bottomPanelHeight, availableSize.height - containerInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: containerWidth, height: itemLayout.contentHeight)))
            
            transition.setPosition(view: self.backgroundView, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height)))
            
            var scrollClippingInset: CGFloat = 0.0
            if case .members = component.stateContext.subject {
            } else if case .channels = component.stateContext.subject {
            } else {
                scrollClippingInset = 10.0
            }
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset + scrollClippingInset), size: CGSize(width: availableSize.width, height: availableSize.height - scrollClippingInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            var dismissOffset: CGFloat = 0.0
            if let dismissPanState = self.dismissPanState {
                dismissOffset = max(0.0, dismissPanState.translation)
            }
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: dismissOffset), size: availableSize))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height)))
            let contentSize = CGSize(width: containerWidth, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            let contentInset: UIEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomPanelHeight + bottomPanelInset, right: 0.0)
            let indicatorInset = UIEdgeInsets(top: max(itemLayout.containerInset, environment.safeInsets.top + navigationHeight), left: 0.0, bottom: contentInset.bottom, right: 0.0)
            if indicatorInset != self.scrollView.verticalScrollIndicatorInsets {
                self.scrollView.verticalScrollIndicatorInsets = indicatorInset
            }
            if contentInset != self.scrollView.contentInset {
                self.scrollView.contentInset = contentInset
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height))
            } else if let previousItemLayout, previousItemLayout.topInset != topInset {
                let topInsetDifference = previousItemLayout.topInset - topInset
                var scrollBounds = self.scrollView.bounds
                scrollBounds.origin.y += -topInsetDifference
                scrollBounds.origin.y = max(0.0, min(scrollBounds.origin.y, self.scrollView.contentSize.height - scrollBounds.height))
                let visibleDifference = self.scrollView.bounds.origin.y - scrollBounds.origin.y
                self.scrollView.bounds = scrollBounds
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: visibleDifference), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: contentTransition)
             
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ShareWithPeersScreen: ViewControllerComponentContainer {    
    private let context: AccountContext
    
    private var isCustomModal = true
    private var isDismissed: Bool = false
    
    public var dismissed: () -> Void = {}
    
    public init(
        context: AccountContext,
        initialPrivacy: EngineStoryPrivacy,
        initialSendAsPeerId: EnginePeer.Id? = nil,
        allowScreenshots: Bool = true,
        pin: Bool = false,
        timeout: Int = 0,
        mentions: [String] = [],
        coverImage: UIImage? = nil,
        stateContext: StateContext,
        completion: @escaping (EnginePeer.Id?, EngineStoryPrivacy, Bool, Bool, [EnginePeer], Bool) -> Void,
        editCategory: @escaping (EngineStoryPrivacy, Bool, Bool) -> Void = { _, _, _ in },
        editBlockedPeers: @escaping (EngineStoryPrivacy, Bool, Bool) -> Void = { _, _, _ in },
        editCover: @escaping () -> Void = { },
        peerCompletion: @escaping (EnginePeer.Id) -> Void = { _ in }
    ) {
        self.context = context
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var categoryItems: [ShareWithPeersScreenComponent.CategoryItem] = []
        var optionItems: [ShareWithPeersScreenComponent.OptionItem] = []
        var coverItem: ShareWithPeersScreenComponent.CoverItem?
        if case let .stories(editing, _) = stateContext.subject {
            var everyoneSubtitle = presentationData.strings.Story_Privacy_ExcludePeople
            if (stateContext.stateValue?.savedSelectedPeers[.everyone]?.count ?? 0) > 0 {
                var peerNamesArray: [String] = []
                var peersCount = 0
                if let state = stateContext.stateValue, let peerIds = state.savedSelectedPeers[.everyone] {
                    peersCount = peerIds.count
                    for peerId in peerIds {
                        if let peer = state.peersMap[peerId] {
                            peerNamesArray.append(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))
                        }
                    }
                }
                let peerNames = String(peerNamesArray.map { $0 }.joined(separator: ", "))
                if peersCount == 1 {
                    if !peerNames.isEmpty {
                        everyoneSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                    } else {
                        everyoneSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExcept(1)
                    }
                } else {
                    if !peerNames.isEmpty {
                        everyoneSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                    } else {
                        everyoneSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExcept(Int32(peersCount))
                    }
                }
            }
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .everyone,
                title: presentationData.strings.Story_Privacy_CategoryEveryone,
                icon: "Media Editor/Privacy/Everyone",
                iconColor: .blue,
                actionTitle: everyoneSubtitle
            ))
                                    
            var contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeople
            if (stateContext.stateValue?.savedSelectedPeers[.contacts]?.count ?? 0) > 0 {
                var peerNamesArray: [String] = []
                var peersCount = 0
                if let state = stateContext.stateValue, let peerIds = state.savedSelectedPeers[.contacts] {
                    peersCount = peerIds.count
                    for peerId in peerIds {
                        if let peer = state.peersMap[peerId] {
                            peerNamesArray.append(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))
                        }
                    }
                }
                let peerNames = String(peerNamesArray.map { $0 }.joined(separator: ", "))
                if peersCount == 1 {
                    if !peerNames.isEmpty {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                    } else {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExcept(1)
                    }
                } else {
                    if !peerNames.isEmpty {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                    } else {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExcept(Int32(peersCount))
                    }
                }
            }
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .contacts,
                title: presentationData.strings.Story_Privacy_CategoryContacts,
                icon: "Media Editor/Privacy/Contacts",
                iconColor: .violet,
                actionTitle: contactsSubtitle
            ))
            
            var closeFriendsSubtitle = presentationData.strings.Story_Privacy_EditList
            if let peers = stateContext.stateValue?.closeFriendsPeers, !peers.isEmpty {
                if peers.count > 2 {
                    closeFriendsSubtitle = presentationData.strings.Story_Privacy_People(Int32(peers.count))
                } else {
                    closeFriendsSubtitle = String(peers.map { $0.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) }.joined(separator: ", "))
                }
            }
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .closeFriends,
                title: presentationData.strings.Story_Privacy_CategoryCloseFriends,
                icon: "Media Editor/Privacy/CloseFriends",
                iconColor: .green,
                actionTitle: closeFriendsSubtitle
            ))
            
            var selectedContactsSubtitle = presentationData.strings.Story_Privacy_Choose
            if (stateContext.stateValue?.savedSelectedPeers[.nobody]?.count ?? 0) > 0 {
                var peerNamesArray: [String] = []
                var peersCount = 0
                if let state = stateContext.stateValue, let peerIds = state.savedSelectedPeers[.nobody] {
                    peersCount = peerIds.count
                    for peerId in peerIds {
                        if let peer = state.peersMap[peerId] {
                            peerNamesArray.append(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))
                        }
                    }
                }
                let peerNames = String(peerNamesArray.map { $0 }.joined(separator: ", "))
                if peersCount == 1 {
                    if !peerNames.isEmpty {
                        selectedContactsSubtitle = peerNames
                    } else {
                        selectedContactsSubtitle = presentationData.strings.Story_Privacy_People(1)
                    }
                } else {
                    if !peerNames.isEmpty {
                        selectedContactsSubtitle = peerNames
                    } else {
                        selectedContactsSubtitle = presentationData.strings.Story_Privacy_People(Int32(peersCount))
                    }
                }
            }
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .selectedContacts,
                title: presentationData.strings.Story_Privacy_CategorySelectedContacts,
                icon: "Media Editor/Privacy/SelectedUsers",
                iconColor: .yellow,
                actionTitle: selectedContactsSubtitle
            ))
            
            if !editing {
                optionItems.append(ShareWithPeersScreenComponent.OptionItem(
                    id: .screenshot,
                    title: presentationData.strings.Story_Privacy_AllowScreenshots
                ))
                
                optionItems.append(ShareWithPeersScreenComponent.OptionItem(
                    id: .pin,
                    title: presentationData.strings.Story_Privacy_KeepOnMyPage
                ))
            }
            
            if !editing || pin, coverImage != nil {
                coverItem = ShareWithPeersScreenComponent.CoverItem(id: .choose, title: presentationData.strings.Story_Privacy_ChooseCover, image: coverImage)
            }
        }
        
        var theme: ViewControllerComponentContainer.Theme = .dark
        if case .members = stateContext.subject {
            theme = .default
        } else if case .channels = stateContext.subject {
            theme = .default
        }
        super.init(context: context, component: ShareWithPeersScreenComponent(
            context: context,
            stateContext: stateContext,
            initialPrivacy: initialPrivacy,
            initialSendAsPeerId: initialSendAsPeerId,
            screenshot: allowScreenshots,
            pin: pin,
            timeout: timeout,
            mentions: mentions,
            categoryItems: categoryItems,
            optionItems: optionItems,
            coverItem: coverItem,
            completion: completion,
            editCategory: editCategory,
            editBlockedPeers: editBlockedPeers,
            editCover: editCover,
            peerCompletion: peerCompletion
        ), navigationBarAppearance: .none, theme: theme)
        
        self.statusBar.statusBarStyle = .Ignore
        if case .members = stateContext.subject {
            self.navigationPresentation = .modal
            self.isCustomModal = false
        } else if case .channels = stateContext.subject {
            self.navigationPresentation = .modal
            self.isCustomModal = false
        } else {
            self.navigationPresentation = .flatModal
        }
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if !self.isDismissed {
            self.isDismissed = true
            self.dismissed()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        var updatedLayout = layout
        updatedLayout.intrinsicInsets.bottom += 66.0
        self.presentationContext.containerLayoutUpdated(updatedLayout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.isCustomModal {
            self.view.disablesInteractiveModalDismiss = true
            
            if let componentView = self.node.hostView.componentView as? ShareWithPeersScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController { controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
        }
        self.forEachController { controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        }
    }
    
    func requestDismiss() {
        self.dismissAllTooltips()
        self.dismissed()
        self.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            self.view.endEditing(true)
           
            if self.isCustomModal {
                if let componentView = self.node.hostView.componentView as? ShareWithPeersScreenComponent.View {
                    componentView.animateOut(completion: { [weak self] in
                        completion?()
                        self?.dismiss(animated: false)
                    })
                } else {
                    self.dismiss(animated: false)
                }
            } else {
                self.dismiss(animated: true)
            }
        }
    }
}
