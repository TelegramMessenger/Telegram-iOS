// A laid-out litehtml document as text (M1c plan, Task 3), for tests and failure messages.
#pragma once

#include <string>

namespace litehtml {
class document;
}

namespace wr {

/// The litehtml element tree (not the DOM, so any two documents dump the same way), one line per element in tree
/// order, skipping text and space pieces: two spaces per depth, the tag name, then get_placement()'s x, y, width and
/// height by `%g`, each after a space, and a newline.
std::string dumpLayout(const litehtml::document& document);

} // namespace wr
