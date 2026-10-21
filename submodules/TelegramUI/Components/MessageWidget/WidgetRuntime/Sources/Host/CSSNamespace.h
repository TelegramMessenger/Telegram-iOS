// The CSS namespace (V5c plan; CSSOM §6.6): CSS.escape and CSS.supports, the latter answered from profile 1's tables
// (Sources/Host/CSSSupports.h). Hand-built, as Intl is: the generator skips WebIDL namespaces.
#pragma once

#include "quickjs.h"

namespace wr {

/// Defines the lazy global CSS (writable, configurable, non-enumerable): an object with escape and supports (data
/// properties, enumerable, as WebIDL makes a namespace's operations) and the class string "CSS". Called by installHost.
void installCSSNamespace(JSContext* ctx);

} // namespace wr
