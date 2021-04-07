#import "TGPainting.h"

#import "LegacyComponentsInternal.h"

#import <SSignalKit/SSignalKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "matrix.h"

#import "TGPaintBrush.h"
#import "TGPaintPath.h"
#import "TGPaintRender.h"
#import "TGPaintSlice.h"
#import "TGPaintShader.h"
#import "TGPaintShaderSet.h"
#import "TGPaintTexture.h"
#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPaintUndoManager.h>

@interface TGPainting ()
{
    EAGLContext *_context;
    NSDictionary *_shaders;
    
    NSData *_initialImageData;
    
    GLuint _textureName;
    GLuint _quadVAO;
    GLuint _quadVBO;
    GLfloat _projection[16];
    
    CGRect _activeStrokeBounds;
    
    GLuint _reusableFramebuffer;
    GLuint _paintTextureName;

    TGPaintTexture *_brushTexture;

    TGPaintRenderState *_renderState;
    NSInteger _suppressChangesCounter;
    
    SQueue *_queue;
    
    __weak TGPaintUndoManager *_undoManager;
    NSUInteger _strokeCount;
}
@end

@implementation TGPainting

- (instancetype)initWithSize:(CGSize)size undoManager:(TGPaintUndoManager *)undoManager imageData:(NSData *)imageData
{
    self = [super init];
    if (self != nil)
    {
        _queue = [[SQueue alloc] init];
        _undoManager = undoManager;
        
        _initialImageData = imageData;
        _renderState = [[TGPaintRenderState alloc] init];
    
        if (_initialImageData.length > 0)
            _strokeCount++;
        
        [self setSize:size];
    }
    return self;
}

- (void)dealloc
{
    if (_context == nil)
        return;
    
    [self performSynchronouslyInContext:^{
        [EAGLContext setCurrentContext:_context];
        if (_paintTextureName != 0)
            glDeleteTextures(1, &_paintTextureName);
        
        glDeleteBuffers(1, &_quadVBO);
        glDeleteVertexArraysOES(1, &_quadVAO);
        
        if (_reusableFramebuffer != 0)
            glDeleteFramebuffers(1, &_reusableFramebuffer);
        
        if (_textureName != 0)
            glDeleteTextures(1, &_textureName);
        
        [_brushTexture cleanResources];
        
        TGPaintHasGLError();
        [EAGLContext setCurrentContext:nil];
    }];
}

- (void)setSize:(CGSize)size
{
    _size = size;
    mat4f_LoadOrtho(0, (GLint)size.width, 0, (GLint)size.height, -1.0f, 1.0f, _projection);
}

- (EAGLContext *)context
{
    if (_context == nil)
    {
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (_context != nil && [EAGLContext setCurrentContext:_context])
        {
            glEnable(GL_BLEND);
            glDisable(GL_DITHER);
            glDisable(GL_STENCIL_TEST);
            glDisable(GL_DEPTH_TEST);
        }
        [self _setupShaders];
    }
    
    return _context;
}

- (bool)isEmpty
{
    return (_strokeCount == 0);
}

- (CGRect)bounds
{
    return CGRectMake(0.0f, 0.0f, self.size.width, self.size.height);
}

#pragma mark - 

- (void)beginSuppressingChanges
{
    _suppressChangesCounter++;
}

- (void)endSuppressingChanges
{
    _suppressChangesCounter--;
}

- (bool)isSuppressingChanges
{
    return _suppressChangesCounter > 0;
}

#pragma mark -

- (void)performSynchronouslyInContext:(void (^)(void))block
{
    [_queue dispatch:^
    {
        [EAGLContext setCurrentContext:self.context];
        block();
    } synchronous:true];
}

- (void)performAsynchronouslyInContext:(void (^)(void))block
{
    [_queue dispatch:^
    {
        [EAGLContext setCurrentContext:self.context];
        block();
    }];
}

- (void)paintStroke:(TGPaintPath *)path clearBuffer:(bool)clearBuffer completion:(void (^)(void))completion
{
    [self performAsynchronouslyInContext:^
    {
        _activePath = path;
        
        CGRect bounds = CGRectZero;
        glBindFramebuffer(GL_FRAMEBUFFER, [self _reusableFramebuffer]);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, [self _paintTextureName], 0);
        
        GLuint status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        
        if (status == GL_FRAMEBUFFER_COMPLETE)
        {
            glViewport(0, 0, (GLint)self.size.width, (GLint)self.size.height);
            
            if (clearBuffer)
            {
                glClearColor(0, 0, 0, 0);
                glClear(GL_COLOR_BUFFER_BIT);
            }
            
            [self _setupBrush];
            bounds = [TGPaintRender renderPath:path renderState:_renderState];
        }
        
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        TGPaintHasGLError();
        
        if (self.contentChanged != nil)
            self.contentChanged(bounds);
        
        _activeStrokeBounds = TGPaintUnionRect(_activeStrokeBounds, bounds);
        
        if (completion != nil)
            completion();
    }];
}

- (void)commitStrokeWithColor:(UIColor *)color erase:(bool)erase
{
    [self performAsynchronouslyInContext:^
    {
        [self registerUndoInRect:_activeStrokeBounds];
        
        [self beginSuppressingChanges];
        
        [self updateWithBlock:^
        {
            GLfloat proj[16];
            mat4f_LoadOrtho(0, (GLint)self.size.width, 0, (GLint)self.size.height, -1.0f, 1.0f, proj);
            
            TGPaintShader *shader = erase ? [self shaderForKey:@"compositeWithEraseMask"] : [self shaderForKey:@"compositeWithMask"];
            if (_brush.lightSaber)
                shader = [self shaderForKey:@"compositeWithMaskLight"];
            glUseProgram(shader.program);
            
            glUniformMatrix4fv([shader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, proj);
            glUniform1i([shader uniformForKey:@"texture"], 0);
            glUniform1i([shader uniformForKey:@"mask"], 1);
            if (!erase)
                TGSetupColorUniform([shader uniformForKey:@"color"], color);
            
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, self.textureName);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, self._paintTextureName);
            
            glBlendFunc(GL_ONE, GL_ZERO);
            
            glBindVertexArrayOES([self _quad]);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            
            glBindVertexArrayOES(0);
            
            glBindTexture(GL_TEXTURE_2D, self.textureName);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        } bounds:_activeStrokeBounds];

        [self endSuppressingChanges];
        
        [_renderState reset];
        
        _activeStrokeBounds = CGRectZero;
        
        _activePath = nil;
        
        TGDispatchOnMainThread(^
        {
           if (self.strokeCommited != nil)
               self.strokeCommited();
        });
    }];
}

- (void)setBrush:(TGPaintBrush *)brush
{
    _brush = brush;
    [self performAsynchronouslyInContext:^{
        if (_brushTexture != nil)
        {
//            [_brushTexture cleanResources];
            _brushTexture = nil;
        }
    }];
}

- (void)_setupBrush
{
    TGPaintShader *shader = [self shaderForKey:_brush.lightSaber ? @"brushLight" : @"brush"];
    glUseProgram(shader.program);
    
    glActiveTexture(GL_TEXTURE0);
    
    if (_brushTexture == nil)
        _brushTexture = [[TGPaintTexture alloc] initWithCGImage:_brush.stampRef forceRGB:false];
    
    glBindTexture(GL_TEXTURE_2D, _brushTexture.textureName);
    
    glUniformMatrix4fv([shader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, _projection);
    glUniform1i([shader uniformForKey:@"texture"], 0);
    TGPaintHasGLError();
}

#pragma mark -

- (void)updateWithBlock:(void (^)(void))updateBlock bounds:(CGRect)bounds
{
    glBindFramebuffer(GL_FRAMEBUFFER, [self _reusableFramebuffer]);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.textureName, 0);
    
    GLuint status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status == GL_FRAMEBUFFER_COMPLETE)
    {
        glViewport(0, 0, (GLint)self.size.width, (GLint)self.size.height);
        
        TGPaintHasGLError();
        updateBlock();
        TGPaintHasGLError();
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    if (![self isSuppressingChanges])
    {
        if (self.contentChanged != nil)
            self.contentChanged(bounds);
    }
}

- (void)clear
{
    _strokeCount = 0;
    
    [self performAsynchronouslyInContext:^
    {
        [self updateWithBlock:^
        {
            glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
            glClear(GL_COLOR_BUFFER_BIT);
        } bounds:[self bounds]];
    }];
}

- (dispatch_queue_t)_queue
{
    return _queue._dispatch_queue;
}

#pragma mark - 

- (void)renderWithProjection:(GLfloat *)projection
{
    if (_activePath != nil)
    {
        if (_activePath.action == TGPaintActionErase)
            [self _renderWithProjection:projection mask:[self _paintTextureName] color:nil erase:true];
        else
            [self _renderWithProjection:projection mask:[self _paintTextureName] color:_activePath.color erase:false];
    }
    else
    {
        [self _renderWithProjection:projection];
    }
}

- (void)_renderWithProjection:(GLfloat *)projection mask:(GLint)mask color:(UIColor *)color erase:(bool)erase
{
    TGPaintShader *shader = erase ? [self shaderForKey:@"blitWithEraseMask"] : [self shaderForKey:@"blitWithMask"];
    if (_brush.lightSaber)
        shader = [self shaderForKey:@"blitWithMaskLight"];
    
    glUseProgram(shader.program);
    
    glUniformMatrix4fv([shader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, projection);
    glUniform1i([shader uniformForKey:@"texture"], 0);
    glUniform1i([shader uniformForKey:@"mask"], 1);
    if (!erase)
        TGSetupColorUniform([shader uniformForKey:@"color"], color);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureName);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, mask);
    
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    glBindVertexArrayOES([self _quad]);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindVertexArrayOES(0);
}

- (void)_renderWithProjection:(GLfloat *)projection
{
    TGPaintShader *shader = [self shaderForKey:@"blit"];
    glUseProgram(shader.program);
    
    glUniformMatrix4fv([shader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, projection);
    glUniform1i([shader uniformForKey:@"texture"], 0);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureName);
    
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    glBindVertexArrayOES([self _quad]);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindVertexArrayOES(0);
}

#pragma mark -

- (NSData *)imageDataForRect:(CGRect)rect resultPaintingData:(NSData **)resultPaintingData
{
    [EAGLContext setCurrentContext:self.context];
    
    TGPaintHasGLError();
    
    GLint minX = (GLint) CGRectGetMinX(rect);
    GLint minY = (GLint) CGRectGetMinY(rect);
    GLint width = (GLint) CGRectGetWidth(rect);
    GLint height = (GLint) CGRectGetHeight(rect);
    
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    GLuint colorRenderbuffer;
    glGenRenderbuffers(1, &colorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, width, height);
  
    GLuint textureName;    
    GLenum format = GL_RGBA;
    GLenum type = GL_UNSIGNED_BYTE;
    
    glGenTextures(1, &textureName);
    glBindTexture(GL_TEXTURE_2D, textureName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    glBindTexture(GL_TEXTURE_2D, textureName);
    
    glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, type, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textureName, 0);
    
    GLint status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    if (status != GL_FRAMEBUFFER_COMPLETE)
    {
        TGLegacyLog(@"ERROR: imageAndData: - Incomplete Framebuffer!");
        TGPaintHasGLError();
        return nil;
    }
    
    glViewport(0, 0, (GLint)self.size.width, (GLint)self.size.height);
    
    TGPaintShader *blitShader = [self shaderForKey:@"nonPremultipliedBlit"];
    glUseProgram(blitShader.program);
    
    GLfloat proj[16], effectiveProj[16],final[16];
    mat4f_LoadOrtho(0, (GLint)self.size.width, 0, (GLint)self.size.height, -1.0f, 1.0f, proj);
    
    CGAffineTransform translate = CGAffineTransformMakeTranslation(-minX, -minY);
    mat4f_LoadCGAffineTransform(effectiveProj, translate);
    mat4f_MultiplyMat4f(proj, effectiveProj, final);
    
    glUniformMatrix4fv([blitShader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, final);
    glUniform1i([blitShader uniformForKey:@"texture"], (GLuint)0);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureName);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    glBindVertexArrayOES([self _quad]);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArrayOES(0);
    
    NSUInteger length = width * 4 * height;
    GLubyte *pixels = malloc(sizeof(GLubyte) * length);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    NSData *paintingResult = [NSData dataWithBytes:pixels length:length];
    
    if (resultPaintingData != NULL)
        *resultPaintingData = paintingResult;

    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
    
    status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    if (status != GL_FRAMEBUFFER_COMPLETE)
    {
        TGLegacyLog(@"ERROR: imageAndData: - Incomplete Framebuffer!");
        TGPaintHasGLError();
        return nil;
    }
    
    blitShader = [self shaderForKey:@"blit"];
    glUseProgram(blitShader.program);
        
    glUniformMatrix4fv([blitShader uniformForKey:@"mvpMatrix"], 1, GL_FALSE, final);
    glUniform1i([blitShader uniformForKey:@"texture"], (GLuint)0);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureName);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    glBindVertexArrayOES([self _quad]);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArrayOES(0);
    
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    NSData *result = [NSData dataWithBytes:pixels length:length];
    free(pixels);

    glDeleteFramebuffers(1, &framebuffer);
    glDeleteTextures(1, &textureName);
    glDeleteRenderbuffers(1, &colorRenderbuffer);
    
    TGPaintHasGLError();
    return result;
}

- (UIImage *)imageWithSize:(CGSize)size andData:(NSData *__autoreleasing *)outData
{
    NSData *paintingData = nil;
    NSData *imageData = [self imageDataForRect:self.bounds resultPaintingData:&paintingData];
    UIImage *image = [self imageForData:imageData size:self.size outputSize:size];
    
    if (outData != NULL)
        *outData = paintingData;
    
    return image;
}

- (UIImage *)imageForData:(NSData *)data size:(CGSize)size outputSize:(CGSize)outputSize
{
    size_t width = (size_t)size.width;
    size_t height = (size_t)size.height;
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate((void *)data.bytes, width, height, 8, width * 4, colorSpaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpaceRef);
    
    UIGraphicsBeginImageContext(outputSize);
    [[UIImage imageWithCGImage:imageRef] drawInRect:CGRectMake(0.0f, 0.0f, outputSize.width, outputSize.height)];
    CGImageRelease(imageRef);
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

#pragma mark - 

- (void)registerUndoInRect:(CGRect)rect
{
    rect = CGRectIntersection(rect, self.bounds);
    
    NSData *paintingData = nil;
    [self imageDataForRect:rect resultPaintingData:&paintingData];
    
    TGPaintSlice *slice = [[TGPaintSlice alloc] initWithData:paintingData bounds:rect];
    NSInteger uuid;
    arc4random_buf(&uuid, sizeof(NSInteger));
    [_undoManager registerUndoWithUUID:uuid block:^(TGPainting *painting, __unused TGPhotoEntitiesContainerView *entitiesContainer, __unused NSInteger uuid)
    {
        [painting restoreSlice:slice redo:false];
    }];
    
    _strokeCount++;
}

- (void)restoreSlice:(TGPaintSlice *)slice redo:(bool)redo
{
    [self performAsynchronouslyInContext:^
    {
        if (!redo)
            _strokeCount--;
        
        NSData *data = slice.data;
        
        glBindTexture(GL_TEXTURE_2D, self.textureName);
        glTexSubImage2D(GL_TEXTURE_2D, 0, (GLint)slice.bounds.origin.x, (GLint)slice.bounds.origin.y, (GLint)slice.bounds.size.width, (GLint)slice.bounds.size.height, GL_RGBA, GL_UNSIGNED_BYTE, data.bytes);
        
        if (![self isSuppressingChanges] && self.contentChanged != nil)
            self.contentChanged(slice.bounds);
    }];
}

#pragma mark -

- (GLuint)textureName
{
    if (_textureName == 0)
    {
        _textureName = [self _generateTextureWithPixels:(GLubyte *)_initialImageData.bytes];
        _initialImageData = nil;
    }
    
    return _textureName;
}

- (GLuint)_paintTextureName
{
    if (_paintTextureName == 0)
        _paintTextureName = [self _generateTextureWithPixels:nil];
    
    return _paintTextureName;
}

- (GLuint)_reusableFramebuffer
{
    if (_reusableFramebuffer == 0)
        glGenFramebuffers(1, &_reusableFramebuffer);

    return _reusableFramebuffer;
}

- (GLuint)_quad
{
    if (_quadVAO == 0)
    {
        [EAGLContext setCurrentContext:self.context];
        CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
        
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

- (GLfloat *)_projection
{
    return _projection;
}

- (GLuint)_generateTextureWithPixels:(GLubyte *)pixels
{
    [EAGLContext setCurrentContext:self.context];
    TGPaintHasGLError();
    
    GLuint textureName;
    glGenTextures(1, &textureName);
    glBindTexture(GL_TEXTURE_2D, textureName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    GLuint width = (GLuint)self.size.width;
    GLuint height = (GLuint)self.size.height;
    GLenum format = GL_RGBA;
    GLenum type = GL_UNSIGNED_BYTE;
    NSUInteger bytesPerPixel = 4;
    
    if (pixels == NULL)
    {
        pixels = calloc((size_t) (self.size.width * bytesPerPixel * self.size.height), sizeof(GLubyte));
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, type, pixels);
        free(pixels);
    }
    else
    {
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, type, pixels);
    }
    
    TGPaintHasGLError();
    return textureName;
}

#pragma mark - Shaders

- (void)_setupShaders
{
    if (_shaders != nil)
        return;
    
    _shaders = [TGPaintShaderSet setup];
}

- (TGPaintShader *)shaderForKey:(NSString *)key
{
    return _shaders[key];
}

@end
