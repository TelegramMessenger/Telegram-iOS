#include "Sources/Animation/AnimationState.h"

#include <algorithm>
#include <cmath>
#include <iterator>
#include <map>
#include <string_view>
#include <unordered_map>
#include <unordered_set>

#include "Generated/Bindings.h"
#include "Sources/Animation/Animation.h"
#include "Sources/Animation/AnimationPlaybackEvent.h"
#include "Sources/Animation/CSSAnimationEvents.h"
#include "Sources/Animation/CSSAnimations.h"
#include "Sources/Animation/KeyframeEffect.h"
#include "Sources/Animation/Timeline.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Animation/Interpolation.h"
#include "Sources/DOM/StyleDeclaration.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"

namespace wr::animation {

AnimationState::AnimationState(JSContext* ctx)
    : m_ctx(ctx), m_animations(JSAllocator<Ref<Animation>>(JS_GetRuntime(ctx))), m_events(JSAllocator<QueuedEvent>(JS_GetRuntime(ctx))),
      m_marked(JSAllocator<Ref<Element>>(JS_GetRuntime(ctx))) {
    // Made after frames already ran (the first use of an animation API): the latest step's time, not 0, until the next
    // frame sets it.
    HostState& host = HostState::of(ctx);
    m_documentTime = std::max(0.0, host.loop().currentTime() - host.timeOrigin());
}

AnimationState::~AnimationState() = default;

AnimationState& AnimationState::of(JSContext* ctx) {
    std::unique_ptr<AnimationState>& slot = HostState::of(ctx).animationSlot();
    if (!slot) {
        slot = std::make_unique<AnimationState>(ctx);
    }
    return *slot;
}

AnimationState* AnimationState::find(JSContext* ctx) {
    HostState* host = HostState::find(ctx);
    return host ? host->animationSlot().get() : nullptr;
}

DocumentTimeline& AnimationState::documentTimeline(JSContext* ctx) {
    if (!m_timeline) {
        m_timeline = create<DocumentTimeline>(ctx, idl::kDocumentTimeline, 0.0);
    }
    return *m_timeline;
}

void AnimationState::track(JSContext* ctx, Animation& animation) {
    if (animation.isTracked()) {
        return;
    }
    m_animations.push_back(Ref<Animation>::retain(ctx, &animation));
    animation.setTracked(true);
}

void AnimationState::updateAnimations(JSContext* ctx, double timestamp) {
    // A pending task or a finished state may run script (a widget's `then` on a resolved promise), so the list is
    // copied: the copy keeps each animation alive while it is visited.
    Vector<Ref<Animation>> visit(m_animations);
    // Which animations moved until now, read before the time moves: one that finishes in this frame stops moving here,
    // and its target must be sampled once more.
    std::vector<bool> wasMoving(visit.size());
    for (size_t i = 0; i < visit.size(); i++) {
        wasMoving[i] = visit[i]->wantsFrame();
    }
    m_documentTime = timestamp;
    bool wants = false;
    for (size_t i = 0; i < visit.size(); i++) {
        const Ref<Animation>& animation = visit[i];
        animation->update(ctx);
        animation->afterUpdate(ctx);
        const bool moving = animation->wantsFrame();
        wants = wants || moving;
        // A target whose animation moved, started or stopped moving this frame is sampled again at the flush.
        if (wasMoving[i] || moving) {
            if (KeyframeEffect* effect = animation->keyframeEffect()) {
                this->noteTarget(effect->targetElement());
            }
        }
    }
    this->removeReplaced(ctx);
    m_wantsFrame = wants;
}

void AnimationState::removeReplaced(JSContext* ctx) {
    // Level 1's replaceable animations: active or persisted, so a persisted one covers those below it too.
    std::vector<Animation*> candidates;
    for (const Ref<Animation>& animation : m_animations) {
        KeyframeEffect* effect = animation->keyframeEffect();
        // CSS animations and transitions are prescribed by markup: never replaceable (V5f).
        if (animation->compositeClass() == 2 && animation->replace() != Animation::ReplaceState::Removed && effect && effect->targetElement() &&
            dynamic_cast<DocumentTimeline*>(animation->timeline(ctx)) && animation->state() == Animation::PlayState::Finished &&
            animation->isFilling()) {
            candidates.push_back(animation.get());
        }
    }
    if (candidates.size() < 2) {
        return;
    }
    std::sort(candidates.begin(), candidates.end(), [](const Animation* a, const Animation* b) { return compositeOrderLess(*a, *b); });
    // The properties later animations cover, per effect target (an element, or one of its pseudo-elements: each has its
    // own effect stack), sorted; views into the effects' own text, alive for the call.
    JSRuntime* rt = JS_GetRuntime(ctx);
    std::map<std::pair<Element*, std::string_view>, Vector<std::string_view>> covered;
    for (auto it = candidates.rbegin(); it != candidates.rend(); ++it) {
        Animation* animation = *it;
        KeyframeEffect* effect = animation->keyframeEffect();
        Vector<std::string_view> names{JSAllocator<std::string_view>(rt)};
        for (const Keyframe& frame : effect->keyframes()) {
            for (const auto& [name, value] : frame.values) {
                names.emplace_back(*name);
            }
        }
        std::sort(names.begin(), names.end());
        names.erase(std::unique(names.begin(), names.end()), names.end());
        auto [entry, inserted] =
            covered.try_emplace({effect->targetElement(), effect->pseudoElementText()}, JSAllocator<std::string_view>(rt));
        Vector<std::string_view>& cover = entry->second;
        // Only an active animation whose target is in the document is removed.
        const bool replaced = animation->replace() == Animation::ReplaceState::Active && effect->targetElement()->connected(ctx) &&
                              !names.empty() && std::includes(cover.begin(), cover.end(), names.begin(), names.end());
        if (replaced) {
            animation->markRemoved(ctx);
        }
        Vector<std::string_view> merged{JSAllocator<std::string_view>(rt)};
        merged.reserve(cover.size() + names.size());
        std::set_union(cover.begin(), cover.end(), names.begin(), names.end(), std::back_inserter(merged));
        cover.swap(merged);
    }
}

void AnimationState::queueEvent(JSContext* ctx, Animation& animation, const char* type, std::optional<double> currentTime,
                                std::optional<double> timelineTime, std::optional<double> scheduledTime) {
    if (m_events.size() >= kMaxQueuedEvents) {
        return;
    }
    // A NaN time (a start time of -Infinity, from a rate so small that end / rate overflows) is unresolved: the sort's
    // comparator needs a strict weak ordering, which NaN breaks (final review C1).
    if (scheduledTime && std::isnan(*scheduledTime)) {
        scheduledTime.reset();
    }
    m_events.push_back(QueuedEvent{Ref<Animation>::retain(ctx, &animation), Atom::fromUTF8(ctx, type), currentTime, timelineTime,
                                   scheduledTime, m_eventOrder++});
}

void AnimationState::queueCSSEvent(JSContext* ctx, Animation& animation, Element& target, CSSEventKind kind, const char* type,
                                   std::string_view name, double elapsedSeconds, std::optional<double> scheduledTime) {
    if (m_events.size() >= kMaxQueuedEvents) {
        return;
    }
    if (scheduledTime && std::isnan(*scheduledTime)) {
        scheduledTime.reset();
    }
    QueuedEvent event{Ref<Animation>::retain(ctx, &animation), Atom::fromUTF8(ctx, type), std::nullopt, std::nullopt, scheduledTime, m_eventOrder++};
    event.cssKind = kind;
    event.target = Ref<Element>::retain(ctx, &target);
    event.name = makeSharedText(JS_GetRuntime(ctx), name);
    event.elapsedSeconds = elapsedSeconds;
    m_events.push_back(std::move(event));
}

void AnimationState::dispatchEvents(JSContext* ctx) {
    if (m_events.empty()) {
        return;
    }
    Vector<QueuedEvent> events(JSAllocator<QueuedEvent>(JS_GetRuntime(ctx)));
    events.swap(m_events);
    std::sort(events.begin(), events.end(), [](const QueuedEvent& a, const QueuedEvent& b) {
        if (a.scheduledTime.has_value() != b.scheduledTime.has_value()) {
            return !a.scheduledTime.has_value();
        }
        if (a.scheduledTime && *a.scheduledTime != *b.scheduledTime) {
            return *a.scheduledTime < *b.scheduledTime;
        }
        if (a.animation.get() != b.animation.get() &&
            (compositeOrderLess(*a.animation, *b.animation) || compositeOrderLess(*b.animation, *a.animation))) {
            return compositeOrderLess(*a.animation, *b.animation);
        }
        return a.order < b.order;
    });
    for (const QueuedEvent& queued : events) {
        if (queued.cssKind == CSSEventKind::None) {
            Ref<AnimationPlaybackEvent> event = AnimationPlaybackEvent::make(ctx, queued.type.get(), queued.currentTime, queued.timelineTime);
            dispatch(ctx, *event, *queued.animation);
            continue;
        }
        const std::string type = String::fromAtom(ctx, queued.type.get()).utf8();
        const std::string_view name = queued.name ? std::string_view(*queued.name) : std::string_view();
        if (queued.cssKind == CSSEventKind::Animation) {
            Ref<AnimationEvent> event = AnimationEvent::make(ctx, type, name, queued.elapsedSeconds);
            dispatch(ctx, *event, *queued.target);
        } else {
            Ref<TransitionEvent> event = TransitionEvent::make(ctx, type, name, queued.elapsedSeconds);
            dispatch(ctx, *event, *queued.target);
        }
    }
}

void AnimationState::release(JSContext* ctx) {
    std::unordered_set<const Animation*> awaitingEvents;
    for (const QueuedEvent& queued : m_events) {
        awaitingEvents.insert(queued.animation.get());
    }
    Vector<Ref<Animation>> kept{JSAllocator<Ref<Animation>>(JS_GetRuntime(ctx))};
    kept.reserve(m_animations.size());
    Vector<Ref<Animation>> released{JSAllocator<Ref<Animation>>(JS_GetRuntime(ctx))};
    for (Ref<Animation>& animation : m_animations) {
        if (animation->isReleasable() && !awaitingEvents.count(animation.get())) {
            animation->setTracked(false);
            released.push_back(std::move(animation));
        } else {
            kept.push_back(std::move(animation));
        }
    }
    m_animations.swap(kept);
    // `released` goes here: possibly each animation's last reference, nothing touches them after this.
}

std::vector<Ref<Animation>> AnimationState::animationsOf(JSContext* ctx, Element& element, bool subtree) {
    std::vector<Ref<Animation>> out;
    for (const Ref<Animation>& animation : m_animations) {
        KeyframeEffect* effect = animation->keyframeEffect();
        Element* target = effect ? effect->targetElement() : nullptr;
        if (!target || !animation->isRelevant()) {
            continue;
        }
        if (target == &element || (subtree && element.isInclusiveAncestorOf(ctx, *target))) {
            out.push_back(animation);
        }
    }
    std::sort(out.begin(), out.end(), [](const Ref<Animation>& a, const Ref<Animation>& b) { return compositeOrderLess(*a, *b); });
    return out;
}

std::vector<Ref<Animation>> AnimationState::documentAnimations(JSContext* ctx) {
    std::vector<Ref<Animation>> out;
    for (const Ref<Animation>& animation : m_animations) {
        KeyframeEffect* effect = animation->keyframeEffect();
        Element* target = effect ? effect->targetElement() : nullptr;
        if (target && target->connected(ctx) && animation->isRelevant()) {
            out.push_back(animation);
        }
    }
    std::sort(out.begin(), out.end(), [](const Ref<Animation>& a, const Ref<Animation>& b) { return compositeOrderLess(*a, *b); });
    return out;
}

// ── rendering ──

/// The reference renderer's initial values, for a property neither an earlier animation nor the inline style gives.
std::string_view initialValue(std::string_view property) {
    static const std::pair<std::string_view, std::string_view> kInitial[] = {
        {"opacity", "1"}, {"transform", "none"}, {"translate", "0px"}, {"scale", "1"},
        {"rotate", "0deg"}, {"filter", "none"}, {"letter-spacing", "0px"},
    };
    for (const auto& [name, value] : kInitial) {
        if (name == property) {
            return value;
        }
    }
    return {};
}

namespace {

/// A value that stays inside its declaration: no `;`, `{`, `}` or `!`, brackets balanced, quotes closed. Anything else
/// would end its declaration early or swallow the next ones, so it is not rendered.
bool staysInItsDeclaration(std::string_view value) {
    int round = 0, square = 0;
    char quote = 0;
    for (size_t i = 0; i < value.size(); i++) {
        const char c = value[i];
        if (quote) {
            if (c == '\\') {
                i++;
            } else if (c == quote) {
                quote = 0;
            }
            continue;
        }
        switch (c) {
        case ';': case '{': case '}': case '!': return false;
        case '"': case '\'': quote = c; break;
        case '(': round++; break;
        case ')': if (--round < 0) return false; break;
        case '[': square++; break;
        case ']': if (--square < 0) return false; break;
        default: break;
        }
    }
    return !quote && round == 0 && square == 0;
}

} // namespace

void AnimationState::noteTarget(Element* element) {
    if (!element || !HostState::of(m_ctx).render()) {
        return;
    }
    if (m_markedSet.insert(element).second) {
        m_marked.push_back(Ref<Element>::retain(m_ctx, element));
    }
}

void AnimationState::stylesResolved(JSContext* ctx, RenderTree& render, const StyleChange& change) {
    if (m_styleObserver) {
        m_styleObserver(change);
    }
    if (!m_css) {
        m_css = std::make_unique<CSSAnimationState>();
    }
    m_css->stylesResolved(ctx, render, change);
    // An animated element whose style changed is sampled again: its declarations are its underlying values.
    if (change.all) {
        for (const auto& [element, styled] : m_styles) {
            this->noteTarget(styled.element.get());
        }
    } else {
        for (const Ref<Element>& element : change.elements) {
            if (m_styles.count(element.get())) {
                this->noteTarget(element.get());
            }
        }
    }
}

void AnimationState::styleAttributeChanged(Element& element) {
    if (m_styles.count(&element)) {
        this->noteTarget(&element);
    }
}

std::unordered_map<const Element*, std::vector<Animation*>> AnimationState::renderedAnimations(
    JSContext* ctx, const std::unordered_set<const Element*>& targets) {
    std::unordered_map<const Element*, std::vector<Animation*>> out;
    // widget-sandbox v0.3.0's limit.animations caps the live script animations (Limits::renderedAnimations; upstream's
    // validator counts its shim's animation records); CSS animations and transitions are the renderer's own. All of them
    // together stay within the runtime's own bound, kMaxRenderedAnimations.
    const size_t cap = Runtime::from(ctx).limits().renderedAnimations;
    size_t rendered = 0, scripted = 0;
    auto note = [&](size_t count, const char* what) {
        if (!m_notedAnimationLimit) {
            m_notedAnimationLimit = true;
            Runtime::from(ctx).host().diagnostic("animation-limit", "more than " + std::to_string(count) + what +
                                                                        "; further ones are not rendered");
        }
    };
    for (const Ref<Animation>& animation : m_animations) {
        KeyframeEffect* effect = animation->keyframeEffect();
        Element* target = effect ? effect->targetElement() : nullptr;
        if (!target) {
            continue;
        }
        if (animation->compositeClass() == 2 && scripted++ >= cap) {
            note(cap, " live script animations");
            continue;
        }
        if (rendered >= kMaxRenderedAnimations) {
            note(kMaxRenderedAnimations, " live animations");
            break;
        }
        rendered++;
        if (targets.count(target)) {
            out[target].push_back(animation.get());
        }
    }
    for (auto& [target, list] : out) {
        std::sort(list.begin(), list.end(), [](const Animation* a, const Animation* b) { return compositeOrderLess(*a, *b); });
    }
    return out;
}

std::vector<std::pair<std::string, std::string>> AnimationState::sample(JSContext* ctx, Element& element,
                                                                        const std::vector<Animation*>& animations,
                                                                        const Animation* include) {
    // Every lookup is a hash: an effect has up to 64 x 64 values, and a scan per property made sampling quadratic
    // (final review I9). No script runs while sampling, so the views into keyframes and the parsed style stay valid.
    std::vector<std::pair<std::string, std::string>> results;
    std::unordered_map<std::string_view, size_t> resultIndex;
    std::optional<std::vector<CSSStyleDeclaration::Declaration>> inlineStyle;
    std::unordered_map<std::string_view, std::string_view> inlineValues;
    auto underlying = [&](std::string_view property) -> std::string {
        if (auto it = resultIndex.find(property); it != resultIndex.end()) {
            return results[it->second].second;
        }
        // The cascaded declaration (V5f: litehtml keeps one for every property CSS animations watch), else the inline
        // style's, else the initial value.
        if (RenderTree* render = HostState::of(ctx).render()) {
            std::string cascaded = render->declaredValue(element, std::string(property));
            if (!cascaded.empty()) {
                return cascaded;
            }
        }
        if (!inlineStyle) {
            const std::optional<String> text = element.attributeValue(ctx, DOMState::of(ctx).name(Name::style));
            inlineStyle = text ? CSSStyleDeclaration::parse(ctx, text->utf8()) : std::vector<CSSStyleDeclaration::Declaration>{};
            for (const CSSStyleDeclaration::Declaration& d : *inlineStyle) {
                inlineValues.emplace(d.name, d.value);
            }
        }
        if (auto it = inlineValues.find(property); it != inlineValues.end()) {
            return std::string(it->second);
        }
        return std::string(initialValue(property));
    };
    struct Property {
        std::string_view name;
        std::vector<PropertyFrame> frames;
        size_t lastFrame;
    };
    for (Animation* animation : animations) {
        KeyframeEffect* effect = animation->keyframeEffect();
        // commitStyles' own animation counts even when it was removed (Level 1 §4.4.20); being in effect still decides.
        if (!effect || effect->targetsPseudoElement() || (animation != include && !animation->isRelevant())) {
            continue;
        }
        const ComputedTiming timing = computeTiming(effect->timing(), animation->currentTime(), animation->playbackRate(ctx) >= 0);
        if (!timing.progress) {
            continue;
        }
        const Vector<Keyframe>& keyframes = effect->keyframes();
        const size_t frameCount = std::min(keyframes.size(), kMaxRenderedKeyframes);
        // The properties in the order they first appear, each with its value in every keyframe that has one (the first
        // one a keyframe lists).
        std::vector<Property> properties;
        std::unordered_map<std::string_view, size_t> propertyIndex;
        for (size_t k = 0; k < frameCount; k++) {
            const Keyframe& frame = keyframes[k];
            const size_t count = std::min(frame.values.size(), kMaxRenderedProperties);
            for (size_t v = 0; v < count; v++) {
                const std::string_view name = *frame.values[v].first;
                auto [it, added] = propertyIndex.emplace(name, properties.size());
                if (added) {
                    properties.push_back(Property{name, {}, SIZE_MAX});
                }
                Property& property = properties[it->second];
                if (property.lastFrame == k) {
                    continue;
                }
                property.lastFrame = k;
                if (staysInItsDeclaration(*frame.values[v].second)) {
                    property.frames.push_back(
                        PropertyFrame{frame.computedOffset, frame.easing.get(), frame.composite, std::string_view(*frame.values[v].second)});
                }
            }
        }
        for (const Property& property : properties) {
            if (property.frames.empty()) {
                continue;
            }
            const std::string base = underlying(property.name);
            std::string value = effectValue(ctx, property.frames, property.name, *timing.progress, timing.currentIteration.value_or(0),
                                            effect->compositeOperation(), effect->accumulatesIterations(), base);
            if (!staysInItsDeclaration(value)) {
                continue;
            }
            auto [it, added] = resultIndex.emplace(property.name, results.size());
            if (added) {
                results.emplace_back(std::string(property.name), std::move(value));
            } else {
                results[it->second].second = std::move(value);
            }
        }
    }
    return results;
}

void AnimationState::collectRenderChanges(JSContext* ctx, RenderTree& render) {
    if (m_marked.empty()) {
        return;
    }
    Vector<Ref<Element>> marked{JSAllocator<Ref<Element>>(JS_GetRuntime(ctx))};
    marked.swap(m_marked);
    const std::unordered_set<const Element*> targets = std::move(m_markedSet);
    m_markedSet.clear();
    const std::unordered_map<const Element*, std::vector<Animation*>> byTarget = this->renderedAnimations(ctx, targets);
    static const std::vector<Animation*> kNone;
    for (const Ref<Element>& element : marked) {
        auto list = byTarget.find(element.get());
        // The text opens with twidget's animation-layer marker: litehtml then records none of the declarations after it
        // as the element's declared values (style.cpp's raw declarations), which transitions compare (V5f plan, Task 2).
        static constexpr std::string_view kLayerMarker = "-lh-anim: 1; ";
        std::string text;
        for (const auto& [name, value] : this->sample(ctx, *element, list == byTarget.end() ? kNone : list->second)) {
            if (text.empty()) {
                text = kLayerMarker;
            }
            const size_t size = name.size() + 2 + value.size() + 2;
            if (text.size() + size > kMaxAnimatedStyleBytes) {
                break;
            }
            text += name;
            text += ": ";
            text += value;
            text += "; ";
        }
        auto it = m_styles.find(element.get());
        bool changed = false;
        if (text.empty()) {
            if (it != m_styles.end()) {
                m_styles.erase(it);
                changed = true;
            }
        } else if (it == m_styles.end()) {
            m_styles.emplace(element.get(), Styled{element, JSText(text, JSAllocator<char>(JS_GetRuntime(ctx)))});
            changed = true;
        } else if (std::string_view(it->second.text) != text) {
            it->second.text.assign(text);
            changed = true;
        }
        if (changed) {
            render.animatedStyleChanged(*element);
        }
    }
}

const JSText* AnimationState::animatedStyle(const Element& element) const {
    auto it = m_styles.find(&element);
    return it == m_styles.end() ? nullptr : &it->second.text;
}

const JSText* AnimationState::animatedStyleOf(JSContext* ctx, const Element& element) {
    const AnimationState* state = find(ctx);
    return state ? state->animatedStyle(element) : nullptr;
}

std::vector<std::pair<std::string, std::string>> AnimationState::valuesUpTo(JSContext* ctx, Element& element, const Animation& animation) {
    const std::unordered_map<const Element*, std::vector<Animation*>> byTarget = this->renderedAnimations(ctx, {&element});
    std::vector<Animation*> stack;
    if (auto it = byTarget.find(&element); it != byTarget.end()) {
        for (Animation* a : it->second) {
            if (!compositeOrderLess(animation, *a)) {
                stack.push_back(a);
            }
        }
    }
    if (std::find(stack.begin(), stack.end(), &animation) == stack.end()) {
        // Past the rendered animations, or removed (Level 1 §4.4.20 adds a removed animation's effects back): its own
        // values over what is below it.
        stack.push_back(const_cast<Animation*>(&animation));
        std::sort(stack.begin(), stack.end(), [](const Animation* a, const Animation* b) { return compositeOrderLess(*a, *b); });
    }
    std::vector<std::pair<std::string, std::string>> values = this->sample(ctx, element, stack, &animation);
    // Only the animation's own target properties are committed, each computed over the stack up to it.
    std::unordered_set<std::string_view> own;
    if (const KeyframeEffect* effect = animation.keyframeEffect()) {
        for (const Keyframe& frame : effect->keyframes()) {
            for (const auto& [name, value] : frame.values) {
                own.insert(std::string_view(*name));
            }
        }
    }
    values.erase(std::remove_if(values.begin(), values.end(), [&](const auto& v) { return !own.count(v.first); }), values.end());
    return values;
}

std::optional<std::string> AnimationState::sampledValue(JSContext* ctx, Element& element, Animation& animation, std::string_view property) {
    for (auto& [name, value] : this->sample(ctx, element, {&animation})) {
        if (name == property) {
            return std::move(value);
        }
    }
    return std::nullopt;
}

void AnimationState::noteUnsupportedPseudoElement() {
    if (m_notedPseudoElement) {
        return;
    }
    m_notedPseudoElement = true;
    Runtime::from(m_ctx).host().diagnostic("unsupported", "KeyframeEffect pseudoElement");
}

} // namespace wr::animation
