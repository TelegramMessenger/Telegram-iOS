import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction

public protocol ChatInputPanelViewForOverlayContent: UIView {
    func maybeDismissContent(point: CGPoint)
}

open class ChatInputPanelNode: ASDisplayNode {
    open var context: AccountContext?
    open var chatControllerInteraction: ChatControllerInteraction?
    open var interfaceInteraction: ChatPanelInterfaceInteraction?
    open var prevInputPanelNode: ChatInputPanelNode?
    
    open var viewForOverlayContent: ChatInputPanelViewForOverlayContent?
    
    open func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    open func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        return 0.0
    }
    
    open func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return 0.0
    }
    
    open func defaultHeight(metrics: LayoutMetrics) -> CGFloat {
        if case .regular = metrics.widthClass, case .regular = metrics.heightClass {
            return 40.0
        } else {
            return 40.0
        }
    }
    
    open func canHandleTransition(from prevInputPanelNode: ChatInputPanelNode?) -> Bool {
        return false
    }
}
