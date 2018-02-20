import Foundation
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
}

public protocol PeekControllerContentNode {
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}
