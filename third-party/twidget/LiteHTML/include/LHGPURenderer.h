#include <TargetConditionals.h>
#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#else
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#endif
#import <Metal/Metal.h>

@class LHDisplayList;

NS_ASSUME_NONNULL_BEGIN

@interface LHGPURenderer : NSObject

- (nullable instancetype)initWithDevice:(nullable id<MTLDevice>)device;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly) id<MTLDevice> device;
@property (readonly) id<MTLCommandQueue> queue;

- (BOOL)encodeDisplayList:(LHDisplayList *)list tiles:(NSArray<NSValue *> *)tiles scale:(CGFloat)scale targets:(NSArray<id<MTLTexture>> *)targets commandBuffer:(id<MTLCommandBuffer>)commandBuffer NS_SWIFT_NAME(encode(_:tiles:scale:targets:commandBuffer:));
- (void)endFrame;

@property (readonly) NSUInteger textureBytes;
@property (readonly) NSUInteger textureCount;
@property (readonly) NSUInteger capturedInLastFrame;
@property (readonly) NSUInteger rasterizedGlyphs;

@end

NS_ASSUME_NONNULL_END
