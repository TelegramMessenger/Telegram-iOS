#pragma once

#include <optional>
#include <vector>

#include "Sources/DOM/Element.h"

namespace wr {

/// HTML's DOMStringMap over an element's data-* attributes (`dataset`), bound through NamedExotic. Its name-value pairs
/// come from the attributes' qualified names, in the attribute list's order.
class DOMStringMap : public PlatformObject {
public:
    DOMStringMap(JSContext* ctx, Element& element) : m_element(&element) { m_elementRef.value = JS_DupValue(ctx, element.object()); }
    // The NamedExotic contract.
    std::vector<String> supportedNames(JSContext* ctx);
    std::optional<String> namedValue(JSContext* ctx, const String& name);
    void setNamed(JSContext* ctx, const String& name, const String& value);
    /// Removes the attribute of a supported name; false (and nothing removed) for any other name.
    bool deleteNamed(JSContext* ctx, const String& name);

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override { m_elementRef.mark(rt, mark); }
    void dispose(JSRuntime* rt) override { m_elementRef.clear(rt); }

private:
    /// The index of the attribute whose pair is named `name`, or -1.
    int find(JSContext* ctx, const String& name);

    Element* m_element;
    Held m_elementRef;
};

} // namespace wr
