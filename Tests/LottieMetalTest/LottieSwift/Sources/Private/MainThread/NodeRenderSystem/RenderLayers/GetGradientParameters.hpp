#ifndef ShapeRenderLayer_hpp
#define ShapeRenderLayer_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/RenderNode.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/NodeOutput.hpp"

namespace lottie {

void getGradientParameters(int numberOfColors, GradientColorSet const &colors, std::vector<Color> &outColors, std::vector<double> &outLocations);

}

#endif /* ShapeRenderLayer_hpp */
