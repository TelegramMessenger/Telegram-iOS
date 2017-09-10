import Foundation
import Display
import AsyncDisplayKit

final class AuthorizationSequenceSignUpController: ViewController {
    private var controllerNode: AuthorizationSequenceSignUpControllerNode {
        return self.displayNode as! AuthorizationSequenceSignUpControllerNode
    }
    
    var initialName: (String, String) = ("", "")
    var signUpWithName: ((String, String) -> Void)?
    
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
        self.displayNode = AuthorizationSequenceSignUpControllerNode()
        self.displayNodeDidLoad()
        
        self.controllerNode.signUpWithName = { [weak self] _, _ in
            self?.nextPressed()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateData(firstName: String, lastName: String) {
        if self.isNodeLoaded {
            if (firstName, lastName) != self.controllerNode.currentName {
                self.controllerNode.updateData(firstName: firstName, lastName: lastName)
            }
        } else {
            self.initialName = (firstName, lastName)
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    @objc func nextPressed() {
        if self.controllerNode.currentName.0.isEmpty {
            hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            let name = self.controllerNode.currentName
            self.signUpWithName?(name.0, name.1)
        }
    }
}
