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
    
    if (iosMajorVersion() >= 7) {
        _textSize = [self.text boundingRectWithSize:CGSizeMake(1000.0f, 1000.0f) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: _font} context:nil].size;
    } else {
        _textSize = [self.text sizeWithFont:_font];
    }
    
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
        _offscreenContextStride = ((4 * _offscreenContextWidth + 15) & (~15));
        _offscreenMemory = malloc(_offscreenContextStride * _offscreenContextHeight);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
        _offscreenContext = CGBitmapContextCreate(_offscreenMemory, _offscreenContextWidth, _offscreenContextHeight, 8, _offscreenContextStride, colorSpace, bitmapInfo);
        CGColorSpaceRelease(colorSpace);
    }
    
    if (_textColor != nil)
    {
        CGPoint drawingOffset = CGPointMake(CGFloor((bounds.size.width - _textSize.width) / 2.0f), CGFloor((bounds.size.height - _textSize.height) / 2.0f));
        
        if (false)
        {
            memset(_offscreenMemory, 0x00, (int)(_offscreenContextStride * _offscreenContextHeight));
            UIGraphicsPushContext(_offscreenContext);
            [_text drawAtPoint:CGPointMake(2.0f, 2.0f) withFont:_font];
            UIGraphicsPopContext();
            
            int minX = _offscreenContextWidth;
            int minY = _offscreenContextHeight;
            int maxX = 0;
            int maxY = 0;
            
            const void *offscreenMemory = _offscreenMemory;
            const int offscreenStride = _offscreenContextStride;
            for (int y = 0; y < _offscreenContextHeight; y++)
            {
                for (int x = 0; x < _offscreenContextWidth; x++)
                {
                    if ((*((uint32_t *)&offscreenMemory[y * offscreenStride + x * 4]) & 0xff000000) == 0xff000000)
                    {
                        if (x < minX)
                            minX = x;
                        if (y < minY)
                            minY = y;
                        if (x > maxX)
                            maxX = x;
                        if (y > maxY)
                            maxY = y;
                    }
                }
            }
            
            const int halfY = (maxY + minY) / 2;
            const int halfX = (maxX + minX) / 2;
            
            int topHalf = 0;
            int bottomHalf = 0;
            int rightHalf = 0;
            int leftHalf = 0;
            for (int y = minY; y <= maxY; y++)
            {
                for (int x = minX; x <= maxX; x++)
                {
                    if ((*((uint32_t *)&offscreenMemory[y * offscreenStride + x * 4]) & 0xff000000) == 0xff000000)
                    {
                        if (x < halfX)
                            leftHalf++;
                        else
                            rightHalf++;
                        
                        if (y < halfY)
                            topHalf++;
                        else
                            bottomHalf++;
                    }
                }
            }
            
            CGFloat topOffset = 0.0f;
            CGFloat leftOffset = 0.0f;
            
            if (topHalf != 0 && bottomHalf != 0 && leftHalf != 0 && rightHalf != 0)
            {
                topOffset = topHalf / (CGFloat)bottomHalf - 1.0f;
                leftOffset = leftHalf / (CGFloat)rightHalf - 1.0f;
            }
            
            minY = _offscreenContextHeight - minY;
            maxY = _offscreenContextHeight - maxY;
            int tmp = maxY;
            maxY = minY;
            minY = tmp;
            
            CGSize realSize = CGSizeMake(maxX - minX, maxY - minY);
            CGPoint realOffset = CGPointMake(minX - 2.0f, minY - 2.0f);
            
            if (realSize.width > FLT_EPSILON && realSize.height > FLT_EPSILON)
            {
                drawingOffset = CGPointMake(CGFloor((bounds.size.width - realSize.width) / 2.0f) - realOffset.x, CGFloor((bounds.size.height - realSize.height) / 2.0f) - realOffset.y);
                //drawingOffset.x += leftOffset;
                //drawingOffset.y += topOffset;
            }
        }
        
        CGContextSetFillColorWithColor(context, _textColor.CGColor);
        [_text drawAtPoint:drawingOffset withFont:_font];
    }
    else
    {
        CGContextSetTextDrawingMode(context, kCGTextClip);
        
        [_text drawAtPoint:CGPointMake(CGFloor((bounds.size.width - _textSize.width) / 2.0f), CGFloor((bounds.size.height - _textSize.height) / 2.0f)) withFont:_font];
        
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
