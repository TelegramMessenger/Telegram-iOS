// The mutation journal (M1c plan, Task 6; Ruling 13): what changed in the rendered tree since the last flush, as
// RenderTree's MutationListener recorded it. The callbacks carry no values, so an entry is a node and the kinds of
// change it saw; the flush reads the DOM as it is now.
//
// One entry per distinct node, in the order each was first recorded, each holding a Ref<Node>: an untraced, counted
// root (Global Constraints, "Payload rules"), so a recorded node cannot be freed, or its address reused, before the
// flush has read it. Past kMaxNodes distinct nodes the journal collapses to "rebuild everything" and releases its
// entries; so does a change only a rebuild answers (a width, a theme, a tree never built). While a rebuild is pending
// nothing more is recorded: the rebuild reads everything.
//
// Its entries and index go through QuickJS's allocator (Global Constraints, "Memory"): a failure to grow is
// std::bad_alloc at the widget's memory limit.
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <unordered_map>
#include <utility>

#include "Sources/Support/Allocator.h"
#include "Sources/Support/PlatformObject.h"

namespace wr {

class Node;

/// The kind of change, one bit per MutationListener callback.
enum class JournalKind : uint8_t {
    /// attributeChanged: one of its attributes was set, changed or removed. Which one is not kept: the flush reads
    /// the element's attributes as they are.
    Attribute = 1 << 0,
    /// characterDataChanged on a Text node: its data.
    Text = 1 << 1,
    /// childrenChanged: its children changed (it is the parent; insertions and removals under it each have their own
    /// entry for the node inserted or removed).
    Children = 1 << 2,
    /// nodeInserted: it was inserted, as a root. Its descendants have no entry of their own (the DOM tells of roots).
    Inserted = 1 << 3,
    /// nodeRemoved: it was removed from its parent, which has a Children entry.
    Removed = 1 << 4,
};

/// A set of JournalKind bits.
using JournalKinds = uint8_t;

constexpr JournalKinds journalBit(JournalKind kind) {
    return JournalKinds(kind);
}

struct JournalEntry {
    /// Held until the entry goes (the flush, a collapse, the journal's destruction).
    Ref<Node> node;
    /// Every kind recorded for it since the last flush.
    JournalKinds kinds = 0;
};

class Journal {
public:
    /// Ruling 13: a journal of more than 4,096 distinct nodes collapses to "rebuild".
    static constexpr size_t kMaxNodes = 4096;

    explicit Journal(JSContext* ctx);
    /// Releases every entry's node: the context must be alive.
    ~Journal();
    Journal(const Journal&) = delete;
    Journal& operator=(const Journal&) = delete;

    /// Adds `kind` to `node`'s entry, making one (and retaining the node) the first time `node` is recorded. Past
    /// kMaxNodes distinct nodes, collapses instead (rebuildAll). Records nothing while a rebuild is pending. Throws
    /// std::bad_alloc (the memory limit); the journal is then unchanged.
    void record(JSContext* ctx, Node& node, JournalKind kind);

    /// "Rebuild everything": drops every entry, releasing its node, and keeps the journal dirty until clear().
    void markRebuild() noexcept;
    /// Clean: no entries and no rebuild pending. A successful rebuild ends with it.
    void clear() noexcept;

    /// Whether the next flush must rebuild the whole document whatever the entries say.
    bool rebuildPending() const { return m_rebuild; }
    /// Whether there is anything to flush.
    bool dirty() const { return m_rebuild || !m_entries.empty(); }
    /// Distinct nodes recorded (0 while a rebuild is pending).
    size_t nodes() const { return m_entries.size(); }

    // For the flush's planning (Tasks 7–9): the entries in the order their nodes were first recorded, each with every
    // kind it saw. kinds() is their union, so "only Text entries" is kinds() == journalBit(JournalKind::Text).
    const Vector<JournalEntry>& entries() const { return m_entries; }
    JournalKinds kinds() const { return m_kinds; }
    /// Calls `f(Node&, JournalKinds)` for each entry that has `kind`, in order.
    template <class F>
    void forEach(JournalKind kind, F&& f) const {
        for (const JournalEntry& entry : m_entries) {
            if (entry.kinds & journalBit(kind)) {
                f(*entry.node, entry.kinds);
            }
        }
    }

private:
    using Index = std::unordered_map<Node*, size_t, std::hash<Node*>, std::equal_to<Node*>,
                                     JSAllocator<std::pair<Node* const, size_t>>>;

    Vector<JournalEntry> m_entries;
    /// Node → its entry's position: safe to key by pointer, since every key's entry holds its node.
    Index m_index;
    JournalKinds m_kinds = 0;
    bool m_rebuild = false;
};

} // namespace wr
