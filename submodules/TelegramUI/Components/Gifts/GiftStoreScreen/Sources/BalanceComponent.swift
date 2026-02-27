import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import TextFormat
import TelegramStringFormatting
import Markdown

final class BalanceComponent: Component {
    private let context: AccountContext
    private let theme: PresentationTheme
    private let action: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.action = action
    }

    static func ==(lhs: BalanceComponent, rhs: BalanceComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private var text = ComponentView<Empty>()
                
        private var component: BalanceComponent?
        private var componentState: EmptyComponentState?
        
        private var starsBalance: Int64 = 0
        private var tonBalance: Int64 = 0
        private var balanceDisposable: Disposable?
                        
        override public init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.balanceDisposable?.dispose()
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        private var isUpdating = false
        func update(component: BalanceComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            self.component = component
            self.componentState = state
            
            if self.balanceDisposable == nil {
                if let starsContext = component.context.starsContext, let tonContext = component.context.tonContext {
                    self.balanceDisposable = combineLatest(queue: Queue.mainQueue(),
                        starsContext.state,
                        tonContext.state
                    ).start(next: { [weak self] starsState, tonState in
                        guard let self else {
                            return
                        }
                        self.starsBalance = starsState?.balance.value ?? 0
                        self.tonBalance = tonState?.balance.value ?? 0
                        if !self.isUpdating {
                            self.componentState?.updated()
                        }
                    })
                }
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

            var rawString: String = ""
            let starsBalanceString = "**⭐️\(presentationStringsFormattedNumber(Int32(clamping: self.starsBalance), presentationData.dateTimeFormat.groupingSeparator))**"
            if self.tonBalance > 0 {
                let tonBalanceString = "**💎\(formatTonAmountText(self.tonBalance, dateTimeFormat: presentationData.dateTimeFormat))**"
                rawString = starsBalanceString + "\n" + tonBalanceString
            } else {
                rawString = presentationData.strings.Stars_Purchase_Balance + "\n" + starsBalanceString
            }
            
            let attributedText = parseMarkdownIntoAttributedString(
                rawString,
                attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(12.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(12.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(12.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    linkAttribute: { _ in
                        return nil
                    }
                ),
                textAlignment: .right
            ).mutableCopy() as! NSMutableAttributedString
            let starRange = (attributedText.string as NSString).range(of: "⭐️")
            if starRange.location != NSNotFound {
                attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: starRange)
                attributedText.addAttribute(.baselineOffset, value: 1.0, range: starRange)
            }
            let tonRange = (attributedText.string as NSString).range(of: "💎")
            if tonRange.location != NSNotFound {
                attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .ton(tinted: false)), range: tonRange)
                attributedText.addAttribute(.baselineOffset, value: 1.0, range: tonRange)
            }
                        
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .white,
                        text: .plain(attributedText),
                        horizontalAlignment: .right,
                        maximumNumberOfLines: 2,
                        lineSpacing: 0.1,
                        displaysAsynchronously: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let inset: CGFloat = 12.0
            let size = CGSize(width: textSize.width + inset * 2.0, height: 44.0)
                        
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.isUserInteractionEnabled = false
                    self.addSubview(textView)
                    
                    if !transition.animation.isImmediate {
                        transition.animateAlpha(view: textView, from: 0.0, to: 1.0)
                    }
                }
                textView.frame = CGRect(origin: CGPoint(x: inset, y: 8.0 - UIScreenPixel), size: textSize)
            }
            
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
