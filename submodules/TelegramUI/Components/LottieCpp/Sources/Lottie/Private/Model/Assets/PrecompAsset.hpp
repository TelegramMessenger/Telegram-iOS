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
    
    virtual ~PrecompAsset() = default;
    
    explicit PrecompAsset(lottiejson11::Json::object const &json) noexcept(false) :
    Asset(json) {
        if (const auto frameRateValue = getOptionalDouble(json, "fr")) {
            frameRate = (float)frameRateValue.value();
        }
        
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
    
    virtual void toJson(lottiejson11::Json::object &json) const override {
        Asset::toJson(json);
        
        lottiejson11::Json::array layerArray;
        for (const auto &layer : layers) {
            lottiejson11::Json::object layerJson;
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
    
    std::optional<float> frameRate;
};

}

#endif /* PrecompAsset_hpp */
