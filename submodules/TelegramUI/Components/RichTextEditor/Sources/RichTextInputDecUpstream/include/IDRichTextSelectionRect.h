#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextSelectionRect : UITextSelectionRect
- (instancetype)initWithRect:(CGRect)rect
               baselineOffset:(CGFloat)baselineOffset
                containsStart:(BOOL)containsStart
                  containsEnd:(BOOL)containsEnd
                   isVertical:(BOOL)isVertical
             writingDirection:(NSWritingDirection)writingDirection;
/// A rect whose baseline is unknown (`baselineOffset` 0): a caret rect, a placeholder.
- (instancetype)initWithRect:(CGRect)rect
                containsStart:(BOOL)containsStart
                  containsEnd:(BOOL)containsEnd
                   isVertical:(BOOL)isVertical
             writingDirection:(NSWritingDirection)writingDirection;
/// The line's baseline, measured down from the rect's top edge; 0 when the rect was built
/// without one. UITextSelectionRect keeps this in a private ivar that UIKit initialises to
/// infinity and that its text-choice assistant reads to place an accepted autocorrection's
/// underline (falling back to three quarters of the height only when it reads 0) — so a subclass
/// that never answers it draws that underline at y = infinity. Measured on iOS 26.5, 2026-09-11.
- (CGFloat)baselineOffset;
@end

NS_ASSUME_NONNULL_END

#endif
