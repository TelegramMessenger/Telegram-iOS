import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import AccountContext
import MultilineTextComponent
import AvatarNode
import Markdown
import LottieComponent
import PlainButtonComponent

private final class QuickShareToastScreenComponent: Component {
    let context: AccountContext
    let peer: EnginePeer
    let sourceFrame: CGRect
    let action: (QuickShareToastScreen.Action) -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        sourceFrame: CGRect,
        action: @escaping (QuickShareToastScreen.Action) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.sourceFrame = sourceFrame
        self.action = action
    }
    
    static func ==(lhs: QuickShareToastScreenComponent, rhs: QuickShareToastScreenComponent) -> Bool {
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.sourceFrame != rhs.sourceFrame {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let contentView: UIView
        private let backgroundView: BlurredBackgroundView
        
        private let avatarNode: AvatarNode
        private let animation = ComponentView<Empty>()
        
        private let content = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        private var component: QuickShareToastScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
                
        private var doneTimer: Foundation.Timer?
                
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.contentView = UIView()
            self.contentView.isUserInteractionEnabled = false
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 15.0))
                        
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.contentView)
            self.contentView.addSubview(self.avatarNode.view)
            
            self.backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture)))
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.doneTimer?.invalidate()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.frame.contains(point) {
                return nil
            }
            return super.hitTest(point, with: event)
        }
        
        @objc private func tapGesture() {
            guard let component = self.component else {
                return
            }
            component.action(.info)
            self.doneTimer?.invalidate()
            self.environment?.controller()?.dismiss()
        }
        
        func animateIn() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            func generateAvatarParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat) -> [CGPoint] {
                let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
                
                let x1 = sourcePoint.x
                let y1 = sourcePoint.y
                let x2 = midPoint.x
                let y2 = midPoint.y
                let x3 = targetPosition.x
                let y3 = targetPosition.y
                
                var keyframes: [CGPoint] = []
                if abs(y1 - y3) < 5.0 && abs(x1 - x3) < 5.0 {
                    for i in 0 ..< 10 {
                        let k = CGFloat(i) / CGFloat(10 - 1)
                        let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
                        let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
                        keyframes.append(CGPoint(x: x, y: y))
                    }
                } else {
                    let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                    let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                    let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                    
                    for i in 0 ..< 10 {
                        let k = CGFloat(i) / CGFloat(10 - 1)
                        let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
                        let y = a * x * x + b * x + c
                        keyframes.append(CGPoint(x: x, y: y))
                    }
                }
                
                return keyframes
            }
            
            let playIconAnimation: (Double) -> Void = { duration in
                self.avatarNode.contentNode.alpha = 0.0
                self.avatarNode.contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration)
                self.avatarNode.contentNode.layer.animateScale(from: 1.0, to: 0.01, duration: duration, removeOnCompletion: false)
                
                if let view = self.animation.view as? LottieComponent.View {
                    view.alpha = 1.0
                    view.playOnce()
                }
            }
            
            if component.peer.id == component.context.account.peerId {
                playIconAnimation(0.2)
            }
            
            let offset = self.bounds.height - environment.inputHeight - self.backgroundView.frame.minY
            self.backgroundView.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.35, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                if component.peer.id != component.context.account.peerId {
                    playIconAnimation(0.1)
                }
                HapticFeedback().success()
            })
            
            if let component = self.component {
                let fromPoint = self.avatarNode.view.convert(component.sourceFrame.center, from: nil).offsetBy(dx: 0.0, dy: -offset)
                let positionValues = generateAvatarParabollicMotionKeyframes(from: fromPoint, to: .zero, elevation: 20.0)
                self.avatarNode.layer.animateKeyframes(values: positionValues.map { NSValue(cgPoint: $0) }, duration: 0.35, keyPath: "position", additive: true)
                self.avatarNode.layer.animateScale(from: component.sourceFrame.width / self.avatarNode.bounds.width, to: 1.0, duration: 0.35)
            }
                        
            if !self.isUpdating {
                self.state?.updated(transition: .spring(duration: 0.5))
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.backgroundView.layer.animateScale(from: 1.0, to: 0.96, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        
        func update(component: QuickShareToastScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            if self.component == nil {
                self.doneTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: { [weak self] _ in
                    guard let self, let controller = self.environment?.controller() as? QuickShareToastScreen else {
                        return
                    }
                    controller.dismissWithCommitAction()
                })
            }
            
            self.component = component
            self.environment = environment
            self.state = state
            
            let contentInsets = UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 10.0)
            
            let tabBarHeight = 49.0 + max(environment.safeInsets.bottom, environment.inputHeight)
            
            let containerInsets = UIEdgeInsets(
                top: environment.safeInsets.top,
                left: environment.safeInsets.left + 12.0,
                bottom: tabBarHeight + 3.0,
                right: environment.safeInsets.right + 12.0
            )
            
            let availableContentSize = CGSize(width: availableSize.width - containerInsets.left - containerInsets.right, height: availableSize.height - containerInsets.top - containerInsets.bottom)
            
            let spacing: CGFloat = 8.0
            
            let iconSize = CGSize(width: 30.0, height: 30.0)
            
            let tooltipText: String
            var overrideImage: AvatarNodeImageOverride?
            var animationName: String = "anim_forward"
            if component.peer.id == component.context.account.peerId {
                tooltipText = environment.strings.Conversation_ForwardTooltip_SavedMessages_One
                overrideImage = .savedMessagesIcon
                animationName = "anim_savedmessages"
            } else {
                tooltipText = environment.strings.Conversation_ForwardTooltip_Chat_One(component.peer.compactDisplayTitle).string
            }
            
            let actionButtonSize = self.actionButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.peer.id != component.context.account.peerId ? environment.strings.Undo_Undo : "", font: Font.regular(17.0), textColor: environment.theme.list.itemAccentColor.withMultiplied(hue: 0.933, saturation: 0.61, brightness: 1.0)))
                    )),
                    effectAlignment: .center,
                    contentInsets: UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0),
                    action: { [weak self] in
                        guard let self, let _ = self.component else {
                            return
                        }
                        self.doneTimer?.invalidate()
                        self.environment?.controller()?.dismiss()
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: availableContentSize.width - contentInsets.left - contentInsets.right - spacing - iconSize.width, height: availableContentSize.height)
            )
            
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .markdown(
                    text: tooltipText,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white),
                        bold: MarkdownAttributeSet(font: Font.semibold(14.0), textColor: environment.theme.list.itemAccentColor.withMultiplied(hue: 0.933, saturation: 0.61, brightness: 1.0)),
                        link: MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white),
                        linkAttribute: { _ in return nil })
                ))),
                environment: {},
                containerSize: CGSize(width: availableContentSize.width - contentInsets.left - contentInsets.right - spacing - iconSize.width - actionButtonSize.width - 16.0 - 4.0, height: availableContentSize.height)
            )
            
            var contentHeight: CGFloat = 0.0
            contentHeight += contentInsets.top + contentInsets.bottom + max(iconSize.height, contentSize.height)
                        
            let avatarFrame = CGRect(origin: CGPoint(x: contentInsets.left, y: floor((contentHeight - iconSize.height) * 0.5)), size: iconSize)
            self.avatarNode.setPeer(context: component.context, theme: environment.theme, peer: component.peer, overrideImage: overrideImage, synchronousLoad: true)
            self.avatarNode.updateSize(size: avatarFrame.size)
            transition.setFrame(view: self.avatarNode.view, frame: avatarFrame)
    
            let _ = self.animation.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(
                        name: animationName
                    ),
                    size: CGSize(width: 38.0, height: 38.0),
                    loop: false
                )),
                environment: {},
                containerSize: iconSize
            )
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    animationView.alpha = 0.0
                    self.avatarNode.view.addSubview(animationView)
                }
                animationView.frame = CGRect(origin: .zero, size: iconSize).insetBy(dx: -2.0, dy: -2.0)
            }
            
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.contentView.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: contentInsets.left + iconSize.width + spacing, y: floor((contentHeight - contentSize.height) * 0.5)), size: contentSize))
            }
            
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.backgroundView.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: CGRect(origin: CGPoint(x: availableContentSize.width - contentInsets.right - 16.0 - actionButtonSize.width, y: floor((contentHeight - actionButtonSize.height) * 0.5)), size: actionButtonSize))
            }
            
            let size = CGSize(width: availableContentSize.width, height: contentHeight)
            let backgroundFrame = CGRect(origin: CGPoint(x: containerInsets.left, y: availableSize.height - containerInsets.bottom - size.height), size: size)
            
            self.backgroundView.updateColor(color: UIColor(white: 0.0, alpha: 0.7), transition: transition.containedViewLayoutTransition)

            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: 14.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            transition.setFrame(view: self.contentView, frame: CGRect(origin: .zero, size: backgroundFrame.size))
            
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

public final class QuickShareToastScreen: ViewControllerComponentContainer {
    public enum Action {
        case info
        case commit
    }
    
    private var processedDidAppear: Bool = false
    private var processedDidDisappear: Bool = false
    
    private let action: (Action) -> Void
    
    public init(
        context: AccountContext,
        peer: EnginePeer,
        sourceFrame: CGRect,
        action: @escaping (Action) -> Void
    ) {
        self.action = action
        super.init(
            context: context,
            component: QuickShareToastScreenComponent(
                context: context,
                peer: peer,
                sourceFrame: sourceFrame,
                action: action
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            presentationMode: .default,
            updatedPresentationData: nil
        )
        self.navigationPresentation = .flatModal
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.processedDidAppear {
            self.processedDidAppear = true
            if let componentView = self.node.hostView.componentView as? QuickShareToastScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    private func superDismiss() {
        super.dismiss()
    }
    
    private var didCommit = false
    public func dismissWithCommitAction() {
        if !self.didCommit {
            self.didCommit = true
            self.action(.commit)
        }
        self.dismiss()
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        if !self.processedDidDisappear {
            self.processedDidDisappear = true
            
            if let componentView = self.node.hostView.componentView as? QuickShareToastScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    if let self {
                        self.superDismiss()
                    }
                    completion?()
                })
            } else {
                super.dismiss(completion: completion)
            }
        }
    }
}
