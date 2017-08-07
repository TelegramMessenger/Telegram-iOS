#import "PGPhotoCustomFilterPass.h"

#import "PGPhotoEditorPicture.h"

#import "LegacyComponentsInternal.h"

NSString *const PGPhotoFilterDefinitionsShaderString = PGShaderString
(
 precision highp float;
 
 varying vec2 texCoord;
 uniform sampler2D sourceImage;
 uniform float intensity;
);

NSString *const PGPhotoFilterMainShaderString = PGShaderString
(
 void main() {
     vec4 texel = texture2D(sourceImage, texCoord);
     vec4 result = filter(texel);
     
     gl_FragColor = vec4(mix(texel.rgb, result.rgb, intensity), texel.a);
 }
);

@interface PGPhotoCustomFilter : GPUImageFilter
{
    GLint _intensityUniform;
    
    GLuint _filterSourceTexture2;
    GLuint _filterSourceTexture3;
    GLuint _filterSourceTexture4;
    GLuint _filterSourceTexture5;
    GLuint _filterSourceTexture6;
    
    GLint _filterInputTextureUniform2;
    GLint _filterInputTextureUniform3;
    GLint _filterInputTextureUniform4;
    GLint _filterInputTextureUniform5;
    GLint _filterInputTextureUniform6;
}

@property (nonatomic, assign) CGFloat intensity;

@end

@implementation PGPhotoCustomFilter

- (instancetype)initWithFragmentShaderFromString:(NSString *)fragmentShaderString
{
    self = [super initWithFragmentShaderFromString:fragmentShaderString];
    if (self != nil)
    {
        _intensityUniform = [filterProgram uniformIndex:@"intensity"];
        self.intensity = 1.0f;
        
        _filterInputTextureUniform2 = [filterProgram uniformIndex:@"inputImageTexture2"];
        _filterInputTextureUniform3 = [filterProgram uniformIndex:@"inputImageTexture3"];
        _filterInputTextureUniform4 = [filterProgram uniformIndex:@"inputImageTexture4"];
        _filterInputTextureUniform5 = [filterProgram uniformIndex:@"inputImageTexture5"];
        _filterInputTextureUniform6 = [filterProgram uniformIndex:@"inputImageTexture6"];
    }
    return self;
}

- (void)dealloc
{
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        if (_filterSourceTexture2)
            glDeleteTextures(1, &_filterSourceTexture2);
        
        if (_filterSourceTexture3)
            glDeleteTextures(1, &_filterSourceTexture3);
        
        if (_filterSourceTexture4)
            glDeleteTextures(1, &_filterSourceTexture4);
        
        if (_filterSourceTexture5)
            glDeleteTextures(1, &_filterSourceTexture5);
        
        if (_filterSourceTexture6)
            glDeleteTextures(1, &_filterSourceTexture6);
    });
}

- (void)addTextureWithImage:(UIImage *)image textureIndex:(NSInteger)textureIndex
{
    bool redrawNeeded = false;
    CGImageRef cgImage = image.CGImage;
    
    if (image.imageOrientation != UIImageOrientationUp)
        redrawNeeded = true;
    
    CGSize imageSize = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
    if (image.imageOrientation == UIImageOrientationLeft || image.imageOrientation == UIImageOrientationRight)
        imageSize = CGSizeMake(imageSize.height, imageSize.width);
    
    GLubyte *imageData = NULL;
    CFDataRef dataFromImageDataProvider = NULL;
    GLenum format = GL_BGRA;
    
    if (!redrawNeeded)
    {
        if (CGImageGetBytesPerRow(cgImage) != CGImageGetWidth(cgImage) * 4 ||
            CGImageGetBitsPerPixel(cgImage) != 32 ||
            CGImageGetBitsPerComponent(cgImage) != 8)
        {
            redrawNeeded = true;
        }
        else
        {
            CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(cgImage);
            if ((bitmapInfo & kCGBitmapFloatComponents) != 0)
            {
                redrawNeeded = true;
            }
            else
            {
                CGBitmapInfo byteOrderInfo = bitmapInfo & kCGBitmapByteOrderMask;
                if (byteOrderInfo == kCGBitmapByteOrder32Little)
                {
                    /* Little endian, for alpha-first we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedFirst && alphaInfo != kCGImageAlphaFirst &&
                        alphaInfo != kCGImageAlphaNoneSkipFirst)
                    {
                        redrawNeeded = true;
                    }
                }
                else if (byteOrderInfo == kCGBitmapByteOrderDefault || byteOrderInfo == kCGBitmapByteOrder32Big)
                {
                    /* Big endian, for alpha-last we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedLast && alphaInfo != kCGImageAlphaLast &&
                        alphaInfo != kCGImageAlphaNoneSkipLast)
                    {
                        redrawNeeded = true;
                    } else
                    {
                        /* Can access directly using GL_RGBA pixel format */
                        format = GL_RGBA;
                    }
                }
            }
        }
    }
    
    if (redrawNeeded)
    {
        imageData = (GLubyte *) calloc(1, (int)imageSize.width * (int)imageSize.height * 4);
        
        CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef imageContext = CGBitmapContextCreate(imageData, (size_t)imageSize.width, (size_t)imageSize.height, 8, (size_t)imageSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        
        CGSize imageDrawSize = CGSizeMake(imageSize.width, imageSize.height);
        if (image.imageOrientation == UIImageOrientationLeft || image.imageOrientation == UIImageOrientationRight)
            imageDrawSize = CGSizeMake(imageDrawSize.height, imageDrawSize.width);
        
        CGAffineTransform transform = CGAffineTransformIdentity;
        switch (image.imageOrientation)
        {
            case UIImageOrientationDown:
            case UIImageOrientationDownMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.width, imageSize.height);
                transform = CGAffineTransformRotate(transform, (CGFloat)M_PI);
                break;
                
            case UIImageOrientationLeft:
            case UIImageOrientationLeftMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.width, 0);
                transform = CGAffineTransformRotate(transform, (CGFloat)M_PI_2);
                break;
                
            case UIImageOrientationRight:
            case UIImageOrientationRightMirrored:
                transform = CGAffineTransformTranslate(transform, 0, imageSize.height);
                transform = CGAffineTransformRotate(transform, (CGFloat)-M_PI_2);
                break;
                
            default:
                break;
        }
        
        switch (image.imageOrientation)
        {
            case UIImageOrientationUpMirrored:
            case UIImageOrientationDownMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.width,0);
                transform = CGAffineTransformScale(transform, -1, 1);
                break;
                
            case UIImageOrientationLeftMirrored:
            case UIImageOrientationRightMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.height, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
                break;
                
            default:
                break;
        }
        
        CGContextConcatCTM(imageContext, transform);
        
        CGContextDrawImage(imageContext, CGRectMake(0.0f, 0.0f, imageDrawSize.width, imageDrawSize.height), cgImage);
        CGContextRelease(imageContext);
        CGColorSpaceRelease(genericRGBColorspace);
    }
    else
    {
        dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
        imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
    }
    
    runSynchronouslyOnVideoProcessingQueue(^
    {
        [GPUImageContext useImageProcessingContext];
        
        switch (textureIndex)
        {
            case 0:
            {
                glActiveTexture(GL_TEXTURE3);
                glGenTextures(1, &_filterSourceTexture2);
                glBindTexture(GL_TEXTURE_2D, _filterSourceTexture2);
            }
                break;
                
            case 1:
            {
                glActiveTexture(GL_TEXTURE4);
                glGenTextures(1, &_filterSourceTexture3);
                glBindTexture(GL_TEXTURE_2D, _filterSourceTexture3);
            }
                break;
                
            case 2:
            {
                glActiveTexture(GL_TEXTURE5);
                glGenTextures(1, &_filterSourceTexture4);
                glBindTexture(GL_TEXTURE_2D, _filterSourceTexture4);
            }
                break;
                
            case 3:
            {
                glActiveTexture(GL_TEXTURE6);
                glGenTextures(1, &_filterSourceTexture5);
                glBindTexture(GL_TEXTURE_2D, _filterSourceTexture5);
                break;
            }
                
            case 4:
            {
                glActiveTexture(GL_TEXTURE7);
                glGenTextures(1, &_filterSourceTexture6);
                glBindTexture(GL_TEXTURE_2D, _filterSourceTexture6);
                break;
            }
                
            default:
                break;
        }
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)imageSize.width, (GLsizei)imageSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
        
        if (redrawNeeded)
            free(imageData);
        else if (dataFromImageDataProvider)
            CFRelease(dataFromImageDataProvider);
    });
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:false];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    [self setUniformsForProgramAtIndex:0];
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    glUniform1i(filterInputTextureUniform, 2);
    
    if (_filterSourceTexture2)
    {
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, _filterSourceTexture2);
        glUniform1i(_filterInputTextureUniform2, 3);
    }
    
    if (_filterSourceTexture3)
    {
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, _filterSourceTexture3);
        glUniform1i(_filterInputTextureUniform3, 4);
    }
    
    if (_filterSourceTexture4)
    {
        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, _filterSourceTexture4);
        glUniform1i(_filterInputTextureUniform4, 5);
    }
    
    if (_filterSourceTexture5)
    {
        glActiveTexture(GL_TEXTURE6);
        glBindTexture(GL_TEXTURE_2D, _filterSourceTexture5);
        glUniform1i(_filterInputTextureUniform5, 6);
    }
    
    if (_filterSourceTexture6)
    {
        glActiveTexture(GL_TEXTURE7);
        glBindTexture(GL_TEXTURE_2D, _filterSourceTexture6);
        glUniform1i(_filterInputTextureUniform6, 7);
    }
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
        dispatch_semaphore_signal(imageCaptureSemaphore);
}

- (void)setIntensity:(CGFloat)intensity
{
    _intensity = intensity;
    
    [self setFloat:(float)_intensity forUniform:_intensityUniform program:filterProgram];
}

@end

@implementation PGPhotoCustomFilterPass

@dynamic intensity;

- (instancetype)initWithShaderFile:(NSString *)shaderFile textureFiles:(NSArray *)textureFiles
{
    return [self initWithShaderFile:shaderFile textureFiles:textureFiles optimized:false];
}

- (instancetype)initWithShaderFile:(NSString *)shaderFile textureFiles:(NSArray *)textureFiles optimized:(bool)optimized
{
    NSString *fragmentShaderPathname = TGComponentsPathForResource(shaderFile, @"fsh");
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragmentShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableArray *textureImages = [[NSMutableArray alloc] init];
    for (id textureDefinition in textureFiles)
    {
        NSString *textureFile = nil;
        if ([textureDefinition isKindOfClass:[NSString class]])
        {
            textureFile = (NSString *)textureDefinition;
        }
        else if ([textureDefinition isKindOfClass:[NSArray class]])
        {
            NSArray *textureDefinitions = (NSArray *)textureDefinition;
            textureFile = optimized ? textureDefinitions.lastObject : textureDefinitions.firstObject;
        }

        NSString *name = [[textureFile lastPathComponent] stringByDeletingPathExtension];
        NSString *extension = [textureFile pathExtension];
        
        NSString *texturePathname = TGComponentsPathForResource(name, extension);
        UIImage *textureImage = [UIImage imageWithContentsOfFile:texturePathname];
        
        [textureImages addObject:textureImage];
    }

    return [self initWithShaderString:fragmentShaderString textureImages:textureImages];
}

- (instancetype)initWithShaderString:(NSString *)shaderString textureImages:(NSArray *)textureImages
{
    self = [super init];
    if (self != nil)
    {
        NSMutableString *fullShaderString = [[NSMutableString alloc] initWithString:PGPhotoFilterDefinitionsShaderString];
        [fullShaderString appendString:shaderString];
        [fullShaderString appendString:PGPhotoFilterMainShaderString];
        
        PGPhotoCustomFilter *filter = [[PGPhotoCustomFilter alloc] initWithFragmentShaderFromString:fullShaderString];
        
        NSInteger index = 0;
        for (UIImage *image in textureImages)
        {
            [filter addTextureWithImage:image textureIndex:index];
            index++;
        }
        
        _filter = filter;
    }
    return self;
}

- (void)setIntensity:(CGFloat)intensity
{
    [(PGPhotoCustomFilter *)_filter setIntensity:intensity];
}

@end
