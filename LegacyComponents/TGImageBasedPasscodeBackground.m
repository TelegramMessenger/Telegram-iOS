#import "TGImageBasedPasscodeBackground.h"

#import <LegacyComponents/TGImageBlur.h>

@interface TGImageBasedPasscodeBackground ()
{
    CGSize _size;
    UIImage *_backgroundImage;
    UIImage *_foregroundImage;
}

@end

@implementation TGImageBasedPasscodeBackground

- (instancetype)initWithSize:(CGSize)size
{
    return [self initWithImage:nil size:size];
}

- (instancetype)initWithImage:(UIImage *)image size:(CGSize)size
{
    self = [super init];
    if (self != nil)
    {
        _size = size;
        
        NSArray *images = TGBlurredBackgroundImages(image, size);
        _backgroundImage = images[0];
        _foregroundImage = images[1];
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
    return _foregroundImage;
}

@end
