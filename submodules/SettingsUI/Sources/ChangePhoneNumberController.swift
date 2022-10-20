import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import AlertUI
import PresentationDataUtils
import CountrySelectionUI
import PhoneNumberFormat
import CoreTelephony
import MessageUI

public final class ChangePhoneNumberController: ViewController, MFMailComposeViewControllerDelegate {
    private var controllerNode: ChangePhoneNumberControllerNode {
        return self.displayNode as! ChangePhoneNumberControllerNode
    }
    
    private let context: AccountContext
    
    private var currentData: (Int32, String?, String)?
    private let requestDisposable = MetaDisposable()
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    var loginWithNumber: ((String) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    private var presentationData: PresentationData
    
    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.ChangePhoneNumberNumber_Title
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.requestDisposable.dispose()
    }
    
    func updateData(countryCode: Int32, countryName: String, number: String) {
        if self.currentData == nil || self.currentData! != (countryCode, countryName, number) {
            self.currentData = (countryCode, countryName, number)
            if self.isNodeLoaded {
                self.controllerNode.codeAndNumber = (countryCode, countryName, number)
            }
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChangePhoneNumberControllerNode(presentationData: self.presentationData)
        self.displayNodeDidLoad()
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme)
                controller.completeWithCountryCode = { code, name in
                    if let strongSelf = self {
                        strongSelf.updateData(countryCode: Int32(code), countryName: name, number: strongSelf.controllerNode.codeAndNumber.2)
                        strongSelf.controllerNode.activateInput()
                    }
                }
                strongSelf.controllerNode.view.endEditing(true)
                strongSelf.push(controller)
            }
        }
        
        loadServerCountryCodes(accountManager: self.context.sharedContext.accountManager, engine: self.context.engine, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.updateCountryCode()
            }
        })
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    @objc func nextPressed() {
        let (code, _, number) = self.controllerNode.codeAndNumber
        var phoneNumber = number
        if let code = code {
            phoneNumber = "\(code)\(phoneNumber)"
        }
        if !number.isEmpty {
            self.inProgress = true
            self.requestDisposable.set((self.context.engine.accountData.requestChangeAccountPhoneNumberVerification(phoneNumber: self.controllerNode.currentNumber) |> deliverOnMainQueue).start(next: { [weak self] next in
                if let strongSelf = self {
                    strongSelf.inProgress = false
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(changePhoneNumberCodeController(context: strongSelf.context, phoneNumber: strongSelf.controllerNode.currentNumber, codeData: next))
                }
            }, error: { [weak self] error in
                if let strongSelf = self {
                    strongSelf.inProgress = false
                    
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                
                    let text: String
                    var actions: [TextAlertAction] = []
                    switch error {
                        case .limitExceeded:
                            text = presentationData.strings.Login_CodeFloodError
                            actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                        case .invalidPhoneNumber:
                            text = presentationData.strings.Login_InvalidPhoneError
                            actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                        case .phoneNumberOccupied:
                            text = presentationData.strings.ChangePhone_ErrorOccupied(formatPhoneNumber(phoneNumber)).string
                            actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                        case .phoneBanned:
                            text = presentationData.strings.Login_PhoneBannedError
                            actions.append(TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                            actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Login_PhoneNumberHelp, action: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                let formattedNumber = formatPhoneNumber(number)
                                let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
                                let systemVersion = UIDevice.current.systemVersion
                                let locale = Locale.current.identifier
                                let carrier = CTCarrier()
                                let mnc = carrier.mobileNetworkCode ?? "none"
                                
                                strongSelf.presentEmailComposeController(address: "login@stel.com", subject: presentationData.strings.Login_PhoneBannedEmailSubject(formattedNumber).string, body: presentationData.strings.Login_PhoneBannedEmailBody(formattedNumber, appVersion, systemVersion, locale, mnc).string)
                            }))
                        case .generic:
                            text = presentationData.strings.Login_UnknownError
                            actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                    }
                    
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: actions), in: .window(.root))
                }
            }))
        } else {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        }
    }
    
    private func presentEmailComposeController(address: String, subject: String, body: String) {
        if MFMailComposeViewController.canSendMail() {
            let composeController = MFMailComposeViewController()
            composeController.setToRecipients([address])
            composeController.setSubject(subject)
            composeController.setMessageBody(body, isHTML: false)
            composeController.mailComposeDelegate = self
            
            self.view.window?.rootViewController?.present(composeController, animated: true, completion: nil)
        } else {
            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Login_EmailNotConfiguredError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
