import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import ItemListUI
import UndoUI
import AccountContext
import PremiumStarComponent
import ButtonComponent

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let invoice: TelegramMediaInvoice
    let source: BotPaymentInvoiceSource
    let inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?)?, NoError>
    
    init(
        context: AccountContext,
        invoice: TelegramMediaInvoice,
        source: BotPaymentInvoiceSource,
        inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?)?, NoError>
    ) {
        self.context = context
        self.invoice = invoice
        self.source = source
        self.inputData = inputData
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.invoice != rhs.invoice {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedStarImage: (UIImage, PresentationTheme)?
        
        private let context: AccountContext
        private let source: BotPaymentInvoiceSource
        
        var peer: EnginePeer?
        var peerDisposable: Disposable?
        var balance: Int64?
        var form: BotPaymentForm?
        
        var inProgress = false
        
        init(
            context: AccountContext,
            source: BotPaymentInvoiceSource,
            inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?)?, NoError>
        ) {
            self.context = context
            self.source = source
            
            super.init()
            
            self.peerDisposable = (inputData
            |> deliverOnMainQueue).start(next: { [weak self] inputData in
                guard let self else {
                    return
                }
                self.balance = inputData?.0.balance ?? 0
                self.form = inputData?.1
                self.peer = inputData?.2
                self.updated(transition: .immediate)
            })
        }
        
        deinit {
            self.peerDisposable?.dispose()
        }
        
        func buy(completion: @escaping () -> Void) {
            guard let form else {
                return
            }
            self.inProgress = true
            self.updated()
            
            let _ = (self.context.engine.payments.sendStarsPaymentForm(formId: form.id, source: self.source)
            |> deliverOnMainQueue).start(next: { _ in
                completion()
            })
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, source: self.source, inputData: self.inputData)
    }
        
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let star = Child(GiftAvatarComponent.self)
        let closeButton = Child(Button.self)
        let title = Child(Text.self)
        let text = Child(BalancedTextComponent.self)
        let balanceText = Child(MultilineTextComponent.self)
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme
//            let strings = presentationData.strings
            
//            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.list.blocksBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            if let peer = state.peer {
                let star = star.update(
                    component: GiftAvatarComponent(
                        context: context.component.context,
                        theme: environment.theme,
                        peers: [peer],
                        isVisible: true,
                        hasIdleAnimations: true,
                        hasScaleAnimation: false,
                        color: UIColor(rgb: 0xf7ab04),
                        offset: 40.0
                    ),
                    availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
                
                context.add(star
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 0.0 + star.size.height / 2.0 - 30.0))
                )
            }
            
            let closeImage: UIImage
            if let (image, cacheTheme) = state.cachedCloseImage, theme === cacheTheme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: {
//                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - closeButton.size.width, y: 28.0))
            )
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            
            contentSize.height += 130.0
            let title = title.update(
                component: Text(text: "Confirm Your Purchase", font: Font.bold(24.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 13.0
                        
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let amount = component.invoice.totalAmount
            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(text: "Do you want to buy **\(component.invoice.title)** in **\(state.peer?.compactDisplayTitle ?? "levlam_bot")** for **\(amount) Stars**?", attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += 24.0
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: UIColor(rgb: 0xf09903))!, theme)
            }
            
            let balanceAttributedString = parseMarkdownIntoAttributedString("Balance\n >  **\(state.balance ?? 0)**", attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
            if let range = balanceAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                balanceAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: balanceAttributedString.string))
                balanceAttributedString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xf09903), range: NSRange(range, in: balanceAttributedString.string))
                balanceAttributedString.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: balanceAttributedString.string))
            }
            let balanceText = balanceText.update(
                component: MultilineTextComponent(
                    text: .plain(balanceAttributedString),
                    horizontalAlignment: .left,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(balanceText
                .position(CGPoint(x: 16.0 + balanceText.size.width / 2.0, y: 29.0))
            )
            
            if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: .white)!, theme)
            }
            
            let buttonAttributedString = NSMutableAttributedString(string: "Confirm and Pay   >  \(amount)", font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: ">"), let starImage = state.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff), range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let controller = environment.controller() as? StarsTransferScreen
            
            let accountContext = component.context
            let botTitle = state.peer?.compactDisplayTitle ?? ""
            
            let invoice = component.invoice
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: state.inProgress,
                    action: { [weak state, weak controller] in
                        state?.buy(completion: { [weak controller] in
                            let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                            let resultController = UndoOverlayController(
                                presentationData: presentationData,
                                content: .image(image: UIImage(bundleImageName: "Premium/Stars/Star")!, title: "Purchase Completed", text: "You acquired **\(invoice.title)** in **\(botTitle)** for **\(invoice.totalAmount) Stars**.", round: false, undoText: nil),
                                elevatedLayout: true,
                                action: { _ in return true})
                            controller?.present(resultController, in: .window(.root))

                            controller?.dismissAnimated()
                        })
                    }
                ),
                availableSize: CGSize(width: 361.0, height: 50),
                transition: .immediate
            )
            context.add(button
                .clipsToBounds(true)
                .cornerRadius(10.0)
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
            contentSize.height += 48.0
            
            return contentSize
        }
    }
}

private final class StarsTransferSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let invoice: TelegramMediaInvoice
    private let source: BotPaymentInvoiceSource
    private let inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?)?, NoError>
    
    init(
        context: AccountContext,
        invoice: TelegramMediaInvoice,
        source: BotPaymentInvoiceSource,
        inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?)?, NoError>
    ) {
        self.context = context
        self.invoice = invoice
        self.source = source
        self.inputData = inputData
    }
    
    static func ==(lhs: StarsTransferSheetComponent, rhs: StarsTransferSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.invoice != rhs.invoice {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        invoice: context.component.invoice,
                        source: context.component.source,
                        inputData: context.component.inputData
                    )),
                    backgroundColor: .blur(.light),
                    followContentSizeChanges: true,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class StarsTransferScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    public init(
        context: AccountContext,
        invoice: TelegramMediaInvoice,
        source: BotPaymentInvoiceSource,
        inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?)?, NoError>
    ) {
        self.context = context
                
        super.init(
            context: context,
            component: StarsTransferSheetComponent(
                context: context,
                invoice: invoice,
                source: source,
                inputData: inputData
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}
