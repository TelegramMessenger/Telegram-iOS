#import "TGModernGalleryZoomableItemView.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGModernGalleryZoomableScrollView.h>
#import "TGModernGalleryImageItemContainerView.h"

@interface TGModernGalleryZoomableItemView () <UIScrollViewDelegate>

@property (nonatomic, strong) UIView *internalContainerView;

@end

@implementation TGModernGalleryZoomableItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _internalContainerView = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:_internalContainerView];
        
        _containerView = [[TGModernGalleryImageItemContainerView alloc] initWithFrame:_internalContainerView.bounds];
        [_internalContainerView addSubview:_containerView];
        
        _scrollView = [[TGModernGalleryZoomableScrollView alloc] initWithFrame:_containerView.bounds hasDoubleTap:true];
        _scrollView.delegate = self;
        _scrollView.showsHorizontalScrollIndicator = false;
        _scrollView.showsVerticalScrollIndicator = false;
        _scrollView.clipsToBounds = false;
        [_containerView addSubview:_scrollView];
        
        __weak TGModernGalleryZoomableItemView *weakSelf = self;
        
        _scrollView.singleTapped = ^
        {
            __strong TGModernGalleryZoomableItemView *strongSelf = weakSelf;
            [strongSelf singleTap];
        };
        
        _scrollView.doubleTapped = ^(CGPoint point)
        {
            __strong TGModernGalleryZoomableItemView *strongSelf = weakSelf;
            [strongSelf doubleTap:point];
        };
        
        ((TGModernGalleryImageItemContainerView *)_containerView).contentView = ^UIView *
        {
            __strong TGModernGalleryZoomableItemView *strongSelf = weakSelf;
            if (strongSelf != nil)
                return [strongSelf contentView];
            
            return nil;
        };
    }
    return self;
}

- (void)dealloc
{
    _scrollView.delegate = nil;
}

- (void)prepareForReuse
{
}

- (CGSize)contentSize
{
    return CGSizeZero;
}

- (UIView *)contentView
{
    return nil;
}

- (UIView *)transitionContentView
{
    return [self contentView];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)__unused scrollView withView:(UIView *)__unused view
{
}

- (void)scrollViewDidZoom:(UIScrollView *)__unused scrollView
{
    [self adjustZoom];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)__unused scrollView withView:(UIView *)__unused view atScale:(CGFloat)__unused scale
{
    [self adjustZoom];
    
    if (_scrollView.zoomScale < _scrollView.normalZoomScale - FLT_EPSILON)
    {
        [TGHacks setAnimationDurationFactor:0.5f];
        [_scrollView setZoomScale:_scrollView.normalZoomScale animated:true];
        [TGHacks setAnimationDurationFactor:1.0f];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)__unused scrollView
{
    return [self contentView];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    _internalContainerView.frame = self.bounds;
    _containerView.frame = _internalContainerView.bounds;
    
    if (!CGSizeEqualToSize(frame.size, _scrollView.frame.size))
    {
        [self forceUpdateLayout];
    }
}

- (void)forceUpdateLayout {
    CGRect frame = self.frame;
    CGSize contentSize = [self contentSize];
    
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 1.0f;
    _scrollView.normalZoomScale = 1.0f;
    _scrollView.zoomScale = 1.0f;
    _scrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    _scrollView.contentSize = contentSize;
    [self contentView].frame = CGRectMake(0.0f, 0.0f, contentSize.width, contentSize.height);
    
    [self adjustZoom];
    _scrollView.zoomScale = _scrollView.normalZoomScale;
}

- (void)reset
{
    CGSize contentSize = [self contentSize];
    
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 1.0f;
    _scrollView.normalZoomScale = 1.0f;
    _scrollView.zoomScale = 1.0f;
    _scrollView.contentSize = contentSize;
    [self contentView].frame = CGRectMake(0.0f, 0.0f, contentSize.width, contentSize.height);
    
    [self adjustZoom];
    _scrollView.zoomScale = _scrollView.normalZoomScale;
}

- (void)adjustZoom
{
    CGSize contentSize = [self contentSize];
    CGSize boundsSize = _scrollView.frame.size;
    if (contentSize.width < FLT_EPSILON || contentSize.height < FLT_EPSILON || boundsSize.width < FLT_EPSILON || boundsSize.height < FLT_EPSILON)
        return;
    
    CGFloat scaleWidth = boundsSize.width / contentSize.width;
    CGFloat scaleHeight = boundsSize.height / contentSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    CGFloat maxScale = MAX(scaleWidth, scaleHeight);
    maxScale = MAX(maxScale, minScale * 3.0f);
    
    if (ABS(maxScale - minScale) < 0.01f)
        maxScale = minScale;

    if (_scrollView.minimumZoomScale != 0.05f)
        _scrollView.minimumZoomScale = 0.05f;
    if (_scrollView.normalZoomScale != minScale)
        _scrollView.normalZoomScale = minScale;
    if (_scrollView.maximumZoomScale != maxScale)
        _scrollView.maximumZoomScale = maxScale;

    CGRect contentFrame = [self contentView].frame;
    
    if (boundsSize.width > contentFrame.size.width)
        contentFrame.origin.x = (boundsSize.width - contentFrame.size.width) / 2.0f;
    else
        contentFrame.origin.x = 0;
    
    if (boundsSize.height > contentFrame.size.height)
        contentFrame.origin.y = (boundsSize.height - contentFrame.size.height) / 2.0f;
    else
        contentFrame.origin.y = 0;
    
    [self contentView].frame = contentFrame;
    
    _scrollView.scrollEnabled = ABS(_scrollView.zoomScale - _scrollView.normalZoomScale) > FLT_EPSILON;
}

- (void)singleTap
{
    id<TGModernGalleryItemViewDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(itemViewDidRequestInterfaceShowHide:)])
        [delegate itemViewDidRequestInterfaceShowHide:self];
}

- (void)doubleTap:(CGPoint)point
{
    [TGHacks setAnimationDurationFactor:0.6f];
    if (_scrollView.zoomScale <= _scrollView.normalZoomScale + FLT_EPSILON)
    {
        CGPoint pointInView = [_scrollView convertPoint:point toView:[self contentView]];
        
        CGFloat newZoomScale = _scrollView.maximumZoomScale;
        
        CGSize scrollViewSize = _scrollView.bounds.size;
        
        CGFloat w = scrollViewSize.width / newZoomScale;
        CGFloat h = scrollViewSize.height / newZoomScale;
        CGFloat x = pointInView.x - (w / 2.0f);
        CGFloat y = pointInView.y - (h / 2.0f);
        
        CGRect rectToZoomTo = CGRectMake(x, y, w, h);
        
        [_scrollView zoomToRect:rectToZoomTo animated:true];
    }
    else
        [_scrollView setZoomScale:_scrollView.normalZoomScale animated:true];
    [TGHacks setAnimationDurationFactor:1.0f];
}

@end
