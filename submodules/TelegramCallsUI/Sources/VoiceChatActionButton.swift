import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AnimationUI
import AppBundle
import ManagedAnimationNode

private let titleFont = Font.regular(15.0)
private let subtitleFont = Font.regular(13.0)

private let white = UIColor(rgb: 0xffffff)
private let greyColor = UIColor(rgb: 0x2c2c2e)
private let secondaryGreyColor = UIColor(rgb: 0x1c1c1e)
private let blue = UIColor(rgb: 0x007fff)
private let lightBlue = UIColor(rgb: 0x00affe)
private let green = UIColor(rgb: 0x33c659)
private let activeBlue = UIColor(rgb: 0x00a0b9)
private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)

private let areaSize = CGSize(width: 300.0, height: 300.0)
private let blobSize = CGSize(width: 190.0, height: 190.0)

private let smallScale: CGFloat = 0.48
private let smallIconScale: CGFloat = 0.69

private let buttonHeight: CGFloat = 52.0

final class VoiceChatActionButton: HighlightTrackingButtonNode {
    enum State: Equatable {
        enum ActiveState: Equatable {
            case cantSpeak
            case muted
            case on
        }
        
        enum ScheduledState: Equatable {
            case start
            case subscribe
            case unsubscribe
        }

        case button(text: String)
        case scheduled(state: ScheduledState)
        case connecting
        case active(state: ActiveState)
    }
    
    var stateValue: State {
        return self.currentParams?.state ?? .connecting
    }
    var statePromise = ValuePromise<State>()
    var state: Signal<State, NoError> {
        return self.statePromise.get()
    }
    
    let bottomNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    private let backgroundNode: VoiceChatActionButtonBackgroundNode
    private let iconNode: VoiceChatActionButtonIconNode
    private let labelContainerNode: ASDisplayNode
    let titleLabel: ImmediateTextNode
    private let subtitleLabel: ImmediateTextNode
    private let buttonTitleLabel: ImmediateTextNode
    
    private var currentParams: (size: CGSize, buttonSize: CGSize, state: VoiceChatActionButton.State, dark: Bool, small: Bool, title: String, subtitle: String, snap: Bool)?
    
    private var activePromise = ValuePromise<Bool>(false)
    private var outerColorPromise = Promise<(UIColor?, UIColor?)>((nil, nil))
    var outerColor: Signal<(UIColor?, UIColor?), NoError> {
        return self.outerColorPromise.get()
    }
    
    var connectingColor: UIColor = UIColor(rgb: 0xb6b6bb) {
        didSet {
            self.backgroundNode.connectingColor = self.connectingColor
        }
    }
    
    var activeDisposable = MetaDisposable()
    
    var isDisabled: Bool = false
    
    var ignoreHierarchyChanges: Bool {
        get {
            return self.backgroundNode.ignoreHierarchyChanges
        } set {
            self.backgroundNode.ignoreHierarchyChanges = newValue
        }
    }
    
    var wasActiveWhenPressed = false
    var pressing: Bool = false {
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
        
    init() {
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
    
    func updateLevel(_ level: CGFloat, immediately: Bool = false) {
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
    
    func update(snap: Bool, animated: Bool) {
        if let previous = self.currentParams {
            self.currentParams = (previous.size, previous.buttonSize, previous.state, previous.dark, previous.small, previous.title, previous.subtitle, snap)
            
            self.backgroundNode.isSnap = snap
            self.backgroundNode.glowHidden = snap || previous.small
            self.backgroundNode.updateColors()
            self.applyParams(animated: animated)
            self.applyIconParams()
        }
    }
    
    func update(size: CGSize, buttonSize: CGSize, state: VoiceChatActionButton.State, title: String, subtitle: String, dark: Bool, small: Bool, animated: Bool = false) {
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var hitRect = self.bounds
        if let (_, buttonSize, state, _, _, _, _, _) = self.currentParams {
            if case .button = state {
                hitRect = CGRect(x: 0.0, y: floor((self.bounds.height - buttonHeight) / 2.0), width: self.bounds.width, height: buttonHeight)
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
    
    func playAnimation() {
        self.iconNode.playRandomAnimation()
    }
}

extension UIBezierPath {
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

private let progressLineWidth: CGFloat = 3.0 + UIScreenPixel
private let buttonSize = CGSize(width: 112.0, height: 112.0)
private let radius = buttonSize.width / 2.0

private final class VoiceChatActionButtonBackgroundNode: ASDisplayNode {
    enum State: Equatable {
        case connecting
        case disabled
        case button
        case blob(Bool)
    }
    
    private var state: State
    private var hasState = false
    
    private var transition: State?
    
    var audioLevel: CGFloat = 0.0  {
        didSet {
            self.maskBlobView.updateLevel(self.audioLevel, immediately: false)
        }
    }
    
    
    
    var updatedActive: ((Bool) -> Void)?
    var updatedColors: ((UIColor?, UIColor?) -> Void)?
    
    private let backgroundCircleLayer = CAShapeLayer()
    private let foregroundCircleLayer = CAShapeLayer()
    private let growingForegroundCircleLayer = CAShapeLayer()
    
    private let foregroundView = UIView()
    private let foregroundGradientLayer = CAGradientLayer()
    
    private let maskView = UIView()
    private let maskGradientLayer = CAGradientLayer()
    private let maskBlobView: VoiceBlobView
    private let maskCircleLayer = CAShapeLayer()
    
    fileprivate let maskProgressLayer = CAShapeLayer()
    
    private let maskMediumBlobLayer = CAShapeLayer()
    private let maskBigBlobLayer = CAShapeLayer()
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = false
    var ignoreHierarchyChanges = false
        
    override init() {
        self.state = .connecting
        
        self.maskBlobView = VoiceBlobView(frame: CGRect(origin: CGPoint(x: (areaSize.width - blobSize.width) / 2.0, y: (areaSize.height - blobSize.height) / 2.0), size: blobSize), maxLevel: 1.5, mediumBlobRange: (0.69, 0.87), bigBlobRange: (0.71, 1.0))
        self.maskBlobView.setColor(white)
        self.maskBlobView.isHidden = true
        
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()
        
        self.addSubnode(self.hierarchyTrackingNode)
        
        let circlePath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: buttonSize)).cgPath
        self.backgroundCircleLayer.fillColor = greyColor.cgColor
        self.backgroundCircleLayer.path = circlePath
        
        let smallerCirclePath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: CGSize(width: buttonSize.width - progressLineWidth, height: buttonSize.height - progressLineWidth))).cgPath
        self.foregroundCircleLayer.fillColor = greyColor.cgColor
        self.foregroundCircleLayer.path = smallerCirclePath
        self.foregroundCircleLayer.transform = CATransform3DMakeScale(0.0, 0.0, 1)
        self.foregroundCircleLayer.isHidden = true
        
        self.growingForegroundCircleLayer.fillColor = greyColor.cgColor
        self.growingForegroundCircleLayer.path = smallerCirclePath
        self.growingForegroundCircleLayer.transform = CATransform3DMakeScale(1.0, 1.0, 1)
        self.growingForegroundCircleLayer.isHidden = true
        
        self.foregroundGradientLayer.type = .radial
        self.foregroundGradientLayer.colors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
        self.foregroundGradientLayer.locations = [0.0, 0.55, 1.0]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        
        self.maskView.backgroundColor = .clear
        
        self.maskGradientLayer.type = .radial
        self.maskGradientLayer.colors = [UIColor(rgb: 0xffffff, alpha: 0.4).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
        self.maskGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.maskGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.maskGradientLayer.transform = CATransform3DMakeScale(0.3, 0.3, 1.0)
        self.maskGradientLayer.isHidden = true
        
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: (buttonSize.width + 6.0) / 2.0, y: (buttonSize.height + 6.0) / 2.0), radius: radius, startAngle: 0.0, endAngle: CGFloat.pi * 2.0, clockwise: true)
        
        self.maskProgressLayer.strokeColor = white.cgColor
        self.maskProgressLayer.fillColor = UIColor.clear.cgColor
        self.maskProgressLayer.lineWidth = progressLineWidth
        self.maskProgressLayer.lineCap = .round
        self.maskProgressLayer.path = path
        
        let circleFrame = CGRect(origin: CGPoint(x: (areaSize.width - buttonSize.width) / 2.0, y: (areaSize.height - buttonSize.height) / 2.0), size: buttonSize).insetBy(dx: -progressLineWidth / 2.0, dy: -progressLineWidth / 2.0)
        let largerCirclePath = UIBezierPath(roundedRect: CGRect(x: circleFrame.minX, y: circleFrame.minY, width: circleFrame.width, height: circleFrame.height), cornerRadius: circleFrame.width / 2.0).cgPath
        
        self.maskCircleLayer.path = largerCirclePath
        self.maskCircleLayer.fillColor = white.cgColor
        self.maskCircleLayer.isHidden = true
        
        updateInHierarchy = { [weak self] value in
            if let strongSelf = self, !strongSelf.ignoreHierarchyChanges {
                strongSelf.isCurrentlyInHierarchy = value
                strongSelf.updateAnimations()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.addSublayer(self.backgroundCircleLayer)
        
        self.view.addSubview(self.foregroundView)
        self.layer.addSublayer(self.foregroundCircleLayer)
        self.layer.addSublayer(self.growingForegroundCircleLayer)
    
        self.foregroundView.mask = self.maskView
        self.foregroundView.layer.addSublayer(self.foregroundGradientLayer)
          
        self.maskView.layer.addSublayer(self.maskGradientLayer)
        self.maskView.layer.addSublayer(self.maskProgressLayer)
        self.maskView.addSubview(self.maskBlobView)
        self.maskView.layer.addSublayer(self.maskCircleLayer)
        
        self.maskBlobView.scaleUpdated = { [weak self] scale in
            if let strongSelf = self {
                strongSelf.updateGlowScale(strongSelf.isActive ? scale : nil)
            }
        }
    }
        
    private func setupGradientAnimations() {
        if let _ = self.foregroundGradientLayer.animation(forKey: "movement") {
        } else {
            let previousValue = self.foregroundGradientLayer.startPoint
            let newValue: CGPoint
            if self.maskBlobView.presentationAudioLevel > 0.22 {
                newValue = CGPoint(x: CGFloat.random(in: 0.9 ..< 1.0), y: CGFloat.random(in: 0.15 ..< 0.35))
            } else if self.maskBlobView.presentationAudioLevel > 0.01 {
                newValue = CGPoint(x: CGFloat.random(in: 0.57 ..< 0.85), y: CGFloat.random(in: 0.15 ..< 0.45))
            } else {
                newValue = CGPoint(x: CGFloat.random(in: 0.6 ..< 0.75), y: CGFloat.random(in: 0.25 ..< 0.45))
            }
            self.foregroundGradientLayer.startPoint = newValue
            
            CATransaction.begin()
            
            let animation = CABasicAnimation(keyPath: "startPoint")
            animation.duration = Double.random(in: 0.8 ..< 1.4)
            animation.fromValue = previousValue
            animation.toValue = newValue
            
            CATransaction.setCompletionBlock { [weak self] in
                if let isCurrentlyInHierarchy = self?.isCurrentlyInHierarchy, isCurrentlyInHierarchy {
                    self?.setupGradientAnimations()
                }
            }
            
            self.foregroundGradientLayer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }
    
    private func setupProgressAnimations() {
        if let _ = self.maskProgressLayer.animation(forKey: "progressRotation") {
        } else {
            self.maskProgressLayer.isHidden = false
            
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            animation.duration = 1.0
            animation.fromValue = NSNumber(value: Float(0.0))
            animation.toValue = NSNumber(value: Float.pi * 2.0)
            animation.repeatCount = Float.infinity
            animation.beginTime = 0.0
            self.maskProgressLayer.add(animation, forKey: "progressRotation")
            
            let shrinkAnimation = CABasicAnimation(keyPath: "strokeEnd")
            shrinkAnimation.fromValue = 1.0
            shrinkAnimation.toValue = 0.0
            shrinkAnimation.duration = 1.0
            shrinkAnimation.beginTime = 0.0
            
            let growthAnimation = CABasicAnimation(keyPath: "strokeEnd")
            growthAnimation.fromValue = 0.0
            growthAnimation.toValue = 1.0
            growthAnimation.duration = 1.0
            growthAnimation.beginTime = 1.0
            
            let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotateAnimation.fromValue = 0.0
            rotateAnimation.toValue = CGFloat.pi * 2
            rotateAnimation.isAdditive = true
            rotateAnimation.duration = 1.0
            rotateAnimation.beginTime = 1.0
            
            let groupAnimation = CAAnimationGroup()
            groupAnimation.repeatCount = Float.infinity
            groupAnimation.animations = [shrinkAnimation, growthAnimation, rotateAnimation]
            groupAnimation.duration = 2.0
            
            self.maskProgressLayer.add(groupAnimation, forKey: "progressGrowth")
        }
    }
    
    var glowHidden: Bool = false {
        didSet {
            if self.glowHidden != oldValue {
                let initialAlpha = CGFloat(self.maskProgressLayer.opacity)
                let targetAlpha: CGFloat = self.glowHidden ? 0.0 : 1.0
                self.maskGradientLayer.opacity = Float(targetAlpha)
                self.maskGradientLayer.animateAlpha(from: initialAlpha, to: targetAlpha, duration: 0.2)
            }
        }
    }
    
    var disableGlowAnimations = false
    func updateGlowScale(_ scale: CGFloat?) {
        if self.disableGlowAnimations {
            return
        }
        if let scale = scale {
            self.maskGradientLayer.transform = CATransform3DMakeScale(0.89 + 0.11 * scale, 0.89 + 0.11 * scale, 1.0)
        } else {
            let initialScale: CGFloat = ((self.maskGradientLayer.value(forKeyPath: "presentationLayer.transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (((self.maskGradientLayer.value(forKeyPath: "transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (0.89))
            let targetScale: CGFloat = self.isActive ? 0.89 : 0.85
            if abs(targetScale - initialScale) > 0.03 {
                self.maskGradientLayer.transform = CATransform3DMakeScale(targetScale, targetScale, 1.0)
                self.maskGradientLayer.animateScale(from: initialScale, to: targetScale, duration: 0.3)
            }
        }
    }
    
    enum Gradient {
        case speaking
        case active
        case connecting
        case muted
    }
    
    func updateGlowAndGradientAnimations(type: Gradient, previousType: Gradient? = nil, animated: Bool = true) {
        let effectivePreviousTyoe = previousType ?? .active
        
        let scale: CGFloat
        if case .speaking = effectivePreviousTyoe {
            scale = 0.95
        } else {
            scale = 0.8
        }
        
        let initialScale: CGFloat = ((self.maskGradientLayer.value(forKeyPath: "presentationLayer.transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (((self.maskGradientLayer.value(forKeyPath: "transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? scale)
        let initialColors = self.foregroundGradientLayer.colors
        
        let outerColor: UIColor?
        let activeColor: UIColor?
        let targetColors: [CGColor]
        let targetScale: CGFloat
        switch type {
            case .speaking:
                targetColors = [activeBlue.cgColor, green.cgColor, green.cgColor]
                targetScale = 0.89
                outerColor = UIColor(rgb: 0x134b22)
                activeColor = green
            case .active:
                targetColors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
                targetScale = 0.85
                outerColor = UIColor(rgb: 0x002e5d)
                activeColor = blue
            case .connecting:
                targetColors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
                targetScale = 0.3
                outerColor = nil
                activeColor = blue
            case .muted:
                targetColors = [pink.cgColor, purple.cgColor, purple.cgColor]
                targetScale = 0.85
                outerColor = UIColor(rgb: 0x24306b)
                activeColor = purple
        }
        self.updatedColors?(outerColor, activeColor)
        
        self.maskGradientLayer.transform = CATransform3DMakeScale(targetScale, targetScale, 1.0)
        if let _ = previousType {
            self.maskGradientLayer.animateScale(from: initialScale, to: targetScale, duration: 0.3)
        } else if animated {
            self.maskGradientLayer.animateSpring(from: initialScale as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", duration: 0.45)
        }
        
        self.foregroundGradientLayer.colors = targetColors
        if animated {
            self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        }
    }
    
    private func playMuteAnimation() {
        self.maskBlobView.startAnimating()
        self.maskBlobView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.state != .connecting {
                return
            }
            strongSelf.maskBlobView.isHidden = true
            strongSelf.maskBlobView.stopAnimating()
            strongSelf.maskBlobView.layer.removeAllAnimations()
        })
    }
    
    var animatingDisappearance = false
    private func playDeactivationAnimation() {
        if self.animatingDisappearance {
            return
        }
        self.animatingDisappearance = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.growingForegroundCircleLayer.isHidden = false
        CATransaction.commit()
        
        self.disableGlowAnimations = true
        self.maskGradientLayer.removeAllAnimations()
        self.updateGlowAndGradientAnimations(type: .connecting, previousType: nil)
        
        self.maskBlobView.startAnimating()
        self.maskBlobView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.state != .connecting {
                return
            }
            strongSelf.maskBlobView.isHidden = true
            strongSelf.maskBlobView.stopAnimating()
            strongSelf.maskBlobView.layer.removeAllAnimations()
        })
        
        CATransaction.begin()
        let growthAnimation = CABasicAnimation(keyPath: "transform.scale")
        growthAnimation.fromValue = 0.0
        growthAnimation.toValue = 1.0
        growthAnimation.duration = 0.15
        growthAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        growthAnimation.isRemovedOnCompletion = false
        growthAnimation.fillMode = .forwards
        
        CATransaction.setCompletionBlock {
            self.animatingDisappearance = false
            self.growingForegroundCircleLayer.isHidden = true
            self.disableGlowAnimations = false
            if self.state != .connecting {
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.maskGradientLayer.isHidden = true
            self.maskCircleLayer.isHidden = true
            self.growingForegroundCircleLayer.removeAllAnimations()
            CATransaction.commit()
        }
        
        self.growingForegroundCircleLayer.add(growthAnimation, forKey: "insideGrowth")
        CATransaction.commit()
    }
            
    private func playActivationAnimation(active: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.maskCircleLayer.isHidden = false
        self.maskProgressLayer.isHidden = true
        self.maskGradientLayer.isHidden = false
        CATransaction.commit()
                
        self.maskGradientLayer.removeAllAnimations()
        self.updateGlowAndGradientAnimations(type: active ? .speaking : .active, previousType: nil)
        
        self.maskBlobView.isHidden = false
        self.maskBlobView.startAnimating()
        self.maskBlobView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
    }
        
    private func playConnectionAnimation(type: Gradient, completion: @escaping () -> Void) {
        CATransaction.begin()
        let initialRotation: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.transform.rotation.z") as? NSNumber)?.floatValue ?? 0.0)
        let initialStrokeEnd: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.strokeEnd") as? NSNumber)?.floatValue ?? 1.0)
        
        self.maskProgressLayer.removeAnimation(forKey: "progressGrowth")
        self.maskProgressLayer.removeAnimation(forKey: "progressRotation")
        
        let duration: Double = (1.0 - Double(initialStrokeEnd)) * 0.3
        
        let growthAnimation = CABasicAnimation(keyPath: "strokeEnd")
        growthAnimation.fromValue = initialStrokeEnd
        growthAnimation.toValue = 1.0
        growthAnimation.duration = duration
        growthAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotateAnimation.fromValue = initialRotation
        rotateAnimation.toValue = initialRotation + CGFloat.pi * 2
        rotateAnimation.isAdditive = true
        rotateAnimation.duration = duration
        rotateAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [growthAnimation, rotateAnimation]
        groupAnimation.duration = duration
        
        CATransaction.setCompletionBlock {
            var active = true
            if case .connecting = self.state {
                active = false
            }
            if active {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.foregroundCircleLayer.isHidden = false
                self.foregroundCircleLayer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
                self.maskCircleLayer.isHidden = false
                self.maskProgressLayer.isHidden = true
                self.maskGradientLayer.isHidden = false
                CATransaction.commit()
                
                completion()
                
                self.updateGlowAndGradientAnimations(type: type, previousType: nil)
                
                if case .connecting = self.state {
                } else {
                    self.maskBlobView.isHidden = false
                    self.maskBlobView.startAnimating()
                    self.maskBlobView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                }
                
                self.updatedActive?(true)
                
                CATransaction.begin()
                let shrinkAnimation = CABasicAnimation(keyPath: "transform.scale")
                shrinkAnimation.fromValue = 1.0
                shrinkAnimation.toValue = 0.00001
                shrinkAnimation.duration = 0.15
                shrinkAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
                shrinkAnimation.isRemovedOnCompletion = false
                shrinkAnimation.fillMode = .forwards
                
                CATransaction.setCompletionBlock {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.foregroundCircleLayer.isHidden = true
                    self.foregroundCircleLayer.transform = CATransform3DMakeScale(0.0, 0.0, 1.0)
                    self.foregroundCircleLayer.removeAllAnimations()
                    CATransaction.commit()
                }
                
                self.foregroundCircleLayer.add(shrinkAnimation, forKey: "insideShrink")
                CATransaction.commit()
            }
        }

        self.maskProgressLayer.add(groupAnimation, forKey: "progressCompletion")
        CATransaction.commit()
    }
    
    private var maskIsCircle = true
    private func setupButtonAnimation() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.backgroundCircleLayer.isHidden = true
        self.foregroundCircleLayer.isHidden = true
        self.maskCircleLayer.isHidden = false
        self.maskProgressLayer.isHidden = true
        self.maskGradientLayer.isHidden = true
        
        let path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: floor((self.bounds.height - buttonHeight) / 2.0), width: self.bounds.width, height: buttonHeight), cornerRadius: 10.0).cgPath
        self.maskCircleLayer.path = path
        self.maskIsCircle = false
        
        CATransaction.commit()
        
        self.updateGlowAndGradientAnimations(type: .muted, previousType: nil)
        
        self.updatedActive?(true)
    }
    
    private func playScheduledAnimation() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.maskGradientLayer.isHidden = false
        CATransaction.commit()
        
        let circleFrame = CGRect(origin: CGPoint(x: (self.bounds.width - buttonSize.width) / 2.0, y: (self.bounds.height - buttonSize.height) / 2.0), size: buttonSize).insetBy(dx: -progressLineWidth / 2.0, dy: -progressLineWidth / 2.0)
        let largerCirclePath = UIBezierPath(roundedRect: CGRect(x: circleFrame.minX, y: circleFrame.minY, width: circleFrame.width, height: circleFrame.height), cornerRadius: circleFrame.width / 2.0).cgPath
        
        let previousPath = self.maskCircleLayer.path
        self.maskCircleLayer.path = largerCirclePath
        self.maskIsCircle = true
        
        self.maskCircleLayer.animateSpring(from: previousPath as AnyObject, to: largerCirclePath as AnyObject, keyPath: "path", duration: 0.6, initialVelocity: 0.0, damping: 100.0)
        
        self.maskBlobView.isHidden = false
        self.maskBlobView.startAnimating()
        self.maskBlobView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, damping: 100.0)
        
        self.disableGlowAnimations = true
        self.maskGradientLayer.removeAllAnimations()
        self.maskGradientLayer.animateSpring(from: 0.3 as NSNumber, to: 0.85 as NSNumber, keyPath: "transform.scale", duration: 0.45, completion: { [weak self] _ in
            self?.disableGlowAnimations = false
        })
    }
    
    var isActive = false
    func updateAnimations() {
        if !self.isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
            self.growingForegroundCircleLayer.removeAllAnimations()
            self.maskGradientLayer.removeAllAnimations()
            self.maskProgressLayer.removeAllAnimations()
            self.maskBlobView.stopAnimating()
            return
        }
        self.setupGradientAnimations()
        
        switch self.state {
            case .connecting:
                self.updatedActive?(false)
                if let transition = self.transition {
                    self.updateGlowScale(nil)
                    if case .blob = transition {
                        self.playDeactivationAnimation()
                    } else if case .disabled = transition {
                        self.playDeactivationAnimation()
                    }
                    self.transition = nil
                }
                self.setupProgressAnimations()
                self.isActive = false
            case let .blob(newActive):
                if let transition = self.transition {
                    let type: Gradient = newActive ? .speaking : .active
                    if transition == .connecting {
                        self.playConnectionAnimation(type: type) { [weak self] in
                            self?.isActive = newActive
                        }
                    } else if transition == .disabled {
                        self.playActivationAnimation(active: newActive)
                        self.transition = nil
                        self.isActive = newActive
                        self.updatedActive?(true)
                    } else if case let .blob(previousActive) = transition {
                        self.updateGlowAndGradientAnimations(type: type, previousType: previousActive ? .speaking : .active)
                        self.transition = nil
                        self.isActive = newActive
                    }
                    self.transition = nil
                } else {
                    self.maskBlobView.startAnimating()
                }
            case .disabled:
                self.updatedActive?(true)
                self.isActive = false
                
                if let transition = self.transition {
                    if case .button = transition {
                        self.playScheduledAnimation()
                    } else if case .connecting = transition {
                        self.playConnectionAnimation(type: .muted) { [weak self] in
                            self?.isActive = false
                        }
                    } else if case let .blob(previousActive) = transition {
                        self.updateGlowAndGradientAnimations(type: .muted, previousType: previousActive ? .speaking : .active)
                        self.playMuteAnimation()
                    }
                    self.transition = nil
                } else {
                    if self.maskBlobView.isHidden {
                        self.updateGlowAndGradientAnimations(type: .muted, previousType: nil, animated: false)
                        self.maskCircleLayer.isHidden = false
                        self.maskProgressLayer.isHidden = true
                        self.maskGradientLayer.isHidden = false
                        self.maskBlobView.isHidden = false
                        self.maskBlobView.startAnimating()
                        self.maskBlobView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                    }
                }
            case .button:
                self.updatedActive?(true)
                self.isActive = false
                self.setupButtonAnimation()
        }
    }
    
    var isDark: Bool = false {
        didSet {
            if self.isDark != oldValue {
                self.updateColors()
            }
        }
    }
    
    var isSnap: Bool = false {
        didSet {
            if self.isSnap != oldValue {
                self.updateColors()
            }
        }
    }
    
    var connectingColor: UIColor = UIColor(rgb: 0xb6b6bb) {
        didSet {
            if self.connectingColor.rgb != oldValue.rgb {
                self.updateColors()
            }
        }
    }
    
    fileprivate func updateColors() {
        let previousColor: CGColor = self.backgroundCircleLayer.fillColor ?? greyColor.cgColor
        let targetColor: CGColor
        if self.isSnap {
            targetColor = self.connectingColor.cgColor
        } else if self.isDark {
            targetColor = secondaryGreyColor.cgColor
        } else {
            targetColor = greyColor.cgColor
        }
        self.backgroundCircleLayer.fillColor = targetColor
        self.foregroundCircleLayer.fillColor = targetColor
        self.growingForegroundCircleLayer.fillColor = targetColor
        self.backgroundCircleLayer.animate(from: previousColor, to: targetColor, keyPath: "fillColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        self.foregroundCircleLayer.animate(from: previousColor, to: targetColor, keyPath: "fillColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        self.growingForegroundCircleLayer.animate(from: previousColor, to: targetColor, keyPath: "fillColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
    }
    
    func update(state: State, animated: Bool) {
        var animated = animated
        var hadState = true
        if !self.hasState {
            hadState = false
            self.hasState = true
            animated = false
        }
        
        if state != self.state || !hadState {
            if animated {
                self.transition = self.state
            }
            self.state = state
        }
        
        self.updateAnimations()
    }
    
    var previousSize: CGSize?
    override func layout() {
        super.layout()
        
        let sizeUpdated = self.previousSize != self.bounds.size
        self.previousSize = self.bounds.size
        
        let bounds = CGRect(x: (self.bounds.width - areaSize.width) / 2.0, y: (self.bounds.height - areaSize.height) / 2.0, width: areaSize.width, height: areaSize.height)
        let center = bounds.center
        
        self.maskBlobView.frame = CGRect(origin: CGPoint(x: bounds.minX + (bounds.width - blobSize.width) / 2.0, y: bounds.minY + (bounds.height - blobSize.height) / 2.0), size: blobSize)
        
        let circleFrame = CGRect(origin: CGPoint(x: bounds.minX + (bounds.width - buttonSize.width) / 2.0, y: bounds.minY + (bounds.height - buttonSize.height) / 2.0), size: buttonSize)
        self.backgroundCircleLayer.frame = circleFrame
        self.foregroundCircleLayer.position = center
        self.foregroundCircleLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: circleFrame.width - progressLineWidth, height: circleFrame.height - progressLineWidth))
        self.growingForegroundCircleLayer.position = center
        self.growingForegroundCircleLayer.bounds = self.foregroundCircleLayer.bounds
        self.maskCircleLayer.frame = self.bounds

        if sizeUpdated && self.maskIsCircle {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let circleFrame = CGRect(origin: CGPoint(x: (self.bounds.width - buttonSize.width) / 2.0, y: (self.bounds.height - buttonSize.height) / 2.0), size: buttonSize).insetBy(dx: -progressLineWidth / 2.0, dy: -progressLineWidth / 2.0)
            let largerCirclePath = UIBezierPath(roundedRect: CGRect(x: circleFrame.minX, y: circleFrame.minY, width: circleFrame.width, height: circleFrame.height), cornerRadius: circleFrame.width / 2.0).cgPath
            
            self.maskCircleLayer.path = largerCirclePath
            CATransaction.commit()
        }
        
        self.maskProgressLayer.frame = circleFrame.insetBy(dx: -3.0, dy: -3.0)
        self.foregroundView.frame = self.bounds
        self.foregroundGradientLayer.frame = self.bounds
        self.maskGradientLayer.position = center
        self.maskGradientLayer.bounds = bounds
        self.maskView.frame = self.bounds
    }
}

private final class VoiceBlobView: UIView {
    private let mediumBlob: BlobView
    private let bigBlob: BlobView
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    
    var scaleUpdated: ((CGFloat) -> Void)? {
        didSet {
            self.bigBlob.scaleUpdated = self.scaleUpdated
        }
    }
    
    private(set) var isAnimating = false
    
    public typealias BlobRange = (min: CGFloat, max: CGFloat)

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true
    
    public init(
        frame: CGRect,
        maxLevel: CGFloat,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
    ) {
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        self.maxLevel = maxLevel
        
        self.mediumBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 0.9,
            maxSpeed: 4.0,
            minScale: mediumBlobRange.min,
            maxScale: mediumBlobRange.max
        )
        self.bigBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.0,
            maxSpeed: 4.4,
            minScale: bigBlobRange.min,
            maxScale: bigBlobRange.max
        )
        
        super.init(frame: frame)

        addSubnode(hierarchyTrackingNode)
        
        addSubview(bigBlob)
        addSubview(mediumBlob)
        
        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }

            if !strongSelf.isCurrentlyInHierarchy {
                return
            }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        }

        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
        mediumBlob.setColor(color.withAlphaComponent(0.5))
        bigBlob.setColor(color.withAlphaComponent(0.21))
    }
    
    public func updateLevel(_ level: CGFloat, immediately: Bool) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        mediumBlob.updateSpeedLevel(to: normalizedLevel)
        bigBlob.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
        if immediately {
            presentationAudioLevel = normalizedLevel
        }
    }
    
    public func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        isAnimating = false
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        if isAnimating {
            if mediumBlob.frame.size != .zero {
                mediumBlob.startAnimating()
                bigBlob.startAnimating()
            }
        } else {
            mediumBlob.stopAnimating()
            bigBlob.stopAnimating()
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        mediumBlob.frame = bounds
        bigBlob.frame = bounds
        
        updateBlobsState()
    }
}

final class BlobView: UIView {
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    let minScale: CGFloat
    let maxScale: CGFloat
    
    var scaleUpdated: ((CGFloat) -> Void)?
    
    var level: CGFloat = 0 {
        didSet {
            if abs(self.level - oldValue) > 0.01 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                let lv = self.minScale + (self.maxScale - self.minScale) * self.level
                self.shapeLayer.transform = CATransform3DMakeScale(lv, lv, 1)
                self.scaleUpdated?(self.level)
                CATransaction.commit()
            }
        }
    }
    
    private var speedLevel: CGFloat = 0
    private var lastSpeedLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
        
    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale
        
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2
        
        super.init(frame: .zero)
        
        self.layer.addSublayer(self.shapeLayer)
        
        self.shapeLayer.transform = CATransform3DMakeScale(minScale, minScale, 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor) {
        self.shapeLayer.fillColor = color.cgColor
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        self.speedLevel = max(self.speedLevel, newSpeedLevel)
        
//        if abs(lastSpeedLevel - newSpeedLevel) > 0.45 {
//            animateToNewShape()
//        }
    }
    
    func startAnimating() {
        self.animateToNewShape()
    }
    
    func stopAnimating() {
        self.shapeLayer.removeAnimation(forKey: "path")
    }
    
    private func animateToNewShape() {
        if self.shapeLayer.path == nil {
            let points = generateNextBlob(for: self.bounds.size)
            self.shapeLayer.path = UIBezierPath.smoothCurve(through: points, length: bounds.width, smoothness: smoothness).cgPath
        }
        
        let nextPoints = generateNextBlob(for: self.bounds.size)
        let nextPath = UIBezierPath.smoothCurve(through: nextPoints, length: bounds.width, smoothness: smoothness).cgPath
        
        let animation = CABasicAnimation(keyPath: "path")
        let previousPath = self.shapeLayer.path
        self.shapeLayer.path = nextPath
        animation.duration = CFTimeInterval(1.0 / (minSpeed + (maxSpeed - minSpeed) * speedLevel))
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fromValue = previousPath
        animation.toValue = nextPath
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.completion = { [weak self] finished in
            if finished {
                self?.animateToNewShape()
            }
        }

        self.shapeLayer.add(animation, forKey: "path")
        
        self.lastSpeedLevel = self.speedLevel
        self.speedLevel = 0
    }
    
    // MARK: Helpers
    
    private func generateNextBlob(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return blob(pointsCount: pointsCount, randomness: randomness)
            .map {
                return CGPoint(
                    x: $0.x * CGFloat(size.width),
                    y: $0.y * CGFloat(size.height)
                )
            }
    }
    
    func blob(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        
        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1 / (1 + randomness / 10)
        
        let startAngle = angle * CGFloat(arc4random_uniform(100)) / CGFloat(100)
        
        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let angleRandomness: CGFloat = angle * 0.1
            let randAngle = angle + angle * ((angleRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - angleRandomness * 0.5)
            let pointX = sin(startAngle + CGFloat(i) * randAngle)
            let pointY = cos(startAngle + CGFloat(i) * randAngle)
            return CGPoint(
                x: pointX * randPointOffset,
                y: pointY * randPointOffset
            )
        }
        
        return points
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }
}

enum VoiceChatActionButtonIconAnimationState: Equatable {
    case empty
    case start
    case subscribe
    case unsubscribe
    case unmute
    case mute
    case hand
}

final class VoiceChatActionButtonIconNode: ManagedAnimationNode {
    private let isColored: Bool
    private var iconState: VoiceChatActionButtonIconAnimationState = .mute
    
    init(isColored: Bool) {
        self.isColored = isColored
        super.init(size: CGSize(width: 100.0, height: 100.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceUnmute"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.1))
    }
    
    func enqueueState(_ state: VoiceChatActionButtonIconAnimationState) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        if state != .empty {
            self.alpha = 1.0
        }
        switch previousState {
            case .empty:
                switch state {
                    case .start:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceStart"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    default:
                        break
                }
            case .subscribe:
                switch state {
                    case .unsubscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminder")))
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminderToMute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminderToRaiseHand")))
                    default:
                        break
                }
            case .unsubscribe:
                switch state {
                    case .subscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminder")))
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminderToMute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminderToRaiseHand")))
                    default:
                        break
                }
            case .start:
                switch state {
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceStart")))
                    default:
                        break
                }
            case .unmute:
                switch state {
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceMute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceUnmuteToRaiseHand")))
                    default:
                        break
                }
            case .mute:
                switch state {
                    case .start:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceStart"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    case .unmute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceUnmute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceMuteToRaiseHand")))
                    case .subscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminderToRaiseHand"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    case .unsubscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminderToRaiseHand"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    case .empty:
                        self.alpha = 0.0
                    default:
                        break
                }
            case .hand:
                switch state {
                    case .mute, .unmute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceRaiseHandToMute")))
                    default:
                        break
                }
        }
    }
    
    func playRandomAnimation() {
        if case .hand = self.iconState {
            if let next = self.trackStack.first, case let .local(name) = next.source, name.hasPrefix("VoiceHand_") {
                return
            }
            
            var useTiredAnimation = false
            var useAngryAnimation = false
            let val = Float.random(in: 0.0..<1.0)
            if val <= 0.01 {
                useTiredAnimation = true
            } else if val <= 0.05 {
                useAngryAnimation = true
            }
            
            let normalAnimations = ["VoiceHand_1", "VoiceHand_2", "VoiceHand_3", "VoiceHand_4", "VoiceHand_7", "VoiceHand_8"]
            let tiredAnimations = ["VoiceHand_5", "VoiceHand_6"]
            let angryAnimations = ["VoiceHand_9", "VoiceHand_10"]
            let animations: [String]
            if useTiredAnimation {
                animations = tiredAnimations
            } else if useAngryAnimation {
                animations = angryAnimations
            } else {
                animations = normalAnimations
            }
            if let animationName = animations.randomElement() {
                self.trackTo(item: ManagedAnimationItem(source: .local(animationName)))
            }
        }
    }
}


final class VoiceChatRaiseHandNode: ASDisplayNode {
    private let animationNode: AnimationNode
    private let color: UIColor?
    private var playedOnce = false
    
    init(color: UIColor?) {
        self.color = color
        if let color = color, let url = getAppBundle().url(forResource: "anim_hand1", withExtension: "json"), let data = try? Data(contentsOf: url) {
            self.animationNode = AnimationNode(animationData: transformedWithColors(data: data, colors: [(UIColor(rgb: 0xffffff), color)]))
        } else {
            self.animationNode = AnimationNode(animation: "anim_hand1", colors: nil, scale: 0.5)
        }
        super.init()
        self.addSubnode(self.animationNode)
    }
    
    func playRandomAnimation() {
        guard self.playedOnce else {
            self.playedOnce = true
            self.animationNode.play()
            return
        }
        
        guard !self.animationNode.isPlaying else {
            self.animationNode.completion = { [weak self] in
                self?.playRandomAnimation()
            }
            return
        }
        
        self.animationNode.completion = nil
        if let animationName = ["anim_hand1", "anim_hand2", "anim_hand3", "anim_hand4"].randomElement() {
            if let color = color, let url = getAppBundle().url(forResource: animationName, withExtension: "json"), let data = try? Data(contentsOf: url) {
                self.animationNode.setAnimation(data: transformedWithColors(data: data, colors: [(UIColor(rgb: 0xffffff), color)]))
            } else {
                self.animationNode.setAnimation(name: animationName)
            }
            self.animationNode.play()
        }
    }
    
    override func layout() {
        super.layout()
        self.animationNode.frame = self.bounds
    }
}
