import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import SearchBarNode

open class SearchDisplayControllerContentNode: ASDisplayNode {
    public final var dismissInput: (() -> Void)?
    public final var cancel: (() -> Void)?
    public final var setQuery: ((NSAttributedString?, [SearchBarToken], String) -> Void)?
    public final var setPlaceholder: ((String) -> Void)?
    
    open var animateBackgroundAppearance: Bool {
        return true
    }
    
    open var hasDim: Bool {
        return false
    }
    
    open var isSearching: Signal<Bool, NoError> {
        return .single(false)
    }
    
    override public init() {
        super.init()
    }
    
    open func updatePresentationData(_ presentationData: PresentationData) {
    }
    
    open func searchTextUpdated(text: String) {
    }
    
    open func searchTokensUpdated(tokens: [SearchBarToken]) {
    }
    
    open func searchTextClearPrefix() {
    }
    
    open func searchTextClearTokens() {
    }
    
    open func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    
    }
    
    open func ready() -> Signal<Void, NoError> {
        return .single(Void())
    }
    
    open func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
        return nil
    }
    
    open func scrollToTop() {
    }
}
