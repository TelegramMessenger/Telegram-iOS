#ifndef Merge_hpp
#define Merge_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

enum class MergeMode: int {
    None = 0,
    Merge = 1,
    Add = 2,
    Subtract = 3,
    Intersect = 4,
    Exclude = 5
};

/// An item that define an ellipse shape
class Merge: public ShapeItem {
public:
    explicit Merge(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    mode(MergeMode::None) {
        auto modeRawValue = getInt(json, "mm");
        switch (modeRawValue) {
            case 0:
                mode = MergeMode::None;
                break;
            case 1:
                mode = MergeMode::Merge;
                break;
            case 2:
                mode = MergeMode::Add;
                break;
            case 3:
                mode = MergeMode::Subtract;
                break;
            case 4:
                mode = MergeMode::Intersect;
                break;
            case 5:
                mode = MergeMode::Exclude;
                break;
            default:
                throw LottieParsingException();
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        json.insert(std::make_pair("mm", (int)mode));
    }
    
public:
    /// The mode of the merge path
    MergeMode mode;
};

}

#endif /* Merge_hpp */
