import Foundation
import UIKit
import AsyncDisplayKit
import Display
import GlassBackgroundComponent

/// One label lent to an expansion: the live view, where its text's centre is in it and the text's size (for the common
/// width), where that centre is on screen, how its colour changes, views riding with it (the chat title's emoji status
/// and verified icons), framed in the label view's coordinates, and views following it in place.
public struct NavigationExpansionLabel {
    public enum Coloring {
        /// The view is rendered in this colour; a colour layer composited source-atop over it, in a group of its own,
        /// recolours its glyphs as the ink runs (the view stays in the window, so a node keeps its rendered contents).
        case recolor(UIColor)
        /// Its text is rendered white and tinted by these layers' multiply colour (the profile's labels), now this one.
        case multiply([CALayer], UIColor)
        case none
    }

    public let view: UIView
    public let textCenter: CGPoint
    public let textSize: CGSize
    public let screenCenter: CGPoint
    public let coloring: Coloring
    public let accessories: [(view: UIView, frame: CGRect)]
    /// Views laid out around the label at rest (the profile's level, badge, rating, username, balance): they stay
    /// in their own superviews (a mask's shapes too) and keep their own alpha, and move and scale as if they were part
    /// of the label.
    public let followers: [UIView]

    public init(view: UIView, textCenter: CGPoint, textSize: CGSize, screenCenter: CGPoint, coloring: Coloring, accessories: [(view: UIView, frame: CGRect)] = [], followers: [UIView] = []) {
        self.view = view
        self.textCenter = textCenter
        self.textSize = textSize
        self.screenCenter = screenCenter
        self.coloring = coloring
        self.accessories = accessories
        self.followers = followers
    }
}

/// What the lower screen lends (the chat): its pill's frame and glass, its avatar capsule, its labels, the press still
/// on them. Screen coordinates.
public final class NavigationExpansionSourceLoan {
    public let origin: CGRect
    public let originTint: GlassBackgroundView.TintColor
    public let isDark: Bool
    public let companion: CGRect?
    public let companionPhotoDiameter: CGFloat
    /// The companion's own content (the chat's avatar node), hidden while the destination's photo stands in for it.
    public let companionView: UIView?
    /// Title, then status (the status is the anchor the card's edge carries).
    public let labels: [NavigationExpansionLabel]
    public let press: ExpansionPress
    public let originContent: UIView?

    public init(origin: CGRect, originTint: GlassBackgroundView.TintColor, isDark: Bool, companion: CGRect?, companionPhotoDiameter: CGFloat, companionView: UIView?, labels: [NavigationExpansionLabel], press: ExpansionPress, originContent: UIView? = nil) {
        self.origin = origin
        self.originTint = originTint
        self.isDark = isDark
        self.companion = companion
        self.companionPhotoDiameter = companionPhotoDiameter
        self.companionView = companionView
        self.labels = labels
        self.press = press
        self.originContent = originContent
    }
}

public protocol NavigationExpansionSourceProviding: NavigationExpansionSource {
    /// What it takes from its bar: the bar morph leaves those out (known before anything is lent).
    var expansionBarExclusions: NavigationBarTransitionExclusions { get }
    /// Lends its views, in `screenView`'s coordinates; nil if it cannot (then nothing is drawn).
    func lendExpansionSource(in screenView: UIView) -> NavigationExpansionSourceLoan?
    /// Takes every lent view back to where it was.
    func returnExpansionSource()
}

/// What the upper screen lends (the profile). Screen coordinates, at rest.
public final class NavigationExpansionDestinationLoan {
    public let avatar: CGRect?
    public let photo: CGRect?
    /// The live view showing the avatar (or, on the photo path, the expanded photo), laid out at `avatarRestFrame`.
    public let avatarView: UIView?
    public let avatarRestFrame: CGRect
    /// Title, then status, in the same order as the source's.
    public let labels: [NavigationExpansionLabel]
    /// The labels' colours at rest: what the ink runs to.
    public let labelColors: [UIColor]
    public let carriedEdge: CGFloat
    /// The action buttons, in order, laid out at rest: each appears on its own; a page view holding them carries them
    /// with the page (`pageViews`).
    public let appearingViews: [UIView]
    /// Views that appear with each button, by its index: drawn elsewhere (the profile's platters are shapes in a blur's
    /// mask), so the button's own alpha and transform do not reach them.
    public let appearingCompanions: [[UIView]]
    /// Content that lies on the photo (the profile's header content on the photo path): lifted above the photo at its
    /// place on screen and cut by the card, as the upper screen is.
    public let overlayViews: [UIView]
    /// Fade with `background`, `list`, `pattern`.
    public let backgroundViews: [UIView]
    public let listViews: [UIView]
    public let patternViews: [UIView]
    /// The page below the header, which rides the status (`page`): they stay in their own superviews and keep their own
    /// transforms. A view holding the action buttons carries them, their platters and whatever draws those (the
    /// profile's blur and its mask, which clip at the blur's own frame); never a button, a platter or a label's follower
    /// itself, which have transforms of their own.
    public let pageViews: [UIView]
    /// Views clipping at a bottom edge that is the page's top (the profile's cover, whose bottom band is the music strip):
    /// the edge rides the page while what they show holds still, so the page never leaves a strip of the cover below it,
    /// until the page passes its resting place; past it what they show lands with the page, so its overshoot moves the
    /// background with everything on it. They stay in their own superviews and keep their own transforms and sublayer
    /// transforms.
    public let pageEdgeViews: [UIView]
    /// The rest of the background (the gifts around the profile's avatar): held still while the page comes in, landing
    /// with it past its resting place, as what the page edges show does. They stay in their own superviews and keep their
    /// own transforms.
    public let landingViews: [UIView]
    /// The colour the drops' glass tints toward (the profile's colour; nil: none, the plain profile).
    public let glassTint: UIColor?
    /// The screen's corner radii (`ContainerViewLayout.screenCornerRadii`), which differ on iPhone Duo's cover screen.
    public let screenCornerRadii: CornerRadii
    public let backButtonFrame: CGRect?
    public let backgroundOpening: ClosedRange<CGFloat>?
    public let backgroundClosing: ClosedRange<CGFloat>?
    public let flyingViews: [UIView]
    /// The avatar's corner radius over its side: 0.5 is round, a forum's rounded square is 0.25. The photo keeps it while
    /// it flies.
    public let avatarCornerFraction: CGFloat

    public init(avatar: CGRect?, photo: CGRect?, avatarView: UIView?, avatarRestFrame: CGRect, labels: [NavigationExpansionLabel], labelColors: [UIColor], carriedEdge: CGFloat, appearingViews: [UIView], appearingCompanions: [[UIView]] = [], overlayViews: [UIView] = [], backgroundViews: [UIView], listViews: [UIView], pageViews: [UIView] = [], pageEdgeViews: [UIView] = [], landingViews: [UIView] = [], patternViews: [UIView], glassTint: UIColor?, screenCornerRadii: CornerRadii, backButtonFrame: CGRect?, backgroundOpening: ClosedRange<CGFloat>? = nil, backgroundClosing: ClosedRange<CGFloat>? = nil, flyingViews: [UIView] = [], avatarCornerFraction: CGFloat = 0.5) {
        self.avatar = avatar
        self.photo = photo
        self.avatarView = avatarView
        self.avatarRestFrame = avatarRestFrame
        self.labels = labels
        self.labelColors = labelColors
        self.carriedEdge = carriedEdge
        self.appearingViews = appearingViews
        self.appearingCompanions = appearingCompanions
        self.overlayViews = overlayViews
        self.backgroundViews = backgroundViews
        self.listViews = listViews
        self.pageViews = pageViews
        self.pageEdgeViews = pageEdgeViews
        self.landingViews = landingViews
        self.patternViews = patternViews
        self.glassTint = glassTint
        self.screenCornerRadii = screenCornerRadii
        self.backButtonFrame = backButtonFrame
        self.backgroundOpening = backgroundOpening
        self.backgroundClosing = backgroundClosing
        self.flyingViews = flyingViews
        self.avatarCornerFraction = avatarCornerFraction
    }
}

public protocol NavigationExpansionDestinationProviding: NavigationExpansionDestination {
    /// Which way it arrives (the photo path when it opens on its expanded photo).
    var expansionPath: ExpansionPath { get }
    func lendExpansionDestination(in screenView: UIView) -> NavigationExpansionDestinationLoan?
    func returnExpansionDestination()
    var expansionOpenSpring: NavigationTransitionSpring? { get }
    var expansionCloseSpring: NavigationTransitionSpring? { get }
    func expansionDidLand()
}

public extension NavigationExpansionDestinationProviding {
    var expansionOpenSpring: NavigationTransitionSpring? {
        return nil
    }

    var expansionCloseSpring: NavigationTransitionSpring? {
        return nil
    }

    func expansionDidLand() {
    }
}
