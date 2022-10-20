#import "TGPaintBuffers.h"
#import <LegacyComponents/TGPaintUtils.h>

#import "LegacyComponentsInternal.h"

@implementation TGPaintBuffers

+ (instancetype)buffersWithGLContext:(EAGLContext *)context layer:(CAEAGLLayer *)layer
{
    TGPaintBuffers *c = [[TGPaintBuffers alloc] init];
    
    c->_layer = layer;
    layer.opaque = false;
    layer.drawableProperties = @
    {
        kEAGLDrawablePropertyRetainedBacking: @true,
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
    };
    
    c.context = context;
    [EAGLContext setCurrentContext:context];
    
    glGenFramebuffers(1, &c->_framebuffer);
    glGenRenderbuffers(1, &c->_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, c->_framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, c->_renderbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, c->_renderbuffer);
    
    glGenRenderbuffers(1, &c->_stencilBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, c->_stencilBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, c->_stencilBuffer);
    
    TGPaintHasGLError();
    
    return c;
}

- (void)dealloc
{
    [self cleanResources];
}

- (void)cleanResources
{
    [EAGLContext setCurrentContext:_context];
    
    if (_framebuffer != 0)
    {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer != 0)
    {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
    if (_stencilBuffer)
    {
        glDeleteBuffers(1, &_stencilBuffer);
        _stencilBuffer = 0;
    }
    
    TGPaintHasGLError();
}

- (bool)update
{
    [EAGLContext setCurrentContext:_context];
    TGPaintHasGLError();
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _stencilBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, _width, _height);
    
    TGPaintHasGLError();
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        TGLegacyLog(@"Failed to create complete framebuffer %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return false;
    }
    
    return true;
}

- (void)present
{
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

@end
