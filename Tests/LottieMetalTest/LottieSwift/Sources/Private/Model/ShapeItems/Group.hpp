#ifndef Group_hpp
#define Group_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <vector>
#include <memory>

namespace lottie {

/// An item that define an ellipse shape
class Group: public ShapeItem {
public:
    explicit Group(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json) {
        auto itemsData = getObjectArray(json, "it");
        for (const auto &itemData : itemsData) {
            items.push_back(parseShapeItem(itemData));
        }
        
        numberOfProperties = getOptionalInt(json, "np");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        json11::Json::array itemArray;
        for (const auto &item : items) {
            json11::Json::object itemJson;
            item->toJson(itemJson);
            itemArray.push_back(itemJson);
        }
        
        json.insert(std::make_pair("it", itemArray));
        
        if (numberOfProperties.has_value()) {
            json.insert(std::make_pair("np", numberOfProperties.value()));
        }
    }
    
public:
    /// A list of shape items.
    std::vector<std::shared_ptr<ShapeItem>> items;
    
    std::optional<int> numberOfProperties;
};

}

#endif /* Group_hpp */
