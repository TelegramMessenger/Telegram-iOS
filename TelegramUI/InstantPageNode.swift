import Foundation
import AsyncDisplayKit
import Display

protocol InstantPageNode {    
    func updateIsVisible(_ isVisible: Bool)
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)?
    func updateHiddenMedia(media: InstantPageMedia?)
    func update(strings: PresentationStrings, theme: InstantPageTheme)
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}
