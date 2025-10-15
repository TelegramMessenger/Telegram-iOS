import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import CountrySelectionUI

enum BotCheckoutInfoControllerAddressFocus {
    case street1
    case street2
    case city
    case state
    case postcode
}

enum BotCheckoutInfoControllerFocus {
    case address(BotCheckoutInfoControllerAddressFocus)
    case name
    case phone
    case email
}

final class BotCheckoutInfoController: ViewController {
    private var controllerNode: BotCheckoutInfoControllerNode {
        return super.displayNode as! BotCheckoutInfoControllerNode
    }
    
    private let context: AccountContext
    private let invoice: BotPaymentInvoice
    private let source: BotPaymentInvoiceSource
    private let initialFormInfo: BotPaymentRequestedInfo
    private let focus: BotCheckoutInfoControllerFocus
    
    private let formInfoUpdated: (BotPaymentRequestedInfo, BotPaymentValidatedFormInfo) -> Void
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    private var doneItem: UIBarButtonItem?
    private var activityItem: UIBarButtonItem?
    
    public init(
        context: AccountContext,
        invoice: BotPaymentInvoice,
        source: BotPaymentInvoiceSource,
        initialFormInfo: BotPaymentRequestedInfo,
        focus: BotCheckoutInfoControllerFocus,
        formInfoUpdated: @escaping (BotPaymentRequestedInfo, BotPaymentValidatedFormInfo) -> Void
    ) {
        self.context = context
        self.invoice = invoice
        self.source = source
        self.initialFormInfo = initialFormInfo
        self.focus = focus
        self.formInfoUpdated = formInfoUpdated
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        
        self.title = self.presentationData.strings.CheckoutInfo_Title
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = self.doneItem
        self.doneItem?.isEnabled = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func loadDisplayNode() {
        self.displayNode = BotCheckoutInfoControllerNode(context: self.context, navigationBar: self.navigationBar, invoice: self.invoice, source: self.source, formInfo: self.initialFormInfo, focus: self.focus, theme: self.presentationData.theme, strings: self.presentationData.strings, dismiss: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }, openCountrySelection: { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false)
                controller.completeWithCountryCode = { _, id in
                    if let strongSelf = self {
                        strongSelf.controllerNode.updateCountry(id)
                    }
                }
                strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }, updateStatus: { [weak self] status in
            if let strongSelf = self {
                switch status {
                    case .notReady:
                        strongSelf.doneItem?.isEnabled = false
                    case .ready:
                        strongSelf.doneItem?.isEnabled = true
                    case .verifying:
                        break
                }
                switch status {
                    case .verifying:
                        if strongSelf.activityItem == nil {
                            strongSelf.activityItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.presentationData.theme.rootController.navigationBar.controlColor))
                            strongSelf.navigationItem.setRightBarButton(strongSelf.activityItem, animated: false)
                        }
                    default:
                        if strongSelf.activityItem != nil {
                            strongSelf.activityItem = nil
                            strongSelf.navigationItem.setRightBarButton(strongSelf.doneItem, animated: false)
                        }
                }
            }
        }, formInfoUpdated: { [weak self] formInfo, validatedInfo in
            if let strongSelf = self {
                strongSelf.formInfoUpdated(formInfo, validatedInfo)
                strongSelf.dismiss()
            }
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
    
    @objc func donePressed() {
        self.controllerNode.verify()
    }
}
