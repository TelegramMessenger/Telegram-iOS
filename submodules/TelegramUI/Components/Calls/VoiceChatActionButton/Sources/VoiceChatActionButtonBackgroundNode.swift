import Foundation
import UIKit
import AsyncDisplayKit
import Display

private let progressLineWidth: CGFloat = 3.0 + UIScreenPixel
private let buttonSize = CGSize(width: 112.0, height: 112.0)
private let radius = buttonSize.width / 2.0

private let areaSize = CGSize(width: 300.0, height: 300.0)
private let blobSize = CGSize(width: 190.0, height: 190.0)

private let secondaryGreyColor = UIColor(rgb: 0x1c1c1e)
private let whiteColor = UIColor(rgb: 0xffffff)
private let greyColor = UIColor(rgb: 0x2c2c2e)
private let blue = UIColor(rgb: 0x007fff)
private let lightBlue = UIColor(rgb: 0x00affe)
private let green = UIColor(rgb: 0x33c659)
private let activeBlue = UIColor(rgb: 0x00a0b9)
private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)

final class VoiceChatActionButtonBackgroundNode: ASDisplayNode {
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
    
    let maskProgressLayer = CAShapeLayer()
    
    private let maskMediumBlobLayer = CAShapeLayer()
    private let maskBigBlobLayer = CAShapeLayer()
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = false
    var ignoreHierarchyChanges = false
        
    override init() {
        self.state = .connecting
        
        self.maskBlobView = VoiceBlobView(frame: CGRect(origin: CGPoint(x: (areaSize.width - blobSize.width) / 2.0, y: (areaSize.height - blobSize.height) / 2.0), size: blobSize), maxLevel: 1.5, mediumBlobRange: (0.69, 0.87), bigBlobRange: (0.71, 1.0))
        self.maskBlobView.setColor(whiteColor)
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
        
        self.maskProgressLayer.strokeColor = whiteColor.cgColor
        self.maskProgressLayer.fillColor = UIColor.clear.cgColor
        self.maskProgressLayer.lineWidth = progressLineWidth
        self.maskProgressLayer.lineCap = .round
        self.maskProgressLayer.path = path
        
        let circleFrame = CGRect(origin: CGPoint(x: (areaSize.width - buttonSize.width) / 2.0, y: (areaSize.height - buttonSize.height) / 2.0), size: buttonSize).insetBy(dx: -progressLineWidth / 2.0, dy: -progressLineWidth / 2.0)
        let largerCirclePath = UIBezierPath(roundedRect: CGRect(x: circleFrame.minX, y: circleFrame.minY, width: circleFrame.width, height: circleFrame.height), cornerRadius: circleFrame.width / 2.0).cgPath
        
        self.maskCircleLayer.path = largerCirclePath
        self.maskCircleLayer.fillColor = whiteColor.cgColor
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
        if self.animationsEnabled {
            self.maskBlobView.startAnimating()
        }
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
        
        if self.animationsEnabled {
            self.maskBlobView.startAnimating()
        }
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
        if self.animationsEnabled {
            self.maskBlobView.startAnimating()
        }
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
                    if self.animationsEnabled {
                        self.maskBlobView.startAnimating()
                    }
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
        
        let path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: floor((self.bounds.height - VoiceChatActionButton.buttonHeight) / 2.0), width: self.bounds.width, height: VoiceChatActionButton.buttonHeight), cornerRadius: 10.0).cgPath
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
        if self.animationsEnabled {
            self.maskBlobView.startAnimating()
        }
        self.maskBlobView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, damping: 100.0)
        
        self.disableGlowAnimations = true
        self.maskGradientLayer.removeAllAnimations()
        self.maskGradientLayer.animateSpring(from: 0.3 as NSNumber, to: 0.85 as NSNumber, keyPath: "transform.scale", duration: 0.45, completion: { [weak self] _ in
            self?.disableGlowAnimations = false
        })
    }
    
    var animationsEnabled: Bool = true {
        didSet {
            self.updateAnimations()
        }
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
        
        if !self.animationsEnabled {
            self.foregroundGradientLayer.removeAllAnimations()
            self.maskBlobView.stopAnimating()
        } else {
            self.setupGradientAnimations()
        }
        
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
                    if self.animationsEnabled {
                        self.maskBlobView.startAnimating()
                    }
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
                        if self.animationsEnabled {
                            self.maskBlobView.startAnimating()
                        }
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
    
    func updateColors() {
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
