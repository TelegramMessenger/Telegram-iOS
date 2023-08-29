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
import MultilineTextComponent
import LottieAnimationComponent
import BundleIconComponent

private final class ProgressComponent: Component {
    typealias EnvironmentType = Empty
    
    let title: String
    let value: Float
    let cancel: () -> Void
    
    init(
        title: String,
        value: Float,
        cancel: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.cancel = cancel
    }
    
    static func ==(lhs: ProgressComponent, rhs: ProgressComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let title = ComponentView<Empty>()
        private let progressLayer = SimpleShapeLayer()
        private let cancelButton = ComponentView<Empty>()
       
        private var component: ProgressComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            let lineWidth: CGFloat = 3.0
            let progressSize = CGSize(width: 42.0, height: 42.0)
            
            self.progressLayer.path = CGPath(ellipseIn: CGRect(origin: .zero, size: progressSize).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5), transform: nil)
            self.progressLayer.lineWidth = lineWidth
            self.progressLayer.strokeColor = UIColor.white.cgColor
            self.progressLayer.fillColor = UIColor.clear.cgColor
            self.progressLayer.lineCap = .round
            
            super.init(frame: frame)
            
            self.backgroundColor = .clear

            self.progressLayer.bounds = CGRect(origin: .zero, size: progressSize)
            
            self.layer.addSublayer(self.progressLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ProgressComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
        
            let minWidth: CGFloat = 98.0
            let inset: CGFloat = 16.0
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(Text(text: component.title, font: Font.regular(14.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: 160.0, height: 40.0)
            )
            
            let width: CGFloat = max(minWidth, titleSize.width + inset * 2.0)
            let titleFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels((width - titleSize.width) / 2.0), y: 16.0),
                size: titleSize
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }

            let progressPosition = CGPoint(x: width / 2.0, y: titleFrame.maxY + 34.0)
            self.progressLayer.position = progressPosition
            transition.setShapeLayerStrokeEnd(layer: self.progressLayer, strokeEnd: CGFloat(max(0.027, component.value)))
            
            if self.progressLayer.animation(forKey: "rotation") == nil {
                let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                basicAnimation.duration = 2.0
                basicAnimation.fromValue = NSNumber(value: Float(0.0))
                basicAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
                basicAnimation.repeatCount = Float.infinity
                basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                self.progressLayer.add(basicAnimation, forKey: "rotation")
            }
            
            let cancelSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Media Gallery/Close",
                                tintColor: UIColor.white
                            )
                        ),
                        action: { [weak self] in
                            if let self, let component = self.component {
                                component.cancel()
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 160.0, height: 40.0)
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(progressPosition.x - cancelSize.width / 2.0), y: floorToScreenPixels(progressPosition.y - cancelSize.height / 2.0)), size: cancelSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                cancelButtonView.frame = cancelButtonFrame
            }
            
            return CGSize(width: width, height: 104.0)
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class BannerComponent: Component {
    typealias EnvironmentType = Empty
    
    let iconName: String
    let text: String
    
    init(
        iconName: String,
        text: String
    ) {
        self.iconName = iconName
        self.text = text
    }
    
    static func ==(lhs: BannerComponent, rhs: BannerComponent) -> Bool {
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let icon = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
               
        private var component: BannerComponent?
        private weak var state: EmptyComponentState?
                
        func update(component: BannerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
        
            let height: CGFloat = 49.0
            
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(
                    LottieAnimationComponent(animation: LottieAnimationComponent.AnimationItem(name: component.iconName, mode: .animating(loop: false)), colors: [:], size: CGSize(width: 32.0, height: 32.0))
                ),
                environment: {},
                containerSize: CGSize(width: 32.0, height: 32.0)
            )
            let iconFrame = CGRect(
                origin: CGPoint(x: 9.0, y: floorToScreenPixels((height - iconSize.height) / 2.0)),
                size: iconSize
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.frame = iconFrame
            }
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: component.text, font: Font.regular(14.0), color: .white)
                ),
                environment: {},
                containerSize: CGSize(width: 200.0, height: height)
            )
            
            let textFrame = CGRect(
                origin: CGPoint(x: iconFrame.maxX + 9.0, y: floorToScreenPixels((height - textSize.height) / 2.0)),
                size: textSize
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.frame = textFrame
            }
            
            return CGSize(width: textFrame.maxX + 12.0, height: height)
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class SaveProgressScreenComponent: Component {
    public typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    public enum Content: Equatable {
        enum ContentType: Equatable {
            case progress
            case completion
        }
        
        case progress(String, Float)
        case completion(String)
        
        var type: ContentType {
            switch self {
            case .progress:
                return .progress
            case .completion:
                return .completion
            }
        }
    }
    
    public let context: AccountContext
    public let content: Content
    public let cancel: () -> Void
    
    public init(
        context: AccountContext,
        content: Content,
        cancel: @escaping () -> Void
    ) {
        self.context = context
        self.content = content
        self.cancel = cancel
    }
    
    public static func ==(lhs: SaveProgressScreenComponent, rhs: SaveProgressScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private var content = ComponentView<Empty>()
       
        private var component: SaveProgressScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: UIColor(rgb: 0x000000, alpha: 0.5))
            
            super.init(frame: frame)
            
            self.backgroundColor = .clear

            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SaveProgressScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            var animateIn = false
            var disappearingView: UIView?
            if let previousComponent, previousComponent.content.type != component.content.type {
                if let view = self.content.view {
                    disappearingView = view
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                    view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                }
                
                self.content = ComponentView<Empty>()
                animateIn = true
            }
        
            let cornerRadius: CGFloat
            let content: AnyComponent<Empty>
            switch component.content {
            case let .progress(title, progress):
                content = AnyComponent(ProgressComponent(title: title, value: progress, cancel: component.cancel))
                cornerRadius = 18.0
            case let .completion(text):
                content = AnyComponent(BannerComponent(iconName: "anim_savemedia", text: text))
                cornerRadius = 9.0
            }
            
            let contentSize = self.content.update(
                transition: transition,
                component: content,
                environment: {},
                containerSize: CGSize(width: 160.0, height: 160.0)
            )
            let contentFrame = CGRect(
                origin: .zero,
                size: contentSize
            )
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.backgroundView.addSubview(contentView)
                    if animateIn {
                        contentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        contentView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.25)
                    }
                }
                transition.setFrame(view: contentView, frame: contentFrame)
                if let disappearingView {
                    transition.setPosition(view: disappearingView, position: contentFrame.center)
                }
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - contentFrame.size.width) / 2.0), y: floorToScreenPixels((availableSize.height - contentFrame.size.height) / 2.0)), size: contentFrame.size)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: cornerRadius, transition: transition.containedViewLayoutTransition)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class SaveProgressScreen: ViewController {
    fileprivate final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: SaveProgressScreen?
        private let context: AccountContext
    
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        
        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        init(controller: SaveProgressScreen) {
            self.controller = controller
            self.context = controller.context

            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            super.init()
            
            self.backgroundColor = .clear
        }
                
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
        }
        
        private func animateIn() {
            if let view = self.componentHost.view {
                view.layer.animateScale(from: 0.4, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            if let view = self.componentHost.view {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.25, removeOnCompletion: false)
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    completion()
                })
            }
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, transition: Transition) {
            guard let controller = self.controller else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout

            let previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
            let topInset: CGFloat = floorToScreenPixels(layout.size.height - previewSize.height) / 2.0
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(
                    top: topInset,
                    left: layout.safeInsets.left,
                    bottom: topInset,
                    right: layout.safeInsets.right
                ),
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: nil,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    SaveProgressScreenComponent(
                        context: self.context,
                        content: controller.content,
                        cancel: { [weak self] in
                            if let self, let controller = self.controller {
                                controller.cancel()
                            }
                        }
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: false,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.view.addSubview(componentView)
                }
                let componentFrame = CGRect(origin: .zero, size: componentSize)
                transition.setFrame(view: componentView, frame: CGRect(origin: componentFrame.origin, size: CGSize(width: componentFrame.width, height: componentFrame.height)))
            }
            
            if isFirstTime {
                self.animateIn()
            }
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    fileprivate let context: AccountContext
    public var content: SaveProgressScreenComponent.Content {
        didSet {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .animated(duration: 0.25, curve: .easeInOut))
            }
            self.maybeSetupDismissTimer()
        }
    }
    
    private var dismissTimer: SwiftSignalKit.Timer?
            
    public var cancelled: () -> Void = {}
    
    public init(context: AccountContext, content: SaveProgressScreenComponent.Content) {
        self.context = context
        self.content = content
        
        super.init(navigationBarPresentationData: nil)

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.maybeSetupDismissTimer()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
    
    fileprivate func cancel() {
        self.cancelled()
        
        self.node.animateOut(completion: { [weak self] in
            if let self {
                self.dismiss()
            }
        })
    }
    
    private func maybeSetupDismissTimer() {
        if case .completion = self.content {
            self.node.isUserInteractionEnabled = false
            if self.dismissTimer == nil {
                let timer = SwiftSignalKit.Timer(timeout: 3.0, repeat: false, completion: { [weak self] in
                    if let self {
                        self.node.animateOut(completion: { [weak self] in
                            if let self {
                                self.dismiss()
                            }
                        })
                    }
                }, queue: Queue.mainQueue())
                timer.start()
                self.dismissTimer = timer
            }
        }
    }
                
    private var validLayout: ContainerViewLayout?
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
}
