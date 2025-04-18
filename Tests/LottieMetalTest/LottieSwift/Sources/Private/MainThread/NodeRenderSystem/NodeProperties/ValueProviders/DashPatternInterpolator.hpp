#ifndef DashPatternInterpolator_hpp
#define DashPatternInterpolator_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/KeyframeInterpolator.hpp"
#include "Lottie/Public/Primitives/DashPattern.hpp"

namespace lottie {

/// A value provider that produces an array of values from an array of Keyframe Interpolators
class DashPatternInterpolator: public ValueProvider<DashPattern>, public std::enable_shared_from_this<DashPatternInterpolator> {
public:
    /// Initialize with an array of array of keyframes.
    DashPatternInterpolator(std::vector<std::vector<Keyframe<Vector1D>>> const &keyframeGroups) {
        for (const auto &keyframeGroup : keyframeGroups) {
            _keyframeInterpolators.push_back(std::make_shared<KeyframeInterpolator<Vector1D>>(keyframeGroup));
        }
    }
    
    virtual AnyValue::Type valueType() const override {
        return AnyValueType<DashPattern>::type();
    }
    
    virtual DashPattern value(AnimationFrameTime frame) override {
        std::vector<double> values;
        for (const auto &interpolator : _keyframeInterpolators) {
            values.push_back(interpolator->value(frame).value);
        }
        return DashPattern(std::move(values));
    }
    
    virtual bool hasUpdate(double frame) const override {
        for (const auto &interpolator : _keyframeInterpolators) {
            if (interpolator->hasUpdate(frame)) {
                return true;
            }
        }
        return false;
    }
    
private:
    std::vector<std::shared_ptr<KeyframeInterpolator<Vector1D>>> _keyframeInterpolators;
};

}

#endif /* DashPatternInterpolator_hpp */
