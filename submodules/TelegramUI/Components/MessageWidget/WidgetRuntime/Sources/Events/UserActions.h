// The user-action state and the default actions of a click (M1d plan, Task 3).
// - UserActions is the main document's ElementState for the user-action pseudo-classes: the focused element (:focus,
//   :focus-within on its inclusive ancestors), the element under the last primary pointer down (:hover on its inclusive
//   ancestors; it stays after the up, as touch browsers keep it), and the elements pressed (:active, each while a
//   press on it is down: one entry per press, which only that press's end removes, so a second finger on an element
//   holds it after the first lifts, even when the element left the document between their downs). A
//   change tells the render tree (RenderTree::userActionStateChanged).
// - focusElement runs HTML's focusing steps and their events: blur, focusout, focus, focusin (FocusEvent).
// - The activation behaviours HTMLElement runs from DOM dispatch's hooks: a checkbox or radio toggles before the
//   listeners and reverts when the click is canceled; a label clicks its control; a summary toggles its details; a
//   submit button submits its form, whose submit is then always canceled (nothing navigates); a link calls the bridge's
//   openLink, unless it is a fragment or javascript: link. Checkedness is the `checked` content attribute until M2's
//   forms (which litehtml's :checked and the controls' drawing read too).
#pragma once

#include <cstdint>
#include <vector>

#include "Sources/DOM/DOMState.h"
#include "Sources/Support/PlatformObject.h"

namespace wr {

class Element;
class Event;
class HTMLElement;
class Node;

class UserActions final : public ElementState {
public:
    UserActions() = default;
    UserActions(const UserActions&) = delete;
    UserActions& operator=(const UserActions&) = delete;

    // Profile 1 has no focus (V4 plan, Task 8; RB §8.1): nothing is ever focused.
    bool focused(JSContext*, Element&) override { return false; }
    bool focusWithin(JSContext*, Element&) override { return false; }
    bool focusVisible(JSContext*, Element&) override { return false; }
    bool hovered(JSContext* ctx, Element& element) override;
    bool active(JSContext* ctx, Element& element) override;

    /// The element under the primary pointer's down.
    void setHover(JSContext* ctx, Element* hover);
    /// Press `press` (HostState::beginPress's number) went down on `element` (nullptr: on no element), or ended.
    void addActive(JSContext* ctx, Element* element, uint64_t press);
    void removeActive(JSContext* ctx, uint64_t press);
    /// Drops every reference (the host state's destructor, while the context lives).
    void clear();
    /// A node left the main document (RenderTree's mutation listener): the hover and press inside it go, which changes
    /// `oldParent`'s inclusive ancestors' state.
    void nodeRemoved(JSContext* ctx, Node& node, Node& oldParent);
    /// While a label's activation clicks its control (so a click it made never activates a label again).
    bool labelActivating() const { return m_labelActivating; }
    struct LabelScope {
        UserActions& actions;
        explicit LabelScope(UserActions& a) : actions(a) { actions.m_labelActivating = true; }
        ~LabelScope() { actions.m_labelActivating = false; }
    };

private:
    struct Active {
        uint64_t press = 0;
        Ref<Element> element;
    };

    Ref<Element> m_hover;
    std::vector<Active> m_active;
    bool m_labelActivating = false;
};

/// tabIndex's default: 0 for HTML's focusable kinds (a[href], button, input but hidden, select, textarea, a details'
/// summary), -1 for the rest (an attribute that parses wins).
int32_t tabIndexOf(JSContext* ctx, Element& element);

/// DOM dispatch's activation hooks, for an HTML element (HTMLElement forwards to these).
bool hasActivationBehavior(JSContext* ctx, HTMLElement& element);
void legacyPreActivation(JSContext* ctx, HTMLElement& element);
void runActivation(JSContext* ctx, HTMLElement& element, Event& event);
void legacyCanceledActivation(JSContext* ctx, HTMLElement& element);
/// Whether `element` is a disabled button, input, select or textarea (a click on it does nothing).
bool isDisabledControl(JSContext* ctx, Element& element);

} // namespace wr
