#ifndef ImageLayerModel_hpp
#define ImageLayerModel_hpp

#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// A layer that holds an image.
class ImageLayerModel: public LayerModel {
public:
    explicit ImageLayerModel(json11::Json::object const &json) noexcept(false) :
    LayerModel(json) {
        referenceID = getString(json, "refId");
        
        _sc = getOptionalString(json, "sc");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        LayerModel::toJson(json);
        
        json.insert(std::make_pair("refId", referenceID));
        
        if (_sc.has_value()) {
            json.insert(std::make_pair("sc", _sc.value()));
        }
    }
    
public:
    /// The reference ID of the image.
    std::string referenceID;
    
    std::optional<std::string> _sc;
};

}

#endif /* ImageLayerModel_hpp */
