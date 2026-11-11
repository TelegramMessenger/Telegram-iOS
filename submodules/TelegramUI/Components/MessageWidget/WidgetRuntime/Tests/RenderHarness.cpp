#include "Tests/RenderHarness.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <map>
#include <memory>
#include <sstream>
#include <unordered_map>
#include <utility>
#include <variant>

#include "Sources/DOM/DOMState.h"
#include "Sources/DOM/Document.h"
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

void RenderEnv::buildAfresh() {
    auto fresh = std::make_unique<wr::RenderTree>(this->ctx(), m_host, m_tree->options());
    fresh->build(this->ctx());
    m_tree = fresh.get();
    wr::HostState::of(this->ctx()).setRender(std::move(fresh));
}

std::string insertsMismatch(const wr::LayerTree& tree, const std::vector<wr::LayerOp>& ops) {
    std::map<wr::LayerId, std::vector<wr::LayerId>> replayed{{0, {}}};
    for (size_t i = 0; i < ops.size(); i++) {
        const wr::LayerOp& op = ops[i];
        if (op.kind != wr::LayerOp::Insert) {
            return "op " + std::to_string(i) + " is not an Insert";
        }
        auto parent = replayed.find(op.parent);
        if (parent == replayed.end() || replayed.count(op.node)) {
            return "op " + std::to_string(i) + " names an unknown parent or a node inserted already";
        }
        std::vector<wr::LayerId>& list = parent->second;
        auto at = list.begin();
        if (op.after != 0) {
            at = std::find(list.begin(), list.end(), op.after);
            if (at == list.end()) {
                return "op " + std::to_string(i) + " follows a node its parent does not hold";
            }
            ++at;
        }
        list.insert(at, op.node);
        replayed[op.node];
    }
    std::map<wr::LayerId, std::vector<wr::LayerId>> expected{{0, {tree.mirror()->id}}};
    std::vector<const wr::MirrorNode*> stack{tree.mirror()};
    while (!stack.empty()) {
        const wr::MirrorNode* node = stack.back();
        stack.pop_back();
        std::vector<wr::LayerId>& list = expected[node->id];
        for (const auto& child : node->children) {
            list.push_back(child->id);
            stack.push_back(child.get());
        }
    }
    return replayed == expected ? std::string() : std::string("the replayed structure is not the tree's");
}

std::tuple<std::string, std::string, std::string> rebuildDump(RenderEnv& env) {
    // The render tree's options as they are now: the width and the theme (its root declarations) set since boot. A later
    // build's: litehtml's step budget cuts the boot alone (Ruling E19).
    wr::RenderOptions options = env.render().options();
    options.selectorStepCut = false;
    wr::RenderTree fresh(env.ctx(), env.host(), options);
    fresh.build(env.ctx());
    std::shared_ptr<const wr::LayerTree> tree = fresh.layerTree();
    return {fresh.layoutDump(), fresh.renderInput(), tree ? tree->dump() : std::string()};
}

std::string totalsMismatch(const wr::RenderTree& flushed, const wr::RenderTree& fresh) {
    const wr::RenderBuild& a = flushed.publishedBuild();
    const wr::RenderBuild& b = fresh.publishedBuild();
    std::string out;
    const auto note = [&](const char* name, uint64_t x, uint64_t y) {
        if (x != y) {
            out += std::string(name) + " " + std::to_string(x) + "/" + std::to_string(y) + " ";
        }
    };
    note("boxes", a.boxes, b.boxes);
    note("bytes", a.bytes, b.bytes);
    note("units", a.textUnits.units, b.textUnits.units);
    note("complex", a.textUnits.complex, b.textUnits.complex);
    note("elements", a.elementCount, b.elementCount);
    note("formControls", a.formControlCount, b.formControlCount);
    if (a.styleSheets != b.styleSheets) {
        out += "styleSheets ";
    }
    bool sheets = a.sheets.size() == b.sheets.size();
    for (const auto& [node, sheet] : a.sheets) {
        auto other = b.sheets.find(node);
        sheets = sheets && other != b.sheets.end() && other->second.utf8 == sheet.utf8 &&
                 other->second.length == sheet.length && other->second.text.units == sheet.text.units &&
                 other->second.text.complex == sheet.text.complex &&
                 other->second.strings.units == sheet.strings.units &&
                 other->second.strings.complex == sheet.strings.complex;
    }
    if (!sheets) {
        out += "sheets ";
    }
    return out;
}

bool countsMatchAFreshBuild(RenderEnv& env, const std::string& what) {
    wr::RenderOptions options = env.render().options();
    options.selectorStepCut = false;
    wr::RenderTree fresh(env.ctx(), env.host(), options);
    fresh.build(env.ctx());
    const litehtml::document* flushed = env.render().document();
    const litehtml::document* built = fresh.document();
    if (!flushed || !built) {
        return flushed == built;
    }
    const std::string totals = totalsMismatch(env.render(), fresh);
    const bool same = flushed->build_elements() == built->build_elements() &&
                      flushed->pseudo_elements() == built->pseudo_elements() &&
                      flushed->text_elements() == built->text_elements() &&
                      env.render().renderLimits() == fresh.renderLimits() && totals.empty();
    if (!same) {
        std::string a, b;
        for (const std::string& kind : env.render().renderLimits()) a += kind + " ";
        for (const std::string& kind : fresh.renderLimits()) b += kind + " ";
        std::printf("  counts differ after %s: elements %d/%d, pseudo %d/%d, pieces %d/%d, limits [%s] / [%s],"
                    " totals [%s]\n",
                    what.c_str(), flushed->build_elements(), built->build_elements(), flushed->pseudo_elements(),
                    built->pseudo_elements(), flushed->text_elements(), built->text_elements(), a.c_str(), b.c_str(),
                    totals.c_str());
    }
    return same;
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

std::string readsDump(wr::RenderTree& tree, JSContext* ctx) {
    wr::Document& document = wr::DOMState::of(ctx).document();
    std::vector<const wr::Node*> order;
    std::unordered_map<const wr::Node*, size_t> position;
    for (const wr::Node* node = &document; node; node = node->nextInTreeOrder(&document)) {
        position.emplace(node, order.size());
        order.push_back(node);
    }
    std::ostringstream out;
    out.precision(10);
    const auto box = [&](const wr::RenderBox& b) { out << b.x << ',' << b.y << ',' << b.width << ',' << b.height; };
    const auto rects = [&](const std::vector<wr::RenderBox>& list) {
        out << '[';
        for (const wr::RenderBox& b : list) {
            box(b);
            out << ' ';
        }
        out << ']';
    };
    static const char* const kProperties[] = {"display", "position", "width", "height", "color", "font-size", "transform", "opacity"};
    size_t elements = 0;
    for (size_t i = 0; i < order.size() && elements < 600; i++) {
        const wr::Node& node = *order[i];
        if (node.type() != wr::NodeType::Element) {
            continue;
        }
        // kEditHelpersJS's `excluded` subtrees, whole.
        const std::string id = static_cast<wr::Element&>(const_cast<wr::Node&>(node)).id(ctx).utf8();
        if (id == "filler" || id == "filler2" || id == "inputs") {
            const wr::Node* next = node.nextSkippingChildren(&document);
            i = next ? position.at(next) - 1 : order.size();
            continue;
        }
        elements++;
        out << '#' << i << " b ";
        if (const std::optional<wr::RenderBox> border = tree.borderBox(node)) {
            box(*border);
        } else {
            out << '-';
        }
        const std::vector<wr::RenderBox> client = tree.clientRects(node);
        out << " c ";
        rects(client);
        out << " v ";
        rects(tree.visualRects(node, client));
        for (const char* property : kProperties) {
            const std::optional<std::string> value = tree.computedStyleValue(node, property, wr::PseudoElement::None);
            out << ' ' << property << '=' << (value ? *value : "-");
        }
        const std::optional<std::string> before = tree.computedStyleValue(node, "content", wr::PseudoElement::Before);
        out << " ::before=" << (before ? *before : "-") << '\n';
    }
    const double width = tree.layoutWidth(), height = std::min(tree.documentHeight(), 1000.0);
    out << "hits";
    for (double y = 16; y < height; y += 32) {
        for (double x = 16; x < width; x += 32) {
            const wr::Node* hit = tree.nodeAt(x, y);
            auto found = hit ? position.find(hit) : position.end();
            out << ' ' << (found == position.end() ? std::string("-") : std::to_string(found->second));
        }
    }
    out << '\n';
    if (std::optional<wr::SelectableText> text = tree.selectableText(height)) {
        out << "text";
        for (char16_t unit : text->text) {
            out << ' ' << unsigned(unit);
        }
        out << '\n';
        for (const wr::SelectableRun& run : text->runs) {
            out << "run " << run.start << '+' << run.length << ' ';
            box(run.box);
            out << " at " << run.nodeOffset << " t";
            for (double v : run.transform) {
                out << ' ' << v;
            }
            out << '\n';
        }
    } else {
        out << "text -\n";
    }
    return out.str();
}

} // namespace wr_test
