#pragma once

#include <string>

#include "Sources/DOM/Element.h"

namespace wr {

class DocumentFragment;

class HTMLElement : public Element {
public:
    using Element::Element;

    // HTMLElement's focus and activation members (M1d plan, Task 3; Sources/Events/UserActions.h).
    /// HTML's click(): a synthetic, untrusted click at this element, unless it is a disabled form control.
    void click(JSContext* ctx);
    // CSSOM View (V3 plan, Task 3; Sources/DOM/Geometry.cpp): layout queries.
    Element* offsetParent(JSContext* ctx);
    int32_t offsetTop(JSContext* ctx);
    int32_t offsetLeft(JSContext* ctx);
    int32_t offsetWidth(JSContext* ctx);
    int32_t offsetHeight(JSContext* ctx);
    void focus(JSContext* ctx);
    void blur(JSContext* ctx);
    int32_t tabIndex(JSContext* ctx);
    void setTabIndex(JSContext* ctx, int32_t value);
    bool hasActivationBehavior(JSContext* ctx) override;
    void legacyPreActivationBehavior(JSContext* ctx) override;
    void activationBehavior(JSContext* ctx, Event& event) override;
    void legacyCanceledActivationBehavior(JSContext* ctx) override;
    /// A checkbox's or radio's state from its legacy-pre-activation steps to the end of its click's dispatch.
    void saveActivation(JSContext* ctx, bool checked, Element* previousRadio);
    bool savedChecked() const { return m_savedChecked; }
    Element* savedRadio() const;
    void clearActivation(JSContext* ctx);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    bool m_savedChecked = false;
    Held m_savedRadio;
};

/// A class of its own for the methods profile 1's sandbox makes no-ops (V4 plan, Task 8; RB §8.1).
class HTMLInputElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;
    void select(JSContext*) {}
    void setSelectionRange(JSContext*, uint32_t, uint32_t, std::optional<String>) {}
};

/// A dialog as profile 1's sandbox has it (V4 plan, Task 8; RB §8.2): show() and showModal() set open; close() sets the
/// returnValue when given one, removes open and fires a non-bubbling close synchronously (browsers fire it from a task).
/// Nothing reaches a top layer: the renderer's copy is an inert div.
class HTMLDialogElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;
    String returnValue(JSContext* ctx) const;
    void setReturnValue(JSContext* ctx, String value);
    void show(JSContext* ctx);
    void showModal(JSContext* ctx);
    void close(JSContext* ctx, std::optional<String> returnValue);
    void dispose(JSRuntime* rt) override;

private:
    Held m_returnValue;
};

/// A class of its own because WindowEventHandlers' generated glue casts to it: the C++ chain mirrors the IDL chain.
class HTMLBodyElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;
};

class HTMLTemplateElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;
    /// Made on first use, in the node document's template contents owner document, with this element as its host.
    DocumentFragment* content(JSContext* ctx);
    bool hostsContents() const override { return !m_content.isUndefined(); }
    /// HTML's cloning steps: a deep clone copies the contents (queued, for cloneNodeInto's loop).
    void cloneSteps(JSContext* ctx, Node& copy, bool subtree, CloneQueue& pending) override;
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_content;
};

/// HTML's "child text content": the data of the Text children, in order (not of the descendants).
String childTextContent(JSContext* ctx, Node& node);

/// The script element (https://html.spec.whatwg.org/multipage/scripting.html#the-script-element). Its state is HTML's;
/// "prepare the script element" and "execute the script element" are Host/Scripts.cpp.
class HTMLScriptElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;

    enum class Kind : uint8_t { Classic, Module };
    /// The script's result: not yet fetched; null (the loader refused it); or ready (resultSource, resultURL).
    enum class Result : uint8_t { Uninitialized, Null, Ready };

    /// The parser document: the document whose parser made this element (HTML's parser sets it; the fragment parser
    /// does not). A counted reference, traced.
    Document* parserDocument() const;
    void setParserDocument(JSContext* ctx, Document* document);
    bool parserInserted() const { return !m_parserDocument.isUndefined(); }
    bool alreadyStarted() const { return m_alreadyStarted; }
    void setAlreadyStarted(bool value) { m_alreadyStarted = value; }
    /// Initially true; the parser sets it false, and setting or adding the async attribute does.
    bool forceAsync() const { return m_forceAsync; }
    void setForceAsync(bool value) { m_forceAsync = value; }
    bool fromExternalFile() const { return m_fromExternalFile; }
    void setFromExternalFile(bool value) { m_fromExternalFile = value; }
    bool readyToBeParserExecuted() const { return m_readyToBeParserExecuted; }
    void setReadyToBeParserExecuted(bool value) { m_readyToBeParserExecuted = value; }
    Kind scriptKind() const { return m_kind; }
    void setScriptKind(Kind kind) { m_kind = kind; }
    Document* preparationTimeDocument() const;
    void setPreparationTimeDocument(JSContext* ctx, Document& document);
    Result result() const { return m_result; }
    void setNullResult(JSRuntime* rt);
    void setResult(JSContext* ctx, const String& source, const String& url);
    String resultSource(JSContext* ctx) const;
    /// The result's URL, converted to UTF-8.
    std::string resultURL(JSContext* ctx) const;

    // HTMLScriptElement
    bool async(JSContext* ctx);
    void setAsync(JSContext* ctx, bool value);
    String text(JSContext* ctx) { return childTextContent(ctx, *this); }
    void setText(JSContext* ctx, String value);
    static bool supports(JSContext* ctx, String type);

    /// HTML's cloning steps: the copy is already started when this element is (a clone of an inert script stays
    /// inert). A copy has no parser document.
    void cloneSteps(JSContext* ctx, Node& copy, bool subtree, CloneQueue& pending) override {
        static_cast<HTMLScriptElement&>(copy).setAlreadyStarted(m_alreadyStarted);
    }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_parserDocument;
    Held m_preparationTimeDocument;
    Held m_source;
    Held m_sourceURL;
    Result m_result = Result::Uninitialized;
    Kind m_kind = Kind::Classic;
    bool m_alreadyStarted = false;
    bool m_forceAsync = true;
    bool m_fromExternalFile = false;
    bool m_readyToBeParserExecuted = false;
};

class SVGElement : public Element {
public:
    using Element::Element;
};

class DOMPoint;
class DOMRect;

/// SVG 2 (V3b plan, Task 4; SVGGeometry.cpp): g, svg, use, image, a, switch, foreignObject, and the shapes and text.
class SVGGraphicsElement : public SVGElement {
public:
    using SVGElement::SVGElement;
    /// The user-unit box of the shape, or of the shapes a container holds; all zero when not rendered.
    Ref<DOMRect> getBBox(JSContext* ctx, idl::SVGBoundingBoxOptions options);
};

/// rect, circle, ellipse, line, polyline, polygon, path.
class SVGGeometryElement final : public SVGGraphicsElement {
public:
    using SVGGraphicsElement::SVGGraphicsElement;
    double getTotalLength(JSContext* ctx);
    /// Clamped to [0, the length].
    Ref<DOMPoint> getPointAtLength(JSContext* ctx, Unrestricted distance);
};

/// text, tspan, textPath.
class SVGTextContentElement final : public SVGGraphicsElement {
public:
    using SVGGraphicsElement::SVGGraphicsElement;
    /// UTF-16 code units of the text.
    int32_t getNumberOfChars(JSContext* ctx);
    /// The text's advance in its font, in user units.
    double getComputedTextLength(JSContext* ctx);
};

} // namespace wr
