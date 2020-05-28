#import "GPUImageContext.h"
#import "GPUImageFramebuffer.h"

#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>

void runOnMainQueueWithoutDeadlocking(void (^block)(void));
void runSynchronouslyOnVideoProcessingQueue(void (^block)(void));
void runAsynchronouslyOnVideoProcessingQueue(void (^block)(void));
void runSynchronouslyOnContextQueue(GPUImageContext *context, void (^block)(void));
void runAsynchronouslyOnContextQueue(GPUImageContext *context, void (^block)(void));
void reportAvailableMemoryForGPUImage(NSString *tag);

@interface GPUImageOutput : NSObject
{
    GPUImageFramebuffer *outputFramebuffer;
    
    NSMutableArray *targets, *targetTextureIndices;
    
    CGSize inputTextureSize, cachedMaximumOutputSize, forcedMaximumSize;
    
    BOOL overrideInputSize;
    
    BOOL allTargetsWantMonochromeData;
    BOOL usingNextFrameForImageCapture;
}

@property(readwrite, nonatomic) BOOL shouldSmoothlyScaleOutput;
@property(readwrite, nonatomic) BOOL shouldIgnoreUpdatesToThisTarget;
@property(readwrite, nonatomic, unsafe_unretained) id<GPUImageInput> targetToIgnoreForUpdates;
@property(nonatomic, copy) void(^frameProcessingCompletionBlock)(GPUImageOutput*, CMTime);
@property(nonatomic) BOOL enabled;
@property(readwrite, nonatomic) GPUTextureOptions outputTextureOptions;

- (void)setInputFramebufferForTarget:(id<GPUImageInput>)target atIndex:(NSInteger)inputTextureIndex;
- (GPUImageFramebuffer *)framebufferForOutput;
- (void)removeOutputFramebuffer;
- (void)notifyTargetsAboutNewOutputTexture;

- (CGSize)inputTextureSize;

/** Returns an array of the current targets.
 */
- (NSArray*)targets;

/** Adds a target to receive notifications when new frames are available.
 
 The target will be asked for its next available texture.
 
 See [GPUImageInput newFrameReadyAtTime:]
 
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget;

/** Adds a target to receive notifications when new frames are available.
 
 See [GPUImageInput newFrameReadyAtTime:]
 
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;

/** Removes a target. The target will no longer receive notifications when new frames are available.
 
 @param targetToRemove Target to be removed
 */
- (void)removeTarget:(id<GPUImageInput>)targetToRemove;

/** Removes all targets.
 */
- (void)removeAllTargets;

/// @name Manage the output texture

- (void)forceProcessingAtSize:(CGSize)frameSize;
- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize;

/// @name Still image processing

- (void)useNextFrameForImageCapture;
- (CGImageRef)newCGImageFromCurrentlyProcessedOutput;
- (void)newCIImageFromCurrentlyProcessedOutput:(void (^)(CIImage *image, void(^unlock)(void)))completion;
- (void)commitImageCapture;

- (UIImage *)imageFromCurrentFramebuffer;
- (UIImage *)imageFromCurrentFramebufferWithOrientation:(UIImageOrientation)imageOrientation;

- (BOOL)providesMonochromeOutput;

@end
