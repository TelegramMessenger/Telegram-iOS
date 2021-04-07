#import "TGPaintBrushPreview.h"

#import <LegacyComponents/LegacyComponents.h>

#import <OpenGLES/ES2/glext.h>

#import "matrix.h"

#import "TGPainting.h"
#import "TGPaintBrush.h"
#import "TGPaintPath.h"
#import "TGPaintRender.h"
#import "TGPaintShader.h"
#import "TGPaintShaderSet.h"
#import "TGPaintTexture.h"
#import <LegacyComponents/TGPaintUtils.h>

const NSUInteger TGPaintBrushPreviewSegmentsCount = 100;

@interface TGPaintBrushPreview ()
{
    EAGLContext *_context;
    
    TGPaintBrush *_brush;
    TGPaintShader *_brushShader;
    TGPaintShader *_brushLightShader;
    TGPaintShader *_blitLightShader;
    TGPaintTexture *_brushTexture;
    TGPaintRenderState *_renderState;
    
    GLuint _quadVAO;
    GLuint _quadVBO;
    
    TGPaintPath *_path;
    
    GLubyte *_data;
    CGContextRef _cgContext;
    
    GLuint _framebuffer;
    GLuint _maskTextureName;
    
    GLuint _lightFramebuffer;
    GLuint _lightTextureName;
    
    GLfloat _projection[16];
    GLint _width;
    GLint _height;
    
    GLenum _format;
    GLenum _type;
}
@end

@implementation TGPaintBrushPreview

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        _format = GL_RGBA;
        _type = GL_UNSIGNED_BYTE;
        
        if (_context == nil || ![EAGLContext setCurrentContext:_context])
            return nil;
        
        glEnable(GL_BLEND);
        glDisable(GL_DITHER);
        glDisable(GL_STENCIL_TEST);
        glDisable(GL_DEPTH_TEST);
        
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        
        glGenFramebuffers(1, &_framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        
        glGenFramebuffers(1, &_lightFramebuffer);
        
        NSDictionary *availableShaders = [TGPaintShaderSet availableShaders];

        NSDictionary *shader = availableShaders[@"brush"];
        _brushShader = [[TGPaintShader alloc] initWithVertexShader:shader[@"vertex"] fragmentShader:shader[@"fragment"] attributes:shader[@"attributes"] uniforms:shader[@"uniforms"]];
        
        shader = availableShaders[@"brushLight"];
        _brushLightShader = [[TGPaintShader alloc] initWithVertexShader:shader[@"vertex"] fragmentShader:shader[@"fragment"] attributes:shader[@"attributes"] uniforms:shader[@"uniforms"]];
        
        shader = availableShaders[@"brushLightPreview"];
        _blitLightShader = [[TGPaintShader alloc] initWithVertexShader:shader[@"vertex"] fragmentShader:shader[@"fragment"] attributes:shader[@"attributes"] uniforms:shader[@"uniforms"]];
        
        _renderState = [[TGPaintRenderState alloc] init];
        
        TGPaintHasGLError();
    }
    return self;
}

- (void)dealloc
{
    if (_context == nil)
        return;
    
    [EAGLContext setCurrentContext:_context];
    
    if (_cgContext != NULL)
        CGContextRelease(_cgContext);
    
    _brush = nil;
    
    glDeleteBuffers(1, &_quadVBO);
    glDeleteVertexArraysOES(1, &_quadVAO);
    
    if (_framebuffer != 0)
    {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_maskTextureName != 0)
    {
        glDeleteTextures(1, &_maskTextureName);
        _maskTextureName = 0;
    }
    
    if (_lightFramebuffer != 0)
    {
        glDeleteFramebuffers(1, &_lightFramebuffer);
        _lightFramebuffer = 0;
    }
    
    if (_lightTextureName != 0)
    {
        glDeleteTextures(1, &_lightTextureName);
        _lightTextureName = 0;
    }
    
    [EAGLContext setCurrentContext:nil];
}

- (void)setSize:(CGSize)size
{
    if (_width == size.width && _height == size.height)
        return;
    
    _width = (GLint)size.width;
    _height = (GLint)size.height;
    
    if (_data != NULL)
        free(_data);
    
    _data = malloc(_width * _height * 4);
    
    if (_cgContext != NULL)
        CGContextRelease(_cgContext);
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    _cgContext = CGBitmapContextCreate(_data, _width, _height, 8, _width * 4, colorSpaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    
    CGColorSpaceRelease(colorSpaceRef);
    
    if (_path != nil)
        _path = nil;
    
    [self _generateBrushPath];
    
    GLfloat mProj[16], mScale[16];
    mat4f_LoadOrtho(0, _width, 0, _height, -1.0f, 1.0f, mProj);
    
    CGFloat scale = MIN(2.0f, TGScreenScaling());
    CGAffineTransform tX = CGAffineTransformMakeScale(scale, scale);
    mat4f_LoadCGAffineTransform(mScale, tX);
    
    mat4f_MultiplyMat4f(mProj, mScale, _projection);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    glGenTextures(1, &_maskTextureName);
    glBindTexture(GL_TEXTURE_2D, _maskTextureName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    glBindTexture(GL_TEXTURE_2D, _maskTextureName);
    glTexImage2D(GL_TEXTURE_2D, 0, _format, _width, _height, 0, _format, _type, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _maskTextureName, 0);
    
    
    glBindFramebuffer(GL_FRAMEBUFFER, _lightFramebuffer);
    
    glGenTextures(1, &_lightTextureName);
    glBindTexture(GL_TEXTURE_2D, _lightTextureName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    glBindTexture(GL_TEXTURE_2D, _lightTextureName);
    glTexImage2D(GL_TEXTURE_2D, 0, _format, _width, _height, 0, _format, _type, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _lightTextureName, 0);
    
    TGPaintHasGLError();
}

- (void)_generateBrushPath
{
    if (_path != nil)
        return;

    CGFloat scale = MIN(2.0f, TGScreenScaling());

    CGPoint start = CGPointMake(15.0f, _height / (2.0f * scale));
    CGFloat width = (_width / scale) - 2.0f * 15.0f;
    CGFloat amplitude = 6.0f;
    
    NSMutableArray *points = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < TGPaintBrushPreviewSegmentsCount; i++)
    {
        CGFloat fraction = (CGFloat)i / (TGPaintBrushPreviewSegmentsCount - 1);
        CGPoint pt = CGPointMake(start.x + width * fraction, start.y + sin(-fraction * 2 * M_PI) * amplitude);

        TGPaintPoint *point = [TGPaintPoint pointWithX:pt.x y:pt.y z:fraction];
        [points addObject:point];
        
        if (i == 0 || i == TGPaintBrushPreviewSegmentsCount - 1)
            point.edge = true;
    }

    _path = [[TGPaintPath alloc] initWithPoints:points];
    _path.baseWeight = 12.0f;
    _path.color = [UIColor redColor];
}

- (void)_setupBrush
{
    TGPaintShader *shader = _brush.lightSaber ? _brushLightShader : _brushShader;
    glUseProgram(shader.program);
    glActiveTexture(GL_TEXTURE0);
    
    if (_brushTexture == nil)
        _brushTexture = [[TGPaintTexture alloc] initWithCGImage:_brush.previewStampRef forceRGB:false];
    
    glBindTexture(GL_TEXTURE_2D, _brushTexture.textureName);
    
    glUniform1i([shader uniformForKey:@"texture"], 0);
    glUniformMatrix4fv([shader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, _projection);
}

- (void)_cleanBrushResources
{
    if (_brushTexture == nil)
        return;
    
    [EAGLContext setCurrentContext:_context];
    [_brushTexture cleanResources];
    _brushTexture = nil;
}

- (UIImage *)imageForBrush:(TGPaintBrush *)brush size:(CGSize)size
{
    if (![brush isEqual:_brush])
        [self _cleanBrushResources];
    
    _brush = brush;
    
    CGFloat scale = MIN(2.0f, TGScreenScaling());
    size = TGPaintMultiplySizeScalar(size, scale);
    
    [EAGLContext setCurrentContext:_context];
    [self setSize:size];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _width, _height);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    TGPaintHasGLError();
    
    [self _setupBrush];
    [_renderState reset];
    _path.remainder = 0.0f;
    _path.pressureRemainder = 0.0f;
    _path.brush = brush;
    
    [TGPaintRender renderPath:_path renderState:_renderState];
        
    if (_brush.lightSaber)
    {
        glBindFramebuffer(GL_FRAMEBUFFER, _lightFramebuffer);
        glViewport(0, 0, _width, _height);
        
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        TGPaintShader *shader = _blitLightShader;
        glUseProgram(shader.program);
        
        glUniformMatrix4fv([shader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, _projection);
        glUniform1i([shader uniformForKey:@"mask"], 0);
        TGSetupColorUniform([shader uniformForKey:@"color"], [UIColor blackColor]);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _maskTextureName);
        
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        
        glBindVertexArrayOES([self _quad]);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        glBindVertexArrayOES(0);
    }
    
    glReadPixels(0, 0, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, _data);
    CGImageRef imageRef = CGBitmapContextCreateImage(_cgContext);
    UIImage *result = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(imageRef);
    
    return result;
}

- (GLuint)_quad
{
    if (_quadVAO == 0)
    {
        [EAGLContext setCurrentContext:_context];
        CGFloat scale = MIN(2.0f, TGScreenScaling());
        CGRect rect = CGRectMake(0, 0, _width / scale, _height / scale);
        
        CGPoint corners[4];
        corners[0] = rect.origin;
        corners[1] = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
        corners[2] = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
        corners[3] = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
        
        const GLfloat vertices[] =
        {
            (GLfloat)corners[0].x, (GLfloat)corners[0].y, 0.0, 0.0,
            (GLfloat)corners[1].x, (GLfloat)corners[1].y, 1.0, 0.0,
            (GLfloat)corners[3].x, (GLfloat)corners[3].y, 0.0, 1.0,
            (GLfloat)corners[2].x, (GLfloat)corners[2].y, 1.0, 1.0,
        };
        
        glGenVertexArraysOES(1, &_quadVAO);
        glBindVertexArrayOES(_quadVAO);
        
        glGenBuffers(1, &_quadVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _quadVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 16, vertices, GL_STATIC_DRAW);
        
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 4, (void*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 4, (void*)8);
        glEnableVertexAttribArray(1);
        
        glBindBuffer(GL_ARRAY_BUFFER,0);
        glBindVertexArrayOES(0);
    }
    
    return _quadVAO;
}

@end
