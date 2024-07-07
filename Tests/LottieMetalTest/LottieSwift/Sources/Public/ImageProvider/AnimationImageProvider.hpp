#ifndef AnimationImageProvider_hpp
#define AnimationImageProvider_hpp

#include "Lottie/Public/Primitives/CALayer.hpp"
#include "Lottie/Private/Model/Assets/ImageAsset.hpp"

namespace lottie {

class AnimationImageProvider {
public:
    virtual std::shared_ptr<CGImage> imageForAsset(ImageAsset const &imageAsset) = 0;
};

}

#endif /* AnimationImageProvider_hpp */
