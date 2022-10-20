import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

public enum PeekControllerContentPresentation {
    case contained
    case freeform
}

public enum PeerControllerMenuActivation {
    case drag
    case press
}

public protocol PeekControllerContent {
    func presentation() -> PeekControllerContentPresentation
    func menuActivation() -> PeerControllerMenuActivation
    func menuItems() -> [ContextMenuItem]
    func node() -> PeekControllerContentNode & ASDisplayNode
    
    func topAccessoryNode() -> ASDisplayNode?
    func fullScreenAccessoryNode(blurView: UIVisualEffectView) -> (PeekControllerAccessoryNode & ASDisplayNode)?
    
    func isEqual(to: PeekControllerContent) -> Bool
}

public protocol PeekControllerContentNode {
    func ready() -> Signal<Bool, NoError>
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}

public protocol PeekControllerAccessoryNode {
    var dismiss: () -> Void { get set }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}
