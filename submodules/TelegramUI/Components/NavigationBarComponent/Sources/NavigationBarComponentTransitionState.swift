import Foundation
import UIKit
import Display

/// A title drawn on a glass pill (the chat header), which a navigation transition treats as its bar's second right
/// platter (asked 2026-10-15): the pill morphs with the other bar's platter at that index, its contents swapping. When the
/// other bar has none there (Contacts: only its "+"), it materializes or dematerializes in place (asked 2026-10-18).
public struct NavigationBarTransitionTitlePill {
    /// The pill's frame, in the same coordinates as the row's.
    public var frame: CGRect
    /// What it shows: two bars' pills with different signatures swap their contents.
    public var signature: AnyHashable
    /// Its contents without the glass, at the pill's size: the live views, lent to the transition (the same view on
    /// every call while the bar's glass is detached) and taken back by the bar. Never a still copy, which freezes what
    /// animates (the chat title's emoji status) and is blank for a screen that is arriving.
    public var lendContent: () -> UIView

    public init(frame: CGRect, signature: AnyHashable, lendContent: @escaping () -> UIView) {
        self.frame = frame
        self.signature = signature
        self.lendContent = lendContent
    }
}

/// What a bar built on `NavigationBarComponent` hands a navigation transition's renderer: its row, column and
/// backdrop, in its content view's coordinates.
public struct NavigationBarComponentTransitionState {
    public var content: NavigationBarComponent.Content
    public var theme: NavigationBarTheme
    public var strings: NavigationBarStrings
    /// The row's frame in the content view.
    public var rowFrame: CGRect
    /// How much of the row is on screen: 0 while the bar hides it (an active search takes its place).
    public var rowAlpha: CGFloat
    public var leftInset: CGFloat
    public var rightInset: CGFloat
    public var trailingButtonsInset: CGFloat
    /// iPhone Duo: the side column's region in the content view; nil without one.
    public var sideColumnFrame: CGRect?
    public var hidesSideColumnButtons: Bool
    /// The backdrop: its height from the content view's top, its colour (nil: none), alpha and extension.
    public var backdropHeight: CGFloat
    public var backdropColor: UIColor?
    public var backdropAlpha: CGFloat
    public var backdropExtension: CGFloat
    /// The press UIKit was drawing on each capsule when the bar gave them to the transition (1: none): the button that
    /// started it is still releasing, and the transition's capsule goes on with that release.
    public var leadingPressScale: CGFloat
    /// UIKit's press glow on the leading capsule at that moment (0: none), carried on as the press is.
    public var leadingPressGlow: CGFloat
    /// The press and glow on each right platter (index from the edge; missing: none), likewise.
    public var trailingPressScales: [CGFloat]
    public var trailingPressGlows: [CGFloat]
    /// The edge effect's tint opacity (`EdgeEffectView.update(alpha:)`): 0.75 on the regular bar, 0.85 on the chat-list
    /// header.
    public var backdropTintAlpha: CGFloat
    /// The edge effect's gradient length at its bottom edge, at most (`edgeSize: min(length, height)`): 64 on the
    /// regular bar, 54 on the chat-list header.
    public var backdropEdgeLength: CGFloat
    /// Whether a backdrop only this bar shows stays on its own screen during a transition, riding it, instead of being
    /// drawn by the transition and faded next to the bar without one (the chat-list header's edge effect, kept at the
    /// user's request on 2026-10-15). The renderer answers with `updateKeepsOwnBackdrop(_:)`.
    public var keepsLoneBackdrop: Bool
    /// The title's glass pill when the bar has one and room for it (fewer than two right platters).
    public var titlePill: NavigationBarTransitionTitlePill?

    public init(content: NavigationBarComponent.Content, theme: NavigationBarTheme, strings: NavigationBarStrings, rowFrame: CGRect, rowAlpha: CGFloat, leftInset: CGFloat, rightInset: CGFloat, trailingButtonsInset: CGFloat, sideColumnFrame: CGRect?, hidesSideColumnButtons: Bool, backdropHeight: CGFloat, backdropColor: UIColor?, backdropAlpha: CGFloat, backdropExtension: CGFloat, leadingPressScale: CGFloat = 1.0, leadingPressGlow: CGFloat = 0.0, trailingPressScales: [CGFloat] = [], trailingPressGlows: [CGFloat] = [], backdropTintAlpha: CGFloat = 0.75, backdropEdgeLength: CGFloat = 64.0, keepsLoneBackdrop: Bool = false, titlePill: NavigationBarTransitionTitlePill? = nil) {
        self.titlePill = titlePill
        self.content = content
        self.theme = theme
        self.strings = strings
        self.rowFrame = rowFrame
        self.rowAlpha = rowAlpha
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.trailingButtonsInset = trailingButtonsInset
        self.sideColumnFrame = sideColumnFrame
        self.hidesSideColumnButtons = hidesSideColumnButtons
        self.backdropHeight = backdropHeight
        self.backdropColor = backdropColor
        self.backdropAlpha = backdropAlpha
        self.backdropExtension = backdropExtension
        self.leadingPressScale = leadingPressScale
        self.leadingPressGlow = leadingPressGlow
        self.trailingPressScales = trailingPressScales
        self.trailingPressGlows = trailingPressGlows
        self.backdropTintAlpha = backdropTintAlpha
        self.backdropEdgeLength = backdropEdgeLength
        self.keepsLoneBackdrop = keepsLoneBackdrop
    }
}

/// A navigation transition source whose bar is a `NavigationBarComponent` (the regular bar, the chat-list header).
public protocol NavigationBarComponentTransitionSource: NavigationBarTransitionSource {
    var componentTransitionState: NavigationBarComponentTransitionState? { get }
    /// True while the transition leaves this bar's backdrop to it (`keepsLoneBackdrop`): the bar shows it in its role,
    /// on its own screen, and the renderer draws none of it. False while the renderer draws it. A bar put back forgets it.
    func updateKeepsOwnBackdrop(_ keepsOwnBackdrop: Bool)
}

extension NavigationBarComponentTransitionSource {
    public func updateKeepsOwnBackdrop(_ keepsOwnBackdrop: Bool) {
    }
}
