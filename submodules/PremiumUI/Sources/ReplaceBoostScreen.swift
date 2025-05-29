import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import UndoUI
import Markdown
import TextFormat
import ButtonComponent
import PeerListItemComponent
import TelegramStringFormatting
import AvatarNode

private final class ReplaceBoostScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let myBoostStatus: MyBoostStatus
    let initiallySelectedSlot: Int32?
    let selectedSlotsUpdated: ([Int32]) -> Void
    let presentController: (ViewController) -> Void
    let giftPremium: () -> Void
    
    init(context: AccountContext, peerId: EnginePeer.Id, myBoostStatus: MyBoostStatus, initiallySelectedSlot: Int32?, selectedSlotsUpdated: @escaping ([Int32]) -> Void, presentController: @escaping (ViewController) -> Void, giftPremium: @escaping () -> Void) {
        self.context = context
        self.peerId = peerId
        self.myBoostStatus = myBoostStatus
        self.initiallySelectedSlot = initiallySelectedSlot
        self.selectedSlotsUpdated = selectedSlotsUpdated
        self.presentController = presentController
        self.giftPremium = giftPremium
    }
    
    static func ==(lhs: ReplaceBoostScreenComponent, rhs: ReplaceBoostScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.myBoostStatus != rhs.myBoostStatus {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let disposable = MetaDisposable()
        private var timer: SwiftSignalKit.Timer?
        
        var peer: EnginePeer?
        var selectedSlots: [Int32] = []
        var currentTime: Int32
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        
        init(context: AccountContext, peerId: EnginePeer.Id, initiallySelectedSlot: Int32?) {
            self.context = context
            
            self.currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            super.init()
            
            if let initiallySelectedSlot {
                self.selectedSlots.append(initiallySelectedSlot)
            }
            
            self.disposable.set((context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self else {
                    return
                }
                self.peer = peer
                self.updated()
            }))
            
            self.timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                if let self {
                    self.currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    self.updated()
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
        
        deinit {
            self.disposable.dispose()
            self.timer?.invalidate()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId, initiallySelectedSlot: self.initiallySelectedSlot)
    }
    
    static var body: Body {
        let header = Child(ReplaceBoostHeaderComponent.self)
        let description = Child(MultilineTextComponent.self)
        let boostsBackground = Child(RoundedRectangle.self)
        let boosts = Child(List<Empty>.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            let availableSize = context.availableSize
            let theme = environment.theme
            let strings = environment.strings
            
            let textSideInset: CGFloat = 32.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var boostItems: [AnyComponentWithIdentity<Empty>] = []
            let myBoosts = context.component.myBoostStatus.boosts
            
            let occupiedBoosts = myBoosts.filter { $0.peer?.id != context.component.peerId && $0.peer != nil }.sorted { lhs, rhs in
                return lhs.date < rhs.date
            }
            
            var otherPeers: [EnginePeer] = []
            for slot in state.selectedSlots {
                if let peer = occupiedBoosts.first(where: { $0.slot == slot })?.peer {
                    if !otherPeers.contains(where: { $0.id == peer.id }) {
                        otherPeers.append(peer)
                    }
                }
            }
            if let mainPeer = state.peer {
                let header = header.update(
                    component: ReplaceBoostHeaderComponent(
                        context: context.component.context,
                        theme: environment.theme,
                        mainPeer: mainPeer,
                        otherPeers: otherPeers.reversed()
                    ),
                    availableSize: availableSize,
                    transition: context.transition
                )
                context.add(header
                    .position(CGPoint(x: availableSize.width / 2.0, y: 93.0))
                )
            }
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
           
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.component.context.currentAppConfiguration.with({ $0 }))
            
            var channelName = state.peer?.compactDisplayTitle ?? ""
            if channelName.count > 48 {
                channelName = "\(channelName.prefix(48))..."
            }
            let descriptionString = strings.ReassignBoost_DescriptionWithLink(channelName, "\(premiumConfiguration.boostsPerGiftCount)").string
            
            let giftPremium = context.component.giftPremium
            let description = description.update(
                component: MultilineTextComponent(
                    text: .markdown(text: descriptionString, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1,
                    highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        giftPremium()
                    }
                ),
                environment: {},
                availableSize: CGSize(width: availableSize.width - sideInset * 2.0 - textSideInset, height: availableSize.height),
                transition: .immediate
            )
            context.add(description
                .position(CGPoint(x: availableSize.width / 2.0, y: 172.0))
            )
            
            let hasSelection = occupiedBoosts.count > 1
            
            let selectedSlotsUpdated = context.component.selectedSlotsUpdated
            let presentController = context.component.presentController
            for i in 0 ..< occupiedBoosts.count {
                let boost = occupiedBoosts[i]
                guard let peer = boost.peer else {
                    continue
                }
                
                var isEnabled = true
                let subtitle: String
                if let cooldownUntil = boost.cooldownUntil, cooldownUntil > state.currentTime {
                    let duration = cooldownUntil - state.currentTime
                    let durationValue = stringForDuration(duration, position: nil)
                    subtitle = strings.ReassignBoost_AvailableIn(durationValue).string
                    isEnabled = false
                } else {
                    let expiresValue = stringForDate(timestamp: boost.expires, strings: strings)
                    subtitle = strings.ReassignBoost_ExpiresOn(expiresValue).string
                }
                
                let accountContext = context.component.context
                boostItems.append(
                    AnyComponentWithIdentity(
                        id: AnyHashable(boost.slot),
                        component: AnyComponent(
                            PeerListItemComponent(
                                context: context.component.context,
                                theme: theme,
                                strings: strings,
                                style: .generic,
                                sideInset: 0.0,
                                title: peer.compactDisplayTitle,
                                peer: peer,
                                subtitle: PeerListItemComponent.Subtitle(text: subtitle, color: .neutral),
                                subtitleAccessory: .none,
                                presence: nil,
                                selectionState: hasSelection ? .editing(isSelected: state.selectedSlots.contains(boost.slot), isTinted: false) : .none,
                                selectionPosition: .right,
                                isEnabled: isEnabled,
                                hasNext: i != occupiedBoosts.count - 1,
                                action: { [weak state] _, _, _ in
                                    guard let state, hasSelection else {
                                        return
                                    }
                                    if isEnabled {
                                        if state.selectedSlots.contains(boost.slot) {
                                            state.selectedSlots.removeAll(where: { $0 == boost.slot })
                                        } else {
                                            state.selectedSlots.append(boost.slot)
                                        }
                                        state.updated(transition: .easeInOut(duration: 0.2))
                                        selectedSlotsUpdated(state.selectedSlots)
                                    } else {
                                        let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
         
                                        let undoController = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: strings.ReassignBoost_WaitForCooldown("\(premiumConfiguration.boostsPerGiftCount)").string, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .top, action: { _ in return true })
                                        presentController(undoController)
                                    }
                                })
                        )
                    )
                )
            }
            
            let boosts = boosts.update(
                component: List(boostItems),
                environment: {},
                availableSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0),
                transition: context.transition
            )
            
            let boostsBackground = boostsBackground.update(
                component: RoundedRectangle(color: theme.list.itemBlocksBackgroundColor, cornerRadius: 10.0),
                environment: {},
                availableSize: CGSize(width: availableSize.width - sideInset * 2.0, height: boosts.size.height),
                transition: context.transition
            )
            
            context.add(boostsBackground
                .position(CGPoint(x: availableSize.width / 2.0, y: 226 + boosts.size.height / 2.0))
            )
            context.add(boosts
                .position(CGPoint(x: availableSize.width / 2.0, y: 226 + boosts.size.height / 2.0))
            )
            
            return CGSize(width: availableSize.width, height: 226.0 + boosts.size.height + environment.safeInsets.bottom + 91.0)
        }
    }
}

public class ReplaceBoostScreen: ViewController {
    final class Node: ViewControllerTracingNode, ASScrollViewDelegate, ASGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: ReplaceBoostScreen?
        
        private let component: AnyComponent<ViewControllerComponentContainer.Environment>
        
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        let scrollView: UIScrollView
        let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        private let footerView: FooterView
        private var footerHeight: CGFloat = 0.0
        private var bottomOffset: CGFloat = 1000.0
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        var selectedSlots: [Int32] = [] {
            didSet {
                self.controller?.requestLayout(transition: .immediate)
            }
        }
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
                
        init(context: AccountContext, controller: ReplaceBoostScreen, component: AnyComponent<ViewControllerComponentContainer.Environment>) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            
            let effectiveTheme = self.presentationData.theme
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.scrollView = UIScrollView()
            self.hostView = ComponentHostView()
            
            self.footerView = FooterView()
            
            super.init()
            
            self.scrollView.delegate = self.wrappedScrollViewDelegate
            self.scrollView.showsVerticalScrollIndicator = false
            
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = effectiveTheme.list.blocksBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.scrollView)
            self.scrollView.addSubview(self.hostView)
            
            self.wrappingView.addSubview(self.footerView)
            
            self.footerView.action = { [weak self] in
                guard let self else {
                    return
                }
                self.controller?.replaceBoosts?(self.selectedSlots)
            }
            self.footerView.updateBackgroundAlpha(1.0, transition: .immediate)
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, !self.footerView.inProgress {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let (layout, _) = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        private func updateFooterAlpha() {
            guard let (layout, _) = self.currentLayout else {
                return
            }
            let contentFrame = self.scrollView.convert(self.hostView.frame, to: self.view)
            let bottomOffset = contentFrame.maxY - layout.size.height
            
            let backgroundAlpha: CGFloat = min(30.0, max(0.0, bottomOffset)) / 30.0
            self.footerView.updateBackgroundAlpha(backgroundAlpha, transition: .immediate)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = self.scrollView.contentOffset.y
            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
            
            self.updateFooterAlpha()
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            let footerTargetPosition = self.footerView.center
            let footerStartPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            self.footerView.center = footerStartPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
                self.footerView.center = footerTargetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            positionTransition.updatePosition(layer: self.footerView.layer, position: CGPoint(x: self.footerView.center.x, y: self.bounds.height + self.footerView.bounds.height / 2.0))
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ComponentTransition) {
            let hadLayout = self.currentLayout != nil
            self.currentLayout = (layout, navigationHeight)
            
            if let controller = self.controller, let navigationBar = controller.navigationBar, navigationBar.view.superview !== self.wrappingView {
                self.containerView.addSubview(navigationBar.view)
            }
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                additionalInsets: layout.additionalInsets,
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: layout.metrics.orientation,
                isVisible: self.currentIsVisible,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            let contentSize = self.hostView.update(
                transition: transition,
                component: self.component,
                environment: {
                    environment
                },
                forceUpdate: true,
                containerSize: CGSize(width: layout.size.width, height: 10000.0)
            )
//            contentSize.height = max(layout.size.height - navigationHeight, contentSize.height)
            transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            
            self.scrollView.contentSize = contentSize
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            let modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            
            let clipFrame: CGRect
            if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    var containerTopInset: CGFloat = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
                
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: clipFrame.size), completion: nil)

            let footerInsets = UIEdgeInsets(top: 0.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right)
            
            transition.setFrame(view: self.footerView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topInset), size: layout.size))
            self.footerHeight = self.footerView.update(size: layout.size, insets: footerInsets, theme: self.presentationData.theme, strings: self.presentationData.strings, count: Int32(self.selectedSlots.count))
            
            if !hadLayout {
                self.updateFooterAlpha()
            }
        }
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var defaultTopInset: CGFloat {
            guard let (layout, _) = self.currentLayout else{
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                var factor: CGFloat = 0.2488
                if layout.size.width <= 320.0 {
                    factor = 0.15
                }
                if self.scrollView.contentSize.height > 0.0 && self.scrollView.contentSize.height < layout.size.height / 2.0 {
                    return layout.size.height - self.scrollView.contentSize.height - layout.intrinsicInsets.bottom - 30.0
                } else {
                    return floor(max(layout.size.width, layout.size.height) * factor)
                }
            } else {
                return 210.0
            }
        }
        
        private func findScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? UIScrollView {
                    return (view, nil)
                }
                if let node = view.asyncdisplaykit_node as? ListView {
                    return (node.scroller, node)
                }
                return findScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollViewAndListNode = self.findScrollView(view: currentHitView)
                    if scrollViewAndListNode?.0.frame.height == self.frame.width {
                        scrollViewAndListNode = nil
                    }
                    let scrollView = scrollViewAndListNode?.0
                    let listNode = scrollViewAndListNode?.1
                                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView, listNode)
                case .changed:
                    guard let (topInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    var translation = recognizer.translation(in: self.view).y

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if case let .known(value) = visibleContentOffset, value <= epsilon {
                        if let scrollView = scrollView {
                            scrollView.bounces = false
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                        }
                    } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView, listNode)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
                
                    self.updateFooterAlpha()
                case .ended:
                    guard let (currentTopInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    let translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    
                    if self.isExpanded {
                        if case let .known(value) = visibleContentOffset, value > 0.1 {
                            velocity = CGPoint()
                        } else if case .unknown = visibleContentOffset {
                            velocity = CGPoint()
                        } else if contentOffset > 0.1 {
                            velocity = CGPoint()
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let listNode = listNode {
                                listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            } else if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if (velocity.y < -300.0 || offset < topInset / 2.0) {
                        if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                            DispatchQueue.main.async {
                                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            }
                        }
                                                    
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                
                    self.updateFooterAlpha()
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                
                    self.updateFooterAlpha()
                default:
                    break
            }
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.isExpanded = isExpanded
            
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    
    private var replaceBoosts: (([Int32]) -> Void)?
    
    private var currentLayout: ContainerViewLayout?
            
    public convenience init(context: AccountContext, peerId: EnginePeer.Id, myBoostStatus: MyBoostStatus, replaceBoosts: @escaping ([Int32]) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
        var initiallySelectedSlot: Int32?
        let occupiedBoosts = myBoostStatus.boosts.filter { $0.peer?.id != peerId && $0.peer != nil }.sorted { lhs, rhs in
            return lhs.date < rhs.date
        }
        if occupiedBoosts.count == 1, let boost = occupiedBoosts.first {
            initiallySelectedSlot = boost.slot
        }
        
        var selectedSlotsUpdatedImpl: (([Int32]) -> Void)?
        var presentControllerImpl: ((ViewController) -> Void)?
        var giftPremiumImpl: (() -> Void)?
        self.init(context: context, component: ReplaceBoostScreenComponent(context: context, peerId: peerId, myBoostStatus: myBoostStatus, initiallySelectedSlot: initiallySelectedSlot, selectedSlotsUpdated: { slots in
            selectedSlotsUpdatedImpl?(slots)
        }, presentController: { c in
            presentControllerImpl?(c)
        }, giftPremium: {
            giftPremiumImpl?()
        }))
        
        self.title = presentationData.strings.ReassignBoost_Title
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        selectedSlotsUpdatedImpl = { [weak self] selectedSlots in
            self?.node.selectedSlots = selectedSlots
        }
        presentControllerImpl = { [weak self] c in
            self?.dismissAllTooltips()
            self?.present(c, in: .window(.root))
        }
        
        self.replaceBoosts = replaceBoosts
        
        if let initiallySelectedSlot {
            self.node.selectedSlots = [initiallySelectedSlot]
        }
        
        giftPremiumImpl = { [weak self] in
            guard let self else {
                return
            }
            let navigationController = self.navigationController
            self.dismiss(animated: true, completion: {
                let giftController = context.sharedContext.makePremiumGiftController(context: context, source: .channelBoost, completion: nil)
                navigationController?.pushViewController(giftController, animated: true)
            })
        }
    }
    
    private init<C: Component>(context: AccountContext, component: C, theme: PresentationTheme? = nil) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, component: self.component)
        self.displayNodeDidLoad()
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
    
    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var navigationLayout = self.navigationLayout(layout: layout)
        var navigationFrame = navigationLayout.navigationFrame
        
        var layout = layout
        if case .regular = layout.metrics.widthClass {
            let verticalInset: CGFloat = 44.0
            let maxSide = max(layout.size.width, layout.size.height)
            let minSide = min(layout.size.width, layout.size.height)
            let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
            let clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            navigationFrame.size.width = clipFrame.width
            layout.size = clipFrame.size
        }
        
        navigationFrame.size.height = 56.0
        navigationLayout.navigationFrame = navigationFrame
        navigationLayout.defaultContentHeight = 56.0
        
        layout.statusBarHeight = nil
        
        self.applyNavigationBarLayout(layout, navigationLayout: navigationLayout, additionalBackgroundHeight: 0.0, additionalCutout: nil, transition: transition)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight: CGFloat = 56.0
        
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
    }
}

private final class FooterView: UIView {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorView: UIView
    private let button = ComponentView<Empty>()
    
    var action: () -> Void = {}
    
    init() {
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        self.separatorView = UIView()
        
        super.init(frame: .zero)
        
        self.addSubnode(self.backgroundNode)
        self.addSubview(self.separatorView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate var inProgress = false
    
    private var currentLayout: (CGSize, UIEdgeInsets, PresentationTheme, PresentationStrings, Int32)?
    func update(size: CGSize, insets: UIEdgeInsets, theme: PresentationTheme, strings: PresentationStrings, count: Int32) -> CGFloat {
        let hadLayout = self.currentLayout != nil
        self.currentLayout = (size, insets, theme, strings, count)
        
        self.backgroundNode.updateColor(color: theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorView.backgroundColor = theme.rootController.tabBar.separatorColor
        
        let buttonInset: CGFloat = 16.0
        let buttonWidth = size.width - insets.left - insets.right - buttonInset * 2.0
        let inset: CGFloat = 9.0
                
        var panelHeight: CGFloat = 50.0 + inset * 2.0
        panelHeight += insets.bottom
        
        let totalPanelHeight = panelHeight
        
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - totalPanelHeight), size: CGSize(width: size.width, height: panelHeight))
        
        var buttonTransition: ComponentTransition = .easeInOut(duration: 0.2)
        if !hadLayout {
            buttonTransition = .immediate
        }
        let buttonSize = self.button.update(
            transition: buttonTransition,
            component: AnyComponent(
                ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: strings.ReassignBoost_ReassignBoosts,
                            badge: Int(count),
                            textColor: theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: theme.list.itemCheckColors.fillColor,
                            badgeStyle: .roundedRectangle,
                            badgeIconName: "Premium/BoostButtonIcon",
                            combinedAlignment: true
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: self.inProgress,
                    action: { [weak self] in
                        guard let self, !self.inProgress else {
                            return
                        }
                        self.inProgress = true
                        if let (size, insets, theme, strings, count) = self.currentLayout {
                            let _ = self.update(size: size, insets: insets, theme: theme, strings: strings, count: count)
                        }
                        self.action()
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: buttonWidth, height: 50.0)
        )
        if let view = self.button.view {
            if view.superview == nil {
                self.addSubview(view)
            }
            view.frame = CGRect(origin: CGPoint(x: insets.left + buttonInset, y: panelFrame.minY + inset), size: buttonSize)
            
            buttonTransition.setAlpha(view: view, alpha: count > 0 ? 1.0 : 0.3)
            view.isUserInteractionEnabled = count > 0
        }
        
        self.backgroundNode.frame = panelFrame
        self.backgroundNode.update(size: panelFrame.size, transition: .immediate)
        self.separatorView.frame = CGRect(origin: panelFrame.origin, size: CGSize(width: panelFrame.width, height: UIScreenPixel))
        
        return panelHeight
    }
    
    func updateBackgroundAlpha(_ alpha: CGFloat, transition: ComponentTransition) {
        transition.setAlpha(view: self.backgroundNode.view, alpha: alpha)
        transition.setAlpha(view: self.separatorView, alpha: alpha)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.backgroundNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
}

private func generateBoostIcon(theme: PresentationTheme) -> UIImage? {
    if let image = UIImage(bundleImageName: "Premium/AvatarBoost") {
        let size = CGSize(width: image.size.width + 4.0, height: image.size.height + 4.0)
        return generateImage(size, contextGenerator: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            if let cgImage = image.cgImage {
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: image.size))
            }
            
            let lineWidth = 2.0 - UIScreenPixel
            context.setLineWidth(lineWidth)
            context.setStrokeColor(theme.list.blocksBackgroundColor.cgColor)
            context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0 + UIScreenPixel, dy: lineWidth / 2.0 + UIScreenPixel))
        }, opaque: false)
    }
    return nil
}

private final class ReplaceBoostHeaderComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let mainPeer: EnginePeer
    let otherPeers: [EnginePeer]

    init(context: AccountContext, theme: PresentationTheme, mainPeer: EnginePeer, otherPeers: [EnginePeer]) {
        self.context = context
        self.theme = theme
        self.mainPeer = mainPeer
        self.otherPeers = otherPeers
    }

    static func ==(lhs: ReplaceBoostHeaderComponent, rhs: ReplaceBoostHeaderComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.mainPeer != rhs.mainPeer {
            return false
        }
        if lhs.otherPeers != rhs.otherPeers {
            return false
        }
        return true
    }
    
    final class WrapperAvatarView: UIView {
        let backgroundView = UIView()
        let avatarNode: AvatarNode
        let badgeImageView: UIImageView
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
            self.avatarNode.frame = CGRect(origin: .zero, size: CGSize(width: 60.0, height: 60.0))
            self.backgroundView.frame = self.avatarNode.frame.insetBy(dx: -3.0 + UIScreenPixel, dy: -3.0 + UIScreenPixel)
            self.backgroundView.layer.cornerRadius = self.backgroundView.frame.height / 2.0
            
            self.badgeImageView = UIImageView(frame: CGRect(x: 60.0 - 24.0, y: 60.0 - 24.0, width: 28.0, height: 28.0))
            self.badgeImageView.alpha = 0.0
            
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            
            self.addSubview(self.backgroundView)
            self.addSubnode(self.avatarNode)
            self.addSubview(self.badgeImageView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    

    final class View: UIView {
        private let containerView = UIView()
        private let avatarNode: AvatarNode
        private let arrowView: UIImageView
        
        private var otherAvatarNodes: [EnginePeer.Id: WrapperAvatarView] = [:]
        
        private var component: ReplaceBoostHeaderComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
            self.avatarNode.frame = CGRect(origin: .zero, size: CGSize(width: 60.0, height: 60.0))
            
            self.arrowView = UIImageView(image: UIImage(bundleImageName: "Peer Info/AlertArrow")?.withRenderingMode(.alwaysTemplate))
          
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.arrowView)
            self.containerView.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var badgeImage: UIImage?
        func update(component: ReplaceBoostHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let avatarSize = CGSize(width: 60.0, height: 60.0)
            
            let spacing: CGFloat = 27.0
            var totalWidth: CGFloat = avatarSize.width
            if !component.otherPeers.isEmpty {
                totalWidth += spacing
                totalWidth += avatarSize.width
                
                if component.otherPeers.count > 1 {
                    totalWidth += (avatarSize.width / 2.0) * CGFloat(component.otherPeers.count - 1)
                }
            }
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: (availableSize.width - totalWidth) / 2.0, y: 0.0), size: CGSize(width: totalWidth, height: avatarSize.height)))

            var originX: CGFloat = 0.0
            var validIds: [EnginePeer.Id] = []
            for i in 0 ..< component.otherPeers.count {
                let peer = component.otherPeers[i]
                validIds.append(peer.id)
                
                let avatarView: WrapperAvatarView
                var avatarTransition = transition
                if let current = self.otherAvatarNodes[peer.id] {
                    avatarView = current
                } else {
                    avatarTransition = .immediate
                     
                    avatarView = WrapperAvatarView()
                    avatarView.bounds = CGRect(origin: .zero, size: avatarSize)
                    avatarView.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, synchronousLoad: true)
                    avatarView.backgroundView.backgroundColor = component.theme.list.blocksBackgroundColor
                    
                    if self.badgeImage == nil {
                        self.badgeImage = generateBoostIcon(theme: component.theme)
                    }
                    avatarView.badgeImageView.image = self.badgeImage
                    
                    self.otherAvatarNodes[peer.id] = avatarView
                    self.containerView.insertSubview(avatarView, at: 0)
                    
                    avatarView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    avatarView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                let isLast = i == component.otherPeers.count - 1
                avatarTransition.setAlpha(view: avatarView.badgeImageView, alpha: isLast ? 1.0 : 0.0)
                avatarTransition.setScale(view: avatarView.badgeImageView, scale: isLast ? 1.0 : 0.1)
                
                avatarTransition.setPosition(view: avatarView, position: CGPoint(x: originX + avatarSize.width / 2.0, y: avatarSize.height / 2.0))
                if isLast {
                    originX += avatarSize.width
                } else {
                    originX += avatarSize.width / 2.0
                }
            }
            
            if !component.otherPeers.isEmpty {
                originX += spacing
            }
            
            self.arrowView.tintColor = component.theme.list.itemSecondaryTextColor
            transition.setAlpha(view: self.arrowView, alpha: component.otherPeers.isEmpty ? 0.0 : 1.0)
            transition.setScale(view: self.arrowView, scale: component.otherPeers.isEmpty ? 0.1 : 1.0)
            transition.setPosition(view: self.arrowView, position: CGPoint(x: originX - 13.0, y: avatarSize.height / 2.0))
            
            transition.setFrame(view: self.avatarNode.view, frame: CGRect(origin: CGPoint(x: originX, y: 0.0), size: avatarSize))
            self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.mainPeer, synchronousLoad: true)
            
            var removeIds: [EnginePeer.Id] = []
            for (id, avatarView) in self.otherAvatarNodes {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    avatarView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        avatarView.removeFromSuperview()
                    })
                    avatarView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                }
            }
            for id in removeIds {
                self.otherAvatarNodes.removeValue(forKey: id)
            }
            
            return CGSize(width: availableSize.width, height: avatarSize.height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
