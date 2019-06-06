import Foundation
import UIKit
import AsyncDisplayKit

struct OverlayMediaItemNodeGroup: Hashable, RawRepresentable {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    var hashValue: Int {
        return self.rawValue.hashValue
    }
}

enum OverlayMediaItemMinimizationEdge {
    case left
    case right
}

class OverlayMediaItemNode: ASDisplayNode {
    var hasAttachedContextUpdated: ((Bool) -> Void)?
    var hasAttachedContext: Bool = false
    
    var unminimize: (() -> Void)?
    
    var group: OverlayMediaItemNodeGroup? {
        return nil
    }
    
    var tempExtendedTopInset: Bool {
        return false
    }
    
    var isMinimizeable: Bool {
        return false
    }
    
    var customTransition: Bool = false
    
    func setShouldAcquireContext(_ value: Bool) {
    }
    
    func preferredSizeForOverlayDisplay() -> CGSize {
        return CGSize(width: 50.0, height: 50.0)
    }
    
    func updateLayout(_ size: CGSize) {
    }
    
    func dismiss() {
    }
    
    func updateMinimizedEdge(_ edge: OverlayMediaItemMinimizationEdge?, adjusting: Bool) {
    }
    
    func performCustomTransitionIn() -> Bool {
        return false
    }
    
    func performCustomTransitionOut() -> Bool {
        return false
    }
}
