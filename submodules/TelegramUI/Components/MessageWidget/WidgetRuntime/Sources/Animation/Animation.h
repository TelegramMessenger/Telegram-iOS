// Animation (V5e plan, Task 3; Web Animations Level 1 §4.4): the timing model's playback control. Pending play and
// pause tasks run in the update step of the next frame (AnimationState::updateAnimations); ready and finished settle
// in queued jobs (Sources/Support/Promises.h); finish and cancel events are queued for the update step.
#pragma once

#include <cstdint>
#include <optional>

#include "Sources/Events/EventTarget.h"
#include "Sources/Support/Bindings.h"
#include "Sources/Support/Promises.h"

namespace wr {

class AnimationEffect;
class AnimationTimeline;
class KeyframeEffect;

class Animation : public EventTarget {
public:
    enum class PlayState : uint8_t { Idle, Running, Paused, Finished };
    enum class ReplaceState : uint8_t { Active, Removed, Persisted };
    enum class PendingTask : uint8_t { None, Play, Pause };

    Animation(JSContext* ctx, uint64_t sequence) : m_ctx(ctx), m_sequence(sequence) {}
    /// `new Animation(effect, timeline)`: an absent timeline (undefined) is document.timeline, null none, anything else
    /// must be an AnimationTimeline (the generator cannot tell an absent nullable from null, so it is `any`).
    static Ref<Animation> construct(JSContext* ctx, OrNull<AnimationEffect> effect, std::optional<Value> timeline);
    /// An animation of `effect` on `timeline`, as Element.animate makes it (not yet playing).
    static Ref<Animation> make(JSContext* ctx, AnimationEffect* effect, AnimationTimeline* timeline);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

    String id(JSContext* ctx) const;
    void setId(JSContext* ctx, String id);
    AnimationEffect* effect(JSContext*) const { return m_effectPayload; }
    void setEffect(JSContext* ctx, OrNull<AnimationEffect> effect);
    AnimationTimeline* timeline(JSContext*) const { return m_timelinePayload; }
    void setTimeline(JSContext* ctx, OrNull<AnimationTimeline> timeline);
    std::optional<double> startTime(JSContext*) const { return m_startTime ? std::optional<double>(*m_startTime == 0 ? 0.0 : *m_startTime) : std::nullopt; }
    void setStartTime(JSContext* ctx, std::optional<double> startTime);
    std::optional<double> currentTime(JSContext*) const { return this->currentTime(); }
    void setCurrentTime(JSContext* ctx, std::optional<double> seekTime);
    double playbackRate(JSContext*) const { return m_playbackRate; }
    void setPlaybackRate(JSContext* ctx, double rate);
    String playState(JSContext* ctx) const;
    String replaceState(JSContext* ctx) const;
    bool pending(JSContext*) const { return m_pendingTask != PendingTask::None; }
    Value ready(JSContext* ctx) const { return Value::dup(ctx, m_ready.promise.value); }
    Value finished(JSContext* ctx) const { return Value::dup(ctx, m_finished.promise.value); }
    /// Virtual: a CSS animation or transition also queues its cancel event (V5f).
    virtual void cancel(JSContext* ctx);
    void finish(JSContext* ctx);
    /// Virtual: a CSSAnimation's play() and pause() also take its play state over from style (V5f).
    virtual void play(JSContext* ctx) { this->playWithAutoRewind(ctx, true); }
    virtual void pause(JSContext* ctx);
    void updatePlaybackRate(JSContext* ctx, double rate);
    void reverse(JSContext* ctx);
    void persist(JSContext* ctx);
    /// Level 1 §4.4.20: the values this animation and those below it give the target now, written into its style
    /// attribute (setProperty). InvalidStateError when the target is not connected.
    void commitStyles(JSContext* ctx);

    // Native.
    /// Level 1 §4.4.4 "calculating the current time".
    std::optional<double> currentTime() const;
    PlayState state() const;
    ReplaceState replace() const { return m_replaceState; }
    /// Creation order: the composite order of script animations.
    uint64_t sequence() const { return m_sequence; }
    /// The class of the composite order (CSS Animations 2, CSS Transitions 2): 0 a CSS transition, 1 a CSS animation,
    /// 2 a script animation; within a class, creation order (compositeOrderLess).
    virtual int compositeClass() const { return 2; }
    /// The effect as a KeyframeEffect, or nullptr.
    KeyframeEffect* keyframeEffect() const;
    /// The pending playback rate if there is one, else the playback rate.
    double effectivePlaybackRate() const { return m_pendingPlaybackRate.value_or(m_playbackRate); }
    /// Level 1 §5.6 "relevant": in effect or about to be, or paused while pending.
    bool isRelevant() const;
    /// Its time moves (a running animation on a timeline), or it waits for a frame (a pending task on a timeline).
    bool wantsFrame() const;
    /// The update step: runs a pending task that is ready (its timeline has a time), then updates the finished state.
    void update(JSContext* ctx);
    /// After update(), in the same step: a CSS animation or transition queues the events its phase change makes (V5f).
    virtual void afterUpdate(JSContext*) {}
    /// Level 1 §4.4.14.
    void updateFinishedState(JSContext* ctx, bool didSeek, bool synchronouslyNotify);
    /// The effect's timing or keyframes changed: the finished state follows.
    void effectChanged(JSContext* ctx);
    /// Level 1 §5.5: replaced by later animations of the same properties; a remove event is queued.
    void markRemoved(JSContext* ctx);
    /// Filling: in effect outside its active interval or at its end (the replace check's candidates).
    bool isFilling() const;
    /// Nothing can come of it any more without script touching it, and nothing pending: idle; removed (it renders
    /// nothing) and paused, or removed and finished with `finished` settled; or finished and out of effect with
    /// `finished` settled. AnimationState lets such an animation go.
    bool isReleasable() const;
    /// Whether AnimationState holds it.
    bool isTracked() const { return m_tracked; }
    void setTracked(bool tracked) { m_tracked = tracked; }

protected:
    /// Animation::make's body: the timeline, `ready` resolved and `finished` pending, the effect, tracked.
    void initialize(JSContext* ctx, AnimationEffect* effect, AnimationTimeline* timeline);
    /// Level 1's "play an animation" (play() is it with auto-rewind).
    void playWithAutoRewind(JSContext* ctx, bool autoRewind);

private:
    std::optional<double> timelineTime() const;
    double effectEnd() const;
    void applyPendingPlaybackRate();
    void silentlySetCurrentTime(JSContext* ctx, std::optional<double> seekTime);
    void commitPendingPlay(JSContext* ctx, double readyTime);
    void commitPendingPause(JSContext* ctx, double readyTime);
    /// Resolves the current ready promise with the animation.
    void resolveReady(JSContext* ctx);
    /// Level 1's finish notification steps.
    void finishNotification(JSContext* ctx);
    static JSValue finishNotificationJob(JSContext* ctx, int argc, JSValueConst* argv);
    /// A state change: the frames are looked at again in the next update.
    void noteChange();

    JSContext* m_ctx;
    uint64_t m_sequence;
    Held m_id;
    Held m_effect;
    AnimationEffect* m_effectPayload = nullptr;
    Held m_timeline;
    AnimationTimeline* m_timelinePayload = nullptr;
    std::optional<double> m_startTime;
    std::optional<double> m_holdTime;
    std::optional<double> m_previousCurrentTime;
    double m_playbackRate = 1;
    std::optional<double> m_pendingPlaybackRate;
    PendingTask m_pendingTask = PendingTask::None;
    ReplaceState m_replaceState = ReplaceState::Active;
    PromiseSlot m_ready;
    PromiseSlot m_finished;
    bool m_finishNotificationQueued = false;
    bool m_tracked = false;
};

/// Composite order: a's effects apply before b's (the class, then creation order).
inline bool compositeOrderLess(const Animation& a, const Animation& b) {
    const int ca = a.compositeClass(), cb = b.compositeClass();
    return ca != cb ? ca < cb : a.sequence() < b.sequence();
}

} // namespace wr
