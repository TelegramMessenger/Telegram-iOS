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
        super.init(navigationBarTheme: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = OverlayMediaControllerNode()
        self.displayNodeDidLoad()
    }
    
    func addVideoContext(mediaManager: MediaManager, postbox: Postbox, id: ManagedMediaId, resource: MediaResource, priority: Int32) {
        self.controllerNode.addVideoContext(mediaManager: mediaManager, postbox: postbox, id: id, resource: resource, priority: priority)
    }
    
    func removeVideoContext(id: ManagedMediaId) {
        self.controllerNode.removeVideoContext(id: id)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
