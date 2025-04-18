#ifndef KeyframeGroup_hpp
#define KeyframeGroup_hpp

#include "Lottie/Public/Keyframes/Keyframe.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <vector>

namespace lottie {

/// Used for coding/decoding a group of Keyframes by type.
///
/// Keyframe data is wrapped in a dictionary { "k" : KeyframeData }.
/// The keyframe data can either be an array of keyframes or, if no animation is present, the raw value.
/// This helper object is needed to properly decode the json.

template<typename T>
class KeyframeGroup {
public:
    KeyframeGroup(std::vector<Keyframe<T>> &&keyframes_) :
    keyframes(std::move(keyframes_)),
    isSingle(false) {
    }
    
    KeyframeGroup(T const &value_) :
    keyframes({ Keyframe<T>(value_, std::nullopt, std::nullopt) }),
    isSingle(false) {
    }
    
    KeyframeGroup(json11::Json::object const &json) noexcept(false) {
        isAnimated = getOptionalInt(json, "a");
        expression = getOptionalAny(json, "x");
        expressionIndex = getOptionalInt(json, "ix");
        _extraL = getOptionalInt(json, "l");
        
        auto containerData = getAny(json, "k");
        
        try {
            LottieParsingException::Guard expectedException;
            T keyframeData = T(containerData);
            keyframes.push_back(Keyframe<T>(keyframeData, std::nullopt, std::nullopt));
            isSingle = true;
        } catch(...) {
            // Decode and array of keyframes.
            //
            // Body Movin and Lottie deal with keyframes in different ways.
            //
            // A keyframe object in Body movin defines a span of time with a START
            // and an END, from the current keyframe time to the next keyframe time.
            //
            // A keyframe object in Lottie defines a singular point in time/space.
            // This point has an in-tangent and an out-tangent.
            //
            // To properly decode this we must iterate through keyframes while holding
            // reference to the previous keyframe.
            
            if (!containerData.is_array()) {
                throw LottieParsingException();
            }
            
            std::optional<KeyframeData<T>> previousKeyframeData;
            for (const auto &containerItem : containerData.array_items()) {
                // Ensure that Time and Value are present.
                auto keyframeData = KeyframeData<T>(containerItem);
                rawKeyframeData.push_back(keyframeData);
                
                std::optional<T> value;
                if (keyframeData.startValue.has_value()) {
                    value = keyframeData.startValue;
                } else if (previousKeyframeData.has_value()) {
                    value = previousKeyframeData->endValue;
                }
                if (!value.has_value()) {
                    throw LottieParsingException();
                }
                if (!keyframeData.time.has_value()) {
                    throw LottieParsingException();
                }
                
                std::optional<Vector2D> inTangent;
                std::optional<Vector3D> spatialInTangent;
                if (previousKeyframeData.has_value()) {
                    inTangent = previousKeyframeData->inTangent;
                    spatialInTangent = previousKeyframeData->spatialInTangent;
                }
                
                keyframes.emplace_back(
                    value.value(),
                    keyframeData.time.value(),
                    keyframeData.isHold(),
                    inTangent,
                    keyframeData.outTangent,
                    spatialInTangent,
                    keyframeData.spatialOutTangent
                );
                
                previousKeyframeData = keyframeData;
            }
            
            isSingle = false;
        }
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        assert(!keyframes.empty());
        
        if (keyframes.size() == 1 && isSingle) {
            result.insert(std::make_pair("k", keyframes[0].value.toJson()));
        } else {
            json11::Json::array containerData;
            
            for (const auto &keyframe : rawKeyframeData) {
                containerData.push_back(keyframe.toJson());
            }
            
            result.insert(std::make_pair("k", containerData));
        }
        
        if (isAnimated.has_value()) {
            result.insert(std::make_pair("a", isAnimated.value()));
        }
        if (expression.has_value()) {
            result.insert(std::make_pair("x", expression.value()));
        }
        if (expressionIndex.has_value()) {
            result.insert(std::make_pair("ix", expressionIndex.value()));
        }
        if (_extraL.has_value()) {
            result.insert(std::make_pair("l", _extraL.value()));
        }
        
        return result;
    }
    
public:
    std::vector<Keyframe<T>> keyframes;
    std::optional<int> isAnimated;
    
    std::optional<json11::Json> expression;
    std::optional<int> expressionIndex;
    std::vector<KeyframeData<T>> rawKeyframeData;
    bool isSingle = false;
    std::optional<int> _extraL;
};

}

#endif /* KeyframeGroup_hpp */
