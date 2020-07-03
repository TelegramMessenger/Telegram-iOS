#import "TGPhotoEditorPreviewView.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPaintUtils.h>

#import "PGPhotoEditorView.h"
#import <LegacyComponents/PGPhotoEditorValues.h>
#import <LegacyComponents/TGPaintingData.h>

@interface TGPhotoEditorPreviewView ()
{
    UIView *_snapshotView;
    UIView *_transitionView;

    UITapGestureRecognizer *_tapGestureRecognizer;
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    
    bool _needsTransitionIn;
    UIImage *_delayedImage;
    
    UIView *_paintingContainerView;
    
    bool _paintingHidden;
    CGRect _cropRect;
    UIImageOrientation _cropOrientation;
    CGFloat _cropRotation;
    bool _cropMirrored;
    CGSize _originalSize;
}
@end

@implementation TGPhotoEditorPreviewView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[PGPhotoEditorView alloc] initWithFrame:self.bounds];
        _imageView.alpha = 0.0f;
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_imageView];
        
        _paintingContainerView = [[UIView alloc] init];
        _paintingContainerView.userInteractionEnabled = false;
        [self addSubview:_paintingContainerView];
        
        _paintingView = [[UIImageView alloc] init];
        [_paintingContainerView addSubview:_paintingView];
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [_imageView addGestureRecognizer:_tapGestureRecognizer];
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        _pressGestureRecognizer.minimumPressDuration = 0.175;
        [_imageView addGestureRecognizer:_pressGestureRecognizer];
        
        [_tapGestureRecognizer requireGestureRecognizerToFail:_pressGestureRecognizer];
    }
    return self;
}

- (void)setSnapshotImage:(UIImage *)image
{
    [_snapshotView removeFromSuperview];
    
    _snapshotView = [[UIImageView alloc] initWithImage:image];
    _snapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _snapshotView.frame = self.bounds;
    [self insertSubview:_snapshotView atIndex:0];
}

- (void)setSnapshotImageOnTransition:(UIImage *)image
{
    if (![_snapshotView isKindOfClass:[UIImageView class]])
        return;
    
    _delayedImage = image;
}

- (void)setSnapshotView:(UIView *)view
{
    [_snapshotView removeFromSuperview];
    
    _snapshotView = view;
    _snapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _snapshotView.frame = self.bounds;
    [self insertSubview:_snapshotView atIndex:0];
}

- (void)setPaintingImageWithData:(TGPaintingData *)data
{
    if (data == nil)
    {
        _paintingView.hidden = true;
    }
    else
    {
        _paintingView.hidden = false;
        _paintingView.frame = self.bounds;
        _paintingView.image = data.image;
        
        [self setNeedsLayout];
    }
}

- (void)setCropRect:(CGRect)cropRect cropOrientation:(UIImageOrientation)cropOrientation cropRotation:(CGFloat)cropRotation cropMirrored:(bool)cropMirrored originalSize:(CGSize)originalSize
{
    _cropRect = cropRect;
    _cropOrientation = cropOrientation;
    _cropRotation = cropRotation;
    _cropMirrored = cropMirrored;
    _originalSize = originalSize;
    
    [self setNeedsLayout];
}

- (void)setPaintingHidden:(bool)hidden
{
    _paintingHidden = hidden;
    _paintingView.alpha = hidden ? 0.0f : 1.0f;
}

- (UIView *)originalSnapshotView
{
    return [_snapshotView snapshotViewAfterScreenUpdates:false];
}

- (void)prepareTransitionFadeView
{
    _transitionView = [_imageView snapshotViewAfterScreenUpdates:false];
    _transitionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self insertSubview:_transitionView belowSubview:_paintingContainerView];
}

- (void)performTransitionFade
{
    [UIView animateWithDuration:0.15f animations:^
    {
        _transitionView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        [_transitionView removeFromSuperview];
        _transitionView = nil;
    }];
}

- (void)performTransitionInWithCompletion:(void (^)(void))completion
{
    _needsTransitionIn = false;
    
    [UIView animateWithDuration:0.15f animations:^
    {
        _imageView.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
}

- (void)setNeedsTransitionIn
{
    _needsTransitionIn = true;
}

- (void)performTransitionInIfNeeded
{
    if (_needsTransitionIn)
    {
        [self performTransitionInWithCompletion:nil];
    }
    else if (_delayedImage != nil && [_delayedImage isKindOfClass:[UIImage class]])
    {
        UIImageView *transitionView = [[UIImageView alloc] initWithFrame:_snapshotView.frame];
        transitionView.image = ((UIImageView *)_snapshotView).image;
        [self insertSubview:transitionView aboveSubview:_snapshotView];
        
        ((UIImageView *)_snapshotView).image = _delayedImage;
        _delayedImage = nil;
        
        [UIView animateWithDuration:0.3 animations:^
         {
             transitionView.alpha = 0.0f;
         } completion:^(__unused BOOL finished)
         {
             [transitionView removeFromSuperview];
         }];
    }
}

- (void)prepareForTransitionOut
{
    [_snapshotView removeFromSuperview];
}

- (void)performTransitionToCropAnimated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2f animations:^
        {
            _imageView.alpha = 0.0f;
        }];
    }
    else
    {
        _imageView.alpha = 0.0f;
    }
}

- (void)handleTap:(UITapGestureRecognizer *)__unused gestureRecognizer
{
    if (self.tapped != nil)
        self.tapped();
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _isTracking = true;
            
            if (self.touchedDown != nil)
                self.touchedDown();

            if (!self.customTouchDownHandling)
                [self setActualImageHidden:true animated:false];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _isTracking = false;
            
            if (self.touchedUp != nil)
                self.touchedUp();
            
            if (!self.customTouchDownHandling)
                [self setActualImageHidden:false animated:false];
            
            if (self.interactionEnded != nil)
                self.interactionEnded();
        }
            break;
            
        default:
            break;
    }
}

- (void)setActualImageHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.1f delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _paintingView.alpha = hidden || _paintingHidden ? 0.0f : 1.0f;
            _imageView.alpha = hidden ? 0.0f : 1.0f;
        } completion:nil];
    }
    else
    {
        _paintingView.alpha = hidden || _paintingHidden ? 0.0f : 1.0f;
        _imageView.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (CGPoint)fittedCropCenterScale:(CGFloat)scale
{
    CGSize size = CGSizeMake(_cropRect.size.width * scale, _cropRect.size.height * scale);
    CGRect rect = CGRectMake(_cropRect.origin.x * scale, _cropRect.origin.y * scale, size.width, size.height);
    
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

- (void)layoutSubviews
{
    if (self.bounds.size.width <= 0.0f || _cropRect.size.width <= 0.0f || _originalSize.width <= 0.0f || self.paintingView.image == nil) {
        return;
    }
    
    CGFloat rotation = TGRotationForOrientation(_cropOrientation);
    CGAffineTransform transform = CGAffineTransformMakeScale(_cropMirrored && self.applyMirror ? -1.0 : 1.0, 1.0);
    _paintingContainerView.transform = CGAffineTransformRotate(transform, rotation);
    _paintingContainerView.frame = self.bounds;
    
    CGFloat width = TGOrientationIsSideward(_cropOrientation, NULL) ? self.bounds.size.height : self.bounds.size.width;
    CGFloat ratio = 1.0;
    if (_cropRect.size.width > 0.0) {
        ratio = width / _cropRect.size.width;
    }
   
    rotation = _cropRotation;
    
    CGRect originalFrame = CGRectMake(-_cropRect.origin.x * ratio, -_cropRect.origin.y * ratio, _originalSize.width * ratio, _originalSize.height * ratio);
    CGSize fittedOriginalSize = CGSizeMake(_originalSize.width * ratio, _originalSize.height * ratio);
    CGSize rotatedSize = TGRotatedContentSize(fittedOriginalSize, rotation);
    CGPoint centerPoint = CGPointMake(rotatedSize.width / 2.0f, rotatedSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / _originalSize.width;
    CGPoint centerOffset = TGPaintSubtractPoints(centerPoint, [self fittedCropCenterScale:scale]);
    
    _paintingView.transform = CGAffineTransformIdentity;
    _paintingView.frame = originalFrame;
    
    _paintingView.transform = CGAffineTransformMakeRotation(rotation);
    _paintingView.center = TGPaintAddPoints(TGPaintCenterOfRect(_paintingContainerView.bounds), centerOffset);
}

@end
