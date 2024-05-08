#ifndef Mask_hpp
#define Mask_hpp

#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Utility/Primitives/BezierPath.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

enum class MaskMode {
    Add,
    Subtract,
    Intersect,
    Lighten,
    Darken,
    Difference,
    None
};

class Mask {
public:
    explicit Mask(json11::Json::object const &json) noexcept(false) :
    opacity(KeyframeGroup<Vector1D>(Vector1D(100.0))),
    shape(KeyframeGroup<BezierPath>(BezierPath())),
    inverted(false),
    expansion(KeyframeGroup<Vector1D>(Vector1D(0.0))) {
        if (const auto modeRawValue = getOptionalString(json, "mode")) {
            if (modeRawValue.value() == "a") {
                _mode = MaskMode::Add;
            } else if (modeRawValue.value() == "s") {
                _mode = MaskMode::Subtract;
            } else if (modeRawValue.value() == "i") {
                _mode = MaskMode::Intersect;
            } else if (modeRawValue.value() == "l") {
                _mode = MaskMode::Lighten;
            } else if (modeRawValue.value() == "d") {
                _mode = MaskMode::Darken;
            } else if (modeRawValue.value() == "f") {
                _mode = MaskMode::Difference;
            } else if (modeRawValue.value() == "n") {
                _mode = MaskMode::None;
            } else {
                throw LottieParsingException();
            }
        }
        
        if (const auto opacityData = getOptionalObject(json, "o")) {
            opacity = KeyframeGroup<Vector1D>(opacityData.value());
        }
        
        shape = KeyframeGroup<BezierPath>(getObject(json, "pt"));
        
        if (const auto invertedData = getOptionalBool(json, "inv")) {
            inverted = invertedData.value();
        }
        
        if (const auto expansionData = getOptionalObject(json, "x")) {
            expansion = KeyframeGroup<Vector1D>(expansionData.value());
        }
        
        name = getOptionalString(json, "nm");
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        if (_mode.has_value()) {
            switch (_mode.value()) {
                case MaskMode::Add:
                    result.insert(std::make_pair("mode", "a"));
                    break;
                case MaskMode::Subtract:
                    result.insert(std::make_pair("mode", "s"));
                    break;
                case MaskMode::Intersect:
                    result.insert(std::make_pair("mode", "i"));
                    break;
                case MaskMode::Lighten:
                    result.insert(std::make_pair("mode", "l"));
                    break;
                case MaskMode::Darken:
                    result.insert(std::make_pair("mode", "d"));
                    break;
                case MaskMode::Difference:
                    result.insert(std::make_pair("mode", "f"));
                    break;
                case MaskMode::None:
                    result.insert(std::make_pair("mode", "n"));
                    break;
            }
        }
        
        if (opacity.has_value()) {
            result.insert(std::make_pair("o", opacity->toJson()));
        }
        
        result.insert(std::make_pair("pt", shape.toJson()));
        
        if (inverted.has_value()) {
            result.insert(std::make_pair("inv", inverted.value()));
        }
        
        if (expansion.has_value()) {
            result.insert(std::make_pair("x", expansion->toJson()));
        }
        
        if (name.has_value()) {
            result.insert(std::make_pair("nm", name.value()));
        }
        
        return result;
    }
    
public:
    MaskMode mode() const {
        if (_mode.has_value()) {
            return _mode.value();
        } else {
            return MaskMode::Add;
        }
    }
    
public:
    std::optional<MaskMode> _mode;
    
    std::optional<KeyframeGroup<Vector1D>> opacity;
    
    KeyframeGroup<BezierPath> shape;
    
    std::optional<bool> inverted;
    
    std::optional<KeyframeGroup<Vector1D>> expansion;
    
    std::optional<std::string> name;
};

}

#endif /* Mask_hpp */
