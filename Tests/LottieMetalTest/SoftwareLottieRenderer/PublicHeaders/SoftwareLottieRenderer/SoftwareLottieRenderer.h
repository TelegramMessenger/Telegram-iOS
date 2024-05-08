#ifndef SoftwareLottieRenderer_h
#define SoftwareLottieRenderer_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <LottieCpp/LottieCpp.h>

#ifdef __cplusplus
extern "C" {
#endif

CGRect getPathNativeBoundingBox(CGPathRef _Nonnull path);
UIImage * _Nullable renderLottieAnimationContainer(LottieAnimationContainer * _Nonnull animationContainer, CGSize size, bool useReferenceRendering);

#ifdef __cplusplus
}
#endif

#endif /* QOILoader_h */
