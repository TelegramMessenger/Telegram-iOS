// The user-action state and the default actions of a click (M1d plan, Task 3).
// - UserActions is the main document's ElementState for the user-action pseudo-classes: the focused element (:focus,
//   :focus-within on its inclusive ancestors), the element under the last pointer down (:hover on its inclusive
//   ancestors; it stays after the up, as touch browsers keep it), and the element pressed (:active, while the pointer is
//   down). A change tells the render tree (RenderTree::userActionStateChanged).
// - focusElement runs HTML's focusing steps and their events: blur, focusout, focus, focusin (FocusEvent).
// - The activation behaviours HTMLElement runs from DOM dispatch's hooks: a checkbox or radio toggles before the
//   listeners and reverts when the click is canceled; a label clicks its control; a summary toggles its details; a
//   submit button submits its form, whose submit is then always canceled (nothing navigates); a link calls the bridge's
//   openLink, unless it is a fragment or javascript: link. Checkedness is the `checked` content attribute until M2's
//   forms (which litehtml's :checked and the controls' drawing read too).
#pragma once

#include <cstdint>

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

    bool focused(JSContext* ctx, Element& element) override;
    bool focusWithin(JSContext* ctx, Element& element) override;
    bool focusVisible(JSContext*, Element&) override { return false; }
    bool hovered(JSContext* ctx, Element& element) override;
    bool active(JSContext* ctx, Element& element) override;

    /// The focused element while it is connected; nullptr otherwise (the body is the active element then).
    Element* focusedElement(JSContext* ctx) const;
    /// HTML's focusing steps for `element` (nullptr: blur to none). Nothing when it is already focused. Fires blur and
    /// focusout at the old one, then focus and focusin at the new one, each with the other as relatedTarget.
    void setFocus(JSContext* ctx, Element* element);
    /// The pointer's state: `hover` the element under the down, `active` the one pressed (nullptr when released).
    void setPointer(JSContext* ctx, Element* hover, Element* active);
    /// Drops every reference (the host state's destructor, while the context lives).
    void clear();
    /// A node left the main document (RenderTree's mutation listener): HTML's focus fixup drops a focus inside it (no
    /// events; the body is the active element), and the hover and press inside it go too. The render tree rebuilds
    /// when its CSS uses the state.
    void nodeRemoved(JSContext* ctx, Node& node);
    /// While a label's activation clicks its control (so a click it made never activates a label again).
    bool labelActivating() const { return m_labelActivating; }
    struct LabelScope {
        UserActions& actions;
        explicit LabelScope(UserActions& a) : actions(a) { actions.m_labelActivating = true; }
        ~LabelScope() { actions.m_labelActivating = false; }
    };

private:
    Ref<Element> m_focus;
    Ref<Element> m_hover;
    Ref<Element> m_active;
    bool m_labelActivating = false;
};

/// HTML "focusable area" for the profile: a[href], button, input (not hidden), select, textarea, a details' summary,
/// or anything with a tabindex attribute; never a disabled form control.
bool isFocusable(JSContext* ctx, Element& element);
/// tabIndex's default: 0 for the focusable kinds above, -1 for the rest (an attribute that parses wins).
int32_t tabIndexOf(JSContext* ctx, Element& element);
/// The nearest focusable inclusive ancestor of `node`, or nullptr.
Element* focusableAncestor(JSContext* ctx, Node* node);

/// DOM dispatch's activation hooks, for an HTML element (HTMLElement forwards to these).
bool hasActivationBehavior(JSContext* ctx, HTMLElement& element);
void legacyPreActivation(JSContext* ctx, HTMLElement& element);
void runActivation(JSContext* ctx, HTMLElement& element, Event& event);
void legacyCanceledActivation(JSContext* ctx, HTMLElement& element);
/// Whether `element` is a disabled button, input, select or textarea (a click on it does nothing).
bool isDisabledControl(JSContext* ctx, Element& element);

} // namespace wr
