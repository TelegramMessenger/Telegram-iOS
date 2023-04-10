import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import AccountContext
import MultilineTextComponent
import TelegramPresentationData

final class BadgeComponent: Component {
    let fillColor: UIColor
    let content: AnyComponent<Empty>
    
    init(
        fillColor: UIColor,
        content: AnyComponent<Empty>
    ) {
        self.fillColor = fillColor
        self.content = content
    }
    
    static func ==(lhs: BadgeComponent, rhs: BadgeComponent) -> Bool {
        if lhs.fillColor != rhs.fillColor {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundLayer: SimpleLayer
        private let content = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.backgroundLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let height: CGFloat = 20.0
            let contentInset: CGFloat = 10.0
            
            let contentSize = self.content.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )
            let backgroundWidth: CGFloat = max(height, contentSize.width + contentInset)
            let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: backgroundWidth, height: height))
            
            transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
            transition.setBackgroundColor(layer: self.backgroundLayer, color: component.fillColor)
            transition.setCornerRadius(layer: self.backgroundLayer, cornerRadius: height / 2.0)
            
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: floor((backgroundFrame.width - contentSize.width) * 0.5), y: floor((backgroundFrame.height - contentSize.height) * 0.5)), size: contentSize))
            }
            
            return backgroundFrame.size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ChatFolderLinkHeaderComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let title: String
    let badge: String?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        title: String,
        badge: String?
    ) {
        self.theme = theme
        self.strings = strings
        self.title = title
        self.badge = badge
    }
    
    static func ==(lhs: ChatFolderLinkHeaderComponent, rhs: ChatFolderLinkHeaderComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let leftView = UIImageView()
        private let rightView = UIImageView()
        private let title = ComponentView<Empty>()
        private let separatorLayer = SimpleLayer()
        
        private var badge: ComponentView<Empty>?
        
        private var component: ChatFolderLinkHeaderComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.leftView)
            self.addSubview(self.rightView)
            self.layer.addSublayer(self.separatorLayer)
            
            self.separatorLayer.cornerRadius = 2.0
            self.separatorLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatFolderLinkHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            
            let height: CGFloat = 60.0
            let spacing: CGFloat = 16.0
            let badgeSpacing: CGFloat = 6.0
            
            if themeUpdated {
                let leftString = NSAttributedString(string: component.strings.FolderLinkPreview_IconTabLeft, font: Font.semibold(14.0), textColor: component.theme.list.freeTextColor)
                let rightString = NSAttributedString(string: component.strings.FolderLinkPreview_IconTabRight, font: Font.semibold(14.0), textColor: component.theme.list.freeTextColor)
                
                let leftStringBounds = leftString.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                let rightStringBounds = rightString.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                
                self.leftView.image = generateImage(leftStringBounds.size.integralFloor, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    
                    leftString.draw(in: leftStringBounds)
                    
                    var colors: [UIColor] = []
                    var locations: [CGFloat] = []
                    for i in 0 ... 8 {
                        let t: CGFloat = CGFloat(i) / CGFloat(8)
                        let a: CGFloat = t * t
                        colors.append(UIColor(white: 1.0, alpha: a))
                        locations.append(t)
                    }
                    
                    if let image = generateGradientImage(size: CGSize(width: size.width * 0.8, height: 16.0), colors: colors, locations: locations, direction: .horizontal) {
                        image.draw(in: CGRect(origin: CGPoint(), size: CGSize(width: image.size.width, height: size.height)), blendMode: .destinationIn, alpha: 1.0)
                    }
                    
                    UIGraphicsPopContext()
                })
                self.leftView.alpha = 0.5
                
                self.rightView.image = generateImage(rightStringBounds.size.integralFloor, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    
                    rightString.draw(in: rightStringBounds)
                    
                    var colors: [UIColor] = []
                    var locations: [CGFloat] = []
                    for i in 0 ... 8 {
                        let t: CGFloat = CGFloat(i) / CGFloat(8)
                        let a: CGFloat = 1.0 - t * t
                        colors.append(UIColor(white: 1.0, alpha: a))
                        locations.append(t)
                    }
                    
                    if let image = generateGradientImage(size: CGSize(width: size.width * 0.8, height: 16.0), colors: colors, locations: locations, direction: .horizontal) {
                        image.draw(in: CGRect(origin: CGPoint(x: size.width - image.size.width, y: 0.0), size: CGSize(width: image.size.width, height: size.height)), blendMode: .destinationIn, alpha: 1.0)
                    }
                    
                    UIGraphicsPopContext()
                })
                self.rightView.alpha = 0.5
                
                self.separatorLayer.backgroundColor = component.theme.list.itemAccentColor.cgColor
            }
            
            var contentWidth: CGFloat = 0.0
            if let leftImage = self.leftView.image {
                contentWidth += leftImage.size.width
            }
            contentWidth += spacing
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.title, font: Font.semibold(17.0), color: component.theme.list.itemAccentColor)),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            contentWidth += titleSize.width
            
            var badgeSize: CGSize?
            if let badge = component.badge {
                let badgeContainer: ComponentView<Empty>
                var badgeTransition = transition
                if let current = self.badge {
                    badgeContainer = current
                } else {
                    badgeTransition = .immediate
                    badgeContainer = ComponentView()
                    self.badge = badgeContainer
                }
                let badgeSizeValue = badgeContainer.update(
                    transition: badgeTransition,
                    component: AnyComponent(BadgeComponent(
                        fillColor: component.theme.list.itemCheckColors.fillColor,
                        content: AnyComponent(Text(text: badge, font: Font.semibold(12.0), color: component.theme.list.itemCheckColors.foregroundColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                badgeSize = badgeSizeValue
                contentWidth += badgeSpacing + badgeSizeValue.width
            } else {
                if let badge = self.badge {
                    self.badge = nil
                    if let view = badge.view {
                        transition.setScale(view: view, scale: 0.0001, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    }
                }
            }
            
            contentWidth += spacing
            if let rightImage = self.rightView.image {
                contentWidth += rightImage.size.width
            }
            
            var contentOriginX: CGFloat = 0.0
            
            if let leftImage = self.leftView.image {
                transition.setFrame(view: self.leftView, frame: CGRect(origin: CGPoint(x: contentOriginX, y: floor((height - leftImage.size.height) / 2.0) - 1.0), size: leftImage.size))
                contentOriginX += leftImage.size.width
            }
            contentOriginX += spacing
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                let titleFrame = CGRect(origin: CGPoint(x: contentOriginX, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
                transition.setFrame(view: titleView, frame: titleFrame)
                
                var separatorWidth = titleFrame.width
                
                if let badgeSize, let badge = self.badge {
                    let badgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + badgeSpacing, y: titleFrame.minY + 1.0 + floor((titleFrame.height - badgeSize.height) * 0.5)), size: badgeSize)
                    
                    separatorWidth += badgeSpacing + badgeSize.width
                    
                    if let badgeView = badge.view {
                        var badgeTransition = transition
                        var animateIn = false
                        if badgeView.superview == nil {
                            badgeTransition = .immediate
                            self.addSubview(badgeView)
                            animateIn = true
                        }
                        badgeTransition.setFrame(view: badgeView, frame: badgeFrame)
                        if animateIn {
                            transition.animateScale(view: badgeView, from: 0.0001, to: 1.0)
                        }
                    }
                }
                
                transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + 9.0), size: CGSize(width: separatorWidth, height: 3.0)))
            }
            contentOriginX += titleSize.width
            if let badgeSize {
                contentOriginX += badgeSpacing
                contentOriginX += badgeSize.width
            }
            contentOriginX += spacing
            
            if let rightImage = self.rightView.image {
                transition.setFrame(view: self.rightView, frame: CGRect(origin: CGPoint(x: contentOriginX, y: floor((height - rightImage.size.height) / 2.0) - 1.0), size: rightImage.size))
                contentOriginX += rightImage.size.width
            }
            
            return CGSize(width: contentWidth, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
