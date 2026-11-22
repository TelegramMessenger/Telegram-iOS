import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import TextFormat
import Markdown
import TelegramStringFormatting

public final class StarsBalanceOverlayComponent: Component {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let theme: PresentationTheme
    private let currency: CurrencyAmount.Currency
    private let action: () -> Void
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        theme: PresentationTheme,
        currency: CurrencyAmount.Currency,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.peerId = peerId
        self.theme = theme
        self.currency = currency
        self.action = action
    }

    public static func ==(lhs: StarsBalanceOverlayComponent, rhs: StarsBalanceOverlayComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView = BlurredBackgroundView(color: nil)
        private var text = ComponentView<Empty>()
        private let action = ComponentView<Empty>()
                
        private var component: StarsBalanceOverlayComponent?
        private var state: EmptyComponentState?
        
        private var starsBalance: Int64 = 0
        private var tonBalance: Int64 = 0
        private var balanceDisposable: Disposable?
        
        private var starsRevenueStatsContext: StarsRevenueStatsContext?
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.balanceDisposable?.dispose()
        }
        
        private var didTap = false
        @objc private func tapped() {
            if let component = self.component, !self.didTap {
                self.didTap = true
                component.action()
            }
        }
        
        private var isUpdating = false
        func update(component: StarsBalanceOverlayComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            if self.balanceDisposable == nil {
                if component.peerId == component.context.account.peerId {
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
                                self.state?.updated()
                            }
                        })
                    }
                } else {
                    let starsRevenueStatsContext = StarsRevenueStatsContext(account: component.context.account, peerId: component.peerId, ton: false)
                    self.starsRevenueStatsContext = starsRevenueStatsContext
                    
                    self.balanceDisposable = (starsRevenueStatsContext.state
                    |> map { state -> Int64 in
                        return state.stats?.balances.currentBalance.amount.value ?? 0
                    }
                    |> distinctUntilChanged
                    |> deliverOnMainQueue).start(next: { [weak self] balance in
                        guard let self else {
                            return
                        }
                        self.starsBalance = balance
                        if !self.isUpdating {
                            self.state?.updated()
                        }
                    })
                }
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let balance = presentationStringsFormattedNumber(Int32(self.starsBalance), presentationData.dateTimeFormat.groupingSeparator)
            
            let rawString: String
            if component.peerId == component.context.account.peerId {
                let balanceString: String
                switch component.currency {
                case .stars:
                    balanceString = "**⭐️\(balance)**"
                case .ton:
                    balanceString = "**💎\(formatTonAmountText(self.tonBalance, dateTimeFormat: presentationData.dateTimeFormat))**"
                }
                rawString = presentationData.strings.StarsBalance_YourBalance(balanceString).string
            } else {
                rawString = presentationData.strings.StarsBalance_ChannelBalance("**⭐️\(balance)**").string
            }
            
            let attributedText = parseMarkdownIntoAttributedString(
                rawString,
                attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.rootController.navigationBar.primaryTextColor),
                    linkAttribute: { _ in
                        return nil
                    }
                )
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
            
            if previousComponent?.currency != component.currency {
                if let textView = self.text.view {
                    if !transition.animation.isImmediate {
                        transition.setAlpha(view: textView, alpha: 0.0, completion: { _ in
                            textView.removeFromSuperview()
                        })
                    } else {
                        textView.removeFromSuperview()
                    }
                }
                self.text = ComponentView()
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
                        displaysAsynchronously: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let size: CGSize
            
            let hasAction = component.currency == .stars && component.peerId == component.context.account.peerId
            if hasAction {
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
                size = CGSize(width: max(textSize.width, actionSize.width) + 40.0, height: 54.0)
                
                if let actionView = self.action.view {
                    if actionView.superview == nil {
                        actionView.alpha = 1.0
                        self.backgroundView.addSubview(actionView)
                        
                        if !transition.animation.isImmediate {
                            transition.animateAlpha(view: actionView, from: 0.0, to: 1.0)
                        }
                    }
                    actionView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - actionSize.width) / 2.0), y: 29.0), size: actionSize)
                }
            } else {
                size = CGSize(width: textSize.width + 40.0, height: 35.0)
                
                if let actionView = self.action.view, actionView.superview != nil {
                    if !transition.animation.isImmediate {
                        transition.setAlpha(view: actionView, alpha: 0.0, completion: { _ in
                            actionView.removeFromSuperview()
                        })
                    } else {
                        actionView.removeFromSuperview()
                    }
                }
            }

            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.alpha = 1.0
                    self.backgroundView.addSubview(textView)
                    
                    if !transition.animation.isImmediate {
                        transition.animateAlpha(view: textView, from: 0.0, to: 1.0)
                    }
                }
                textView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: 10.0), size: textSize)
            }
            
            self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.opaqueBackgroundColor, transition: .immediate)
            self.backgroundView.update(size: size, cornerRadius: size.height / 2.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - size.width) / 2.0), y: 0.0), size: size))
            
            return CGSize(width: availableSize.width, height: size.height)
        }
        
        public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return self.backgroundView.frame.contains(point)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
