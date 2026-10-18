import CoreGraphics

/// The spacing between the avatars of the chat list header's expanded stories row when they do not all fit. The row
/// scrolls, and the avatar its edge cuts is what says so. When only a sliver of that avatar's ring shows (iPhone Duo
/// folded: five avatars fit exactly and the sixth's ring shows at the edge), the sliver reads as a glitch, so the
/// spacing grows until the avatar before it is cut at its centre. Any other row keeps the designed spacing.
enum StoryPeerListRowLayout {
    /// How far an avatar's story ring reaches past its item (`StoryPeerListItemComponent`: radius 30.66 in a 60 pt
    /// item), which is where it starts to show at the edge.
    static let ringOutset: CGFloat = 0.66
    /// A peek narrower than this is a sliver.
    static let maximumSliverWidth: CGFloat = 4.0

    /// The spacing for a row whose content, at `baseSpacing`, is wider than `containerWidth`; the first avatar is
    /// `leadingInset` in.
    static func itemSpacing(containerWidth: CGFloat, leadingInset: CGFloat, itemWidth: CGFloat, baseSpacing: CGFloat, itemCount: Int) -> CGFloat {
        let pitch = itemWidth + baseSpacing
        // The first avatar the edge cuts, and how much of its ring shows (negative when the edge falls in the gap).
        var cutIndex = 0
        while leadingInset + CGFloat(cutIndex) * pitch + itemWidth <= containerWidth {
            cutIndex += 1
        }
        if cutIndex < 2 || cutIndex >= itemCount {
            return baseSpacing
        }
        let visibleItemWidth = containerWidth - (leadingInset + CGFloat(cutIndex) * pitch)
        let peekWidth = visibleItemWidth + StoryPeerListRowLayout.ringOutset
        if peekWidth <= 0.0 || peekWidth >= StoryPeerListRowLayout.maximumSliverWidth {
            return baseSpacing
        }
        // The avatar before it, whole until now, becomes the cut one.
        let previousVisibleWidth = visibleItemWidth + pitch
        return baseSpacing + floor((previousVisibleWidth - itemWidth * 0.5) / CGFloat(cutIndex - 1))
    }
}
