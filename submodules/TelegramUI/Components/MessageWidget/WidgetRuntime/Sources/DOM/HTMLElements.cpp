#include "Sources/DOM/HTMLElements.h"

#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/UIEvents.h"
#include "Sources/Events/UserActions.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"

namespace wr {

void HTMLElement::click(JSContext* ctx) {
    if (isDisabledControl(ctx, *this)) {
        return;
    }
    Ref<MouseEvent> event = create<MouseEvent>(ctx, idl::kMouseEvent, ctx);
    Atom atom = Atom::fromUTF8(ctx, "click");
    event->initialize(ctx, atom.get(), true, true);
    event->setComposed(true);
    if (HostState* host = HostState::find(ctx)) {
        event->setView(ctx, &host->window());
    }
    dispatch(ctx, *event, *this);
}

// Profile 1 has no focus (V4 plan, Task 8; RB §8.1): the sandbox's focus() and blur() are no-ops.
void HTMLElement::focus(JSContext*) {}

void HTMLElement::blur(JSContext*) {}

String HTMLDialogElement::returnValue(JSContext* ctx) const {
    return m_returnValue.isUndefined() ? String::fromUTF8(ctx, "") : String::adopt(ctx, JS_DupValue(ctx, m_returnValue.value));
}

void HTMLDialogElement::setReturnValue(JSContext* ctx, String value) {
    m_returnValue.set(JS_GetRuntime(ctx), value.toJS(ctx));
}

void HTMLDialogElement::show(JSContext* ctx) {
    Atom open = Atom::fromUTF8(ctx, "open");
    this->setAttributeValue(ctx, open.get(), String::fromUTF8(ctx, ""));
}

void HTMLDialogElement::showModal(JSContext* ctx) {
    this->show(ctx);
}

void HTMLDialogElement::close(JSContext* ctx, std::optional<String> returnValue) {
    if (returnValue) {
        this->setReturnValue(ctx, std::move(*returnValue));
    }
    Atom open = Atom::fromUTF8(ctx, "open");
    this->removeAttributeAtom(ctx, open.get());
    Atom type = Atom::fromUTF8(ctx, "close");
    fireEvent(ctx, *this, type.get());
}

void HTMLDialogElement::dispose(JSRuntime* rt) {
    m_returnValue.clear(rt);
    HTMLElement::dispose(rt);
}

int32_t HTMLElement::tabIndex(JSContext* ctx) {
    return tabIndexOf(ctx, *this);
}

void HTMLElement::setTabIndex(JSContext* ctx, int32_t value) {
    Atom atom = Atom::fromUTF8(ctx, "tabindex");
    this->setAttributeValue(ctx, atom.get(), String::fromUTF8(ctx, std::to_string(value)));
}

bool HTMLElement::hasActivationBehavior(JSContext* ctx) {
    return wr::hasActivationBehavior(ctx, *this);
}

void HTMLElement::legacyPreActivationBehavior(JSContext* ctx) {
    legacyPreActivation(ctx, *this);
}

void HTMLElement::activationBehavior(JSContext* ctx, Event& event) {
    runActivation(ctx, *this, event);
}

void HTMLElement::legacyCanceledActivationBehavior(JSContext* ctx) {
    legacyCanceledActivation(ctx, *this);
}

void HTMLElement::saveActivation(JSContext* ctx, bool checked, Element* previousRadio) {
    m_savedChecked = checked;
    m_savedRadio.set(JS_GetRuntime(ctx), previousRadio ? JS_DupValue(ctx, previousRadio->object()) : JS_UNDEFINED);
}

Element* HTMLElement::savedRadio() const {
    return m_savedRadio.isUndefined() ? nullptr : static_cast<Element*>(payloadOfKnown(m_savedRadio.value));
}

void HTMLElement::clearActivation(JSContext* ctx) {
    m_savedRadio.clear(JS_GetRuntime(ctx));
}

void HTMLElement::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_savedRadio.mark(rt, mark);
    Element::trace(rt, mark);
}

void HTMLElement::dispose(JSRuntime* rt) {
    m_savedRadio.clear(rt);
    Element::dispose(rt);
}

DocumentFragment* HTMLTemplateElement::content(JSContext* ctx) {
    if (m_content.isUndefined()) {
        Document& owner = this->nodeDocument().templateContentsOwner(ctx);
        Ref<DocumentFragment> content = owner.createDocumentFragment(ctx);
        content->setHost(ctx, *this);
        m_content.set(JS_GetRuntime(ctx), content.release());
    }
    return static_cast<DocumentFragment*>(payloadOfKnown(m_content.value));
}

// The copy's contents get copies of this one's children, in the copy's template contents owner document. Queued, not
// cloned here: cloning them here would recurse once per template nested in contents.
void HTMLTemplateElement::cloneSteps(JSContext* ctx, Node& copy, bool subtree, CloneQueue& pending) {
    // Contents never asked for are empty: no need to make them, here or in the copy.
    if (!subtree || m_content.isUndefined()) {
        return;
    }
    auto* from = static_cast<DocumentFragment*>(payloadOfKnown(m_content.value));
    if (!from->firstChildNode()) {
        return;
    }
    DocumentFragment* to = static_cast<HTMLTemplateElement&>(copy).content(ctx);
    pending.emplace_back(Ref<Node>::retain(ctx, from), Ref<Node>::retain(ctx, to));
}

void HTMLTemplateElement::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_content.mark(rt, mark);
    HTMLElement::trace(rt, mark);
}

void HTMLTemplateElement::dispose(JSRuntime* rt) {
    m_content.clear(rt);
    HTMLElement::dispose(rt);
}

String childTextContent(JSContext* ctx, Node& node) {
    Vector<char16_t> out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    for (size_t i = 0; i < node.childCount(); i++) {
        Node* child = node.childAt(i);
        if (child->type() == NodeType::Text) {
            String data = static_cast<CharacterData*>(child)->dataString(ctx);
            appendCodeUnits(out, data);
        }
    }
    return String::fromUTF16(ctx, out.data(), out.size());
}

static Document* documentIn(const Held& held) {
    return held.isUndefined() ? nullptr : static_cast<Document*>(payloadOfKnown(held.value));
}

Document* HTMLScriptElement::parserDocument() const {
    return documentIn(m_parserDocument);
}

void HTMLScriptElement::setParserDocument(JSContext* ctx, Document* document) {
    m_parserDocument.set(JS_GetRuntime(ctx), document ? JS_DupValue(ctx, document->object()) : JS_UNDEFINED);
}

Document* HTMLScriptElement::preparationTimeDocument() const {
    return documentIn(m_preparationTimeDocument);
}

void HTMLScriptElement::setPreparationTimeDocument(JSContext* ctx, Document& document) {
    m_preparationTimeDocument.set(JS_GetRuntime(ctx), JS_DupValue(ctx, document.object()));
}

void HTMLScriptElement::setNullResult(JSRuntime* rt) {
    m_source.clear(rt);
    m_sourceURL.clear(rt);
    m_result = Result::Null;
}

void HTMLScriptElement::setResult(JSContext* ctx, const String& source, const String& url) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    m_source.set(rt, source.toJS(ctx));
    m_sourceURL.set(rt, url.toJS(ctx));
    m_result = Result::Ready;
}

String HTMLScriptElement::resultSource(JSContext* ctx) const {
    return m_source.isUndefined() ? String() : String::adopt(ctx, JS_DupValue(ctx, m_source.value));
}

std::string HTMLScriptElement::resultURL(JSContext* ctx) const {
    if (m_sourceURL.isUndefined()) {
        return std::string();
    }
    String url = String::adopt(ctx, JS_DupValue(ctx, m_sourceURL.value));
    return url.utf8();
}

// HTML: the async getter answers true while force async is set; the setter clears it and sets or removes the attribute.
bool HTMLScriptElement::async(JSContext* ctx) {
    return m_forceAsync || this->hasAttributeAtom(ctx, DOMState::of(ctx).name(Name::async));
}

void HTMLScriptElement::setAsync(JSContext* ctx, bool value) {
    m_forceAsync = false;
    JSAtom async = DOMState::of(ctx).name(Name::async);
    if (value) {
        this->setAttributeValue(ctx, async, String::fromUTF8(ctx, ""));
    } else {
        this->removeAttributeAtom(ctx, async);
    }
}

void HTMLScriptElement::setText(JSContext* ctx, String value) {
    stringReplaceAll(ctx, value, *this);
}

// HTML's supports(type): "classic", "module", "importmap" and "speculationrules", case-sensitively, for what the user
// agent supports. Import maps and speculation rules are not supported here.
bool HTMLScriptElement::supports(JSContext* ctx, String type) {
    return type.equalsASCII("classic") || type.equalsASCII("module");
}

void HTMLScriptElement::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_parserDocument.mark(rt, mark);
    m_preparationTimeDocument.mark(rt, mark);
    HTMLElement::trace(rt, mark);
}

void HTMLScriptElement::dispose(JSRuntime* rt) {
    m_parserDocument.clear(rt);
    m_preparationTimeDocument.clear(rt);
    m_source.clear(rt);
    m_sourceURL.clear(rt);
    HTMLElement::dispose(rt);
}

} // namespace wr
