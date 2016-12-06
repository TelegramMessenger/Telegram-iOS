import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

class UniversalMasterController: ViewController {
    private var controllers: [ViewController] = []
    
    public init() {
        super.init(navigationBar: NavigationBar())
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    
}
