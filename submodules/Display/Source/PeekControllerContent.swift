import Foundation
import UIKit
import AsyncDisplayKit

public enum PeekControllerContentPresentation {
    case contained
    case freeform
}

public enum PeerkControllerMenuActivation {
    case drag
    case press
}

public protocol PeekControllerContent {
    func presentation() -> PeekControllerContentPresentation
    func menuActivation() -> PeerkControllerMenuActivation
    func menuItems() -> [PeekControllerMenuItem]
    func node() -> PeekControllerContentNode & ASDisplayNode
    
    func topAccessoryNode() -> ASDisplayNode?
    
    func isEqual(to: PeekControllerContent) -> Bool
}

public protocol PeekControllerContentNode {
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}
