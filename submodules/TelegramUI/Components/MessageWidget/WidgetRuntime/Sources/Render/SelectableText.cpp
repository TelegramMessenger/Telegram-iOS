#include "Sources/Render/SelectableText.h"

#include <algorithm>
#include <memory>
#include <utility>

#include <litehtml.h>
#include <litehtml/el_text.h>
#include <litehtml/render_inline.h>

#include "Sources/Render/ComputedStyle.h"

namespace wr {

namespace {

/// UTF-8 to UTF-16; a malformed sequence is one U+FFFD, as the host's conversion makes it.
std::u16string toUTF16(std::string_view utf8) {
    std::u16string out;
    out.reserve(utf8.size());
    size_t i = 0;
    while (i < utf8.size()) {
        const uint8_t lead = uint8_t(utf8[i]);
        uint32_t c = 0xFFFD;
        size_t length = 1;
        if (lead < 0x80) {
            c = lead;
        } else if (lead >= 0xC2 && lead < 0xF5) {
            length = lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
            if (i + length <= utf8.size()) {
                c = lead & (0xFF >> (length + 1));
                for (size_t k = 1; k < length; k++) {
                    const uint8_t next = uint8_t(utf8[i + k]);
                    if ((next & 0xC0) != 0x80) {
                        c = 0xFFFD;
                        length = k;
                        break;
                    }
                    c = (c << 6) | (next & 0x3F);
                }
            } else {
                length = utf8.size() - i;
            }
        }
        i += length;
        if (c >= 0x10000) {
            c -= 0x10000;
            out += char16_t(0xD800 + (c >> 10));
            out += char16_t(0xDC00 + (c & 0x3FF));
        } else {
            out += char16_t(c);
        }
    }
    return out;
}

bool inlineLevel(litehtml::style_display display) {
    return display == litehtml::display_inline || display == litehtml::display_inline_text ||
           display == litehtml::display_inline_block || display == litehtml::display_inline_table ||
           display == litehtml::display_inline_flex || display == litehtml::display_inline_grid;
}

bool overlaps(const RenderBox& a, const RenderBox& b) {
    return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}

RenderBox mapped(const RenderBox& box, const Affine& m) {
    double left = 0, top = 0, right = 0, bottom = 0;
    bool first = true;
    for (const auto& [x, y] : {std::pair{box.x, box.y}, std::pair{box.x + box.width, box.y},
                               std::pair{box.x, box.y + box.height}, std::pair{box.x + box.width, box.y + box.height}}) {
        const double mx = m.a * x + m.c * y + m.tx;
        const double my = m.b * x + m.d * y + m.ty;
        left = first ? mx : std::min(left, mx);
        right = first ? mx : std::max(right, mx);
        top = first ? my : std::min(top, my);
        bottom = first ? my : std::max(bottom, my);
        first = false;
    }
    return RenderBox{left, top, right - left, bottom - top};
}

std::shared_ptr<litehtml::render_item> firstRenderItem(const litehtml::element& element) {
    std::shared_ptr<litehtml::render_item> item;
    element.for_each_render_item([&](const std::shared_ptr<litehtml::render_item>& ri) {
        if (!item) {
            item = ri;
        }
    });
    return item;
}

/// What the runs of one parent element share: pieces of a Text node are siblings, so consecutive pieces ask once.
struct ParentFacts {
    const litehtml::element* parent = nullptr;
    bool selectable = false;
    Affine transform;
    /// The intersection of the ancestors' overflow clips (their padding boxes, layout space); none when unclipped.
    std::optional<RenderBox> clip;
    /// The nearest block container: a change between two runs is a newline.
    const litehtml::element* block = nullptr;
    litehtml::uint_ptr font = 0;
};

class Exporter {
public:
    explicit Exporter(const SelectableTextSource& source) : m_source(source) {}

    SelectableText run() {
        if (m_source.root) {
            visit(*m_source.root);
        }
        return std::move(m_out);
    }

private:
    void visit(const litehtml::element& element) {
        if (element.is_text()) {
            piece(element);
            return;
        }
        if (element.is_break()) {
            // A <br>: a newline where it is laid out inside selectable text.
            if (firstRenderItem(element) && facts(element).selectable) {
                m_pendingNewline = true;
            }
            return;
        }
        for (const auto& child : element.children()) {
            visit(*child);
        }
    }

    void piece(const litehtml::element& element) {
        const uint64_t key = m_source.keyOf(element);
        if (!key) {
            return; // generated content
        }
        const std::string& text = static_cast<const litehtml::el_text&>(element).display_text();
        const std::u16string whole = toUTF16(text);
        if (key != m_key) {
            m_key = key;
            m_keyOffset = 0;
        }
        const uint32_t pieceOffset = m_keyOffset;
        m_keyOffset += uint32_t(whole.size());
        const litehtml::element* parent = element.parent().get();
        if (!parent) {
            return;
        }
        const ParentFacts& f = facts(*parent);
        if (!f.selectable) {
            return;
        }
        if (element.is_break()) {
            m_pendingNewline = true;
            return;
        }
        if (element.is_white_space()) {
            m_pendingSpace = true;
            return;
        }
        element.for_each_render_item([&](const std::shared_ptr<litehtml::render_item>& ri) {
            std::vector<std::pair<std::shared_ptr<litehtml::render_item>, const std::string*>> parts;
            auto textItem = std::dynamic_pointer_cast<litehtml::render_text>(ri);
            if (textItem && !textItem->fragments.empty()) {
                for (const auto& fragment : textItem->fragments) {
                    parts.emplace_back(fragment, &fragment->fragment_text);
                }
            } else {
                parts.emplace_back(ri, &text);
            }
            uint32_t partOffset = 0;
            for (const auto& [part, drawn] : parts) {
                const uint32_t offset = partOffset;
                partOffset += uint32_t(toUTF16(*drawn).size());
                const int bytes = part->ellipsis_bytes();
                const std::string shown = bytes < 0 ? *drawn : drawn->substr(0, size_t(bytes));
                emit(*part, shown, f, key, pieceOffset + offset);
            }
        });
    }

    /// One run; false when it is not selectable after all (hidden, clipped, unmeasurable).
    bool emit(const litehtml::render_item& item, const std::string& shown, const ParentFacts& f, uint64_t key,
              uint32_t nodeOffset) {
        if (shown.empty()) {
            return false;
        }
        for (const litehtml::render_item* r = &item; r; r = r->parent().get()) {
            if (!r->is_visible()) {
                return false;
            }
        }
        const litehtml::position placement = item.get_placement();
        const RenderBox box{double(placement.x.value()), double(placement.y.value()), double(placement.width.value()),
                            double(placement.height.value())};
        if (f.clip && !overlaps(box, *f.clip)) {
            return false;
        }
        const RenderBox onScreen = mapped(box, f.transform);
        if (onScreen.y >= m_source.visibleHeight || onScreen.y + onScreen.height <= 0) {
            return false;
        }
        const std::u16string units = toUTF16(shown);
        std::vector<float> carets = m_source.caretOffsets(f.font, shown);
        if (carets.size() != units.size() + 1) {
            return false;
        }
        if (m_lastBlock && f.block != m_lastBlock) {
            m_pendingNewline = true;
        }
        m_lastBlock = f.block;
        separate();
        SelectableRun run;
        run.start = uint32_t(m_out.text.size());
        run.length = uint32_t(units.size());
        run.box = box;
        run.carets = std::move(carets);
        run.transform[0] = f.transform.a;
        run.transform[1] = f.transform.b;
        run.transform[2] = f.transform.c;
        run.transform[3] = f.transform.d;
        run.transform[4] = f.transform.tx;
        run.transform[5] = f.transform.ty;
        run.node = key;
        run.nodeOffset = nodeOffset;
        m_out.text += units;
        m_out.runs.push_back(std::move(run));
        return true;
    }

    /// The pending separator before a run: a newline over a space, never at the start, never two in a row.
    void separate() {
        if (!m_out.text.empty()) {
            const char16_t last = m_out.text.back();
            if (m_pendingNewline) {
                if (last != u'\n') {
                    m_out.text += u'\n';
                }
            } else if (m_pendingSpace && last != u' ' && last != u'\n') {
                m_out.text += u' ';
            }
        }
        m_pendingNewline = false;
        m_pendingSpace = false;
    }

    const ParentFacts& facts(const litehtml::element& parent) {
        if (m_facts.parent == &parent) {
            return m_facts;
        }
        ParentFacts f;
        f.parent = &parent;
        f.selectable = selectsText(parent);
        if (f.selectable) {
            visualTransform(parent, f.transform);
            for (auto r = firstRenderItem(parent); r; r = r->parent()) {
                if (r->css().get_overflow() == litehtml::overflow_visible) {
                    continue;
                }
                const litehtml::position p = r->get_placement();
                const double left = double(r->padding_left().value());
                const double top = double(r->padding_top().value());
                const RenderBox padding{double(p.x.value()) - left, double(p.y.value()) - top,
                                        double(p.width.value()) + left + double(r->padding_right().value()),
                                        double(p.height.value()) + top + double(r->padding_bottom().value())};
                if (!f.clip) {
                    f.clip = padding;
                } else {
                    const double x = std::max(f.clip->x, padding.x);
                    const double y = std::max(f.clip->y, padding.y);
                    const double right = std::min(f.clip->x + f.clip->width, padding.x + padding.width);
                    const double bottom = std::min(f.clip->y + f.clip->height, padding.y + padding.height);
                    f.clip = RenderBox{x, y, std::max(0.0, right - x), std::max(0.0, bottom - y)};
                }
            }
            for (const litehtml::element* el = &parent; el; el = el->parent().get()) {
                if (!inlineLevel(el->css().get_display())) {
                    f.block = el;
                    break;
                }
            }
            f.font = parent.css().get_font();
        }
        m_facts = f;
        return m_facts;
    }

    const SelectableTextSource& m_source;
    SelectableText m_out;
    bool m_pendingSpace = false;
    bool m_pendingNewline = false;
    const litehtml::element* m_lastBlock = nullptr;
    uint64_t m_key = 0;
    uint32_t m_keyOffset = 0;
    ParentFacts m_facts;
};

} // namespace

SelectableText exportSelectableText(const SelectableTextSource& source) {
    return Exporter(source).run();
}

} // namespace wr
