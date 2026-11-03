#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// THE ONE WAY THIS EDITOR'S SELECTION RECTS DIVERGE FROM A STOCK TEXT VIEW'S, written down once.
///
/// A stock text view hugs the text column: its wash stops at the container's `lineFragmentPadding`,
/// 5pt in from each edge. This editor fills the LINE — a line covered to its end reaches the
/// container's trailing edge, a line covered from its beginning reaches its leading edge — because
/// that is what the shipping composer does (`BlockLayout.selectionFillRects` extends to `0` and
/// `container.size.width`), and leaving a 5pt strip of a covered line bare is the raggedness the
/// block-selection work exists to remove.
///
/// These contracts therefore keep comparing against STOCK, through this transform, rather than
/// against recorded numbers of our own. That is deliberate: a test that asserts our own output
/// cannot tell us we broke something. Anything that differs from stock by more than the sides named
/// here still fails, which is the whole point — the transform moves a side to the container's edge
/// or leaves it on stock's glyph, and has no third answer.
///
/// The sides are LOGICAL, and the caller states them about ITS OWN case: `coveredFromLineStart` is
/// "the selection reaches the beginning of this line", `coveredToLineEnd` is "it reaches the end".
/// `writingDirection` maps those onto physical edges — an RTL line covered to its end fills the
/// LEFT edge, which is the same rule as an LTR line filling the right. Passing NO/NO is exact stock
/// parity.
///
/// `containerBounds` is the line's own container in the rect's coordinate space, so a caller must
/// pass the container it measured the stock rect against, not a canvas or a view.
///
/// `writingDirection` is the LINE's base direction — the script its text is written in — and NOT
/// whatever the rect under test reports in its own `writingDirection` property. Those two differ:
/// measured on `["abc", "\u05d0\u05d1\u05d2"]`, the Hebrew block's rect reports
/// `NSWritingDirectionLeftToRight` while its line lays out right-to-left and fills the RIGHT edge
/// when covered from its beginning. Reading the direction off the rect would also make the
/// assertion circular — the rect would be judged against a fact it supplied.
///
/// `writingDirection` is the LINE's base direction — the script its text is written in — and NOT
/// whatever the rect under test reports in its own `writingDirection` property. Those two differ:
/// measured on `["abc", "\u05d0\u05d1\u05d2"]`, the Hebrew block's rect reports
/// `NSWritingDirectionLeftToRight` while its line lays out right-to-left and fills the RIGHT edge
/// when covered from its beginning. Reading the direction off the rect would also make the
/// assertion circular — the rect would be judged against a fact it supplied.
CGRect IDSelectionRectExpectedFromStock(CGRect stockRect,
                                        CGRect containerBounds,
                                        NSWritingDirection writingDirection,
                                        BOOL coveredFromLineStart,
                                        BOOL coveredToLineEnd);

NS_ASSUME_NONNULL_END
