#ifndef TextDocument_hpp
#define TextDocument_hpp

#include <LottieCpp/Vectors.h>
#import <LottieCpp/Color.h>
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>
#include <optional>

namespace lottie {

enum class TextJustification: int {
    Left = 0,
    Right = 1,
    Center = 2
};

class TextDocument {
public:
    TextDocument(
        std::string const &text_,
        float fontSize_,
        std::string const &fontFamily_,
        TextJustification justification_,
        int tracking_,
        float lineHeight_,
        std::optional<float> baseline_,
        std::optional<Color> fillColorData_,
        std::optional<Color> strokeColorData_,
        std::optional<float> strokeWidth_,
        std::optional<bool> strokeOverFill_,
        std::optional<Vector3D> textFramePosition_,
        std::optional<Vector3D> textFrameSize_
    ) :
    text(text_),
    fontSize(fontSize_),
    fontFamily(fontFamily_),
    justification(justification_),
    tracking(tracking_),
    lineHeight(lineHeight_),
    baseline(baseline_),
    fillColorData(fillColorData_),
    strokeColorData(strokeColorData_),
    strokeWidth(strokeWidth_),
    strokeOverFill(strokeOverFill_),
    textFramePosition(textFramePosition_),
    textFrameSize(textFrameSize_) {
    }
    
    explicit TextDocument(lottiejson11::Json const &jsonAny) noexcept(false) :
    text(""),
    fontSize(0.0),
    fontFamily(""),
    justification(TextJustification::Left),
    tracking(0),
    lineHeight(0.0) {
        if (!jsonAny.is_object()) {
            throw LottieParsingException();
        }
        
        lottiejson11::Json::object const &json = jsonAny.object_items();
        
        text = getString(json, "t");
        fontSize = (float)getDouble(json, "s");
        fontFamily = getString(json, "f");
        
        auto justificationRawValue = getInt(json, "j");
        switch (justificationRawValue) {
            case 0:
                justification = TextJustification::Left;
                break;
            case 1:
                justification = TextJustification::Right;
                break;
            case 2:
                justification = TextJustification::Center;
                break;
            default:
                throw LottieParsingException();
        }
        
        tracking = getInt(json, "tr");
        lineHeight = (float)getDouble(json, "lh");
        if (const auto baselineValue = getOptionalDouble(json, "ls")) {
            baseline = (float)baselineValue.value();
        }
        
        if (const auto fillColorDataValue = getOptionalAny(json, "fc")) {
            fillColorData = Color(fillColorDataValue.value());
        }
        
        if (const auto strokeColorDataValue = getOptionalAny(json, "sc")) {
            strokeColorData = Color(strokeColorDataValue.value());
        }
        
        if (const auto strokeWidthValue = getOptionalDouble(json, "sw")) {
            strokeWidth = (float)strokeWidthValue.value();
        }
        if (const auto strokeOverFillValue = getOptionalBool(json, "of")) {
            strokeOverFill = (float)strokeOverFillValue.value();
        }
        
        if (const auto textFramePositionData = getOptionalAny(json, "ps")) {
            textFramePosition = Vector3D(textFramePositionData.value());
        }
        if (const auto textFrameSizeData = getOptionalAny(json, "sz")) {
            textFrameSize = Vector3D(textFrameSizeData.value());
        }
    }
    
    lottiejson11::Json::object toJson() const {
        lottiejson11::Json::object result;
        
        result.insert(std::make_pair("t", text));
        result.insert(std::make_pair("s", fontSize));
        result.insert(std::make_pair("f", fontFamily));
        result.insert(std::make_pair("j", (int)justification));
        result.insert(std::make_pair("tr", tracking));
        result.insert(std::make_pair("lh", lineHeight));
        
        if (baseline.has_value()) {
            result.insert(std::make_pair("ls", baseline.value()));
        }
        
        if (fillColorData.has_value()) {
            result.insert(std::make_pair("fc", fillColorData->toJson()));
        }
        if (strokeColorData.has_value()) {
            result.insert(std::make_pair("sc", strokeColorData->toJson()));
        }
        
        if (strokeWidth.has_value()) {
            result.insert(std::make_pair("sw", strokeWidth.value()));
        }
        if (strokeOverFill.has_value()) {
            result.insert(std::make_pair("of", strokeOverFill.value()));
        }
        if (textFramePosition.has_value()) {
            result.insert(std::make_pair("ps", textFramePosition->toJson()));
        }
        if (textFrameSize.has_value()) {
            result.insert(std::make_pair("sz", textFrameSize->toJson()));
        }
        
        return result;
    }
    
public:
    /// The Text
    std::string text;
    
    /// The Font size
    float fontSize;
    
    /// The Font Family
    std::string fontFamily;
    
    /// Justification
    TextJustification justification;
    
    /// Tracking
    int tracking;
    
    /// Line Height
    float lineHeight;
    
    /// Baseline
    std::optional<float> baseline;
    
    /// Fill Color data
    std::optional<Color> fillColorData;
    
    /// Scroke Color data
    std::optional<Color> strokeColorData;
    
    /// Stroke Width
    std::optional<float> strokeWidth;
    
    /// Stroke Over Fill
    std::optional<bool> strokeOverFill;
    
    std::optional<Vector3D> textFramePosition;
    
    std::optional<Vector3D> textFrameSize;
};

}

#endif /* TextDocument_hpp */
