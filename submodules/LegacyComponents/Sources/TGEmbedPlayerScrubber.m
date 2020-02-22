#import "TGEmbedPlayerScrubber.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

const CGFloat TGEmbedPlayerKnobMargin = 8.0f;

@interface TGEmbedPlayerScrubber ()
{
    UIImageView *_backgroundView;
    UIView *_downloadProgressView;
    UIImageView *_playPositionView;
    
    UIControl *_knobView;
    
    CGFloat _position;
    CGFloat _downloadProgress;
    
    CGFloat _knobDragPosition;
    bool _tracking;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
}
@end

@implementation TGEmbedPlayerScrubber

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-20, -20, -20, -20);
        
        UIImage *hollowTrackImage = [TGComponentsImageNamed(@"EmbedVideoTrackHollow") resizableImageWithCapInsets:UIEdgeInsetsMake(0, 2, 0, 2)];
        _backgroundView = [[UIImageView alloc] initWithImage:hollowTrackImage];
        [self addSubview:_backgroundView];
        
        _downloadProgressView = [[UIView alloc] initWithFrame:CGRectZero];
        _downloadProgressView.backgroundColor = [UIColor blackColor];
        [self addSubview:_downloadProgressView];
        
        static UIImage *trackImage = nil;
        static dispatch_once_t onceToken1;
        dispatch_once(&onceToken1, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(3.0f, 3.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0, 0, 3.0f, 3.0f));
            trackImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(0, 1, 0, 1)];
            UIGraphicsEndImageContext();
        });
        
        _playPositionView = [[UIImageView alloc] initWithImage:trackImage];
        [self addSubview:_playPositionView];
        
        static UIImage *knobViewImage = nil;
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(21.0f, 21.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetShadowWithColor(context, CGSizeMake(0, 1.0f), 2.0f, [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(3.0f, 3.0f, 15.0f, 15.0f));
            knobViewImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _knobView = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 21.0f, 21.0f)];
        _knobView.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
        [self addSubview:_knobView];
        
        UIImageView *knobBackground = [[UIImageView alloc] initWithImage:knobViewImage];
        [_knobView addSubview:knobBackground];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [_knobView addGestureRecognizer:_panGestureRecognizer];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint touchLocation = [gestureRecognizer locationInView:self];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _tracking = true;
            
            if (self.onInteractionStart != nil)
                self.onInteractionStart();
        }
        case UIGestureRecognizerStateChanged:
        {
            _knobDragPosition = [self knobPositionForX:touchLocation.x];

            [self setNeedsLayout];
            
            if (self.onSeek != nil)
                self.onSeek(_knobDragPosition);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _tracking = false;
            _position = _knobDragPosition;
            [self setNeedsLayout];
            
            if (self.onInteractionEnd != nil)
                self.onInteractionEnd();
        }
            break;
            
        default:
            break;
    }
}

- (bool)isTracking
{
    return _knobView.highlighted;
}

- (void)setPosition:(CGFloat)position
{
    _position = position;
    [self setNeedsLayout];
}

- (void)setDownloadProgress:(CGFloat)progress
{
    _downloadProgress = progress;
    [self setNeedsLayout];
}

- (void)setTintColor:(UIColor *)tintColor
{
    UIImage *tintedImage = [TGTintedImage(TGComponentsImageNamed(@"EmbedVideoTrackHollow"), tintColor) resizableImageWithCapInsets:UIEdgeInsetsMake(0, 2, 0, 2)];
    _backgroundView.image = tintedImage;
    _downloadProgressView.backgroundColor = tintColor;
}

- (CGFloat)knobPositionRange
{
    return MAX(0.0f, self.bounds.size.width - TGEmbedPlayerKnobMargin * 2);
}

- (CGFloat)knobPositionForX:(CGFloat)x
{
    return MAX(0, MIN(1.0f, (x - TGEmbedPlayerKnobMargin) / [self knobPositionRange]));
}

- (void)layoutSubviews
{
    _backgroundView.frame = self.bounds;
    
    CGFloat downloadProgressRange = MAX(0.0f, self.bounds.size.width - 2.0f);
    _downloadProgressView.frame = CGRectMake(1.0f, 1.0f, TGRetinaFloor(_downloadProgress * downloadProgressRange), 1.0f);
    
    CGFloat position = _tracking ? _knobDragPosition : _position;
    _knobView.center = CGPointMake(TGRetinaCeil(TGEmbedPlayerKnobMargin + position * [self knobPositionRange]), 1.5f);
    
    _playPositionView.frame = CGRectMake(0, 0, _knobView.center.x, 3.0f);
}

@end
