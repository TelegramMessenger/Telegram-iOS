#ifndef SolidLayerModel_hpp
#define SolidLayerModel_hpp

#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// A layer that holds a solid color.
class SolidLayerModel: public LayerModel {
public:
    explicit SolidLayerModel(lottiejson11::Json::object const &json) noexcept(false) :
    LayerModel(json) {
        colorHex = getString(json, "sc");
        width = (float)getDouble(json, "sw");
        height = (float)getDouble(json, "sh");
    }
    
    virtual ~SolidLayerModel() = default;
    
    virtual void toJson(lottiejson11::Json::object &json) const override {
        LayerModel::toJson(json);
        
        json.insert(std::make_pair("sc", colorHex));
        json.insert(std::make_pair("sw", width));
        json.insert(std::make_pair("sh", height));
    }
    
public:
    /// The color of the solid in Hex // Change to value provider.
    std::string colorHex;
    
    /// The Width of the color layer
    float width;
    
    /// The height of the color layer
    float height;
};

}

#endif /* SolidLayerModel_hpp */
