#import <Foundation/Foundation.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreImage/CoreImage.h>

typedef struct GPUTextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} GPUTextureOptions;

@interface GPUImageFramebuffer : NSObject

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) GPUTextureOptions textureOptions;
@property (nonatomic, readonly) GLuint texture;
@property (nonatomic, readonly) BOOL missingFramebuffer;

@property (nonatomic, assign) BOOL mark;

// Initialization and teardown
- (id)initWithSize:(CGSize)framebufferSize;
- (id)initWithSize:(CGSize)framebufferSize textureOptions:(GPUTextureOptions)fboTextureOptions onlyTexture:(BOOL)onlyGenerateTexture;
- (id)initWithSize:(CGSize)framebufferSize overriddenTexture:(GLuint)inputTexture;
- (id)initWithSize:(CGSize)framebufferSize overridenFramebuffer:(GLuint)overridenFramebuffer overriddenTexture:(GLuint)inputTexture;

// Usage
- (void)useFramebuffer;
- (void)activateFramebuffer;

// Reference counting
- (void)lock;
- (void)unlock;
- (void)clearAllLocks;
- (void)disableReferenceCounting;
- (void)enableReferenceCounting;

// Image capture
- (CGImageRef)newCGImageFromFramebufferContents;
- (void)newCIImageFromFramebufferContents:(void (^)(CIImage *image, void(^unlock)(void)))completion;
- (void)restoreRenderTarget;

// Raw data bytes
- (void)lockForReading;
- (void)unlockAfterReading;
- (NSUInteger)bytesPerRow;
- (GLubyte *)byteBuffer;

+ (void)setMark:(BOOL)mark;

@end
