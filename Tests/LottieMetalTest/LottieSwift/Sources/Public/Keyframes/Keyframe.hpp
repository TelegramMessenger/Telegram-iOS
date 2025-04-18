#ifndef Keyframe_hpp
#define Keyframe_hpp

#include "Lottie/Public/Primitives/AnimationTime.hpp"
#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Public/Keyframes/Interpolatable.hpp"
#include "Lottie/Public/Keyframes/ValueInterpolators.hpp"

#include <optional>

namespace lottie {

/// A keyframe with a single value, and timing information
/// about when the value should be displayed and how it
/// should be interpolated.
template<typename T>
class Keyframe {
public:
    /// Initialize a value-only keyframe with no time data.
    Keyframe(
        T const &value_,
        std::optional<Vector3D> spatialInTangent_,
        std::optional<Vector3D> spatialOutTangent_
    ) :
    value(value_),
    spatialInTangent(spatialInTangent_),
    spatialOutTangent(spatialOutTangent_),
    time(0),
    isHold(true),
    inTangent(std::nullopt),
    outTangent(std::nullopt) {
    }
    
    /// Initialize a keyframe
    Keyframe(
        T value_,
        AnimationFrameTime time_,
        bool isHold_,
        std::optional<Vector2D> inTangent_,
        std::optional<Vector2D> outTangent_,
        std::optional<Vector3D> spatialInTangent_,
        std::optional<Vector3D> spatialOutTangent_
    ) :
    value(value_),
    time(time_),
    isHold(isHold_),
    inTangent(inTangent_),
    outTangent(outTangent_),
    spatialInTangent(spatialInTangent_),
    spatialOutTangent(spatialOutTangent_) {
    }
    
    bool operator==(Keyframe const &rhs) {
        return value == rhs.value
            && time == rhs.time
            && isHold == rhs.isHold
            && inTangent == rhs.inTangent
            && outTangent == rhs.outTangent
            && spatialInTangent == rhs.spatialInTangent
            && spatialOutTangent == rhs.spatialOutTangent;
    }
    
    bool operator!=(Keyframe const &rhs) {
        return !(*this == rhs);
    }
    
public:
    T interpolate(Keyframe<T> const &to, double progress) {
        std::optional<Vector2D> spatialOutTangent2d;
        if (spatialOutTangent) {
            spatialOutTangent2d = Vector2D(spatialOutTangent->x, spatialOutTangent->y);
        }
        std::optional<Vector2D> spatialInTangent2d;
        if (to.spatialInTangent) {
            spatialInTangent2d = Vector2D(to.spatialInTangent->x, to.spatialInTangent->y);
        }
        return ValueInterpolator<T>::interpolate(value, to.value, progress, spatialOutTangent2d, spatialInTangent2d);
    }
    
    /// Interpolates the keyTime into a value from 0-1
    double interpolatedProgress(Keyframe<T> const &to, double keyTime) {
        double startTime = time;
        double endTime = to.time;
        if (keyTime <= startTime) {
            return 0.0;
        }
        if (endTime <= keyTime) {
            return 1.0;
        }
        
        if (isHold) {
            return 0.0;
        }
        
        Vector2D outTanPoint = Vector2D::Zero();
        if (outTangent.has_value()) {
            outTanPoint = outTangent.value();
        }
        Vector2D inTanPoint = Vector2D(1.0, 1.0);
        if (to.inTangent.has_value()) {
            inTanPoint = to.inTangent.value();
        }
        double progress = remapDouble(keyTime, startTime, endTime, 0.0, 1.0);
        if (!outTanPoint.isZero() || inTanPoint != Vector2D(1.0, 1.0)) {
            /// Cubic interpolation
            progress = cubicBezierInterpolate(progress, Vector2D::Zero(), outTanPoint, inTanPoint, Vector2D(1.0, 1.0));
        }
        return progress;
    }
    
public:
    /// The value of the keyframe
    T value;
    /// The time in frames of the keyframe.
    AnimationFrameTime time;
    /// A hold keyframe freezes interpolation until the next keyframe that is not a hold.
    bool isHold;
    /// The in tangent for the time interpolation curve.
    std::optional<Vector2D> inTangent;
    /// The out tangent for the time interpolation curve.
    std::optional<Vector2D> outTangent;
    
    /// The spatial in tangent of the vector.
    std::optional<Vector3D> spatialInTangent;
    /// The spatial out tangent of the vector.
    std::optional<Vector3D> spatialOutTangent;
};

template<typename T>
class KeyframeData {
public:
    KeyframeData(
        std::optional<T> startValue_,
        std::optional<T> endValue_,
        std::optional<AnimationFrameTime> time_,
        std::optional<int> hold_,
        std::optional<Vector2D> inTangent_,
        std::optional<Vector2D> outTangent_,
        std::optional<Vector3D> spatialInTangent_,
        std::optional<Vector3D> spatialOutTangent_
    ) :
    startValue(startValue_),
    endValue(endValue_),
    time(time_),
    hold(hold_),
    inTangent(inTangent_),
    outTangent(outTangent_),
    spatialInTangent(spatialInTangent_),
    spatialOutTangent(spatialOutTangent_) {
    }
    
    explicit KeyframeData(json11::Json const &json) noexcept(false) {
        if (!json.is_object()) {
            throw LottieParsingException();
        }
        
        if (const auto startValueData = getOptionalAny(json.object_items(), "s")) {
            startValue = T(startValueData.value());
        }
        
        if (const auto endValueData = getOptionalAny(json.object_items(), "e")) {
            endValue = T(endValueData.value());
        }
        
        time = getOptionalDouble(json.object_items(), "t");
        hold = getOptionalInt(json.object_items(), "h");
        
        if (const auto inTangentData = getOptionalObject(json.object_items(), "i")) {
            inTangent = Vector2D(inTangentData.value());
        }
        
        if (const auto outTangentData = getOptionalObject(json.object_items(), "o")) {
            outTangent = Vector2D(outTangentData.value());
        }
        
        if (const auto spatialInTangentData = getOptionalAny(json.object_items(), "ti")) {
            spatialInTangent = Vector3D(spatialInTangentData.value());
        }
        
        if (const auto spatialOutTangentData = getOptionalAny(json.object_items(), "to")) {
            spatialOutTangent = Vector3D(spatialOutTangentData.value());
        }
        
        if (const auto nDataValue = getOptionalAny(json.object_items(), "n")) {
            nData = nDataValue.value();
        }
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        if (startValue.has_value()) {
            result.insert(std::make_pair("s", startValue->toJson()));
        }
        if (endValue.has_value()) {
            result.insert(std::make_pair("e", endValue->toJson()));
        }
        if (time.has_value()) {
            result.insert(std::make_pair("t", time.value()));
        }
        if (hold.has_value()) {
            result.insert(std::make_pair("h", hold.value()));
        }
        if (inTangent.has_value()) {
            result.insert(std::make_pair("i", inTangent->toJson()));
        }
        if (outTangent.has_value()) {
            result.insert(std::make_pair("o", outTangent->toJson()));
        }
        if (spatialInTangent.has_value()) {
            result.insert(std::make_pair("ti", spatialInTangent->toJson()));
        }
        if (spatialOutTangent.has_value()) {
            result.insert(std::make_pair("to", spatialOutTangent->toJson()));
        }
        if (nData.has_value()) {
            result.insert(std::make_pair("n", nData.value()));
        }
        
        return result;
    }
    
public:
    /// The start value of the keyframe
    std::optional<T> startValue;
    /// The End value of the keyframe. Note: Newer versions animation json do not have this field.
    std::optional<T> endValue;
    /// The time in frames of the keyframe.
    std::optional<AnimationFrameTime> time;
    /// A hold keyframe freezes interpolation until the next keyframe that is not a hold.
    std::optional<int> hold;
    
    /// The in tangent for the time interpolation curve.
    std::optional<Vector2D> inTangent;
    /// The out tangent for the time interpolation curve.
    std::optional<Vector2D> outTangent;
    
    /// The spacial in tangent of the vector.
    std::optional<Vector3D> spatialInTangent;
    /// The spacial out tangent of the vector.
    std::optional<Vector3D> spatialOutTangent;
    
    std::optional<json11::Json> nData;
    
    bool isHold() const {
        if (hold.has_value()) {
            return hold.value() > 0;
        } else {
            return false;
        }
    }
};

}

#endif /* Keyframe_hpp */
