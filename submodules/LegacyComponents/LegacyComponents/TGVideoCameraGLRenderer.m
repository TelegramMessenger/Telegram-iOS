#import "TGVideoCameraGLRenderer.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/glext.h>

#import <LegacyComponents/TGPaintShader.h>

@interface TGVideoCameraGLRenderer ()
{
	EAGLContext *_context;
	CVOpenGLESTextureCacheRef _textureCache;
    CVOpenGLESTextureCacheRef _prevTextureCache;
	CVOpenGLESTextureCacheRef _renderTextureCache;
	CVPixelBufferPoolRef _bufferPool;
	CFDictionaryRef _bufferPoolAuxAttributes;
	CMFormatDescriptionRef _outputFormatDescription;
    
    CVPixelBufferRef _previousPixelBuffer;
    
    TGPaintShader *_shader;
	GLint _frameUniform;
    GLint _previousFrameUniform;
    GLint _opacityUniform;
    GLint _aspectRatioUniform;
    GLint _noMirrorUniform;
	GLuint _offscreenBufferHandle;
    
    CGFloat _aspectRatio;
    float _textureVertices[8];
}

@end

@implementation TGVideoCameraGLRenderer

- (instancetype)init
{
	self = [super init];
	if ( self )
	{
		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if (!_context)
			return nil;
	}
	return self;
}

- (void)dealloc
{
	[self deleteBuffers];
}

- (void)prepareForInputWithFormatDescription:(CMFormatDescriptionRef)inputFormatDescription outputRetainedBufferCountHint:(size_t)outputRetainedBufferCountHint
{
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription);
    CGFloat minSide = MIN(dimensions.width, dimensions.height);
    CGFloat maxSide = MAX(dimensions.width, dimensions.height);
    CGSize outputSize = CGSizeMake(minSide, minSide);
    
    _aspectRatio = minSide / maxSide;
    [self updateTextureVertices];
    
	[self deleteBuffers];
    [self initializeBuffersWithOutputSize:outputSize retainedBufferCountHint:outputRetainedBufferCountHint];
}

- (void)setOrientation:(AVCaptureVideoOrientation)orientation
{
    _orientation = orientation;
    [self updateTextureVertices];
}

- (void)setMirror:(bool)mirror
{
    _mirror = mirror;
    [self updateTextureVertices];
}

- (void)updateTextureVertices
{
    GLfloat centerOffset = (GLfloat)((1.0f - _aspectRatio) / 2.0f);
    
    switch (_orientation)
    {
        case AVCaptureVideoOrientationPortrait:
            if (!_mirror)
            {
                _textureVertices[0] = centerOffset;
                _textureVertices[1] = 1.0f;
                _textureVertices[2] = centerOffset;
                _textureVertices[3] = 0.0f;
                _textureVertices[4] = (1.0f - centerOffset);
                _textureVertices[5] = 1.0f;
                _textureVertices[6] = (1.0f - centerOffset);
                _textureVertices[7] = 0.0f;
            }
            else
            {
                _textureVertices[0] = (1.0f - centerOffset);
                _textureVertices[1] = 0.0f;
                _textureVertices[2] = (1.0f - centerOffset);
                _textureVertices[3] = 1.0f;
                _textureVertices[4] = centerOffset;
                _textureVertices[5] = 0.0f;
                _textureVertices[6] = centerOffset;
                _textureVertices[7] = 1.0f;
            }
            break;
            
        case AVCaptureVideoOrientationLandscapeLeft:
            if (!_mirror)
            {
                _textureVertices[0] = (1.0f - centerOffset);
                _textureVertices[1] = 1.0f;
                _textureVertices[2] = centerOffset;
                _textureVertices[3] = 1.0f;
                _textureVertices[4] = (1.0f - centerOffset);
                _textureVertices[5] = 0.0f;
                _textureVertices[6] = centerOffset;
                _textureVertices[7] = 0.0f;
            }
            else
            {
                _textureVertices[0] = centerOffset;
                _textureVertices[1] = 0.0f;
                _textureVertices[2] = (1.0f - centerOffset);
                _textureVertices[3] = 0.0f;
                _textureVertices[4] = centerOffset;
                _textureVertices[5] = 1.0f;
                _textureVertices[6] = (1.0f - centerOffset);
                _textureVertices[7] = 1.0f;
            }
            break;
            
        case AVCaptureVideoOrientationLandscapeRight:
            if (!_mirror)
            {
                _textureVertices[0] = centerOffset;
                _textureVertices[1] = 0.0f;
                _textureVertices[2] = (1.0f - centerOffset);
                _textureVertices[3] = 0.0f;
                _textureVertices[4] = centerOffset;
                _textureVertices[5] = 1.0f;
                _textureVertices[6] = (1.0f - centerOffset);
                _textureVertices[7] = 1.0f;
            }
            else
            {
                _textureVertices[0] = (1.0f - centerOffset);
                _textureVertices[1] = 1.0f;
                _textureVertices[2] = centerOffset;
                _textureVertices[3] = 1.0f;
                _textureVertices[4] = (1.0f - centerOffset);
                _textureVertices[5] = 0.0f;
                _textureVertices[6] = centerOffset;
                _textureVertices[7] = 0.0f;
            }
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            if (!_mirror)
            {
                _textureVertices[0] = 1.0f - centerOffset;
                _textureVertices[1] = 0.0f;
                _textureVertices[2] = 1.0f - centerOffset;
                _textureVertices[3] = 1.0f;
                _textureVertices[4] = centerOffset;
                _textureVertices[5] = 0.0f;
                _textureVertices[6] = centerOffset;
                _textureVertices[7] = 1.0f;
            }
            else
            {
                _textureVertices[0] = centerOffset;
                _textureVertices[1] = 1.0f;
                _textureVertices[2] = centerOffset;
                _textureVertices[3] = 0.0f;
                _textureVertices[4] = 1.0f - centerOffset;
                _textureVertices[5] = 1.0f;
                _textureVertices[6] = 1.0f - centerOffset;
                _textureVertices[7] = 0.0f;
            }
            break;
        default:
            break;
    }
}

- (void)reset
{
	[self deleteBuffers];
}

- (bool)hasPreviousPixelbuffer
{
    return _previousPixelBuffer != NULL;
}

- (void)setPreviousPixelBuffer:(CVPixelBufferRef)previousPixelBuffer
{
    if (_previousPixelBuffer != NULL)
    {
        CFRelease(_previousPixelBuffer);
        _previousPixelBuffer = NULL;
    }
    
    _previousPixelBuffer = previousPixelBuffer;
    if (_previousPixelBuffer != NULL)
        CFRetain(_previousPixelBuffer);
}

- (CVPixelBufferRef)copyRenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
	static const GLfloat squareVertices[] =
    {
		-1.0f, -1.0f,
		1.0f, -1.0f,
		-1.0f,  1.0f,
		1.0f,  1.0f,
	};
	
	if (_offscreenBufferHandle == 0)
		return NULL;
	
	if (pixelBuffer == NULL)
		return NULL;
	
	const CMVideoDimensions srcDimensions = { (int32_t)CVPixelBufferGetWidth(pixelBuffer), (int32_t)CVPixelBufferGetHeight(pixelBuffer) };
	const CMVideoDimensions dstDimensions = CMVideoFormatDescriptionGetDimensions(_outputFormatDescription);
		
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return NULL;
	}
	
	CVReturn err = noErr;
	CVOpenGLESTextureRef srcTexture = NULL;
    CVOpenGLESTextureRef prevTexture = NULL;
	CVOpenGLESTextureRef dstTexture = NULL;
	CVPixelBufferRef dstPixelBuffer = NULL;
	
	err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, srcDimensions.width, srcDimensions.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &srcTexture);
    
	if (!srcTexture || err)
		goto bail;
    
    bool hasPreviousTexture = false;
    if (_previousPixelBuffer != NULL)
    {
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _prevTextureCache, _previousPixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, srcDimensions.width, srcDimensions.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &prevTexture);
        
        if (!prevTexture || err)
            goto bail;
        
        hasPreviousTexture = true;
    }
    
	err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferPoolAuxAttributes, &dstPixelBuffer);
	if (err == kCVReturnWouldExceedAllocationThreshold)
    {
		CVOpenGLESTextureCacheFlush(_renderTextureCache, 0);
		err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferPoolAuxAttributes, &dstPixelBuffer);
	}
    
	if (err)
		goto bail;

	err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _renderTextureCache, dstPixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, dstDimensions.width, dstDimensions.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &dstTexture);
	
	if (!dstTexture || err)
		goto bail;
	
	glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
	glViewport(0, 0, dstDimensions.width, dstDimensions.height);
	glUseProgram(_shader.program);
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(CVOpenGLESTextureGetTarget(dstTexture), CVOpenGLESTextureGetName(dstTexture));
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(dstTexture), CVOpenGLESTextureGetName(dstTexture), 0);
	
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(CVOpenGLESTextureGetTarget(srcTexture), CVOpenGLESTextureGetName(srcTexture));
	glUniform1i(_frameUniform, 1);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    if (hasPreviousTexture)
    {
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(CVOpenGLESTextureGetTarget(prevTexture), CVOpenGLESTextureGetName(prevTexture));
        glUniform1i(_previousFrameUniform, 2);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
	
	glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, squareVertices);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, _textureVertices);
	glEnableVertexAttribArray(1);
    
    glUniform1f(_opacityUniform, (GLfloat)_opacity);
    glUniform1f(_aspectRatioUniform, (GLfloat)(1.0f / _aspectRatio));
    glUniform1f(_noMirrorUniform, (GLfloat)(_mirror ? 1 : -1));
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	glBindTexture(CVOpenGLESTextureGetTarget(srcTexture), 0);
    if (hasPreviousTexture)
        glBindTexture(CVOpenGLESTextureGetTarget(prevTexture), 0);
	glBindTexture(CVOpenGLESTextureGetTarget(dstTexture), 0);
	
	glFlush();
	
bail:
	if (oldContext != _context)
		[EAGLContext setCurrentContext:oldContext];
	
	if (srcTexture)
		CFRelease(srcTexture);
    
    if (prevTexture)
        CFRelease(prevTexture);
	
	if (dstTexture)
		CFRelease(dstTexture);
	
	return dstPixelBuffer;
}

- (CMFormatDescriptionRef)outputFormatDescription
{
	return _outputFormatDescription;
}

- (bool)initializeBuffersWithOutputSize:(CGSize)outputSize retainedBufferCountHint:(size_t)clientRetainedBufferCountHint
{
	bool success = true;
	
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return false;
	}
	
	glDisable(GL_DEPTH_TEST);
	
	glGenFramebuffers(1, &_offscreenBufferHandle);
	glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
	
	CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
	if (err)
    {
		success = false;
		goto bail;
	}
	
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_prevTextureCache);
    if (err)
    {
        success = false;
        goto bail;
    }
    
	err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_renderTextureCache);
	if (err)
    {
		success = false;
		goto bail;
	}
    
    _shader = [[TGPaintShader alloc] initWithVertexShader:@"VideoMessage" fragmentShader:@"VideoMessage" attributes:@[ @"inPosition", @"inTexcoord" ] uniforms:@[ @"texture", @"previousTexture", @"opacity", @"aspectRatio", @"noMirror" ]];
    
    _frameUniform = [_shader uniformForKey:@"texture"];
    _previousFrameUniform = [_shader uniformForKey:@"previousTexture"];
    _opacityUniform = [_shader uniformForKey:@"opacity"];
    _aspectRatioUniform = [_shader uniformForKey:@"aspectRatio"];
    _noMirrorUniform = [_shader uniformForKey:@"noMirror"];
    
	size_t maxRetainedBufferCount = clientRetainedBufferCountHint + 1;
    _bufferPool = [TGVideoCameraGLRenderer createPixelBufferPoolWithWidth:(int32_t)outputSize.width height:(int32_t)outputSize.height pixelFormat:kCVPixelFormatType_32BGRA maxBufferCount:(int32_t)maxRetainedBufferCount];
    
	if (!_bufferPool)
    {
		success = NO;
		goto bail;
	}
	
    _bufferPoolAuxAttributes = [TGVideoCameraGLRenderer createPixelBufferPoolAuxAttribute:(int32_t)maxRetainedBufferCount];
    [TGVideoCameraGLRenderer preallocatePixelBuffersInPool:_bufferPool auxAttributes:_bufferPoolAuxAttributes];
	
	CMFormatDescriptionRef outputFormatDescription = NULL;
	CVPixelBufferRef testPixelBuffer = NULL;
	CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferPoolAuxAttributes, &testPixelBuffer);
	if (!testPixelBuffer)
    {
		success = false;
		goto bail;
	}
	CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, testPixelBuffer, &outputFormatDescription);
	_outputFormatDescription = outputFormatDescription;
	CFRelease( testPixelBuffer );
	
bail:
	if (!success)
		[self deleteBuffers];
	
	if (oldContext != _context)
		[EAGLContext setCurrentContext:oldContext];
	
	return success;
}

- (void)deleteBuffers
{
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return;
	}
    
	if (_offscreenBufferHandle)
    {
		glDeleteFramebuffers(1, &_offscreenBufferHandle);
		_offscreenBufferHandle = 0;
	}
	
    if (_shader)
    {
        [_shader cleanResources];
        _shader = nil;
	}
    
	if (_textureCache)
    {
		CFRelease(_textureCache);
		_textureCache = 0;
	}
    
    if (_prevTextureCache)
    {
        CFRelease(_prevTextureCache);
        _prevTextureCache = 0;
    }
    
	if (_renderTextureCache)
    {
		CFRelease(_renderTextureCache);
		_renderTextureCache = 0;
	}
    
	if (_bufferPool)
    {
		CFRelease(_bufferPool);
		_bufferPool = NULL;
	}
    
	if (_bufferPoolAuxAttributes)
    {
		CFRelease(_bufferPoolAuxAttributes);
		_bufferPoolAuxAttributes = NULL;
	}
    
	if (_outputFormatDescription)
    {
		CFRelease(_outputFormatDescription);
		_outputFormatDescription = NULL;
	}
    
	if (oldContext != _context)
        [EAGLContext setCurrentContext:oldContext];
}

+ (CVPixelBufferPoolRef)createPixelBufferPoolWithWidth:(int32_t)width height:(int32_t)height pixelFormat:(FourCharCode)pixelFormat maxBufferCount:(int32_t) maxBufferCount
{
	CVPixelBufferPoolRef outputPool = NULL;
	
	NSDictionary *sourcePixelBufferOptions = @
    {
        (id)kCVPixelBufferPixelFormatTypeKey : @(pixelFormat),
        (id)kCVPixelBufferWidthKey : @(width),
        (id)kCVPixelBufferHeightKey : @(height),
        (id)kCVPixelFormatOpenGLESCompatibility : @true,
        (id)kCVPixelBufferIOSurfacePropertiesKey : @{ }
    };
	
    NSDictionary *pixelBufferPoolOptions = @{ (id)kCVPixelBufferPoolMinimumBufferCountKey : @(maxBufferCount) };
	CVPixelBufferPoolCreate(kCFAllocatorDefault, (__bridge CFDictionaryRef)pixelBufferPoolOptions, (__bridge CFDictionaryRef)sourcePixelBufferOptions, &outputPool);
	
	return outputPool;
}

+ (CFDictionaryRef)createPixelBufferPoolAuxAttribute:(int32_t)maxBufferCount
{
	return CFBridgingRetain( @{ (id)kCVPixelBufferPoolAllocationThresholdKey : @(maxBufferCount) } );
}

+ (void)preallocatePixelBuffersInPool:(CVPixelBufferPoolRef)pool auxAttributes:(CFDictionaryRef)auxAttributes
{
	NSMutableArray *pixelBuffers = [[NSMutableArray alloc] init];
    
	while (true)
	{
		CVPixelBufferRef pixelBuffer = NULL;
		OSStatus err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer);
		
		if (err == kCVReturnWouldExceedAllocationThreshold)
			break;
		
		[pixelBuffers addObject:CFBridgingRelease(pixelBuffer)];
	}
    
	[pixelBuffers removeAllObjects];
}

@end
