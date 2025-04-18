#ifndef PreCompLayerModel_hpp
#define PreCompLayerModel_hpp

#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <optional>

namespace lottie {

/// A layer that holds another animation composition.
class PreCompLayerModel: public LayerModel {
public:
    PreCompLayerModel(json11::Json::object const &json) :
    LayerModel(json) {
        referenceID = getString(json, "refId");
        if (const auto timeRemappingData = getOptionalObject(json, "tm")) {
            timeRemapping = KeyframeGroup<Vector1D>(timeRemappingData.value());
        }
        width = getDouble(json, "w");
        height = getDouble(json, "h");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
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
    double width;
    
    /// Precomp Height
    double height;
};

}

#endif /* PreCompLayerModel_hpp */
