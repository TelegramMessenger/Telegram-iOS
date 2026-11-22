#include "Sources/Render/RenderCut.h"

#include <algorithm>

#include "Sources/DOM/DOM.h"

namespace wr {

void RenderCut::note(std::string_view kind) {
    if (std::find(m_limits.begin(), m_limits.end(), kind) == m_limits.end()) {
        m_limits.emplace_back(kind);
    }
}

bool RenderCut::addNodes(size_t count) {
    m_state.nodes += count;
    return m_state.nodes <= kMaxRenderNodes;
}

const char* RenderCut::elementLimit(bool formControl, int depth, bool countsLitehtml) const {
    if (m_state.elements >= kMaxElements) {
        return "elements";
    }
    if (formControl && m_state.formControls >= kMaxFormControls) {
        return "form-controls";
    }
    // litehtml's own caps, as external_element_allowed asks them.
    if (depth >= litehtml::document::max_external_depth) {
        return "depth";
    }
    if (countsLitehtml && m_state.litehtmlElements >= litehtml::document::max_external_elements) {
        return "elements";
    }
    return nullptr;
}

void RenderCut::addElement(bool formControl, bool countsLitehtml) {
    m_state.elements++;
    if (formControl) {
        m_state.formControls++;
    }
    if (countsLitehtml) {
        m_state.litehtmlElements++;
    }
}

uint32_t RenderCut::keepPieces(uint32_t count) {
    const int room = std::max(0, litehtml::document::max_text_elements - m_state.pieces);
    const uint32_t kept = std::min(count, uint32_t(room));
    m_state.pieces += int(kept);
    if (kept < count) {
        note("text-pieces");
    }
    return kept;
}

} // namespace wr
