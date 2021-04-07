#import "TGPhotoCropView.h"

#import "LegacyComponentsInternal.h"

#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "TGPhotoCropScrollView.h"
#import "TGPhotoCropAreaView.h"
#import "TGPhotoCropRotationView.h"

const CGFloat TGPhotoCropViewOverscreenSize = 1000;

@interface TGPhotoCropView () <UIScrollViewDelegate>
{
    CGSize _originalSize;

    STimer *_confirmTimer;
    bool _animatingConfirm;
    bool _cropAreaChanged;
    
    UIView *_overlayWrapperView;
    UIView *_topOverlayView;
    UIView *_leftOverlayView;
    UIView *_rightOverlayView;
    UIView *_bottomOverlayView;
    
    UIControl *_areaWrapperView;
    TGPhotoCropAreaView *_areaView;
    CGRect _previousAreaFrame;
    
    TGPhotoCropScrollView *_scrollView;
    UIView *_contentWrapperView;
    UIVisualEffectView *_blurView;
    UIImageView *_imageView;
    UIView *_snapshotView;
    CGSize _snapshotSize;
    UIImageView *_paintingImageView;
    UIView *_entitiesView;
    
    UIImage *_paintingImage;
    
    bool _hasArbitraryRotation;
    bool _animatingRotation;
    UIView *_rotationSnapshotView;
    TGPhotoCropRotationView *_rotationView;
    
    UIInterfaceOrientation _previousInterfaceOrientation;
}
@end

@implementation TGPhotoCropView


- (instancetype)initWithOriginalSize:(CGSize)originalSize hasArbitraryRotation:(bool)hasArbitraryRotation
{
    self = [self initWithFrame:CGRectZero];
    if (self != nil)
    {
        _hasArbitraryRotation = hasArbitraryRotation;
        
        _originalSize = originalSize;
        _cropRect = CGRectMake(0.0f, 0.0f, originalSize.width, originalSize.height);
        _cropOrientation = UIImageOrientationUp;
        
        __weak TGPhotoCropView *weakSelf = self;
        
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -100, -100, -100);
        
        _areaWrapperView = [[UIControl alloc] initWithFrame:CGRectZero];
        _areaWrapperView.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -100, -100, -100);
        [self addSubview:_areaWrapperView];
        
        _scrollView = [[TGPhotoCropScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.shouldBeginChanging = ^bool
        {
            __strong TGPhotoCropView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return true;
            
            return !strongSelf->_animatingConfirm && !strongSelf->_areaView.isTracking && !strongSelf->_rotationView.isTracking;
        };
        _scrollView.didBeginChanging = ^
        {
            __strong TGPhotoCropView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf resetBackdropViewsAnimated:true];
            [strongSelf cancelConfirmCountdown];
            [strongSelf->_areaView setGridMode:TGPhotoCropViewGridModeMajor animated:true];
            
            [strongSelf->_scrollView resetRotationStartValues];
            
            if (strongSelf.interactionBegan != nil)
                strongSelf.interactionBegan();
        };
        _scrollView.didEndChanging = ^
        {
            __strong TGPhotoCropView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf startConfirmCountdown];
            
            if (strongSelf.croppingChanged != nil)
                strongSelf.croppingChanged();
        };
        [_areaWrapperView addSubview:_scrollView];
        
        if (iosMajorVersion() >= 9)
        {
            _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
            _blurView.alpha = 0.0f;
            _blurView.userInteractionEnabled = false;
            [_areaWrapperView addSubview:_blurView];
        }
        
        _overlayWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        _overlayWrapperView.userInteractionEnabled = false;
        [_areaWrapperView addSubview:_overlayWrapperView];
        
        UIColor *overlayColor = iosMajorVersion() >= 9 ? UIColorRGBA(0x000000, 0.45f) : [TGPhotoEditorInterfaceAssets cropTransparentOverlayColor];
        _topOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _topOverlayView.backgroundColor = overlayColor;
        [_overlayWrapperView addSubview:_topOverlayView];
        
        _leftOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _leftOverlayView.backgroundColor = overlayColor;
        [_overlayWrapperView addSubview:_leftOverlayView];
        
        _rightOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _rightOverlayView.backgroundColor = overlayColor;
        [_overlayWrapperView addSubview:_rightOverlayView];
        
        _bottomOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _bottomOverlayView.backgroundColor = overlayColor;
        [_overlayWrapperView addSubview:_bottomOverlayView];
        
        _areaView = [[TGPhotoCropAreaView alloc] initWithFrame:self.bounds];
        _areaView.shouldBeginEditing = ^bool
        {
            __strong TGPhotoCropView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return true;
            
            return !strongSelf->_animatingConfirm && !strongSelf->_scrollView.isTracking && !strongSelf->_rotationView.isTracking;
        };
        _areaView.didBeginEditing = ^
        {
            __strong TGPhotoCropView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_previousAreaFrame = strongSelf->_areaView.frame;
            
            [strongSelf resetBackdropViewsAnimated:false];
            [strongSelf cancelConfirmCountdown];
            [strongSelf->_areaView setGridMode:TGPhotoCropViewGridModeMajor animated:true];
            [strongSelf setIntefaceHidden:true animated:true];

            [strongSelf->_scrollView resetRotationStartValues];
            
            if (strongSelf.interactionBegan != nil)
                strongSelf.interactionBegan();
        };
        _areaView.didEndEditing = ^
        {
            __strong TGPhotoCropView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf startConfirmCountdown];
        };
        _areaView.areaChanged = ^
        {
            __strong TGPhotoCropView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf handleCropAreaChanged];
        };
        [_areaWrapperView addSubview:_areaView];
        
        if (_hasArbitraryRotation)
        {
            _rotationView = [[TGPhotoCropRotationView alloc] initWithFrame:CGRectZero];
            _rotationView.hitTestEdgeInsets = UIEdgeInsetsMake(10, 10, 0, 10);
            [self addSubview:_rotationView];
            
            _rotationView.shouldBeginChanging = ^bool
            {
                __strong TGPhotoCropView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return true;
                
                return !strongSelf->_animatingConfirm && !strongSelf->_scrollView.isTracking && !strongSelf->_areaView.isTracking;
            };
            _rotationView.didBeginChanging = ^
            {
                __strong TGPhotoCropView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf resetBackdropViewsAnimated:true];
                [strongSelf cancelConfirmCountdown];
                [strongSelf->_areaView setGridMode:TGPhotoCropViewGridModeMinor animated:true];
                
                [strongSelf->_scrollView storeRotationStartValues];
                
                if (strongSelf.interactionBegan != nil)
                    strongSelf.interactionBegan();
            };
            
            _rotationView.didEndChanging = ^
            {
                __strong TGPhotoCropView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf startConfirmCountdown];
                [strongSelf->_areaView setGridMode:TGPhotoCropViewGridModeNone animated:true];
                
                if (strongSelf.croppingChanged != nil)
                    strongSelf.croppingChanged();
                
                if (strongSelf.interactionEnded != nil)
                    strongSelf.interactionEnded();
            };
            
            _rotationView.angleChanged = ^(CGFloat angle, bool resetting)
            {
                __strong TGPhotoCropView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf setRotation:angle resetting:resetting];
            };
        }
    }
    return self;
}

- (void)dealloc
{
    if (_confirmTimer != nil)
    {
        [_confirmTimer invalidate];
        _confirmTimer = nil;
    }
}

#pragma mark - Transition

- (void)animateTransitionIn
{
    _scrollView.hidden = true;
    _overlayWrapperView.alpha = 0.0f;
    _areaView.alpha = 0.0f;
    _rotationView.alpha = 0.0f;
}

- (void)animateTransitionOut
{
    if (_confirmTimer != nil)
    {
        [_confirmTimer invalidate];
        _confirmTimer = nil;
    }
    
    _scrollView.hidden = true;
    _blurView.hidden = true;
    [UIView animateWithDuration:0.1f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^
    {
        _areaView.alpha = 0.0f;
        _rotationView.alpha = 0.0f;
    } completion:nil];
    
    _overlayWrapperView.alpha = 0.0f;
}

- (void)transitionInFinishedAnimated:(bool)animated completion:(void (^)(void))completion
{
    _overlayWrapperView.alpha = 1.0f;
    
    _scrollView.hidden = false;

    if (animated)
        _scrollView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.35f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
    {
        if (animated)
            _scrollView.alpha = 1.0f;
        _areaView.alpha = 1.0f;
        _rotationView.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
    
    [self showBackdropViewAnimated:false];
}

- (bool)isAnimating
{
    return _animatingConfirm || _animatingRotation || _scrollView.animating;
}

- (bool)isAnimatingRotation
{
    return _animatingRotation;
}

#pragma mark - Setup

- (void)setup
{
    _contentWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _originalSize.width, _originalSize.height)];
    
    _scrollView.contentSize = _originalSize;
    [_scrollView setContentView:_contentWrapperView];
    
    _imageView = [[UIImageView alloc] initWithFrame:_contentWrapperView.bounds];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_contentWrapperView addSubview:_imageView];
    
    _scrollView.imageView = _imageView;
    
    [self _layoutAreaViewAnimated:false completion:nil];
    [self _zoomToCropRectWithFrame:_scrollView.bounds animated:false completion:nil];
    
    if (_snapshotView != nil)
    {
        CGAffineTransform transform = _contentWrapperView.transform;
        _contentWrapperView.transform = CGAffineTransformIdentity;
        
        CGRect rotatedRect = [_contentWrapperView convertRect:_scrollView.bounds fromView:_scrollView];
        CGRect frame = [_scrollView zoomedRect];

        _snapshotView.frame = frame;
        _snapshotView.center = CGPointMake(CGRectGetMidX(rotatedRect), CGRectGetMidY(rotatedRect));
        _snapshotView.transform = CGAffineTransformRotate(_snapshotView.transform, -self.rotation);
        [_contentWrapperView addSubview:_snapshotView];
        
        _contentWrapperView.transform = transform;
    }
    
    if (_paintingImage != nil)
    {
        _paintingImageView = [[UIImageView alloc] initWithFrame:_imageView.frame];
        _paintingImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _paintingImageView.image = _paintingImage;
        [_contentWrapperView addSubview:_paintingImageView];
        
        [_scrollView setPaintingImage:_paintingImage];
    }
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    [_imageView setImage:image];
    
    [_snapshotView removeFromSuperview];
    _snapshotView = nil;
}

- (void)setSnapshotImage:(UIImage *)snapshotImage
{
    [_snapshotView removeFromSuperview];
    
    _snapshotSize = snapshotImage.size;
    
    UIImageView *imageSnapshotView = [[UIImageView alloc] initWithImage:snapshotImage];
    _snapshotView = imageSnapshotView;
}

- (void)setSnapshotView:(UIView *)snapshotView
{
    [_snapshotView removeFromSuperview];
    _snapshotView = snapshotView;
}

- (void)setPaintingImage:(UIImage *)paintingImage
{
    _paintingImage = paintingImage;
    
    if (_paintingImageView != nil)
    {
        _paintingImageView.hidden = (paintingImage == nil);
        _paintingImageView.image = paintingImage;
    }
}

- (void)setEntitiesView:(UIView *)entitiesView
{
    _entitiesView = entitiesView;
}

#pragma mark - Crop Area

- (void)handleCropAreaChanged
{
    _cropAreaChanged = true;
    
    _areaView.frame = [self _cappedAreaViewRectWithRect:_areaView.frame];
    
    CGPoint translationOffset = CGPointMake(_previousAreaFrame.origin.x - _areaView.frame.origin.x,
                                            _previousAreaFrame.origin.y - _areaView.frame.origin.y);
    
    [_scrollView translateContentViewWithOffset:translationOffset];
    _previousAreaFrame = _areaView.frame;
    
    _scrollView.frame = _areaView.frame;
    [_scrollView fitContentInsideBoundsAllowScale:true animated:false completion:nil];
    
    [self _layoutRotationView];
    
    [self _layoutOverlayViewsWithFrame:_areaView.frame animated:false];
}

- (CGRect)_cappedAreaViewRectWithRect:(CGRect)cropRect
{
    CGRect cappedRect = [self convertRect:cropRect fromView:_areaWrapperView];
    CGFloat aspectRatio = _lockedAspectRatio;
    if (aspectRatio > 0 && (_cropOrientation == UIImageOrientationLeft || _cropOrientation == UIImageOrientationRight))
        aspectRatio = 1.0f / aspectRatio;
    
    if (CGRectGetMaxX(cappedRect) > self.frame.size.width)
    {
        cappedRect.origin.x = MIN(self.frame.size.width - TGPhotoCropCornerControlSize.width, cappedRect.origin.x);
        cappedRect.size.width = MAX(TGPhotoCropCornerControlSize.width, self.frame.size.width - cappedRect.origin.x);
        if (aspectRatio > 0)
            cappedRect.size.height = cappedRect.size.width * aspectRatio;
    }
    else if (CGRectGetMinX(cappedRect) < 0)
    {
        cappedRect.size.width = CGRectGetMaxX(cappedRect);
        if (aspectRatio > 0)
            cappedRect.size.height = cappedRect.size.width * aspectRatio;
        cappedRect.origin.x = 0;
    }
    
    if (CGRectGetMaxY(cappedRect) > self.frame.size.height)
    {
        cappedRect.origin.y = MIN(self.frame.size.height - TGPhotoCropCornerControlSize.height, cappedRect.origin.y);
        cappedRect.size.height = MAX(TGPhotoCropCornerControlSize.height, self.frame.size.height - cappedRect.origin.y);
        if (aspectRatio > 0)
            cappedRect.size.width = cappedRect.size.height / aspectRatio;
    }
    else if (CGRectGetMinY(cappedRect) < 0)
    {
        cappedRect.size.height = CGRectGetMaxY(cappedRect);
        if (aspectRatio > 0)
            cappedRect.size.width = cappedRect.size.height / aspectRatio;
        cappedRect.origin.y = 0;
    }
    
    return [self convertRect:cappedRect toView:_areaWrapperView];
}

#pragma mark - Backdrop

- (void)_layoutBackdrop
{
    if (iosMajorVersion() < 9 || _imageView.image == nil)
        return;
    
    UIView *superview = self.superview.superview;
    _blurView.frame = [superview convertRect:superview.bounds toView:_blurView.superview];
    
    UIView *snapshotView = [_scrollView setSnapshotViewEnabled:true];
    snapshotView.frame = _scrollView.frame;
    [_areaWrapperView insertSubview:snapshotView aboveSubview:_blurView];
}

- (void)showBackdropViewAnimated:(bool)animated
{
    if (iosMajorVersion() < 9 || _imageView.image == nil)
        return;
    
    [self _layoutBackdrop];
    
    if (animated)
    {
        [UIView animateWithDuration:0.16f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            _blurView.alpha = 1.0f;
        } completion:nil];
    }
    else
    {
        _blurView.alpha = 1.0f;
    }
}

- (void)resetBackdropViewsAnimated:(bool)animated
{
    if (iosMajorVersion() < 9)
        return;
    
    if (animated)
    {
        if (_blurView.alpha == 0)
        {
            [_scrollView setSnapshotViewEnabled:false];
            return;
        }
        
        [UIView animateWithDuration:0.16f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            _blurView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                [_scrollView setSnapshotViewEnabled:false];
        }];
    }
    else
    {
        [_scrollView setSnapshotViewEnabled:false];
        _blurView.alpha = 0.0f;
    }
}

#pragma mark - Area Confirmation

- (void)startConfirmCountdown
{
    if (_areaView.isTracking)
        return;
    
    __weak TGPhotoCropView *weakSelf = self;
    
    _confirmTimer = [[STimer alloc] initWithTimeout:1.0f repeat:false completion:^
    {
        __strong TGPhotoCropView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf performConfirmAnimated:true];
    } nativeQueue:dispatch_get_main_queue()];
    [_confirmTimer start];
}

- (void)cancelConfirmCountdown
{
    [_confirmTimer invalidate];
    _confirmTimer = nil;
}

- (void)performConfirmAnimated:(bool)animated
{
    [self performConfirmAnimated:animated updateInterface:true];
}

- (void)performConfirmAnimated:(bool)animated updateInterface:(bool)updateInterface
{
    if (_areaView.isTracking || _animatingConfirm)
        return;
    
    [_confirmTimer invalidate];
    _confirmTimer = nil;
    
    _cropRect = [_scrollView zoomedRect];
    CGSize minimumSizes = CGSizeMake(_originalSize.width / _scrollView.maximumZoomScale, _originalSize.height / _scrollView.maximumZoomScale);
    
    CGRect constrainedCropRect = _cropRect;
    if (_cropRect.size.width < minimumSizes.width && _cropRect.size.height < minimumSizes.height)
    {
        if (_cropRect.size.width > _cropRect.size.height)
        {
            constrainedCropRect.size.width = minimumSizes.width;
            constrainedCropRect.size.height = _cropRect.size.height * constrainedCropRect.size.width / _cropRect.size.width;
        }
        else
        {
            constrainedCropRect.size.height = minimumSizes.height;
            constrainedCropRect.size.width = _cropRect.size.width * constrainedCropRect.size.height / _cropRect.size.height;
        }
        
        CGSize rotatedContentSize = TGRotatedContentSize(_scrollView.contentSize, _scrollView.contentRotation);
        if (CGRectGetMaxX(constrainedCropRect) > rotatedContentSize.width)
            constrainedCropRect.origin.x = rotatedContentSize.width - constrainedCropRect.size.width;

        if (CGRectGetMaxY(constrainedCropRect) > rotatedContentSize.height)
            constrainedCropRect.origin.y = rotatedContentSize.height - constrainedCropRect.size.height;
    }
    _cropRect = constrainedCropRect;
    
    [_areaView setGridMode:TGPhotoCropViewGridModeNone animated:animated];
    
    if (updateInterface)
    {
        [self setIntefaceHidden:false animated:animated];
    }
    else
    {
        if (_rotationView.hidden)
            [self setCropAreaHidden:true animated:false];
    }
    
    if (!_cropAreaChanged)
    {
        [self showBackdropViewAnimated:animated];
        
        if (self.croppingChanged != nil)
            self.croppingChanged();
        
        if (self.interactionEnded != nil)
            self.interactionEnded();
        
        return;
    }
    
    _cropAreaChanged = false;
    
    [self evenlyFillAreaViewAnimated:animated reset:false completion:^
    {
        if (self.interactionEnded != nil)
            self.interactionEnded();
    }];
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

- (void)evenlyFillAreaViewAnimated:(bool)animated reset:(bool)reset completion:(void (^)(void))completion
{
    if (animated)
    {
        [self _layoutRotationView];
        
        _animatingConfirm = true;
        
        NSMutableSet *animations = [NSMutableSet set];
        void (^onAnimationCompletion)(id) = ^(id object)
        {
            [animations removeObject:object];
            
            if (animations.count == 0)
            {
                _animatingConfirm = false;
                
                [_scrollView fitContentInsideBoundsAllowScale:false animated:true completion:^
                {
                    [self showBackdropViewAnimated:true];
                    
                    if (completion != nil)
                        completion();
                }];
            }
        };
        
        [animations addObject:@1];
        CGRect frame = [self _layoutAreaViewAnimated:true completion:^
        {
            onAnimationCompletion(@1);
        }];
        
        if (reset)
        {
            [animations addObject:@2];
            [_scrollView resetAnimatedWithFrame:frame completion:^
            {
                onAnimationCompletion(@2);
            }];
        }
        else
        {
            [animations addObject:@2];
            [self _zoomToCropRectWithFrame:frame animated:true completion:^
            {
                onAnimationCompletion(@2);
            }];
        }
    }
    else
    {
        [self _layoutAreaViewAnimated:false completion:nil];
        if (reset)
            [_scrollView reset];
        else
            [self _zoomToCropRectWithFrame:_scrollView.bounds animated:false completion:nil];
        [self showBackdropViewAnimated:true];

        if (completion != nil)
            completion();
    }
}

- (void)setCropAreaHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _areaView.hidden = false;
        [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            _areaView.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                _areaView.hidden = hidden;
        }];
    }
    else
    {
        _areaView.hidden = hidden;
        _areaView.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)setIntefaceHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _rotationView.hidden = false;
        [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            _rotationView.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                _rotationView.hidden = hidden;
        }];
    }
    else
    {
        _rotationView.hidden = hidden;
        _rotationView.alpha = hidden ? 0.0f : 1.0f;
    }
}

#pragma mark - Cropping

- (UIView *)cropSnapshotView
{
    bool update = false;
    if (_imageView.alpha < FLT_EPSILON)
    {
        _imageView.alpha = 1.0f;
        update = true;
    }
    UIView *snapshotView = [_scrollView snapshotViewAfterScreenUpdates:update];
    snapshotView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(_cropOrientation));
    return snapshotView;
}

- (CGRect)cropRectFrameForView:(UIView *)view
{
    return [_areaWrapperView convertRect:_scrollView.frame toView:view];
}

- (UIImage *)croppedImageWithMaxSize:(CGSize)maxSize
{
    return TGPhotoEditorVideoCrop(_imageView.image, _paintingImage, self.cropOrientation, self.rotation, self.cropRect, self.mirrored, maxSize, _originalSize, true, true);
}

#pragma mark - Rotation

- (bool)hasArbitraryRotation
{
    return (_rotationView != nil);
}

- (void)setRotation:(CGFloat)rotation
{
    [_rotationView setAngle:rotation];
    [self setRotation:rotation resetting:false];
}

- (void)setRotation:(CGFloat)rotation resetting:(bool)resetting
{
    _rotation = rotation;
    [_scrollView setContentRotation:rotation maximize:true resetting:resetting];
}

- (void)setRotation:(CGFloat)rotation animated:(bool)animated
{
    [_rotationView setAngle:rotation animated:animated];
}

- (void)setMirrored:(bool)mirrored
{
    _mirrored = mirrored;
    [_scrollView setContentMirrored:mirrored];
}

- (void)rotate90DegreesCCWAnimated:(bool)animated
{
    if (_animatingConfirm || _scrollView.animating)
        return;
    
    [self cancelConfirmCountdown];
    
    UIView *snapshotView = nil;
    
    if (_rotationSnapshotView != nil)
    {
        snapshotView = _rotationSnapshotView;
    }
    else
    {
        if (animated)
        {
            snapshotView = [self cropSnapshotView];
            snapshotView.transform = _areaWrapperView.transform;
            snapshotView.frame = [self convertRect:_scrollView.frame fromView:_areaWrapperView];
            [self addSubview:snapshotView];
            
            _rotationSnapshotView = snapshotView;
        }
        
        _cropRect = [_scrollView zoomedRect];
    }

    _scrollView.hidden = true;
    
    [self resetBackdropViewsAnimated:false];
    
    [self setIntefaceHidden:true animated:false];
    [self setCropAreaHidden:true animated:false];
    
    [_scrollView resetRotationStartValues];
    
    self.cropOrientation = TGNextCCWOrientationForOrientation(self.cropOrientation);
    
    CGSize areaSize = [self _areaSizeForCropRect:_cropRect orientation:_cropOrientation];
    CGRect areaBounds = CGRectMake(0, 0, areaSize.width, areaSize.height);
    if (self.cropOrientation == UIImageOrientationLeft || self.cropOrientation == UIImageOrientationRight)
        areaBounds = CGRectMake(0, 0, areaSize.height, areaSize.width);
    
    _areaWrapperView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
    
    if (animated)
    {
        _animatingRotation = true;
        
        POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
        centerAnimation.fromValue = [NSValue valueWithCGPoint:snapshotView.center];
        centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)];
        centerAnimation.springSpeed = 7;
        centerAnimation.springBounciness = 1;
        [snapshotView pop_addAnimation:centerAnimation forKey:@"center"];
        
        POPSpringAnimation *boundsAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewBounds];
        boundsAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.bounds];
        boundsAnimation.toValue = [NSValue valueWithCGRect:areaBounds];
        boundsAnimation.springSpeed = 7;
        boundsAnimation.springBounciness = 1;
        [snapshotView pop_addAnimation:boundsAnimation forKey:@"bounds"];
        
        CGFloat currentRotation = [[snapshotView.layer valueForKeyPath:@"transform.rotation.z"] floatValue];
        CGFloat targetRotation = TGRotationForOrientation(self.cropOrientation);
        if (fabs(currentRotation - targetRotation) > M_PI)
            targetRotation = -2 * (CGFloat)M_PI + targetRotation;
            
        POPSpringAnimation *rotationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
        rotationAnimation.fromValue = @(currentRotation);
        rotationAnimation.toValue = @(targetRotation);
        rotationAnimation.springSpeed = 7;
        rotationAnimation.springBounciness = 1;
        [snapshotView.layer pop_addAnimation:rotationAnimation forKey:@"rotation"];
        
        [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
        {
            if (!allFinished)
                return;
            
            _animatingRotation = false;
            
            [snapshotView removeFromSuperview];
            if (_rotationSnapshotView == snapshotView)
                _rotationSnapshotView = nil;
            
            _areaWrapperView.backgroundColor = [UIColor clearColor];
            
            [self evenlyFillAreaViewAnimated:false reset:false completion:nil];
            
            _scrollView.hidden = false;
            [self setIntefaceHidden:false animated:true];
            [self setCropAreaHidden:false animated:true];
            
            [self showBackdropViewAnimated:false];
            _blurView.alpha = 0.0f;
            _imageView.alpha = 0.0f;
            [UIView animateWithDuration:0.16f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
                _blurView.alpha = 1.0f;
            } completion:^(__unused BOOL finished)
            {
                _imageView.alpha = 1.0f;
            }];
        } whenCompletedAllAnimations:@[ centerAnimation, boundsAnimation, rotationAnimation ]];
    }
    else
    {
        [snapshotView removeFromSuperview];
        if (_rotationSnapshotView == snapshotView)
            _rotationSnapshotView = nil;
        
        _areaWrapperView.backgroundColor = [UIColor clearColor];
        
        [self _layoutAreaViewAnimated:false completion:nil];
        [self _zoomToCropRectWithFrame:_scrollView.bounds animated:false completion:nil];
        
        _scrollView.hidden = false;
        [self setIntefaceHidden:false animated:false];
        [self setCropAreaHidden:false animated:false];
        
        [self showBackdropViewAnimated:false];
    }
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

#pragma mark - 

- (void)mirror
{
    if (_animatingConfirm || _scrollView.animating)
        return;
    
    [self cancelConfirmCountdown];
    
    self.cropRect = [_scrollView zoomedRect];
    self.mirrored = !self.mirrored;
    
    [self resetBackdropViewsAnimated:false];
    [_scrollView setContentMirrored:self.mirrored];
    [self showBackdropViewAnimated:false];
    
    [self _layoutAreaViewAnimated:false completion:nil];
    [self _zoomToCropRectWithFrame:_scrollView.bounds animated:false completion:nil];
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

#pragma mark - Aspect Ratio Lock

- (void)setLockedAspectRatio:(CGFloat)aspectRatio performResize:(bool)performResize animated:(bool)animated
{
    _lockedAspectRatio = aspectRatio;
    
    _areaView.lockAspectRatio = true;
    _areaView.aspectRatio = aspectRatio;
    
    if (!performResize)
        return;
    
    CGPoint currentCenter = CGPointMake(CGRectGetMidX(_cropRect), CGRectGetMidY(_cropRect));
    CGRect availableRect = [_scrollView availableRect];
    CGRect newCropRect = _cropRect;
    newCropRect.size.height = newCropRect.size.width * aspectRatio;
    
    if (newCropRect.size.height > availableRect.size.height)
    {
        newCropRect.size.height = availableRect.size.height;
        newCropRect.size.width = newCropRect.size.height / aspectRatio;
    }
    
    newCropRect.origin.x = currentCenter.x - newCropRect.size.width / 2;
    newCropRect.origin.y = currentCenter.y - newCropRect.size.height / 2;
    
    if (newCropRect.origin.x < availableRect.origin.x)
        newCropRect.origin.x = availableRect.origin.x;
    
    if (newCropRect.origin.y < availableRect.origin.y)
        newCropRect.origin.y = availableRect.origin.y;
    
    if (CGRectGetMaxX(newCropRect) > CGRectGetMaxX(availableRect))
        newCropRect.origin.x = CGRectGetMaxX(availableRect) - newCropRect.size.width;
    
    if (CGRectGetMaxY(newCropRect) > CGRectGetMaxY(availableRect))
        newCropRect.origin.y = CGRectGetMaxY(availableRect) - newCropRect.size.height;
    
    if (!_CGRectEqualToRectWithEpsilon(newCropRect, _cropRect, [self _cropRectEpsilon]))
         [self resetBackdropViewsAnimated:false];
    
    _cropRect = newCropRect;
    
    [self evenlyFillAreaViewAnimated:animated reset:false completion:nil];
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

- (void)unlockAspectRatio
{
    _lockedAspectRatio = 0;
    _areaView.lockAspectRatio = false;
    _areaView.aspectRatio = 0;
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

- (bool)isAspectRatioLocked
{
    return (_lockedAspectRatio > FLT_EPSILON);
}

- (CGFloat)_cropRectEpsilon
{
    return MAX(_originalSize.width, _originalSize.height) * 0.005f;
}

#pragma mark - Reset

- (void)resetAnimated:(bool)animated
{
    if (_animatingConfirm)
        return;
    
    _animatingConfirm = true;
    
    if (self.cropOrientation != UIImageOrientationUp && (_mirrored || ABS(_rotation) > FLT_EPSILON || !_CGRectEqualToRectWithEpsilon(_cropRect, CGRectMake(0, 0, _originalSize.width, _originalSize.height), FLT_EPSILON)))
        animated = false;
    
    _cropAreaChanged = false;
    [self cancelConfirmCountdown];
    
    _lockedAspectRatio = 0;
    _areaView.lockAspectRatio = false;
    _areaView.aspectRatio = 0;
    
    CGRect originalCropRect = CGRectMake(0.0f, 0.0f, _originalSize.width, _originalSize.height);
    
    if (!_CGRectEqualToRectWithEpsilon(_cropRect, originalCropRect, FLT_EPSILON) || fabs(_rotation) > 0 || _cropOrientation != UIImageOrientationUp)
    {
        [self resetBackdropViewsAnimated:false];
    }
    
    _cropRect = originalCropRect;
    _rotation = 0.0f;
    _cropOrientation = UIImageOrientationUp;
    _mirrored = false;
    
    if (animated && _cropOrientation != UIImageOrientationUp)
    {
        [self setIntefaceHidden:true animated:false];
        [self setCropAreaHidden:true animated:false];
    }
    
    [_rotationView resetAnimated:animated];
    [_areaView setGridMode:TGPhotoCropViewGridModeNone animated:animated];
    
    [_scrollView resetRotationStartValues];
    [_scrollView setContentMirrored:false];
    
    [self evenlyFillAreaViewAnimated:animated reset:true completion:^
    {
        [self setIntefaceHidden:false animated:true];
        [self setCropAreaHidden:false animated:true];
        
        _animatingConfirm = false;
    }];
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

#pragma mark - Layout

- (bool)isTracking
{
    return _rotationView.isTracking || _areaView.isTracking || _scrollView.isTracking;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if (view == self || view == _areaWrapperView)
        return _scrollView;
    
    return view;
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _interfaceOrientation = interfaceOrientation;
    _rotationView.interfaceOrientation = interfaceOrientation;
}

- (void)layoutSubviews
{
    void (^layoutBackdrop)(void) = ^
    {
        if (!_animatingRotation)
            [self _layoutBackdrop];
    };
    
    if (_imageView == nil)
    {
        [self setup];
    }
    else if (_previousInterfaceOrientation != self.interfaceOrientation)
    {
        bool performedConfirm = false;
        if (_confirmTimer != nil)
        {
            [UIView performWithoutAnimation:^
            {
                [self performConfirmAnimated:false];
            }];
            performedConfirm = true;
        }
        
        void (^layoutBlock)(void) = ^
        {
            if (!_areaView.isTracking && !_animatingConfirm)
                [self _layoutAreaViewAnimated:false completion:layoutBackdrop];
            
            [self _zoomToCropRectWithFrame:_scrollView.bounds animated:false completion:nil];
        };
        
        if (performedConfirm)
            [UIView performWithoutAnimation:layoutBlock];
        else
            layoutBlock();
    }
    else
    {
        if (!_areaView.isTracking && !_animatingConfirm)
            [self _layoutAreaViewAnimated:false completion:layoutBackdrop];
        
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            [self _zoomToCropRectWithFrame:_scrollView.bounds animated:false completion:nil];
    }
    
    _previousInterfaceOrientation = self.interfaceOrientation;
}

- (void)_layoutRotationView
{
    CGRect initialAreaFrame = _areaView.frame;
    [self _layoutRotationViewWithWrapperFrame:_areaWrapperView.frame areaFrame:initialAreaFrame animated:false];
}

- (void)_layoutRotationViewWithWrapperFrame:(CGRect)wrapperFrame areaFrame:(CGRect)areaFrame animated:(bool)animated
{
    CGRect rotationViewFrame = CGRectZero;
    
    CGPoint areaOrigin = areaFrame.origin;
    CGSize areaSize = areaFrame.size;
    
    switch (self.cropOrientation)
    {
        case UIImageOrientationDown:
        {
            areaOrigin = CGPointMake(wrapperFrame.size.width - areaFrame.size.width, wrapperFrame.size.height - areaFrame.size.height);
            areaSize = CGSizeMake(areaFrame.size.width - areaFrame.origin.x, areaFrame.size.height - areaFrame.origin.y);
        }
            break;
        case UIImageOrientationLeft:
        {
            areaOrigin = CGPointMake(areaFrame.origin.y, wrapperFrame.size.height - areaFrame.size.width);
            areaSize = CGSizeMake(areaFrame.size.height, areaFrame.size.width - areaFrame.origin.x);
        }
            break;
        case UIImageOrientationRight:
        {
            areaOrigin = CGPointMake(wrapperFrame.size.width - areaFrame.size.height, areaFrame.origin.x);
            areaSize = CGSizeMake(areaFrame.size.height - areaFrame.origin.y, areaFrame.size.width);
        }
            break;
            
        default:
            break;
    }
    
    areaFrame.origin = areaOrigin;
    areaFrame.size = areaSize;
    
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            rotationViewFrame = CGRectMake(wrapperFrame.origin.x - 100, wrapperFrame.origin.y + areaFrame.origin.y + (areaFrame.size.height - self.frame.size.height) / 2, 100, self.frame.size.height);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            rotationViewFrame = CGRectMake(wrapperFrame.origin.x + areaFrame.origin.x + areaFrame.size.width, wrapperFrame.origin.y + areaFrame.origin.y + (areaFrame.size.height - self.frame.size.height) / 2, 100, self.frame.size.height);
        }
            break;
            
        default:
        {
            rotationViewFrame = CGRectMake(wrapperFrame.origin.x + areaFrame.origin.x + (areaFrame.size.width - self.frame.size.width) / 2, wrapperFrame.origin.y + areaFrame.origin.y + areaFrame.size.height, self.frame.size.width, 100);
        }
            break;
    }
    
    if (animated)
    {
        POPSpringAnimation *animation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        animation.fromValue = [NSValue valueWithCGRect:_rotationView.frame];
        animation.toValue = [NSValue valueWithCGRect:rotationViewFrame];
        animation.springSpeed = 7;
        animation.springBounciness = 1;
        [_rotationView pop_addAnimation:animation forKey:@"frameAnimation"];
    }
    else
    {
        _rotationView.frame = rotationViewFrame;
    }
    
    [_rotationView setNeedsLayout];
}

- (void)_layoutOverlayViewsWithFrame:(CGRect)frame animated:(bool)animated
{
    CGRect overlayWrapperFrame = frame;
    CGRect topOverlayFrame = CGRectMake(0, -TGPhotoCropViewOverscreenSize, overlayWrapperFrame.size.width, TGPhotoCropViewOverscreenSize);
    CGRect leftOverlayFrame = CGRectMake(-TGPhotoCropViewOverscreenSize, -TGPhotoCropViewOverscreenSize, TGPhotoCropViewOverscreenSize, overlayWrapperFrame.size.height + 2 * TGPhotoCropViewOverscreenSize);
    CGRect rightOverlayFrame = CGRectMake(overlayWrapperFrame.size.width, -TGPhotoCropViewOverscreenSize, TGPhotoCropViewOverscreenSize, overlayWrapperFrame.size.height + 2 * TGPhotoCropViewOverscreenSize);
    CGRect bottomOverlayFrame = CGRectMake(0, overlayWrapperFrame.size.height, overlayWrapperFrame.size.width, TGPhotoCropViewOverscreenSize);
    
    if (animated)
    {
        POPSpringAnimation *wrapperAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        wrapperAnimation.fromValue = [NSValue valueWithCGRect:_overlayWrapperView.frame];
        wrapperAnimation.toValue = [NSValue valueWithCGRect:overlayWrapperFrame];
        wrapperAnimation.springSpeed = 7;
        wrapperAnimation.springBounciness = 1;
        [_overlayWrapperView pop_addAnimation:wrapperAnimation forKey:@"frameAnimation"];
        
        POPSpringAnimation *topAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        topAnimation.fromValue = [NSValue valueWithCGRect:_topOverlayView.frame];
        topAnimation.toValue = [NSValue valueWithCGRect:topOverlayFrame];
        topAnimation.springSpeed = 7;
        topAnimation.springBounciness = 1;
        [_topOverlayView pop_addAnimation:topAnimation forKey:@"frameAnimation"];
        
        POPSpringAnimation *leftAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        leftAnimation.fromValue = [NSValue valueWithCGRect:_leftOverlayView.frame];
        leftAnimation.toValue = [NSValue valueWithCGRect:leftOverlayFrame];
        leftAnimation.springSpeed = 7;
        leftAnimation.springBounciness = 1;
        [_leftOverlayView pop_addAnimation:leftAnimation forKey:@"frameAnimation"];
        
        POPSpringAnimation *rightAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        rightAnimation.fromValue = [NSValue valueWithCGRect:_rightOverlayView.frame];
        rightAnimation.toValue = [NSValue valueWithCGRect:rightOverlayFrame];
        rightAnimation.springSpeed = 7;
        rightAnimation.springBounciness = 1;
        [_rightOverlayView pop_addAnimation:rightAnimation forKey:@"frameAnimation"];
        
        POPSpringAnimation *bottomAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        bottomAnimation.fromValue = [NSValue valueWithCGRect:_bottomOverlayView.frame];
        bottomAnimation.toValue = [NSValue valueWithCGRect:bottomOverlayFrame];
        bottomAnimation.springSpeed = 7;
        bottomAnimation.springBounciness = 1;
        [_bottomOverlayView pop_addAnimation:bottomAnimation forKey:@"frameAnimation"];
    }
    else
    {
        _overlayWrapperView.frame = overlayWrapperFrame;
        _topOverlayView.frame = topOverlayFrame;
        _leftOverlayView.frame = leftOverlayFrame;
        _rightOverlayView.frame = rightOverlayFrame;
        _bottomOverlayView.frame = bottomOverlayFrame;
    }
}

- (CGSize)_areaSizeForCropRect:(CGRect)cropRect orientation:(UIImageOrientation)orientation
{
    CGSize resultSize = cropRect.size;
    CGSize rotatedSize = resultSize;
    if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight)
        rotatedSize = CGSizeMake(rotatedSize.height, rotatedSize.width);
    
    CGSize areaSize = TGScaleToSize(rotatedSize, self.bounds.size);
    
    return areaSize;
}

- (CGRect)_layoutAreaViewAnimated:(bool)animated completion:(void (^)(void))completion
{
    CGSize areaSize = [self _areaSizeForCropRect:_cropRect orientation:_cropOrientation];
    CGRect areaWrapperFrame = CGRectMake((self.frame.size.width - areaSize.width) / 2, (self.frame.size.height - areaSize.height) / 2, areaSize.width, areaSize.height);
    CGRect areaWrapperBounds = CGRectMake(0, 0, areaWrapperFrame.size.width, areaWrapperFrame.size.height);
    
    switch (self.cropOrientation)
    {
        case UIImageOrientationUp:
        {
            _areaWrapperView.transform = CGAffineTransformIdentity;
        }
            break;
            
        case UIImageOrientationDown:
        {
            _areaWrapperView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
        }
            break;
            
        case UIImageOrientationLeft:
        {
            _areaWrapperView.transform = CGAffineTransformMakeRotation((CGFloat)-M_PI_2);
            areaWrapperBounds = CGRectMake(0, 0, areaWrapperBounds.size.height, areaWrapperBounds.size.width);
        }
            break;
            
        case UIImageOrientationRight:
        {
            _areaWrapperView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
            areaWrapperBounds = CGRectMake(0, 0, areaWrapperBounds.size.height, areaWrapperBounds.size.width);
        }
            break;
            
        default:
            break;
    }
    
    if (animated)
    {
        POPSpringAnimation *wrapperAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        wrapperAnimation.fromValue = [NSValue valueWithCGRect:_areaWrapperView.frame];
        wrapperAnimation.toValue = [NSValue valueWithCGRect:areaWrapperFrame];
        wrapperAnimation.springSpeed = 7;
        wrapperAnimation.springBounciness = 1;
        
        POPSpringAnimation *areaAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        areaAnimation.fromValue = [NSValue valueWithCGRect:_areaView.frame];
        areaAnimation.toValue = [NSValue valueWithCGRect:areaWrapperBounds];
        areaAnimation.springSpeed = 7;
        areaAnimation.springBounciness = 1;
        
        POPSpringAnimation *scrollViewAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        scrollViewAnimation.fromValue = [NSValue valueWithCGRect:_scrollView.frame];
        scrollViewAnimation.toValue = [NSValue valueWithCGRect:areaWrapperBounds];
        scrollViewAnimation.springSpeed = 7;
        scrollViewAnimation.springBounciness = 1;

        [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
        {
          if (completion != nil)
              completion();
        } whenCompletedAllAnimations:@[ wrapperAnimation, areaAnimation, scrollViewAnimation ]];

        [_areaWrapperView pop_addAnimation:wrapperAnimation forKey:@"frameAnimation"];
        [_areaView pop_addAnimation:areaAnimation forKey:@"frameAnimation"];
        [_scrollView pop_addAnimation:scrollViewAnimation forKey:@"frameAnimation"];
    }
    else
    {
        _areaWrapperView.frame = areaWrapperFrame;
        _areaView.frame = areaWrapperBounds;
        _scrollView.frame = areaWrapperBounds;
        
        if (completion != nil)
            completion();
    }

    [self _layoutOverlayViewsWithFrame:areaWrapperBounds animated:animated];
    [self _layoutRotationViewWithWrapperFrame:areaWrapperFrame areaFrame:CGRectMake(0, 0, areaWrapperBounds.size.width, areaWrapperBounds.size.height) animated:animated];
    
    return areaWrapperBounds;
}

- (void)_zoomToCropRectWithFrame:(CGRect)frame animated:(bool)animated completion:(void (^)(void))completion
{
    [_scrollView zoomToRect:_cropRect withFrame:frame animated:animated completion:completion];
}

@end
