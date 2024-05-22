#ifndef Stroke_hpp
#define Stroke_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/ShapeItems/GradientStroke.hpp"
#include "Lottie/Public/Primitives/Color.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Model/Objects/DashElement.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <optional>

namespace lottie {

/// An item that define an ellipse shape
class Stroke: public ShapeItem {
public:
    explicit Stroke(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    opacity(KeyframeGroup<Vector1D>(Vector1D(100.0))),
    color(KeyframeGroup<Color>(Color(0.0, 0.0, 0.0, 0.0))),
    width(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    lineCap(LineCap::Round),
    lineJoin(LineJoin::Round) {
        opacity = KeyframeGroup<Vector1D>(getObject(json, "o"));
        color = KeyframeGroup<Color>(getObject(json, "c"));
        width = KeyframeGroup<Vector1D>(getObject(json, "w"));
        
        if (const auto lineCapRawValue = getOptionalInt(json, "lc")) {
            switch (lineCapRawValue.value()) {
                case 0:
                    lineCap = LineCap::None;
                    break;
                case 1:
                    lineCap = LineCap::Butt;
                    break;
                case 2:
                    lineCap = LineCap::Round;
                    break;
                case 3:
                    lineCap = LineCap::Square;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        if (const auto lineJoinRawValue = getOptionalInt(json, "lj")) {
            switch (lineJoinRawValue.value()) {
                case 0:
                    lineJoin = LineJoin::None;
                    break;
                case 1:
                    lineJoin = LineJoin::Miter;
                    break;
                case 2:
                    lineJoin = LineJoin::Round;
                    break;
                case 3:
                    lineJoin = LineJoin::Bevel;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        if (const auto miterLimitData = getOptionalDouble(json, "ml")) {
            miterLimit = miterLimitData.value();
        }
        
        if (const auto dashElementsData = getOptionalObjectArray(json, "d")) {
            dashPattern = std::vector<DashElement>();
            for (const auto &dashElementData : dashElementsData.value()) {
                dashPattern->push_back(DashElement(dashElementData));
            }
        }
        
        fillEnabled = getOptionalBool(json, "fillEnabled");
        ml2 = getOptionalAny(json, "ml2");
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        json.insert(std::make_pair("o", opacity.toJson()));
        json.insert(std::make_pair("c", color.toJson()));
        json.insert(std::make_pair("w", width.toJson()));
        
        json.insert(std::make_pair("lc", (int)lineCap));
        json.insert(std::make_pair("lj", (int)lineJoin));
        
        if (miterLimit.has_value()) {
            json.insert(std::make_pair("ml", miterLimit.value()));
        }
        
        if (dashPattern.has_value()) {
            json11::Json::array dashElements;
            for (const auto &dashElement : dashPattern.value()) {
                dashElements.push_back(dashElement.toJson());
            }
            json.insert(std::make_pair("d", dashElements));
        }
        
        if (fillEnabled.has_value()) {
            json.insert(std::make_pair("fillEnabled", fillEnabled.value()));
        }
        if (ml2.has_value()) {
            json.insert(std::make_pair("ml2", ml2.value()));
        }
    }
    
public:
    /// The opacity of the stroke
    KeyframeGroup<Vector1D> opacity;
    
    /// The Color of the stroke
    KeyframeGroup<Color> color;
    
    /// The width of the stroke
    KeyframeGroup<Vector1D> width;
    
    /// Line Cap
    LineCap lineCap;
    
    /// Line Join
    LineJoin lineJoin;
    
    /// Miter Limit
    std::optional<double> miterLimit;
    
    /// The dash pattern of the stroke
    std::optional<std::vector<DashElement>> dashPattern;
    
    std::optional<bool> fillEnabled;
    std::optional<json11::Json> ml2;
};

}

#endif /* Stroke_hpp */
