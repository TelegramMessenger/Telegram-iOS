#include "Sources/Events/UserActions.h"

#include <algorithm>
#include <cstdlib>
#include <string>
#include <string_view>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/UIEvents.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Links.h"
#include "Sources/Host/Task.h"
#include "Sources/Host/TelegramWidget.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"

namespace wr {

namespace {

bool named(JSContext* ctx, const Element& element, std::string_view name) {
    Atom atom = Atom::fromUTF8(ctx, name);
    return element.hasHTMLName(atom.get());
}

std::optional<String> attribute(JSContext* ctx, const Element& element, std::string_view name) {
    Atom atom = Atom::fromUTF8(ctx, name);
    return element.attributeValue(ctx, atom.get());
}

bool hasAttribute(JSContext* ctx, const Element& element, std::string_view name) {
    Atom atom = Atom::fromUTF8(ctx, name);
    return element.hasAttributeAtom(ctx, atom.get());
}

void setBooleanAttribute(JSContext* ctx, Element& element, std::string_view name, bool on) {
    Atom atom = Atom::fromUTF8(ctx, name);
    if (on) {
        if (!element.hasAttributeAtom(ctx, atom.get())) {
            element.setAttributeValue(ctx, atom.get(), String::fromUTF8(ctx, ""));
        }
    } else {
        element.removeAttributeAtom(ctx, atom.get());
    }
}

// An attribute's value, ASCII-lowercased and trimmed of ASCII whitespace; "" when absent.
std::string keyword(JSContext* ctx, const Element& element, std::string_view name) {
    std::optional<String> value = attribute(ctx, element, name);
    if (!value) {
        return std::string();
    }
    std::string text = value->utf8();
    size_t begin = text.find_first_not_of(" \t\n\f\r");
    size_t end = text.find_last_not_of(" \t\n\f\r");
    if (begin == std::string::npos) {
        return std::string();
    }
    text = text.substr(begin, end - begin + 1);
    for (char& c : text) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c - 'A' + 'a');
        }
    }
    return text;
}

bool isInclusiveAncestor(const Node& ancestor, const Node* node) {
    for (const Node* n = node; n; n = n->parent()) {
        if (n == &ancestor) {
            return true;
        }
    }
    return false;
}

// `anchor` and its inclusive ancestors may have changed state (RenderTree::userActionStateChanged).
void noteRender(JSContext* ctx, Element* anchor) {
    if (HostState* host = HostState::find(ctx)) {
        if (RenderTree* render = host->render()) {
            render->userActionStateChanged(anchor);
        }
    }
}

// An `input` element's type keyword ("text" when absent).
std::string inputType(JSContext* ctx, const Element& element) {
    std::string type = keyword(ctx, element, "type");
    return type.empty() ? std::string("text") : type;
}

bool isLabelable(JSContext* ctx, Element& element) {
    if (named(ctx, element, "input")) {
        return inputType(ctx, element) != "hidden";
    }
    return named(ctx, element, "button") || named(ctx, element, "select") || named(ctx, element, "textarea");
}

// The radios in `radio`'s group: the same non-empty name, in the same tree (no form owners until M2).
template <class F>
void forEachInGroup(JSContext* ctx, Element& radio, F visit) {
    std::optional<String> name = attribute(ctx, radio, "name");
    if (!name || name->empty()) {
        return;
    }
    Node* root = &radio;
    while (Node* parent = root->parentNode(ctx)) {
        root = parent;
    }
    for (Node* n = root; n; n = n->nextInTreeOrder(root)) {
        if (!n->isElement() || n == &radio) {
            continue;
        }
        auto& other = static_cast<Element&>(*n);
        if (named(ctx, other, "input") && inputType(ctx, other) == "radio") {
            std::optional<String> otherName = attribute(ctx, other, "name");
            if (otherName && otherName->equals(ctx, *name)) {
                visit(other);
            }
        }
    }
}

enum class Kind : uint8_t { None, Checkbox, Radio, Submit, Link, Label, Summary, Button };

Kind kindOf(JSContext* ctx, Element& element) {
    if (!element.isHTMLElement()) {
        return Kind::None;
    }
    if (named(ctx, element, "input")) {
        const std::string type = inputType(ctx, element);
        if (type == "checkbox") {
            return Kind::Checkbox;
        }
        if (type == "radio") {
            return Kind::Radio;
        }
        if (type == "submit" || type == "image") {
            return Kind::Submit;
        }
        return Kind::None;
    }
    if (named(ctx, element, "button")) {
        const std::string type = keyword(ctx, element, "type");
        return type == "button" || type == "reset" ? Kind::Button : Kind::Submit;
    }
    if (named(ctx, element, "a")) {
        return hasAttribute(ctx, element, "href") ? Kind::Link : Kind::None;
    }
    if (named(ctx, element, "label")) {
        return Kind::Label;
    }
    if (named(ctx, element, "summary")) {
        Node* parent = element.parentNode(ctx);
        return parent && parent->isElement() && named(ctx, static_cast<Element&>(*parent), "details") ? Kind::Summary
                                                                                                      : Kind::None;
    }
    return Kind::None;
}

void fireSimple(JSContext* ctx, std::string_view type, EventTarget& target, bool bubbles, bool cancelable,
                bool cancelAfter = false) {
    Ref<Event> event = create<Event>(ctx, idl::kEvent, ctx);
    Atom atom = Atom::fromUTF8(ctx, type);
    event->initialize(ctx, atom.get(), bubbles, cancelable);
    event->setIsTrusted(true);
    Ref<EventTarget> held = Ref<EventTarget>::retain(ctx, &target);
    dispatch(ctx, *event, target);
    if (cancelAfter) {
        // A form's submission: there is no navigation, so its default is always canceled.
        event->preventDefault(ctx);
    }
}

void clickControl(JSContext* ctx, Element& control, bool trusted) {
    Ref<MouseEvent> event = create<MouseEvent>(ctx, idl::kMouseEvent, ctx);
    Atom atom = Atom::fromUTF8(ctx, "click");
    event->initialize(ctx, atom.get(), true, true);
    event->setComposed(true);
    event->setView(ctx, &HostState::of(ctx).window());
    event->setDetail(1);
    event->setIsTrusted(trusted);
    Ref<Element> held = Ref<Element>::retain(ctx, &control);
    dispatch(ctx, *event, control);
}

} // namespace

// UserActions

bool UserActions::hovered(JSContext*, Element& element) {
    return m_hover && isInclusiveAncestor(element, m_hover.get());
}

bool UserActions::active(JSContext*, Element& element) {
    return std::any_of(m_active.begin(), m_active.end(),
                       [&](const Active& active) { return isInclusiveAncestor(element, active.element.get()); });
}

void UserActions::setHover(JSContext* ctx, Element* hover) {
    if (m_hover.get() == hover) {
        return;
    }
    const Ref<Element> old = std::move(m_hover);
    m_hover = hover ? Ref<Element>::retain(ctx, hover) : Ref<Element>();
    noteRender(ctx, old.get());
    noteRender(ctx, hover);
}

void UserActions::addActive(JSContext* ctx, Element* element, uint64_t press) {
    if (!element) {
        return;
    }
    m_active.push_back(Active{press, Ref<Element>::retain(ctx, element)});
    noteRender(ctx, element);
}

void UserActions::removeActive(JSContext* ctx, uint64_t press) {
    const auto it = std::find_if(m_active.begin(), m_active.end(), [&](const Active& active) { return active.press == press; });
    if (it == m_active.end()) {
        return;
    }
    const Ref<Element> element = std::move(it->element);
    m_active.erase(it);
    noteRender(ctx, element.get());
}

void UserActions::nodeRemoved(JSContext* ctx, Node& node, Node& oldParent) {
    bool changed = false;
    if (m_hover && isInclusiveAncestor(node, m_hover.get())) {
        m_hover = Ref<Element>();
        changed = true;
    }
    const size_t before = m_active.size();
    m_active.erase(std::remove_if(m_active.begin(), m_active.end(),
                                  [&](const Active& active) { return isInclusiveAncestor(node, active.element.get()); }),
                   m_active.end());
    changed = changed || m_active.size() != before;
    if (changed) {
        noteRender(ctx, oldParent.isElement() ? static_cast<Element*>(&oldParent) : nullptr);
    }
}

void UserActions::clear() {
    m_hover = Ref<Element>();
    m_active.clear();
}

// Focus

bool isDisabledControl(JSContext* ctx, Element& element) {
    if (!element.isHTMLElement()) {
        return false;
    }
    if (!named(ctx, element, "button") && !named(ctx, element, "input") && !named(ctx, element, "select") &&
        !named(ctx, element, "textarea")) {
        return false;
    }
    return hasAttribute(ctx, element, "disabled");
}

namespace {

std::optional<int32_t> parsedTabIndex(JSContext* ctx, const Element& element) {
    std::string text = keyword(ctx, element, "tabindex");
    if (text.empty()) {
        return std::nullopt;
    }
    char* end = nullptr;
    long value = std::strtol(text.c_str(), &end, 10);
    if (end == text.c_str() || *end != 0 || value < INT32_MIN || value > INT32_MAX) {
        return std::nullopt;
    }
    return int32_t(value);
}

bool focusableKind(JSContext* ctx, Element& element) {
    if (named(ctx, element, "a")) {
        return hasAttribute(ctx, element, "href");
    }
    if (named(ctx, element, "input")) {
        return inputType(ctx, element) != "hidden";
    }
    if (named(ctx, element, "summary")) {
        return kindOf(ctx, element) == Kind::Summary;
    }
    return named(ctx, element, "button") || named(ctx, element, "select") || named(ctx, element, "textarea");
}

} // namespace

int32_t tabIndexOf(JSContext* ctx, Element& element) {
    if (std::optional<int32_t> parsed = parsedTabIndex(ctx, element)) {
        return *parsed;
    }
    return element.isHTMLElement() && focusableKind(ctx, element) ? 0 : -1;
}

// Activation

bool hasActivationBehavior(JSContext* ctx, HTMLElement& element) {
    return kindOf(ctx, element) != Kind::None;
}

void legacyPreActivation(JSContext* ctx, HTMLElement& element) {
    const Kind kind = kindOf(ctx, element);
    if (kind != Kind::Checkbox && kind != Kind::Radio) {
        return;
    }
    const bool wasChecked = hasAttribute(ctx, element, "checked");
    element.saveActivation(ctx, wasChecked, nullptr);
    if (kind == Kind::Checkbox) {
        setBooleanAttribute(ctx, element, "checked", !wasChecked);
        return;
    }
    Element* previous = nullptr;
    forEachInGroup(ctx, element, [&](Element& other) {
        if (hasAttribute(ctx, other, "checked")) {
            previous = previous ? previous : &other;
            setBooleanAttribute(ctx, other, "checked", false);
        }
    });
    element.saveActivation(ctx, wasChecked, previous);
    setBooleanAttribute(ctx, element, "checked", true);
}

void runActivation(JSContext* ctx, HTMLElement& element, Event& event) {
    switch (kindOf(ctx, element)) {
    case Kind::Checkbox:
    case Kind::Radio: {
        const bool wasChecked = element.savedChecked();
        element.clearActivation(ctx);
        if (wasChecked == hasAttribute(ctx, element, "checked")) {
            return;
        }
        fireSimple(ctx, "input", element, true, false);
        fireSimple(ctx, "change", element, true, false);
        return;
    }
    case Kind::Submit: {
        if (isDisabledControl(ctx, element)) {
            return;
        }
        for (Node* n = element.parentNode(ctx); n; n = n->parentNode(ctx)) {
            if (n->isElement() && named(ctx, static_cast<Element&>(*n), "form")) {
                fireSimple(ctx, "submit", *n, true, true, true);
                return;
            }
        }
        return;
    }
    case Kind::Link: {
        std::optional<String> href = attribute(ctx, element, "href");
        if (!href) {
            return;
        }
        // SDK v1 §2.5: by host to openTelegramLink or openLink, as the press allows; a fragment does nothing.
        followAnchor(ctx, *href);
        return;
    }
    case Kind::Label: {
        Element* control = nullptr;
        if (std::optional<String> forId = attribute(ctx, element, "for")) {
            Element* found = element.nodeDocument().getElementById(ctx, *forId);
            if (found && isLabelable(ctx, *found)) {
                control = found;
            }
        } else {
            for (Node* n = element.firstChildNode(); n; n = n->nextInTreeOrder(&element)) {
                if (n->isElement() && isLabelable(ctx, static_cast<Element&>(*n))) {
                    control = static_cast<Element*>(n);
                    break;
                }
            }
        }
        // HTML: nothing when the click was at the labeled control or inside it (its own click came here because the
        // control has no activation of its own), nor for a click this label made (a guard against any other loop).
        EventTarget* clicked = event.targetNode();
        Node* clickedNode = clicked ? dynamic_cast<Node*>(clicked) : nullptr;
        UserActions& actions = HostState::of(ctx).userActions();
        if (control && !isDisabledControl(ctx, *control) && !isInclusiveAncestor(*control, clickedNode) &&
            !actions.labelActivating()) {
            UserActions::LabelScope scope(actions);
            clickControl(ctx, *control, event.isTrusted(ctx));
        }
        return;
    }
    case Kind::Summary: {
        auto* details = static_cast<Element*>(element.parentNode(ctx));
        setBooleanAttribute(ctx, *details, "open", !hasAttribute(ctx, *details, "open"));
        Ref<Element> held = Ref<Element>::retain(ctx, details);
        HostState::of(ctx).loop().queueTask(TaskSource::DOMManipulation, makeTask(ctx, [held](JSContext* ctx) {
            fireSimple(ctx, "toggle", *held, false, false);
        }));
        return;
    }
    case Kind::Button:
    case Kind::None:
        return;
    }
}

void legacyCanceledActivation(JSContext* ctx, HTMLElement& element) {
    const Kind kind = kindOf(ctx, element);
    if (kind != Kind::Checkbox && kind != Kind::Radio) {
        return;
    }
    const bool wasChecked = element.savedChecked();
    Ref<Element> previous = Ref<Element>::retain(ctx, element.savedRadio());
    element.clearActivation(ctx);
    setBooleanAttribute(ctx, element, "checked", wasChecked);
    if (kind == Kind::Radio && previous) {
        setBooleanAttribute(ctx, *previous, "checked", true);
    }
}

} // namespace wr
