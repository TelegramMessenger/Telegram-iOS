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
#include "el_break.h"
#include "el_div.h"
#include "el_form.h"
#include "el_image.h"
#include "el_para.h"
#include "el_style.h"
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
#include <tuple>
#include <typeinfo>
#include <unordered_set>

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

    void document::release_style_charges(const element::ptr& root)
    {
        std::vector<element::ptr> pending{root};
        while(!pending.empty())
        {
            element::ptr el = pending.back();
            pending.pop_back();
            if(auto tag = std::dynamic_pointer_cast<html_tag>(el))
                tag->release_style_charges();
            for(const auto& child : el->children())
                pending.push_back(child);
        }
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
        release_style_charges(child); // Telegram (VENDOR.md edit 21)
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
        // Elements whose generated content or drawing reads their descendants' text. Not a <button>: el_button draws its
        // bezel around its children and never reads them.
        bool text_read_by_element(const element& el)
        {
            // An <svg> paints its subtree itself (its render item an image): a change under it replaces the svg's render
            // subtree (edit 74's boundary), so it is not listed.
            static const char* const names[] = {"select", "option",   "optgroup", "datalist",
                                                "textarea", "input", "progress", "meter"};
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
        // Telegram (VENDOR.md edit 76): each refusal names why (a caller walks the cut at the text-piece cap).
        if(!parent || !text || !m_finalized || !m_root)
            return refuse("an invalid subtree");
        if(is_raw_text_parent(*parent))
            return refuse("a parent whose children an element reads");
        for(element::ptr el = parent; el; el = el->parent())
        {
            if(text_read_by_element(*el))
                return refuse("a parent whose children an element reads");
        }
        const elements_list& children = parent->children();
        if(first > children.size() || count > children.size() - first)
            return refuse("an invalid subtree");
        auto at = children.begin();
        std::advance(at, first);
        for(size_t i = 0; i < count; i++, ++at)
        {
            const element& el = **at;
            if(typeid(el) != typeid(el_text) && typeid(el) != typeid(el_space))
                return refuse("an invalid subtree");
        }
        int pieces = 0;
        m_container->split_text(text, [&pieces](const char*) { pieces++; }, [&pieces](const char*) { pieces++; });
        const int delta = pieces - int(count);
        // Telegram (VENDOR.md edit 84): the document's own text, which a build makes before any generated content.
        const int base  = m_patch_pending ? m_patch_text_base + m_patch_growth : document_text_pieces();
        if(base + pending_growth + delta > max_text_elements + m_text_allowance)
            return refuse("the text-piece cap");
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
            m_patch_rebuild_reason.clear();
            begin_generated_watch(); // Telegram (VENDOR.md edit 84)
            m_patch_text_base = document_text_pieces();
            m_patch_growth    = 0;
            m_patch_new_text.clear();
            m_patch_seeds.clear(); // Telegram (VENDOR.md edit 74)
            m_patch_custom_tops.clear(); // Telegram (VENDOR.md edit 17)
            m_patch_attribute_changes.clear(); // Telegram (VENDOR.md edit 77)
            m_patch_boxes.clear();
            m_patch_sheets = false; // Telegram (VENDOR.md edit 81)
        }
        record_boxes(parent); // Telegram (VENDOR.md edit 74)
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
        // Telegram (VENDOR.md edit 74): placed in place whatever else the session replaces; else the parent is a seed.
        if(!replace_text_renderers(old, created))
            note_replacement(parent, "text: pieces not placeable"); // edit 73
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
        // Telegram (VENDOR.md edit 88): :empty's answer (edit 31.5): no children but ::before and ::after.
        bool matches_empty(const element& el)
        {
            for(const auto& child : el.children())
            {
                if(child->tag() != __tag_before_ && child->tag() != __tag_after_)
                    return false;
            }
            return true;
        }
    }

    void document::commit_patch()
    {
        if(!m_patch_pending)
            return;
        if(m_patch_sheets)
            apply_sheets();      // Telegram (VENDOR.md edit 81): first, so every later match reads the new sheets
        match_attribute_reach(); // Telegram (VENDOR.md edit 77)
        m_patch_pending = false;
        m_patch_growth  = 0;
        std::vector<element::ptr> new_text;
        new_text.swap(m_patch_new_text);
        // Telegram (VENDOR.md edit 18): the subtrees the session linked, styled as a fresh subtree is styled,
        // now that every structure change is made (a positional match reads the final children). One removed again in
        // the session is not in the document and is left alone.
        std::vector<element::ptr> fresh;
        // Telegram (VENDOR.md edit 89): the subtrees the session inserted and left in the document, text pieces included.
        std::unordered_set<const element*> fresh_roots;
        {
            std::vector<element::ptr> inserted;
            inserted.swap(m_patch_inserted);
            for(const auto& el : inserted)
            {
                element::ptr top = el;
                while(top && top != m_root)
                    top = top->parent();
                if(top != m_root)
                    continue;
                if(std::dynamic_pointer_cast<html_tag>(el))
                    fresh.push_back(el);
                fresh_roots.insert(el.get());
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
            // Telegram (VENDOR.md edit 78): a counted element inserted counts in tree order with the others.
            for(const auto& el : fresh)
                note_counted_subtree(el);
            // Telegram (VENDOR.md edit 42): the other element children of a parent a subject positional rule reaches,
            // matched again now that their places are final.
            // Telegram (VENDOR.md edit 90): the elements the commit's own re-matches take (edit 42's, edit 88's), which the
            // structure reach does not match again; one matched earlier in the session is.
            std::unordered_set<const element*> matchedHere;
            std::vector<element::ptr> parents;
            parents.swap(m_patch_position_parents);
            for(const auto& parent : parents)
            {
                element::ptr top = parent;
                while(top && top != m_root)
                    top = top->parent();
                if(top != m_root)
                    continue;
                // Telegram (VENDOR.md edit 89): with the parent's render tree kept (linked), a child whose box or more than
                // its paint the match changes is a replacement seed, its box recorded before any match.
                const auto matched = [&](const element::ptr& child) {
                    return std::dynamic_pointer_cast<html_tag>(child) && !child->is_text() && !generated_content(*child) &&
                           std::find(fresh.begin(), fresh.end(), child) == fresh.end();
                };
                for(const auto& child : parent->children())
                {
                    if(matched(child))
                        record_boxes(child);
                }
                for(const auto& child : parent->children())
                {
                    if(!matched(child))
                        continue;
                    auto tag = std::static_pointer_cast<html_tag>(child);
                    // Released before the match, so that what it makes counts within the caps; what goes back is taken
                    // back (edit 91).
                    for(const auto& inner : child->children())
                    {
                        if(inner->tag() == __tag_before_ || inner->tag() == __tag_after_)
                            release_pieces(inner);
                    }
                    const string_map attrs   = tag->attributes();
                    const bool       neutral = apply_retag(child, attrs, true);
                    matchedHere.insert(child.get());
                    if(!neutral)
                        note_replacement(child, m_retag_reason);
                    tag->forget_flips();
                    if(std::find(m_patch_restyle.begin(), m_patch_restyle.end(), child) == m_patch_restyle.end())
                    {
                        m_patch_restyle.push_back(child);
                        if(neutral && !m_rematch_changed)
                            m_patch_quiet.insert(child.get()); // edit 90
                    }
                }
            }
            // Telegram (VENDOR.md edit 88): a parent whose emptiness the session flipped is matched again (its :empty,
            // :not(:empty) rules and their content), checked as its render tree may be kept (edit 89: a seed where more
            // than paint changed, its box recorded by the structure change), and with
            // sibling combinators in the sheets so is every element of its later siblings' subtrees, whose boxes and
            // content such a rule can change: each is matched as an attribute's reach is, its box recorded first and a
            // replacement seed where more than paint changed. Each parent's children are walked once, from its first
            // flipped child, and each subtree once. Its descendants never read it (an empty element has none). The
            // var() readers below follow (edit 17, below).
            std::vector<std::pair<element::ptr, bool>> emptyParents;
            emptyParents.swap(m_patch_empty_parents);
            m_patch_empty_noted.clear();
            std::vector<element::ptr> flipped, parentsOfFlipped, reach;
            std::unordered_set<const element*> flippedSet, parentSet, walked, freshSet, restyled;
            for(const auto& el : fresh)
                freshSet.insert(el.get());
            for(const auto& el : m_patch_restyle)
                restyled.insert(el.get());
            const bool siblings = sibling_combinators();
            for(const auto& [parent, was_empty] : emptyParents)
            {
                element::ptr top = parent;
                while(top && top != m_root)
                    top = top->parent();
                if(top != m_root || matches_empty(*parent) == was_empty || !flippedSet.insert(parent.get()).second)
                    continue;
                flipped.push_back(parent);
                if(siblings && parent->parent() && parentSet.insert(parent->parent().get()).second)
                    parentsOfFlipped.push_back(parent->parent());
            }
            // Edit 90: from the first sibling when a :nth-last-* with an `of S` list reads the following siblings.
            const bool earlier = backward_of_lists();
            for(const auto& outer : parentsOfFlipped)
            {
                bool after = earlier;
                for(const auto& sibling : outer->children())
                {
                    if(!after)
                    {
                        after = flippedSet.count(sibling.get()) != 0;
                        continue;
                    }
                    std::vector<element::ptr> stack{sibling};
                    while(!stack.empty())
                    {
                        element::ptr el = stack.back();
                        stack.pop_back();
                        // A subtree inserted in the session is styled afresh above.
                        if(el->is_text() || generated_content(*el) || !std::dynamic_pointer_cast<html_tag>(el) ||
                           freshSet.count(el.get()) || !walked.insert(el.get()).second)
                            continue;
                        if(!flippedSet.count(el.get()))
                            reach.push_back(el);
                        const elements_list& kids = el->children();
                        for(auto it = kids.rbegin(); it != kids.rend(); ++it)
                            stack.push_back(*it);
                    }
                }
            }
            for(const auto& el : reach)
                record_boxes(el); // edit 74: before any match, which can make elements
            const auto match_again = [&](const element::ptr& el, bool check) {
                if(freshSet.count(el.get()))
                    return;
                auto tag = std::static_pointer_cast<html_tag>(el);
                // Released before the match, so that what it makes counts within the caps; what goes back is taken
                // back (edit 91).
                for(const auto& inner : el->children())
                {
                    if(inner->tag() == __tag_before_ || inner->tag() == __tag_after_)
                        release_pieces(inner);
                }
                // el_anchor::apply_stylesheet adds :link once per sheet while it has an href.
                if(typeid(*el) == typeid(el_anchor))
                {
                    while(tag->set_pseudo_class(_link_, false))
                    {
                    }
                }
                const string_map attrs   = tag->attributes();
                const bool       neutral = apply_retag(el, attrs, check);
                matchedHere.insert(el.get());
                if(!neutral && check)
                    note_replacement(el, m_retag_reason); // edits 73, 74
                tag->forget_flips();
                if(restyled.insert(el.get()).second)
                {
                    m_patch_restyle.push_back(el);
                    if(neutral && !m_rematch_changed)
                        m_patch_quiet.insert(el.get()); // edit 90
                }
            };
            for(const auto& el : flipped)
                match_again(el, true);
            for(const auto& el : reach)
                match_again(el, true);
            // Telegram (VENDOR.md edit 90): with sibling combinators or positional pseudo-classes in the sheets, the element
            // children of each parent whose children the session changed, from the first it changed (every one when a rule
            // reads following siblings outside its subject: those rules read only preceding siblings otherwise), and their
            // subtrees, matched again as an attribute's reach is: every box recorded before any match, a seed where more
            // than paint changed. Each element is walked once (with edit 88's reach) and matched once; a subtree the
            // session inserted is styled afresh, and a parent inside one is left to it.
            if(structure_reaches_siblings())
            {
                const bool all = backward_positions();
                std::vector<element::ptr> siblings;
                std::unordered_map<const element*, bool> insideFresh;
                for(const auto& change : m_patch_structure)
                {
                    element::ptr top = change.parent;
                    while(top && top != m_root)
                        top = top->parent();
                    if(top != m_root || inside_any(change.parent.get(), freshSet, insideFresh))
                        continue;
                    size_t index = 0;
                    for(const auto& child : change.parent->children())
                    {
                        if(!all && index++ < change.first)
                            continue;
                        std::vector<element::ptr> stack{child};
                        while(!stack.empty())
                        {
                            element::ptr el = stack.back();
                            stack.pop_back();
                            if(el->is_text() || generated_content(*el) || !std::dynamic_pointer_cast<html_tag>(el) ||
                               freshSet.count(el.get()) || !walked.insert(el.get()).second)
                                continue;
                            siblings.push_back(el);
                            const elements_list& kids = el->children();
                            for(auto it = kids.rbegin(); it != kids.rend(); ++it)
                                stack.push_back(*it);
                        }
                    }
                }
                for(const auto& el : siblings)
                    record_boxes(el); // edit 74: before any match, which can make elements
                for(const auto& el : siblings)
                {
                    if(!matchedHere.count(el.get()))
                        match_again(el, true);
                }
            }
        }
        // Telegram (VENDOR.md edit 17): a restyle substitutes no var() again (subst_vars replaces them in the style), so the
        // elements below an element that declared custom properties before or after it was matched again, whose styles
        // read var(), are matched again too, as a pseudo-class reach is (set_pseudo_classes).
        {
            std::vector<element::ptr> tops;
            tops.swap(m_patch_custom_tops);
            std::vector<element::ptr> readers;
            for(const auto& e : var_readers(tops))
            {
                element::ptr top = e;
                while(top && top != m_root)
                    top = top->parent();
                if(top == m_root)
                    readers.push_back(e);
            }
            rematch_reach(readers);
            m_patch_custom_tops.clear();
        }
        // Telegram (VENDOR.md edit 78): last of the commit's matches, so each counted element counts in a build's order
        // whatever matched it before.
        if(m_patch_counters)
            rerun_counters();
        m_patch_counters = false;
        // Telegram (VENDOR.md edit 84): near a cap the session's generated content may be cut where a fresh build would not
        // cut it: the style pass again, from zero in a build's order.
        const bool restyling     = !m_patch_restyle.empty() || !fresh.empty() || !new_text.empty();
        const bool replay        = generated_cut_in_play(restyling);
        const bool style_limited = m_style_limited;
        m_generated_watch = false;
        m_last_replay_steps    = 0;
        m_last_replay_weight = 0;
        m_last_replay_visits = 0;
        m_last_replay_cut      = false;
        if(replay)
        {
            replay_generated_content();
            m_patch_quiet.clear(); // edit 90: the replay restyles as a build does
        }
        // A cut boot's mark goes with the replay, unless the replay was cut too.
        m_match_cut = m_match_cut && m_last_replay_cut;
        // Telegram (VENDOR.md edit 74): the session's seeds and the outer boxes as they were before it, taken once the
        // commit's own matches (the var() readers above) have noted theirs.
        bool keep_tree    = m_patch_keep_tree && m_root_render;
        m_patch_keep_tree = true;
        std::vector<element::ptr> seeds;
        seeds.swap(m_patch_seeds);
        std::unordered_map<const element*, outer_box> boxes;
        boxes.swap(m_patch_boxes);
        // Telegram (VENDOR.md edit 73).
        m_rebuild_reason = keep_tree ? std::string() : (m_patch_rebuild_reason.empty() ? std::string("no render tree") : m_patch_rebuild_reason);
        m_patch_rebuild_reason.clear();
        // Telegram (VENDOR.md edit 17): the session's re-matched elements join the new pieces.
#if 0
        restyle_after_patch({}, new_text, keep_tree);
#else
        std::vector<element::ptr> restyle;
        restyle.swap(m_patch_restyle);
        // Edit 77: the restyled elements, and the subtrees styled fresh (a caller may have built a kept element again).
        m_last_restyled.assign(restyle.begin(), restyle.end());
        m_last_restyled.insert(m_last_restyled.end(), fresh.begin(), fresh.end());
        restyle_after_patch(restyle, new_text, keep_tree);
#endif
        // Telegram (VENDOR.md edit 84): a restyle charges the style budget too (var() splices, an inline style). One that
        // passed it charged in the patch's order: the style pass is replayed, and the document restyled, as a build's.
        if(!replay && !style_limited && m_style_limited)
        {
            replay_generated_content();
            m_patch_quiet.clear(); // edit 90
            keep_tree         = keep_tree && m_patch_keep_tree;
            m_patch_keep_tree = true;
            seeds.insert(seeds.end(), m_patch_seeds.begin(), m_patch_seeds.end());
            m_patch_seeds.clear();
            boxes.insert(m_patch_boxes.begin(), m_patch_boxes.end());
            m_patch_boxes.clear();
            std::vector<element::ptr> again;
            again.swap(m_patch_restyle);
            m_last_restyled.insert(m_last_restyled.end(), again.begin(), again.end());
            restyle_after_patch(again, {}, keep_tree);
            if(!keep_tree && m_rebuild_reason.empty())
                m_rebuild_reason = m_patch_rebuild_reason.empty() ? std::string("the style budget") : m_patch_rebuild_reason;
            m_patch_rebuild_reason.clear();
        }
        // Telegram (VENDOR.md edit 89): each parent whose children the session changed links its render children (below),
        // or is refused: a replacement seed under a reason naming the case, "structure: <op>: <why>" (plan_link). One out
        // of the document or inside a subtree the session inserted is left to what holds it. A parent whose :empty answer
        // flipped (edit 88) and whose box or more than its paint changed with it is a seed already (an empty parent
        // holding a block-level ::before is a block formatting context), and a seed's boundary holds its links. The
        // refusals' seeds join the session's, as the replay's do.
        std::vector<std::pair<element::ptr, const char*>> linkable;
        {
            std::vector<structure_change> parents;
            parents.swap(m_patch_structure);
            m_patch_structure_noted.clear();
            std::unordered_map<const element*, bool> inside;
            for(const auto& [parent, op, first] : parents)
            {
                element::ptr top = parent;
                while(top && top != m_root)
                {
                    m_replacement_steps++;
                    top = top->parent();
                }
                if(top != m_root || inside_any(parent.get(), fresh_roots, inside))
                    continue;
                const std::string why = plan_link(parent, fresh_roots).refusal;
                if(why.empty())
                    linkable.emplace_back(parent, op);
                else
                    note_replacement(parent, std::string("structure: ") + op + ": " + why);
            }
            seeds.insert(seeds.end(), m_patch_seeds.begin(), m_patch_seeds.end());
            m_patch_seeds.clear();
            boxes.insert(m_patch_boxes.begin(), m_patch_boxes.end());
            m_patch_boxes.clear();
            keep_tree         = keep_tree && m_patch_keep_tree;
            m_patch_keep_tree = true;
            if(!keep_tree && m_rebuild_reason.empty())
                m_rebuild_reason = m_patch_rebuild_reason;
            m_patch_rebuild_reason.clear();
        }
        // Telegram (VENDOR.md edit 74): each seed's nearest boundary has its render subtree replaced; nothing else is made
        // again. Then (edit 89) each linkable parent outside every boundary links: the replacements swap a child's item
        // where it was, so its plan holds (one that does not, which no known change makes, replaces the root). A
        // replacement or a link that moves the table-cell cap's cut replaces the root, which counts in tree order as a build.
        std::vector<element::ptr> replaced;
        bool root_replaced = false;
        const bool limited = m_table_limited;
        if(!keep_tree)
        {
            replaced = m_root_render ? replacement_boundaries(seeds, boxes) : std::vector<element::ptr>{m_root};
            if(replaced.empty())
                m_rebuild_reason.clear();
            else
                root_replaced = replace_render_subtrees(replaced);
        }
        std::vector<element::ptr> renumbered, linked;
        if(!root_replaced && !linkable.empty())
        {
            std::unordered_set<const element*> boundaries;
            for(const auto& b : replaced)
                boundaries.insert(b.get());
            std::unordered_map<const element*, bool> inside;
            for(const auto& [parent, op] : linkable)
            {
                if(inside_any(parent.get(), boundaries, inside))
                    continue;
                const link_plan plan = plan_link(parent, fresh_roots);
                if(plan.refusal.empty())
                {
                    link_render_children(parent, plan, fresh_roots, renumbered, linked);
                    continue;
                }
                if(m_rebuild_reason.empty())
                    m_rebuild_reason = std::string("structure: ") + op + ": " + plan.refusal;
                root_replaced = true;
            }
            if(root_replaced)
                replace_render_subtrees({m_root});
        }
        if(!root_replaced && !limited && m_table_limited)
            root_replaced = replace_render_subtrees({m_root});
        report_replacements(); // Telegram (VENDOR.md edits 74, 89)
        // Telegram (VENDOR.md edit 20): the elements restyled with their render items kept (outside every replaced subtree
        // and, edit 89, every linked one), and whether paint order changed; then the list items numbered again.
        if(m_render_observer && !root_replaced)
        {
            std::unordered_set<const element*> boundaries;
            for(const auto& b : replaced)
                boundaries.insert(b.get());
            for(const auto& b : linked)
                boundaries.insert(b.get());
            std::unordered_map<const element*, bool> inside;
            std::unordered_set<const element*> told;
            for(const auto& el : restyle)
            {
                // Edit 90: one matched again to no change paints as it did.
                if(!m_patch_quiet.count(el.get()) && !inside_any(el.get(), boundaries, inside))
                {
                    told.insert(el.get());
                    m_render_observer->element_restyled(el.get(), m_patch_paint_order.count(el.get()) != 0);
                }
            }
            for(const auto& el : renumbered)
            {
                if(!told.count(el.get()) && !inside_any(el.get(), boundaries, inside))
                    m_render_observer->element_restyled(el.get(), false);
            }
        }
        m_patch_paint_order.clear();
        m_patch_quiet.clear(); // edit 90
        if(!root_replaced)
            forget_positions();
        // Telegram (VENDOR.md edit 17): the render tree has let go of what the session replaced by now.
        m_patch_released = 0;
        m_patch_released_generated = 0; // edit 84
        m_patch_pseudo_released    = 0;
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
            // A <button> reads its disabled attribute again in compute_styles, which the restyle runs. A <br> reads none
            // of its own (Telegram, VENDOR.md edit 17).
            if(type == typeid(html_tag) || type == typeid(el_div) || type == typeid(el_para) || type == typeid(el_td) ||
               type == typeid(el_tr) || type == typeid(el_body) || type == typeid(el_button) || type == typeid(el_break))
                return 1;
            // A <table>'s parse_attributes maps width, height, cellspacing, border and bgcolor to styles.
            if(type == typeid(el_image) || type == typeid(el_anchor) || type == typeid(el_input) || type == typeid(el_svg) ||
               type == typeid(el_table))
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
                // Telegram (VENDOR.md edit 81): a <style>'s piece, which element::children() does not hold.
                if(const auto* sheet = dynamic_cast<const el_style*>(el.get()))
                    n += int(sheet->sheet_pieces().size());
                for(const auto& child : el->children())
                    pending.push_back(child);
            }
            return n;
        }

        // Telegram (VENDOR.md edit 84): generated content: a ::before, an ::after, a form control's lh-* part.
        bool generated_child(const element& el)
        {
            if(el.tag() == __tag_before_ || el.tag() == __tag_after_)
                return true;
            const char* tag = el.get_tagName();
            return tag && !std::strncmp(tag, "lh-", 3);
        }

        // Telegram (VENDOR.md edit 84): the generated content's pieces under `root`, and its pseudo-elements and their
        // images, as note_generated_piece and note_pseudo_element count them.
        int count_generated_pieces(const element::ptr& root)
        {
            int                       n = 0;
            std::vector<element::ptr> pending{root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                if(const auto* piece = dynamic_cast<const el_text*>(el.get()); piece && piece->generated())
                    n++;
                for(const auto& child : el->children())
                    pending.push_back(child);
            }
            return n;
        }

        int count_pseudo_elements(const element::ptr& root)
        {
            int                       n = 0;
            std::vector<element::ptr> pending{root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                const bool pseudo = dynamic_cast<const el_before_after_base*>(el.get()) != nullptr;
                if(pseudo)
                    n++;
                for(const auto& child : el->children())
                {
                    // A pseudo-element's url() image (el_before_after.cpp's el_pseudo_image) counts with it.
                    if(pseudo && dynamic_cast<const el_image*>(child.get()))
                        n++;
                    pending.push_back(child);
                }
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
        m_patch_rebuild_reason.clear();
        begin_generated_watch(); // Telegram (VENDOR.md edit 84)
        m_patch_text_base = document_text_pieces();
        m_patch_growth    = 0;
        m_patch_new_text.clear();
        m_patch_restyle.clear();
        m_patch_position_parents.clear(); // Telegram (VENDOR.md edit 42)
        m_patch_position_unreached.clear();
        m_patch_empty_parents.clear(); // Telegram (VENDOR.md edit 88)
        m_patch_empty_noted.clear();
        m_patch_seeds.clear();            // Telegram (VENDOR.md edit 74)
        m_patch_structure.clear();        // Telegram (VENDOR.md edit 89)
        m_patch_structure_noted.clear();
        m_patch_custom_tops.clear();      // Telegram (VENDOR.md edit 17)
        m_patch_attribute_changes.clear(); // Telegram (VENDOR.md edit 77)
        m_patch_boxes.clear();
        m_patch_sheets = false; // Telegram (VENDOR.md edit 81)
    }

    // Keeps `root` alive until commit_patch and stops text_element_allowed from counting its pieces, and (edit 84)
    // pseudo_element_allowed its pseudo-elements.
    void document::release_pieces(const element::ptr& root)
    {
        m_patch_released += count_pieces(root);
        const int generated = count_generated_pieces(root);
        const int pseudo    = count_pseudo_elements(root);
        m_patch_released_generated += generated;
        m_patch_pseudo_released += pseudo;
        // A subtree that leaves with generated content in it (a removal, a replaced subtree): the generated content the
        // cut counted goes, though it lives on to the commit. Its owner's own generated content, released for a match that
        // makes it again, is the match's to judge (rematch_finish).
        if((generated > 0 || pseudo > 0) && !generated_child(*root))
            note_generated_change();
        m_patch_hold.push_back(root);
    }

    // Telegram (VENDOR.md edit 91): the counts release_pieces added taken back; the hold may keep its reference.
    void document::unrelease_pieces(const element::ptr& root)
    {
        m_patch_released -= count_pieces(root);
        m_patch_released_generated -= count_generated_pieces(root);
        m_patch_pseudo_released -= count_pseudo_elements(root);
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
                    m_pseudo_content |= 1;
                    // A form control's parts: an lh-* subject (has_tag answered for the controls), or `*` with a control.
                    if(sel->m_right.m_tag == star_id ? has_tag(_input_) || has_tag(_select_) || has_tag(_textarea_)
                                                     : _s(sel->m_right.m_tag).compare(0, 3, "lh-") == 0)
                        m_pseudo_content |= 2;
                    if(m_pseudo_content == 3)
                        return true;
                }
            }
        }
        return m_pseudo_content != 0;
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
            note_style_pass_limit("style-bytes"); // Telegram (VENDOR.md edit 84)
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
            note_style_pass_limit("style-bytes"); // Telegram (VENDOR.md edit 84)
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
            return refuse("not a rendered element");
        // An inline or animated style is patched whatever it declares: custom properties and var() are matched again where
        // they reach (commit_patch's var() readers), counters run again in a build's order (edit 78).
        (void)attrs;
        return true;
    }

    // Telegram (VENDOR.md edit 77): the names that differ between two attribute maps.
    document::name_change document::changed_names(const string_map& before, const string_map& after) const
    {
        name_change names;
        auto normalized = [this](const std::string* value) {
            std::string text = value ? *value : std::string();
            if(m_mode == quirks_mode)
                lcase(text);
            return text;
        };
        auto note = [&](const std::string& attr, const std::string* old, const std::string* next) {
            names.attrs.insert(_id(attr));
            if(attr == "id")
            {
                names.ids.insert(_id(normalized(old)));
                names.ids.insert(_id(normalized(next)));
            } else if(attr == "class")
            {
                std::unordered_set<string_id> a, c;
                for(const auto& cls : split_string(normalized(old), whitespace, "", ""))
                    a.insert(_id(cls));
                for(const auto& cls : split_string(normalized(next), whitespace, "", ""))
                    c.insert(_id(cls));
                for(string_id cls : a)
                {
                    if(!c.count(cls))
                        names.classes.insert(cls);
                }
                for(string_id cls : c)
                {
                    if(!a.count(cls))
                        names.classes.insert(cls);
                }
            }
        };
        for(const auto& entry : before)
        {
            auto it = after.find(entry.first);
            if(it == after.end() || it->second != entry.second)
                note(entry.first, &entry.second, it == after.end() ? nullptr : &it->second);
        }
        for(const auto& entry : after)
        {
            if(!before.count(entry.first))
                note(entry.first, nullptr, &entry.second);
        }
        return names;
    }

    bool document::names_reach_others(const name_change& names)
    {
        selector_scope(); // fills m_left_*
        auto any = [](const std::unordered_set<string_id>& names, const std::unordered_set<string_id>& left) {
            return std::any_of(names.begin(), names.end(), [&left](string_id name) { return left.count(name) != 0; });
        };
        return any(names.classes, m_left_classes) || any(names.ids, m_left_ids) || any(names.attrs, m_left_attrs);
    }

    bool document::names_named(const name_change& names)
    {
        selector_scope(); // fills the rule indexes
        auto any = [](const std::unordered_set<string_id>& names,
                      const std::unordered_map<string_id, std::vector<const css_selector*>>& index) {
            return std::any_of(names.begin(), names.end(), [&index](string_id name) { return index.count(name) != 0; });
        };
        return any(names.classes, m_class_rules) || any(names.ids, m_id_rules) || any(names.attrs, m_attr_rules);
    }

    bool document::can_set_element_attributes(const element::ptr& el, const string_map& attrs, attribute_growth* pending)
    {
        if(!el || !m_finalized || !m_root)
            return refuse("not a rendered element");
        if(attribute_patch_kind(*el) == 0)
            return refuse("an element type with no attribute patch");
        element::ptr top = el;
        while(top && top != m_root)
            top = top->parent();
        if(top != m_root)
            return refuse("not a rendered element");
        // Sibling and positional selectors and counters anywhere in the sheets, and the names in ancestor positions
        // (selector_scope fills m_left_*), are what an attribute can reach beyond the element.
#if 0
        if(selector_scope() != 0)
            return false;
#else
        // Telegram (VENDOR.md edit 42): a positional pseudo-class reads an element's place, which no attribute changes,
        // and :empty its children; sibling combinators (and `of S`, bit 1) reach the siblings, which the session matches
        // again (edit 77); counters run again in a build's order at the commit (edit 78). The scope fills m_left_*.
        selector_scope();
#endif
        for(auto p = el->parent(); p; p = p->parent())
        {
            if(p->tag() == _select_)
                return refuse("inside a <select>");
        }
        if(!attribute_change_allowed(el, attrs))
            return false;
        // The cells a span change can add, which a caller planning several changes threads through (the commit recounts
        // the cells from the root, cutting them as a build does).
        attribute_growth bound;
        auto             tag = std::static_pointer_cast<html_tag>(el);
        const string_map& before = tag->attributes();
        const int old_cells = span_of(before, "colspan") * span_of(before, "rowspan");
        const int new_cells = span_of(attrs, "colspan") * span_of(attrs, "rowspan");
        if(new_cells > old_cells)
            bound.cells = new_cells - old_cells;
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
        // Telegram (VENDOR.md edit 77): a change whose names a rule reads beyond the element is matched over its reach.
        if(const name_change names = changed_names(tag->attributes(), attrs);
           (((selector_scope() & 1) != 0 && names_named(names)) || names_reach_others(names)) &&
           std::none_of(m_patch_attribute_changes.begin(), m_patch_attribute_changes.end(),
                        [&el](const auto& change) { return change.first == el; }))
            m_patch_attribute_changes.emplace_back(el, tag->attributes());
        record_boxes(el); // Telegram (VENDOR.md edit 74): before apply_retag, which can make elements
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
        // The ::before and ::after are released before the match, so that what it makes counts within the caps; those
        // rematch_settle puts back are taken back (edit 91).
        for(const auto& child : el->children())
        {
            if(child->tag() == __tag_before_ || child->tag() == __tag_after_)
                release_pieces(child);
        }
        const bool neutral = apply_retag(el, attrs, kind == 1);
        m_attribute_rematches++;
        if(!neutral)
            note_replacement(el, m_retag_reason); // edits 73, 74
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
        // The document-level elements: html, head and body.
        bool document_level_element(const element& el)
        {
            const string_id tag = el.tag();
            return tag == _html_ || tag == _head_ || tag == _body_ || tag == _link_ || tag == _base_ ||
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

        struct subtree_shape
        {
            int       elements       = 0;   // its elements, generated content left out
            long long cells          = 0;   // each element's colspan x rowspan as table_grid::add_cell reads them
            int       levels         = -1;  // the deepest element's level below the root (0: the root); -1: no element
            bool      document_level = false;
            bool      sheets         = false;   // a <style> (Telegram, VENDOR.md edit 81)
            int       master_content = 0;       // elements a master content rule names (edit 84), with `doc`
        };

        // One walk, no recursion.
        subtree_shape shape_of(const element::ptr& root, const document* doc = nullptr)
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
                shape.sheets         = shape.sheets || el->tag() == _style_;
                if(doc && doc->master_content_owner(*el))
                    shape.master_content++;
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
            return refuse("not a rendered element");
        element::ptr top = parent;
        for(; top && top != m_root; top = top->parent())
        {
            if(text_read_by_element(*top))
                return refuse("a parent whose children an element reads");
            if(generated_content(*top))
                return refuse("generated content");
        }
        if(top != m_root)
            return refuse("not a rendered element");
        return true;
    }

    bool document::structure_insertable(const element::ptr& parent, const std::vector<element::ptr>& subtrees,
                                        structure_growth& growth)
    {
        // Telegram (VENDOR.md edit 18): the commit's match makes an inserted element's pseudo-element content; near a cap the
        // commit replays the style pass in a build's order (edit 84).
        int depth = 0;
        for(auto p = parent->parent(); p; p = p->parent())
            depth++;
        int       elements = 0;
        long long cells    = 0;
        std::unordered_set<const element*> seen;
        for(const auto& subtree : subtrees)
        {
            if(!subtree || subtree->parent() || subtree == m_root || !seen.insert(subtree.get()).second)
                return refuse("an invalid subtree");
            // What the parent's own appendChild refuses (el_table takes its row groups and caption only), which a build
            // leaves out.
            if(typeid(*parent) == typeid(el_table) && subtree->tag() != _tbody_ && subtree->tag() != _thead_ &&
               subtree->tag() != _tfoot_ && subtree->tag() != _caption_)
                return refuse("a subtree a parent's own append refuses");
            const subtree_shape shape = shape_of(subtree);
            if(shape.document_level)
                return refuse("a document-level element");
            if(shape.levels >= 0 && depth + 1 + shape.levels >= max_build_depth)
                return refuse("the depth cap");
            elements += shape.elements;
            cells += shape.cells;
        }
        if(m_build_elements + growth.elements + elements > max_build_elements)
            return refuse("the element cap");
        // The pieces of the subtrees are alive, and counted, already: the document's own text (edit 84).
        if(document_text_pieces() - growth.released > max_text_elements + m_text_allowance)
            return refuse("the text-piece cap");
        growth.elements += elements;
        growth.cells += int(cells);
        return true;
    }

    bool document::structure_removable(const element::ptr& subtree, structure_growth& growth)
    {
        if(!subtree || subtree == m_root)
            return refuse("an invalid subtree");
        if(generated_content(*subtree))
            return refuse("generated content");
        const element::ptr parent = subtree->parent();
        if(!parent)
            return refuse("not a rendered element");
        if(!structure_parent_allowed(parent))
            return false;
        const subtree_shape shape = shape_of(subtree);
        if(shape.document_level)
            return refuse("a document-level element");
        growth.released += count_pieces(subtree) - count_generated_pieces(subtree); // edit 84: the document's own text
        growth.elements -= shape.elements;
        return true;
    }

    void document::link_subtree(const element::ptr& parent, size_t index, const element::ptr& subtree)
    {
        const subtree_shape shape = shape_of(subtree, this);
        m_build_elements += shape.elements;
        m_master_content_elements += shape.master_content; // edit 84
        m_patch_sheets = m_patch_sheets || shape.sheets; // edit 81
        insert_child(parent, index, subtree);
        m_patch_inserted.push_back(subtree);
    }

    void document::unlink_subtree(const element::ptr& subtree)
    {
        note_counted_subtree(subtree); // edit 78
        const subtree_shape shape = shape_of(subtree, this);
        m_build_elements -= shape.elements;
        m_master_content_elements -= shape.master_content; // edit 84
        m_patch_sheets = m_patch_sheets || shape.sheets; // edit 81
        release_pieces(subtree);
        remove_child(subtree);
        m_patch_inserted.erase(std::remove(m_patch_inserted.begin(), m_patch_inserted.end(), subtree), m_patch_inserted.end());
    }

    // Telegram (VENDOR.md edits 75, 77): a reach, each element once.
    void document::take_reach(const element::ptr& top, bool subtree, std::vector<element::ptr>& reach,
                              std::unordered_set<const element*>& taken, std::unordered_set<const element*>& whole)
    {
        std::vector<element::ptr> stack{top};
        while(!stack.empty())
        {
            element::ptr next = stack.back();
            stack.pop_back();
            m_predicate_steps++;
            if(whole.count(next.get()))
                continue;
            if(subtree)
                whole.insert(next.get());
            if(!std::dynamic_pointer_cast<html_tag>(next) || generated_content(*next))
                continue;
            if(taken.insert(next.get()).second)
                reach.push_back(next);
            if(!subtree)
                continue;
            const elements_list& children = next->children();
            for(auto it = children.rbegin(); it != children.rend(); ++it)
                stack.push_back(*it);
        }
    }

    // Telegram (VENDOR.md edit 75): elements' pseudo-classes changed in place.
    std::vector<element::ptr> document::pseudo_reach(const std::vector<pseudo_flip>& flips)
    {
        const bool siblings = (selector_scope() & 1) != 0; // fills m_left_pseudo
        std::vector<element::ptr> reach;
        std::unordered_set<const element*> taken;
        std::unordered_set<const element*> whole;
        for(const auto& [el, states] : flips)
        {
            take_reach(el,
                       std::any_of(states.begin(), states.end(),
                                   [this](const auto& state) { return m_left_pseudo.count(state.first) != 0; }),
                       reach, taken, whole);
            // A sibling combinator reaches the later siblings, an nth-last-child(… of S) the earlier ones.
            if(siblings && el->parent())
            {
                for(const auto& sibling : el->parent()->children())
                {
                    if(sibling != el)
                        take_reach(sibling, true, reach, taken, whole);
                }
            }
        }
        return reach;
    }

    // Telegram (VENDOR.md edit 77): an attribute change's reach.
    std::vector<element::ptr> document::attribute_reach(const std::vector<std::pair<element::ptr, const string_map*>>& changes)
    {
        const bool siblings = (selector_scope() & 1) != 0;
        std::vector<element::ptr> reach;
        std::unordered_set<const element*> taken;
        std::unordered_set<const element*> whole;
        // A parent whose children were taken: many changed siblings take them once.
        std::unordered_set<const element*> parents;
        for(const auto& [el, other] : changes)
        {
            auto tag = std::dynamic_pointer_cast<html_tag>(el);
            if(!tag || !other)
                continue;
            m_predicate_steps++;
            const name_change names = changed_names(tag->attributes(), *other);
            const bool deep = names_reach_others(names);
            const bool beside = siblings && names_named(names);
            if(!deep && !beside)
                continue;
            take_reach(el, deep, reach, taken, whole);
            if(beside && el->parent() && parents.insert(el->parent().get()).second)
            {
                for(const auto& sibling : el->parent()->children())
                {
                    if(sibling != el)
                        take_reach(sibling, true, reach, taken, whole);
                }
            }
        }
        return reach;
    }

    // Telegram (VENDOR.md edit 17): the elements below `tops` whose styles read var().
    std::vector<element::ptr> document::var_readers(const std::vector<element::ptr>& tops)
    {
        std::vector<element::ptr> readers;
        if(m_var_readers <= 0)
            return readers;
        std::unordered_set<const element*> walked;
        std::unordered_set<const element*> listed;
        for(const auto& top : tops)
        {
            std::vector<element::ptr> stack;
            for(const auto& child : top->children())
                stack.push_back(child);
            while(!stack.empty())
            {
                element::ptr next = stack.back();
                stack.pop_back();
                m_predicate_steps++;
                if(!walked.insert(next.get()).second)
                    continue;
                auto tag = std::dynamic_pointer_cast<html_tag>(next);
                if(!tag)
                    continue;
                // A ::before or ::after that reads var() is made again by matching its owner again.
                if(generated_content(*next))
                {
                    const element::ptr owner = next->parent();
                    if(tag->reads_var() && owner && owner != top && listed.insert(owner.get()).second)
                        readers.push_back(owner);
                    continue;
                }
                if(tag->reads_var() && listed.insert(next.get()).second)
                    readers.push_back(next);
                for(const auto& child : next->children())
                    stack.push_back(child);
            }
        }
        return readers;
    }

    bool document::can_set_pseudo_classes(const std::vector<pseudo_flip>& flips)
    {
        if(!m_finalized || !m_root)
            return refuse("not a rendered element");
        // Under the root and outside a <select>: each ancestor checked once across the flips.
        std::unordered_set<const element*> under;
        for(const auto& [el, states] : flips)
        {
            if(!el || !std::dynamic_pointer_cast<html_tag>(el))
                return refuse("not a rendered element");
            if(generated_content(*el))
                return refuse("generated content");
            for(element::ptr at = el; at != m_root && !under.count(at.get());)
            {
                m_predicate_steps++;
                element::ptr parent = at->parent();
                if(!parent)
                    return refuse("not a rendered element");
                if(parent->tag() == _select_)
                    return refuse("inside a <select>");
                under.insert(at.get());
                at = parent;
            }
        }
        return true;
    }

    bool document::set_pseudo_classes(const std::vector<pseudo_flip>& flips)
    {
        if(!can_set_pseudo_classes(flips))
            return false;
        std::vector<std::tuple<element::ptr, string_id, bool>> changes;
        for(const auto& [el, states] : flips)
        {
            for(const auto& [name, on] : states)
            {
                if(el->has_pseudo_class(name) != on)
                    changes.emplace_back(el, name, on);
            }
        }
        if(changes.empty())
            return true;
        auto apply = [&changes](bool on) {
            for(const auto& [el, name, wanted] : changes)
                el->set_pseudo_class(name, on == wanted);
        };
        m_match_epoch++;
        begin_patch_session();
        match_attribute_reach(); // edit 77: before the flips, so each filter compares one step of the change
        apply(true);
        // Only an element whose match by a rule naming a changed class differs with the changes and without them is
        // matched again: the others keep their styles, their pseudo-element content and their render items.
        selector_scope(); // fills m_pseudo_class_rules
        std::vector<const css_selector*> rules;
        {
            std::unordered_set<const css_selector*> seen;
            for(const auto& change : changes)
            {
                auto named = m_pseudo_class_rules.find(std::get<1>(change));
                if(named == m_pseudo_class_rules.end())
                    continue;
                for(const css_selector* rule : named->second)
                {
                    if(seen.insert(rule).second)
                        rules.push_back(rule);
                }
            }
        }
        rematch_reach(differing_matches(pseudo_reach(flips), rules, apply));
        return true;
    }

    // Telegram (VENDOR.md edits 75, 77): which candidates a change makes match differently.
    std::vector<element::ptr> document::differing_matches(const std::vector<element::ptr>& candidates,
                                                          const std::vector<const css_selector*>& rules,
                                                          const std::function<void(bool)>& apply)
    {
        // Telegram (VENDOR.md edit 81): its tests in a counted pass, so a selector that walks every sibling or ancestor
        // stops at the session's limit (the caller's limit check abandons the patch) instead of running unbounded.
        const counted_selection pass(this);
        auto matches = [&rules](const element::ptr& e) {
            std::vector<int> out;
            out.reserve(rules.size());
            const auto tag = std::static_pointer_cast<html_tag>(e);
            for(const css_selector* rule : rules)
                out.push_back(tag->select(*rule, true));
            return out;
        };
        // Compared a run of the candidates at a time: the change is undone and made again once per run.
        std::vector<element::ptr> differing;
        constexpr size_t run = 256;
        std::vector<std::vector<int>> now;
        for(size_t at = 0; at < candidates.size(); at += run)
        {
            const size_t end = std::min(candidates.size(), at + run);
            now.clear();
            for(size_t i = at; i < end; i++)
                now.push_back(matches(candidates[i]));
            apply(false);
            for(size_t i = at; i < end; i++)
            {
                if(matches(candidates[i]) != now[i - at])
                    differing.push_back(candidates[i]);
            }
            apply(true);
        }
        return differing;
    }

    // Telegram (VENDOR.md edits 17, 75, 77): a reach matched again in the session.
    void document::rematch_reach(const std::vector<element::ptr>& reach)
    {
        // Matched afresh: a match memo of this epoch (an element matched earlier in the session) replays its rules without
        // el_anchor::apply_stylesheet, which gives back the :link stripped below.
        m_match_epoch++;
        for(const auto& e : reach)
            record_boxes(e); // edit 74: before the rematch, which can make elements
        if(!reach.empty())
            m_layout_before_valid = false;
        std::unordered_set<const element*> reached;
        for(const auto& e : reach)
        {
            reached.insert(e.get());
            auto tag = std::static_pointer_cast<html_tag>(e);
            // The ::before and ::after are released before the match, so that what it makes counts within the caps;
            // those rematch_settle puts back are taken back (edit 91).
            for(const auto& child : e->children())
            {
                if(child->tag() == __tag_before_ || child->tag() == __tag_after_)
                    release_pieces(child);
            }
            // el_anchor::apply_stylesheet adds :link once per sheet while it has an href.
            if(typeid(*e) == typeid(el_anchor))
            {
                while(tag->set_pseudo_class(_link_, false))
                {
                }
            }
            if(!rematch(e, true, tag->attributes()))
                note_replacement(e, m_retag_reason); // edits 73, 74
            tag->forget_flips();
        }
        // The reach's tops: restyle_after_patch restyles each with its subtree. An element whose paint order or paint
        // group changed is restyled too, below a top or not, so that the render observer hears of it (edit 20).
        for(const auto& e : reach)
        {
            const element::ptr parent = e->parent();
            if((!parent || !reached.count(parent.get()) || m_patch_paint_order.count(e.get())) &&
               std::find(m_patch_restyle.begin(), m_patch_restyle.end(), e) == m_patch_restyle.end())
                m_patch_restyle.push_back(e);
        }
    }

    // Telegram (VENDOR.md edit 79): the environment changes in place.
    namespace
    {
        bool same_media(const media_features& a, const media_features& b)
        {
            return a.type == b.type && a.width.value() == b.width.value() && a.height.value() == b.height.value() &&
                   a.device_width.value() == b.device_width.value() && a.device_height.value() == b.device_height.value() &&
                   a.color == b.color && a.color_index == b.color_index && a.monochrome == b.monochrome &&
                   a.resolution == b.resolution && a.color_scheme == b.color_scheme && a.reduced_motion == b.reduced_motion;
        }

    } // namespace

    std::vector<element::ptr> document::media_users(const std::unordered_set<const media_query_list_list*>& lists)
    {
        std::vector<element::ptr> users;
        if(lists.empty() || !m_root)
            return users;
        std::vector<element::ptr> pending{m_root};
        while(!pending.empty())
        {
            element::ptr el = pending.back();
            pending.pop_back();
            m_predicate_steps++;
            if(dynamic_cast<const html_tag*>(el.get()) && !el->is_text() && !generated_content(*el))
            {
                for(const auto& used : el->m_used_styles)
                {
                    if(used->m_selector->m_media_query && lists.count(used->m_selector->m_media_query.get()))
                    {
                        users.push_back(el);
                        break;
                    }
                }
            }
            const elements_list& children = el->children();
            for(auto it = children.rbegin(); it != children.rend(); ++it)
                pending.push_back(*it);
        }
        return users;
    }

    std::vector<element::ptr> document::environment_users(int changed)
    {
        std::vector<element::ptr> users;
        if(!changed || !m_root)
            return users;
        std::vector<element::ptr> pending{m_root};
        while(!pending.empty())
        {
            element::ptr el = pending.back();
            pending.pop_back();
            m_predicate_steps++;
            auto tag = std::dynamic_pointer_cast<html_tag>(el);
            if(tag && !el->is_text() && !generated_content(*el))
            {
                bool reads = (tag->style_environment() & changed) != 0;
                for(const auto& child : el->children())
                {
                    if(child->tag() == __tag_before_ || child->tag() == __tag_after_)
                        reads = reads || (std::static_pointer_cast<html_tag>(child)->style_environment() & changed) != 0;
                }
                if(reads)
                    users.push_back(el);
            }
            const elements_list& children = el->children();
            for(auto it = children.rbegin(); it != children.rend(); ++it)
                pending.push_back(*it);
        }
        return users;
    }

    void document::reparse_environment(int changed)
    {
        // The same text parses to the same sorted rules under any environment (testEnvironmentParsesPairUp), so they pair
        // by position; a rule whose parse read a changed part takes the new parse's style, keeping its own media list.
        auto swap = [changed](css& current, const css& fresh) {
            const css_selector::vector& now = current.selectors();
            const css_selector::vector& next = fresh.selectors();
            if(now.size() != next.size())
            {
                current = fresh;
                return;
            }
            std::unordered_map<const css_selector*, css_selector::ptr> copies;
            for(size_t i = 0; i < now.size(); i++)
            {
                if(!now[i] || !now[i]->m_style || !(now[i]->m_style->environment() & changed) || !next[i])
                    continue;
                auto copy     = std::make_shared<css_selector>(*now[i]);
                copy->m_style = next[i]->m_style;
                copies.emplace(now[i].get(), copy);
            }
            current.replace_selectors(copies);
        };
        if(!m_master_styles.empty())
            swap(m_master_css, parsed_master(m_master_styles));
        if(!m_css.empty())
            swap(m_styles, parsed_author());
        // The root declarations too (edit 80): the root's style combined their environment in, so the root is a user.
        if(m_has_root_declarations && (m_root_declarations.environment() & changed))
            set_root_declarations(m_root_declarations_text);
        // The parses registered their own media lists: keep those a selector uses.
        std::unordered_set<const media_query_list_list*> used;
        for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
        {
            for(const auto& sel : sheet->selectors())
            {
                if(sel && sel->m_media_query)
                    used.insert(sel->m_media_query.get());
            }
        }
        m_media_lists.erase(std::remove_if(m_media_lists.begin(), m_media_lists.end(),
                                           [&used](const media_query_list_list::ptr& list) { return !used.count(list.get()); }),
                            m_media_lists.end());
        update_media_lists(m_media);
        // The rules replaced: what the document derived from them (the indexes hold rules by pointer) is made again.
        forget_sheet_derivations();
    }

    int document::environment_change(const media_features& next) const
    {
        int changed = 0;
        if(next.width.value() != m_media.width.value() || next.height.value() != m_media.height.value())
            changed |= environment_viewport;
        if(next.color_scheme != m_media.color_scheme)
            changed |= environment_scheme; // edit 80
        return changed;
    }

    std::vector<element::ptr> document::environment_reach(const media_features& next, bool declarations_changed)
    {
        std::unordered_set<const media_query_list_list*> flipping;
        for(const auto& list : m_media_lists)
        {
            if(list->would_flip(next))
                flipping.insert(list.get());
        }
        std::vector<element::ptr> reach = media_users(flipping);
        std::unordered_set<const element*> listed;
        for(const auto& e : reach)
            listed.insert(e.get());
        for(const auto& e : environment_users(environment_change(next)))
        {
            if(listed.insert(e.get()).second)
                reach.push_back(e);
        }
        // New root declarations match the root again (change_root_declarations); the caller lists the var() readers below.
        if(declarations_changed && m_root && listed.insert(m_root.get()).second)
            reach.push_back(m_root);
        return reach;
    }

    bool document::environment_changed()
    {
        if(!m_finalized || !m_root)
            return false;
        media_features media;
        container()->get_media_features(media);
        if(same_media(media, m_media))
            return false;
        begin_patch_session();
        const int changed = environment_change(media);
        std::unordered_set<const media_query_list_list*> flipped;
        for(const auto& list : m_media_lists)
        {
            if(list->apply_media_features(media))
                flipped.insert(list.get());
        }
        m_media = media;
        invalidate_paint();
        m_share_cache.clear(); // computed values
        // The users of rules whose media list flipped, and (the rules parsed again first) the elements whose style read a
        // changed part of the environment: a viewport unit folded at parse (edit 11), or light-dark() or a color-scheme
        // naming both resolved at parse (edit 80), in a rule, an inline style, a var() value or the root declarations.
        std::vector<element::ptr> reach = media_users(flipped);
        if(changed)
        {
            reparse_environment(changed);
            std::unordered_set<const element*> listed;
            for(const auto& e : reach)
                listed.insert(e.get());
            for(const auto& e : environment_users(changed))
            {
                if(listed.insert(e.get()).second)
                    reach.push_back(e);
            }
        }
        rematch_reach(reach);
        return true;
    }

    // Telegram (VENDOR.md edit 80).
    bool document::change_root_declarations(const std::string& declarations)
    {
        if(!m_finalized || !m_root || declarations == m_root_declarations_text)
            return false;
        begin_patch_session();
        set_root_declarations(declarations);
        // Matched again, not restyled: the root's style combined the old declarations in, and only a match starts it
        // afresh. The match notes the root as a custom-property top, before or after (edit 17).
        rematch_reach({m_root});
        return true;
    }

    // Telegram (VENDOR.md edit 81).
    bool document::replace_style_text(const element::ptr& style, const std::string& text, std::vector<element::ptr>& pieces)
    {
        auto sheet = std::dynamic_pointer_cast<el_style>(style);
        if(!m_finalized || !m_root || !sheet)
            return false;
        element::ptr top = style;
        while(top && top != m_root)
            top = top->parent();
        if(top != m_root)
            return false;
        // The piece cap, as replace_text counts it: the net pieces the session adds.
        const int count = int(sheet->sheet_pieces().size());
        const int delta = (text.empty() ? 0 : 1) - count;
        const int base  = m_patch_pending ? m_patch_text_base + m_patch_growth : document_text_pieces();
        if(base + delta > max_text_elements + m_text_allowance)
            return false;
        begin_patch_session();
        const elements_list old = sheet->sheet_pieces();
        elements_list       made;
        if(!text.empty())
            made.push_back(std::make_shared<el_text>(text.c_str(), shared_from_this()));
        pieces.assign(made.begin(), made.end());
        sheet->replace_pieces(std::move(made));
        m_patch_growth += delta;
        // The old piece stays alive and uncounted until commit_patch, as replace_text's do.
        m_patch_released += int(old.size());
        m_patch_hold.insert(m_patch_hold.end(), old.begin(), old.end());
        m_patch_sheets = true;
        return true;
    }

    void document::apply_sheets()
    {
        m_patch_sheets = false;
        if(!m_root)
            return;
        // 1. The <style> texts in tree order, as finalize's parse_attributes adds them (el_style holds no media).
        css_text::vector sheets;
        {
            std::vector<element::ptr> pending{m_root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                m_predicate_steps++;
                if(const auto* sheet = dynamic_cast<const el_style*>(el.get()))
                {
                    std::string text;
                    for(const auto& piece : sheet->sheet_pieces())
                        piece->get_text(text);
                    if(!text.empty())
                        sheets.emplace_back(text.c_str(), nullptr, nullptr);
                    continue;
                }
                const elements_list& children = el->children();
                for(auto it = children.rbegin(); it != children.rend(); ++it)
                    pending.push_back(*it);
            }
        }
        // 2. Paired with the current sheets: the common ends, then a longest common subsequence of the rest, which pairs
        // nothing past a bound of its table (every sheet there is then new). The same sheets change nothing, and parse
        // nothing (the runtime charges a parse only when the applied texts change).
        auto same = [](const css_text& a, const css_text& b) {
            return a.text == b.text && a.media == b.media && a.baseurl == b.baseurl;
        };
        if(std::equal(sheets.begin(), sheets.end(), m_css.begin(), m_css.end(), same))
            return;
        const size_t n = m_css.size(), m = sheets.size();
        std::vector<std::pair<size_t, size_t>> pairs; // (old, new), ascending
        size_t head = 0;
        while(head < n && head < m && same(m_css[head], sheets[head]))
        {
            pairs.emplace_back(head, head);
            head++;
        }
        size_t tail = 0;
        while(tail < n - head && tail < m - head && same(m_css[n - 1 - tail], sheets[m - 1 - tail]))
            tail++;
        const size_t a = n - head - tail, b = m - head - tail;
        constexpr size_t max_table = size_t(1) << 20;
        if(a > 0 && b > 0 && (a + 1) * (b + 1) <= max_table)
        {
            std::unordered_map<std::string, int> ids;
            auto id = [&ids](const css_text& sheet) {
                return ids.emplace(sheet.text + '\x1f' + sheet.media + '\x1f' + sheet.baseurl, int(ids.size())).first->second;
            };
            std::vector<int> x(a), y(b);
            for(size_t i = 0; i < a; i++)
                x[i] = id(m_css[head + i]);
            for(size_t j = 0; j < b; j++)
                y[j] = id(sheets[head + j]);
            std::vector<uint32_t> table((a + 1) * (b + 1), 0); // the common length of x[i..] and y[j..]
            for(size_t i = a; i-- > 0;)
            {
                for(size_t j = b; j-- > 0;)
                {
                    table[i * (b + 1) + j] = x[i] == y[j] ? table[(i + 1) * (b + 1) + j + 1] + 1
                                                          : std::max(table[(i + 1) * (b + 1) + j], table[i * (b + 1) + j + 1]);
                }
            }
            for(size_t i = 0, j = 0; i < a && j < b;)
            {
                if(x[i] == y[j])
                {
                    pairs.emplace_back(head + i, head + j);
                    i++;
                    j++;
                }
                else if(table[(i + 1) * (b + 1) + j] >= table[i * (b + 1) + j + 1])
                    i++;
                else
                    j++;
            }
        }
        for(size_t k = tail; k > 0; k--)
            pairs.emplace_back(n - k, m - k);
        // 3. The new sheets parsed as finalize parses them, through the styles cache.
        css old = m_styles;
        m_css   = std::move(sheets);
        css fresh = parsed_author();
        // 4. A paired sheet keeps its rules: the k-th it parsed stands where the new parse's k-th does.
        std::unordered_map<const css_selector*, css_selector::ptr> kept;
        auto range = [](const css& sheet, size_t k) {
            const std::vector<int>& ends = sheet.sheet_ends();
            const size_t begin = k == 0 ? 0 : size_t(ends[k - 1]);
            return std::make_pair(begin, size_t(ends[k]));
        };
        if(old.sheet_ends().size() == n && fresh.sheet_ends().size() == m)
        {
            for(const auto& [i, j] : pairs)
            {
                const auto [from, to]       = range(old, i);
                const auto [fresh_from, fresh_to] = range(fresh, j);
                if(to - from != fresh_to - fresh_from)
                    continue;
                for(size_t k = 0; k < to - from; k++)
                    kept.emplace(fresh.parsed()[fresh_from + k].get(), old.parsed()[from + k]);
            }
        }
        fresh.replace_selectors(kept);
        // 5. What matches differently: an element holding a rule the sheets lost (it, or its ::before or ::after), and one
        // a new rule matches, each new rule tested against each element, a selector step each. Subtrees the session
        // linked are left out: the commit styles them with the new sheets next.
        std::unordered_set<const css_selector*> now, gone, reused;
        for(const auto& sel : fresh.selectors())
            now.insert(sel.get());
        for(const auto& [fresh_sel, old_sel] : kept)
            reused.insert(old_sel.get());
        for(const auto& sel : old.selectors())
        {
            if(!now.count(sel.get()))
                gone.insert(sel.get());
        }
        std::vector<const css_selector*> added;
        for(const auto& sel : fresh.selectors())
        {
            if(!reused.count(sel.get()))
                added.push_back(sel.get());
        }
        std::unordered_set<const element*> linked;
        for(const auto& el : m_patch_inserted)
            linked.insert(el.get());
        std::vector<element::ptr> reach;
        {
            auto holds_gone = [&gone](const element& el) {
                for(const auto& used : el.m_used_styles)
                {
                    if(gone.count(used->m_selector.get()))
                        return true;
                }
                return false;
            };
            const counted_selection pass(this);
            std::vector<element::ptr> pending{m_root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                if(linked.count(el.get()))
                    continue;
                m_predicate_steps++;
                auto tag = std::dynamic_pointer_cast<html_tag>(el);
                if(tag && !el->is_text() && !generated_content(*el))
                {
                    bool again = holds_gone(*el);
                    for(const auto& child : el->children())
                    {
                        if(!again && (child->tag() == __tag_before_ || child->tag() == __tag_after_))
                            again = holds_gone(*child);
                    }
                    // Each rule apply_selector's filter lets through (its rightmost tag, its first class) tested as it
                    // tests one, without pseudo-classes, in a counted pass (below): every step select takes is the
                    // session's, and past its limit it matches nothing more, the session cut (the caller's limit check).
                    for(size_t i = 0; !again && i < added.size(); i++)
                    {
                        const css_element_selector& right = added[i]->m_right;
                        if(right.m_tag != star_id && right.m_tag != el->tag())
                            continue;
                        if(!right.m_attrs.empty() && right.m_attrs[0].type == select_class &&
                           std::find(tag->classes().begin(), tag->classes().end(), right.m_attrs[0].name) == tag->classes().end())
                            continue;
                        again = tag->select(*added[i], false) != select_no_match;
                    }
                    if(again)
                        reach.push_back(el);
                }
                const elements_list& children = el->children();
                for(auto it = children.rbegin(); it != children.rend(); ++it)
                    pending.push_back(*it);
            }
        }
        // 6. The new sheets in place, the media lists no rule uses dropped and the features applied to the new ones.
        m_styles = std::move(fresh);
        {
            std::unordered_set<const media_query_list_list*> used;
            for(const css* sheet : {&m_master_css, &m_styles, &m_user_css})
            {
                for(const auto& sel : sheet->selectors())
                {
                    if(sel && sel->m_media_query)
                        used.insert(sel->m_media_query.get());
                }
            }
            m_media_lists.erase(std::remove_if(m_media_lists.begin(), m_media_lists.end(),
                                               [&used](const media_query_list_list::ptr& list) { return !used.count(list.get()); }),
                                m_media_lists.end());
            update_media_lists(m_media);
        }
        // 7. What was derived from the sheets, computed again when next asked.
        forget_sheet_derivations();
        rematch_reach(reach);
    }

    void document::forget_sheet_derivations()
    {
        m_selector_scope = -1;
        m_ids_selectable = -1;
        m_left_classes.clear();
        m_left_ids.clear();
        m_left_attrs.clear();
        m_left_pseudo.clear();
        m_pseudo_class_rules.clear();
        m_class_rules.clear();
        m_id_rules.clear();
        m_attr_rules.clear();
        m_subject_positions.clear();
        m_backward_positions = false; // Telegram (VENDOR.md edit 90)
        m_backward_of_lists  = false;
        m_pseudo_content     = -1;
        m_style_rule_bytes   = -1;
        m_share_cache.clear();
    }

    // Telegram (VENDOR.md edit 78).
    std::vector<element::ptr> document::counted_elements()
    {
        std::vector<element::ptr> counted;
        if(!m_root || (selector_scope() & 4) == 0)
            return counted;
        std::vector<element::ptr> pending{m_root};
        while(!pending.empty())
        {
            element::ptr el = pending.back();
            pending.pop_back();
            m_predicate_steps++;
            auto tag = std::dynamic_pointer_cast<html_tag>(el);
            if(tag && !el->is_text() && !generated_content(*el) && tag->counted())
                counted.push_back(el);
            const elements_list& children = el->children();
            for(auto it = children.rbegin(); it != children.rend(); ++it)
                pending.push_back(*it);
        }
        return counted;
    }

    void document::note_counted_subtree(const element::ptr& root)
    {
        if(m_patch_counters || !root || (selector_scope() & 4) == 0)
            return;
        std::vector<element::ptr> pending{root};
        while(!pending.empty())
        {
            element::ptr el = pending.back();
            pending.pop_back();
            auto tag = std::dynamic_pointer_cast<html_tag>(el);
            if(tag && !el->is_text() && tag->counted())
            {
                m_patch_counters = true;
                return;
            }
            for(const auto& child : el->children())
                pending.push_back(child);
        }
    }

    // Telegram (VENDOR.md edit 78): counters are state a build makes as it goes: each counter-reset and counter-increment
    // changes the values on an element, a previous sibling or an ancestor (element::find_counter), and each ::before or
    // ::after reads them as it is made. So every counted element is matched again in a build's order: all values
    // cleared, then the master pass, the attributes and the author pass, and the user pass, each over the counted
    // elements in tree order.
    void document::rerun_counters()
    {
        m_patch_counters = false;
        if(!m_root || (selector_scope() & 4) == 0)
            return;
        // counted_elements' walk, which clears every element's values once it has read them.
        std::vector<element::ptr> counted;
        {
            std::vector<element::ptr> pending{m_root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                m_predicate_steps++;
                auto tag = std::dynamic_pointer_cast<html_tag>(el);
                if(tag && !el->is_text() && !generated_content(*el) && tag->counted())
                    counted.push_back(el);
                el->m_counter_values.clear();
                const elements_list& children = el->children();
                for(auto it = children.rbegin(); it != children.rend(); ++it)
                    pending.push_back(*it);
            }
        }
        if(counted.empty())
            return;
        // The custom properties the counted elements declare are those they were matched with: what reads them is as
        // it was.
        const size_t custom_tops = m_patch_custom_tops.size();
        m_match_epoch++;
        for(const auto& e : counted)
            record_boxes(e); // edit 74: before the match, which can make elements
        m_layout_before_valid = false;
        std::vector<rematch_state> states;
        states.reserve(counted.size());
        for(const auto& e : counted)
        {
            auto tag = std::static_pointer_cast<html_tag>(e);
            // The ::before and ::after are released before the match, so that what it makes counts within the caps;
            // those rematch_settle puts back are taken back (edit 91).
            for(const auto& child : e->children())
            {
                if(child->tag() == __tag_before_ || child->tag() == __tag_after_)
                    release_pieces(child);
            }
            // Each pass gives an <a> with an href its :link again, as el_anchor::apply_stylesheet does.
            if(typeid(*e) == typeid(el_anchor))
            {
                while(tag->set_pseudo_class(_link_, false))
                {
                }
            }
            states.push_back(rematch_begin(e, true, tag->attributes()));
        }
        // Each pass in a build's order: an element's own rules, then its ::before and parts, and its ::after once the
        // counted elements below it have had the pass.
        const css* sheets[3] = {&m_master_css, &m_styles, &m_user_css};
        for(int sheet = 0; sheet < 3; sheet++)
        {
            std::vector<element::ptr> pending; // owners whose ::after waits for the end of their subtree, outermost first
            auto contains = [](const element::ptr& owner, const element::ptr& el) {
                for(element::ptr at = el->parent(); at; at = at->parent())
                    if(at == owner)
                        return true;
                return false;
            };
            for(const auto& state : states)
            {
                while(!pending.empty() && !contains(pending.back(), state.el))
                {
                    std::static_pointer_cast<html_tag>(pending.back())->apply_matching_pass_generated(*sheets[sheet], true);
                    pending.pop_back();
                }
                rematch_pass(state, sheet);
                auto tag = std::static_pointer_cast<html_tag>(state.el);
                tag->apply_matching_pass_generated(*sheets[sheet], false);
                pending.push_back(state.el);
            }
            while(!pending.empty())
            {
                std::static_pointer_cast<html_tag>(pending.back())->apply_matching_pass_generated(*sheets[sheet], true);
                pending.pop_back();
            }
        }
        std::unordered_set<const element*> reached;
        for(const auto& state : states)
        {
            reached.insert(state.el.get());
            if(!rematch_finish(state))
                note_replacement(state.el, m_retag_reason); // edits 73, 74
            std::static_pointer_cast<html_tag>(state.el)->forget_flips();
        }
        std::unordered_set<const element*> restyled;
        for(const auto& e : m_patch_restyle)
            restyled.insert(e.get());
        for(const auto& e : counted)
        {
            const element::ptr parent = e->parent();
            if((!parent || !reached.count(parent.get()) || m_patch_paint_order.count(e.get())) && restyled.insert(e.get()).second)
                m_patch_restyle.push_back(e);
        }
        m_patch_custom_tops.resize(custom_tops);
        m_patch_counters = false;
    }

    // Telegram (VENDOR.md edit 84).
    namespace
    {
        void print_generated(const element& el, std::string& out)
        {
            const char* tag = el.get_tagName();
            out += tag ? tag : "#";
            if(el.is_text())
            {
                out += '"';
                el.get_text(out);
                out += '"';
            } else if(const char* src = el.get_attr("src"))
            {
                out += '@';
                out += src;
            }
            out += '{';
            for(const auto& child : el.children())
                print_generated(*child, out);
            out += '}';
        }

        // Pairs two subtrees of one shape node by node, in tree order.
        void pair_subtrees(const element::ptr& a, const element::ptr& b,
                           std::vector<std::pair<element::ptr, element::ptr>>& pairs)
        {
            pairs.emplace_back(a, b);
            auto ia = a->children().begin();
            auto ib = b->children().begin();
            for(; ia != a->children().end() && ib != b->children().end(); ++ia, ++ib)
                pair_subtrees(*ia, *ib, pairs);
        }
    } // namespace

    std::string document::generated_fingerprint(const element& owner)
    {
        std::string out;
        for(const auto& child : owner.children())
        {
            if(generated_child(*child))
                print_generated(*child, out);
        }
        return out;
    }

    // Telegram (VENDOR.md edit 91): as edit 84's put-back in replay_generated_content.
    bool document::take_back_generated(const rematch_state& state)
    {
        // A style that read var() held what the custom properties were (edit 17's subst_vars).
        if(state.generated_reads_var)
            return false;
        elements_list& children = state.el->m_children;
        std::vector<std::pair<elements_list::iterator, element::ptr>> swaps;
        std::vector<std::pair<element::ptr, element::ptr>>            pairs;
        for(auto it = children.begin(); it != children.end(); ++it)
        {
            if((*it)->tag() != __tag_before_ && (*it)->tag() != __tag_after_)
                continue;
            const auto old = std::find_if(state.generated_aside.begin(), state.generated_aside.end(),
                                          [&it](const element::ptr& aside) { return aside->tag() == (*it)->tag(); });
            if(old == state.generated_aside.end())
                return false;
            std::string was, is;
            print_generated(**old, was);
            print_generated(**it, is);
            if(was != is)
                return false;
            swaps.emplace_back(it, *old);
            pair_subtrees(*old, *it, pairs);
        }
        if(swaps.size() != state.generated_aside.size())
            return false;
        for(const auto& [o, n] : pairs)
        {
            auto ot = std::dynamic_pointer_cast<html_tag>(o);
            auto nt = std::dynamic_pointer_cast<html_tag>(n);
            if(!ot != !nt || (ot && ot->used_rules() != nt->used_rules()))
                return false;
        }
        // The old ones take the new ones' styles, charges and counter values, and their places; the new ones are
        // released, held to the commit.
        for(const auto& [o, n] : pairs)
        {
            if(auto ot = std::dynamic_pointer_cast<html_tag>(o))
                ot->adopt_matched(*std::static_pointer_cast<html_tag>(n));
        }
        for(auto& [it, old] : swaps)
        {
            const element::ptr made = *it;
            made->parent(nullptr);
            release_pieces(made);
            unrelease_pieces(old);
            old->parent(state.el);
            *it = old;
        }
        return true;
    }

    void document::begin_generated_watch()
    {
        m_generated_watch       = true;
        m_generated_changed     = false;
        m_rematching            = 0;
        m_session_document_text = document_text_pieces();
        m_session_style_bytes   = m_style_bytes;
        m_session_build_elements = m_build_elements;
    }

    int document::document_text_pieces() const
    {
        return (m_text_elements - m_generated_pieces) - (m_patch_released - m_patch_released_generated);
    }

    bool document::generated_cut_in_play(bool restyling) const
    {
        if(!m_generated_watch)
            return false;
        if(m_match_cut)
            return true;
        const bool changed = m_generated_changed || document_text_pieces() != m_session_document_text ||
                             m_style_bytes != m_session_style_bytes || m_build_elements != m_session_build_elements;
        // Past the style budget a match is refused declarations whatever it charged before: any restyle replays.
        if(m_style_limited && (changed || restyling))
            return true;
        if(!changed)
            return false;
        // A build's master pass holds every master content element's content at once, whatever the author pass drops.
        if(m_pseudo_limited ||
           m_build_elements + m_pseudo_elements - m_patch_pseudo_released + m_master_content_elements > max_build_elements)
            return true;
        const int generated = m_generated_pieces - m_patch_released_generated;
        if(m_text_limited)
            return generated > 0 || pseudo_content_possible();
        const long long master = (long long)m_master_content_elements * master_content_pieces();
        return (generated > 0 || master > 0) &&
               document_text_pieces() + generated + master + m_generated_transient >= max_text_elements;
    }

    int document::master_content_pieces() const
    {
        if(m_master_content_pieces >= 0)
            return m_master_content_pieces;
        m_master_content_pieces = 0;
        for(const auto& sel : m_master_css.selectors())
        {
            if(!sel || !sel->m_style)
                continue;
            bool pseudo = false;
            for(const auto& attr : sel->m_right.m_attrs)
                pseudo = pseudo || (attr.type == select_pseudo_element && (attr.name == _before_ || attr.name == _after_));
            const auto& content = sel->m_style->get_property(_content_);
            if(!pseudo || !content.is<std::string>() || content.get<std::string>().empty() ||
               content.get<std::string>() == "none")
                continue;
            if(sel->m_right.m_tag == star_id)
                m_master_content_any = true;
            else if(std::find(m_master_content_tags.begin(), m_master_content_tags.end(), sel->m_right.m_tag) ==
                    m_master_content_tags.end())
                m_master_content_tags.push_back(sel->m_right.m_tag);
            // Its pieces: each quoted string split as text is; anything else (a counter, attr(), a quote) any number.
            const std::string& str = content.get<std::string>();
            int                pieces = 0;
            for(size_t i = 0; i < str.size() && pieces < max_text_elements;)
            {
                if(str[i] == ' ')
                {
                    i++;
                } else if(str[i] == '"' || str[i] == '\'')
                {
                    const size_t end = str.find(str[i], i + 1);
                    const std::string text = str.substr(i + 1, end == std::string::npos ? std::string::npos : end - i - 1);
                    m_container->split_text(text.c_str(), [&pieces](const char*) { pieces++; },
                                            [&pieces](const char*) { pieces++; });
                    i = end == std::string::npos ? str.size() : end + 1;
                } else
                {
                    pieces = max_text_elements;
                }
            }
            m_master_content_pieces = std::max(m_master_content_pieces, std::min(pieces, max_text_elements));
        }
        return m_master_content_pieces;
    }

    bool document::master_content_owner(const element& el) const
    {
        master_content_pieces();
        return (m_master_content_any && el.tag() != __tag_before_ && el.tag() != __tag_after_) ||
               std::find(m_master_content_tags.begin(), m_master_content_tags.end(), el.tag()) != m_master_content_tags.end();
    }

    void document::count_master_content_owners()
    {
        m_master_content_elements = m_root ? shape_of(m_root, this).master_content : 0;
    }

    void document::note_style_pass_limit(const char* kind)
    {
        if(m_recording_style_pass && std::find(m_style_pass_limits.begin(), m_style_pass_limits.end(), kind) ==
                                         m_style_pass_limits.end())
            m_style_pass_limits.emplace_back(kind);
    }

    std::vector<std::string> document::style_pass_limits() const
    {
        std::vector<std::string> kinds = m_style_pass_limits;
        // The style budget can be passed while styles are computed too (var() splices, an inline style), after matching.
        if(m_style_limited && std::find(kinds.begin(), kinds.end(), "style-bytes") == kinds.end())
            kinds.emplace_back("style-bytes");
        if(m_table_limited)
            kinds.emplace_back("table");
        return kinds;
    }

    void document::replay_generated_content()
    {
        m_generated_replays++;
        m_last_replay_visits            = 0;
        const bool style_limited_before = m_style_limited;
        // Every element in tree order, generated content aside; the counter values cleared, as a build starts with none.
        std::vector<element::ptr> elements;
        {
            std::vector<element::ptr> pending{m_root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                m_predicate_steps++;
                m_last_replay_visits++;
                // Generated content, and what is under it, is made again by its owner's match.
                if(generated_child(*el))
                    continue;
                el->m_counter_values.clear();
                if(std::dynamic_pointer_cast<html_tag>(el) && !el->is_text())
                    elements.push_back(el);
                const elements_list& children = el->children();
                for(auto it = children.rbegin(); it != children.rend(); ++it)
                    pending.push_back(*it);
            }
        }
        {
            const pseudo_element_tags creators = pseudo_element_creators();
            m_last_replay_weight               = 0;
            for(const auto& e : elements)
                m_last_replay_weight += int64_t(matching_weight(*e, creators));
        }
        m_match_epoch++;
        for(const auto& e : elements)
            record_boxes(e); // edit 74: before the match, which can make elements
        m_layout_before_valid = false;
        // Each element's generated content set aside, as its match will make it again: held to the commit, its pieces and
        // pseudo-elements uncounted, its style charges given back.
        std::vector<std::vector<element::ptr>> old(elements.size());
        std::vector<std::string>               prints(elements.size());
        for(size_t i = 0; i < elements.size(); i++)
        {
            const element::ptr& e = elements[i];
            for(const auto& child : e->children())
            {
                m_last_replay_visits++;
                if(generated_child(*child))
                    old[i].push_back(child);
            }
            if(old[i].empty())
                continue;
            prints[i] = generated_fingerprint(*e);
            for(const auto& child : old[i])
            {
                release_pieces(child);
                release_style_charges(child);
                e->removeChild(child);
            }
        }
        std::vector<rematch_state> states;
        states.reserve(elements.size());
        for(const auto& e : elements)
        {
            auto tag = std::static_pointer_cast<html_tag>(e);
            // Each pass gives an <a> with an href its :link again, as el_anchor::apply_stylesheet does.
            if(typeid(*e) == typeid(el_anchor))
            {
                while(tag->set_pseudo_class(_link_, false))
                {
                }
            }
            states.push_back(rematch_begin(e, true, tag->attributes()));
        }
        // The caps from zero, as a build's matching starts them, and the replay's steps within its limit.
        m_text_limited   = false;
        m_pseudo_limited = false;
        m_style_bytes    = 0;
        m_style_limited  = false;
        m_style_budget_epoch++; // edit 60
        m_style_pass_limits.clear();
        m_recording_style_pass   = true;
        m_generated_transient    = 0;
        // What the caps count from: the document's own pieces in the tree, which is what a build has made before it
        // matches; every other piece and pseudo-element alive (set aside here, or kept by replaced render items until a
        // layout) is held as released.
        {
            int document_pieces = 0;
            std::vector<element::ptr> pending{m_root};
            while(!pending.empty())
            {
                element::ptr el = pending.back();
                pending.pop_back();
                m_last_replay_visits++;
                if(generated_child(*el))
                    continue;
                if(el->is_text())
                    document_pieces++;
                if(const auto* sheet = dynamic_cast<const el_style*>(el.get()))
                    document_pieces += int(sheet->sheet_pieces().size());
                for(const auto& child : el->children())
                    pending.push_back(child);
            }
            m_patch_released           = int(m_text_elements) - document_pieces;
            m_patch_released_generated = m_generated_pieces;
            m_patch_pseudo_released    = int(m_pseudo_elements);
        }
        const int64_t used_before  = selector_steps_used();
        const int64_t limit_before = selector_step_limit();
        const int64_t limit        = m_replay_step_limit;
        if(m_step_session_open)
            set_selector_step_limit(limit);
        // The elements are in tree order, so each one's subtree is the elements from it up to its end: where an owner's
        // ::after waits, whether an element is below it is one comparison.
        std::vector<size_t> ends(elements.size());
        {
            std::unordered_map<const element*, size_t> index;
            index.reserve(elements.size());
            for(size_t i = 0; i < elements.size(); i++)
            {
                index.emplace(elements[i].get(), i);
                ends[i] = i + 1;
            }
            for(size_t i = elements.size(); i-- > 0;)
            {
                m_last_replay_visits++;
                for(element::ptr at = elements[i]->parent(); at; at = at->parent())
                {
                    m_last_replay_visits++;
                    if(auto found = index.find(at.get()); found != index.end())
                    {
                        ends[found->second] = std::max(ends[found->second], ends[i]);
                        break;
                    }
                }
            }
        }
        // The passes in a build's order: the master sheet over the tree, the attributes, the author sheets, the host sheet;
        // in each, an element's own rules, then its ::before and parts, and its ::after once the elements below it have
        // had the pass.
        const css* sheets[3] = {&m_master_css, &m_styles, &m_user_css};
        for(int sheet = 0; sheet < 3; sheet++)
        {
            if(sheet == 1)
            {
                for(const auto& state : states)
                    std::static_pointer_cast<html_tag>(state.el)->parse_own_attributes();
            }
            std::vector<size_t> pending; // owners whose ::after waits for the end of their subtree, outermost first
            for(size_t i = 0; i < states.size(); i++)
            {
                const rematch_state& state = states[i];
                while(!pending.empty() && i >= ends[pending.back()])
                {
                    m_last_replay_visits++;
                    std::static_pointer_cast<html_tag>(elements[pending.back()])
                        ->apply_matching_pass_generated(*sheets[sheet], true);
                    pending.pop_back();
                }
                auto tag = std::static_pointer_cast<html_tag>(state.el);
                tag->apply_matching_pass(*sheets[sheet], sheet, false);
                tag->apply_matching_pass_generated(*sheets[sheet], false);
                m_last_replay_visits += 1 + 2 * int64_t(tag->children().size()); // its generated children, twice
                pending.push_back(i);
            }
            while(!pending.empty())
            {
                std::static_pointer_cast<html_tag>(elements[pending.back()])->apply_matching_pass_generated(*sheets[sheet], true);
                pending.pop_back();
            }
        }
        m_recording_style_pass = false;
        const int64_t used_after = selector_steps_used();
        m_last_replay_steps      = used_after - used_before;
        m_last_replay_cut        = m_step_session_open && used_after > limit;
        if(m_step_session_open)
            set_selector_step_limit(limit_before);
        // Each element finished as a re-match is (with its generated content aside, so its rules decide), then given back
        // its old generated content where the new comes out the same, with the new match's styles.
        for(size_t i = 0; i < states.size(); i++)
        {
            const element::ptr& e   = states[i].el;
            auto                tag = std::static_pointer_cast<html_tag>(e);
            std::vector<std::pair<element::ptr, size_t>> made; // the new generated children, with their places
            {
                size_t at = 0;
                for(const auto& child : e->children())
                {
                    if(generated_child(*child))
                        made.emplace_back(child, at);
                    at++;
                }
                m_last_replay_visits += 3 * int64_t(at); // this scan, the set-aside and the return
            }
            const std::string print = made.empty() ? std::string() : generated_fingerprint(*e);
            elements_list children;
            children.swap(tag->m_children);
            for(const auto& child : children)
            {
                if(!generated_child(*child))
                    tag->m_children.push_back(child);
            }
            const bool kept = rematch_finish(states[i]);
            tag->m_children.swap(children);
            if(!kept)
                note_replacement(e, m_retag_reason); // edits 73, 74
            tag->forget_flips();
            bool same = print == prints[i] && made.size() == old[i].size();
            std::vector<std::pair<element::ptr, element::ptr>> pairs;
            for(size_t k = 0; same && k < made.size(); k++)
                pair_subtrees(old[i][k], made[k].first, pairs);
            for(const auto& [o, n] : pairs)
            {
                auto ot = std::dynamic_pointer_cast<html_tag>(o);
                auto nt = std::dynamic_pointer_cast<html_tag>(n);
                if(!ot != !nt || (ot && ot->used_rules() != nt->used_rules()))
                    same = false;
            }
            if(made.empty() && old[i].empty())
                continue;
            if(!same)
            {
                note_replacement(e, "generated content");
                continue;
            }
            for(const auto& [o, n] : pairs)
            {
                if(auto ot = std::dynamic_pointer_cast<html_tag>(o))
                    ot->adopt_matched(*std::static_pointer_cast<html_tag>(n));
            }
            for(size_t k = 0; k < made.size(); k++)
            {
                auto it = tag->m_children.begin();
                std::advance(it, made[k].second);
                old[i][k]->parent(e);
                *it = old[i][k];
                made[k].first->parent(nullptr);
            }
        }
        // Every element is restyled, as for an environment change; near the style budget a match can keep its rules and
        // lose declarations, which no rule comparison sees, so the whole tree is made again there.
        std::unordered_set<const element*> restyled;
        for(const auto& e : m_patch_restyle)
            restyled.insert(e.get());
        for(const auto& e : elements)
        {
            if(restyled.insert(e.get()).second)
                m_patch_restyle.push_back(e);
        }
        if(style_limited_before || m_style_limited)
            note_replacement(m_root, "the style budget");
        m_patch_counters = false;
    }

    // Telegram (VENDOR.md edit 77): the session's attribute changes matched over their reach.
    void document::match_attribute_reach()
    {
        if(m_patch_attribute_changes.empty())
            return;
        std::vector<std::pair<element::ptr, string_map>> changes;
        changes.swap(m_patch_attribute_changes);
        std::vector<std::pair<element::ptr, const string_map*>> before;
        std::vector<string_map> now;
        std::unordered_set<const element*> recorded;
        name_change names;
        for(auto& [el, attrs] : changes)
        {
            now.push_back(std::static_pointer_cast<html_tag>(el)->attributes());
            before.emplace_back(el, &attrs);
            recorded.insert(el.get());
            const name_change changed = changed_names(attrs, now.back());
            names.classes.insert(changed.classes.begin(), changed.classes.end());
            names.ids.insert(changed.ids.begin(), changed.ids.end());
            names.attrs.insert(changed.attrs.begin(), changed.attrs.end());
        }
        // The rules naming a changed name (selector_scope fills the indexes: a sheet change the commit applied forgot
        // them, edit 81).
        selector_scope();
        std::vector<const css_selector*> rules;
        {
            std::unordered_set<const css_selector*> seen;
            auto add = [&](const std::unordered_map<string_id, std::vector<const css_selector*>>& index,
                           const std::unordered_set<string_id>& changed) {
                for(string_id name : changed)
                {
                    auto named = index.find(name);
                    if(named == index.end())
                        continue;
                    for(const css_selector* rule : named->second)
                    {
                        if(seen.insert(rule).second)
                            rules.push_back(rule);
                    }
                }
            };
            add(m_class_rules, names.classes);
            add(m_id_rules, names.ids);
            add(m_attr_rules, names.attrs);
        }
        // A recorded element in the reach is matched again whatever its match: it was matched with the other changes'
        // attributes as they were. Every other element whose match by a rule naming a changed name differs with the
        // changes and without them, except that :link follows href, which flipping the attributes does not: with an href
        // changed, every element of the reach is matched again.
        std::vector<element::ptr> reach;
        std::vector<element::ptr> others;
        for(const auto& e : attribute_reach(before))
            (recorded.count(e.get()) ? reach : others).push_back(e);
        auto apply = [&changes, &now](bool on) {
            for(size_t i = 0; i < changes.size(); i++)
                std::static_pointer_cast<html_tag>(changes[i].first)->reset_attributes(on ? now[i] : changes[i].second);
        };
        const std::vector<element::ptr> differing =
            names.attrs.count(_id("href")) ? others : differing_matches(others, rules, apply);
        reach.insert(reach.end(), differing.begin(), differing.end());
        rematch_reach(reach);
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
        if(!subtree)
            return refuse("an invalid subtree");
        if(!structure_parent_allowed(parent))
            return false;
        if(index > parent->children().size())
            return refuse("an invalid subtree");
        // Edit 78: counters run again at the commit; edit 88: a parent whose emptiness flips is matched again there; edit
        // 83: under sibling combinators and positional pseudo-classes, the siblings a rule can reach are.
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
        if(!m_finalized || !m_root)
            return refuse("not a rendered element");
        // Edits 78, 88 and 90, as can_insert_subtree.
#endif
        structure_growth growth = pending ? *pending : structure_growth();
        if(!structure_removable(subtree, growth))
            return false;
        if(pending)
            *pending = growth;
        return true;
    }

    // Telegram (VENDOR.md edit 82).
    bool document::can_replace_root(const element::ptr& root, structure_growth* pending)
    {
        if(!m_finalized || !m_root || !root || root->parent() || root == m_root || root->is_text() ||
           !std::dynamic_pointer_cast<html_tag>(root))
            return refuse("an invalid subtree");
        structure_growth growth = pending ? *pending : structure_growth{};
        // The old tree goes, as a removal.
        growth.released += count_pieces(m_root) - count_generated_pieces(m_root);
        growth.elements -= shape_of(m_root).elements;
        // The new one comes at the root's place. Its pseudo-element content follows its own sheets, which the commit
        // applies: a cap that content reaches is the caller's check after the commit.
        const subtree_shape shape = shape_of(root);
        if(shape.levels >= max_build_depth)
            return refuse("the depth cap");
        if(m_build_elements + growth.elements + shape.elements > max_build_elements)
            return refuse("the element cap");
        if(document_text_pieces() - growth.released > max_text_elements + m_text_allowance)
            return refuse("the text-piece cap");
        if(pending)
        {
            growth.elements += shape.elements;
            *pending = growth;
        }
        return true;
    }

    bool document::replace_root(const element::ptr& root)
    {
        if(!can_replace_root(root))
            return false;
        begin_patch_session();
        m_match_epoch++;
        note_style_change();
        m_layout_before_valid = false;
        const element::ptr old = m_root;
        // The old tree goes as a removal does: its counted elements noted, its elements uncounted, its pieces released and
        // held until the commit, its style charges given back; the pointer elements leave with it.
        release_style_charges(old);
        unlink_subtree(old);
        m_over_element   = nullptr;
        m_active_element = nullptr;
        old->set_pseudo_class(_root_, false);
        // The new one comes as an insertion does, at the root's place: styled fresh at the commit.
        m_root = root;
        m_root->set_pseudo_class(_root_, true);
        const subtree_shape shape = shape_of(root, this);
        m_build_elements += shape.elements;
        m_master_content_elements += shape.master_content; // edit 84
        m_patch_sheets = m_patch_sheets || shape.sheets; // edit 81
        m_patch_inserted.push_back(root);
        note_replacement(m_root, "structure: the document element replaced"); // edits 73, 74
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

    // Each parent asked once in a session, however many of its children the session changes: one noted stays noted, and
    // one no rule reaches stays unreached while its children only go.
    void document::note_position_parent(const element::ptr& parent)
    {
        if(!parent || m_patch_position_unreached.count(parent.get()) ||
           std::find(m_patch_position_parents.begin(), m_patch_position_parents.end(), parent) != m_patch_position_parents.end())
            return;
        if(positions_reach(parent))
            m_patch_position_parents.push_back(parent);
        else
            m_patch_position_unreached.insert(parent.get());
    }

    // Telegram (VENDOR.md edit 88).
    void document::note_empty_parent(const element::ptr& parent)
    {
        if(!parent || !empty_in_sheets() || !m_patch_empty_noted.insert(parent.get()).second)
            return;
        m_patch_empty_parents.emplace_back(parent, matches_empty(*parent));
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
                m_position_scans++;
                if(child->is_text() || generated_content(*child) || !std::dynamic_pointer_cast<html_tag>(child))
                    continue;
                if(rule.tag == star_id || child->tag() == rule.tag)
                    return true;
            }
        }
        return false;
    }

    // Telegram (VENDOR.md edit 89): a parent whose children the session changes, each once with the first operation;
    // commit_patch links its render children or replaces it.
    void document::note_structure(const element::ptr& parent, const char* op, size_t index)
    {
        if(!parent)
            return;
        auto noted = m_patch_structure_noted.find(parent.get());
        if(noted == m_patch_structure_noted.end())
        {
            m_patch_structure_noted.emplace(parent.get(), m_patch_structure.size());
            m_patch_structure.push_back({parent, op, index});
            return;
        }
        structure_change& change = m_patch_structure[noted->second];
        change.first = std::min(change.first, index);
    }

    bool document::insert_subtree(const element::ptr& parent, size_t index, const element::ptr& subtree)
    {
        if(!can_insert_subtree(parent, index, subtree))
            return false;
        begin_patch_session();
        m_match_epoch++;
        note_style_change();
        m_layout_before_valid = false;
        record_boxes(parent);             // Telegram (VENDOR.md edit 74)
        note_structure(parent, "insert", index); // edits 89, 90
        note_position_parent(parent); // Telegram (VENDOR.md edit 42)
        note_empty_parent(parent);    // Telegram (VENDOR.md edit 88)
        link_subtree(parent, index, subtree);
        // An element a rule names can make the parent reached for the next change under it.
        if(m_patch_position_unreached.count(parent.get()))
        {
            for(const auto& rule : m_subject_positions)
            {
                if((rule.parent == star_id || rule.parent == parent->tag()) &&
                   (rule.tag == star_id || rule.tag == subtree->tag()) && std::dynamic_pointer_cast<html_tag>(subtree))
                {
                    m_patch_position_unreached.erase(parent.get());
                    break;
                }
            }
        }
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
        record_boxes(subtree->parent()); // Telegram (VENDOR.md edit 74)
        {
            // Edits 89, 90: its place among its parent's children.
            size_t index = 0;
            for(const auto& child : subtree->parent()->children())
            {
                if(child == subtree)
                    break;
                index++;
            }
            note_structure(subtree->parent(), "remove", index);
        }
        note_position_parent(subtree->parent()); // Telegram (VENDOR.md edit 42)
        note_empty_parent(subtree->parent());    // Telegram (VENDOR.md edit 88)
        unlink_subtree(subtree);
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
} // namespace litehtml
