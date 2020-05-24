#import "GPUImageOutput.h"
#import <CoreImage/CoreImage.h>

@interface GPUImageTextureInput : GPUImageOutput
{
    CGSize textureSize;
}

- (instancetype)initWithTexture:(GLuint)newInputTexture size:(CGSize)newTextureSize;
- (instancetype)initWithCIImage:(CIImage *)ciImage;

- (void)processTextureWithFrameTime:(CMTime)frameTime synchronous:(bool)synchronous;

- (CGSize)textureSize;

@end
