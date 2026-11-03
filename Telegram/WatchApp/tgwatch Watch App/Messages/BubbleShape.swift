import CoreGraphics

/// Single source of truth for message-bubble geometry. Every bubble surface
/// (text, voice, audio, document, poll, photo, video, map) clips/fills to this
/// radius; fill-chrome bubbles also enforce the minimum so a one-word message
/// renders as a 28×28 pill (radius == half-size → circular ends).
enum BubbleShape {
    static let cornerRadius: CGFloat = 14
    /// Minimum bubble edge (min-width and min-height). Equals `2 × cornerRadius`
    /// so a one-word fill-chrome bubble renders as a circle/pill rather than a
    /// rounded-rect with concave-looking corners.
    static let minSize: CGFloat = 28
}
