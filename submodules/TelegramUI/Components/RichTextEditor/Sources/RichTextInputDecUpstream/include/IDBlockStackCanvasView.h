#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

#import "IDDocumentLayoutCoordinator.h"

@class IDBlockDocument;
@class IDBlockDocumentChange;
@class IDBlockLayout;

#import "IDBlockLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDBlockStackCanvasView : UIView <IDDocumentLayoutSnapshotSource>
/// Display-only decoration for every block's rendered text. See `IDBlockLayout.displayDecorator`.
@property(nonatomic, copy, nullable) IDBlockTextDisplayDecorator displayDecorator;

/// Forces the rendered text to be recomputed on the next pass even with no document change — the
/// selection-driven case a decorator exists for.
- (void)id_setDisplayDecorationNeedsUpdate;


/// The text container inset, applied INSIDE this view rather than by positioning it.
///
/// This view's origin therefore stays (0, 0) in its host, which is load-bearing: it is the host's
/// `-textInputView`, so UIKit interprets every `UITextInput` geometry answer relative to it. While
/// this view was POSITIONED at the inset instead, the host's geometry — expressed in the host's own
/// coordinates — was reinterpreted as if relative to here, and UIKit drew the caret and the selection
/// one inset down and to the right of the glyphs they belong to.
@property(nonatomic) UIEdgeInsets contentInsets;

/// Space reserved AROUND individual blocks, keyed by the engine's own block identity.
///
/// A host drawing a container across several blocks — a quote, a code band — needs interior padding
/// at the RUN's edges, and it cannot come from the text: TextKit ignores `paragraphSpacingBefore` on
/// the first paragraph of a container and trailing spacing does not extend the used height, so a
/// block laid out alone gets neither. The layout reserves it instead.
///
/// Keyed rather than positional because block identity is the only thing that survives an edit; an
/// index would silently move the padding onto a different block the moment one is inserted.
///
/// `left` and `right` narrow the block's text MEASURE as well as moving its canvas, so an inset
/// block wraps inside the space that is left and never reaches past the column. Stacked and placed
/// blocks answer this the same way; until 2026-09-11 only a placed one did, and a stacked block laid
/// out at the full column was then drawn one `left` in, hanging that far off its trailing edge.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *blockInsets;

/// The box a block's SELECTION fills where the selection covers it: the block's canvas plus the
/// space `blockInsets` reserves around it, in this view's coordinates. `CGRectNull` for an unknown
/// identifier — zero is a plausible rect, and a caller would park a wash at the origin.
///
/// Slots TILE. The stacking pass advances by top inset, canvas, bottom inset, so one block's slot
/// ends exactly where the next one's begins. A selection spanning several blocks can therefore be
/// drawn with no gaps without the wash knowing anything about the rhythm — which is the whole reason
/// this exists. A PLACED block's slot is its cell: the frame the host gave it, padding included,
/// carried by the run's horizontal offset like every other placed rect.
- (CGRect)selectionSlotForBlockIdentifier:(NSUUID *)identifier;

/// The BOX a block occupies — the frame of the thing the reader sees it as — keyed by the engine's
/// block identity, for the blocks that have one. A host passes the frame of the very view the wash
/// must line up with (a container's band, an atom's hosted view) VERBATIM, so the two are one
/// derivation and cannot drift; deriving an outset from that frame instead would be a second
/// derivation of the same number, which is how a collapsed quote's fold glyph came to be drawn in
/// two places at once.
///
/// Both halves are read, and they mean different things:
///
/// - HORIZONTALLY the box is where the selection reaches, always. A code band bleeds past the text
///   column, an image bleeds further, an inner quote's band starts one indent in.
/// - VERTICALLY the box divides a block's reserved space in two. The part INSIDE the box is the
///   block's own padding and is washed whenever the block's content is; the part outside it is the
///   rhythm SEPARATING this block from its neighbours, and that is washed only when the selection
///   actually reaches past it. Without the split, selecting a quote on its own hugged its text and
///   left its band bare top and bottom (device, 2026-09-15).
///
/// Read live, when a selection is measured, and deliberately NOT part of layout: a box moves
/// nothing, and a setter that invalidated layout would re-enter the host pass that writes it. An
/// absent entry means the block has no box of its own — its column is the text column and all of
/// its reserved space is rhythm.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *selectionBoxes;

/// The part of the block's slot that is the BLOCK rather than the space around it: its declared box
/// clipped to its slot, or `CGRectNull` when it has no box. See `selectionBoxes`.
- (CGRect)selectionBoxForBlockIdentifier:(NSUUID *)identifier;

/// Frames a host assigns to blocks it PLACES instead of stacking, keyed by the engine's block
/// identity. Consecutive placed blocks (document order) form a RUN anchored at the stacking cursor
/// where the run begins; a frame is relative to that anchor. A placed block lays out at its frame's
/// width, its canvas is at least its frame's height, and the cursor advances past the whole run at
/// once by the run's extent. `blockInsets` on a placed block apply INSIDE its frame (left, right,
/// top), except `bottom`, which extends the run's extent below the block. Read only by
/// `-updateForDocumentChange:width:`; the text view reconciles after setting it.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *blockFrames;

/// How far a placed RUN's clip may sit outside the text column, keyed by the run's FIRST block.
/// `left`/`right` only; a positive value widens the clip, a negative one narrows it, and an absent
/// entry means the column itself — which is what every run did before this existed.
///
/// A run scrolls horizontally inside its own clip, and where that clip ENDS is a host decision, not
/// a text-layout one: a run at the top level is cut at the canvas edge, so its content passes under
/// the text inset rather than stopping short of it, while a run inside a host-drawn container is cut
/// at that container's interior, which is narrower than the column. The run's position never moves —
/// only where its content stops being visible — because the outset widens the scroll view and shifts
/// its content view by the same amount.
///
/// The clip decides only what is VISIBLE. How far the run may scroll is its COLUMN's business —
/// `placedRunColumnOutsets` — so a host may show a run's content through a margin it does not let
/// the run rest in.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *placedRunClipOutsets;

/// Where a placed RUN's own column sits relative to the text column, keyed by the run's FIRST block,
/// with the same sign convention as `placedRunClipOutsets`: positive is wider, negative narrower, an
/// absent entry means the text column itself.
///
/// The column is WHERE THE RUN MAY REST — it decides how far the run scrolls, so that its far edge
/// comes to rest on the column's far edge and no further. The CLIP is what is visible. The two are
/// the same rect for a run with nothing drawn around it, and they are not for one inside a
/// host-drawn container: a table in a quote rests inside the quote's interior while its window
/// reaches into the quote's own margin, so the handles that hang off its edges are drawn there.
///
/// Read together they say: scroll until the run's edge reaches its column, and show whatever the
/// window admits along the way.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *placedRunColumnOutsets;

/// Placed blocks that BEGIN a run, whatever precedes them. A placed block adjacent to another one
/// continues its run — which is what makes a table's cells one scrolling surface — unless it is
/// named here.
///
/// Adjacency alone cannot tell two GROUPS of placed blocks apart, and only the host knows where one
/// ends: two tables with nothing stacked between them looked like one run, so they shared one
/// scroll view (dragging either scrolled both) and one clip, which is keyed by the run's first
/// block — a table inside a container that followed a top-level one was cut at the canvas edge
/// rather than at its container's interior. Both were the same missing boundary.
///
/// An absent or empty set is the old behaviour exactly: adjacency decides everything.
@property(nonatomic, copy, nullable) NSSet<NSUUID *> *placedRunStarts;

/// Padding inside each block's text container, on both horizontal edges. Defaults to 5, matching
/// `NSTextContainer`, and is applied to every layout this view owns — created or reused.
@property(nonatomic) CGFloat lineFragmentPadding;

/// What each block's line should be measured and its caret placed with while that block is EMPTY,
/// keyed by block identifier. See `IDBlockLayout.id_hostEmptyLineAttributes`.
@property(nonatomic, copy, nullable)
    NSDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *emptyLineAttributesByBlock;

/// How far along its line each block's EMPTY caret sits, keyed by block identifier. See
/// `IDBlockLayout.id_hostEmptyLineCaretOffset`.
@property(nonatomic, copy, nullable)
    NSDictionary<NSUUID *, NSNumber *> *emptyLineCaretOffsetsByBlock;

/// Answers an EMPTY block's line attributes / caret offset on demand, by identity, taking
/// precedence over the maps above for the identities it answers. A host that knows what each
/// block would render as can answer at the moment the layout or the typing adoption asks, with no
/// map to build, key, or re-key when identities change.
@property(nonatomic, copy, nullable)
    NSDictionary<NSAttributedStringKey, id> *_Nullable (^emptyLineAttributesProvider)(NSUUID *identifier);
@property(nonatomic, copy, nullable)
    NSNumber *_Nullable (^emptyLineCaretOffsetProvider)(NSUUID *identifier);

@property(nonatomic, copy, readonly) NSArray<IDBlockLayout *> *blockLayouts;
@property(nonatomic, readonly) CGSize documentContentSize;

- (instancetype)initWithDocument:(IDBlockDocument *)document;
- (void)updateForDocumentChange:(nullable IDBlockDocumentChange *)change
                           width:(CGFloat)width;
- (nullable IDBlockLayout *)layoutForBlockIdentifier:(NSUUID *)identifier;
- (CGPoint)documentOriginForBlockIdentifier:(NSUUID *)identifier;
/// Clamps above/below the document; an exact shared boundary belongs to the following block.
- (nullable IDBlockLayout *)nearestBlockLayoutForDocumentPoint:(CGPoint)point;
- (nullable NSUUID *)verticallyAdjacentBlockIdentifierFromBlockIdentifier:(NSUUID *)identifier
                                                                  downward:(BOOL)downward
                                                      anchorPositionOffset:(CGFloat)anchorPositionOffset;

/// The scrolling content of the placed run `identifier` belongs to; nil for a stacked block. A host
/// may add its own subviews (a table's chrome, overlays) — they scroll with the run's blocks and are
/// clipped with them, and a relayout leaves them in place.
- (nullable UIView *)placedRunContentViewForBlockIdentifier:(NSUUID *)identifier;
- (CGFloat)placedRunContentOffsetForBlockIdentifier:(NSUUID *)identifier;
- (void)setPlacedRunContentOffset:(CGFloat)offset forBlockIdentifier:(NSUUID *)identifier;

@end

NS_ASSUME_NONNULL_END

#endif
