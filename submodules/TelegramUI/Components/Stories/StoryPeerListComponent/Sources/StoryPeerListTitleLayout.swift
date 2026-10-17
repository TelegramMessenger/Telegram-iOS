import CoreGraphics

/// Where the collapsed header's content stands (the stories' avatars or the activity spinner, then the title with its
/// lock and status): centred, kept inside the band between the buttons. A header too narrow for all of it (a narrow
/// phone, a long title in some languages) goes without the title's text and keeps the rest.
enum StoryPeerListTitleLayout {
    /// Kept between the content and either side of the band.
    static let leadingMargin: CGFloat = 4.0
    static let trailingMargin: CGFloat = 4.0

    /// The content's left edge.
    static func contentOrigin(containerWidth: CGFloat, contentWidth: CGFloat, maxX: CGFloat) -> CGFloat {
        return min((containerWidth - contentWidth) * 0.5, maxX - contentWidth - StoryPeerListTitleLayout.trailingMargin)
    }

    /// Whether the title's text fits, given the content's width with it.
    static func showsTitleText(containerWidth: CGFloat, contentWidth: CGFloat, minX: CGFloat, maxX: CGFloat) -> Bool {
        return StoryPeerListTitleLayout.contentOrigin(containerWidth: containerWidth, contentWidth: contentWidth, maxX: maxX) >= minX + StoryPeerListTitleLayout.leadingMargin
    }
}
