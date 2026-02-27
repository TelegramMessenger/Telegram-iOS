import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import GlassBackgroundComponent

public class GiftRemainingCountComponent: Component {
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
    
    public static func ==(lhs: GiftRemainingCountComponent, rhs: GiftRemainingCountComponent) -> Bool {
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
        private var component: GiftRemainingCountComponent?
        
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
        
        private let activeChromeView = UIImageView()
                        
        override init(frame: CGRect) {
            self.container = UIView()
            self.container.clipsToBounds = true
            self.container.layer.cornerRadius = 15.0
            
            self.inactiveBackground = SimpleLayer()
            
            self.activeContainer = UIView()
            self.activeContainer.clipsToBounds = true
            self.activeContainer.layer.cornerRadius = 15.0
            
            self.activeBackground = SimpleLayer()
            self.activeBackground.anchorPoint = CGPoint()
                                                
            super.init(frame: frame)
            
            self.addSubview(self.container)
            self.container.layer.addSublayer(self.inactiveBackground)
            self.container.addSubview(self.activeContainer)
            self.activeContainer.layer.addSublayer(self.activeBackground)
            //self.activeContainer.addSubview(self.activeChromeView)
            
            self.activeChromeView.layer.compositingFilter = "overlayBlendMode"
            self.activeChromeView.alpha = 0.8
            self.activeChromeView.image = GlassBackgroundView.generateForegroundImage(size: CGSize(width: 30.0, height: 30.0), isDark: false, fillColor: .clear)
            
            self.isUserInteractionEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var previousAvailableSize: CGSize?
        func update(component: GiftRemainingCountComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.inactiveBackground.backgroundColor = component.inactiveColor.cgColor
            self.activeBackground.backgroundColor = component.activeColors.last?.cgColor
            
            let size = CGSize(width: availableSize.width, height: 90.0)
            
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
                    progressTransition.setFrame(layer: self.inactiveBackground, frame: CGRect(origin: CGPoint(x: activityPosition - 15.0, y: 0.0), size: CGSize(width: size.width - activityPosition + 15.0, height: lineHeight)))
                    progressTransition.setFrame(view: self.activeContainer, frame: CGRect(origin: .zero, size: CGSize(width: activityPosition, height: lineHeight)))
                    progressTransition.setBounds(layer: self.activeBackground, bounds: CGRect(origin: .zero, size: CGSize(width: containerFrame.width * 1.35, height: lineHeight)))
                } else {
                    progressTransition.setFrame(layer: self.inactiveBackground, frame: CGRect(origin: .zero, size: CGSize(width: activityPosition, height: lineHeight)))
                    progressTransition.setFrame(view: self.activeContainer, frame: CGRect(origin: CGPoint(x: activityPosition, y: 0.0), size: CGSize(width: activeWidth, height: lineHeight)))
                    progressTransition.setFrame(layer: self.activeBackground, frame: CGRect(origin: CGPoint(x: -activityPosition, y: 0.0), size: CGSize(width: containerFrame.width * 1.35, height: lineHeight)))
                }
                
                progressTransition.setFrame(view: self.activeChromeView, frame: CGRect(origin: CGPoint(x: -activityPosition, y: 0.0), size: CGSize(width: activeWidth, height: lineHeight)))
                
                if self.activeBackground.animation(forKey: "movement") == nil {
                    self.activeBackground.position = CGPoint(x: -self.activeContainer.frame.width * 0.35, y: lineHeight / 2.0)
                }
            }
            
            if self.previousAvailableSize != availableSize {
                self.previousAvailableSize = availableSize
                
                var locations: [CGFloat] = []
                let delta = 1.0 / CGFloat(component.activeColors.count - 1)
                for i in 0 ..< component.activeColors.count {
                    locations.append(delta * CGFloat(i))
                }
                
                let gradient = generateGradientImage(size: CGSize(width: 200.0, height: 60.0), colors: Array(component.activeColors.reversed()), locations: locations, direction: .horizontal)
                
                self.activeBackground.contentsGravity = .resizeAspectFill
                self.activeBackground.contents = gradient?.cgImage
                
                self.setupGradientAnimations()
            }
            
            return size
        }
        
        private func setupGradientAnimations() {
            guard let _ = self.component else {
                return
            }
            if let _ = self.activeBackground.animation(forKey: "movement") {
            } else {
                CATransaction.begin()
                
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
