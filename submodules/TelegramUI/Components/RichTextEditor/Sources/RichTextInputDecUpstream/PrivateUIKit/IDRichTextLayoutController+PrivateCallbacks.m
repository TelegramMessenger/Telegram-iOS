#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextSelectionRect.h"
#import "TGPrivateMethodAliases.h"
#import "TGPrivateRuntimeNames.h"

#include <math.h>

@interface IDRichTextSelectionRect (PrivateMutationCallbacks)
- (void)tgpn_setRect:(CGRect)rect fromView:(nullable UIView *)view;
- (void)tgpn_setContainsStart:(BOOL)containsStart;
- (void)tgpn_setContainsEnd:(BOOL)containsEnd;
@end

@implementation IDRichTextSelectionRect (PrivateMutationCallbacks)

- (void)tgpn_setRect:(CGRect)rect fromView:(UIView *)view {
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

- (void)tgpn_setContainsStart:(BOOL)containsStart {
    [self setValue:@(containsStart) forKey:@"storedContainsStart"];
}

- (void)tgpn_setContainsEnd:(BOOL)containsEnd {
    [self setValue:@(containsEnd) forKey:@"storedContainsEnd"];
}

@end

// UIKit calls this on a selection rect it was handed; it is compiled under a neutral name and added
// under the private one (`TGPrivateMethodAliases.h`).
void IDRichTextSelectionRectInstallPrivateCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_setRect_fromView_, @selector(tgpn_setRect:fromView:) },
        { TGPN_setContainsStart_, @selector(tgpn_setContainsStart:) },
        { TGPN_setContainsEnd_, @selector(tgpn_setContainsEnd:) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

@interface IDRichTextLayoutController (PrivateCallbacks)
- (NSTextStorage *)textStorage;
- (NSArray<NSTextContainer *> *)textContainers;
- (nullable id)layoutManager;
- (UITextPosition *)beginningOfDocument;
- (UITextPosition *)endOfDocument;
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
- (NSComparisonResult)comparePosition:(UITextPosition *)first
                            toPosition:(UITextPosition *)second;
- (NSInteger)offsetFromPosition:(UITextPosition *)first toPosition:(UITextPosition *)second;
- (void)invalidateDisplayForCharacterRange:(NSRange)range;
- (void)ensureLayoutForRange:(UITextRange *)range;
- (void)invalidateLayoutForRange:(UITextRange *)range;
- (NSAttributedString *)attributedTextInRange:(UITextRange *)range;
- (NSRange)tgpn_characterRangeForTextRange:(nullable UITextRange *)range;
@end

@implementation IDRichTextLayoutController (PrivateCallbacks)

- (NSTextStorage *)textStorage { return [self id_textStorage]; }
- (NSArray<NSTextContainer *> *)textContainers { return [self id_textContainers]; }
- (id)layoutManager { return [self id_layoutManager]; }
- (UITextPosition *)beginningOfDocument { return [self id_beginningOfDocument]; }
- (UITextPosition *)endOfDocument { return [self id_endOfDocument]; }
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
- (NSComparisonResult)comparePosition:(UITextPosition *)first
                            toPosition:(UITextPosition *)second {
    return [self id_comparePosition:first toPosition:second];
}
- (NSInteger)offsetFromPosition:(UITextPosition *)first toPosition:(UITextPosition *)second {
    return [self id_offsetFromPosition:first toPosition:second];
}
- (void)invalidateDisplayForCharacterRange:(NSRange)range {
    [self id_invalidateDisplayForCharacterRange:range];
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
- (NSRange)tgpn_characterRangeForTextRange:(nullable UITextRange *)range {
    return [self id_characterRangeForTextRange:range clipped:NO];
}

@end

// The layout controller's callbacks that UIKit calls under PRIVATE names. Each is an `id_` method
// with the same arguments, so it is added under the private name directly instead of through a
// forwarder compiled under that name (`TGPrivateMethodAliases.h`). The one exception is
// `characterRangeForTextRange:`, whose `id_` counterpart takes one more argument.
void IDRichTextLayoutControllerInstallPrivateCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_firstTextContainer, @selector(id_firstTextContainer) },
        { TGPN_textContainerForPosition_, @selector(id_textContainerForPosition:) },
        { TGPN_canAccessLayoutManager, @selector(id_canAccessLayoutManager) },
        { TGPN_textInputController, @selector(inputController) },
        { TGPN_adoptTextInputController_, @selector(id_adoptTextInputController:) },
        { TGPN_detachFromTextInputController, @selector(id_detachFromTextInputController) },
        { TGPN_emptyTextRangeAtPosition_, @selector(id_emptyTextRangeAtPosition:) },
        { TGPN_textRangeForLineEnclosingPosition_, @selector(id_textRangeForLineEnclosingPosition:) },
        { TGPN_textRangeForLineEnclosingPosition_effectiveAffinity_,
          @selector(id_textRangeForLineEnclosingPosition:effectiveAffinity:) },
        { TGPN_attributesAtPosition_inDirection_, @selector(id_attributesAtPosition:inDirection:) },
        { TGPN_baseWritingDirectionAtPosition_, @selector(id_baseWritingDirectionAtPosition:) },
        { TGPN_affinityForPosition_, @selector(id_affinityForPosition:) },
        { TGPN_characterRangeForTextRange_, @selector(tgpn_characterRangeForTextRange:) },
        { TGPN_boundingRectForCharacterRange_, @selector(id_boundingRectForCharacterRange:) },
        { TGPN_characterRangeForTextRange_clippedToDocument_, @selector(id_characterRangeForTextRange:clipped:) },
        { TGPN_characterRangesForTextRange_clippedToDocument_, @selector(id_characterRangesForTextRange:clipped:) },
        { TGPN_textRangeForCharacterRange_, @selector(id_textRangeForCharacterRange:) },
        { TGPN_textRangeForCharacterRanges_, @selector(id_textRangeForCharacterRanges:) },
        { TGPN_positionWithOffset_affinity_, @selector(id_positionWithOffset:affinity:) },
        { TGPN_rangeOfCharacterClusterAtIndex_type_, @selector(id_rangeOfCharacterClusterAtIndex:type:) },
        { TGPN_selectionRectsForRange_fromView_forContainerPassingTest_,
          @selector(id_selectionRectsForRange:fromView:forContainerPassingTest:) },
        { TGPN_requestTextGeometryAtPosition_typingAttributes_resultBlock_,
          @selector(id_requestTextGeometryAtPosition:typingAttributes:resultBlock:) },
        { TGPN_insertionRectForPosition_typingAttributes_placeholderAttachment_textContainer_,
          @selector(id_insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:) },
        { TGPN_cursorPositionAtPoint_inContainer_, @selector(id_cursorPositionAtPoint:inContainer:) },
        { TGPN_nearestPositionAtPoint_inContainer_, @selector(id_nearestPositionAtPoint:inContainer:) },
        { TGPN__visualSelectionRangeForExtent_forPoint_fromPosition_inDirection_,
          @selector(id_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:) },
        { TGPN_annotationAttribute_atPosition_, @selector(id_annotationAttribute:atPosition:) },
        { TGPN_annotatedSubstringForRange_, @selector(id_annotatedSubstringForRange:) },
        { TGPN_addAnnotationAttribute_value_forRange_, @selector(id_addAnnotationAttribute:value:forRange:) },
        { TGPN_removeAnnotationAttribute_forRange_, @selector(id_removeAnnotationAttribute:forRange:) },
        { TGPN_addRenderingAttributes_forRange_, @selector(id_addRenderingAttributes:forRange:) },
        { TGPN_removeRenderingAttributes_forRange_, @selector(id_removeRenderingAttributes:forRange:) },
        { TGPN__invalidateTemporaryAttributesInRange_, @selector(id_invalidateTemporaryAttributesInRange:) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

#endif
