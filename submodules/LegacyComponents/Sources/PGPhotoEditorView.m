#import "PGPhotoEditorView.h"

#import "GPUImageContext.h"
#import "GPUImageFilter.h"

#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

@interface PGPhotoEditorView ()
{
    GPUImageRotationMode inputRotation;
    CGSize _sizeInPixels;
    
    GPUImageFramebuffer *inputFramebufferForDisplay;
    GLuint displayRenderbuffer;
    GLuint displayFramebuffer;
    
    GLProgram *displayProgram;
    GLint displayPositionAttribute;
    GLint displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
    CGSize inputImageSize;
    GLfloat imageVertices[8];
    GLfloat backgroundColorRed;
    GLfloat backgroundColorGreen;
    GLfloat backgroundColorBlue;
    GLfloat backgroundColorAlpha;
    
    CGSize boundsSizeAtFrameBufferEpoch;
}

@property (assign, nonatomic) NSUInteger aspectRatio;

@end

@implementation PGPhotoEditorView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (void)commonInit
{
    if ([self respondsToSelector:@selector(setContentScaleFactor:)])
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
    
    self.enabled = true;
    
    inputRotation = kGPUImageNoRotation;
    self.opaque = true;

    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = true;
    eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking: @NO,
                                      kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8 };
    
    runSynchronouslyOnVideoProcessingQueue(^
    {
        [GPUImageContext useImageProcessingContext];
        
        displayProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
        
        if (!displayProgram.initialized)
        {
            [displayProgram addAttribute:@"position"];
            [displayProgram addAttribute:@"inputTexCoord"];
            
            if (![displayProgram link])
            {
                NSString *progLog = [displayProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [displayProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [displayProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                displayProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        displayPositionAttribute = [displayProgram attributeIndex:@"position"];
        displayTextureCoordinateAttribute = [displayProgram attributeIndex:@"inputTexCoord"];
        displayInputTextureUniform = [displayProgram uniformIndex:@"sourceImage"];
        
        [GPUImageContext setActiveShaderProgram:displayProgram];
        glEnableVertexAttribArray(displayPositionAttribute);
        glEnableVertexAttribArray(displayTextureCoordinateAttribute);
        
        [self setBackgroundColorRed:0.0 green:0.0 blue:0.0 alpha:1.0];
        [self createDisplayFramebuffer];
    });
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!CGSizeEqualToSize(self.bounds.size, boundsSizeAtFrameBufferEpoch) &&
        !CGSizeEqualToSize(self.bounds.size, CGSizeZero))
    {
        runSynchronouslyOnVideoProcessingQueue(^
        {
            [self destroyDisplayFramebuffer];
            [self createDisplayFramebuffer];
            [self recalculateViewGeometry];
        });
    }
}

- (void)dealloc
{
    runSynchronouslyOnVideoProcessingQueue(^
    {
        [self destroyDisplayFramebuffer];
    });
}

- (void)createDisplayFramebuffer
{
    [GPUImageContext useImageProcessingContext];
    
    glGenFramebuffers(1, &displayFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
    
    glGenRenderbuffers(1, &displayRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    
    [[[GPUImageContext sharedImageProcessingContext] context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    
    GLint backingWidth, backingHeight;
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if ( (backingWidth == 0) || (backingHeight == 0) )
    {
        [self destroyDisplayFramebuffer];
        return;
    }
    
    _sizeInPixels.width = (CGFloat)backingWidth;
    _sizeInPixels.height = (CGFloat)backingHeight;
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, displayRenderbuffer);
    
    GLuint framebufferCreationStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferCreationStatus == GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.bounds.size.width, self.bounds.size.height);
    boundsSizeAtFrameBufferEpoch = self.bounds.size;
}

- (void)destroyDisplayFramebuffer
{
    [GPUImageContext useImageProcessingContext];
    
    if (displayFramebuffer)
    {
        glDeleteFramebuffers(1, &displayFramebuffer);
        displayFramebuffer = 0;
    }
    
    if (displayRenderbuffer)
    {
        glDeleteRenderbuffers(1, &displayRenderbuffer);
        displayRenderbuffer = 0;
    }
}

- (void)setDisplayFramebuffer
{
    if (!displayFramebuffer)
    {
        [self createDisplayFramebuffer];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
    
    glViewport(0, 0, (GLint)_sizeInPixels.width, (GLint)_sizeInPixels.height);
}

- (void)presentFramebuffer
{
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    [[GPUImageContext sharedImageProcessingContext] presentBufferForDisplay];
}

#pragma mark -
#pragma mark Handling fill mode

- (void)recalculateViewGeometry
{
    runSynchronouslyOnVideoProcessingQueue(^
    {
        CGFloat heightScaling, widthScaling;
        
        widthScaling = 1.0;
        heightScaling = 1.0;
        
        imageVertices[0] = (GLfloat)-widthScaling;
        imageVertices[1] = (GLfloat)-heightScaling;
        imageVertices[2] = (GLfloat)widthScaling;
        imageVertices[3] = (GLfloat)-heightScaling;
        imageVertices[4] = (GLfloat)-widthScaling;
        imageVertices[5] = (GLfloat)heightScaling;
        imageVertices[6] = (GLfloat)widthScaling;
        imageVertices[7] = (GLfloat)heightScaling;
    });
}

- (void)setBackgroundColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent alpha:(GLfloat)alphaComponent
{
    backgroundColorRed = redComponent;
    backgroundColorGreen = greenComponent;
    backgroundColorBlue = blueComponent;
    backgroundColorAlpha = alphaComponent;
}

+ (const GLfloat *)textureCoordinatesForRotation:(GPUImageRotationMode)rotationMode
{
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat rotateRightTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateLeftTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotate180HorizontalFlipTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    switch(rotationMode)
    {
        case kGPUImageNoRotation: return noRotationTextureCoordinates;
        case kGPUImageRotateLeft: return rotateLeftTextureCoordinates;
        case kGPUImageRotateRight: return rotateRightTextureCoordinates;
        case kGPUImageFlipVertical: return verticalFlipTextureCoordinates;
        case kGPUImageFlipHorizonal: return horizontalFlipTextureCoordinates;
        case kGPUImageRotateRightFlipVertical: return rotateRightVerticalFlipTextureCoordinates;
        case kGPUImageRotateRightFlipHorizontal: return rotateRightHorizontalFlipTextureCoordinates;
        case kGPUImageRotate180: return rotate180TextureCoordinates;
        case kGPUImageRotate180FlipHorizontal: return rotate180HorizontalFlipTextureCoordinates;
    }
}

#pragma mark - Input

- (void)newFrameReadyAtTime:(CMTime)__unused frameTime atIndex:(NSInteger)__unused textureIndex
{
    runSynchronouslyOnVideoProcessingQueue(^
    {
        [GPUImageContext setActiveShaderProgram:displayProgram];
        [self setDisplayFramebuffer];
        
        glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, [inputFramebufferForDisplay texture]);
        glUniform1i(displayInputTextureUniform, 4);
        
        glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
        glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [PGPhotoEditorView textureCoordinatesForRotation:inputRotation]);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        [self presentFramebuffer];
        [inputFramebufferForDisplay unlock];
        inputFramebufferForDisplay = nil;
    });
}

- (NSInteger)nextAvailableTextureIndex
{
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)__unused textureIndex
{
    inputFramebufferForDisplay = newInputFramebuffer;
    [inputFramebufferForDisplay lock];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)__unused textureIndex
{
    inputRotation = newInputRotation;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)__unused textureIndex
{
    runSynchronouslyOnVideoProcessingQueue(^{
        CGSize rotatedSize = newSize;
        
        if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
        {
            rotatedSize.width = newSize.height;
            rotatedSize.height = newSize.width;
        }
        
        if (!CGSizeEqualToSize(inputImageSize, rotatedSize))
        {
            inputImageSize = rotatedSize;
            [self recalculateViewGeometry];
        }
    });
}

- (CGSize)maximumOutputSize
{
    if ([self respondsToSelector:@selector(setContentScaleFactor:)])
    {
        CGSize pointSize = self.bounds.size;
        return CGSizeMake(self.contentScaleFactor * pointSize.width, self.contentScaleFactor * pointSize.height);
    }
    else
    {
        return self.bounds.size;
    }
}

- (void)endProcessing
{
    
}

- (BOOL)shouldIgnoreUpdatesToThisTarget
{
    return NO;
}

- (BOOL)wantsMonochromeInput
{
    return NO;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)__unused newValue
{
    
}

#pragma mark -

- (CGSize)sizeInPixels
{
    if (CGSizeEqualToSize(_sizeInPixels, CGSizeZero))
    {
        return [self maximumOutputSize];
    }
    else
    {
        return _sizeInPixels;
    }
}

@end
