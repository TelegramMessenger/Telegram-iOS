import Foundation
import Display
import AsyncDisplayKit

final class AuthorizationSequencePhoneEntryController: ViewController {
    private var controllerNode: AuthorizationSequencePhoneEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePhoneEntryControllerNode
    }
    
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    
    private var currentData: (Int32, String)?
    
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
    
    private let hapticFeedback = HapticFeedback()
    
    init(strings: PresentationStrings, theme: AuthorizationTheme) {
        self.strings = strings
        self.theme = theme
        
        super.init(navigationBarTheme: AuthorizationSequenceController.navigationBarTheme(theme))
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = theme.statusBarStyle
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        self.displayNode = AuthorizationSequencePhoneEntryControllerNode(strings: self.strings, theme: self.theme)
        self.displayNodeDidLoad()
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.strings, theme: strongSelf.theme)
                controller.completeWithCountryCode = { code, _ in
                    if let strongSelf = self, let currentData = strongSelf.currentData {
                        strongSelf.updateData(countryCode: Int32(code), number: currentData.1)
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
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func nextPressed() {
        let (_, number) = self.controllerNode.codeAndNumber
        if !number.isEmpty {
            self.loginWithNumber?(self.controllerNode.currentNumber)
        } else {
            hapticFeedback.error()
            self.controllerNode.animateError()
        }
    }
}
