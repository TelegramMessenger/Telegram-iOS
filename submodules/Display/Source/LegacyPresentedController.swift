import Foundation
import UIKit
import AsyncDisplayKit

public enum LegacyPresentedControllerPresentation {
    case custom
    case modal
}

private func passControllerAppearanceAnimated(presentation: LegacyPresentedControllerPresentation) -> Bool {
    switch presentation {
        case .custom:
            return false
        case .modal:
            return true
    }
}

open class LegacyPresentedController: ViewController {
    private let legacyController: UIViewController
    private let presentation: LegacyPresentedControllerPresentation
    
    private var controllerNode: LegacyPresentedControllerNode {
        return self.displayNode as! LegacyPresentedControllerNode
    }
    private var loadedController = false
    
    var controllerLoaded: (() -> Void)?
    
    private let asPresentable = true
    
    public init(legacyController: UIViewController, presentation: LegacyPresentedControllerPresentation) {
        self.legacyController = legacyController
        self.presentation = presentation
        
        super.init(navigationBarPresentationData: nil)
        
        /*legacyController.navigation_setDismiss { [weak self] in
            self?.dismiss()
        }*/
        if !asPresentable {
            self.addChild(legacyController)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = LegacyPresentedControllerNode()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        if !loadedController && !asPresentable {
            loadedController = true

            self.controllerNode.controllerView = self.legacyController.view
            self.controllerNode.view.addSubview(self.legacyController.view)
            self.legacyController.didMove(toParent: self)
            
            if let controllerLoaded = self.controllerLoaded {
                controllerLoaded()
            }
        }
        
        if !asPresentable {
            self.legacyController.viewWillAppear(animated && passControllerAppearanceAnimated(presentation: self.presentation))
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        if !asPresentable {
            self.legacyController.viewWillDisappear(animated && passControllerAppearanceAnimated(presentation: self.presentation))
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        if asPresentable {
            if !loadedController {
                loadedController = true
                //self.legacyController.modalPresentationStyle = .currentContext
                self.present(self.legacyController, animated: false, completion: nil)
            }
        } else {
            switch self.presentation {
                case .modal:
                    self.controllerNode.animateModalIn()
                    self.legacyController.viewDidAppear(true)
                case .custom:
                    self.legacyController.viewDidAppear(animated)
            }
        }
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if !self.asPresentable {
            self.legacyController.viewDidDisappear(animated && passControllerAppearanceAnimated(presentation: self.presentation))
        }
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        switch self.presentation {
            case .modal:
                self.controllerNode.animateModalOut { [weak self] in
                    /*if let controller = self?.legacyController as? TGViewController {
                        controller.didDismiss()
                    } else if let controller = self?.legacyController as? TGNavigationController {
                        controller.didDismiss()
                    }*/
                    self?.presentingViewController?.dismiss(animated: false, completion: completion)
                }
            case .custom:
                /*if let controller = self.legacyController as? TGViewController {
                    controller.didDismiss()
                } else if let controller = self.legacyController as? TGNavigationController {
                    controller.didDismiss()
                }*/
                self.presentingViewController?.dismiss(animated: false, completion: completion)
        }
    }
}
