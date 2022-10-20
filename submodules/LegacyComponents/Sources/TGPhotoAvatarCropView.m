#import "TGPhotoAvatarCropView.h"
#import <AVFoundation/AVFoundation.h>

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"

#import "PGPhotoEditorView.h"
#import "TGPhotoEntitiesContainerView.h"

const CGFloat TGPhotoAvatarCropViewOverscreenSize = 1000;
const CGFloat TGPhotoAvatarCropViewCurtainSize = 300;
const CGFloat TGPhotoAvatarCropViewCurtainMargin = 200;

@interface TGPhotoAvatarCropView () <UIScrollViewDelegate>
{
    CGSize _originalSize;
    CGRect _cropRect;
    bool _cropMirrored;
    
    UIScrollView *_scrollView;
    UIView *_wrapperView;
    UIImageView *_imageView;
    UIView *_snapshotView;
    CGSize _snapshotSize;
    
    UIView *_flashView;
    
    UIView *_topOverlayView;
    UIView *_leftOverlayView;
    UIView *_rightOverlayView;
    UIView *_bottomOverlayView;
    
    UIView *_topCurtainView;
    UIView *_bottomCurtainView;
    UIImageView *_areaMaskView;
    
    bool _imageReloadingNeeded;
    
    CGFloat _currentDiameter;
    
    UIView *_entitiesWrapperView;
    
    __weak PGPhotoEditorView *_fullPreviewView;
    __weak UIImageView *_fullPaintingView;
    __weak TGPhotoEntitiesContainerView *_fullEntitiesView;
}
@end

@implementation TGPhotoAvatarCropView

- (instancetype)initWithOriginalSize:(CGSize)originalSize screenSize:(CGSize)screenSize fullPreviewView:(PGPhotoEditorView *)fullPreviewView fullPaintingView:(UIImageView *)fullPaintingView fullEntitiesView:(TGPhotoEntitiesContainerView *)fullEntitiesView
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _originalSize = originalSize;
        
        CGFloat shortSide = MIN(originalSize.width, originalSize.height);
        _cropRect = CGRectMake((_originalSize.width - shortSide) / 2, (_originalSize.height - shortSide) / 2, shortSide, shortSide);
        
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.alwaysBounceHorizontal = true;
        _scrollView.alwaysBounceVertical = true;
        _scrollView.clipsToBounds = false;
        _scrollView.contentSize = _originalSize;
        _scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
        _scrollView.delegate = self;
        _scrollView.hidden = true;
        _scrollView.showsHorizontalScrollIndicator = false;
        _scrollView.showsVerticalScrollIndicator = false;
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _originalSize.width, _originalSize.height)];
        [_scrollView addSubview:_wrapperView];
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _wrapperView.frame.size.width, _wrapperView.frame.size.height)];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.userInteractionEnabled = false;
        [_wrapperView addSubview:_imageView];
        
        _fullPreviewView = fullPreviewView;
        _fullPreviewView.center = _imageView.center;
        CGSize fittedSize  = TGScaleToSize(_originalSize, CGSizeMake(1024, 1024));
        CGFloat scale = _imageView.bounds.size.width / fittedSize.width;
        _fullPreviewView.transform = CGAffineTransformMakeScale(self.cropMirrored ? -scale : scale, scale);
        _fullPreviewView.userInteractionEnabled = false;
        [_wrapperView addSubview:_fullPreviewView];
        
        _fullPaintingView = fullPaintingView;
        _fullPaintingView.frame = _fullPreviewView.frame;
        [_wrapperView addSubview:_fullPaintingView];
        
        _entitiesWrapperView = [[UIView alloc] init];
        _fullEntitiesView = fullEntitiesView;
        _fullEntitiesView.frame = CGRectMake(0.0, 0.0, _fullEntitiesView.frame.size.width, _fullEntitiesView.frame.size.height);
        _entitiesWrapperView.frame = _fullEntitiesView.frame;
        
        CGFloat entitiesScale = _fullPreviewView.frame.size.width / _entitiesWrapperView.frame.size.width;
        _entitiesWrapperView.transform = CGAffineTransformMakeScale(entitiesScale, entitiesScale);
        _entitiesWrapperView.frame = _fullPreviewView.frame;
        [_entitiesWrapperView addSubview:_fullEntitiesView];
        [_wrapperView addSubview:_entitiesWrapperView];
        
        _flashView = [[UIView alloc] init];
        _flashView.alpha = 0.0;
        _flashView.backgroundColor = [UIColor whiteColor];
        _flashView.userInteractionEnabled = false;
        [self addSubview:_flashView];
        
        _topCurtainView = [[UIView alloc] initWithFrame:CGRectZero];
        _topCurtainView.backgroundColor = [UIColor blackColor];
        [self addSubview:_topCurtainView];
        
        _bottomCurtainView = [[UIView alloc] initWithFrame:CGRectZero];
        _bottomCurtainView.backgroundColor = [UIColor blackColor];
        [self addSubview:_bottomCurtainView];
        
        _topOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _topOverlayView.backgroundColor = [TGPhotoEditorInterfaceAssets cropTransparentOverlayColor];
        _topOverlayView.userInteractionEnabled = false;
        [self addSubview:_topOverlayView];
        
        _leftOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _leftOverlayView.backgroundColor = [TGPhotoEditorInterfaceAssets cropTransparentOverlayColor];
        _leftOverlayView.userInteractionEnabled = false;
        [self addSubview:_leftOverlayView];
        
        _rightOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _rightOverlayView.backgroundColor = [TGPhotoEditorInterfaceAssets cropTransparentOverlayColor];
        _rightOverlayView.userInteractionEnabled = false;
        [self addSubview:_rightOverlayView];
        
        _bottomOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _bottomOverlayView.backgroundColor = [TGPhotoEditorInterfaceAssets cropTransparentOverlayColor];
        _bottomOverlayView.userInteractionEnabled = false;
        [self addSubview:_bottomOverlayView];
        
        _areaMaskView = [[UIImageView alloc] initWithFrame:self.bounds];
        _areaMaskView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_areaMaskView];
        
        [self updateCircleImageWithReferenceSize:screenSize];
        
        UITapGestureRecognizer *tapRecognier = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [_wrapperView addGestureRecognizer:tapRecognier];
        
        _clipView = [[UIView alloc] init];
        _clipView.clipsToBounds = true;
        _clipView.userInteractionEnabled = false;
        [self addSubview:_clipView];
    }
    return self;
}

- (void)attachEntitiesView {
    [_entitiesWrapperView addSubview:_fullEntitiesView];
}

- (void)dealloc
{
    _scrollView.delegate = nil;
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer {
    if (self.tapped != nil)
        self.tapped();
}

- (void)updateCircleImageWithReferenceSize:(CGSize)referenceSize
{
    CGFloat shortSide = MIN(referenceSize.width, referenceSize.height);
    CGFloat diameter = shortSide - [TGPhotoAvatarCropView areaInsetSize].width * 2;
 
    if (fabs(diameter - _currentDiameter) < DBL_EPSILON)
        return;
    
    _currentDiameter = diameter;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [TGPhotoEditorInterfaceAssets cropTransparentOverlayColor].CGColor);
    
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, diameter, diameter)];
    [path appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, diameter, diameter)]];
    path.usesEvenOddFillRule = true;
    [path fill];
    
    UIImage *areaMaskImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    _areaMaskView.image = areaMaskImage;
}

- (bool)isTracking
{
    return _scrollView.isTracking;
}

#pragma mark - Setup

- (void)setImage:(UIImage *)image
{
    _image = image;
    _imageReloadingNeeded = true;
    
    if (_scrollView.isTracking)
        return;
    
    [self reloadImageIfNeeded];
}

- (void)reloadImageIfNeeded
{
    if (!_imageReloadingNeeded)
        return;
    
    _imageReloadingNeeded = false;
    
    _imageView.image = _image;
    
    if (_snapshotView != nil && !_scrollView.hidden)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self fadeInImageView];
        });
    }
}

- (void)_replaceSnapshotImage:(UIImage *)image
{
    if ([_snapshotView isKindOfClass:[UIImageView class]])
        ((UIImageView *)_snapshotView).image = image;
}

- (void)setSnapshotImage:(UIImage *)snapshotImage
{
    [_snapshotView removeFromSuperview];
    
    _imageView.alpha = 0.0f;
    
    _snapshotSize = snapshotImage.size;
    
    UIImageView *imageSnapshotView = [[UIImageView alloc] initWithImage:snapshotImage];
    _snapshotView = imageSnapshotView;
    [_wrapperView insertSubview:_snapshotView belowSubview:_imageView];
}

- (void)setSnapshotView:(UIView *)snapshotView
{
    [_snapshotView removeFromSuperview];
    
    _imageView.alpha = 0.0f;
    
    _snapshotView = snapshotView;
    [_wrapperView insertSubview:_snapshotView belowSubview:_imageView];
}

#pragma mark - Rotation

- (void)rotate90DegreesCCWAnimated:(bool)animated
{
    self.cropOrientation = TGNextCCWOrientationForOrientation(self.cropOrientation);
    
    if (animated)
    {
        _isAnimating = true;
        
        CGFloat currentRotation = [[_scrollView.layer valueForKeyPath:@"transform.rotation.z"] floatValue];
        CGFloat targetRotation = TGRotationForOrientation(self.cropOrientation);
        if (fabs(currentRotation - targetRotation) > M_PI)
            targetRotation = -2 * (CGFloat)M_PI + targetRotation;
        
        POPSpringAnimation *rotationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
        rotationAnimation.fromValue = @(currentRotation);
        rotationAnimation.toValue = @(targetRotation);
        rotationAnimation.springSpeed = 7;
        rotationAnimation.springBounciness = 1;
        rotationAnimation.completionBlock = ^(__unused POPAnimation *animation, BOOL finished)
        {
            if (finished)
                _isAnimating = false;
        };
        [_scrollView.layer pop_addAnimation:rotationAnimation forKey:@"rotation"];
    }
    else
    {
        _scrollView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(self.cropOrientation));
    }
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

- (void)mirror
{
    self.cropMirrored = !self.cropMirrored;
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

- (void)resetAnimated:(bool)animated
{
    _cropRect = [self _defaultCropRect];
    _cropOrientation = UIImageOrientationUp;
    
    if (animated)
    {
        _isAnimating = true;
        
        CGPoint targetContentOffset = CGPointMake(_cropRect.origin.x * _scrollView.minimumZoomScale,
                                                  _cropRect.origin.y * _scrollView.minimumZoomScale);
        
        POPSpringAnimation *offsetAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPScrollViewContentOffset];
        offsetAnimation.fromValue = [NSValue valueWithCGPoint:_scrollView.contentOffset];
        offsetAnimation.toValue = [NSValue valueWithCGPoint:targetContentOffset];
        offsetAnimation.springSpeed = 7;
        offsetAnimation.springBounciness = 1;
        [_scrollView pop_addAnimation:offsetAnimation forKey:@"contentOffset"];
        
        POPSpringAnimation *zoomAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPScrollViewZoomScale];
        zoomAnimation.fromValue = @(_scrollView.zoomScale);
        zoomAnimation.toValue = @(_scrollView.minimumZoomScale);
        zoomAnimation.springSpeed = 7;
        zoomAnimation.springBounciness = 1;
        [_scrollView pop_addAnimation:zoomAnimation forKey:@"zoomScale"];
        
        POPSpringAnimation *rotationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
        rotationAnimation.fromValue = (NSNumber *)[_scrollView.layer valueForKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = @0;
        rotationAnimation.springSpeed = 7;
        rotationAnimation.springBounciness = 1;
        [_scrollView.layer pop_addAnimation:rotationAnimation forKey:@"rotation"];
        
        [TGPhotoEditorAnimation performBlock:^(bool allFinished)
        {
            if (allFinished)
                _isAnimating = false;
        } whenCompletedAllAnimations:@[ offsetAnimation, zoomAnimation, rotationAnimation ]];
    }
    else
    {
        _scrollView.transform = CGAffineTransformIdentity;
        [_scrollView zoomToRect:_cropRect animated:false];
    }
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
}

- (CGRect)_defaultCropRect
{
    CGFloat shortSide = MIN(_originalSize.width, _originalSize.height);
    return CGRectMake((_originalSize.width - shortSide) / 2, (_originalSize.height - shortSide) / 2, shortSide, shortSide);
}

#pragma mark - Scroll View

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.interactionBegan != nil)
        self.interactionBegan();
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view
{
    if (self.interactionBegan != nil)
        self.interactionBegan();
}

- (void)scrollViewDidZoom:(UIScrollView *)__unused scrollView
{
    [self adjustScrollView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)__unused scrollView withView:(UIView *)__unused view atScale:(CGFloat)__unused scale
{
    [self adjustScrollView];
    
    [self _updateCropRect];
    
    if (self.croppingChanged != nil)
        self.croppingChanged();
    
    [self reloadImageIfNeeded];
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (self.interactionEnded != nil)
            self.interactionEnded();
    });
}

- (void)scrollViewDidEndDragging:(UIScrollView *)__unused scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [self scrollViewDidEndDecelerating:scrollView];
        
        if (self.croppingChanged != nil)
            self.croppingChanged();
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    _isAnimating = false;
    
    [self _updateCropRect];
    
    if (!scrollView.isTracking) {
        if (self.croppingChanged != nil)
            self.croppingChanged();
    }
    
    [self reloadImageIfNeeded];
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (self.interactionEnded != nil)
            self.interactionEnded();
    });
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)__unused scrollView
{
    _isAnimating = true;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)__unused scrollView
{
    return _wrapperView;
}

- (void)adjustScrollView
{
    CGSize imageSize = _originalSize;
    CGFloat imageScale = 1.0f;
    imageSize.width /= imageScale;
    imageSize.height /= imageScale;
    
    CGSize boundsSize = _scrollView.bounds.size;
    
    CGFloat scaleWidth = boundsSize.width / imageSize.width;
    CGFloat scaleHeight = boundsSize.height / imageSize.height;
    CGFloat minScale = MAX(scaleWidth, scaleHeight);
    
    if (_scrollView.minimumZoomScale != minScale)
        _scrollView.minimumZoomScale = minScale;
    if (_scrollView.maximumZoomScale != minScale * 3.0f)
        _scrollView.maximumZoomScale = minScale * 3.0f;
}

#pragma mark - Cropping

- (void)_updateCropRect
{
    _cropRect = [_scrollView convertRect:_scrollView.bounds toView:_wrapperView];
}

- (CGRect)cropRect
{
    return _cropRect;
}

- (void)setCropRect:(CGRect)cropRect
{
    _cropRect = CGRectIntegral(cropRect);
    if (!CGRectIsEmpty(self.frame))
        [self invalidateCropRect];
}

- (void)setCropMirrored:(bool)cropMirrored
{
    _cropMirrored = cropMirrored;
    _imageView.transform = CGAffineTransformMakeScale(self.cropMirrored ? -1.0f : 1.0f, 1.0f);
    
    CGSize fittedSize  = TGScaleToSize(_originalSize, CGSizeMake(1024, 1024));
    CGFloat scale = _imageView.bounds.size.width / fittedSize.width;
    _fullPreviewView.transform = CGAffineTransformMakeScale(self.cropMirrored ? -scale : scale, scale);
}

- (void)invalidateCropRect
{
    [_scrollView zoomToRect:_cropRect animated:false];
}

- (CGRect)contentFrameForView:(UIView *)view
{
    return [_scrollView convertRect:_wrapperView.frame toView:view];
}

- (CGRect)cropRectFrameForView:(UIView *)view
{
    return [self convertRect:_scrollView.frame toView:view];
}

- (UIView *)cropSnapshotView
{
    UIView *snapshotView = [_scrollView snapshotViewAfterScreenUpdates:false];
    snapshotView.transform = _scrollView.transform;
    return snapshotView;
}

- (UIImage *)currentImage {
    return _imageView.image;
}

- (UIImage *)croppedImageWithMaxSize:(CGSize)maxSize
{
    return TGPhotoEditorCrop(_imageView.image, nil, self.cropOrientation, 0.0f, self.cropRect, false, maxSize, _originalSize, true);
}

#pragma mark - Transition

- (void)fadeInImageView
{
    [UIView animateWithDuration:0.3f animations:^
    {
        _imageView.alpha = 1.0f;
        _areaMaskView.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        [_snapshotView removeFromSuperview];
        _snapshotView = nil;
    }];
}

- (void)animateTransitionIn
{
    if (!_scrollView.hidden)
        return;
    
    _scrollView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
    
    _areaMaskView.alpha = 0.0f;
    _topOverlayView.alpha = 0.0f;
    _leftOverlayView.alpha = 0.0f;
    _rightOverlayView.alpha = 0.0f;
    _bottomOverlayView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _topOverlayView.alpha = 1.0f;
        _leftOverlayView.alpha = 1.0f;
        _rightOverlayView.alpha = 1.0f;
        _bottomOverlayView.alpha = 1.0f;
        _areaMaskView.alpha = 1.0f;
    }];
}

- (void)transitionInFinishedFromCamera:(bool)fromCamera
{
    _scrollView.hidden = false;
    _scrollView.backgroundColor = [UIColor clearColor];
    
    if (_imageView.image != nil && _snapshotView != nil)
        [self fadeInImageView];
}

- (void)animateTransitionOutSwitching:(bool)switching
{
    if (switching)
    {
        UIView *snapshotView = [_scrollView snapshotViewAfterScreenUpdates:false];
        snapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        snapshotView.frame = _scrollView.frame;
        snapshotView.transform = _scrollView.transform;
        [self insertSubview:snapshotView aboveSubview:_scrollView];
    }
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _scrollView.alpha = 0.0f;
        _topOverlayView.alpha = 0.0f;
        _leftOverlayView.alpha = 0.0f;
        _rightOverlayView.alpha = 0.0f;
        _bottomOverlayView.alpha = 0.0f;
        _areaMaskView.alpha = 0.0f;
    }];
}

- (void)animateTransitionOut
{
    [UIView animateWithDuration:0.2f animations:^
    {
        _topOverlayView.alpha = 0.0f;
        _leftOverlayView.alpha = 0.0f;
        _rightOverlayView.alpha = 0.0f;
        _bottomOverlayView.alpha = 0.0f;
        _areaMaskView.alpha = 0.0f;
    }];
}

- (void)hideImageForCustomTransition
{
    _scrollView.hidden = true;
}

#pragma mark - Layout

- (void)_layoutOverlayViews
{
    CGRect topOverlayFrame = CGRectMake(0, -TGPhotoAvatarCropViewOverscreenSize, self.bounds.size.width, TGPhotoAvatarCropViewOverscreenSize);
    CGRect leftOverlayFrame = CGRectMake(-TGPhotoAvatarCropViewOverscreenSize, -TGPhotoAvatarCropViewOverscreenSize, TGPhotoAvatarCropViewOverscreenSize, self.bounds.size.height + 2 * TGPhotoAvatarCropViewOverscreenSize);
    CGRect rightOverlayFrame = CGRectMake(self.bounds.size.width, -TGPhotoAvatarCropViewOverscreenSize, TGPhotoAvatarCropViewOverscreenSize, self.bounds.size.height + 2 * TGPhotoAvatarCropViewOverscreenSize);
    CGRect bottomOverlayFrame = CGRectMake(0, self.bounds.size.height, self.bounds.size.width, TGPhotoAvatarCropViewOverscreenSize);
    
    _topOverlayView.frame = topOverlayFrame;
    _leftOverlayView.frame = leftOverlayFrame;
    _rightOverlayView.frame = rightOverlayFrame;
    _bottomOverlayView.frame = bottomOverlayFrame;
}

- (void)closeCurtains {
    CGRect topFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, -TGPhotoAvatarCropViewCurtainSize, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, 1.0);
    CGRect bottomFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, self.bounds.size.height + TGPhotoAvatarCropViewCurtainSize, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, 1.0);
       
    _topCurtainView.frame = topFrame;
    _bottomCurtainView.frame = bottomFrame;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^
    {
        CGRect topFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, -TGPhotoAvatarCropViewCurtainSize, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, TGPhotoAvatarCropViewCurtainSize);
        CGRect bottomFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, self.bounds.size.height, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, TGPhotoAvatarCropViewCurtainSize);
  
        _topCurtainView.frame = topFrame;
        _bottomCurtainView.frame = bottomFrame;
    } completion:nil];
}

- (void)openCurtains {
    CGRect topFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, -TGPhotoAvatarCropViewCurtainSize, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, TGPhotoAvatarCropViewCurtainSize);
    CGRect bottomFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, self.bounds.size.height, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, TGPhotoAvatarCropViewCurtainSize);
    
    _topCurtainView.frame = topFrame;
    _bottomCurtainView.frame = bottomFrame;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^
    {
        CGRect topFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, -TGPhotoAvatarCropViewCurtainSize, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, 1.0);
        CGRect bottomFrame = CGRectMake(-TGPhotoAvatarCropViewCurtainMargin, self.bounds.size.height + TGPhotoAvatarCropViewCurtainSize, self.bounds.size.width + TGPhotoAvatarCropViewCurtainMargin * 2.0, 1.0);
        
        _topCurtainView.frame = topFrame;
        _bottomCurtainView.frame = bottomFrame;
    } completion:nil];
}

- (void)layoutSubviews
{
    [self _layoutOverlayViews];
    
    _clipView.frame = self.bounds;
    
    _flashView.frame = self.bounds;
    
    if (_scrollView.superview == nil)
    {
        _scrollView.frame = self.bounds;
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_scrollView atIndex:0];
        [self adjustScrollView];
        
        _scrollView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(_cropOrientation));
        [self invalidateCropRect];
        
        if (_snapshotView != nil)
        {
            CGRect snapshotFrame = [self convertRect:_scrollView.frame toView:_wrapperView];
            
            if (!CGSizeEqualToSize(_snapshotSize, CGSizeZero))
            {
                CGSize snapshotSize = TGScaleToFillSize(_snapshotSize, snapshotFrame.size);

                snapshotFrame = CGRectMake(CGRectGetMidX(snapshotFrame) - snapshotSize.width / 2,
                                           CGRectGetMidY(snapshotFrame)  - snapshotSize.height / 2,
                                           snapshotSize.width, snapshotSize.height);
            }
            
            _snapshotView.frame = snapshotFrame;
        }
    }
}

+ (CGSize)areaInsetSize
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        return CGSizeMake(10, 10);
    else
        return CGSizeMake(20, 20);
}

- (void)flash:(void (^)(void))completion {
    [UIView animateWithDuration:0.12 animations:^{
        _flashView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            _flashView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            completion();
        }];
    }];
}

@end
