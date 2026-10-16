import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private var backArrowImageCache: [Int32: UIImage] = [:]

public final class NavigationBarTheme {
    public static func generateBackArrowImage(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 13.0, height: 22.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)
            
            context.translateBy(x: 0.0, y: -UIScreenPixel)
            
            let _ = try? drawSvgPath(context, path: "M3.60751322,11.5 L11.5468531,3.56066017 C12.1326395,2.97487373 12.1326395,2.02512627 11.5468531,1.43933983 C10.9610666,0.853553391 10.0113191,0.853553391 9.42553271,1.43933983 L0.449102936,10.4157696 C-0.149700979,11.0145735 -0.149700979,11.9854265 0.449102936,12.5842304 L9.42553271,21.5606602 C10.0113191,22.1464466 10.9610666,22.1464466 11.5468531,21.5606602 C12.1326395,20.9748737 12.1326395,20.0251263 11.5468531,19.4393398 L3.60751322,11.5 Z ")
        })
    }
    
    public let overallDarkAppearance: Bool
    public let buttonColor: UIColor
    public let disabledButtonColor: UIColor
    public let primaryTextColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeTextColor: UIColor
    public let edgeEffectColor: UIColor?
    public let accentButtonColor: UIColor
    public let accentDisabledButtonColor: UIColor
    public let accentForegroundColor: UIColor
    public let glassStyle: NavigationBar.GlassStyle
    /// The glass of capsules whose buttons ask for no tint of their own, when it is not the panel glass: the profile's
    /// buttons over a cover colour or its expanded avatar. Nil: the panel glass (or clear, by `glassStyle`).
    public let glassTintColor: UIColor?
    
    public init(overallDarkAppearance: Bool, buttonColor: UIColor, disabledButtonColor: UIColor, primaryTextColor: UIColor, badgeBackgroundColor: UIColor, badgeTextColor: UIColor, edgeEffectColor: UIColor? = nil, accentButtonColor: UIColor, accentDisabledButtonColor: UIColor, accentForegroundColor: UIColor, glassStyle: NavigationBar.GlassStyle = .default, glassTintColor: UIColor? = nil) {
        self.overallDarkAppearance = overallDarkAppearance
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
        self.primaryTextColor = primaryTextColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeTextColor = badgeTextColor
        self.edgeEffectColor = edgeEffectColor
        self.accentButtonColor = accentButtonColor
        self.accentDisabledButtonColor = accentDisabledButtonColor
        self.accentForegroundColor = accentForegroundColor
        self.glassStyle = glassStyle
        self.glassTintColor = glassTintColor
    }
}

public final class NavigationBarStrings {
    public let back: String
    public let close: String
    /// The iPhone Duo side column's "…" overflow button.
    public let more: String

    public init(back: String, close: String, more: String) {
        self.back = back
        self.close = close
        self.more = more
    }
}

public final class NavigationBarPresentationData {
    public let theme: NavigationBarTheme
    public let strings: NavigationBarStrings
    
    public init(theme: NavigationBarTheme, strings: NavigationBarStrings) {
        self.theme = theme
        self.strings = strings
    }
}

public enum NavigationPreviousAction: Equatable {
    case item(UINavigationItem)
    case close
    
    public static func ==(lhs: NavigationPreviousAction, rhs: NavigationPreviousAction) -> Bool {
        switch lhs {
        case let .item(lhsItem):
            if case let .item(rhsItem) = rhs, lhsItem === rhsItem {
                return true
            } else {
                return false
            }
        case .close:
            if case .close = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public func navigationBarBackArrowImage(color: UIColor) -> UIImage? {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    let key = (Int32(alpha * 255.0) << 24) | (Int32(red * 255.0) << 16) | (Int32(green * 255.0) << 8) | Int32(blue * 255.0)
    if let image = backArrowImageCache[key] {
        return image
    } else {
        if let image = NavigationBarTheme.generateBackArrowImage(color: color) {
            backArrowImageCache[key] = image
            return image
        } else {
            return nil
        }
    }
}

public protocol NavigationButtonCustomDisplayNode {
    var isHighlightable: Bool { get }
}


public enum NavigationBarGlassStyle {
    case `default`
    case clear
}

/// iPhone Duo: where the bar may lay out its side column. `ViewController` sets it before `updateLayout` while the
/// screen places its navigation in the side strip (`placesNavigationButtonInSideColumn`) and shows its bar; nil
/// keeps every button in the bar's row.
public struct NavigationBarSideColumnPlacement {
    /// The controller's layout; the bar sits at its origin.
    public var layout: ContainerViewLayout
    /// The vertical tab bar's frame (a tab's root screen), which the column stays clear of.
    public var reservedBelow: CGRect?

    public init(layout: ContainerViewLayout, reservedBelow: CGRect?) {
        self.layout = layout
        self.reservedBelow = reservedBelow
    }
}

/// iPhone Duo: where a bar's side column is, for the screen's own layout: the strip it is in, and the frame its shapes
/// span (back circle to the last shape) in the bar's coordinates, which are the screen's (the bar sits at its origin).
public struct NavigationBarSideColumnExtent: Equatable {
    public var edge: ContainerViewLayoutSideEdge
    public var frame: CGRect

    public init(edge: ContainerViewLayoutSideEdge, frame: CGRect) {
        self.edge = edge
        self.frame = frame
    }
}

public protocol NavigationBar: ASDisplayNode, NavigationBarTransitionSource {
    typealias GlassStyle = NavigationBarGlassStyle
    
    var backPressed: () -> Void { get set }
    
    var userInfo: Any? { get set }
    
    var customOverBackgroundContentView: UIView { get }
    var contentNode: NavigationBarContentNode? { get }
    var secondaryContentNode: ASDisplayNode? { get }
    
    var item: UINavigationItem? { get set }
    
    var enableAutomaticBackButton: Bool { get set }
    /// Hides the back or close button without forgetting the previous item (unlike `enableAutomaticBackButton`).
    var hidesBackButton: Bool { get set }
    var previousItem: NavigationPreviousAction? { get set }
    
    /// iPhone Duo: where the bar may lay out its side column; see `NavigationBarSideColumnPlacement`.
    var sideColumnPlacement: NavigationBarSideColumnPlacement? { get set }
    /// iPhone Duo: whether the bar shows its back or close button in its side column.
    var isBackInSideColumn: Bool { get }
    /// iPhone Duo: the side column the bar lays out for `placement` with its current items, computed without laying it
    /// out (a screen that keeps its content clear of the column asks before its own layout); nil without a column.
    func sideColumnExtent(placement: NavigationBarSideColumnPlacement) -> NavigationBarSideColumnExtent?
    /// Called when a change of the bar's items moved its side column outside a layout pass: the screen lays out again.
    var sideColumnExtentUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    /// A long press on the back button (the chat's navigation stack); nil leaves it a plain button.
    var backButtonContextAction: ((UIView, ContextGesture) -> Void)? { get set }
    /// Fades the back button and the right buttons in (a chat appearing from a preview).
    func animateButtonsIn(duration: Double)
    /// iPhone Duo: how much further than the right inset the bar's trailing buttons stay from the right edge, to
    /// clear the status island beside the bar (`ContainerViewLayout.navigationBarTrailingButtonsInset`). Set before
    /// `updateLayout`; the title keeps its band.
    var trailingButtonsInset: CGFloat { get set }
    
    var additionalContentNode: SparseNode { get }
    
    var secondaryContentHeight: CGFloat { get set }
    
    /// Whether the bar's backdrop (its edge effect) is fully shown.
    var isBackdropVisible: Bool { get }
    /// Fades the bar's backdrop, for a screen whose content shows through the bar until it scrolls under it.
    func setBackdropAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition)
    func updatePresentationData(_ presentationData: NavigationBarPresentationData, transition: ContainedViewLayoutTransition)
    
    var intrinsicCanTransitionInline: Bool { get set }
    
    var passthroughTouches: Bool { get set }
    
    var canTransitionInline: Bool { get }
    
    func contentHeight(defaultHeight: CGFloat) -> CGFloat
    func setContentNode(_ contentNode: NavigationBarContentNode?, animated: Bool)
    func setSecondaryContentNode(_ secondaryContentNode: ASDisplayNode?, animated: Bool)
    func executeBack() -> Bool
    func setHidden(_ hidden: Bool, animated: Bool)
    /// The screen puts something of its own in the row's place (the profile's search, a pane's own navigation
    /// content): the row and the iPhone Duo column hide, apart from `setHidden`, which the controller re-applies on
    /// every layout. A hidden row hands a navigation transition no capsules.
    func setRowHiddenByScreen(_ hidden: Bool, transition: ContainedViewLayoutTransition)
    /// The view of a right bar button item the screen set, nil if the bar shows none for it.
    func rightButtonView(for item: UIBarButtonItem) -> UIView?
    
    var requestContainerLayout: ((ContainedViewLayoutTransition) -> Void)? { get set }
    
    func updateLayout(size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, transition: ContainedViewLayoutTransition)
    
    func updateEdgeEffectExtension(value: CGFloat, transition: ContainedViewLayoutTransition)
    
    func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer?
}

public var defaultNavigationBarImpl: ((NavigationBarPresentationData) -> NavigationBar)?
