#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextLayoutController.h"

@class IDBlockStackCanvasView;
@class IDBlockDocumentChange;
@class IDDocumentLayoutCoordinator;
@class IDRichTextPosition;
@class IDRichTextRange;
@class IDRichTextAnnotationStore;
@class IDRichTextSelectionRect;

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextLayoutController ()

@property(nonatomic, readonly) NSUInteger id_boundingRectForCharacterRangeCallCount;
@property(nonatomic, strong, readonly)
    IDDocumentLayoutCoordinator *id_documentLayoutCoordinator;
@property(nonatomic, strong, readwrite) NSTextContainer *id_interactionTextContainer;
@property(nonatomic, weak, nullable, readwrite) UIView *id_interactionTextView;
- (instancetype)initWithDocument:(IDBlockDocument *)document
               textStorageAdapter:(IDCanonicalTextStorageAdapter *)textStorageAdapter
                        blockStack:(IDBlockStackCanvasView *)blockStack NS_DESIGNATED_INITIALIZER;

- (IDBlockStackCanvasView *)id_blockStack;

- (NSTextStorage *)id_textStorage;
- (NSArray<NSTextContainer *> *)id_textContainers;
- (nullable NSTextContainer *)id_firstTextContainer;
- (nullable NSTextContainer *)id_textContainerForPosition:(UITextPosition *)position;
- (BOOL)id_canAccessLayoutManager;
- (nullable id)id_layoutManager;
- (void)id_adoptTextInputController:(id)controller;
- (void)id_detachFromTextInputController;
- (UITextPosition *)id_beginningOfDocument;
- (UITextPosition *)id_endOfDocument;
- (UITextRange *)id_emptyTextRangeAtPosition:(nullable UITextPosition *)position;
- (UITextRange *)id_textRangeFromPosition:(nullable UITextPosition *)from
                               toPosition:(nullable UITextPosition *)to;
- (nullable UITextPosition *)id_positionFromPosition:(UITextPosition *)position
                                     offset:(NSInteger)offset;
- (nullable UITextPosition *)id_positionFromPosition:(UITextPosition *)position
                                     offset:(NSInteger)offset
                                   affinity:(UITextStorageDirection)affinity;
- (nullable UITextPosition *)id_positionFromPosition:(UITextPosition *)position
                                          inDirection:(UITextLayoutDirection)direction
                                               offset:(NSInteger)offset
                                             affinity:(UITextStorageDirection)affinity
                                 anchorPositionOffset:(CGFloat)anchorPositionOffset;
- (nullable UITextRange *)id_textRangeForLineEnclosingPosition:(UITextPosition *)position;
- (nullable UITextRange *)id_textRangeForLineEnclosingPosition:(UITextPosition *)position
                                              effectiveAffinity:(UITextStorageDirection)affinity;
- (NSDictionary<NSAttributedStringKey, id> *)id_attributesAtPosition:(UITextPosition *)position
                                                          inDirection:(UITextStorageDirection)direction;
- (NSWritingDirection)id_baseWritingDirectionAtPosition:(UITextPosition *)position;
- (NSComparisonResult)id_comparePosition:(UITextPosition *)first
                              toPosition:(UITextPosition *)second;
- (NSInteger)id_offsetFromPosition:(UITextPosition *)first
                        toPosition:(UITextPosition *)second;
- (UITextStorageDirection)id_affinityForPosition:(UITextPosition *)position;
- (NSRange)id_characterRangeForTextRange:(nullable UITextRange *)range
                                  clipped:(BOOL)clipped;
- (NSArray<NSValue *> *)id_characterRangesForTextRange:(UITextRange *)range
                                                clipped:(BOOL)clipped;
- (UITextRange *)id_textRangeForCharacterRange:(NSRange)range;
- (UITextRange *)id_textRangeForCharacterRanges:(NSArray<NSValue *> *)ranges;
- (UITextPosition *)id_positionWithOffset:(NSInteger)offset
                                  affinity:(UITextStorageDirection)affinity;
- (void)id_invalidateDisplayForCharacterRange:(NSRange)range;
- (CGRect)id_boundingRectForCharacterRange:(NSRange)range;
- (NSRange)id_rangeOfCharacterClusterAtIndex:(NSUInteger)index type:(NSInteger)type;
- (NSArray *)id_selectionRectsForRange:(UITextRange *)range
                              fromView:(UIView *)view
               forContainerPassingTest:(BOOL (^)(id container))predicate;
- (nullable NSArray<IDRichTextSelectionRect *> *)
    id_exactSelectionRectsForRange:(UITextRange *)range
                           fromView:(nullable UIView *)view
            forContainerPassingTest:(nullable BOOL (^)(id container))predicate;
/// UIKit's result block takes FOUR arguments — the container, the insertion rect, the line's
/// baseline measured down from that rect's top, and the position — and its caller stamps the
/// baseline on every selection rect for the range ending here, where an accepted
/// autocorrection's underline is placed. Called with the rect alone, the rect still arrives (a
/// CGRect travels in d0–d3 whatever its position) and the baseline is whatever d4 held.
- (void)id_requestTextGeometryAtPosition:(UITextPosition *)position
                         typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                              resultBlock:(void (^)(NSTextContainer *container,
                                                    CGRect rect,
                                                    CGFloat baselineOffset,
                                                    UITextPosition *position))resultBlock;
- (CGRect)id_insertionRectForPosition:(UITextPosition *)position
                      typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                 placeholderAttachment:(nullable id)attachment
                         textContainer:(NSTextContainer * _Nullable * _Nullable)textContainer;
- (nullable UITextPosition *)id_cursorPositionAtPoint:(CGPoint)point
                                           inContainer:(nullable NSTextContainer *)container;
- (nullable UITextPosition *)id_nearestPositionAtPoint:(CGPoint)point
                                            inContainer:(nullable NSTextContainer *)container;
- (nullable UITextRange *)id_visualSelectionRangeForExtent:(UITextPosition *)extent
                                                   forPoint:(CGPoint)point
                                               fromPosition:(UITextPosition *)position
                                                inDirection:(UITextStorageDirection)direction;
- (void)id_ensureLayoutForRange:(UITextRange *)range;
- (void)id_invalidateLayoutForRange:(UITextRange *)range;
- (NSAttributedString *)id_attributedTextInRange:(UITextRange *)range;
- (nullable id)id_annotationAttribute:(id)attribute
                           atPosition:(UITextPosition *)position;
- (NSAttributedString *)id_annotatedSubstringForRange:(UITextRange *)range;
- (void)id_addAnnotationAttribute:(id)attribute
                            value:(id)value
                         forRange:(UITextRange *)range;
- (void)id_removeAnnotationAttribute:(id)attribute
                             forRange:(UITextRange *)range;
- (void)id_addRenderingAttributes:(NSDictionary *)attributes
                          forRange:(UITextRange *)range;
- (void)id_removeRenderingAttributes:(id<NSFastEnumeration>)attributes
                             forRange:(UITextRange *)range;
- (void)id_invalidateTemporaryAttributesInRange:(UITextRange *)range;
- (NSUInteger)id_canonicalOffsetForPosition:(IDRichTextPosition *)position;
- (void)id_directSelectionReplacementDidOccur;
- (void)id_attachInteractionTextView:(UIView *)view;
- (void)id_detachInteractionTextView;
- (void)id_updateInteractionContainerGeometry;
- (void)id_reapplyTemporaryAttributesForDocumentChange:(IDBlockDocumentChange *)change;

@end

/// Adds the controller's callbacks UIKit calls under private names
/// (`IDRichTextLayoutController+PrivateCallbacks.m`). Called from `+initialize`.
FOUNDATION_EXTERN void IDRichTextLayoutControllerInstallPrivateCallbacks(Class cls);
/// Adds the selection rect's private mutation callback. Called from `+initialize`.
FOUNDATION_EXTERN void IDRichTextSelectionRectInstallPrivateCallbacks(Class cls);

NS_ASSUME_NONNULL_END

#endif
