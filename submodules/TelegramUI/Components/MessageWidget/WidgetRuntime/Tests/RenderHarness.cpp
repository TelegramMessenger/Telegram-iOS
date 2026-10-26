#include "Tests/RenderHarness.h"

#include <utility>
#include <variant>

#include "Sources/Host/HostState.h"

namespace wr_test {

namespace {

// A deep copy of `layer`'s entries into `out`, with the set-clip/del-clip pairs that hold nothing (draw_children opens
// one on every pass that reaches a clipping item) and the lone del-clip of a display:inline clipper dropped, at every
// depth. A pair is dropped from the inside out, so a pair holding only dropped pairs goes too. set-clip-path pairs
// (a paint group's clip path) are kept.
void normalizeInto(const wr::Layer& layer, wr::Layer& out) {
    struct Open {
        size_t at;       // its index in `out`
        bool clip;       // set-clip (droppable), not set-clip-path
        bool content;
    };
    std::vector<Open> open;
    for (const wr::LayerEntry& entry : layer.entries) {
        if (const wr::PaintItem* item = std::get_if<wr::PaintItem>(&entry)) {
            if (item->kind == wr::PaintItem::Kind::SetClip || item->kind == wr::PaintItem::Kind::SetClipPath) {
                out.entries.emplace_back(*item);
                open.push_back({out.entries.size() - 1, item->kind == wr::PaintItem::Kind::SetClip, false});
                continue;
            }
            if (item->kind == wr::PaintItem::Kind::DelClip) {
                if (open.empty()) {
                    continue;   // a lone del-clip
                }
                const Open top = open.back();
                open.pop_back();
                if (top.clip && !top.content) {
                    out.entries.erase(out.entries.begin() + ptrdiff_t(top.at), out.entries.end());
                    continue;
                }
                out.entries.emplace_back(*item);
                if (!open.empty()) {
                    open.back().content = true;
                }
                continue;
            }
            out.entries.emplace_back(*item);
        } else {
            const wr::Layer& child = *std::get<std::unique_ptr<wr::Layer>>(entry);
            auto copy = std::make_unique<wr::Layer>();
            copy->kind = child.kind;
            copy->group = child.group;
            copy->filter = child.filter;
            copy->box = child.box;
            normalizeInto(child, *copy);
            out.entries.emplace_back(std::move(copy));
        }
        if (!open.empty()) {
            open.back().content = true;
        }
    }
}



} // namespace

std::shared_ptr<const wr::LayerTree> normalized(const wr::LayerTree& recorded) {
    wr::Layer root;
    root.kind = wr::Layer::Kind::Root;
    root.box = recorded.root().box;
    normalizeInto(recorded.root(), root);
    return std::make_shared<const wr::LayerTree>(recorded.width(), recorded.height(), std::move(root));
}

RenderEnv::RenderEnv(std::string_view html, wr::RenderOptions options, bool drain,
                     const std::function<void(HostEnv&)>& beforeBoot)
    : m_options(std::move(options)) {
    // Every test keeps its oracle (Ruling E11).
    m_options.keepRenderInput = true;
    m_env = HostEnv::booted(wr::BootOptions{html}, 1, [&](HostEnv& env) {
        m_tree = &wr::installRender(env.ctx(), m_host, m_options);
        if (beforeBoot) {
            beforeBoot(env);
        }
    });
    if (drain) {
        m_env->drain();
    }
}

// The runtime goes first, its HostState's tree with it (its documents call the host's fonts), then the host.
RenderEnv::~RenderEnv() = default;

std::tuple<std::string, std::string, std::string> rebuildDump(RenderEnv& env) {
    // The render tree's options as they are now: the width and the theme (its root declarations) set since boot.
    wr::RenderTree fresh(env.ctx(), env.host(), env.render().options());
    fresh.rebuild(env.ctx());
    std::shared_ptr<const wr::LayerTree> tree = fresh.layerTree();
    return {fresh.layoutDump(), fresh.renderInput(), tree ? tree->dump() : std::string()};
}

std::vector<const wr::TextItem*> textItems(const wr::LayerTree& tree) {
    std::vector<const wr::TextItem*> found;
    std::vector<std::pair<const wr::Layer*, size_t>> stack{{&tree.root(), 0}};
    while (!stack.empty()) {
        auto& [layer, next] = stack.back();
        if (next == layer->entries.size()) {
            stack.pop_back();
            continue;
        }
        const wr::LayerEntry& entry = layer->entries[next++];
        if (const wr::PaintItem* item = std::get_if<wr::PaintItem>(&entry)) {
            if (const wr::TextItem* text = std::get_if<wr::TextItem>(&item->payload)) {
                found.push_back(text);
            }
        } else {
            stack.emplace_back(std::get<std::unique_ptr<wr::Layer>>(entry).get(), 0);
        }
    }
    return found;
}

const wr::TextItem* findText(const wr::LayerTree& tree, const std::string& text) {
    for (const wr::TextItem* item : textItems(tree)) {
        if (item->text == text) {
            return item;
        }
    }
    return nullptr;
}

} // namespace wr_test
