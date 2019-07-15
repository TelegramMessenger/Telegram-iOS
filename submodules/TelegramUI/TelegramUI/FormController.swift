import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData

class FormController<InnerState, InitParams, Node: FormControllerNode<InitParams, InnerState>>: ViewController {
    var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let initParams: InitParams
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    init(initParams: InitParams, presentationData: PresentationData) {
        self.initParams = initParams
        self.presentationData = presentationData
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.controllerNode.animateIn()
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.view.endEditing(true)
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override func loadDisplayNode() {
        self.displayNode = Node(initParams: self.initParams, presentationData: self.presentationData)
        self.controllerNode.present = { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }
        
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}
