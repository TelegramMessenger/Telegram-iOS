#include "Sources/Canvas/ImageElement.h"

#include <cmath>
#include <string>
#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Canvas/CanvasState.h"
#include "Sources/DOM/DOMState.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Work.h"

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
    const HTMLImageElement::State state = image.state(ctx);
    if (state == HTMLImageElement::State::Unavailable) {
        return;
    }
    fireEvent(ctx, image, Atom::fromUTF8(ctx, state == HTMLImageElement::State::Available ? "load" : "error").get());
}

} // namespace

HTMLImageElement::State HTMLImageElement::state(JSContext* ctx, std::optional<DecodedImage>* decoded) const {
    std::optional<String> src = this->attributeValue(ctx, DOMState::of(ctx).name(Name::src));
    if (!src || src->empty()) {
        return State::Unavailable;
    }
    if (!m_decided) {
        if (!HostState::find(ctx)) {
            return State::Broken;
        }
        chargeScan(ctx, src->length());
        bool decoded = false;
        m_decoded = canvas::CanvasState::of(ctx).sharedImage(src->utf8(), decoded);
        m_decided = true;
        if (decoded) {
            // A decode, the first time any image with this src asks (V5d final review, I3).
            charge(ctx, uint64_t(m_decoded->width * m_decoded->height / 64) * work::kCanvasSixtyFourPixels);
        }
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
    return state(ctx, &image) == State::Available ? uint32_t(std::lround(image->width)) : 0;
}

uint32_t HTMLImageElement::naturalHeight(JSContext* ctx) const {
    std::optional<DecodedImage> image;
    return state(ctx, &image) == State::Available ? uint32_t(std::lround(image->height)) : 0;
}

uint32_t HTMLImageElement::width(JSContext* ctx) const {
    std::optional<uint32_t> attribute = dimensionAttribute(ctx, *this, Name::width);
    return attribute ? *attribute : naturalWidth(ctx);
}

uint32_t HTMLImageElement::height(JSContext* ctx) const {
    std::optional<uint32_t> attribute = dimensionAttribute(ctx, *this, Name::height);
    return attribute ? *attribute : naturalHeight(ctx);
}

void HTMLImageElement::setWidth(JSContext* ctx, uint32_t value) { setDimensionAttribute(ctx, *this, Name::width, value); }
void HTMLImageElement::setHeight(JSContext* ctx, uint32_t value) { setDimensionAttribute(ctx, *this, Name::height, value); }

bool HTMLImageElement::complete(JSContext*) const {
    // A data: image's decision is made the moment it is asked for, and nothing else ever loads.
    return true;
}

String HTMLImageElement::currentSrc(JSContext* ctx) const {
    if (state(ctx) != State::Available) {
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
    if (!src || src->empty() || !HostState::find(ctx)) {
        return;
    }
    element.setEventQueued();
    Ref<HTMLImageElement> image = Ref<HTMLImageElement>::retain(ctx, &element);
    EventLoop::of(ctx).queueTask(TaskSource::DOMManipulation, makeTask(ctx, [image = std::move(image)](JSContext* ctx) mutable {
        fireImageEvent(ctx, *image);
    }));
}

void fireParsedImageEvents(JSContext* ctx) {
    // Collected first: a handler may change the tree.
    std::vector<Ref<HTMLImageElement>> pending;
    Node* node = &DOMState::of(ctx).document();
    while (node) {
        charge(ctx, work::kNodeVisit);
        if (auto* image = dynamic_cast<HTMLImageElement*>(node); image && !image->eventQueued()) {
            image->setEventQueued();
            pending.push_back(Ref<HTMLImageElement>::retain(ctx, image));
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
    for (Ref<HTMLImageElement>& image : pending) {
        fireImageEvent(ctx, *image);
    }
}

} // namespace wr
