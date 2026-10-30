// The event types any listener was ever added for, anywhere in the widget: what the renderer forwards taps and moves
// for (M1d). It never shrinks, as today's interest set does not: a type stays after its last listener is removed.
#pragma once

#include <cstddef>
#include <functional>
#include <string>
#include <unordered_set>
#include <vector>

#include "quickjs.h"
#include "Sources/Support/Allocator.h"

namespace wr {

class ListenedTypes {
public:
    explicit ListenedTypes(JSRuntime* rt);
    ~ListenedTypes();
    ListenedTypes(const ListenedTypes&) = delete;
    ListenedTypes& operator=(const ListenedTypes&) = delete;

    /// Records `type`. A type not seen before marks the set changed. Throws std::bad_alloc at the memory limit, with
    /// the set as it was.
    void note(JSContext* ctx, JSAtom type);
    bool contains(JSAtom type) const { return m_set.count(type) != 0; }
    /// Whether a type was noted since the last take.
    bool changed() const { return m_taken < m_order.size(); }
    /// The types noted since the previous call (PF8: a delta, not every type so far), in the order first added; empty
    /// when nothing new was noted. The set only grows, so the host accumulates what it is given: its work over a run is
    /// proportional to the note() calls. Called by the host between steps. Throws Aborted when a type's text cannot be
    /// made (out of memory); nothing is taken then.
    std::vector<std::string> takeIfChanged(JSContext* ctx);

private:
    JSRuntime* m_rt;
    /// Every type noted, in the order first added; each holds its atom.
    Vector<JSAtom> m_order;
    std::unordered_set<JSAtom, std::hash<JSAtom>, std::equal_to<JSAtom>, JSAllocator<JSAtom>> m_set;
    /// How many of m_order the takes have answered so far.
    size_t m_taken = 0;
};

} // namespace wr
