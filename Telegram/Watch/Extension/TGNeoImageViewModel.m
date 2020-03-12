#import "TGNeoImageViewModel.h"

@implementation TGNeoImageViewModel

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self != nil)
    {
        _image = image;
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor
{
    self = [super init];
    if (self != nil)
    {
        _image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _tintColor = tintColor;
    }
    return self;
}

- (void)drawInContext:(CGContextRef)context
{
    UIGraphicsPushContext(context);
    if (_tintColor != nil)
    {
        CGContextSaveGState(context);
        CGContextSetFillColorWithColor(context, _tintColor.CGColor);
    }
        
    [self.image drawInRect:CGRectMake((self.frame.size.width - self.image.size.width) / 2, (self.frame.size.height - self.image.size.height) / 2, self.image.size.width, self.image.size.height)];
    
    if (_tintColor)
        CGContextRestoreGState(context);
    UIGraphicsPopContext();
}

@end
