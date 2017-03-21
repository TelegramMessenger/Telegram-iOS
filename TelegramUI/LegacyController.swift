import Foundation
import Display
import TelegramLegacyComponents

enum LegacyControllerPresentation {
    case custom
    case modal
}

private func passControllerAppearanceAnimated(presentation: LegacyControllerPresentation) -> Bool {
    switch presentation {
        case .custom:
            return false
        case .modal:
            return true
    }
}

private final class LegacyControllerApplicationInterface: NSObject, TGLegacyApplicationInterface {
    private weak var controller: ViewController?
    
    init(controller: ViewController?) {
        self.controller = controller
        
        super.init()
    }
    
    @available(iOS 8.0, *)
    public func currentSizeClass() -> UIUserInterfaceSizeClass {
        return .compact
    }
    
    @available(iOS 8.0, *)
    public func currentHorizontalSizeClass() -> UIUserInterfaceSizeClass {
        return .compact
    }
    
    public func forceSetStatusBarHidden(_ hidden: Bool, with animation: UIStatusBarAnimation) {
        if let controller = self.controller {
            controller.statusBar.isHidden = hidden
        }
    }
    
    public func applicationBounds() -> CGRect {
        if let controller = controller {
            return controller.view.bounds;
        } else {
            return CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 320.0, height: 480.0))
        }
    }
    
    public func applicationStatusBarAlpha() -> CGFloat {
        return controller?.statusBar.alpha ?? 1.0
    }
    
    public func setApplicationStatusBarAlpha(_ alpha: CGFloat) {
        controller?.statusBar.alpha = alpha
    }
    
    public func applicationStatusBarOffset() -> CGFloat {
        return 0.0
    }
    
    public func setApplicationStatusBarOffset(_ offset: CGFloat) {
        
    }
    
    public func animateApplicationStatusBarAppearance(_ statusBarAnimation: Int32, delay: TimeInterval, duration: TimeInterval, completion: (() -> Swift.Void)!) {
        if let completion = completion {
            completion()
        }
    }
    
    public func animateApplicationStatusBarAppearance(_ statusBarAnimation: Int32, duration: TimeInterval, completion: (() -> Swift.Void)!) {
        if let completion = completion {
            completion()
        }
    }
    
    public func animateApplicationStatusBarStyleTransition(withDuration duration: TimeInterval) {
        
    }
}

class LegacyController: ViewController {
    private let legacyController: UIViewController
    private let presentation: LegacyControllerPresentation
    
    private var controllerNode: LegacyControllerNode {
        return self.displayNode as! LegacyControllerNode
    }
    
    var applicationInterface: TGLegacyApplicationInterface {
        return LegacyControllerApplicationInterface(controller: self)
    }
    
    var controllerLoaded: (() -> Void)?
    
    init(legacyController: UIViewController, presentation: LegacyControllerPresentation) {
        self.legacyController = legacyController
        self.presentation = presentation
        
        super.init()
        
        if let legacyController = legacyController as? TGLegacyApplicationInterfaceHolder {
            legacyController.applicationInterface = self.applicationInterface
        }
        
        self.navigationBar.isHidden = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = LegacyControllerNode()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !self.legacyController.isViewLoaded {
            self.controllerNode.controllerView = self.legacyController.view
            self.controllerNode.view.addSubview(self.legacyController.view)
            
            if let controllerLoaded = self.controllerLoaded {
                controllerLoaded()
            }
        }
        
        self.legacyController.viewWillAppear(animated && passControllerAppearanceAnimated(presentation: self.presentation))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.legacyController.viewWillDisappear(animated && passControllerAppearanceAnimated(presentation: self.presentation))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        switch self.presentation {
            case .modal:
                self.controllerNode.animateModalIn()
                self.legacyController.viewDidAppear(true)
            case .custom:
                self.legacyController.viewDidAppear(animated)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.legacyController.viewDidDisappear(animated && passControllerAppearanceAnimated(presentation: self.presentation))
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override open func dismiss() {
        switch self.presentation {
            case .modal:
                self.controllerNode.animateModalOut { [weak self] in
                    if let controller = self?.legacyController as? TGViewController {
                        controller.didDismiss()
                    } else if let controller = self?.legacyController as? TGNavigationController {
                        controller.didDismiss()
                    }
                    self?.presentingViewController?.dismiss(animated: false, completion: nil)
                }
            case .custom:
                if let controller = self.legacyController as? TGViewController {
                    controller.didDismiss()
                } else if let controller = self.legacyController as? TGNavigationController {
                    controller.didDismiss()
                }
                self.presentingViewController?.dismiss(animated: false, completion: nil)
        }
    }
}
