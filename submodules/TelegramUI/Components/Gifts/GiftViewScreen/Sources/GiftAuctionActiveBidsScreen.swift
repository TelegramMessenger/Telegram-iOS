import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ComponentFlow
import AccountContext
import ViewControllerComponent
import TelegramCore
import SwiftSignalKit
import Display
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import ButtonComponent
import PlainButtonComponent
import Markdown
import BundleIconComponent
import TextFormat
import TelegramStringFormatting
import GlassBarButtonComponent
import GiftItemComponent
import EdgeEffect
import AnimatedTextComponent

private final class GiftAuctionActiveBidsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    
    init(
        context: AccountContext
    ) {
        self.context = context
    }
    
    static func ==(lhs: GiftAuctionActiveBidsScreenComponent, rhs: GiftAuctionActiveBidsScreenComponent) -> Bool {
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var containerCornerRadius: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let topEdgeEffectView: EdgeEffectView
        
        private let backgroundHandleView: UIImageView
        
        private let closeButton = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private var itemsViews: [Int64: ComponentView<Empty>] = [:]
        
        private var auctionStates: [GiftAuctionContext.State] = []
        private var auctionStatesDisposable: Disposable?
        
        private var ignoreScrolling: Bool = false
        
        private var giftAuctionTimer: SwiftSignalKit.Timer?
        
        private var component: GiftAuctionActiveBidsScreenComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
                
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = UIView()
            
            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 40.0
            self.containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 40.0
                        
            self.backgroundHandleView = UIImageView()
            
            self.navigationBarContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.topEdgeEffectView = EdgeEffectView()
            self.topEdgeEffectView.clipsToBounds = true
            self.topEdgeEffectView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.topEdgeEffectView.layer.cornerRadius = 40.0
                                    
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.layer.addSublayer(self.backgroundLayer)
                        
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
            
            self.containerView.addSubview(self.navigationBarContainer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.auctionStatesDisposable?.dispose()
            self.giftAuctionTimer?.invalidate()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
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
            guard let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let minScale: CGFloat = (itemLayout.containerSize.width - 6.0 * 2.0) / itemLayout.containerSize.width
            let minScaledTranslation: CGFloat = (itemLayout.containerSize.height - itemLayout.containerSize.height * minScale) * 0.5 - 6.0
            let minScaledCornerRadius: CGFloat = itemLayout.containerCornerRadius
            
            let scale = minScale * (1.0 - topOffsetFraction) + 1.0 * topOffsetFraction
            let scaledTranslation = minScaledTranslation * (1.0 - topOffsetFraction)
            let scaledCornerRadius = minScaledCornerRadius * (1.0 - topOffsetFraction) + itemLayout.containerCornerRadius * topOffsetFraction
            
            var containerTransform = CATransform3DIdentity
            containerTransform = CATransform3DTranslate(containerTransform, 0.0, scaledTranslation, 0.0)
            containerTransform = CATransform3DScale(containerTransform, scale, scale, scale)
            transition.setTransform(view: self.containerView, transform: containerTransform)
            transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: scaledCornerRadius)
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
        }
      
        func update(component: GiftAuctionActiveBidsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, environment.deviceMetrics.screenSize.width) - environment.safeInsets.left * 2.0
            }
            let rawSideInset: CGFloat = floor((availableSize.width - fillingSize) * 0.5)
            let sideInset: CGFloat = rawSideInset + 16.0
            
            if self.component == nil, let giftAuctionsManager = component.context.giftAuctionsManager {
                self.auctionStatesDisposable = (giftAuctionsManager.state
                |> deliverOnMainQueue).start(next: { [weak self] auctionStates in
                    guard let self else {
                        return
                    }
                    self.auctionStates = auctionStates.filter { state in
                        if case .ongoing = state.auctionState {
                            return true
                        } else {
                            return false
                        }
                    }
                    self.state?.updated(transition: .immediate)
                    
                    if self.auctionStates.isEmpty {
                        self.environment?.controller()?.dismiss()
                    }
                })
                
                self.giftAuctionTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                    self?.state?.updated()
                }, queue: Queue.mainQueue())
                self.giftAuctionTimer?.start()
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            let theme = environment.theme.withModalBlocksBackground()
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = theme.list.blocksBackgroundColor.cgColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            var contentHeight: CGFloat = 75.0
            
            var validKeys: Set<Int64> = Set()
            for auctionState in self.auctionStates {
                let id = auctionState.gift.giftId
                validKeys.insert(id)
                
                let itemView: ComponentView<Empty>
                if let current = self.itemsViews[id] {
                    itemView = current
                } else {
                    itemView = ComponentView()
                    self.itemsViews[id] = itemView
                }
                
                let itemSize = itemView.update(
                    transition: transition,
                    component: AnyComponent(
                        ActiveAuctionComponent(
                            context: component.context,
                            theme: theme,
                            strings: environment.strings,
                            dateTimeFormat: environment.dateTimeFormat,
                            state: auctionState,
                            currentTime: currentTime,
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if let giftAuctionsManager = component.context.giftAuctionsManager {
                                    let _ = (giftAuctionsManager.auctionContext(for: .giftId(id))
                                    |> deliverOnMainQueue).start(next: { [weak self] auction in
                                        guard let self, let component = self.component, let auction, let controller = environment.controller(), let navigationController = controller.navigationController as? NavigationController else {
                                            return
                                        }
                                        let bidController = component.context.sharedContext.makeGiftAuctionBidScreen(context: component.context, toPeerId: auction.currentBidPeerId ?? component.context.account.peerId, text: nil, entities: nil, hideName: false, auctionContext: auction, acquiredGifts: nil)
                                        navigationController.pushViewController(bidController)
                                    })
                                }
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let itemFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: itemSize)
                if let view = itemView.view {
                    if view.superview == nil {
                        self.scrollContentView.addSubview(view)
                    }
                    view.frame = itemFrame
                }
                contentHeight += itemSize.height
                contentHeight += 20.0
            }
            contentHeight -= 10.0
            
            var removeKeys: [Int64] = []
            for (id, item) in self.itemsViews {
                if !validKeys.contains(id) {
                    removeKeys.append(id)
                    
                    if let itemView = item.view {
                        transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                            itemView.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeKeys {
                self.itemsViews.removeValue(forKey: id)
            }
            
            if self.backgroundHandleView.image == nil {
                self.backgroundHandleView.image = generateStretchableFilledCircleImage(diameter: 5.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.backgroundHandleView.tintColor = theme.list.itemPrimaryTextColor.withMultipliedAlpha(theme.overallDarkAppearance ? 0.2 : 0.07)
            let backgroundHandleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - 36.0) * 0.5), y: 5.0), size: CGSize(width: 36.0, height: 5.0))
            if self.backgroundHandleView.superview == nil {
                self.navigationBarContainer.addSubview(self.backgroundHandleView)
            }
            transition.setFrame(view: self.backgroundHandleView, frame: backgroundHandleFrame)
            
            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: rawSideInset + 16.0, y: 16.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            contentHeight += environment.safeInsets.bottom
            
            let clippingY: CGFloat
            
            let titleText: String = environment.strings.Gift_ActiveAuctions_Title(Int32(self.auctionStates.count))
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: 26.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
                                          
            let initialContentHeight = contentHeight
            
            let edgeEffectHeight: CGFloat = 80.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: CGSize(width: fillingSize, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: edgeEffectFrame)
            self.topEdgeEffectView.update(content: theme.actionSheet.opaqueItemBackgroundColor, blur: true, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectFrame.height, transition: transition)
            if self.topEdgeEffectView.superview == nil {
                self.navigationBarContainer.insertSubview(self.topEdgeEffectView, at: 0)
            }
             
            clippingY = availableSize.height
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 38.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, containerCornerRadius: environment.deviceMetrics.screenCornerRadius, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: fillingSize, height: availableSize.height)))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: availableSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setPosition(view: self.containerView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
                        
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let bottomInset: CGFloat = contentHeight - 12.0
            
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            }
            
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

public class GiftAuctionActiveBidsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    private var didPlayAppearAnimation: Bool = false
    private var isDismissed: Bool = false
    
    public init(context: AccountContext) {
        self.context = context
        
        super.init(context: context, component: GiftAuctionActiveBidsScreenComponent(
            context: context
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if !self.didPlayAppearAnimation {
            self.didPlayAppearAnimation = true
            
            if let componentView = self.node.hostView.componentView as? GiftAuctionActiveBidsScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
        
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? GiftAuctionActiveBidsScreenComponent.View {
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

private final class ActiveAuctionComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let state: GiftAuctionContext.State
    let currentTime: Int32
    let action: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        state: GiftAuctionContext.State,
        currentTime: Int32,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.state = state
        self.currentTime = currentTime
        self.action = action
    }
    
    static func ==(lhs: ActiveAuctionComponent, rhs: ActiveAuctionComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.currentTime != rhs.currentTime {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let button =  ComponentView<Empty>()

        private var component: ActiveAuctionComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.cornerRadius = 26.0
            self.clipsToBounds = true
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: ActiveAuctionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
                        
            var size = CGSize(width: availableSize.width, height: 0.0)
            size.height += 11.0
            
            
            if case let .generic(gift) = component.state.gift {
                let titleSize = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(GiftItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        subject: .starGift(gift: gift, price: ""),
                        mode: .preview
                    )),
                    environment: {},
                    containerSize: CGSize(width: 64.0, height: 64.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: 2.0, y: 0.0), size: titleSize)
                if let iconView = self.icon.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
            }
            
            var endTime = component.currentTime
            
            var titleText: String = ""
            var subtitleText: String = ""
            var subtitleTextColor = component.theme.list.itemPrimaryTextColor
            if case let .ongoing(_, startDate, _, _, _, _, nextRoundDate, _, currentRound, totalRound, _, _) = component.state.auctionState, let myBid = component.state.myState.bidAmount {
                titleText = component.strings.Gift_ActiveAuctions_Round("\(currentRound)", "\(totalRound)").string
                
                let bidString = "#\(presentationStringsFormattedNumber(Int32(clamping: myBid), component.dateTimeFormat.groupingSeparator))"
                if component.currentTime < startDate {
                    subtitleText = component.strings.Gift_ActiveAuctions_UpcomingBid
                } else if let place = component.state.place, case let .generic(gift) = component.state.gift, let auctionGiftsPerRound = gift.auctionGiftsPerRound, place > auctionGiftsPerRound {
                    subtitleText = component.strings.Gift_ActiveAuctions_Outbid(bidString).string
                    subtitleTextColor = component.theme.list.itemDestructiveColor
                } else {
                    subtitleText = component.strings.Gift_ActiveAuctions_Winning(bidString, "\(component.state.place ?? 0)").string
                }
                
                endTime = nextRoundDate
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 63.0 - 20.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 63.0, y: size.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            size.height += titleSize.height
            size.height += 2.0
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = subtitleTextColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: textColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let attributedString = parseMarkdownIntoAttributedString(subtitleText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
            if let range = attributedString.string.range(of: "#") {
                attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                attributedString.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: attributedString.string))
            }
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(context: component.context, animationCache: component.context.animationCache, animationRenderer: component.context.animationRenderer, placeholderColor: .clear, text: .plain(attributedString), maximumNumberOfLines: 2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 63.0 - 20.0, height: 100.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: 63.0, y: size.height), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                subtitleView.frame = subtitleFrame
            }
            size.height += subtitleSize.height
            size.height += 19.0
            
            let endTimeout = max(0, endTime - component.currentTime)
            let hours = Int(endTimeout / 3600)
            let minutes = Int((endTimeout % 3600) / 60)
            let seconds = Int(endTimeout % 60)
                   
            var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
            if hours > 0 {
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "h", content: .number(hours, minDigits: 1)))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "colon1", content: .text(":")))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "colon2", content: .text(":")))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
            } else {
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "colon2", content: .text(":")))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
            }
            
            let buttonSize = self.button.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(
                    ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: component.theme.list.itemCheckColors.fillColor,
                            foreground: component.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(id: "label", component: AnyComponent(
                            HStack([
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                    BundleIconComponent(name: "Premium/Auction/BidSmall", tintColor: component.theme.list.itemCheckColors.foregroundColor)
                                )),
                                AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: component.strings.Gift_ActiveAuctions_RaiseBid, font: Font.semibold(17.0), textColor: component.theme.list.itemCheckColors.foregroundColor)))
                                )),
                                AnyComponentWithIdentity(id: "timer", component: AnyComponent(
                                    AnimatedTextComponent(
                                        font: Font.with(size: 17.0, weight: .medium, traits: .monospacedNumbers),
                                        color: component.theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7),
                                        items: buttonAnimatedTitleItems,
                                        noDelay: true
                                    )
                                ))
                            ], spacing: 5.0)
                        )),
                        action: {
                            component.action()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 52.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0), y: size.height), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                buttonView.frame = buttonFrame
            }
            size.height += buttonSize.height
            size.height += 16.0
           
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
