#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

#import "IDBlockTextGeometry.h"

@class IDBlock;
@class IDBlockSelectionSegment;
@class IDRichTextSelectionRect;
@class IDTextLayoutCanvasView;

NS_ASSUME_NONNULL_BEGIN

@interface IDBlockLayout : NSObject

@property(nonatomic, copy, readonly) NSUUID *blockIdentifier;
@property(nonatomic, strong, readonly) NSTextContentStorage *contentStorage;
@property(nonatomic, strong, readonly) NSTextLayoutManager *layoutManager;
@property(nonatomic, strong, readonly) NSTextContainer *textContainer;
@property(nonatomic, strong, readonly) IDTextLayoutCanvasView *canvasView;
/// Exact full-range usage size. An empty block occupies one exact font line.
@property(nonatomic, readonly) CGSize usedSize;
/// Advances only when attributed content or separator attributes change.
@property(nonatomic, readonly) NSUInteger contentRevision;
/// Advances when content revision or normalized layout inputs change.
@property(nonatomic, readonly) NSUInteger layoutGeneration;

/// Decorates a block's text for RENDERING ONLY, never for the model.
///
/// THIS IS THE ONLY DISPLAY-ONLY CHANNEL THIS ENGINE HAS, and it exists because a block renders from
/// `block.attributedText`: presentation is otherwise written into the document, where every visual
/// channel maps onto a model field and would be sent. Styling that must not be sent — a spoiler's
/// hide — and styling that must change without an edit — that hide coming and going as the selection
/// moves — has nowhere else to go. A document write would also mean an undo entry per caret move.
///
/// Called with the block's own text and identity; return the text to draw. Must be pure and cheap:
/// it runs on every content update.
typedef NSAttributedString *_Nonnull (^IDBlockTextDisplayDecorator)(
    NSAttributedString *text, NSUUID *blockIdentifier);

@property(nonatomic, copy, nullable) IDBlockTextDisplayDecorator displayDecorator;

/// What this block's line should be measured and its caret placed with while the block is EMPTY.
///
/// An empty text storage carries no attributes at all, so nothing about the intended line — neither
/// the font, nor a pinned paragraph line height, nor an indent — is reachable from it. The layout
/// otherwise takes them from the block's SEPARATOR, which is the newline that follows it: workable
/// for every block but the last, which has no following newline and falls back to the document's
/// defaults. A host that knows what an empty block is going to be sets this instead.
///
/// Empty or nil means "use the separator", which is the behaviour every existing caller gets.
@property(nonatomic, copy, nullable)
    NSDictionary<NSAttributedStringKey, id> *id_hostEmptyLineAttributes;

/// Moves the EMPTY line's caret along the line, without moving what is typed into it.
///
/// A host that draws a prompt in an empty line usually wants the caret at the prompt's start rather
/// than at the insertion point the line's own alignment produces — a CENTRED prompt otherwise has
/// the caret in its middle. That is a property of the prompt, not of the text, so it cannot come
/// from `id_hostEmptyLineAttributes`: those also decide what a first keystroke inherits, and a line
/// that types its first character off-centre is a worse bug than the one being fixed.
@property(nonatomic) CGFloat id_hostEmptyLineCaretOffset;

/// Reloads the rendered text from `block`, applying `displayDecorator`. Returns YES when what is
/// drawn actually changed.
- (BOOL)updateContentFromBlock:(IDBlock *)block;

- (instancetype)initWithBlock:(IDBlock *)block width:(CGFloat)width;
- (void)updateFromBlock:(IDBlock *)block width:(CGFloat)width;
- (nullable id<NSTextLocation>)locationForLocalOffset:(NSUInteger)offset;
- (NSUInteger)localOffsetForLocation:(nullable id<NSTextLocation>)location;
- (CGRect)caretRectForLocalOffset:(NSUInteger)offset
                         affinity:(UITextStorageDirection)affinity;
- (CGRect)boundingRectForLocalRange:(NSRange)range;

/// The frame TextKit laid an ATTACHMENT out in, at a local offset, in this block's coordinates.
///
/// Not the same as a selection rect, and the difference is visible: a selection rect is the LINE's
/// height, while an attachment's box is its own square sitting on the baseline. Positioning a hosted
/// emoji view from a selection rect stretches it.
- (CGRect)attachmentFrameForLocalOffset:(NSUInteger)offset;
- (NSArray<IDRichTextSelectionRect *> *)selectionRectsForLocalRange:(NSRange)range;
- (NSArray<IDRichTextSelectionRect *> *)selectionRectsForLocalRange:(NSRange)range
                                                         extendHead:(BOOL)extendHead
                                                         extendTail:(BOOL)extendTail;
- (nullable NSArray<IDBlockSelectionSegment *> *)selectionSegmentsForLocalRange:
    (NSRange)range
                                                                      extendHead:
    (BOOL)extendHead
                                                                      extendTail:
    (BOOL)extendTail;
- (IDBlockCaretStop)caretStopForPoint:(CGPoint)point;
- (NSUInteger)nearestLocalOffsetForPoint:(CGPoint)point;
- (NSRange)localLineRangeEnclosingOffset:(NSUInteger)offset
                        effectiveAffinity:(nullable UITextStorageDirection *)affinity;
- (NSWritingDirection)baseWritingDirectionAtLocalOffset:(NSUInteger)offset;
- (NSWritingDirection)resolvedWritingDirectionAtLocalOffset:(NSUInteger)offset;
- (NSUInteger)visuallyAdjacentLocalOffsetFromOffset:(NSUInteger)offset
                                            affinity:(UITextStorageDirection)affinity
                                           direction:(UITextLayoutDirection)direction
                                    resultingAffinity:(nullable UITextStorageDirection *)resultingAffinity;
- (IDBlockCaretStop)caretStopFromLocalOffset:(NSUInteger)offset
                                     affinity:(UITextStorageDirection)affinity
                                    direction:(UITextLayoutDirection)direction
                         anchorPositionOffset:(CGFloat)anchorPositionOffset;
- (NSDictionary<NSAttributedStringKey, id> *)attributesAtLocalOffset:(NSUInteger)offset
                                                            direction:(UITextStorageDirection)direction;

@end

NS_ASSUME_NONNULL_END

#endif
