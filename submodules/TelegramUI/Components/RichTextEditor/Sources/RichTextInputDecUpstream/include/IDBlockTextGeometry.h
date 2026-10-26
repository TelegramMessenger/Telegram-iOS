#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@class IDRichTextSelectionRect;
@class IDBlockSelectionSegment;

typedef struct {
    NSUInteger localOffset;
    UITextStorageDirection affinity;
    CGFloat anchorPositionOffset;
    BOOL found;
} IDBlockCaretStop;

@interface IDBlockTextGeometry : NSObject

- (instancetype)initWithContentStorage:(NSTextContentStorage *)contentStorage
                          layoutManager:(NSTextLayoutManager *)layoutManager
                          textContainer:(NSTextContainer *)textContainer;
- (CGRect)insertionRectForLocation:(id<NSTextLocation>)location
                           affinity:(UITextStorageDirection)affinity;
- (CGRect)boundingRectForLocalRange:(NSRange)range;
- (NSArray<IDRichTextSelectionRect *> *)selectionRectsForLocalRange:(NSRange)range
                                                         extendHead:(BOOL)extendHead
                                                         extendTail:(BOOL)extendTail;
- (nullable NSArray<IDBlockSelectionSegment *> *)selectionSegmentsForLocalRange:
    (NSRange)range
                                                                      extendHead:
    (BOOL)extendHead
                                                                      extendTail:
    (BOOL)extendTail
                                                                layoutGeneration:
    (NSUInteger)layoutGeneration;
- (IDBlockCaretStop)caretStopForLocation:(id<NSTextLocation>)location
                                affinity:(UITextStorageDirection)affinity
                               direction:(UITextLayoutDirection)direction
                    anchorPositionOffset:(CGFloat)anchorPositionOffset;
- (IDBlockCaretStop)caretStopForPoint:(CGPoint)point;

@end


NS_ASSUME_NONNULL_END

#endif
