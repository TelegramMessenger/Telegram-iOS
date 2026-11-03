#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextRenderingSurfaceView.h"

#include <math.h>

@interface IDTextRenderingSurfaceView ()

@property(nonatomic, strong, nullable, readwrite) NSTextLayoutFragment *layoutFragment;
@property(nonatomic, readwrite) CGPoint containerOrigin;
@property(nonatomic, readwrite) CGSize containerSize;
@property(nonatomic, readwrite) CGRect clipRect;
@property(nonatomic) NSUInteger changeDepth;
@property(nonatomic) BOOL attachmentGeometryNeedsUpdate;
@property(nonatomic) BOOL tornDown;
@property(nonatomic, strong) NSHashTable<UIView *> *attachmentViews;

@end

@implementation IDTextRenderingSurfaceView

- (instancetype)initWithLayoutFragment:(NSTextLayoutFragment *)layoutFragment
                        containerOrigin:(CGPoint)containerOrigin
                         containerSize:(CGSize)containerSize
                              clipRect:(CGRect)clipRect {
    self = [super initWithFrame:CGRectZero];
    if (self == nil) {
        return nil;
    }

    _layoutFragment = layoutFragment;
    _containerOrigin = containerOrigin;
    _containerSize = containerSize;
    _clipRect = clipRect;
    _attachmentViews = [NSHashTable weakObjectsHashTable];
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    __weak IDTextRenderingSurfaceView *weakSelf = self;
    [self registerForTraitChanges:@[UITraitDisplayScale.class]
                     withHandler:^(__kindof id<UITraitEnvironment> environment,
                                   UITraitCollection *previousCollection) {
        [weakSelf id_geometryDidChange];
    }];
    [self id_updateGeometry];
    return self;
}

- (void)performChanges:(dispatch_block_t)changes {
    self.changeDepth += 1;
    @try {
        changes();
    } @finally {
        self.changeDepth -= 1;
        if (self.changeDepth == 0) {
            [self id_updateGeometry];
        }
    }
}

- (void)setContainerOrigin:(CGPoint)containerOrigin {
    if (CGPointEqualToPoint(_containerOrigin, containerOrigin)) {
        return;
    }
    _containerOrigin = containerOrigin;
    [self id_geometryDidChange];
}

- (void)setContainerSize:(CGSize)containerSize {
    if (CGSizeEqualToSize(_containerSize, containerSize)) {
        return;
    }
    _containerSize = containerSize;
}

- (void)setClipRect:(CGRect)clipRect {
    if (CGRectEqualToRect(_clipRect, clipRect)) {
        return;
    }
    _clipRect = clipRect;
    [self id_geometryDidChange];
}

- (void)enumerateTextAttachmentViewsUsingBlock:(IDTextAttachmentEnumerationBlock)block {
    NSTextLayoutFragment *fragment = self.layoutFragment;
    if (fragment.textElement == nil) {
        return;
    }

    for (NSTextAttachmentViewProvider *provider in fragment.textAttachmentViewProviders ?: @[]) {
        UIView *view = provider.view;
        if (view == nil) {
            continue;
        }
        CGRect frame = [fragment frameForTextAttachmentAtLocation:provider.location];
        block(view, frame);
    }
}

- (void)teardown {
    if (self.tornDown) {
        return;
    }
    self.tornDown = YES;
    [self id_removeTextAttachmentViews];
    self.layoutFragment = nil;
    self.layer.contents = nil;
    self.hidden = YES;
    self.frame = CGRectZero;
    self.bounds = CGRectZero;
}

- (void)drawRect:(CGRect)rect {
    NSTextLayoutFragment *fragment = self.layoutFragment;
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (fragment == nil || context == NULL || self.tornDown || self.hidden ||
        fragment.state < NSTextLayoutFragmentStateLayoutAvailable ||
        ![self id_isFiniteRect:fragment.layoutFragmentFrame] ||
        ![self id_isFiniteRect:fragment.renderingSurfaceBounds]) {
        return;
    }

    CGContextSaveGState(context);
    CGContextClipToRect(context, CGRectIntersection(rect, self.bounds));
    [fragment drawAtPoint:CGPointZero inContext:context];
    CGContextRestoreGState(context);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview != nil && !self.tornDown) {
        [self id_updateTextAttachmentGeometry];
    } else if (!self.tornDown) {
        self.attachmentGeometryNeedsUpdate = YES;
    }
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.attachmentGeometryNeedsUpdate && self.superview != nil && !self.tornDown) {
        [self id_updateTextAttachmentGeometry];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    return hitView == self ? nil : hitView;
}

- (void)id_geometryDidChange {
    if (self.changeDepth == 0) {
        [self id_updateGeometry];
    }
}

- (void)id_updateGeometry {
    NSTextLayoutFragment *fragment = self.layoutFragment;
    if (fragment == nil || self.tornDown) {
        return;
    }
    if (fragment.state < NSTextLayoutFragmentStateLayoutAvailable) {
        [self id_installSafeEmptyGeometry];
        return;
    }

    CGRect rawFragmentFrame = fragment.layoutFragmentFrame;
    CGRect rawSurfaceBounds = fragment.renderingSurfaceBounds;
    if (![self id_isFiniteRect:rawFragmentFrame] ||
        ![self id_isFiniteRect:rawSurfaceBounds] ||
        !isfinite(self.containerOrigin.x) || !isfinite(self.containerOrigin.y) ||
        (!CGRectIsNull(self.clipRect) && ![self id_isFiniteRect:self.clipRect])) {
        [self id_installSafeEmptyGeometry];
        return;
    }

    CGRect fragmentFrame = [self id_pixelIntegralRect:rawFragmentFrame];
    CGRect surfaceBounds = CGRectIntegral(rawSurfaceBounds);
    CGRect activeFrame = CGRectOffset(surfaceBounds,
                                      CGRectGetMinX(fragmentFrame) + self.containerOrigin.x,
                                      CGRectGetMinY(fragmentFrame) + self.containerOrigin.y);
    if (!CGRectIsNull(self.clipRect)) {
        CGFloat originalMinimumX = CGRectGetMinX(activeFrame);
        CGFloat clippedMinimumX = MAX(originalMinimumX, CGRectGetMinX(self.clipRect));
        CGFloat clippedMaximumX = MIN(CGRectGetMaxX(activeFrame),
                                      CGRectGetMaxX(self.clipRect));
        CGFloat clippedWidth = clippedMaximumX - clippedMinimumX;
        if (clippedWidth > 0) {
            surfaceBounds.origin.x += clippedMinimumX - originalMinimumX;
            activeFrame.origin.x = clippedMinimumX;
            activeFrame.size.width = clippedWidth;
        }
    }
    activeFrame = [self id_pixelIntegralRect:activeFrame];
    CGRect activeBounds = (CGRect){surfaceBounds.origin, activeFrame.size};
    if (![self id_isFiniteRect:activeFrame] || ![self id_isFiniteRect:activeBounds]) {
        [self id_installSafeEmptyGeometry];
        return;
    }
    self.hidden = NO;
    self.frame = activeFrame;
    self.bounds = activeBounds;
    [self setNeedsDisplay];
}

- (void)id_installSafeEmptyGeometry {
    [self id_removeTextAttachmentViews];
    self.hidden = YES;
    self.frame = CGRectZero;
    self.bounds = CGRectZero;
    [self setNeedsDisplay];
}

- (void)id_removeTextAttachmentViews {
    for (UIView *view in self.attachmentViews.allObjects) {
        [view removeFromSuperview];
    }
    [self.attachmentViews removeAllObjects];
}

- (void)id_updateTextAttachmentGeometry {
    self.attachmentGeometryNeedsUpdate = NO;
    NSMutableSet<UIView *> *current = [NSMutableSet set];
    [self enumerateTextAttachmentViewsUsingBlock:^(UIView *view, CGRect fragmentFrame) {
        [current addObject:view];
        if (view.superview != self) {
            [self addSubview:view];
        }
        view.frame = fragmentFrame;
        [self.attachmentViews addObject:view];
    }];
    for (UIView *view in self.attachmentViews.allObjects) {
        if (![current containsObject:view]) {
            [view removeFromSuperview];
            [self.attachmentViews removeObject:view];
        }
    }
}

- (CGRect)id_pixelIntegralRect:(CGRect)rect {
    if (![self id_isFiniteRect:rect]) {
        return CGRectZero;
    }
    CGFloat scale = self.traitCollection.displayScale;
    if (!(scale > 0) || !isfinite(scale)) {
        scale = 1.0;
    }
    CGFloat minimumX = floor(CGRectGetMinX(rect) * scale) / scale;
    CGFloat minimumY = floor(CGRectGetMinY(rect) * scale) / scale;
    CGFloat maximumX = ceil(CGRectGetMaxX(rect) * scale) / scale;
    CGFloat maximumY = ceil(CGRectGetMaxY(rect) * scale) / scale;
    return CGRectMake(minimumX,
                      minimumY,
                      MAX(maximumX - minimumX, 0),
                      MAX(maximumY - minimumY, 0));
}

- (BOOL)id_isFiniteRect:(CGRect)rect {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

- (BOOL)id_isUsableRect:(CGRect)rect {
    return [self id_isFiniteRect:rect] && !CGRectIsEmpty(rect);
}

@end

#endif
