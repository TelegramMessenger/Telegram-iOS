#import "TGLocationWavesView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGPhotoEditorUtils.h"

@interface TGLocationWavesView ()
{
    CADisplayLink *_displayLink;
    NSTimeInterval _previousTime;
    
    CGFloat _progress;
    UIImage *_image;
}
@end

@implementation TGLocationWavesView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _image = TGComponentsImageNamed(@"LocationWave");
        self.userInteractionEnabled = false;
        _color = [UIColor whiteColor];
    }
    return self;
}

- (void)invalidate
{
    [_displayLink invalidate];
    _displayLink = nil;
}

- (CADisplayLink *)displayLink {
    if (_displayLink == nil) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate)];
        _displayLink.paused = true;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _displayLink;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    _image = TGTintedImage(TGComponentsImageNamed(@"LocationWave"), color);
}

- (void)start
{
    [self displayLink].paused = false;
}

- (void)stop
{
    _displayLink.paused = true;
}

- (void)drawRect:(CGRect)rect
{
    CGPoint center = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
    CGFloat length = 9.0f;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, _color.CGColor);
    
    void (^draw)(CGFloat, bool) = ^(CGFloat pos, bool right)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddArc(path, NULL, center.x, center.y, length * pos + 7.0f, right ? TGDegreesToRadians(-26) : TGDegreesToRadians(154), right ? TGDegreesToRadians(26) : TGDegreesToRadians(206), false);
        
        CGPathRef strokedArc = CGPathCreateCopyByStrokingPath(path, NULL, 1.65f, kCGLineCapRound, kCGLineJoinMiter, 10);
        
        CGContextAddPath(context, strokedArc);
        
        CGPathRelease(strokedArc);
        CGPathRelease(path);
        
        CGContextFillPath(context);
    };
    
    CGFloat position = _progress;
    CGFloat alpha = position / 0.5f;
    if (alpha > 1.0f)
        alpha = 2.0f - alpha;
    CGContextSetAlpha(context, alpha * 0.7f);

    draw(position, false);
    draw(position, true);
    
    CGFloat progress =  _progress + 0.5f;
    if (progress > 1.0f)
        progress = progress - 1.0f;

    CGFloat largerPos = progress;
    CGFloat largerAlpha = largerPos / 0.5f;
    if (largerAlpha > 1.0f)
        largerAlpha = 2.0f - largerAlpha;
    CGContextSetAlpha(context, largerAlpha * 0.7f);
    
    draw(largerPos, false);
    draw(largerPos, true);
}

- (void)displayLinkUpdate
{
    NSTimeInterval previousTime = _previousTime;
    NSTimeInterval currentTime = CACurrentMediaTime();
    _previousTime = currentTime;
    
    NSTimeInterval delta = previousTime > DBL_EPSILON ? currentTime - previousTime : 0.0;
    if (delta < DBL_EPSILON)
        return;
    
    _progress += delta * 0.52;
    if (_progress > 1.0f)
        _progress = 1.0f - _progress;
    
    [self setNeedsDisplay];
}

@end
