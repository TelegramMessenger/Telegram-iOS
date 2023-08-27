import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AppBundle
import BundleIconComponent
import Markdown
import TelegramCore
import BalancedTextComponent

public final class StoryStealthModeInfoContentComponent: Component {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let backwardDuration: Int32
    public let forwardDuration: Int32
    public let mode: StoryStealthModeSheetScreen.Mode
    public let dismiss: () -> Void
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        backwardDuration: Int32,
        forwardDuration: Int32,
        mode: StoryStealthModeSheetScreen.Mode,
        dismiss: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.backwardDuration = backwardDuration
        self.forwardDuration = forwardDuration
        self.mode = mode
        self.dismiss = dismiss
    }
    
    public static func ==(lhs: StoryStealthModeInfoContentComponent, rhs: StoryStealthModeInfoContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.backwardDuration != rhs.backwardDuration {
            return false
        }
        if lhs.forwardDuration != rhs.forwardDuration {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    private final class Item {
        let icon = ComponentView<Empty>()
        let title = ComponentView<Empty>()
        let text = ComponentView<Empty>()
        
        init() {
        }
    }
    
    public final class View: UIView {
        private let scrollView: UIScrollView
        private let iconBackground: UIImageView
        private let iconForeground: UIImageView
        
        private let title = ComponentView<Empty>()
        private let mainText = ComponentView<Empty>()
        
        private var items: [Item] = []
        
        private var component: StoryStealthModeInfoContentComponent?
        
        public override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
            self.iconBackground = UIImageView()
            self.iconForeground = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.scrollView)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.clipsToBounds = false
            
            self.scrollView.addSubview(self.iconBackground)
            self.scrollView.addSubview(self.iconForeground)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let result = super.hitTest(point, with: event) {
                return result
            } else {
                return nil
            }
        }
        
        func update(component: StoryStealthModeInfoContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 16.0
            let sideIconInset: CGFloat = 40.0
            
            var contentHeight: CGFloat = 0.0
            
            let iconSize: CGFloat = 90.0
            if self.iconBackground.image == nil {
                let backgroundColors: [UIColor] = [UIColor(rgb: 0x3DA1FD), UIColor(rgb: 0x34C76F)]
                let colors: NSArray = [backgroundColors[0].cgColor, backgroundColors[1].cgColor]
                self.iconBackground.image = generateGradientFilledCircleImage(diameter: iconSize, colors: colors)
            }
            let iconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize) * 0.5), y: contentHeight), size: CGSize(width: iconSize, height: iconSize))
            transition.setFrame(view: self.iconBackground, frame: iconBackgroundFrame)
            
            if self.iconForeground.image == nil {
                self.iconForeground.image = generateTintedImage(image: UIImage(bundleImageName: "Stories/StealthModeIntroIconMain"), color: .white)
            }
            if let image = self.iconForeground.image {
                transition.setFrame(view: self.iconForeground, frame: CGRect(origin: CGPoint(x: iconBackgroundFrame.minX + floor((iconBackgroundFrame.width - image.size.width) * 0.5), y: iconBackgroundFrame.minY + floor((iconBackgroundFrame.height - image.size.height) * 0.5)), size: image.size))
            }
            
            contentHeight += iconSize
            contentHeight += 15.0
            
            let titleString = NSMutableAttributedString()
            titleString.append(NSAttributedString(string: component.strings.Story_StealthMode_Title, font: Font.semibold(19.0), textColor: component.theme.list.itemPrimaryTextColor))
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = self.iconBackground.image
            titleString.append(NSAttributedString(attachment: imageAttachment))
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleString),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.scrollView.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize))
            }
            contentHeight += titleSize.height
            contentHeight += 15.0
            
            let text: String
            switch component.mode {
            case .control:
                text = component.strings.Story_StealthMode_ControlText
            case .upgrade:
                text = component.strings.Story_StealthMode_UpgradeText
            }
            let mainText = NSMutableAttributedString()
            mainText.append(parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(
                    font: Font.regular(15.0),
                    textColor: component.theme.list.itemSecondaryTextColor
                ),
                bold: MarkdownAttributeSet(
                    font: Font.semibold(15.0),
                    textColor: component.theme.list.itemSecondaryTextColor
                ),
                link: MarkdownAttributeSet(
                    font: Font.regular(15.0),
                    textColor: component.theme.list.itemAccentColor,
                    additionalAttributes: [:]
                ),
                linkAttribute: { attributes in
                    return ("URL", "")
                }
            )))
            
            let mainTextSize = self.mainText.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(mainText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let mainTextView = self.mainText.view {
                if mainTextView.superview == nil {
                    self.scrollView.addSubview(mainTextView)
                }
                transition.setFrame(view: mainTextView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - mainTextSize.width) * 0.5), y: contentHeight), size: mainTextSize))
            }
            contentHeight += mainTextSize.height
            contentHeight += 24.0
            
            struct ItemDesc {
                var icon: String
                var title: String
                var text: String
            }
            let itemDescs: [ItemDesc] = [
                ItemDesc(
                    icon: "Stories/StealthModeIntroIconHidePrevious",
                    title: component.strings.Story_StealthMode_RecentTitle,
                    text: component.strings.Story_StealthMode_RecentText(timeIntervalString(strings: component.strings, value: component.backwardDuration)).string
                ),
                ItemDesc(
                    icon: "Stories/StealthModeIntroIconHideNext",
                    title: component.strings.Story_StealthMode_NextTitle,
                    text: component.strings.Story_StealthMode_NextText(timeIntervalString(strings: component.strings, value: component.forwardDuration)).string
                )
            ]
            for i in 0 ..< itemDescs.count {
                if i != 0 {
                    contentHeight += 24.0
                }
                
                let item: Item
                if self.items.count > i {
                    item = self.items[i]
                } else {
                    item = Item()
                    self.items.append(item)
                }
                
                let itemDesc = itemDescs[i]
                
                let iconSize = item.icon.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(
                        name: itemDesc.icon,
                        tintColor: component.theme.list.itemAccentColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let titleSize = item.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: itemDesc.title, font: Font.semibold(15.0), textColor: component.theme.list.itemPrimaryTextColor)),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - sideIconInset, height: 1000.0)
                )
                let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: component.theme.list.itemSecondaryTextColor)
                let textSize = item.text.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: itemDesc.text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.18
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - sideIconInset, height: 1000.0)
                )
                
                if let iconView = item.icon.view {
                    if iconView.superview == nil {
                        self.scrollView.addSubview(iconView)
                    }
                    transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 4.0), size: iconSize))
                }
                
                if let titleView = item.title.view {
                    if titleView.superview == nil {
                        self.scrollView.addSubview(titleView)
                    }
                    transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: sideInset + sideIconInset, y: contentHeight), size: titleSize))
                }
                contentHeight += titleSize.height
                contentHeight += 2.0
                
                if let textView = item.text.view {
                    if textView.superview == nil {
                        self.scrollView.addSubview(textView)
                    }
                    transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: sideInset + sideIconInset, y: contentHeight), size: textSize))
                }
                contentHeight += textSize.height
            }
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            let size = CGSize(width: availableSize.width, height: min(availableSize.height, contentSize.height))
            if self.scrollView.bounds.size != size || self.scrollView.contentSize != contentSize {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: size)
                self.scrollView.contentSize = contentSize
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
