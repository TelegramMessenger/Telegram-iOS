#import "TGPasscodePinView.h"

#import "LegacyComponentsInternal.h"

#import "TGPasscodePinDotView.h"

@interface TGPasscodePinView ()
{
    id<TGPasscodeBackground> _background;
    NSArray *_dotViews;
    NSUInteger _maxCharacterCount;
}

@end

@implementation TGPasscodePinView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = nil;
    }
    return self;
}

- (void)setBackground:(id<TGPasscodeBackground>)background
{
    _background = background;
    for (TGPasscodePinDotView *dotView in _dotViews)
    {
        [dotView setBackground:_background];
    }
    [self setNeedsDisplay];
}

- (void)setCharacterCount:(NSUInteger)characterCount maxCharacterCount:(NSUInteger)maxCharacterCount
{
    if (_maxCharacterCount != maxCharacterCount)
        [self setNeedsDisplay];
    
    NSUInteger displayLimit = 0;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
        displayLimit = 22;
    else if ((int)screenSize.height == 736)
        displayLimit = 26;
    else if ((int)screenSize.height == 667)
        displayLimit = 23;
    else if ((int)screenSize.height == 568)
        displayLimit = 19;
    else
        displayLimit = 19;
    
    _maxCharacterCount = maxCharacterCount;
    NSUInteger dotCount = MIN(displayLimit, MAX(characterCount, maxCharacterCount));
    
    NSMutableArray *dotViews = [[NSMutableArray alloc] initWithArray:_dotViews];
    
    while (dotViews.count > dotCount)
    {
        TGPasscodePinDotView *dotView = dotViews.lastObject;
        [dotView removeFromSuperview];
        [dotViews removeLastObject];
    }
    
    for (NSUInteger i = dotViews.count; i < dotCount; i++)
    {
        TGPasscodePinDotView *dotView = [[TGPasscodePinDotView alloc] init];
        [dotView setBackground:_background];
        [self addSubview:dotView];
        [dotViews addObject:dotView];
    }
    
    for (NSUInteger i = 0; i < dotViews.count; i++)
    {
        TGPasscodePinDotView *dotView = dotViews[i];
        [dotView setFilled:maxCharacterCount == 0 || i < characterCount];
    }
    
    _dotViews = dotViews;
    
    [self _layoutDots];
}

- (void)setFrame:(CGRect)frame
{
    bool needsDotsLayout = !CGPointEqualToPoint(self.frame.origin, frame.origin);
    [super setFrame:frame];
    if (needsDotsLayout)
    {
        [self _layoutDots];
        [self setNeedsDisplay];
    }
}

- (void)_layoutDots
{
    CGFloat dotSimpleSize = 0.0f;
    CGFloat dotComplexSize = 0.0f;
    CGFloat dotSimpleSpacing = 0.0f;
    CGFloat dotComplexSpacing = 0.0f;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
    {
        dotSimpleSize = 16.0f;
        dotComplexSize = 7.0f;
        dotSimpleSpacing = 27.0f;
        dotComplexSpacing = 7.0f;
    }
    else if ((int)screenSize.height == 736)
    {
        dotSimpleSize = 13.0f;
        dotComplexSize = 7.0f;
        dotSimpleSpacing = 24.0f;
        dotComplexSpacing = 7.0f;
    }
    else if ((int)screenSize.height == 667)
    {
        dotSimpleSize = 13.0f;
        dotComplexSize = 7.0f;
        dotSimpleSpacing = 24.0f;
        dotComplexSpacing = 7.0f;
    }
    else if ((int)screenSize.height == 568)
    {
        dotSimpleSize = 13.0f;
        dotComplexSize = 7.0f;
        dotSimpleSpacing = 24.0f;
        dotComplexSpacing = 7.0f;
    }
    else
    {
        dotSimpleSize = 13.0f;
        dotComplexSize = 7.0f;
        dotSimpleSpacing = 24.0f;
        dotComplexSpacing = 7.0f;
    }
    
    CGFloat dotSize = _maxCharacterCount == 0 ? dotComplexSize : dotSimpleSize;
    CGFloat spacing = _maxCharacterCount == 0 ? dotComplexSpacing : dotSimpleSpacing;
    CGFloat dotsWidth = _dotViews.count * dotSize + (_dotViews.count == 0 ? 0.0f : ((_dotViews.count - 1) * spacing));
    CGPoint dotsPosition = CGPointMake(CGFloor((self.frame.size.width - dotsWidth) / 2.0f), CGFloor((self.frame.size.height - dotSize) / 2.0f));
    NSUInteger index = 0;
    for (TGPasscodePinDotView *dotView in _dotViews)
    {
        dotView.frame = CGRectMake(dotsPosition.x + index * (dotSize + spacing), dotsPosition.y, dotSize, dotSize);
        [dotView setAbsoluteOffset:CGPointMake(self.frame.origin.x + dotView.frame.origin.x, self.frame.origin.y + dotView.frame.origin.y)];
        index++;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self _layoutDots];
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGSize size = self.bounds.size;
    
    [[_background backgroundImage] drawInRect:CGRectMake(-self.frame.origin.x, -self.frame.origin.y, [_background size].width, [_background size].height) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    if (_maxCharacterCount == 0)
    {
        CGFloat padding = 0.0f;
        CGFloat lineWidth = 1.0f;
        CGFloat radius = 5.0f;
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, padding, radius);
        CGContextAddArcToPoint(context, padding, 0.0f, padding + radius, 0.0f, radius);
        CGContextAddLineToPoint(context, size.width - padding - radius, 0.0f);
        CGContextAddArcToPoint(context, size.width - padding, 0.0f, size.width - padding, radius, radius);
        CGContextAddLineToPoint(context, size.width - padding, size.height - radius);
        CGContextAddArcToPoint(context, size.width - padding, size.height, size.width - padding - radius, size.height, radius);
        CGContextAddLineToPoint(context, padding + radius, size.height);
        CGContextAddArcToPoint(context, padding, size.height, padding, size.height - radius, radius);
        CGContextClosePath(context);
        CGContextClip(context);
        
        [[_background foregroundImage] drawInRect:CGRectMake(-self.frame.origin.x, -self.frame.origin.y, [_background size].width, [_background size].height) blendMode:kCGBlendModeNormal alpha:1.0f];
        
        radius = 4.0f;
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, padding + lineWidth, radius + lineWidth);
        CGContextAddArcToPoint(context, padding + lineWidth, lineWidth, padding + radius + lineWidth, lineWidth, radius);
        CGContextAddLineToPoint(context, size.width - padding - radius - lineWidth, lineWidth);
        CGContextAddArcToPoint(context, size.width - padding - lineWidth, lineWidth, size.width - padding - lineWidth, radius + lineWidth, radius);
        CGContextAddLineToPoint(context, size.width - padding - lineWidth, size.height - radius - lineWidth);
        CGContextAddArcToPoint(context, size.width - padding - lineWidth, size.height - lineWidth, size.width - padding - radius - lineWidth, size.height - lineWidth, radius);
        CGContextAddLineToPoint(context, padding + radius + lineWidth, size.height - lineWidth);
        CGContextAddArcToPoint(context, padding + lineWidth, size.height - lineWidth, padding + lineWidth, size.height - radius - lineWidth, radius);
        CGContextClosePath(context);
        
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
        CGContextFillPath(context);
    }
}

@end
