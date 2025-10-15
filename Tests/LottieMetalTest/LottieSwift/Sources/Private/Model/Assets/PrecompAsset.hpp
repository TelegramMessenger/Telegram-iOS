#ifndef PrecompAsset_hpp
#define PrecompAsset_hpp

#include "Lottie/Private/Model/Assets/Asset.hpp"
#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Model/Layers/LayerModelSerialization.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <vector>

namespace lottie {

class PrecompAsset: public Asset {
public:
    PrecompAsset(
        std::string const &id_,
        std::vector<std::shared_ptr<LayerModel>> const &layers_
    ) : Asset(id_),
    layers(layers_) {
    }
    
    explicit PrecompAsset(json11::Json::object const &json) noexcept(false) :
    Asset(json) {
        frameRate = getOptionalDouble(json, "fr");
        
        auto layerDictionaries = getObjectArray(json, "layers");
        for (size_t i = 0; i < layerDictionaries.size(); i++) {
            try {
                auto layer = parseLayerModel(layerDictionaries[i]);
                layers.push_back(layer);
            } catch(...) {
                throw LottieParsingException();
            }
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        Asset::toJson(json);
        
        json11::Json::array layerArray;
        for (const auto &layer : layers) {
            json11::Json::object layerJson;
            layer->toJson(layerJson);
            layerArray.push_back(layerJson);
        }
        json.insert(std::make_pair("layers", layerArray));
        
        if (frameRate.has_value()) {
            json.insert(std::make_pair("fr", frameRate.value()));
        }
    }
    
public:
    /// Layers of the precomp
    std::vector<std::shared_ptr<LayerModel>> layers;
    
    std::optional<double> frameRate;
};

}

#endif /* PrecompAsset_hpp */
