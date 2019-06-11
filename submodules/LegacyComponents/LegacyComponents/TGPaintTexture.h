#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <OpenGLES/ES2/gl.h>

@interface TGPaintTexture : NSObject

@property (nonatomic, readonly) GLuint textureName;

+ (instancetype)textureWithImage:(UIImage *)image forceRGB:(bool)forceRGB;

- (instancetype)initWithCGImage:(CGImageRef)imageRef forceRGB:(bool)forceRGB;
- (void)cleanResources;

@end
