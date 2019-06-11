#import "TGMediaPickerGalleryVideoScrubber.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import "POPBasicAnimation.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import <LegacyComponents/TGPhotoEditorInterfaceAssets.h>

#import "TGMediaPickerGalleryVideoScrubberThumbnailView.h"
#import "TGMediaPickerGalleryVideoTrimView.h"

static const CGFloat TGVideoScrubberMinimumTrimDuration = 1.0f;
static const CGFloat TGVideoScrubberZoomActivationInterval = 0.25f;
static const CGFloat TGVideoScrubberTrimRectEpsilon = 3.0f;
static const CGFloat TGVideoScrubberPadding = 8.0f;

typedef enum
{
    TGMediaPickerGalleryVideoScrubberPivotSourceHandle,
    TGMediaPickerGalleryVideoScrubberPivotSourceTrimStart,
    TGMediaPickerGalleryVideoScrubberPivotSourceTrimEnd
} TGMediaPickerGalleryVideoScrubberPivotSource;

@interface TGMediaPickerGalleryVideoScrubber () <UIGestureRecognizerDelegate>
{
    UILabel *_currentTimeLabel;
    UILabel *_inverseTimeLabel;
    
    UIControl *_wrapperView;
    UIView *_summaryThumbnailSnapshotView;
    UIView *_zoomedThumbnailWrapperView;
    UIView *_summaryThumbnailWrapperView;
    TGMediaPickerGalleryVideoTrimView *_trimView;
    UIView *_leftCurtainView;
    UIView *_rightCurtainView;
    UIControl *_scrubberHandle;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    
    bool _beganInteraction;
    bool _endedInteraction;
    
    bool _scrubbing;
    CGFloat _scrubbingPosition;
    
    NSTimeInterval _duration;

    bool _ignoreThumbnailLoad;
    bool _fadingThumbnailViews;
    CGFloat _thumbnailAspectRatio;
    NSArray *_summaryTimestamps;
    NSMutableArray *_summaryThumbnailViews;
    
    CGSize _originalSize;
    CGRect _cropRect;
    UIImageOrientation _cropOrientation;
    bool _cropMirrored;
    
    bool _zoomedIn;
    bool _preparingToZoomIn;
    bool _cancelledZoomIn;
    bool _animatingZoomIn;
    bool _animatingZoomOut;
    
    TGMediaPickerGalleryVideoScrubberPivotSource _pivotSource;
    NSTimeInterval _zoomedDuration;
    NSTimeInterval _zoomPivotPosition;
    CGFloat _zoomPivotCenter;
    CGFloat _zoomPivotOffset;
    NSInteger _zoomedPivotTimestampIndex;
    NSArray *_zoomedTimestamps;
    NSMutableArray *_zoomedThumbnailViews;
    
    UIImageView *_arrowView;
    UILabel *_recipientLabel;
}
@end

@implementation TGMediaPickerGalleryVideoScrubber

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _allowsTrimming = true;
        
        _currentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, 100, 15)];
        _currentTimeLabel.font = TGSystemFontOfSize(12.0f);
        _currentTimeLabel.backgroundColor = [UIColor clearColor];
        _currentTimeLabel.text = @"0:00";
        _currentTimeLabel.textColor = [UIColor whiteColor];
        [self addSubview:_currentTimeLabel];
        
        _inverseTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width - 108, 4, 100, 15)];
        _inverseTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _inverseTimeLabel.font = TGSystemFontOfSize(12.0f);
        _inverseTimeLabel.backgroundColor = [UIColor clearColor];
        _inverseTimeLabel.text = @"0:00";
        _inverseTimeLabel.textAlignment = NSTextAlignmentRight;
        _inverseTimeLabel.textColor = [UIColor whiteColor];
        [self addSubview:_inverseTimeLabel];
        
        _wrapperView = [[UIControl alloc] initWithFrame:CGRectMake(8, 24, 0, 36)];
        _wrapperView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -10);
        [self addSubview:_wrapperView];
        
        _zoomedThumbnailWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 32)];
        [_wrapperView addSubview:_zoomedThumbnailWrapperView];
        
        _summaryThumbnailWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 32)];
        _summaryThumbnailWrapperView.clipsToBounds = true;
        [_wrapperView addSubview:_summaryThumbnailWrapperView];
        
        _leftCurtainView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
        _leftCurtainView.backgroundColor = [[TGPhotoEditorInterfaceAssets toolbarBackgroundColor] colorWithAlphaComponent:0.8f];
        [_wrapperView addSubview:_leftCurtainView];

        _rightCurtainView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
        _rightCurtainView.backgroundColor = [[TGPhotoEditorInterfaceAssets toolbarBackgroundColor] colorWithAlphaComponent:0.8f];
        [_wrapperView addSubview:_rightCurtainView];
        
        __weak TGMediaPickerGalleryVideoScrubber *weakSelf = self;
        _trimView = [[TGMediaPickerGalleryVideoTrimView alloc] initWithFrame:CGRectZero];
        _trimView.exclusiveTouch = true;
        _trimView.trimmingEnabled = _allowsTrimming;
        _trimView.didBeginEditing = ^(bool start)
        {
            __strong TGMediaPickerGalleryVideoScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidBeginEditing:)])
                [delegate videoScrubberDidBeginEditing:strongSelf];
            
            [strongSelf cancelZoomIn];
            if ([strongSelf zoomAvailable])
            {
                if (start)
                    strongSelf->_pivotSource = TGMediaPickerGalleryVideoScrubberPivotSourceTrimStart;
                else
                    strongSelf->_pivotSource = TGMediaPickerGalleryVideoScrubberPivotSourceTrimEnd;
                
                [strongSelf performSelector:@selector(zoomIn) withObject:nil afterDelay:TGVideoScrubberZoomActivationInterval];
            }
            
            [strongSelf->_trimView setTrimming:true animated:true];
            
            [strongSelf setScrubberHandleHidden:true animated:false];
        };
        _trimView.didEndEditing = ^
        {
            __strong TGMediaPickerGalleryVideoScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidEndEditing:)])
                [delegate videoScrubberDidEndEditing:strongSelf];
            
            CGRect newTrimRect = strongSelf->_trimView.frame;
            CGRect trimRect = [strongSelf _scrubbingRect];
            CGRect normalScrubbingRect = [strongSelf _scrubbingRectZoomedIn:false];
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
            
            [strongSelf cancelZoomIn];
            if (strongSelf->_zoomedIn)
                [strongSelf zoomOut];
        };
        _trimView.startHandleMoved = ^(CGPoint translation)
        {
            __strong TGMediaPickerGalleryVideoScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf->_animatingZoomIn)
                return;
            
            UIView *trimView = strongSelf->_trimView;
            
            CGRect availableTrimRect = [strongSelf _scrubbingRect];
            CGRect normalScrubbingRect = [strongSelf _scrubbingRectZoomedIn:false];
            CGFloat originX = MAX(0, trimView.frame.origin.x + translation.x);
            CGFloat delta = originX - trimView.frame.origin.x;
            CGFloat maxWidth = availableTrimRect.size.width + normalScrubbingRect.origin.x * 2 - originX;
            
            CGRect trimViewRect = CGRectMake(originX,
                                             trimView.frame.origin.y,
                                             MIN(maxWidth, trimView.frame.size.width - delta),
                                             trimView.frame.size.height);
            
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
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubber:editingStartValueDidChange:)])
                [delegate videoScrubber:strongSelf editingStartValueDidChange:trimStartPosition];
            
            [strongSelf cancelZoomIn];
            if ([strongSelf zoomAvailable])
            {
                strongSelf->_pivotSource = TGMediaPickerGalleryVideoScrubberPivotSourceTrimStart;
                [strongSelf performSelector:@selector(zoomIn) withObject:nil afterDelay:TGVideoScrubberZoomActivationInterval];
            }
        };
        _trimView.endHandleMoved = ^(CGPoint translation)
        {
            __strong TGMediaPickerGalleryVideoScrubber *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf->_animatingZoomIn)
                return;
            
            UIView *trimView = strongSelf->_trimView;
            
            CGRect availableTrimRect = [strongSelf _scrubbingRect];
            CGRect normalScrubbingRect = [strongSelf _scrubbingRectZoomedIn:false];
            CGFloat localOriginX = trimView.frame.origin.x - availableTrimRect.origin.x + normalScrubbingRect.origin.x;
            CGFloat maxWidth = availableTrimRect.size.width + normalScrubbingRect.origin.x * 2 - localOriginX;
            
            CGRect trimViewRect = CGRectMake(trimView.frame.origin.x,
                                             trimView.frame.origin.y,
                                             MIN(maxWidth, trimView.frame.size.width + translation.x),
                                             trimView.frame.size.height);
            
            NSTimeInterval trimStartPosition = 0.0;
            NSTimeInterval trimEndPosition = 0.0;
            [strongSelf _trimStartPosition:&trimStartPosition trimEndPosition:&trimEndPosition forTrimFrame:trimViewRect duration:strongSelf.duration];
            
            NSTimeInterval duration = trimEndPosition - trimStartPosition;
            
            if (trimEndPosition - trimStartPosition < TGVideoScrubberMinimumTrimDuration)
                return;
            
            if (strongSelf.maximumLength > DBL_EPSILON && duration > strongSelf.maximumLength)
            {
                trimViewRect = CGRectMake(trimView.frame.origin.x + translation.x,
                                          trimView.frame.origin.y,
                                          trimView.frame.size.width,
                                          trimView.frame.size.height);
                
                [strongSelf _trimStartPosition:&trimStartPosition trimEndPosition:&trimEndPosition forTrimFrame:trimViewRect duration:strongSelf.duration];
            }
            
            trimView.frame = trimViewRect;
            
            [strongSelf _layoutTrimCurtainViews];
            
            strongSelf->_trimStartValue = trimStartPosition;
            strongSelf->_trimEndValue = trimEndPosition;
            
            [strongSelf setValue:strongSelf->_trimEndValue];
            
            UIView *handle = strongSelf->_scrubberHandle;
            handle.center = CGPointMake(CGRectGetMaxX(trimView.frame) - 12 - handle.frame.size.width / 2, handle.center.y);
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubber:editingEndValueDidChange:)])
                [delegate videoScrubber:strongSelf editingEndValueDidChange:trimEndPosition];
            
            [strongSelf cancelZoomIn];
            if ([strongSelf zoomAvailable])
            {
                strongSelf->_pivotSource = TGMediaPickerGalleryVideoScrubberPivotSourceTrimEnd;
                [strongSelf performSelector:@selector(zoomIn) withObject:nil afterDelay:TGVideoScrubberZoomActivationInterval];
            }
        };
        [_wrapperView addSubview:_trimView];
        
        _scrubberHandle = [[UIControl alloc] initWithFrame:CGRectMake(0, -4.0f, 5.0f, 44.0f)];
        _scrubberHandle.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -12, -5, -12);
        [_wrapperView addSubview:_scrubberHandle];
        
        static UIImage *handleViewImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(_scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetShadowWithColor(context, CGSizeMake(0, 0), 0.5f, [UIColor colorWithWhite:0.0f alpha:0.65f].CGColor);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5f, 0.5f, _scrubberHandle.frame.size.width - 1, _scrubberHandle.frame.size.height - 1.0f) cornerRadius:2.0f];
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
        [_scrubberHandle addGestureRecognizer:_pressGestureRecognizer];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [_scrubberHandle addGestureRecognizer:_panGestureRecognizer];
        
        _arrowView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"PhotoPickerArrow")];
        _arrowView.alpha = 0.45f;
        _arrowView.hidden = true;
        [self addSubview:_arrowView];
        
        _recipientLabel = [[UILabel alloc] init];
        _recipientLabel.backgroundColor = [UIColor clearColor];
        _recipientLabel.font = TGBoldSystemFontOfSize(13.0f);
        _recipientLabel.textColor = UIColorRGBA(0xffffff, 0.45f);
        _recipientLabel.hidden = true;
        [self addSubview:_recipientLabel];
    }
    return self;
}

- (void)setRecipientName:(NSString *)recipientName
{
    _recipientLabel.text = recipientName;
    _recipientLabel.hidden = recipientName.length == 0;
    _arrowView.hidden = _recipientLabel.hidden;
    
    [_recipientLabel sizeToFit];
    
    [self _layoutRecipientLabel];
}

- (bool)zoomAvailable
{
    if (_zoomedIn || _preparingToZoomIn || _summaryTimestamps.count == 0)
        return false;
    
    return _duration > 1.0f;
}

- (void)zoomIn
{
    if (![self zoomAvailable])
        return;
    
    _preparingToZoomIn = true;
    
    NSTimeInterval trimStartValue = 0.0;
    NSTimeInterval trimEndValue = 0.0;
    
    [self _trimStartPosition:&trimStartValue trimEndPosition:&trimEndValue forTrimFrame:_trimView.frame duration:_duration];
    
    switch (_pivotSource)
    {
        case TGMediaPickerGalleryVideoScrubberPivotSourceTrimStart:
            _zoomPivotCenter = [self _zoomPivotCenterForTrimStart];
            _zoomPivotPosition = trimStartValue;
            break;
            
        case TGMediaPickerGalleryVideoScrubberPivotSourceTrimEnd:
            _zoomPivotCenter = [self _zoomPivotCenterForTrimEnd];
            _zoomPivotPosition = trimEndValue;
            break;
            
        default:
            _zoomPivotCenter = [self _zoomPivotCenterForHandle];
            _zoomPivotPosition = [self _positionForScrubberPosition:_scrubberHandle.center duration:_duration];
            break;
    }
    
    if (_summaryTimestamps.count > 1)
        _zoomedDuration = [_summaryTimestamps[1] doubleValue] - [_summaryTimestamps[0] doubleValue];

    __block NSTimeInterval minimalInterval = DBL_MAX;
    __block NSUInteger timestampIndex = 0;
    [_summaryTimestamps enumerateObjectsUsingBlock:^(NSNumber *timestamp, NSUInteger index, __unused BOOL *stop)
    {
        NSTimeInterval timestampValue = timestamp.doubleValue;
        NSTimeInterval interval = fabs(timestampValue - _zoomPivotPosition);
        if (interval < minimalInterval)
        {
            minimalInterval = interval;
            timestampIndex = index;
        }
    }];
    
    _zoomedPivotTimestampIndex = timestampIndex;
    
    id<TGMediaPickerGalleryVideoScrubberDataSource> dataSource = self.dataSource;
    
    NSInteger leftSummaryTimestampIndex = MAX(0, (NSInteger)_zoomedPivotTimestampIndex - 1);
    NSInteger rightSummaryTimestampIndex = MIN((NSInteger)_zoomedPivotTimestampIndex + 1, (NSInteger)_summaryTimestamps.count - 1);
    
    NSTimeInterval leftTimestamp = [[_summaryTimestamps objectAtIndex:leftSummaryTimestampIndex] doubleValue];
    NSTimeInterval rightTimestamp = [[_summaryTimestamps objectAtIndex:rightSummaryTimestampIndex] doubleValue];
    
    if ((NSUInteger)rightSummaryTimestampIndex == _summaryTimestamps.count - 1)
        rightTimestamp = _duration;
    
    CGSize thumbnailImageSize = [self _thumbnailSize];
    CGFloat countMultiplier = 1.0f;
    if (_zoomedPivotTimestampIndex > 01)
        countMultiplier = 2.1f;
    NSInteger thumbnailCount = (NSInteger)CGCeil(_summaryThumbnailWrapperView.frame.size.width / thumbnailImageSize.width * countMultiplier);
    
    if ([dataSource respondsToSelector:@selector(videoScrubber:evenlySpacedTimestamps:startingAt:endingAt:)])
        _zoomedTimestamps = [dataSource videoScrubber:self evenlySpacedTimestamps:thumbnailCount startingAt:leftTimestamp endingAt:rightTimestamp];
    
    CGFloat scale = MIN(2.0f, TGScreenScaling());
    thumbnailImageSize = CGSizeMake(thumbnailImageSize.width * scale, thumbnailImageSize.height * scale);
    
    _zoomedThumbnailViews = [[NSMutableArray alloc] init];
    
    if ([dataSource respondsToSelector:@selector(videoScrubber:requestThumbnailImagesForTimestamps:size:isSummaryThumbnails:)])
        [dataSource videoScrubber:self requestThumbnailImagesForTimestamps:_zoomedTimestamps size:thumbnailImageSize isSummaryThumbnails:false];
}

- (CGFloat)_zoomPivotCenterForHandle
{
    CGFloat duration = MAX(0.0001, _duration);
    CGFloat fractValue = (CGFloat)_value / duration * 2 - 1;
    return _scrubberHandle.center.x - [self _scrubbingRectZoomedIn:false].origin.x + fractValue * _scrubberHandle.frame.size.width / 2;
}

- (CGFloat)_zoomPivotCenterForTrimStart
{
    return CGRectGetMinX(_trimView.frame);
}

- (CGFloat)_zoomPivotCenterForTrimEnd
{
    CGRect scrubbingRect = [self _scrubbingRectZoomedIn:false];
    return CGRectGetMaxX(_trimView.frame) - scrubbingRect.origin.x * 2;
}

- (void)commitZoomIn
{
    if (!_preparingToZoomIn)
        return;
    
    if (_summaryThumbnailViews.count == 0)
        return;
    
    _zoomedIn = true;
    _preparingToZoomIn = false;
    _animatingZoomIn = true;
    
    [self _layoutZoomedThumbnailViewsStacked:true];
    
    NSTimeInterval pivotTimestamp = [_summaryTimestamps[_zoomedPivotTimestampIndex] doubleValue];
    CGRect normalPivotFrame = [_summaryThumbnailViews[_zoomedPivotTimestampIndex] frame];
    CGRect normalScrubbingRect = [self _scrubbingRectZoomedIn:false];
    CGRect zoomedScrubbingRect = [self _scrubbingRectZoomedIn:true];
    
    CGFloat duration = MAX(0.0001, _duration);
    CGFloat zoomedPivotPosition = (zoomedScrubbingRect.size.width - [self _thumbnailSize].width) * (CGFloat)pivotTimestamp / (CGFloat)duration;
    _zoomPivotOffset = zoomedPivotPosition - normalPivotFrame.origin.x + zoomedScrubbingRect.origin.x - normalScrubbingRect.origin.x;
    
    _summaryThumbnailWrapperView.clipsToBounds = false;
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionAllowUserInteraction animations:^
    {
        [self _layoutZoomedThumbnailViewsStacked:false];
        [self _layoutSummaryThumbnailViewsForZoom:true];
        [self _layoutTrimViewZoomedIn:_zoomedIn];
    } completion:^(__unused BOOL finished)
    {
        _animatingZoomIn = false;
    }];
}

- (void)cancelZoomIn
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(zoomIn) object:nil];
    
    if (!_preparingToZoomIn)
        return;
    
    _preparingToZoomIn = false;
    
    id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(videoScrubberDidCancelRequestingThumbnails:)])
        [delegate videoScrubberDidCancelRequestingThumbnails:self];
    
    [self _resetZooming];
}

- (void)zoomOut
{
    _animatingZoomOut = true;
    _trimView.userInteractionEnabled = false;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionLayoutSubviews animations:^
    {
        [self _layoutSummaryThumbnailViewsForZoom:false];
        [self _layoutZoomedThumbnailViewsStacked:true];
        [self _layoutTrimViewZoomedIn:false];
        [self _updateScrubberAnimationsAndResetCurrentPosition:true zoomedIn:false];
    } completion:^(__unused BOOL finished)
    {
        _zoomedIn = false;
        _animatingZoomOut = false;
        
        [self _resetZooming];
        
        _trimView.userInteractionEnabled = true;
        _summaryThumbnailWrapperView.clipsToBounds = true;
    }];
}

- (void)_resetZooming
{
    _zoomedIn = false;
    _zoomedDuration = 0.0;
    _zoomPivotPosition = 0.0f;
    _zoomPivotOffset = 0.0f;
    _zoomedPivotTimestampIndex = -1;
    for (UIView *view in _zoomedThumbnailWrapperView.subviews)
        [view removeFromSuperview];
    _zoomedThumbnailViews = nil;
}

- (void)reloadThumbnails
{
    [self resetThumbnails];
    
    id<TGMediaPickerGalleryVideoScrubberDataSource> dataSource = self.dataSource;
    
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
    
    if (_summaryThumbnailViews.count < _summaryTimestamps.count || _zoomedThumbnailViews.count < _zoomedTimestamps.count)
    {
        id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(videoScrubberDidCancelRequestingThumbnails:)])
            [delegate videoScrubberDidCancelRequestingThumbnails:self];
    }
    
    for (UIView *view in _summaryThumbnailWrapperView.subviews)
        [view removeFromSuperview];
    
    for (UIView *view in _zoomedThumbnailWrapperView.subviews)
        [view removeFromSuperview];
    
    _summaryThumbnailViews = nil;
    _zoomedThumbnailViews = nil;
    
    _summaryTimestamps = nil;
    _zoomedTimestamps = nil;
    
    [self _resetZooming];
}

- (void)reloadData
{
    [self reloadDataAndReset:true];
}

- (void)reloadDataAndReset:(bool)reset
{
    id<TGMediaPickerGalleryVideoScrubberDataSource> dataSource = self.dataSource;
    if ([dataSource respondsToSelector:@selector(videoScrubberDuration:)])
        _duration = [dataSource videoScrubberDuration:self];
    else
        return;
    
    if (!reset && _summaryThumbnailViews.count > 0 && _summaryThumbnailSnapshotView == nil)
    {
        _summaryThumbnailSnapshotView = [_summaryThumbnailWrapperView snapshotViewAfterScreenUpdates:false];
        _summaryThumbnailSnapshotView.frame = _summaryThumbnailWrapperView.frame;
        [_summaryThumbnailWrapperView.superview insertSubview:_summaryThumbnailSnapshotView aboveSubview:_summaryThumbnailWrapperView];
    }
    else if (reset)
    {
        [_summaryThumbnailSnapshotView removeFromSuperview];
        _summaryThumbnailSnapshotView = nil;
    }
    
    [self _layoutTrimViewZoomedIn:false];
    
    [self reloadThumbnails];
}

- (void)setThumbnailImage:(UIImage *)image forTimestamp:(NSTimeInterval)__unused timestamp isSummaryThubmnail:(bool)isSummaryThumbnail
{
    TGMediaPickerGalleryVideoScrubberThumbnailView *thumbnailView = [[TGMediaPickerGalleryVideoScrubberThumbnailView alloc] initWithImage:image originalSize:_originalSize cropRect:_cropRect cropOrientation:_cropOrientation cropMirrored:_cropMirrored];
    
    if (isSummaryThumbnail)
    {
        [_summaryThumbnailWrapperView addSubview:thumbnailView];
        [_summaryThumbnailViews addObject:thumbnailView];
    }
    else
    {
        [_zoomedThumbnailWrapperView addSubview:thumbnailView];
        [_zoomedThumbnailViews addObject:thumbnailView];
    }
    
    if ((isSummaryThumbnail && _summaryThumbnailViews.count == _summaryTimestamps.count)
        || (!isSummaryThumbnail && _zoomedThumbnailViews.count == _zoomedTimestamps.count))
    {
        if (!_ignoreThumbnailLoad)
        {
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidFinishRequestingThumbnails:)])
                [delegate videoScrubberDidFinishRequestingThumbnails:self];
        }
        _ignoreThumbnailLoad = false;
        
        if (isSummaryThumbnail)
        {
            [self _layoutSummaryThumbnailViewsForZoom:false];
            
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
        else
        {
            [self commitZoomIn];
        }
    }
}

- (CGSize)_thumbnailSize
{
    return [self _thumbnailSizeWithAspectRatio:_thumbnailAspectRatio orientation:_cropOrientation];
}

- (CGSize)_thumbnailSizeWithAspectRatio:(CGFloat)aspectRatio orientation:(UIImageOrientation)orientation
{
    if (aspectRatio < FLT_EPSILON || isnan(aspectRatio))
        aspectRatio = 1.0f;
    
    if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight)
        aspectRatio = 1.0f / aspectRatio;
    return CGSizeMake(CGCeil(36.0f * aspectRatio), 36.0f);
}

- (void)_layoutSummaryThumbnailViewsForZoom:(bool)forZoom
{
    if (_summaryThumbnailViews.count == 0)
        return;
    
    CGSize thumbnailViewSize = [self _thumbnailSize];
    CGFloat totalWidth = thumbnailViewSize.width * _summaryThumbnailViews.count;
    CGFloat originX = (_summaryThumbnailWrapperView.frame.size.width - totalWidth) / 2;
    
    if (!forZoom)
    {
        [_summaryThumbnailViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
        {
            view.frame = CGRectMake(originX + thumbnailViewSize.width * index, 0, thumbnailViewSize.width, thumbnailViewSize.height);
        }];
    }
    else
    {
        CGRect leftThumbnailFrame = [_zoomedThumbnailViews.firstObject frame];
        CGRect rightThumbnailFrame = [_zoomedThumbnailViews.lastObject frame];
        
        CGRect pivotThumbnailFrame = CGRectMake(originX + thumbnailViewSize.width * _zoomedPivotTimestampIndex + _zoomPivotOffset, 0, thumbnailViewSize.width, thumbnailViewSize.height);
        
        [_summaryThumbnailViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
        {
            if ((NSInteger)index == _zoomedPivotTimestampIndex)
            {
                view.frame = pivotThumbnailFrame;
            }
            else
            {
                if ((NSInteger)index < _zoomedPivotTimestampIndex)
                {
                    CGFloat delta = pivotThumbnailFrame.origin.x - leftThumbnailFrame.origin.x + leftThumbnailFrame.size.width;
                    view.frame = CGRectMake(pivotThumbnailFrame.origin.x - delta * (_zoomedPivotTimestampIndex - index), 0, thumbnailViewSize.width, thumbnailViewSize.height);
                }
                else
                {
                    CGFloat delta = rightThumbnailFrame.origin.x + rightThumbnailFrame.size.width - pivotThumbnailFrame.origin.x;
                    view.frame = CGRectMake(pivotThumbnailFrame.origin.x + delta * (index - _zoomedPivotTimestampIndex), 0, thumbnailViewSize.width, thumbnailViewSize.height);
                }
            }
        }];
    }
}

- (void)_layoutZoomedThumbnailViewsStacked:(bool)stacked
{
    if (_zoomedThumbnailViews.count == 0 || _summaryThumbnailViews.count == 0)
        return;
    
    CGSize thumbnailViewSize = [self _thumbnailSize];
    CGRect stackFrame = [_summaryThumbnailViews[_zoomedPivotTimestampIndex] frame];
    
    if (stacked)
    {
        [_zoomedThumbnailViews enumerateObjectsUsingBlock:^(UIView *view, __unused NSUInteger index, __unused BOOL *stop)
        {
            view.frame = stackFrame;
        }];
    }
    else
    {
        NSTimeInterval zoomedPivotThumbnailTimestamp = [_summaryTimestamps[_zoomedPivotTimestampIndex] doubleValue];
        
        __block NSInteger i = 1;
        [_zoomedThumbnailViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
        {
            NSTimeInterval timestamp = [_zoomedTimestamps[index] doubleValue];
            if (timestamp >= zoomedPivotThumbnailTimestamp)
            {
                view.frame = CGRectMake(stackFrame.origin.x + thumbnailViewSize.width * i + _zoomPivotOffset, 0, thumbnailViewSize.width, thumbnailViewSize.height);
                i++;
            }
        }];
        
        i = 1;
        [_zoomedThumbnailViews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
        {
            NSTimeInterval timestamp = [_zoomedTimestamps[index] doubleValue];
            if (timestamp < zoomedPivotThumbnailTimestamp)
            {
                view.frame = CGRectMake(stackFrame.origin.x - thumbnailViewSize.width * i + _zoomPivotOffset, 0, thumbnailViewSize.width, thumbnailViewSize.height);
                i++;
            }
        }];
    }
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
    
    [self _updateTimeLabels];
    if (resetPosition)
        [self _updateScrubberAnimationsAndResetCurrentPosition:true];
}

- (void)_updateScrubberAnimationsAndResetCurrentPosition:(bool)resetCurrentPosition
{
    [self _updateScrubberAnimationsAndResetCurrentPosition:resetCurrentPosition zoomedIn:_zoomedIn];
}

- (void)_updateScrubberAnimationsAndResetCurrentPosition:(bool)resetCurrentPosition zoomedIn:(bool)zoomedIn
{
    if (isnan(_duration) || _duration < FLT_EPSILON)
        return;

    CGPoint point = [self _scrubberPositionForPosition:_value duration:_duration zoomedIn:zoomedIn];
    CGRect frame = CGRectMake(CGFloor(point.x) - _scrubberHandle.frame.size.width / 2, _scrubberHandle.frame.origin.y, _scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height);
    
    if (_trimStartValue > DBL_EPSILON && fabs(_value - _trimStartValue) < 0.01)
    {
        frame = CGRectMake(_trimView.frame.origin.x + [self _scrubbingRectZoomedIn:zoomedIn].origin.x, _scrubberHandle.frame.origin.y, _scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height);
    }
    else if (fabs(_value - _trimEndValue) < 0.01)
    {
        frame = CGRectMake(_trimView.frame.origin.x + _trimView.frame.size.width - [self _scrubbingRectZoomedIn:zoomedIn].origin.x - _scrubberHandle.frame.size.width, _scrubberHandle.frame.origin.y, _scrubberHandle.frame.size.width, _scrubberHandle.frame.size.height);
    }
    
    if (_isPlaying)
    {
        if (resetCurrentPosition)
            _scrubberHandle.frame = frame;
        
        CGRect scrubbingRect = [self _scrubbingRectZoomedIn:zoomedIn];
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
    [self _updateTimeLabels];
    
    [self removeHandleAnimation];
    _scrubberHandle.center = CGPointMake(_trimView.frame.origin.x + [self _scrubbingRect].origin.x + _scrubberHandle.frame.size.width / 2, _scrubberHandle.center.y);
}

- (void)_updateTimeLabels
{
    _currentTimeLabel.text = @"";
    
    NSString *text = [NSString stringWithFormat:@"%@ / %@", [TGMediaPickerGalleryVideoScrubber _stringFromTotalSeconds:(NSInteger)self.value], [TGMediaPickerGalleryVideoScrubber _stringFromTotalSeconds:(NSInteger)self.duration]];
    
    _inverseTimeLabel.text = text;
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
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidBeginScrubbing:)])
                [delegate videoScrubberDidBeginScrubbing:self];
            
            [self cancelZoomIn];
            if ([self zoomAvailable])
            {
                _pivotSource = TGMediaPickerGalleryVideoScrubberPivotSourceHandle;
                [self performSelector:@selector(zoomIn) withObject:nil afterDelay:TGVideoScrubberZoomActivationInterval];
            }
            
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
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidEndScrubbing:)])
                [delegate videoScrubberDidEndScrubbing:self];
            
            [self cancelZoomIn];
            if (_zoomedIn)
                [self zoomOut];
            
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
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidBeginScrubbing:)])
                [delegate videoScrubberDidBeginScrubbing:self];
            
            [self cancelZoomIn];
            
            _endedInteraction = false;
            _beganInteraction = true;
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            if (_animatingZoomIn || _animatingZoomOut)
                return;
            
            CGRect scrubbingRect = [self _scrubbingRect];
            CGRect normalScrubbingRect = [self _scrubbingRectZoomedIn:false];
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
            [self _updateTimeLabels];
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubber:valueDidChange:)])
                [delegate videoScrubber:self valueDidChange:position];
            
            [self cancelZoomIn];
            if ([self zoomAvailable])
            {
                _pivotSource = TGMediaPickerGalleryVideoScrubberPivotSourceHandle;
                [self performSelector:@selector(zoomIn) withObject:nil afterDelay:TGVideoScrubberZoomActivationInterval];
            }
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (_endedInteraction)
                return;
            
            _scrubbing = false;
            
            id<TGMediaPickerGalleryVideoScrubberDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(videoScrubberDidEndScrubbing:)])
                [delegate videoScrubberDidEndScrubbing:self];
            
            [self cancelZoomIn];
            if (_zoomedIn)
                [self zoomOut];
            
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
    return [self _scrubberPositionForPosition:position duration:duration zoomedIn:_zoomedIn];
}

- (CGPoint)_scrubberPositionForPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration zoomedIn:(bool)zoomedIn
{
    CGRect scrubbingRect = [self _scrubbingRectZoomedIn:zoomedIn];
    
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
    return [self _scrubbingRectZoomedIn:_zoomedIn];
}

- (CGRect)_scrubbingRectZoomedIn:(bool)zoomedIn
{
    CGFloat width = self.frame.size.width;
    CGFloat origin = 0;
    CGFloat handleWidth = self.allowsTrimming ? 12.0f : 0.0f;
    
    width = width - handleWidth * 2.0f - TGVideoScrubberPadding * 2.0f;
    origin = handleWidth;
    
    if (zoomedIn)
    {
        CGFloat zoomedDuration = _zoomedDuration;
        if (zoomedDuration < FLT_EPSILON)
            zoomedDuration = _duration;
        
        CGFloat newWidth = (CGFloat)(width * _duration / _zoomedDuration);
        CGFloat newPosition = _zoomPivotCenter * newWidth / width;
        
        origin += _zoomPivotCenter - newPosition;
        
        width = newWidth;
    }
    
    return CGRectMake(origin, 24, width, 40);
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

- (void)setTrimStartValue:(NSTimeInterval)trimStartValue
{
    _trimStartValue = trimStartValue;
    
    [self _layoutTrimViewZoomedIn:_zoomedIn];
    
    if (_value < _trimStartValue)
    {
        [self setValue:_trimStartValue];
        _scrubberHandle.center = CGPointMake(_trimView.frame.origin.x + 12 + _scrubberHandle.frame.size.width / 2, _scrubberHandle.center.y);
    }
}

- (void)setTrimEndValue:(NSTimeInterval)trimEndValue
{
    _trimEndValue = trimEndValue;
    
    [self _layoutTrimViewZoomedIn:_zoomedIn];
    
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

- (CGRect)_trimFrameForStartPosition:(NSTimeInterval)startPosition endPosition:(NSTimeInterval)endPosition duration:(NSTimeInterval)duration zoomedIn:(bool)zoomedIn
{
    CGRect trimRect = [self _scrubbingRectZoomedIn:zoomedIn];
    CGRect normalScrubbingRect = [self _scrubbingRectZoomedIn:false];
    
    CGFloat minX = duration > FLT_EPSILON ? ((CGFloat)startPosition * trimRect.size.width / (CGFloat)duration + trimRect.origin.x - normalScrubbingRect.origin.x) : 0.0f;
    CGFloat maxX = duration > FLT_EPSILON ? ((CGFloat)endPosition * trimRect.size.width / (CGFloat)duration + trimRect.origin.x + normalScrubbingRect.origin.x) : 0.0f;
    
    return CGRectMake(minX, 0, maxX - minX, 36);
}

- (void)_layoutTrimViewZoomedIn:(bool)zoomedIn
{
    if (_duration > DBL_EPSILON)
    {
        NSTimeInterval endPosition = _trimEndValue;
        if (endPosition < DBL_EPSILON)
            endPosition = _duration;
        
        _trimView.frame = [self _trimFrameForStartPosition:_trimStartValue endPosition:_trimEndValue duration:_duration zoomedIn:zoomedIn];
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
        CGRect normalScrubbingRect = [self _scrubbingRectZoomedIn:false];
        
        _leftCurtainView.frame = CGRectMake(scrubbingRect.origin.x - 12.0f, 0.0f, _trimView.frame.origin.x - scrubbingRect.origin.x + normalScrubbingRect.origin.x + 12.0f, 36.0f);
        _rightCurtainView.frame = CGRectMake(CGRectGetMaxX(_trimView.frame) - 4.0f, 0.0, scrubbingRect.origin.x + scrubbingRect.size.width - CGRectGetMaxX(_trimView.frame) - scrubbingRect.origin.x + normalScrubbingRect.origin.x + 4.0f + 12.0f, 36.0f);
    }
}

- (void)_layoutRecipientLabel
{
    if (self.frame.size.width < FLT_EPSILON)
        return;
    
    CGFloat screenWidth = MAX(self.frame.size.width, self.frame.size.height);
    CGFloat recipientWidth = MIN(_recipientLabel.frame.size.width, screenWidth - 100.0f);
    
    _arrowView.frame = CGRectMake(14.0f, 6.0f, _arrowView.frame.size.width, _arrowView.frame.size.height);
    _recipientLabel.frame = CGRectMake(CGRectGetMaxX(_arrowView.frame) + 6.0f, _arrowView.frame.origin.y - 2.0f, recipientWidth, _recipientLabel.frame.size.height);
}

- (void)setFrame:(CGRect)frame
{
    if (isnan(frame.origin.x) || isnan(frame.origin.y) || isnan(frame.size.width) || isnan(frame.size.height))
        return;
    
    [super setFrame:frame];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    _wrapperView.frame = CGRectMake(TGVideoScrubberPadding, 24, self.frame.size.width - TGVideoScrubberPadding * 2.0f, 36);
    [self _layoutTrimViewZoomedIn:_zoomedIn];
    
    CGRect scrubbingRect = [self _scrubbingRect];
    if (isnan(scrubbingRect.origin.x) || isnan(scrubbingRect.origin.y))
        return;
    
    _summaryThumbnailWrapperView.frame = CGRectMake(MIN(0.0, scrubbingRect.origin.x), 0.0f, MAX(_wrapperView.frame.size.width, scrubbingRect.size.width), 36.0f);
    _zoomedThumbnailWrapperView.frame = _summaryThumbnailWrapperView.frame;
    
    [self _updateScrubberAnimationsAndResetCurrentPosition:true];
    
    [self _layoutRecipientLabel];
}

+ (NSString *)_stringFromTotalSeconds:(NSInteger)totalSeconds
{
    NSInteger hours = (NSInteger)totalSeconds / 3600;
    NSInteger minutes = (NSInteger)(totalSeconds / 60) % 60;
    NSInteger seconds = (NSInteger)(totalSeconds % 60);
    
    if (hours > 0)
        return [NSString stringWithFormat:@"%02d:%02d:%02d", (int)hours, (int)minutes, (int)seconds];
    else
        return [NSString stringWithFormat:@"%d:%02d", (int)minutes, (int)seconds];
}

@end
