import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction

public protocol ChatInputPanelViewForOverlayContent: UIView {
    func maybeDismissContent(point: CGPoint)
}

/// The bubble-free mode's "next channel" island, which the history hands to the input panel while a channel or topic is
/// pulled up past its end: the next channel (nil when there is none), what to call it, its unread count, and how far
/// the pull has gone (0 to 1, 1 being far enough to switch).
public struct ChatInputPanelOverscrollIsland {
    public let context: AccountContext
    public let peer: EnginePeer?
    public let title: String
    public let unreadCount: Int
    public let progress: CGFloat

    public init(context: AccountContext, peer: EnginePeer?, title: String, unreadCount: Int, progress: CGFloat) {
        self.context = context
        self.peer = peer
        self.title = title
        self.unreadCount = unreadCount
        self.progress = progress
    }
}

/// The extra side inset of the chat's bottom panels with a small bottom inset on a screen with rounded corners, which
/// they keep clear of. What lines up with the panels' edges (the history navigation buttons above them) takes it too.
public func chatInputPanelCompactBottomSideInset(bottomInset: CGFloat, deviceMetrics: DeviceMetrics) -> CGFloat {
    if bottomInset <= 32.0 && deviceMetrics.screenCornerRadius > 0.0 {
        return 18.0
    } else {
        return 0.0
    }
}

/// How far the chat's history navigation buttons and footer panels step in from the side with a small bottom inset.
/// On iPad they line up with the input panels, which never step in there (no rounded corners). On phones they keep
/// stepping in for any small bottom inset, as before, also on home-button iPhones, where the input panels do not.
public func chatBottomControlsCompactSideInset(bottomInset: CGFloat, deviceMetrics: DeviceMetrics) -> CGFloat {
    if case .tablet = deviceMetrics.type {
        return chatInputPanelCompactBottomSideInset(bottomInset: bottomInset, deviceMetrics: deviceMetrics)
    }
    if bottomInset <= 32.0 {
        return 18.0
    } else {
        return 0.0
    }
}

open class ChatInputPanelNode: ASDisplayNode {
    open var context: AccountContext?
    open var chatControllerInteraction: ChatControllerInteraction?
    open var interfaceInteraction: ChatPanelInterfaceInteraction?
    open var prevInputPanelNode: ChatInputPanelNode?
    
    open var viewForOverlayContent: ChatInputPanelViewForOverlayContent?
    
    open func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    public final func compactBottomSideInset(bottomInset: CGFloat, deviceMetrics: DeviceMetrics) -> CGFloat {
        return chatInputPanelCompactBottomSideInset(bottomInset: bottomInset, deviceMetrics: deviceMetrics)
    }
    
    open func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isMediaInputExpanded: Bool) -> CGFloat {
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
    
    /// Shows, moves or (nil) sinks the "next channel" island, which grows out of the panel's own glass. Returns false
    /// when this panel has no glass to grow it from: the history then shows its own control instead.
    open func updateOverscrollIsland(_ island: ChatInputPanelOverscrollIsland?, animated: Bool) -> Bool {
        return false
    }
    
    /// A chat switch is about to fade a snapshot of this panel (with the panel's bounds) out with the outgoing chat. A
    /// snapshot does not show the island's glass, so a showing island stays on the panel, which stays on screen until
    /// the next chat is ready, and the returned closure, called once the snapshot is on screen, moves it beside the
    /// snapshot to sink there. Nil without an island.
    open func overscrollIslandHandOver() -> ((UIView) -> Void)? {
        return nil
    }
}
