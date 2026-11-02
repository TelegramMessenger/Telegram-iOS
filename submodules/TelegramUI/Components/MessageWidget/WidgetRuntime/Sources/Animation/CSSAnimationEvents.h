// AnimationEvent and TransitionEvent (V5f plan, Task 3; CSS Animations 1 §4.1, CSS Transitions 1 §6.1): what a CSS
// animation or transition dispatches at its owning element.
#pragma once

#include <string_view>

#include "Sources/Events/Event.h"
#include "Sources/Support/Allocator.h"

namespace wr {

namespace idl {
struct AnimationEventInit;
struct TransitionEventInit;
} // namespace idl

class AnimationEvent final : public Event {
public:
    explicit AnimationEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<AnimationEvent> construct(JSContext* ctx, String type, idl::AnimationEventInit init);
    /// A trusted, bubbling, not cancelable event the update step dispatches. `elapsedSeconds` as CSS gives it.
    static Ref<AnimationEvent> make(JSContext* ctx, std::string_view type, std::string_view animationName, double elapsedSeconds);
    String animationName(JSContext* ctx) const { return String::fromUTF8(ctx, m_animationName ? std::string_view(*m_animationName) : ""); }
    double elapsedTime(JSContext*) const { return m_elapsedTime; }
    String pseudoElement(JSContext* ctx) const { return String::fromUTF8(ctx, m_pseudoElement ? std::string_view(*m_pseudoElement) : ""); }

private:
    SharedText m_animationName;
    SharedText m_pseudoElement;
    double m_elapsedTime = 0;
};

class TransitionEvent final : public Event {
public:
    explicit TransitionEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<TransitionEvent> construct(JSContext* ctx, String type, idl::TransitionEventInit init);
    /// A trusted, bubbling, not cancelable event the update step dispatches.
    static Ref<TransitionEvent> make(JSContext* ctx, std::string_view type, std::string_view propertyName, double elapsedSeconds);
    String propertyName(JSContext* ctx) const { return String::fromUTF8(ctx, m_propertyName ? std::string_view(*m_propertyName) : ""); }
    double elapsedTime(JSContext*) const { return m_elapsedTime; }
    String pseudoElement(JSContext* ctx) const { return String::fromUTF8(ctx, m_pseudoElement ? std::string_view(*m_pseudoElement) : ""); }

private:
    SharedText m_propertyName;
    SharedText m_pseudoElement;
    double m_elapsedTime = 0;
};

} // namespace wr
