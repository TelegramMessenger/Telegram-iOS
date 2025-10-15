#ifndef Font_hpp
#define Font_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>
#include <vector>

namespace lottie {

class Font {
public:
    Font(
         std::string const &name_,
         std::string const &familyName_,
         std::string const &style_,
         double ascent_
    ) :
    name(name_),
    familyName(familyName_),
    style(style_),
    ascent(ascent_) {
    }
    
    explicit Font(json11::Json::object const &json) noexcept(false) {
        name = getString(json, "fName");
        familyName = getString(json, "fFamily");
        path = getOptionalString(json, "fPath");
        weight = getOptionalString(json, "fWeight");
        fontClass = getOptionalString(json, "fClass");
        style = getString(json, "fStyle");
        ascent = getDouble(json, "ascent");
        origin = getOptionalInt(json, "origin");
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        result.insert(std::make_pair("fName", name));
        result.insert(std::make_pair("fFamily", familyName));
        if (path.has_value()) {
            result.insert(std::make_pair("fPath", path.value()));
        }
        if (weight.has_value()) {
            result.insert(std::make_pair("fWeight", weight.value()));
        }
        if (fontClass.has_value()) {
            result.insert(std::make_pair("fClass", fontClass.value()));
        }
        result.insert(std::make_pair("fStyle", style));
        result.insert(std::make_pair("ascent", ascent));
        if (origin.has_value()) {
            result.insert(std::make_pair("origin", origin.value()));
        }
        
        return result;
    }
    
public:
    std::string name;
    std::string familyName;
    std::optional<std::string> path;
    std::optional<std::string> weight;
    std::optional<std::string> fontClass;
    std::string style;
    double ascent;
    std::optional<int> origin;
};

/// A list of fonts
class FontList {
public:
    FontList(std::vector<Font> const &fonts_) :
    fonts(fonts_) {
    }
    
    explicit FontList(json11::Json::object const &json) noexcept(false) {
        if (const auto fontsData = getOptionalObjectArray(json, "list")) {
            for (const auto &fontData : fontsData.value()) {
                fonts.emplace_back(fontData);
            }
        }
    }
    
    json11::Json::object toJson() const {
        json11::Json::array fontArray;
        
        for (const auto &font : fonts) {
            fontArray.push_back(font.toJson());
        }
        
        json11::Json::object result;
        result.insert(std::make_pair("list", fontArray));
        return result;
    }
    
public:
    std::vector<Font> fonts;
};

}

#endif /* Font_hpp */
