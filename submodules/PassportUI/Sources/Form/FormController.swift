import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData

public class FormController<InnerState, InitParams, Node: FormControllerNode<InitParams, InnerState>>: ViewController {
    public var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let initParams: InitParams
    private var presentationData: PresentationData
        
    init(initParams: InitParams, presentationData: PresentationData) {
        self.initParams = initParams
        self.presentationData = presentationData
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.view.endEditing(true)
        super.dismiss(completion: completion)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(initParams: self.initParams, presentationData: self.presentationData)
        self.controllerNode.present = { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
