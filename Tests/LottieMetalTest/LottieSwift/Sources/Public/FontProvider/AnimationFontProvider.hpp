#ifndef AnimationFontProvider_hpp
#define AnimationFontProvider_hpp

#include "Lottie/Public/Primitives/CTFont.hpp"

#include <memory>

namespace lottie {

/// Font provider is a protocol that is used to supply fonts to `AnimationView`.
///
class AnimationFontProvider {
public:
    virtual std::shared_ptr<CTFont> fontFor(std::string const &family, double size) = 0;
};

/// Default Font provider.
class DefaultFontProvider: public AnimationFontProvider {
public:
    DefaultFontProvider() {
    }

    virtual std::shared_ptr<CTFont> fontFor(std::string const &family, double size) override {
        //CTFontCreateWithName(family as CFString, size, nil)
        return nullptr;
    }
};

}

#endif /* AnimationFontProvider_hpp */
