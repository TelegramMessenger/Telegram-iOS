#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <QuartzCore/QuartzCore.h>

@interface TGPaintBuffers : NSObject

@property (nonatomic, weak) EAGLContext *context;
@property (nonatomic, readonly) CAEAGLLayer *layer;
@property (nonatomic, readonly) GLuint renderbuffer;
@property (nonatomic, readonly) GLuint framebuffer;
@property (nonatomic, readonly) GLuint stencilBuffer;
@property (nonatomic, readonly) GLint width;
@property (nonatomic, readonly) GLint height;

- (bool)update;
- (void)present;

+ (instancetype)buffersWithGLContext:(EAGLContext *)context layer:(CAEAGLLayer *)layer;

@end
