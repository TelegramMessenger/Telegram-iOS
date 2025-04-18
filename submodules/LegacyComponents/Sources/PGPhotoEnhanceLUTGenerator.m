#import "PGPhotoEnhanceLUTGenerator.h"

#import "LegacyComponentsInternal.h"

#import "PGPhotoProcessPass.h"

const NSUInteger PGPhotoEnhanceHistogramBins = 256;
const NSUInteger PGPhotoEnhanceSegments = 4;

@interface PGPhotoEnhanceLUTGenerator ()
{
    CGFloat _clipLimit;
    
    CGSize _imageSize;
    GPUImageRotationMode _inputRotation;
    
    GPUImageFramebuffer *_firstInputFramebuffer;
    GPUImageFramebuffer *_outputFramebuffer;
    GPUImageFramebuffer *_retainedFramebuffer;
    
    GLProgram *_dataProgram;
    GLint _dataPositionAttribute;
    GLint _dataTextureCoordinateAttribute;
    GLint _dataInputTextureUniform;
    
    bool _hasReadCurrentFrame;
    
    GLubyte *_rawBytesForImage;
    bool _lockNextFramebuffer;
}

@property (nonatomic, assign) BOOL enabled;

@end

@implementation PGPhotoEnhanceLUTGenerator

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _clipLimit = 1.25f;
        
        self.enabled = true;
        _lockNextFramebuffer = false;
        _inputRotation = kGPUImageNoRotation;
        
        [GPUImageContext useImageProcessingContext];
        
        if (([GPUImageContext supportsFastTextureUpload]))
        {
            _dataProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:PGPhotoEnhanceColorSwapShaderString];
        }
        else
        {
            _dataProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
        }

        if (!_dataProgram.initialized)
        {
            [_dataProgram addAttribute:@"position"];
            [_dataProgram addAttribute:@"inputTexCoord"];

            if (![_dataProgram link])
            {
                NSString *progLog = [_dataProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [_dataProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [_dataProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                _dataProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        _dataPositionAttribute = [_dataProgram attributeIndex:@"position"];
        _dataTextureCoordinateAttribute = [_dataProgram attributeIndex:@"inputTexCoord"];
        _dataInputTextureUniform = [_dataProgram uniformIndex:@"sourceImage"];
    }
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

#pragma mark - GPUImageInput

- (void)newFrameReadyAtTime:(CMTime)__unused frameTime atIndex:(NSInteger)__unused textureIndex
{
    if (self.skip)
        return;
    
    _hasReadCurrentFrame = false;
    _lockNextFramebuffer = true;
    
    NSUInteger totalSegments = PGPhotoEnhanceSegments * PGPhotoEnhanceSegments;
    CGSize tileSize = CGSizeMake(CGFloor(_imageSize.width / PGPhotoEnhanceSegments), CGFloor(_imageSize.height / PGPhotoEnhanceSegments));
    NSUInteger tileArea = (NSUInteger)(tileSize.width * tileSize.height);
    NSUInteger clipLimit = (NSUInteger)MAX(1, _clipLimit * tileArea / (CGFloat)PGPhotoEnhanceHistogramBins);
    CGFloat scale = 255.0f / (CGFloat)tileArea;
    
    GLubyte *bytes = [self _rawBytes];
    NSUInteger bytesPerRow = [_retainedFramebuffer bytesPerRow];
    
    NSUInteger hist[totalSegments][PGPhotoEnhanceHistogramBins];
    NSUInteger cdfs[totalSegments][PGPhotoEnhanceHistogramBins];
    NSUInteger cdfsMin[totalSegments];
    NSUInteger cdfsMax[totalSegments];
    
    memset(hist, 0, totalSegments * PGPhotoEnhanceHistogramBins * sizeof(NSUInteger));
    memset(cdfs, 0, totalSegments * PGPhotoEnhanceHistogramBins * sizeof(NSUInteger));
    memset(cdfsMin, 0, totalSegments * sizeof(NSUInteger));
    memset(cdfsMax, 0, totalSegments * sizeof(NSUInteger));
    
    CGFloat xMul = PGPhotoEnhanceSegments / _imageSize.width;
    CGFloat yMul = PGPhotoEnhanceSegments / _imageSize.height;

    for (NSUInteger y = 0; y < _imageSize.height; y++)
    {
        NSUInteger yOffset = y * bytesPerRow;
        for (NSUInteger x = 0; x < _imageSize.width; x++)
        {
            NSUInteger index = x * 4 + yOffset;
            
            NSUInteger tx = (NSUInteger)(x * xMul);
            NSUInteger ty = (NSUInteger)(y * yMul);
            NSUInteger t = ty * PGPhotoEnhanceSegments + tx;
                        
            GLubyte value = bytes[index + 2];
            hist[t][value]++;
        }
    }
    
    [_retainedFramebuffer unlockAfterReading];
    [_retainedFramebuffer unlock];
    _retainedFramebuffer = nil;
    
    for (NSUInteger i = 0; i < totalSegments; i++)
    {
        if (clipLimit > 0)
        {
            NSUInteger clipped = 0;
            for (NSUInteger j = 0; j < PGPhotoEnhanceHistogramBins; ++j)
            {
                if (hist[i][j] > clipLimit)
                {
                    clipped += hist[i][j] - clipLimit;
                    hist[i][j] = clipLimit;
                }
            }
            
            NSUInteger redistBatch = clipped / PGPhotoEnhanceHistogramBins;
            NSUInteger residual = clipped - redistBatch * PGPhotoEnhanceHistogramBins;
            
            for (NSUInteger j = 0; j < PGPhotoEnhanceHistogramBins; ++j)
                hist[i][j] += redistBatch;
            
            for (NSUInteger j = 0; j < residual; ++j)
                hist[i][j]++;
        }
        
        memcpy(&cdfs[i], &hist[i], PGPhotoEnhanceHistogramBins * sizeof(NSUInteger));

        NSUInteger hMin = PGPhotoEnhanceHistogramBins - 1;
        for (NSUInteger j = 0; j < hMin; ++j)
        {
            if (cdfs[i][j] != 0)
                hMin = j;
        }
        
        NSUInteger cdf = 0;
        for (NSUInteger j = hMin; j < PGPhotoEnhanceHistogramBins; ++j)
        {
            cdf += cdfs[i][j];
            cdfs[i][j] = (uint8_t)MIN(255, cdf * scale);
        }
        
        cdfsMin[i] = cdfs[i][hMin];
        cdfsMax[i] = cdfs[i][PGPhotoEnhanceHistogramBins - 1];
    }
    
    NSUInteger resultSize = 4 * PGPhotoEnhanceHistogramBins * totalSegments;
    NSUInteger resultBytesPerRow = 4 * PGPhotoEnhanceHistogramBins;
    
    GLubyte *result = calloc(resultSize, sizeof(GLubyte));
    for (NSUInteger tile = 0; tile < totalSegments; tile++)
    {
        NSUInteger yOffset = tile * resultBytesPerRow;
        for (NSUInteger i = 0; i < PGPhotoEnhanceHistogramBins; i++)
        {
            NSUInteger index = i * 4 + yOffset;
            result[index] = (uint8_t)cdfs[tile][i];
            result[index + 1] = (uint8_t)cdfsMin[tile];
            result[index + 2] = (uint8_t)cdfsMax[tile];
        }
    }
    
    if (self.lutDataReady != nil)
        self.lutDataReady(result);
}

- (NSInteger)nextAvailableTextureIndex
{
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)__unused textureIndex
{
    _firstInputFramebuffer = newInputFramebuffer;
    [_firstInputFramebuffer lock];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)__unused textureIndex
{
    _inputRotation = newInputRotation;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)__unused textureIndex
{
    _imageSize = newSize;
}

- (CGSize)maximumOutputSize
{
    return CGSizeMake(PGPhotoEnhanceHistogramBins, PGPhotoEnhanceSegments * PGPhotoEnhanceSegments);
}

- (void)endProcessing
{
    
}

- (BOOL)shouldIgnoreUpdatesToThisTarget
{
    return false;
}

- (BOOL)wantsMonochromeInput
{
    return false;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)__unused newValue
{
    
}

- (void)_render
{
    [GPUImageContext setActiveShaderProgram:_dataProgram];
    
    _outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:_imageSize onlyTexture:false];
    [_outputFramebuffer activateFramebuffer];
    
    if(_lockNextFramebuffer)
    {
        _retainedFramebuffer = _outputFramebuffer;
        [_retainedFramebuffer lock];
        [_retainedFramebuffer lockForReading];
        _lockNextFramebuffer = false;
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
    glBindTexture(GL_TEXTURE_2D, [_firstInputFramebuffer texture]);
    glUniform1i(_dataInputTextureUniform, 4);
    
    glVertexAttribPointer(_dataPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(_dataTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glEnableVertexAttribArray(_dataPositionAttribute);
    glEnableVertexAttribArray(_dataTextureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [_firstInputFramebuffer unlock];
}

- (GLubyte *)_rawBytes
{
    if ((_rawBytesForImage == NULL) && (![GPUImageContext supportsFastTextureUpload]))
    {
        _rawBytesForImage = (GLubyte *)calloc((NSInteger)(_imageSize.width * _imageSize.height) * 4, sizeof(GLubyte));
        _hasReadCurrentFrame = false;
    }
    
    if (!_hasReadCurrentFrame)
    {
        runSynchronouslyOnVideoProcessingQueue(^
        {
            [GPUImageContext useImageProcessingContext];
            [self _render];
            
            if ([GPUImageContext supportsFastTextureUpload])
            {
                glFinish();
                _rawBytesForImage = [_outputFramebuffer byteBuffer];
            }
            else
            {
                glReadPixels(0, 0, (GLsizei)_imageSize.width, (GLsizei)_imageSize.height, GL_RGBA, GL_UNSIGNED_BYTE, _rawBytesForImage);
            }
            
            _hasReadCurrentFrame = true;
        });
    }
    
    return _rawBytesForImage;
}

@end
