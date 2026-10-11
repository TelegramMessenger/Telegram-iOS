#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGRichTextInputDecSelectionRect : UITextSelectionRect
- (instancetype)initWithRect:(CGRect)rect
                containsStart:(BOOL)containsStart
                  containsEnd:(BOOL)containsEnd
                   isVertical:(BOOL)isVertical
             writingDirection:(NSWritingDirection)writingDirection;
@end

NS_ASSUME_NONNULL_END

#endif
