import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import MultilineTextComponent
import ButtonComponent
import BundleIconComponent
import Markdown
import PresentationDataUtils
import TelegramStringFormatting
import ContextUI
import AvatarNode
import PlainButtonComponent
import ToastComponent

private final class JoinAffiliateProgramScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let sourcePeer: EnginePeer
    let commissionPermille: Int32
    let programDuration: Int32?
    let revenuePerUser: Double
    let mode: JoinAffiliateProgramScreen.Mode
    
    init(
        context: AccountContext,
        sourcePeer: EnginePeer,
        commissionPermille: Int32,
        programDuration: Int32?,
        revenuePerUser: Double,
        mode: JoinAffiliateProgramScreen.Mode
    ) {
        self.context = context
        self.sourcePeer = sourcePeer
        self.commissionPermille = commissionPermille
        self.programDuration = programDuration
        self.revenuePerUser = revenuePerUser
        self.mode = mode
    }
    
    static func ==(lhs: JoinAffiliateProgramScreenComponent, rhs: JoinAffiliateProgramScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationBarSeparator: SimpleLayer
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let closeButton = ComponentView<Empty>()
        
        private var toast: ComponentView<Empty>?
        
        private let sourceAvatar = ComponentView<Empty>()
        private let sourceAvatarBadge = ComponentView<Empty>()
        private let targetAvatar = ComponentView<Empty>()
        private let targetAvatarBadge = ComponentView<Empty>()
        private let sourceTargetArrow = UIImageView()
        
        private let linkIconBackground = ComponentView<Empty>()
        private let linkIcon = ComponentView<Empty>()
        private var linkIconBadge: ComponentView<Empty>?
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let openBotButton = ComponentView<Empty>()
        private var dailyRevenueText: ComponentView<Empty>?
        private let titleTransformContainer: UIView
        private let bottomPanelContainer: UIView
        private let actionButton = ComponentView<Empty>()
        private let bottomText = ComponentView<Empty>()
        private let linkText = ComponentView<Empty>()
        
        private let targetText = ComponentView<Empty>()
        private let targetPeer = ComponentView<Empty>()
        
        private let bottomOverscrollLimit: CGFloat
        
        private var isFirstTimeApplyingModalFactor: Bool = true
        private var ignoreScrolling: Bool = false
        
        private var component: JoinAffiliateProgramScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        private var itemLayout: ItemLayout?
        private var topOffsetDistance: CGFloat?
        
        private var currentTargetPeer: EnginePeer?
        private var currentMode: JoinAffiliateProgramScreen.Mode?
        
        private var possibleTargetPeers: [EnginePeer] = []
        private var possibleTargetPeersDisposable: Disposable?
        
        private var changeTargetPeerDisposable: Disposable?
        private var isChangingTargetPeer: Bool = false
        
        private var cachedCloseImage: UIImage?
        private var inlineTextStarImage: UIImage?
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationBarSeparator = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.titleTransformContainer = UIView()
            self.titleTransformContainer.isUserInteractionEnabled = false
            
            self.bottomPanelContainer = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
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
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.addSubview(self.navigationBarContainer)
            self.addSubview(self.titleTransformContainer)
            self.addSubview(self.bottomPanelContainer)
            
            self.navigationBarContainer.addSubview(self.navigationBackgroundView)
            self.navigationBarContainer.layer.addSublayer(self.navigationBarSeparator)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.possibleTargetPeersDisposable?.dispose()
            self.changeTargetPeerDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            
            let titleCenterY: CGFloat = -itemLayout.topInset + itemLayout.containerInset + 54.0 * 0.5
            
            let titleTransformDistance: CGFloat = 20.0
            let titleY: CGFloat = max(titleCenterY, self.titleTransformContainer.center.y + topOffset + itemLayout.containerInset)
            
            transition.setSublayerTransform(view: self.titleTransformContainer, transform: CATransform3DMakeTranslation(0.0, titleY - self.titleTransformContainer.center.y, 0.0))
            
            let titleYDistance: CGFloat = titleY - titleCenterY
            let titleTransformFraction: CGFloat = 1.0 - max(0.0, min(1.0, titleYDistance / titleTransformDistance))
            let titleMinScale: CGFloat = 17.0 / 24.0
            let titleScale: CGFloat = 1.0 * (1.0 - titleTransformFraction) + titleMinScale * titleTransformFraction
            if let titleView = self.title.view {
                transition.setScale(view: titleView, scale: titleScale)
            }
            
            let navigationAlpha: CGFloat = titleTransformFraction
            transition.setAlpha(view: self.navigationBackgroundView, alpha: navigationAlpha)
            transition.setAlpha(layer: self.navigationBarSeparator, alpha: navigationAlpha)
            
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            if let toastView = self.toast?.view {
                let toastY = topOffset + itemLayout.containerInset - toastView.bounds.height - 16.0
                transition.setTransform(layer: toastView.layer, transform: CATransform3DMakeTranslation(0.0, toastY, 0.0))
                
                let toastAlpha: CGFloat
                if toastY < itemLayout.containerInset {
                    toastAlpha = 0.0
                } else {
                    toastAlpha = 1.0
                }
                if toastAlpha != toastView.alpha {
                    ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: toastView, alpha: toastAlpha)
                }
            }
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            var modalOverlayTransition = transition
            if self.isFirstTimeApplyingModalFactor {
                self.isFirstTimeApplyingModalFactor = false
                modalOverlayTransition = .spring(duration: 0.5)
            }
            if self.isUpdating {
                DispatchQueue.main.async { [weak controller] in
                    guard let controller else {
                        return
                    }
                    controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalOverlayTransition.containedViewLayoutTransition)
                }
            } else {
                controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalOverlayTransition.containedViewLayoutTransition)
            }
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.titleTransformContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomPanelContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let toastView = self.toast?.view {
                toastView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                toastView.layer.animateAlpha(from: 0.0, to: toastView.alpha, duration: 0.15)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.titleTransformContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomPanelContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let toastView = self.toast?.view {
                toastView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
                toastView.layer.animateAlpha(from: toastView.alpha, to: 0.0, duration: 0.15, removeOnCompletion: false)
            }
            
            if let environment = self.environment, let controller = environment.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        }
        
        private func displayTargetSelectionMenu(sourceView: UIView) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            guard let currentTargetPeer = self.currentTargetPeer else {
                return
            }
            
            var items: [ContextMenuItem] = []
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            let peers: [EnginePeer] = self.possibleTargetPeers.isEmpty ? [
                currentTargetPeer
            ] : self.possibleTargetPeers
            
            let avatarSize = CGSize(width: 30.0, height: 30.0)
            
            for peer in peers {
                let peerLabel: String
                if peer.id == component.context.account.peerId {
                    peerLabel = environment.strings.AffiliateProgram_PeerTypeSelf
                } else if case .channel = peer {
                    peerLabel = environment.strings.Channel_Status
                } else {
                    peerLabel = environment.strings.Bot_GenericBotStatus
                }
                let isSelected = peer.id == self.currentTargetPeer?.id
                let accentColor = environment.theme.list.itemAccentColor
                let avatarSignal = peerAvatarCompleteImage(account: component.context.account, peer: peer, size: avatarSize)
                |> map { image in
                    let context = DrawingContext(size: avatarSize, scale: 0.0, clear: true)
                    context?.withContext { c in
                        UIGraphicsPushContext(c)
                        defer {
                            UIGraphicsPopContext()
                        }
                        if isSelected {
                            
                        }
                        c.saveGState()
                        let scaleFactor = (avatarSize.width - 3.0 * 2.0) / avatarSize.width
                        if isSelected {
                            c.translateBy(x: avatarSize.width * 0.5, y: avatarSize.height * 0.5)
                            c.scaleBy(x: scaleFactor, y: scaleFactor)
                            c.translateBy(x: -avatarSize.width * 0.5, y: -avatarSize.height * 0.5)
                        }
                        if let image {
                            image.draw(in: CGRect(origin: CGPoint(), size: avatarSize))
                        }
                        c.restoreGState()
                        
                        if isSelected {
                            c.setStrokeColor(accentColor.cgColor)
                            let lineWidth: CGFloat = 1.0 + UIScreenPixel
                            c.setLineWidth(lineWidth)
                            c.strokeEllipse(in: CGRect(origin: CGPoint(), size: avatarSize).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
                        }
                    }
                    return context?.generateImage()
                }
                items.append(.action(ContextMenuActionItem(text: peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder), textLayout: .secondLineWithValue(peerLabel), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: avatarSignal), action: { [weak self] c, _ in
                    c?.dismiss(completion: {})
                    
                    guard let self, let currentMode = self.currentMode, let component = self.component else {
                        return
                    }
                    if self.currentTargetPeer?.id == peer.id {
                        return
                    }
                    
                    self.currentTargetPeer = peer
                    
                    switch currentMode {
                    case .join:
                        self.currentTargetPeer = peer
                    case let .active(active):
                        self.isChangingTargetPeer = true
                        self.changeTargetPeerDisposable?.dispose()
                        self.changeTargetPeerDisposable = (component.context.engine.peers.connectStarRefBot(id: peer.id, botId: component.sourcePeer.id)
                        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                            guard let self else {
                                return
                            }
                            self.isChangingTargetPeer = false
                            
                            self.currentMode = .active(JoinAffiliateProgramScreen.Mode.Active(
                                targetPeer: peer,
                                bot: result,
                                copyLink: active.copyLink
                            ))
                            self.state?.updated(transition: .immediate)
                        }, error: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.isChangingTargetPeer = false
                            self.state?.updated(transition: .immediate)
                        })
                    }
                    
                    self.state?.updated(transition: .immediate)
                })))
            }
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, actionsOnTop: true)), items: .single(ContextController.Items(id: AnyHashable(0), content: .list(items))), gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
        
        func update(component: JoinAffiliateProgramScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            let currentMode = self.currentMode ?? component.mode
            
            if self.component == nil {
                self.currentMode = component.mode
                
                var loadPossibleTargetPeers = false
                switch component.mode {
                case let .join(join):
                    self.currentTargetPeer = join.initialTargetPeer
                    loadPossibleTargetPeers = join.canSelectTargetPeer
                case let .active(active):
                    self.currentTargetPeer = active.targetPeer
                    loadPossibleTargetPeers = true
                }
                
                if loadPossibleTargetPeers {
                    self.possibleTargetPeersDisposable = (component.context.engine.peers.getPossibleStarRefBotTargets()
                    |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                        guard let self else {
                            return
                        }
                        self.possibleTargetPeers = result
                    })
                }
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.list.plainBackgroundColor.cgColor
                
                self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationBarSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            
            let closeImage: UIImage
            if let image = self.cachedCloseImage, !themeUpdated {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.05), foregroundColor: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.4))!
                self.cachedCloseImage = closeImage
            }
            
            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(image: closeImage, size: closeImage.size)),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        controller.dismiss()
                    }
                ).minSize(CGSize(width: 62.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - closeButtonSize.width, y: 0.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            let clippingY: CGFloat
            
            if let currentTargetPeer = self.currentTargetPeer, case .join = currentMode {
                contentHeight += 34.0
                
                let sourceAvatarSize = self.sourceAvatar.update(
                    transition: transition,
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        peer: component.sourcePeer
                    )),
                    environment: {},
                    containerSize: CGSize(width: 78.0, height: 78.0)
                )
                let targetAvatarSize = self.targetAvatar.update(
                    transition: transition,
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        peer: currentTargetPeer
                    )),
                    environment: {},
                    containerSize: CGSize(width: 78.0, height: 78.0)
                )
                
                let avatarSpacing: CGFloat = 41.0
                
                let sourceAvatarFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - sourceAvatarSize.width - avatarSpacing - targetAvatarSize.width) * 0.5), y: contentHeight), size: sourceAvatarSize)
                let targetAvatarFrame = CGRect(origin: CGPoint(x: sourceAvatarFrame.maxX + avatarSpacing, y: contentHeight), size: targetAvatarSize)
                
                if let sourceAvatarView = self.sourceAvatar.view {
                    if sourceAvatarView.superview == nil {
                        self.scrollContentView.addSubview(sourceAvatarView)
                    }
                    transition.setFrame(view: sourceAvatarView, frame: sourceAvatarFrame)
                }
                if let targetAvatarView = self.targetAvatar.view {
                    if targetAvatarView.superview == nil {
                        self.scrollContentView.addSubview(targetAvatarView)
                    }
                    transition.setFrame(view: targetAvatarView, frame: targetAvatarFrame)
                }
                
                if component.revenuePerUser != 0.0 {
                    var revenueString = String(format: "%.1f", component.revenuePerUser)
                    if revenueString.hasSuffix(".0") {
                        revenueString = String(revenueString[revenueString.startIndex ..< revenueString.index(revenueString.endIndex, offsetBy: -2)])
                    }
                    let sourceAvatarBadgeSize = self.sourceAvatarBadge.update(
                        transition: transition,
                        component: AnyComponent(BorderedBadgeComponent(
                            backgroundColor: environment.theme.list.itemDisclosureActions.constructive.fillColor,
                            cutoutColor: environment.theme.list.plainBackgroundColor,
                            content: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(TransformContents(
                                    content: AnyComponent(BundleIconComponent(
                                        name: "Premium/PremiumStar",
                                        tintColor: environment.theme.list.itemDisclosureActions.constructive.foregroundColor,
                                        scaleFactor: 0.58
                                    )),
                                    fixedSize: CGSize(width: 13.0, height: 10.0),
                                    translation: CGPoint(x: 0.0, y: 1.0 + UIScreenPixel)
                                ))),
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(string: revenueString, font: Font.regular(13.0), textColor: environment.theme.list.itemDisclosureActions.constructive.foregroundColor))
                                )))
                            ], spacing: 2.0)),
                            insets: UIEdgeInsets(top: 3.0, left: 6.0, bottom: 3.0, right: 6.0),
                            cutoutWidth: 1.0 + UIScreenPixel)
                        ),
                        environment: {},
                        containerSize: CGSize(width: 100.0, height: 100.0)
                    )
                    let sourceAvatarBadgeFrame = CGRect(origin: CGPoint(x: sourceAvatarFrame.minX + floor((sourceAvatarFrame.width - sourceAvatarBadgeSize.width) * 0.5), y: sourceAvatarFrame.maxY - 7.0 - floor(sourceAvatarBadgeSize.height * 0.5)), size: sourceAvatarBadgeSize)
                    if let sourceAvatarBadgeView = self.sourceAvatarBadge.view {
                        if sourceAvatarBadgeView.superview == nil {
                            self.scrollContentView.addSubview(sourceAvatarBadgeView)
                        }
                        transition.setFrame(view: sourceAvatarBadgeView, frame: sourceAvatarBadgeFrame)
                    }
                }
                
                let targetAvatarBadgeSize = self.targetAvatarBadge.update(
                    transition: transition,
                    component: AnyComponent(BorderedBadgeComponent(
                        backgroundColor: environment.theme.list.itemCheckColors.fillColor,
                        cutoutColor: environment.theme.list.plainBackgroundColor,
                        content: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(TransformContents(
                                    content: AnyComponent(BundleIconComponent(
                                        name: "Media Editor/Link",
                                        tintColor: environment.theme.list.itemCheckColors.foregroundColor,
                                        scaleFactor: 0.75
                                    )),
                                    translation: CGPoint(x: 0.0, y: 0.0)
                                ))
                            ),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: "\(formatPermille(component.commissionPermille))%", font: Font.regular(13.0), textColor: environment.theme.list.itemCheckColors.foregroundColor))
                            )))
                        ], spacing: 2.0)),
                        insets: UIEdgeInsets(top: 3.0, left: 6.0, bottom: 3.0, right: 6.0),
                        cutoutWidth: 1.0 + UIScreenPixel)
                    ),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let targetAvatarBadgeFrame = CGRect(origin: CGPoint(x: targetAvatarFrame.minX + floor((targetAvatarFrame.width - targetAvatarBadgeSize.width) * 0.5), y: targetAvatarFrame.maxY - 7.0 - floor(targetAvatarBadgeSize.height * 0.5)), size: targetAvatarBadgeSize)
                if let targetAvatarBadgeView = self.targetAvatarBadge.view {
                    if targetAvatarBadgeView.superview == nil {
                        self.scrollContentView.addSubview(targetAvatarBadgeView)
                    }
                    transition.setFrame(view: targetAvatarBadgeView, frame: targetAvatarBadgeFrame)
                }
                
                contentHeight += sourceAvatarSize.height + 16.0
                
                if self.sourceTargetArrow.image == nil || themeUpdated {
                    self.sourceTargetArrow.image = generateImage(CGSize(width: 12.0, height: 22.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setStrokeColor(environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.2).cgColor)
                        
                        let lineWidth: CGFloat = 3.0
                        context.setLineWidth(lineWidth)
                        context.setLineJoin(.round)
                        context.setLineCap(.round)
                        
                        context.move(to: CGPoint(x: lineWidth * 0.5, y: lineWidth * 0.5))
                        context.addLine(to: CGPoint(x: size.width - lineWidth * 0.5, y: size.height * 0.5))
                        context.addLine(to: CGPoint(x: lineWidth * 0.5, y: size.height - lineWidth * 0.5))
                        context.strokePath()
                    })
                }
                if let sourceTargetArrowSize = self.sourceTargetArrow.image?.size {
                    let sourceTargetArrowFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - sourceTargetArrowSize.width) * 0.5), y: sourceAvatarFrame.minY + floor((sourceAvatarFrame.height - sourceTargetArrowSize.height) * 0.5)), size: sourceTargetArrowSize)
                    
                    if self.sourceTargetArrow.superview == nil {
                        self.scrollContentView.addSubview(self.sourceTargetArrow)
                    }
                    transition.setFrame(view: self.sourceTargetArrow, frame: sourceTargetArrowFrame)
                }
            } else if case let .active(active) = currentMode {
                contentHeight += 31.0
                
                let linkIconBackgroundSize = self.linkIconBackground.update(
                    transition: transition,
                    component: AnyComponent(FilledRoundedRectangleComponent(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        cornerRadius: .minEdge,
                        smoothCorners: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 90.0, height: 90.0)
                )
                let linkIconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - linkIconBackgroundSize.width) * 0.5), y: contentHeight), size: linkIconBackgroundSize)
                if let linkIconBackgroundView = self.linkIconBackground.view {
                    if linkIconBackgroundView.superview == nil {
                        self.scrollContentView.addSubview(linkIconBackgroundView)
                    }
                    transition.setFrame(view: linkIconBackgroundView, frame: linkIconBackgroundFrame)
                }
                
                let linkIconSize = self.linkIcon.update(
                    transition: transition,
                    component: AnyComponent(BundleIconComponent(
                        name: "Chat/Links/LargeLink",
                        tintColor: environment.theme.list.itemCheckColors.foregroundColor,
                        scaleFactor: 0.88
                    )),
                    environment: {},
                    containerSize: linkIconBackgroundSize
                )
                let linkIconFrame = CGRect(origin: CGPoint(x: linkIconBackgroundFrame.minX + floor((linkIconBackgroundFrame.width - linkIconSize.width) * 0.5), y: linkIconBackgroundFrame.minY + floor((linkIconBackgroundFrame.height - linkIconSize.height) * 0.5)), size: linkIconSize)
                if let linkIconView = self.linkIcon.view {
                    if linkIconView.superview == nil {
                        self.scrollContentView.addSubview(linkIconView)
                    }
                    transition.setFrame(view: linkIconView, frame: linkIconFrame)
                }
                
                if active.bot.participants != 0 {
                    let linkIconBadge: ComponentView<Empty>
                    var linkIconBadgeTransition = transition
                    if let current = self.linkIconBadge {
                        linkIconBadge = current
                    } else {
                        linkIconBadgeTransition = linkIconBadgeTransition.withAnimation(.none)
                        linkIconBadge = ComponentView()
                        self.linkIconBadge = linkIconBadge
                    }
                    
                    let linkIconBadgeSize = linkIconBadge.update(
                        transition: .immediate,
                        component: AnyComponent(BorderedBadgeComponent(
                            backgroundColor: UIColor(rgb: 0x34C759),
                            cutoutColor: environment.theme.list.plainBackgroundColor,
                            content: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                                    name: "Stories/RepostUser",
                                    tintColor: environment.theme.list.itemCheckColors.foregroundColor,
                                    scaleFactor: 1.0
                                ))),
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(string: "\(active.bot.participants)", font: Font.bold(14.0), textColor: .white))
                                )))
                            ], spacing: 4.0)),
                            insets: UIEdgeInsets(top: 4.0, left: 9.0, bottom: 4.0, right: 8.0),
                            cutoutWidth: 1.0 + UIScreenPixel)
                        ),
                        environment: {},
                        containerSize: CGSize(width: 100.0, height: 100.0)
                    )
                    let linkIconBadgeFrame = CGRect(origin: CGPoint(x: linkIconBackgroundFrame.minX + floor((linkIconBackgroundFrame.width - linkIconBadgeSize.width) * 0.5), y: linkIconBackgroundFrame.maxY - floor(linkIconBadgeSize.height * 0.5)), size: linkIconBadgeSize)
                    if let linkIconBadgeView = linkIconBadge.view {
                        if linkIconBadgeView.superview == nil {
                            self.scrollContentView.addSubview(linkIconBadgeView)
                        }
                        linkIconBadgeTransition.setFrame(view: linkIconBadgeView, frame: linkIconBadgeFrame)
                    }
                } else if let linkIconBadge = self.linkIconBadge {
                    self.linkIconBadge = nil
                    linkIconBadge.view?.removeFromSuperview()
                }
                
                contentHeight += linkIconBackgroundSize.height + 21.0
            }
            
            let commissionTitle = "\(formatPermille(component.commissionPermille))%"
            
            let titleString: String
            var subtitleString: String
            var dailyRevenueString: String?
            let termsString: String
            switch currentMode {
            case .join:
                titleString = environment.strings.AffiliateProgram_JoinTitle
                
                if let programDuration = component.programDuration {
                    if programDuration < 12 {
                        subtitleString = environment.strings.AffiliateProgram_JoinSubtitleMonths(Int32(programDuration)).replacingOccurrences(of: "{bot}", with: component.sourcePeer.compactDisplayTitle).replacingOccurrences(of: "{commission}", with: commissionTitle)
                    } else {
                        subtitleString = environment.strings.AffiliateProgram_JoinSubtitleYears(Int32(programDuration / 12)).replacingOccurrences(of: "{bot}", with: component.sourcePeer.compactDisplayTitle).replacingOccurrences(of: "{commission}", with: commissionTitle)
                    }
                } else {
                    subtitleString = environment.strings.AffiliateProgram_JoinSubtitleLifetime.replacingOccurrences(of: "{bot}", with: component.sourcePeer.compactDisplayTitle).replacingOccurrences(of: "{commission}", with: commissionTitle)
                }
                
                if component.revenuePerUser != 0.0 {
                    var revenueString = String(format: "%.1f", component.revenuePerUser)
                    if revenueString.hasSuffix(".0") {
                        revenueString = String(revenueString[revenueString.startIndex ..< revenueString.index(revenueString.endIndex, offsetBy: -2)])
                    }
                    dailyRevenueString = environment.strings.AffiliateProgram_DailyRevenueText(revenueString).string
                }
                
                termsString = environment.strings.AffiliateProgram_JoinTerms
            case let .active(active):
                titleString = environment.strings.AffiliateProgram_LinkTitle
                if let programDuration = component.programDuration {
                    if programDuration < 12 {
                        subtitleString = environment.strings.AffiliateProgram_LinkSubtitleMonths(Int32(programDuration)).replacingOccurrences(of: "{bot}", with: component.sourcePeer.compactDisplayTitle).replacingOccurrences(of: "{commission}", with: commissionTitle)
                    } else {
                        subtitleString = environment.strings.AffiliateProgram_LinkSubtitleYears(Int32(programDuration / 12)).replacingOccurrences(of: "{bot}", with: component.sourcePeer.compactDisplayTitle).replacingOccurrences(of: "{commission}", with: commissionTitle)
                    }
                } else {
                    subtitleString = environment.strings.AffiliateProgram_LinkSubtitleLifetime.replacingOccurrences(of: "{bot}", with: component.sourcePeer.compactDisplayTitle).replacingOccurrences(of: "{commission}", with: commissionTitle)
                }
                
                termsString = environment.strings.AffiliateProgram_UserCountFooter(Int32(active.bot.participants)).replacingOccurrences(of: "{bot}", with: component.sourcePeer.compactDisplayTitle)
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.bold(24.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = title.view {
                if titleView.superview == nil {
                    self.titleTransformContainer.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setPosition(view: self.titleTransformContainer, position: titleFrame.center)
            }
            contentHeight += titleSize.height + 14.0
            
            let navigationBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 54.0))
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationBackgroundFrame)
            self.navigationBackgroundView.update(size: navigationBackgroundFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.navigationBarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            var openBotComponents: [AnyComponentWithIdentity<Empty>] = []
            var openBotLeftInset: CGFloat = 12.0
            if case .active = component.mode {
                openBotLeftInset = 1.0
                openBotComponents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(TransformContents(
                    content: AnyComponent(AvatarComponent(
                    context: component.context,
                    peer: component.sourcePeer,
                    size: CGSize(width: 30.0, height: 30.0)
                    )), fixedSize: CGSize(width: 30.0, height: 2.0),
                    translation: CGPoint(x: 0.0, y: 1.0)))))
            }
            openBotComponents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: environment.strings.AffiliateProgram_OpenBot(component.sourcePeer.compactDisplayTitle).string, font: Font.medium(15.0), textColor: environment.theme.list.itemInputField.primaryColor))
            ))))
            openBotComponents.append(AnyComponentWithIdentity(id: 2, component: AnyComponent(TransformContents(
                content: AnyComponent(BundleIconComponent(
                    name: "Item List/DisclosureArrow",
                    tintColor: environment.theme.list.itemInputField.primaryColor.withMultipliedAlpha(0.5),
                    scaleFactor: 0.8
                )),
                fixedSize: CGSize(width: 8.0, height: 2.0),
                translation: CGPoint(x: 0.0, y: 2.0)
            ))))
            let openBotButtonSize = self.openBotButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack(openBotComponents, spacing: 2.0)),
                    background: AnyComponent(FilledRoundedRectangleComponent(color: environment.theme.list.itemInputField.backgroundColor, cornerRadius: .minEdge, smoothCorners: false)),
                    effectAlignment: .center,
                    minSize: CGSize(width: 1.0, height: 30.0 + 2.0),
                    contentInsets: UIEdgeInsets(top: 0.0, left: openBotLeftInset, bottom: 0.0, right: 12.0),
                    action: { [weak self] in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        guard let controller = environment.controller(), let navigationController = controller.navigationController as? NavigationController else {
                            return
                        }
                        guard let infoController = component.context.sharedContext.makePeerInfoController(
                            context: component.context,
                            updatedPresentationData: nil,
                            peer: component.sourcePeer._asPeer(),
                            mode: .generic,
                            avatarInitiallyExpanded: false,
                            fromChat: false,
                            requestsContext: nil
                        ) else {
                            return
                        }
                        controller.dismiss(completion: { [weak navigationController] in
                            DispatchQueue.main.async {
                                guard let navigationController else {
                                    return
                                }
                                navigationController.pushViewController(infoController)
                            }
                        })
                    },
                    animateAlpha: true,
                    animateScale: true,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let openBotButtonFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - openBotButtonSize.width) * 0.5), y: contentHeight), size: openBotButtonSize)
            if let openBotButtonView = self.openBotButton.view {
                if openBotButtonView.superview == nil {
                    self.scrollContentView.addSubview(openBotButtonView)
                }
                transition.setPosition(view: openBotButtonView, position: openBotButtonFrame.center)
                openBotButtonView.bounds = CGRect(origin: CGPoint(), size: openBotButtonFrame.size)
            }
            contentHeight += openBotButtonSize.height
            contentHeight += 20.0
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: subtitleString,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.scrollContentView.addSubview(subtitleView)
                }
                transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
            }
            contentHeight += subtitleSize.height
            
            if let dailyRevenueString {
                let dailyRevenueText: ComponentView<Empty>
                if let current = self.dailyRevenueText {
                    dailyRevenueText = current
                } else {
                    dailyRevenueText = ComponentView()
                    self.dailyRevenueText = dailyRevenueText
                }
                
                var inlineTextStarImage: UIImage?
                if let current = self.inlineTextStarImage {
                    inlineTextStarImage = current
                } else {
                    if let image = UIImage(bundleImageName: "Premium/Stars/StarSmall") {
                        let starInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                        inlineTextStarImage = generateImage(CGSize(width: starInsets.left + image.size.width + starInsets.right, height: image.size.height), rotatedContext: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            UIGraphicsPushContext(context)
                            defer {
                                UIGraphicsPopContext()
                            }
                            
                            image.draw(at: CGPoint(x: starInsets.left, y: starInsets.top))
                        })?.withRenderingMode(.alwaysOriginal)
                        self.inlineTextStarImage = inlineTextStarImage
                    }
                }
                
                let attributedDailyRevenueString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(dailyRevenueString, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                ), textAlignment: .center))
                if let range = attributedDailyRevenueString.string.range(of: "#"), let starImage = inlineTextStarImage {
                    final class RunDelegateData {
                        let ascent: CGFloat
                        let descent: CGFloat
                        let width: CGFloat
                        
                        init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
                            self.ascent = ascent
                            self.descent = descent
                            self.width = width
                        }
                    }
                    
                    let runDelegateData = RunDelegateData(
                        ascent: Font.regular(15.0).ascender,
                        descent: Font.regular(15.0).descender,
                        width: starImage.size.width + 2.0
                    )
                    var callbacks = CTRunDelegateCallbacks(
                        version: kCTRunDelegateCurrentVersion,
                        dealloc: { dataRef in
                            Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                        },
                        getAscent: { dataRef in
                            let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                            return data.takeUnretainedValue().ascent
                        },
                        getDescent: { dataRef in
                            let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                            return data.takeUnretainedValue().descent
                        },
                        getWidth: { dataRef in
                            let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                            return data.takeUnretainedValue().width
                        }
                    )
                    if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
                        attributedDailyRevenueString.addAttribute(NSAttributedString.Key(kCTRunDelegateAttributeName as String), value: runDelegate, range: NSRange(range, in: attributedDailyRevenueString.string))
                    }
                    attributedDailyRevenueString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: attributedDailyRevenueString.string))
                    attributedDailyRevenueString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff), range: NSRange(range, in: attributedDailyRevenueString.string))
                    attributedDailyRevenueString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: attributedDailyRevenueString.string))
                }
                
                let dailyRevenueTextSize = dailyRevenueText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(attributedDailyRevenueString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                contentHeight += 16.0
                let dailyRevenueTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - dailyRevenueTextSize.width) * 0.5), y: contentHeight), size: dailyRevenueTextSize)
                if let dailyRevenueTextView = dailyRevenueText.view {
                    if dailyRevenueTextView.superview == nil {
                        self.scrollContentView.addSubview(dailyRevenueTextView)
                    }
                    transition.setPosition(view: dailyRevenueTextView, position: dailyRevenueTextFrame.center)
                    dailyRevenueTextView.bounds = CGRect(origin: CGPoint(), size: dailyRevenueTextFrame.size)
                }
                contentHeight += dailyRevenueTextSize.height
            } else if let dailyRevenueText = self.dailyRevenueText {
                self.dailyRevenueText = nil
                dailyRevenueText.view?.removeFromSuperview()
            }
            
            contentHeight += 23.0
            
            var displayTargetPeer = false
            var isTargetPeerSelectable = false
            switch currentMode {
            case let .join(join):
                displayTargetPeer = join.canSelectTargetPeer
                isTargetPeerSelectable = join.canSelectTargetPeer
            case .active:
                displayTargetPeer = true
                isTargetPeerSelectable = true
            }
            
            if displayTargetPeer {
                let targetTextSize = self.targetText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.AffiliateProgram_CommistionDestinationText, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let targetTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - targetTextSize.width) * 0.5), y: contentHeight), size: targetTextSize)
                if let targetTextView = self.targetText.view {
                    if targetTextView.superview == nil {
                        self.scrollContentView.addSubview(targetTextView)
                    }
                    transition.setPosition(view: targetTextView, position: targetTextFrame.center)
                    targetTextView.bounds = CGRect(origin: CGPoint(), size: targetTextFrame.size)
                }
                contentHeight += targetTextSize.height + 12.0
                
                if let currentTargetPeer = self.currentTargetPeer {
                    let targetPeerSize = self.targetPeer.update(
                        transition: transition,
                        component: AnyComponent(PeerBadgeComponent(
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            peer: currentTargetPeer,
                            action: isTargetPeerSelectable ? { [weak self] sourceView in
                                guard let self else {
                                    return
                                }
                                self.displayTargetSelectionMenu(sourceView: sourceView)
                            } : nil
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                    )
                    let targetPeerFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - targetPeerSize.width) * 0.5), y: contentHeight), size: targetPeerSize)
                    if let targetPeerView = self.targetPeer.view {
                        if targetPeerView.superview == nil {
                            self.scrollContentView.addSubview(targetPeerView)
                        }
                        transition.setFrame(view: targetPeerView, frame: targetPeerFrame)
                    }
                    contentHeight += targetPeerSize.height
                    contentHeight += 20.0
                }
            }
            contentHeight += 12.0
            
            if case let .active(active) = currentMode {
                var cleanLink = active.bot.url
                let removePrefixes: [String] = ["http://", "https://"]
                for prefix in removePrefixes {
                    if cleanLink.hasPrefix(prefix) {
                        cleanLink = String(cleanLink[cleanLink.index(cleanLink.startIndex, offsetBy: prefix.count)...])
                    }
                }
                let linkTextSize = self.linkText.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: cleanLink, font: Font.regular(17.0), textColor: environment.theme.list.itemInputField.primaryColor)),
                            truncationType: .middle
                        )),
                        background: AnyComponent(FilledRoundedRectangleComponent(
                            color: environment.theme.list.itemInputField.backgroundColor,
                            cornerRadius: .value(8.0),
                            smoothCorners: true
                        )),
                        effectAlignment: .center,
                        minSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0),
                        contentInsets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 10.0),
                        action: { [weak self] in
                            guard let self, case let .active(active) = self.currentMode else {
                                return
                            }
                            self.environment?.controller()?.dismiss()
                            active.copyLink(active.bot)
                        },
                        animateAlpha: true,
                        animateScale: false,
                        animateContents: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
                )
                let linkTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - linkTextSize.width) * 0.5), y: contentHeight), size: linkTextSize)
                if let linkTextView = self.linkText.view {
                    if linkTextView.superview == nil {
                        self.scrollContentView.addSubview(linkTextView)
                    }
                    transition.setFrame(view: linkTextView, frame: linkTextFrame)
                    transition.setAlpha(view: linkTextView, alpha: self.isChangingTargetPeer ? 0.6 : 1.0)
                }
                contentHeight += linkTextSize.height
                contentHeight += 24.0
            }
            
            let actionButtonTitle: String
            switch currentMode {
            case .join:
                actionButtonTitle = environment.strings.AffiliateProgram_ActionJoin
            case .active:
                actionButtonTitle = environment.strings.AffiliateProgram_ActionCopyLink
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
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: actionButtonTitle,
                            badge: 0,
                            textColor: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: environment.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let currentMode = self.currentMode else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                        
                        switch currentMode {
                        case let .join(join):
                            if let currentTargetPeer = self.currentTargetPeer {
                                join.completion(currentTargetPeer)
                            }
                        case let .active(active):
                            active.copyLink(active.bot)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            
            let bottomTextSize = self.bottomText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: termsString,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            
            let bottomTextSpacing: CGFloat = 10.0
            let bottomPanelHeight = 10.0 + environment.safeInsets.bottom + actionButtonSize.height + bottomTextSpacing + bottomTextSize.height
            
            let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight), size: CGSize(width: availableSize.width, height: bottomPanelHeight))
            transition.setFrame(view: self.bottomPanelContainer, frame: bottomPanelFrame)
            
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.bottomPanelContainer.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            let bottomTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - bottomTextSize.width) * 0.5), y: actionButtonFrame.maxY + bottomTextSpacing), size: bottomTextSize)
            if let bottomTextView = self.bottomText.view {
                if bottomTextView.superview == nil {
                    self.bottomPanelContainer.addSubview(bottomTextView)
                }
                transition.setPosition(view: bottomTextView, position: bottomTextFrame.center)
                bottomTextView.bounds = CGRect(origin: CGPoint(), size: bottomTextFrame.size)
            }
            
            contentHeight += bottomPanelHeight
            
            clippingY = bottomPanelFrame.minY - 8.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - contentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            //self.scrollContentClippingView.layer.cornerRadius = 10.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            if case .active = currentMode {
                let toast: ComponentView<Empty>
                if let current = self.toast {
                    toast = current
                } else {
                    toast = ComponentView()
                    self.toast = toast
                }
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let toastSize = toast.update(
                    transition: transition,
                    component: AnyComponent(ToastContentComponent(
                        icon: AnyComponent(AvatarComponent(
                            context: component.context,
                            peer: component.sourcePeer,
                            size: CGSize(width: 30.0, height: 30.0)
                        )),
                        content: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                text: .markdown(text: environment.strings.AffiliateProgram_ToastJoined_Title, attributes: MarkdownAttributes(body: bold, bold: bold, link: body, linkAttribute: { _ in nil })),
                                maximumNumberOfLines: 0
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                text: .markdown(text: environment.strings.AffiliateProgram_ToastJoined_Text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                                maximumNumberOfLines: 0
                            )))
                        ], alignment: .left, spacing: 6.0)),
                        insets: UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 10.0),
                        iconSpacing: 12.0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 12.0 * 2.0, height: 1000.0)
                )
                let toastFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 12.0, y: 0.0), size: toastSize)
                if let toastView = toast.view {
                    if toastView.superview == nil {
                        self.addSubview(toastView)
                    }
                    transition.setPosition(view: toastView, position: toastFrame.center)
                    transition.setBounds(view: toastView, bounds: CGRect(origin: CGPoint(), size: toastFrame.size))
                }
            }
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset), size: CGSize(width: availableSize.width - sideInset * 2.0, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            } else {
                if !previousBounds.isEmpty, !transition.animation.isImmediate {
                    let bounds = self.scrollView.bounds
                    if bounds.maxY != previousBounds.maxY {
                        let offsetY = previousBounds.maxY - bounds.maxY
                        transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                    }
                }
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
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

public class JoinAffiliateProgramScreen: ViewControllerComponentContainer {
    public typealias Mode = JoinAffiliateProgramScreenMode
    
    private let context: AccountContext
    
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        sourcePeer: EnginePeer,
        commissionPermille: Int32,
        programDuration: Int32?,
        revenuePerUser: Double,
        mode: Mode
    ) {
        self.context = context
        
        super.init(context: context, component: JoinAffiliateProgramScreenComponent(
            context: context,
            sourcePeer: sourcePeer,
            commissionPermille: commissionPermille,
            programDuration: programDuration,
            revenuePerUser: revenuePerUser,
            mode: mode
        ), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? JoinAffiliateProgramScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? JoinAffiliateProgramScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private final class PeerBadgeComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer
    let action: ((UIView) -> Void)?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        action: ((UIView) -> Void)?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.action = action
    }
    
    static func ==(lhs: PeerBadgeComponent, rhs: PeerBadgeComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    final class View: HighlightableButton {
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private var avatarNode: AvatarNode?
        private var selectorIcon: ComponentView<Empty>?
        
        private var component: PeerBadgeComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action?(self)
        }
        
        func update(component: PeerBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.isEnabled = component.action != nil
            
            let height: CGFloat = 32.0
            let avatarPadding: CGFloat = 1.0
            
            let avatarDiameter = height - avatarPadding * 2.0
            let avatarTextSpacing: CGFloat = 4.0
            let rightTextInset: CGFloat = component.action != nil ? 26.0 : 12.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.displayTitle(strings: component.strings, displayOrder: .firstLast), font: Font.medium(15.0), textColor: component.action != nil ? component.theme.list.itemInputField.primaryColor : component.theme.list.itemInputField.primaryColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarPadding - avatarDiameter - avatarTextSpacing - rightTextInset, height: height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: avatarPadding + avatarDiameter + avatarTextSpacing, y: floorToScreenPixels((height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(avatarDiameter * 0.5)))
                avatarNode.isUserInteractionEnabled = false
                avatarNode.displaysAsynchronously = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarPadding, y: avatarPadding), size: CGSize(width: avatarDiameter, height: avatarDiameter))
            avatarNode.frame = avatarFrame
            avatarNode.updateSize(size: avatarFrame.size)
            avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer)
            
            let size = CGSize(width: avatarPadding + avatarDiameter + avatarTextSpacing + titleSize.width + rightTextInset, height: height)
            
            if component.action != nil {
                let selectorIcon: ComponentView<Empty>
                if let current = self.selectorIcon {
                    selectorIcon = current
                } else {
                    selectorIcon = ComponentView()
                    self.selectorIcon = selectorIcon
                }
                let selectorIconSize = selectorIcon.update(
                    transition: transition,
                    component: AnyComponent(BundleIconComponent(
                        name: "Item List/ContextDisclosureArrow", tintColor: component.theme.list.itemAccentColor)),
                    environment: {},
                    containerSize: CGSize(width: 10.0, height: 10.0)
                )
                let selectorIconFrame = CGRect(origin: CGPoint(x: size.width - 8.0 - selectorIconSize.width, y: floorToScreenPixels((size.height - selectorIconSize.height) * 0.5)), size: selectorIconSize)
                if let selectorIconView = selectorIcon.view {
                    if selectorIconView.superview == nil {
                        selectorIconView.isUserInteractionEnabled = false
                        self.addSubview(selectorIconView)
                    }
                    transition.setFrame(view: selectorIconView, frame: selectorIconFrame)
                }
            } else if let selectorIcon = self.selectorIcon {
                self.selectorIcon = nil
                selectorIcon.view?.removeFromSuperview()
            }
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.action != nil ? component.theme.list.itemAccentColor.withMultipliedAlpha(0.1) : component.theme.list.itemInputField.backgroundColor,
                    cornerRadius: .minEdge,
                    smoothCorners: false
                )),
                environment: {},
                containerSize: size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    backgroundView.isUserInteractionEnabled = false
                    self.insertSubview(backgroundView, at: 0)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class AvatarComponent: Component {
    let context: AccountContext
    let peer: EnginePeer
    let size: CGSize?

    init(context: AccountContext, peer: EnginePeer, size: CGSize? = nil) {
        self.context = context
        self.peer = peer
        self.size = size
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    final class View: UIView {
        private var avatarNode: AvatarNode?
        
        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = component.size ?? availableSize

            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(size.width * 0.5)))
                avatarNode.displaysAsynchronously = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            avatarNode.frame = CGRect(origin: CGPoint(), size: size)
            avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true,
                displayDimensions: size
            )
            avatarNode.updateSize(size: size)
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

private final class BorderedBadgeComponent: Component {
    let backgroundColor: UIColor
    let cutoutColor: UIColor
    let content: AnyComponent<Empty>
    let insets: UIEdgeInsets
    let aspect: CGFloat?
    let cutoutWidth: CGFloat

    init(
        backgroundColor: UIColor,
        cutoutColor: UIColor,
        content: AnyComponent<Empty>,
        insets: UIEdgeInsets,
        aspect: CGFloat? = nil,
        cutoutWidth: CGFloat
    ) {
        self.backgroundColor = backgroundColor
        self.cutoutColor = cutoutColor
        self.content = content
        self.insets = insets
        self.aspect = aspect
        self.cutoutWidth = cutoutWidth
    }

    static func ==(lhs: BorderedBadgeComponent, rhs: BorderedBadgeComponent) -> Bool {
        if lhs.backgroundColor !== rhs.backgroundColor {
            return false
        }
        if lhs.cutoutColor != rhs.cutoutColor {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.aspect != rhs.aspect {
            return false
        }
        if lhs.cutoutWidth != rhs.cutoutWidth {
            return false
        }
        return true
    }

    final class View: UIView {
        private let cutoutBackground = ComponentView<Empty>()
        private let background = ComponentView<Empty>()
        private let content = ComponentView<Empty>()
        
        private var component: BorderedBadgeComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BorderedBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let contentSize = self.content.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: CGSize(width: availableSize.width - component.insets.left - component.insets.right, height: availableSize.height - component.insets.top - component.insets.bottom)
            )
            var size = CGSize(width: contentSize.width + component.insets.left + component.insets.right, height: contentSize.height + component.insets.top + component.insets.bottom)
            if let aspect = component.aspect {
                size.width = size.height * aspect
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            let cutoutBackgroundFrame = backgroundFrame.insetBy(dx: -component.cutoutWidth, dy: -component.cutoutWidth)
            
            let _ = self.cutoutBackground.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.cutoutColor,
                    cornerRadius: .minEdge,
                    smoothCorners: false
                )),
                environment: {}, containerSize: cutoutBackgroundFrame.size
            )
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.backgroundColor,
                    cornerRadius: .minEdge,
                    smoothCorners: false
                )),
                environment: {}, containerSize: backgroundFrame.size
            )
            
            if let cutoutBackgroundView = self.cutoutBackground.view {
                if cutoutBackgroundView.superview == nil {
                    self.addSubview(cutoutBackgroundView)
                }
                transition.setFrame(view: cutoutBackgroundView, frame: cutoutBackgroundFrame)
            }
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + component.insets.left, y: backgroundFrame.minY + component.insets.top), size: contentSize)
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: contentFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class AffiliatePeerSubtitleComponent: Component {
    let theme: PresentationTheme
    let percentText: String
    let text: String

    init(
        theme: PresentationTheme,
        percentText: String,
        text: String
    ) {
        self.theme = theme
        self.percentText = percentText
        self.text = text
    }

    static func ==(lhs: AffiliatePeerSubtitleComponent, rhs: AffiliatePeerSubtitleComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.percentText != rhs.percentText {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }

    final class View: UIView {
        private let badgeBackground = ComponentView<Empty>()
        private let badgeText = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        
        private var component: AffiliatePeerSubtitleComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AffiliatePeerSubtitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let badgeSpacing: CGFloat = 5.0
            let badgeInsets = UIEdgeInsets(top: 2.0, left: 4.0, bottom: 2.0, right: 4.0)
            
            let badgeTextSize = self.badgeText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.percentText, font: Font.regular(13.0), textColor: component.theme.list.itemCheckColors.foregroundColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let badgeSize = CGSize(width: badgeTextSize.width + badgeInsets.left + badgeInsets.right, height: badgeTextSize.height + badgeInsets.top + badgeInsets.bottom)
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let size = CGSize(width: badgeSize.width + badgeSpacing + textSize.width, height: textSize.height)
            
            let badgeFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - badgeSize.height) * 0.5)), size: badgeSize)
            let _ = self.badgeBackground.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.theme.list.itemCheckColors.fillColor,
                    cornerRadius: .value(5.0),
                    smoothCorners: true
                )),
                environment: {},
                containerSize: badgeFrame.size
            )
            if let badgeBackgroundView = self.badgeBackground.view {
                if badgeBackgroundView.superview == nil {
                    self.addSubview(badgeBackgroundView)
                }
                transition.setFrame(view: badgeBackgroundView, frame: badgeFrame)
            }
            
            let badgeTextFrame = CGRect(origin: CGPoint(x: badgeFrame.minX + badgeInsets.left, y: badgeFrame.minY + badgeInsets.top), size: badgeTextSize)
            if let badgeTextView = self.badgeText.view {
                if badgeTextView.superview == nil {
                    self.addSubview(badgeTextView)
                }
                transition.setPosition(view: badgeTextView, position: badgeTextFrame.center)
                badgeTextView.bounds = CGRect(origin: CGPoint(), size: badgeTextFrame.size)
            }
            
            let textFrame = CGRect(origin: CGPoint(x: badgeSize.width + badgeSpacing, y: 0.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class BotSectionSortButtonComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sortMode: EngineSuggestedStarRefBotsContext.SortMode
    let action: (UIView) -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        sortMode: EngineSuggestedStarRefBotsContext.SortMode,
        action: @escaping (UIView) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.sortMode = sortMode
        self.action = action
    }

    static func ==(lhs: BotSectionSortButtonComponent, rhs: BotSectionSortButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.sortMode != rhs.sortMode {
            return false
        }
        return true
    }

    final class View: HighlightableButton {
        private let text = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        
        private var component: BotSectionSortButtonComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(self)
        }
        
        func update(component: BotSectionSortButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let sortByString: String
            switch component.sortMode {
            case .date:
                sortByString = component.strings.AffiliateSetup_SortSectionHeader_Date
            case .profitability:
                sortByString = component.strings.AffiliateSetup_SortSectionHeader_Profitability
            case .revenue:
                sortByString = component.strings.AffiliateSetup_SortSectionHeader_Revenue
            }
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: sortByString, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.freeTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: component.theme.list.freeTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.itemAccentColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }
                    ))
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Item List/ContextDisclosureArrow",
                    tintColor: component.theme.list.itemAccentColor,
                    scaleFactor: 0.7
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let spacing: CGFloat = 2.0
            
            let size = CGSize(width: textSize.width + spacing + iconSize.width, height: textSize.height)
            
            let textFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.isUserInteractionEnabled = false
                    self.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.center)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            let iconFrame = CGRect(origin: CGPoint(x: textFrame.maxX + spacing, y: floorToScreenPixels((size.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class PeerBadgeAvatarComponent: Component {
    final class SynchronousLoadHint {
    }
    
    let context: AccountContext
    let peer: EnginePeer
    let theme: PresentationTheme
    let hasBadge: Bool

    init(context: AccountContext, peer: EnginePeer, theme: PresentationTheme, hasBadge: Bool) {
        self.context = context
        self.peer = peer
        self.theme = theme
        self.hasBadge = hasBadge
    }

    static func ==(lhs: PeerBadgeAvatarComponent, rhs: PeerBadgeAvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.hasBadge != rhs.hasBadge {
            return false
        }
        return true
    }

    final class View: UIView {
        private var avatarNode: AvatarNode?
        
        private let badgeBackground = UIImageView()
        private let badgeIcon = UIImageView()
        
        private var component: PeerBadgeAvatarComponent?
        private weak var state: EmptyComponentState?
        
        private static let badgeBackgroundImage = generateFilledCircleImage(diameter: 18.0, color: .white)?.withRenderingMode(.alwaysTemplate)
        private static let badgeIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Link"), color: .white)?.withRenderingMode(.alwaysTemplate)
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerBadgeAvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            var synchronousLoad = false
            if transition.userData(SynchronousLoadHint.self) != nil {
                synchronousLoad = true
            }
            
            let size = CGSize(width: 40.0, height: 40.0)
            let badgeSize: CGFloat = 18.0

            let badgeFrame = CGRect(origin: CGPoint(x: size.width - badgeSize, y: size.height - badgeSize), size: CGSize(width: badgeSize, height: badgeSize))
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(size.width * 0.5)))
                avatarNode.displaysAsynchronously = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            avatarNode.frame = CGRect(origin: CGPoint(), size: size)
            avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: synchronousLoad,
                displayDimensions: size,
                cutoutRect: component.hasBadge ? badgeFrame.insetBy(dx: -(1.0 + UIScreenPixel), dy: -(1.0 + UIScreenPixel)) : nil
            )
            
            if self.badgeBackground.image == nil {
                self.badgeBackground.image = View.badgeBackgroundImage
            }
            if self.badgeBackground.superview == nil {
                self.addSubview(self.badgeBackground)
            }
            if self.badgeIcon.image == nil {
                self.badgeIcon.image = View.badgeIconImage
            }
            if self.badgeIcon.superview == nil {
                self.addSubview(self.badgeIcon)
            }
            
            self.badgeBackground.tintColor = component.theme.list.itemCheckColors.fillColor
            self.badgeIcon.tintColor = component.theme.list.itemCheckColors.foregroundColor
            
            transition.setFrame(view: self.badgeBackground, frame: badgeFrame)
            
            if let badgeIconSize = self.badgeIcon.image?.size {
                let badgeIconFactor: CGFloat = 0.45
                let badgeIconSize = CGSize(width: badgeIconSize.width * badgeIconFactor, height: badgeIconSize.height * badgeIconFactor)
                let badgeIconFrame = CGRect(origin: CGPoint(x: badgeFrame.minX + floorToScreenPixels((badgeSize - badgeIconSize.width) * 0.5), y: badgeFrame.minY + floorToScreenPixels((badgeSize - badgeIconSize.height) * 0.5)), size: badgeIconSize)
                transition.setFrame(view: self.badgeIcon, frame: badgeIconFrame)
            }
            
            self.badgeBackground.isHidden = !component.hasBadge
            self.badgeIcon.isHidden = !component.hasBadge
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
