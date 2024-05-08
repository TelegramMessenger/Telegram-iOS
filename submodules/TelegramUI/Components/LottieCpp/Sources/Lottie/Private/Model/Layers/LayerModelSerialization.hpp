#ifndef LayerModelSerialization_hpp
#define LayerModelSerialization_hpp

#include <LottieCpp/lottiejson11.hpp>
#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Private/Model/Layers/LayerModel.hpp"

namespace lottie {

std::shared_ptr<LayerModel> parseLayerModel(lottiejson11::Json::object const &json) noexcept(false);

}

#endif /* LayerModelSerialization_hpp */
