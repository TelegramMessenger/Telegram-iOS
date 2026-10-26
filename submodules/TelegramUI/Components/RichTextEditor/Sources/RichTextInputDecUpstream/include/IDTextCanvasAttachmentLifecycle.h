#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@protocol IDTextCanvasAttachmentLifecycleSink <NSObject>

- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentFrame;
- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views;
- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views;

@end

NS_ASSUME_NONNULL_END

#endif
