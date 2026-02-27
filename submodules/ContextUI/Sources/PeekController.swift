import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

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

public final class PeekControllerTheme {
    public let isDark: Bool
    public let menuBackgroundColor: UIColor
    public let menuItemHighligtedColor: UIColor
    public let menuItemSeparatorColor: UIColor
    public let accentColor: UIColor
    public let destructiveColor: UIColor
    
    public init(isDark: Bool, menuBackgroundColor: UIColor, menuItemHighligtedColor: UIColor, menuItemSeparatorColor: UIColor, accentColor: UIColor, destructiveColor: UIColor) {
        self.isDark = isDark
        self.menuBackgroundColor = menuBackgroundColor
        self.menuItemHighligtedColor = menuItemHighligtedColor
        self.menuItemSeparatorColor = menuItemSeparatorColor
        self.accentColor = accentColor
        self.destructiveColor = destructiveColor
    }
}

extension PeekControllerTheme {
    convenience public init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(isDark: actionSheet.backgroundType == .dark, menuBackgroundColor: actionSheet.opaqueItemBackgroundColor, menuItemHighligtedColor: actionSheet.opaqueItemHighlightedBackgroundColor, menuItemSeparatorColor: actionSheet.opaqueItemSeparatorColor, accentColor: actionSheet.controlAccentColor, destructiveColor: actionSheet.destructiveActionTextColor)
    }
}

public protocol PeekController: ViewController, ContextControllerProtocol {
    var visibilityUpdated: ((Bool) -> Void)? { get set }
    var getOverlayViews: (() -> [UIView])? { get set }
    var appeared: (() -> Void)? { get set }
    var disappeared: (() -> Void)? { get set }
    var sourceView: () -> (UIView, CGRect)? { get set }
    var contentNode: PeekControllerContentNode & ASDisplayNode { get }
}

public var makePeekControllerImpl: ((
    _ presentationData: PresentationData,
    _ content: PeekControllerContent,
    _ sourceView: @escaping () -> (UIView, CGRect)?,
    _ activateImmediately: Bool
) -> PeekController)?

public func makePeekController(
    presentationData: PresentationData,
    content: PeekControllerContent,
    sourceView: @escaping () -> (UIView, CGRect)?,
    activateImmediately: Bool = false
) -> PeekController {
    return makePeekControllerImpl!(
        presentationData,
        content,
        sourceView,
        activateImmediately
    )
}
