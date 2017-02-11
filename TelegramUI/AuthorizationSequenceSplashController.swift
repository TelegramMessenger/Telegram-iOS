import Foundation
import Display
import AsyncDisplayKit

import TelegramUIPrivateModule

final class AuthorizationSequenceSplashController: ViewController {
    private var controllerNode: AuthorizationSequenceSplashControllerNode {
        return self.displayNode as! AuthorizationSequenceSplashControllerNode
    }
    
    private let controller = RMIntroViewController()
    
    var nextPressed: (() -> Void)?
    
    override init(navigationBar: NavigationBar = NavigationBar()) {
        super.init(navigationBar: navigationBar)
        
        self.navigationBar.isHidden = true
        self.controller.startMessaging = { [weak self] in
            self?.nextPressed?()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceSplashControllerNode()
        self.displayNodeDidLoad()
    }
    
    private func addControllerIfNeeded() {
        if !controller.isViewLoaded {
            self.displayNode.view.addSubview(controller.view)
            controller.view.frame = self.displayNode.bounds;
            controller.viewDidAppear(false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        controller.viewWillAppear(false)
        self.addControllerIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        controller.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        controller.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        controller.viewDidDisappear(animated)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
        
        self.addControllerIfNeeded()
        if case .immediate = transition {
            self.controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            })
        }
    }
}
