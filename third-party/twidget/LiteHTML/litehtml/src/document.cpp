#include <set>
#include "html.h"
#include "document.h"
#include <string_view>
#include <unordered_set>
#include "document_container.h"
#include "css_parser.h" // Telegram (VENDOR.md edit 29.3): normalize, for a <style media> prelude
#include "el_anchor.h"
#include "el_base.h"
#include "el_body.h"
#include "el_break.h"
#include "el_cdata.h"
#include "el_comment.h"
#include "el_div.h"
#include "el_font.h"
#include "el_form.h"
#include "el_svg.h"
#include "el_image.h"
#include <unordered_set>
#include <map>
#include "el_link.h"
#include "el_para.h"
#include "el_script.h"
#include "el_space.h"
#include "el_style.h"
#include "el_table.h"
#include "el_td.h"
#include "el_text.h"
#include "el_title.h"
#include "el_tr.h"
#include "gumbo.h"
#include "html_tag.h"
#include "render_block.h"
#include "render_block_context.h"
#include "render_flex.h"
#include "render_grid.h"
#include "render_inline.h"
#include "render_item.h"
#include "render_inline_context.h"
#include "render_table.h"
#include "stylesheet.h"
#include "types.h"

#include <cstdlib>
#include <iterator>
#include <mutex>
#include <typeinfo>
#include <string>
#include <unordered_map>

namespace litehtml
{

    document::document(document_container* container)
    {
        m_container = container;
    }

    document::~document()
    {
        // Telegram (VENDOR.md edit 18): the selector-step session points into this document.
        if(m_step_session_open)
            set_selector_step_session(nullptr);
        m_over_element = m_active_element = nullptr;
        if(m_container)
        {
            for(auto& font : m_fonts)
            {
                m_container->delete_font(font.second.font);
            }
        }
    }

    document::ptr document::createFromString(const estring& str, document_container* container,
                                             const std::string& master_styles, const std::string& user_styles)
    {
        // Create litehtml::document
        document::ptr doc = std::make_shared<document>(container);

        // Parse document into GumboOutput
        GumboOutput* output = doc->parse_html(str);

        // mode must be set before doc->create_node because it is used in html_tag::set_attr
        switch(output->document->v.document.doc_type_quirks_mode)
        {
        case GUMBO_DOCTYPE_NO_QUIRKS:
            doc->m_mode = no_quirks_mode;
            break;
        case GUMBO_DOCTYPE_QUIRKS:
            doc->m_mode = quirks_mode;
            break;
        case GUMBO_DOCTYPE_LIMITED_QUIRKS:
            doc->m_mode = limited_quirks_mode;
            break;
        }

        // Create litehtml::elements.
        elements_list root_elements;
        doc->create_node(output->root, root_elements, true, true);
        element::ptr root;
        if(!root_elements.empty())
        {
            root = root_elements.back();
        }

        // Destroy GumboOutput
        gumbo_destroy_output(&kGumboDefaultOptions, output);

        doc->finalize_from_external_root(root, master_styles, user_styles);

        return doc;
    }

    namespace
    {
        bool mentions_counters(const std::string& text)
        {
            for(size_t i = 0; i + 7 <= text.size(); i++)
            {
                if((text[i] | 0x20) != 'c' || t_strncasecmp(text.data() + i, "counter", 7) != 0)
                    continue;
                const size_t next = i + 7;
                if(next < text.size() && (text[next] == '-' || text[next] == '(' || ((text[next] | 0x20) == 's')))
                    return true;
            }
            return false;
        }

        struct selector_names
        {
            std::unordered_set<string_id>& classes;
            std::unordered_set<string_id>& ids;
            std::unordered_set<string_id>& attrs;
            std::unordered_set<string_id>& pseudo; // Telegram (VENDOR.md edit 75)
        };

        void collect_ancestor_names(const css_selector& selector, bool self, selector_names& names)
        {
            for(const css_selector* sel = &selector; sel; sel = sel->m_left.get())
            {
                const bool ancestor = !self || sel != &selector;
                for(const auto& attr : sel->m_right.m_attrs)
                {
                    // Telegram (VENDOR.md edit 75): a pseudo-class whose change reaches the subject's descendants or siblings.
                    if(ancestor && attr.type == select_pseudo_class)
                        names.pseudo.insert(attr.name);
                    if(ancestor)
                    {
                        if(attr.type == select_class)
                            names.classes.insert(attr.name);
                        else if(attr.type == select_id)
                            names.ids.insert(attr.name);
                        else if(attr.type == select_attr)
                            names.attrs.insert(attr.name);
                        else if(attr.type == select_pseudo_class && attr.name == _checked_)
                        {
                            names.attrs.insert(_id("checked"));
                            names.attrs.insert(_id("selected"));
                        } else if(attr.type == select_pseudo_class && (attr.name == _disabled_ || attr.name == _enabled_))
                            names.attrs.insert(_id("disabled"));
                        else if(attr.type == select_pseudo_class && attr.name == _link_)
                            names.attrs.insert(_id("href")); // Telegram (VENDOR.md edit 17): el_anchor pushes :link for an href
                    }
                    // Telegram (VENDOR.md edit 31.4): :lang() reads the lang attribute of the subject and its ancestors.
                    if(attr.type == select_pseudo_class && attr.name == _lang_)
                        names.attrs.insert(_id("lang"));
                    for(const auto& inner : attr.selector_list)
                    {
                        if(inner)
                            collect_ancestor_names(*inner, !ancestor, names);
                    }
                }
            }
        }

        // Telegram (VENDOR.md edit 75): the pseudo-classes `selector` names anywhere (inside :not(), :is() too).
        void collect_pseudo_classes(const css_selector& selector, std::unordered_set<string_id>& names)
        {
            for(const css_selector* sel = &selector; sel; sel = sel->m_left.get())
            {
                for(const auto& attr : sel->m_right.m_attrs)
                {
                    if(attr.type == select_pseudo_class)
                        names.insert(attr.name);
                    for(const auto& inner : attr.selector_list)
                    {
                        if(inner)
                            collect_pseudo_classes(*inner, names);
                    }
                }
            }
        }

        // Telegram (VENDOR.md edit 77): the classes, ids and attribute names `selector` names anywhere (inside :not(),
        // :is() too), with the attributes the pseudo-classes read (as collect_ancestor_names maps them).
        void collect_names(const css_selector& selector, std::unordered_set<string_id>& classes,
                           std::unordered_set<string_id>& ids, std::unordered_set<string_id>& attrs)
        {
            for(const css_selector* sel = &selector; sel; sel = sel->m_left.get())
            {
                for(const auto& attr : sel->m_right.m_attrs)
                {
                    if(attr.type == select_class)
                        classes.insert(attr.name);
                    else if(attr.type == select_id)
                        ids.insert(attr.name);
                    else if(attr.type == select_attr)
                        attrs.insert(attr.name);
                    else if(attr.type == select_pseudo_class && attr.name == _checked_)
                    {
                        attrs.insert(_id("checked"));
                        attrs.insert(_id("selected"));
                    } else if(attr.type == select_pseudo_class && (attr.name == _disabled_ || attr.name == _enabled_))
                        attrs.insert(_id("disabled"));
                    else if(attr.type == select_pseudo_class && attr.name == _link_)
                        attrs.insert(_id("href"));
                    else if(attr.type == select_pseudo_class && attr.name == _lang_)
                        attrs.insert(_id("lang"));
                    for(const auto& inner : attr.selector_list)
                    {
                        if(inner)
                            collect_names(*inner, classes, ids, attrs);
                    }
                }
            }
        }

        // Telegram (VENDOR.md edit 31.5): whether `selector` uses :empty anywhere (inside :not(), :is() too).
        bool uses_empty(const css_selector& selector)
        {
            for(const css_selector* sel = &selector; sel; sel = sel->m_left.get())
            {
                for(const auto& attr : sel->m_right.m_attrs)
                {
                    if(attr.type == select_pseudo_class && attr.name == _empty_)
                        return true;
                    for(const auto& inner : attr.selector_list)
                    {
                        if(inner && uses_empty(*inner))
                            return true;
                    }
                }
            }
            return false;
        }

        void scan_selector(const css_selector& selector, bool& attributes, bool& positions)
        {
            for(const css_selector* sel = &selector; sel; sel = sel->m_left.get())
            {
                if(sel->m_left && (sel->m_combinator == combinator_adjacent_sibling || sel->m_combinator == combinator_general_sibling))
                {
                    attributes = true;
                    positions  = true;
                }
                for(const auto& attr : sel->m_right.m_attrs)
                {
                    if(attr.type == select_pseudo_class)
                    {
                        switch(attr.name)
                        {
                        case _only_child_:
                        case _only_of_type_:
                        case _first_child_:
                        case _first_of_type_:
                        case _last_child_:
                        case _last_of_type_:
                        case _nth_child_:
                        case _nth_of_type_:
                        case _nth_last_child_:
                        case _nth_last_of_type_:
                            positions = true;
                            if(!attr.selector_list.empty())
                                attributes = true;
                            break;
                        default:
                            break;
                        }
                    }
                    for(const auto& inner : attr.selector_list)
                    {
                        if(inner)
                            scan_selector(*inner, attributes, positions);
                    }
                }
            }
        }
    }

    namespace
    {
        // Telegram (VENDOR.md edit 42): scan_selector, telling a positional pseudo-class in the subject compound (or in a
        // selector list inside it) from one anywhere else: `subject_positions` for the first, `positions` for the second.
        void scan_positions(const css_selector& selector, bool& attributes, bool& positions, bool& subject_positions,
                            bool& backward, bool& backward_of, bool subject)
        {
            for(const css_selector* sel = &selector; sel; sel = sel->m_left.get())
            {
                const bool here = subject && sel == &selector;
                if(sel->m_left && (sel->m_combinator == combinator_adjacent_sibling || sel->m_combinator == combinator_general_sibling))
                {
                    attributes = true;
                    positions  = true;
                }
                for(const auto& attr : sel->m_right.m_attrs)
                {
                    if(attr.type == select_pseudo_class)
                    {
                        switch(attr.name)
                        {
                        case _only_child_:
                        case _only_of_type_:
                        case _first_child_:
                        case _first_of_type_:
                        case _last_child_:
                        case _last_of_type_:
                        case _nth_child_:
                        case _nth_of_type_:
                        case _nth_last_child_:
                        case _nth_last_of_type_:
                            (here ? subject_positions : positions) = true;
                            if(!attr.selector_list.empty())
                                attributes = true;
                            // Telegram (VENDOR.md edit 90): one that reads the following siblings.
                            if(!here && (attr.name == _last_child_ || attr.name == _last_of_type_ ||
                                         attr.name == _only_child_ || attr.name == _only_of_type_ ||
                                         attr.name == _nth_last_child_ || attr.name == _nth_last_of_type_))
                                backward = true;
                            if(!attr.selector_list.empty() &&
                               (attr.name == _nth_last_child_ || attr.name == _nth_last_of_type_))
                                backward_of = true;
                            break;
                        default:
                            break;
                        }
                    }
                    for(const auto& inner : attr.selector_list)
                    {
                        if(inner)
                            scan_positions(*inner, attributes, positions, subject_positions, backward, backward_of, here);
                    }
                }
            }
        }
    } // namespace

    static std::vector<std::pair<std::string, std::string>> split_style_declarations(const std::string& text)
    {
        std::vector<std::pair<std::string, std::string>> out;
        size_t start = 0;
        int    depth = 0;
        char   quote = 0;
        for(size_t i = 0; i <= text.size(); i++)
        {
            const char c = i < text.size() ? text[i] : ';';
            if(quote)
            {
                if(c == quote)
                    quote = 0;
                continue;
            }
            if(c == '"' || c == '\'')
                quote = c;
            else if(c == '(')
                depth++;
            else if(c == ')')
                depth--;
            else if(c == ';' && depth <= 0)
            {
                std::string decl = text.substr(start, i - start);
                start = i + 1;
                size_t colon = decl.find(':');
                if(colon == std::string::npos)
                {
                    if(decl.find_first_not_of(" \t\n") != std::string::npos)
                        out.emplace_back(decl, std::string());
                    continue;
                }
                size_t a = decl.find_first_not_of(" \t\n"), b = decl.find_last_not_of(" \t\n", colon - 1);
                std::string name = a == std::string::npos || a >= colon ? std::string() : decl.substr(a, b - a + 1);
                out.emplace_back(name, decl.substr(colon + 1));
            }
        }
        return out;
    }

    // A style hole may be patched in place unless the edit touches custom properties, var() or counters,
    // whose effects reach other elements.
    static bool paint_only_property(const std::string& name)
    {
        static const std::unordered_set<std::string>& paint = *new std::unordered_set<std::string>{
            "color", "background", "background-color", "background-image", "background-position", "background-repeat",
            "opacity", "transform", "transform-origin", "box-shadow", "text-shadow", "filter", "outline", "outline-color",
            "outline-width", "outline-style", "outline-offset", "visibility", "fill", "fill-opacity", "stroke", "stroke-opacity",
            "stroke-width", "stroke-dasharray", "stroke-dashoffset", "stop-color", "stop-opacity", "border-color",
            "border-top-color", "border-right-color", "border-bottom-color", "border-left-color", "text-decoration-color",
            "caret-color", "cursor", "-lh-anim"};
        return paint.count(name) != 0;
    }

    // Telegram (VENDOR.md edit 63): a property only layout reads: a box's size, margins, padding, offsets, gaps and flex
    // sizes. Creating and initialising render items reads display, position, float, list-style-type, white-space and
    // flex-direction, never these, so a change of them keeps the render tree; the restyle marks the box's layout dirty.
    static bool geometry_only_property(const std::string& name)
    {
        static const std::unordered_set<std::string>& geometry = *new std::unordered_set<std::string>{
            "width", "height", "min-width", "min-height", "max-width", "max-height", "margin", "margin-top", "margin-right",
            "margin-bottom", "margin-left", "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
            "top", "right", "bottom", "left", "inset", "gap", "row-gap", "column-gap", "flex-grow", "flex-shrink",
            "flex-basis"};
        return geometry.count(name) != 0;
    }

    // Telegram (VENDOR.md edit 27): whether a change of the property can change paint order or start or end a paint
    // group (commit_patch tells the render observer).
    static bool paint_order_property(const std::string& property)
    {
        return property == "opacity" || property == "transform" || property == "transform-origin" || property == "filter" ||
               property == "visibility" || property == "-lh-anim";
    }

    // Telegram (VENDOR.md edit 27): the properties whose declaration one text has and the other has not, or has with
    // another value.
    static std::vector<std::string> changed_declarations(const std::string& before, const std::string& after)
    {
        // Telegram (VENDOR.md edit 62): a value without the whitespace around it, so that a re-serialization (CSSOM
        // writes `width: 40px;` for `width:40px`) changes nothing.
        auto trimmed = [](const std::string& value) {
            const size_t a = value.find_first_not_of(" \t\n");
            return a == std::string::npos ? std::string() : value.substr(a, value.find_last_not_of(" \t\n") - a + 1);
        };
        std::map<std::string, std::string> left, right;
        for(const auto& d : split_style_declarations(before))
            left[d.first] = trimmed(d.second);
        for(const auto& d : split_style_declarations(after))
            right[d.first] = trimmed(d.second);
        std::vector<std::string> changed;
        for(const auto& d : left)
        {
            auto it = right.find(d.first);
            if(it == right.end() || it->second != d.second)
                changed.push_back(d.first);
        }
        for(const auto& d : right)
        {
            if(!left.count(d.first))
                changed.push_back(d.first);
        }
        return changed;
    }

    namespace
    {
    }

    bool document::take_table_cells(int count)
    {
        if(m_table_cells + count > max_table_cells)
        {
            if(!m_table_limited)
            {
                m_table_limited = true;
                if(!m_table_quiet) // Telegram (VENDOR.md edit 84)
                    m_container->sanitizer_limit("table");
            }
            return false;
        }
        m_table_cells += count;
        return true;
    }

    // Telegram (VENDOR.md edit 10).
    bool document::text_element_allowed()
    {
#if 0
        if(m_text_elements < max_text_elements + m_text_allowance)
            return true;
#else
        // Telegram (VENDOR.md edit 17): a patch session does not count the pieces it replaced or forgot.
        if(m_text_elements - m_patch_released < max_text_elements + m_text_allowance)
            return true;
#endif
        if(!m_text_limited)
        {
            m_text_limited = true;
            m_container->sanitizer_limit("text");
            note_style_pass_limit("text"); // Telegram (VENDOR.md edit 84)
        }
        return false;
    }

    // Telegram (VENDOR.md edit 19).
    bool document::pseudo_element_allowed()
    {
        // Telegram (VENDOR.md edit 84): not the pseudo-elements the patch session released (held to its commit).
        if(m_build_elements + m_pseudo_elements - m_patch_pseudo_released < max_build_elements)
            return true;
        if(!m_pseudo_limited)
        {
            m_pseudo_limited = true;
            m_container->sanitizer_limit("elements");
            note_style_pass_limit("elements"); // Telegram (VENDOR.md edit 84)
        }
        return false;
    }

    void document::forget_positions()
    {
        if(!m_root_render)
            return;
        // Telegram (VENDOR.md edit 20): what the observer compares when the layout ends is what was there before this.
        if(m_render_observer)
        {
            if(layout_cache_enabled())
            {
                for(render_item* item : m_layout_marked)
                    item->observe_geometry();
            } else
            {
                std::vector<render_item*> observed{m_root_render.get()};
                while(!observed.empty())
                {
                    render_item* item = observed.back();
                    observed.pop_back();
                    item->observe_geometry();
                    for(const auto& child : item->children())
                        observed.push_back(child.get());
                }
            }
        }
        if(layout_cache_enabled())
        {
            for(render_item* item : m_layout_marked)
                item->pos() = position();
            m_layout_marked.clear();
            return;
        }
        std::vector<render_item*> pending{m_root_render.get()};
        while(!pending.empty())
        {
            render_item* item = pending.back();
            pending.pop_back();
            item->pos() = position();
            for(const auto& child : item->children())
                pending.push_back(child.get());
        }
    }

    bool document::replace_text_renderers(const std::vector<element::ptr>& current,
                                          const elements_list& replacement)
    {
#if 0
        if(current.empty() || replacement.empty())
            return false;
        auto owner = current.front()->parent();
        if(!owner || owner->children().size() != replacement.size() ||
           !std::equal(owner->children().begin(), owner->children().end(), replacement.begin()))
            return false;
        std::shared_ptr<render_item> target;
        owner->run_on_renderers([&](const std::shared_ptr<render_item>& item) {
            if(!std::dynamic_pointer_cast<render_item_inline_context>(item) || item->children().size() != current.size())
                return true;
            auto root = item;
            while(auto parent = root->parent())
                root = parent;
            if(root != m_root_render)
                return true;
            auto old = current.begin();
            for(const auto& child : item->children())
            {
                if(child->src_el() != *old++)
                    return true;
            }
            target = item;
            return false;
        });
        if(!target)
            return false;
        for(const auto& child : target->children())
            m_layout_marked.erase(std::remove(m_layout_marked.begin(), m_layout_marked.end(), child.get()), m_layout_marked.end());
        // Telegram (VENDOR.md edit 20): the inline context's old pieces go, its new ones come, and its text was replaced.
        if(m_render_observer)
        {
            for(const auto& child : target->children())
            {
                m_observed.erase(std::remove(m_observed.begin(), m_observed.end(), child.get()), m_observed.end());
                m_render_observer->item_removed(child.get());
            }
        }
        target->children().clear();
        for(const auto& child : replacement)
            target->add_child(child->create_render_item(target)->init());
        if(m_render_observer)
        {
            for(const auto& child : target->children())
                m_render_observer->item_added(child);
            m_render_observer->text_replaced(target.get());
        }
        target->mark_layout_dirty();
        m_render_tree_serial++;
        return true;
    #else
        // Telegram (VENDOR.md edit 16, amended): the old pieces' renderers are a run among the children of their owner's
        // render item, which is the owner's inline context (a <p>'s text) or an inline element's own item (a <span>'s, a
        // <b>'s, whose pieces its inline context lays out), beside other children or not (an element, a ::before). The
        // run is replaced, nothing else; the owner's children, which hold the replacement already, must match the item's
        // children one for one afterwards.
        if(current.empty() || replacement.empty())
            return false;
        auto owner = current.front()->parent();
        if(!owner)
            return false;
        std::shared_ptr<render_item>                          target;
        std::list<std::shared_ptr<render_item>>::iterator run;
        owner->run_on_renderers([&](const std::shared_ptr<render_item>& item) {
            auto root = item;
            while(auto parent = root->parent())
                root = parent;
            if(root != m_root_render || item->src_el() != owner)
                return true;
            // An inline context, or an inline element's own item, which its inline context lays out: nothing else.
            if(!std::dynamic_pointer_cast<render_item_inline_context>(item) &&
               !(owner->css().get_display() == display_inline && std::dynamic_pointer_cast<render_item_inline>(item)))
                return true;
            auto& kids = item->children();
            for(auto at = kids.begin(); at != kids.end(); ++at)
            {
                auto probe = at;
                auto old   = current.begin();
                while(probe != kids.end() && old != current.end() && (*probe)->src_el() == *old)
                {
                    ++probe;
                    ++old;
                }
                if(old == current.end())
                {
                    target = item;
                    run    = at;
                    return false;
                }
            }
            return true;
        });
        if(!target)
            return false;
        auto& kids = target->children();
        // One for one: the item's children before the run, the replacement, and those after it are the owner's.
        if(kids.size() - current.size() + replacement.size() != owner->children().size())
            return false;
        {
            auto el = owner->children().begin();
            for(auto at = kids.begin(); at != run; ++at, ++el)
            {
                if((*at)->src_el() != *el)
                    return false;
            }
            for(const auto& piece : replacement)
            {
                if(*el++ != piece)
                    return false;
            }
            auto after = run;
            std::advance(after, current.size());
            for(auto at = after; at != kids.end(); ++at, ++el)
            {
                if((*at)->src_el() != *el)
                    return false;
            }
        }
        auto after = run;
        std::advance(after, current.size());
        for(auto at = run; at != after; ++at)
            m_layout_marked.erase(std::remove(m_layout_marked.begin(), m_layout_marked.end(), at->get()), m_layout_marked.end());
        // Telegram (VENDOR.md edit 20): the run's old pieces go, its new ones come, and the item's text was replaced.
        if(m_render_observer)
        {
            for(auto at = run; at != after; ++at)
            {
                m_observed.erase(std::remove(m_observed.begin(), m_observed.end(), at->get()), m_observed.end());
                m_render_observer->item_removed(at->get());
            }
        }
        std::vector<std::shared_ptr<render_item>> added;
        added.reserve(replacement.size());
        auto at = kids.erase(run, after);
        for(const auto& child : replacement)
        {
            auto item = child->create_render_item(target)->init();
            item->parent(target);
            kids.insert(at, item);
            added.push_back(item);
        }
        if(m_render_observer)
        {
            for(const auto& item : added)
                m_render_observer->item_added(item);
            m_render_observer->text_replaced(target.get());
        }
        target->mark_layout_dirty();
        m_render_tree_serial++;
        return true;
#endif
    }

    void document::restyle_after_patch(const std::vector<element::ptr>& restyle, const std::vector<element::ptr>& new_text,
                                       bool keep_tree, const std::vector<element::ptr>& retext,
                                       const std::unordered_set<const element*>& background_only)
    {
        invalidate_paint();
        m_share_cache.clear();
        std::unordered_set<const element*> pending;
        for(const auto& el : restyle)
        {
            if(auto tag = std::dynamic_pointer_cast<html_tag>(el))
                tag->restore_base_style();
            pending.insert(el.get());
        }
        for(const auto& el : new_text)
            pending.insert(el.get());
        for(const auto& el : retext)
            pending.insert(el.get());
        auto covered = [&pending](const element::ptr& el) {
            for(auto p = el->parent(); p; p = p->parent())
            {
                if(pending.count(p.get()))
                    return true;
            }
            return false;
        };
        if(!keep_tree || !new_text.empty())
            m_layout_before_valid = false;
        const bool positioned_fresh = keep_tree && new_text.empty() && m_positioned_epoch == m_style_epoch &&
                                      m_positioned_tree == m_render_tree_serial;
        // Telegram (VENDOR.md edit 87): what add_positioned reads of each element: its position, and whether it holds
        // the positioned boxes inside it (a transform, contain: layout or paint).
        auto holds_positioned = [](const element* el) {
            return !el->css().get_transform().empty() || el->css().contains(contain_layout | contain_paint);
        };
        std::vector<std::tuple<const element*, element_position, bool>> positions;
        auto collect_positions = [&positions, &holds_positioned](const element::ptr& root) {
            std::vector<const element*> stack{root.get()};
            while(!stack.empty())
            {
                const element* el = stack.back();
                stack.pop_back();
                positions.emplace_back(el, el->css().get_position(), holds_positioned(el));
                for(const auto& child : el->children())
                    stack.push_back(child.get());
            }
        };
        std::vector<element::ptr> roots;
        for(const auto& list : {&restyle, &new_text, &retext})
        {
            for(const auto& el : *list)
            {
                if(!covered(el))
                    roots.push_back(el);
            }
        }
        if(positioned_fresh)
        {
            for(const auto& el : roots)
                collect_positions(el);
        }
        for(const auto& el : roots)
        {
            if(background_only.count(el.get()))
                std::static_pointer_cast<html_tag>(el)->compute_background_style();
            else
                el->compute_styles(true);
        }
        if(positioned_fresh)
        {
            bool same = true;
            for(const auto& [el, position, holds] : positions)
            {
                if(el->css().get_position() != position || holds_positioned(el) != holds)
                {
                    same = false;
                    break;
                }
            }
            if(same)
                m_positioned_epoch = m_style_epoch;
        }

    }

    std::shared_ptr<render_item> document::live_item(const element& el) const
    {
        std::shared_ptr<render_item> found;
        bool several = false;
        el.for_each_render_item([&](const std::shared_ptr<render_item>& item) {
            auto parent = item->parent();
            if(parent && parent->src_el().get() == &el)
                return;
            auto top = item;
            while(top->parent())
                top = top->parent();
            if(top != m_root_render || item == found)
                return;
            several = several || found;
            found = item;
        });
        return several ? nullptr : found;
    }

    // Telegram (VENDOR.md edit 74): an element's outer box, the part of its computed style its parent's render structure
    // reads (render_item_block::init, split_inlines and render_item_flex::init read a child's display and float).
    document::outer_box document::outer_box_of(const element& el)
    {
        return outer_box{el.css().get_display(), el.css().get_float(), el.css().get_position()};
    }

    void document::record_boxes(const element::ptr& seed)
    {
        // An element recorded already had its ancestors recorded with it.
        for(element::ptr el = seed; el; el = el->parent())
        {
            m_replacement_steps++;
            if(!m_patch_boxes.emplace(el.get(), outer_box_of(*el)).second)
                break;
        }
    }

    void document::note_replacement(const element::ptr& seed, std::string why)
    {
        m_patch_keep_tree = false;
        if(seed)
            m_patch_seeds.push_back(seed);
        note_rebuild(std::move(why));
    }

    // Whether `el` or an ancestor is in `set`; each element's answer is kept in `memo`, so a commit steps through each
    // element once whatever the number of questions.
    bool document::inside_any(const element* el, const std::unordered_set<const element*>& set,
                              std::unordered_map<const element*, bool>& memo) const
    {
        std::vector<const element*> path;
        bool inside = false;
        for(const element* e = el; e;)
        {
            m_replacement_steps++;
            if(set.count(e))
            {
                inside = true;
                break;
            }
            auto known = memo.find(e);
            if(known != memo.end())
            {
                inside = known->second;
                break;
            }
            path.push_back(e);
            e = e->parent().get();
        }
        for(const element* e : path)
            memo[e] = inside;
        return inside;
    }

    // Where the session's seeds are replaced (the boundary rule): from each seed in the document up, the first element
    // whose outer box is what it was and whose render item stands alone (a block-level box, an inline-level box with its
    // own formatting, or a replaced element, but no table part, which its table's grid holds; with one live item, not in
    // an anonymous block made from it, which a flex container makes for an item that is not a block box and which
    // inherits from it). A seed under an element that renders nothing and still does not is dropped, unless the document
    // has had an <svg>, which a <use> or a url(#…) paint can draw from anywhere. The root when a walk reaches it or the
    // table-cell cap has cut the document; the outer ones of nested boundaries. Each element a walk passes keeps where it
    // led, so a commit steps through each element once.
    std::vector<element::ptr> document::replacement_boundaries(const std::vector<element::ptr>& seeds,
                                                               const std::unordered_map<const element*, outer_box>& boxes) const
    {
        if(m_table_limited)
            return {m_root};
        std::unordered_map<const element*, const element*> led; // the boundary, or null: dropped
        std::vector<element::ptr> found;
        for(const auto& seed : seeds)
        {
            std::vector<const element*> path;
            const element* verdict = nullptr;
            for(element::ptr b = seed; b; b = b->parent())
            {
                m_replacement_steps++;
                auto known = led.find(b.get());
                if(known != led.end())
                {
                    verdict = known->second;
                    break;
                }
                path.push_back(b.get());
                if(b == m_root)
                    return {m_root};
                auto was = boxes.find(b.get());
                if(was == boxes.end() || !(was->second == outer_box_of(*b)))
                    continue;
                const style_display display = b->css().get_display();
                if(display == display_none)
                {
                    if(m_has_svg)
                        continue;
                    break;
                }
                const bool table_part = display == display_table_row || display == display_table_cell ||
                                        display == display_table_caption || display == display_table_column ||
                                        display == display_table_column_group || display == display_table_row_group ||
                                        display == display_table_header_group || display == display_table_footer_group;
                const bool stands_alone = !table_part && (display == display_block || display == display_list_item ||
                                                          display == display_inline_block || display == display_table ||
                                                          display == display_inline_table || display == display_flex ||
                                                          display == display_inline_flex || display == display_grid ||
                                                          display == display_inline_grid || b->is_replaced());
                if(!stands_alone)
                    continue;
                std::shared_ptr<render_item> item = live_item(*b);
                if(!item)
                    continue;
                std::shared_ptr<render_item> parent = item->parent();
                if(parent && parent->src_el() && parent->src_el()->parent() == b)
                    continue;
                verdict = b.get();
                found.push_back(b);
                break;
            }
            for(const element* e : path)
                led[e] = verdict;
        }
        std::unordered_set<const element*> boundaries;
        for(const auto& b : found)
            boundaries.insert(b.get());
        std::unordered_map<const element*, bool> above;
        std::vector<element::ptr> outer;
        for(const auto& b : found)
        {
            auto parent = b->parent();
            if(!parent || !inside_any(parent.get(), boundaries, above))
                outer.push_back(b);
        }
        return outer;
    }

    // Telegram (VENDOR.md edit 74): each boundary's render subtree made again, as a build makes it, and put where the old
    // one was; the render observer hears subtree_replaced for each while the old one is alive. The root among them, or a
    // boundary with no live item under a parent, replaces the root: everything is made again. True when the root was.
    bool document::replace_render_subtrees(const std::vector<element::ptr>& boundaries)
    {
        struct replacement
        {
            element::ptr                 el;
            std::shared_ptr<render_item> old;
            std::shared_ptr<render_item> parent;
            std::shared_ptr<render_item> item;
        };
        std::vector<replacement> made;
        bool root = !m_root_render;
        for(const auto& el : boundaries)
        {
            std::shared_ptr<render_item> old = el == m_root ? nullptr : live_item(*el);
            std::shared_ptr<render_item> parent = old ? old->parent() : nullptr;
            if(!parent)
            {
                root = true;
                break;
            }
            made.push_back({el, old, parent, nullptr});
        }
        if(root)
        {
            replace_root_render();
            return true;
        }
        // The old subtrees go, and the new ones are made as a build makes the tree.
        std::vector<render_item*> tops;
        for(const auto& r : made)
            tops.push_back(r.old.get());
        release_render_subtrees(tops);
        for(auto& r : made)
            r.item = make_render_subtree(r.el, r.parent);
        // Each parent's children once: the old items swapped for the new ones where they were.
        std::unordered_map<const render_item*, const replacement*> by_old;
        std::vector<render_item*> parents;
        for(const auto& r : made)
        {
            by_old.emplace(r.old.get(), &r);
            if(std::find(parents.begin(), parents.end(), r.parent.get()) == parents.end())
                parents.push_back(r.parent.get());
        }
        size_t spliced = 0;
        for(render_item* parent : parents)
        {
            auto& kids = parent->children();
            for(auto at = kids.begin(); at != kids.end();)
            {
                m_replacement_steps++;
                auto r = by_old.find(at->get());
                if(r == by_old.end())
                {
                    ++at;
                    continue;
                }
                spliced++;
                if(r->second->item)
                {
                    *at = r->second->item;
                    r->second->item->parent(r->second->parent);
                    ++at;
                } else
                {
                    at = kids.erase(at);
                }
            }
        }
        if(spliced != made.size())
        {
            replace_root_render();
            return true;
        }
        for(const auto& r : made)
        {
            r.old->parent(nullptr);
            // Line boxes, flex lines and positioned lists can point at the old items until the next layout.
            m_replaced_hold.push_back(r.old);
            if(r.item)
                r.item->mark_layout_dirty();
            else
                r.parent->mark_layout_dirty();
        }
        m_render_tree_serial++;
        m_layout_before_valid = false;
        for(const auto& r : made)
        {
            if(r.item)
                m_pending_replacements.emplace_back(r.old, r.item);
        }
        return false;
    }

    // Telegram (VENDOR.md edits 74, 89): a render subtree's tables give their cells back, and its items leave the layout's
    // lists and their elements.
    void document::release_render_subtrees(const std::vector<render_item*>& tops)
    {
        std::unordered_set<render_item*> gone;
        for(render_item* top : tops)
        {
            std::vector<render_item*> pending{top};
            while(!pending.empty())
            {
                render_item* item = pending.back();
                pending.pop_back();
                m_replacement_steps++;
                gone.insert(item);
                if(auto table = dynamic_cast<render_item_table*>(item))
                    m_table_cells -= table->cells_taken();
                for(const auto& child : item->children())
                    pending.push_back(child.get());
            }
        }
        const auto in_gone = [&gone](render_item* item) { return gone.count(item) != 0; };
        m_layout_marked.erase(std::remove_if(m_layout_marked.begin(), m_layout_marked.end(), in_gone), m_layout_marked.end());
        m_relayout_roots.erase(std::remove_if(m_relayout_roots.begin(), m_relayout_roots.end(), in_gone), m_relayout_roots.end());
        m_observed.erase(std::remove_if(m_observed.begin(), m_observed.end(), in_gone), m_observed.end());
        for(render_item* item : gone)
            item->src_el()->remove_render(item);
    }

    // Telegram (VENDOR.md edits 74, 89): `el`'s render subtree made under `parent` as a build makes it.
    std::shared_ptr<render_item> document::make_render_subtree(const element::ptr& el, const std::shared_ptr<render_item>& parent)
    {
        m_tabular_elements.clear();
        std::shared_ptr<render_item> item = el->create_render_item(parent);
        fix_tables_layout();
        item = item ? item->init() : nullptr;
        m_tabular_elements.clear();
        return item;
    }

    // Telegram (VENDOR.md edit 89): whether `parent`'s render children follow the session's changes to its children by
    // links alone. They do when its one live item is a block formatting context's and the children render_item_block::init
    // would make from its children now are its render children but the fresh block-level ones and those of the removed
    // children; the first reason that holds otherwise is the refusal. Each child is stepped through once, and each
    // anonymous block's children.
    document::link_plan document::plan_link(const element::ptr& parent, const std::unordered_set<const element*>& fresh) const
    {
        link_plan plan;
        const auto refuse = [&plan](const char* why) {
            plan.refusal = why;
            plan.children.clear();
            plan.unlinked.clear();
            return plan;
        };
        if(m_table_limited)
            return refuse("at the table-cell cap");
        const std::shared_ptr<render_item> item = live_item(*parent);
        if(!item)
        {
            bool any = false;
            parent->for_each_render_item([&any](const std::shared_ptr<render_item>&) { any = true; });
            return refuse(any ? "several render items" : "renders nothing");
        }
        if(parent->is_replaced())
            return refuse("in a replaced element");
        const render_item&    object = *item;
        const std::type_info& type   = typeid(object);
        if(type == typeid(render_item_inline_context))
            return refuse("in an inline context");
        if(type == typeid(render_item_inline))
            return refuse("in an inline");
        if(type == typeid(render_item_flex))
            return refuse("in a flex container");
        if(type == typeid(render_item_grid))
            return refuse("in a grid");
        if(type == typeid(render_item_table) || type == typeid(render_item_table_row) || type == typeid(render_item_table_part))
            return refuse("in a table");
        if(type != typeid(render_item_block_context))
            return refuse("elsewhere");
        if(parent->tag() == _details_ && !parent->get_attr("open"))
            return refuse("in a closed details");
        // What render_item_block::init makes of the children in a block formatting context: each child that is not inline
        // alone, and each run of inline children an anonymous block when it holds more than white space (a run of white
        // space alone is dropped). A child create_render_item makes nothing for (display: none, a comment) makes nothing.
        // A table part outside a table is wrapped with its like siblings in an anonymous table (fix_table_parent), which
        // this does not follow.
        const auto table_part = [](const element& el) {
            switch(el.css().get_display())
            {
            case display_table_caption:
            case display_table_cell:
            case display_table_column:
            case display_table_column_group:
            case display_table_footer_group:
            case display_table_header_group:
            case display_table_row:
            case display_table_row_group:
                return true;
            default:
                return false;
            }
        };
        struct token
        {
            element::ptr                block;
            std::vector<const element*> run;
        };
        std::vector<token>                 expected;
        std::vector<const element*>        run;
        bool                               solid       = false;
        bool                               block_level = false;
        std::unordered_set<const element*> kids;
        const auto close = [&] {
            if(solid)
                expected.push_back({nullptr, run});
            run.clear();
            solid = false;
        };
        for(const auto& child : parent->children())
        {
            m_replacement_steps++;
            kids.insert(child.get());
            if(child->css().get_display() == display_none || std::dynamic_pointer_cast<el_comment>(child))
                continue;
            if(table_part(*child))
                return refuse("a table part outside a table");
            if(!child->is_float() && child->is_block_box())
                block_level = true;
            if(!child->is_inline())
            {
                close();
                expected.push_back({child, {}});
                continue;
            }
            run.push_back(child.get());
            solid = solid || !child->is_white_space();
        }
        close();
        if(!block_level)
            return refuse("the formatting context flips");
        // The render children: a child's own item, an anonymous block (made from the parent: its element is the parent's
        // but none of its children), or a removed child's item (its element left the document's tree). Anything else is a
        // block an inline holding it was split around (render_item::split_inlines).
        std::vector<std::shared_ptr<render_item>> current;
        for(const auto& child : item->children())
        {
            m_replacement_steps++;
            const element* el = child->src_el().get();
            if(!kids.count(el) && el->parent() == parent && dynamic_cast<render_item_table*>(child.get()))
                return refuse("a table part outside a table");
            if(kids.count(el) || (el->parent() == parent))
                current.push_back(child);
            else if(!el->parent())
            {
                if(table_part(*el))
                    return refuse("a table part outside a table");
                plan.unlinked.push_back(child);
            }
            else
                return refuse("an inline holding blocks");
        }
        const auto out_of_flow = [](const element& el) {
            return el.is_float() || el.css().get_position() == element_position_absolute ||
                   el.css().get_position() == element_position_fixed;
        };
        for(const auto& gone : plan.unlinked)
        {
            if(out_of_flow(*gone->src_el()))
                return refuse("a float or an out-of-flow box");
        }
        for(const token& t : expected)
        {
            if(t.block && fresh.count(t.block.get()) && out_of_flow(*t.block))
                return refuse("a float or an out-of-flow box");
        }
        // The kept children in order: each expected child that is not fresh is the next render child, its own item or an
        // anonymous block holding the same run.
        auto at = current.begin();
        for(const token& t : expected)
        {
            if(t.block && fresh.count(t.block.get()))
            {
                plan.children.push_back({t.block, nullptr});
                continue;
            }
            if(at == current.end())
                return refuse("inline content");
            const std::shared_ptr<render_item>& kept = *at++;
            if(t.block)
            {
                if(kept->src_el() != t.block)
                    return refuse("inline content");
            } else
            {
                if(kids.count(kept->src_el().get()) || kept->children().size() != t.run.size())
                    return refuse("inline content");
                auto member = t.run.begin();
                for(const auto& inner : kept->children())
                {
                    m_replacement_steps++;
                    if(inner->src_el().get() != *member++)
                        return refuse("inline content");
                }
            }
            plan.children.push_back({nullptr, kept});
        }
        if(at != current.end())
            return refuse("inline content");
        return plan;
    }

    // Telegram (VENDOR.md edit 89): the removed children's render subtrees leave the parent's item (alive until the next
    // layout and the report), the fresh block-level ones are made where they go, and the list items after the change are
    // numbered again, as render_item_block::init numbers them (from the parent's `start`, every list item counted).
    void document::link_render_children(const element::ptr& parent, const link_plan& plan,
                                        const std::unordered_set<const element*>& fresh,
                                        std::vector<element::ptr>& renumbered, std::vector<element::ptr>& linked)
    {
        const std::shared_ptr<render_item> item = live_item(*parent);
        std::vector<render_item*> tops;
        for(const auto& gone : plan.unlinked)
            tops.push_back(gone.get());
        release_render_subtrees(tops);
        for(const auto& gone : plan.unlinked)
        {
            gone->parent(nullptr);
            m_replaced_hold.push_back(gone);
            m_pending_unlinks.push_back(gone);
        }
        std::list<std::shared_ptr<render_item>> children;
        for(const auto& child : plan.children)
        {
            m_replacement_steps++;
            if(!child.fresh)
            {
                children.push_back(child.item);
                continue;
            }
            std::shared_ptr<render_item> made = make_render_subtree(child.fresh, item);
            if(!made)
                continue;
            made->parent(item);
            made->mark_layout_dirty();
            children.push_back(made);
            m_pending_links.push_back(made);
            linked.push_back(child.fresh);
        }
        item->children() = std::move(children);
        if(!plan.unlinked.empty())
            item->mark_layout_dirty();
        bool lists = false;
        for(const auto& child : parent->children())
            lists = lists || child->css().get_display() == display_list_item;
        if(lists)
        {
            int val = atoi(parent->get_attr("start", "1"));
            for(const auto& child : parent->children())
            {
                m_replacement_steps++;
                if(child->css().get_display() != display_list_item)
                    continue;
                const std::string index = std::to_string(val++);
                if(child->css().get_list_style_type() < list_style_type_armenian || fresh.count(child.get()))
                    continue;
                const char* now = child->get_attr("list_index");
                if(now && index == now)
                    continue;
                child->set_attr("list_index", index.c_str());
                if(auto li = live_item(*child))
                    li->mark_layout_dirty();
                renumbered.push_back(child);
            }
        }
        m_render_tree_serial++;
        m_layout_before_valid = false;
    }

    // Telegram (VENDOR.md edits 74, 89): the replacements, unlinks and links made since the last report, told once each,
    // at the end of what made them; a root replaced among them is told alone, from the root as it was before the first.
    void document::report_replacements()
    {
        std::vector<std::pair<std::shared_ptr<render_item>, std::shared_ptr<render_item>>> pending;
        pending.swap(m_pending_replacements);
        std::vector<std::shared_ptr<render_item>> links, unlinks;
        links.swap(m_pending_links);
        unlinks.swap(m_pending_unlinks);
        if(!m_render_observer)
            return;
        const auto is_root = [](const auto& r) { return !r.second || !r.second->parent(); };
        const auto first_root = std::find_if(pending.begin(), pending.end(), is_root);
        if(first_root != pending.end())
        {
            const auto last_root = std::find_if(pending.rbegin(), pending.rend(), is_root);
            m_render_observer->subtree_replaced(first_root->first.get(), last_root->second);
            return;
        }
        for(const auto& r : pending)
            m_render_observer->subtree_replaced(r.first.get(), r.second);
        for(const auto& gone : unlinks)
            m_render_observer->subtree_unlinked(gone.get());
        for(const auto& made : links)
            m_render_observer->subtree_linked(made);
    }

    void document::replace_root_render()
    {
        std::shared_ptr<render_item> old = m_root_render;
        // The old items leave their elements first: the new ones register as they are made.
        if(old)
        {
            std::vector<render_item*> pending{old.get()};
            while(!pending.empty())
            {
                render_item* item = pending.back();
                pending.pop_back();
                item->src_el()->remove_render(item);
                for(const auto& child : item->children())
                    pending.push_back(child.get());
            }
        }
        m_tabular_elements.clear();
        m_table_cells = 0;
        // Telegram (VENDOR.md edit 84): the cells count from zero in tree order, as a build's; a cap reached already is not
        // reported again.
        const bool table_limited = m_table_limited;
        m_table_limited          = false;
        m_table_quiet            = table_limited;
        m_observed.clear();
        m_root_render = m_root->create_render_item(nullptr);
        m_render_tree_serial++;
        m_layout_marked.clear();
        m_relayout_roots.clear();
        m_layout_before_valid = false;
        fix_tables_layout();
        if(m_root_render)
            m_root_render = m_root_render->init();
        m_table_quiet = false;
        m_tabular_elements.clear();
        if(!m_root_render)
        {
            // A root that goes (`display: none` on the document element) leaves no size, as a fresh document's, and no
            // layout to point at the replaced items (the report holds the old root until it is told).
            m_size.width  = 0;
            m_size.height = 0;
            m_replaced_hold.clear();
        }
        // A root that appears or goes is reported too, its missing side null.
        if(old || m_root_render)
            m_pending_replacements.emplace_back(old, m_root_render);
    }

    int document::selector_scope()
    {
        if(m_selector_scope >= 0)
            return m_selector_scope;
        bool           attributes = false;
        bool           positions  = false;
        bool           backward   = false;
        bool           backward_of = false;
        selector_names names{m_left_classes, m_left_ids, m_left_attrs, m_left_pseudo};
        for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
        {
            for(const auto& sel : sheet->selectors())
            {
                if(!sel)
                    continue;
#if 0
                scan_selector(*sel, attributes, positions);
#else
                // Telegram (VENDOR.md edit 42): a rule positional in its subject alone is kept apart.
                bool subject = false;
                scan_positions(*sel, attributes, positions, subject, backward, backward_of, true);
                if(subject)
                {
                    const bool child = sel->m_left && sel->m_combinator == combinator_child;
                    m_subject_positions.push_back({sel->m_right.m_tag, child ? sel->m_left->m_right.m_tag : star_id});
                }
#endif
                collect_ancestor_names(*sel, !(sel->m_style && sel->m_style->declares_custom_property()), names);
                // Telegram (VENDOR.md edit 75)
                std::unordered_set<string_id> pseudo;
                collect_pseudo_classes(*sel, pseudo);
                for(string_id name : pseudo)
                    m_pseudo_class_rules[name].push_back(sel.get());
                // Telegram (VENDOR.md edit 77)
                std::unordered_set<string_id> classes, ids, attrs;
                collect_names(*sel, classes, ids, attrs);
                for(string_id name : classes)
                    m_class_rules[name].push_back(sel.get());
                for(string_id name : ids)
                    m_id_rules[name].push_back(sel.get());
                for(string_id name : attrs)
                    m_attr_rules[name].push_back(sel.get());
            }
        }
        bool counters = mentions_counters(m_master_styles);
        for(const auto& sheet : m_css)
            counters = counters || mentions_counters(sheet.text);
        m_selector_scope = (attributes ? 1 : 0) | (positions ? 2 : 0) | (counters ? 4 : 0);
        m_backward_positions = backward; // Telegram (VENDOR.md edit 90)
        m_backward_of_lists  = backward_of;
        if(!m_subject_positions.empty())
            m_selector_scope |= 16; // Telegram (VENDOR.md edit 42)
        // Telegram (VENDOR.md edit 31.5): 8 when :empty is used: a change of an element's children changes how the
        // element itself matches, which the commit matches again where it flipped (edit 88).
        for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
        {
            for(const auto& sel : sheet->selectors())
            {
                if(sel && uses_empty(*sel))
                {
                    m_selector_scope |= 8;
                    break;
                }
            }
        }
        return m_selector_scope;
    }

    namespace
    {
        // Telegram (VENDOR.md edit 73): the first attribute, in name order, whose presence or value differs.
        std::string first_changed_key(const string_map& before, const string_map& after)
        {
            std::set<std::string> names;
            for(const auto& entry : before)
                names.insert(entry.first);
            for(const auto& entry : after)
                names.insert(entry.first);
            for(const auto& name : names)
            {
                auto a = before.find(name), b = after.find(name);
                if((a == before.end()) != (b == after.end()) || (a != before.end() && a->second != b->second))
                    return name;
            }
            return std::string();
        }
    }

    bool document::apply_retag(const element::ptr& el, const string_map& attrs, bool check)
    {
        auto             tag          = std::static_pointer_cast<html_tag>(el);
        const string_map attrs_before = tag->attributes();
        tag->reset_attributes(attrs);
        return rematch(el, check, attrs_before);
    }

    namespace
    {
        bool has_pseudo_children(const elements_list& children)
        {
            for(const auto& child : children)
                if(child->tag() == __tag_before_ || child->tag() == __tag_after_)
                    return true;
            return false;
        }
    }

    bool document::rematch(const element::ptr& el, bool check, const string_map& attrs_before_change)
    {
        const rematch_state state = rematch_begin(el, check, attrs_before_change);
        auto                tag   = std::static_pointer_cast<html_tag>(el);
        elements_list children;
        children.swap(tag->m_children);
        const css* sheets[3] = {&m_master_css, &m_styles, &m_user_css};
        {
            // Telegram (VENDOR.md edit 31.5): :empty reads the children set aside, not the empty list matching sees.
            struct Aside
            {
                html_tag& tag;
                ~Aside() { tag.set_children_for_matching(nullptr); }
            } aside{*tag};
            tag->set_children_for_matching(&children);
            tag->apply_matching(sheets, m_match_epoch);
        }
        elements_list pseudo;
        pseudo.swap(tag->m_children);
        for(const auto& child : pseudo)
        {
            if(child->tag() == __tag_before_)
                children.push_front(child);
            else
                children.push_back(child);
        }
        tag->m_children.swap(children);
        return rematch_finish(state);
    }

    document::rematch_state document::rematch_begin(const element::ptr& el, bool check, const string_map& attrs_before_change)
    {
        auto          tag = std::static_pointer_cast<html_tag>(el);
        rematch_state state;
        // Telegram (VENDOR.md edit 84): the generated content before; what the match makes and drops is compared with it
        // at rematch_finish, not noted as it happens.
        state.generated_before = generated_fingerprint(*el);
        m_rematching++;
        state.el      = el;
        state.check   = check;
        state.counted = tag->counted(); // edit 78: read before the match forgets it
        // Telegram (VENDOR.md edit 91): the ::before and ::after forget_matched_styles drops below, kept so that a match
        // that changes nothing can put them back (take_back_generated).
        for(const auto& child : el->m_children)
        {
            if(child->tag() != __tag_before_ && child->tag() != __tag_after_)
                continue;
            state.generated_aside.push_back(child);
            if(const auto pseudo = std::dynamic_pointer_cast<html_tag>(child); pseudo && pseudo->reads_var())
                state.generated_reads_var = true;
        }
        state.neutral = check;
        if(state.neutral)
        {
            state.rules_before.reserve(el->m_used_styles.size());
            state.held_before.reserve(el->m_used_styles.size()); // Telegram (VENDOR.md edit 79)
            for(const auto& used : el->m_used_styles)
            {
                state.rules_before.emplace_back(used->m_selector.get(), used->m_used);
                state.held_before.push_back(used->m_selector);
            }
            std::sort(state.rules_before.begin(), state.rules_before.end());
            state.attrs_before = attrs_before_change;
        }
        // Telegram (VENDOR.md edit 17): an element declaring custom properties before or after may change what the var()s
        // below it read (commit_patch matches those again).
        if(tag->declares_custom_properties())
            note_custom_top(el);
        tag->forget_matched_styles();
        return state;
    }

    void document::rematch_pass(const rematch_state& state, int sheet)
    {
        const css* sheets[3] = {&m_master_css, &m_styles, &m_user_css};
        std::static_pointer_cast<html_tag>(state.el)->apply_matching_pass(*sheets[sheet], sheet);
    }

    bool document::rematch_finish(const rematch_state& state)
    {
        // Telegram (VENDOR.md edit 84): generated content the match made again equal changes nothing the cut reads.
        if(m_rematching > 0)
            m_rematching--;
        if(m_generated_watch && generated_fingerprint(*state.el) != state.generated_before)
            m_generated_changed = true;
        return rematch_settle(state);
    }

    bool document::rematch_settle(const rematch_state& state)
    {
        const element::ptr& el  = state.el;
        auto                tag = std::static_pointer_cast<html_tag>(el);
        const bool          check   = state.check;
        // Telegram (VENDOR.md edit 90): changed until the comparison below says otherwise.
        m_rematch_changed = true;
        m_patch_quiet.erase(el.get());
        auto used_rules = [&el]() {
            std::vector<std::pair<const css_selector*, bool>> rules;
            rules.reserve(el->m_used_styles.size());
            for(const auto& used : el->m_used_styles)
                rules.emplace_back(used->m_selector.get(), used->m_used);
            std::sort(rules.begin(), rules.end());
            return rules;
        };
        const auto&  rules_before = state.rules_before;
        string_map   attrs_before = state.attrs_before;
        if(tag->declares_custom_properties())
            note_custom_top(el); // edit 17
        // Telegram (VENDOR.md edit 78): a counted element matched again, before or after, changes what the counters count.
        if((state.counted || tag->counted()) && (selector_scope() & 4))
            m_patch_counters = true;
        // Telegram (VENDOR.md edit 73): why the tree cannot be kept, for rebuild_reason.
        if(!check)
        {
            m_retag_reason = std::string("element: ") + (el->get_tagName() ? el->get_tagName() : "");
            return false;
        }
        // Telegram (VENDOR.md edit 91): an element with a ::before or ::after before or after the match keeps its
        // render tree only when the match changes nothing and the old ones go back (below).
        const bool generated = !state.generated_aside.empty() || has_pseudo_children(el->m_children);
        const auto refuse    = [&](std::string reason) {
            m_retag_reason = generated ? std::string("pseudo-element children") : std::move(reason);
            return false;
        };
        attrs_before.erase("class");
        string_map attrs_after = tag->attributes();
        attrs_after.erase("class");
        // Telegram (VENDOR.md edit 27): an animated element's declarations change on every frame. A change of them keeps
        // the tree when every property it changes is paint-only, as a class change whose rules declare only those does.
        auto take_animated = [](string_map& attrs) {
            auto        it   = attrs.find(animated_style_attribute);
            std::string text = it == attrs.end() ? std::string() : it->second;
            if(it != attrs.end())
                attrs.erase(it);
            return text;
        };
        const std::string animated_before = take_animated(attrs_before);
        const std::string animated_after  = take_animated(attrs_after);
#if 0
        if(attrs_before != attrs_after)
            return false;
        const std::vector<std::string> animated = changed_declarations(animated_before, animated_after);
#else
        // Telegram (VENDOR.md edit 62): a script's inline style changes on every frame too (an rAF loop setting
        // el.style.transform), and keeps the tree on the same terms: its changed properties join the animated ones.
        auto take_style = [](string_map& attrs) {
            auto        it   = attrs.find("style");
            std::string text = it == attrs.end() ? std::string() : it->second;
            if(it != attrs.end())
                attrs.erase(it);
            return text;
        };
        const std::string style_before = take_style(attrs_before);
        const std::string style_after  = take_style(attrs_after);
        if(attrs_before != attrs_after)
            return refuse("attribute: " + first_changed_key(attrs_before, attrs_after)); // edit 73
        std::vector<std::string> animated = changed_declarations(animated_before, animated_after);
        for(auto& property : changed_declarations(style_before, style_after))
            animated.push_back(std::move(property));
#endif
        // Telegram (VENDOR.md edit 63): an inline element's geometry is its line's, which a kept tree does not lay out
        // again: only a box that is not inline keeps the tree for it.
        const bool geometry = el->css().get_display() != display_inline;
        for(const auto& property : animated)
        {
            // Telegram (VENDOR.md edit 63): or one only layout reads (the caller lays the document out again).
            if(!paint_only_property(property) && !(geometry && geometry_only_property(property)))
                return refuse("property: " + property); // edit 73
        }
        const auto                                        rules_after = used_rules();
        std::vector<std::pair<const css_selector*, bool>> changed;
        std::set_symmetric_difference(rules_before.begin(), rules_before.end(), rules_after.begin(), rules_after.end(),
                                      std::back_inserter(changed));
        // Telegram (VENDOR.md edit 73): every changed rule is looked at, so that rebuild_reason names the smallest property
        // that keeps the tree from being kept, whatever order the rules come in (`changed` is sorted by address).
        bool        kept_all = true;
        std::string offending;
        for(const auto& rule : changed)
        {
            if(!rule.first->m_style)
            {
                kept_all = false;
                continue;
            }
            rule.first->m_style->only_declares([geometry, &kept_all, &offending](string_id name) {
                const std::string& text     = _s(name);
                const std::string  property = text.compare(0, 8, "-lh-raw-") == 0 ? text.substr(8) : text;
                if(!paint_only_property(property) && !(geometry && geometry_only_property(property))) // edit 63
                {
                    kept_all = false;
                    if(offending.empty() || property < offending)
                        offending = property;
                }
                return true;
            });
        }
        if(!kept_all)
            return refuse(offending.empty() ? std::string("rule") : "rule: " + offending);
        // Telegram (VENDOR.md edit 91): the old ::before and ::after go back only when the match changed nothing.
        if(generated && (!changed.empty() || !animated.empty() || !take_back_generated(state)))
            return refuse("pseudo-element children");
        // Telegram (VENDOR.md edit 20): whether a rule that started or stopped matching decides paint order or a paint
        // group, which commit_patch tells the render observer.
        if(m_render_observer)
        {
            for(const auto& rule : changed)
            {
                const bool other = rule.first->m_style->only_declares([](string_id name) {
                    const std::string& text     = _s(name);
                    const std::string  property = text.compare(0, 8, "-lh-raw-") == 0 ? text.substr(8) : text;
                    return !paint_order_property(property);
                });
                if(!other)
                {
                    m_patch_paint_order.insert(el.get());
                    break;
                }
            }
            // Telegram (VENDOR.md edit 27): an animated property that decides paint order, as a rule's.
            if(std::any_of(animated.begin(), animated.end(), paint_order_property))
                m_patch_paint_order.insert(el.get());
        }
        m_rematch_changed = !changed.empty() || !animated.empty(); // Telegram (VENDOR.md edit 90)
        return true;
    }

    bool document::ids_selectable()
    {
        if(m_ids_selectable >= 0)
            return m_ids_selectable != 0;
        static const bool disabled = getenv("LH_NO_ID_SHARE") != nullptr;
        std::function<bool(const css_selector&)> sees_ids = [&](const css_selector& selector) {
            for(const css_selector* sel = &selector; sel; sel = sel->m_left.get())
            {
                for(const auto& attr : sel->m_right.m_attrs)
                {
                    if(attr.type == select_id || (attr.type == select_attr && t_strcasecmp(_s(attr.name).c_str(), "id") == 0))
                        return true;
                    for(const auto& inner : attr.selector_list)
                    {
                        if(inner && sees_ids(*inner))
                            return true;
                    }
                }
            }
            return false;
        };
        bool seen = disabled;
        for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
        {
            for(const auto& sel : sheet->selectors())
            {
                if(seen)
                    break;
                seen = sel && sees_ids(*sel);
            }
        }
        m_ids_selectable = seen ? 1 : 0;
        return seen;
    }

    bool document::style_sharing_enabled() const
    {
        static const bool enabled = getenv("LH_NO_STYLE_SHARING") == nullptr;
        return enabled;
    }

    void document::set_document_mode(document_mode mode)
    {
        m_mode = mode;
    }

    // Telegram (VENDOR.md edit 79): the master sheet parsed as finalize parses it, through its cache, under the
    // container's environment as it is now.
    css document::parsed_master(const std::string& master_styles)
    {
        css parsed;
        static std::mutex&                           master_cache_mutex = *new std::mutex;
        static std::unordered_map<std::string, css>& master_cache = *new std::unordered_map<std::string, css>;
        const bool                                  cacheable =
            master_styles.find("@media") == std::string::npos && master_styles.find("@import") == std::string::npos;
        bool hit = false;
        // Telegram (VENDOR.md edit 13): light-dark() resolves at parse, so the cache is keyed by the scheme too.
        media_features scheme_media;
        container()->get_media_features(scheme_media);
#if 0
        const std::string master_key =
            std::string(scheme_media.color_scheme ? "\x03" : "\x02") + master_styles;
#else
        // Telegram (VENDOR.md edit 29.7): and by the container's sanitizer key.
        const uint32_t    master_sanitizer = container()->sanitizer_key();
        const std::string master_key       = std::string(scheme_media.color_scheme ? "\x03" : "\x02") +
                                       std::string(reinterpret_cast<const char*>(&master_sanitizer), sizeof master_sanitizer) +
                                       master_styles + environment_key(master_styles); // edit 79
#endif
        if(cacheable)
        {
            std::lock_guard<std::mutex> lock(master_cache_mutex);
#if 0
            auto                        it = master_cache.find(master_styles);
#else
            auto                        it = master_cache.find(master_key); // Telegram (VENDOR.md edit 13)
#endif
            if(it != master_cache.end())
            {
                parsed = it->second;
                hit    = true;
            }
        }
        if(!hit)
        {
            container()->trusted_styles(true);
            parsed.set_layered_origins(true); // Telegram (VENDOR.md edit 41)
            parsed.parse_css_stylesheet(master_styles, "", shared_from_this());
            container()->trusted_styles(false);
            parsed.sort_selectors();
            if(cacheable)
            {
                std::lock_guard<std::mutex> lock(master_cache_mutex);
                if(master_cache.size() > 64)
                    master_cache.clear();
#if 0
                master_cache.emplace(master_styles, parsed);
#else
                master_cache.emplace(master_key, parsed); // Telegram (VENDOR.md edit 13): keyed by the scheme
#endif
            }
        }
        return parsed;
    }

    // Telegram (VENDOR.md edit 79): the document's sheets (m_css) parsed as finalize parses them, through their cache,
    // under the container's environment as it is now.
    css document::parsed_author()
    {
        css            parsed;
        media_features scheme_media;
        container()->get_media_features(scheme_media);
        // Parsed and sorted document stylesheets are immutable, so documents built from the same
        // <style> text share one parse. Media and imports register per-document state while parsing,
        // so sheets that use them are parsed every time.
        static std::mutex&                           styles_cache_mutex = *new std::mutex;
        static std::unordered_map<std::string, css>& styles_cache = *new std::unordered_map<std::string, css>;
        std::string                                 styles_key;
        bool                                        styles_cacheable = !m_css.empty();
        for(const auto& css : m_css)
        {
            if(css.media != "" || css.text.find("@media") != std::string::npos || css.text.find("@import") != std::string::npos)
            {
                styles_cacheable = false;
                break;
            }
        }
        bool styles_hit = false;
        if(styles_cacheable)
        {
            styles_key.push_back(static_cast<char>('0' + static_cast<int>(m_mode)));
            // Telegram (VENDOR.md edit 13): keyed by the container's scheme too.
            styles_key.push_back(scheme_media.color_scheme ? '\x03' : '\x02');
            // Telegram (VENDOR.md edit 29.7): and by the container's sanitizer key.
            {
                const uint32_t sanitizer = container()->sanitizer_key();
                styles_key.append(reinterpret_cast<const char*>(&sanitizer), sizeof sanitizer);
            }
            for(const auto& css : m_css)
            {
                styles_key.append(css.baseurl);
                styles_key.push_back('\x1e');
                styles_key.append(css.text);
                styles_key.append(environment_key(css.text)); // edit 79
                styles_key.push_back('\x1f');
            }
            std::lock_guard<std::mutex> lock(styles_cache_mutex);
            auto                        it = styles_cache.find(styles_key);
            if(it != styles_cache.end())
            {
                parsed     = it->second;
                styles_hit = true;
            }
        }
        if(!styles_hit)
        {
            // parse style sheets linked in document
            for(const auto& css : m_css)
            {
                media_query_list_list::ptr media;
                if(css.media != "")
                {
                    // Telegram (VENDOR.md edit 29.3): a <style media> the container refuses is not applied.
                    if(!container()->sanitize_media_query(normalize(css.media, f_componentize)))
                    {
                        parsed.end_sheet(); // Telegram (VENDOR.md edit 81)
                        continue;
                    }
                    auto mq_list = parse_media_query_list(css.media, shared_from_this());
                    media        = std::make_shared<media_query_list_list>();
                    media->add(mq_list);
                }
                parsed.parse_css_stylesheet(css.text, css.baseurl, shared_from_this(), media);
                parsed.end_sheet(); // Telegram (VENDOR.md edit 81)
            }
            // Sort css selectors using CSS rules.
            parsed.sort_selectors();
            if(styles_cacheable)
            {
                std::lock_guard<std::mutex> lock(styles_cache_mutex);
                if(styles_cache.size() > 128)
                    styles_cache.clear();
                styles_cache.emplace(std::move(styles_key), parsed);
            }
        }

        return parsed;
    }

    // Telegram (VENDOR.md edit 79): viewport units fold to pixels at parse (edit 11), so a text that may hold one is
    // cached per viewport.
    std::string document::environment_key(const std::string& text) const
    {
        if(!text_may_hold_viewport_unit(text))
            return std::string();
        media_features media;
        m_container->get_media_features(media);
        return "\x04" + std::to_string(media.width.value()) + "x" + std::to_string(media.height.value());
    }

    void document::finalize_from_external_root(const std::shared_ptr<element>& root, const std::string& base_master_styles,
                                               const std::string& user_styles)
    {
        invalidate_paint();
        // Finalization accumulates state that is never rolled back: the parsed stylesheets, the media
        // lists, the tabular elements, the render tree, and the used selectors of every element. A
        // second run would duplicate all of it, so a document is finalized once, exactly like a parsed
        // one. Build a new document to rebuild.
        if(m_finalized)
        {
            return;
        }
        m_finalized = true;

        m_root = root;

        const std::string master_styles =
            m_mode == quirks_mode && base_master_styles != ""
                ? base_master_styles + "\ntable { font-size: medium; font-weight: normal; font-style: normal; }\n"
                : base_master_styles;
        // Telegram (VENDOR.md edit 79): kept, to be parsed again under a new environment.
        m_master_styles = master_styles;
        if(master_styles != "")
            m_master_css = parsed_master(master_styles);
        if(user_styles != "")
        {
            container()->trusted_styles(true);
            m_user_css.parse_css_stylesheet(user_styles, "", shared_from_this());
            container()->trusted_styles(false);
            m_user_css.sort_selectors();
        }

        // Let's process created elements tree
        if(m_root)
        {
            container()->get_media_features(m_media);

            m_root->set_pseudo_class(_root_, true);
            count_master_content_owners(); // Telegram (VENDOR.md edit 84)

            // Telegram (VENDOR.md edit 18): the caller's matching gate, asked before the master sheet's pass with its rule
            // count and a bound of the elements it tests them against; declined, nothing is matched and the document is
            // left unfinished.
            if(m_matching_gate &&
               !m_matching_gate(m_master_css.selectors().size(), matching_bound(m_root, pseudo_element_creators({&m_master_css}))))
            {
                m_matching_gated = true;
                return;
            }

            // Telegram (VENDOR.md edit 84): the limits the style pass reaches, in order, and its content's transients.
            m_style_pass_limits.clear();
            m_recording_style_pass = true;
            m_generated_transient  = 0;
            // apply master CSS
            m_root->apply_stylesheet(m_master_css);

            // parse elements attributes
            m_root->parse_attributes();

            m_styles        = parsed_author(); // Telegram (VENDOR.md edit 79)
            m_sheets_parsed = true;            // Telegram (VENDOR.md edit 81)

            // Apply media features.
            update_media_lists(m_media);

            // Telegram (VENDOR.md edit 18): the gate again, before the author and host sheets' passes.
            if(m_matching_gate && !m_matching_gate(m_styles.selectors().size() + m_user_css.selectors().size(),
                                                   matching_bound(m_root, pseudo_element_creators())))
            {
                m_matching_gated = true;
                return;
            }

            m_style_rule_bytes = -1; // Telegram (VENDOR.md edit 21): the sheets are parsed
            // Apply parsed styles.
            m_root->apply_stylesheet(m_styles);

            // Apply user styles if any
            m_root->apply_stylesheet(m_user_css);
            m_recording_style_pass = false; // Telegram (VENDOR.md edit 84)

            // Initialize element::m_css
            m_root->compute_styles();

            // Create rendering tree
            m_table_cells = 0;
            m_observed.clear();   // Telegram (VENDOR.md edit 20): a build's render tree is reported by no one
            m_root_render = m_root->create_render_item(nullptr);
            m_render_tree_serial++;
            m_layout_marked.clear();
            m_relayout_roots.clear();
            m_layout_before_valid = false;

            // Now the m_tabular_elements is filled with tabular elements.
            // We have to check the tabular elements for missing table elements
            // and create the anonymous boxes in visual table layout
            fix_tables_layout();

            // Finally initialize elements
            // init() returns pointer to the render_init element because it can change its type
            if(m_root_render)
            {
                m_root_render = m_root_render->init();
            }
        }
    }

    // https://html.spec.whatwg.org/multipage/parsing.html#change-the-encoding
    encoding adjust_meta_encoding(encoding meta_encoding, encoding current_encoding)
    {
        // 1.
        if(current_encoding == encoding::utf_16le || current_encoding == encoding::utf_16be)
        {
            return current_encoding;
        }

        // 2.
        if(meta_encoding == encoding::utf_16le || meta_encoding == encoding::utf_16be)
        {
            return encoding::utf_8;
        }

        // 3.
        if(meta_encoding == encoding::x_user_defined)
        {
            return encoding::windows_1252;
        }

        // 4,5,6.
        return meta_encoding;
    }

    // https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inhead:change-the-encoding
    encoding get_meta_encoding(GumboNode* root)
    {
        // find <head>
        GumboNode* head = nullptr;
        for(size_t i = 0; i < root->v.element.children.length; i++)
        {
            auto* node = static_cast<GumboNode*>(root->v.element.children.data[i]);
            if(node->type == GUMBO_NODE_ELEMENT && node->v.element.tag == GUMBO_TAG_HEAD)
            {
                head = node;
                break;
            }
        }
        if(!head)
        {
            return encoding::null;
        }

        // go through <meta> tags in <head>
        for(size_t i = 0; i < head->v.element.children.length; i++)
        {
            auto* node = static_cast<GumboNode*>(head->v.element.children.data[i]);
            if(node->type != GUMBO_NODE_ELEMENT || node->v.element.tag != GUMBO_TAG_META)
            {
                continue;
            }

            auto* charset    = gumbo_get_attribute(&node->v.element.attributes, "charset");
            auto* http_equiv = gumbo_get_attribute(&node->v.element.attributes, "http-equiv");
            auto* content    = gumbo_get_attribute(&node->v.element.attributes, "content");
            // 1. If the element has a charset attribute...
            if(charset)
            {
                auto encoding = get_encoding(charset->value);
                if(encoding != encoding::null)
                {
                    return encoding;
                }
            }
            // 2. Otherwise, if the element has an http-equiv attribute...
            else if(http_equiv && t_strcasecmp(http_equiv->value, "content-type") == 0 && content)
            {
                auto encoding = extract_encoding_from_meta_element(content->value);
                if(encoding != encoding::null)
                {
                    return encoding;
                }
            }
        }

        return encoding::null;
    }

    // substitute for gumbo_parse that handles encodings
    GumboOutput* document::parse_html(estring str)
    {
        // https://html.spec.whatwg.org/multipage/parsing.html#the-input-byte-stream
        encoding_sniffing_algorithm(str);
        // cannot store output in local variable because gumbo keeps pointers into it,
        // which will be accessed later in gumbo_tag_from_original_text
        if(str.encoding == encoding::utf_8)
        {
            m_text = str;
        } else
        {
            decode(str, str.encoding, m_text);
        }

        // Gumbo does not support callbacks on node creation, so we cannot change encoding while parsing.
        // Instead, we parse entire file and then handle <meta> tags.

        // Using gumbo_parse_with_options to pass string length (m_text may contain NUL chars).
        GumboOutput* output = gumbo_parse_with_options(&kGumboDefaultOptions, m_text.data(), m_text.size());

        if(str.confidence == confidence::certain)
        {
            return output;
        }

        // Otherwise: confidence is tentative.

        // If valid HTML encoding is specified in <meta> tag...
        encoding meta_encoding = get_meta_encoding(output->root);
        if(meta_encoding != encoding::null)
        {
            // ...and it is different from currently used encoding...
            encoding new_encoding = adjust_meta_encoding(meta_encoding, str.encoding);
            if(new_encoding != str.encoding)
            {
                // ...reparse with the new encoding.
                gumbo_destroy_output(&kGumboDefaultOptions, output);
                m_text.clear();

                if(new_encoding == encoding::utf_8)
                {
                    m_text = str;
                } else
                {
                    decode(str, new_encoding, m_text);
                }
                output = gumbo_parse_with_options(&kGumboDefaultOptions, m_text.data(), m_text.size());
            }
        }

        return output;
    }

    void document::create_node(void* gnode, elements_list& elements, bool parseTextNode, bool process_root)
    {
        auto* node = static_cast<GumboNode*>(gnode);
        switch(node->type)
        {
        case GUMBO_NODE_ELEMENT:
            {
                if(process_root)
                {
                    string_map      attrs;
                    GumboAttribute* attr = nullptr;
                    for(unsigned int i = 0; i < node->v.element.attributes.length; i++)
                    {
                        attr              = static_cast<GumboAttribute*>(node->v.element.attributes.data[i]);
                        attrs[attr->name] = attr->value;
                    }

                    element::ptr ret;
                    const char*  tag = gumbo_normalized_tagname(node->v.element.tag);
                    std::string  name;
                    if(tag[0])
                    {
                        name = tag;
                    } else if(node->v.element.original_tag.data && node->v.element.original_tag.length)
                    {
                        gumbo_tag_from_original_text(&node->v.element.original_tag);
                        name.assign(node->v.element.original_tag.data, node->v.element.original_tag.length);
                    }
                    if(!name.empty())
                    {
                        if(m_build_depth >= max_build_depth || m_build_elements >= max_build_elements)
                        {
                            m_container->sanitizer_limit(m_build_depth >= max_build_depth ? "depth" : "elements");
                            m_build_limited = true;
                            break;
                        }
                        if(!m_container->sanitize_element(name, node->v.element.tag_namespace == GUMBO_NAMESPACE_SVG, attrs))
                        {
                            break;
                        }
                        ret = create_element(name.c_str(), attrs);
                        m_build_elements++;
                    }
                    if(!strcmp(tag, "script"))
                    {
                        parseTextNode = false;
                    }
                    if(ret)
                    {
                        elements_list child;
                        m_build_depth++;
                        for(unsigned int i = 0; i < node->v.element.children.length; i++)
                        {
                            child.clear();
                            create_node(static_cast<GumboNode*>(node->v.element.children.data[i]), child, parseTextNode,
                                        true);
                            std::for_each(child.begin(), child.end(),
                                          [&ret](element::ptr& el) { ret->appendChild(el); });
                        }
                        m_build_depth--;
                        elements.push_back(ret);
                    }
                } else
                {
                    for(unsigned int i = 0; i < node->v.element.children.length; i++)
                    {
                        create_node(static_cast<GumboNode*>(node->v.element.children.data[i]), elements, parseTextNode,
                                    true);
                    }
                }
            }
            break;
        case GUMBO_NODE_TEXT:
            {
                const size_t before = elements.size();
                if(!parseTextNode)
                {
                    // Telegram (VENDOR.md edit 10): no text piece past the cap.
                    if(!text_element_allowed())
                        m_build_limited = true;
                    else
                    elements.push_back(std::make_shared<el_text>(node->v.text.text, shared_from_this()));
                } else
                {
                    m_container->split_text(
                        node->v.text.text,
                        [this, &elements](const char* text) {
                            if(!text_element_allowed())
                                m_build_limited = true;
                            else
                            elements.push_back(std::make_shared<el_text>(text, shared_from_this()));
                        },
                        [this, &elements](const char* text) {
                            if(!text_element_allowed())
                                m_build_limited = true;
                            else
                            elements.push_back(std::make_shared<el_space>(text, shared_from_this()));
                        });
                }
            }
            break;
        case GUMBO_NODE_CDATA:
            {
                element::ptr ret = std::make_shared<el_cdata>(shared_from_this());
                ret->set_data(node->v.text.text);
                elements.push_back(ret);
            }
            break;
        case GUMBO_NODE_COMMENT:
            {
                element::ptr ret = std::make_shared<el_comment>(shared_from_this());
                ret->set_data(node->v.text.text);
                elements.push_back(ret);
            }
            break;
        case GUMBO_NODE_WHITESPACE:
            {
                std::string str = node->v.text.text;
                for(size_t i = 0; i < str.length(); i++)
                {
                    // Telegram (VENDOR.md edit 10): no text piece past the cap.
                    if(!text_element_allowed())
                    {
                        m_build_limited = true;
                        break;
                    }
                    elements.push_back(std::make_shared<el_space>(str.substr(i, 1).c_str(), shared_from_this()));
                }
            }
            break;
        default:
            break;
        }
    }

    element::ptr document::create_element(const char* tag_name, const string_map& attributes)
    {
        element::ptr  newTag;
        document::ptr this_doc = shared_from_this();
        if(m_container)
        {
            newTag = m_container->create_element(tag_name, attributes, this_doc);
        }
        if(!newTag)
        {
            if(!strcmp(tag_name, "br"))
            {
                newTag = std::make_shared<el_break>(this_doc);
            } else if(!strcmp(tag_name, "p"))
            {
                newTag = std::make_shared<el_para>(this_doc);
            } else if(!strcmp(tag_name, "img") || !strcmp(tag_name, "canvas"))
            {
                newTag = std::make_shared<el_image>(this_doc);
            } else if(!strcmp(tag_name, "table"))
            {
                newTag = std::make_shared<el_table>(this_doc);
            } else if(!strcmp(tag_name, "td") || !strcmp(tag_name, "th"))
            {
                newTag = std::make_shared<el_td>(this_doc);
            } else if(!strcmp(tag_name, "link"))
            {
                newTag = std::make_shared<el_link>(this_doc);
            } else if(!strcmp(tag_name, "title"))
            {
                newTag = std::make_shared<el_title>(this_doc);
            } else if(!strcmp(tag_name, "a"))
            {
                newTag = std::make_shared<el_anchor>(this_doc);
            } else if(!strcmp(tag_name, "tr"))
            {
                newTag = std::make_shared<el_tr>(this_doc);
            } else if(!strcmp(tag_name, "style"))
            {
                newTag = std::make_shared<el_style>(this_doc);
            } else if(!strcmp(tag_name, "base"))
            {
                newTag = std::make_shared<el_base>(this_doc);
            } else if(!strcmp(tag_name, "body"))
            {
                newTag = std::make_shared<el_body>(this_doc);
            } else if(!strcmp(tag_name, "div"))
            {
                newTag = std::make_shared<el_div>(this_doc);
            } else if(!strcmp(tag_name, "script"))
            {
                newTag = std::make_shared<el_script>(this_doc);
            } else if(!strcmp(tag_name, "font"))
            {
                newTag = std::make_shared<el_font>(this_doc);
            } else if(!strcmp(tag_name, "svg"))
            {
                newTag = std::make_shared<el_svg>(this_doc);
            } else if(!strcmp(tag_name, "input"))
            {
                newTag = std::make_shared<el_input>(this_doc);
            } else if(!strcmp(tag_name, "select"))
            {
                newTag = std::make_shared<el_select>(this_doc);
            } else if(!strcmp(tag_name, "button"))
            {
                newTag = std::make_shared<el_button>(this_doc);
            } else if(!strcmp(tag_name, "textarea"))
            {
                newTag = std::make_shared<el_textarea>(this_doc);
            } else if(!strcmp(tag_name, "fieldset"))
            {
                newTag = std::make_shared<el_fieldset>(this_doc);
            } else if(!strcmp(tag_name, "progress") || !strcmp(tag_name, "meter"))
            {
                newTag = std::make_shared<el_meter>(this_doc);
            } else
            {
                newTag = std::make_shared<html_tag>(this_doc);
            }
        }

        if(newTag)
        {
            newTag->set_tagName(tag_name);
            for(const auto& attribute : attributes)
            {
                newTag->set_attr(attribute.first.c_str(), attribute.second.c_str());
            }
        }

        return newTag;
    }

    uint_ptr document::add_font(const font_description& descr, font_metrics* fm)
    {
        uint_ptr ret = 0;

        std::string key = descr.hash();

        if(m_fonts.find(key) == m_fonts.end())
        {
            font_item fi = {0, {}};

            fi.font      = m_container->create_font(descr, this, &fi.metrics);
            m_fonts[key] = fi;
            ret          = fi.font;
            if(fm)
            {
                *fm = fi.metrics;
            }
        }
        return ret;
    }

    uint_ptr document::get_font(const font_description& descr, font_metrics* fm)
    {
        if(descr.size == 0_px)
        {
            // Telegram (VENDOR.md edit 18): no font has no metrics. Left as they were, an element restyled to font-size 0
            // (an attribute patch, edit 17) kept its old line height where a fresh one has none.
            if(fm)
                *fm = font_metrics();
            return 0;
        }

        auto key = descr.hash();

        auto el = m_fonts.find(key);

        if(el != m_fonts.end())
        {
            if(fm)
            {
                *fm = el->second.metrics;
            }
            return el->second.font;
        }
        return add_font(descr, fm);
    }

    std::atomic<uint64_t> document::s_layout_hits{0};
    std::atomic<uint64_t> document::s_layout_misses{0};
    std::atomic<uint64_t> document::s_layout_mismatches{0};

    bool document::layout_cache_enabled() const
    {
        static const bool disabled = getenv("LH_NO_LAYOUT_CACHE") != nullptr;
        return !disabled;
    }

    bool document::layout_cache_check() const
    {
        static const bool check = getenv("LH_LAYOUT_CACHE_CHECK") != nullptr;
        return check;
    }

    namespace
    {
        template <class F> void walk_boxes(render_item* item, float x, float y, bool unsafe, F&& visit)
        {
            const css_properties& css = item->src_el()->css();
            unsafe = unsafe || css.get_position() == element_position_absolute || css.get_position() == element_position_fixed ||
                     css.is_paint_group();
            const position& pos = item->pos_const();
            visit(item, x, y, unsafe);
            unsafe = unsafe || !css.get_transform().empty() || is_one_of(css.get_overflow(), overflow_scroll, overflow_auto);
            const float cx = x + pos.x.value();
            const float cy = y + pos.y.value();
            for(const auto& child : item->children())
                walk_boxes(child.get(), cx, cy, unsafe, visit);
        }

    }

    void document::snapshot_layout()
    {
        m_layout_before.clear();
        m_layout_before.reserve(m_layout_before.capacity());
        walk_boxes(m_root_render.get(), 0, 0, false, [this](const render_item* item, float x, float y, bool) {
            position box  = item->pos_const();
            box.x        += pixel_t(x);
            box.y        += pixel_t(y);
            m_layout_before.push_back({item, box});
        });
        m_layout_before_valid = true;
    }

    pixel_t document::render(pixel_t max_width, render_type rt)
    {
        invalidate_paint();
        pixel_t ret = 0_px;
        if(m_root && m_root_render)
        {
            position viewport;
            m_container->get_viewport(viewport);
            if(!(viewport == m_layout_viewport))
            {
                m_layout_viewport = viewport;
                invalidate_layout_cache();
            }
            m_layout_marked.clear();
            containing_block_context cb_context;
            cb_context.width       = max_width;
            cb_context.width.type  = containing_block_context::cbc_value_type_absolute;
            cb_context.height      = viewport.height;
            cb_context.height.type = containing_block_context::cbc_value_type_absolute;

            if(rt == render_fixed_only)
            {
                m_fixed_boxes.clear();
                m_root_render->render_positioned(rt);
            } else
            {
                static const bool refetch = getenv("LH_NO_POSITIONED_REUSE") != nullptr;
                if(refetch || m_positioned_epoch != m_style_epoch || m_positioned_tree != m_render_tree_serial)
                {
                    m_has_positioned   = m_root_render->fetch_positioned();
                    m_positioned_epoch = m_style_epoch;
                    m_positioned_tree  = m_render_tree_serial;
                }
                ret = m_root_render->render(0_px, 0_px, cb_context, nullptr).natural_width;
                for(render_item* item : m_relayout_roots)
                    item->relayout();
                m_relayout_roots.clear();
                m_layout_after_render = true;
                if(m_has_positioned)
                {
                    m_fixed_boxes.clear();
                    m_root_render->render_positioned(rt);
                }
                m_size.width  = 0;
                m_size.height = 0;
                m_root_render->calc_document_size(m_size);
                m_replaced_hold.clear(); // Telegram (VENDOR.md edit 74): the layout let go of the replaced items
            }
        }
        // Telegram (VENDOR.md edit 20): the boxes this layout changed, each against what it was before.
        if(m_render_observer)
            report_observed_geometry();
        return ret;
    }

    // Telegram (VENDOR.md edit 20): the render observer.
    void document::set_render_observer(render_observer* observer)
    {
        m_render_observer = observer;
        m_observed.clear();
        m_patch_paint_order.clear();
        m_observe_epoch = m_observe_epoch + 1 == 0 ? 1 : m_observe_epoch + 1;
    }

    void document::report_observed_geometry()
    {
        std::vector<render_item*> items;
        items.swap(m_observed);
        // The next layout's first writes save again.
        m_observe_epoch = m_observe_epoch + 1 == 0 ? 1 : m_observe_epoch + 1;
        for(render_item* item : items)
        {
            const unsigned what = item->observed_change();
            if(what && m_render_observer)
                m_render_observer->item_geometry_changed(item, what);
        }
    }

    void document::draw(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip, bool cull)
    {
        if(m_root && m_root_render)
        {
            const bool saved = m_cull_paint;
            m_cull_paint     = cull && clip && !g_paint_trace;
            if(!m_root->css().get_clip_path().empty())
            {
                m_root_render->draw_group(hdc, x, y, clip, m_root_render);
            } else
            {
#if 0
                m_root->draw(hdc, x, y, clip, m_root_render);
#else
                paint_or_visit(m_root_render, draw_root, hdc, x, y, clip);   // Telegram (VENDOR.md edit 20)
#endif
                m_root_render->draw_stacking_context(hdc, x, y, clip, true);
            }
            m_cull_paint = saved;
        }
    }

    pixel_t document::to_pixels(const css_length& val, const font_metrics& metrics, pixel_t size) const
    {
        if(val.is_predefined())
        {
            return 0_px;
        }
        // Telegram (VENDOR.md edit 48): a calc at `size`, its font-relative terms by `metrics`.
        if(val.is_calc())
        {
            return val.calc_value(size, calc_fonts_for(metrics));
        }
        // Telegram: viewport_changed() computes styles again only for a document that resolved a viewport unit.
        if(val.units() == css_units_vw || val.units() == css_units_vh || val.units() == css_units_vmin || val.units() == css_units_vmax)
            m_viewport_units = true;
        pixel_t ret;
        switch(val.units())
        {
        case css_units_percentage:
            ret = val.calc_percent(size);
            break;
        case css_units_em:
            ret = metrics.font_size * val.val();
            break;

        // https://drafts.csswg.org/css-values-4/#absolute-lengths
        case css_units_pt:
            ret = m_container->pt_to_px(val.val());
            break;
        case css_units_in:
            ret = m_container->pt_to_px(val.val() * 72); // 1in = 72pt
            break;
        case css_units_pc:
            ret = m_container->pt_to_px(val.val() * 12); // 1pc = (1/6)in = 12pt
            break;
        case css_units_cm:
            ret = m_container->pt_to_px(val.val() * 72 / 2.54f); // 1cm = (1/2.54)in = (72/2.54)pt
            break;
        case css_units_mm:
            ret = m_container->pt_to_px(val.val() * 72 / 2.54f / 10);
            break;

        case css_units_vw:
            ret = pixel_t(m_media.width.value() * val.val() / 100.0f);
            break;
        case css_units_vh:
            ret = pixel_t(m_media.height.value() * val.val() / 100.0f);
            break;
        case css_units_vmin:
            ret = pixel_t(std::min(m_media.height.value(), m_media.width.value()) * val.val() / 100.0f);
            break;
        case css_units_vmax:
            ret = pixel_t(std::max(m_media.height.value(), m_media.width.value()) * val.val() / 100.0f);
            break;
        case css_units_rem:
            ret = pixel_t(m_root->css().get_font_size().value() * val.val());
            break;
        case css_units_ex:
            ret = pixel_t(metrics.x_height.value() * val.val());
            break;
        case css_units_ch:
            ret = pixel_t(metrics.ch_width.value() * val.val());
            break;
        default:
            ret = pixel_t(val.val());
            break;
        }
        return ret;
    }

    // Telegram (VENDOR.md edit 48).
    calc_fonts document::calc_fonts_for(const font_metrics& metrics) const
    {
        calc_fonts fonts;
        fonts.em  = double(metrics.font_size);
        fonts.rem = m_root ? double(m_root->css().get_font_size().value()) : double(metrics.font_size);
        fonts.ex  = double(metrics.x_height.value());
        fonts.ch  = double(metrics.ch_width.value());
        return fonts;
    }

    void document::cvt_units(css_length& val, const font_metrics& metrics, pixel_t size) const
    {
        if(val.is_predefined())
        {
            return;
        }
        // Telegram (VENDOR.md edit 48): font-relative terms fold into px now; a calc left without a percentage is a
        // plain px length, and one with a percentage stays deferred to layout (calc_percent).
        if(val.is_calc())
        {
            const calc_fonts fonts  = calc_fonts_for(metrics);
            calc_ref         folded = calc_node::fold_fonts(val.calc(), fonts);
            if(!folded->has_percent())
                val.set_value(float(folded->eval(0, fonts)), css_units_px);
            else
                val.set_calc(std::move(folded));
            return;
        }
        if(val.units() != css_units_percentage)
        {
            val.set_value(static_cast<float>(to_pixels(val, metrics, size)), css_units_px);
        }
    }

    pixel_t document::width() const
    {
        return m_size.width;
    }

    pixel_t document::height() const
    {
        return m_size.height;
    }

    void document::add_stylesheet(const char* str, const char* baseurl, const char* media)
    {
        // Telegram (VENDOR.md edit 81): once finalize has parsed the sheets, apply_sheets reads them from the tree (a
        // <style> a patch inserts is parsed by its parse_attributes too).
        if(str && str[0] && !m_sheets_parsed)
        {
            m_style_rule_bytes = -1; // Telegram (VENDOR.md edit 21)
            m_css.emplace_back(str, baseurl, media);
        }
    }

    bool document::on_mouse_over(pixel_t x, pixel_t y, pixel_t client_x, pixel_t client_y,
                                 const std::function<void(const position&)>& redraw_box)
    {
        invalidate_paint();
        if(!m_root || !m_root_render)
        {
            return false;
        }

        element::ptr over_el = m_root_render->get_element_by_point(x, y, client_x, client_y, nullptr);

        bool state_was_changed = false;

        if(over_el != m_over_element)
        {
            if(m_over_element)
            {
                if(m_over_element->on_mouse_leave())
                {
                    m_container->on_mouse_event(m_over_element, mouse_event_leave);
                    state_was_changed = true;
                }
            }
            m_over_element = over_el;
        }

        std::string cursor;

        if(m_over_element)
        {
            if(m_over_element->on_mouse_over())
            {
                state_was_changed = true;
            }
            cursor = m_over_element->css().get_cursor();
        }

        m_container->set_cursor(cursor.c_str());

        if(state_was_changed)
        {
            m_container->on_mouse_event(m_over_element, mouse_event_enter);
            return m_root->find_styles_changes(redraw_box);
        }
        return false;
    }

    std::vector<scroll_values> document::on_scroll(pixel_t dx, pixel_t dy, pixel_t x, pixel_t y, pixel_t client_x,
                                                   pixel_t client_y) const
    {
        invalidate_paint();
        if(dy == 0_px && dx == 0_px)
        {
            return {};
        }

        element::ptr vscroll_el;
        element::ptr hscroll_el;

        if(dy != 0_px)
        {
            vscroll_el = m_root_render->get_element_by_point(
                x, y, client_x, client_y,
                [dy](const std::shared_ptr<render_item>& el) -> bool { return el->is_v_scrollable(dy); });
        }

        if(dx != 0_px)
        {
            hscroll_el = m_root_render->get_element_by_point(
                x, y, client_x, client_y,
                [dx](const std::shared_ptr<render_item>& el) -> bool { return el->is_h_scrollable(dx); });
        }

        if(!vscroll_el && !hscroll_el)
        {
            return {};
        }

        if(vscroll_el == hscroll_el)
        {
            scroll_values sv;
            sv.dx         = hscroll_el->h_scroll(dx);
            sv.dy         = vscroll_el->v_scroll(dy);
            sv.scroll_box = hscroll_el->get_placement();
            return {sv};
        }

        std::vector<scroll_values> ret;
        ret.reserve(2);

        if(vscroll_el)
        {
            scroll_values sv;
            sv.dy         = vscroll_el->v_scroll(dy);
            sv.scroll_box = vscroll_el->get_placement();
            ret.push_back(sv);
        }

        if(hscroll_el)
        {
            scroll_values sv;
            sv.dx         = hscroll_el->h_scroll(dx);
            sv.scroll_box = hscroll_el->get_placement();
            ret.push_back(sv);
        }

        return ret;
    }

    bool document::on_mouse_leave(const std::function<void(const position&)>& redraw_box)
    {
        invalidate_paint();
        if(!m_root || !m_root_render)
        {
            return false;
        }
        if(m_over_element)
        {
            auto el        = m_over_element;
            m_over_element = nullptr;
            if(el->on_mouse_leave())
            {
                m_container->on_mouse_event(el, mouse_event_leave);
                return m_root->find_styles_changes(redraw_box);
            }
        }
        return false;
    }

    bool document::on_lbutton_down(pixel_t x, pixel_t y, pixel_t client_x, pixel_t client_y,
                                   const std::function<void(const position&)>& redraw_box)
    {
        invalidate_paint();
        if(!m_root || !m_root_render)
        {
            return false;
        }

        element::ptr over_el = m_root_render->get_element_by_point(x, y, client_x, client_y, nullptr);
        m_active_element     = over_el;

        bool state_was_changed = false;

        if(over_el != m_over_element)
        {
            if(m_over_element)
            {
                if(m_over_element->on_mouse_leave())
                {
                    m_container->on_mouse_event(m_over_element, mouse_event_leave);
                    state_was_changed = true;
                }
            }
            m_over_element = over_el;
            if(m_over_element)
            {
                if(m_over_element->on_mouse_over())
                {
                    state_was_changed = true;
                }
            }
        }

        std::string cursor;

        if(m_over_element)
        {
            if(m_over_element->on_lbutton_down())
            {
                state_was_changed = true;
            }
            cursor = m_over_element->css().get_cursor();
        }

        m_container->set_cursor(cursor.c_str());

        if(state_was_changed)
        {
            m_container->on_mouse_event(m_over_element, mouse_event_enter);
            return m_root->find_styles_changes(redraw_box);
        }

        return false;
    }

    bool document::on_lbutton_up(pixel_t /*x*/, pixel_t /*y*/, pixel_t /*client_x*/, pixel_t /*client_y*/,
                                 const std::function<void(const position&)>& redraw_box)
    {
        invalidate_paint();
        if(!m_root || !m_root_render)
        {
            return false;
        }
        if(m_over_element)
        {
            if(m_over_element->on_lbutton_up(m_active_element == m_over_element))
            {
                return m_root->find_styles_changes(redraw_box);
            }
        }
        return false;
    }

    bool document::on_button_cancel(const std::function<void(const position&)>& redraw_box)
    {
        invalidate_paint();
        m_active_element = nullptr;
        return on_mouse_leave(redraw_box);
    }

    void document::get_fixed_boxes(position::vector& fixed_boxes)
    {
        fixed_boxes = m_fixed_boxes;
    }

    void document::add_fixed_box(const position& pos)
    {
        m_fixed_boxes.push_back(pos);
    }

    bool document::media_changed()
    {
        invalidate_paint();
        container()->get_media_features(m_media);
        m_rebuild_reason.clear(); // Telegram (VENDOR.md edit 73)
        if(update_media_lists(m_media))
        {
            m_rebuild_reason = "media";
#if 0
            m_root->refresh_styles();
#else
            refresh_all_styles(); // Telegram (VENDOR.md edit 21)
#endif
            m_root->compute_styles();
            // The set of rendered elements can change across a media breakpoint
            // (e.g. display:none <-> block on responsive nav/hero blocks). The render
            // tree is built once in createFromString() from the computed display values,
            // so rebuild it here to add/remove render items for elements whose display
            // just changed; otherwise a newly-shown element keeps no render item and
            // never lays out (it collapses to zero).
            replace_root_render(); // Telegram (VENDOR.md edit 74)
            report_replacements();
            return true;
        }
        return false;
    }

    // Telegram: the media features, and the viewport units computed from them, follow the container's
    // viewport. createFromString reads them once, at parse, when the container may not know its width yet
    // (LHDocument's is 0 until the first layout), and nothing reads them again, so every
    // @media width query and vw length was resolved against 0. The host calls this after it sets the viewport
    // a layout is measured against. When the viewport moved, the media lists are applied again, and styles
    // and the render tree are rebuilt as media_changed() does when a query flipped or the document resolved
    // a viewport unit (those turn into pixels while styles compute, and the style-sharing cache keeps
    // computed values, so it is emptied first).
    bool document::viewport_changed()
    {
        if(!m_root)
        {
            return false;
        }
        media_features media;
        container()->get_media_features(media);
        if(media.width.value() == m_media.width.value() && media.height.value() == m_media.height.value())
        {
            return false;
        }
        m_media = media;
        const bool flipped = update_media_lists(m_media);
        m_rebuild_reason.clear(); // Telegram (VENDOR.md edit 73)
        if(!flipped && !m_viewport_units)
        {
            return false;
        }
        m_rebuild_reason = flipped ? "media" : "viewport";
        invalidate_paint();
        m_share_cache.clear();
#if 0
        m_root->refresh_styles();
#else
        refresh_all_styles(); // Telegram (VENDOR.md edit 21)
#endif
        m_root->compute_styles();
        replace_root_render(); // Telegram (VENDOR.md edit 74)
        report_replacements();
        return true;
    }

    bool document::lang_changed()
    {
        invalidate_paint();
        if(!m_media_lists.empty())
        {
            std::string culture;
            container()->get_language(m_lang, culture);
            if(!culture.empty())
            {
                m_culture = m_lang + '-' + culture;
            } else
            {
                m_culture.clear();
            }
#if 0
            m_root->refresh_styles();
#else
            refresh_all_styles(); // Telegram (VENDOR.md edit 21)
#endif
            m_root->compute_styles();
            return true;
        }
        return false;
    }

    // Apply media features (determine which selectors are active).
    bool document::update_media_lists(const media_features& features)
    {
        invalidate_paint();
        bool update_styles = false;
        for(auto& media_list : m_media_lists)
        {
            if(media_list->apply_media_features(features))
            {
                update_styles = true;
            }
        }
        return update_styles;
    }

    void document::add_media_list(const media_query_list_list::ptr& list)
    {
        if(list && !contains(m_media_lists, list))
        {
            m_media_lists.push_back(list);
        }
    }

    void document::fix_tables_layout()
    {
        invalidate_paint();
        const std::size_t limit = m_tabular_elements.size() * 8 + 64;
        std::size_t       processed = 0;
        for(const auto& el_ptr : m_tabular_elements)
        {
            if(++processed > limit)
            {
                break;
            }
            switch(el_ptr->src_el()->css().get_display())
            {
            case display_inline_table:
            case display_table:
                fix_table_children(el_ptr, display_table_row_group, "table-row-group");
                break;
            case display_table_footer_group:
            case display_table_row_group:
            case display_table_header_group:
                {
                    auto parent = el_ptr->parent();
                    if(parent)
                    {
                        if(parent->src_el()->css().get_display() != display_inline_table)
                        {
                            fix_table_parent(el_ptr, display_table, "table");
                        }
                    }
                    fix_table_children(el_ptr, display_table_row, "table-row");
                }
                break;
            case display_table_row:
                fix_table_parent(el_ptr, display_table_row_group, "table-row-group");
                fix_table_children(el_ptr, display_table_cell, "table-cell");
                break;
            case display_table_cell:
                fix_table_parent(el_ptr, display_table_row, "table-row");
                break;
            // TODO: make table layout fix for table-caption, table-column etc. elements
            case display_table_caption:
            case display_table_column:
            case display_table_column_group:
            default:
                break;
            }
        }
        // Telegram (VENDOR.md edit 85): the list is this pass's alone. Kept, it held the items init() replaces after it,
        // and with them the elements under them: a replaced text's pieces stayed alive.
        m_tabular_elements.clear();
    }

    void document::fix_table_children(const std::shared_ptr<render_item>& el_ptr, style_display disp,
                                      const char* disp_str)
    {
        std::list<std::shared_ptr<render_item>> tmp;
        auto                                    first_iter = el_ptr->children().begin();
        auto                                    cur_iter   = el_ptr->children().begin();

        auto flush_elements = [&]() {
            element::ptr annon_tag = std::make_shared<html_tag>(el_ptr->src_el(), std::string("display:") + disp_str);
            std::shared_ptr<render_item> annon_ri;
            if(annon_tag->css().get_display() == display_table_cell)
            {
                annon_tag->set_tagName("table_cell");
                annon_ri = std::make_shared<render_item_block>(annon_tag);
            } else if(annon_tag->css().get_display() == display_table_row)
            {
                annon_ri = std::make_shared<render_item_table_row>(annon_tag);
            } else
            {
                annon_ri = std::make_shared<render_item_table_part>(annon_tag);
            }
            for(const auto& el : tmp)
            {
                annon_ri->add_child(el);
            }
            // add annon item as tabular for future processing
            add_tabular(annon_ri);
            annon_ri->parent(el_ptr);
            first_iter = el_ptr->children().insert(first_iter, annon_ri);
            cur_iter   = std::next(first_iter);
            while(cur_iter != el_ptr->children().end() && (*cur_iter)->parent() != el_ptr)
            {
                cur_iter = el_ptr->children().erase(cur_iter);
            }
            first_iter = cur_iter;
            tmp.clear();
        };

        while(cur_iter != el_ptr->children().end())
        {
            if((*cur_iter)->src_el()->css().get_display() != disp)
            {
                if(!(*cur_iter)->src_el()->is_table_skip() || ((*cur_iter)->src_el()->is_table_skip() && !tmp.empty()))
                {
                    if(disp != display_table_row_group ||
                       (*cur_iter)->src_el()->css().get_display() != display_table_caption)
                    {
                        if(tmp.empty())
                        {
                            first_iter = cur_iter;
                        }
                        tmp.push_back((*cur_iter));
                    }
                }
                cur_iter++;
            } else if(!tmp.empty())
            {
                flush_elements();
            } else
            {
                cur_iter++;
            }
        }
        if(!tmp.empty())
        {
            flush_elements();
        }
    }

    void document::fix_table_parent(const std::shared_ptr<render_item>& el_ptr, style_display disp,
                                    const char* disp_str)
    {
        auto parent = el_ptr->parent();

        if(parent->src_el()->css().get_display() != disp)
        {
            auto this_element = std::find_if(parent->children().begin(), parent->children().end(),
                                             [&](const std::shared_ptr<render_item>& el) { return el == el_ptr; });
            if(this_element != parent->children().end())
            {
                style_display el_disp = el_ptr->src_el()->css().get_display();
                auto          first   = this_element;
                auto          last    = this_element;
                auto          cur     = this_element;

                // find first element with same display
                while(true)
                {
                    if(cur == parent->children().begin())
                    {
                        break;
                    }
                    cur--;
                    if((*cur)->src_el()->is_table_skip() || (*cur)->src_el()->css().get_display() == el_disp)
                    {
                        first = cur;
                    } else
                    {
                        break;
                    }
                }

                // find last element with same display
                cur = this_element;
                while(true)
                {
                    cur++;
                    if(cur == parent->children().end())
                    {
                        break;
                    }

                    if((*cur)->src_el()->is_table_skip() || (*cur)->src_el()->css().get_display() == el_disp)
                    {
                        last = cur;
                    } else
                    {
                        break;
                    }
                }

                // extract elements with the same display and wrap them with anonymous object
                element::ptr annon_tag =
                    std::make_shared<html_tag>(parent->src_el(), std::string("display:") + disp_str);
                std::shared_ptr<render_item> annon_ri;
                if(annon_tag->css().get_display() == display_table ||
                   annon_tag->css().get_display() == display_inline_table)
                {
                    annon_ri = std::make_shared<render_item_table>(annon_tag);
                } else if(annon_tag->css().get_display() == display_table_row)
                {
                    annon_ri = std::make_shared<render_item_table_row>(annon_tag);
                } else
                {
                    annon_ri = std::make_shared<render_item_table_part>(annon_tag);
                }
                std::for_each(first, std::next(last, 1),
                              [&annon_ri](std::shared_ptr<render_item>& el) { annon_ri->add_child(el); });
                first = parent->children().erase(first, std::next(last));
                parent->children().insert(first, annon_ri);
                add_tabular(annon_ri);
                annon_ri->parent(parent);
            }
        }
    }

    void document::append_children_from_string(element& parent, const char* str, bool replace_existing)
    {
        invalidate_paint();
        // parent must belong to this document
        if(parent.get_document().get() != this)
        {
            return;
        }

        GumboOptions opts = kGumboDefaultOptions;
        // This is require to prevent creating html, head, body tags around the fragment
        // Although Gumbo always creates html tag anyway. We have to ignore it in create_node.
        opts.fragment_context = GUMBO_TAG_BODY;
        // parse document into GumboOutput
        GumboOutput* output = gumbo_parse_with_options(&opts, str, strlen(str));

        // Create litehtml::elements.
        elements_list child_elements;
        // Create elements excluding the root node
        create_node(output->root, child_elements, true, false);

        // Destroy GumboOutput
        gumbo_destroy_output(&kGumboDefaultOptions, output);

        auto parent_render = parent.get_render_item();

        if(replace_existing)
        {
            parent.clearRecursive();
            parent_render->children().clear();
        }

        // Let's process created elements tree
        for(const auto& child : child_elements)
        {
            // Add the child element to parent
            parent.appendChild(child);

            // apply master CSS
            child->apply_stylesheet(m_master_css);

            // parse elements attributes
            child->parse_attributes();

            // Apply parsed styles.
            child->apply_stylesheet(m_styles);

            // Apply user styles if any
            child->apply_stylesheet(m_user_css);

            // Initialize m_css
            child->compute_styles();

            // Finally initialize elements
            if(parent_render)
            {
                auto child_render = child->create_render_item(parent_render);
                if(child_render)
                {
                    child_render = child_render->init();
                    parent_render->add_child(child_render);
                }
            }
        }
        // Now the m_tabular_elements is filled with tabular elements.
        // We have to check the tabular elements for missing table elements
        // and create the anonymous boxes in visual table layout
        fix_tables_layout();
    }

    void document::dump(dumper& cout)
    {
        if(m_root_render)
        {
            m_root_render->dump(cout);
        }
    }

} // namespace litehtml
