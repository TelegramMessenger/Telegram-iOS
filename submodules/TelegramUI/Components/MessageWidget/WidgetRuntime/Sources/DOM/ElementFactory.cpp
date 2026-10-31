#include "Sources/DOM/ElementFactory.h"

#include "Generated/Bindings.h"
#include "Sources/Canvas/CanvasElement.h"
#include "Sources/Canvas/ImageElement.h"
#include "Sources/DOM/DOM.h"

namespace wr {

/// "valid custom element name" (HTML), loosely: a lowercase ASCII start and a hyphen.
static bool looksLikeCustomElementName(JSContext* ctx, JSAtom name) {
    String s = String::fromAtom(ctx, name);
    if (s.empty() || !(s.at(0) >= 'a' && s.at(0) <= 'z')) {
        return false;
    }
    uint32_t i = 0;
    while (i < s.length() && s.at(i) != '-') {
        i++;
    }
    return i < s.length();
}

Ref<Element> createElementNode(JSContext* ctx, Document& document, Namespace ns, JSAtom localName, JSAtom prefix, JSAtom otherNamespace) {
    if (ns == Namespace::HTML) {
        DOMState& state = DOMState::of(ctx);
        int iface = state.htmlInterface(localName);
        if (localName == state.name(Name::template_)) {
            return create<HTMLTemplateElement>(ctx, idl::kHTMLTemplateElement, ctx, document, ns, localName, prefix, otherNamespace);
        }
        if (localName == state.name(Name::script)) {
            return create<HTMLScriptElement>(ctx, idl::kHTMLScriptElement, ctx, document, ns, localName, prefix, otherNamespace);
        }
        if (localName == state.name(Name::canvas)) {
            return create<HTMLCanvasElement>(ctx, idl::kHTMLCanvasElement, ctx, document, ns, localName, prefix, otherNamespace);
        }
        if (localName == state.name(Name::img)) {
            imageCreated(ctx);
            return create<HTMLImageElement>(ctx, idl::kHTMLImageElement, ctx, document, ns, localName, prefix, otherNamespace);
        }
        if (localName == state.name(Name::body)) {
            return create<HTMLBodyElement>(ctx, idl::kHTMLBodyElement, ctx, document, ns, localName, prefix, otherNamespace);
        }
        if (iface == idl::kHTMLInputElement) {
            return create<HTMLInputElement>(ctx, idl::kHTMLInputElement, ctx, document, ns, localName, prefix, otherNamespace);
        }
        if (iface == idl::kHTMLDialogElement) {
            return create<HTMLDialogElement>(ctx, idl::kHTMLDialogElement, ctx, document, ns, localName, prefix, otherNamespace);
        }
        uint16_t chosen;
        if (iface >= 0) {
            chosen = uint16_t(iface);
        } else if (state.isKnownHTMLElement(localName) || looksLikeCustomElementName(ctx, localName)) {
            chosen = idl::kHTMLElement;
        } else {
            chosen = idl::kHTMLUnknownElement;
        }
        return create<HTMLElement>(ctx, chosen, ctx, document, ns, localName, prefix, otherNamespace);
    }
    if (ns == Namespace::SVG) {
        // SVG 2's interfaces for the elements that have geometry (V3b plan, Task 4); every other one is an SVGElement.
        const String name = String::fromAtom(ctx, localName);
        for (const char* shape : {"rect", "circle", "ellipse", "line", "polyline", "polygon", "path"}) {
            if (name.equalsASCII(shape)) {
                return create<SVGGeometryElement>(ctx, idl::kSVGGeometryElement, ctx, document, ns, localName, prefix, otherNamespace);
            }
        }
        for (const char* text : {"text", "tspan", "textPath"}) {
            if (name.equalsASCII(text)) {
                return create<SVGTextContentElement>(ctx, idl::kSVGTextContentElement, ctx, document, ns, localName, prefix, otherNamespace);
            }
        }
        for (const char* graphics : {"svg", "g", "use", "image", "a", "switch", "foreignObject"}) {
            if (name.equalsASCII(graphics)) {
                return create<SVGGraphicsElement>(ctx, idl::kSVGGraphicsElement, ctx, document, ns, localName, prefix, otherNamespace);
            }
        }
        return create<SVGElement>(ctx, idl::kSVGElement, ctx, document, ns, localName, prefix, otherNamespace);
    }
    return create<Element>(ctx, idl::kElement, ctx, document, ns, localName, prefix, otherNamespace);
}

} // namespace wr
