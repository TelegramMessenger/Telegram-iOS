import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import LegacyComponents

private let titleFont = Font.regular(17.0)
private let subtitleFont = Font.regular(13.0)

private let white = UIColor(rgb: 0xffffff)
private let greyColor = UIColor(rgb: 0x2c2c2e)
private let secondaryGreyColor = UIColor(rgb: 0x1c1c1e)
private let blue = UIColor(rgb: 0x0078ff)
private let lightBlue = UIColor(rgb: 0x59c7f8)
private let green = UIColor(rgb: 0x33c659)
private let activeBlue = UIColor(rgb: 0x00a0b9)
private let purple = UIColor(rgb: 0x6b81f0)
private let pink = UIColor(rgb: 0xd75a76)

private let areaSize = CGSize(width: 440.0, height: 440.0)
private let blobSize = CGSize(width: 244.0, height: 244.0)

final class VoiceChatActionButton: HighlightTrackingButtonNode {
    enum State: Equatable {
        enum ActiveState: Equatable {
            case cantSpeak
            case muted
            case on
        }

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
    private let iconNode: VoiceChatMicrophoneNode
    private let titleLabel: ImmediateTextNode
    private let subtitleLabel: ImmediateTextNode
    
    private var currentParams: (size: CGSize, buttonSize: CGSize, state: VoiceChatActionButton.State, dark: Bool, small: Bool, title: String, subtitle: String, snap: Bool)?
    
    private var activePromise = ValuePromise<Bool>(false)
    private var outerColorPromise = ValuePromise<UIColor?>(nil)
    var outerColor: Signal<UIColor?, NoError> {
        return outerColorPromise.get()
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
            guard let (_, _, state, _, _, _, _, snap) = self.currentParams, !self.isDisabled else {
                return
            }
            if self.pressing {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                transition.updateTransformScale(node: self.iconNode, scale: snap ? 0.5 : 0.9)
                
                switch state {
                    case let .active(state):
                        switch state {
                            case .on:
                                self.wasActiveWhenPressed = true
                            default:
                                break
                        }
                    case .connecting:
                        break
                }
            } else {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                transition.updateTransformScale(node: self.iconNode, scale: snap ? 0.5 : 1.0)
                self.wasActiveWhenPressed = false
            }
        }
    }
        
    init() {
        self.bottomNode = ASDisplayNode()
        self.containerNode = ASDisplayNode()
        self.backgroundNode = VoiceChatActionButtonBackgroundNode()
        self.iconNode = VoiceChatMicrophoneNode()
        
        self.titleLabel = ImmediateTextNode()
        self.subtitleLabel = ImmediateTextNode()
        
        super.init()
    
        self.addSubnode(self.bottomNode)
        self.addSubnode(self.titleLabel)
        self.addSubnode(self.subtitleLabel)

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.iconNode)
        
        self.highligthedChanged = { [weak self] pressing in
            if let strongSelf = self {
                guard let (_, _, _, _, _, _, _, snap) = strongSelf.currentParams, !strongSelf.isDisabled else {
                    return
                }
                if pressing {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.iconNode, scale: snap ? 0.5 : 0.9)
                } else if !strongSelf.pressing {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.iconNode, scale: snap ? 0.5 : 1.0)
                }
            }
        }
        
        self.backgroundNode.updatedActive = { [weak self] active in
            self?.activePromise.set(active)
        }
        
        self.backgroundNode.updatedOuterColor = { [weak self] color in
            self?.outerColorPromise.set(color)
        }
    }
    
    deinit {
        self.activeDisposable.dispose()
    }
    
    func updateLevel(_ level: CGFloat) {
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

        self.titleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor(size.height - totalHeight / 2.0) - 112.0), size: titleSize)
        self.subtitleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: self.titleLabel.frame.maxY + 1.0), size: subtitleSize)

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
            case .connecting:
                break
        }
        
        
        if snap {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
            transition.updateTransformScale(node: self.backgroundNode, scale: active ? 0.75 : 0.5)
            transition.updateTransformScale(node: self.iconNode, scale: 0.5)
            transition.updateAlpha(node: self.titleLabel, alpha: 0.0)
            transition.updateAlpha(node: self.subtitleLabel, alpha: 0.0)
            transition.updateAlpha(layer: self.backgroundNode.maskProgressLayer, alpha: 0.0)
        } else {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
            transition.updateTransformScale(node: self.backgroundNode, scale: small ? 0.85 : 1.0, delay: 0.05)
            transition.updateTransformScale(node: self.iconNode, scale: self.pressing ? 0.9 : 1.0, delay: 0.05)
            transition.updateAlpha(node: self.titleLabel, alpha: 1.0, delay: 0.05)
            transition.updateAlpha(node: self.subtitleLabel, alpha: 1.0, delay: 0.05)
            transition.updateAlpha(layer: self.backgroundNode.maskProgressLayer, alpha: 1.0)
        }
        
        let iconSize = CGSize(width: 90.0, height: 90.0)
        self.iconNode.bounds = CGRect(origin: CGPoint(), size: iconSize)
        self.iconNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
    
    private func applyIconParams() {
        guard let (_, _, state, _, _, _, _, snap) = self.currentParams else {
            return
        }
        
        var iconMuted = true
        var iconColor: UIColor = UIColor(rgb: 0xffffff)
        switch state {
            case let .active(state):
                switch state {
                    case .on:
                        iconMuted = false
                    case .muted:
                        break
                    case .cantSpeak:
                        if !snap {
                            iconColor = UIColor(rgb: 0xff3b30)
                        }
                }
            case .connecting:
                break
        }
        self.iconNode.update(state: VoiceChatMicrophoneNode.State(muted: iconMuted, color: iconColor), animated: true)
    }
    
    func update(snap: Bool, animated: Bool) {
        if let previous = self.currentParams {
            self.currentParams = (previous.size, previous.buttonSize, previous.state, previous.dark, previous.small, previous.title, previous.subtitle, snap)
            
            self.backgroundNode.isSnap = snap
            self.backgroundNode.glowHidden = snap
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
        
        var backgroundState: VoiceChatActionButtonBackgroundNode.State
        switch state {
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
        
        self.backgroundNode.isDark = dark
        self.backgroundNode.update(state: backgroundState, animated: true)
        
        if case .active = state, let previousState = previousState, case .connecting = previousState, animated {
            self.activeDisposable.set((self.activePromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] active in
                if active {
                    self?.activeDisposable.set(nil)
                    self?.applyParams(animated: true)
                }
            }))
        } else {
            applyParams(animated: animated)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var hitRect = self.bounds
        if let (_, buttonSize, _, _, _, _, _, _) = self.currentParams {
            hitRect = self.bounds.insetBy(dx: (self.bounds.width - buttonSize.width) / 2.0, dy: (self.bounds.height - buttonSize.height) / 2.0)
        }
        let result = super.hitTest(point, with: event)
        if !hitRect.contains(point) {
            return nil
        }
        return result
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
private let buttonSize = CGSize(width: 144.0, height: 144.0)
private let radius = buttonSize.width / 2.0

private final class VoiceChatActionButtonBackgroundNode: ASDisplayNode {
    enum State: Equatable {
        case connecting
        case disabled
        case blob(Bool)
    }
    
    private var state: State
    private var hasState = false
    
    private var transition: State?
    
    var audioLevel: CGFloat = 0.0  {
        didSet {
            self.maskBlobView.updateLevel(audioLevel)
        }
    }
    
    var updatedActive: ((Bool) -> Void)?
    var updatedOuterColor: ((UIColor?) -> Void)?
    
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
        self.foregroundGradientLayer.locations = [0.0, 0.85, 1.0]
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
        
        let largerCirclePath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: CGSize(width: buttonSize.width + progressLineWidth, height: buttonSize.height + progressLineWidth))).cgPath
        self.maskCircleLayer.fillColor = white.cgColor
        self.maskCircleLayer.path = largerCirclePath
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
                newValue = CGPoint(x: CGFloat.random(in: 0.9 ..< 1.0), y: CGFloat.random(in: 0.1 ..< 0.35))
            } else if self.maskBlobView.presentationAudioLevel > 0.01 {
                newValue = CGPoint(x: CGFloat.random(in: 0.77 ..< 0.95), y: CGFloat.random(in: 0.1 ..< 0.35))
            } else {
                newValue = CGPoint(x: CGFloat.random(in: 0.65 ..< 0.85), y: CGFloat.random(in: 0.1 ..< 0.45))
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
    
    func updateGlowAndGradientAnimations(active: Bool?, previousActive: Bool? = nil) {
        let effectivePreviousActive = previousActive ?? false
        
        let initialScale: CGFloat = ((self.maskGradientLayer.value(forKeyPath: "presentationLayer.transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (((self.maskGradientLayer.value(forKeyPath: "transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (effectivePreviousActive ? 0.95 : 0.8))
        let initialColors = self.foregroundGradientLayer.colors
        
        let outerColor: UIColor?
        let targetColors: [CGColor]
        let targetScale: CGFloat
        if let active = active {
            if active {
                targetColors = [activeBlue.cgColor, green.cgColor, green.cgColor]
                targetScale = 0.89
                outerColor = UIColor(rgb: 0x21674f)
            } else {
                targetColors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
                targetScale = 0.85
                outerColor = UIColor(rgb: 0x1d588d)
            }
        } else {
            targetColors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
            targetScale = 0.3
            outerColor = nil
        }
        self.updatedOuterColor?(outerColor)
        
        self.maskGradientLayer.transform = CATransform3DMakeScale(targetScale, targetScale, 1.0)
        if let _ = previousActive {
            self.maskGradientLayer.animateScale(from: initialScale, to: targetScale, duration: 0.3)
        } else {
            self.maskGradientLayer.animateSpring(from: initialScale as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", duration: 0.45)
        }
        
        self.foregroundGradientLayer.colors = targetColors
        self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
    }
    
    private func playConnectionDisappearanceAnimation() {
        let initialRotation: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.transform.rotation.z") as? NSNumber)?.floatValue ?? 0.0)
        let initialStrokeEnd: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.strokeEnd") as? NSNumber)?.floatValue ?? 1.0)
        
        self.maskProgressLayer.removeAnimation(forKey: "progressGrowth")
        self.maskProgressLayer.removeAnimation(forKey: "progressRotation")
        
        let duration: Double = (1.0 - Double(initialStrokeEnd)) * 0.6
        
        let growthAnimation = CABasicAnimation(keyPath: "strokeEnd")
        growthAnimation.fromValue = initialStrokeEnd
        growthAnimation.toValue = 0.0
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
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.maskProgressLayer.isHidden = true
            self.maskProgressLayer.removeAllAnimations()
            CATransaction.commit()
        }
        
        self.maskProgressLayer.add(groupAnimation, forKey: "progressDisappearance")
        CATransaction.commit()
    }
    
    var animatingDisappearance = false
    private func playBlobsDisappearanceAnimation() {
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
        self.updateGlowAndGradientAnimations(active: nil, previousActive: nil)
        
        self.maskBlobView.startAnimating()
        self.maskBlobView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.state != .connecting && strongSelf.state != .disabled {
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
        
        CATransaction.setCompletionBlock {
            self.animatingDisappearance = false
            if self.state != .connecting && self.state != .disabled {
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.disableGlowAnimations = false
            self.maskGradientLayer.isHidden = true
            self.maskCircleLayer.isHidden = true
            self.growingForegroundCircleLayer.isHidden = true
            self.growingForegroundCircleLayer.removeAllAnimations()
            CATransaction.commit()
        }
        
        self.growingForegroundCircleLayer.add(growthAnimation, forKey: "insideGrowth")
        CATransaction.commit()
    }
        
    private func playBlobsAppearanceAnimation(active: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.foregroundCircleLayer.isHidden = false
        self.maskCircleLayer.isHidden = false
        self.maskProgressLayer.isHidden = true
        self.maskGradientLayer.isHidden = false
        CATransaction.commit()
                
        self.disableGlowAnimations = true
        self.maskGradientLayer.removeAllAnimations()
        self.updateGlowAndGradientAnimations(active: active, previousActive: nil)
        
        self.maskBlobView.isHidden = false
        self.maskBlobView.startAnimating()
        self.maskBlobView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                
        CATransaction.begin()
        let shrinkAnimation = CABasicAnimation(keyPath: "transform.scale")
        shrinkAnimation.fromValue = 1.0
        shrinkAnimation.toValue = 0.0
        shrinkAnimation.duration = 0.15
        shrinkAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        
        CATransaction.setCompletionBlock {
            if case .blob = self.state {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.disableGlowAnimations = false
                self.foregroundCircleLayer.isHidden = true
                CATransaction.commit()
            }
        }
        
        self.foregroundCircleLayer.add(shrinkAnimation, forKey: "insideShrink")
        CATransaction.commit()
    }
    
    private func playConnectionAnimation(active: Bool, completion: @escaping () -> Void) {
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
            if case .blob = self.state {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.foregroundCircleLayer.isHidden = false
                self.maskCircleLayer.isHidden = false
                self.maskProgressLayer.isHidden = true
                self.maskGradientLayer.isHidden = false
                CATransaction.commit()
                
                completion()
                
                self.updateGlowAndGradientAnimations(active: active, previousActive: nil)
                
                self.maskBlobView.isHidden = false
                self.maskBlobView.startAnimating()
                self.maskBlobView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                
                self.updatedActive?(true)
                
                CATransaction.begin()
                let shrinkAnimation = CABasicAnimation(keyPath: "transform.scale")
                shrinkAnimation.fromValue = 1.0
                shrinkAnimation.toValue = 0.0
                shrinkAnimation.duration = 0.15
                shrinkAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
                
                CATransaction.setCompletionBlock {
                    if case .blob = self.state {
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        self.foregroundCircleLayer.isHidden = true
                        CATransaction.commit()
                    }
                }
                
                self.foregroundCircleLayer.add(shrinkAnimation, forKey: "insideShrink")
                CATransaction.commit()
            }
        }

        self.maskProgressLayer.add(groupAnimation, forKey: "progressCompletion")
        CATransaction.commit()
    }
    
    var isActive = false
    func updateAnimations() {
        if !self.isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
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
                        playBlobsDisappearanceAnimation()
                    }
                    self.transition = nil
                }
                self.setupProgressAnimations()
                self.isActive = false
            case let .blob(newActive):
                if let transition = self.transition {
                    if transition == .connecting {
                        self.playConnectionAnimation(active: newActive) { [weak self] in
                            self?.isActive = newActive
                        }
                    } else if transition == .disabled {
                        self.playBlobsAppearanceAnimation(active: newActive)
                        self.transition = nil
                        self.isActive = newActive
                        self.updatedActive?(true)
                    } else if case let .blob(previousActive) = transition {
                        updateGlowAndGradientAnimations(active: newActive, previousActive: previousActive)
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
                self.updateGlowScale(nil)
                
                if let transition = self.transition {
                    if case .connecting = transition {
                        playConnectionDisappearanceAnimation()
                    } else if case .blob = transition {
                        playBlobsDisappearanceAnimation()
                    }
                    self.transition = nil
                }
                break
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
    
    override func layout() {
        super.layout()
        
        let center = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
        
        let circleFrame = CGRect(origin: CGPoint(x: (self.bounds.width - buttonSize.width) / 2.0, y: (self.bounds.height - buttonSize.height) / 2.0), size: buttonSize)
        self.backgroundCircleLayer.frame = circleFrame
        self.foregroundCircleLayer.position = center
        self.foregroundCircleLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: circleFrame.width - progressLineWidth, height: circleFrame.height - progressLineWidth))
        self.growingForegroundCircleLayer.position = center
        self.growingForegroundCircleLayer.bounds = self.foregroundCircleLayer.bounds
        self.maskCircleLayer.frame = circleFrame.insetBy(dx: -progressLineWidth / 2.0, dy: -progressLineWidth / 2.0)
        self.maskProgressLayer.frame = circleFrame.insetBy(dx: -3.0, dy: -3.0)
        self.foregroundView.frame = self.bounds
        self.foregroundGradientLayer.frame = self.bounds
        self.maskGradientLayer.position = center
        self.maskGradientLayer.bounds = self.bounds
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
    
    public init(
        frame: CGRect,
        maxLevel: CGFloat,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
    ) {
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
        
        addSubview(bigBlob)
        addSubview(mediumBlob)
        
        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
        mediumBlob.setColor(color.withAlphaComponent(0.55))
        bigBlob.setColor(color.withAlphaComponent(0.35))
    }
    
    public func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        mediumBlob.updateSpeedLevel(to: normalizedLevel)
        bigBlob.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
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
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let lv = minScale + (maxScale - minScale) * level
            shapeLayer.transform = CATransform3DMakeScale(lv, lv, 1)
            self.scaleUpdated?(level)
            CATransaction.commit()
        }
    }
    
    private var speedLevel: CGFloat = 0
    private var lastSpeedLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
    
    private var transition: CGFloat = 0 {
        didSet {
            guard let currentPoints = currentPoints else { return }
            
            shapeLayer.path = UIBezierPath.smoothCurve(through: currentPoints, length: bounds.width, smoothness: smoothness).cgPath
        }
    }
    
    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?
    
    private var currentPoints: [CGPoint]? {
        guard let fromPoints = fromPoints, let toPoints = toPoints else { return nil }
        
        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(
                x: fromPoint.x + (toPoint.x - fromPoint.x) * transition,
                y: fromPoint.y + (toPoint.y - fromPoint.y) * transition
            )
        }
    }
    
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
        
        layer.addSublayer(shapeLayer)
        
        shapeLayer.transform = CATransform3DMakeScale(minScale, minScale, 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor) {
        shapeLayer.fillColor = color.cgColor
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)
        
//        if abs(lastSpeedLevel - newSpeedLevel) > 0.45 {
//            animateToNewShape()
//        }
    }
    
    func startAnimating() {
        animateToNewShape()
    }
    
    func stopAnimating() {
        fromPoints = currentPoints
        toPoints = nil
        pop_removeAnimation(forKey: "blob")
    }
    
    private func animateToNewShape() {
        if pop_animation(forKey: "blob") != nil {
            fromPoints = currentPoints
            toPoints = nil
            pop_removeAnimation(forKey: "blob")
        }
        
        if fromPoints == nil {
            fromPoints = generateNextBlob(for: bounds.size)
        }
        if toPoints == nil {
            toPoints = generateNextBlob(for: bounds.size)
        }
        
        let animation = POPBasicAnimation()
        animation.property = POPAnimatableProperty.property(withName: "blob.transition", initializer: { property in
            property?.readBlock = { blobView, values in
                guard let blobView = blobView as? BlobView, let values = values else { return }
                
                values.pointee = blobView.transition
            }
            property?.writeBlock = { blobView, values in
                guard let blobView = blobView as? BlobView, let values = values else { return }
                
                blobView.transition = values.pointee
            }
        })  as? POPAnimatableProperty
        animation.completionBlock = { [weak self] animation, finished in
            if finished {
                self?.fromPoints = self?.currentPoints
                self?.toPoints = nil
                self?.animateToNewShape()
            }
        }
        animation.duration = CFTimeInterval(1 / (minSpeed + (maxSpeed - minSpeed) * speedLevel))
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fromValue = 0
        animation.toValue = 1
        pop_add(animation, forKey: "blob")
        
        lastSpeedLevel = speedLevel
        speedLevel = 0
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
