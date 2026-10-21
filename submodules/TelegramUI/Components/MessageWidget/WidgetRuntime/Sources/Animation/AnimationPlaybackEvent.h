// AnimationPlaybackEvent (V5e plan, Task 3; Web Animations Level 1 §6.5): finish, cancel and remove at an Animation.
#pragma once

#include <optional>

#include "Sources/Events/Event.h"

namespace wr {

namespace idl {
struct AnimationPlaybackEventInit;
} // namespace idl

class AnimationPlaybackEvent final : public Event {
public:
    explicit AnimationPlaybackEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<AnimationPlaybackEvent> construct(JSContext* ctx, String type, idl::AnimationPlaybackEventInit init);
    /// A trusted event the update step dispatches.
    static Ref<AnimationPlaybackEvent> make(JSContext* ctx, JSAtom type, std::optional<double> currentTime, std::optional<double> timelineTime);
    std::optional<double> currentTime(JSContext*) const { return m_currentTime; }
    std::optional<double> timelineTime(JSContext*) const { return m_timelineTime; }

private:
    std::optional<double> m_currentTime;
    std::optional<double> m_timelineTime;
};

} // namespace wr
