import UIKit
import Display

public class NativeControllerWrapper: ViewController {
    
    private let controller: UIViewController
    private var validLayout: ContainerViewLayout?
    
    public override var childForStatusBarStyle: UIViewController? {
        return controller
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return controller.supportedInterfaceOrientations
    }
    
    //  MARK: - Lifecycle
    
    public init(controller: UIViewController) {
        self.controller = controller
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.addControllerIfNeeded()
        controller.viewWillAppear(false)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        controller.viewDidAppear(animated)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        controller.viewWillDisappear(animated)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        controller.viewDidDisappear(animated)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        controller.view.frame = self.view.bounds
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        let controllerFrame = CGRect(origin: CGPoint(), size: layout.size)
        
        self.addControllerIfNeeded()
        if case .immediate = transition {
            self.controller.view.frame = controllerFrame
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.controller.view.frame = controllerFrame
            })
        }
    }
    
    //  MARK: - Private Functions
    
    private func addControllerIfNeeded() {
        if !controller.isViewLoaded || controller.view.superview == nil {
            self.displayNode.view.addSubview(controller.view)
            if let layout = self.validLayout {
                controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            }
        }
    }
}
