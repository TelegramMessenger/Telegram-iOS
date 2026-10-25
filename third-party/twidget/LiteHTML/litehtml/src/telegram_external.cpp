// Telegram (VENDOR.md edit 12): building a litehtml document from an external DOM, element by element, instead of
// from an HTML string. The builder creates elements with create_element(), splices them with insert_child(),
// appends text with append_text(), asks external_element_allowed() before each element (the caps create_node
// enforces), and ends with finalize_from_external_root().
#include "html.h"
#include "document.h"
#include "document_container.h"
#include "el_space.h"
#include "el_anchor.h"
#include "el_before_after.h"
#include "el_body.h"
#include "el_div.h"
#include "el_form.h"
#include "el_image.h"
#include "el_para.h"
#include "el_svg.h"
#include "el_table.h"
#include "el_td.h"
#include "el_tr.h"
#include "html_tag.h"
#include "el_text.h"
#include "telegram_external.h"
#include <algorithm>
#include <iterator>
#include <cstring>
#include <typeinfo>

namespace litehtml
{
    bool is_raw_text_parent(const element& parent)
    {
        return parent.tag() == _style_ || parent.tag() == _script_;
    }

    void document::insert_child(const element::ptr& parent, size_t index, const element::ptr& child)
    {
        if(!parent || !child)
            return;
        // The parent's own appendChild decides what it accepts (a <style> takes text only) and sets the parent.
        if(!parent->appendChild(child))
            return;
        const size_t count = parent->m_children.size();
        if(index >= count - 1)
            return;
        auto at = parent->m_children.begin();
        std::advance(at, index);
        parent->m_children.splice(at, parent->m_children, std::prev(parent->m_children.end()));
    }

    void document::remove_child(const element::ptr& child)
    {
        if(!child)
            return;
        element::ptr parent = child->parent();
        if(!parent)
            return;
        auto leaves = [&child](const element::ptr& hovered) {
            for(element::ptr el = hovered; el; el = el->parent())
            {
                if(el == child)
                    return true;
            }
            return false;
        };
        const bool over   = leaves(m_over_element);
        const bool active = leaves(m_active_element);
        parent->removeChild(child);
        if(!over && !active)
            return;
        // A parent that is itself detached has no attached ancestor either, so the answer is the parent or none.
        element::ptr attached = parent;
        while(attached && attached != m_root)
            attached = attached->parent();
        element::ptr target = attached ? parent : nullptr;
        if(over)
            m_over_element = target;
        if(active)
            m_active_element = target;
    }

    bool document::append_text(const element::ptr& parent, const char* text, std::vector<element::ptr>& pieces)
    {
        if(!parent || !text)
            return true;
        bool ok = true;
        auto add = [&](const element::ptr& piece) {
            if(parent->appendChild(piece))
                pieces.push_back(piece);
        };
        if(is_raw_text_parent(*parent))
        {
            if(!text_element_allowed())
            {
                m_build_limited = true;
                return false;
            }
            add(std::make_shared<el_text>(text, shared_from_this()));
            return true;
        }
        m_container->split_text(
            text,
            [&](const char* word) {
                if(!ok)
                    return;
                if(!text_element_allowed())
                {
                    m_build_limited = true;
                    ok              = false;
                    return;
                }
                add(std::make_shared<el_text>(word, shared_from_this()));
            },
            [&](const char* space) {
                if(!ok)
                    return;
                if(!text_element_allowed())
                {
                    m_build_limited = true;
                    ok              = false;
                    return;
                }
                add(std::make_shared<el_space>(space, shared_from_this()));
            });
        return ok;
    }

    bool document::external_element_allowed(int depth)
    {
        if(depth >= max_build_depth || m_build_elements >= max_build_elements)
        {
            m_container->sanitizer_limit(depth >= max_build_depth ? "depth" : "elements");
            m_build_limited = true;
            return false;
        }
        m_build_elements++;
        return true;
    }
    // Telegram (VENDOR.md edit 16): text patched in place.
    namespace
    {
        // Elements whose generated content or drawing reads their descendants' text.
        bool text_read_by_element(const element& el)
        {
            static const char* const names[] = {"select", "option", "optgroup", "datalist", "textarea",
                                                "button", "input",  "progress", "meter",    "svg"};
            const char* tag = el.get_tagName();
            if(!tag)
                return false;
            for(const char* name : names)
            {
                if(!std::strcmp(tag, name))
                    return true;
            }
            return false;
        }
    } // namespace

    bool document::can_replace_text(const element::ptr& parent, size_t first, size_t count, const char* text,
                                    int pending_growth, int* growth) const
    {
        if(!parent || !text || !m_finalized || !m_root || is_raw_text_parent(*parent))
            return false;
        // Telegram (VENDOR.md edit 17): pseudo-element content makes a patch and a rebuild cut at different words.
        if(pseudo_content_possible())
            return false;
        for(element::ptr el = parent; el; el = el->parent())
        {
            if(text_read_by_element(*el))
                return false;
        }
        const elements_list& children = parent->children();
        if(first > children.size() || count > children.size() - first)
            return false;
        auto at = children.begin();
        std::advance(at, first);
        for(size_t i = 0; i < count; i++, ++at)
        {
            const element& el = **at;
            if(typeid(el) != typeid(el_text) && typeid(el) != typeid(el_space))
                return false;
        }
        int pieces = 0;
        m_container->split_text(text, [&pieces](const char*) { pieces++; }, [&pieces](const char*) { pieces++; });
        const int delta = pieces - int(count);
        const int base  = m_patch_pending ? m_patch_text_base + m_patch_growth : int(m_text_elements);
        if(base + pending_growth + delta > max_text_elements + m_text_allowance)
            return false;
        if(growth)
            *growth = delta;
        return true;
    }

    bool document::replace_text(const element::ptr& parent, size_t first, size_t count, const char* text,
                                std::vector<element::ptr>& pieces)
    {
        int growth = 0;
        if(!can_replace_text(parent, first, count, text, 0, &growth))
            return false;
        if(!m_patch_pending)
        {
            // Telegram (VENDOR.md edit 18): the patch session's selector-step budget, unless the caller opened one.
            if(!m_step_session_open)
            {
                begin_selector_steps();
                m_step_session_auto = true;
            }
            m_patch_pending   = true;
            m_patch_keep_tree = true;
            m_patch_text_base = m_text_elements;
            m_patch_growth    = 0;
            m_patch_new_text.clear();
        }
        elements_list created;
        m_container->split_text(
            text, [&](const char* word) { created.push_back(std::make_shared<el_text>(word, shared_from_this())); },
            [&](const char* space) { created.push_back(std::make_shared<el_space>(space, shared_from_this())); });
        auto from = parent->m_children.begin();
        std::advance(from, first);
        auto to = from;
        std::advance(to, count);
        std::vector<element::ptr> old(from, to);
        // The pointer elements leave with the pieces they were over.
        auto in_old = [&old](const element::ptr& hovered) {
            return hovered && std::find(old.begin(), old.end(), hovered) != old.end();
        };
        if(in_old(m_over_element))
            m_over_element = parent;
        if(in_old(m_active_element))
            m_active_element = parent;
        for(const auto& piece : created)
        {
            piece->parent(parent);
            parent->m_children.insert(from, piece);
        }
        parent->m_children.erase(from, to);
        if(m_patch_keep_tree && !replace_text_renderers(old, created))
            m_patch_keep_tree = false;
        m_patch_growth += growth;
        // Telegram (VENDOR.md edit 17): the replaced pieces stay alive and uncounted until commit_patch.
        m_patch_released += int(old.size());
        m_patch_hold.insert(m_patch_hold.end(), old.begin(), old.end());
        m_patch_new_text.insert(m_patch_new_text.end(), created.begin(), created.end());
        pieces.assign(created.begin(), created.end());
        return true;
    }

    namespace
    {
        bool generated_content(const element& el); // Telegram (VENDOR.md edit 42): defined with the structure patches
    }

    void document::commit_patch()
    {
        if(!m_patch_pending)
            return;
        m_patch_pending = false;
        m_patch_growth  = 0;
        std::vector<element::ptr> new_text;
        new_text.swap(m_patch_new_text);
        const bool keep_tree = m_patch_keep_tree && m_root_render;
        m_patch_keep_tree    = true;
        // Telegram (VENDOR.md edit 18): the subtrees the session linked, styled as update_structure styles a fresh subtree,
        // now that every structure change is made (a positional match reads the final children). One removed again in
        // the session is not in the document and is left alone.
        {
            std::vector<element::ptr> inserted;
            inserted.swap(m_patch_inserted);
            std::vector<element::ptr> fresh;
            for(const auto& el : inserted)
            {
                element::ptr top = el;
                while(top && top != m_root)
                    top = top->parent();
                if(top != m_root)
                    continue;
                if(std::dynamic_pointer_cast<html_tag>(el))
                    fresh.push_back(el);
                new_text.push_back(el);
            }
            for(const auto& el : fresh)
                el->apply_stylesheet(m_master_css);
            for(const auto& el : fresh)
                el->parse_attributes();
            for(const auto& el : fresh)
                el->apply_stylesheet(m_styles);
            for(const auto& el : fresh)
                el->apply_stylesheet(m_user_css);
            // Telegram (VENDOR.md edit 42): the other element children of a parent a subject positional rule reaches,
            // matched again now that their places are final.
            std::vector<element::ptr> parents;
            parents.swap(m_patch_position_parents);
            for(const auto& parent : parents)
            {
                element::ptr top = parent;
                while(top && top != m_root)
                    top = top->parent();
                if(top != m_root)
                    continue;
                for(const auto& child : parent->children())
                {
                    auto tag = std::dynamic_pointer_cast<html_tag>(child);
                    if(!tag || child->is_text() || generated_content(*child) ||
                       std::find(fresh.begin(), fresh.end(), child) != fresh.end())
                        continue;
                    for(const auto& inner : child->children())
                    {
                        if(inner->tag() == __tag_before_ || inner->tag() == __tag_after_)
                            release_pieces(inner);
                    }
                    const string_map attrs = tag->attributes();
                    apply_retag(child, attrs, false);
                    tag->forget_flips();
                    if(std::find(m_patch_restyle.begin(), m_patch_restyle.end(), child) == m_patch_restyle.end())
                        m_patch_restyle.push_back(child);
                }
            }
        }
        // Telegram (VENDOR.md edit 17): the session's re-matched elements join the new pieces.
#if 0
        restyle_after_patch({}, new_text, keep_tree);
#else
        std::vector<element::ptr> restyle;
        restyle.swap(m_patch_restyle);
        restyle_after_patch(restyle, new_text, keep_tree);
#endif
        // Telegram (VENDOR.md edit 20): the elements restyled with the render tree kept, and whether paint order changed.
        if(m_render_observer && keep_tree)
        {
            for(const auto& el : restyle)
                m_render_observer->element_restyled(el.get(), m_patch_paint_order.count(el.get()) != 0);
        }
        m_patch_paint_order.clear();
        if(keep_tree)
            forget_positions();
        // Not a paint-only patch: the damage regions of an earlier one do not describe this.
        m_paint_only_patch = false;
        m_patch_confined   = false;
        m_patch_regions.clear();
        // Telegram (VENDOR.md edit 17): the render tree has let go of what the session replaced by now.
        m_patch_released = 0;
        m_patch_hold.clear();
        // The patch can have added elements (a control's lh-* parts): the next query reads the tree as it now is.
        m_pseudo_content = -1;
        // Telegram (VENDOR.md edit 18): the session's own selector-step budget ends with it.
        if(m_step_session_auto)
            end_selector_steps();
    }

    // Telegram (VENDOR.md edit 17): attributes and inline style patched in place.
    namespace
    {
        // 1: the types apply_retag re-reads completely and may keep the render tree for (document.cpp's
        // restylable_in_place); 2: the four whose parse_attributes or pseudo-classes were checked against a fresh build
        // (tests/external_test.cpp), which never keep it; 0: the rest.
        int attribute_patch_kind(const element& el)
        {
            const std::type_info& type = typeid(el);
            if(type == typeid(html_tag) || type == typeid(el_div) || type == typeid(el_para) || type == typeid(el_td) ||
               type == typeid(el_tr) || type == typeid(el_body))
                return 1;
            if(type == typeid(el_image) || type == typeid(el_anchor) || type == typeid(el_input) || type == typeid(el_svg))
                return 2;
            return 0;
        }

        // table_grid::add_cell's reading of a span.
        int span_of(const string_map& attrs, const char* name)
        {
            auto it = attrs.find(name);
            int  n  = it == attrs.end() ? 1 : std::atoi(it->second.c_str());
            return n < 1 ? 1 : (n > 1000 ? 1000 : n);
        }

        int count_pieces(const element::ptr& root)
        {
            int                       n = 0;
            std::vector<element::ptr> pending{root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                if(typeid(*el) == typeid(el_text) || typeid(*el) == typeid(el_space))
                    n++;
                for(const auto& child : el->children())
                    pending.push_back(child);
            }
            return n;
        }
    } // namespace

    void document::begin_patch_session()
    {
        if(m_patch_pending)
            return;
        // Telegram (VENDOR.md edit 18): the patch session's selector-step budget, unless the caller opened one.
        if(!m_step_session_open)
        {
            begin_selector_steps();
            m_step_session_auto = true;
        }
        m_patch_pending   = true;
        m_patch_keep_tree = true;
        m_patch_text_base = m_text_elements;
        m_patch_growth    = 0;
        m_patch_new_text.clear();
        m_patch_restyle.clear();
        m_patch_position_parents.clear(); // Telegram (VENDOR.md edit 42)
    }

    // Keeps `root` alive until commit_patch and stops text_element_allowed from counting its pieces.
    void document::release_pieces(const element::ptr& root)
    {
        m_patch_released += count_pieces(root);
        m_patch_hold.push_back(root);
    }

    bool document::pseudo_content_possible() const
    {
        if(m_pseudo_content >= 0)
            return m_pseudo_content != 0;
        std::unordered_set<string_id> tags;
        bool                          tags_known = false;
        auto                          has_tag    = [&](string_id tag) {
            if(!tags_known)
            {
                tags_known = true;
                // O(elements), once per finalize or commit_patch; the patch path's layout pre-charge (kLayoutBox per
                // element and piece) is charged for the same count before the first query.
                std::vector<element::ptr> pending{m_root};
                while(!pending.empty())
                {
                    element::ptr el = pending.back();
                    pending.pop_back();
                    if(!el)
                        continue;
                    tags.insert(el->tag());
                    for(const auto& child : el->children())
                        pending.push_back(child);
                }
            }
            if(tags.count(tag) != 0)
                return true;
            // A form control makes its lh-* parts when it is matched again, whatever its type is now: a rule for one
            // counts wherever the document has a control that could make it.
            if(_s(tag).compare(0, 3, "lh-") == 0)
                return tags.count(_input_) || tags.count(_select_) || tags.count(_textarea_);
            return false;
        };
        m_pseudo_content = 0;
        for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
        {
            for(const auto& sel : sheet->selectors())
            {
                if(!sel || !sel->m_style)
                    continue;
                bool pseudo = false;
                for(const auto& attr : sel->m_right.m_attrs)
                    pseudo = pseudo || (attr.type == select_pseudo_element && (attr.name == _before_ || attr.name == _after_));
                if(!pseudo)
                    continue;
                const auto& content = sel->m_style->get_property(_content_);
                if(!content.is<std::string>() || content.get<std::string>().empty() || content.get<std::string>() == "none")
                    continue;
                if(sel->m_right.m_tag == star_id || has_tag(sel->m_right.m_tag))
                {
                    m_pseudo_content = 1;
                    return true;
                }
            }
        }
        return false;
    }

    // Telegram (VENDOR.md edit 19, W Ruling E28).
    bool document::pseudo_cap_in_play(long long extra) const
    {
        if(m_pseudo_rules < 0)
        {
            m_pseudo_rules = 0;
            // The master sheet's two ::before rules are content rules on `summary`: pseudo_content_possible's.
            for(const css* sheet : {&m_styles, &m_user_css})
            {
                for(const auto& sel : sheet->selectors())
                {
                    if(!sel)
                        continue;
                    for(const auto& attr : sel->m_right.m_attrs)
                    {
                        if(attr.type == select_pseudo_element && (attr.name == _before_ || attr.name == _after_))
                            m_pseudo_rules = 1;
                    }
                }
            }
        }
        if(m_pseudo_rules == 0)
            return false;
        return m_pseudo_limited ||
               (long long)m_build_elements + m_pseudo_elements + extra >= max_build_elements;
    }

    // Telegram (VENDOR.md edit 21).
    bool document::style_admit(const style& st, const style& onto, size_t& charged)
    {
        charged = 0;
        if(!m_style_charging)
            return true;
        if(m_style_limited)
            return false;
        const size_t bytes = st.payload_growth_over(onto);
        if(bytes > max_style_bytes || m_style_bytes + bytes > max_style_bytes)
        {
            m_style_limited = true;
            m_container->sanitizer_limit("style-bytes");
            return false;
        }
        m_style_bytes += bytes;
        charged = bytes;
        return true;
    }

    bool document::style_splice(size_t bytes, size_t& charged)
    {
        charged = 0;
        if(m_style_limited)
            return false;
        if(bytes > max_style_bytes || m_style_bytes + bytes > max_style_bytes)
        {
            m_style_limited = true;
            m_container->sanitizer_limit("style-bytes");
            return false;
        }
        m_style_bytes += bytes;
        charged = bytes;
        return true;
    }

    void document::refresh_all_styles()
    {
        auto root = std::dynamic_pointer_cast<html_tag>(m_root);
        if(!root)
        {
            m_root->refresh_styles();
            return;
        }
        long long elements = 0;
        {
            std::vector<const element*> stack{m_root.get()};
            while(!stack.empty())
            {
                const element* el = stack.back();
                stack.pop_back();
                elements++;
                for(const auto& child : el->children())
                    stack.push_back(child.get());
            }
        }
        if(!style_budget_in_play(elements))
        {
            root->refresh_styles();
            return;
        }
        m_style_bytes   = 0;
        m_style_limited = false;
        m_style_budget_epoch++; // Telegram (VENDOR.md edit 60)
        root->refresh_clear_styles();
        root->refresh_replay_styles(0);
        root->parse_attributes();
        root->refresh_replay_styles(1);
        root->refresh_replay_styles(2);
    }

    bool document::style_budget_in_play(long long elements) const
    {
        if(m_style_limited)
            return true;
        if(m_style_rule_bytes < 0)
        {
            m_style_rule_bytes = 0;
            // The most one element can keep: per property, the largest value any rule declares.
            std::map<string_id, size_t> most;
            for(const css* sheet : {&m_styles, &m_user_css})
            {
                for(const auto& sel : sheet->selectors())
                {
                    if(sel && sel->m_style)
                        sel->m_style->max_payload_into(most);
                }
            }
            for(const auto& entry : most)
                m_style_rule_bytes += (long long)entry.second;
            // A var() splice copies a custom property's value onto the element: each use, at most the largest value.
            size_t var_uses = 0, largest_custom = 0;
            for(const css* sheet : {&m_styles, &m_user_css})
            {
                for(const auto& sel : sheet->selectors())
                {
                    if(sel && sel->m_style)
                        sel->m_style->var_stats(var_uses, largest_custom);
                }
            }
            m_style_rule_bytes += (long long)(std::min<size_t>(var_uses, 64) * largest_custom);
        }
        if(m_style_rule_bytes == 0)
            return false;
        return (long long)m_style_bytes + elements * m_style_rule_bytes >= (long long)max_style_bytes;
    }

    bool document::attribute_target(const element::ptr& el, const char* name, const char* value, string_map& attrs)
    {
        auto tag = std::dynamic_pointer_cast<html_tag>(el);
        if(!tag || !name || !*name)
            return false;
        attrs                   = tag->attributes();
        const std::string lname = lowcase(name);
        if(value)
            attrs[lname] = value;
        else
            attrs.erase(lname);
        return true;
    }

    bool document::attribute_change_allowed(const element::ptr& el, const string_map& attrs)
    {
        auto tag = std::dynamic_pointer_cast<html_tag>(el);
        if(!tag)
            return false;
        // Telegram (VENDOR.md edit 19, W Ruling E28): a change can add up to two pseudo-elements to every element.
        if(pseudo_cap_in_play(2LL * m_build_elements))
            return false;
        // Telegram (VENDOR.md edit 21): a change restyles at most every element, each with every rule.
        if(style_budget_in_play(m_build_elements))
            return false;
        auto unsafe_style = [](std::string_view value) {
            return value.find("counter") != std::string_view::npos || value.find("var(") != std::string_view::npos ||
                   value.find("--") != std::string_view::npos;
        };
        const string_map& before    = tag->attributes();
        // Telegram (VENDOR.md edit 27): an animated element's declarations are a second inline style.
        for(const char* name : {"style", animated_style_attribute})
        {
            auto              was       = before.find(name);
            auto              now       = attrs.find(name);
            const std::string old_style = was == before.end() ? std::string() : was->second;
            const std::string new_style = now == attrs.end() ? std::string() : now->second;
            if(old_style != new_style && (unsafe_style(old_style) || unsafe_style(new_style)))
                return false;
        }
        auto normalized = [this](const std::string* value) {
            std::string text = value ? *value : std::string();
            if(m_mode == quirks_mode)
                lcase(text);
            return text;
        };
        auto reaches_others = [&](const std::string& attr, const std::string* old, const std::string* next) {
            if(!m_left_attrs.empty() && m_left_attrs.count(_id(attr)))
                return true;
            if(attr == "id")
                return m_left_ids.count(_id(normalized(old))) != 0 || m_left_ids.count(_id(normalized(next))) != 0;
            if(attr != "class")
                return false;
            std::unordered_set<string_id> a, c;
            for(const auto& cls : split_string(normalized(old), whitespace, "", ""))
                a.insert(_id(cls));
            for(const auto& cls : split_string(normalized(next), whitespace, "", ""))
                c.insert(_id(cls));
            for(string_id cls : a)
            {
                if(!c.count(cls) && m_left_classes.count(cls))
                    return true;
            }
            for(string_id cls : c)
            {
                if(!a.count(cls) && m_left_classes.count(cls))
                    return true;
            }
            return false;
        };
        for(const auto& entry : before)
        {
            auto it = attrs.find(entry.first);
            if((it == attrs.end() || it->second != entry.second) &&
               reaches_others(entry.first, &entry.second, it == attrs.end() ? nullptr : &it->second))
                return false;
        }
        for(const auto& entry : attrs)
        {
            if(!before.count(entry.first) && reaches_others(entry.first, nullptr, &entry.second))
                return false;
        }
        return true;
    }

    bool document::can_set_element_attributes(const element::ptr& el, const string_map& attrs, attribute_growth* pending)
    {
        if(!el || !m_finalized || !m_root || attribute_patch_kind(*el) == 0)
            return false;
        element::ptr top = el;
        while(top && top != m_root)
            top = top->parent();
        if(top != m_root)
            return false;
        // Sibling and positional selectors and counters anywhere in the sheets, and the names in ancestor positions
        // (selector_scope fills m_left_*), are what an attribute can reach beyond the element.
#if 0
        if(selector_scope() != 0)
            return false;
#else
        // Telegram (VENDOR.md edit 42): a positional pseudo-class reads an element's place, which no attribute changes,
        // and :empty its children: only sibling combinators (and `of S`, bit 1) and counters (4) reach beyond it.
        if((selector_scope() & 5) != 0)
            return false;
#endif
        for(auto p = el->parent(); p; p = p->parent())
        {
            if(p->tag() == _select_)
                return false;
        }
        if(!attribute_change_allowed(el, attrs))
            return false;
        // The caps a fresh build enforces where a match or a layout makes pieces and cells.
        if(pseudo_content_possible())
            return false;
        attribute_growth bound;
        auto             tag = std::static_pointer_cast<html_tag>(el);
        const string_map& before = tag->attributes();
        const int old_cells = span_of(before, "colspan") * span_of(before, "rowspan");
        const int new_cells = span_of(attrs, "colspan") * span_of(attrs, "rowspan");
        if(new_cells > old_cells)
        {
            bound.cells = new_cells - old_cells;
            if(m_table_cells + bound.cells + (pending ? pending->cells : 0) > max_table_cells)
                return false;
        }
        if(pending)
            pending->cells += bound.cells;
        return true;
    }

    bool document::can_set_element_attribute(const element::ptr& el, const char* name, const char* value)
    {
        string_map attrs;
        return el && attribute_target(el, name, value, attrs) && can_set_element_attributes(el, attrs);
    }

    bool document::set_element_attributes(const element::ptr& el, const string_map& wanted)
    {
        if(!can_set_element_attributes(el, wanted))
            return false;
        auto       tag   = std::static_pointer_cast<html_tag>(el);
        string_map attrs = wanted;
        auto       index = tag->attributes().find("list_index");
        if(index != tag->attributes().end() && !attrs.count("list_index"))
            attrs["list_index"] = index->second;
        if(attrs == tag->attributes())
            return true;
        const int kind = attribute_patch_kind(*el);
        m_match_epoch++;
        begin_patch_session();
        m_layout_before_valid = false;
        if(typeid(*el) == typeid(el_input))
        {
            // parse_attributes generates the control's parts again, and with the children swapped out it would not see
            // the old ones to remove.
            std::vector<element::ptr> generated;
            for(const auto& child : el->children())
            {
                const char* child_tag = child->get_tagName();
                if(child_tag && !std::strncmp(child_tag, "lh-", 3))
                    generated.push_back(child);
            }
            for(const auto& child : generated)
            {
                release_pieces(child);
                remove_child(child);
            }
        } else if(typeid(*el) == typeid(el_anchor))
        {
            // el_anchor::apply_stylesheet adds :link once per sheet while it has an href.
            while(tag->set_pseudo_class(_link_, false))
            {
            }
        }
        // The pseudo-element content the match forgets stays alive in the render tree, uncounted from here on.
        for(const auto& child : el->children())
        {
            if(child->tag() == __tag_before_ || child->tag() == __tag_after_)
                release_pieces(child);
        }
        const bool neutral = apply_retag(el, attrs, kind == 1);
        m_attribute_rematches++;
        m_patch_keep_tree = m_patch_keep_tree && neutral;
        tag->forget_flips();
        if(std::find(m_patch_restyle.begin(), m_patch_restyle.end(), el) == m_patch_restyle.end())
            m_patch_restyle.push_back(el);
        return true;
    }

    bool document::set_element_attribute(const element::ptr& el, const char* name, const char* value)
    {
        string_map attrs;
        return el && attribute_target(el, name, value, attrs) && set_element_attributes(el, attrs);
    }
    // Telegram (VENDOR.md edit 18): structure patched in place.
    namespace
    {
        // update_structure's document-level elements (document.cpp, has_document_level_element).
        bool document_level_element(const element& el)
        {
            const string_id tag = el.tag();
            return tag == _html_ || tag == _head_ || tag == _body_ || tag == _style_ || tag == _link_ || tag == _base_ ||
                   tag == _meta_ || tag == _title_ || tag == _script_ || tag == _frameset_ || tag == _select_ ||
                   tag == _option_ || tag == _optgroup_ || tag == _datalist_;
        }

        // Content litehtml makes and no caller built: a pseudo-element, or a form control's lh-* part (el_form.cpp removes
        // the children so named as its own).
        bool generated_content(const element& el)
        {
            if(el.tag() == __tag_before_ || el.tag() == __tag_after_)
                return true;
            const element::ptr parent = el.parent();
            if(!parent)
                return false;
            const std::type_info& type = typeid(*parent);
            if(type != typeid(el_input) && type != typeid(el_select) && type != typeid(el_textarea))
                return false;
            const char* tag = el.get_tagName();
            return tag && !std::strncmp(tag, "lh-", 3);
        }

        // The tags the ::before/::after rules that declare content name (pseudo_content_possible's reading of a rule).
        void content_rule_tags(const css& sheet, std::unordered_set<string_id>& tags)
        {
            for(const auto& sel : sheet.selectors())
            {
                if(!sel || !sel->m_style)
                    continue;
                bool pseudo = false;
                for(const auto& attr : sel->m_right.m_attrs)
                    pseudo = pseudo || (attr.type == select_pseudo_element && (attr.name == _before_ || attr.name == _after_));
                if(!pseudo)
                    continue;
                const auto& content = sel->m_style->get_property(_content_);
                if(!content.is<std::string>() || content.get<std::string>().empty() || content.get<std::string>() == "none")
                    continue;
                tags.insert(sel->m_right.m_tag);
            }
        }

        struct subtree_shape
        {
            int       elements       = 0;   // its elements, generated content left out
            long long cells          = 0;   // each element's colspan x rowspan as table_grid::add_cell reads them
            int       levels         = -1;  // the deepest element's level below the root (0: the root); -1: no element
            bool      document_level = false;
            bool      content        = false;   // an element a content rule could make pseudo-element content for
        };

        // One walk, no recursion. `tags` and `parts` (an lh-* rule exists) decide `content`.
        subtree_shape shape_of(const element::ptr& root, const std::unordered_set<string_id>* tags = nullptr, bool parts = false)
        {
            subtree_shape                              shape;
            std::vector<std::pair<element::ptr, int>> pending{{root, 0}};
            while(!pending.empty())
            {
                auto [el, level] = pending.back();
                pending.pop_back();
                if(typeid(*el) == typeid(el_text) || typeid(*el) == typeid(el_space) || generated_content(*el))
                    continue;
                shape.elements++;
                shape.levels = std::max(shape.levels, level);
                shape.document_level = shape.document_level || document_level_element(*el);
                if(tags && (tags->count(el->tag()) ||
                            (parts && (el->tag() == _input_ || el->tag() == _select_ || el->tag() == _textarea_))))
                    shape.content = true;
                auto span = [&](const char* name) {
                    int n = std::atoi(el->get_attr(name, "1"));
                    return n < 1 ? 1 : (n > 1000 ? 1000 : n);
                };
                shape.cells += (long long)span("colspan") * span("rowspan");
                for(const auto& child : el->children())
                    pending.emplace_back(child, level + 1);
            }
            return shape;
        }
    } // namespace

    bool document::structure_parent_allowed(const element::ptr& parent)
    {
        if(!m_finalized || !m_root || !parent || !std::dynamic_pointer_cast<html_tag>(parent) || is_raw_text_parent(*parent))
            return false;
        element::ptr top = parent;
        for(; top && top != m_root; top = top->parent())
        {
            if(text_read_by_element(*top) || generated_content(*top))
                return false;
        }
        return top == m_root;
    }

    bool document::structure_insertable(const element::ptr& parent, const std::vector<element::ptr>& subtrees,
                                        structure_growth& growth)
    {
        if(pseudo_content_possible())
            return false;
        if(!m_content_tags_known)
        {
            m_content_tags_known = true;
            for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
                content_rule_tags(*sheet, m_content_tags);
            for(string_id tag : m_content_tags)
                m_content_parts = m_content_parts || _s(tag).compare(0, 3, "lh-") == 0;
        }
        const std::unordered_set<string_id>& tags  = m_content_tags;
        const bool                           parts = m_content_parts;
        int depth = 0;
        for(auto p = parent->parent(); p; p = p->parent())
            depth++;
        int       elements = 0;
        long long cells    = 0;
        std::unordered_set<const element*> seen;
        for(const auto& subtree : subtrees)
        {
            if(!subtree || subtree->parent() || subtree == m_root || !seen.insert(subtree.get()).second)
                return false;
            // What the parent's own appendChild refuses (el_table takes its row groups and caption only), which a build
            // leaves out.
            if(typeid(*parent) == typeid(el_table) && subtree->tag() != _tbody_ && subtree->tag() != _thead_ &&
               subtree->tag() != _tfoot_ && subtree->tag() != _caption_)
                return false;
            const subtree_shape shape = shape_of(subtree, &tags, parts);
            if(shape.document_level || shape.content)
                return false;
            if(shape.levels >= 0 && depth + 1 + shape.levels >= max_build_depth)
                return false;
            elements += shape.elements;
            cells += shape.cells;
        }
        if(m_build_elements + growth.elements + elements > max_build_elements)
            return false;
        // Telegram (VENDOR.md edit 19, W Ruling E28): each new element can bring two pseudo-elements.
        if(pseudo_cap_in_play(3LL * ((growth.elements > 0 ? growth.elements : 0) + elements)))
            return false;
        // Telegram (VENDOR.md edit 21): the new elements are styled with every rule (3x also covers pseudo-elements).
        if(style_budget_in_play(3LL * ((growth.elements > 0 ? growth.elements : 0) + elements)))
            return false;
        // The pieces of the subtrees are alive, and counted, already.
        if(int(m_text_elements) - m_patch_released - growth.released > max_text_elements + m_text_allowance)
            return false;
        if((long long)m_table_cells + growth.cells + cells > max_table_cells)
            return false;
        growth.elements += elements;
        growth.cells += int(cells);
        return true;
    }

    bool document::structure_removable(const element::ptr& subtree, structure_growth& growth)
    {
        if(!subtree || subtree == m_root || generated_content(*subtree))
            return false;
        const element::ptr parent = subtree->parent();
        if(!parent || !structure_parent_allowed(parent) || pseudo_content_possible())
            return false;
        if(m_pseudo_limited) // Telegram (VENDOR.md edit 19, W Ruling E28): freed budget would go to later elements.
            return false;
        if(style_budget_in_play(0)) // Telegram (VENDOR.md edit 21): a limit-cut document is rebuilt, never patched.
            return false;
        const subtree_shape shape = shape_of(subtree);
        if(shape.document_level)
            return false;
        growth.released += count_pieces(subtree);
        growth.elements -= shape.elements;
        return true;
    }

    void document::link_subtree(const element::ptr& parent, size_t index, const element::ptr& subtree)
    {
        m_build_elements += shape_of(subtree).elements;
        insert_child(parent, index, subtree);
        m_patch_inserted.push_back(subtree);
    }

    void document::unlink_subtree(const element::ptr& subtree)
    {
        m_build_elements -= shape_of(subtree).elements;
        release_pieces(subtree);
        remove_child(subtree);
        m_patch_inserted.erase(std::remove(m_patch_inserted.begin(), m_patch_inserted.end(), subtree), m_patch_inserted.end());
    }

    bool document::can_insert_subtree(const element::ptr& parent, size_t index, const element::ptr& subtree,
                                      structure_growth* pending)
    {
#if 0
        if(!subtree || !structure_parent_allowed(parent) || index > parent->children().size() || selector_scope() != 0)
            return false;
#else
        // Telegram (VENDOR.md edit 42): a rule positional in its subject alone does not refuse: commit_patch matches the
        // parent's other children again where it reaches them.
        if(!subtree || !structure_parent_allowed(parent) || index > parent->children().size() ||
           (selector_scope() & ~16) != 0)
            return false;
#endif
        structure_growth growth = pending ? *pending : structure_growth();
        if(!structure_insertable(parent, {subtree}, growth))
            return false;
        if(pending)
            *pending = growth;
        return true;
    }

    bool document::can_remove_subtree(const element::ptr& subtree, structure_growth* pending)
    {
#if 0
        if(!m_finalized || !m_root || selector_scope() != 0)
            return false;
#else
        // Telegram (VENDOR.md edit 42): as can_insert_subtree.
        if(!m_finalized || !m_root || (selector_scope() & ~16) != 0)
            return false;
#endif
        structure_growth growth = pending ? *pending : structure_growth();
        if(!structure_removable(subtree, growth))
            return false;
        if(pending)
            *pending = growth;
        return true;
    }

    bool document::can_replace_children(const element::ptr& parent, const std::vector<element::ptr>& subtrees,
                                        structure_growth* pending)
    {
#if 0
        if(!structure_parent_allowed(parent) || (selector_scope() & 4))
            return false;
#else
        // Telegram (VENDOR.md edit 31.5): nor with :empty (the parent's own match changes).
        if(!structure_parent_allowed(parent) || (selector_scope() & 12))
            return false;
#endif
        structure_growth growth = pending ? *pending : structure_growth();
        for(const auto& child : parent->children())
        {
            if(!generated_content(*child) && !structure_removable(child, growth))
                return false;
        }
        if(!structure_insertable(parent, subtrees, growth))
            return false;
        if(pending)
            *pending = growth;
        return true;
    }

    bool document::structure_reaches_siblings()
    {
        return (selector_scope() & 3) != 0;
    }

    // Telegram (VENDOR.md edit 42).
    bool document::structure_reaches_siblings(const element::ptr& parent)
    {
        return structure_reaches_siblings() || positions_reach(parent);
    }

    void document::note_position_parent(const element::ptr& parent)
    {
        if(parent && positions_reach(parent) &&
           std::find(m_patch_position_parents.begin(), m_patch_position_parents.end(), parent) == m_patch_position_parents.end())
            m_patch_position_parents.push_back(parent);
    }

    bool document::positions_reach(const element::ptr& parent)
    {
        if(!parent || (selector_scope() & 16) == 0)
            return false;
        for(const auto& rule : m_subject_positions)
        {
            if(rule.parent != star_id && rule.parent != parent->tag())
                continue;
            for(const auto& child : parent->children())
            {
                if(child->is_text() || generated_content(*child) || !std::dynamic_pointer_cast<html_tag>(child))
                    continue;
                if(rule.tag == star_id || child->tag() == rule.tag)
                    return true;
            }
        }
        return false;
    }

    bool document::insert_subtree(const element::ptr& parent, size_t index, const element::ptr& subtree)
    {
        if(!can_insert_subtree(parent, index, subtree))
            return false;
        begin_patch_session();
        m_match_epoch++;
        note_style_change();
        m_layout_before_valid = false;
        m_patch_keep_tree     = false;
        note_position_parent(parent); // Telegram (VENDOR.md edit 42)
        link_subtree(parent, index, subtree);
        return true;
    }

    bool document::remove_subtree(const element::ptr& subtree)
    {
        if(!can_remove_subtree(subtree))
            return false;
        begin_patch_session();
        m_match_epoch++;
        note_style_change();
        m_layout_before_valid = false;
        m_patch_keep_tree     = false;
        note_position_parent(subtree->parent()); // Telegram (VENDOR.md edit 42)
        unlink_subtree(subtree);
        return true;
    }

    bool document::replace_children(const element::ptr& parent, const std::vector<element::ptr>& subtrees)
    {
        if(!can_replace_children(parent, subtrees))
            return false;
        begin_patch_session();
        m_match_epoch++;
        note_style_change();
        m_layout_before_valid = false;
        m_patch_keep_tree     = false;
        std::vector<element::ptr> old;
        for(const auto& child : parent->children())
        {
            if(!generated_content(*child))
                old.push_back(child);
        }
        for(const auto& child : old)
            unlink_subtree(child);
        // After a ::before (first) and before an ::after (last).
        size_t index = 0;
        for(const auto& child : parent->children())
        {
            if(child->tag() != __tag_before_)
                break;
            index++;
        }
        for(const auto& subtree : subtrees)
            link_subtree(parent, index++, subtree);
        return true;
    }

    void document::make_text_pieces(const element::ptr& parent, const char* text, std::vector<element::ptr>& pieces)
    {
        if(!text)
            return;
        if(parent && is_raw_text_parent(*parent))
        {
            pieces.push_back(std::make_shared<el_text>(text, shared_from_this()));
            return;
        }
        m_container->split_text(
            text, [&](const char* word) { pieces.push_back(std::make_shared<el_text>(word, shared_from_this())); },
            [&](const char* space) { pieces.push_back(std::make_shared<el_space>(space, shared_from_this())); });
    }
} // namespace litehtml

namespace litehtml
{
    // Telegram (VENDOR.md edit 18): one selector-step budget per build or patch session, and the bound of a patch's steps.
    void document::begin_selector_steps(int64_t limit)
    {
        m_step_session.limit = limit;
        m_step_session.used  = 0;
        m_step_session.owner = this;
        m_step_session_open  = true;
        m_step_session_auto  = false;
        set_selector_step_session(&m_step_session);
    }

    int64_t document::end_selector_steps()
    {
        if(!m_step_session_open)
            return 0;
        m_step_session_open = false;
        m_step_session_auto = false;
        set_selector_step_session(nullptr);
        return m_step_session.used;
    }

    document::pseudo_element_tags document::pseudo_element_creators(std::initializer_list<const css*> sheets) const
    {
        const std::initializer_list<const css*> all = {&m_master_css, &m_styles, &m_user_css};
        pseudo_element_tags                     creators;
        for(const css* sheet : sheets.size() ? sheets : all)
        {
            for(const auto& sel : sheet->selectors())
            {
                if(!sel || !sel->m_style)
                    continue;
                const auto& right  = sel->m_right;
                bool        pseudo = false;
                for(const auto& attr : right.m_attrs)
                    pseudo = pseudo || (attr.type == select_pseudo_element && (attr.name == _before_ || attr.name == _after_));
                if(!pseudo)
                    continue;
                const auto& content = sel->m_style->get_property(_content_);
                if(content.is<std::string>() && content.get<std::string>() == "none")
                    continue;
                if(right.m_tag != star_id)
                {
                    creators.tags.insert(right.m_tag);
                    creators.parts = creators.parts || _s(right.m_tag).compare(0, 3, "lh-") == 0;
                } else if(right.m_attrs.size() > 1)
                {
                    creators.every = true;
                    creators.parts = true;
                }
            }
        }
        return creators;
    }

    size_t document::matching_weight(const element& el, const pseudo_element_tags& creators)
    {
        if(!dynamic_cast<const html_tag*>(&el))
            return 0;
        const bool form = el.tag() == _input_ || el.tag() == _select_ || el.tag() == _textarea_;
        return 1 + (creators.creatable(el.tag()) ? 2 : 0) + (form ? 3 * (creators.parts ? 3 : 1) : 0);
    }

    size_t document::matching_bound(const element::ptr& root, const pseudo_element_tags& creators)
    {
        size_t                      n = 0;
        std::vector<const element*> pending;
        if(root)
            pending.push_back(root.get());
        while(!pending.empty())
        {
            const element* el = pending.back();
            pending.pop_back();
            if(!dynamic_cast<const html_tag*>(el) || dynamic_cast<const el_before_after_base*>(el))
                continue;
            n += matching_weight(*el, creators);
            const bool form = el->tag() == _input_ || el->tag() == _select_ || el->tag() == _textarea_;
            for(const auto& child : el->children())
            {
                const char* tag = child->get_tagName();
                if(form && tag && !std::strncmp(tag, "lh-", 3))
                    continue;
                pending.push_back(child.get());
            }
        }
        return n;
    }

    size_t document::selector_count() const
    {
        return m_master_css.selectors().size() + m_styles.selectors().size() + m_user_css.selectors().size();
    }

    namespace
    {
        // The place a selector is tested at, as an upper bound: the ancestors and the siblings it can walk.
        struct step_place
        {
            double ancestors = 0;
            double siblings  = 0;
        };

        double selector_steps(const css_selector& selector, const step_place& at);

        // The counted steps a compound's pseudo-classes take: their selector lists, tested against the element (or, for
        // :nth-child(of S), against each sibling). Its other simple selectors count none.
        double compound_steps(const css_element_selector& compound, const step_place& at)
        {
            double steps = 0;
            for(const auto& attr : compound.m_attrs)
            {
                if(attr.type != select_pseudo_class || attr.selector_list.empty())
                    continue;
                double list = 0;
                for(const auto& inner : attr.selector_list)
                {
                    if(inner)
                        list += selector_steps(*inner, at);
                }
                steps += (attr.name == _nth_child_ || attr.name == _nth_last_child_) ? at.siblings * list : list;
            }
            return steps;
        }

        // html_tag::select(const css_selector&): one counted step, the compound, and its left part by combinator.
        double selector_steps(const css_selector& selector, const step_place& at)
        {
            double steps = 1 + compound_steps(selector.m_right, at);
            if(!selector.m_left)
                return steps;
            const css_selector& left  = *selector.m_left;
            const double        whole = selector_steps(left, at);
            const double        right = compound_steps(left.m_right, at);
            switch(selector.m_combinator)
            {
            case combinator_descendant:
                // find_ancestor: each ancestor tests `left`; with the prune (a descendant `left` failing where its own
                // rightmost compound matches stops the walk), only one ancestor can go past the compound.
                if(left.m_left && left.m_combinator == combinator_descendant)
                    steps += at.ancestors * (1 + 2 * right) + whole + right;
                else
                    steps += at.ancestors * whole;
                break;
            case combinator_child:
            case combinator_adjacent_sibling:
                steps += whole;
                break;
            case combinator_general_sibling:
                // find_sibling: each earlier sibling until one matches, and the prune's compound test.
                steps += at.siblings * (whole + right);
                break;
            default:
                break;
            }
            return steps;
        }

        uint64_t bucket_key(string_id tag, string_id cls)
        {
            return (uint64_t(uint32_t(tag)) << 32) | uint32_t(cls);
        }

        const string_id kNoClass = string_id(-1);

        std::unordered_set<string_id> classes_of(const char* value, document_mode mode)
        {
            std::unordered_set<string_id> out;
            if(!value)
                return out;
            std::string text = value;
            if(mode == quirks_mode)
                lcase(text);
            for(const auto& name : split_string(text, whitespace, "", ""))
                out.insert(_id(name));
            return out;
        }

        int depth_of(const element::ptr& el)
        {
            int depth = 0;
            for(auto p = el ? el->parent() : nullptr; p; p = p->parent())
                depth++;
            return depth;
        }
    } // namespace

    int64_t document::selector_step_bound(const selector_step_plan& plan) const
    {
        // The deepest place and the most siblings of anything the plan matches (an input's parts are one deeper).
        step_place at;
        std::unordered_map<const element*, size_t> roots_under;
        for(const auto& [parent, subtree] : plan.inserted)
        {
            if(parent)
                roots_under[parent.get()]++;
        }
        auto widen = [&at](double ancestors, double siblings) {
            at.ancestors = std::max(at.ancestors, ancestors);
            at.siblings  = std::max(at.siblings, siblings);
        };
        constexpr double kParts = 3;   // the most lh-* parts a control makes
        for(const auto& [parent, subtree] : plan.inserted)
        {
            if(!parent || !subtree)
                continue;
            const double base = depth_of(parent) + 1;
            widen(base, double(parent->children().size() + roots_under[parent.get()]));
            std::vector<std::pair<const element*, int>> pending{{subtree.get(), 0}};
            while(!pending.empty())
            {
                auto [el, level] = pending.back();
                pending.pop_back();
                widen(base + level + 1, double(el->children().size()) + kParts);
                for(const auto& child : el->children())
                    pending.emplace_back(child.get(), level + 1);
            }
        }
        for(const auto& [el, attrs] : plan.rematched)
        {
            if(!el)
                continue;
            widen(depth_of(el) + 1, el->parent() ? double(el->parent()->children().size()) : 0);
            widen(depth_of(el) + 1, kParts);
        }
        // A compound left of a combinator is tested at an ancestor, and a sibling combinator or :nth-child(of S) there walks
        // that ancestor's siblings: every ancestor's parent's children, from the plan's elements up to the root (once per
        // distinct starting point).
        {
            std::unordered_set<const element*> walked;
            auto ancestors = [&](const element* from) {
                for(const element* el = from; el; el = el->parent().get())
                {
                    if(!walked.insert(el).second)
                        break;
                    if(const auto parent = el->parent())
                        widen(0, double(parent->children().size()));
                }
            };
            for(const auto& [parent, subtree] : plan.inserted)
                ancestors(parent.get());
            for(const auto& [el, attrs] : plan.rematched)
                ancestors(el.get());
        }
        // Every selector of the three sheets into the bucket apply_selector's filter reads (its rightmost tag, and its
        // first class when it starts with one), at twice its bound (a test without pseudo-classes, then one with).
        std::unordered_map<uint64_t, double> buckets;
        double                               parts = 0;   // what a generated lh-* part (no classes) can be tested by
        for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
        {
            for(const auto& sel : sheet->selectors())
            {
                if(!sel)
                    continue;
                const auto&     right = sel->m_right;
                const string_id cls   = !right.m_attrs.empty() && right.m_attrs[0].type == select_class ? right.m_attrs[0].name
                                                                                                     : kNoClass;
                const double    steps = 2 * selector_steps(*sel, at);
                buckets[bucket_key(right.m_tag, cls)] += steps;
                if(cls == kNoClass && (right.m_tag == star_id || _s(right.m_tag).compare(0, 3, "lh-") == 0))
                    parts += steps;
            }
        }
        auto bucket = [&buckets](string_id tag, string_id cls) {
            auto it = buckets.find(bucket_key(tag, cls));
            return it == buckets.end() ? 0.0 : it->second;
        };
        const pseudo_element_tags creators = pseudo_element_creators();
        auto element_steps = [&](const element& el, const std::unordered_set<string_id>& classes) {
            double steps = bucket(el.tag(), kNoClass) + (el.tag() == star_id ? 0 : bucket(star_id, kNoClass));
            for(string_id cls : classes)
                steps += bucket(el.tag(), cls) + (el.tag() == star_id ? 0 : bucket(star_id, cls));
            if(el.tag() == _input_ || el.tag() == _select_ || el.tag() == _textarea_)
                steps += kParts * parts;
            // The ::before and ::after a match can create for it, tested as `*` elements with no classes.
            if(creators.creatable(el.tag()))
                steps += 2 * bucket(star_id, kNoClass);
            return steps;
        };
        double total = 0;
        for(const auto& [parent, subtree] : plan.inserted)
        {
            if(!subtree)
                continue;
            std::vector<const element*> pending{subtree.get()};
            while(!pending.empty())
            {
                const element* el = pending.back();
                pending.pop_back();
                if(!dynamic_cast<const html_tag*>(el))
                    continue;
                total += element_steps(*el, classes_of(el->get_attr("class"), m_mode));
                for(const auto& child : el->children())
                    pending.push_back(child.get());
            }
        }
        for(const auto& [el, attrs] : plan.rematched)
        {
            if(!el || !dynamic_cast<const html_tag*>(el.get()))
                continue;
            std::unordered_set<string_id> classes = classes_of(el->get_attr("class"), m_mode);
            if(attrs)
            {
                auto it = attrs->find("class");
                if(it != attrs->end())
                {
                    for(string_id cls : classes_of(it->second.c_str(), m_mode))
                        classes.insert(cls);
                }
            }
            total += element_steps(*el, classes);
        }
        return total >= 4e18 ? int64_t(4e18) : int64_t(total) + 1;
    }
} // namespace litehtml
