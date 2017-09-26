import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

class SearchDisplayControllerContentNode: ASDisplayNode {
    final var dismissInput: (() -> Void)?
    final var cancel: (() -> Void)?
    
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
    
    func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, Any)? {
        return nil
    }
}
