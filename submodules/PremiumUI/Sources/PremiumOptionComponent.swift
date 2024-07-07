import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import CheckNode
import Markdown

final class PremiumOptionComponent: CombinedComponent {
    let title: String
    let subtitle: String
    let labelPrice: String
    let discount: String
    let multiple: Bool
    let selected: Bool
    let primaryTextColor: UIColor
    let secondaryTextColor: UIColor
    let accentColor: UIColor
    let checkForegroundColor: UIColor
    let checkBorderColor: UIColor
    
    init(
        title: String,
        subtitle: String,
        labelPrice: String,
        discount: String,
        multiple: Bool = false,
        selected: Bool,
        primaryTextColor: UIColor,
        secondaryTextColor: UIColor,
        accentColor: UIColor,
        checkForegroundColor: UIColor,
        checkBorderColor: UIColor
    ) {
        self.title = title
        self.subtitle = subtitle
        self.labelPrice = labelPrice
        self.discount = discount
        self.multiple = multiple
        self.selected = selected
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.checkForegroundColor = checkForegroundColor
        self.checkBorderColor = checkBorderColor
    }
    
    static func ==(lhs: PremiumOptionComponent, rhs: PremiumOptionComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.labelPrice != rhs.labelPrice {
            return false
        }
        if lhs.discount != rhs.discount {
            return false
        }
        if lhs.multiple != rhs.multiple {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        if lhs.primaryTextColor != rhs.primaryTextColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.checkForegroundColor != rhs.checkForegroundColor {
            return false
        }
        if lhs.checkBorderColor != rhs.checkBorderColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let check = Child(CheckComponent.self)
        let title = Child(MultilineTextComponent.self)
        let subtitle = Child(MultilineTextComponent.self)
        let discountBackground = Child(RoundedRectangle.self)
        let discount = Child(MultilineTextComponent.self)
        let label = Child(MultilineTextComponent.self)
        
        return { context in
            let component = context.component
            
            var insets = UIEdgeInsets(top: 11.0, left: 46.0, bottom: 13.0, right: 16.0)
                        
            let label = label.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.labelPrice,
                            font: Font.regular(17),
                            textColor: component.secondaryTextColor
                        )
                    ),
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.title,
                            font: Font.regular(17),
                            textColor: component.primaryTextColor
                        )
                    ),
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - insets.left - insets.right - label.size.width, height: context.availableSize.height),
                transition: context.transition
            )
                     
            let discountSize: CGSize
            if !component.discount.isEmpty {
                let discount = discount.update(
                    component: MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.discount,
                                font: Font.with(size: 14.0, design: .round, weight: .semibold, traits: []),
                                textColor: .white
                            )
                        ),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                discountSize = CGSize(width: discount.size.width + 6.0, height: 18.0)
            
                let discountBackground = discountBackground.update(
                    component: RoundedRectangle(
                        color: component.accentColor,
                        cornerRadius: 5.0
                    ),
                    availableSize: discountSize,
                    transition: context.transition
                )
                
                let discountPosition = CGPoint(x: insets.left + title.size.width + 6.0 + discountSize.width / 2.0, y: insets.top + title.size.height / 2.0)
                
                context.add(discountBackground
                    .position(discountPosition)
                )
                context.add(discount
                    .position(discountPosition)
                )
            } else {
                discountSize = CGSize(width: 0.0, height: 18.0)
            }
                        
            var spacing: CGFloat = 0.0
            var subtitleSize = CGSize()
            if !component.subtitle.isEmpty {
                spacing = 2.0
                
                let subtitleFont = Font.regular(13)
                let subtitleColor = component.secondaryTextColor
                
                let subtitleString = parseMarkdownIntoAttributedString(
                    component.subtitle,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: subtitleFont, textColor: subtitleColor),
                        bold: MarkdownAttributeSet(font: subtitleFont, textColor: subtitleColor, additionalAttributes: [NSAttributedString.Key.strikethroughStyle.rawValue: NSUnderlineStyle.single.rawValue as NSNumber]),
                        link: MarkdownAttributeSet(font: subtitleFont, textColor: subtitleColor),
                        linkAttribute: { _ in return nil }
                    )
                )
                
                let subtitle = subtitle.update(
                    component: MultilineTextComponent(
                        text: .plain(subtitleString),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - insets.left - insets.right, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(subtitle
                    .position(CGPoint(x: insets.left + subtitle.size.width / 2.0, y: insets.top + title.size.height + spacing + subtitle.size.height / 2.0))
                )
                subtitleSize = subtitle.size
                
                insets.top -= 2.0
                insets.bottom -= 2.0
            }
            
            let check = check.update(
                component: CheckComponent(
                    theme: CheckComponent.Theme(
                        backgroundColor: component.accentColor,
                        strokeColor: component.checkForegroundColor,
                        borderColor: component.checkBorderColor,
                        overlayBorder: false,
                        hasInset: false,
                        hasShadow: false
                    ),
                    selected: component.selected
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                
            context.add(title
                .position(CGPoint(x: insets.left + title.size.width / 2.0, y: insets.top + title.size.height / 2.0))
            )
               
            let size = CGSize(width: context.availableSize.width, height: insets.top + title.size.height + spacing + subtitleSize.height + insets.bottom)
            
            let distance = context.availableSize.width - insets.left - insets.right - label.size.width - subtitleSize.width
            
            let labelY: CGFloat
            if distance > 8.0 {
                labelY = size.height / 2.0
            } else {
                labelY = insets.top + title.size.height / 2.0
            }
            
            context.add(label
                .position(CGPoint(x: context.availableSize.width - insets.right - label.size.width / 2.0, y: labelY))
            )
            
            context.add(check
                .position(CGPoint(x: 4.0 + check.size.width / 2.0, y: size.height / 2.0))
            )
            
            return size
        }
    }
}

private final class CheckComponent: Component {
    struct Theme: Equatable {
        public let backgroundColor: UIColor
        public let strokeColor: UIColor
        public let borderColor: UIColor
        public let overlayBorder: Bool
        public let hasInset: Bool
        public let hasShadow: Bool
        public let filledBorder: Bool
        public let borderWidth: CGFloat?
        
        public init(backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool, filledBorder: Bool = false, borderWidth: CGFloat? = nil) {
            self.backgroundColor = backgroundColor
            self.strokeColor = strokeColor
            self.borderColor = borderColor
            self.overlayBorder = overlayBorder
            self.hasInset = hasInset
            self.hasShadow = hasShadow
            self.filledBorder = filledBorder
            self.borderWidth = borderWidth
        }
        
        var checkNodeTheme: CheckNodeTheme {
            return CheckNodeTheme(
                backgroundColor: self.backgroundColor,
                strokeColor: self.strokeColor,
                borderColor: self.borderColor,
                overlayBorder: self.overlayBorder,
                hasInset: self.hasInset,
                hasShadow: self.hasShadow,
                filledBorder: self.filledBorder,
                borderWidth: self.borderWidth
            )
        }
    }
    
    let theme: Theme
    let selected: Bool
    
    init(
        theme: Theme,
        selected: Bool
    ) {
        self.theme = theme
        self.selected = selected
    }
    
    static func ==(lhs: CheckComponent, rhs: CheckComponent) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var currentValue: CGFloat?
        private var animator: DisplayLinkAnimator?

        private var checkLayer: CheckLayer {
            return self.layer as! CheckLayer
        }
        
        override class var layerClass: AnyClass {
            return CheckLayer.self
        }
        
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

    
        func update(component: CheckComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.checkLayer.setSelected(component.selected, animated: true)
            self.checkLayer.theme = component.theme.checkNodeTheme
            
            return CGSize(width: 22.0, height: 22.0)
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
