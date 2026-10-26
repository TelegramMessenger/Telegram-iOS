#include "Sources/Animation/Timeline.h"

#include "Generated/Bindings.h"
#include "Sources/Animation/AnimationState.h"

namespace wr {

Ref<DocumentTimeline> DocumentTimeline::construct(JSContext* ctx, const idl::DocumentTimelineOptions& options) {
    // The state keeps the document's time, which this timeline reads; it must see the frames from now on.
    animation::AnimationState::of(ctx);
    return create<DocumentTimeline>(ctx, idl::kDocumentTimeline, options.originTime);
}

std::optional<double> DocumentTimeline::currentTime(JSContext* ctx) const {
    return animation::AnimationState::of(ctx).documentTime() - m_originTime;
}

} // namespace wr
