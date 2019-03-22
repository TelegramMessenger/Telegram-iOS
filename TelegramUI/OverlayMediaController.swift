import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox

public final class OverlayMediaController: ViewController {
    private var controllerNode: OverlayMediaControllerNode {
        return self.displayNode as! OverlayMediaControllerNode
    }
    
    public init() {
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = OverlayMediaControllerNode()
        self.displayNodeDidLoad()
    }
    
    var hasNodes: Bool {
        return self.controllerNode.hasNodes
    }
    
    func addNode(_ node: OverlayMediaItemNode, customTransition: Bool = false) {
        self.controllerNode.addNode(node, customTransition: customTransition)
    }
    
    func removeNode(_ node: OverlayMediaItemNode, customTransition: Bool = false) {
        self.controllerNode.removeNode(node, customTransition: customTransition)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let updatedLayout = ContainerViewLayout(size: layout.size, metrics: layout.metrics, intrinsicInsets: UIEdgeInsets(top: (layout.statusBarHeight ?? 0.0) + 44.0, left: layout.intrinsicInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.intrinsicInsets.right), safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, standardInputHeight: layout.standardInputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
        self.controllerNode.containerLayoutUpdated(updatedLayout, transition: transition)
    }
}
