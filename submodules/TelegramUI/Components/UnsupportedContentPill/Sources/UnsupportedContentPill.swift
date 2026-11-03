import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

// Geometry, ported literal-for-literal from ChatMessageUnsupportedBubbleContentNode. The chat
// bubble must stay pixel-identical, so these are not tunables.
let pillContentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 8.0, right: 12.0)
let pillMaximumCornerRadius: CGFloat = 22.0

let pillBadgeDiameter: CGFloat = 44.0
let pillBadgeTextSpacing: CGFloat = 12.0

// The badge is two 44x44 template assets drawn at the same frame: the bubble silhouette and the
// plane positioned to sit inside it. They must not be inset relative to each other.
let pillBadgeBackgroundAlpha: (dark: CGFloat, light: CGFloat) = (0.2, 0.15)

let pillTitleSubtitleSpacing: CGFloat = 0.0

let pillTextButtonSpacing: CGFloat = 12.0
let pillButtonHorizontalPadding: CGFloat = 11.0
let pillButtonVerticalPadding: CGFloat = 8.0

let pillSubtitleAlpha: CGFloat = 0.6

/// The pill's copy, already resolved to strings.
///
/// Resolved rather than a `PresentationStrings` so the component has no opinion about where its
/// words come from, and so its tests need no app bundle.
public struct UnsupportedContentPillStrings: Equatable {
    public let title: String
    public let text: String
    public let action: String

    public init(title: String, text: String, action: String) {
        self.title = title
        self.text = text
        self.action = action
    }

    public init(strings: PresentationStrings) {
        self.init(
            title: strings.Conversation_UnsupportedMedia_Title,
            text: strings.Conversation_UnsupportedMedia_Text,
            action: strings.Conversation_UnsupportedMedia_Action
        )
    }
}

/// `fill` is used ONLY when the host supplies no wallpaper node; with one, the wallpaper shows
/// through instead. `isDark` drives the badge's background alpha and the button's fill polarity.
public struct UnsupportedContentPillColors: Equatable {
    public let fill: UIColor
    public let primaryText: UIColor
    public let isDark: Bool

    public init(fill: UIColor, primaryText: UIColor, isDark: Bool) {
        self.fill = fill
        self.primaryText = primaryText
        self.isDark = isDark
    }
}

/// Pure geometry — deliberately no `TextNodeLayout`s and no apply closures.
///
/// `TextNode.asyncLayout(nil)`'s apply creates a NEW node per call, and the chat bubble re-lays out
/// on every apply, so carrying applies here would rebuild three text nodes and swap three subviews
/// per list update. Instead the view owns its nodes and re-derives them through the same measure
/// function; `constrainedWidth` is carried so it can reproduce the host's measure pass exactly.
public struct UnsupportedContentPillLayout: Equatable {
    /// Intrinsic size at `constrainedWidth`. The host may render the pill WIDER than this (the chat
    /// bubble stretches it to the bubble's bounding width); it must never render it narrower.
    public let size: CGSize
    public let constrainedWidth: CGFloat

    let titleSize: CGSize
    let subtitleSize: CGSize
    /// The button's outer size — the label plus its padding.
    let buttonSize: CGSize
    /// The button LABEL's size. Carried here, like every other measured size, because a `TextNode`
    /// returned by `apply()` has zero bounds until its frame is assigned: positioning the label
    /// from its own `bounds` collapses it to nothing, and the button renders correctly sized and
    /// tappable with no visible text.
    let buttonTitleSize: CGSize
    let textColumnSize: CGSize
}

public extension UnsupportedContentPillLayout {
    /// The action button's frame inside a pill rendered at `size`, in pill-local coordinates.
    ///
    /// The single source of truth for where the button lands: the view positions its button here,
    /// and a host that arbitrates taps itself derives the same rect from the LAYOUT alone — the
    /// InstantPage V2 renderer has no pill view to ask while a chat bubble's `tapActionAtPoint` is
    /// resolving a touch, only the laid-out item.
    ///
    /// `size` rather than `self.size` because a host may render the pill wider than its intrinsic
    /// width (the chat bubble stretches it to the bubble), and the button is pinned to the trailing
    /// edge.
    func actionFrame(in size: CGSize) -> CGRect {
        return CGRect(
            origin: CGPoint(
                x: size.width - pillContentInsets.right - self.buttonSize.width,
                y: floorToScreenPixels((size.height - self.buttonSize.height) / 2.0)
            ),
            size: self.buttonSize
        )
    }
}

/// The apply half of a measure pass. Each closure returns the `TextNode` carrying that piece of
/// text — the same node that was passed in, when one was.
struct UnsupportedContentPillTextApply {
    let title: () -> TextNode
    let subtitle: () -> TextNode
    let buttonTitle: () -> TextNode
}

/// The single measurement implementation. The static entry point below passes nil nodes (off-main,
/// geometry only); the view passes its own nodes and uses the applies. One function, so the two
/// paths cannot disagree about a size.
func measureUnsupportedContentPill(
    strings: UnsupportedContentPillStrings,
    colors: UnsupportedContentPillColors,
    constrainedWidth: CGFloat,
    titleNode: TextNode?,
    subtitleNode: TextNode?,
    buttonTitleNode: TextNode?
) -> (UnsupportedContentPillLayout, UnsupportedContentPillTextApply) {
    let makeTitleLayout = TextNode.asyncLayout(titleNode)
    let makeSubtitleLayout = TextNode.asyncLayout(subtitleNode)
    let makeButtonTitleLayout = TextNode.asyncLayout(buttonTitleNode)

    // The button is sized by its own label, so measure it first: whatever it takes is
    // subtracted from the width the title and subtitle get to wrap within.
    let buttonTitleString = NSAttributedString(
        string: strings.action,
        font: Font.semibold(15.0),
        textColor: colors.primaryText
    )
    let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(
        attributedString: buttonTitleString,
        backgroundColor: nil,
        maximumNumberOfLines: 1,
        truncationType: .end,
        constrainedSize: CGSize(width: max(1.0, constrainedWidth / 2.0), height: CGFloat.greatestFiniteMagnitude),
        alignment: .natural,
        cutout: nil,
        insets: UIEdgeInsets()
    ))
    let buttonSize = CGSize(
        width: buttonTitleLayout.size.width + pillButtonHorizontalPadding * 2.0,
        height: buttonTitleLayout.size.height + pillButtonVerticalPadding * 2.0
    )

    let fixedWidth = pillContentInsets.left + pillBadgeDiameter + pillBadgeTextSpacing + pillTextButtonSpacing + buttonSize.width + pillContentInsets.right
    let maximumTextWidth = max(1.0, constrainedWidth - fixedWidth)

    let titleString = NSAttributedString(
        string: strings.title,
        font: Font.semibold(15.0),
        textColor: colors.primaryText
    )
    let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(
        attributedString: titleString,
        backgroundColor: nil,
        maximumNumberOfLines: 1,
        truncationType: .end,
        constrainedSize: CGSize(width: maximumTextWidth, height: CGFloat.greatestFiniteMagnitude),
        alignment: .natural,
        cutout: nil,
        insets: UIEdgeInsets()
    ))

    let subtitleString = NSAttributedString(
        string: strings.text,
        font: Font.regular(13.0),
        textColor: colors.primaryText.withMultipliedAlpha(pillSubtitleAlpha)
    )
    let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(
        attributedString: subtitleString,
        backgroundColor: nil,
        maximumNumberOfLines: 0,
        truncationType: .end,
        constrainedSize: CGSize(width: maximumTextWidth, height: CGFloat.greatestFiniteMagnitude),
        alignment: .natural,
        cutout: nil,
        insets: UIEdgeInsets()
    ))

    let textColumnWidth = max(titleLayout.size.width, subtitleLayout.size.width)
    let textColumnHeight = titleLayout.size.height + pillTitleSubtitleSpacing + subtitleLayout.size.height

    let width = fixedWidth + textColumnWidth
    let height = pillContentInsets.top + max(pillBadgeDiameter, max(textColumnHeight, buttonSize.height)) + pillContentInsets.bottom

    let layout = UnsupportedContentPillLayout(
        size: CGSize(width: width, height: height),
        constrainedWidth: constrainedWidth,
        titleSize: titleLayout.size,
        subtitleSize: subtitleLayout.size,
        buttonSize: buttonSize,
        buttonTitleSize: buttonTitleLayout.size,
        textColumnSize: CGSize(width: textColumnWidth, height: textColumnHeight)
    )
    let apply = UnsupportedContentPillTextApply(title: titleApply, subtitle: subtitleApply, buttonTitle: buttonTitleApply)
    return (layout, apply)
}

public enum UnsupportedContentPill {
    /// Off-main safe: `TextNode.asyncLayout(nil)` is the codebase's standard measure-without-a-view
    /// path. Deterministic in its inputs.
    public static func layout(
        strings: UnsupportedContentPillStrings,
        colors: UnsupportedContentPillColors,
        constrainedWidth: CGFloat
    ) -> UnsupportedContentPillLayout {
        let (layout, _) = measureUnsupportedContentPill(
            strings: strings,
            colors: colors,
            constrainedWidth: constrainedWidth,
            titleNode: nil,
            subtitleNode: nil,
            buttonTitleNode: nil
        )
        return layout
    }
}
