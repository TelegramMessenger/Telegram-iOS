import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import AccountContext
import MultilineTextComponent
import TelegramPresentationData
import PresentationDataUtils
import SolidRoundedButtonComponent
import AnimatedTextComponent

final class StarsBalanceComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let count: Int64
    let purchaseAvailable: Bool
    let buy: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        count: Int64,
        purchaseAvailable: Bool,
        buy: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.count = count
        self.purchaseAvailable = purchaseAvailable
        self.buy = buy
    }
    
    static func ==(lhs: StarsBalanceComponent, rhs: StarsBalanceComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.purchaseAvailable != rhs.purchaseAvailable {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = UIImageView()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private var button = ComponentView<Empty>()
        
        private var component: StarsBalanceComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.icon.image = UIImage(bundleImageName: "Premium/Stars/BalanceStar")
            
            self.addSubview(self.icon)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StarsBalanceComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component
            
            let sideInset: CGFloat = 16.0
            var contentHeight: CGFloat = sideInset
            
            var animatedTextItems: [AnimatedTextComponent.Item] = []
            animatedTextItems.append(AnimatedTextComponent.Item(
                id: 1,
                isUnbreakable: true,
                content: .number(Int(component.count), minDigits: 1)
            ))
            
            let titleSize = self.title.update(
                transition: isFirstTime ? .immediate : .easeInOut(duration: 0.2),
                component: AnyComponent(
                    AnimatedTextComponent(
                        font: Font.with(size: 48.0, design: .round, weight: .semibold),
                        color: component.theme.list.itemPrimaryTextColor,
                        items: animatedTextItems
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                if let icon = self.icon.image {
                    let spacing: CGFloat = 3.0
                    let totalWidth = titleSize.width + icon.size.width + spacing
                    let origin = floorToScreenPixels((availableSize.width - totalWidth) / 2.0)
                    let titleFrame = CGRect(origin: CGPoint(x: origin + icon.size.width + spacing, y: contentHeight - 3.0), size: titleSize)
                    titleView.frame = titleFrame
                    
                    self.icon.frame = CGRect(origin: CGPoint(x: origin, y: contentHeight + 2.0), size: icon.size)
                }
            }
            contentHeight += titleSize.height
        
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.Stars_Intro_YourBalance, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor)),
                        horizontalAlignment: .center
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                let subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - subtitleSize.width) / 2.0), y: contentHeight - 4.0), size: subtitleSize)
                subtitleView.frame = subtitleFrame
            }
            contentHeight += subtitleSize.height
            
            if component.purchaseAvailable {
                contentHeight += 12.0
                
                let buttonSize = self.button.update(
                    transition: .immediate,
                    component: AnyComponent(
                        SolidRoundedButtonComponent(
                            title: component.strings.Stars_Intro_Buy,
                            theme: SolidRoundedButtonComponent.Theme(theme: component.theme),
                            height: 50.0,
                            cornerRadius: 11.0,
                            action: { [weak self] in
                                self?.component?.buy()
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
                )
                if let buttonView = self.button.view {
                    if buttonView.superview == nil {
                        self.addSubview(buttonView)
                    }
                    let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: buttonSize)
                    buttonView.frame = buttonFrame
                }
                contentHeight += buttonSize.height
            }
            contentHeight += sideInset
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
