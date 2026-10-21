// A runtime over the DOM's interface table with an HTML document as the global `document`, and a global `gc()`.
#pragma once

#include <string_view>

#include "Generated/Bindings.h"
#include "Tests/JSHarness.h"

namespace wr_test {

class DOMEnv : public JSEnv {
public:
    /// The document is <html><head></head><body></body></html>, built by hand: no quirks mode, no doctype.
    DOMEnv();
    /// The document is `html`, parsed (parseDocumentInto).
    explicit DOMEnv(std::string_view html);
    /// The hand-built skeleton, over `host` (which outlives the environment).
    explicit DOMEnv(wr::Host& host);
    /// `html`, parsed, over `host`.
    DOMEnv(std::string_view html, wr::Host& host);
};

} // namespace wr_test
