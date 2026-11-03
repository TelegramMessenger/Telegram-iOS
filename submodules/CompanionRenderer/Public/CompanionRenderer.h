#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, CompanionComponentKind) {
    CompanionComponentModel, CompanionComponentAnimation, CompanionComponentMaterials,
    CompanionComponentItem, CompanionComponentItemMaterials, CompanionComponentScene, CompanionComponentItemAnimation
};
@interface CompanionRenderer : NSObject
- (nullable instancetype)initWithDevice:(id<MTLDevice>)device resourceDirectory:(NSString *)directory error:(NSError **)error;
- (BOOL)setComponentAtURL:(nullable NSURL *)url kind:(CompanionComponentKind)kind socket:(nullable NSString *)socket error:(NSError **)error;
- (BOOL)loadDefault:(NSError **)error;
+ (NSArray<NSDictionary *> *)presets;
- (BOOL)applyPreset:(NSString *)identifier files:(NSDictionary<NSString *, NSURL *> *)files error:(NSError **)error NS_SWIFT_NAME(applyPreset(_:files:));
- (NSArray<NSDictionary *> *)componentRows;
@property(nonatomic, readonly) NSString *customizationNotice;
- (void)orbitX:(float)x y:(float)y;
- (void)returnToInitialOrbit;
- (void)zoomBy:(float)factor;
- (void)resetCamera;
// Encodes into MetalEngine's command buffer. Never commits or waits on the GPU.
- (nullable id<MTLTexture>)encodeFrame:(id<MTLCommandBuffer>)commandBuffer width:(NSUInteger)width height:(NSUInteger)height deltaTime:(float)deltaTime;
@end
NS_ASSUME_NONNULL_END
