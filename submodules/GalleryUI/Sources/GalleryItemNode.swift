import Foundation
import UIKit
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
    public var index: Int {
        get {
            return self._index!
        } set(value) {
            self._index = value
        }
    }
    
    public var toggleControlsVisibility: () -> Void = { }
    public var updateControlsVisibility: (Bool) -> Void = { _ in }
    public var updateOrientation: (UIInterfaceOrientation) -> Void = { _ in }
    public var dismiss: () -> Void = { }
    public var beginCustomDismiss: (Bool) -> Void = { _ in }
    public var completeCustomDismiss: () -> Void = { }
    public var baseNavigationController: () -> NavigationController? = { return nil }
    public var galleryController: () -> ViewController? = { return nil }
    public var alternativeDismiss: () -> Bool = { return false }
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
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
    
    open func rightBarButtonItems() -> Signal<[UIBarButtonItem]?, NoError> {
        return .single(nil)
    }
    
    open func isPagingEnabled() -> Signal<Bool, NoError> {
        return .single(true)
    }
    
    open func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((nil, nil))
    }
    
    open func navigationStyle() -> Signal<GalleryItemNodeNavigationStyle, NoError> {
        return .single(.dark)
    }
    
    open func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    open func centralityUpdated(isCentral: Bool) {
    }
    
    open func screenFrameUpdated(_ frame: CGRect) {
    }
    
    open func activateAsInitial() {
    }
    
    open func processAction(_ action: GalleryControllerItemNodeAction) {
    }
    
    open func visibilityUpdated(isVisible: Bool) {
    }
    
    open func controlsVisibilityUpdated(isVisible: Bool) {
    }
    
    open func adjustForPreviewing() {
    }
    
    open func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
    }
    
    open func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
    }
    
    open func contentSize() -> CGSize? {
        return nil
    }
}
