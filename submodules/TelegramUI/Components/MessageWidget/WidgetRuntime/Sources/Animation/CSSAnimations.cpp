#include "Sources/Animation/CSSAnimations.h"

#include "Generated/Bindings.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/Animation/KeyframeEffect.h"
#include "Sources/Animation/Timeline.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Render/RenderTree.h"

namespace wr {

using animation::AnimationState;
using animation::CSSAnimationSpec;
using animation::CSSKeyframesRule;

namespace {

/// Where an animation is, for its events: its phase (0 idle, 1 before, 2 active, 3 after), current iteration, active
/// time, active duration and delay, all in milliseconds.
struct Moment {
    uint8_t phase = 0;
    double iteration = 0;
    double activeTime = 0;
    double activeDuration = 0;
    double delay = 0;
    double iterationDuration = 0;
    double iterationStart = 0;
};

Moment momentOf(const Animation& animation) {
    Moment moment;
    KeyframeEffect* effect = animation.keyframeEffect();
    if (!effect || animation.state() == Animation::PlayState::Idle) {
        return moment;
    }
    const animation::ComputedTiming t =
        animation::computeTiming(effect->timing(), animation.currentTime(), animation.effectivePlaybackRate() >= 0);
    switch (t.phase) {
    case animation::ComputedTiming::Phase::Before: moment.phase = 1; break;
    case animation::ComputedTiming::Phase::Active: moment.phase = 2; break;
    case animation::ComputedTiming::Phase::After: moment.phase = 3; break;
    case animation::ComputedTiming::Phase::None: moment.phase = 0; break;
    }
    moment.iteration = t.currentIteration.value_or(0);
    moment.activeTime = t.activeTime.value_or(0);
    moment.activeDuration = t.activeDuration;
    moment.delay = effect->timing().delay;
    moment.iterationDuration = effect->timing().duration.value_or(0);
    moment.iterationStart = effect->timing().iterationStart;
    return moment;
}

/// CSS's "interval start" and "interval end" (CSS Animations 2 §4.2), in milliseconds.
double intervalStart(const Moment& m) { return std::max(std::min(-m.delay, m.activeDuration), 0.0); }
double intervalEnd(const Moment& m) { return std::max(m.activeDuration, 0.0); }

/// When `elapsedMs` of active time is reached on the timeline: its start time, the delay and the elapsed time at its
/// rate; unresolved without a start time.
std::optional<double> scheduledAt(JSContext* ctx, Animation& animation, const Moment& m, double elapsedMs) {
    const std::optional<double> start = animation.startTime(ctx);
    const double rate = animation.effectivePlaybackRate();
    if (!start || rate == 0) {
        return std::nullopt;
    }
    return *start + (m.delay + elapsedMs) / rate;
}

} // namespace

// MARK: CSSAnimation

Ref<CSSAnimation> CSSAnimation::make(JSContext* ctx, Element& owner, const CSSAnimationSpec& spec, std::shared_ptr<const CSSKeyframesRule> rule) {
    AnimationState& state = AnimationState::of(ctx);
    Ref<CSSAnimation> made = create<CSSAnimation>(ctx, idl::kCSSAnimation, ctx, state.nextSequence());
    made->m_owner.set(JS_GetRuntime(ctx), owner.newRef(ctx));
    made->m_spec = spec;
    made->m_rule = std::move(rule);
    Ref<KeyframeEffect> effect = KeyframeEffect::makeForCSS(
        ctx, owner, animation::keyframesFor(ctx, *made->m_rule, animation::specEasing(ctx, spec.easing)), animation::animationTiming(spec));
    made->initialize(ctx, effect.get(), &state.documentTimeline(ctx));
    // Style's play state, not script's: the overrides below would take it over.
    if (spec.paused) {
        made->Animation::pause(ctx);
    } else {
        made->Animation::play(ctx);
    }
    return made;
}

void CSSAnimation::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_owner.mark(rt, mark);
    Animation::trace(rt, mark);
}

void CSSAnimation::dispose(JSRuntime* rt) {
    m_owner.clear(rt);
    Animation::dispose(rt);
}

Element* CSSAnimation::owner() const {
    return JS_IsUndefined(m_owner.value) ? nullptr : static_cast<Element*>(payloadOfKnown(m_owner.value));
}

void CSSAnimation::play(JSContext* ctx) {
    m_styleControlsPlayState = false;
    Animation::play(ctx);
}

void CSSAnimation::pause(JSContext* ctx) {
    m_styleControlsPlayState = false;
    Animation::pause(ctx);
}

void CSSAnimation::cancel(JSContext* ctx) {
    const Moment before = momentOf(*this);
    Animation::cancel(ctx);
    Element* target = this->owner();
    if (m_previousPhase != 0 && target) {
        AnimationState::of(ctx).queueCSSEvent(ctx, *this, *target, AnimationState::CSSEventKind::Animation, "animationcancel",
                                              m_spec.name, before.activeTime / 1000, std::nullopt);
    }
    m_previousPhase = 0;
}

void CSSAnimation::afterUpdate(JSContext* ctx) {
    // CSS Animations 2 §4.2: compared each frame the animation has no pending task.
    if (this->pending(ctx)) {
        return;
    }
    const Moment now = momentOf(*this);
    const uint8_t was = m_previousPhase;
    Element* target = this->owner();
    if (target && now.phase != 0) {
        AnimationState& state = AnimationState::of(ctx);
        auto queue = [&](const char* type, double elapsedMs) {
            state.queueCSSEvent(ctx, *this, *target, AnimationState::CSSEventKind::Animation, type, m_spec.name, elapsedMs / 1000,
                                scheduledAt(ctx, *this, now, elapsedMs));
        };
        const bool fromIdleOrBefore = was == 0 || was == 1;
        if (fromIdleOrBefore && now.phase == 2) {
            queue("animationstart", intervalStart(now));
        } else if (fromIdleOrBefore && now.phase == 3) {
            queue("animationstart", intervalStart(now));
            queue("animationend", intervalEnd(now));
        } else if (was == 2 && now.phase == 1) {
            queue("animationend", intervalStart(now));
        } else if (was == 2 && now.phase == 2 && now.iteration != m_previousIteration) {
            queue("animationiteration", (now.iteration - now.iterationStart) * now.iterationDuration);
        } else if (was == 2 && now.phase == 3) {
            queue("animationend", intervalEnd(now));
        } else if (was == 3 && now.phase == 2) {
            queue("animationstart", intervalEnd(now));
        } else if (was == 3 && now.phase == 1) {
            queue("animationstart", intervalEnd(now));
            queue("animationend", intervalStart(now));
        }
    }
    m_previousPhase = now.phase;
    m_previousIteration = now.iteration;
}

void CSSAnimation::applyStyle(JSContext* ctx, const CSSAnimationSpec& spec, std::shared_ptr<const CSSKeyframesRule> rule) {
    if (spec == m_spec && rule == m_rule) {
        return;
    }
    const bool wasPaused = m_spec.paused;
    m_spec = spec;
    m_rule = std::move(rule);
    if (KeyframeEffect* effect = this->keyframeEffect()) {
        effect->setForCSS(ctx, animation::keyframesFor(ctx, *m_rule, animation::specEasing(ctx, spec.easing)), animation::animationTiming(spec));
    }
    // A play state from style resumes without auto-rewind and never throws (CSS Animations 2 §5; Gecko's PlayFromStyle and
    // PauseFromStyle): a finished animation stays finished, and a reversed infinite one that cannot pause stays as it is.
    if (m_styleControlsPlayState && spec.paused != wasPaused) {
        try {
            if (spec.paused) {
                Animation::pause(ctx);
            } else {
                this->playWithAutoRewind(ctx, false);
            }
        } catch (const DOMError&) {
        }
    }
}

// MARK: CSSTransition

Ref<CSSTransition> CSSTransition::make(JSContext* ctx, Element& owner, std::string_view property, std::string_view from,
                                       std::string_view to, const animation::CSSTransitionSpec& spec) {
    AnimationState& state = AnimationState::of(ctx);
    JSRuntime* rt = JS_GetRuntime(ctx);
    Ref<CSSTransition> made = create<CSSTransition>(ctx, idl::kCSSTransition, ctx, state.nextSequence());
    made->m_owner.set(rt, owner.newRef(ctx));
    made->m_property = makeSharedText(rt, property);
    made->m_to = makeSharedText(rt, to);
    Vector<animation::Keyframe> frames{JSAllocator<animation::Keyframe>(rt)};
    for (const auto& [offset, value] : {std::make_pair(0.0, from), std::make_pair(1.0, to)}) {
        animation::Keyframe frame(rt);
        frame.offset = offset;
        frame.computedOffset = offset;
        frame.values.emplace_back(made->m_property, makeSharedText(rt, value));
        frames.push_back(std::move(frame));
    }
    animation::EffectTiming timing;
    timing.duration = std::max(spec.durationMs, 0.0);
    timing.delay = spec.delayMs;
    timing.fill = animation::Fill::Backwards;
    timing.easing = animation::specEasing(ctx, spec.easing);
    Ref<KeyframeEffect> effect = KeyframeEffect::makeForCSS(ctx, owner, std::move(frames), std::move(timing));
    made->initialize(ctx, effect.get(), &state.documentTimeline(ctx));
    made->Animation::play(ctx);
    return made;
}

void CSSTransition::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_owner.mark(rt, mark);
    Animation::trace(rt, mark);
}

void CSSTransition::dispose(JSRuntime* rt) {
    m_owner.clear(rt);
    Animation::dispose(rt);
}

void CSSTransition::cancel(JSContext* ctx) {
    const Moment before = momentOf(*this);
    Animation::cancel(ctx);
    Element* target = this->owner();
    if (m_previousPhase != 0 && target && m_property) {
        AnimationState::of(ctx).queueCSSEvent(ctx, *this, *target, AnimationState::CSSEventKind::Transition, "transitioncancel",
                                              *m_property, before.activeTime / 1000, std::nullopt);
    }
    m_previousPhase = 0;
}

void CSSTransition::afterUpdate(JSContext* ctx) {
    // CSS Transitions 2 §5: a pending transition counts as before its start.
    const Moment now = momentOf(*this);
    const uint8_t phase = this->pending(ctx) ? 1 : now.phase;
    const uint8_t was = m_previousPhase;
    Element* target = this->owner();
    if (target && m_property && phase != 0) {
        AnimationState& state = AnimationState::of(ctx);
        auto queue = [&](const char* type, double elapsedMs) {
            state.queueCSSEvent(ctx, *this, *target, AnimationState::CSSEventKind::Transition, type, *m_property, elapsedMs / 1000,
                                scheduledAt(ctx, *this, now, elapsedMs));
        };
        if (was == 0) {
            queue("transitionrun", intervalStart(now));
            if (phase >= 2) {
                queue("transitionstart", intervalStart(now));
            }
            if (phase == 3) {
                queue("transitionend", intervalEnd(now));
            }
        } else if (was == 1 && phase == 2) {
            queue("transitionstart", intervalStart(now));
        } else if (was == 1 && phase == 3) {
            queue("transitionstart", intervalStart(now));
            queue("transitionend", intervalEnd(now));
        } else if (was == 2 && phase == 3) {
            queue("transitionend", intervalEnd(now));
        } else if (was == 2 && phase == 1) {
            queue("transitionend", intervalStart(now));
        } else if (was == 3 && phase == 2) {
            queue("transitionstart", intervalEnd(now));
        } else if (was == 3 && phase == 1) {
            queue("transitionstart", intervalEnd(now));
            queue("transitionend", intervalStart(now));
        }
    }
    m_previousPhase = phase;
}

Element* CSSTransition::owner() const {
    return JS_IsUndefined(m_owner.value) ? nullptr : static_cast<Element*>(payloadOfKnown(m_owner.value));
}

namespace animation {

namespace {

const std::string* valueIn(const DeclaredValues& values, std::string_view property) {
    for (const auto& [name, value] : values) {
        if (name == property) {
            return &value;
        }
    }
    return nullptr;
}

} // namespace

// MARK: CSSAnimationState

void CSSAnimationState::stylesResolved(JSContext* ctx, RenderTree& render, const StyleChange& change) {
    if (change.all) {
        // A build is what applies a changed sheet: the rules are read again when the sheets' text changed. Kept
        // otherwise, so a rule keeps its identity and a CSS animation whose spec is unchanged keeps what script did to
        // its effect.
        uint64_t hash = 14695981039346656037ull;
        for (const std::string& sheet : render.styleSheets()) {
            for (unsigned char c : sheet) {
                hash = (hash ^ c) * 1099511628211ull;
            }
            hash = (hash ^ 0xff) * 1099511628211ull;
        }
        if (!m_rulesParsed || hash != m_sheetsHash) {
            m_rules.clear();
            for (const std::string& sheet : render.styleSheets()) {
                parseKeyframesRules(ctx, sheet, m_rules);
            }
            m_rulesParsed = true;
            m_sheetsHash = hash;
        }
    }
    // An element that left the document has no style: its animations are cancelled. Cancelling can run script (a
    // promise's `then` getter), so each entry leaves the map before its animations are cancelled.
    std::vector<const Element*> gone;
    for (const auto& [element, entry] : m_elements) {
        if (!entry.element->connected(ctx)) {
            gone.push_back(element);
        }
    }
    for (const Element* element : gone) {
        auto node = m_elements.extract(element);
        if (!node.empty()) {
            cancelAll(ctx, node.mapped());
        }
    }
    if (change.all) {
        // The elements first, each held: an update can run script, which can take any node out of the document.
        std::vector<Ref<Element>> elements;
        std::vector<Node*> stack{&DOMState::of(ctx).document()};
        while (!stack.empty()) {
            Node* node = stack.back();
            stack.pop_back();
            if (node->type() == NodeType::Element) {
                elements.push_back(Ref<Element>::retain(ctx, static_cast<Element*>(node)));
            }
            for (size_t i = node->childCount(); i > 0; i--) {
                stack.push_back(node->childAt(i - 1));
            }
        }
        for (const Ref<Element>& element : elements) {
            if (element->connected(ctx)) {
                this->update(ctx, render, *element, nullptr);
            }
        }
        return;
    }
    for (const Ref<Element>& element : change.elements) {
        if (!element->connected(ctx)) {
            continue;
        }
        const DeclaredValues* before = nullptr;
        for (const auto& [changed, values] : change.before) {
            if (changed == element.get()) {
                before = &values;
                break;
            }
        }
        this->update(ctx, render, *element, before);
    }
}

void CSSAnimationState::update(JSContext* ctx, RenderTree& render, Element& element, const DeclaredValues* before) {
    const DeclaredLookup declared = [&](std::string_view property) { return render.declaredValue(element, std::string(property)); };
    auto found = m_elements.find(&element);
    const bool declaresAnimations = !declared("animation").empty() || !declared("animation-name").empty();
    const bool declaresTransitions = !declared("transition").empty() || !declared("transition-property").empty();
    if (!declaresAnimations && !declaresTransitions && found == m_elements.end()) {
        return;
    }
    if (found == m_elements.end()) {
        found = m_elements.emplace(&element, ElementAnimations{Ref<Element>::retain(ctx, &element), {}, {}, {}, false}).first;
    }
    ElementAnimations& entry = found->second;
    const std::vector<CSSAnimationSpec> specs = declaresAnimations ? animationSpecs(ctx, declared) : std::vector<CSSAnimationSpec>{};
    std::vector<Ref<CSSAnimation>> previous = std::move(entry.animations);
    entry.animations.clear();
    // CSS Animations 2: an animation keeps its object while its name stays in the list (matched in list order).
    std::vector<bool> used(previous.size(), false);
    for (const CSSAnimationSpec& spec : specs) {
        auto rule = m_rules.find(spec.name);
        size_t match = previous.size();
        for (size_t i = 0; i < previous.size(); i++) {
            if (!used[i] && previous[i]->spec().name == spec.name) {
                match = i;
                break;
            }
        }
        if (rule == m_rules.end()) {
            continue;
        }
        if (match < previous.size()) {
            used[match] = true;
            previous[match]->applyStyle(ctx, spec, rule->second);
            entry.animations.push_back(std::move(previous[match]));
            continue;
        }
        entry.animations.push_back(CSSAnimation::make(ctx, element, spec, rule->second));
    }
    for (size_t i = 0; i < previous.size(); i++) {
        if (!used[i]) {
            previous[i]->cancel(ctx);
        }
    }
    this->updateTransitions(ctx, element, entry, declared, before, declaresTransitions);
    if (entry.animations.empty() && entry.transitions.empty() && !entry.tracksTransitions) {
        m_elements.erase(&element);
    }
}

void CSSAnimationState::updateTransitions(JSContext* ctx, Element& element, ElementAnimations& entry, const DeclaredLookup& declared,
                                          const DeclaredValues* before, bool declaresTransitions) {
    // A finished transition is over: its end value is the declared one now.
    entry.transitions.erase(std::remove_if(entry.transitions.begin(), entry.transitions.end(),
                                           [](const auto& t) {
                                               const Animation::PlayState s = t.second->state();
                                               return s == Animation::PlayState::Finished || s == Animation::PlayState::Idle;
                                           }),
                            entry.transitions.end());
    if (!declaresTransitions && entry.transitions.empty() && !entry.tracksTransitions) {
        return;
    }
    DeclaredValues after;
    for (std::string_view property : kWatchedProperties) {
        std::string value = watchedValue(declared, property);
        if (!value.empty()) {
            after.emplace_back(std::string(property), std::move(value));
        }
    }
    // The before-change style: the values kept at the last change, else what the flush read before patching.
    const DeclaredValues* previous = entry.tracksTransitions ? &entry.declared : before;
    if (previous) {
        const std::vector<CSSTransitionSpec> specs = declaresTransitions ? transitionSpecs(ctx, declared) : std::vector<CSSTransitionSpec>{};
        for (std::string_view property : kWatchedProperties) {
            // An undeclared value, before or after, is the property's initial one (a transition from or back to
            // unset); a property without one in the table does not transition.
            const std::string_view initial = initialValue(property);
            const auto valueOr = [&](const std::string* declared) -> std::optional<std::string> {
                if (declared) {
                    return *declared;
                }
                return initial.empty() ? std::nullopt : std::optional<std::string>(std::string(initial));
            };
            const std::optional<std::string> now = valueOr(valueIn(after, property));
            const std::optional<std::string> was = valueOr(valueIn(*previous, property));
            auto running = std::find_if(entry.transitions.begin(), entry.transitions.end(), [&](const auto& t) { return t.first == property; });
            if (!now) {
                if (running != entry.transitions.end()) {
                    running->second->cancel(ctx);
                    entry.transitions.erase(running);
                }
                continue;
            }
            // The last spec covering the property wins (CSS Transitions 1 §2).
            const CSSTransitionSpec* spec = nullptr;
            for (const CSSTransitionSpec& s : specs) {
                if (transitionCovers(s.property, property)) {
                    spec = &s;
                }
            }
            if (!spec) {
                if (running != entry.transitions.end()) {
                    running->second->cancel(ctx);
                    entry.transitions.erase(running);
                }
                continue;
            }
            if (!was || *was == *now || (running != entry.transitions.end() && running->second->to() == *now)) {
                continue;
            }
            // An interrupted transition hands over where it is.
            std::string from = *was;
            if (running != entry.transitions.end()) {
                if (std::optional<std::string> current = AnimationState::of(ctx).sampledValue(ctx, element, *running->second, property)) {
                    from = std::move(*current);
                }
                running->second->cancel(ctx);
                entry.transitions.erase(running);
            }
            entry.transitions.emplace_back(std::string(property), CSSTransition::make(ctx, element, property, from, *now, *spec));
        }
    }
    entry.tracksTransitions = declaresTransitions || !entry.transitions.empty();
    entry.declared = entry.tracksTransitions ? std::move(after) : DeclaredValues{};
}

void CSSAnimationState::cancelAll(JSContext* ctx, ElementAnimations& entry) {
    for (const Ref<CSSAnimation>& animation : entry.animations) {
        animation->cancel(ctx);
    }
    for (const auto& [property, transition] : entry.transitions) {
        transition->cancel(ctx);
    }
}

} // namespace animation
} // namespace wr
