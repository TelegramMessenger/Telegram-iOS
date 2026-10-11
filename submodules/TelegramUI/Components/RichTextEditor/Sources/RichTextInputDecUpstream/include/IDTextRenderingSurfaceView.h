#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

typedef void (^IDTextAttachmentEnumerationBlock)(UIView *view, CGRect fragmentFrame);

@interface IDTextRenderingSurfaceView : UIView

@property(nonatomic, strong, nullable, readonly) NSTextLayoutFragment *layoutFragment;
@property(nonatomic, readonly) CGPoint containerOrigin;
@property(nonatomic, readonly) CGSize containerSize;
@property(nonatomic, readonly) CGRect clipRect;

- (instancetype)initWithLayoutFragment:(NSTextLayoutFragment *)layoutFragment
                        containerOrigin:(CGPoint)containerOrigin
                         containerSize:(CGSize)containerSize
                              clipRect:(CGRect)clipRect NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)performChanges:(dispatch_block_t)changes;
- (void)setContainerOrigin:(CGPoint)containerOrigin;
- (void)setContainerSize:(CGSize)containerSize;
- (void)setClipRect:(CGRect)clipRect;
- (void)enumerateTextAttachmentViewsUsingBlock:(IDTextAttachmentEnumerationBlock)block;
- (void)teardown;

@end

NS_ASSUME_NONNULL_END

#endif
