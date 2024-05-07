#ifndef LottieRenderTreeInternal_h
#define LottieRenderTreeInternal_h

#include <LottieCpp/LottieRenderTree.h>
#import "RenderNode.hpp"

#include <memory>

@interface LottieRenderNode (Internal)

- (instancetype _Nonnull)initWithRenderNode:(std::shared_ptr<lottie::OutputRenderNode> const &)renderNode __attribute__((objc_direct));

@end

#endif /* LottieRenderTreeInternal_h */
