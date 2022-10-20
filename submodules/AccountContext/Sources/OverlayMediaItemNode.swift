import Foundation
import UIKit
import AsyncDisplayKit
import AVKit

public struct OverlayMediaItemNodeGroup: Hashable, RawRepresentable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

public enum OverlayMediaItemMinimizationEdge {
    case left
    case right
}

open class OverlayMediaItemNode: ASDisplayNode {
    open var hasAttachedContextUpdated: ((Bool) -> Void)?
    open var hasAttachedContext: Bool = false
    
    open var unminimize: (() -> Void)?
    
    public var manualExpandEmbed: (() -> Void)?
    public var customUnembedWhenPortrait: ((OverlayMediaItemNode) -> Bool)?
    
    open var group: OverlayMediaItemNodeGroup? {
        return nil
    }
    
    open var tempExtendedTopInset: Bool {
        return false
    }
    
    open var isMinimizeable: Bool {
        return false
    }
    
    open var customTransition: Bool = false
    
    open func setShouldAcquireContext(_ value: Bool) {
    }
    
    open func preferredSizeForOverlayDisplay(boundingSize: CGSize) -> CGSize {
        return CGSize(width: 50.0, height: 50.0)
    }
    
    open func updateLayout(_ size: CGSize) {
    }
    
    open func dismiss() {
    }
    
    open func updateMinimizedEdge(_ edge: OverlayMediaItemMinimizationEdge?, adjusting: Bool) {
    }
    
    open func performCustomTransitionIn() -> Bool {
        return false
    }
    
    open func performCustomTransitionOut() -> Bool {
        return false
    }

    @available(iOSApplicationExtension 15.0, iOS 15.0, *)
    open func makeNativeContentSource() -> AVPictureInPictureController.ContentSource? {
        return nil
    }
}
