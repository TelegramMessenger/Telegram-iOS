#include "LayerModelSerialization.hpp"

#include "Lottie/Private/Model/Layers/PreCompLayerModel.hpp"
#include "Lottie/Private/Model/Layers/SolidLayerModel.hpp"
#include "Lottie/Private/Model/Layers/ImageLayerModel.hpp"
#include "Lottie/Private/Model/Layers/ShapeLayerModel.hpp"
#include "Lottie/Private/Model/Layers/TextLayerModel.hpp"

namespace lottie {

std::shared_ptr<LayerModel> parseLayerModel(json11::Json::object const &json) noexcept(false) {
    LayerType layerType = parseLayerType(json, "ty");
    
    switch (layerType) {
        case LayerType::Precomp:
            return std::make_shared<PreCompLayerModel>(json);
        case LayerType::Solid:
            return std::make_shared<SolidLayerModel>(json);
        case LayerType::Image:
            return std::make_shared<ImageLayerModel>(json);
        case LayerType::Null:
            return std::make_shared<LayerModel>(json);
        case LayerType::Shape:
            try {
                return std::make_shared<ShapeLayerModel>(json);
            } catch(...) {
                throw LottieParsingException();
            }
        case LayerType::Text:
            return std::make_shared<TextLayerModel>(json);
    }
}

}
