#include "Sources/Canvas/ImageElement.h"

#include <cmath>
#include <string>
#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Canvas/CanvasState.h"
#include "Sources/DOM/DOMState.h"
#include "Sources/DOM/Geometry.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Host/CSSPolicy.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Render/WidgetContainer.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

constexpr uint32_t kMaxReflected = 2147483647;

std::optional<uint32_t> dimensionAttribute(JSContext* ctx, const Element& element, Name name) {
    std::optional<String> value = element.attributeValue(ctx, DOMState::of(ctx).name(name));
    if (!value) {
        return std::nullopt;
    }
    const std::string s = value->utf8Prefix(64, nullptr);
    size_t i = 0;
    while (i < s.size() && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\f' || s[i] == '\r')) {
        i++;
    }
    if (i < s.size() && s[i] == '+') {
        i++;
    }
    if (i >= s.size() || s[i] < '0' || s[i] > '9') {
        return std::nullopt;
    }
    uint64_t v = 0;
    for (; i < s.size() && s[i] >= '0' && s[i] <= '9'; i++) {
        v = v * 10 + uint64_t(s[i] - '0');
        if (v > kMaxReflected) {
            return std::nullopt;
        }
    }
    return uint32_t(v);
}

void setDimensionAttribute(JSContext* ctx, Element& element, Name name, uint32_t value) {
    element.setAttributeValue(ctx, DOMState::of(ctx).name(name), String::fromUTF8(ctx, std::to_string(value <= kMaxReflected ? value : 0)));
}

void fireImageEvent(JSContext* ctx, HTMLImageElement& image) {
    image.settled();
    const HTMLImageElement::State state = image.state(ctx);
    if (state == HTMLImageElement::State::Unavailable) {
        return;
    }
    fireEvent(ctx, image, Atom::fromUTF8(ctx, state == HTMLImageElement::State::Available ? "load" : "error").get());
}

} // namespace

HTMLImageElement::State HTMLImageElement::state(JSContext* ctx, std::optional<DecodedImage>* decoded) const {
    std::optional<String> src = this->attributeValue(ctx, DOMState::of(ctx).name(Name::src));
    if (!src) {
        return State::Unavailable;
    }
    if (!m_decided) {
        if (!HostState::find(ctx)) {
            return State::Broken;
        }
        // A present src profile 1 refuses, the empty one included, is the 48 px placeholder the renderer draws in its
        // place (V4 plan, Task 6; RB §3.5, §8.5): it loads.
        std::string utf8 = src->utf8();
        // widget-sandbox v0.3.0: one claiming more than 1024² pixels is the placeholder too, and bytes of none of the
        // profile's formats are broken, as the layout decides (css::policy::imageSource).
        const css::policy::ImageSource source = css::policy::imageSource(utf8);
        if (source == css::policy::ImageSource::Refused) {
            utf8 = std::string(WidgetContainer::kPlaceholderURL);
        }
        if (source == css::policy::ImageSource::Broken) {
            m_decoded = std::nullopt;
        } else {
            m_decoded = canvas::CanvasState::of(ctx).sharedImage(utf8);
        }
        m_decided = true;
    }
    if (!m_decoded) {
        return State::Broken;
    }
    if (decoded) {
        *decoded = m_decoded;
    }
    return State::Available;
}

uint32_t HTMLImageElement::naturalWidth(JSContext* ctx) const {
    std::optional<DecodedImage> image;
    return !m_pending && state(ctx, &image) == State::Available ? uint32_t(std::lround(image->width)) : 0;
}

uint32_t HTMLImageElement::naturalHeight(JSContext* ctx) const {
    std::optional<DecodedImage> image;
    return !m_pending && state(ctx, &image) == State::Available ? uint32_t(std::lround(image->height)) : 0;
}

// HTML (widget-sandbox v0.2.3): the rendered size when the image is being rendered (a layout query), else the
// attribute, else the natural size. A pending image has no natural size yet, so a browser lays a dimension the CSS
// leaves auto out at 0 until it decodes; the render tree already knows the decoded size (v0.2.3 review, M3).
uint32_t HTMLImageElement::width(JSContext* ctx) const {
    if (connected(ctx)) {
        if (std::optional<RenderedContentSize> rendered = renderedContentSize(ctx, *this)) {
            return m_pending && rendered->autoWidth ? 0 : uint32_t(std::lround(rendered->width));
        }
    }
    std::optional<uint32_t> attribute = dimensionAttribute(ctx, *this, Name::width);
    return attribute ? *attribute : naturalWidth(ctx);
}

uint32_t HTMLImageElement::height(JSContext* ctx) const {
    if (connected(ctx)) {
        if (std::optional<RenderedContentSize> rendered = renderedContentSize(ctx, *this)) {
            return m_pending && rendered->autoHeight ? 0 : uint32_t(std::lround(rendered->height));
        }
    }
    std::optional<uint32_t> attribute = dimensionAttribute(ctx, *this, Name::height);
    return attribute ? *attribute : naturalHeight(ctx);
}

void HTMLImageElement::setWidth(JSContext* ctx, uint32_t value) { setDimensionAttribute(ctx, *this, Name::width, value); }
void HTMLImageElement::setHeight(JSContext* ctx, uint32_t value) { setDimensionAttribute(ctx, *this, Name::height, value); }

bool HTMLImageElement::complete(JSContext*) const {
    // A data: image is decided when its load or error fires (widget-sandbox v0.2.3); nothing else ever loads.
    return !m_pending;
}

String HTMLImageElement::currentSrc(JSContext* ctx) const {
    if (m_pending || state(ctx) != State::Available) {
        return String::fromUTF8(ctx, "");
    }
    return *this->attributeValue(ctx, DOMState::of(ctx).name(Name::src));
}

namespace {

JSValue constructImage(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        if (JS_IsUndefined(newTarget)) {
            throw TypeError{"Image: the constructor must be called with new."};
        }
        // WebIDL: the arguments convert before the element is made.
        std::optional<uint32_t> width, height;
        if (argc > 0 && !JS_IsUndefined(argv[0])) {
            width = convert<uint32_t>(ctx, argv[0], ArgInfo{"Image", "constructor", 0});
        }
        if (argc > 1 && !JS_IsUndefined(argv[1])) {
            height = convert<uint32_t>(ctx, argv[1], ArgInfo{"Image", "constructor", 1});
        }
        DOMState& state = DOMState::of(ctx);
        Ref<Element> made = createElementNode(ctx, state.document(), Namespace::HTML, state.name(Name::img), JS_ATOM_NULL, JS_ATOM_NULL);
        auto* image = static_cast<HTMLImageElement*>(made.get());
        if (width) {
            image->setWidth(ctx, *width);
        }
        if (height) {
            image->setHeight(ctx, *height);
        }
        return made->newRef(ctx);
    });
}

JSValue makeImageConstructor(JSContext* ctx) {
    try {
        Value fn = Value::adopt(ctx, checked(ctx, JS_NewCFunction2(ctx, constructImage, "Image", 0, JS_CFUNC_constructor, 0)));
        // A legacy factory function's prototype: the interface's, not writable, enumerable or configurable.
        Value prototype = Value::dup(ctx, Runtime::from(ctx).prototype(idl::kHTMLImageElement));
        check(ctx, JS_DefinePropertyValueStr(ctx, fn.get(), "prototype", prototype.release(), 0));
        return fn.release();
    } catch (...) {
        return rethrowAsJS(ctx);
    }
}

} // namespace

void installImageConstructor(JSContext* ctx) {
    Runtime::from(ctx).defineLazyGlobal("Image", makeImageConstructor);
}

void imageCreated(JSContext* ctx) {
    if (HostState::find(ctx)) {
        canvas::CanvasState::of(ctx);
    }
}

void imageSourceChanged(JSContext* ctx, HTMLImageElement& element) {
    element.forgetDecision();
    std::optional<String> src = element.attributeValue(ctx, DOMState::of(ctx).name(Name::src));
    const bool loads = src && HostState::find(ctx);
    // Pending until its load or error fires (widget-sandbox v0.2.3); a newer src replaces that event.
    element.sourceChanged(loads);
    if (!loads) {
        return;
    }
    // A parsed image's event waits for the window's load (fireParsedImageEvents), when the page's listeners exist.
    if (DOMState::of(ctx).parsingDocument()) {
        canvas::CanvasState::of(ctx).addParsedImage(Ref<HTMLImageElement>::retain(ctx, &element));
        return;
    }
    element.setEventQueued();
    Ref<HTMLImageElement> image = Ref<HTMLImageElement>::retain(ctx, &element);
    const uint32_t generation = element.sourceGeneration();
    EventLoop::of(ctx).queueTask(TaskSource::DOMManipulation, makeTask(ctx, [image = std::move(image), generation](JSContext* ctx) mutable {
        if (image->sourceGeneration() == generation) {
            fireImageEvent(ctx, *image);
        }
    }));
}

void HTMLImageElement::adoptedInto(JSContext* ctx, Document& document) {
    HTMLElement::adoptedInto(ctx, document);
    if (&document == &DOMState::of(ctx).document()) {
        imageSourceChanged(ctx, *this);
    }
}

void fireParsedImageEvents(JSContext* ctx) {
    // Collected first, each with its source generation: a handler may change the tree, or give an image collected
    // here a new src, whose own task then fires it (v0.2.3 fix-wave review, minor 5).
    struct Collected {
        Ref<HTMLImageElement> image;
        uint32_t generation;
    };
    Vector<Collected> pending{JSAllocator<Collected>(JS_GetRuntime(ctx))};
    Document& document = DOMState::of(ctx).document();
    Node* node = &document;
    while (node) {
        if (auto* image = dynamic_cast<HTMLImageElement*>(node); image && !image->eventQueued()) {
            image->setEventQueued();
            pending.push_back(Collected{Ref<HTMLImageElement>::retain(ctx, image), image->sourceGeneration()});
        }
        if (Node* child = node->firstChildNode()) {
            node = child;
            continue;
        }
        while (node && !node->nextSiblingNode()) {
            node = node->parentNode(ctx);
        }
        node = node ? node->nextSiblingNode() : nullptr;
    }
    // Then the parsed images a script took out of the document: a browser's fetch goes on (v0.2.3 review, I1). One in a
    // template's contents (another document) loads when it is adopted into this one.
    HostState* host = HostState::find(ctx);
    if (canvas::CanvasState* state = host ? host->canvasSlot().get() : nullptr) {
        for (Ref<HTMLImageElement>& image : state->takeParsedImages()) {
            if (!image->eventQueued() && &image->nodeDocument() == &document) {
                image->setEventQueued();
                const uint32_t generation = image->sourceGeneration();
                pending.push_back(Collected{std::move(image), generation});
            }
        }
    }
    for (Collected& entry : pending) {
        if (entry.image->sourceGeneration() == entry.generation) {
            fireImageEvent(ctx, *entry.image);
        }
    }
}

} // namespace wr
