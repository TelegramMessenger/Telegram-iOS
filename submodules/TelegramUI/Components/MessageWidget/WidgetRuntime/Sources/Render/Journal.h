// The mutation journal (M1c plan, Task 6; Ruling 13): what changed in the rendered tree since the last flush, as
// RenderTree's MutationListener recorded it. The callbacks carry no values, so an entry is a node and the kinds of
// change it saw; the flush reads the DOM as it is now.
//
// One entry per distinct node, in the order each was first recorded, each holding a Ref<Node>: an untraced, counted
// root (Global Constraints, "Payload rules"), so a recorded node cannot be freed, or its address reused, before the
// flush has read it. Every distinct node keeps its entry, however many a task changes: each is allocated under the
// session's memory limit, and what a flush does is linear in them (the fork's own session lists are searched
// linearly, quadratic up to litehtml's caps). Before the boot's build nothing is recorded: the build reads everything.
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
    /// RenderTree::userActionStateChanged: its :hover or :active may have changed (it or a descendant is the target).
    State = 1 << 5,
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

    explicit Journal(JSContext* ctx);
    /// Releases every entry's node: the context must be alive.
    ~Journal();
    Journal(const Journal&) = delete;
    Journal& operator=(const Journal&) = delete;

    /// Adds `kind` to `node`'s entry, making one (and retaining the node) the first time `node` is recorded. Records
    /// nothing before the boot's build (it reads everything). Throws std::bad_alloc (the memory limit); the journal is
    /// then unchanged.
    void record(JSContext* ctx, Node& node, JournalKind kind);

    /// The boot's build read the whole document: from here the journal records what changes. Clears it.
    void markBuilt() noexcept;
    /// Whether the boot's build has run; until it has, the next flush builds whatever the entries say.
    bool built() const { return m_built; }
    /// The render options' media changed (a width, a theme, reduced motion: twidget edits 79 and 80): the next flush
    /// applies them in its patch. Before the boot's build, the build applies them.
    void markEnvironment() noexcept { m_environment = true; }
    bool environmentPending() const { return m_environment && m_built; }
    /// A change no entry holds moved a cap's cut (a node inserted or removed where no build renders, counted by the node
    /// cap): the next flush walks the cut (RenderCut.h). Before the boot's build, the build walks everything.
    void markCut() noexcept { m_cut = true; }
    bool cutPending() const { return m_cut && m_built; }
    /// Clean: no entries, nothing pending. A patch ends with it.
    void clear() noexcept;

    /// Whether there is anything to flush.
    bool dirty() const { return !m_built || m_environment || m_cut || !m_entries.empty(); }
    /// Distinct nodes recorded (0 before the boot's build).
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
    bool m_built = false;
    bool m_environment = false;
    bool m_cut = false;
};

} // namespace wr
