import Foundation
import UIKit
import TelegramCore

/// What surrounds a V2 page, for the pieces that a rounded container would otherwise round for it. A page in a bubble
/// leaves full-width media, code bands and quotes to the bubble's clip; a chat message without a bubble has nothing
/// around it, so it rounds its media, pads and rounds its code bands, rounds its quotes as every block in a message, and
/// keeps media blocks that would stack flush apart.
public struct InstantPageV2ContainerStyle: Equatable {
    /// The least corner radius any media block gets.
    public var minimumMediaCornerRadius: CGFloat
    /// The least room a code band that bleeds into no container keeps around its text.
    public var codeBlockMinimumPadding: CGFloat
    /// The radius such a band is rounded with.
    public var codeBlockCornerRadius: CGFloat
    /// The radius of a block quote's or pull quote's fill.
    public var quoteCornerRadius: CGFloat
    /// The gap between media blocks that would otherwise stack 1pt apart.
    public var separateMediaSpacing: CGFloat
    
    public init(minimumMediaCornerRadius: CGFloat, codeBlockMinimumPadding: CGFloat, codeBlockCornerRadius: CGFloat, quoteCornerRadius: CGFloat, separateMediaSpacing: CGFloat) {
        self.minimumMediaCornerRadius = minimumMediaCornerRadius
        self.codeBlockMinimumPadding = codeBlockMinimumPadding
        self.codeBlockCornerRadius = codeBlockCornerRadius
        self.quoteCornerRadius = quoteCornerRadius
        self.separateMediaSpacing = separateMediaSpacing
    }
    
    /// Inside a rounded container: the page's own constants, as every V2 surface had them.
    public static let bubble = InstantPageV2ContainerStyle(minimumMediaCornerRadius: 0.0, codeBlockMinimumPadding: 0.0, codeBlockCornerRadius: 0.0, quoteCornerRadius: 6.0, separateMediaSpacing: 0.0)
    
    /// A chat message without a bubble: media round at least as the message's media do, code bands and quotes at the
    /// radius every block in the message has.
    public static func bubbleless(mainRadius: CGFloat, blockCornerRadius: CGFloat, codeBlockMinimumPadding: CGFloat, separateMediaSpacing: CGFloat) -> InstantPageV2ContainerStyle {
        return InstantPageV2ContainerStyle(minimumMediaCornerRadius: mainRadius, codeBlockMinimumPadding: codeBlockMinimumPadding, codeBlockCornerRadius: blockCornerRadius, quoteCornerRadius: blockCornerRadius, separateMediaSpacing: separateMediaSpacing)
    }
    
    /// Whether full-width media bleed past the trailing edge so that a container's rounded clip leaves no sliver: only
    /// when something clips them.
    public var mediaBleeds: Bool {
        return self.minimumMediaCornerRadius <= 0.0
    }
}

/// A media block's corner radius: at least the style's.
func instantPageV2MediaCornerRadius(_ effectiveCornerRadius: CGFloat, style: InstantPageV2ContainerStyle) -> CGFloat {
    return max(effectiveCornerRadius, style.minimumMediaCornerRadius)
}

/// The corners of a collage cell that lie on the collage's outline, which are the ones rounded when nothing clips the
/// collage; the corners between its cells stay square.
func instantPageV2CollageCellRoundedCorners(top: Bool, bottom: Bool, left: Bool, right: Bool) -> CACornerMask {
    var corners: CACornerMask = []
    if top && left {
        corners.insert(.layerMinXMinYCorner)
    }
    if top && right {
        corners.insert(.layerMaxXMinYCorner)
    }
    if bottom && left {
        corners.insert(.layerMinXMaxYCorner)
    }
    if bottom && right {
        corners.insert(.layerMaxXMaxYCorner)
    }
    return corners
}

/// The gap between two blocks: media that stack flush inside a container, which clips them as one, are each rounded on
/// their own without one, and keep apart as separate blocks do.
func instantPageV2BlockGap(_ spacing: CGFloat, upper: InstantPageBlock?, lower: InstantPageBlock, style: InstantPageV2ContainerStyle) -> CGFloat {
    guard style.minimumMediaCornerRadius > 0.0, let upper, instantPageBlocksStackAsMedia(upper: upper, lower: lower) else {
        return spacing
    }
    return max(spacing, style.separateMediaSpacing)
}

/// How much further than the paragraph inset a code band's text sits from each of its sides. A band that bleeds into no
/// container and has no paragraph inset to give its text would hold the code against its own edge, so it pads the text
/// itself; inside a container it needs nothing.
func instantPageV2CodeBandStandalonePadding(bleed: InstantPageV2ChildBleed, horizontalInset: CGFloat, bandMinX: CGFloat, style: InstantPageV2ContainerStyle) -> CGFloat {
    guard bleed == .none else {
        return 0.0
    }
    return max(0.0, style.codeBlockMinimumPadding - (horizontalInset - bandMinX))
}
