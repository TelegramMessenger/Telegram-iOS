import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import AccountContext

public final class OverlayMediaControllerImpl: ViewController, OverlayMediaController {
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
    
    public var hasNodes: Bool {
        return self.controllerNode.hasNodes
    }
    
    public func addNode(_ node: OverlayMediaItemNode, customTransition: Bool) {
        self.controllerNode.addNode(node, customTransition: customTransition)
    }
    
    public func removeNode(_ node: OverlayMediaItemNode, customTransition: Bool) {
        self.controllerNode.removeNode(node, customTransition: customTransition)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let updatedLayout = ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: (layout.statusBarHeight ?? 0.0) + 44.0, left: layout.intrinsicInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.intrinsicInsets.right), safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
        self.controllerNode.containerLayoutUpdated(updatedLayout, transition: transition)
    }
}
