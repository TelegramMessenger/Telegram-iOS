#import "GPUImageFilter.h"

extern NSString *const kGPUImageTwoInputTextureVertexShaderString;

@interface GPUImageTwoInputFilter : GPUImageFilter
{
    GPUImageFramebuffer *secondInputFramebuffer;

    GLint filterSecondTextureCoordinateAttribute;
    GLint filterInputTextureUniform2;
    GPUImageRotationMode inputRotation2;
    CMTime firstFrameTime, secondFrameTime;
    
    BOOL hasSetFirstTexture, hasReceivedFirstFrame, hasReceivedSecondFrame, firstFrameWasVideo, secondFrameWasVideo;
    BOOL firstFrameCheckDisabled, secondFrameCheckDisabled;
}

@property (nonatomic, assign) bool rotateOnlyFirstTexture;

- (void)disableFirstFrameCheck;
- (void)disableSecondFrameCheck;

@end
