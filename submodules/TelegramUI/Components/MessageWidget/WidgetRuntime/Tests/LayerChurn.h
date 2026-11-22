// The churn metric of the fine-grained patches design: the layers a flush re-creates though their element did not change.
//
// A layer is churn when the flush removed a node and inserted another of the same kind and NodeKey (re-created), as
// many times as both happened, unless excused; a layer that goes and is not made again (a background removed, a group
// that ends) is not churn. Layers no node owns (NodeKey 0: anonymous blocks and their runs, wherever they are) are
// never counted, so a zero leaves those out. A layer is excused when its element or a DOM ancestor changed its outer
// box (display, float, position), or when its own element's render item changed class (a formatting context that
// flipped); an Inline run also when its key is that of a node whose Text, insertion, removal or children the journal
// holds, or of a DOM ancestor of one, or of an ancestor of an inline-level element whose box changed (its inline
// context's content changed). An element with only its own attribute change is not excused for its subtree, nor its
// inline context for its line. A canvas-only flush (RenderTree::publishRepaints) is not probed. A churned layer is
// counted under the fork's reason for the flush, unless its element is one the runtime built again (a new litehtml
// element for the node): then under "(moved)" when the journal holds the node's insertion or removal (a move), "(built
// again)" otherwise (an element built again though its node did not move: every node of a document element replaced,
// RenderTree::flushRoot, and walking the cut, a node whose cut moved). A generated element's layers (::before, ::after,
// a form control's lh-* part: keyed by their owner, RenderTree::ownerKeyOfGenerated) are excused with their owner, or
// when the owner's generated content printed differently (litehtml::document::generated_fingerprint), and bucketed with
// it.
#pragma once

#include <cstddef>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <typeindex>
#include <unordered_map>
#include <unordered_set>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"

namespace wr_test {

/// One flush's layers removed, inserted and churned (the file comment's rule), or a sum of them.
struct LayerChurn {
    size_t removed = 0;
    size_t inserted = 0;
    size_t churned = 0;
    /// The churned layers' elements.
    std::set<wr::NodeKey> churnedKeys;
    LayerChurn& operator+=(const LayerChurn& other);
};

/// Installed on a RenderTree (setFlushProbeForTesting), measures every flush after the boot: the last one's churn, the
/// sum, and the sum by the fork's reason for replacing render subtrees (litehtml::document::rebuild_reason, "" when the
/// flush replaced none), a churned layer of an element the runtime built again counted under "(moved)" or "(built
/// again)" instead (the file comment). A flush that stops the widget is not measured.
class ChurnProbe final : public wr::RenderTree::FlushProbe {
public:
    void beforeFlush(const wr::RenderTree& tree) override;
    void afterPublish(const wr::RenderTree& tree) override;

    const LayerChurn& last() const { return m_last; }
    const LayerChurn& total() const { return m_total; }
    const std::map<std::string, LayerChurn>& byReason() const { return m_byReason; }
    /// Flushes measured (told both before and after).
    size_t flushes() const { return m_flushes; }

private:
    struct Element {
        /// Not held: a freed element is one built again.
        std::weak_ptr<litehtml::element> element;
        /// Its generated children's print before the flush.
        std::string generated;
        wr::NodeKey key = 0;
        int display = 0;
        int floating = 0;
        int position = 0;
        std::type_index item = typeid(void);
    };
    bool m_pending = false;
    std::shared_ptr<const wr::LayerTree> m_before;
    /// Every rendered element before the flush, keyed or not (a plain wrapper has no key but can change its box).
    std::unordered_map<wr::Node*, Element> m_elements;
    std::unordered_map<wr::NodeKey, wr::Node*> m_nodeOfKey;
    std::unordered_set<wr::NodeKey> m_inlineExcused;
    /// The nodes the journal holds an insertion or removal of.
    std::unordered_set<wr::Node*> m_moved;
    LayerChurn m_last;
    LayerChurn m_total;
    std::map<std::string, LayerChurn> m_byReason;
    size_t m_flushes = 0;
};

/// `node`'s NodeKey in `tree`'s published build; 0 when it has none.
wr::NodeKey keyOfNode(const wr::RenderTree& tree, wr::Node* node);

/// "<flushes> flushes, removed <r>, inserted <i>, churned <c> (<n> elements)", then a line per reason, most churned
/// first: "  <churned> <reason>" ("(none)" for "").
std::string describeChurn(size_t flushes, const LayerChurn& total, const std::map<std::string, LayerChurn>& byReason);

/// What several probes measured, summed (a test's report over many envs). NodeKeys are per env, so `total.churnedKeys`
/// stays empty and `elements` sums each env's count.
struct ChurnTally {
    size_t flushes = 0;
    size_t elements = 0;
    LayerChurn total;
    std::map<std::string, LayerChurn> byReason;
    void add(const ChurnProbe& probe);
    /// describeChurn's text, with `elements` for the elements.
    std::string describe() const;
};

/// A ChurnProbe installed on `tree` for its own life, added to `tally` and uninstalled when it goes.
class ScopedChurnProbe {
public:
    ScopedChurnProbe(wr::RenderTree& tree, ChurnTally& tally);
    ~ScopedChurnProbe();
    ScopedChurnProbe(const ScopedChurnProbe&) = delete;
    ScopedChurnProbe& operator=(const ScopedChurnProbe&) = delete;
    const ChurnProbe& probe() const { return m_probe; }

private:
    wr::RenderTree& m_tree;
    ChurnTally& m_tally;
    ChurnProbe m_probe;
};

} // namespace wr_test
