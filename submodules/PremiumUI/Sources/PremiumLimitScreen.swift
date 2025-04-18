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
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import BalancedTextComponent
import ConfettiEffect
import AvatarNode
import TextFormat
import RoundedRectWithTailPath
import PremiumPeerShortcutComponent

func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

public class PremiumLimitDisplayComponent: Component {
    private let inactiveColor: UIColor
    private let activeColors: [UIColor]
    private let inactiveTitle: String
    private let inactiveValue: String
    private let inactiveTitleColor: UIColor
    private let activeTitle: String
    private let activeValue: String
    private let activeTitleColor: UIColor
    private let badgeIconName: String?
    private let badgeText: String?
    private let badgePosition: CGFloat
    private let badgeGraphPosition: CGFloat
    private let invertProgress: Bool
    private let isPremiumDisabled: Bool
    
    public init(
        inactiveColor: UIColor,
        activeColors: [UIColor],
        inactiveTitle: String,
        inactiveValue: String,
        inactiveTitleColor: UIColor,
        activeTitle: String,
        activeValue: String,
        activeTitleColor: UIColor,
        badgeIconName: String?,
        badgeText: String?,
        badgePosition: CGFloat,
        badgeGraphPosition: CGFloat,
        invertProgress: Bool = false,
        isPremiumDisabled: Bool
    ) {
        self.inactiveColor = inactiveColor
        self.activeColors = activeColors
        self.inactiveTitle = inactiveTitle
        self.inactiveValue = inactiveValue
        self.inactiveTitleColor = inactiveTitleColor
        self.activeTitle = activeTitle
        self.activeValue = activeValue
        self.activeTitleColor = activeTitleColor
        self.badgeIconName = badgeIconName
        self.badgeText = badgeText
        self.badgePosition = badgePosition
        self.badgeGraphPosition = badgeGraphPosition
        self.invertProgress = invertProgress
        self.isPremiumDisabled = isPremiumDisabled
    }
    
    public static func ==(lhs: PremiumLimitDisplayComponent, rhs: PremiumLimitDisplayComponent) -> Bool {
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
        if lhs.badgeIconName != rhs.badgeIconName {
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
        if lhs.isPremiumDisabled != rhs.isPremiumDisabled {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: PremiumLimitDisplayComponent?
        
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
        private let badgeIcon: UIImageView
        private let badgeLabel: BadgeLabelView
        private let badgeLabelMaskView = UIImageView()
        
        private var badgeTailPosition: CGFloat = 0.0
        private var badgeShapeArguments: (Double, Double, CGSize, CGFloat, CGFloat)?
        
        private let hapticFeedback = HapticFeedback()
        
        override init(frame: CGRect) {
            self.container = UIView()
            self.container.clipsToBounds = true
            self.container.layer.cornerRadius = 6.0
            
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
            
            self.badgeIcon = UIImageView()
            self.badgeIcon.contentMode = .center
                        
            self.badgeLabel = BadgeLabelView()
            let _ = self.badgeLabel.update(value: "0", transition: .immediate)
            self.badgeLabel.mask = self.badgeLabelMaskView
            
            super.init(frame: frame)
            
            self.addSubview(self.container)
            self.container.layer.addSublayer(self.inactiveBackground)
            self.container.addSubview(self.activeContainer)
            self.activeContainer.layer.addSublayer(self.activeBackground)
            
            self.addSubview(self.badgeView)
            self.badgeView.layer.addSublayer(self.badgeForeground)
            self.badgeView.addSubview(self.badgeIcon)
            self.badgeView.addSubview(self.badgeLabel)
            
            self.badgeLabelMaskView.contentMode = .scaleToFill
            self.badgeLabelMaskView.image = generateImage(CGSize(width: 2.0, height: 36.0), rotatedContext: { size, context in
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
        func playAppearanceAnimation(component: PremiumLimitDisplayComponent, badgeFullSize: CGSize, from: CGFloat? = nil) {
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
            positionAnimation.fromValue = NSValue(cgPoint: CGPoint(x: from ?? 0.0, y: 0.0))
            positionAnimation.toValue = NSValue(cgPoint: CGPoint(x: to, y: 0.0))
            positionAnimation.duration = 0.5
            positionAnimation.fillMode = .forwards
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.badgeView.layer.add(positionAnimation, forKey: "appearance1")
           
            if from != to {
                let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotateAnimation.fromValue = 0.0 as NSNumber
                rotateAnimation.toValue = -rotationAngle as NSNumber
                rotateAnimation.duration = 0.15
                rotateAnimation.fillMode = .forwards
                rotateAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                rotateAnimation.isRemovedOnCompletion = false
                self.badgeView.layer.add(rotateAnimation, forKey: "appearance2")
                
                Queue.mainQueue().after(0.5, {
                    let bounceAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    bounceAnimation.fromValue = -rotationAngle as NSNumber
                    bounceAnimation.toValue = 0.04 as NSNumber
                    bounceAnimation.duration = 0.2
                    bounceAnimation.fillMode = .forwards
                    bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    bounceAnimation.isRemovedOnCompletion = false
                    self.badgeView.layer.add(bounceAnimation, forKey: "appearance3")
                    self.badgeView.layer.removeAnimation(forKey: "appearance2")
                    
                    if !self.badgeView.isHidden {
                        self.hapticFeedback.impact(.light)
                    }
                    
                    Queue.mainQueue().after(0.2) {
                        let returnAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                        returnAnimation.fromValue = 0.04 as NSNumber
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
            
            if let badgeText = component.badgeText {
                let transition: ComponentTransition = .easeInOut(duration: from != nil ? 0.3 : 0.5)
                var frameTransition = transition
                if from == nil {
                    frameTransition = frameTransition.withAnimation(.none)
                }
                let badgeLabelSize = self.badgeLabel.update(value: badgeText, transition: transition)
                frameTransition.setFrame(view: self.badgeLabel, frame: CGRect(origin: CGPoint(x: 14.0 + floorToScreenPixels((badgeFullSize.width - badgeLabelSize.width) / 2.0), y: 5.0), size: badgeLabelSize))
            }
        }
        
        var previousAvailableSize: CGSize?
        func update(component: PremiumLimitDisplayComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.inactiveBackground.backgroundColor = component.inactiveColor.cgColor
            self.activeBackground.backgroundColor = component.activeColors.last?.cgColor
            
            let size = CGSize(width: availableSize.width, height: 120.0)
            
            self.badgeIcon.image = component.badgeIconName.flatMap { UIImage(bundleImageName: $0)?.withRenderingMode(.alwaysTemplate) }
            self.badgeIcon.tintColor = component.activeTitleColor
            self.badgeView.isHidden = self.badgeIcon.image == nil
            self.badgeLabel.color = component.activeTitleColor
            
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
            
            if !component.isPremiumDisabled {
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
            }
                        
            var progressTransition: ComponentTransition = .immediate
            if !transition.animation.isImmediate {
                progressTransition = .easeInOut(duration: 0.5)
            }
            if !component.isPremiumDisabled {
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
                switch badgeText.count {
                    case 1:
                        countWidth = 20.0
                    case 2:
                        countWidth = 35.0
                    case 3:
                        countWidth = 51.0
                    case 4:
                        countWidth = 60.0
                    case 5:
                        countWidth = 74.0
                    case 6:
                        countWidth = 88.0
                    default:
                        countWidth = 51.0
                }
            } else {
                countWidth = 51.0
            }
            let badgeWidth: CGFloat = countWidth + 54.0
            
            let badgeSize = CGSize(width: badgeWidth, height: 48.0)
            let badgeFullSize = CGSize(width: badgeWidth, height: 48.0 + 12.0)
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeFullSize)
            self.badgeShapeLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: badgeFullSize)
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeFullSize)
            
            let currentBadgeX = self.badgeView.center.x
            
            var badgePosition = component.badgePosition
            if component.isPremiumDisabled {
                badgePosition = 0.5
            }
            
            if badgePosition > 1.0 - 0.15 {
                progressTransition.setAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: 1.0, y: 1.0))
                
                if component.isPremiumDisabled || progressTransition.animation.isImmediate {
                    self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailPosition: component.isPremiumDisabled ? nil : 1.0).cgPath
                } else {
                    self.badgeShapeArguments = (CACurrentMediaTime(), 0.5, badgeSize, self.badgeTailPosition, 1.0)
                    self.animateBadgeTailPositionChange()
                }
                self.badgeTailPosition = 1.0
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                } else {
                    self.badgeView.center = CGPoint(x: 3.0 + (size.width - 6.0) * badgePosition + 3.0, y: 82.0)
                }
            } else if badgePosition < 0.15 {
                progressTransition.setAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: 0.0, y: 1.0))
                
                if component.isPremiumDisabled || progressTransition.animation.isImmediate {
                    self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailPosition: component.isPremiumDisabled ? nil : 0.0).cgPath
                } else {
                    self.badgeShapeArguments = (CACurrentMediaTime(), 0.5, badgeSize, self.badgeTailPosition, 0.0)
                    self.animateBadgeTailPositionChange()
                }
                self.badgeTailPosition = 0.0
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                    
                } else {
                    self.badgeView.center = CGPoint(x: (size.width - 6.0) * badgePosition, y: 82.0)
                }
            } else {
                progressTransition.setAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: 0.5, y: 1.0))
                
                if component.isPremiumDisabled || progressTransition.animation.isImmediate {
                    self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailPosition: component.isPremiumDisabled ? nil : 0.5).cgPath
                } else {
                    self.badgeShapeArguments = (CACurrentMediaTime(), 0.5, badgeSize, self.badgeTailPosition, 0.5)
                    self.animateBadgeTailPositionChange()
                }
                self.badgeTailPosition = 0.5
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                    
                } else {
                    self.badgeView.center = CGPoint(x: size.width * badgePosition, y: 82.0)
                }
            }
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: badgeFullSize.width * 3.0, height: badgeFullSize.height))
            if self.badgeForeground.animation(forKey: "movement") == nil {
                self.badgeForeground.position = CGPoint(x: badgeSize.width * 3.0 / 2.0 - self.badgeForeground.frame.width * 0.35, y: badgeFullSize.height / 2.0)
            }
    
            self.badgeIcon.frame = CGRect(x: 10.0, y: 9.0, width: 30.0, height: 30.0)
            self.badgeLabelMaskView.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 36.0)
            
            if component.isPremiumDisabled {
                if !self.didPlayAppearanceAnimation {
                    self.didPlayAppearanceAnimation = true
                    
                    self.badgeView.alpha = 1.0
                    if let badgeText = component.badgeText {
                        let badgeLabelSize = self.badgeLabel.update(value: badgeText, transition: .immediate)
                        transition.setFrame(view: self.badgeLabel, frame: CGRect(origin: CGPoint(x: 14.0 + floorToScreenPixels((badgeFullSize.width - badgeLabelSize.width) / 2.0), y: 5.0), size: badgeLabelSize))
                    }
                }
            } else if !self.didPlayAppearanceAnimation || !transition.animation.isImmediate {
                self.didPlayAppearanceAnimation = true
                if transition.animation.isImmediate {
                    if component.badgePosition < 0.1 {
                        self.badgeView.alpha = 1.0
                        if let badgeText = component.badgeText {
                            let badgeLabelSize = self.badgeLabel.update(value: badgeText, transition: .immediate)
                            transition.setFrame(view: self.badgeLabel, frame: CGRect(origin: CGPoint(x: 14.0 + floorToScreenPixels((badgeFullSize.width - badgeLabelSize.width) / 2.0), y: 5.0), size: badgeLabelSize))
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
                
                self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: badgeSize, tailPosition: value).cgPath
                
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

private final class LimitSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumLimitScreen.Subject
    let count: Int32
    let cancel: () -> Void
    let action: () -> Bool
    let dismiss: () -> Void
    let openPeer: (EnginePeer) -> Void
    let openStats: (() -> Void)?
    let openGift: (() -> Void)?
    
    init(context: AccountContext, subject: PremiumLimitScreen.Subject, count: Int32, cancel: @escaping () -> Void, action: @escaping () -> Bool, dismiss: @escaping () -> Void, openPeer: @escaping (EnginePeer) -> Void, openStats: (() -> Void)?, openGift: (() -> Void)?) {
        self.context = context
        self.subject = subject
        self.count = count
        self.cancel = cancel
        self.action = action
        self.dismiss = dismiss
        self.openPeer = openPeer
        self.openStats = openStats
        self.openGift = openGift
    }
    
    static func ==(lhs: LimitSheetContent, rhs: LimitSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        private var disposable: Disposable?
        var initialized = false
        var limits: EngineConfiguration.UserLimits
        var premiumLimits: EngineConfiguration.UserLimits
        var isPremium = false
        
        var myBoostCount: Int32 = 0
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(context: AccountContext, subject: PremiumLimitScreen.Subject) {
            self.context = context
            self.limits = EngineConfiguration.UserLimits.defaultValue
            self.premiumLimits = EngineConfiguration.UserLimits.defaultValue
            
            super.init()
            
            self.disposable = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true),
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
            ) |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    let (limits, premiumLimits, accountPeer) = result
                    strongSelf.initialized = true
                    strongSelf.limits = limits
                    strongSelf.premiumLimits = premiumLimits
                    strongSelf.isPremium = accountPeer?.isPremium ?? false
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
        let closeButton = Child(Button.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let alternateText = Child(List<Empty>.self)
        let limit = Child(PremiumLimitDisplayComponent.self)
        let linkButton = Child(SolidRoundedButtonComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        let peerShortcut = Child(Button.self)
        let statsButton = Child(Button.self)
        
        let orLeftLine = Child(Rectangle.self)
        let orRightLine = Child(Rectangle.self)
        let orText = Child(MultilineTextComponent.self)
        let giftText = Child(BalancedTextComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            
            let state = context.state
            let subject = component.subject
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let isPremiumDisabled: Bool
            if case .storiesChannelBoost = subject {
                isPremiumDisabled = false
            } else {
                isPremiumDisabled = premiumConfiguration.isPremiumDisabled
            }
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: { [weak component] in
                        component?.dismiss()
                        component?.cancel()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
            
            var boostUpdated = false
             
            var peerShortcutChild: _UpdatedChildComponent?
            
            var useAlternateText = false
            var alternateTitle = ""
            var alternateBadge: String?
            
            var titleText = strings.Premium_LimitReached
            var actionButtonText: String?
            var actionButtonHasGloss = true
            var gradientedActionButton = true
            var buttonAnimationName: String? = "premium_x2"
            var buttonIconName: String?
            let iconName: String
            var badgeText: String
            var string: String
            let defaultValue: String
            var defaultTitle = strings.Premium_Free
            var premiumTitle = strings.Premium_Premium
            let premiumValue: String
            let badgePosition: CGFloat
            let badgeGraphPosition: CGFloat
            var invertProgress = false
            switch subject {
            case .folders:
                let limit = state.limits.maxFoldersCount
                let premiumLimit = state.premiumLimits.maxFoldersCount
                iconName = "Premium/Folder"
                badgeText = "\(component.count)"
                string = component.count >= premiumLimit ? strings.Premium_MaxFoldersCountFinalText("\(premiumLimit)").string : strings.Premium_MaxFoldersCountText("\(limit)", "\(premiumLimit)").string
                defaultValue = component.count > limit ? "\(limit)" : ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                if component.count >= premiumLimit {
                    badgeGraphPosition = max(0.35, CGFloat(limit) / CGFloat(premiumLimit))
                } else {
                    badgeGraphPosition = max(0.35, CGFloat(component.count) / CGFloat(premiumLimit))
                }
                badgePosition = max(0.35, CGFloat(component.count) / CGFloat(premiumLimit))
            
                if !state.isPremium && badgePosition > 0.5 {
                    string = strings.Premium_MaxFoldersCountText("\(limit)", "\(premiumLimit)").string
                }
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxFoldersCountNoPremiumText("\(limit)").string
                }
            case .chatsPerFolder:
                let limit = state.limits.maxFolderChatsCount
                let premiumLimit = state.premiumLimits.maxFolderChatsCount
                iconName = "Premium/Chat"
                badgeText = "\(component.count)"
                string = component.count >= premiumLimit ? strings.Premium_MaxChatsInFolderFinalText("\(premiumLimit)").string : strings.Premium_MaxChatsInFolderText("\(limit)", "\(premiumLimit)").string
                defaultValue = component.count > limit ? "\(limit)" : ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                badgePosition = CGFloat(component.count) / CGFloat(premiumLimit)
                badgeGraphPosition = badgePosition
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxChatsInFolderNoPremiumText("\(limit)").string
                }
            case .channels:
                let limit = state.limits.maxChannelsCount
                let premiumLimit = state.premiumLimits.maxChannelsCount
                iconName = "Premium/Chat"
                badgeText = "\(component.count)"
                string = component.count >= premiumLimit ? strings.Premium_MaxChannelsFinalText("\(premiumLimit)").string : strings.Premium_MaxChannelsText("\(limit)", "\(premiumLimit)").string
                defaultValue = component.count > limit ? "\(limit)" : ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                if component.count >= premiumLimit {
                    badgeGraphPosition = max(0.35, CGFloat(limit) / CGFloat(premiumLimit))
                } else {
                    badgeGraphPosition = max(0.35, CGFloat(component.count) / CGFloat(premiumLimit))
                }
                badgePosition = max(0.35, CGFloat(component.count) / CGFloat(premiumLimit))
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxChannelsNoPremiumText("\(limit)").string
                }
            case .linksPerSharedFolder:
                /*let count: Int32 = 5 + Int32("".count)// component.count
                let limit: Int32 = 5 + Int32("".count)//state.limits.maxSharedFolderInviteLinks
                let premiumLimit: Int32 = 100 + Int32("".count)//state.premiumLimits.maxSharedFolderInviteLinks*/
            
                let count: Int32 = component.count
                let limit: Int32 = state.limits.maxSharedFolderInviteLinks
                let premiumLimit: Int32 = state.premiumLimits.maxSharedFolderInviteLinks
            
                iconName = "Premium/Link"
                badgeText = "\(count)"
                string = count >= premiumLimit ? strings.Premium_MaxSharedFolderLinksFinalText("\(premiumLimit)").string : strings.Premium_MaxSharedFolderLinksText("\(limit)", "\(premiumLimit)").string
                defaultValue = count > limit ? "\(limit)" : ""
                premiumValue = count >= premiumLimit ? "" : "\(premiumLimit)"
                if count >= premiumLimit {
                    badgeGraphPosition = max(0.35, CGFloat(limit) / CGFloat(premiumLimit))
                } else {
                    badgeGraphPosition = max(0.35, CGFloat(count) / CGFloat(premiumLimit))
                }
                badgePosition = max(0.35, CGFloat(count) / CGFloat(premiumLimit))
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxSharedFolderLinksNoPremiumText("\(limit)").string
                }
            
                buttonAnimationName = nil
            case .membershipInSharedFolders:
                let limit = state.limits.maxSharedFolderJoin
                let premiumLimit = state.premiumLimits.maxSharedFolderJoin
                iconName = "Premium/Folder"
                badgeText = "\(component.count)"
                string = component.count >= premiumLimit ? strings.Premium_MaxSharedFolderMembershipFinalText("\(premiumLimit)").string : strings.Premium_MaxSharedFolderMembershipText("\(limit)", "\(premiumLimit)").string
                defaultValue = component.count > limit ? "\(limit)" : ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                if component.count >= premiumLimit {
                    badgeGraphPosition = max(0.35, CGFloat(limit) / CGFloat(premiumLimit))
                } else {
                    badgeGraphPosition = max(0.35, CGFloat(component.count) / CGFloat(premiumLimit))
                }
                badgePosition = max(0.35, CGFloat(component.count) / CGFloat(premiumLimit))
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxSharedFolderMembershipNoPremiumText("\(limit)").string
                }
            
                buttonAnimationName = nil
            case .pins:
                let limit = state.limits.maxPinnedChatCount
                let premiumLimit = state.premiumLimits.maxPinnedChatCount
                iconName = "Premium/Pin"
                badgeText = "\(component.count)"
                string = component.count >= premiumLimit ? strings.Premium_MaxPinsFinalText("\(premiumLimit)").string : strings.Premium_MaxPinsText("\(limit)", "\(premiumLimit)").string
                defaultValue = component.count > limit ? "\(limit)" : ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                badgePosition = CGFloat(component.count) / CGFloat(premiumLimit)
                badgeGraphPosition = badgePosition
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxPinsNoPremiumText("\(limit)").string
                }
            case .pinnedSavedPeers:
                let limit = state.limits.maxPinnedSavedChatCount
                let premiumLimit = state.premiumLimits.maxPinnedSavedChatCount
                iconName = "Premium/Pin"
                badgeText = "\(component.count)"
                string = component.count >= premiumLimit ? strings.Premium_MaxSavedPinsFinalText("\(premiumLimit)").string : strings.Premium_MaxSavedPinsText("\(limit)", "\(premiumLimit)").string
                defaultValue = component.count > limit ? "\(limit)" : ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                badgePosition = max(0.35, min(0.65, CGFloat(component.count) / CGFloat(premiumLimit)))
                badgeGraphPosition = badgePosition
                buttonAnimationName = nil
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxSavedPinsNoPremiumText("\(limit)").string
                }
            case .files:
                let limit = Int64(state.limits.maxUploadFileParts) * 512 * 1024 + 1024 * 1024 * 100
                let premiumLimit = Int64(state.premiumLimits.maxUploadFileParts) * 512 * 1024 + 1024 * 1024 * 100
                iconName = "Premium/File"
                badgeText = dataSizeString(component.count == 4 ? premiumLimit : limit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))
                string = component.count == 4 ? strings.Premium_MaxFileSizeFinalText(dataSizeString(premiumLimit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))).string : strings.Premium_MaxFileSizeText(dataSizeString(premiumLimit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))).string
                defaultValue = component.count == 4 ? dataSizeString(limit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator)) : ""
                premiumValue = component.count != 4 ? dataSizeString(premiumLimit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator)) : ""
                badgePosition = component.count == 4 ? 1.0 : 0.5
                badgeGraphPosition = 0.5
                titleText = strings.Premium_FileTooLarge
            
                if isPremiumDisabled {
                    badgeText = dataSizeString(limit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))
                    string = strings.Premium_MaxFileSizeNoPremiumText(dataSizeString(premiumLimit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))).string
                }
            case .accounts:
                let limit = 3
                let premiumLimit = limit + 1
                iconName = "Premium/Account"
                badgeText = "\(component.count)"
                string = component.count >= premiumLimit ? strings.Premium_MaxAccountsFinalText("\(premiumLimit)").string : strings.Premium_MaxAccountsText("\(limit)").string
                defaultValue = component.count > limit ? "\(limit)" : ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                if component.count == limit {
                    badgePosition = 0.5
                } else {
                    badgePosition = min(1.0, CGFloat(component.count) / CGFloat(premiumLimit))
                }
                badgeGraphPosition = 0.5
                buttonAnimationName = "premium_addone"
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxAccountsNoPremiumText("\(limit)").string
                }
            case .expiringStories:
                let limit = state.limits.maxExpiringStoriesCount
                let premiumLimit = state.premiumLimits.maxExpiringStoriesCount
                iconName = "Premium/Stories"
                badgeText = "\(limit)"
                if component.count >= premiumLimit {
                    let limitNumberString = strings.Premium_MaxExpiringStoriesFinalTextNumberFormat(Int32(premiumLimit))
                    string = strings.Premium_MaxExpiringStoriesFinalTextFormat(limitNumberString).string
                } else {
                    let limitNumberString = strings.Premium_MaxExpiringStoriesTextNumberFormat(Int32(limit))
                    let premiumLimitNumberString = strings.Premium_MaxExpiringStoriesTextPremiumNumberFormat(Int32(premiumLimit))
                    string = strings.Premium_MaxExpiringStoriesTextFormat(limitNumberString, premiumLimitNumberString).string
                }
                defaultValue = ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                badgePosition = max(0.32, CGFloat(component.count) / CGFloat(premiumLimit))
                badgeGraphPosition = badgePosition
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    let numberString = strings.Premium_MaxExpiringStoriesNoPremiumTextNumberFormat(Int32(limit))
                    string = strings.Premium_MaxExpiringStoriesNoPremiumTextFormat(numberString).string
                }
                buttonAnimationName = nil
            case .storiesWeekly:
                let limit = state.limits.maxStoriesWeeklyCount
                let premiumLimit = state.premiumLimits.maxStoriesWeeklyCount
                iconName = "Premium/Stories"
                badgeText = "\(limit)"
                string = component.count >= premiumLimit ? strings.Premium_MaxStoriesWeeklyFinalText("\(premiumLimit)").string : strings.Premium_MaxStoriesWeeklyText("\(limit)", "\(premiumLimit)").string
                defaultValue = ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                badgePosition = max(0.32, CGFloat(component.count) / CGFloat(premiumLimit))
                badgeGraphPosition = badgePosition
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxStoriesWeeklyNoPremiumText("\(limit)").string
                }
                buttonAnimationName = nil
            case .storiesMonthly:
                let limit = state.limits.maxStoriesMonthlyCount
                let premiumLimit = state.premiumLimits.maxStoriesMonthlyCount
                iconName = "Premium/Stories"
                badgeText = "\(limit)"
                string = component.count >= premiumLimit ? strings.Premium_MaxStoriesMonthlyFinalText("\(premiumLimit)").string : strings.Premium_MaxStoriesMonthlyText("\(limit)", "\(premiumLimit)").string
                defaultValue = ""
                premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                badgePosition = max(0.32, CGFloat(component.count) / CGFloat(premiumLimit))
                badgeGraphPosition = badgePosition
            
                if isPremiumDisabled {
                    badgeText = "\(limit)"
                    string = strings.Premium_MaxStoriesMonthlyNoPremiumText("\(limit)").string
                }
                buttonAnimationName = nil
            case let .storiesChannelBoost(peer, boostSubject, isCurrent, level, currentLevelBoosts, nextLevelBoosts, link, myBoostCount, canBoostAgain):
                var isGroup = false
                if case let .channel(channel) = peer, case .group = channel.info {
                    isGroup = true
                }
                
                if link == nil, !isCurrent, state.initialized {
                    peerShortcutChild = peerShortcut.update(
                        component: Button(
                            content: AnyComponent(
                                PremiumPeerShortcutComponent(
                                    context: component.context,
                                    theme: environment.theme,
                                    peer: peer
                                )
                            ),
                            action: {
                                component.dismiss()
                                Queue.mainQueue().after(0.35) {
                                    component.openPeer(peer)
                                }
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - 32.0, height: context.availableSize.height),
                        transition: .immediate
                    )
                }
                
                if link != nil {
                    gradientedActionButton = false
                }
                
                if let _ = link, let openStats = component.openStats {
                    let _ = openStats
                    let statsButton = statsButton.update(
                        component: Button(
                            content: AnyComponent(
                                BundleIconComponent(
                                    name: "Premium/Stats",
                                    tintColor: environment.theme.list.itemAccentColor
                                )
                            ),
                            action: {
                                component.dismiss()
                                Queue.mainQueue().after(0.35) {
                                    openStats()
                                }
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)),
                        availableSize: context.availableSize,
                        transition: .immediate
                    )
                    context.add(statsButton
                        .position(CGPoint(x: 31.0, y: 28.0))
                    )
                }
                
                if myBoostCount > 0 && state.myBoostCount != myBoostCount {
                    state.myBoostCount = myBoostCount
                    boostUpdated = true
                }
                useAlternateText = myBoostCount > 0
                
                iconName = "Premium/Boost"
                badgeText = "\(component.count)"
            
                var remaining: Int32?
                if let nextLevelBoosts {
                    remaining = nextLevelBoosts - component.count
                }
                
                
                if let _ = link {
                    if let remaining {
                        let storiesString = strings.ChannelBoost_StoriesPerDay(level + 1)
                        let valueString = strings.ChannelBoost_MoreBoosts(remaining)
                        
                        switch boostSubject {
                        case .stories:
                            if level == 0 {
                                titleText = strings.ChannelBoost_EnableStories
                                string = isGroup ? strings.GroupBoost_EnableStoriesText(valueString).string : strings.ChannelBoost_EnableStoriesText(valueString).string
                            } else {
                                titleText = strings.ChannelBoost_IncreaseLimit
                                string = isGroup ? strings.GroupBoost_IncreaseLimitText(valueString, storiesString).string : strings.ChannelBoost_IncreaseLimitText(valueString, storiesString).string
                            }
                        case let .nameColors(colors):
                            titleText = strings.ChannelBoost_EnableColors
                            
                            let colorLevel = requiredBoostSubjectLevel(subject: .nameColors(colors: colors), group: false, context: component.context, configuration: premiumConfiguration)
                            
                            string = strings.ChannelBoost_EnableColorsLevelText("\(colorLevel)").string
                        case let .channelReactions(reactionCount):
                            titleText = strings.ChannelBoost_CustomReactions
                            string = strings.ChannelBoost_CustomReactionsText("\(reactionCount)", "\(reactionCount)").string
                        }
                    } else {
                        let storiesString = strings.ChannelBoost_StoriesPerDay(level)
                        titleText = strings.ChannelBoost_MaxLevelReached
                        string = strings.ChannelBoost_MaxLevelReachedTextAuthor("\(level)", storiesString).string
                    }
                    actionButtonText = strings.ChannelBoost_CopyLink
                    buttonIconName = "Premium/CopyLink"
                    actionButtonHasGloss = false
                } else {
                    let storiesString = strings.ChannelBoost_StoriesPerDay(level + 1)
                    if let remaining {
                        let boostsString = strings.ChannelBoost_MoreBoosts(remaining)
                        if level == 0 {
                            titleText = isCurrent ? strings.ChannelBoost_EnableStoriesForChannel : strings.ChannelBoost_EnableStoriesForOtherChannel
                            string = strings.ChannelBoost_EnableStoriesForChannelText(peer.compactDisplayTitle, boostsString).string
                        } else {
                            titleText = strings.ChannelBoost_HelpUpgradeChannel
                            string = strings.ChannelBoost_HelpUpgradeChannelText(peer.compactDisplayTitle, boostsString, storiesString).string
                        }
                        actionButtonText = strings.ChannelBoost_BoostChannel
                        buttonIconName = "Premium/BoostChannel"
                    } else {
                        titleText = strings.ChannelBoost_MaxLevelReached
                        string = strings.ChannelBoost_BoostedChannelReachedLevel("\(level)", storiesString).string
                        actionButtonText = strings.Common_OK
                        buttonIconName = nil
                        actionButtonHasGloss = false
                    }
                }
                buttonAnimationName = nil
                defaultTitle = strings.ChannelBoost_Level("\(level)").string
                defaultValue = ""
                premiumValue = strings.ChannelBoost_Level("\(level + 1)").string
                
                premiumTitle = ""
                
                if myBoostCount > 0 {
                    alternateTitle = isCurrent ? strings.ChannelBoost_YouBoostedChannelText(peer.compactDisplayTitle).string : strings.ChannelBoost_YouBoostedOtherChannelText
                    if myBoostCount > 1 {
                        alternateBadge = "X\(myBoostCount)"
                    }
                    let storiesString = strings.ChannelBoost_StoriesPerDay(level + 1)
                    if let _ = remaining, canBoostAgain {
                        actionButtonText = strings.ChannelBoost_BoostAgain
                    } else {
                        buttonIconName = nil
                        actionButtonText = environment.strings.Common_OK
                        actionButtonHasGloss = false
                    }
                    if let remaining {
                        let boostsString = strings.ChannelBoost_MoreBoosts(remaining)
                        if level == 0 {
                            if remaining == 0 {
                                string = strings.ChannelBoost_EnabledStoriesForChannelText
                            } else {
                                string = strings.ChannelBoost_EnableStoriesMoreRequired(boostsString).string
                            }
                        }
                        else {
                            if remaining == 0 {
                                string = strings.ChannelBoost_BoostedChannelReachedLevel("\(level + 1)", storiesString).string
                            } else {
                                string = strings.ChannelBoost_BoostedChannelMoreRequired(boostsString, storiesString).string
                            }
                        }
                    } else {
                        string = strings.ChannelBoost_BoostedChannelReachedLevel("\(level + 1)", storiesString).string
                    }
                }
                
                let progress: CGFloat
                if let nextLevelBoosts {
                    progress = CGFloat(component.count - currentLevelBoosts) / CGFloat(nextLevelBoosts - currentLevelBoosts)
                } else {
                    progress = 1.0
                }
                
                badgePosition = progress
                badgeGraphPosition = progress
                
                invertProgress = true
            }
            var reachedMaximumLimit = badgePosition >= 1.0
            if case .folders = subject, !state.isPremium {
                reachedMaximumLimit = false
            }
            if case .storiesChannelBoost = component.subject {
                reachedMaximumLimit = false
            }
            
            let contentSize: CGSize
            if state.initialized {
                let title = title.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: titleText,
                            font: Font.semibold(17.0),
                            textColor: theme.actionSheet.primaryTextColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                
                let textFont = Font.regular(15.0)
                let boldTextFont = Font.semibold(15.0)
                let textColor = theme.actionSheet.primaryTextColor
                let linkColor = theme.actionSheet.controlAccentColor
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                
                var textChild: _UpdatedChildComponent?
                var alternateTextChild: _UpdatedChildComponent?
                if useAlternateText {
                    alternateTextChild = alternateText.update(
                        component: List(
                            [
                                AnyComponentWithIdentity(
                                    id: "title",
                                    component: AnyComponent(
                                        BoostedTitleContent(text: NSAttributedString(string: alternateTitle, font: Font.semibold(15.0), textColor: textColor), badge: alternateBadge)
                                    )
                                ),
                                AnyComponentWithIdentity(
                                    id: "text",
                                    component: AnyComponent(
                                        BalancedTextComponent(
                                            text: .markdown(text: string, attributes: markdownAttributes),
                                            horizontalAlignment: .center,
                                            maximumNumberOfLines: 0,
                                            lineSpacing: 0.1
                                        )
                                    )
                                )
                            ],
                            centerAlignment: true
                        ),
                        availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                        transition: .immediate
                    )
                    
//                    alternateTextChild = alternateText.update(
//                        component: BalancedTextComponent(
//                            text: .markdown(text: string, attributes: markdownAttributes),
//                            horizontalAlignment: .center,
//                            maximumNumberOfLines: 0,
//                            lineSpacing: 0.1
//                        ),
//                        availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
//                        transition: .immediate
//                    )
                } else {
                    textChild = text.update(
                        component: BalancedTextComponent(
                            text: .markdown(text: string, attributes: markdownAttributes),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1
                        ),
                        availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                        transition: .immediate
                    )
                }
                
                var topOffset: CGFloat = 0.0
                if let peerShortcutChild {
                    context.add(peerShortcutChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: 64.0))
                    )
                    topOffset += 38.0
                }
                
                let gradientColors: [UIColor]
                var buttonGradientColors: [UIColor]
                if isPremiumDisabled {
                    gradientColors = [
                        UIColor(rgb: 0x007afe),
                        UIColor(rgb: 0x5494ff)
                    ]
                } else {
                    gradientColors = [
                        UIColor(rgb: 0x0077ff),
                        UIColor(rgb: 0x6b93ff),
                        UIColor(rgb: 0x8878ff),
                        UIColor(rgb: 0xe46ace)
                    ]
                }
                if gradientedActionButton {
                    buttonGradientColors = gradientColors
                } else {
                    buttonGradientColors = [
                        UIColor(rgb: 0x007afe),
                        UIColor(rgb: 0x5494ff)
                    ]
                }
                
                var limitTransition: ComponentTransition = .immediate
                if boostUpdated {
                    limitTransition = .easeInOut(duration: 0.35)
                }
                            
                let isIncreaseButton = !reachedMaximumLimit && !isPremiumDisabled
                let button = button.update(
                    component: SolidRoundedButtonComponent(
                        title: actionButtonText ?? (isIncreaseButton ? strings.Premium_IncreaseLimit : strings.Common_OK),
                        theme: SolidRoundedButtonComponent.Theme(
                            backgroundColor: .black,
                            backgroundColors: buttonGradientColors,
                            foregroundColor: .white
                        ),
                        font: .bold,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: isIncreaseButton && actionButtonHasGloss,
                        iconName: buttonIconName,
                        animationName: isIncreaseButton ? buttonAnimationName : nil,
                        iconPosition: buttonIconName != nil ? .left : .right,
                        action: {
                            if isIncreaseButton {
                                if component.action() {
                                    component.dismiss()
                                }
                            } else {
                                component.dismiss()
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
                
                var buttonOffset: CGFloat = 0.0
                var textOffset: CGFloat = 184.0 + topOffset
                                
                if case let .storiesChannelBoost(_, _, _, _, _, _, link, _, _) = component.subject {
                    if let link {
                        let linkButton = linkButton.update(
                            component: SolidRoundedButtonComponent(
                                title: link.replacingOccurrences(of: "https://", with: ""),
                                theme: SolidRoundedButtonComponent.Theme(
                                    backgroundColor: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3),
                                    backgroundColors: [],
                                    foregroundColor: environment.theme.list.itemPrimaryTextColor
                                ),
                                font: .regular,
                                fontSize: 17.0,
                                height: 50.0,
                                cornerRadius: 10.0,
                                action: {
                                    if component.action() {
                                        component.dismiss()
                                    }
                                }
                            ),
                            availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                            transition: context.transition
                        )
                        buttonOffset += 66.0
                        
                        let linkFrame = CGRect(origin: CGPoint(x: sideInset, y: textOffset + (textChild?.size ?? .zero).height + 24.0), size: linkButton.size)
                        context.add(linkButton
                            .position(CGPoint(x: linkFrame.midX, y: linkFrame.midY))
                        )
                    }
                }
                if isPremiumDisabled {
                    textOffset -= 68.0
                }
                
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 28.0))
                )
                
                var textSize: CGSize
                if let textChild {
                    textSize = textChild.size
                    
                    textOffset += textSize.height / 2.0
                    
                    context.add(textChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: textOffset))
                        .appear(ComponentTransition.Appear({ _, view, transition in
                            transition.animatePosition(view: view, from: CGPoint(x: 0.0, y: 64.0), to: .zero, additive: true)
                            transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        }))
                        .disappear(ComponentTransition.Disappear({ view, transition, completion in
                            view.superview?.sendSubviewToBack(view)
                            transition.animatePosition(view: view, from: .zero, to: CGPoint(x: 0.0, y: -64.0), additive: true)
                            transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                                completion()
                            })
                        }))
                    )
                } else if let alternateTextChild {
                    textSize = alternateTextChild.size
                    
                    textOffset += textSize.height / 2.0
                    
                    context.add(alternateTextChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: textOffset))
                        .appear(ComponentTransition.Appear({ _, view, transition in
                            transition.animatePosition(view: view, from: CGPoint(x: 0.0, y: 64.0), to: .zero, additive: true)
                            transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        }))
                        .disappear(ComponentTransition.Disappear({ view, transition, completion in
                            transition.animatePosition(view: view, from: .zero, to: CGPoint(x: 0.0, y: -64.0), additive: true)
                            transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                                completion()
                            })
                        }))
                    )
                } else {
                    textSize = .zero
                }
                
                let limit = limit.update(
                    component: PremiumLimitDisplayComponent(
                        inactiveColor: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3),
                        activeColors: gradientColors,
                        inactiveTitle: defaultTitle,
                        inactiveValue: defaultValue,
                        inactiveTitleColor: theme.list.itemPrimaryTextColor,
                        activeTitle: premiumTitle,
                        activeValue: premiumValue,
                        activeTitleColor: .white,
                        badgeIconName: iconName,
                        badgeText: badgeText,
                        badgePosition: badgePosition,
                        badgeGraphPosition: badgeGraphPosition,
                        invertProgress: invertProgress,
                        isPremiumDisabled: isPremiumDisabled
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: limitTransition
                )
                context.add(limit
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: limit.size.height / 2.0 + 44.0 + topOffset))
                )
                
                let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: textOffset + ceil(textSize.height / 2.0) + buttonOffset + 24.0), size: button.size)
                context.add(button
                    .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
                )
                
                var additionalContentHeight: CGFloat = 0.0
                if case let .storiesChannelBoost(_, _, _, _, _, _, link, _, _) = component.subject, link != nil, let openGift = component.openGift {
                    let orText = orText.update(
                        component: MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.ChannelBoost_Or, font: Font.regular(15.0), textColor: textColor.withAlphaComponent(0.8), paragraphAlignment: .center))),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                        transition: .immediate
                    )
                    context.add(orText
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: buttonFrame.maxY + 27.0))
                    )
                                        
                    let orLeftLine = orLeftLine.update(
                        component: Rectangle(color: environment.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                        availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                        transition: .immediate
                    )
                    context.add(orLeftLine
                        .position(CGPoint(x: context.availableSize.width / 2.0 - orText.size.width / 2.0 - 11.0 - 45.0, y: buttonFrame.maxY + 27.0))
                    )
                    
                    let orRightLine = orRightLine.update(
                        component: Rectangle(color: environment.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                        availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                        transition: .immediate
                    )
                    context.add(orRightLine
                        .position(CGPoint(x: context.availableSize.width / 2.0 + orText.size.width / 2.0 + 11.0 + 45.0, y: buttonFrame.maxY + 27.0))
                    )
                    
                    if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                        state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, environment.theme)
                    }
                    
                    let giftString = environment.strings.Premium_BoostByGiveawayDescription
                    let giftAttributedString = parseMarkdownIntoAttributedString(giftString, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
                    
                    if let range = giftAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                        giftAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: giftAttributedString.string))
                    }
                    let giftText = giftText.update(
                        component: BalancedTextComponent(
                            text: .plain(giftAttributedString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1,
                            highlightColor: linkColor.withAlphaComponent(0.2),
                            highlightAction: { _ in
                                return nil
                            },
                            tapAction: { _, _ in
                                openGift()
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                        transition: .immediate
                    )
                    context.add(giftText
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: buttonFrame.maxY + 50.0 + giftText.size.height / 2.0))
                    )
                    
                    additionalContentHeight += giftText.size.height + 50.0
                }
            
                contentSize = CGSize(width: context.availableSize.width, height: buttonFrame.maxY + additionalContentHeight + 5.0 + environment.safeInsets.bottom)
            } else {
                var height: CGFloat = 351.0
                if isPremiumDisabled {
                    height -= 78.0
                }
                
                if case let .storiesChannelBoost(_, _, isCurrent, _, _, _, link, _, _) = component.subject {
                    if link != nil {
                        height += 66.0
                        
                        if let _ = component.openGift {
                            height += 100.0
                        }
                    } else {
                        if isCurrent {
                            height -= 53.0
                        } else {
                            height -= 53.0 - 32.0
                        }
                    }
                }
                
                contentSize = CGSize(width: context.availableSize.width, height: height + environment.safeInsets.bottom)
            }
            
            return contentSize
        }
    }
}

private final class LimitSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumLimitScreen.Subject
    let count: Int32
    let cancel: () -> Void
    let action: () -> Bool
    let openPeer: (EnginePeer) -> Void
    let openStats: (() -> Void)?
    let openGift: (() -> Void)?
    
    init(context: AccountContext, subject: PremiumLimitScreen.Subject, count: Int32, cancel: @escaping () -> Void, action: @escaping () -> Bool, openPeer: @escaping (EnginePeer) -> Void, openStats: (() -> Void)?, openGift: (() -> Void)?) {
        self.context = context
        self.subject = subject
        self.count = count
        self.cancel = cancel
        self.action = action
        self.openPeer = openPeer
        self.openStats = openStats
        self.openGift = openGift
    }
    
    static func ==(lhs: LimitSheetComponent, rhs: LimitSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(LimitSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        count: context.component.count,
                        cancel: context.component.cancel,
                        action: context.component.action,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        },
                        openPeer: context.component.openPeer,
                        openStats: context.component.openStats,
                        openGift: context.component.openGift
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public class PremiumLimitScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case folders
        case chatsPerFolder
        case pins
        case pinnedSavedPeers
        case files
        case accounts
        case linksPerSharedFolder
        case membershipInSharedFolders
        case channels
        case expiringStories
        case storiesWeekly
        case storiesMonthly
        
        public enum BoostSubject: Equatable {
            case stories
            case nameColors(colors: PeerNameColor)
            case channelReactions(reactionCount: Int)
        }
        
        case storiesChannelBoost(peer: EnginePeer, boostSubject: BoostSubject, isCurrent: Bool, level: Int32, currentLevelBoosts: Int32, nextLevelBoosts: Int32?, link: String?, myBoostCount: Int32, canBoostAgain: Bool)
    }
    
    private let context: AccountContext
    private var action: (() -> Bool)?
    private let openPeer: (EnginePeer) -> Void
    public var disposed: () -> Void = {}
    
    private let hapticFeedback = HapticFeedback()
    
    public init(context: AccountContext, subject: PremiumLimitScreen.Subject, count: Int32, forceDark: Bool = false, cancel: @escaping () -> Void = {}, action: @escaping () -> Bool, openPeer: @escaping (EnginePeer) -> Void = { _ in }, openStats: (() -> Void)? = nil, openGift: (() -> Void)? = nil) {
        self.context = context
        self.openPeer = openPeer
        
        var actionImpl: (() -> Bool)?
        super.init(context: context, component: LimitSheetComponent(context: context, subject: subject, count: count, cancel: {}, action: {
            return actionImpl?() ?? true
        }, openPeer: openPeer, openStats: openStats, openGift: openGift), navigationBarAppearance: .none, statusBarStyle: .ignore, theme: forceDark ? .dark : .default)
        
        self.navigationPresentation = .flatModal
        if case .storiesChannelBoost = subject {
            self.automaticallyControlPresentationContextLayout = false
        }
        
        self.wasDismissed = cancel
        
        actionImpl = { [weak self] in
            if action() {
                self?.wasDismissed = nil
                return true
            } else {
                return false
            }
        }
        self.action = actionImpl
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
    
    public func updateSubject(_ subject: Subject, count: Int32) {
        let component = LimitSheetComponent(
            context: self.context,
            subject: subject,
            count: count,
            cancel: {},
            action: { [weak self] in
                return self?.action?() ?? true
            },
            openPeer: self.openPeer,
            openStats: nil,
            openGift: nil
        )
        self.updateComponent(component: AnyComponent(component), transition: .easeInOut(duration: 0.2))
                
        self.animateSuccess()
    }
    
    public func animateSuccess() {
        self.hapticFeedback.impact()
        self.view.addSubview(ConfettiView(frame: self.view.bounds))
    }
}

public final class BoostIconComponent: Component {
    let hasIcon: Bool
    let text: String

    public init(hasIcon: Bool, text: String) {
        self.hasIcon = hasIcon
        self.text = text
    }

    public static func ==(lhs: BoostIconComponent, rhs: BoostIconComponent) -> Bool {
        if lhs.hasIcon != rhs.hasIcon {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let badgeBackground = UIView()
        private let badgeIcon: UIImageView
        private let badgeText = ComponentView<Empty>()
        
        private var component: BoostIconComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.badgeIcon = UIImageView(image: UIImage(bundleImageName: "Premium/BoostButtonIcon"))
            
            super.init(frame: frame)
                                                
            self.badgeBackground.clipsToBounds = true
            self.badgeBackground.backgroundColor = UIColor(rgb: 0x9671ff)
            
            self.addSubview(self.badgeBackground)
            self.addSubview(self.badgeIcon)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BoostIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                    
            let textSize = self.badgeText.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.text, font: Font.with(size: 10.0, design: .round, weight: .bold), textColor: .white, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let spacing: CGFloat = 2.0
            var totalWidth = textSize.width
            var iconSize = CGSize()
            if let icon = self.badgeIcon.image, component.hasIcon {
                iconSize = CGSize(width: icon.size.width * 0.9, height: icon.size.height * 0.9)
                totalWidth += spacing + icon.size.width
            }
            
            let size = CGSize(width: totalWidth + 8.0, height: 19.0)
            
            let iconFrame = CGRect(x: floorToScreenPixels((size.width - totalWidth) / 2.0 + 1.0), y: 4.0 + UIScreenPixel, width: iconSize.width, height: iconSize.height)
            self.badgeIcon.frame = iconFrame
            
            let textFrame = CGRect(origin: CGPoint(x: component.hasIcon ? iconFrame.maxX + spacing : 5.0, y: 4.0), size: textSize)
            
            if let view = self.badgeText.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = textFrame
            }
            
            self.badgeBackground.frame = CGRect(origin: .zero, size: size)
            self.badgeBackground.layer.cornerRadius = size.height / 2.0
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class BoostedTitleContent: CombinedComponent {
    let text: NSAttributedString
    let badge: String?
  
    init(
        text: NSAttributedString,
        badge: String?
    ) {
        self.text = text
        self.badge = badge
    }
    
    static func ==(lhs: BoostedTitleContent, rhs: BoostedTitleContent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        return true
    }
    
    static var body: Body {
        let text = Child(MultilineTextComponent.self)
        let badge = Child(BoostIconComponent.self)
        
        return { context in
            let component = context.component
            
            let height: CGFloat = 24.0
            var totalWidth: CGFloat = 0.0
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(component.text),
                    horizontalAlignment: .center
                ),
                availableSize: CGSize(width: context.availableSize.width - 40.0, height: context.availableSize.height),
                transition: .immediate
            )
            totalWidth += text.size.width
            context.add(text
                .position(CGPoint(x: text.size.width / 2.0, y: height / 2.0))
            )
            
            if let badgeText = component.badge {
                let badge = badge.update(
                    component: BoostIconComponent(hasIcon: false, text: badgeText),
                    availableSize: CGSize(width: 24.0, height: 24.0),
                    transition: .immediate
                )
                totalWidth += badge.size.width + 4.0
                context.add(badge
                    .position(CGPoint(x: totalWidth - badge.size.width / 2.0, y: height / 2.0))
                )
            }
            
            return CGSize(width: totalWidth, height: height)
        }
    }
}
