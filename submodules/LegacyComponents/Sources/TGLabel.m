#import "TGLabel.h"

@implementation TGLabel

@synthesize reuseIdentifier = _reuseIdentifier;

@synthesize normalShadowColor = _normalShadowColor;
@synthesize highlightedShadowColor = _highlightedShadowColor;

@synthesize portraitFont = _portraitFont;
@synthesize landscapeFont = _landscapeFont;

@synthesize persistentBackgroundColor = _persistentBackgroundColor;

@synthesize verticalAlignment = _verticalAlignment;
@synthesize verticalOffset = _verticalOffset;
@synthesize verticalOffsetMultiplier = _verticalOffsetMultiplier;

@synthesize customDrawingOffset = _customDrawingOffset;
@synthesize customDrawingSize = _customDrawingSize;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    if (_highlightedShadowColor != nil && _normalShadowColor != nil)
        self.shadowColor = highlighted ? _highlightedShadowColor : _normalShadowColor;
}

- (void)setLandscape:(bool)landscape
{
    if (_landscapeFont != nil && _portraitFont != nil)
    {
        self.font = landscape ? _landscapeFont : _portraitFont;
    }
}

- (void)setOpaque:(BOOL)opaque
{
    [super setOpaque:opaque];
    
    if (opaque && _persistentBackgroundColor != nil)
    {
        [super setBackgroundColor:_persistentBackgroundColor];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    if (self.opaque && _persistentBackgroundColor != nil)
        [super setBackgroundColor:_persistentBackgroundColor];
    else
        [super setBackgroundColor:backgroundColor];
}

- (void)setPersistentBackgroundColor:(UIColor *)persistentBackgroundColor
{
    _persistentBackgroundColor = persistentBackgroundColor;
    
    if (self.opaque)
        self.backgroundColor = persistentBackgroundColor;
}

- (void)setCustomDrawingOffset:(CGPoint)customDrawingOffset
{
    if (!CGPointEqualToPoint(customDrawingOffset, _customDrawingOffset))
    {
        _customDrawingOffset = customDrawingOffset;
        [self setNeedsDisplay];
    }
}

- (void)setCustomDrawingSize:(CGSize)customDrawingSize
{
    if (!CGSizeEqualToSize(customDrawingSize, _customDrawingSize))
    {
        _customDrawingSize = customDrawingSize;
        [self setNeedsDisplay];
    }
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
    if (_customDrawingSize.height != 0)
        bounds.size = _customDrawingSize;
    if (_verticalAlignment == TGLabelVericalAlignmentCenter)
    {
        CGRect textRect = [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];
        textRect.origin.y = bounds.origin.y + (int)((bounds.size.height - textRect.size.height) / 2);
        return CGRectOffset(textRect, 0, (int)(_verticalOffset + _verticalOffsetMultiplier * textRect.size.height));
    }
    else if (_verticalAlignment == TGLabelVericalAlignmentTop)
    {
        CGRect textRect = [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];    
        textRect.origin.y = bounds.origin.y;
        return CGRectOffset(textRect, 0, (int)(_verticalOffset + _verticalOffsetMultiplier * textRect.size.height));
    }
    else
        return CGRectOffset([super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines], 0, _verticalOffset);
}

- (void)drawTextInRect:(CGRect)requestedRect 
{
    if (_customDrawingSize.height != 0)
    {
        if (requestedRect.size.width > _customDrawingSize.width)
            requestedRect.size.width = _customDrawingSize.width;
        CGRect actualRect = [self textRectForBounds:requestedRect limitedToNumberOfLines:self.numberOfLines];
        if (_verticalAlignment != TGLabelVericalAlignmentCenter)
            actualRect.origin.y = requestedRect.origin.y;
        [super drawTextInRect:CGRectMake(requestedRect.origin.x + _customDrawingOffset.x, actualRect.origin.y + _customDrawingOffset.y, MIN(actualRect.size.width, _customDrawingSize.width), MIN(actualRect.size.height, _customDrawingSize.height))];
    }
    else
    {
        CGRect actualRect = [self textRectForBounds:requestedRect limitedToNumberOfLines:self.numberOfLines];
        [super drawTextInRect:actualRect];
    }
}

- (void)drawRect:(CGRect)__unused rect
{
    [self drawTextInRect:self.bounds];
}

@end
