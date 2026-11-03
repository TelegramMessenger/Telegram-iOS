import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import BundleIconComponent
import AnimatedTextComponent

public final class PremiumLockButtonSubtitleComponent: CombinedComponent {
    public let count: Int
    public let color: UIColor
    public let strings: PresentationStrings
    
    public init(count: Int, color: UIColor, strings: PresentationStrings) {
        self.count = count
        self.color = color
        self.strings = strings
    }
    
    public convenience init(count: Int, theme: PresentationTheme, strings: PresentationStrings) {
        self.init(count: count, color: theme.list.itemCheckColors.foregroundColor.withMultipliedAlpha(0.7), strings: strings)
    }
    
    public static func ==(lhs: PremiumLockButtonSubtitleComponent, rhs: PremiumLockButtonSubtitleComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        if lhs.color !== rhs.color {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    public static var body: Body {
        let icon = Child(BundleIconComponent.self)
        let text = Child(AnimatedTextComponent.self)

        return { context in
            let icon = icon.update(
                component: BundleIconComponent(
                    name: "Chat/Input/Accessory Panels/TextLockIcon",
                    tintColor: context.component.color,
                    maxSize: CGSize(width: 10.0, height: 10.0)
                ),
                availableSize: CGSize(width: 100.0, height: 100.0),
                transition: context.transition
            )
            var textItems: [AnimatedTextComponent.Item] = []
            
            let levelString = context.component.strings.ChannelReactions_LevelRequiredLabel("")
            var previousIndex = 0
            let nsLevelString = levelString.string as NSString
            for range in levelString.ranges.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
                if range.range.lowerBound > previousIndex {
                    textItems.append(AnimatedTextComponent.Item(id: AnyHashable(range.index), content: .text(nsLevelString.substring(with: NSRange(location: previousIndex, length: range.range.lowerBound - previousIndex)))))
                }
                if range.index == 0 {
                    textItems.append(AnimatedTextComponent.Item(id: AnyHashable(range.index), content: .number(context.component.count, minDigits: 1)))
                }
                previousIndex = range.range.upperBound
            }
            if nsLevelString.length > previousIndex {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable(100), content: .text(nsLevelString.substring(with: NSRange(location: previousIndex, length: nsLevelString.length - previousIndex)))))
            }
            
            let text = text.update(
                component: AnimatedTextComponent(font: Font.medium(11.0), color: context.component.color, items: textItems),
                availableSize: CGSize(width: context.availableSize.width - 20.0, height: 100.0),
                transition: context.transition
            )

            let spacing: CGFloat = 3.0
            let size = CGSize(width: icon.size.width + spacing + text.size.width, height: text.size.height)
            context.add(icon
                .position(icon.size.centered(in: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: icon.size.width, height: size.height))).center)
            )
            context.add(text
                .position(text.size.centered(in: CGRect(origin: CGPoint(x: icon.size.width + spacing, y: 0.0), size: text.size)).center)
            )

            return size
        }
    }
}
