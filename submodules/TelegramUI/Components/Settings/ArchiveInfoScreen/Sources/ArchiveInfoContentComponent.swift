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

public final class ArchiveInfoContentComponent: Component {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let settings: GlobalPrivacySettings
    public let openSettings: () -> Void
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        settings: GlobalPrivacySettings,
        openSettings: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.settings = settings
        self.openSettings = openSettings
    }
    
    public static func ==(lhs: ArchiveInfoContentComponent, rhs: ArchiveInfoContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.settings != rhs.settings {
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
        
        private var chevronImage: UIImage?
        
        private var items: [Item] = []
        
        private var component: ArchiveInfoContentComponent?
        
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
        
        func update(component: ArchiveInfoContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 16.0
            let sideIconInset: CGFloat = 40.0
            
            var contentHeight: CGFloat = 0.0
            
            let iconSize: CGFloat = 90.0
            if self.iconBackground.image == nil {
                let backgroundColors = component.theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
                let colors: NSArray = [backgroundColors.1.cgColor, backgroundColors.0.cgColor]
                self.iconBackground.image = generateGradientFilledCircleImage(diameter: iconSize, colors: colors)
            }
            let iconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize) * 0.5), y: contentHeight), size: CGSize(width: iconSize, height: iconSize))
            transition.setFrame(view: self.iconBackground, frame: iconBackgroundFrame)
            
            if self.iconForeground.image == nil {
                self.iconForeground.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/ArchiveIconLarge"), color: .white)
            }
            if let image = self.iconForeground.image {
                transition.setFrame(view: self.iconForeground, frame: CGRect(origin: CGPoint(x: iconBackgroundFrame.minX + floor((iconBackgroundFrame.width - image.size.width) * 0.5), y: iconBackgroundFrame.minY + floor((iconBackgroundFrame.height - image.size.height) * 0.5)), size: image.size))
            }
            
            contentHeight += iconSize
            contentHeight += 15.0
            
            let titleString = NSMutableAttributedString()
            titleString.append(NSAttributedString(string: component.strings.ArchiveInfo_Title, font: Font.semibold(19.0), textColor: component.theme.list.itemPrimaryTextColor))
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
            contentHeight += 16.0
            
            let text: String
            if component.settings.keepArchivedUnmuted {
                text = component.strings.ArchiveInfo_TextKeepArchivedUnmuted
            } else {
                text = component.strings.ArchiveInfo_TextKeepArchivedDefault
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
            if self.chevronImage == nil {
                self.chevronImage = UIImage(bundleImageName: "Settings/TextArrowRight")
            }
            if let range = mainText.string.range(of: ">"), let chevronImage = self.chevronImage {
                mainText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: mainText.string))
            }
            
            let mainTextSize = self.mainText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(mainText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: component.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            return NSAttributedString.Key(rawValue: "URL")
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.openSettings()
                    }
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
                    icon: "Chat List/Archive/IconArchived",
                    title: component.strings.ArchiveInfo_ChatsTitle,
                    text: component.strings.ArchiveInfo_ChatsText
                ),
                ItemDesc(
                    icon: "Chat List/Archive/IconHide",
                    title: component.strings.ArchiveInfo_HideTitle,
                    text: component.strings.ArchiveInfo_HideText
                ),
                ItemDesc(
                    icon: "Chat List/Archive/IconStories",
                    title: component.strings.ArchiveInfo_StoriesTitle,
                    text: component.strings.ArchiveInfo_StoriesText
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
                let textSize = item.text.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: itemDesc.text, font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor)),
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
