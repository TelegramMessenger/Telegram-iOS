#ifndef StrokeNode_hpp
#define StrokeNode_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/NodePropertyMap.hpp"
#include "Lottie/Private/Model/ShapeItems/Stroke.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/NodeProperty.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/KeyframeInterpolator.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/SingleValueProvider.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/AnimatorNode.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/RenderNode.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/DashPatternInterpolator.hpp"

namespace lottie {

class StrokeShapeDashConfiguration {
public:
    StrokeShapeDashConfiguration(std::vector<DashElement> const &elements) {
        /// Converts the `[DashElement]` data model into `lineDashPattern` and `lineDashPhase`
        /// representations usable in a `CAShapeLayer`
        for (const auto &dash : elements) {
            if (dash.type == DashElementType::Offset) {
                dashPhase = dash.value.keyframes;
            } else {
                dashPatterns.push_back(dash.value.keyframes);
            }
        }
    }
    
public:
    std::vector<std::vector<Keyframe<Vector1D>>> dashPatterns;
    std::vector<Keyframe<Vector1D>> dashPhase;
};

}

#endif /* StrokeNode_hpp */
