#include "Sources/Animation/AnimationPlaybackEvent.h"

#include "Generated/Bindings.h"

namespace wr {

Ref<AnimationPlaybackEvent> AnimationPlaybackEvent::construct(JSContext* ctx, String type, idl::AnimationPlaybackEventInit init) {
    Ref<AnimationPlaybackEvent> event = create<AnimationPlaybackEvent>(ctx, idl::kAnimationPlaybackEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->m_currentTime = init.currentTime;
    event->m_timelineTime = init.timelineTime;
    return event;
}

Ref<AnimationPlaybackEvent> AnimationPlaybackEvent::make(JSContext* ctx, JSAtom type, std::optional<double> currentTime,
                                                          std::optional<double> timelineTime) {
    Ref<AnimationPlaybackEvent> event = create<AnimationPlaybackEvent>(ctx, idl::kAnimationPlaybackEvent, ctx);
    event->constructWith(ctx, String::fromAtom(ctx, type), false, false, false);
    event->setIsTrusted(true);
    event->m_currentTime = currentTime;
    event->m_timelineTime = timelineTime;
    return event;
}

} // namespace wr
