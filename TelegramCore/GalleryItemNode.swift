import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

enum GalleryItemNodeNavigationStyle {
    case light
    case dark
}

class GalleryItemNode: ASDisplayNode {
    private var _index: Int?
    var index: Int {
        get {
            return self._index!
        } set(value) {
            self._index = value
        }
    }
    
    var toggleControlsVisibility: () -> Void = { }
    
    override init() {
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
    }
    
    func ready() -> Signal<Void, NoError> {
        return .single(Void())
    }
    
    func title() -> Signal<String, NoError> {
        return .single("")
    }
    
    func titleView() -> Signal<UIView?, NoError> {
        return .single(nil)
    }
    
    func navigationStyle() -> Signal<GalleryItemNodeNavigationStyle, NoError> {
        return .single(.dark)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    func centralityUpdated(isCentral: Bool) {
    }
    
    func visibilityUpdated(isVisible: Bool) {
    }
    
    func animateIn(from node: ASDisplayNode) {
    }
    
    func animateOut(to node: ASDisplayNode, completion: () -> Void) {
    }
}
