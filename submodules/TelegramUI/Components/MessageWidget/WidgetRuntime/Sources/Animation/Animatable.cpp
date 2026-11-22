// Web Animations' Animatable on Element, and Document's timeline and getAnimations (V5e plan, Task 3).
#include "Generated/Bindings.h"
#include "Sources/Animation/Animation.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/Animation/KeyframeEffect.h"
#include "Sources/Animation/Timeline.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"

namespace wr {

using animation::AnimationState;

namespace {

idl::KeyframeEffectOptions effectOptions(const idl::KeyframeAnimationOptions& o) {
    idl::KeyframeEffectOptions e;
    e.delay = o.delay;
    e.direction = o.direction;
    e.duration = o.duration;
    e.easing = o.easing;
    e.endDelay = o.endDelay;
    e.fill = o.fill;
    e.iterationStart = o.iterationStart;
    e.iterations = o.iterations;
    e.composite = o.composite;
    e.iterationComposite = o.iterationComposite;
    e.pseudoElement = o.pseudoElement;
    return e;
}

} // namespace

Ref<Animation> Element::animate(JSContext* ctx, std::optional<Object> keyframes, std::variant<Unrestricted, idl::KeyframeAnimationOptions> options) {
    std::variant<Unrestricted, idl::KeyframeEffectOptions> forEffect = Unrestricted{0};
    AnimationTimeline* timeline = &AnimationState::of(ctx).documentTimeline(ctx);
    std::optional<String> id;
    if (const idl::KeyframeAnimationOptions* o = std::get_if<idl::KeyframeAnimationOptions>(&options)) {
        forEffect = effectOptions(*o);
        if (o->timeline) {
            timeline = o->timeline->ptr;
        }
        id = o->id;
    } else {
        forEffect = std::get<Unrestricted>(options);
    }
    std::optional<Value> keyframeValue = keyframes ? Value(*keyframes) : Value::adopt(ctx, JS_NULL);
    Ref<KeyframeEffect> effect = KeyframeEffect::construct(ctx, Value::dup(ctx, this->object()), std::move(keyframeValue), std::move(forEffect));
    Ref<Animation> animation = Animation::make(ctx, effect.get(), timeline);
    if (id) {
        animation->setId(ctx, *id);
    }
    animation->play(ctx);
    return animation;
}

namespace {

/// getAnimations sees the CSS animations and transitions of the styles as they are now (CSS Animations 2): the
/// render tree is flushed first, as a layout query flushes it: its time is the query's, and past the 100 ms per task the
/// widget stops at that flush (the fix waves' review: a plain flush's time moved the slice's deadline on, so a loop of
/// them ran unchecked).
void flushStyle(JSContext* ctx) {
    layoutForQuery(ctx);
}

} // namespace

std::vector<Ref<Animation>> Element::getAnimations(JSContext* ctx, const idl::GetAnimationsOptions& options) {
    flushStyle(ctx);
    return AnimationState::of(ctx).animationsOf(ctx, *this, options.subtree);
}

DocumentTimeline* Document::timeline(JSContext* ctx) { return &AnimationState::of(ctx).documentTimeline(ctx); }

std::vector<Ref<Animation>> Document::getAnimations(JSContext* ctx) {
    flushStyle(ctx);
    return AnimationState::of(ctx).documentAnimations(ctx);
}

} // namespace wr
