import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class AuthorizationSequencePhoneEntryController: ViewController {
    private var controllerNode: AuthorizationSequencePhoneEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePhoneEntryControllerNode
    }
    
    private let otherAccountPhoneNumbers: [String]
    private let network: Network
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    private let openUrl: (String) -> Void
    
    private let back: () -> Void
    
    private var currentData: (Int32, String?, String)?
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.theme.accentColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    var loginWithNumber: ((String) -> Void)?
    
    private let termsDisposable = MetaDisposable()
    
    private let hapticFeedback = HapticFeedback()
    
    init(otherAccountPhoneNumbers: [String], network: Network, strings: PresentationStrings, theme: AuthorizationTheme, openUrl: @escaping (String) -> Void, back: @escaping () -> Void) {
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        self.network = network
        self.strings = strings
        self.theme = theme
        self.openUrl = openUrl
        self.back = back
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = theme.statusBarStyle
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
        
        if !otherAccountPhoneNumbers.isEmpty {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.termsDisposable.dispose()
    }
    
    @objc private func cancelPressed() {
        self.back()
    }
    
    func updateData(countryCode: Int32, countryName: String?, number: String) {
        self.currentData = (countryCode, countryName, number)
        if self.isNodeLoaded {
            self.controllerNode.codeAndNumber = (countryCode, countryName, number)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePhoneEntryControllerNode(strings: self.strings, theme: self.theme)
        if let (code, name, number) = self.currentData {
            self.controllerNode.codeAndNumber = (code, name, number)
        }
        self.displayNodeDidLoad()
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.strings, theme: AuthorizationSequenceCountrySelectionTheme(authorizationTheme: strongSelf.theme))
                controller.completeWithCountryCode = { code, name in
                    if let strongSelf = self, let currentData = strongSelf.currentData {
                        strongSelf.updateData(countryCode: Int32(code), countryName: name, number: currentData.2)
                        strongSelf.controllerNode.activateInput()
                    }
                }
                controller.dismissed = {
                    self?.controllerNode.activateInput()
                }
                strongSelf.controllerNode.view.endEditing(true)
                strongSelf.present(controller, in: .window(.root))
            }
        }
        self.controllerNode.checkPhone = { [weak self] in
            self?.nextPressed()
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
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func nextPressed() {
        let (_, _, number) = self.controllerNode.codeAndNumber
        if !number.isEmpty {
            if self.otherAccountPhoneNumbers.lazy.map(formatPhoneNumber).contains(formatPhoneNumber(self.controllerNode.currentNumber)) {
                self.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: self.theme), title: nil, text: self.strings.Login_PhoneNumberAlreadyAuthorized, actions: [TextAlertAction(type: .defaultAction, title: self.strings.Common_OK, action: {})]), in: .window(.root))
            } else {
                self.loginWithNumber?(self.controllerNode.currentNumber)
            }
        } else {
            hapticFeedback.error()
            self.controllerNode.animateError()
        }
    }
}
