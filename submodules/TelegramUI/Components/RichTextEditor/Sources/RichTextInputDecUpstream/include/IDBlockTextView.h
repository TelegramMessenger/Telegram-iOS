#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

#import "IDInlineTextFormatting.h"

#import "IDBlockLayout.h"

NS_ASSUME_NONNULL_BEGIN

/// Availability is gated at the HIGHEST requirement of the properties below rather than
/// per-property, deliberately.
///
/// Six of them use UIKit types newer than this project's own floor —
/// `UITextInlinePredictionType` (17.0), `UITextMathExpressionCompletionType`,
/// `UIWritingToolsBehavior`, `UIWritingToolsResultOptions` (18.0), and `UIConversationContext`
/// (18.4). Left unannotated they compiled here, because this project targets a recent iOS, but a
/// HOST with a lower deployment floor cannot import this header from Swift at all: the type
/// references are errors before any call site exists. telegram-ios builds at iOS 15 and hit exactly
/// that.
///
/// One class-level gate rather than six property gates keeps the class coherent: a caller that can
/// see `IDBlockTextView` can see all of it, instead of holding a reference whose members wink in and
/// out with the deployment target. The cost is reach — `conversationContext` ALONE forces 18.4;
/// everything else would fit under 18.0 — so if a host needs the wider range, moving that one
/// property behind its own `API_AVAILABLE(ios(18.4))` drops the class to 18.0.
API_AVAILABLE(ios(18.4))
@interface IDBlockTextView : UIScrollView <UITextPasteConfigurationSupporting>

@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy, readonly) NSArray<NSAttributedString *> *attributedBlocks;
@property(nonatomic, strong) UIFont *font;
@property(nonatomic, strong) UIColor *textColor;
@property(nonatomic) UIEdgeInsets textContainerInset;
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, getter=isSelectable) BOOL selectable;
@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;
@property(nonatomic) UITextSpellCheckingType spellCheckingType;
@property(nonatomic) UITextSmartQuotesType smartQuotesType;
@property(nonatomic) UITextSmartDashesType smartDashesType;
@property(nonatomic) UITextSmartInsertDeleteType smartInsertDeleteType;
@property(nonatomic) UITextInlinePredictionType inlinePredictionType;
@property(nonatomic) UITextMathExpressionCompletionType mathExpressionCompletionType;
@property(nonatomic) UIKeyboardType keyboardType;
@property(nonatomic) UIKeyboardAppearance keyboardAppearance;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic) BOOL enablesReturnKeyAutomatically;
@property(nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property(nullable, nonatomic, copy) UITextContentType textContentType;
@property(nullable, nonatomic, copy) UITextInputPasswordRules *passwordRules;
@property(nonatomic) UIWritingToolsBehavior writingToolsBehavior;
@property(nonatomic) UIWritingToolsResultOptions allowedWritingToolsResultOptions;
@property(nullable, nonatomic, strong) UIConversationContext *conversationContext;
@property(nonatomic) BOOL allowsNumberPadPopover;
@property(nullable, nonatomic, copy) UIPasteConfiguration *pasteConfiguration;
@property(nullable, nonatomic, weak) id<UITextPasteDelegate> pasteDelegate;
@property(nonatomic, readonly) IDInlineTextTraits effectiveInlineTextTraits;
@property(nullable, nonatomic, copy)
    void (^inlineTextTraitStateDidChangeHandler)(void);

- (instancetype)initWithFrame:(CGRect)frame
              attributedBlocks:(NSArray<NSAttributedString *> *)blocks;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)toggleInlineTextTrait:(IDInlineTextTraits)trait;
/// Applies several text-input trait changes and reloads the keyboard ONCE, and only if one of them
/// actually changed a value. Each trait setter on its own reloads the input views when first
/// responder; a host switching a group of traits together (a caret entering code) wants one reload.
- (void)id_updateTextInputTraits:(void (NS_NOESCAPE ^)(void))updates;
/// Display-only decoration for the rendered text. NEVER reaches the document.
///
/// The engine's one channel for styling that must not be sent, or that must change without an edit —
/// a spoiler's hide, and that hide coming and going as the selection moves. Everything else a host
/// styles goes into the document, where each visual channel maps onto a model field.
@property(nonatomic, copy, nullable) IDBlockTextDisplayDecorator displayDecorator;

/// Geometry for an arbitrary canonical range, in THIS VIEW's coordinate space.
///
/// A host that draws over text — spoiler dust, and whatever comes after it — needs this and has no
/// way to build it: `selectionRectsForLocalRange:` is per-block and block-local, and mapping a
/// canonical range onto blocks and converting each block's coordinates is engine knowledge.
- (NSArray<NSValue *> *)id_rectsForCanonicalRange:(NSRange)range;

/// The frame of the ATTACHMENT at a canonical offset, in this view's coordinates, or `CGRectNull`.
/// Use this rather than `id_rectsForCanonicalRange:` to place a view over an inline atom: the latter
/// returns the LINE's height and stretches it.
/// Space reserved AROUND individual blocks, keyed by the engine's block identity. See
/// `IDBlockStackCanvasView.blockInsets`: interior padding for a host-drawn container that spans
/// several blocks, which cannot be expressed in the text itself.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *blockInsets;

/// Where each block's selection reaches horizontally, keyed by the engine's block identity. See
/// `IDBlockStackCanvasView.selectionBoxes`. Assigning it does NOT lay anything out.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *selectionBoxes;

/// Frames for blocks the host PLACES instead of stacking. See `IDBlockStackCanvasView.blockFrames`.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *blockFrames;

/// Where a placed RUN's clip sits relative to its text column, keyed by the run's first block. See
/// `IDBlockStackCanvasView.placedRunClipOutsets`.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *placedRunClipOutsets;

/// Where each placed RUN's own column sits, which is how far it may scroll. See
/// `IDBlockStackCanvasView.placedRunColumnOutsets`.
@property(nonatomic, copy, nullable) NSDictionary<NSUUID *, NSValue *> *placedRunColumnOutsets;

/// Placed blocks that begin a run. See `IDBlockStackCanvasView.placedRunStarts`.
@property(nonatomic, copy, nullable) NSSet<NSUUID *> *placedRunStarts;

/// Padding inside the text container on both horizontal edges, named after the `NSTextContainer`
/// property it forwards to. Defaults to 5, that container's own default.
///
/// (Named without reference to UIKit's own text view on purpose: `IDProjectSmokeTests` scans
/// production sources for that class name and a mention in prose trips it.)
///
/// A host that owns its horizontal padding — a chat composer, whose panel insets the field and passes
/// the remainder as `textContainerInset` — sets 0, or this lands on top of what it asked for and the
/// text reads as inset 5pt more than intended on each side.
@property(nonatomic) CGFloat lineFragmentPadding;

/// What each block's line should be measured and its caret placed with while that block is EMPTY,
/// keyed by block identifier (`id_blockIdentifiers`).
///
/// An empty text storage carries no attributes, so the intended line is not recoverable from it. The
/// engine otherwise reads them off the block's SEPARATOR — the newline that follows it — which
/// leaves the LAST block with nothing but the document's defaults: a trailing empty line measured in
/// the default font with its caret at the container's leading edge, whatever it was going to be.
///
/// Keyed by identifier rather than by index so the answers survive the re-parse every edit performs.
@property(nonatomic, copy, nullable)
    NSDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *id_emptyLineAttributesByBlock;

/// How far along its line each block's EMPTY caret sits, keyed by block identifier — for a host that
/// draws a prompt there and wants the caret at its start. Does NOT affect what is typed.
@property(nonatomic, copy, nullable)
    NSDictionary<NSUUID *, NSNumber *> *id_emptyLineCaretOffsetsByBlock;

/// On-demand alternatives to the two maps above. See `IDBlockStackCanvasView`'s counterparts.
@property(nonatomic, copy, nullable)
    NSDictionary<NSAttributedStringKey, id> *_Nullable (^id_emptyLineAttributesProvider)(NSUUID *identifier);
@property(nonatomic, copy, nullable)
    NSNumber *_Nullable (^id_emptyLineCaretOffsetProvider)(NSUUID *identifier);

/// An attribute-only edit over a canonical range, for a host that restyles text it has just
/// moved or created by a controller edit. Reported as a change like any attribute rewrite; NOT
/// recorded by the controller's undo, and it shifts no offsets, so the controller's entries stay
/// valid. A host that needs the restyle undone registers its own undo inside the same group.
- (void)id_setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
        inCanonicalRange:(NSRange)range;

- (CGRect)id_attachmentFrameForCanonicalOffset:(NSUInteger)offset;

/// The frame of the BLOCK at `index`, in this view's coordinates, or `CGRectNull` for an unknown
/// index.
///
/// The sibling of the two accessors above, for decoration that surrounds a block rather than
/// covering its glyphs — a code block's background band, a quote's accent bar. Those answer about
/// text and about one inline atom respectively; neither describes the box such decoration lines up
/// with. A host could not compute it either: it would have to reach through `blockLayouts` into each
/// block's canvas view and redo the coordinate conversion, and the block canvases sit inside a
/// scrolling stack whose offset is not simply their frame.
///
/// `CGRectNull` and not `CGRectZero` for an unknown index, deliberately: zero is a plausible rect, so
/// a host would park its decoration at the origin and see nothing wrong until a real block landed
/// there.
- (CGRect)id_frameForBlockAtIndex:(NSUInteger)index;

/// The block's SELECTION slot — its frame plus the space reserved around it — in this view's
/// coordinates, or `CGRectNull` for an unknown index. See
/// `IDBlockStackCanvasView.selectionSlotForBlockIdentifier:`. A host reads it to check what a
/// selection over this block will cover; it is not needed to place anything.
- (CGRect)id_selectionSlotForBlockAtIndex:(NSUInteger)index;

/// The part of that slot which is the BLOCK rather than the space around it, or `CGRectNull` when
/// the block has no box of its own. See `IDBlockStackCanvasView.selectionBoxForBlockIdentifier:`.
- (CGRect)id_selectionBoxForBlockAtIndex:(NSUInteger)index;

/// The size the block's text actually occupies, independent of any frame height a host imposed.
/// `CGSizeZero` when `index` is out of range.
- (CGSize)id_usedSizeForBlockAtIndex:(NSUInteger)index;

/// The scrolling content view of the placed run the block at `index` belongs to (nil for a stacked
/// block), and that run's horizontal content offset. See `IDBlockStackCanvasView`'s counterparts.
- (nullable UIView *)id_placedRunContentViewForBlockAtIndex:(NSUInteger)index;
- (CGFloat)id_placedRunContentOffsetForBlockAtIndex:(NSUInteger)index;

/// Whether any placed run is IN FLIGHT: being dragged, or coasting from a drag.
///
/// For a host that nests this view inside something with a drag of its own. A sheet that dismisses
/// on a downward pan recognises simultaneously with every other pan, so a finger put down to catch a
/// coasting run starts the dismiss instead — unless the host can say that the gesture belongs to the
/// editor, which is what this answers.
@property(nonatomic, readonly) BOOL id_hasPlacedRunInFlight;

/// Is the placed run that OWNS this view in flight — dragging, coasting, bouncing, or held by the
/// finger that caught it? NO for a view inside no run.
///
/// For a host that hangs its own interactive chrome inside a run. A tap that CATCHES a moving run
/// must not also press what is under the finger — every scroll view in iOS refuses content touches
/// that way, and a run cannot: it never receives the touch. Ask this from the chrome's own
/// recogniser, at touch-down.
- (BOOL)id_isPlacedRunInFlightForView:(UIView *)view;
- (void)id_setPlacedRunContentOffset:(CGFloat)offset forBlockAtIndex:(NSUInteger)index;

/// The text as it is actually RENDERED for a block, decoration included.
///
/// Exists so a host can verify decoration end to end. Without it the only ways to check that a
/// decorator reached the screen are pixels or testing the decorator function in isolation — and the
/// latter is precisely how three broken presentation designs shipped with green tests: each
/// exercised the contract at the one place it worked and never the path the app uses.
- (nullable NSAttributedString *)id_renderedTextForBlockAtIndex:(NSUInteger)index;

/// Recomputes the decorated text on the next layout pass. Call when the decorator's OUTPUT would
/// change although the document has not — the selection moving across a spoiler.
- (void)setNeedsDisplayDecorationUpdate;

/// Decides what a newly typed run carries, given what it inherited and what came before it.
///
/// A NAME LIST IS NOT ENOUGH, which is why this replaced one. Continuation is not a property of an
/// attribute, it is a decision about a specific edit: a link continues when a word character is typed
/// against it and stops at punctuation or a space; a spoiler always continues, or typing inside one
/// splits it in two. Only the host knows those rules.
///
/// `current` is what the inserted run has after the engine's own insertion; `preceding` is the run it
/// was typed after (empty at the start of a block); `following` is the character the inserted run was
/// typed BEFORE, in the same block (empty at the end of a block, and before a line break); `insertedText`
/// is what was typed. Return the attributes the inserted run should end up with.
///
/// `following` is what tells typing INSIDE a run from typing at its end: a link stops at a space typed
/// after it, and must not split in two at a space typed between two of its own characters.
@property(nonatomic, copy, nullable)
    NSDictionary<NSAttributedStringKey, id> *(^typedTextAttributePolicy)(
        NSDictionary<NSAttributedStringKey, id> *current,
        NSDictionary<NSAttributedStringKey, id> *preceding,
        NSDictionary<NSAttributedStringKey, id> *following,
        NSString *insertedText);

/// Transforms every run's attributes across the current selection, or the typing attributes when the
/// selection is collapsed. One call is one undo step.
- (void)transformInlineAttributesUsingBlock:
    (NSDictionary<NSAttributedStringKey, id> *(^)(
        NSDictionary<NSAttributedStringKey, id> *attributes))block;

/// Sets a HOST attribute — a key this engine does not own — over the current selection, or on the
/// typing attributes when the selection is collapsed. `nil` removes the key.
///
/// Storage counterpart to `IDInlineTextStyleContributor`, which owns such a key's PRESENTATION.
- (void)setHostAttributeValue:(nullable id)value
                       forKey:(NSAttributedStringKey)key;

/// The host attribute's value over the current selection, or nil when the selection carries none —
/// or carries more than one distinct value, which is the link-spanning-two-links case.
- (nullable id)hostAttributeValueForKey:(NSAttributedStringKey)key;

- (IDInlineTextTraitState)stateForInlineTextTrait:
    (IDInlineTextTraits)trait;

@end

API_AVAILABLE(ios(18.4))
@interface IDBlockTextView (TextInputConformance) <UITextInput>
@end

NS_ASSUME_NONNULL_END

#endif
