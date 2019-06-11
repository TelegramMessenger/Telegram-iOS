#import "PGPhotoEditorRawDataInput.h"

@interface PGPhotoEditorRawDataInput ()
{
    CGSize _imageSize;
    bool _processed;
    
    dispatch_semaphore_t _updateSemaphore;
}
@end

@implementation PGPhotoEditorRawDataInput

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _updateSemaphore = dispatch_semaphore_create(1);
        _processed = false;
    }
    return self;
}

- (void)invalidate
{
}

- (instancetype)initWithBytes:(GLubyte *)bytes size:(CGSize)size
{
    return [self initWithBytes:bytes size:size pixelFormat:GPUPixelFormatBGRA type:GPUPixelTypeUByte];
}

- (instancetype)initWithBytes:(GLubyte *)bytes size:(CGSize)size pixelFormat:(GPUPixelFormat)pixelFormat
{
    return [self initWithBytes:bytes size:size pixelFormat:pixelFormat type:GPUPixelTypeUByte];
}

- (instancetype)initWithBytes:(GLubyte *)bytes size:(CGSize)size pixelFormat:(GPUPixelFormat)pixelFormat type:(GPUPixelType)pixelType
{
    self = [self init];
    if (self != nil)
    {
        _imageSize = size;
        self.pixelFormat = pixelFormat;
        self.pixelType = pixelType;
        
        if (bytes != NULL)
            [self uploadBytes:bytes];
    }
    return self;
}

- (void)dealloc
{
    [outputFramebuffer enableReferenceCounting];
    [outputFramebuffer unlock];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation
{
    [super addTarget:newTarget atTextureLocation:textureLocation];
    
    if (_processed)
    {
        [newTarget setInputSize:_imageSize atIndex:textureLocation];
        [newTarget setInputFramebuffer:outputFramebuffer atIndex:textureLocation];
        [newTarget newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureLocation];
    }
}

- (void)removeAllTargets
{
    [super removeAllTargets];
    _processed = false;
}

- (void)uploadBytes:(GLubyte *)bytes
{
    [GPUImageContext useImageProcessingContext];
    
    if (outputFramebuffer != nil)
    {
        [outputFramebuffer enableReferenceCounting];
        [outputFramebuffer unlock];
    }
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:_imageSize textureOptions:self.outputTextureOptions onlyTexture:true];
    [outputFramebuffer disableReferenceCounting];
    
    glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
    glTexImage2D(GL_TEXTURE_2D, 0, _pixelFormat==GPUPixelFormatRGB ? GL_RGB : GL_RGBA, (int)_imageSize.width, (int)_imageSize.height, 0, (GLint)_pixelFormat, (GLenum)_pixelType, bytes);
}

- (void)updateDataWithBytes:(GLubyte *)bytes size:(CGSize)size
{
    _imageSize = size;
    
    [self uploadBytes:bytes];
}

- (void)processData
{
    _processed = true;
    
    if (dispatch_semaphore_wait(_updateSemaphore, DISPATCH_TIME_NOW) != 0)
        return;
    
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        CGSize pixelSizeOfImage = [self outputImageSize];
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [currentTarget setInputSize:pixelSizeOfImage atIndex:textureIndexOfTarget];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            [currentTarget newFrameReadyAtTime:kCMTimeInvalid atIndex:textureIndexOfTarget];
        }
        
        dispatch_semaphore_signal(_updateSemaphore);
    });
}

- (void)processDataForTimestamp:(CMTime)frameTime
{
    _processed = true;
    
    if (dispatch_semaphore_wait(_updateSemaphore, DISPATCH_TIME_NOW) != 0)
        return;
    
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        CGSize pixelSizeOfImage = [self outputImageSize];
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [currentTarget setInputSize:pixelSizeOfImage atIndex:textureIndexOfTarget];
            [currentTarget newFrameReadyAtTime:frameTime atIndex:textureIndexOfTarget];
        }
        
        dispatch_semaphore_signal(_updateSemaphore);
    });
}

- (CGSize)outputImageSize
{
    return _imageSize;
}

@end
