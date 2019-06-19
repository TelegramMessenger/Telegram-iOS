import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

class SearchDisplayControllerContentNode: ASDisplayNode {
    final var dismissInput: (() -> Void)?
    final var cancel: (() -> Void)?
    final var setQuery: ((NSAttributedString?, String) -> Void)?
    final var setPlaceholder: ((String) -> Void)?
    
    var isSearching: Signal<Bool, NoError> {
        return .single(false)
    }
    
    override init() {
        super.init()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
    
    }
    
    func searchTextUpdated(text: String) {
        
    }
    
    func searchTextClearPrefix() {
        
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    
    }
    
    func ready() -> Signal<Void, NoError> {
        return .single(Void())
    }
    
    func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
        return nil
    }
    
    func scrollToTop() {
    }
}
