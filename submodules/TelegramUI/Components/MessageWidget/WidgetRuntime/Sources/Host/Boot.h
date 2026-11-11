// Boot (M1b Task 14): markup into a running page. Parses into the main document and queues the parse's scripts and
// HTML's "the end" (https://html.spec.whatwg.org/multipage/parsing.html#the-end) on the event loop; the host then
// steps the loop. Ruling 9 has the order.
#pragma once

#include <string>
#include <string_view>

// ParseLimits and ParseOutcome are Parser.h's, which is not self-contained (its Element.h needs Attr complete): DOM.h
// brings it with every header it needs, so this header (and HostHarness.h) can come first.
#include "Sources/DOM/DOM.h"

namespace wr {

struct BootOptions {
    std::string_view html;
    std::string url = "about:srcdoc";
    ParseLimits limits;
};

/// Sets the main document's URL and readiness ("loading"), parses `options.html` into it, and queues the first script
/// task (or "the end"). Runs no script. The parse is M1a's parseDocumentInto, bounded by `options.limits` (spec section
/// 5, step 2); the host runs boot on no CPU slice.
/// The main document must be empty: one with children breaks the contract, and the widget stops (Internal) with
/// nothing parsed.
/// A step boundary (Ruling C1): it never throws. A stop inside it (a counted cap, the memory limit) or a native failure
/// latches the runtime and ends the boot; a runtime that stopped before it boots nothing. The host checks
/// Runtime::stopReason() after boot: while it is not None, the returned ParseOutcome means nothing.
ParseOutcome boot(JSContext* ctx, const BootOptions& options);

} // namespace wr
