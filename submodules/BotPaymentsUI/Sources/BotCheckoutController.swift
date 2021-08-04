import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

public final class BotCheckoutController: ViewController {
    public final class InputData {
        public enum FetchError {
            case generic
        }

        let form: BotPaymentForm
        let validatedFormInfo: BotPaymentValidatedFormInfo?

        private init(
            form: BotPaymentForm,
            validatedFormInfo: BotPaymentValidatedFormInfo?
        ) {
            self.form = form
            self.validatedFormInfo = validatedFormInfo
        }

        public static func fetch(context: AccountContext, messageId: EngineMessage.Id) -> Signal<InputData, FetchError> {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let themeParams: [String: Any] = [
                "bg_color": Int32(bitPattern: presentationData.theme.list.plainBackgroundColor.argb),
                "text_color": Int32(bitPattern: presentationData.theme.list.itemPrimaryTextColor.argb),
                "link_color": Int32(bitPattern: presentationData.theme.list.itemAccentColor.argb),
                "button_color": Int32(bitPattern: presentationData.theme.list.itemCheckColors.fillColor.argb),
                "button_text_color": Int32(bitPattern: presentationData.theme.list.itemCheckColors.foregroundColor.argb)
            ]

            return context.engine.payments.fetchBotPaymentForm(messageId: messageId, themeParams: themeParams)
            |> mapError { _ -> FetchError in
                return .generic
            }
            |> mapToSignal { paymentForm -> Signal<InputData, FetchError> in
                if let current = paymentForm.savedInfo {
                    return context.engine.payments.validateBotPaymentForm(saveInfo: true, messageId: messageId, formInfo: current)
                    |> mapError { _ -> FetchError in
                        return .generic
                    }
                    |> map { result -> InputData in
                        return InputData(
                            form: paymentForm,
                            validatedFormInfo: result
                        )
                    }
                    |> `catch` { _ -> Signal<InputData, FetchError> in
                        return .single(InputData(
                            form: paymentForm,
                            validatedFormInfo: nil
                        ))
                    }
                } else {
                    return .single(InputData(
                        form: paymentForm,
                        validatedFormInfo: nil
                    ))
                }
            }
        }
    }

    private var controllerNode: BotCheckoutControllerNode {
        return self.displayNode as! BotCheckoutControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    private let invoice: TelegramMediaInvoice
    private let messageId: EngineMessage.Id
    private let completed: (String, EngineMessage.Id?) -> Void
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false

    private let inputData: Promise<BotCheckoutController.InputData?>
    
    public init(context: AccountContext, invoice: TelegramMediaInvoice, messageId: EngineMessage.Id, inputData: Promise<BotCheckoutController.InputData?>, completed: @escaping (String, EngineMessage.Id?) -> Void) {
        self.context = context
        self.invoice = invoice
        self.messageId = messageId
        self.inputData = inputData
        self.completed = completed
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        var title = self.presentationData.strings.Checkout_Title
        if invoice.flags.contains(.isTest) {
            title += " (Test)"
        }
        self.title = title
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        let displayNode = BotCheckoutControllerNode(controller: self, navigationBar: self.navigationBar!, context: self.context, invoice: self.invoice, messageId: self.messageId, inputData: self.inputData, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, dismissAnimated: { [weak self] in
            self?.dismiss()
        }, completed: self.completed)
        
        displayNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.displayNode = displayNode
        super.displayNodeDidLoad()
        self._ready.set(displayNode.ready)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition, additionalInsets: UIEdgeInsets())
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
}
