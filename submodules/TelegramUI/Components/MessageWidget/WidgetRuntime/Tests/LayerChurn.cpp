#include "Tests/LayerChurn.h"

#include <algorithm>
#include <cstdio>
#include <typeinfo>
#include <utility>
#include <vector>

#include <litehtml/element.h>
#include <litehtml/render_item.h>

#include "Sources/DOM/DOM.h"
#include "Sources/Render/Journal.h"

namespace wr_test {

namespace {

// Every node of `tree`'s mirror by id.
std::unordered_map<wr::LayerId, const wr::MirrorNode*> nodesOf(const std::shared_ptr<const wr::LayerTree>& tree) {
    std::unordered_map<wr::LayerId, const wr::MirrorNode*> out;
    if (!tree || !tree->mirror()) {
        return out;
    }
    std::vector<const wr::MirrorNode*> stack{tree->mirror()};
    while (!stack.empty()) {
        const wr::MirrorNode* node = stack.back();
        stack.pop_back();
        out.emplace(node->id, node);
        for (const auto& child : node->children) {
            stack.push_back(child.get());
        }
    }
    return out;
}

std::string describeChurnOf(size_t flushes, const LayerChurn& total, size_t elements,
                            const std::map<std::string, LayerChurn>& byReason);

bool inlineLevel(int display) {
    return display == litehtml::display_inline || display == litehtml::display_inline_block ||
           display == litehtml::display_inline_table || display == litehtml::display_inline_flex ||
           display == litehtml::display_inline_grid;
}

std::type_index itemClass(litehtml::element& element) {
    const std::shared_ptr<litehtml::render_item> item = element.get_render_item();
    if (!item) {
        return std::type_index(typeid(void));
    }
    const litehtml::render_item& object = *item;
    return std::type_index(typeid(object));
}

} // namespace

LayerChurn& LayerChurn::operator+=(const LayerChurn& other) {
    removed += other.removed;
    inserted += other.inserted;
    churned += other.churned;
    churnedKeys.insert(other.churnedKeys.begin(), other.churnedKeys.end());
    return *this;
}

wr::NodeKey keyOfNode(const wr::RenderTree& tree, wr::Node* node) {
    const auto& nodes = tree.publishedBuild().nodes;
    auto found = node ? nodes.find(node) : nodes.end();
    return found == nodes.end() ? 0 : found->second.key;
}

void ChurnProbe::beforeFlush(const wr::RenderTree& tree) {
    m_pending = true;
    m_before = tree.layerTree();
    m_elements.clear();
    m_nodeOfKey.clear();
    m_inlineExcused.clear();
    m_moved.clear();
    for (const auto& [node, entry] : tree.publishedBuild().nodes) {
        if (entry.key) {
            m_nodeOfKey.emplace(entry.key, node);
        }
        if (!entry.element) {
            continue;
        }
        Element element;
        element.element = entry.element;
        element.generated = litehtml::document::generated_fingerprint(*entry.element);
        element.key = entry.key;
        element.display = int(entry.element->css().get_display());
        element.floating = int(entry.element->css().get_float());
        element.position = int(entry.element->css().get_position());
        element.item = itemClass(*entry.element);
        m_elements.emplace(node, element);
    }
    // An inline context's content: its Texts, and what goes in, out and among its children (not an attribute or a state).
    constexpr wr::JournalKinds kContent = wr::journalBit(wr::JournalKind::Text) |
                                          wr::journalBit(wr::JournalKind::Inserted) |
                                          wr::journalBit(wr::JournalKind::Removed) |
                                          wr::journalBit(wr::JournalKind::Children);
    constexpr wr::JournalKinds kMoved = wr::journalBit(wr::JournalKind::Inserted) | wr::journalBit(wr::JournalKind::Removed);
    for (const wr::JournalEntry& journaled : tree.journalForTesting().entries()) {
        if ((journaled.kinds & kMoved) != 0) {
            m_moved.insert(journaled.node.get());
        }
        if ((journaled.kinds & kContent) == 0) {
            continue;
        }
        for (wr::Node* at = journaled.node.get(); at; at = at->parent()) {
            if (const wr::NodeKey key = keyOfNode(tree, at)) {
                m_inlineExcused.insert(key);
            }
        }
    }
}

void ChurnProbe::afterPublish(const wr::RenderTree& tree) {
    if (!m_pending) {
        return;
    }
    m_pending = false;
    // The elements whose outer box changed (by node: a plain wrapper has no key), and those whose render item changed
    // class. An inline-level element whose box changed changes its inline context's runs: its ancestors' are excused.
    std::unordered_set<wr::Node*> boxChanged;
    std::unordered_set<wr::NodeKey> flipped;
    // The owners whose generated content printed differently.
    std::unordered_set<wr::NodeKey> generatedChanged;
    const auto& nodes = tree.publishedBuild().nodes;
    for (const auto& [node, was] : m_elements) {
        auto now = nodes.find(node);
        if (now == nodes.end() || !now->second.element) {
            continue;
        }
        litehtml::element& element = *now->second.element;
        const int display = int(element.css().get_display());
        if (display != was.display || int(element.css().get_float()) != was.floating ||
            int(element.css().get_position()) != was.position) {
            boxChanged.insert(node);
            if (inlineLevel(display) || inlineLevel(was.display)) {
                for (wr::Node* at = node->parent(); at; at = at->parent()) {
                    if (const wr::NodeKey key = keyOfNode(tree, at)) {
                        m_inlineExcused.insert(key);
                    }
                }
            }
        }
        if (was.key && itemClass(element) != was.item) {
            flipped.insert(was.key);
        }
        if (was.key && litehtml::document::generated_fingerprint(element) != was.generated) {
            generatedChanged.insert(was.key);
        }
    }
    // Asked only of a key with a node after the flush too, so the node is alive (a removed one may be freed by now).
    const auto boxChangedAbove = [&](wr::NodeKey key) {
        auto node = m_nodeOfKey.find(key);
        if (node == m_nodeOfKey.end()) {
            return false;
        }
        for (wr::Node* at = node->second; at; at = at->parent()) {
            if (boxChanged.count(at)) {
                return true;
            }
        }
        return false;
    };
    const std::string reason = tree.document() ? tree.document()->rebuild_reason() : std::string();
    // A key whose node now has another litehtml element than before the flush: built again by the runtime.
    const auto bucketOfNode = [&](wr::NodeKey key) -> std::string {
        auto node = m_nodeOfKey.find(key);
        if (node == m_nodeOfKey.end()) {
            return reason;
        }
        auto now = nodes.find(node->second);
        auto was = m_elements.find(node->second);
        if (now == nodes.end() || was == m_elements.end() || !now->second.element ||
            was->second.element.lock() == now->second.element) {
            return reason;
        }
        return m_moved.count(node->second) ? "(moved)" : "(built again)";
    };
    // A generated element's key goes with its owner's.
    const auto bucketOf = [&](wr::NodeKey key) -> std::string {
        const wr::NodeKey owner = tree.ownerKeyOfGenerated(key);
        return bucketOfNode(owner ? owner : key);
    };
    const auto before = nodesOf(m_before);
    const auto after = nodesOf(tree.layerTree());
    // Removed and inserted nodes by kind and key: re-created as many times as both happened.
    std::map<std::pair<int, wr::NodeKey>, std::pair<size_t, size_t>> made;
    LayerChurn churn;
    std::map<std::string, LayerChurn> buckets;
    for (const auto& [id, node] : before) {
        if (!after.count(id)) {
            churn.removed++;
            made[{int(node->kind), node->key}].first++;
        }
    }
    for (const auto& [id, node] : after) {
        if (!before.count(id)) {
            churn.inserted++;
            made[{int(node->kind), node->key}].second++;
        }
    }
    for (const auto& [kindAndKey, counts] : made) {
        const auto [kind, key] = kindAndKey;
        const size_t again = std::min(counts.first, counts.second);
        if (!key || !again || flipped.count(key) || boxChangedAbove(key)) {
            continue;
        }
        if (const wr::NodeKey owner = tree.ownerKeyOfGenerated(key);
            owner && (flipped.count(owner) || boxChangedAbove(owner) || generatedChanged.count(owner))) {
            continue;
        }
        if (kind == int(wr::MirrorNode::Kind::Inline) && m_inlineExcused.count(key)) {
            continue;
        }
        churn.churned += again;
        churn.churnedKeys.insert(key);
        LayerChurn& bucket = buckets[bucketOf(key)];
        bucket.churned += again;
        bucket.churnedKeys.insert(key);
    }
    buckets[reason].removed += churn.removed;
    buckets[reason].inserted += churn.inserted;
    m_last = churn;
    m_total += churn;
    for (const auto& [name, part] : buckets) {
        m_byReason[name] += part;
    }
    m_flushes++;
    m_before.reset();
    m_elements.clear();
    m_nodeOfKey.clear();
    m_inlineExcused.clear();
    m_moved.clear();
}

void ChurnTally::add(const ChurnProbe& probe) {
    flushes += probe.flushes();
    total.removed += probe.total().removed;
    total.inserted += probe.total().inserted;
    total.churned += probe.total().churned;
    for (const auto& [reason, churn] : probe.byReason()) {
        LayerChurn& sum = byReason[reason];
        sum.removed += churn.removed;
        sum.inserted += churn.inserted;
        sum.churned += churn.churned;
    }
    elements += probe.total().churnedKeys.size();
}

std::string ChurnTally::describe() const {
    return describeChurnOf(flushes, total, elements, byReason);
}

ScopedChurnProbe::ScopedChurnProbe(wr::RenderTree& tree, ChurnTally& tally) : m_tree(tree), m_tally(tally) {
    m_tree.setFlushProbeForTesting(&m_probe);
}

ScopedChurnProbe::~ScopedChurnProbe() {
    m_tree.setFlushProbeForTesting(nullptr);
    m_tally.add(m_probe);
}

std::string describeChurn(size_t flushes, const LayerChurn& total, const std::map<std::string, LayerChurn>& byReason) {
    return describeChurnOf(flushes, total, total.churnedKeys.size(), byReason);
}

namespace {

std::string describeChurnOf(size_t flushes, const LayerChurn& total, size_t elements,
                            const std::map<std::string, LayerChurn>& byReason) {
    char line[256];
    std::snprintf(line, sizeof line, "%zu flushes, removed %zu, inserted %zu, churned %zu (%zu elements)\n", flushes,
                  total.removed, total.inserted, total.churned, elements);
    std::string out = line;
    std::vector<std::pair<std::string, size_t>> reasons;
    for (const auto& [reason, churn] : byReason) {
        reasons.emplace_back(reason.empty() ? std::string("(none)") : reason, churn.churned);
    }
    std::sort(reasons.begin(), reasons.end(), [](const auto& a, const auto& b) {
        return a.second != b.second ? a.second > b.second : a.first < b.first;
    });
    for (const auto& [reason, churned] : reasons) {
        std::snprintf(line, sizeof line, "  %8zu %s\n", churned, reason.c_str());
        out += line;
    }
    return out;
}

} // namespace

} // namespace wr_test
