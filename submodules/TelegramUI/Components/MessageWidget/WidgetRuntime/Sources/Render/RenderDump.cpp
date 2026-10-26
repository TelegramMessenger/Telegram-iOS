#include "Sources/Render/RenderDump.h"

#include <cstdio>
#include <utility>
#include <vector>

#include <litehtml.h>

namespace wr {

std::string dumpLayout(const litehtml::document& document) {
    std::string out;
    // document::root() is not const, though it only returns the root; nothing here changes the document.
    litehtml::element::ptr root = const_cast<litehtml::document&>(document).root();
    if (!root) {
        return out;
    }
    // In tree order with an explicit stack: nothing in W recurses over a tree (Global Constraints, "Stack").
    std::vector<std::pair<const litehtml::element*, size_t>> stack;
    stack.emplace_back(root.get(), 0);
    while (!stack.empty()) {
        auto [element, depth] = stack.back();
        stack.pop_back();
        if (element->is_text() || element->is_space()) {
            continue;
        }
        const litehtml::position placement = element->get_placement();
        const char* tag = element->get_tagName();
        char numbers[160];
        std::snprintf(numbers, sizeof(numbers), " %g %g %g %g\n", double(placement.x.value()),
                      double(placement.y.value()), double(placement.width.value()), double(placement.height.value()));
        out.append(2 * depth, ' ');
        out += tag ? tag : "";
        out += numbers;
        const auto& children = element->children();
        for (auto child = children.rbegin(); child != children.rend(); ++child) {
            stack.emplace_back(child->get(), depth + 1);
        }
    }
    return out;
}

} // namespace wr
