#ifndef Glyph_hpp
#define Glyph_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>
#include <vector>

namespace lottie {

class Glyph {
public:
    Glyph(
        std::string const &character_,
        float fontSize_,
        std::string const &fontFamily_,
        std::string const &fontStyle_,
        float width_,
        std::optional<std::vector<std::shared_ptr<ShapeItem>>> shapes_
    ) :
    character(character_),
    fontSize(fontSize_),
    fontFamily(fontFamily_),
    fontStyle(fontStyle_),
    width(width_),
    shapes(shapes_) {
    }
    
    explicit Glyph(lottiejson11::Json::object const &json) noexcept(false) :
    character(""),
    fontSize(0.0),
    fontFamily(""),
    fontStyle(""),
    width(0.0) {
        character = getString(json, "ch");
        fontSize = (float)getDouble(json, "size");
        fontFamily = getString(json, "fFamily");
        fontStyle = getString(json, "style");
        width = (float)getDouble(json, "w");
        
        if (const auto shapeContainer = getOptionalObject(json, "data")) {
            internalHasData = true;
            
            if (const auto shapesData = getOptionalObjectArray(shapeContainer.value(), "shapes")) {
                shapes = std::vector<std::shared_ptr<ShapeItem>>();
                
                for (const auto &shapeData : shapesData.value()) {
                    shapes->push_back(parseShapeItem(shapeData));
                }
            }
        }
    }
    
    lottiejson11::Json::object toJson() const {
        lottiejson11::Json::object result;
        
        result.insert(std::make_pair("ch", character));
        result.insert(std::make_pair("size", fontSize));
        result.insert(std::make_pair("fFamily", fontFamily));
        result.insert(std::make_pair("style", fontStyle));
        result.insert(std::make_pair("w", width));
        
        if (internalHasData || shapes.has_value()) {
            lottiejson11::Json::object shapeContainer;
            
            if (shapes.has_value()) {
                lottiejson11::Json::array shapeArray;
                
                for (const auto &shape : shapes.value()) {
                    lottiejson11::Json::object shapeJson;
                    shape->toJson(shapeJson);
                    shapeArray.push_back(shapeJson);
                }
                
                shapeContainer.insert(std::make_pair("shapes", shapeArray));
            }
            result.insert(std::make_pair("data", shapeContainer));
        }
        
        return result;
    }
    
public:
    /// The character
    std::string character;
    
    /// The font size of the character
    float fontSize;
    
    /// The font family of the character
    std::string fontFamily;
    
    /// The Style of the character
    std::string fontStyle;
    
    /// The Width of the character
    float width;
    
    /// The Shape Data of the Character
    std::optional<std::vector<std::shared_ptr<ShapeItem>>> shapes;
    
    bool internalHasData = false;
};

}

#endif /* Glyph_hpp */
