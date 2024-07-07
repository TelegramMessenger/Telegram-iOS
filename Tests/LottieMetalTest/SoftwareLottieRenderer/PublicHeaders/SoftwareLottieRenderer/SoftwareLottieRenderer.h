#ifndef SoftwareLottieRenderer_h
#define SoftwareLottieRenderer_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

CGRect getPathNativeBoundingBox(CGPathRef _Nonnull path);

@interface SoftwareLottieRenderer : NSObject

@property (nonatomic, readonly) NSInteger frameCount;
@property (nonatomic, readonly) NSInteger framesPerSecond;
@property (nonatomic, readonly) CGSize size;

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data;

- (void)setFrame:(CGFloat)index;
- (UIImage * _Nullable)renderForSize:(CGSize)size useReferenceRendering:(bool)useReferenceRendering canUseMoreMemory:(bool)canUseMoreMemory skipImageGeneration:(bool)skipImageGeneration;

@end

#ifdef __cplusplus
}
#endif

#endif /* QOILoader_h */
