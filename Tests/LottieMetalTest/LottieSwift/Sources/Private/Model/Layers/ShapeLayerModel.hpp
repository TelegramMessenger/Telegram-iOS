#ifndef ShapeLayerModel_hpp
#define ShapeLayerModel_hpp

#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <vector>

namespace lottie {

/// A layer that holds vector shape objects.
class ShapeLayerModel: public LayerModel {
public:
    ShapeLayerModel(json11::Json::object const &json) noexcept(false) :
    LayerModel(json) {
        auto shapeItemsData = getObjectArray(json, "shapes");
        for (const auto &shapeItemData : shapeItemsData) {
            items.push_back(parseShapeItem(shapeItemData));
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        LayerModel::toJson(json);
        
        json11::Json::array shapeItemArray;
        for (const auto &item : items) {
            json11::Json::object itemJson;
            item->toJson(itemJson);
            shapeItemArray.push_back(itemJson);
        }
        
        json.insert(std::make_pair("shapes", shapeItemArray));
    }
    
public:
    /// A list of shape items.
    std::vector<std::shared_ptr<ShapeItem>> items;
};

}

#endif /* ShapeLayerModel_hpp */
