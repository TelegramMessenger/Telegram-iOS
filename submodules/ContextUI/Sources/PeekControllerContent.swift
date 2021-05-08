import Foundation
import UIKit
import AsyncDisplayKit
import Display

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
    
    func isEqual(to: PeekControllerContent) -> Bool
}

public protocol PeekControllerContentNode {
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}
