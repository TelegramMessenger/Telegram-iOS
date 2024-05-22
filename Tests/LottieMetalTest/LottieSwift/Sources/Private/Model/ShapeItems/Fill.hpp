#ifndef Fill_hpp
#define Fill_hpp

#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Public/Primitives/Color.hpp"
#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

enum class FillRule: int {
    None = 0,
    NonZeroWinding = 1,
    EvenOdd = 2
};

class Fill: public ShapeItem {
public:
    explicit Fill(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    opacity(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    color(KeyframeGroup<Color>(Color(0.0, 0.0, 0.0, 0.0))) {
        opacity = KeyframeGroup<Vector1D>(getObject(json, "o"));
        color = KeyframeGroup<Color>(getObject(json, "c"));
        
        if (const auto fillRuleRawValue = getOptionalInt(json, "r")) {
            switch (fillRuleRawValue.value()) {
                case 0:
                    fillRule = FillRule::None;
                    break;
                case 1:
                    fillRule = FillRule::NonZeroWinding;
                    break;
                case 2:
                    fillRule = FillRule::EvenOdd;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        fillEnabled = getOptionalBool(json, "fillEnabled");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        json.insert(std::make_pair("o", opacity.toJson()));
        json.insert(std::make_pair("c", color.toJson()));
        
        if (fillRule.has_value()) {
            json.insert(std::make_pair("r", (int)fillRule.value()));
        }
        
        if (fillEnabled.has_value()) {
            json.insert(std::make_pair("fillEnabled", fillEnabled.value()));
        }
    }
    
public:
    KeyframeGroup<Vector1D> opacity;

    /// The color keyframes for the fill
    KeyframeGroup<Color> color;

    std::optional<FillRule> fillRule;
    
    std::optional<bool> fillEnabled;
};

}

#endif /* Fill_hpp */
