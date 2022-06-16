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
import SheetComponent
import MultilineTextComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown

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

private class PremiumLimitAnimationComponent: Component {
    private let iconName: String?
    private let inactiveColor: UIColor
    private let activeColors: [UIColor]
    private let textColor: UIColor
    private let badgeText: String?
    private let badgePosition: CGFloat
    private let isPremiumDisabled: Bool
    
    init(
        iconName: String?,
        inactiveColor: UIColor,
        activeColors: [UIColor],
        textColor: UIColor,
        badgeText: String?,
        badgePosition: CGFloat,
        isPremiumDisabled: Bool
    ) {
        self.iconName = iconName
        self.inactiveColor = inactiveColor
        self.activeColors = activeColors
        self.textColor = textColor
        self.badgeText = badgeText
        self.badgePosition = badgePosition
        self.isPremiumDisabled = isPremiumDisabled
    }
    
    static func ==(lhs: PremiumLimitAnimationComponent, rhs: PremiumLimitAnimationComponent) -> Bool {
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.inactiveColor != rhs.inactiveColor {
            return false
        }
        if lhs.activeColors != rhs.activeColors {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.badgeText != rhs.badgeText {
            return false
        }
        if lhs.badgePosition != rhs.badgePosition {
            return false
        }
        if lhs.isPremiumDisabled != rhs.isPremiumDisabled {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let container: SimpleLayer
        private let inactiveBackground: SimpleLayer
        
        private let activeContainer: SimpleLayer
        private let activeBackground: SimpleLayer
        
        private let badgeView: UIView
        private let badgeMaskView: UIView
        private let badgeMaskBackgroundView: UIView
        private let badgeMaskArrowView: UIImageView
        private let badgeMaskTailView: UIImageView
        private let badgeForeground: SimpleLayer
        private let badgeIcon: UIImageView
        private let badgeCountLabel: RollingLabel
        
        private let hapticFeedback = HapticFeedback()
        
        override init(frame: CGRect) {
            self.container = SimpleLayer()
            self.container.masksToBounds = true
            self.container.cornerRadius = 6.0
            
            self.inactiveBackground = SimpleLayer()
            
            self.activeContainer = SimpleLayer()
            self.activeContainer.masksToBounds = true
            
            self.activeBackground = SimpleLayer()
            
            self.badgeView = UIView()
            self.badgeView.alpha = 0.0
            
            self.badgeMaskBackgroundView = UIView()
            self.badgeMaskBackgroundView.backgroundColor = .white
            self.badgeMaskBackgroundView.layer.cornerRadius = 24.0
            
            self.badgeMaskArrowView = UIImageView()
            self.badgeMaskArrowView.image = generateImage(CGSize(width: 44.0, height: 12.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.scaleBy(x: 3.76, y: 3.76)
                context.translateBy(x: -9.3, y: -12.7)
                try? drawSvgPath(context, path: "M6.4,0.0 C2.9,0.0 0.0,2.84 0.0,6.35 C0.0,9.86 2.9,12.7 6.4,12.7 H9.302 H11.3 C11.7,12.7 12.1,12.87 12.4,13.17 L14.4,15.13 C14.8,15.54 15.5,15.54 15.9,15.13 L17.8,13.17 C18.1,12.87 18.5,12.7 18.9,12.7 H20.9 H23.6 C27.1,12.7 29.9,9.86 29.9,6.35 C29.9,2.84 27.1,0.0 23.6,0.0 Z ")
            })
            
            self.badgeMaskTailView = UIImageView()
            self.badgeMaskTailView.isHidden = true
            
            
            let img = generateImage(CGSize(width: 44.0, height: 36.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 44.0, height: 24.0)))
                context.translateBy(x: 22.0, y: 24.0)
                try? drawSvgPath(context, path: "M0.0,0.0 H22.0 V4.75736 C22.0,7.43007 18.7686,8.76857 16.8787,6.87868 L11.7574,1.75736 C10.6321,0.632141 9.10602,0.0 7.51472,0.0 H0.0 Z ")
            })
            self.badgeMaskTailView.image = img
            
            self.badgeMaskView = UIView()
            self.badgeMaskView.addSubview(self.badgeMaskBackgroundView)
            self.badgeMaskView.addSubview(self.badgeMaskArrowView)
            self.badgeMaskView.addSubview(self.badgeMaskTailView)
            self.badgeMaskView.layer.rasterizationScale = UIScreenScale
            self.badgeMaskView.layer.shouldRasterize = true
            self.badgeView.mask = self.badgeMaskView
            
            self.badgeForeground = SimpleLayer()
            
            self.badgeIcon = UIImageView()
            self.badgeIcon.contentMode = .center
            
            self.badgeCountLabel = RollingLabel()
            self.badgeCountLabel.font = Font.with(size: 24.0, design: .round, weight: .semibold, traits: [])
            self.badgeCountLabel.textColor = .white
            self.badgeCountLabel.configure(with: "0")
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.container)
            self.container.addSublayer(self.inactiveBackground)
            self.container.addSublayer(self.activeContainer)
            self.activeContainer.addSublayer(self.activeBackground)
            
            self.addSubview(self.badgeView)
            self.badgeView.layer.addSublayer(self.badgeForeground)
            self.badgeView.addSubview(self.badgeIcon)
            self.badgeView.addSubview(self.badgeCountLabel)
            
            self.isUserInteractionEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var didPlayAppearanceAnimation = false
        func playAppearanceAnimation(component: PremiumLimitAnimationComponent, availableSize: CGSize) {
            self.badgeView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.4, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                        
            let positionAnimation = CABasicAnimation(keyPath: "position.x")
            positionAnimation.fromValue = NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0))
            positionAnimation.toValue = NSValue(cgPoint: self.badgeView.center)
            positionAnimation.duration = 0.5
            positionAnimation.fillMode = .forwards
            self.badgeView.layer.add(positionAnimation, forKey: "appearance1")
           
            
            Queue.mainQueue().after(0.5, {
                let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotateAnimation.fromValue = 0.0 as NSNumber
                rotateAnimation.toValue = 0.2 as NSNumber
                rotateAnimation.duration = 0.2
                rotateAnimation.fillMode = .forwards
                rotateAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                rotateAnimation.isRemovedOnCompletion = false
                self.badgeView.layer.add(rotateAnimation, forKey: "appearance2")
                
                if !self.badgeView.isHidden {
                    self.hapticFeedback.impact(.light)
                }
                
                Queue.mainQueue().after(0.2) {
                    let returnAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    returnAnimation.fromValue = 0.2 as NSNumber
                    returnAnimation.toValue = 0.0 as NSNumber
                    returnAnimation.duration = 0.18
                    returnAnimation.fillMode = .forwards
                    returnAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    self.badgeView.layer.add(returnAnimation, forKey: "appearance3")
                    self.badgeView.layer.removeAnimation(forKey: "appearance2")
                }
            })
            
            self.badgeView.alpha = 1.0
            self.badgeView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            
            if let badgeText = component.badgeText {
                self.badgeCountLabel.configure(with: badgeText)
            }
        }
        
        var previousAvailableSize: CGSize?
        func update(component: PremiumLimitAnimationComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.inactiveBackground.backgroundColor = component.inactiveColor.cgColor
            self.activeBackground.backgroundColor = component.activeColors.last?.cgColor
            
            self.badgeIcon.image = component.iconName.flatMap { UIImage(bundleImageName: $0)?.withRenderingMode(.alwaysTemplate) }
            self.badgeIcon.tintColor = component.textColor
            self.badgeView.isHidden = self.badgeIcon.image == nil
            
            let lineHeight: CGFloat = 30.0
            let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - lineHeight), size: CGSize(width: availableSize.width, height: lineHeight))
            self.container.frame = containerFrame
            
            if !component.isPremiumDisabled {
                self.inactiveBackground.frame = CGRect(origin: .zero, size: CGSize(width: containerFrame.width / 2.0, height: lineHeight))
                self.activeContainer.frame = CGRect(origin: CGPoint(x: containerFrame.width / 2.0, y: 0.0), size: CGSize(width: containerFrame.width / 2.0, height: lineHeight))
                
                self.activeBackground.bounds = CGRect(origin: .zero, size: CGSize(width: containerFrame.width * 3.0 / 2.0, height: lineHeight))
                if self.activeBackground.animation(forKey: "movement") == nil {
                    self.activeBackground.position = CGPoint(x: containerFrame.width * 3.0 / 4.0 - self.activeBackground.frame.width * 0.35, y: lineHeight / 2.0)
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
                    default:
                        countWidth = 51.0
                }
            } else {
                countWidth = 51.0
            }
            let badgeWidth: CGFloat = countWidth + 62.0
            
            let badgeSize = CGSize(width: badgeWidth, height: 48.0 + 12.0)
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeSize)
            self.badgeMaskBackgroundView.frame = CGRect(origin: .zero, size: CGSize(width: badgeSize.width, height: 48.0))
            self.badgeMaskArrowView.frame = CGRect(origin: CGPoint(x: (badgeSize.width - 44.0) / 2.0, y: badgeSize.height - 12.0), size: CGSize(width: 44.0, height: 12.0))
            
            self.badgeMaskTailView.frame = CGRect(origin: CGPoint(x: badgeSize.width - 44.0, y: badgeSize.height - 36.0), size: CGSize(width: 44.0, height: 36.0))
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeSize)
            
            var badgePosition = component.badgePosition
            if component.isPremiumDisabled {
                badgePosition = 0.5
            }
            if badgePosition > 1.0 - .ulpOfOne {
                self.badgeView.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
                
                self.badgeMaskTailView.isHidden = false
                self.badgeMaskArrowView.isHidden = true
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                    
                } else {
                    self.badgeView.center = CGPoint(x: 3.0 + (availableSize.width - 6.0) * badgePosition + 3.0, y: 82.0)
                }
            } else {
                self.badgeView.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                
                self.badgeMaskTailView.isHidden = true
                self.badgeMaskArrowView.isHidden = component.isPremiumDisabled
                
                if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                    
                } else {
                    self.badgeView.center = CGPoint(x: 3.0 + (availableSize.width - 6.0) * badgePosition, y: 82.0)
                }
                
                if self.badgeView.frame.maxX > availableSize.width {
                    let delta = self.badgeView.frame.maxX - availableSize.width - 6.0
                    if let _ = self.badgeView.layer.animation(forKey: "appearance1") {
                        
                    } else {
                        self.badgeView.center = self.badgeView.center.offsetBy(dx: -delta, dy: 0.0)
                    }
                }
            }
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: badgeSize.width * 3.0, height: badgeSize.height))
            if self.badgeForeground.animation(forKey: "movement") == nil {
                self.badgeForeground.position = CGPoint(x: badgeSize.width * 3.0 / 2.0 - self.badgeForeground.frame.width * 0.35, y: badgeSize.height / 2.0)
            }
    
            self.badgeIcon.frame = CGRect(x: 15.0, y: 9.0, width: 30.0, height: 30.0)
            self.badgeCountLabel.frame = CGRect(x: badgeSize.width - countWidth - 11.0, y: 10.0, width: countWidth, height: 48.0)
            
            if component.isPremiumDisabled {
                if !self.didPlayAppearanceAnimation {
                    self.didPlayAppearanceAnimation = true
                    
                    self.badgeView.alpha = 1.0
                    if let badgeText = component.badgeText {
                        self.badgeCountLabel.configure(with: badgeText, duration: 0.3)
                    }
                }
            } else if !self.didPlayAppearanceAnimation {
                self.didPlayAppearanceAnimation = true
                self.playAppearanceAnimation(component: component, availableSize: availableSize)
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
            
            return availableSize
        }
        
        private func setupGradientAnimations() {
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
                
                let lineOffset = (self.activeBackground.frame.width - self.activeContainer.bounds.width) / 2.0
                let linePreviousValue = self.activeBackground.position.x
                var lineNewValue: CGFloat = lineOffset
                if lineOffset - linePreviousValue < self.activeBackground.frame.width * 0.25 {
                    lineNewValue -= self.activeBackground.frame.width * 0.35
                }
                self.activeBackground.position = CGPoint(x: lineNewValue, y: self.activeBackground.bounds.size.height / 2.0)
                                
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
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

public final class PremiumLimitDisplayComponent: CombinedComponent {
    let inactiveColor: UIColor
    let activeColors: [UIColor]
    let inactiveTitle: String
    let inactiveValue: String
    let inactiveTitleColor: UIColor
    let activeTitle: String
    let activeValue: String
    let activeTitleColor: UIColor
    let badgeIconName: String?
    let badgeText: String?
    let badgePosition: CGFloat
    let isPremiumDisabled: Bool
    
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
        if lhs.isPremiumDisabled != rhs.isPremiumDisabled {
            return false
        }
        return true
    }
    
    public static var body: Body {
        let inactiveTitle = Child(MultilineTextComponent.self)
        let inactiveValue = Child(MultilineTextComponent.self)
        let activeTitle = Child(MultilineTextComponent.self)
        let activeValue = Child(MultilineTextComponent.self)
        let animation = Child(PremiumLimitAnimationComponent.self)

        return { context in
            let component = context.component
            
            let height: CGFloat = 120.0
            let lineHeight: CGFloat = 30.0
            
            let animation = animation.update(
                component: PremiumLimitAnimationComponent(
                    iconName: component.badgeIconName,
                    inactiveColor: component.inactiveColor,
                    activeColors: component.activeColors,
                    textColor: component.activeTitleColor,
                    badgeText: component.badgeText,
                    badgePosition: component.badgePosition,
                    isPremiumDisabled: component.isPremiumDisabled
                ),
                availableSize: CGSize(width: context.availableSize.width, height: height),
                transition: context.transition
            )
            
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: height / 2.0))
            )
            
            if !component.isPremiumDisabled {
                let inactiveTitle = inactiveTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.inactiveTitle,
                                font: Font.semibold(15.0),
                                textColor: component.inactiveTitleColor
                            )
                        )
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                let inactiveValue = inactiveValue.update(
                    component: MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.inactiveValue,
                                font: Font.semibold(15.0),
                                textColor: component.inactiveTitleColor
                            )
                        )
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                let activeTitle = activeTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.activeTitle,
                                font: Font.semibold(15.0),
                                textColor: component.activeTitleColor
                            )
                        )
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                let activeValue = activeValue.update(
                    component: MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.activeValue,
                                font: Font.semibold(15.0),
                                textColor: component.activeTitleColor
                            )
                        )
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                context.add(inactiveTitle
                    .position(CGPoint(x: inactiveTitle.size.width / 2.0 + 12.0, y: height - lineHeight / 2.0))
                )
                
                context.add(inactiveValue
                    .position(CGPoint(x: context.availableSize.width / 2.0 - inactiveValue.size.width / 2.0 - 12.0, y: height - lineHeight / 2.0))
                )
                
                context.add(activeTitle
                    .position(CGPoint(x: context.availableSize.width / 2.0 + activeTitle.size.width / 2.0 + 12.0, y: height - lineHeight / 2.0))
                )
                
                context.add(activeValue
                    .position(CGPoint(x: context.availableSize.width - activeValue.size.width / 2.0 - 12.0, y: height - lineHeight / 2.0))
                )
            }
                           
            return CGSize(width: context.availableSize.width, height: height)
        }
    }
}

private final class LimitSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumLimitScreen.Subject
    let count: Int32
    let action: () -> Void
    let dismiss: () -> Void
    
    init(context: AccountContext, subject: PremiumLimitScreen.Subject, count: Int32, action: @escaping () -> Void, dismiss: @escaping () -> Void) {
        self.context = context
        self.subject = subject
        self.count = count
        self.action = action
        self.dismiss = dismiss
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
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        
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
        let text = Child(MultilineTextComponent.self)
        let limit = Child(PremiumLimitDisplayComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            
            let state = context.state
            let subject = component.subject
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 24.0 + environment.safeInsets.left
            
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
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
             
            var titleText = strings.Premium_LimitReached
            var buttonAnimationName = "premium_x2"
            let iconName: String
            var badgeText: String
            var string: String
            let defaultValue: String
            let premiumValue: String
            let badgePosition: CGFloat
            switch subject {
                case .folders:
                    let limit = state.limits.maxFoldersCount
                    let premiumLimit = state.premiumLimits.maxFoldersCount
                    iconName = "Premium/Folder"
                    badgeText = "\(component.count)"
                    string = component.count >= premiumLimit ? strings.Premium_MaxFoldersCountFinalText("\(premiumLimit)").string : strings.Premium_MaxFoldersCountText("\(limit)", "\(premiumLimit)").string
                    defaultValue = component.count > limit ? "\(limit)" : ""
                    premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                    badgePosition = CGFloat(component.count) / CGFloat(premiumLimit)
                
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
                
                    if isPremiumDisabled {
                        badgeText = "\(limit)"
                        string = strings.Premium_MaxChatsInFolderNoPremiumText("\(limit)").string
                    }
                case .pins:
                    let limit = state.limits.maxPinnedChatCount
                    let premiumLimit = state.premiumLimits.maxPinnedChatCount
                    iconName = "Premium/Pin"
                    badgeText = "\(component.count)"
                    string = component.count >= premiumLimit ? strings.Premium_MaxPinsFinalText("\(premiumLimit)").string : strings.Premium_MaxPinsText("\(limit)", "\(premiumLimit)").string
                    defaultValue = component.count > limit ? "\(limit)" : ""
                    premiumValue = component.count >= premiumLimit ? "" : "\(premiumLimit)"
                    badgePosition = CGFloat(component.count) / CGFloat(premiumLimit)
                
                    if isPremiumDisabled {
                        badgeText = "\(limit)"
                        string = strings.Premium_MaxPinsNoPremiumText("\(limit)").string
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
                    buttonAnimationName = "premium_addone"
                
                    if isPremiumDisabled {
                        badgeText = "\(limit)"
                        string = strings.Premium_MaxAccountsNoPremiumText("\(limit)").string
                    }
            }
            var reachedMaximumLimit = badgePosition >= 1.0
            if case .folders = subject, !state.isPremium {
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
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                
                let textFont = Font.regular(17.0)
                let boldTextFont = Font.semibold(17.0)
                let textColor = theme.actionSheet.primaryTextColor
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: textColor), linkAttribute: { _ in
                    return nil
                })
                
                let text = text.update(
                    component: MultilineTextComponent(
                        text: .markdown(text: string, attributes: markdownAttributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.0
                    ),
                    availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                    transition: .immediate
                )
                
                let gradientColors: [UIColor]
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
                
                let limit = limit.update(
                    component: PremiumLimitDisplayComponent(
                        inactiveColor: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.5),
                        activeColors: gradientColors,
                        inactiveTitle: strings.Premium_Free,
                        inactiveValue: defaultValue,
                        inactiveTitleColor: theme.list.itemPrimaryTextColor,
                        activeTitle: strings.Premium_Premium,
                        activeValue: premiumValue,
                        activeTitleColor: .white,
                        badgeIconName: iconName,
                        badgeText: badgeText,
                        badgePosition: badgePosition,
                        isPremiumDisabled: isPremiumDisabled
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(limit
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: limit.size.height / 2.0 + 44.0))
                )
            
                let isIncreaseButton = !reachedMaximumLimit && !isPremiumDisabled
                let button = button.update(
                    component: SolidRoundedButtonComponent(
                        title: isIncreaseButton ? strings.Premium_IncreaseLimit : strings.Common_OK,
                        
                        theme: SolidRoundedButtonComponent.Theme(
                            backgroundColor: .black,
                            backgroundColors: gradientColors,
                            foregroundColor: .white
                        ),
                        font: .bold,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: isIncreaseButton,
                        animationName: isIncreaseButton ? buttonAnimationName : nil,
                        iconPosition: .right,
                        action: { [weak component] in
                            guard let component = component else {
                                return
                            }
                            component.dismiss()
                            if isIncreaseButton {
                                component.action()
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
                
                var textOffset: CGFloat = 228.0
                if isPremiumDisabled {
                    textOffset -= 68.0
                }
                
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 28.0))
                )
                context.add(text
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: textOffset))
                )
                
                let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: textOffset + ceil(text.size.height / 2.0) + 38.0), size: button.size)
                context.add(button
                    .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
                )
            
                contentSize = CGSize(width: context.availableSize.width, height: buttonFrame.maxY + 5.0 + environment.safeInsets.bottom)
            } else {
                contentSize = CGSize(width: context.availableSize.width, height: 351.0 + environment.safeInsets.bottom)
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
    let action: () -> Void
    
    init(context: AccountContext, subject: PremiumLimitScreen.Subject, count: Int32, action: @escaping () -> Void) {
        self.context = context
        self.subject = subject
        self.count = count
        self.action = action
    }
    
    static func ==(lhs: LimitSheetComponent, rhs: LimitSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(LimitSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        count: context.component.count,
                        action: context.component.action,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: environment.theme.actionSheet.opaqueItemBackgroundColor,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
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
            
            return context.availableSize
        }
    }
}

public class PremiumLimitScreen: ViewControllerComponentContainer {
    public enum Subject {
        case folders
        case chatsPerFolder
        case pins
        case files
        case accounts
    }
    
    public init(context: AccountContext, subject: PremiumLimitScreen.Subject, count: Int32, action: @escaping () -> Void) {
        super.init(context: context, component: LimitSheetComponent(context: context, subject: subject, count: count, action: action), navigationBarAppearance: .none)
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
}
