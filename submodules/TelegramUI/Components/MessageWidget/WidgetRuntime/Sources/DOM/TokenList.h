#pragma once

#include <vector>

#include "Sources/DOM/Element.h"

namespace wr {

/// DOMTokenList over one of an element's null-namespace attributes (`class` for classList). The token set is parsed
/// from the attribute's value and kept while the attribute holds that same value: the list keeps a reference to the
/// value it parsed, so a later value cannot reuse its address. The list's own writes keep the set they wrote rather
/// than parse it back.
class DOMTokenList : public PlatformObject {
public:
    /// `attribute` is borrowed.
    DOMTokenList(JSContext* ctx, Element& element, JSAtom attribute);
    uint32_t length(JSContext* ctx) { return uint32_t(this->tokens(ctx).size()); }
    std::optional<String> item(JSContext* ctx, uint32_t index);
    /// For IndexedExotic: `index` is below length().
    JSValue indexedValue(JSContext* ctx, uint32_t index) { return JS_DupValue(ctx, this->tokens(ctx)[index].value); }
    bool contains(JSContext* ctx, String token);
    void add(JSContext* ctx, std::vector<String> tokens);
    void remove(JSContext* ctx, std::vector<String> tokens);
    bool toggle(JSContext* ctx, String token, std::optional<bool> force);
    bool replace(JSContext* ctx, String token, String newToken);
    bool supports(JSContext* ctx, String token);
    String value(JSContext* ctx);
    void setValue(JSContext* ctx, String value);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override { m_elementRef.mark(rt, mark); }
    void dispose(JSRuntime* rt) override;

private:
    /// The token set of the attribute's current value.
    const Vector<Held>& tokens(JSContext* ctx);
    void parse(JSContext* ctx, const String& value);
    void clearTokens(JSRuntime* rt);
    /// The token set as Strings, to edit.
    Vector<String> copyOfTokens(JSContext* ctx);
    /// The DOM's "update steps": the attribute becomes `set` serialized, and `set` the token set of that value.
    void update(JSContext* ctx, const Vector<String>& set);

    Element* m_element;
    Held m_elementRef;
    HeldAtom m_attribute;
    /// The value the tokens were parsed from (undefined for no attribute), while m_parsed.
    Held m_parsedFrom;
    bool m_parsed = false;
    Vector<Held> m_tokens;
};

} // namespace wr
