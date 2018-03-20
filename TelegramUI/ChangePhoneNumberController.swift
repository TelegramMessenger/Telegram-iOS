import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit

final class ChangePhoneNumberController: ViewController {
    private var controllerNode: ChangePhoneNumberControllerNode {
        return self.displayNode as! ChangePhoneNumberControllerNode
    }
    
    private let account: Account
    
    private var currentData: (Int32, String)?
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
    
    init(account: Account) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
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
    
    func updateData(countryCode: Int32, number: String) {
        if self.currentData == nil || self.currentData! != (countryCode, number) {
            self.currentData = (countryCode, number)
            if self.isNodeLoaded {
                self.controllerNode.codeAndNumber = (countryCode, number)
            }
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChangePhoneNumberControllerNode(presentationData: self.presentationData)
        self.displayNodeDidLoad()
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: defaultLightAuthorizationTheme)
                controller.completeWithCountryCode = { code, _ in
                    if let strongSelf = self {
                        strongSelf.updateData(countryCode: Int32(code), number: strongSelf.controllerNode.codeAndNumber.1)
                        strongSelf.controllerNode.activateInput()
                    }
                }
                strongSelf.controllerNode.view.endEditing(true)
                strongSelf.present(controller, in: .window(.root))
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    @objc func nextPressed() {
        let (_, number) = self.controllerNode.codeAndNumber
        if !number.isEmpty {
            self.inProgress = true
            self.requestDisposable.set((requestChangeAccountPhoneNumberVerification(account: self.account, phoneNumber: self.controllerNode.currentNumber) |> deliverOnMainQueue).start(next: { [weak self] next in
                if let strongSelf = self {
                    strongSelf.inProgress = false
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(changePhoneNumberCodeController(account: strongSelf.account, phoneNumber: strongSelf.controllerNode.currentNumber, codeData: next))
                }
            }, error: { [weak self] error in
                if let strongSelf = self {
                    strongSelf.inProgress = false
                    
                    let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                
                    let text: String
                    switch error {
                        case .limitExceeded:
                            text = "You have requested authorization code too many times. Please try again later."
                        case .invalidPhoneNumber:
                            text = "The phone number you entered is not valid. Please enter the correct number along with your area code."
                        case .phoneNumberOccupied:
                            text = "The number \(number) is already connected to a Telegram account. Please delete that account before migrating to the new number."
                        case .generic:
                            text = "An error occurred. Please try again later."
                    }
                    
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window(.root))
                }
            }))
        } else {
            hapticFeedback.error()
            self.controllerNode.animateError()
        }
    }
}
