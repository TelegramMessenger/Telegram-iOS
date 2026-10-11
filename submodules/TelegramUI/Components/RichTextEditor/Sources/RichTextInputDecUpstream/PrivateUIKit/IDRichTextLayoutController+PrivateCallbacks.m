#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextSelectionRect.h"

#include <math.h>

@interface IDRichTextSelectionRect (PrivateMutationCallbacks)
- (void)setRect:(CGRect)rect fromView:(nullable UIView *)view;
- (void)setContainsStart:(BOOL)containsStart;
- (void)setContainsEnd:(BOOL)containsEnd;
@end

@implementation IDRichTextSelectionRect (PrivateMutationCallbacks)

- (void)setRect:(CGRect)rect fromView:(UIView *)view {
    if (!isfinite(rect.origin.x) || !isfinite(rect.origin.y) ||
        !isfinite(rect.size.width) || !isfinite(rect.size.height)) return;
    CGFloat scale = view.contentScaleFactor;
    if (!isfinite(scale) || scale <= 0) scale = view.window.screen.scale;
    if (!isfinite(scale) || scale <= 0) scale = view.traitCollection.displayScale;
    if (!isfinite(scale) || scale <= 0) scale = 1.0;
    CGFloat minimumX = round(CGRectGetMinX(rect) * scale) / scale;
    CGFloat minimumY = round(CGRectGetMinY(rect) * scale) / scale;
    CGFloat maximumX = round(CGRectGetMaxX(rect) * scale) / scale;
    CGFloat maximumY = round(CGRectGetMaxY(rect) * scale) / scale;
    CGRect rounded = CGRectMake(minimumX,
                                minimumY,
                                maximumX - minimumX,
                                maximumY - minimumY);
    [self setValue:[NSValue valueWithCGRect:rounded] forKey:@"storedRect"];
}

- (void)setContainsStart:(BOOL)containsStart {
    [self setValue:@(containsStart) forKey:@"storedContainsStart"];
}

- (void)setContainsEnd:(BOOL)containsEnd {
    [self setValue:@(containsEnd) forKey:@"storedContainsEnd"];
}

@end

@interface IDRichTextLayoutController (PrivateCallbacks)
- (NSTextStorage *)textStorage;
- (NSArray<NSTextContainer *> *)textContainers;
- (nullable NSTextContainer *)firstTextContainer;
- (nullable NSTextContainer *)textContainerForPosition:(UITextPosition *)position;
- (BOOL)canAccessLayoutManager;
- (nullable id)layoutManager;
- (nullable id)textInputController;
- (void)adoptTextInputController:(id)controller;
- (void)detachFromTextInputController;
- (UITextPosition *)beginningOfDocument;
- (UITextPosition *)endOfDocument;
- (UITextRange *)emptyTextRangeAtPosition:(UITextPosition *)position;
- (UITextRange *)textRangeFromPosition:(UITextPosition *)from
                            toPosition:(UITextPosition *)to;
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset;
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                  offset:(NSInteger)offset
                                affinity:(UITextStorageDirection)affinity;
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                      inDirection:(UITextLayoutDirection)direction
                                           offset:(NSInteger)offset
                                         affinity:(UITextStorageDirection)affinity
                             anchorPositionOffset:(CGFloat)anchorPositionOffset;
- (nullable UITextRange *)textRangeForLineEnclosingPosition:(UITextPosition *)position;
- (nullable UITextRange *)textRangeForLineEnclosingPosition:(UITextPosition *)position
                                           effectiveAffinity:(UITextStorageDirection)affinity;
- (NSDictionary<NSAttributedStringKey, id> *)attributesAtPosition:(UITextPosition *)position
                                                       inDirection:(UITextStorageDirection)direction;
- (NSWritingDirection)baseWritingDirectionAtPosition:(UITextPosition *)position;
- (NSComparisonResult)comparePosition:(UITextPosition *)first
                            toPosition:(UITextPosition *)second;
- (NSInteger)offsetFromPosition:(UITextPosition *)first toPosition:(UITextPosition *)second;
- (UITextStorageDirection)affinityForPosition:(UITextPosition *)position;
- (NSRange)characterRangeForTextRange:(nullable UITextRange *)range;
- (CGRect)boundingRectForCharacterRange:(NSRange)range;
- (NSRange)characterRangeForTextRange:(nullable UITextRange *)range
                    clippedToDocument:(BOOL)clipped;
- (NSArray<NSValue *> *)characterRangesForTextRange:(UITextRange *)range
                                 clippedToDocument:(BOOL)clipped;
- (UITextRange *)textRangeForCharacterRange:(NSRange)range;
- (UITextRange *)textRangeForCharacterRanges:(NSArray<NSValue *> *)ranges;
- (UITextPosition *)positionWithOffset:(NSInteger)offset
                               affinity:(UITextStorageDirection)affinity;
- (void)invalidateDisplayForCharacterRange:(NSRange)range;
- (NSRange)rangeOfCharacterClusterAtIndex:(NSUInteger)index type:(NSInteger)type;
- (NSArray *)selectionRectsForRange:(UITextRange *)range
                           fromView:(UIView *)view
            forContainerPassingTest:(BOOL (^)(id container))predicate;
- (void)requestTextGeometryAtPosition:(UITextPosition *)position
                     typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                          resultBlock:(void (^)(NSTextContainer *container,
                                                    CGRect rect,
                                                    CGFloat baselineOffset,
                                                    UITextPosition *position))resultBlock;
- (CGRect)insertionRectForPosition:(UITextPosition *)position
                   typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
              placeholderAttachment:(nullable id)attachment
                      textContainer:(NSTextContainer * _Nullable * _Nullable)textContainer;
- (nullable UITextPosition *)cursorPositionAtPoint:(CGPoint)point
                                        inContainer:(nullable NSTextContainer *)container;
- (nullable UITextPosition *)nearestPositionAtPoint:(CGPoint)point
                                         inContainer:(nullable NSTextContainer *)container;
- (nullable UITextRange *)_visualSelectionRangeForExtent:(UITextPosition *)extent
                                                forPoint:(CGPoint)point
                                            fromPosition:(UITextPosition *)position
                                             inDirection:(UITextStorageDirection)direction;
- (void)ensureLayoutForRange:(UITextRange *)range;
- (void)invalidateLayoutForRange:(UITextRange *)range;
- (NSAttributedString *)attributedTextInRange:(UITextRange *)range;
- (nullable id)annotationAttribute:(id)attribute
                        atPosition:(UITextPosition *)position;
- (NSAttributedString *)annotatedSubstringForRange:(UITextRange *)range;
- (void)addAnnotationAttribute:(id)attribute
                         value:(id)value
                      forRange:(UITextRange *)range;
- (void)removeAnnotationAttribute:(id)attribute
                          forRange:(UITextRange *)range;
- (void)addRenderingAttributes:(NSDictionary *)attributes
                       forRange:(UITextRange *)range;
- (void)removeRenderingAttributes:(id<NSFastEnumeration>)attributes
                          forRange:(UITextRange *)range;
- (void)_invalidateTemporaryAttributesInRange:(UITextRange *)range;
@end

@implementation IDRichTextLayoutController (PrivateCallbacks)

- (NSTextStorage *)textStorage { return [self id_textStorage]; }
- (NSArray<NSTextContainer *> *)textContainers { return [self id_textContainers]; }
- (NSTextContainer *)firstTextContainer { return [self id_firstTextContainer]; }
- (NSTextContainer *)textContainerForPosition:(UITextPosition *)position {
    return [self id_textContainerForPosition:position];
}
- (BOOL)canAccessLayoutManager { return [self id_canAccessLayoutManager]; }
- (id)layoutManager { return [self id_layoutManager]; }
- (id)textInputController { return self.inputController; }
- (void)adoptTextInputController:(id)controller {
    [self id_adoptTextInputController:controller];
}
- (void)detachFromTextInputController { [self id_detachFromTextInputController]; }
- (UITextPosition *)beginningOfDocument { return [self id_beginningOfDocument]; }
- (UITextPosition *)endOfDocument { return [self id_endOfDocument]; }
- (UITextRange *)emptyTextRangeAtPosition:(UITextPosition *)position {
    return [self id_emptyTextRangeAtPosition:position];
}
- (UITextRange *)textRangeFromPosition:(UITextPosition *)from
                            toPosition:(UITextPosition *)to {
    return [self id_textRangeFromPosition:from toPosition:to];
}
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset {
    return [self id_positionFromPosition:position offset:offset];
}
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                  offset:(NSInteger)offset
                                affinity:(UITextStorageDirection)affinity {
    return [self id_positionFromPosition:position offset:offset affinity:affinity];
}
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                      inDirection:(UITextLayoutDirection)direction
                                           offset:(NSInteger)offset
                                         affinity:(UITextStorageDirection)affinity
                             anchorPositionOffset:(CGFloat)anchorPositionOffset {
    return [self id_positionFromPosition:position
                             inDirection:direction
                                  offset:offset
                                affinity:affinity
                    anchorPositionOffset:anchorPositionOffset];
}
- (UITextRange *)textRangeForLineEnclosingPosition:(UITextPosition *)position {
    return [self id_textRangeForLineEnclosingPosition:position];
}
- (UITextRange *)textRangeForLineEnclosingPosition:(UITextPosition *)position
                                  effectiveAffinity:(UITextStorageDirection)affinity {
    return [self id_textRangeForLineEnclosingPosition:position
                                     effectiveAffinity:affinity];
}
- (NSDictionary<NSAttributedStringKey, id> *)attributesAtPosition:(UITextPosition *)position
                                                       inDirection:(UITextStorageDirection)direction {
    return [self id_attributesAtPosition:position inDirection:direction];
}
- (NSWritingDirection)baseWritingDirectionAtPosition:(UITextPosition *)position {
    return [self id_baseWritingDirectionAtPosition:position];
}
- (NSComparisonResult)comparePosition:(UITextPosition *)first
                            toPosition:(UITextPosition *)second {
    return [self id_comparePosition:first toPosition:second];
}
- (NSInteger)offsetFromPosition:(UITextPosition *)first toPosition:(UITextPosition *)second {
    return [self id_offsetFromPosition:first toPosition:second];
}
- (UITextStorageDirection)affinityForPosition:(UITextPosition *)position {
    return [self id_affinityForPosition:position];
}
- (NSRange)characterRangeForTextRange:(nullable UITextRange *)range {
    return [self id_characterRangeForTextRange:range clipped:NO];
}
- (CGRect)boundingRectForCharacterRange:(NSRange)range {
    return [self id_boundingRectForCharacterRange:range];
}
- (NSRange)characterRangeForTextRange:(nullable UITextRange *)range
                    clippedToDocument:(BOOL)clipped {
    return [self id_characterRangeForTextRange:range clipped:clipped];
}
- (NSArray<NSValue *> *)characterRangesForTextRange:(UITextRange *)range
                                 clippedToDocument:(BOOL)clipped {
    return [self id_characterRangesForTextRange:range clipped:clipped];
}
- (UITextRange *)textRangeForCharacterRange:(NSRange)range {
    return [self id_textRangeForCharacterRange:range];
}
- (UITextRange *)textRangeForCharacterRanges:(NSArray<NSValue *> *)ranges {
    return [self id_textRangeForCharacterRanges:ranges];
}
- (UITextPosition *)positionWithOffset:(NSInteger)offset
                               affinity:(UITextStorageDirection)affinity {
    return [self id_positionWithOffset:offset affinity:affinity];
}
- (void)invalidateDisplayForCharacterRange:(NSRange)range {
    [self id_invalidateDisplayForCharacterRange:range];
}
- (NSRange)rangeOfCharacterClusterAtIndex:(NSUInteger)index type:(NSInteger)type {
    return [self id_rangeOfCharacterClusterAtIndex:index type:type];
}
- (NSArray *)selectionRectsForRange:(UITextRange *)range
                           fromView:(UIView *)view
            forContainerPassingTest:(BOOL (^)(id container))predicate {
    return [self id_selectionRectsForRange:range
                                  fromView:view
                   forContainerPassingTest:predicate];
}
- (void)requestTextGeometryAtPosition:(UITextPosition *)position
                     typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                          resultBlock:(void (^)(NSTextContainer *container,
                                                    CGRect rect,
                                                    CGFloat baselineOffset,
                                                    UITextPosition *position))resultBlock {
    [self id_requestTextGeometryAtPosition:position
                          typingAttributes:attributes
                               resultBlock:resultBlock];
}
- (CGRect)insertionRectForPosition:(UITextPosition *)position
                   typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
              placeholderAttachment:(id)attachment
                      textContainer:(NSTextContainer * _Nullable * _Nullable)textContainer {
    return [self id_insertionRectForPosition:position
                             typingAttributes:attributes
                        placeholderAttachment:attachment
                                textContainer:textContainer];
}
- (UITextPosition *)cursorPositionAtPoint:(CGPoint)point
                                inContainer:(NSTextContainer *)container {
    return [self id_cursorPositionAtPoint:point inContainer:container];
}
- (UITextPosition *)nearestPositionAtPoint:(CGPoint)point
                                 inContainer:(NSTextContainer *)container {
    return [self id_nearestPositionAtPoint:point inContainer:container];
}
- (UITextRange *)_visualSelectionRangeForExtent:(UITextPosition *)extent
                                       forPoint:(CGPoint)point
                                   fromPosition:(UITextPosition *)position
                                    inDirection:(UITextStorageDirection)direction {
    return [self id_visualSelectionRangeForExtent:extent forPoint:point
                                     fromPosition:position inDirection:direction];
}
- (void)ensureLayoutForRange:(UITextRange *)range {
    [self id_ensureLayoutForRange:range];
}
- (void)invalidateLayoutForRange:(UITextRange *)range {
    [self id_invalidateLayoutForRange:range];
}
- (NSAttributedString *)attributedTextInRange:(UITextRange *)range {
    return [self id_attributedTextInRange:range];
}
- (nullable id)annotationAttribute:(id)attribute
                        atPosition:(UITextPosition *)position {
    return [self id_annotationAttribute:attribute atPosition:position];
}
- (NSAttributedString *)annotatedSubstringForRange:(UITextRange *)range {
    return [self id_annotatedSubstringForRange:range];
}
- (void)addAnnotationAttribute:(id)attribute
                         value:(id)value
                      forRange:(UITextRange *)range {
    [self id_addAnnotationAttribute:attribute value:value forRange:range];
}
- (void)removeAnnotationAttribute:(id)attribute
                          forRange:(UITextRange *)range {
    [self id_removeAnnotationAttribute:attribute forRange:range];
}
- (void)addRenderingAttributes:(NSDictionary *)attributes
                       forRange:(UITextRange *)range {
    [self id_addRenderingAttributes:attributes forRange:range];
}
- (void)removeRenderingAttributes:(id<NSFastEnumeration>)attributes
                          forRange:(UITextRange *)range {
    [self id_removeRenderingAttributes:attributes forRange:range];
}
- (void)_invalidateTemporaryAttributesInRange:(UITextRange *)range {
    [self id_invalidateTemporaryAttributesInRange:range];
}

@end

#endif
