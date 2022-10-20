#import "TGVideoCameraGLView.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/CAEAGLLayer.h>

#import <LegacyComponents/TGPaintShader.h>

#import "LegacyComponentsInternal.h"

@interface TGVideoCameraGLView ()
{
	EAGLContext *_context;
	CVOpenGLESTextureCacheRef _textureCache;
	GLint _width;
	GLint _height;
	GLuint _framebuffer;
	GLuint _colorbuffer;
	
    TGPaintShader *_shader;
	GLint _frame;
}
@end

@implementation TGVideoCameraGLView

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
    if (self != nil)
	{
		if (iosMajorVersion() >= 8)
			self.contentScaleFactor = [UIScreen mainScreen].nativeScale;
		else
			self.contentScaleFactor = [UIScreen mainScreen].scale;
		
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		eaglLayer.opaque = true;
		eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking : @false, kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8 };

		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if (!_context)
			return nil;
	}
	return self;
}

- (bool)initializeBuffers
{
	bool success = YES;
	
	glDisable(GL_DEPTH_TEST);
	
	glGenFramebuffers(1, &_framebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	
	glGenRenderbuffers(1, &_colorbuffer );
	glBindRenderbuffer(GL_RENDERBUFFER, _colorbuffer);
	
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
	
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
	
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorbuffer);
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
		success = false;
		goto bail;
	}
	
	
	CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
	if (err)
    {
		success = false;
		goto bail;
	}
    
    _shader = [[TGPaintShader alloc] initWithVertexShader:@"Passthrough" fragmentShader:@"Passthrough" attributes:@[ @"inPosition", @"inTexcoord" ] uniforms:@[ @"texture" ]];
    
    _frame =  [_shader uniformForKey:@"texture"];
	
bail:
	if ( ! success ) {
		[self reset];
	}
	return success;
}

- (void)reset
{
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return;
	}
    
	if (_framebuffer)
    {
		glDeleteFramebuffers(1, &_framebuffer);
		_framebuffer = 0;
	}
    
	if (_colorbuffer)
    {
		glDeleteRenderbuffers(1, &_colorbuffer);
		_colorbuffer = 0;
	}
    
	if (_shader != nil)
    {
        [_shader cleanResources];
        _shader = nil;
	}
    
	if (_textureCache)
    {
		CFRelease(_textureCache);
		_textureCache = 0;
	}
    
	if (oldContext != _context)
		[EAGLContext setCurrentContext:oldContext];
}

- (void)dealloc
{
	[self reset];
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
	static const GLfloat squareVertices[] =
    {
		-1.0f, -1.0f, // bottom left
		1.0f, -1.0f, // bottom right
		-1.0f,  1.0f, // top left
		1.0f,  1.0f, // top right
	};
	
	if (pixelBuffer == NULL)
		return;

	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return;
	}
	
	if (_framebuffer == 0)
    {
		bool success = [self initializeBuffers];
		if (!success)
			return;
	}
	
	size_t frameWidth = CVPixelBufferGetWidth(pixelBuffer);
	size_t frameHeight = CVPixelBufferGetHeight(pixelBuffer);
	CVOpenGLESTextureRef texture = NULL;
	CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &texture);
	
	if (!texture || err)
		return;
	
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	glViewport(0, 0, _width, _height);
	
	glUseProgram(_shader.program);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
	glUniform1i(_frame, 0);
	
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	
	glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, squareVertices);
	glEnableVertexAttribArray(0);
	
	CGSize textureSamplingSize;
	CGSize cropScaleAmount = CGSizeMake(self.bounds.size.width / (CGFloat)frameWidth, self.bounds.size.height / (CGFloat)frameHeight);
	if (cropScaleAmount.height > cropScaleAmount.width)
    {
		textureSamplingSize.width = self.bounds.size.width / ( frameWidth * cropScaleAmount.height );
		textureSamplingSize.height = 1.0;
	}
	else
    {
		textureSamplingSize.width = 1.0;
		textureSamplingSize.height = self.bounds.size.height / ( frameHeight * cropScaleAmount.width );
	}
	
	GLfloat passThroughTextureVertices[] =
    {
		(GLfloat)((1.0 - textureSamplingSize.width) / 2.0), (GLfloat)((1.0 + textureSamplingSize.height) / 2.0), // top left
		(GLfloat)((1.0 + textureSamplingSize.width) / 2.0), (GLfloat)((1.0 + textureSamplingSize.height) / 2.0), // top right
		(GLfloat)((1.0 - textureSamplingSize.width) / 2.0), (GLfloat)((1.0 - textureSamplingSize.height) / 2.0), // bottom left
		(GLfloat)((1.0 + textureSamplingSize.width) / 2.0), (GLfloat)((1.0 - textureSamplingSize.height) / 2.0), // bottom right
	};
	
	glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, passThroughTextureVertices );
	glEnableVertexAttribArray(1);
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	glBindRenderbuffer(GL_RENDERBUFFER, _colorbuffer);
	[_context presentRenderbuffer:GL_RENDERBUFFER];
	
	glBindTexture(CVOpenGLESTextureGetTarget(texture), 0);
	glBindTexture(GL_TEXTURE_2D, 0);
	CFRelease(texture);
	
	if (oldContext != _context)
		[EAGLContext setCurrentContext:oldContext];
}

- (void)flushPixelBufferCache
{
	if (_textureCache)
		CVOpenGLESTextureCacheFlush(_textureCache, 0);
}

@end
