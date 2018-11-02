import Foundation
import AsyncDisplayKit

protocol InstantPageNode {    
    func updateIsVisible(_ isVisible: Bool)
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)?
    func updateHiddenMedia(media: InstantPageMedia?)
    func update(strings: PresentationStrings, theme: InstantPageTheme)
}
