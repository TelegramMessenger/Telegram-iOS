#ifndef SoftwareLottieRenderer_h
#define SoftwareLottieRenderer_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <LottieCpp/LottieCpp.h>

#ifdef __cplusplus
extern "C" {
#endif

CGRect getPathNativeBoundingBox(CGPathRef _Nonnull path);

@interface SoftwareLottieRenderer : NSObject

- (instancetype _Nonnull)initWithAnimationContainer:(LottieAnimationContainer * _Nonnull)animationContainer;

- (UIImage * _Nullable)renderForSize:(CGSize)size useReferenceRendering:(bool)useReferenceRendering;

@end

#ifdef __cplusplus
}
#endif

#endif /* QOILoader_h */
