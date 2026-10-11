#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

#import "IDTextCanvasAttachmentLifecycle.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDTextCanvasAttachmentCoordinator : NSObject

@property(nonatomic, weak, nullable)
    id<IDTextCanvasAttachmentLifecycleSink> lifecycleSink;
@property(nonatomic, strong, readonly) NSSet<UIView *> *visibleAttachmentViews;

- (void)beginViewportLayout;
- (void)recordAttachmentView:(UIView *)view fragmentFrame:(CGRect)frame;
- (void)finishViewportLayout;
- (void)flush;

@end

NS_ASSUME_NONNULL_END

#endif
