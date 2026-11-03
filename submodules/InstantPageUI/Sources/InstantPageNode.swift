import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData

public protocol InstantPageExternalMediaDimensionsNode: AnyObject {
    var updateExternalMediaDimensions: ((EngineMedia.Id, PixelDimensions) -> Void)? { get set }
}

public protocol InstantPageNode: ASDisplayNode {    
    func updateIsVisible(_ isVisible: Bool)
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    func updateHiddenMedia(media: InstantPageMedia?)
    func update(strings: PresentationStrings, theme: InstantPageTheme)
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}
