// AnimationTimeline and DocumentTimeline (V5e plan, Task 3; Web Animations Level 1 §4.3). A document timeline's time
// is the frame's timestamp (AnimationState::documentTime), never a clock: it moves only in the update step.
#pragma once

#include <optional>

#include "Sources/Support/Bindings.h"

namespace wr {

namespace idl {
struct DocumentTimelineOptions;
} // namespace idl

class AnimationTimeline : public PlatformObject {
public:
    /// The timeline's current time; nullopt while it is inactive.
    virtual std::optional<double> currentTime(JSContext* ctx) const { return std::nullopt; }
    /// Level 2's duration: null for a monotonic timeline.
    std::optional<double> duration(JSContext*) const { return std::nullopt; }
};

class DocumentTimeline final : public AnimationTimeline {
public:
    explicit DocumentTimeline(double originTime) : m_originTime(originTime) {}
    static Ref<DocumentTimeline> construct(JSContext* ctx, const idl::DocumentTimelineOptions& options);
    /// The document's time minus the origin time; always resolved.
    std::optional<double> currentTime(JSContext* ctx) const override;

private:
    double m_originTime;
};

} // namespace wr
