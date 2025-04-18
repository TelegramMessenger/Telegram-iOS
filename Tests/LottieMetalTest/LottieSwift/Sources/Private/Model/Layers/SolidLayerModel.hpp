#ifndef SolidLayerModel_hpp
#define SolidLayerModel_hpp

#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// A layer that holds a solid color.
class SolidLayerModel: public LayerModel {
public:
    explicit SolidLayerModel(json11::Json::object const &json) noexcept(false) :
    LayerModel(json) {
        colorHex = getString(json, "sc");
        width = getDouble(json, "sw");
        height = getDouble(json, "sh");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        LayerModel::toJson(json);
        
        json.insert(std::make_pair("sc", colorHex));
        json.insert(std::make_pair("sw", width));
        json.insert(std::make_pair("sh", height));
    }
    
public:
    /// The color of the solid in Hex // Change to value provider.
    std::string colorHex;
    
    /// The Width of the color layer
    double width;
    
    /// The height of the color layer
    double height;
};

}

#endif /* SolidLayerModel_hpp */
