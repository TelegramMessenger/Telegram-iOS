#import "GPUImageTextureInput.h"

@implementation GPUImageTextureInput
{
    CIContext *ciContext;
}
#pragma mark -
#pragma mark Initialization and teardown

- (instancetype)initWithTexture:(GLuint)newInputTexture size:(CGSize)newTextureSize
{
    if (!(self = [super init]))
    {
        return nil;
    }

    textureSize = newTextureSize;
    
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        outputFramebuffer = [[GPUImageFramebuffer alloc] initWithSize:newTextureSize overriddenTexture:newInputTexture];
    });
    
    return self;
}

- (instancetype)initWithCIImage:(CIImage *)ciImage
{
    if (!(self = [super init]))
    {
        return nil;
    }
    textureSize = ciImage.extent.size;
    
    runSynchronouslyOnVideoProcessingQueue(^{
        EAGLContext *context = [[GPUImageContext sharedImageProcessingContext] context];
        [EAGLContext setCurrentContext:context];
        
        GLsizei backingWidth = ciImage.extent.size.width;
        GLsizei backingHeight = ciImage.extent.size.height;
        GLuint outputTexture, defaultFramebuffer;
        
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &outputTexture);
        glBindTexture(GL_TEXTURE_2D, outputTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE1);
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        glBindTexture(GL_TEXTURE_2D, outputTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, backingWidth, backingHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, outputTexture, 0);
        
        NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        
        glBindTexture(GL_TEXTURE_2D, 0);
        
        CIImage *updatedCIImage = [ciImage imageByApplyingTransform:CGAffineTransformConcat(CGAffineTransformMakeScale(1.0f, -1.0f), CGAffineTransformMakeTranslation(0.0f, ciImage.extent.size.height))];
        
        ciContext = [CIContext contextWithEAGLContext:context options:@{kCIContextWorkingColorSpace: [NSNull null]}];
        [ciContext drawImage:updatedCIImage inRect:updatedCIImage.extent fromRect:updatedCIImage.extent];
        
        [GPUImageContext useImageProcessingContext];
        outputFramebuffer = [[GPUImageFramebuffer alloc] initWithSize:ciImage.extent.size overridenFramebuffer:defaultFramebuffer overriddenTexture:outputTexture];
    });
    
    return self;
}

- (void)dealloc {
    NSLog(@"deall texinp");
}

- (void)setCIImage:(CIImage *)ciImage {
    runSynchronouslyOnVideoProcessingQueue(^{
        EAGLContext *context = [[GPUImageContext sharedImageProcessingContext] context];
        [EAGLContext setCurrentContext:context];
        
        GLsizei backingWidth = ciImage.extent.size.width;
        GLsizei backingHeight = ciImage.extent.size.height;
        
        GLint outputTexture = outputFramebuffer.texture;

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, outputTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE1);
        [outputFramebuffer useFramebuffer];

        glBindTexture(GL_TEXTURE_2D, outputTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, backingWidth, backingHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, outputTexture, 0);

        NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", glCheckFramebufferStatus(GL_FRAMEBUFFER));

        glBindTexture(GL_TEXTURE_2D, 0);

        CIImage *updatedCIImage = [ciImage imageByApplyingTransform:CGAffineTransformConcat(CGAffineTransformMakeScale(1.0f, -1.0f), CGAffineTransformMakeTranslation(0.0f, ciImage.extent.size.height))];

        [ciContext drawImage:updatedCIImage inRect:updatedCIImage.extent fromRect:updatedCIImage.extent];
    });
}

- (void)processTextureWithFrameTime:(CMTime)frameTime synchronous:(bool)synchronous completion:(void (^)(void))completion
{
    void (^block)(void) = ^
    {
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [currentTarget setInputSize:textureSize atIndex:targetTextureIndex];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
            [currentTarget newFrameReadyAtTime:frameTime atIndex:targetTextureIndex];
        }
        
        if (completion != nil)
            completion();
    };
    
    if (synchronous)
        runSynchronouslyOnVideoProcessingQueue(block);
    else
        runAsynchronouslyOnVideoProcessingQueue(block);
}

- (CGSize)textureSize {
    return textureSize;
}

@end
