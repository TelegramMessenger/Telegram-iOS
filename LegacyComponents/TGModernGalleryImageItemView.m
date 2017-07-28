#import "TGModernGalleryImageItemView.h"

#import "LegacyComponentsInternal.h"

#import "TGModernGalleryImageItem.h"

#import <LegacyComponents/TGImageView.h>

#import "TGModernGalleryImageItemImageView.h"
#import <LegacyComponents/TGModernGalleryZoomableScrollView.h>

#import <LegacyComponents/TGMessageImageViewOverlayView.h>

@interface TGModernGalleryImageItemView ()
{
    TGMessageImageViewOverlayView *_progressView;
    dispatch_block_t _resetBlock;
    
    bool _progressVisible;
    void (^_currentAvailabilityObserver)(bool);
}

@end

@implementation TGModernGalleryImageItemView

- (UIImage *)shadowImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        
    });
    return image;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        __weak TGModernGalleryImageItemView *weakSelf = self;
        _imageView = [[TGModernGalleryImageItemImageView alloc] init];
        _imageView.progressChanged = ^(CGFloat value)
        {
            __strong TGModernGalleryImageItemView *strongSelf = weakSelf;
            [strongSelf setProgressVisible:value < 1.0f - FLT_EPSILON value:value animated:true];
        };
        _imageView.availabilityStateChanged = ^(bool available)
        {
            __strong TGModernGalleryImageItemView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf->_currentAvailabilityObserver)
                    strongSelf->_currentAvailabilityObserver(available);
            }
        };
        [self.scrollView addSubview:_imageView];
    }
    return self;
}

- (void)prepareForRecycle
{
    [_imageView reset];
    if (_resetBlock)
    {
        _resetBlock();
        _resetBlock = nil;
    }
    [self setProgressVisible:false value:0.0f animated:false];
}

- (void)setItem:(TGModernGalleryImageItem *)item synchronously:(bool)synchronously
{
    [super setItem:item synchronously:synchronously];
    
    _imageSize = item.imageSize;
    if (item.loader != nil)
        _resetBlock = [item.loader(_imageView, synchronously) copy];
    else if (item.uri == nil)
        [_imageView reset];
    else
        [_imageView loadUri:item.uri withOptions:@{TGImageViewOptionSynchronous: @(synchronously)}];
    
    [self reset];
}

- (SSignal *)contentAvailabilityStateSignal
{
    __weak TGModernGalleryImageItemView *weakSelf = self;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        __strong TGModernGalleryImageItemView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [subscriber putNext:@([strongSelf->_imageView isAvailableNow])];
            strongSelf->_currentAvailabilityObserver = ^(bool available)
            {
                [subscriber putNext:@(available)];
            };
        }
        
        return nil;
    }];
}

- (CGSize)contentSize
{
    return _imageSize;
}

- (UIView *)contentView
{
    return _imageView;
}

- (UIView *)transitionView
{
    return self.containerView;
}

- (CGRect)transitionViewContentRect
{
    return [_imageView convertRect:_imageView.bounds toView:[self transitionView]];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (_progressView != nil)
    {
        _progressView.frame = (CGRect){{CGFloor((frame.size.width - _progressView.frame.size.width) / 2.0f), CGFloor((frame.size.height - _progressView.frame.size.height) / 2.0f)}, _progressView.frame.size};
    }
}

- (void)setProgressVisible:(bool)progressVisible value:(CGFloat)value animated:(bool)animated
{
    _progressVisible = progressVisible;
    
    if (progressVisible && _progressView == nil)
    {
        _progressView = [[TGMessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
        _progressView.userInteractionEnabled = false;
        
        _progressView.frame = (CGRect){{CGFloor((self.frame.size.width - _progressView.frame.size.width) / 2.0f), CGFloor((self.frame.size.height - _progressView.frame.size.height) / 2.0f)}, _progressView.frame.size};
    }
    
    if (progressVisible)
    {
        if (_progressView.superview == nil)
            [self.containerView addSubview:_progressView];
        
        _progressView.alpha = 1.0f;
    }
    else if (_progressView.superview != nil)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
             {
                 _progressView.alpha = 0.0f;
             } completion:^(BOOL finished)
             {
                 if (finished)
                     [_progressView removeFromSuperview];
             }];
        }
        else
            [_progressView removeFromSuperview];
    }
    
    [_progressView setProgress:value cancelEnabled:false animated:animated];
}

@end
