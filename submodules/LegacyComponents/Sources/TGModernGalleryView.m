#import "TGModernGalleryView.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGHacks.h"

#import <LegacyComponents/TGModernGalleryDefaultInterfaceView.h>
#import <LegacyComponents/TGModernGalleryScrollView.h>

#import <LegacyComponents/TGModernGalleryZoomableScrollViewSwipeGestureRecognizer.h>

static const CGFloat swipeMinimumVelocity = 600.0f;
static const CGFloat swipeVelocityThreshold = 700.0f;
static const CGFloat swipeDistanceThreshold = 128.0f;

@interface TGModernGalleryView () <UIGestureRecognizerDelegate>
{
    CGFloat _itemPadding;
    
    UIView *_scrollViewContainer;
    CGFloat _dismissProgress;
    
    bool _previewMode;
    CGSize _previewSize;
    
    CGFloat _scrollViewVerticalOffset;
    
    UIView *_instantDismissView;
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGModernGalleryView

- (instancetype)initWithFrame:(CGRect)__unused frame
{
    NSAssert(false, @"use designated initializer");
    return nil;
}

- (instancetype)initWithFrame:(CGRect)frame context:(id<LegacyComponentsContext>)context itemPadding:(CGFloat)itemPadding interfaceView:(UIView<TGModernGalleryInterfaceView> *)interfaceView previewMode:(bool)previewMode previewSize:(CGSize)previewSize
{
    _previewMode = previewMode;
    _previewSize = previewSize;
    
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _context = context;
        _itemPadding = itemPadding;
        
        if (@available(iOS 11.0, *)) {
            self.accessibilityIgnoresInvertColors = true;
        }
        
        self.opaque = false;
        self.backgroundColor = UIColorRGBA(0x000000, 1.0f);
        
        CGRect bounds = [self _boundsFrame];
        
        _scrollViewContainer = [[UIView alloc] initWithFrame:bounds];
        [self addSubview:_scrollViewContainer];
        
        _scrollView = [[TGModernGalleryScrollView alloc] initWithFrame:CGRectMake(-_itemPadding, 0.0f, frame.size.width + itemPadding * 2.0f, frame.size.height)];
        if (@available(iOS 11.0, *)) {
            _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        [_scrollViewContainer addSubview:_scrollView];
        
        _interfaceView = interfaceView;
        _interfaceView.frame = bounds;
        _interfaceView.hidden = _previewMode;
        __weak TGModernGalleryView *weakSelf = self;
        _interfaceView.closePressed = ^
        {
            __strong TGModernGalleryView *strongSelf = weakSelf;
            if (strongSelf.transitionOut)
                strongSelf.transitionOut(0.0f);
        };
        _interfaceView.scrollViewOffsetRequested = ^(CGFloat offset)
        {
            __strong TGModernGalleryView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setScrollViewVerticalOffset:offset];
        };
        [self addSubview:_interfaceView];
        
        bool hasSwipeGesture = true;
        if ([interfaceView respondsToSelector:@selector(allowsDismissalWithSwipeGesture)])
            hasSwipeGesture = [interfaceView allowsDismissalWithSwipeGesture];
        
        if (hasSwipeGesture)
        {
            TGModernGalleryZoomableScrollViewSwipeGestureRecognizer *swipeRecognizer = [[TGModernGalleryZoomableScrollViewSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGesture:)];
            swipeRecognizer.delegate = self;
            swipeRecognizer.delaysTouchesBegan = true;
            swipeRecognizer.cancelsTouchesInView = false;
            [_scrollViewContainer addGestureRecognizer:swipeRecognizer];
        }
        
        _overlayContainerView = [[UIView alloc] initWithFrame:self.bounds];
        _overlayContainerView.userInteractionEnabled = false;
        [self addSubview:_overlayContainerView];
    }
    return self;
}

- (bool)shouldAutorotate
{
    return (_dismissProgress < FLT_EPSILON && (_interfaceView == nil || ![_interfaceView respondsToSelector:@selector(shouldAutorotate)] || [_interfaceView shouldAutorotate]));
}

- (CGRect)_boundsFrame
{
    CGRect bounds =  (CGRect){CGPointZero, self.frame.size};
    if (_previewMode)
    {
        bounds.origin.x = floor((_previewSize.width - bounds.size.width) / 2.0f);
        bounds.origin.y = floor((_previewSize.height - bounds.size.height) / 2.0f);
    }
    
    return bounds;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    CGRect bounds = [self _boundsFrame];
    _interfaceView.frame = bounds;
    _scrollViewContainer.frame = bounds;
    _overlayContainerView.frame = bounds;
    
    if (_scrollView != nil) {
        CGRect scrollViewFrame = CGRectMake(-_itemPadding, _scrollViewVerticalOffset, frame.size.width + _itemPadding * 2.0f, frame.size.height);
        if (!CGRectEqualToRect(_scrollView.frame, scrollViewFrame))
        {
            NSInteger currentItemIndex = (NSInteger)(CGFloor((_scrollView.bounds.origin.x + _scrollView.bounds.size.width / 2.0f) / _scrollView.bounds.size.width));
            [_scrollView setFrameAndBoundsInTransaction:scrollViewFrame bounds:CGRectMake(currentItemIndex * scrollViewFrame.size.width, 0.0f, scrollViewFrame.size.width, scrollViewFrame.size.height)];
        }
    }
}

- (void)setScrollViewVerticalOffset:(CGFloat)offset
{
    _scrollViewVerticalOffset = offset;
    
    CGRect scrollViewFrame = _scrollView.frame;
    scrollViewFrame.origin.y = offset;
    _scrollView.frame = scrollViewFrame;
}

- (bool)isInterfaceHidden
{
    if ([_interfaceView allowsHide])
        return _interfaceView.alpha < FLT_EPSILON;
    else
        return true;
}

- (void)showHideInterface
{
    if ([_interfaceView allowsHide])
    {
        if (_interfaceView.alpha > FLT_EPSILON)
        {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _interfaceView.alpha = 0.0f;
                [_context setApplicationStatusBarAlpha:0.0f];
            } completion:nil];
        }
        else
        {
            [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _interfaceView.alpha = 1.0f;
                if (![_interfaceView prefersStatusBarHidden])
                    [_context setApplicationStatusBarAlpha:1.0f];
            } completion:nil];
        }
    }
}

- (void)showInterfaceAnimated
{
    if ([_interfaceView allowsHide])
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _interfaceView.alpha = 1.0f;
            if (![_interfaceView prefersStatusBarHidden])
                [_context setApplicationStatusBarAlpha:1.0f];
        } completion:nil];
    }
}

- (void)hideInterfaceAnimated
{
    if ([_interfaceView allowsHide])
    {
        if (_interfaceView.alpha > FLT_EPSILON)
        {
            [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _interfaceView.alpha = 0.0f;
                [_context setApplicationStatusBarAlpha:0.0f];
            } completion:nil];
        }
    }
}

- (void)updateInterfaceVisibility
{
    if ([_interfaceView allowsHide])
    {
        bool showsOnScroll = false;
        if ([_interfaceView respondsToSelector:@selector(showHiddenInterfaceOnScroll)])
            showsOnScroll = [_interfaceView showHiddenInterfaceOnScroll];
        
        if (showsOnScroll)
            [self showInterfaceAnimated];
    }
}

- (void)addItemHeaderView:(UIView *)itemHeaderView
{
    [_interfaceView addItemHeaderView:itemHeaderView];
}

- (void)removeItemHeaderView:(UIView *)itemHeaderView
{
    [_interfaceView removeItemHeaderView:itemHeaderView];
}

- (void)addItemFooterView:(UIView *)itemFooterView
{
    [_interfaceView addItemFooterView:itemFooterView];
}

- (void)removeItemFooterView:(UIView *)itemFooterView
{
    [_interfaceView removeItemFooterView:itemFooterView];
}

- (BOOL)gestureRecognizerShouldBegin1:(UIGestureRecognizer *)__unused gestureRecognizer
{
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return false;
}

- (CGFloat)dismissProgressForSwipeDistance:(CGFloat)distance
{
    return MAX(0.0f, MIN(1.0f, ABS(distance / 150.0f)));
}

- (void)swipeGesture:(TGModernGalleryZoomableScrollViewSwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateChanged)
    {
        _dismissProgress = [self dismissProgressForSwipeDistance:[recognizer swipeDistance]];
        [self _updateDismissTransitionWithProgress:_dismissProgress manual:true animated:false];
        [self _updateDismissTransitionMovementWithDistance:[recognizer swipeDistance] animated:false];
    }
    else if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        CGFloat swipeVelocity = [recognizer swipeVelocity];
        if (ABS(swipeVelocity) < swipeMinimumVelocity)
            swipeVelocity = (swipeVelocity < 0.0f ? -1.0f : 1.0f) * swipeMinimumVelocity;
        
        if ((ABS(swipeVelocity) < swipeVelocityThreshold && ABS([recognizer swipeDistance]) < swipeDistanceThreshold) ||  !_transitionOut || !_transitionOut(swipeVelocity))
        {
            _dismissProgress = 0.0f;
            [self _updateDismissTransitionWithProgress:0.0f manual:false animated:true];
            [self _updateDismissTransitionMovementWithDistance:0.0f animated:true];
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateCancelled)
    {
        _dismissProgress = 0.0f;
        [self _updateDismissTransitionWithProgress:0.0f manual:false animated:true];
        [self _updateDismissTransitionMovementWithDistance:0.0f animated:true];
    }
}

- (void)_updateDismissTransitionMovementWithDistance:(CGFloat)distance animated:(bool)animated
{
    CGRect scrollViewFrame = (CGRect){{_scrollView.frame.origin.x, distance}, _scrollView.frame.size};
    if (animated)
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            _scrollView.frame = scrollViewFrame;
        }];
    }
    else
        _scrollView.frame = scrollViewFrame;
}

- (void)_updateDismissTransitionWithProgress:(CGFloat)progress animated:(bool)animated
{
    [self _updateDismissTransitionWithProgress:progress manual:false animated:animated];
}

- (void)_updateDismissTransitionWithProgress:(CGFloat)progress manual:(bool)manual animated:(bool)animated
{
    CGFloat alpha = 1.0f - MAX(0.0f, MIN(1.0f, progress * 4.0f));
    CGFloat transitionProgress = MAX(0.0f, MIN(1.0f, progress * 2.0f));
    UIColor *backgroundColor = UIColorRGBA(0x000000, alpha);
    
    if (animated)
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            self.backgroundColor = backgroundColor;
            [_interfaceView setTransitionOutProgress:transitionProgress manual:manual];
        }];
    }
    else
    {
        self.backgroundColor = backgroundColor;
        [_interfaceView setTransitionOutProgress:transitionProgress manual:manual];
    }
    
    if (self.transitionProgress != nil)
        self.transitionProgress(transitionProgress, manual);
}

- (void)simpleTransitionInWithCompletion:(void (^)())completion
{
    CGFloat velocity = 2000.0f;
    CGFloat distance = (velocity < FLT_EPSILON ? -1.0f : 1.0f) * self.frame.size.height;
    
    CGRect targetFrame = _scrollView.frame;
    CGRect targetInterfaceFrame = _interfaceView.frame;
    CGRect interfaceViewFrame = (CGRect){{_interfaceView.frame.origin.x, distance}, _interfaceView.frame.size};
    CGRect scrollViewFrame = (CGRect){{_scrollView.frame.origin.x, distance}, _scrollView.frame.size};
    _interfaceView.frame = interfaceViewFrame;
    _scrollView.frame = scrollViewFrame;
    _overlayContainerView.alpha = 0.0f;
    self.backgroundColor = UIColorRGBA(0x000000, 0.0f);
    
    [UIView animateWithDuration:ABS(distance / velocity) delay:0.0 options:7 << 16 animations:^{
        _scrollView.frame = targetFrame;
        _interfaceView.frame = targetInterfaceFrame;
    } completion:^(__unused BOOL finished)
    {
        if (completion)
            completion();
    }];
    
    [UIView animateWithDuration:ABS(distance / velocity) animations:^
    {
        _overlayContainerView.alpha = 1.0f;
        self.backgroundColor = UIColorRGBA(0x000000, 1.0f);
    } completion:nil];
}

- (void)simpleTransitionOutWithVelocity:(CGFloat)velocity completion:(void (^)())completion
{
    const CGFloat minVelocity = 2000.0f;
    if (ABS(velocity) < minVelocity)
        velocity = (velocity < 0.0f ? -1.0f : 1.0f) * minVelocity;
    CGFloat distance = (velocity < FLT_EPSILON ? -1.0f : 1.0f) * self.frame.size.height;
    CGRect interfaceViewFrame = (CGRect){{_interfaceView.frame.origin.x, distance}, _interfaceView.frame.size};
    CGRect scrollViewFrame = (CGRect){{_scrollView.frame.origin.x, distance}, _scrollView.frame.size};
    
    [UIView animateWithDuration:ABS(distance / velocity) delay:0.0 options:7 << 16 animations:^{
        _scrollView.frame = scrollViewFrame;
        _interfaceView.frame = interfaceViewFrame;
    } completion:^(__unused BOOL finished)
    {
        if (completion)
            completion();
    }];
    
    [UIView animateWithDuration:0.15 animations:^{
        _interfaceView.alpha = 0.0f;
        _overlayContainerView.alpha = 0.0f;
    }];
    
    [UIView animateWithDuration:0.35 animations:^{
        self.backgroundColor = UIColorRGBA(0x000000, 0.0f);
    }];
}

- (void)transitionInWithDuration:(NSTimeInterval)duration
{
    _interfaceView.alpha = 0.0f;
    _overlayContainerView.alpha = 0.0f;
    self.backgroundColor = UIColorRGBA(0x000000, 0.0f);
    [UIView animateWithDuration:duration delay:0.0 options:0 animations:^
    {
        _interfaceView.alpha = 1.0f;
        _overlayContainerView.alpha = 1.0f;
        self.backgroundColor = UIColorRGBA(0x000000, 1.0f);
    } completion:nil];
}

- (void)transitionOutWithDuration:(NSTimeInterval)duration
{
    [UIView animateWithDuration:duration animations:^
    {
        _interfaceView.alpha = 0.0f;
        _overlayContainerView.alpha = 0.0f;
        self.backgroundColor = UIColorRGBA(0x000000, 0.0f);
    }];
}

- (void)fadeOutWithDuration:(NSTimeInterval)duration completion:(void (^)(void))completion
{
    [UIView animateWithDuration:duration animations:^
    {
        _interfaceView.alpha = 0.0f;
        _scrollView.alpha = 0.0f;
        _overlayContainerView.alpha = 0.0f;
        self.backgroundColor = UIColorRGBA(0x000000, 0.0f);
    } completion:^(__unused BOOL finished)
    {
        if (completion)
            completion();
    }];
}

- (void)setPreviewMode:(bool)previewMode
{
    _previewMode = previewMode;
    _interfaceView.hidden = previewMode;
    
    if (_scrollViewContainer != nil)
    {
        CGRect bounds = [self _boundsFrame];
        _interfaceView.frame = bounds;
        _scrollViewContainer.frame = bounds;
    }
}

- (void)enableInstantDismiss {
    _instantDismissView = [[UIView alloc] initWithFrame:self.bounds];
    _instantDismissView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_instantDismissView];
    [_instantDismissView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(instantDismissViewTap:)]];
}

- (void)disableInstantDismiss
{
    [_instantDismissView removeFromSuperview];
    _instantDismissView = nil;
}

- (void)instantDismissViewTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (_instantDismiss) {
            _instantDismiss();
        }
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (_instantDismissView != nil && CGRectContainsPoint(_instantDismissView.frame, point)) {
        return _instantDismissView;
    }
    return [super hitTest:point withEvent:event];
}

@end
