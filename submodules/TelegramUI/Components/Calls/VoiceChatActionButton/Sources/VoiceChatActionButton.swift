import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AnimationUI
import AppBundle
import ManagedAnimationNode
import ComponentFlow

private let titleFont = Font.regular(15.0)
private let subtitleFont = Font.regular(13.0)

private let smallScale: CGFloat = 0.48
private let smallIconScale: CGFloat = 0.69

public final class VoiceChatActionButton: HighlightTrackingButtonNode {
    static let buttonHeight: CGFloat = 52.0
    
    public enum State: Equatable {
        public enum ActiveState: Equatable {
            case cantSpeak
            case muted
            case on
        }
        
        public enum ScheduledState: Equatable {
            case start
            case subscribe
            case unsubscribe
        }

        case button(text: String)
        case scheduled(state: ScheduledState)
        case connecting
        case active(state: ActiveState)
    }
    
    public var stateValue: State {
        return self.currentParams?.state ?? .connecting
    }
    public var statePromise = ValuePromise<State>()
    public var state: Signal<State, NoError> {
        return self.statePromise.get()
    }
    
    public let bottomNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    private let backgroundNode: VoiceChatActionButtonBackgroundNode
    private let iconNode: VoiceChatActionButtonIconNode
    private let labelContainerNode: ASDisplayNode
    public let titleLabel: ImmediateTextNode
    private let subtitleLabel: ImmediateTextNode
    private let buttonTitleLabel: ImmediateTextNode
    
    private var currentParams: (size: CGSize, buttonSize: CGSize, state: VoiceChatActionButton.State, dark: Bool, small: Bool, title: String, subtitle: String, snap: Bool)?
    
    private var activePromise = ValuePromise<Bool>(false)
    private var outerColorPromise = Promise<(UIColor?, UIColor?)>((nil, nil))
    public var outerColor: Signal<(UIColor?, UIColor?), NoError> {
        return self.outerColorPromise.get()
    }
    
    public var connectingColor: UIColor = UIColor(rgb: 0xb6b6bb) {
        didSet {
            self.backgroundNode.connectingColor = self.connectingColor
        }
    }
    
    public var activeDisposable = MetaDisposable()
    
    public var isDisabled: Bool = false
    
    public var ignoreHierarchyChanges: Bool {
        get {
            return self.backgroundNode.ignoreHierarchyChanges
        } set {
            self.backgroundNode.ignoreHierarchyChanges = newValue
        }
    }
    
    public var wasActiveWhenPressed = false
    public var pressing: Bool = false {
        didSet {
            guard let (_, _, state, _, small, _, _, snap) = self.currentParams, !self.isDisabled else {
                return
            }
            if self.pressing {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                if small {
                    transition.updateTransformScale(node: self.backgroundNode, scale: smallScale * 0.9)
                    transition.updateTransformScale(node: self.iconNode, scale: smallIconScale * 0.9)
                } else {
                    transition.updateTransformScale(node: self.iconNode, scale: snap ? 0.5 : 0.9)
                }
                
                switch state {
                    case let .active(state):
                        switch state {
                            case .on:
                                self.wasActiveWhenPressed = true
                            default:
                                break
                        }
                    case .connecting, .button, .scheduled:
                        break
                }
            } else {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                if small {
                    transition.updateTransformScale(node: self.backgroundNode, scale: smallScale)
                    transition.updateTransformScale(node: self.iconNode, scale: smallIconScale)
                } else {
                    transition.updateTransformScale(node: self.iconNode, scale: snap ? 0.5 : 1.0)
                }
                self.wasActiveWhenPressed = false
            }
        }
    }
        
    public var animationsEnabled: Bool = true {
        didSet {
            self.backgroundNode.animationsEnabled = self.animationsEnabled
        }
    }
    
    public init() {
        self.bottomNode = ASDisplayNode()
        self.bottomNode.isUserInteractionEnabled = false
        self.containerNode = ASDisplayNode()
        self.containerNode.isUserInteractionEnabled = false
        self.backgroundNode = VoiceChatActionButtonBackgroundNode()
        self.iconNode = VoiceChatActionButtonIconNode(isColored: false)
        
        self.labelContainerNode = ASDisplayNode()
        self.titleLabel = ImmediateTextNode()
        self.subtitleLabel = ImmediateTextNode()
        self.buttonTitleLabel = ImmediateTextNode()
        self.buttonTitleLabel.isUserInteractionEnabled = false
        self.buttonTitleLabel.alpha = 0.0
        
        super.init()
    
        self.addSubnode(self.bottomNode)
        self.labelContainerNode.addSubnode(self.titleLabel)
        self.labelContainerNode.addSubnode(self.subtitleLabel)
        self.addSubnode(self.labelContainerNode)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.iconNode)
        
        self.containerNode.addSubnode(self.buttonTitleLabel)
        
        self.highligthedChanged = { [weak self] pressing in
            if let strongSelf = self {
                guard let (_, _, state, _, small, _, _, snap) = strongSelf.currentParams else {
                    return
                }
                if pressing {
                    if case .button = state {
                        strongSelf.containerNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.containerNode.alpha = 0.4
                    } else {
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                        if small {
                            transition.updateTransformScale(node: strongSelf.backgroundNode, scale: smallScale * 0.9)
                            transition.updateTransformScale(node: strongSelf.iconNode, scale: smallIconScale * 0.9)
                        } else {
                            transition.updateTransformScale(node: strongSelf.iconNode, scale: snap ? 0.5 : 0.9)
                        }
                    }
                } else if !strongSelf.pressing {
                    if case .button = state {
                        strongSelf.containerNode.alpha = 1.0
                        strongSelf.containerNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    } else {
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                        if small {
                            transition.updateTransformScale(node: strongSelf.backgroundNode, scale: smallScale)
                            transition.updateTransformScale(node: strongSelf.iconNode, scale: smallIconScale)
                        } else {
                            transition.updateTransformScale(node: strongSelf.iconNode, scale: snap ? 0.5 : 1.0)
                        }
                    }
                }
            }
        }
        
        self.backgroundNode.updatedActive = { [weak self] active in
            self?.activePromise.set(active)
        }
        
        self.backgroundNode.updatedColors = { [weak self] outerColor, activeColor in
            self?.outerColorPromise.set(.single((outerColor, activeColor)))
        }
    }
    
    deinit {
        self.activeDisposable.dispose()
    }
    
    public func updateLevel(_ level: CGFloat, immediately: Bool = false) {
        self.backgroundNode.audioLevel = level
    }
    
    private func applyParams(animated: Bool) {
        guard let (size, _, state, _, small, title, subtitle, snap) = self.currentParams else {
            return
        }
        
        let updatedTitle = self.titleLabel.attributedText?.string != title
        let updatedSubtitle = self.subtitleLabel.attributedText?.string != subtitle
        
        self.titleLabel.attributedText = NSAttributedString(string: title, font: titleFont, textColor: .white)
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, font: subtitleFont, textColor: .white)
                
        if animated && self.titleLabel.alpha > 0.0 {
            if let snapshotView = self.titleLabel.view.snapshotContentTree(), updatedTitle {
                self.titleLabel.view.superview?.insertSubview(snapshotView, belowSubview: self.titleLabel.view)
                snapshotView.frame = self.titleLabel.frame
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.titleLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            if let snapshotView = self.subtitleLabel.view.snapshotContentTree(), updatedSubtitle {
                self.subtitleLabel.view.superview?.insertSubview(snapshotView, belowSubview: self.subtitleLabel.view)
                snapshotView.frame = self.subtitleLabel.frame
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.subtitleLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
        }

        let titleSize = self.titleLabel.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleLabel.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        let totalHeight = titleSize.height + subtitleSize.height + 1.0

        self.labelContainerNode.frame = CGRect(origin: CGPoint(), size: size)
        
        let titleLabelFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - totalHeight) / 2.0) + 84.0), size: titleSize)
        let subtitleLabelFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: titleLabelFrame.maxY + 1.0), size: subtitleSize)
    
        self.titleLabel.bounds = CGRect(origin: CGPoint(), size: titleLabelFrame.size)
        self.titleLabel.position = titleLabelFrame.center
        self.subtitleLabel.bounds = CGRect(origin: CGPoint(), size: subtitleLabelFrame.size)
        self.subtitleLabel.position = subtitleLabelFrame.center
        
        self.bottomNode.frame = CGRect(origin: CGPoint(), size: size)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
        
        self.backgroundNode.bounds = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                
        var active = false
        switch state {
            case let .active(state):
                switch state {
                    case .on:
                        active = self.pressing && !self.wasActiveWhenPressed
                    default:
                        break
                }
            case .connecting, .button, .scheduled:
                break
        }
        
        if snap {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
            transition.updateTransformScale(node: self.backgroundNode, scale: active ? 0.9 : 0.625)
            transition.updateTransformScale(node: self.iconNode, scale: 0.625)
            transition.updateAlpha(node: self.titleLabel, alpha: 0.0)
            transition.updateAlpha(node: self.subtitleLabel, alpha: 0.0)
            transition.updateAlpha(layer: self.backgroundNode.maskProgressLayer, alpha: 0.0)
        } else {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
            if small {
                transition.updateTransformScale(node: self.backgroundNode, scale: self.pressing ? smallScale * 0.9 : smallScale, delay: 0.0)
                transition.updateTransformScale(node: self.iconNode, scale: self.pressing ? smallIconScale * 0.9 : smallIconScale, delay: 0.0)
                transition.updateAlpha(node: self.titleLabel, alpha: 0.0)
                transition.updateAlpha(node: self.subtitleLabel, alpha: 0.0)
                transition.updateSublayerTransformOffset(layer: self.labelContainerNode.layer, offset: CGPoint(x: 0.0, y: -43.0))
                transition.updateTransformScale(node: self.titleLabel, scale: 0.8)
                transition.updateTransformScale(node: self.subtitleLabel, scale: 0.8)
            } else {
                transition.updateTransformScale(node: self.backgroundNode, scale: 1.0, delay: 0.0)
                transition.updateTransformScale(node: self.iconNode, scale: self.pressing ? 0.9 : 1.0, delay: 0.0)
                transition.updateAlpha(node: self.titleLabel, alpha: 1.0, delay: 0.05)
                transition.updateAlpha(node: self.subtitleLabel, alpha: 1.0, delay: 0.05)
                transition.updateSublayerTransformOffset(layer: self.labelContainerNode.layer, offset: CGPoint())
                transition.updateTransformScale(node: self.titleLabel, scale: 1.0)
                transition.updateTransformScale(node: self.subtitleLabel, scale: 1.0)
            }
            transition.updateAlpha(layer: self.backgroundNode.maskProgressLayer, alpha: 1.0)
        }
        
        let iconSize = CGSize(width: 100.0, height: 100.0)
        self.iconNode.bounds = CGRect(origin: CGPoint(), size: iconSize)
        self.iconNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
    
    private var previousIcon: VoiceChatActionButtonIconAnimationState?
    private func applyIconParams() {
        guard let (_, _, state, _, _, _, _, _) = self.currentParams else {
            return
        }
        
        let icon: VoiceChatActionButtonIconAnimationState
        switch state {
            case .button:
                icon = .empty
            case let .scheduled(state):
                switch state {
                    case .start:
                        icon = .start
                    case .subscribe:
                        icon = .subscribe
                    case .unsubscribe:
                        icon = .unsubscribe
                }
            case let .active(state):
                switch state {
                    case .on:
                        icon = .unmute
                    case .muted:
                        icon = .mute
                    case .cantSpeak:
                        icon = .hand
                }
            case .connecting:
                if let previousIcon = previousIcon {
                    icon = previousIcon
                } else {
                    icon = .mute
                }
        }
        self.previousIcon = icon
        
        self.iconNode.enqueueState(icon)
    }
    
    public func update(snap: Bool, animated: Bool) {
        if let previous = self.currentParams {
            self.currentParams = (previous.size, previous.buttonSize, previous.state, previous.dark, previous.small, previous.title, previous.subtitle, snap)
            
            self.backgroundNode.isSnap = snap
            self.backgroundNode.glowHidden = snap || previous.small
            self.backgroundNode.updateColors()
            self.applyParams(animated: animated)
            self.applyIconParams()
        }
    }
    
    public func update(size: CGSize, buttonSize: CGSize, state: VoiceChatActionButton.State, title: String, subtitle: String, dark: Bool, small: Bool, animated: Bool = false) {
        let previous = self.currentParams
        let previousState = previous?.state
        self.currentParams = (size, buttonSize, state, dark, small, title, subtitle, previous?.snap ?? false)

        self.statePromise.set(state)
        
        if let previousState = previousState, case .button = previousState, case .scheduled = state {
            self.buttonTitleLabel.alpha = 0.0
            self.buttonTitleLabel.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            self.buttonTitleLabel.layer.animateScale(from: 1.0, to: 0.001, duration: 0.24)
            
            self.iconNode.alpha = 1.0
            self.iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.iconNode.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.42, damping: 104.0)
        }
        
        var backgroundState: VoiceChatActionButtonBackgroundNode.State
        var animated = true
        switch state {
            case let .button(text):
                backgroundState = .button
                self.buttonTitleLabel.alpha = 1.0
                self.buttonTitleLabel.attributedText = NSAttributedString(string: text, font: Font.semibold(17.0), textColor: .white)
                let titleSize = self.buttonTitleLabel.updateLayout(CGSize(width: size.width, height: 100.0))
                self.buttonTitleLabel.frame = CGRect(origin: CGPoint(x: floor((self.bounds.width - titleSize.width) / 2.0), y: floor((self.bounds.height - titleSize.height) / 2.0)), size: titleSize)
            case .scheduled:
                backgroundState = .disabled
                if previousState == .connecting {
                    animated = false
                }
            case let .active(state):
                switch state {
                    case .on:
                        backgroundState = .blob(true)
                    case .muted:
                        backgroundState = .blob(false)
                    case .cantSpeak:
                        backgroundState = .disabled
                }
            case .connecting:
                backgroundState = .connecting
        }
        self.applyIconParams()
        
        self.backgroundNode.glowHidden = (self.currentParams?.snap ?? false) || small
        self.backgroundNode.isDark = dark
        self.backgroundNode.update(state: backgroundState, animated: animated)
        
        if case .active = state, let previousState = previousState, case .connecting = previousState, animated {
            self.activeDisposable.set((self.activePromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] active in
                if active {
                    self?.activeDisposable.set(nil)
                    self?.applyParams(animated: true)
                }
            }))
        } else {
            self.applyParams(animated: animated)
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var hitRect = self.bounds
        if let (_, buttonSize, state, _, _, _, _, _) = self.currentParams {
            if case .button = state {
                hitRect = CGRect(x: 0.0, y: floor((self.bounds.height - VoiceChatActionButton.buttonHeight) / 2.0), width: self.bounds.width, height: VoiceChatActionButton.buttonHeight)
            } else {
                hitRect = self.bounds.insetBy(dx: (self.bounds.width - buttonSize.width) / 2.0, dy: (self.bounds.height - buttonSize.height) / 2.0)
            }
        }
        let result = super.hitTest(point, with: event)
        if !hitRect.contains(point) {
            return nil
        }
        return result
    }
    
    public func playAnimation() {
        self.iconNode.playRandomAnimation()
    }
}

public extension UIBezierPath {
    static func smoothCurve(through points: [CGPoint], length: CGFloat, smoothness: CGFloat, curve: Bool = false) -> UIBezierPath {
        var smoothPoints = [SmoothPoint]()
        for index in (0 ..< points.count) {
            let prevIndex = index - 1
            let prev = points[prevIndex >= 0 ? prevIndex : points.count + prevIndex]
            let curr = points[index]
            let next = points[(index + 1) % points.count]

            let angle: CGFloat = {
                let dx = next.x - prev.x
                let dy = -next.y + prev.y
                let angle = atan2(dy, dx)
                if angle < 0 {
                    return abs(angle)
                } else {
                    return 2 * .pi - angle
                }
            }()

            smoothPoints.append(
                SmoothPoint(
                    point: curr,
                    inAngle: angle + .pi,
                    inLength: smoothness * distance(from: curr, to: prev),
                    outAngle: angle,
                    outLength: smoothness * distance(from: curr, to: next)
                )
            )
        }

        let resultPath = UIBezierPath()
        if curve {
            resultPath.move(to: CGPoint())
            resultPath.addLine(to: smoothPoints[0].point)
        } else {
            resultPath.move(to: smoothPoints[0].point)
        }

        let smoothCount = curve ? smoothPoints.count - 1 : smoothPoints.count
        for index in (0 ..< smoothCount) {
            let curr = smoothPoints[index]
            let next = smoothPoints[(index + 1) % points.count]
            let currSmoothOut = curr.smoothOut()
            let nextSmoothIn = next.smoothIn()
            resultPath.addCurve(to: next.point, controlPoint1: currSmoothOut, controlPoint2: nextSmoothIn)
        }
        if curve {
            resultPath.addLine(to: CGPoint(x: length, y: 0.0))
        }
        resultPath.close()
        return resultPath
    }

    static private func distance(from fromPoint: CGPoint, to toPoint: CGPoint) -> CGFloat {
        return sqrt((fromPoint.x - toPoint.x) * (fromPoint.x - toPoint.x) + (fromPoint.y - toPoint.y) * (fromPoint.y - toPoint.y))
    }

    struct SmoothPoint {
        let point: CGPoint

        let inAngle: CGFloat
        let inLength: CGFloat

        let outAngle: CGFloat
        let outLength: CGFloat

        func smoothIn() -> CGPoint {
            return smooth(angle: inAngle, length: inLength)
        }

        func smoothOut() -> CGPoint {
            return smooth(angle: outAngle, length: outLength)
        }

        private func smooth(angle: CGFloat, length: CGFloat) -> CGPoint {
            return CGPoint(
                x: point.x + length * cos(angle),
                y: point.y + length * sin(angle)
            )
        }
    }
}
