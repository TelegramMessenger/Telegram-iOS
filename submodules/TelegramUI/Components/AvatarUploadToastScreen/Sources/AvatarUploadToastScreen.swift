import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import AccountContext
import MultilineTextComponent
import RadialStatusNode
import SwiftSignalKit
import AnimatedTextComponent
import PlainButtonComponent

private final class AvatarUploadToastScreenComponent: Component {
    let context: AccountContext
    let image: UIImage
    let uploadStatus: Signal<PeerInfoAvatarUploadStatus, NoError>
    let arrowTarget: () -> (UIView, CGRect)?
    let viewUploadedAvatar: () -> Void
    
    init(context: AccountContext, image: UIImage, uploadStatus: Signal<PeerInfoAvatarUploadStatus, NoError>, arrowTarget: @escaping () -> (UIView, CGRect)?, viewUploadedAvatar: @escaping () -> Void) {
        self.context = context
        self.image = image
        self.uploadStatus = uploadStatus
        self.arrowTarget = arrowTarget
        self.viewUploadedAvatar = viewUploadedAvatar
    }
    
    static func ==(lhs: AvatarUploadToastScreenComponent, rhs: AvatarUploadToastScreenComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let contentView: UIView
        private let backgroundView: BlurredBackgroundView
        
        private let backgroundMaskView: UIView
        private let backgroundMainMaskView: UIView
        private let backgroundArrowMaskView: UIImageView
        
        private let avatarView: UIImageView
        private let progressNode: RadialStatusNode
        private let content = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        private var component: AvatarUploadToastScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        
        private var status: PeerInfoAvatarUploadStatus = .progress(0.0)
        private var statusDisposable: Disposable?
        
        private var doneTimer: Foundation.Timer?
        private var currentIsDone: Bool = false
        
        private var isDisplaying: Bool = false
        
        var targetAvatarView: UIView? {
            return self.avatarView
        }
        
        override init(frame: CGRect) {
            self.contentView = UIView()
            
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            self.backgroundMaskView = UIView()
            
            self.backgroundMainMaskView = UIView()
            self.backgroundMainMaskView.backgroundColor = .white
            
            self.backgroundArrowMaskView = UIImageView()
            
            self.avatarView = UIImageView()
            self.progressNode = RadialStatusNode(backgroundNodeColor: .clear)
            
            super.init(frame: frame)
            
            self.backgroundView.mask = self.backgroundMaskView
            self.backgroundMaskView.addSubview(self.backgroundMainMaskView)
            self.backgroundMaskView.addSubview(self.backgroundArrowMaskView)
            self.addSubview(self.backgroundView)
            
            self.addSubview(self.contentView)
            self.contentView.addSubview(self.avatarView)
            self.contentView.addSubview(self.progressNode.view)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.statusDisposable?.dispose()
            self.doneTimer?.invalidate()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.contentView.frame.contains(point) {
                return nil
            }
            return super.hitTest(point, with: event)
        }
        
        func animateIn() {
            func generateParabollicMotionKeyframes(from sourcePoint: CGFloat, elevation: CGFloat) -> [CGFloat] {
                let midPoint = sourcePoint - elevation
                
                let y1 = sourcePoint
                let y2 = midPoint
                let y3 = sourcePoint
                
                let x1 = 0.0
                let x2 = 100.0
                let x3 = 200.0
                
                var keyframes: [CGFloat] = []
                let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                
                for i in 0 ..< 10 {
                    let k = listViewAnimationCurveSystem(CGFloat(i) / CGFloat(10 - 1))
                    let x = x3 * k
                    let y = a * x * x + b * x + c
                    
                    keyframes.append(y)
                }
                
                return keyframes
            }
            let offsetValues = generateParabollicMotionKeyframes(from: 0.0, elevation: -10.0)
            self.layer.animateKeyframes(values: offsetValues.map { $0 as NSNumber }, duration: 0.5, keyPath: "position.y", additive: true)
            
            self.contentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.isDisplaying = true
            if !self.isUpdating {
                self.state?.updated(transition: .spring(duration: 0.5))
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
            self.contentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }
        
        func update(component: AvatarUploadToastScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            if self.component == nil {
                self.statusDisposable = (component.uploadStatus
                |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                    guard let self else {
                        return
                    }
                    self.status = status
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                    
                    if case .done = status, self.doneTimer == nil {
                        self.doneTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false, block: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.environment?.controller()?.dismiss()
                        })
                    }
                })
            }
            
            self.component = component
            self.environment = environment
            self.state = state
            
            var isDone = false
            let effectiveProgress: CGFloat
            switch self.status {
            case let .progress(value):
                effectiveProgress = CGFloat(value)
            case .done:
                isDone = true
                effectiveProgress = 1.0
            }
            let previousIsDone = self.currentIsDone
            self.currentIsDone = isDone
            
            let contentInsets = UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 10.0)
            
            let tabBarHeight: CGFloat
            if !environment.safeInsets.left.isZero {
                tabBarHeight = 34.0 + environment.safeInsets.bottom
            } else {
                tabBarHeight = 49.0 + environment.safeInsets.bottom
            }
            let containerInsets = UIEdgeInsets(
                top: environment.safeInsets.top,
                left: environment.safeInsets.left + 12.0,
                bottom: tabBarHeight + 3.0,
                right: environment.safeInsets.right + 12.0
            )
            
            let availableContentSize = CGSize(width: availableSize.width - containerInsets.left - containerInsets.right, height: availableSize.height - containerInsets.top - containerInsets.bottom)
            
            let spacing: CGFloat = 12.0
            
            let iconSize = CGSize(width: 30.0, height: 30.0)
            let iconProgressInset: CGFloat = 3.0
            
            let uploadingString = environment.strings.AvatarUpload_StatusUploading
            let doneString = environment.strings.AvatarUpload_StatusDone
            
            var commonPrefixLength = 0
            for i in 0 ..< min(uploadingString.count, doneString.count) {
                if uploadingString[uploadingString.index(uploadingString.startIndex, offsetBy: i)] != doneString[doneString.index(doneString.startIndex, offsetBy: i)] {
                    break
                }
                commonPrefixLength = i
            }
            
            var textItems: [AnimatedTextComponent.Item] = []
            
            if commonPrefixLength != 0 {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable(0), isUnbreakable: true, content: .text(String(uploadingString[uploadingString.startIndex ..< uploadingString.index(uploadingString.startIndex, offsetBy: commonPrefixLength)]))))
            }
            if isDone {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable(1), isUnbreakable: true, content: .text(String(doneString[doneString.index(doneString.startIndex, offsetBy: commonPrefixLength)...]))))
            } else {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable(1), isUnbreakable: true, content: .text(String(uploadingString[uploadingString.index(uploadingString.startIndex, offsetBy: commonPrefixLength)...]))))
            }
            
            let actionButtonSize = self.actionButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.AvatarUpload_ViewAction, font: Font.regular(17.0), textColor: environment.theme.list.itemAccentColor.withMultiplied(hue: 0.933, saturation: 0.61, brightness: 1.0)))
                    )),
                    effectAlignment: .center,
                    contentInsets: UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.doneTimer?.invalidate()
                        self.environment?.controller()?.dismiss()
                        component.viewUploadedAvatar()
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
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.regular(14.0),
                    color: .white,
                    items: textItems
                )),
                environment: {},
                containerSize: CGSize(width: availableContentSize.width - contentInsets.left - contentInsets.right - spacing - iconSize.width - actionButtonSize.width - 16.0 - 4.0, height: availableContentSize.height)
            )
            
            var contentHeight: CGFloat = 0.0
            contentHeight += contentInsets.top + contentInsets.bottom + max(iconSize.height, contentSize.height)
            
            if self.avatarView.image == nil {
                self.avatarView.image = generateImage(iconSize, rotatedContext: { size, context in
                    UIGraphicsPushContext(context)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
                    context.clip()
                    
                    component.image.draw(in: CGRect(origin: CGPoint(), size: size))
                })
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: contentInsets.left, y: floor((contentHeight - iconSize.height) * 0.5)), size: iconSize)
            
            var adjustedAvatarFrame = avatarFrame
            if !isDone {
                adjustedAvatarFrame = adjustedAvatarFrame.insetBy(dx: iconProgressInset, dy: iconProgressInset)
            }
            transition.setPosition(view: self.avatarView, position: adjustedAvatarFrame.center)
            transition.setBounds(view: self.avatarView, bounds: CGRect(origin: CGPoint(), size: adjustedAvatarFrame.size))
            if isDone && !previousIsDone {
                let topScale: CGFloat = 1.1
                self.avatarView.layer.animateScale(from: 1.0, to: topScale, duration: 0.16, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.avatarView.layer.animateScale(from: topScale, to: 1.0, duration: 0.16)
                })
                self.progressNode.layer.animateScale(from: 1.0, to: topScale, duration: 0.16, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.progressNode.layer.animateScale(from: topScale, to: 1.0, duration: 0.16)
                })
                HapticFeedback().success()
            }
            
            self.progressNode.frame = avatarFrame
            self.progressNode.transitionToState(.progress(color: .white, lineWidth: 1.0 + UIScreenPixel, value: effectiveProgress, cancelEnabled: false, animateRotation: true))
            transition.setAlpha(view: self.progressNode.view, alpha: isDone ? 0.0 : 1.0)
            
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.contentView.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: contentInsets.left + iconSize.width + spacing, y: floor((contentHeight - contentSize.height) * 0.5)), size: contentSize))
            }
            
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.contentView.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: CGRect(origin: CGPoint(x: availableContentSize.width - contentInsets.right - 16.0 - actionButtonSize.width, y: floor((contentHeight - actionButtonSize.height) * 0.5)), size: actionButtonSize))
                transition.setAlpha(view: actionButtonView, alpha: isDone ? 1.0 : 0.0)
            }
            
            let size = CGSize(width: availableContentSize.width, height: contentHeight)
            
            let contentFrame = CGRect(origin: CGPoint(x: containerInsets.left, y: availableSize.height - containerInsets.bottom - size.height), size: size)
            
            self.backgroundView.updateColor(color: self.isDisplaying ? UIColor(white: 0.0, alpha: 0.7) : UIColor.black, transition: transition.containedViewLayoutTransition)
            let backgroundFrame: CGRect
            if self.isDisplaying {
                backgroundFrame = contentFrame
            } else {
                backgroundFrame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.backgroundView.bounds.size != contentFrame.size {
                self.backgroundView.update(size: availableSize, cornerRadius: 0.0, transition: transition.containedViewLayoutTransition)
            }
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.backgroundMaskView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            transition.setCornerRadius(layer: self.backgroundMainMaskView.layer, cornerRadius: self.isDisplaying ? 14.0 : 0.0)
            transition.setFrame(view: self.backgroundMainMaskView, frame: backgroundFrame)
            
            if self.backgroundArrowMaskView.image == nil {
                let arrowFactor: CGFloat = 0.75
                let arrowSize = CGSize(width: floor(29.0 * arrowFactor), height: floor(10.0 * arrowFactor))
                self.backgroundArrowMaskView.image = generateImage(arrowSize, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.scaleBy(x: size.width / 29.0, y: size.height / 10.0)
                    context.setFillColor(UIColor.white.cgColor)
                    context.scaleBy(x: 0.333, y: 0.333)
                    let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
                    context.fillPath()
                })?.withRenderingMode(.alwaysTemplate)
            }
            
            if let arrowImage = self.backgroundArrowMaskView.image, let (targetView, targetRect) = component.arrowTarget() {
                let targetArrowRect = targetView.convert(targetRect, to: self)
                self.backgroundArrowMaskView.isHidden = false
                
                var arrowFrame = CGRect(origin: CGPoint(x: targetArrowRect.minX + floor((targetArrowRect.width - arrowImage.size.width) * 0.5), y: contentFrame.maxY), size: arrowImage.size)
                if !self.isDisplaying {
                    arrowFrame = arrowFrame.offsetBy(dx: 0.0, dy: -10.0)
                }
                transition.setFrame(view: self.backgroundArrowMaskView, frame: arrowFrame)
            } else {
                self.backgroundArrowMaskView.isHidden = true
            }
            
            transition.setFrame(view: self.contentView, frame: contentFrame)
            
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

public class AvatarUploadToastScreen: ViewControllerComponentContainer {
    public var targetAvatarView: UIView? {
        if let view = self.node.hostView.componentView as? AvatarUploadToastScreenComponent.View {
            return view.targetAvatarView
        }
        return nil
    }
    
    private var processedDidAppear: Bool = false
    private var processedDidDisappear: Bool = false
    
    public init(
        context: AccountContext,
        image: UIImage,
        uploadStatus: Signal<PeerInfoAvatarUploadStatus, NoError>,
        arrowTarget: @escaping () -> (UIView, CGRect)?,
        viewUploadedAvatar: @escaping () -> Void
    ) {
        super.init(
            context: context,
            component: AvatarUploadToastScreenComponent(
                context: context,
                image: image,
                uploadStatus: uploadStatus,
                arrowTarget: arrowTarget,
                viewUploadedAvatar: viewUploadedAvatar
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            presentationMode: .default,
            updatedPresentationData: nil
        )
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.processedDidAppear {
            self.processedDidAppear = true
            if let componentView = self.node.hostView.componentView as? AvatarUploadToastScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    private func superDismiss() {
        super.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.processedDidDisappear {
            self.processedDidDisappear = true
            
            if let componentView = self.node.hostView.componentView as? AvatarUploadToastScreenComponent.View {
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
