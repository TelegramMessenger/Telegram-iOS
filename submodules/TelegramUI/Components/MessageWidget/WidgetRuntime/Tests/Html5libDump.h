// Our DOM in html5lib's tree-construction format ("| <html>", two spaces per level), as gumbo's tree_dump.h prints
// gumbo's tree: what html5lib's .dat files expect.
#pragma once

#include <string>

#include "Sources/DOM/DOM.h"

namespace wr_test {

/// A whole document: its children, the doctype included, in order.
std::string html5libDumpDocument(JSContext* ctx, wr::Document& document);
/// The children of `parent` (a fragment parse's result).
std::string html5libDumpChildren(JSContext* ctx, wr::Node& parent);

} // namespace wr_test
