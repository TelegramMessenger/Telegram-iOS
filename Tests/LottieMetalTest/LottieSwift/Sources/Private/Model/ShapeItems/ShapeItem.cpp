#include "ShapeItem.hpp"

#include "Ellipse.hpp"
#include "Fill.hpp"
#include "GradientFill.hpp"
#include "Group.hpp"
#include "GradientStroke.hpp"
#include "Merge.hpp"
#include "Rectangle.hpp"
#include "RoundedRectangle.hpp"
#include "Repeater.hpp"
#include "Shape.hpp"
#include "Star.hpp"
#include "Stroke.hpp"
#include "Trim.hpp"
#include "ShapeTransform.hpp"

namespace lottie {

std::shared_ptr<ShapeItem> parseShapeItem(json11::Json::object const &json) noexcept(false) {
    auto typeRawValue = getString(json, "ty");
    if (typeRawValue == "el") {
        return std::make_shared<Ellipse>(json);
    } else if (typeRawValue == "fl") {
        return std::make_shared<Fill>(json);
    } else if (typeRawValue == "gf") {
        return std::make_shared<GradientFill>(json);
    } else if (typeRawValue == "gr") {
        return std::make_shared<Group>(json);
    } else if (typeRawValue == "gs") {
        return std::make_shared<GradientStroke>(json);
    } else if (typeRawValue == "mm") {
        return std::make_shared<Merge>(json);
    } else if (typeRawValue == "rc") {
        return std::make_shared<Rectangle>(json);
    } else if (typeRawValue == "rp") {
        return std::make_shared<Repeater>(json);
    } else if (typeRawValue == "sh") {
        return std::make_shared<Shape>(json);
    } else if (typeRawValue == "sr") {
        return std::make_shared<Star>(json);
    } else if (typeRawValue == "st") {
        return std::make_shared<Stroke>(json);
    } else if (typeRawValue == "tm") {
        return std::make_shared<Trim>(json);
    } else if (typeRawValue == "tr") {
        return std::make_shared<ShapeTransform>(json);
    } else if (typeRawValue == "rd") {
        return std::make_shared<RoundedRectangle>(json);
    } else {
        throw LottieParsingException();
    }
}

}
