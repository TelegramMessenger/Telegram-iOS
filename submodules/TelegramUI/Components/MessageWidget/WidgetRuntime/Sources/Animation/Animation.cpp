#include "Sources/Animation/Animation.h"

#include <algorithm>
#include <cmath>

#include "Generated/Bindings.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/Animation/KeyframeEffect.h"
#include "Sources/Animation/Timeline.h"
#include "Sources/DOM/DOM.h"
#include "Sources/DOM/StyleDeclaration.h"
#include "Sources/Support/Errors.h"

namespace wr {

using animation::AnimationState;

namespace {

const char* const kAbortMessage = "The animation was cancelled";

/// Times and rates script reads are never -0 (a reversed animation at 0 computes 0 × -1): browsers give +0, and WPT
/// compares with Object.is.
double positiveZero(double v) { return v == 0 ? 0.0 : v; }

} // namespace

Ref<Animation> Animation::construct(JSContext* ctx, OrNull<AnimationEffect> effect, std::optional<Value> timeline) {
    AnimationTimeline* chosen = nullptr;
    if (!timeline) {
        chosen = &AnimationState::of(ctx).documentTimeline(ctx);
    } else if (!JS_IsNull(timeline->get())) {
        chosen = convert<AnimationTimeline*>(ctx, timeline->get(), ArgInfo{"Animation", "constructor", 1});
    }
    return make(ctx, effect.ptr, chosen);
}

Ref<Animation> Animation::make(JSContext* ctx, AnimationEffect* effect, AnimationTimeline* timeline) {
    Ref<Animation> animation = create<Animation>(ctx, idl::kAnimation, ctx, AnimationState::of(ctx).nextSequence());
    animation->initialize(ctx, effect, timeline);
    return animation;
}

void Animation::initialize(JSContext* ctx, AnimationEffect* effect, AnimationTimeline* timeline) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    if (timeline) {
        m_timeline.set(rt, timeline->newRef(ctx));
        m_timelinePayload = timeline;
    }
    makeResolved(ctx, m_ready, this->object());
    makePending(ctx, m_finished, true);
    if (effect) {
        this->setEffect(ctx, OrNull<AnimationEffect>{effect});
    }
    AnimationState::of(ctx).track(ctx, *this);
}

void Animation::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_id.mark(rt, mark);
    m_effect.mark(rt, mark);
    m_timeline.mark(rt, mark);
    m_ready.mark(rt, mark);
    m_finished.mark(rt, mark);
    EventTarget::trace(rt, mark);
}

void Animation::dispose(JSRuntime* rt) {
    // The effect may be gone already (a garbage cycle): only what this payload holds is released.
    m_effectPayload = nullptr;
    m_timelinePayload = nullptr;
    m_id.clear(rt);
    m_effect.clear(rt);
    m_timeline.clear(rt);
    m_ready.clear(rt);
    m_finished.clear(rt);
    EventTarget::dispose(rt);
}

String Animation::id(JSContext* ctx) const {
    return m_id.isUndefined() ? String::fromUTF8(ctx, "") : String::adopt(ctx, JS_DupValue(ctx, m_id.value));
}

void Animation::setId(JSContext* ctx, String id) { m_id.set(JS_GetRuntime(ctx), id.toJS(ctx)); }

KeyframeEffect* Animation::keyframeEffect() const {
    return m_effectPayload ? dynamic_cast<KeyframeEffect*>(m_effectPayload) : nullptr;
}

// ── time ──

std::optional<double> Animation::timelineTime() const {
    return m_timelinePayload ? m_timelinePayload->currentTime(m_ctx) : std::nullopt;
}

double Animation::effectEnd() const { return m_effectPayload ? animation::endTime(m_effectPayload->timing()) : 0; }

std::optional<double> Animation::currentTime() const {
    if (m_holdTime) {
        return positiveZero(*m_holdTime);
    }
    const std::optional<double> tt = this->timelineTime();
    if (!tt || !m_startTime) {
        return std::nullopt;
    }
    return positiveZero((*tt - *m_startTime) * m_playbackRate);
}

Animation::PlayState Animation::state() const {
    const std::optional<double> ct = this->currentTime();
    if (!ct && !m_startTime && m_pendingTask == PendingTask::None) {
        return PlayState::Idle;
    }
    if (m_pendingTask == PendingTask::Pause || (!m_startTime && m_pendingTask != PendingTask::Play)) {
        return PlayState::Paused;
    }
    const double rate = this->effectivePlaybackRate();
    if (ct && ((rate > 0 && *ct >= this->effectEnd()) || (rate < 0 && *ct <= 0))) {
        return PlayState::Finished;
    }
    return PlayState::Running;
}

String Animation::playState(JSContext* ctx) const {
    switch (this->state()) {
    case PlayState::Idle: return String::fromUTF8(ctx, "idle");
    case PlayState::Running: return String::fromUTF8(ctx, "running");
    case PlayState::Paused: return String::fromUTF8(ctx, "paused");
    case PlayState::Finished: return String::fromUTF8(ctx, "finished");
    }
    return String::fromUTF8(ctx, "idle");
}

String Animation::replaceState(JSContext* ctx) const {
    switch (m_replaceState) {
    case ReplaceState::Active: return String::fromUTF8(ctx, "active");
    case ReplaceState::Removed: return String::fromUTF8(ctx, "removed");
    case ReplaceState::Persisted: return String::fromUTF8(ctx, "persisted");
    }
    return String::fromUTF8(ctx, "active");
}

bool Animation::isRelevant() const {
    if (!m_effectPayload || m_replaceState == ReplaceState::Removed) {
        return false;
    }
    if (m_pendingTask == PendingTask::Pause) {
        return true;
    }
    const animation::ComputedTiming t = animation::computeTiming(m_effectPayload->timing(), this->currentTime(), m_playbackRate >= 0);
    using Phase = animation::ComputedTiming::Phase;
    if (t.phase == Phase::None) {
        return false;
    }
    const bool current = t.phase == Phase::Active || (t.phase == Phase::Before && m_playbackRate > 0) ||
                         (t.phase == Phase::After && m_playbackRate < 0);
    return current || t.activeTime.has_value();
}

bool Animation::wantsFrame() const {
    if (!m_timelinePayload) {
        return false;
    }
    if (m_pendingTask != PendingTask::None) {
        return true;
    }
    return m_playbackRate != 0 && this->state() == PlayState::Running;
}

void Animation::noteChange() {
    AnimationState& state = AnimationState::of(m_ctx);
    if (!m_tracked) {
        // Released while nothing could come of it; script touched it again.
        state.track(m_ctx, *this);
    }
    state.requestFrame();
    if (KeyframeEffect* effect = this->keyframeEffect()) {
        state.noteTarget(effect->targetElement());
    }
}

void Animation::applyPendingPlaybackRate() {
    if (m_pendingPlaybackRate) {
        m_playbackRate = *m_pendingPlaybackRate;
        m_pendingPlaybackRate.reset();
    }
}

void Animation::resolveReady(JSContext* ctx) {
    // Level 1 resolves the ready promise synchronously (the pending task's last steps, or the setter's), and finished
    // after it: a queued resolution would let finished's reactions run first.
    resolveNow(ctx, m_ready, this->object());
}

// ── Level 1 §4.4 ──

void Animation::setTimeline(JSContext* ctx, OrNull<AnimationTimeline> timeline) {
    // Level 1 §4.4.1: the start time stays (a running animation runs on against the new timeline); a resolved start
    // time makes the hold time unresolved.
    if (timeline.ptr == m_timelinePayload) {
        return;
    }
    m_timeline.set(JS_GetRuntime(ctx), timeline.ptr ? timeline.ptr->newRef(ctx) : JS_UNDEFINED);
    m_timelinePayload = timeline.ptr;
    if (m_startTime) {
        m_holdTime.reset();
    }
    this->updateFinishedState(ctx, false, false);
    this->noteChange();
}

void Animation::setEffect(JSContext* ctx, OrNull<AnimationEffect> effect) {
    if (effect.ptr == m_effectPayload) {
        return;
    }
    // The old effect's target loses this animation's values at the next flush (noteChange below notes the new one).
    if (KeyframeEffect* old = this->keyframeEffect()) {
        AnimationState::of(ctx).noteTarget(old->targetElement());
    }
    if (m_effectPayload) {
        m_effectPayload->setAnimation(ctx, nullptr);
    }
    if (effect.ptr) {
        if (Animation* previous = effect.ptr->animation()) {
            previous->setEffect(ctx, OrNull<AnimationEffect>{});
        }
    }
    m_effect.set(JS_GetRuntime(ctx), effect.ptr ? effect.ptr->newRef(ctx) : JS_UNDEFINED);
    m_effectPayload = effect.ptr;
    if (effect.ptr) {
        effect.ptr->setAnimation(ctx, this);
    }
    this->updateFinishedState(ctx, false, false);
    this->noteChange();
}

void Animation::silentlySetCurrentTime(JSContext*, std::optional<double> seekTime) {
    const std::optional<double> tt = this->timelineTime();
    if (m_holdTime || !m_startTime || !tt || m_playbackRate == 0) {
        m_holdTime = seekTime;
    } else {
        m_startTime = *tt - *seekTime / m_playbackRate;
    }
    if (!tt) {
        m_startTime.reset();
    }
    m_previousCurrentTime.reset();
}

void Animation::setCurrentTime(JSContext* ctx, std::optional<double> seekTime) {
    if (!seekTime) {
        if (this->currentTime()) {
            throw TypeError{"currentTime cannot be set to null"};
        }
        return;
    }
    this->silentlySetCurrentTime(ctx, seekTime);
    if (m_pendingTask == PendingTask::Pause) {
        m_holdTime = seekTime;
        this->applyPendingPlaybackRate();
        m_startTime.reset();
        m_pendingTask = PendingTask::None;
        this->resolveReady(ctx);
    }
    this->updateFinishedState(ctx, true, false);
    this->noteChange();
}

void Animation::setStartTime(JSContext* ctx, std::optional<double> startTime) {
    const std::optional<double> tt = this->timelineTime();
    if (!tt && startTime) {
        m_holdTime.reset();
    }
    const std::optional<double> previous = this->currentTime();
    this->applyPendingPlaybackRate();
    m_startTime = startTime;
    if (startTime) {
        if (m_playbackRate != 0) {
            m_holdTime.reset();
        }
    } else {
        m_holdTime = previous;
    }
    if (m_pendingTask != PendingTask::None) {
        m_pendingTask = PendingTask::None;
        this->resolveReady(ctx);
    }
    this->updateFinishedState(ctx, true, false);
    this->noteChange();
}

void Animation::setPlaybackRate(JSContext* ctx, double rate) {
    m_pendingPlaybackRate.reset();
    const std::optional<double> previous = this->currentTime();
    m_playbackRate = rate;
    if (previous) {
        this->setCurrentTime(ctx, previous);
    }
    this->noteChange();
}

void Animation::playWithAutoRewind(JSContext* ctx, bool autoRewind) {
    const bool abortedPause = m_pendingTask == PendingTask::Pause;
    bool hasPendingReadyPromise = false;
    std::optional<double> seekTime;
    const double rate = this->effectivePlaybackRate();
    const std::optional<double> ct = this->currentTime();
    const double end = this->effectEnd();
    if (autoRewind) {
        if (rate > 0 && (!ct || *ct < 0 || *ct >= end)) {
            seekTime = 0;
        } else if (rate < 0 && (!ct || *ct <= 0 || *ct > end)) {
            if (std::isinf(end)) {
                throw DOMError{"InvalidStateError", "cannot play a reversed animation with infinite duration"};
            }
            seekTime = end;
        }
    }
    if (!seekTime && rate == 0 && !ct) {
        seekTime = 0;
    }
    if (seekTime) {
        m_holdTime = seekTime;
    }
    if (m_holdTime) {
        m_startTime.reset();
    }
    if (m_pendingTask != PendingTask::None) {
        m_pendingTask = PendingTask::None;
        hasPendingReadyPromise = true;
    }
    if (!m_holdTime && !seekTime && !abortedPause && !m_pendingPlaybackRate) {
        return;
    }
    if (!hasPendingReadyPromise) {
        makePending(ctx, m_ready, false);
    }
    m_pendingTask = PendingTask::Play;
    // A removed animation stays removed (Level 1: persist() is what brings one back).
    this->updateFinishedState(ctx, false, false);
    this->noteChange();
}

void Animation::pause(JSContext* ctx) {
    if (m_pendingTask == PendingTask::Pause || this->state() == PlayState::Paused) {
        return;
    }
    std::optional<double> seekTime;
    if (!this->currentTime()) {
        if (m_playbackRate >= 0) {
            seekTime = 0;
        } else {
            const double end = this->effectEnd();
            if (std::isinf(end)) {
                throw DOMError{"InvalidStateError", "cannot pause a reversed animation with infinite duration"};
            }
            seekTime = end;
        }
    }
    if (seekTime) {
        m_holdTime = seekTime;
        m_startTime.reset();
    }
    bool hasPendingReadyPromise = false;
    if (m_pendingTask == PendingTask::Play) {
        m_pendingTask = PendingTask::None;
        hasPendingReadyPromise = true;
    }
    if (!hasPendingReadyPromise) {
        makePending(ctx, m_ready, false);
    }
    m_pendingTask = PendingTask::Pause;
    this->updateFinishedState(ctx, false, false);
    this->noteChange();
}

void Animation::commitPendingPlay(JSContext* ctx, double readyTime) {
    if (m_holdTime) {
        this->applyPendingPlaybackRate();
        m_startTime = m_playbackRate == 0 ? readyTime : readyTime - *m_holdTime / m_playbackRate;
        if (m_playbackRate != 0) {
            m_holdTime.reset();
        }
    } else if (m_startTime && m_pendingPlaybackRate) {
        const double currentTimeToMatch = (readyTime - *m_startTime) * m_playbackRate;
        this->applyPendingPlaybackRate();
        if (m_playbackRate == 0) {
            m_holdTime = currentTimeToMatch;
        }
        m_startTime = m_playbackRate == 0 ? readyTime : readyTime - currentTimeToMatch / m_playbackRate;
    }
    m_pendingTask = PendingTask::None;
    this->resolveReady(ctx);
    this->updateFinishedState(ctx, false, false);
    this->noteChange();
}

void Animation::commitPendingPause(JSContext* ctx, double readyTime) {
    if (m_startTime && !m_holdTime) {
        m_holdTime = (readyTime - *m_startTime) * m_playbackRate;
    }
    this->applyPendingPlaybackRate();
    m_startTime.reset();
    m_pendingTask = PendingTask::None;
    this->resolveReady(ctx);
    this->updateFinishedState(ctx, false, false);
    this->noteChange();
}

void Animation::update(JSContext* ctx) {
    if (m_pendingTask != PendingTask::None) {
        if (const std::optional<double> tt = this->timelineTime()) {
            if (m_pendingTask == PendingTask::Play) {
                this->commitPendingPlay(ctx, *tt);
            } else {
                this->commitPendingPause(ctx, *tt);
            }
            return;
        }
    }
    this->updateFinishedState(ctx, false, false);
}

void Animation::updateFinishedState(JSContext* ctx, bool didSeek, bool synchronouslyNotify) {
    const std::optional<double> tt = this->timelineTime();
    std::optional<double> unconstrained;
    if (didSeek) {
        unconstrained = this->currentTime();
    } else if (tt && m_startTime) {
        unconstrained = (*tt - *m_startTime) * m_playbackRate;
    }
    if (unconstrained && m_startTime && m_pendingTask == PendingTask::None) {
        const double end = this->effectEnd();
        if (m_playbackRate > 0 && *unconstrained >= end) {
            m_holdTime = didSeek ? *unconstrained : (!m_previousCurrentTime ? end : std::max(*m_previousCurrentTime, end));
        } else if (m_playbackRate < 0 && *unconstrained <= 0) {
            m_holdTime = didSeek ? *unconstrained : (!m_previousCurrentTime ? 0.0 : std::min(*m_previousCurrentTime, 0.0));
        } else if (m_playbackRate != 0 && tt) {
            if (didSeek && m_holdTime) {
                m_startTime = *tt - *m_holdTime / m_playbackRate;
            }
            m_holdTime.reset();
        }
    }
    m_previousCurrentTime = this->currentTime();
    const bool finishedNow = this->state() == PlayState::Finished;
    if (finishedNow && !m_finished.settled) {
        if (synchronouslyNotify) {
            this->finishNotification(ctx);
        } else if (!m_finishNotificationQueued) {
            JSValueConst argv[1] = {this->object()};
            if (JS_EnqueueJob(ctx, finishNotificationJob, 1, argv) < 0) {
                throw Thrown{};
            }
            m_finishNotificationQueued = true;
        }
    }
    if (!finishedNow && m_finished.settled) {
        makePending(ctx, m_finished, true);
    }
}

JSValue Animation::finishNotificationJob(JSContext* ctx, int, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        if (auto* animation = dynamic_cast<Animation*>(payloadOf(ctx, argv[0]))) {
            animation->finishNotification(ctx);
        }
        return JS_UNDEFINED;
    });
}

void Animation::finishNotification(JSContext* ctx) {
    m_finishNotificationQueued = false;
    if (this->state() != PlayState::Finished || m_finished.settled) {
        return;
    }
    // Level 1: the finish event is scheduled when the effect end was reached (start time + end / rate, or the start time
    // when reversed), else now; its timelineTime is now.
    const std::optional<double> tt = this->timelineTime();
    std::optional<double> scheduled = tt;
    if (m_startTime && m_playbackRate != 0) {
        scheduled = m_playbackRate > 0 ? *m_startTime + this->effectEnd() / m_playbackRate : *m_startTime;
    }
    const std::optional<double> ct = this->currentTime();
    // The event is queued before the resolution, whose `then` read may run script that changes this animation.
    AnimationState::of(ctx).queueEvent(ctx, *this, "finish", ct, tt, scheduled);
    resolveNow(ctx, m_finished, this->object());
}

void Animation::finish(JSContext* ctx) {
    const double rate = this->effectivePlaybackRate();
    const double end = this->effectEnd();
    if (rate == 0 || (rate > 0 && std::isinf(end))) {
        throw DOMError{"InvalidStateError", "cannot finish an animation with a zero playback rate or infinite duration"};
    }
    this->applyPendingPlaybackRate();
    const double limit = m_playbackRate > 0 ? end : 0;
    this->silentlySetCurrentTime(ctx, limit);
    const std::optional<double> tt = this->timelineTime();
    if (!m_startTime && tt) {
        m_startTime = *tt - limit / m_playbackRate;
    }
    if (m_pendingTask == PendingTask::Pause && m_startTime) {
        m_holdTime.reset();
        m_pendingTask = PendingTask::None;
        this->resolveReady(ctx);
    }
    if (m_pendingTask == PendingTask::Play && m_startTime) {
        m_pendingTask = PendingTask::None;
        this->resolveReady(ctx);
    }
    this->updateFinishedState(ctx, true, true);
    this->noteChange();
}

void Animation::cancel(JSContext* ctx) {
    if (this->state() != PlayState::Idle) {
        if (m_pendingTask != PendingTask::None) {
            m_pendingTask = PendingTask::None;
            this->applyPendingPlaybackRate();
            queueRejectWithDOMException(ctx, m_ready, "AbortError", kAbortMessage);
            makeResolved(ctx, m_ready, this->object());
        }
        queueRejectWithDOMException(ctx, m_finished, "AbortError", kAbortMessage);
        makePending(ctx, m_finished, true);
        if (const std::optional<double> tt = this->timelineTime()) {
            AnimationState::of(ctx).queueEvent(ctx, *this, "cancel", std::nullopt, tt, tt);
        }
    }
    m_holdTime.reset();
    m_startTime.reset();
    this->noteChange();
}

void Animation::reverse(JSContext* ctx) {
    if (!this->timelineTime()) {
        throw DOMError{"InvalidStateError", "cannot reverse an animation with no active timeline"};
    }
    const std::optional<double> original = m_pendingPlaybackRate;
    m_pendingPlaybackRate = positiveZero(-this->effectivePlaybackRate());
    try {
        this->playWithAutoRewind(ctx, true);
    } catch (...) {
        m_pendingPlaybackRate = original;
        throw;
    }
}

void Animation::updatePlaybackRate(JSContext* ctx, double rate) {
    const PlayState previous = this->state();
    m_pendingPlaybackRate = rate;
    if (m_pendingTask != PendingTask::None) {
        this->noteChange();
        return;
    }
    if (previous == PlayState::Idle || previous == PlayState::Paused || !this->currentTime()) {
        // Level 1 §4.4.18.1: idle, paused, or no current time: the rate applies now.
        this->applyPendingPlaybackRate();
        this->noteChange();
        return;
    }
    switch (previous) {
    case PlayState::Idle:
    case PlayState::Paused:
        break;
    case PlayState::Finished: {
        const std::optional<double> tt = this->timelineTime();
        if (tt && m_startTime) {
            const double unconstrained = (*tt - *m_startTime) * m_playbackRate;
            m_startTime = rate == 0 ? *tt : *tt - unconstrained / rate;
        }
        this->applyPendingPlaybackRate();
        this->updateFinishedState(ctx, false, false);
        break;
    }
    case PlayState::Running:
        this->playWithAutoRewind(ctx, false);
        break;
    }
    this->noteChange();
}

void Animation::persist(JSContext*) {
    m_replaceState = ReplaceState::Persisted;
    this->noteChange();
}

bool Animation::isFilling() const {
    if (!m_effectPayload) {
        return false;
    }
    const animation::ComputedTiming t = animation::computeTiming(m_effectPayload->timing(), this->currentTime(), m_playbackRate >= 0);
    return t.activeTime.has_value();
}

bool Animation::isReleasable() const {
    if (m_pendingTask != PendingTask::None || m_finishNotificationQueued) {
        return false;
    }
    const PlayState s = this->state();
    if (s == PlayState::Idle) {
        return true;
    }
    // A removed animation renders nothing, so its fill keeps nothing; but one played again still runs its timing to a
    // finish event and its `finished` promise, so it is kept while running (fix-wave review I1).
    if (m_replaceState == ReplaceState::Removed) {
        return s == PlayState::Paused || (s == PlayState::Finished && m_finished.settled);
    }
    return s == PlayState::Finished && m_finished.settled && !this->isFilling();
}

void Animation::markRemoved(JSContext* ctx) {
    m_replaceState = ReplaceState::Removed;
    AnimationState::of(ctx).queueEvent(ctx, *this, "remove", this->currentTime(), this->timelineTime(), this->timelineTime());
    this->noteChange();
}

void Animation::commitStyles(JSContext* ctx) {
    KeyframeEffect* effect = this->keyframeEffect();
    Element* target = effect ? effect->targetElement() : nullptr;
    if (!target) {
        return;
    }
    if (effect->targetsPseudoElement()) {
        throw DOMError{"NoModificationAllowedError", "a pseudo-element has no style attribute"};
    }
    if (!target->connected(ctx)) {
        throw DOMError{"InvalidStateError", "target is not being rendered"};
    }
    const std::vector<std::pair<std::string, std::string>> values = AnimationState::of(ctx).valuesUpTo(ctx, *target, *this);
    if (values.empty()) {
        return;
    }
    CSSStyleDeclaration* style = target->style(ctx);
    for (const auto& [name, value] : values) {
        style->setProperty(ctx, String::fromUTF8(ctx, name), LegacyNullToEmptyString(String::fromUTF8(ctx, value)),
                           LegacyNullToEmptyString(String::fromUTF8(ctx, "")));
    }
}

void Animation::effectChanged(JSContext* ctx) {
    this->updateFinishedState(ctx, false, false);
    this->noteChange();
}

} // namespace wr
