#import "TGLocationWavesView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

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
    }
    return self;
}

- (void)dealloc
{
    _displayLink.paused = true;
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
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
    [self displayLink].paused = true;
}

- (void)drawRect:(CGRect)rect
{
    CGPoint center = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
    UIImage *wave = _image;
    UIImage *mirroredWave = [UIImage imageWithCGImage:wave.CGImage scale:wave.scale orientation:UIImageOrientationUpMirrored];
    
    CGFloat scale = _progress;
    CGFloat position = _progress;
    CGFloat alpha = position / 0.5f;
    if (alpha > 1.0f)
        alpha = 2.0f - alpha;
    
    CGFloat length = 13.0f;
    
    CGSize size = CGSizeMake(4.5f * scale, 15.5f * scale);
    CGPoint p = CGPointMake(center.x - 3.0f - length * position, center.y);
    CGRect r = CGRectMake(p.x - size.width / 2.0f, p.y - size.height / 2.0f, size.width, size.height);
    [wave drawInRect:r blendMode:kCGBlendModeNormal alpha:alpha];
    
    p = CGPointMake(center.x + 3.0f + length * position, center.y);
    r = CGRectMake(p.x - size.width / 2.0f, p.y - size.height / 2.0f, size.width, size.height);
    [mirroredWave drawInRect:r blendMode:kCGBlendModeNormal alpha:alpha];
    
    CGFloat progress =  _progress + 0.32f;
    if (progress > 1.0f)
        progress = progress - 1.0f;
    
    CGFloat largerScale = progress;
    CGFloat largerPosition = progress;
    CGFloat largerAlpha = largerPosition / 0.5f;
    if (largerAlpha > 1.0f)
        largerAlpha = 2.0f - largerAlpha;
    
    size = CGSizeMake(4.5f * largerScale, 15.5f * largerScale);
    p = CGPointMake(center.x - 3.0f - length * largerPosition, center.y);
    r = CGRectMake(p.x - size.width / 2.0f, p.y - size.height / 2.0f, size.width, size.height);
    [wave drawInRect:r blendMode:kCGBlendModeNormal alpha:largerAlpha];
    
    p = CGPointMake(center.x + 3.0f + length * largerPosition, center.y);
    r = CGRectMake(p.x - size.width / 2.0f, p.y - size.height / 2.0f, size.width, size.height);
    [mirroredWave drawInRect:r blendMode:kCGBlendModeNormal alpha:largerAlpha];
}

- (void)displayLinkUpdate
{
    NSTimeInterval previousTime = _previousTime;
    NSTimeInterval currentTime = CACurrentMediaTime();
    _previousTime = currentTime;
    
    NSTimeInterval delta = previousTime > DBL_EPSILON ? currentTime - previousTime : 0.0;
    if (delta < DBL_EPSILON)
        return;
    
    _progress += delta * 0.65;
    if (_progress > 1.0f)
        _progress = 1.0f - _progress;
    
    [self setNeedsDisplay];
}

@end
