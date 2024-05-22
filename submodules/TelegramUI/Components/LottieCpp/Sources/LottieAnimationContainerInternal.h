#ifndef LottieAnimationContainerInternal_h
#define LottieAnimationContainerInternal_h

#include "Lottie/Private/MainThread/LayerContainers/MainThreadAnimationLayer.hpp"
#include <LottieCpp/LottieAnimationContainer.h>

@interface LottieAnimationContainer (Internal)

@property (nonatomic, readonly) std::shared_ptr<lottie::MainThreadAnimationLayer> layer;

@end

#endif /* LottieAnimationContainerInternal_h */
