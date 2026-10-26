#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

#include "Sources/DOM/Element.h"
#include "Sources/Render/ComputedStyle.h"

namespace wr {

/// CSSOM's CSSStyleDeclaration for an element's inline style (`element.style`). Its declarations are the element's
/// `style` attribute, parsed on every access, so they always agree with it whoever changed it; every change writes
/// the attribute back serialized (CSSOM "update style attribute for"), which the render tree restyles from as for any
/// attribute change. Values are kept as their text (trimmed, comments dropped): there is no CSS value parser here, so
/// a shorthand is not expanded into its longhands, nor a value normalized (IDL/README.md). A name is supported when it
/// is a custom property (`--*`) or in IDL/css-properties.txt.
class CSSStyleDeclaration : public PlatformObject {
public:
    struct Declaration {
        std::string name;
        std::string value;
        bool important = false;
    };

    CSSStyleDeclaration(JSContext* ctx, Element& element) : m_element(&element) { m_elementRef.value = JS_DupValue(ctx, element.object()); }
    /// getComputedStyle's declaration (V3 plan, Task 4): read-only (every write throws NoModificationAllowedError, its
    /// cssText is ""), its values those litehtml computed for the element or its `pseudo`-element, read after a layout
    /// query's flush at every access (Render/ComputedStyle.h). An element that is not rendered has none.
    struct Computed {
        PseudoElement pseudo = PseudoElement::None;
    };
    CSSStyleDeclaration(JSContext* ctx, Element& element, Computed computed) : CSSStyleDeclaration(ctx, element) {
        m_computed = true;
        m_pseudo = computed.pseudo;
    }

    // CSSStyleDeclaration
    String cssText(JSContext* ctx);
    void setCssText(JSContext* ctx, LegacyNullToEmptyString text);
    uint32_t length(JSContext* ctx);
    String item(JSContext* ctx, uint32_t index);
    String getPropertyValue(JSContext* ctx, String property);
    String getPropertyPriority(JSContext* ctx, String property);
    void setProperty(JSContext* ctx, String property, LegacyNullToEmptyString value, LegacyNullToEmptyString priority);
    String removeProperty(JSContext* ctx, String property);
    String cssFloat(JSContext* ctx);
    void setCssFloat(JSContext* ctx, LegacyNullToEmptyString value);
    // CSSStyleProperties' attributes ([CSSProperty]), by the property's name.
    String propertyValue(JSContext* ctx, JSAtom property);
    void setPropertyValue(JSContext* ctx, JSAtom property, LegacyNullToEmptyString value);
    // The IndexedExotic contract.
    JSValue indexedValue(JSContext* ctx, uint32_t index);

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override { m_elementRef.mark(rt, mark); }
    void dispose(JSRuntime* rt) override { m_elementRef.clear(rt); }

    /// CSS Syntax's declaration list for a style attribute: `name: value` up to each `;` outside strings, comments and
    /// brackets, `!important` read off the end, comments dropped. Kept: supported names (lower-cased but for custom
    /// properties) with a non-empty value and no other top-level `!`; of two declarations of one name, the later, at
    /// its place, unless only the earlier is important. Charged by the bytes it scans.
    static std::vector<Declaration> parse(JSContext* ctx, std::string_view text);
    /// CSSOM's "serialize a CSS declaration block": `name: value;` (` !important` before the `;`), space-separated.
    static std::string serialize(JSContext* ctx, const std::vector<Declaration>& declarations);
    /// Whether `name` (already lower-cased unless custom) is a custom property or in IDL/css-properties.txt.
    static bool isSupported(std::string_view name);

private:
    std::vector<Declaration> declarations(JSContext* ctx);
    void write(JSContext* ctx, const std::vector<Declaration>& declarations);
    /// CSSOM's "set a CSS declaration" on the block: in place when the property is there, appended otherwise.
    void set(JSContext* ctx, std::string name, const String& value, bool important);
    std::string remove(JSContext* ctx, const std::string& name);

    /// A computed value, or nullopt when the element is not rendered.
    std::optional<std::string> computedValue(JSContext* ctx, const std::string& name);

    Element* m_element;
    Held m_elementRef;
    bool m_computed = false;
    PseudoElement m_pseudo = PseudoElement::None;
};

} // namespace wr
