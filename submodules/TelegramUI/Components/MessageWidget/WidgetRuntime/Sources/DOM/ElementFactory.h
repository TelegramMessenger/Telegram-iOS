#pragma once

#include "Sources/DOM/Element.h"

namespace wr {

/// Creates an element of the interface its namespace and local name call for (HTML "create an element", without
/// custom elements). Atoms are borrowed.
Ref<Element> createElementNode(JSContext* ctx, Document& document, Namespace ns, JSAtom localName, JSAtom prefix, JSAtom otherNamespace);

} // namespace wr
