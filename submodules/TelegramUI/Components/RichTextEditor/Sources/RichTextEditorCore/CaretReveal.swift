import CoreGraphics

/// Everything the reveal decision needs, in the scroll view's own content coordinates. Vertical
/// only: horizontal reveal belongs to a table cell's own run scroll view, which this never touches
/// (the engine editor scrolls that run in `RichTextEngineEditorView+RunCaretReveal.swift`).
///
/// `firstLineTop` / `lastLineBottom` are the document's two ends — the top and bottom of the caret
/// rects at the beginning and end of the document. They are optional because a caller that cannot
/// answer them must still get the ordinary minimum scroll rather than a guess: the legacy canvas has
/// no cheap answer for either and has always revealed against a ±12pt band instead.
public struct RichTextCaretRevealInput {
    public var caret: CGRect
    public var firstLineTop: CGFloat?
    public var lastLineBottom: CGFloat?
    public var contentHeight: CGFloat
    public var viewportHeight: CGFloat
    public var topInset: CGFloat
    public var bottomInset: CGFloat
    public var offsetY: CGFloat

    public init(caret: CGRect, firstLineTop: CGFloat?, lastLineBottom: CGFloat?,
                contentHeight: CGFloat, viewportHeight: CGFloat,
                topInset: CGFloat, bottomInset: CGFloat, offsetY: CGFloat) {
        self.caret = caret
        self.firstLineTop = firstLineTop
        self.lastLineBottom = lastLineBottom
        self.contentHeight = contentHeight
        self.viewportHeight = viewportHeight
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.offsetY = offsetY
    }
}

/// The arithmetic behind "put the caret where it can be seen", with no view in it.
///
/// It exists as a solver rather than as a method on either editor because both editors need the same
/// answer from different geometry, and because a rule stated in numbers can be tested in numbers.
/// Everything about WHEN to ask belongs to the host; this only answers WHERE.
public enum RichTextCaretRevealSolver {
    /// The offset that reveals the caret, or nil when the caret is already where it should be.
    ///
    /// Two rules beyond the obvious one. **A line's own margin is part of it**: a caret on the first
    /// line brings the document's top margin with it, or the first line sits hard against the
    /// navigation bar with nothing before it and reads as "there is more up there" when there is
    /// not; the same at the other end. And the result is **clamped to the scrollable range**, so a
    /// caller can write it without a second thought.
    public static func offsetY(for input: RichTextCaretRevealInput) -> CGFloat? {
        var top = input.caret.minY
        var bottom = input.caret.maxY
        if let firstLineTop = input.firstLineTop, top <= firstLineTop + 0.5 {
            top = 0.0
        }
        if let lastLineBottom = input.lastLineBottom, bottom >= lastLineBottom - 0.5 {
            bottom = input.contentHeight
        }
        guard bottom > top else { return nil }

        let visibleTop = input.offsetY + input.topInset
        let visibleBottom = input.offsetY + input.viewportHeight - input.bottomInset
        // A rect taller than the visible area can never be wholly shown, and aligning one edge
        // pushes the other out, so the next call would align the other: every reveal flipped the
        // offset. Once the visible area lies inside the rect there is nothing better to do.
        if bottom - top > visibleBottom - visibleTop, visibleTop >= top - 0.5, visibleBottom <= bottom + 0.5 {
            return nil
        }
        let target: CGFloat
        if top < visibleTop {
            target = top - input.topInset
        } else if bottom > visibleBottom {
            target = bottom - input.viewportHeight + input.bottomInset
        } else {
            return nil
        }

        let minimum = -input.topInset
        let maximum = max(minimum, input.contentHeight - input.viewportHeight + input.bottomInset)
        let clamped = min(max(target, minimum), maximum)
        return abs(clamped - input.offsetY) < 0.5 ? nil : clamped
    }
}
