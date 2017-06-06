import Foundation
import Display
import AsyncDisplayKit

final class AuthorizationSequencePasswordEntryController: ViewController {
    private var controllerNode: AuthorizationSequencePasswordEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePasswordEntryControllerNode
    }
    
    var loginWithPassword: ((String) -> Void)?
    var hint: String?
    
    private let hapticFeedback = HapticFeedback()
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode())
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(self.nextPressed))
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    init() {
        super.init(navigationBarTheme: AuthorizationSequenceController.navigationBarTheme)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(self.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePasswordEntryControllerNode()
        self.displayNodeDidLoad()
        
        self.controllerNode.loginWithCode = { [weak self] _ in
            self?.nextPressed()
        }
        
        if let hint = self.hint {
            self.controllerNode.updateData(hint: hint)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateData(hint: String) {
        if self.hint != hint {
            self.hint = hint
            if self.isNodeLoaded {
                self.controllerNode.updateData(hint: hint)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    @objc func nextPressed() {
        if self.controllerNode.currentPassword.isEmpty {
            hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            self.loginWithPassword?(self.controllerNode.currentPassword)
        }
    }
}
