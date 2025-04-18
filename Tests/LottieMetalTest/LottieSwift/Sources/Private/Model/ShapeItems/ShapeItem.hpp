#ifndef ShapeItem_hpp
#define ShapeItem_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>

namespace lottie {

enum class ShapeType {
    Ellipse,
    Fill,
    GradientFill,
    Group,
    GradientStroke,
    Merge,
    Rectangle,
    Repeater,
    Shape,
    Star,
    Stroke,
    Trim,
    Transform,
    RoundedRectangle
};

/// An item belonging to a Shape Layer
class ShapeItem {
public:
    ShapeItem(json11::Json const &jsonAny) noexcept(false) :
    type(ShapeType::Ellipse) {
        if (!jsonAny.is_object()) {
            throw LottieParsingException();
        }
        
        json11::Json::object const &json = jsonAny.object_items();
        
        name = getOptionalString(json, "nm");
        matchName = getOptionalString(json, "mn");
        expressionIndex = getOptionalInt(json, "ix");
        cix = getOptionalInt(json, "cix");
        
        index = getOptionalInt(json, "ind");
        blendMode = getOptionalInt(json, "bm");
        
        auto typeRawValue = getString(json, "ty");
        if (typeRawValue == "el") {
            type = ShapeType::Ellipse;
        } else if (typeRawValue == "fl") {
            type = ShapeType::Fill;
        } else if (typeRawValue == "gf") {
            type = ShapeType::GradientFill;
        } else if (typeRawValue == "gr") {
            type = ShapeType::Group;
        } else if (typeRawValue == "gs") {
            type = ShapeType::GradientStroke;
        } else if (typeRawValue == "mm") {
            type = ShapeType::Merge;
        } else if (typeRawValue == "rc") {
            type = ShapeType::Rectangle;
        } else if (typeRawValue == "rp") {
            type = ShapeType::Repeater;
        } else if (typeRawValue == "sh") {
            type = ShapeType::Shape;
        } else if (typeRawValue == "sr") {
            type = ShapeType::Star;
        } else if (typeRawValue == "st") {
            type = ShapeType::Stroke;
        } else if (typeRawValue == "tm") {
            type = ShapeType::Trim;
        } else if (typeRawValue == "tr") {
            type = ShapeType::Transform;
        } else if (typeRawValue == "rd") {
            type = ShapeType::RoundedRectangle;
        } else {
            throw LottieParsingException();
        }
        
        _hidden = getOptionalBool(json, "hd");
        
        layerClass = getOptionalString(json, "cl");
    }
    
    ShapeItem(
      std::optional<std::string> name_,
      std::optional<std::string> matchName_,
      std::optional<int> expressionIndex_,
      std::optional<int> cix_,
      ShapeType type_,
      std::optional<bool> _hidden_,
      std::optional<int> index_,
      std::optional<int> blendMode_,
      std::optional<std::string> layerClass_
    ) :
    name(name_),
    matchName(matchName_),
    expressionIndex(expressionIndex_),
    cix(cix_),
    type(type_),
    _hidden(_hidden_),
    index(index_),
    blendMode(blendMode_),
    layerClass(layerClass_) {
    }
    
    ShapeItem(const ShapeItem&) = delete;
    ShapeItem& operator=(ShapeItem&) = delete;
    
    virtual void toJson(json11::Json::object &json) const {
        if (name.has_value()) {
            json.insert(std::make_pair("nm", name.value()));
        }
        if (matchName.has_value()) {
            json.insert(std::make_pair("mn", matchName.value()));
        }
        if (expressionIndex.has_value()) {
            json.insert(std::make_pair("ix", expressionIndex.value()));
        }
        if (cix.has_value()) {
            json.insert(std::make_pair("cix", cix.value()));
        }
        
        if (index.has_value()) {
            json.insert(std::make_pair("ind", index.value()));
        }
        if (blendMode.has_value()) {
            json.insert(std::make_pair("bm", blendMode.value()));
        }
        
        switch (type) {
            case ShapeType::Ellipse:
                json.insert(std::make_pair("ty", "el"));
                break;
            case ShapeType::Fill:
                json.insert(std::make_pair("ty", "fl"));
                break;
            case ShapeType::GradientFill:
                json.insert(std::make_pair("ty", "gf"));
                break;
            case ShapeType::Group:
                json.insert(std::make_pair("ty", "gr"));
                break;
            case ShapeType::GradientStroke:
                json.insert(std::make_pair("ty", "gs"));
                break;
            case ShapeType::Merge:
                json.insert(std::make_pair("ty", "mm"));
                break;
            case ShapeType::Rectangle:
                json.insert(std::make_pair("ty", "rc"));
                break;
            case ShapeType::RoundedRectangle:
                json.insert(std::make_pair("ty", "rd"));
                break;
            case ShapeType::Repeater:
                json.insert(std::make_pair("ty", "rp"));
                break;
            case ShapeType::Shape:
                json.insert(std::make_pair("ty", "sh"));
                break;
            case ShapeType::Star:
                json.insert(std::make_pair("ty", "sr"));
                break;
            case ShapeType::Stroke:
                json.insert(std::make_pair("ty", "st"));
                break;
            case ShapeType::Trim:
                json.insert(std::make_pair("ty", "tm"));
                break;
            case ShapeType::Transform:
                json.insert(std::make_pair("ty", "tr"));
                break;
        }
        
        if (_hidden.has_value()) {
            json.insert(std::make_pair("hd", _hidden.value()));
        }
        
        if (layerClass.has_value()) {
            json.insert(std::make_pair("cl", layerClass.value()));
        }
    }
    
    bool hidden() const {
        if (_hidden.has_value()) {
            return _hidden.value();
        } else {
            return false;
        }
    }
    
public:
    std::optional<std::string> name;
    std::optional<std::string> matchName;
    std::optional<int> expressionIndex;
    std::optional<int> cix;
    ShapeType type;
    std::optional<bool> _hidden;
    std::optional<int> index;
    std::optional<int> blendMode;
    
    std::optional<std::string> layerClass;
};

std::shared_ptr<ShapeItem> parseShapeItem(json11::Json::object const &json) noexcept(false);

}

#endif /* ShapeItem_hpp */
