import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit
import ReactionSelectionNode

enum ContextControllerPresentationNodeStateTransition {
    case animateIn
    case animateOut(result: ContextMenuActionResult, completion: () -> Void)
}

protocol ContextControllerPresentationNode: ASDisplayNode {
    func replaceItems(items: ContextController.Items, animated: Bool)
    func pushItems(items: ContextController.Items)
    func popItems()
    
    func update(
        presentationData: PresentationData,
        layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition,
        stateTransition: ContextControllerPresentationNodeStateTransition?
    )
    
    func animateOutToReaction(value: String, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, completion: @escaping () -> Void)
    func cancelReactionAnimation()
    
    func highlightGestureMoved(location: CGPoint)
    func highlightGestureFinished(performAction: Bool)
    
    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition)
}
