import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import Markdown
import TextFormat

public final class InfoParagraphComponent: CombinedComponent {
    let title: String?
    let titleColor: UIColor
    let text: String
    let attributedText: NSAttributedString?
    let textColor: UIColor
    let accentColor: UIColor
    let iconName: String
    let iconColor: UIColor
    let badge: String?
    let action: () -> Void
    
    public init(
        title: String?,
        titleColor: UIColor,
        text: String,
        attributedText: NSAttributedString? = nil,
        textColor: UIColor,
        accentColor: UIColor,
        iconName: String,
        iconColor: UIColor,
        badge: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.attributedText = attributedText
        self.textColor = textColor
        self.accentColor = accentColor
        self.iconName = iconName
        self.iconColor = iconColor
        self.badge = badge
        self.action = action
    }
    
    public static func ==(lhs: InfoParagraphComponent, rhs: InfoParagraphComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.attributedText != rhs.attributedText {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        return true
    }
    
    public static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        let badgeBackground = Child(RoundedRectangle.self)
        let badgeText = Child(MultilineTextComponent.self)
        
        return { context in
            let component = context.component
            
            let leftInset: CGFloat = 32.0
            let rightInset: CGFloat = 24.0
            let textSideInset: CGFloat = leftInset + 8.0
            let spacing: CGFloat = 5.0
            
            let textTopInset: CGFloat = 9.0
            
            var titleSize: CGSize?
            if let titleText = component.title {
                let title = title.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: titleText,
                            font: Font.semibold(16.0),
                            textColor: component.titleColor,
                            paragraphAlignment: .natural
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                titleSize = title.size

                context.add(title
                    .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
                )

                if let badge = component.badge {
                    let badgeText = badgeText.update(
                        component: MultilineTextComponent(text: .plain(NSAttributedString(string: badge, font: Font.semibold(11.0), textColor: .white))),
                        availableSize: context.availableSize,
                        transition: context.transition
                    )

                    let badgeWidth = badgeText.size.width + 7.0
                    let badgeBackground = badgeBackground.update(
                        component: RoundedRectangle(
                            color: component.accentColor,
                            cornerRadius: 5.0),
                        availableSize: CGSize(width: badgeWidth, height: 16.0),
                        transition: context.transition
                    )

                    context.add(badgeBackground
                        .position(CGPoint(x: textSideInset + title.size.width + badgeWidth / 2.0 + 5.0, y: textTopInset + title.size.height / 2.0))
                    )

                    context.add(badgeText
                        .position(CGPoint(x: textSideInset + title.size.width + badgeWidth / 2.0 + 5.0, y: textTopInset + title.size.height / 2.0))
                    )
                }
            }
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = component.textColor
            let accentColor = component.accentColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: accentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
                        
            let text = text.update(
                component: BalancedTextComponent(
                    text: component.attributedText.map { .plain($0) } ?? .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        component.action()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: context.availableSize.height),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.iconColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
         
            let textOriginY: CGFloat
            let iconCenterY: CGFloat
            if let titleSize {
                textOriginY = textTopInset + titleSize.height + spacing
                iconCenterY = textTopInset + 18.0
            } else {
                iconCenterY = textTopInset + 14.0
                if text.size.height <= 20.0 {
                    textOriginY = iconCenterY - text.size.height / 2.0 + 1.0
                } else {
                    textOriginY = textTopInset
                }
            }

            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textOriginY + text.size.height / 2.0))
            )
            
            context.add(icon
                .position(CGPoint(x: 15.0, y: iconCenterY))
            )

            let height: CGFloat
            if let titleSize {
                height = textTopInset + titleSize.height + text.size.height + 20.0
            } else {
                height = max(textTopInset + text.size.height, textTopInset + icon.size.height) + 20.0
            }
            return CGSize(width: context.availableSize.width, height: height)
        }
    }
}
