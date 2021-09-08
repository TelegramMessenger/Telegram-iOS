#import "TGGradientLabel.h"

#import "LegacyComponentsInternal.h"

@interface TGGradientLabel ()
{
    CGSize _textSize;
    
    void *_offscreenMemory;
    int _offscreenContextWidth;
    int _offscreenContextHeight;
    int _offscreenContextStride;
    CGContextRef _offscreenContext;
}

@end

@implementation TGGradientLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.opaque = false;
    }
    return self;
}

- (void)sizeToFit
{
    if (_text == nil || _font == nil)
        return;

    _textSize = [self.text boundingRectWithSize:CGSizeMake(1000.0f, 1000.0f) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: _font} context:nil].size;
    
    CGRect frame = self.frame;
    frame.size = _textSize;
    self.frame = frame;
}

- (void)setText:(NSString *)text
{
    NSString *tmpText = text;
    if (text.length == 1)
    {
        unichar c = [text characterAtIndex:0];
        if (c >= 'a' && c <= 'z')
        {
            c += 'A' - 'a';
            tmpText = [[NSString alloc] initWithCharacters:&c length:1];
        }
    }
    else if (text.length == 3)
    {
        unichar c[3] = {[text characterAtIndex:0], [text characterAtIndex:1], [text characterAtIndex:2]};
        if (c[0] >= 'a' && c[0] <= 'z')
            c[0] += 'A' - 'a';
        if (c[2] >= 'a' && c[2] <= 'z')
            c[2] += 'A' - 'a';
        
        tmpText = [[NSString alloc] initWithCharacters:c length:3];
    }
    _text = tmpText;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)__unused rect
{
    if (_text.length == 0 || _font == nil)
        return;
    
    bool nonEmpty = false;
    for (int i = (int)_text.length - 1; i >= 0; i--)
    {
        if ([_text characterAtIndex:i] != ' ')
        {
            nonEmpty = true;
            break;
        }
    }
    
    if (!nonEmpty)
        return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect bounds = self.bounds;
    
    if (bounds.size.width < FLT_EPSILON || bounds.size.height < FLT_EPSILON)
        return;
    
    int offscreenWidth = (int)bounds.size.width;
    int offscreenHeight = (int)bounds.size.height;
    
    if (offscreenWidth != _offscreenContextWidth || offscreenHeight != _offscreenContextHeight)
    {
        if (_offscreenMemory != NULL)
        {
            free(_offscreenMemory);
            _offscreenMemory = NULL;
        }
        
        if (_offscreenContext != NULL)
        {
            CFRelease(_offscreenContext);
            _offscreenContext = NULL;
        }
        
        _offscreenContextWidth = offscreenWidth;
        _offscreenContextHeight = offscreenHeight;
        _offscreenContextStride = ((4 * _offscreenContextWidth + 31) & (~31));
        _offscreenMemory = malloc(_offscreenContextStride * _offscreenContextHeight);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
        _offscreenContext = CGBitmapContextCreate(_offscreenMemory, _offscreenContextWidth, _offscreenContextHeight, 8, _offscreenContextStride, colorSpace, bitmapInfo);
        CGColorSpaceRelease(colorSpace);
    }
    
    if (_textColor != nil)
    {
        CGPoint drawingOffset = CGPointMake(CGFloor((bounds.size.width - _textSize.width) / 2.0f), CGFloor((bounds.size.height - _textSize.height) / 2.0f));
        
        CGContextSetFillColorWithColor(context, _textColor.CGColor);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [_text drawAtPoint:drawingOffset withFont:_font];
#pragma clang diagnostic pop
    }
    else
    {
        CGContextSetTextDrawingMode(context, kCGTextClip);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [_text drawAtPoint:CGPointMake(CGFloor((bounds.size.width - _textSize.width) / 2.0f), CGFloor((bounds.size.height - _textSize.height) / 2.0f)) withFont:_font];
#pragma clang diagnostic pop
        
        CGColorRef colors[2] = {
            CGColorRetain(UIColorRGB(_topColor).CGColor),
            CGColorRetain(UIColorRGB(_bottomColor).CGColor)
        };
        
        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
        CGFloat locations[2] = {0.0f, 1.0f};
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
        
        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);
        
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, bounds.size.height), 0);
        
        CFRelease(gradient);
    }
}

@end
