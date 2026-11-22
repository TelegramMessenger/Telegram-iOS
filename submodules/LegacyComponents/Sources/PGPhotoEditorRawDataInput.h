#import "GPUImageOutput.h"

typedef enum {
    GPUPixelFormatBGRA = GL_BGRA,
    GPUPixelFormatRGBA = GL_RGBA,
    GPUPixelFormatRGB = GL_RGB
} GPUPixelFormat;

typedef enum {
    GPUPixelTypeUByte = GL_UNSIGNED_BYTE,
    GPUPixelTypeFloat = GL_FLOAT
} GPUPixelType;

@interface PGPhotoEditorRawDataInput : GPUImageOutput

- (instancetype)initWithBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize;
- (instancetype)initWithBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat;
- (instancetype)initWithBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat type:(GPUPixelType)pixelType;

@property (nonatomic, assign) GPUPixelFormat pixelFormat;
@property (nonatomic, assign) GPUPixelType   pixelType;

- (void)updateDataWithBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize;
- (void)processData;
- (void)processDataForTimestamp:(CMTime)frameTime;
- (CGSize)outputImageSize;
- (void)invalidate;

@end
