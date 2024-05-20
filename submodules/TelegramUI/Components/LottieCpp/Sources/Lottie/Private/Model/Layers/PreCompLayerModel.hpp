#ifndef PreCompLayerModel_hpp
#define PreCompLayerModel_hpp

#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include <LottieCpp/Vectors.h>
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <optional>

namespace lottie {

/// A layer that holds another animation composition.
class PreCompLayerModel: public LayerModel {
public:
    PreCompLayerModel(lottiejson11::Json::object const &json) :
    LayerModel(json) {
        referenceID = getString(json, "refId");
        if (const auto timeRemappingData = getOptionalObject(json, "tm")) {
            timeRemapping = KeyframeGroup<Vector1D>(timeRemappingData.value());
        }
        width = (float)getDouble(json, "w");
        height = (float)getDouble(json, "h");
    }
    
    virtual ~PreCompLayerModel() = default;
    
    virtual void toJson(lottiejson11::Json::object &json) const override {
        LayerModel::toJson(json);
        
        json.insert(std::make_pair("refId", referenceID));
        
        if (timeRemapping.has_value()) {
            json.insert(std::make_pair("tm", timeRemapping->toJson()));
        }
        
        json.insert(std::make_pair("w", width));
        json.insert(std::make_pair("h", height));
    }
    
public:
    /// The reference ID of the precomp.
    std::string referenceID;
    
    /// A value that remaps time over time.
    std::optional<KeyframeGroup<Vector1D>> timeRemapping;
    
    /// Precomp Width
    float width;
    
    /// Precomp Height
    float height;
};

}

#endif /* PreCompLayerModel_hpp */
