import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

class SearchDisplayControllerContentNode: ASDisplayNode {
    override init() {
        super.init()
        
        self.backgroundColor = UIColor.white
    }
    
    func searchTextUpdated(text: String) {
        
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    
    }
    
    func ready() -> Signal<Void, NoError> {
        return .single(Void())
    }
}
