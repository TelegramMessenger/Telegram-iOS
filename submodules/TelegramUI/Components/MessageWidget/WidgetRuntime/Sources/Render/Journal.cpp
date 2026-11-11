#include "Sources/Render/Journal.h"

#include "Sources/DOM/DOM.h"

namespace wr {

Journal::Journal(JSContext* ctx)
    : m_entries(JSAllocator<JournalEntry>(JS_GetRuntime(ctx))),
      m_index(0, std::hash<Node*>(), std::equal_to<Node*>(), JSAllocator<std::pair<Node* const, size_t>>(JS_GetRuntime(ctx))) {}

Journal::~Journal() = default;

void Journal::record(JSContext* ctx, Node& node, JournalKind kind) {
    if (!m_built) {
        return;
    }
    auto found = m_index.find(&node);
    if (found != m_index.end()) {
        m_entries[found->second].kinds |= journalBit(kind);
        m_kinds |= journalBit(kind);
        return;
    }
    // The entry, then its index: a failure of either leaves the journal as it was (a dropped entry releases its node).
    m_entries.push_back(JournalEntry{Ref<Node>::retain(ctx, &node), journalBit(kind)});
    try {
        m_index.emplace(&node, m_entries.size() - 1);
    } catch (...) {
        m_entries.pop_back();
        throw;
    }
    m_kinds |= journalBit(kind);
}

void Journal::markBuilt() noexcept {
    this->clear();
    m_built = true;
}

void Journal::clear() noexcept {
    m_index.clear();
    m_entries.clear();
    m_kinds = 0;
    m_environment = false;
    m_cut = false;
}

} // namespace wr
