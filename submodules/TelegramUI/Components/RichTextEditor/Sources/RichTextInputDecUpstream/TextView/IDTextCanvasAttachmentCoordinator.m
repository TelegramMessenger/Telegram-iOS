#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextCanvasAttachmentCoordinator.h"

#include <math.h>

@interface IDTextCanvasAttachmentCoordinator ()

@property(nonatomic, strong) NSMutableSet<UIView *> *previousAttachmentViews;
@property(nonatomic, strong) NSMutableSet<UIView *> *currentAttachmentViews;

@end


@implementation IDTextCanvasAttachmentCoordinator

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _previousAttachmentViews = [NSMutableSet set];
        _currentAttachmentViews = [NSMutableSet set];
    }
    return self;
}

- (NSSet<UIView *> *)visibleAttachmentViews {
    return self.previousAttachmentViews.copy;
}

- (void)beginViewportLayout {
    [self.currentAttachmentViews removeAllObjects];
}

- (void)recordAttachmentView:(UIView *)view fragmentFrame:(CGRect)frame {
    BOOL finite = isfinite(frame.origin.x) && isfinite(frame.origin.y) &&
        isfinite(frame.size.width) && isfinite(frame.size.height);
    if (view == nil || !finite) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Attachment recording requires a view and finite fragment frame"
                                     userInfo:nil];
    }
    view.frame = frame;
    [self.lifecycleSink id_attachmentView:view didLayoutInFragmentFrame:frame];
    [self.currentAttachmentViews addObject:view];
}

- (void)finishViewportLayout {
    NSMutableSet<UIView *> *removed = self.previousAttachmentViews.mutableCopy;
    [removed minusSet:self.currentAttachmentViews];
    NSMutableSet<UIView *> *added = self.currentAttachmentViews.mutableCopy;
    [added minusSet:self.previousAttachmentViews];
    if (removed.count > 0) {
        [self.lifecycleSink id_attachmentViewsDidLeaveViewport:removed.copy];
    }
    if (added.count > 0) {
        [self.lifecycleSink id_attachmentViewsDidEnterViewport:added.copy];
    }
    [self.previousAttachmentViews setSet:self.currentAttachmentViews];
    [self.currentAttachmentViews removeAllObjects];
}

- (void)flush {
    NSMutableSet<UIView *> *tracked = self.previousAttachmentViews.mutableCopy;
    [tracked unionSet:self.currentAttachmentViews];
    NSSet<UIView *> *visible = tracked.copy;
    for (UIView *view in visible) {
        [view removeFromSuperview];
    }
    if (visible.count > 0) {
        [self.lifecycleSink id_attachmentViewsDidLeaveViewport:visible];
    }
    [self.previousAttachmentViews removeAllObjects];
    [self.currentAttachmentViews removeAllObjects];
}

@end

#endif
