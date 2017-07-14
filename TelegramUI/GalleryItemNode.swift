import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox

public enum GalleryItemNodeNavigationStyle {
    case light
    case dark
}

open class GalleryItemNode: ASDisplayNode {
    private var _index: Int?
    var index: Int {
        get {
            return self._index!
        } set(value) {
            self._index = value
        }
    }
    
    var toggleControlsVisibility: () -> Void = { }
    var beginCustomDismiss: () -> Void = { }
    var completeCustomDismiss: () -> Void = { }
    var baseNavigationController: () -> NavigationController? = { return nil }
    
    override init() {
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
    }
    
    open func ready() -> Signal<Void, NoError> {
        return .single(Void())
    }
    
    open func title() -> Signal<String, NoError> {
        return .single("")
    }
    
    open func titleView() -> Signal<UIView?, NoError> {
        return .single(nil)
    }
    
    open func rightBarButtonItem() -> Signal<UIBarButtonItem?, NoError> {
        return .single(nil)
    }
    
    open func footerContent() -> Signal<GalleryFooterContentNode?, NoError> {
        return .single(nil)
    }
    
    open func navigationStyle() -> Signal<GalleryItemNodeNavigationStyle, NoError> {
        return .single(.dark)
    }
    
    open func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    open func centralityUpdated(isCentral: Bool) {
    }
    
    open func visibilityUpdated(isVisible: Bool) {
    }
    
    open func animateIn(from node: ASDisplayNode) {
    }
    
    open func animateOut(to node: ASDisplayNode, completion: @escaping () -> Void) {
    }
}
