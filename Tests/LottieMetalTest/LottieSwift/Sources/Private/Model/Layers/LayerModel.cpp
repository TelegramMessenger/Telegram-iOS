#include "LayerModel.hpp"

namespace lottie {

LayerType parseLayerType(json11::Json::object const &json, std::string const &key) {
    if (const auto layerTypeValue = getOptionalInt(json, "ty")) {
        switch (layerTypeValue.value()) {
            case 0:
                return LayerType::Precomp;
            case 1:
                return LayerType::Solid;
            case 2:
                return LayerType::Image;
            case 3:
                return LayerType::Null;
            case 4:
                return LayerType::Shape;
            case 5:
                return LayerType::Text;
            default:
                return LayerType::Null;
        }
    } else {
        return LayerType::Null;
    }
}

int serializeLayerType(LayerType value) {
    switch (value) {
        case LayerType::Precomp:
            return 0;
        case LayerType::Solid:
            return 1;
        case LayerType::Image:
            return 2;
        case LayerType::Null:
            return 3;
        case LayerType::Shape:
            return 4;
        case LayerType::Text:
            return 5;
    }
}

}
