#include "Sources/Animation/CSSAnimationEvents.h"

#include "Generated/Bindings.h"

namespace wr {

Ref<AnimationEvent> AnimationEvent::construct(JSContext* ctx, String type, idl::AnimationEventInit init) {
    Ref<AnimationEvent> event = create<AnimationEvent>(ctx, idl::kAnimationEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    JSRuntime* rt = JS_GetRuntime(ctx);
    event->m_animationName = makeSharedText(rt, init.animationName.utf8());
    event->m_elapsedTime = init.elapsedTime;
    event->m_pseudoElement = makeSharedText(rt, init.pseudoElement.utf8());
    return event;
}

Ref<AnimationEvent> AnimationEvent::make(JSContext* ctx, std::string_view type, std::string_view animationName, double elapsedSeconds) {
    Ref<AnimationEvent> event = create<AnimationEvent>(ctx, idl::kAnimationEvent, ctx);
    event->constructWith(ctx, String::fromUTF8(ctx, type), true, false, false);
    event->setIsTrusted(true);
    event->m_animationName = makeSharedText(JS_GetRuntime(ctx), animationName);
    event->m_elapsedTime = elapsedSeconds;
    return event;
}

Ref<TransitionEvent> TransitionEvent::construct(JSContext* ctx, String type, idl::TransitionEventInit init) {
    Ref<TransitionEvent> event = create<TransitionEvent>(ctx, idl::kTransitionEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    JSRuntime* rt = JS_GetRuntime(ctx);
    event->m_propertyName = makeSharedText(rt, init.propertyName.utf8());
    event->m_elapsedTime = init.elapsedTime;
    event->m_pseudoElement = makeSharedText(rt, init.pseudoElement.utf8());
    return event;
}

Ref<TransitionEvent> TransitionEvent::make(JSContext* ctx, std::string_view type, std::string_view propertyName, double elapsedSeconds) {
    Ref<TransitionEvent> event = create<TransitionEvent>(ctx, idl::kTransitionEvent, ctx);
    event->constructWith(ctx, String::fromUTF8(ctx, type), true, false, false);
    event->setIsTrusted(true);
    event->m_propertyName = makeSharedText(JS_GetRuntime(ctx), propertyName);
    event->m_elapsedTime = elapsedSeconds;
    return event;
}

} // namespace wr
