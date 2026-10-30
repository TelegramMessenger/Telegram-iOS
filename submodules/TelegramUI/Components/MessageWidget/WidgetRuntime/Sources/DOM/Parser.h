// HTML parsing through gumbo (Telegram's fork, third-party/gumbo). Markup becomes DOM nodes directly from gumbo's
// tree.
#pragma once

#include <cstdint>
#include <string_view>

#include "Sources/DOM/Document.h"
#include "Sources/DOM/DocumentFragment.h"
#include "Sources/DOM/Element.h"

namespace wr {

struct ParseLimits {
    /// Content nested deeper than this is dropped (widget-sandbox's MAX_PARSE_DEPTH). It also bounds the builder's
    /// recursion, which is a few frames per level: raising it far is a native-stack question, not only a policy one.
    uint32_t maxDepth = 256;
    /// Attributes past this many on one element are dropped, by gumbo (widget-sandbox's MAX_ATTRIBUTES).
    uint32_t maxAttributes = 256;
    /// gumbo stops parsing once it has made this many nodes.
    uint32_t maxNodes = 100000;
    /// gumbo stops parsing once the tree keeps this many attributes in all. maxAttributes bounds one element;
    /// attributes are not nodes, so maxNodes does not bound their total (gumbo fork change 12). Bounding it keeps the
    /// transient gumbo heap, which malloc_wrapper allocates outside the widget's memory limit, bounded (see the bound
    /// stated at transientHeapBound in Parser.cpp).
    uint32_t maxTotalAttributes = 100000;
    /// gumbo stops parsing once the attribute strings the tree keeps (each name and value copy, NUL included) hold
    /// this many bytes (gumbo fork change 13). maxTotalAttributes counts attributes, but reconstructing the active
    /// formatting elements deep-copies each one's values, so a few kilobytes of markup can copy one long value
    /// thousands of times; this bounds those bytes. Like maxNodes it is checked between tokens, so one token can
    /// overshoot it (transientHeapBound in Parser.cpp says by how much).
    uint32_t maxTotalAttributeBytes = 8 * 1024 * 1024;
};

struct ParseOutcome {
    /// The markup made more than ParseLimits::maxNodes nodes; the document holds what came before.
    bool stoppedAtNodeLimit = false;
    /// The markup kept more than ParseLimits::maxTotalAttributes attributes or ParseLimits::maxTotalAttributeBytes
    /// bytes of attribute strings; the document holds what came before.
    bool stoppedAtAttributeLimit = false;
};

/// Parses `html` as a whole document into `document`, which must be empty.
ParseOutcome parseDocumentInto(JSContext* ctx, Document& document, std::string_view html, const ParseLimits& limits = {});
/// The HTML fragment parsing algorithm with `context` as the context element, for a script. Scripts in the result are
/// inert.
Ref<DocumentFragment> parseFragment(JSContext* ctx, Element& context, std::string_view html, const ParseLimits& limits = {});

} // namespace wr
