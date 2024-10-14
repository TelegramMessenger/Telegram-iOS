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
import MultilineTextComponent
import Markdown
import TextFormat
import RoundedRectWithTailPath

public class RemainingCountComponent: Component {
    private let inactiveColor: UIColor
    private let activeColors: [UIColor]
    private let inactiveTitle: String
    private let inactiveValue: String
    private let inactiveTitleColor: UIColor
    private let activeTitle: String
    private let activeValue: String
    private let activeTitleColor: UIColor
    private let badgeText: String?
    private let badgePosition: CGFloat
    private let badgeGraphPosition: CGFloat
    private let invertProgress: Bool
    private let leftString: String
    private let groupingSeparator: String
    
    public init(
        inactiveColor: UIColor,
        activeColors: [UIColor],
        inactiveTitle: String,
        inactiveValue: String,
        inactiveTitleColor: UIColor,
        activeTitle: String,
        activeValue: String,
        activeTitleColor: UIColor,
        badgeText: String?,
        badgePosition: CGFloat,
        badgeGraphPosition: CGFloat,
        invertProgress: Bool = false,
        leftString: String,
        groupingSeparator: String
    ) {
        self.inactiveColor = inactiveColor
        self.activeColors = activeColors
        self.inactiveTitle = inactiveTitle
        self.inactiveValue = inactiveValue
        self.inactiveTitleColor = inactiveTitleColor
        self.activeTitle = activeTitle
        self.activeValue = activeValue
        self.activeTitleColor = activeTitleColor
        self.badgeText = badgeText
        self.badgePosition = badgePosition
        self.badgeGraphPosition = badgeGraphPosition
        self.invertProgress = invertProgress
        self.leftString = leftString
        self.groupingSeparator = groupingSeparator
    }
    
    public static func ==(lhs: RemainingCountComponent, rhs: RemainingCountComponent) -> Bool {
        if lhs.inactiveColor != rhs.inactiveColor {
            return false
        }
        if lhs.activeColors != rhs.activeColors {
            return false
        }
        if lhs.inactiveTitle != rhs.inactiveTitle {
            return false
        }
        if lhs.inactiveValue != rhs.inactiveValue {
            return false
        }
        if lhs.inactiveTitleColor != rhs.inactiveTitleColor {
            return false
        }
        if lhs.activeTitle != rhs.activeTitle {
            return false
        }
        if lhs.activeValue != rhs.activeValue {
            return false
        }
        if lhs.activeTitleColor != rhs.activeTitleColor {
            return false
        }
        if lhs.badgeText != rhs.badgeText {
            return false
        }
        if lhs.badgePosition != rhs.badgePosition {
            return false
        }
        if lhs.badgeGraphPosition != rhs.badgeGraphPosition {
            return false
        }
        if lhs.invertProgress != rhs.invertProgress {
            return false
        }
        if lhs.leftString != rhs.leftString {
            return false
        }
        if lhs.groupingSeparator != rhs.groupingSeparator {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: RemainingCountComponent?
        
        private let container: UIView
        private let inactiveBackground: SimpleLayer
        
        private let inactiveTitleLabel = ComponentView<Empty>()
        private let inactiveValueLabel = ComponentView<Empty>()
        
        private let innerLeftTitleLabel = ComponentView<Empty>()
        private let innerRightTitleLabel = ComponentView<Empty>()
        
        private let activeContainer: UIView
        private let activeBackground: SimpleLayer
                
        private let activeTitleLabel = ComponentView<Empty>()
        private let activeValueLabel = ComponentView<Empty>()
        
        private let badgeView: UIView
        private let badgeMaskView: UIView
        private let badgeShapeLayer = CAShapeLayer()
        
        private let badgeForeground: SimpleLayer
        private var badgeLabel: BadgeLabelView?
        private let badgeLeftLabel = ComponentView<Empty>()
        private let badgeLabelMaskView = UIImageView()
        
        private var badgeTailPosition: CGFloat = 0.0
        private var badgeShapeArguments: (Double, Double, CGSize, CGFloat, CGFloat)?
                
        override init(frame: CGRect) {
            self.container = UIView()
            self.container.clipsToBounds = true
            self.container.layer.cornerRadius = 9.0
            
            self.inactiveBackground = SimpleLayer()
            
            self.activeContainer = UIView()
            self.activeContainer.clipsToBounds = true
            
            self.activeBackground = SimpleLayer()
            self.activeBackground.anchorPoint = CGPoint()
            
            self.badgeView = UIView()
            self.badgeView.alpha = 0.0
            
            self.badgeShapeLayer.fillColor = UIColor.white.cgColor
            self.badgeShapeLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            
            self.badgeMaskView = UIView()
            self.badgeMaskView.layer.addSublayer(self.badgeShapeLayer)
            self.badgeView.mask = self.badgeMaskView
            
            self.badgeForeground = SimpleLayer()
                                                
            super.init(frame: frame)
            
            self.addSubview(self.container)
            self.container.layer.addSublayer(self.inactiveBackground)
            self.container.addSubview(self.activeContainer)
            self.activeContainer.layer.addSublayer(self.activeBackground)
            
            self.addSubview(self.badgeView)
            self.badgeView.layer.addSublayer(self.badgeForeground)
            //self.badgeView.addSubview(self.badgeLabel)
            
            self.badgeLabelMaskView.contentMode = .scaleToFill
            self.badgeLabelMaskView.image = generateImage(CGSize(width: 2.0, height: 30.0), rotatedContext: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                
                let colorsArray: [CGColor] = [
                    UIColor(rgb: 0xffffff, alpha: 0.0).cgColor,
                    UIColor(rgb: 0xffffff).cgColor,
                    UIColor(rgb: 0xffffff).cgColor,
                    UIColor(rgb: 0xffffff, alpha: 0.0).cgColor,
                ]
                var locations: [CGFloat] = [0.0, 0.24, 0.76, 1.0]
                let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
            
            self.isUserInteractionEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.badgeShapeAnimator?.invalidate()
        }
        
        private var didPlayAppearanceAnimation = false
        func playAppearanceAnimation(component: RemainingCountComponent, badgeFullSize: CGSize, from: CGFloat? = nil) {
            if from == nil {
                self.badgeView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.4, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
            }
            
            let rotationAngle: CGFloat
            if badgeFullSize.width > 100.0 {
                rotationAngle = 0.2
            } else {
                rotationAngle = 0.26
            }
            
            let to: CGFloat = self.badgeView.center.x
            
            let positionAnimation = CABasicAnimation(keyPath: "position.x")
            positionAnimation.fromValue = NSValue(cgPoint: CGPoint(x: from ?? self.container.frame.width, y: 0.0))
            positionAnimation.toValue = NSValue(cgPoint: CGPoint(x: to, y: 0.0))
            positionAnimation.duration = 0.5
            positionAnimation.fillMode = .forwards
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.badgeView.layer.add(positionAnimation, forKey: "appearance1")
           
            if from != to {
                let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotateAnimation.fromValue = 0.0 as NSNumber
                rotateAnimation.toValue = rotationAngle as NSNumber
                rotateAnimation.duration = 0.15
                rotateAnimation.fillMode = .forwards
                rotateAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                rotateAnimation.isRemovedOnCompletion = false
                self.badgeView.layer.add(rotateAnimation, forKey: "appearance2")
                
                Queue.mainQueue().after(0.5, {
                    let bounceAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    bounceAnimation.fromValue = rotationAngle as NSNumber
                    bounceAnimation.toValue = -0.04 as NSNumber
                    bounceAnimation.duration = 0.2
                    bounceAnimation.fillMode = .forwards
                    bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    bounceAnimation.isRemovedOnCompletion = false
                    self.badgeView.layer.add(bounceAnimation, forKey: "appearance3")
                    self.badgeView.layer.removeAnimation(forKey: "appearance2")
                    
                    Queue.mainQueue().after(0.2) {
                        let returnAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                        returnAnimation.fromValue = -0.04 as NSNumber
                        returnAnimation.toValue = 0.0 as NSNumber
                        returnAnimation.duration = 0.15
                        returnAnimation.fillMode = .forwards
                        returnAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
                        self.badgeView.layer.add(returnAnimation, forKey: "appearance4")
                        self.badgeView.layer.removeAnimation(forKey: "appearance3")
                    }
                })
            }
            
            if from == nil {
                self.badgeView.alpha = 1.0
                self.badgeView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            }
            
            if let badgeText = component.badgeText, let badgeLabel = self.badgeLabel {
                let transition: ComponentTransition = .easeInOut(duration: from != nil ? 0.3 : 0.5)
                var frameTransition = transition
                if from == nil {
                    frameTransition = frameTransition.withAnimation(.none)
                }
                let badgeLabelSize = badgeLabel.update(value: badgeText, transition: transition)
                frameTransition.setFrame(view: badgeLabel, frame: CGRect(origin: CGPoint(x: 10.0, y: -2.0), size: badgeLabelSize))
            }
        }
        
        var previousAvailableSize: CGSize?
        func update(component: RemainingCountComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.inactiveBackground.backgroundColor = component.inactiveColor.cgColor
            self.activeBackground.backgroundColor = component.activeColors.last?.cgColor
            
            let size = CGSize(width: availableSize.width, height: 90.0)
            
            
            if self.badgeLabel == nil {
                let badgeLabel = BadgeLabelView(groupingSeparator: component.groupingSeparator)
                let _ = badgeLabel.update(value: "0", transition: .immediate)
                badgeLabel.mask = self.badgeLabelMaskView
                self.badgeLabel = badgeLabel
                self.badgeView.addSubview(badgeLabel)
            }
            
            self.badgeLabel?.color = component.activeTitleColor
            
            let lineHeight: CGFloat = 30.0
            let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - lineHeight), size: CGSize(width: size.width, height: lineHeight))
            self.container.frame = containerFrame
            
            let activityPosition: CGFloat = floor(containerFrame.width * component.badgeGraphPosition)
            let activeWidth: CGFloat = containerFrame.width - activityPosition
            
            let leftTextColor: UIColor
            let rightTextColor: UIColor
            if component.invertProgress {
                leftTextColor = component.inactiveTitleColor
                rightTextColor = component.inactiveTitleColor
            } else {
                leftTextColor = component.inactiveTitleColor
                rightTextColor = component.activeTitleColor
            }
            
            if component.invertProgress {
                let innerLeftTitleSize = self.innerLeftTitleLabel.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(
                                NSAttributedString(
                                    string: component.inactiveTitle,
                                    font: Font.semibold(15.0),
                                    textColor: component.activeTitleColor
                                )
                            )
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                if let view = self.innerLeftTitleLabel.view {
                    if view.superview == nil {
                        self.activeContainer.addSubview(view)
                    }
                    view.frame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((lineHeight - innerLeftTitleSize.height) / 2.0)), size: innerLeftTitleSize)
                }
                
                let innerRightTitleSize = self.innerRightTitleLabel.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(
                                NSAttributedString(
                                    string: component.activeValue,
                                    font: Font.semibold(15.0),
                                    textColor: component.activeTitleColor
                                )
                            )
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                if let view = self.innerRightTitleLabel.view {
                    if view.superview == nil {
                        self.activeContainer.addSubview(view)
                    }
                    view.frame = CGRect(origin: CGPoint(x: containerFrame.width - 12.0 - innerRightTitleSize.width, y: floorToScreenPixels((lineHeight - innerRightTitleSize.height) / 2.0)), size: innerRightTitleSize)
                }
            }
            
            let inactiveTitleSize = self.inactiveTitleLabel.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.inactiveTitle,
                                font: Font.semibold(15.0),
                                textColor: leftTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.inactiveTitleLabel.view {
                if view.superview == nil {
                    self.container.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((lineHeight - inactiveTitleSize.height) / 2.0)), size: inactiveTitleSize)
            }
            
            let inactiveValueSize = self.inactiveValueLabel.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.inactiveValue,
                                font: Font.semibold(15.0),
                                textColor: leftTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.inactiveValueLabel.view {
                if view.superview == nil {
                    self.container.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: activityPosition - 12.0 - inactiveValueSize.width, y: floorToScreenPixels((lineHeight - inactiveValueSize.height) / 2.0)), size: inactiveValueSize)
            }
            
            let activeTitleSize = self.activeTitleLabel.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.activeTitle,
                                font: Font.semibold(15.0),
                                textColor: rightTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.activeTitleLabel.view {
                if view.superview == nil {
                    self.container.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: activityPosition + 12.0, y: floorToScreenPixels((lineHeight - activeTitleSize.height) / 2.0)), size: activeTitleSize)
            }
            
            let activeValueSize = self.activeValueLabel.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.activeValue,
                                font: Font.semibold(15.0),
                                textColor: rightTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.activeValueLabel.view {
                if view.superview == nil {
                    self.container.addSubview(view)
                    
                    if component.invertProgress {
                        self.container.bringSubviewToFront(self.activeContainer)
                    }
                }
                view.frame = CGRect(origin: CGPoint(x: containerFrame.width - 12.0 - activeValueSize.width, y: floorToScreenPixels((lineHeight - activeValueSize.height) / 2.0)), size: activeValueSize)
            }
                        
            var progressTransition: ComponentTransition = .immediate
            if !transition.animation.isImmediate {
                progressTransition = .easeInOut(duration: 0.5)
            }
            if "".isEmpty {
                if component.invertProgress {
                    progressTransition.setFrame(layer: self.inactiveBackground, frame: CGRect(origin: CGPoint(x: activityPosition, y: 0.0), size: CGSize(width: size.width - activityPosition, height: lineHeight)))
                    progressTransition.setFrame(view: self.activeContainer, frame: CGRect(origin: .zero, size: CGSize(width: activityPosition, height: lineHeight)))
                    progressTransition.setBounds(layer: self.activeBackground, bounds: CGRect(origin: .zero, size: CGSize(width: containerFrame.width * 1.35, height: lineHeight)))
                } else {
                    progressTransition.setFrame(layer: self.inactiveBackground, frame: CGRect(origin: .zero, size: CGSize(width: activityPosition, height: lineHeight)))
                    progressTransition.setFrame(view: self.activeContainer, frame: CGRect(origin: CGPoint(x: activityPosition, y: 0.0), size: CGSize(width: activeWidth, height: lineHeight)))
                    progressTransition.setFrame(layer: self.activeBackground, frame: CGRect(origin: CGPoint(x: -activityPosition, y: 0.0), size: CGSize(width: containerFrame.width * 1.35, height: lineHeight)))
                }
                if self.activeBackground.animation(forKey: "movement") == nil {
                    self.activeBackground.position = CGPoint(x: -self.activeContainer.frame.width * 0.35, y: lineHeight / 2.0)
                }
            }
            
            let countWidth: CGFloat
            if let badgeText = component.badgeText {
                countWidth = getLabelWidth(badgeText)
            } else {
                countWidth = 51.0
            }
            
            let badgeSpacing: CGFloat = 4.0
            
            let badgeLeftSize = self.badgeLeftLabel.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.leftString,
                                font: Font.semibold(15.0),
                                textColor: component.activeTitleColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.badgeLeftLabel.view {
                if view.superview == nil {
                    self.badgeView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: 10.0 + countWidth + badgeSpacing, y: 4.0 + UIScreenPixel), size: badgeLeftSize)
            }
            
            let badgeWidth: CGFloat = countWidth + 20.0 + badgeSpacing + badgeLeftSize.width
            let badgeSize = CGSize(width: badgeWidth, height: 30.0)
            let badgeFullSize = CGSize(width: badgeWidth, height: badgeSize.height + 8.0)
            let tailSize = CGSize(width: 15.0, height: 6.0)
            let tailRadius: CGFloat = 3.0
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeFullSize)
            self.badgeShapeLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: badgeFullSize)
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeFullSize)
            
            let currentBadgeX = self.badgeView.center.x
            
            let badgePosition = component.badgePosition
            
            if badgePosition > 1.0 - 0.15 {
                progressTransition.setAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: 1.0, y: 1.0))
                
                if progressTransition.animation.isImmediate {
                    self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailSize: tailSize, tailRadius: tailRadius, tailPosition: 1.0).cgPath
                } else {
                    self.badgeShapeArguments = (CACurrentMediaTime(), 0.5, badgeSize, self.badgeTailPosition, 1.0)
                    self.animateBadgeTailPositionChange()
                }
                self.badgeTailPosition = 1.0
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                } else {
                    self.badgeView.center = CGPoint(x: 3.0 + (size.width - 6.0) * badgePosition + 3.0, y: 56.0)
                }
            } else if badgePosition < 0.15 {
                progressTransition.setAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: 0.0, y: 1.0))
                
                if progressTransition.animation.isImmediate {
                    self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailSize: tailSize, tailRadius: tailRadius, tailPosition: 0.0).cgPath
                } else {
                    self.badgeShapeArguments = (CACurrentMediaTime(), 0.5, badgeSize, self.badgeTailPosition, 0.0)
                    self.animateBadgeTailPositionChange()
                }
                self.badgeTailPosition = 0.0
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                    
                } else {
                    self.badgeView.center = CGPoint(x: (size.width - 6.0) * badgePosition, y: 56.0)
                }
            } else {
                progressTransition.setAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: 0.5, y: 1.0))
                
                if progressTransition.animation.isImmediate {
                    self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailSize: tailSize, tailRadius: tailRadius, tailPosition: 0.5).cgPath
                } else {
                    self.badgeShapeArguments = (CACurrentMediaTime(), 0.5, badgeSize, self.badgeTailPosition, 0.5)
                    self.animateBadgeTailPositionChange()
                }
                self.badgeTailPosition = 0.5
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                    
                } else {
                    self.badgeView.center = CGPoint(x: size.width * badgePosition, y: 56.0)
                }
            }
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: badgeFullSize.width * 3.0, height: badgeFullSize.height))
            if self.badgeForeground.animation(forKey: "movement") == nil {
                self.badgeForeground.position = CGPoint(x: badgeSize.width * 3.0 / 2.0 - self.badgeForeground.frame.width * 0.35, y: badgeFullSize.height / 2.0)
            }
    
            self.badgeLabelMaskView.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 36.0)
            
            if !self.didPlayAppearanceAnimation || !transition.animation.isImmediate {
                self.didPlayAppearanceAnimation = true
                if transition.animation.isImmediate {
                    if component.badgePosition < 0.1 {
                        self.badgeView.alpha = 1.0
                        if let badgeText = component.badgeText, let badgeLabel = self.badgeLabel {
                            let badgeLabelSize = badgeLabel.update(value: badgeText, transition: .immediate)
                            transition.setFrame(view: badgeLabel, frame: CGRect(origin: CGPoint(x: 10.0, y: -2.0), size: badgeLabelSize))
                        }
                    } else {
                        self.playAppearanceAnimation(component: component, badgeFullSize: badgeFullSize)
                    }
                } else {
                    self.playAppearanceAnimation(component: component, badgeFullSize: badgeFullSize, from: currentBadgeX)
                }
            }
            
            if self.previousAvailableSize != availableSize {
                self.previousAvailableSize = availableSize
                
                var locations: [CGFloat] = []
                let delta = 1.0 / CGFloat(component.activeColors.count - 1)
                for i in 0 ..< component.activeColors.count {
                    locations.append(delta * CGFloat(i))
                }
                
                let gradient = generateGradientImage(size: CGSize(width: 200.0, height: 60.0), colors: component.activeColors, locations: locations, direction: .horizontal)
                self.badgeForeground.contentsGravity = .resizeAspectFill
                self.badgeForeground.contents = gradient?.cgImage
                
                self.activeBackground.contentsGravity = .resizeAspectFill
                self.activeBackground.contents = gradient?.cgImage
                
                self.setupGradientAnimations()
            }
            
            return size
        }
        
        private var badgeShapeAnimator: ConstantDisplayLinkAnimator?
        private func animateBadgeTailPositionChange() {
            if self.badgeShapeAnimator == nil {
                self.badgeShapeAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.animateBadgeTailPositionChange()
                })
                self.badgeShapeAnimator?.isPaused = true
            }
            
            if let (startTime, duration, badgeSize, initial, target) = self.badgeShapeArguments {
                self.badgeShapeAnimator?.isPaused = false
                
                let t = CGFloat(max(0.0, min(1.0, (CACurrentMediaTime() - startTime) / duration)))
                let value = initial + (target - initial) * t
                
                let tailSize = CGSize(width: 15.0, height: 6.0)
                let tailRadius: CGFloat = 3.0
                self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailSize: tailSize, tailRadius: tailRadius, tailPosition: value).cgPath
                
                if t >= 1.0 {
                    self.badgeShapeArguments = nil
                    self.badgeShapeAnimator?.isPaused = true
                    self.badgeShapeAnimator?.invalidate()
                    self.badgeShapeAnimator = nil
                }
            } else {
                self.badgeShapeAnimator?.isPaused = true
                self.badgeShapeAnimator?.invalidate()
                self.badgeShapeAnimator = nil
            }
        }
        
        private func setupGradientAnimations() {
            guard let _ = self.component else {
                return
            }
            if let _ = self.badgeForeground.animation(forKey: "movement") {
            } else {
                CATransaction.begin()
                
                let badgeOffset = (self.badgeForeground.frame.width - self.badgeView.bounds.width) / 2.0
                let badgePreviousValue = self.badgeForeground.position.x
                var badgeNewValue: CGFloat = badgeOffset
                if badgeOffset - badgePreviousValue < self.badgeForeground.frame.width * 0.25 {
                    badgeNewValue -= self.badgeForeground.frame.width * 0.35
                }
                self.badgeForeground.position = CGPoint(x: badgeNewValue, y: self.badgeForeground.bounds.size.height / 2.0)
                
                let lineOffset = 0.0
                let linePreviousValue = self.activeBackground.position.x
                var lineNewValue: CGFloat = lineOffset
                if linePreviousValue < 0.0 {
                    lineNewValue = 0.0
                } else {
                    lineNewValue = -self.activeContainer.bounds.width * 0.35
                }
                lineNewValue -= self.activeContainer.frame.minX
                self.activeBackground.position = CGPoint(x: lineNewValue, y: 0.0)
                
                let badgeAnimation = CABasicAnimation(keyPath: "position.x")
                badgeAnimation.duration = 4.5
                badgeAnimation.fromValue = badgePreviousValue
                badgeAnimation.toValue = badgeNewValue
                badgeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                CATransaction.setCompletionBlock { [weak self] in
                    self?.setupGradientAnimations()
                }
                self.badgeForeground.add(badgeAnimation, forKey: "movement")
                
                let lineAnimation = CABasicAnimation(keyPath: "position.x")
                lineAnimation.duration = 4.5
                lineAnimation.fromValue = linePreviousValue
                lineAnimation.toValue = lineNewValue
                lineAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.activeBackground.add(lineAnimation, forKey: "movement")
                
                CATransaction.commit()
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}


private let spaceWidth: CGFloat = 3.0
private let labelWidth: CGFloat = 10.0
private let labelHeight: CGFloat = 30.0
private let labelSize = CGSize(width: labelWidth, height: labelHeight)
private let font = Font.with(size: 15.0, design: .regular, weight: .semibold, traits: [])

final class BadgeLabelView: UIView {
    private class StackView: UIView {
        var labels: [UILabel] = []
        
        var currentValue: Int32?
        
        var color: UIColor = .white {
            didSet {
                for view in self.labels {
                    view.textColor = self.color
                }
            }
        }
        
        init(groupingSeparator: String) {
            super.init(frame: CGRect(origin: .zero, size: labelSize))
             
            var height: CGFloat = -labelHeight * 2.0
            for i in -2 ..< 10 {
                let label = UILabel()
                let itemWidth: CGFloat
                if i == -2 {
                    label.text = groupingSeparator
                    itemWidth = spaceWidth
                } else if i == -1 {
                    label.text = "9"
                    itemWidth = labelWidth
                } else {
                    label.text = "\(i)"
                    itemWidth = labelWidth
                }
                label.textColor = self.color
                label.font = font
                label.textAlignment = .center
                label.frame = CGRect(x: 0, y: height, width: itemWidth, height: labelHeight)
                self.addSubview(label)
                self.labels.append(label)
                
                height += labelHeight
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(value: Int32?, isFirst: Bool, isLast: Bool, transition: ComponentTransition) {
            let previousValue = self.currentValue
            self.currentValue = value
                        
            self.labels[2].alpha = isFirst && !isLast ? 0.0 : 1.0
            
            if let value {
                if previousValue == 9 && value < 9 {
                    self.bounds = CGRect(
                        origin: CGPoint(
                            x: 0.0,
                            y: -1.0 * labelSize.height
                        ),
                        size: labelSize
                    )
                }
                
                let bounds = CGRect(
                    origin: CGPoint(
                        x: 0.0,
                        y: CGFloat(value) * labelSize.height
                    ),
                    size: labelSize
                )
                transition.setBounds(view: self, bounds: bounds)
            } else {
                self.bounds = CGRect(
                    origin: CGPoint(
                        x: 0.0,
                        y: -2.0 * labelSize.height
                    ),
                    size: labelSize
                )
            }
        }
    }
    
    private let groupingSeparator: String
    private var itemViews: [Int: StackView] = [:]
    
    init(groupingSeparator: String) {
        self.groupingSeparator = groupingSeparator
        
        super.init(frame: .zero)
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var color: UIColor = .white {
        didSet {
            for (_, view) in self.itemViews {
                view.color = self.color
            }
        }
    }
    
    func update(value: String, transition: ComponentTransition) -> CGSize {
        let string = value
        let stringArray = Array(string.map { String($0) }.reversed())
        
        let totalWidth: CGFloat = getLabelWidth(value)
        
        var rightX: CGFloat = totalWidth
        var validIds: [Int] = []
        for i in 0 ..< stringArray.count {
            validIds.append(i)
            
            let itemView: StackView
            var itemTransition = transition
            if let current = self.itemViews[i] {
                itemView = current
            } else {
                itemTransition = transition.withAnimation(.none)
                itemView = StackView(groupingSeparator: self.groupingSeparator)
                itemView.color = self.color
                self.itemViews[i] = itemView
                self.addSubview(itemView)
            }
            
            let digit = Int32(stringArray[i])
            itemView.update(value: digit, isFirst: i == stringArray.count - 1, isLast: i == 0, transition: transition)
            
            let itemWidth: CGFloat = digit != nil ? labelWidth : spaceWidth
            rightX -= itemWidth
            
            itemTransition.setFrame(
                view: itemView,
                frame: CGRect(x: rightX, y: 0.0, width: labelWidth, height: labelHeight)
            )
        }
        
        var removeIds: [Int] = []
        for (id, itemView) in self.itemViews {
            if !validIds.contains(id) {
                removeIds.append(id)
                
                transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                    itemView.removeFromSuperview()
                })
            }
        }
        for id in removeIds {
            self.itemViews.removeValue(forKey: id)
        }
        return CGSize(width: totalWidth, height: labelHeight)
    }
}

private func getLabelWidth(_ string: String) -> CGFloat {
    var totalWidth: CGFloat = 0.0
    for c in string {
        if CharacterSet.decimalDigits.contains(c.unicodeScalars[c.unicodeScalars.startIndex]) {
            totalWidth += labelWidth
        } else {
            totalWidth += spaceWidth
        }
    }
    return totalWidth
}
