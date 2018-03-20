import Foundation
import Display
import AsyncDisplayKit
import TelegramCore

final class AuthorizationSequenceCodeEntryController: ViewController {
    private var controllerNode: AuthorizationSequenceCodeEntryControllerNode {
        return self.displayNode as! AuthorizationSequenceCodeEntryControllerNode
    }
    
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    
    var loginWithCode: ((String) -> Void)?
    var requestNextOption: (() -> Void)?
    
    var data: (String, SentAuthorizationCodeType, AuthorizationCodeNextType?, Int32?)?
    
    private let hapticFeedback = HapticFeedback()
    
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
    
    init(strings: PresentationStrings, theme: AuthorizationTheme) {
        self.strings = strings
        self.theme = theme
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = theme.statusBarStyle
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceCodeEntryControllerNode(strings: self.strings, theme: self.theme)
        self.displayNodeDidLoad()
        
        self.controllerNode.loginWithCode = { [weak self] code in
            self?.loginWithCode?(code)
        }
        
        self.controllerNode.requestNextOption = { [weak self] in
            self?.requestNextOption?()
        }
        
        self.controllerNode.requestAnotherOption = { [weak self] in
            self?.requestNextOption?()
        }
        
        if let (number, codeType, nextType, timeout) = self.data {
            self.controllerNode.updateData(number: number, codeType: codeType, nextType: nextType, timeout: timeout)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateData(number: String, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?) {
        if self.data?.0 != number || self.data?.1 != codeType || self.data?.2 != nextType || self.data?.3 != timeout {
            self.data = (number, codeType, nextType, timeout)
            if self.isNodeLoaded {
                self.controllerNode.updateData(number: number, codeType: codeType, nextType: nextType, timeout: timeout)
                self.requestLayout(transition: .immediate)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func nextPressed() {
        if self.controllerNode.currentCode.isEmpty {
            hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            self.loginWithCode?(self.controllerNode.currentCode)
        }
    }
}
