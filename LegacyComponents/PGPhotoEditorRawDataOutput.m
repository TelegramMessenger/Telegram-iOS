#import "PGPhotoEditorRawDataOutput.h"
#import "PGPhotoProcessPass.h"

#import "GPUImageContext.h"
#import "GLProgram.h"
#import "GPUImageFilter.h"

@interface PGPhotoEditorRawDataOutput ()
{
    GPUImageFramebuffer *firstInputFramebuffer, *outputFramebuffer, *retainedFramebuffer;
    
    bool hasReadFromTheCurrentFrame;
    
    GLProgram *dataProgram;
    GLint dataPositionAttribute, dataTextureCoordinateAttribute;
    GLint dataInputTextureUniform;
    
    GLubyte *_rawBytesForImage;
    
    bool lockNextFramebuffer;
}

@end

@implementation PGPhotoEditorRawDataOutput

@synthesize rawBytesForImage = _rawBytesForImage;
@synthesize newFrameAvailableBlock = _newFrameAvailableBlock;
@synthesize enabled;

#pragma mark -
#pragma mark Initialization and teardown

- (instancetype)initWithImageSize:(CGSize)newImageSize resultsInBGRAFormat:(bool)resultsInBGRAFormat
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.enabled = true;
    lockNextFramebuffer = false;
    outputBGRA = resultsInBGRAFormat;
    _imageSize = newImageSize;
    hasReadFromTheCurrentFrame = false;
    _rawBytesForImage = NULL;
    inputRotation = kGPUImageNoRotation;
    
    [GPUImageContext useImageProcessingContext];
    if ( (outputBGRA && ![GPUImageContext supportsFastTextureUpload]) || (!outputBGRA && [GPUImageContext supportsFastTextureUpload]) )
    {
        dataProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:PGPhotoEnhanceColorSwapShaderString];
    }
    else
    {
        dataProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
    }
    
    if (!dataProgram.initialized)
    {
        [dataProgram addAttribute:@"position"];
        [dataProgram addAttribute:@"inputTextureCoordinate"];
        
        if (![dataProgram link])
        {
            NSString *progLog = [dataProgram programLog];
            NSLog(@"Program link log: %@", progLog);
            NSString *fragLog = [dataProgram fragmentShaderLog];
            NSLog(@"Fragment shader compile log: %@", fragLog);
            NSString *vertLog = [dataProgram vertexShaderLog];
            NSLog(@"Vertex shader compile log: %@", vertLog);
            dataProgram = nil;
            NSAssert(NO, @"Filter shader link failed");
        }
    }
    
    dataPositionAttribute = [dataProgram attributeIndex:@"position"];
    dataTextureCoordinateAttribute = [dataProgram attributeIndex:@"inputTextureCoordinate"];
    dataInputTextureUniform = [dataProgram uniformIndex:@"inputImageTexture"];
    
    return self;
}

- (void)dealloc
{
    if (_rawBytesForImage != NULL && (![GPUImageContext supportsFastTextureUpload]))
    {
        free(_rawBytesForImage);
        _rawBytesForImage = NULL;
    }
}

#pragma mark -
#pragma mark Data access

- (void)renderAtInternalSize
{
    [GPUImageContext setActiveShaderProgram:dataProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:_imageSize onlyTexture:false];
    [outputFramebuffer activateFramebuffer];
    
    if(lockNextFramebuffer)
    {
        retainedFramebuffer = outputFramebuffer;
        [retainedFramebuffer lock];
        [retainedFramebuffer lockForReading];
        lockNextFramebuffer = NO;
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    glUniform1i(dataInputTextureUniform, 4);
    
    glVertexAttribPointer(dataPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(dataTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glEnableVertexAttribArray(dataPositionAttribute);
    glEnableVertexAttribArray(dataTextureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [firstInputFramebuffer unlock];
}

- (PGByteColorVector)colorAtLocation:(CGPoint)locationInImage
{
    PGByteColorVector *imageColorBytes = (PGByteColorVector *)self.rawBytesForImage;
    
    CGPoint locationToPickFrom = CGPointZero;
    locationToPickFrom.x = MIN(MAX(locationInImage.x, 0.0), (_imageSize.width - 1.0));
    locationToPickFrom.y = MIN(MAX((_imageSize.height - locationInImage.y), 0.0), (_imageSize.height - 1.0));
    
    if (outputBGRA)
    {
        PGByteColorVector flippedColor = imageColorBytes[(int)(round((locationToPickFrom.y * _imageSize.width) + locationToPickFrom.x))];
        GLubyte temporaryRed = flippedColor.red;
        
        flippedColor.red = flippedColor.blue;
        flippedColor.blue = temporaryRed;
        
        return flippedColor;
    }
    else
    {
        return imageColorBytes[(int)(round((locationToPickFrom.y * _imageSize.width) + locationToPickFrom.x))];
    }
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)__unused frameTime atIndex:(NSInteger)__unused textureIndex
{
    hasReadFromTheCurrentFrame = NO;
    
    if (_newFrameAvailableBlock != nil)
        _newFrameAvailableBlock();
}

- (NSInteger)nextAvailableTextureIndex
{
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)__unused textureIndex
{
    firstInputFramebuffer = newInputFramebuffer;
    [firstInputFramebuffer lock];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)__unused textureIndex
{
    inputRotation = newInputRotation;
}

- (void)setInputSize:(CGSize)__unused newSize atIndex:(NSInteger)__unused textureIndex
{
}

- (CGSize)maximumOutputSize
{
    return _imageSize;
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
#pragma mark Accessors

- (GLubyte *)rawBytesForImage
{
    if ((_rawBytesForImage == NULL) && (![GPUImageContext supportsFastTextureUpload]))
    {
        _rawBytesForImage = (GLubyte *) calloc((unsigned long)(_imageSize.width * _imageSize.height * 4), sizeof(GLubyte));
        hasReadFromTheCurrentFrame = NO;
    }
    
    if (hasReadFromTheCurrentFrame)
    {
        return _rawBytesForImage;
    }
    else
    {
        runSynchronouslyOnVideoProcessingQueue(^
        {
            [GPUImageContext useImageProcessingContext];
            [self renderAtInternalSize];
            
            if ([GPUImageContext supportsFastTextureUpload])
            {
                glFinish();
                _rawBytesForImage = [outputFramebuffer byteBuffer];
            }
            else
            {
                glReadPixels(0, 0, (GLsizei)(_imageSize.width), (GLsizei)_imageSize.height, GL_RGBA, GL_UNSIGNED_BYTE, _rawBytesForImage);
            }
            
            hasReadFromTheCurrentFrame = YES;
            
        });
        
        return _rawBytesForImage;
    }
}

- (NSUInteger)bytesPerRowInOutput
{
    return [retainedFramebuffer bytesPerRow];
}

- (void)setImageSize:(CGSize)newImageSize
{
    _imageSize = newImageSize;
    if (_rawBytesForImage != NULL && (![GPUImageContext supportsFastTextureUpload]))
    {
        free(_rawBytesForImage);
        _rawBytesForImage = NULL;
    }
}

- (void)lockFramebufferForReading
{
    lockNextFramebuffer = YES;
}

- (void)unlockFramebufferAfterReading
{
    [retainedFramebuffer unlockAfterReading];
    [retainedFramebuffer unlock];
    retainedFramebuffer = nil;
}

@end