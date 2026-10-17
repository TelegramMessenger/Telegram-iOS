import CoreGraphics

/// Where the chat list header's title content stands (the stories' avatars or the activity spinner, then the title with
/// its lock and status) between the bar's buttons: centred in the row while it is clear of both sides, balanced between
/// them (as far from either) when it is not, and on a smooth curve between the two. A header too narrow for all of it
/// (a narrow phone, a long title in some languages) goes without the title's text and keeps the rest.
enum StoryPeerListTitleLayout {
    /// Kept between the content and either side of the band.
    static let leadingMargin: CGFloat = 4.0
    static let trailingMargin: CGFloat = 4.0
    /// How close centred content may come to a side before it starts moving toward the middle of the band; it gets
    /// there when it would touch that side.
    static let balanceRamp: CGFloat = 20.0

    /// The content's left edge in a row of `containerWidth`, the band between the buttons running from `minX` to `maxX`.
    static func contentOrigin(containerWidth: CGFloat, contentWidth: CGFloat, minX: CGFloat, maxX: CGFloat) -> CGFloat {
        let lowerBound = minX + StoryPeerListTitleLayout.leadingMargin
        let upperBound = maxX - StoryPeerListTitleLayout.trailingMargin
        let centred = (containerWidth - contentWidth) * 0.5
        let balanced = (lowerBound + upperBound - contentWidth) * 0.5
        let closestGap = min(centred - lowerBound, upperBound - (centred + contentWidth))
        let x = max(0.0, min(1.0, 1.0 - closestGap / StoryPeerListTitleLayout.balanceRamp))
        let fraction = x * x * (3.0 - 2.0 * x)
        return centred + (balanced - centred) * fraction
    }

    /// Whether the title's text fits, given the content's width with it.
    static func showsTitleText(contentWidth: CGFloat, minX: CGFloat, maxX: CGFloat) -> Bool {
        return contentWidth <= maxX - StoryPeerListTitleLayout.trailingMargin - (minX + StoryPeerListTitleLayout.leadingMargin)
    }
}
