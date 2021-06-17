#import "TGVideoMessageScrubber.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "POPBasicAnimation.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import <LegacyComponents/TGPhotoEditorInterfaceAssets.h>

#import "TGVideoMessageScrubberThumbnailView.h"
#import "TGVideoMessageTrimView.h"

#import "TGModernConversationInputMicButton.h"

static const CGFloat TGVideoScrubberMinimumTrimDuration = 1.0f;
static const CGFloat TGVideoScrubberTrimRectEpsilon = 3.0f;

typedef enum
{
    TGMediaPickerGalleryVideoScrubberPivotSourceHandle,
    TGMediaPickerGalleryVideoScrubberPivotSourceTrimStart,
    TGMediaPickerGalleryVideoScrubberPivotSourceTrimEnd
} TGMediaPickerGalleryVideoScrubberPivotSource;

@interface TGVideoMessageScrubber () <UIGestureRecognizerDelegate>
{
    UIControl *_wrapperView;
    UIView *_summaryThumbnailSnapshotView;
    UIView *_zoomedThumbnailWrapperView;
    UIView *_summaryThumbnailWrapperView;
    TGVideoMessageTrimView *_trimView;
    UIView *_leftCurtainView;
    UIView *_rightCurtainView;
    UIControl *_scrubberHandle;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    
    bool _beganInteraction;
    bool _endedInteraction;
    
    bool _scrubbing;
    
    NSTimeInterval _duration;
    NSTimeInterval _trimStartValue;
    NSTimeInterval _trimEndValue;
    
    bool _ignoreThumbnailLoad;
    bool _fadingThumbnailViews;
    CGFloat _thumbnailAspectRatio;
    NSArray *_summaryTimestamps;
    NSMutableArray *_summaryThumbnailViews;
    
    CGSize _originalSize;
    CGRect _cropRect;
    UIImageOrientation _cropOrientation;
    bool _cropMirrored;
    
    UIImageView *_leftMaskView;
    UIImageView *_rightMaskView;
}
@end

@implementation TGVideoMessageScrubber

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _allowsTrimming = true;

        self.clipsToBounds = true;
        self.layer.cornerRadius = 16.0f;
        
        _wrapperView = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 0, 33)];
        _wrapperView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -10);
        [self addSubview:_wrapperView];
        
        _zoomedThumbnailWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 33)];
        [_wrapperView addSubview:_zoomedThumbnailWrapperView];
        
        _summaryThumbnailWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 33)];
        _summaryThumbnailWrapperView.clipsToBounds = true;
        [_wrapperView addSubview:_summaryThumbnailWrapperView];
        
        _leftMaskView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"VideoMessageScrubberLeftMask")];
        [_wrapperView addSubview:_leftMaskView];
        
        _rightMaskView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"VideoMessageScrubberRightMask")];
        [_wrapperView addSubview:_rightMaskView];
        
        _leftCurtainView = [[UIView alloc] init];
        _leftCurtainView.backgroundColor = [UIColorRGB(0xf7f7f7) colorWithAlphaComponent:0.8f];
        [_wrapperView addSubview:_leftCurtainView];
        
        _rightCurtainView = [[UIView alloc] init];
        _rightCurtainView.backgroundColor = [UIColorRGB(0xf7f7f7) colorWithAlphaComponent:0.8f];
        [_wrapperView addSubview:_rightCurtainView];
        
        __weak TGVideoMessageScrubber *weakSelf = self;
        _trimView = [[TGVideoMessageTrimView alloc] initWithFrame:CGRectZero];
        _trimView.exclusiveTouch = true;
        _trimView.trimmingEnabled = _allowsTrimming;
        _trimView.didBeginEditing = ^(__unused bool start)
        {
            __strong TGVideoMessageScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            id<TGVideoMessageScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidBeginEditing:)])
                [delegate videoScrubberDidBeginEditing:strongSelf];
            
            [strongSelf->_trimView setTrimming:true animated:true];
            
            [strongSelf setScrubberHandleHidden:true animated:false];
        };
        _trimView.didEndEditing = ^(bool start)
        {
            __strong TGVideoMessageScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            id<TGVideoMessageScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidEndEditing:endValueChanged:)])
                [delegate videoScrubberDidEndEditing:strongSelf endValueChanged:!start];
            
            CGRect newTrimRect = strongSelf->_trimView.frame;
            CGRect trimRect = [strongSelf _scrubbingRect];
            CGRect normalScrubbingRect = [strongSelf _scrubbingRect];
            CGFloat maxWidth = trimRect.size.width + normalScrubbingRect.origin.x * 2;
            
            CGFloat leftmostPosition = trimRect.origin.x - normalScrubbingRect.origin.x;
            if (newTrimRect.origin.x < leftmostPosition + TGVideoScrubberTrimRectEpsilon)
            {
                CGFloat delta = leftmostPosition - newTrimRect.origin.x;
                
                newTrimRect.origin.x += delta;
                newTrimRect.size.width = MIN(maxWidth, newTrimRect.size.width - delta);
            }
            
            CGFloat rightmostPosition = maxWidth;
            if (CGRectGetMaxX(newTrimRect) > maxWidth - TGVideoScrubberTrimRectEpsilon)
            {
                CGFloat delta = rightmostPosition - CGRectGetMaxX(newTrimRect);
                
                newTrimRect.size.width = MIN(maxWidth, newTrimRect.size.width + delta);
            }
            
            strongSelf->_trimView.frame = newTrimRect;
            
            NSTimeInterval trimStartPosition = 0.0;
            NSTimeInterval trimEndPosition = 0.0;
            
            [strongSelf _trimStartPosition:&trimStartPosition trimEndPosition:&trimEndPosition forTrimFrame:newTrimRect duration:strongSelf.duration];
            
            strongSelf->_trimStartValue = trimStartPosition;
            strongSelf->_trimEndValue = trimEndPosition;
            
            bool isTrimmed = (strongSelf->_trimStartValue > FLT_EPSILON || fabs(strongSelf->_trimEndValue - strongSelf->_duration) > FLT_EPSILON);
            
            [strongSelf->_trimView setTrimming:isTrimmed animated:true];
            
            [strongSelf setScrubberHandleHidden:false animated:true];
        };
        _trimView.startHandleMoved = ^(CGPoint translation)
        {
            __strong TGVideoMessageScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
        
            UIView *trimView = strongSelf->_trimView;
            
            CGRect availableTrimRect = [strongSelf _scrubbingRect];
            CGRect normalScrubbingRect = [strongSelf _scrubbingRect];
            CGFloat originX = MAX(0, trimView.frame.origin.x + translation.x);
            CGFloat delta = originX - trimView.frame.origin.x;
            CGFloat maxWidth = availableTrimRect.size.width + normalScrubbingRect.origin.x * 2 - originX;
            
            CGRect trimViewRect = CGRectMake(originX, trimView.frame.origin.y, MIN(maxWidth, trimView.frame.size.width - delta), trimView.frame.size.height);
            
            NSTimeInterval trimStartPosition = 0.0;
            NSTimeInterval trimEndPosition = 0.0;
            [strongSelf _trimStartPosition:&trimStartPosition trimEndPosition:&trimEndPosition forTrimFrame:trimViewRect duration:strongSelf.duration];
            
            NSTimeInterval duration = trimEndPosition - trimStartPosition;
            
            if (trimEndPosition - trimStartPosition < TGVideoScrubberMinimumTrimDuration)
                return;
            
            if (strongSelf.maximumLength > DBL_EPSILON && duration > strongSelf.maximumLength)
            {
                trimViewRect = CGRectMake(trimView.frame.origin.x + delta,
                                          trimView.frame.origin.y,
                                          trimView.frame.size.width,
                                          trimView.frame.size.height);
                
                [strongSelf _trimStartPosition:&trimStartPosition trimEndPosition:&trimEndPosition forTrimFrame:trimViewRect duration:strongSelf.duration];
            }
            
            trimView.frame = trimViewRect;
            
            [strongSelf _layoutTrimCurtainViews];
            
            strongSelf->_trimStartValue = trimStartPosition;
            strongSelf->_trimEndValue = trimEndPosition;
            
            [strongSelf setValue:strongSelf->_trimStartValue];
            
            UIView *handle = strongSelf->_scrubberHandle;
            handle.center = CGPointMake(trimView.frame.origin.x + 12 + handle.frame.size.width / 2, handle.center.y);
            
            id<TGVideoMessageScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubber:editingStartValueDidChange:)])
                [delegate videoScrubber:strongSelf editingStartValueDidChange:trimStartPosition];
        };
        _trimView.endHandleMoved = ^(CGPoint translation)
        {
            __strong TGVideoMessageScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            UIView *trimView = strongSelf->_trimView;
            
            CGRect availableTrimRect = [strongSelf _scrubbingRect];
            CGRect normalScrubbingRect = [strongSelf _scrubbingRect];
            CGFloat localOriginX = trimView.frame.origin.x - availableTrimRect.origin.x + normalScrubbingRect.origin.x;
            CGFloat maxWidth = availableTrimRect.size.width + normalScrubbingRect.origin.x * 2 - localOriginX;
            
            CGRect trimViewRect = CGRectMake(trimView.frame.origin.x, trimView.frame.origin.y, MIN(maxWidth, trimView.frame.size.width + translation.x), trimView.frame.size.height);
            
            NSTimeInterval trimStartPosition = 0.0;
            NSTimeInterval trimEndPosition = 0.0;
            [strongSelf _trimStartPosition:&trimStartPosition trimEndPosition:&trimEndPosition forTrimFrame:trimViewRect duration:strongSelf.duration];
            
            NSTimeInterval duration = trimEndPosition - trimStartPosition;
            
            if (trimEndPosition - trimStartPosition < TGVideoScrubberMinimumTrimDuration)
                return;
            
            if (strongSelf.maximumLength > DBL_EPSILON && duration > strongSelf.maximumLength)
            {
                trimViewRect = CGRectMake(trimView.frame.origin.x + translation.x, trimView.frame.origin.y, trimView.frame.size.width, trimView.frame.size.height);
                [strongSelf _trimStartPosition:&trimStartPosition trimEndPosition:&trimEndPosition forTrimFrame:trimViewRect duration:strongSelf.duration];
            }
            
            trimView.frame = trimViewRect;
            
            [strongSelf _layoutTrimCurtainViews];
            
            strongSelf->_trimStartValue = trimStartPosition;
            strongSelf->_trimEndValue = trimEndPosition;
            
            [strongSelf setValue:strongSelf->_trimEndValue];
            
            UIView *handle = strongSelf->_scrubberHandle;
            handle.center = CGPointMake(CGRectGetMaxX(trimView.frame) - 12 - handle.frame.size.width / 2, handle.center.y);
            
            id<TGVideoMessageScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubber:editingEndValueDidChange:)])
                [delegate videoScrubber:strongSelf editingEndValueDidChange:trimEndPosition];
        };
        [_wrapperView addSubview:_trimView];
        
        _scrubberHandle = [[UIControl alloc] initWithFrame:CGRectMake(0, -1, 8, 33.0f)];
        _scrubberHandle.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -10);
        //[_wrapperView addSubview:_scrubberHandle];
        
        static UIImage *handleViewImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(_scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetShadowWithColor(context, CGSizeMake(0, 0.0f), 0.5f, [UIColor colorWithWhite:0.0f alpha:0.65f].CGColor);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(1.0f, 1.5f, _scrubberHandle.frame.size.width - 2.0f, _scrubberHandle.frame.size.height - 2.0f) cornerRadius:2];
            [path fill];
            
            handleViewImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        UIImageView *scrubberImageView = [[UIImageView alloc] initWithFrame:_scrubberHandle.bounds];
        scrubberImageView.image = handleViewImage;
        [_scrubberHandle addSubview:scrubberImageView];
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        _pressGestureRecognizer.delegate = self;
        _pressGestureRecognizer.minimumPressDuration = 0.1f;
        //[_scrubberHandle addGestureRecognizer:_pressGestureRecognizer];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        //[_scrubberHandle addGestureRecognizer:_panGestureRecognizer];
    }
    return self;
}

- (void)setPallete:(TGModernConversationInputMicPallete *)pallete
{
    _pallete = pallete;
    if (_pallete == nil)
        return;
    
    _leftCurtainView.backgroundColor = [pallete.backgroundColor colorWithAlphaComponent:0.8f];
    _rightCurtainView.backgroundColor = [pallete.backgroundColor colorWithAlphaComponent:0.8f];
    
    CGSize size = _leftMaskView.image.size;
    UIGraphicsBeginImageContextWithOptions(_leftMaskView.image.size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, pallete.backgroundColor.CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width * 2.0f, size.height));
    UIImage *maskView = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    _leftMaskView.image = maskView;
    _rightMaskView.image = [UIImage imageWithCGImage:maskView.CGImage scale:maskView.scale orientation:UIImageOrientationUpMirrored];
    
    size = CGSizeMake(16.0f, 33.0f);
    UIGraphicsBeginImageContextWithOptions(_leftMaskView.image.size, false, 0.0f);
    context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, pallete.buttonColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width * 2.0f, size.height));
    CGContextSetFillColorWithColor(context, pallete.iconColor.CGColor);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.0f, 12.0f, 1.666f, 9.0f) cornerRadius:0.833f];
    CGContextAddPath(context, path.CGPath);
    CGContextFillPath(context);
    UIImage *handleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [_trimView setLeftHandleImage:handleImage rightHandleImage:[UIImage imageWithCGImage:handleImage.CGImage scale:handleImage.scale orientation:UIImageOrientationUpMirrored]];
}

- (void)reloadThumbnails
{
    [self resetThumbnails];
    
    id<TGVideoMessageScrubberDataSource> dataSource = self.dataSource;
    
    _summaryThumbnailViews = [[NSMutableArray alloc] init];
    
    if ([dataSource respondsToSelector:@selector(videoScrubberOriginalSize:cropRect:cropOrientation:cropMirrored:)])
        _originalSize = [dataSource videoScrubberOriginalSize:self cropRect:&_cropRect cropOrientation:&_cropOrientation cropMirrored:&_cropMirrored];
    
    CGFloat originalAspectRatio = 1.0f;
    CGFloat frameAspectRatio = 1.0f;
    if ([dataSource respondsToSelector:@selector(videoScrubberThumbnailAspectRatio:)])
        originalAspectRatio = [dataSource videoScrubberThumbnailAspectRatio:self];
    
    if (!CGRectEqualToRect(_cropRect, CGRectZero))
        frameAspectRatio = _cropRect.size.width / _cropRect.size.height;
    else
        frameAspectRatio = originalAspectRatio;
    
    _thumbnailAspectRatio = frameAspectRatio;
    
    NSInteger thumbnailCount = (NSInteger)CGCeil(_summaryThumbnailWrapperView.frame.size.width / [self _thumbnailSizeWithAspectRatio:frameAspectRatio orientation:_cropOrientation].width);
    
    if ([dataSource respondsToSelector:@selector(videoScrubber:evenlySpacedTimestamps:startingAt:endingAt:)])
        _summaryTimestamps = [dataSource videoScrubber:self evenlySpacedTimestamps:thumbnailCount startingAt:0 endingAt:_duration];
    
    CGSize thumbnailImageSize = [self _thumbnailSizeWithAspectRatio:originalAspectRatio orientation:UIImageOrientationUp];
    CGFloat scale = MIN(2.0f, TGScreenScaling());
    thumbnailImageSize = CGSizeMake(thumbnailImageSize.width * scale, thumbnailImageSize.height * scale);
    
    if ([dataSource respondsToSelector:@selector(videoScrubber:requestThumbnailImagesForTimestamps:size:isSummaryThumbnails:)])
        [dataSource videoScrubber:self requestThumbnailImagesForTimestamps:_summaryTimestamps size:thumbnailImageSize isSummaryThumbnails:true];
}

- (void)ignoreThumbnails
{
    _ignoreThumbnailLoad = true;
}

- (void)resetThumbnails
{
    _ignoreThumbnailLoad = false;
    
    if (_summaryThumbnailViews.count < _summaryTimestamps.count)
    {
        id<TGVideoMessageScrubberDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(videoScrubberDidCancelRequestingThumbnails:)])
            [delegate videoScrubberDidCancelRequestingThumbnails:self];
    }
    
    for (UIView *view in _summaryThumbnailWrapperView.subviews)
        [view removeFromSuperview];
    
    for (UIView *view in _zoomedThumbnailWrapperView.subviews)
        [view removeFromSuperview];
    
    _summaryThumbnailViews = nil;
    _summaryTimestamps = nil;
}

- (void)reloadData
{
    [self reloadDataAndReset:true];
}

- (void)reloadDataAndReset:(bool)reset
{
    id<TGVideoMessageScrubberDataSource> dataSource = self.dataSource;
    if ([dataSource respondsToSelector:@selector(videoScrubberDuration:)])
        _duration = [dataSource videoScrubberDuration:self];
    else
        return;
    
    if (!reset && _summaryThumbnailViews.count > 0 && _summaryThumbnailSnapshotView == nil) {
        _summaryThumbnailSnapshotView = [_summaryThumbnailWrapperView snapshotViewAfterScreenUpdates:false];
        _summaryThumbnailSnapshotView.frame = _summaryThumbnailWrapperView.frame;
        [_summaryThumbnailWrapperView.superview insertSubview:_summaryThumbnailSnapshotView aboveSubview:_summaryThumbnailWrapperView];
    } else if (reset) {
        [_summaryThumbnailSnapshotView removeFromSuperview];
        _summaryThumbnailSnapshotView = nil;
    }
    
    [self _layoutTrimView];
    
    [self reloadThumbnails];
}

- (void)setThumbnailImage:(UIImage *)image forTimestamp:(NSTimeInterval)__unused timestamp isSummaryThubmnail:(bool)isSummaryThumbnail
{
    TGVideoMessageScrubberThumbnailView *thumbnailView = [[TGVideoMessageScrubberThumbnailView alloc] initWithImage:image originalSize:_originalSize cropRect:_cropRect cropOrientation:_cropOrientation cropMirrored:_cropMirrored];
    
    if (isSummaryThumbnail)
    {
        [_summaryThumbnailWrapperView addSubview:thumbnailView];
        [_summaryThumbnailViews addObject:thumbnailView];
    }
    
    if ((isSummaryThumbnail && _summaryThumbnailViews.count == _summaryTimestamps.count))
    {
        if (!_ignoreThumbnailLoad)
        {
            id<TGVideoMessageScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidFinishRequestingThumbnails:)])
                [delegate videoScrubberDidFinishRequestingThumbnails:self];
        }
        _ignoreThumbnailLoad = false;
        
        if (isSummaryThumbnail)
        {
            [self _layoutSummaryThumbnailViews];
            
            UIView *snapshotView = _summaryThumbnailSnapshotView;
            _summaryThumbnailSnapshotView = nil;
            
            if (snapshotView != nil)
            {
                _fadingThumbnailViews = true;
                [UIView animateWithDuration:0.3f animations:^
                 {
                     snapshotView.alpha = 0.0f;
                 } completion:^(__unused BOOL finished)
                 {
                     _fadingThumbnailViews = false;
                     [snapshotView removeFromSuperview];
                 }];
            }
        }
    }
}

- (CGSize)_thumbnailSize
{
    return [self _thumbnailSizeWithAspectRatio:_thumbnailAspectRatio orientation:_cropOrientation];
}

- (CGSize)_thumbnailSizeWithAspectRatio:(CGFloat)__unused aspectRatio orientation:(UIImageOrientation)__unused orientation
{
    return CGSizeMake(33, 33);
}

- (void)_layoutSummaryThumbnailViews
{
    if (_summaryThumbnailViews.count == 0)
        return;
    
    CGSize thumbnailViewSize = [self _thumbnailSize];
    CGFloat totalWidth = thumbnailViewSize.width * _summaryThumbnailViews.count;
    CGFloat originX = (_summaryThumbnailWrapperView.frame.size.width - totalWidth) / 2;
    
    [_summaryThumbnailViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(originX + thumbnailViewSize.width * index, 0, thumbnailViewSize.width, thumbnailViewSize.height);
    }];
}

- (void)setIsPlaying:(bool)isPlaying
{
    _isPlaying = isPlaying;
    
    if (_isPlaying)
        [self _updateScrubberAnimationsAndResetCurrentPosition:false];
    else
        [self removeHandleAnimation];
}

- (void)setValue:(NSTimeInterval)value
{
    [self setValue:value resetPosition:false];
}

- (void)setValue:(NSTimeInterval)value resetPosition:(bool)resetPosition
{
    if (_duration < FLT_EPSILON)
        return;
    
    if (value > _duration)
        value = _duration;
    
    _value = value;
    
    if (resetPosition)
        [self _updateScrubberAnimationsAndResetCurrentPosition:true];
}

- (void)_updateScrubberAnimationsAndResetCurrentPosition:(bool)resetCurrentPosition
{
    if (_duration < FLT_EPSILON)
        return;
    
    CGPoint point = [self _scrubberPositionForPosition:_value duration:_duration];
    CGRect frame = CGRectMake(CGFloor(point.x) - _scrubberHandle.frame.size.width / 2, _scrubberHandle.frame.origin.y, _scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height);
    
    if (_trimStartValue > DBL_EPSILON && fabs(_value - _trimStartValue) < 0.01)
    {
        frame = CGRectMake(_trimView.frame.origin.x + [self _scrubbingRect].origin.x, _scrubberHandle.frame.origin.y, _scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height);
    }
    else if (fabs(_value - _trimEndValue) < 0.01)
    {
        frame = CGRectMake(_trimView.frame.origin.x + _trimView.frame.size.width - [self _scrubbingRect].origin.x - _scrubberHandle.frame.size.width, _scrubberHandle.frame.origin.y, _scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height);
    }
    
    if (_isPlaying)
    {
        if (resetCurrentPosition)
            _scrubberHandle.frame = frame;
        
        CGRect scrubbingRect = [self _scrubbingRect];
        CGFloat maxPosition = scrubbingRect.origin.x + scrubbingRect.size.width - _scrubberHandle.frame.size.width / 2;
        NSTimeInterval duration = _duration;
        NSTimeInterval value = _value;
        
        if (self.allowsTrimming)
        {
            maxPosition = MIN(maxPosition, CGRectGetMaxX(_trimView.frame) - scrubbingRect.origin.x - _scrubberHandle.frame.size.width / 2);
            duration = _trimEndValue - _trimStartValue;
            value = _value - _trimStartValue;
        }
        
        CGRect endFrame = CGRectMake(maxPosition - _scrubberHandle.frame.size.width / 2, frame.origin.y, _scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height);
        
        [self addHandleAnimationFromFrame:_scrubberHandle.frame toFrame:endFrame duration:MAX(0.0, duration - value)];
    }
    else
    {
        [self removeHandleAnimation];
        _scrubberHandle.frame = frame;
    }
}

- (void)addHandleAnimationFromFrame:(CGRect)fromFrame toFrame:(CGRect)toFrame duration:(NSTimeInterval)duration
{
    [self removeHandleAnimation];
    
    POPBasicAnimation *animation = [POPBasicAnimation animationWithPropertyNamed:kPOPViewFrame];
    animation.fromValue = [NSValue valueWithCGRect:fromFrame];
    animation.toValue = [NSValue valueWithCGRect:toFrame];
    animation.duration = duration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.clampMode = kPOPAnimationClampBoth;
    animation.roundingFactor = 0.5f;
    
    [_scrubberHandle pop_addAnimation:animation forKey:@"progress"];
}

- (void)removeHandleAnimation
{
    [_scrubberHandle pop_removeAnimationForKey:@"progress"];
}

- (void)resetToStart
{
    _value = _trimStartValue;
    
    [self removeHandleAnimation];
    _scrubberHandle.center = CGPointMake(_trimView.frame.origin.x + [self _scrubbingRect].origin.x + _scrubberHandle.frame.size.width / 2, _scrubberHandle.center.y);
}

#pragma mark - Scrubber Handle

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer.view != otherGestureRecognizer.view)
        return false;
    
    return true;
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            _scrubbing = true;
            
            id<TGVideoMessageScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidBeginScrubbing:)])
                [delegate videoScrubberDidBeginScrubbing:self];

            _endedInteraction = false;
            _beganInteraction = true;
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (_endedInteraction)
                return;
            
            _scrubbing = false;
            
            id<TGVideoMessageScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidEndScrubbing:)])
                [delegate videoScrubberDidEndScrubbing:self];
            
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint translation = [gestureRecognizer translationInView:self];
    [gestureRecognizer setTranslation:CGPointZero inView:self];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            _scrubbing = true;
            
            [self removeHandleAnimation];
            
            id<TGVideoMessageScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidBeginScrubbing:)])
                [delegate videoScrubberDidBeginScrubbing:self];
            
            _endedInteraction = false;
            _beganInteraction = true;
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            CGRect scrubbingRect = [self _scrubbingRect];
            CGRect normalScrubbingRect = [self _scrubbingRect];
            CGFloat minPosition = scrubbingRect.origin.x + _scrubberHandle.frame.size.width / 2;
            CGFloat maxPosition = scrubbingRect.origin.x + scrubbingRect.size.width - _scrubberHandle.frame.size.width / 2;
            if (self.allowsTrimming)
            {
                minPosition = MAX(minPosition, _trimView.frame.origin.x + normalScrubbingRect.origin.x + _scrubberHandle.frame.size.width / 2);
                maxPosition = MIN(maxPosition, CGRectGetMaxX(_trimView.frame) - normalScrubbingRect.origin.x - _scrubberHandle.frame.size.width / 2);
            }
            
            _scrubberHandle.center = CGPointMake(MIN(MAX(_scrubberHandle.center.x + translation.x, minPosition), maxPosition), _scrubberHandle.center.y);
            
            NSTimeInterval position = [self _positionForScrubberPosition:_scrubberHandle.center duration:_duration];
            
            if (self.allowsTrimming)
            {
                if (ABS(_scrubberHandle.center.x - minPosition) < FLT_EPSILON)
                    position = _trimStartValue;
                else if (ABS(_scrubberHandle.center.x - maxPosition) < FLT_EPSILON)
                    position = _trimEndValue;
            }
            
            _value = position;
            
            id<TGVideoMessageScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubber:valueDidChange:)])
                [delegate videoScrubber:self valueDidChange:position];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (_endedInteraction)
                return;
            
            _scrubbing = false;
            
            id<TGVideoMessageScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidEndScrubbing:)])
                [delegate videoScrubberDidEndScrubbing:self];
            
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (void)setScrubberHandleHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _scrubberHandle.hidden = false;
        [UIView animateWithDuration:0.25f animations:^
         {
             _scrubberHandle.alpha = hidden ? 0.0f : 1.0f;
         } completion:^(BOOL finished)
         {
             if (finished)
                 _scrubberHandle.hidden = hidden;
         }];
    }
    else
    {
        _scrubberHandle.hidden = hidden;
        _scrubberHandle.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (CGPoint)_scrubberPositionForPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration
{
    CGRect scrubbingRect = [self _scrubbingRect];
    
    if (duration < FLT_EPSILON)
    {
        position = 0.0;
        duration = 1.0;
    }
    
    return CGPointMake(_scrubberHandle.frame.size.width / 2 + scrubbingRect.origin.x + (CGFloat)(position / duration) * (scrubbingRect.size.width - _scrubberHandle.frame.size.width), CGRectGetMidY([self _scrubbingRect]));
}

- (NSTimeInterval)_positionForScrubberPosition:(CGPoint)scrubberPosition duration:(NSTimeInterval)duration
{
    CGRect scrubbingRect = [self _scrubbingRect];
    return (scrubberPosition.x - _scrubberHandle.frame.size.width / 2 - scrubbingRect.origin.x) / (scrubbingRect.size.width - _scrubberHandle.frame.size.width) * duration;
}

- (CGRect)_scrubbingRect
{
    CGFloat width = self.frame.size.width;
    CGFloat origin = 0;
    if (self.allowsTrimming)
    {
        width = width - 16 * 2;
        origin = 16;
    }
    else
    {
        width = width - 2 * 2;
        origin = 2;
    }
    
    return CGRectMake(origin, 0, width, 33);
}

#pragma mark - Trimming

- (bool)hasTrimming
{
    return (_allowsTrimming && (_trimStartValue > FLT_EPSILON || _trimEndValue < _duration));
}

- (void)setAllowsTrimming:(bool)allowsTrimming
{
    _allowsTrimming = allowsTrimming;
    _trimView.trimmingEnabled = allowsTrimming;
}

- (NSTimeInterval)trimStartValue
{
    return MAX(0.0, _trimStartValue);
}

- (void)setTrimStartValue:(NSTimeInterval)trimStartValue
{
    _trimStartValue = trimStartValue;
    
    [self _layoutTrimView];
    
    if (_value < _trimStartValue)
    {
        [self setValue:_trimStartValue];
        _scrubberHandle.center = CGPointMake(_trimView.frame.origin.x + 12 + _scrubberHandle.frame.size.width / 2, _scrubberHandle.center.y);
    }
}

- (NSTimeInterval)trimEndValue
{
    return MIN(_duration, _trimEndValue);
}

- (void)setTrimEndValue:(NSTimeInterval)trimEndValue
{
    _trimEndValue = trimEndValue;
    
    [self _layoutTrimView];
    
    if (_value > _trimEndValue)
    {
        [self setValue:_trimEndValue];
        _scrubberHandle.center = CGPointMake(CGRectGetMaxX(_trimView.frame) - 12 - _scrubberHandle.frame.size.width / 2, _scrubberHandle.center.y);
    }
}

- (void)setTrimApplied:(bool)trimApplied
{
    [_trimView setTrimming:trimApplied animated:false];
}

- (void)_trimStartPosition:(NSTimeInterval *)trimStartPosition trimEndPosition:(NSTimeInterval *)trimEndPosition forTrimFrame:(CGRect)trimFrame duration:(NSTimeInterval)duration
{
    if (trimStartPosition == NULL || trimEndPosition == NULL)
        return;
    
    CGRect trimRect = [self _scrubbingRect];
    
    *trimStartPosition = (CGRectGetMinX(trimFrame) + 12 - trimRect.origin.x) / trimRect.size.width * duration;
    *trimEndPosition = (CGRectGetMaxX(trimFrame) - 12 - trimRect.origin.x) / trimRect.size.width * duration;
}

- (CGRect)_trimFrameForStartPosition:(NSTimeInterval)startPosition endPosition:(NSTimeInterval)endPosition duration:(NSTimeInterval)duration
{
    CGRect trimRect = [self _scrubbingRect];
    CGRect normalScrubbingRect = [self _scrubbingRect];
    
    CGFloat minX = (CGFloat)startPosition * trimRect.size.width / (CGFloat)duration + trimRect.origin.x - normalScrubbingRect.origin.x;
    CGFloat maxX = (CGFloat)endPosition * trimRect.size.width / (CGFloat)duration + trimRect.origin.x + normalScrubbingRect.origin.x;
    
    return CGRectMake(minX, 0, maxX - minX, 33);
}

- (void)_layoutTrimView
{
    if (_duration > DBL_EPSILON)
    {
        NSTimeInterval endPosition = _trimEndValue;
        if (endPosition < DBL_EPSILON)
            endPosition = _duration;
        
        _trimView.frame = [self _trimFrameForStartPosition:_trimStartValue endPosition:_trimEndValue duration:_duration];
    }
    else
    {
        _trimView.frame = _wrapperView.bounds;
    }
    
    [self _layoutTrimCurtainViews];
}

- (void)_layoutTrimCurtainViews
{
    _leftCurtainView.hidden = !self.allowsTrimming;
    _rightCurtainView.hidden = !self.allowsTrimming;
    
    if (self.allowsTrimming)
    {
        CGRect scrubbingRect = [self _scrubbingRect];
        CGRect normalScrubbingRect = [self _scrubbingRect];
        
        _leftCurtainView.frame = CGRectMake(scrubbingRect.origin.x - 16.0f, 0.0f, _trimView.frame.origin.x - scrubbingRect.origin.x + normalScrubbingRect.origin.x + 16.0f, 33);
        _rightCurtainView.frame = CGRectMake(CGRectGetMaxX(_trimView.frame) - 16.0f, 0.0f, scrubbingRect.origin.x + scrubbingRect.size.width - CGRectGetMaxX(_trimView.frame) - scrubbingRect.origin.x + normalScrubbingRect.origin.x + 32.0f, 33);
    }
}

#pragma mark - Layout

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    _summaryThumbnailWrapperView.frame = CGRectMake(0.0f, 0.0f, frame.size.width, 33);
    _zoomedThumbnailWrapperView.frame = _summaryThumbnailWrapperView.frame;
    
    _leftMaskView.frame = CGRectMake(0.0f, 0.0f, 16.0f, 33.0f);
    _rightMaskView.frame = CGRectMake(frame.size.width - 16.0f, 0.0f, 16.0f, 33.0f);
}

- (void)layoutSubviews
{
    _wrapperView.frame = CGRectMake(0, 0, self.frame.size.width, 33);
    [self _layoutTrimView];
    
    [self _updateScrubberAnimationsAndResetCurrentPosition:true];
}

@end
