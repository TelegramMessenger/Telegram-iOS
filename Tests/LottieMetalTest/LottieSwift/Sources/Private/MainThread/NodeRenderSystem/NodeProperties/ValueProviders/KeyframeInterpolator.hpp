#ifndef KeyframeInterpolator_hpp
#define KeyframeInterpolator_hpp

#include "Lottie/Public/DynamicProperties/AnyValueProvider.hpp"

namespace lottie {

/// A value provider that produces a value at Time from a group of keyframes
template<typename T>
class KeyframeInterpolator: public ValueProvider<T>, public std::enable_shared_from_this<KeyframeInterpolator<T>> {
public:
    KeyframeInterpolator(std::vector<Keyframe<T>> const &keyframes_) :
    keyframes(keyframes_) {
        assert(!keyframes.empty());
    }
    
public:
    std::vector<Keyframe<T>> keyframes;
    
    virtual AnyValue::Type valueType() const override {
        return AnyValueType<T>::type();
    }
    
    virtual T value(AnimationFrameTime frame) override {
        // First set the keyframe span for the frame.
        updateSpanIndices(frame);
        lastUpdatedFrame = frame;
        // If only one keyframe return its value
        
        if (leadingKeyframe.has_value() &&
            trailingKeyframe.has_value())
        {
            /// We have leading and trailing keyframe.
            auto progress = leadingKeyframe->interpolatedProgress(trailingKeyframe.value(), frame);
            return leadingKeyframe->interpolate(trailingKeyframe.value(), progress);
        } else if (leadingKeyframe.has_value()) {
            return leadingKeyframe->value;
        } else if (trailingKeyframe.has_value()) {
            return trailingKeyframe->value;
        } else {
            /// Satisfy the compiler.
            return keyframes[0].value;
        }
    }
    
    /// Returns true to trigger a frame update for this interpolator.
    ///
    /// An interpolator will be asked if it needs to update every frame.
    /// If the interpolator needs updating it will be asked to compute its value for
    /// the given frame.
    ///
    /// Cases a keyframe should not be updated:
    /// - If time is in span and leading keyframe is hold
    /// - If time is after the last keyframe.
    /// - If time is before the first keyframe
    ///
    /// Cases for updating a keyframe:
    /// - If time is in the span, and is not a hold
    /// - If time is outside of the span, and there are more keyframes
    /// - If a value delegate is set
    /// - If leading and trailing are both nil.
    virtual bool hasUpdate(double frame) const override {
        if (!lastUpdatedFrame.has_value()) {
            return true;
        }
            
        if (leadingKeyframe.has_value() &&
            !trailingKeyframe.has_value() &&
            leadingKeyframe->time < frame)
        {
            /// Frame is after bounds of keyframes
            return false;
        }
        if (trailingKeyframe.has_value() &&
            !leadingKeyframe.has_value() &&
            frame < trailingKeyframe->time)
        {
            /// Frame is before bounds of keyframes
            return false;
        }
        if (leadingKeyframe.has_value() &&
            trailingKeyframe.has_value() &&
            leadingKeyframe->isHold &&
            leadingKeyframe->time < frame &&
            frame < trailingKeyframe->time)
        {
            return false;
        }
        return true;
    }
    
    // MARK: Fileprivate
    
    std::optional<double> lastUpdatedFrame;
    
    std::optional<int> leadingIndex;
    std::optional<int> trailingIndex;
    std::optional<Keyframe<T>> leadingKeyframe;
    std::optional<Keyframe<T>> trailingKeyframe;
    
    /// Finds the appropriate Leading and Trailing keyframe index for the given time.
    void updateSpanIndices(double frame) {
        if (keyframes.empty()) {
            leadingIndex = std::nullopt;
            trailingIndex = std::nullopt;
            leadingKeyframe = std::nullopt;
            trailingKeyframe = std::nullopt;
            return;
        }
        
        // This function searches through the array to find the span of two keyframes
        // that contain the current time.
        //
        // We could use Array.first(where:) but that would search through the entire array
        // each frame.
        // Instead we track the last used index and search either forwards or
        // backwards from there. This reduces the iterations and complexity from
        //
        // O(n), where n is the length of the sequence to
        // O(n), where n is the number of items after or before the last used index.
        //
        
        if (keyframes.size() == 1) {
            /// Only one keyframe. Set it as first and move on.
            leadingIndex = 0;
            trailingIndex = std::nullopt;
            leadingKeyframe = keyframes[0];
            trailingKeyframe = std::nullopt;
            return;
        }
        
        /// Sets the initial keyframes. This is often only needed for the first check.
        if
            (!leadingIndex.has_value() &&
            !trailingIndex.has_value())
        {
            if (frame < keyframes[0].time) {
                /// Time is before the first keyframe. Set it as the trailing.
                trailingIndex = 0;
            } else {
                /// Time is after the first keyframe. Set the keyframe and the trailing.
                leadingIndex = 0;
                trailingIndex = 1;
            }
        }
        
        if
            (trailingIndex.has_value() &&
            keyframes[trailingIndex.value()].time <= frame)
        {
            /// Time is after the current span. Iterate forward.
            auto newLeading = trailingIndex.value();
            bool keyframeFound = false;
            while (!keyframeFound) {
                leadingIndex = newLeading;
                if (newLeading + 1 >= 0 && newLeading + 1 < keyframes.size()) {
                    trailingIndex = newLeading + 1;
                } else {
                    trailingIndex = std::nullopt;
                }
                
                if (!trailingIndex.has_value()) {
                    /// We have reached the end of our keyframes. Time is after the last keyframe.
                    keyframeFound = true;
                    continue;
                }
                
                if (frame < keyframes[trailingIndex.value()].time) {
                    /// Keyframe in current span.
                    keyframeFound = true;
                    continue;
                }
                /// Advance the array.
                newLeading = trailingIndex.value();
            }
            
        } else if
            (leadingIndex.has_value() &&
            frame < keyframes[leadingIndex.value()].time)
        {
            
            /// Time is before the current span. Iterate backwards
            auto newTrailing = leadingIndex.value();
            
            bool keyframeFound = false;
            while (!keyframeFound) {
                if (newTrailing - 1 >= 0 && newTrailing - 1 < keyframes.size()) {
                    leadingIndex = newTrailing - 1;
                } else {
                    leadingIndex = std::nullopt;
                }
                trailingIndex = newTrailing;
                
                if (!leadingIndex.has_value()) {
                    /// We have reached the end of our keyframes. Time is after the last keyframe.
                    keyframeFound = true;
                    continue;
                }
                if (keyframes[leadingIndex.value()].time <= frame) {
                    /// Keyframe in current span.
                    keyframeFound = true;
                    continue;
                }
                /// Step back
                newTrailing = leadingIndex.value();
            }
        }
        if (const auto keyFrame = leadingIndex) {
            leadingKeyframe = keyframes[keyFrame.value()];
        } else {
            leadingKeyframe = std::nullopt;
        }
        
        if (const auto keyFrame = trailingIndex) {
            trailingKeyframe = keyframes[keyFrame.value()];
        } else {
            trailingKeyframe = std::nullopt;
        }
    }
};

class BezierPathKeyframeInterpolator {
public:
    BezierPathKeyframeInterpolator(std::vector<Keyframe<BezierPath>> const &keyframes_) :
    keyframes(keyframes_) {
        assert(!keyframes.empty());
    }
    
public:
    std::vector<Keyframe<BezierPath>> keyframes;
    
    void update(AnimationFrameTime frame, BezierPath &outPath) {
        // First set the keyframe span for the frame.
        updateSpanIndices(frame);
        lastUpdatedFrame = frame;
        // If only one keyframe return its value
        
        if (leadingKeyframe.has_value() &&
            trailingKeyframe.has_value())
        {
            /// We have leading and trailing keyframe.
            auto progress = leadingKeyframe->interpolatedProgress(trailingKeyframe.value(), frame);
            interpolateInplace(leadingKeyframe.value(), trailingKeyframe.value(), progress, outPath);
        } else if (leadingKeyframe.has_value()) {
            setInplace(leadingKeyframe.value(), outPath);
        } else if (trailingKeyframe.has_value()) {
            setInplace(trailingKeyframe.value(), outPath);
        } else {
            /// Satisfy the compiler.
            setInplace(keyframes[0], outPath);
        }
    }
    
    /// Returns true to trigger a frame update for this interpolator.
    ///
    /// An interpolator will be asked if it needs to update every frame.
    /// If the interpolator needs updating it will be asked to compute its value for
    /// the given frame.
    ///
    /// Cases a keyframe should not be updated:
    /// - If time is in span and leading keyframe is hold
    /// - If time is after the last keyframe.
    /// - If time is before the first keyframe
    ///
    /// Cases for updating a keyframe:
    /// - If time is in the span, and is not a hold
    /// - If time is outside of the span, and there are more keyframes
    /// - If a value delegate is set
    /// - If leading and trailing are both nil.
    bool hasUpdate(double frame) const {
        if (!lastUpdatedFrame.has_value()) {
            return true;
        }
            
        if (leadingKeyframe.has_value() &&
            !trailingKeyframe.has_value() &&
            leadingKeyframe->time < frame)
        {
            /// Frame is after bounds of keyframes
            return false;
        }
        if (trailingKeyframe.has_value() &&
            !leadingKeyframe.has_value() &&
            frame < trailingKeyframe->time)
        {
            /// Frame is before bounds of keyframes
            return false;
        }
        if (leadingKeyframe.has_value() &&
            trailingKeyframe.has_value() &&
            leadingKeyframe->isHold &&
            leadingKeyframe->time < frame &&
            frame < trailingKeyframe->time)
        {
            return false;
        }
        return true;
    }
    
    // MARK: Fileprivate
    
    std::optional<double> lastUpdatedFrame;
    
    std::optional<int> leadingIndex;
    std::optional<int> trailingIndex;
    std::optional<Keyframe<BezierPath>> leadingKeyframe;
    std::optional<Keyframe<BezierPath>> trailingKeyframe;
    
    /// Finds the appropriate Leading and Trailing keyframe index for the given time.
    void updateSpanIndices(double frame) {
        if (keyframes.empty()) {
            leadingIndex = std::nullopt;
            trailingIndex = std::nullopt;
            leadingKeyframe = std::nullopt;
            trailingKeyframe = std::nullopt;
            return;
        }
        
        // This function searches through the array to find the span of two keyframes
        // that contain the current time.
        //
        // We could use Array.first(where:) but that would search through the entire array
        // each frame.
        // Instead we track the last used index and search either forwards or
        // backwards from there. This reduces the iterations and complexity from
        //
        // O(n), where n is the length of the sequence to
        // O(n), where n is the number of items after or before the last used index.
        //
        
        if (keyframes.size() == 1) {
            /// Only one keyframe. Set it as first and move on.
            leadingIndex = 0;
            trailingIndex = std::nullopt;
            leadingKeyframe = keyframes[0];
            trailingKeyframe = std::nullopt;
            return;
        }
        
        /// Sets the initial keyframes. This is often only needed for the first check.
        if
            (!leadingIndex.has_value() &&
            !trailingIndex.has_value())
        {
            if (frame < keyframes[0].time) {
                /// Time is before the first keyframe. Set it as the trailing.
                trailingIndex = 0;
            } else {
                /// Time is after the first keyframe. Set the keyframe and the trailing.
                leadingIndex = 0;
                trailingIndex = 1;
            }
        }
        
        if
            (trailingIndex.has_value() &&
            keyframes[trailingIndex.value()].time <= frame)
        {
            /// Time is after the current span. Iterate forward.
            auto newLeading = trailingIndex.value();
            bool keyframeFound = false;
            while (!keyframeFound) {
                leadingIndex = newLeading;
                if (newLeading + 1 >= 0 && newLeading + 1 < keyframes.size()) {
                    trailingIndex = newLeading + 1;
                } else {
                    trailingIndex = std::nullopt;
                }
                
                if (!trailingIndex.has_value()) {
                    /// We have reached the end of our keyframes. Time is after the last keyframe.
                    keyframeFound = true;
                    continue;
                }
                
                if (frame < keyframes[trailingIndex.value()].time) {
                    /// Keyframe in current span.
                    keyframeFound = true;
                    continue;
                }
                /// Advance the array.
                newLeading = trailingIndex.value();
            }
            
        } else if
            (leadingIndex.has_value() &&
            frame < keyframes[leadingIndex.value()].time)
        {
            
            /// Time is before the current span. Iterate backwards
            auto newTrailing = leadingIndex.value();
            
            bool keyframeFound = false;
            while (!keyframeFound) {
                if (newTrailing - 1 >= 0 && newTrailing - 1 < keyframes.size()) {
                    leadingIndex = newTrailing - 1;
                } else {
                    leadingIndex = std::nullopt;
                }
                trailingIndex = newTrailing;
                
                if (!leadingIndex.has_value()) {
                    /// We have reached the end of our keyframes. Time is after the last keyframe.
                    keyframeFound = true;
                    continue;
                }
                if (keyframes[leadingIndex.value()].time <= frame) {
                    /// Keyframe in current span.
                    keyframeFound = true;
                    continue;
                }
                /// Step back
                newTrailing = leadingIndex.value();
            }
        }
        if (const auto keyFrame = leadingIndex) {
            leadingKeyframe = keyframes[keyFrame.value()];
        } else {
            leadingKeyframe = std::nullopt;
        }
        
        if (const auto keyFrame = trailingIndex) {
            trailingKeyframe = keyframes[keyFrame.value()];
        } else {
            trailingKeyframe = std::nullopt;
        }
    }
    
private:
    void setInplace(Keyframe<BezierPath> const &from, BezierPath &outPath) {
        ValueInterpolator<BezierPath>::setInplace(from.value, outPath);
    }
    
    void interpolateInplace(Keyframe<BezierPath> const &from, Keyframe<BezierPath> const &to, double progress, BezierPath &outPath) {
        std::optional<Vector2D> spatialOutTangent2d;
        if (from.spatialOutTangent) {
            spatialOutTangent2d = Vector2D(from.spatialOutTangent->x, from.spatialOutTangent->y);
        }
        std::optional<Vector2D> spatialInTangent2d;
        if (to.spatialInTangent) {
            spatialInTangent2d = Vector2D(to.spatialInTangent->x, to.spatialInTangent->y);
        }
        ValueInterpolator<BezierPath>::interpolateInplace(from.value, to.value, progress, spatialOutTangent2d, spatialInTangent2d, outPath);
    }
};

}

#endif /* KeyframeInterpolator_hpp */
