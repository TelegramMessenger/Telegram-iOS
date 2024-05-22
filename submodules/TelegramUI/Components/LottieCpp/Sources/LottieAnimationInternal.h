#ifndef LottieAnimationInternal_h
#define LottieAnimationInternal_h

#include <LottieCpp/LottieAnimation.h>
#include "Lottie/Private/Model/Animation.hpp"

#include <memory>

@interface LottieAnimation (Internal)

- (std::shared_ptr<lottie::Animation>)animationImpl;

@end

#endif /* LottieAnimationInternal_h */
