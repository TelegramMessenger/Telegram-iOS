#include "Sources/Render/LayerDiff.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <map>
#include <tuple>
#include <unordered_map>
#include <utility>

namespace wr {

namespace {

// Ruling E3: past this many Backdrop items in either tree everything changed (nullopt), which bounds the backdrop
// step at 64 × 64; a hostile page of many backdrop-filter elements would otherwise make every flush quadratic.
constexpr size_t kMaxDiffedBackdrops = 64;

// How a rect in some layer's coordinates reaches the root: through `matrix` (the enclosing groups' matrices,
// innermost first), then grown by (growX, growY), which carries the enclosing filters' reach into root units.
// `whole`: the mapping is not finite, and the rect stands for the whole canvas.
struct Mapping {
    litehtml::transform_matrix matrix;
    float growX = 0;
    float growY = 0;
    bool whole = false;
};

bool isFinite(const litehtml::transform_matrix& m) {
    return std::isfinite(m.a) && std::isfinite(m.b) && std::isfinite(m.c) && std::isfinite(m.d) &&
           std::isfinite(m.tx) && std::isfinite(m.ty);
}

bool isFinite(const litehtml::position& p) {
    return std::isfinite(p.x.value()) && std::isfinite(p.y.value()) && std::isfinite(p.width.value()) &&
           std::isfinite(p.height.value());
}

// `mapping` with a filter's reach added, in the coordinates `mapping` starts from: a blur or drop shadow spreads by up
// to its reach on every side, and the matrix carries that offset to the root as at most (|a| + |c|, |b| + |d|) times
// it.
Mapping withReach(const Mapping& mapping, const litehtml::filter_vector& steps) {
    Mapping grown = mapping;
    if (grown.whole) {
        return grown;
    }
    const float reach = litehtml::filter_reach(steps);
    if (!std::isfinite(reach)) {
        grown.whole = true;
    } else if (reach > 0) {
        const auto& m = mapping.matrix;
        grown.growX += (std::fabs(m.a) + std::fabs(m.c)) * reach;
        grown.growY += (std::fabs(m.b) + std::fabs(m.d)) * reach;
        grown.whole = !std::isfinite(grown.growX) || !std::isfinite(grown.growY);
    }
    return grown;
}

// The mapping for `layer`'s contents, given the mapping of the layer holding it.
Mapping enter(const Mapping& outer, const Layer& layer) {
    Mapping inner = outer;
    if (inner.whole) {
        return inner;
    }
    if (layer.kind == Layer::Kind::Group && !layer.group.matrix.is_identity()) {
        // Row vectors: the group's own matrix applies first, then the enclosing ones.
        inner.matrix = layer.group.matrix.then(outer.matrix);
        inner.whole = !isFinite(inner.matrix);
    } else if (layer.kind == Layer::Kind::Filter) {
        // A filter spreads its contents by up to its reach, in its own coordinates.
        inner = withReach(outer, layer.filter);
    }
    return inner;
}

class Collector {
public:
    explicit Collector(const litehtml::position& canvas) : m_canvas(canvas) {}

    /// `rect`, in the coordinates `mapping` starts from, in root coordinates; nullopt when it covers no area.
    std::optional<litehtml::position> toRoot(const Mapping& mapping, const litehtml::position& rect) const {
        if (hasNoArea(rect)) {
            return std::nullopt;
        }
        if (mapping.whole) {
            return m_canvas;
        }
        litehtml::position mapped = mapRect(mapping.matrix, rect);
        if (mapping.growX > 0 || mapping.growY > 0) {
            mapped = litehtml::position(mapped.x.value() - mapping.growX, mapped.y.value() - mapping.growY,
                                        mapped.width.value() + 2 * mapping.growX,
                                        mapped.height.value() + 2 * mapping.growY);
        }
        if (!isFinite(mapped)) {
            return m_canvas;
        }
        return mapped;
    }

    void add(const Mapping& mapping, const litehtml::position& rect) {
        if (std::optional<litehtml::position> root = toRoot(mapping, rect)) {
            push(*root);
        }
    }

    /// An entry that did not match: an item's bounds, or everything a layer paints (its own bounds and every entry
    /// inside it), as one rect.
    void addEntry(const Mapping& mapping, const LayerEntry& entry) {
        if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
            add(mapping, item->bounds);
            return;
        }
        const Layer* layer = std::get<std::unique_ptr<Layer>>(entry).get();
        if (!layer) {
            return;
        }
        litehtml::position total;
        std::vector<std::pair<const Layer*, Mapping>> stack{{layer, enter(mapping, *layer)}};
        while (!stack.empty()) {
            auto [current, inner] = stack.back();
            stack.pop_back();
            if (auto root = toRoot(inner, layerBounds(*current))) {
                total = unite(total, *root);
            }
            for (const auto& child : current->entries) {
                if (const PaintItem* item = std::get_if<PaintItem>(&child)) {
                    if (auto root = toRoot(inner, item->bounds)) {
                        total = unite(total, *root);
                    }
                } else if (const Layer* nested = std::get<std::unique_ptr<Layer>>(child).get()) {
                    stack.emplace_back(nested, enter(inner, *nested));
                }
            }
        }
        if (!hasNoArea(total)) {
            push(total);
        }
    }

    /// A backdrop filters what is painted behind it, so a change anywhere it samples changes it, however equal its
    /// item is. `backdrops` are the backdrop items' bounds in root coordinates, grown by their reach (what they sample).
    /// Each one that overlaps a changed rect is added as a changed rect itself, which may reach another backdrop: every
    /// rect, the added ones included, is checked once against every backdrop not yet added, so this ends after at most
    /// (rects + backdrops) × backdrops checks.
    void coverBackdrops(const std::vector<litehtml::position>& backdrops) {
        std::vector<bool> added(backdrops.size(), false);
        for (size_t checked = 0; checked < m_rects.size(); checked++) {
            const litehtml::position rect = m_rects[checked];
            for (size_t i = 0; i < backdrops.size(); i++) {
                if (!added[i] && overlap(backdrops[i], rect)) {
                    added[i] = true;
                    push(backdrops[i]);
                }
            }
        }
    }

    std::vector<litehtml::position> take() { return std::move(m_rects); }

private:
    // Whether the two share some area; touching edges do not.
    static bool overlap(const litehtml::position& a, const litehtml::position& b) {
        return a.x.value() < b.x.value() + b.width.value() && b.x.value() < a.x.value() + a.width.value() &&
               a.y.value() < b.y.value() + b.height.value() && b.y.value() < a.y.value() + a.height.value();
    }

    static bool identical(const litehtml::position& a, const litehtml::position& b) {
        return a.x.value() == b.x.value() && a.y.value() == b.y.value() && a.width.value() == b.width.value() &&
               a.height.value() == b.height.value();
    }

    void push(const litehtml::position& rect) {
        if (!m_rects.empty() && identical(m_rects.back(), rect)) {
            return;
        }
        m_rects.push_back(rect);
    }

    litehtml::position m_canvas;
    std::vector<litehtml::position> m_rects;
};

// Every backdrop item of `tree`, its bounds mapped to the root and grown by its steps' reach, appended to
// `backdrops`. false, and stops, when the tree holds more than kMaxDiffedBackdrops of them.
bool collectBackdrops(const LayerTree& tree, const Collector& collector, std::vector<litehtml::position>& backdrops) {
    size_t count = 0;
    std::vector<std::pair<const Layer*, Mapping>> stack{{&tree.root(), Mapping{}}};
    while (!stack.empty()) {
        auto [layer, mapping] = stack.back();
        stack.pop_back();
        for (const auto& entry : layer->entries) {
            if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
                if (const auto* backdrop = std::get_if<BackdropItem>(&item->payload)) {
                    if (++count > kMaxDiffedBackdrops) {
                        return false;
                    }
                    if (auto root = collector.toRoot(withReach(mapping, backdrop->steps), item->bounds)) {
                        backdrops.push_back(*root);
                    }
                }
            } else if (const Layer* child = std::get<std::unique_ptr<Layer>>(entry).get()) {
                stack.emplace_back(child, enter(mapping, *child));
            }
        }
    }
    return true;
}

// ---- Mirrors (Task 10b). ----

// The mapping a context's children are in, given the one the context itself is in: through its group's matrix, then its
// filter's reach (the group layer, then the filter layer inside it, as flattening makes them).
Mapping enterContext(const Mapping& outer, const MirrorNode& context) {
    const MirrorGroup* group = context.group.get();
    if (!group) {
        return outer;
    }
    Layer shell;
    shell.kind = Layer::Kind::Group;
    shell.group = group->group;
    Mapping inner = enter(outer, shell);
    if (group->filtered) {
        inner = withReach(inner, group->filter);
    }
    return inner;
}

litehtml::position shiftedBy(const litehtml::position& p, float dx, float dy) {
    return litehtml::position(p.x.value() + dx, p.y.value() + dy, p.width.value(), p.height.value());
}

// The rect a mirror node paints in root coordinates: `mapping` and (x, y) are its context's (the absolute origin its own
// origin is relative to). A Context's is everything inside it, its group's bounds, clip path and backdrop included.
litehtml::position nodeRect(const Collector& collector, const MirrorNode& node, const Mapping& mapping, float x,
                            float y) {
    litehtml::position total;
    struct Frame {
        const MirrorNode* node;
        Mapping mapping;
        float x, y;
    };
    std::vector<Frame> stack{{&node, mapping, x, y}};
    while (!stack.empty()) {
        Frame frame = stack.back();
        stack.pop_back();
        const MirrorNode& at = *frame.node;
        const float ox = frame.x + at.origin.x;
        const float oy = frame.y + at.origin.y;
        if (at.kind != MirrorNode::Kind::Context) {
            if (!at.content) {
                continue;
            }
            litehtml::position local;
            for (const auto& entry : at.content->entries) {
                local = unite(local, entryBounds(entry));
            }
            if (auto root = collector.toRoot(frame.mapping, shiftedBy(local, ox, oy))) {
                total = unite(total, *root);
            }
            continue;
        }
        if (const MirrorGroup* group = at.group.get()) {
            Layer shell;
            shell.kind = Layer::Kind::Group;
            shell.group = group->group;
            const Mapping inGroup = enter(frame.mapping, shell);
            if (auto root = collector.toRoot(inGroup, group->group.bounds)) {
                total = unite(total, *root);
            }
        }
        const Mapping inner = enterContext(frame.mapping, at);
        for (const auto& child : at.children) {
            stack.push_back({child.get(), inner, ox, oy});
        }
    }
    return total;
}

// Every backdrop of a mirror, in root coordinates grown by its reach. false past kMaxDiffedBackdrops.
bool collectMirrorBackdrops(const MirrorNode& root, const Collector& collector, std::vector<litehtml::position>& out) {
    size_t count = 0;
    struct Frame {
        const MirrorNode* node;
        Mapping mapping;
    };
    std::vector<Frame> stack{{&root, Mapping{}}};
    while (!stack.empty()) {
        Frame frame = stack.back();
        stack.pop_back();
        if (frame.node->kind != MirrorNode::Kind::Context) {
            continue;
        }
        if (const MirrorGroup* group = frame.node->group.get(); group && group->backdrop) {
            if (++count > kMaxDiffedBackdrops) {
                return false;
            }
            Layer shell;
            shell.kind = Layer::Kind::Group;
            shell.group = group->group;
            const Mapping reach = withReach(enter(frame.mapping, shell), group->backdrop->steps);
            if (auto rect = collector.toRoot(reach, group->group.bounds)) {
                out.push_back(*rect);
            }
        }
        const Mapping inner = enterContext(frame.mapping, *frame.node);
        for (const auto& child : frame.node->children) {
            stack.push_back({child.get(), inner});
        }
    }
    return true;
}

bool sameRadius(const litehtml::border_radiuses& a, const litehtml::border_radiuses& b) {
    return a.top_left_x == b.top_left_x && a.top_left_y == b.top_left_y && a.top_right_x == b.top_right_x &&
           a.top_right_y == b.top_right_y && a.bottom_right_x == b.bottom_right_x &&
           a.bottom_right_y == b.bottom_right_y && a.bottom_left_x == b.bottom_left_x && a.bottom_left_y == b.bottom_left_y;
}

bool sameClips(const std::vector<MirrorClip>& a, const std::vector<MirrorClip>& b) {
    if (a.size() != b.size()) {
        return false;
    }
    for (size_t i = 0; i < a.size(); i++) {
        if (a[i].key != b[i].key || !(a[i].box == b[i].box) || !sameRadius(a[i].radius, b[i].radius)) {
            return false;
        }
    }
    return true;
}

// Where a node sits and what it is, without what it holds: kind, origin, pass, clips, and a context's own properties.
bool samePlace(const MirrorNode& a, const MirrorNode& b) {
    if (a.kind != b.kind || a.origin.x != b.origin.x || a.origin.y != b.origin.y || a.pass != b.pass ||
        a.zindex != b.zindex || !sameClips(a.clips, b.clips)) {
        return false;
    }
    if (a.kind == MirrorNode::Kind::Context) {
        return a.context == b.context && a.escapes == b.escapes && sameMirrorGroup(a.group.get(), b.group.get());
    }
    return true;
}

bool sameNodeContent(const MirrorNode& a, const MirrorNode& b) {
    if (a.content == b.content) {
        return true;
    }
    if (!a.content || !b.content) {
        return false;
    }
    return sameContent(*a.content, *b.content);
}

std::optional<std::vector<litehtml::position>> mirrorChangedRects(const MirrorNode& before, const MirrorNode& after,
                                                                  const litehtml::position& canvas) {
    Collector collector(canvas);
    std::vector<litehtml::position> backdrops;
    if (!collectMirrorBackdrops(before, collector, backdrops) || !collectMirrorBackdrops(after, collector, backdrops)) {
        return std::nullopt;
    }
    auto push = [&collector](const litehtml::position& rect) {
        if (!hasNoArea(rect)) {
            collector.add(Mapping{}, rect);
        }
    };
    struct Pair {
        const MirrorNode* a;
        const MirrorNode* b;
        Mapping ma, mb;   // the mappings each context's children are in
        float ax, ay, bx, by;   // each context's absolute origin
    };
    std::vector<Pair> stack;
    if (!samePlace(before, after)) {
        push(nodeRect(collector, before, Mapping{}, 0, 0));
        push(nodeRect(collector, after, Mapping{}, 0, 0));
    } else {
        stack.push_back({&before, &after, enterContext(Mapping{}, before), enterContext(Mapping{}, after), before.origin.x,
                         before.origin.y, after.origin.x, after.origin.y});
    }
    while (!stack.empty()) {
        Pair pair = stack.back();
        stack.pop_back();
        // The children matched first by identity (the same object in both trees: a mirror's publishes share every node no
        // operation names), then by kind, key and order among the rest of that kind and key.
        std::vector<bool> taken(pair.b->children.size(), false);
        std::vector<size_t> same(pair.a->children.size(), SIZE_MAX);
        {
            std::unordered_map<const MirrorNode*, size_t> inBByObject;
            for (size_t j = 0; j < pair.b->children.size(); j++) {
                inBByObject.emplace(pair.b->children[j].get(), j);
            }
            for (size_t i = 0; i < pair.a->children.size(); i++) {
                if (auto found = inBByObject.find(pair.a->children[i].get()); found != inBByObject.end()) {
                    same[i] = found->second;
                    taken[found->second] = true;
                }
            }
        }
        std::map<std::tuple<int, NodeKey, size_t>, size_t> inB;
        {
            std::map<std::pair<int, NodeKey>, size_t> seen;
            for (size_t i = 0; i < pair.b->children.size(); i++) {
                if (taken[i]) {
                    continue;
                }
                const MirrorNode& child = *pair.b->children[i];
                const auto kind = std::make_pair(int(child.kind), child.key);
                inB[{kind.first, kind.second, seen[kind]++}] = i;
            }
        }
        std::vector<std::pair<size_t, size_t>> matched;
        {
            std::map<std::pair<int, NodeKey>, size_t> seen;
            for (size_t i = 0; i < pair.a->children.size(); i++) {
                if (same[i] != SIZE_MAX) {
                    matched.emplace_back(i, same[i]);
                    continue;
                }
                const MirrorNode& child = *pair.a->children[i];
                const auto kind = std::make_pair(int(child.kind), child.key);
                auto found = inB.find({kind.first, kind.second, seen[kind]++});
                if (found == inB.end()) {
                    push(nodeRect(collector, child, pair.ma, pair.ax, pair.ay));
                    continue;
                }
                matched.emplace_back(i, found->second);
                taken[found->second] = true;
            }
        }
        for (size_t j = 0; j < pair.b->children.size(); j++) {
            if (!taken[j]) {
                push(nodeRect(collector, *pair.b->children[j], pair.mb, pair.bx, pair.by));
            }
        }
        // Children that changed order give every matched child's rects. With nodes shared (a mirror's publish), the order
        // is the shared ones': a pair matched by key that sits elsewhere among them (a removed node and an inserted one
        // with its key) gives its own.
        const bool shared = std::any_of(same.begin(), same.end(), [](size_t j) { return j != SIZE_MAX; });
        bool reordered = false;
        std::vector<bool> elsewhere(matched.size(), false);
        if (!shared) {
            for (size_t k = 1; k < matched.size(); k++) {
                reordered = reordered || matched[k].second < matched[k - 1].second;
            }
        } else {
            std::vector<size_t> below(matched.size(), SIZE_MAX), above(matched.size(), SIZE_MAX);
            size_t last = SIZE_MAX;
            for (size_t k = 0; k < matched.size(); k++) {
                below[k] = last;
                if (same[matched[k].first] != SIZE_MAX) {
                    reordered = reordered || (last != SIZE_MAX && matched[k].second < last);
                    last = matched[k].second;
                }
            }
            last = SIZE_MAX;
            for (size_t k = matched.size(); k-- > 0;) {
                above[k] = last;
                if (same[matched[k].first] != SIZE_MAX) {
                    last = matched[k].second;
                }
            }
            size_t keyed = SIZE_MAX;   // the last pair matched by key, which one after it must not precede
            for (size_t k = 0; k < matched.size(); k++) {
                if (same[matched[k].first] != SIZE_MAX) {
                    continue;
                }
                const size_t j = matched[k].second;
                elsewhere[k] = (below[k] != SIZE_MAX && j < below[k]) || (above[k] != SIZE_MAX && j > above[k]);
                if (keyed != SIZE_MAX && j < matched[keyed].second) {
                    elsewhere[k] = true;
                    elsewhere[keyed] = true;
                }
                keyed = k;
            }
        }
        for (size_t k = 0; k < matched.size(); k++) {
            const auto [i, j] = matched[k];
            const MirrorNode& a = *pair.a->children[i];
            const MirrorNode& b = *pair.b->children[j];
            if (&a == &b && !reordered && pair.ax == pair.bx && pair.ay == pair.by) {
                continue;
            }
            if (reordered || elsewhere[k] || !samePlace(a, b)) {
                push(nodeRect(collector, a, pair.ma, pair.ax, pair.ay));
                push(nodeRect(collector, b, pair.mb, pair.bx, pair.by));
                continue;
            }
            if (a.kind == MirrorNode::Kind::Context) {
                stack.push_back({&a, &b, enterContext(pair.ma, a), enterContext(pair.mb, b), pair.ax + a.origin.x,
                                 pair.ay + a.origin.y, pair.bx + b.origin.x, pair.by + b.origin.y});
                continue;
            }
            if (!sameNodeContent(a, b)) {
                push(nodeRect(collector, a, pair.ma, pair.ax, pair.ay));
                push(nodeRect(collector, b, pair.mb, pair.bx, pair.by));
            }
        }
    }
    if (!backdrops.empty()) {
        collector.coverBackdrops(backdrops);
    }
    return collector.take();
}

} // namespace

std::optional<std::vector<litehtml::position>> mirrorRects(const MirrorNode* before, const MirrorNode& after,
                                                           const std::vector<MirrorPath>& nodes, double width,
                                                           double height) {
    Collector collector(litehtml::position(0, 0, float(width), float(height)));
    std::vector<litehtml::position> backdrops;
    if ((before && !collectMirrorBackdrops(*before, collector, backdrops)) ||
        !collectMirrorBackdrops(after, collector, backdrops)) {
        return std::nullopt;
    }
    for (const auto& [path, node] : nodes) {
        Mapping mapping;
        float x = 0, y = 0;
        for (const MirrorNode* ancestor : path) {
            x += ancestor->origin.x;
            y += ancestor->origin.y;
            mapping = enterContext(mapping, *ancestor);
        }
        const litehtml::position rect = nodeRect(collector, *node, mapping, x, y);
        if (!hasNoArea(rect)) {
            collector.add(Mapping{}, rect);
        }
    }
    if (!backdrops.empty()) {
        collector.coverBackdrops(backdrops);
    }
    return collector.take();
}

std::optional<std::vector<litehtml::position>> changedRects(const LayerTree* before, const LayerTree& after) {
    if (!before || before->width() != after.width() || before->height() != after.height()) {
        return std::nullopt;
    }
    if (before->mirror() && after.mirror()) {
        return mirrorChangedRects(*before->mirror(), *after.mirror(),
                                  litehtml::position(0, 0, float(after.width()), float(after.height())));
    }
    Collector collector(litehtml::position(0, 0, float(after.width()), float(after.height())));
    // The backdrops first, in either tree: a backdrop in `after` now shows something else when what it samples changed,
    // and one in `before` is where it was shown. Too many, and everything changed (kMaxDiffedBackdrops).
    std::vector<litehtml::position> backdrops;
    if (!collectBackdrops(*before, collector, backdrops) || !collectBackdrops(after, collector, backdrops)) {
        return std::nullopt;
    }
    // Pairs of layers with equal own properties, walked in parallel; `index` is the next entry of both.
    struct Frame {
        const Layer* a;
        const Layer* b;
        size_t index;
        Mapping mapping;
    };
    std::vector<Frame> stack{{&before->root(), &after.root(), 0, Mapping{}}};
    while (!stack.empty()) {
        Frame& frame = stack.back();
        const size_t count = std::max(frame.a->entries.size(), frame.b->entries.size());
        if (frame.index >= count) {
            stack.pop_back();
            continue;
        }
        const size_t index = frame.index++;
        const LayerEntry* a = index < frame.a->entries.size() ? &frame.a->entries[index] : nullptr;
        const LayerEntry* b = index < frame.b->entries.size() ? &frame.b->entries[index] : nullptr;
        const Mapping mapping = frame.mapping;   // `frame` dies with the next push
        if (a && b) {
            const PaintItem* itemA = std::get_if<PaintItem>(a);
            const PaintItem* itemB = std::get_if<PaintItem>(b);
            if (itemA && itemB) {
                if (!samePaint(*itemA, *itemB)) {
                    collector.add(mapping, itemA->bounds);
                    collector.add(mapping, itemB->bounds);
                }
                continue;
            }
            if (!itemA && !itemB) {
                const Layer* layerA = std::get<std::unique_ptr<Layer>>(*a).get();
                const Layer* layerB = std::get<std::unique_ptr<Layer>>(*b).get();
                if (layerA && layerB && sameLayerProperties(*layerA, *layerB)) {
                    stack.push_back({layerA, layerB, 0, enter(mapping, *layerA)});
                    continue;
                }
            }
        }
        if (a) {
            collector.addEntry(mapping, *a);
        }
        if (b) {
            collector.addEntry(mapping, *b);
        }
    }
    // A backdrop in either tree that samples a changed rect is changed too.
    if (!backdrops.empty()) {
        collector.coverBackdrops(backdrops);
    }
    return collector.take();
}

} // namespace wr
