import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown

private final class LimitScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: LimitScreen.Subject
    let proceed: () -> Void
    
    init(context: AccountContext, subject: LimitScreen.Subject, proceed: @escaping () -> Void) {
        self.context = context
        self.subject = subject
        self.proceed = proceed
    }
    
    static func ==(lhs: LimitScreenComponent, rhs: LimitScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        private var disposable: Disposable?
        var limits: EngineConfiguration.UserLimits
        var premiumLimits: EngineConfiguration.UserLimits
        
        init(context: AccountContext, subject: LimitScreen.Subject) {
            self.context = context
            self.limits = EngineConfiguration.UserLimits.defaultValue
            self.premiumLimits = EngineConfiguration.UserLimits.defaultValue
            
            super.init()
            
            self.disposable = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            ) |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    let (limits, premiumLimits) = result
                    strongSelf.limits = limits
                    strongSelf.premiumLimits = premiumLimits
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
    
    static var body: Body {
        let badgeBackground = Child(RoundedRectangle.self)
        let badgeIcon = Child(BundleIconComponent.self)
        let badgeText = Child(MultilineTextComponent.self)
        
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        
        let button = Child(SolidRoundedButtonComponent.self)
        let cancel = Child(Button.self)
    
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            
            let state = context.state
            let subject = component.subject
            
            let topInset: CGFloat = 34.0 + 38.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 24.0 + environment.safeInsets.left
            
            let iconName: String
            let badgeString: String
            let string: String
            switch subject {
                case .folders:
                    let limit = state.limits.maxFoldersCount
                    let premiumLimit = state.premiumLimits.maxFoldersCount
                    iconName = "Premium/Folder"
                    badgeString = "\(limit)"
                    string = strings.Premium_MaxFoldersCountText("\(limit)", "\(premiumLimit)").string
                case .chatsInFolder:
                    let limit = state.limits.maxFolderChatsCount
                    let premiumLimit = state.premiumLimits.maxFolderChatsCount
                    iconName = "Premium/Chat"
                    badgeString = "\(limit)"
                    string = strings.Premium_MaxChatsInFolderCountText("\(limit)", "\(premiumLimit)").string
                case .pins:
                    let limit = state.limits.maxPinnedChatCount
                    let premiumLimit = state.premiumLimits.maxPinnedChatCount
                    iconName = "Premium/Pin"
                    badgeString = "\(limit)"
                    string = strings.DialogList_ExtendedPinLimitError("\(limit)", "\(premiumLimit)").string
                case .files:
                    let limit = 2048 * 1024 * 1024 //state.limits.maxPinnedChatCount
                    let premiumLimit = 4096 * 1024 * 1024 //state.premiumLimits.maxPinnedChatCount
                    iconName = "Premium/File"
                    badgeString = dataSizeString(limit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))
                    string = strings.Premium_MaxFileSizeText(dataSizeString(premiumLimit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))).string
            }
            
            let badgeIcon = badgeIcon.update(
                component: BundleIconComponent(
                    name: iconName,
                    tintColor: .white
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let badgeText = badgeText.update(
                component: MultilineTextComponent(
                    text: NSAttributedString(
                        string: badgeString,
                        font: Font.with(size: 24.0, design: .round, weight: .semibold, traits: []),
                        textColor: .white,
                        paragraphAlignment: .center
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let badgeBackground = badgeBackground.update(
                component: RoundedRectangle(
                    colors: [UIColor(rgb: 0xa34fcf), UIColor(rgb: 0xc8498a), UIColor(rgb: 0xff7a23)],
                    cornerRadius: 23.5
                ),
                availableSize: CGSize(width: badgeText.size.width + 67.0, height: 47.0),
                transition: .immediate
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: NSAttributedString(
                        string: strings.Premium_LimitReached,
                        font: Font.semibold(17.0),
                        textColor: theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(16.0)
            let boldTextFont = Font.semibold(16.0)
            
            let textColor = theme.actionSheet.primaryTextColor
            let attributedText = parseMarkdownIntoAttributedString(string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: textColor), linkAttribute: { _ in
                return nil
            }))
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: attributedText,
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: strings.Premium_IncreaseLimit,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: .black,
                        backgroundColors: [UIColor(rgb: 0x407af0), UIColor(rgb: 0x9551e8), UIColor(rgb: 0xbf499a), UIColor(rgb: 0xf17b30)],
                        foregroundColor: .white
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: false,
                    iconName: "Premium/X2",
                    iconPosition: .right,
                    action: { [weak component] in
                        guard let component = component else {
                            return
                        }
                        component.proceed()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            let cancel = cancel.update(component: Button(
                content: AnyComponent(Text(text: strings.Common_Cancel, font: Font.regular(17.0), color: theme.actionSheet.controlAccentColor)),
                action: {
                    
                }
            ),
            availableSize: context.availableSize,
            transition: context.transition)
            
            let width = context.availableSize.width
            
            let badgeFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - badgeBackground.size.width) / 2.0), y: 33.0), size: badgeBackground.size)
            context.add(badgeBackground
                .position(CGPoint(x: badgeFrame.midX, y: badgeFrame.midY))
            )
            
            let badgeIconFrame = CGRect(origin: CGPoint(x: badgeFrame.minX + 18.0, y: badgeFrame.minY + floor((badgeFrame.height - badgeIcon.size.height) / 2.0)), size: badgeIcon.size)
            context.add(badgeIcon
                .position(CGPoint(x: badgeIconFrame.midX, y: badgeIconFrame.midY))
            )
            
            let badgeTextFrame = CGRect(origin: CGPoint(x: badgeFrame.maxX - badgeText.size.width - 15.0, y: badgeFrame.minY + floor((badgeFrame.height - badgeText.size.height) / 2.0)), size: badgeText.size)
            context.add(badgeText
                .position(CGPoint(x: badgeTextFrame.midX, y: badgeTextFrame.midY))
            )
                        
            context.add(title
                .position(CGPoint(x: width / 2.0, y: topInset + 39.0))
            )
            context.add(text
                .position(CGPoint(x: width / 2.0, y: topInset + 101.0))
            )
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + 76.0 + text.size.height + 27.0), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
          
            context.add(cancel
                .position(CGPoint(x: width / 2.0, y: topInset + 76.0 + text.size.height + 20.0 + button.size.height + 40.0))
            )
            
            let contentSize = CGSize(width: context.availableSize.width, height: topInset + 76.0 + text.size.height + 20.0 + button.size.height + 40.0 + 33.0 + environment.safeInsets.bottom)
            
            return contentSize
        }
    }
}

public class LimitScreen: ViewController {
    final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: LimitScreen?
        
        private let component: AnyComponent<ViewControllerComponentContainer.Environment>
        private let theme: PresentationTheme?
        
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        private var panGestureRecognizer: UIPanGestureRecognizer?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        fileprivate var temporaryDismiss = false
        
        init(context: AccountContext, controller: LimitScreen, component: AnyComponent<ViewControllerComponentContainer.Environment>, theme: PresentationTheme?) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            self.theme = theme
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.hostView = ComponentHostView()
            
            super.init()
                        
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.hostView)
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let (layout, _) = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                } else {
                    let location = gestureRecognizer.location(in: self.containerView)
                    if !self.hostView.frame.contains(location) {
                        return false
                    }
                }
            }
            return true
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
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: Transition) {
            self.currentLayout = (layout, navigationHeight)
            
            if let controller = self.controller, let navigationBar = controller.navigationBar, navigationBar.view.superview !== self.wrappingView {
                self.containerView.addSubview(navigationBar.view)
            }
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            let isLandscape = layout.orientation == .landscape

            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(), size: layout.size), completion: nil)
                        
            var clipFrame: CGRect
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
                        
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                isVisible: self.currentIsVisible,
                theme: self.theme ?? self.presentationData.theme,
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
                containerSize: CGSize(width: clipFrame.size.width, height: clipFrame.size.height)
            )
            transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            
            if !isLandscape {
                clipFrame.origin.y = layout.size.height - contentSize.height
                transition.setFrame(view: self.containerView, frame: clipFrame)
            } else {
                
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
                
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
                case .began:
                    break
                case .changed:
                    let translation = recognizer.translation(in: self.view).y
                
                    var bounds = self.bounds
                    bounds.origin.y = -translation
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                case .ended:
                    let translation = recognizer.translation(in: self.view).y
                    let velocity = recognizer.velocity(in: self.view)
                    
                    var bounds = self.bounds
                    bounds.origin.y = -translation
                    bounds.origin.y = min(0.0, bounds.origin.y)
                                    
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                    } else {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    var bounds = self.bounds
                    let previousBounds = bounds
                    bounds.origin.y = 0.0
                    self.bounds = bounds
                    self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                default:
                    break
            }
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let theme: PresentationTheme?
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    private var isInitiallyExpanded = false
    
    private var currentLayout: ContainerViewLayout?
    
    public var pushController: (ViewController) -> Void = { _ in }
    public var presentController: (ViewController) -> Void = { _ in }
    
    public enum Subject {
        case folders
        case chatsInFolder
        case pins
        case files
    }
    
    public convenience init(context: AccountContext, subject: Subject) {
        self.init(context: context, component: LimitScreenComponent(context: context, subject: subject, proceed: {}))
    }
    
    private init<C: Component>(context: AccountContext, component: C, theme: PresentationTheme? = nil) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        self.theme = nil
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, component: self.component, theme: self.theme)
        self.displayNodeDidLoad()
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
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
        
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight: CGFloat = 56.0
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
    }
}
