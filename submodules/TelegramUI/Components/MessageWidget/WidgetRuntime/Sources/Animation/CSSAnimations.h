// CSSAnimation and CSSTransition (V5f plan, Tasks 3–5; CSS Animations 2 §6, CSS Transitions 2 §3): the Animations the
// style-change step makes for an element's `animation` and `transition` declarations, and the state that step keeps.
// Script cannot construct them; it controls them as any Animation, and its play() or pause() takes a CSS animation's
// play state over from style.
#pragma once

#include <memory>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "Sources/Animation/Animation.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/Animation/CSSAnimationRules.h"
#include "Sources/Support/Allocator.h"

namespace wr {

class Element;
class RenderTree;

class CSSAnimation final : public Animation {
public:
    CSSAnimation(JSContext* ctx, uint64_t sequence) : Animation(ctx, sequence) {}
    /// A new CSS animation of `rule` on `owner`, playing or paused as `spec` says.
    static Ref<CSSAnimation> make(JSContext* ctx, Element& owner, const animation::CSSAnimationSpec& spec,
                                  std::shared_ptr<const animation::CSSKeyframesRule> rule);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

    String animationName(JSContext* ctx) const { return String::fromUTF8(ctx, m_spec.name); }
    void play(JSContext* ctx) override;
    void pause(JSContext* ctx) override;
    void cancel(JSContext* ctx) override;
    void afterUpdate(JSContext* ctx) override;
    int compositeClass() const override { return 1; }

    /// The style gave `spec` and `rule` again: an equal pair changes nothing; else the effect's keyframes and timing
    /// follow, and the play state too unless script took it over.
    void applyStyle(JSContext* ctx, const animation::CSSAnimationSpec& spec, std::shared_ptr<const animation::CSSKeyframesRule> rule);
    const animation::CSSAnimationSpec& spec() const { return m_spec; }
    Element* owner() const;

private:
    Held m_owner;
    animation::CSSAnimationSpec m_spec;
    std::shared_ptr<const animation::CSSKeyframesRule> m_rule;
    /// False once script called play() or pause() (CSS Animations 2 §5).
    bool m_styleControlsPlayState = true;
    /// The phase and iteration at the last update step that had no pending task: what the events compare against
    /// (CSS Animations 2 §4.2). 0 idle, 1 before, 2 active, 3 after.
    uint8_t m_previousPhase = 0;
    double m_previousIteration = 0;
};

class CSSTransition final : public Animation {
public:
    CSSTransition(JSContext* ctx, uint64_t sequence) : Animation(ctx, sequence) {}
    /// A new transition of `property` on `owner` from `from` to `to`, playing: two keyframes, the spec's easing on the
    /// effect, its duration and delay, `fill: backwards` (CSS Transitions 2 §3.1).
    static Ref<CSSTransition> make(JSContext* ctx, Element& owner, std::string_view property, std::string_view from,
                                   std::string_view to, const animation::CSSTransitionSpec& spec);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

    String transitionProperty(JSContext* ctx) const { return String::fromUTF8(ctx, m_property ? std::string_view(*m_property) : ""); }
    int compositeClass() const override { return 0; }
    void cancel(JSContext* ctx) override;
    void afterUpdate(JSContext* ctx) override;
    Element* owner() const;
    /// The value it ends at.
    std::string_view to() const { return m_to ? std::string_view(*m_to) : std::string_view(); }

private:
    Held m_owner;
    SharedText m_property;
    SharedText m_to;
    /// The phase at the last update step (CSS Transitions 2 §5): 0 idle, 1 pending or before, 2 active, 3 after.
    uint8_t m_previousPhase = 0;
};

namespace animation {

/// The CSS animations and transitions of the elements that declare them: what the style-change step keeps between
/// flushes (AnimationState owns it).
class CSSAnimationState {
public:
    CSSAnimationState() = default;
    /// The step: the rules again after a build; every element `change` names (or every rendered one) follows its
    /// declarations; an element no longer in the document loses its animations.
    void stylesResolved(JSContext* ctx, RenderTree& render, const StyleChange& change);

private:
    struct ElementAnimations {
        Ref<Element> element;
        std::vector<Ref<CSSAnimation>> animations;
        /// The running (or not yet finished) transition of each property.
        std::vector<std::pair<std::string, Ref<CSSTransition>>> transitions;
        /// The watched declarations at the last style change, kept while the element declares a transition or one
        /// runs: the next change's before-change style.
        DeclaredValues declared;
        bool tracksTransitions = false;
    };
    /// `element`'s animations and transitions follow its declarations now; `before` is its before-change style when
    /// nothing tracked it.
    void update(JSContext* ctx, RenderTree& render, Element& element, const DeclaredValues* before);
    /// The transitions part of update().
    void updateTransitions(JSContext* ctx, Element& element, ElementAnimations& entry, const DeclaredLookup& declared,
                           const DeclaredValues* before, bool declaresTransitions);
    /// Cancels every animation of an entry.
    static void cancelAll(JSContext* ctx, ElementAnimations& entry);

    CSSKeyframesRules m_rules;
    /// The sheets m_rules was read from, as a hash of their text (FNV-1a).
    uint64_t m_sheetsHash = 0;
    bool m_rulesParsed = false;
    std::unordered_map<const Element*, ElementAnimations> m_elements;
};

} // namespace animation
} // namespace wr
