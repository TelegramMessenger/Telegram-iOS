// A runtime's Web Animations state (V5e plan, Tasks 2–4 and 6), owned by HostState and made on first use: the document
// timeline and its time, the animations the update step visits, and the events it dispatches.
#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "quickjs.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/PlatformObject.h"
#include "Sources/Support/Values.h"

namespace wr {

class Animation;
class DocumentTimeline;
class Element;
class RenderTree;

namespace animation {

/// What a flush resolved styles for again (V5f plan, Task 2; RenderTree::pendingStyleChange): every rendered element, or
/// these.
/// One element's declared values of the watched properties (kWatchedProperties), as written; an undeclared one absent.
using DeclaredValues = std::vector<std::pair<std::string, std::string>>;

struct StyleChange {
    bool all = false;
    std::vector<Ref<Element>> elements;
    /// Nodes left the rendered tree (their elements' CSS animations end).
    bool removed = false;
    /// The declared values `elements` had before the change, read from the published tree before it was patched: the
    /// before-change style of an element no transition tracked yet (CSS Transitions 1).
    std::vector<std::pair<const Element*, DeclaredValues>> before;
};

/// The reference renderer's initial value of a property (opacity 1, transform none, …), or empty.
std::string_view initialValue(std::string_view property);

class CSSAnimationState;

class AnimationState {
public:
    explicit AnimationState(JSContext* ctx);
    ~AnimationState();
    AnimationState(const AnimationState&) = delete;
    AnimationState& operator=(const AnimationState&) = delete;
    /// The context's state, made on first use (HostState::animationSlot()).
    static AnimationState& of(JSContext* ctx);
    /// The context's state if it was made.
    static AnimationState* find(JSContext* ctx);

    /// The document timeline's time: the last frame's timestamp, 0 before the first.
    double documentTime() const { return m_documentTime; }
    /// document.timeline (origin 0), made on first use.
    DocumentTimeline& documentTimeline(JSContext* ctx);
    uint64_t nextSequence() { return ++m_sequence; }

    /// Holds `animation` for the update step (counted: a playing animation is kept alive with nobody holding it).
    void track(JSContext* ctx, Animation& animation);
    /// The animations held.
    size_t liveCount() const { return m_animations.size(); }

    /// HTML "update animations and send events", its first half: the document time becomes `timestamp`, every pending
    /// task whose timeline has a time runs, and every animation's finished state is updated. The caller then performs a
    /// microtask checkpoint and dispatchEvents().
    void updateAnimations(JSContext* ctx, double timestamp);
    /// The queued events, sorted by their scheduled event time (null first), then composite order, then the order
    /// queued (Level 1 §4.2.1).
    void dispatchEvents(JSContext* ctx);
    /// At most kMaxQueuedEvents are queued for a frame; later ones are dropped (the reference's MAX_EVENTS_PER_FRAME).
    /// `scheduledTime`: when the event happened in the timeline's time, which orders it.
    void queueEvent(JSContext* ctx, Animation& animation, const char* type, std::optional<double> currentTime,
                    std::optional<double> timelineTime, std::optional<double> scheduledTime);
    /// After the frame's events: lets go of every animation nothing can come of (Animation::isReleasable) and no event
    /// is queued for. Script that touches one again tracks it again.
    void release(JSContext* ctx);
    static constexpr size_t kMaxQueuedEvents = 4096;
    enum class CSSEventKind : uint8_t { None, Animation, Transition };
    /// A CSS animation's or transition's event (V5f plan, Task 6), dispatched at `target` (bubbling, not cancelable)
    /// as an AnimationEvent or TransitionEvent, sorted with the others by `scheduledTime` and `animation`'s composite
    /// order. Within the same kMaxQueuedEvents.
    void queueCSSEvent(JSContext* ctx, Animation& animation, Element& target, CSSEventKind kind, const char* type,
                       std::string_view name, double elapsedSeconds, std::optional<double> scheduledTime);

    /// A frame is wanted: an animation changed since the last update step (the step looks again), or one was running
    /// or pending then, or an event is queued. Answered without visiting the animations.
    bool wantsFrame() const { return m_wantsFrame || !m_events.empty(); }
    /// An animation's state changed.
    void requestFrame() { m_wantsFrame = true; }

    /// Element.getAnimations: the relevant animations whose target is `element` (or inside it, with `subtree`), in
    /// composite order.
    std::vector<Ref<Animation>> animationsOf(JSContext* ctx, Element& element, bool subtree);
    /// Document.getAnimations: the relevant animations whose target is connected, in composite order.
    std::vector<Ref<Animation>> documentAnimations(JSContext* ctx);

    /// The style-change step (V5f plan, Task 2), after a flush published styles resolved again: CSS animations and
    /// transitions follow the declarations of `change`'s elements. `render` is the tree that published them.
    void stylesResolved(JSContext* ctx, RenderTree& render, const StyleChange& change);
    /// Tests only: called with every style change stylesResolved is given.
    void setStyleObserverForTesting(std::function<void(const StyleChange&)> observer) { m_styleObserver = std::move(observer); }

    /// Posts the reference's diag `unsupported` / `KeyframeEffect pseudoElement` the first time an effect is given a
    /// pseudo-element (Global Constraints: it is kept and read back, and renders nothing).
    void noteUnsupportedPseudoElement();

    // Rendering (Task 6).
    /// At most this many bytes of declarations reach an element (the builder's cap on a style attribute).
    static constexpr size_t kMaxAnimatedStyleBytes = 16384;
    // At most Limits::renderedAnimations live script animations are rendered, the first ones tracked (the reference's
    // MAX_LIVE_ANIMS: 64 under strict since widget-sandbox v0.3.0, 1,024 under compat); CSS animations and transitions
    // are not counted there. Every live animation together, CSS ones included: at most this many.
    static constexpr size_t kMaxRenderedAnimations = 1024;
    /// At most this many keyframes of an effect, and properties of a keyframe, are rendered.
    static constexpr size_t kMaxRenderedKeyframes = 64;
    static constexpr size_t kMaxRenderedProperties = 64;
    /// `element`'s animated declarations may have changed: the next flush samples it again. Nothing without a render tree.
    void noteTarget(Element* element);
    /// `element`'s style attribute changed: when animations render on it, the next flush samples it again (its inline
    /// declarations are underlying values).
    void styleAttributeChanged(Element& element);
    /// At the start of every flush (RenderTree::flush, so a layout query's too): samples every element noted since the
    /// last one and journals each whose declarations changed (RenderTree::animatedStyleChanged).
    void collectRenderChanges(JSContext* ctx, RenderTree& render);
    /// The declarations last handed out for `element` (`name: value; …`), or nullptr: what the builder puts in
    /// litehtml's animated_style_attribute.
    const JSText* animatedStyle(const Element& element) const;
    static const JSText* animatedStyleOf(JSContext* ctx, const Element& element);
    /// The values the animations up to and including `animation` (composite order) give `element` now, for the
    /// properties `animation` animates, in the order they first appear: what commitStyles writes.
    std::vector<std::pair<std::string, std::string>> valuesUpTo(JSContext* ctx, Element& element, const Animation& animation);
    /// What `animation` alone gives `property` on `element` now (over its underlying value), or nullopt when it gives
    /// nothing: where an interrupted transition is (V5f plan, Task 5).
    std::optional<std::string> sampledValue(JSContext* ctx, Element& element, Animation& animation, std::string_view property);

private:
    /// Level 1 §5.5 "remove replaced animations", after the finished states: of the finished, filling, active animations
    /// with a target, one whose every property a later one (composite order) on the same target also animates is
    /// removed.
    void removeReplaced(JSContext* ctx);
    /// The rendered animations of each element in `targets`, in composite order (the first Limits::renderedAnimations
    /// tracked animations with a target only; the first time one is left out posts the `animation-limit` diag).
    std::unordered_map<const Element*, std::vector<Animation*>> renderedAnimations(JSContext* ctx, const std::unordered_set<const Element*>& targets);
    /// The values `animations` (composite order) give `element`, by property in the order they first appear.
    /// `include` counts even when it is not relevant (commitStyles' removed animation); it still has to be in effect.
    std::vector<std::pair<std::string, std::string>> sample(JSContext* ctx, Element& element, const std::vector<Animation*>& animations,
                                                            const Animation* include = nullptr);

    struct QueuedEvent {
        Ref<Animation> animation;
        Atom type;
        std::optional<double> currentTime;
        std::optional<double> timelineTime;
        std::optional<double> scheduledTime;
        uint64_t order;
        /// A CSS event (V5f): dispatched at `target` as a CSSEventKind event carrying `name` and `elapsedSeconds`;
        /// None is an AnimationPlaybackEvent at the animation.
        CSSEventKind cssKind = CSSEventKind::None;
        Ref<Element> target;
        SharedText name;
        double elapsedSeconds = 0;
    };

    JSContext* m_ctx;
    double m_documentTime = 0;
    Ref<DocumentTimeline> m_timeline;
    Vector<Ref<Animation>> m_animations;
    Vector<QueuedEvent> m_events;
    uint64_t m_sequence = 0;
    uint64_t m_eventOrder = 0;
    bool m_wantsFrame = false;
    bool m_notedPseudoElement = false;
    bool m_notedAnimationLimit = false;
    struct Styled {
        Ref<Element> element;
        JSText text;
    };
    /// What each animated element was last handed (counted references keep the keys alive).
    std::unordered_map<const Element*, Styled> m_styles;
    std::function<void(const StyleChange&)> m_styleObserver;
    /// The CSS animations and transitions (V5f), made by the first style change.
    std::unique_ptr<CSSAnimationState> m_css;
    Vector<Ref<Element>> m_marked;
    std::unordered_set<const Element*> m_markedSet;
};

} // namespace animation
} // namespace wr
