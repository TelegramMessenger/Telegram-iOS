import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import TextFormat
import Markdown

public final class StarsBalanceOverlayComponent: Component {
    private let context: AccountContext
    private let theme: PresentationTheme
    private let action: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.action = action
    }

    public static func ==(lhs: StarsBalanceOverlayComponent, rhs: StarsBalanceOverlayComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView = BlurredBackgroundView(color: nil)
        private let text = ComponentView<Empty>()
        private let action = ComponentView<Empty>()
                
        private var component: StarsBalanceOverlayComponent?
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapped() {
            if let component = self.component {
                component.action()
            }
        }
        
        func update(component: StarsBalanceOverlayComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let balance = presentationStringsFormattedNumber(Int32(component.context.starsContext?.currentState?.balance.value ?? 0), presentationData.dateTimeFormat.groupingSeparator)
            
            let attributedText = parseMarkdownIntoAttributedString(
                presentationData.strings.StarsBalance_YourBalance("**⭐️\(balance)**").string,
                attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    linkAttribute: { _ in
                        return nil
                    }
                )
            ).mutableCopy() as! NSMutableAttributedString
            let range = (attributedText.string as NSString).range(of: "⭐️")
            if range.location != NSNotFound {
                attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                attributedText.addAttribute(.baselineOffset, value: 1.0, range: range)
            }
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .white,
                        text: .plain(attributedText)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== component.theme {
                self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: component.theme.rootController.navigationBar.accentTextColor)!, component.theme)
            }
            let actionText = NSMutableAttributedString(string: presentationData.strings.StarsBalance_GetMoreStars, font: Font.regular(13.0), textColor: component.theme.rootController.navigationBar.accentTextColor)
            if let range = actionText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                actionText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: actionText.string))
                actionText.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: actionText.string))
            }
            let actionSize = self.action.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(actionText),
                        maximumNumberOfLines: 1
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let size = CGSize(width: max(textSize.width, actionSize.width) + 40.0, height: 54.0)
            
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: 10.0), size: textSize)
            }
            
            if let actionView = self.action.view {
                if actionView.superview == nil {
                    self.addSubview(actionView)
                }
                actionView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - actionSize.width) / 2.0), y: 29.0), size: actionSize)
            }

            self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.opaqueBackgroundColor, transition: .immediate)
            self.backgroundView.update(size: size, cornerRadius: size.height / 2.0, transition: .immediate)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
