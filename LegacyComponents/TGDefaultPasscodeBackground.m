#import "TGDefaultPasscodeBackground.h"

#import "LegacyComponentsInternal.h"

#import <UIKit/UIKit.h>

@interface TGDefaultPasscodeBackground ()
{
    CGSize _size;
    UIImage *_backgroundImage;
}

@end

@implementation TGDefaultPasscodeBackground

- (instancetype)initWithSize:(CGSize)size
{
    self = [super init];
    if (self != nil)
    {
        _size = size;
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(8.0f, _size.height), true, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGColorRef colors[2] = {
            CGColorRetain(UIColorRGB(0x466f92).CGColor),
            CGColorRetain(UIColorRGB(0x244f74).CGColor)
        };
        
        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
        CGFloat locations[2] = {0.0f, 1.0f};
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
        
        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);
        
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, _size.height), 0);
        
        _backgroundImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f) resizingMode:UIImageResizingModeTile];
        UIGraphicsEndImageContext();
    }
    return self;
}

- (CGSize)size
{
    return _size;
}

- (UIImage *)backgroundImage
{
    return _backgroundImage;
}

- (UIImage *)foregroundImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 1.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.5f).CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 1.0f));
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

@end
