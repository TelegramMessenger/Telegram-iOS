import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import BalancedTextComponent
import TelegramPresentationData
import AppBundle
import BundleIconComponent
import Markdown
import TelegramCore
import LottieComponent

public final class NewSessionInfoContentComponent: Component {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let newSessionReview: NewSessionReview
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        newSessionReview: NewSessionReview
    ) {
        self.theme = theme
        self.strings = strings
        self.newSessionReview = newSessionReview
    }
    
    public static func ==(lhs: NewSessionInfoContentComponent, rhs: NewSessionInfoContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.newSessionReview != rhs.newSessionReview {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let scrollView: UIScrollView
        private let iconBackground: UIImageView
        private let iconForeground = ComponentView<Empty>()
        
        private let notice = ComponentView<Empty>()
        private let noticeBackground: SimpleLayer
        
        private let title = ComponentView<Empty>()
        private let mainText = ComponentView<Empty>()
        
        private var component: NewSessionInfoContentComponent?
        
        public override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
            self.noticeBackground = SimpleLayer()
            self.noticeBackground.cornerRadius = 10.0
            
            self.iconBackground = UIImageView()
            
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
            
            self.scrollView.layer.addSublayer(self.noticeBackground)
            self.scrollView.addSubview(self.iconBackground)
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
        
        func update(component: NewSessionInfoContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 16.0
            let noticeInsetX: CGFloat = 16.0
            let noticeInsetY: CGFloat = 12.0
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += -14.0
            
            let noticeSize = self.notice.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.SessionReview_NoticeText, font: Font.semibold(15.0), textColor: component.theme.list.itemDestructiveColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - noticeInsetX * 2.0, height: 1000.0)
            )
            let noticeBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: availableSize.width, height: noticeSize.height + noticeInsetY * 2.0))
            transition.setFrame(layer: self.noticeBackground, frame: noticeBackgroundFrame)
            self.noticeBackground.backgroundColor = component.theme.list.itemDestructiveColor.withMultipliedAlpha(0.1).cgColor
            
            if let noticeView = self.notice.view {
                if noticeView.superview == nil {
                    self.scrollView.addSubview(noticeView)
                }
                transition.setFrame(view: noticeView, frame: CGRect(origin: CGPoint(x: noticeBackgroundFrame.minX + floor((noticeBackgroundFrame.width - noticeSize.width) * 0.5), y: noticeBackgroundFrame.minY + floor((noticeBackgroundFrame.height - noticeSize.height) * 0.5)), size: noticeSize))
            }
            contentHeight += noticeBackgroundFrame.height
            contentHeight += 24.0
            
            let iconSize: CGFloat = 90.0
            if self.iconBackground.image == nil {
                let colors: NSArray = [component.theme.list.itemAccentColor.cgColor, component.theme.list.itemAccentColor.cgColor]
                self.iconBackground.image = generateGradientFilledCircleImage(diameter: iconSize, colors: colors)
            }
            let iconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize) * 0.5), y: contentHeight), size: CGSize(width: iconSize, height: iconSize))
            transition.setFrame(view: self.iconBackground, frame: iconBackgroundFrame)
            
            let iconForegroundSize = self.iconForeground.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "SessionReviewIcon"),
                    color: .white
                )),
                environment: {},
                containerSize: CGSize(width: 70.0, height: 70.0)
            )
            if let iconForegroundView = self.iconForeground.view as? LottieComponent.View {
                if iconForegroundView.superview == nil {
                    self.scrollView.addSubview(iconForegroundView)
                    DispatchQueue.main.async {
                        iconForegroundView.playOnce()
                    }
                }
                transition.setFrame(view: iconForegroundView, frame: CGRect(origin: CGPoint(x: iconBackgroundFrame.minX + floor((iconBackgroundFrame.width - iconForegroundSize.width) * 0.5), y: iconBackgroundFrame.minY + floor((iconBackgroundFrame.height - iconForegroundSize.height) * 0.5)), size: iconForegroundSize))
            }
            
            contentHeight += iconSize
            contentHeight += 16.0
            
            let titleString = NSMutableAttributedString()
            titleString.append(NSAttributedString(string: component.strings.SessionReview_Title, font: Font.semibold(19.0), textColor: component.theme.list.itemPrimaryTextColor))
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
            
            let text: String = component.strings.SessionReview_Text(component.newSessionReview.device, component.newSessionReview.location).string
            
            let mainText = NSMutableAttributedString()
            mainText.append(parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(
                    font: Font.regular(15.0),
                    textColor: component.theme.list.itemPrimaryTextColor
                ),
                bold: MarkdownAttributeSet(
                    font: Font.semibold(15.0),
                    textColor: component.theme.list.itemPrimaryTextColor
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
            
            contentHeight += 1.0
            
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
