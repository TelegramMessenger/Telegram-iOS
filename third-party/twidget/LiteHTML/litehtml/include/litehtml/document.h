#ifndef LITEHTML_DOCUMENT_H
#define LITEHTML_DOCUMENT_H

#include "stylesheet.h"
#include "css_properties.h"
#include "encodings.h"
#include "font_description.h"
#include "master_css.h"
#include "types.h"

#include <atomic>
#include <cstdint>
#include <functional>
#include <unordered_map>
#include <map>
#include <unordered_set>
#include <vector>

using GumboOutput = struct GumboInternalOutput;

namespace litehtml
{
    struct css_text
    {
        using vector = std::vector<css_text>;

        std::string text;
        std::string baseurl;
        std::string media;

        css_text() = default;

        css_text(const char* txt, const char* url, const char* media_str) :
            text(txt ? txt : ""),
            baseurl(url ? url : ""),
            media(media_str ? media_str : "")
        {
        }
    };

    class dumper
    {
      public:
        virtual ~dumper()                                                        = default;
        virtual void begin_node(const std::string& descr)                        = 0;
        virtual void end_node()                                                  = 0;
        virtual void begin_attrs_group(const std::string& descr)                 = 0;
        virtual void end_attrs_group()                                           = 0;
        virtual void add_attr(const std::string& name, const std::string& value) = 0;
    };

    class html_tag;
    class render_item;

    // Telegram (VENDOR.md edit 18): a selector-step budget shared by every outermost apply_stylesheet of a build or a
    // patch session (html_tag.cpp counts a step for each selector it tests against an element), instead of one
    // 4,000,000-step budget per outermost pass. `used` passes `limit` when a test was refused.
    class document;
    struct selector_step_session
    {
        int64_t         limit = 4000000;
        int64_t         used  = 0;
        const document* owner = nullptr;   // only matching over this document's elements counts into it
    };
    // The session this thread's matching counts into; nullptr (the default): none, and each outermost pass has its own
    // 4,000,000 steps, as before.
    void set_selector_step_session(selector_step_session* session);
    // Telegram (VENDOR.md edit 81): while it lives, select() outside an apply_stylesheet counts its steps into `doc`'s
    // session (the one set_selector_step_session made current, when `doc` owns it) and refuses past its limit, as the
    // outermost apply_stylesheet pass does: a selector tested against elements on its own, which no pass bounds.
    class counted_selection
    {
      public:
        explicit counted_selection(const document* doc);
        ~counted_selection();
        counted_selection(const counted_selection&)            = delete;
        counted_selection& operator=(const counted_selection&) = delete;
    };

    // Telegram (VENDOR.md edit 20): told of each change to the render tree outside a full build, at the point the fork
    // makes it. Null by default, and with none set nothing is reported and nothing behaves differently.
    struct render_observer
    {
        // item_geometry_changed's `what`.
        enum : unsigned
        {
            moved    = 1,   // the item's position (m_pos x, y) changed
            resized  = 2,   // its size, padding or borders changed
            reflowed = 4,   // an inline context: the geometry of its inline content (lines, spans, text, fragments)
        };
        virtual ~render_observer() = default;
        // replace_text_renderers (edit 16) replaced an inline context's children: the old ones go, the new ones come.
        virtual void item_added(const std::shared_ptr<render_item>& item) = 0;
        virtual void item_removed(const render_item* item) = 0;
        // Layout wrote a changed box: the value before the layout that ended against the value it left.
        virtual void item_geometry_changed(const render_item* item, unsigned what) = 0;
        // commit_patch restyled `el` and its subtree with the render tree kept (a neutral attribute change, edit 17);
        // `paint_order`: a rule that started or stopped matching declares a property that decides paint order or a
        // paint group (opacity, transform, transform-origin, filter, visibility, -lh-anim).
        virtual void element_restyled(const element* el, bool paint_order) = 0;
        // The inline context whose text pieces replace_text_renderers replaced.
        virtual void text_replaced(const render_item* inline_context) = 0;
        // Telegram (VENDOR.md edit 74): `old_item` and everything under it are gone; `new_item` and everything under it
        // are new, linked where `old_item` was, under new_item->parent() (null: the root). Told while `old_item` is
        // alive. A root that appears or goes (`display: none` on the document element) has its missing side null.
        virtual void subtree_replaced(const render_item* old_item, const std::shared_ptr<render_item>& new_item) = 0;
        // Telegram (VENDOR.md edit 89): `item` and everything under it are new, linked under item->parent(), whose other
        // children stay. Told at the end of the commit that linked it.
        virtual void subtree_linked(const std::shared_ptr<render_item>& item) = 0;
        // Telegram (VENDOR.md edit 89): `item` and everything under it are gone from under a parent whose other children
        // stay. Told at the end of the commit that unlinked it, while `item` is alive.
        virtual void subtree_unlinked(const render_item* item) = 0;
    };

    class document : public std::enable_shared_from_this<document>
    {
      public:
        bool take_table_cells(int count);
        // Telegram (VENDOR.md edit 20): the render observer, and the layout bookkeeping that feeds it.
        void             set_render_observer(render_observer* observer);
        render_observer* get_render_observer() const { return m_render_observer; }
        uint32_t         observe_epoch() const { return m_observe_epoch; }
        void             note_observed(render_item* item) { m_observed.push_back(item); }
        render_observer*            m_render_observer = nullptr;
        uint32_t                    m_observe_epoch   = 1;
        std::vector<render_item*>   m_observed;
        std::unordered_set<const element*> m_patch_paint_order;
        void                        report_observed_geometry();
        // Telegram (VENDOR.md edit 10): the text pieces (el_text, el_space) alive in this document, counted by
        // el_text's constructor and destructor. The sites that make pieces from markup or style content ask
        // text_element_allowed() first, which at the cap reports the limit once and answers false. Form controls'
        // generated parts (el_form.cpp's append_content) do not ask: they are bounded by the host's HTML size cap.
        static constexpr int max_text_elements = 10000;
        void note_text_element(int delta) { m_text_elements += delta; }
        int  text_elements() const { return m_text_elements; }
        bool text_element_allowed();
        // Telegram (VENDOR.md edit 19): the pseudo-elements and their url() images alive in this document, counted
        // by their constructors and destructors. pseudo_element_allowed() asks before one is made: build-made
        // elements plus these stay under max_build_elements, else it reports "elements" once and answers false.
        void note_pseudo_element(int delta)
        {
            m_pseudo_elements += delta;
            note_generated_change(); // Telegram (VENDOR.md edit 84)
        }
        bool pseudo_element_allowed();
        // Telegram (VENDOR.md edit 84): generated content (::before/::after content, a form control's lh-* parts) is made
        // inside a generated_scope, so its pieces are told apart from the document's own text (the markup's and the
        // <style> sheets'). A build makes the document's text first and the generated content after, while it matches.
        class generated_scope
        {
          public:
            explicit generated_scope(document* doc) : m_doc(doc)
            {
                if(m_doc)
                    m_doc->m_making_generated++;
            }
            ~generated_scope()
            {
                if(m_doc)
                    m_doc->m_making_generated--;
            }
            generated_scope(const generated_scope&)            = delete;
            generated_scope& operator=(const generated_scope&) = delete;

          private:
            document* m_doc;
        };
        bool making_generated() const { return m_making_generated > 0; }
        // The most pieces a pseudo-element held while it made its next content (one rule's content after another's),
        // since the last style pass began: a build's count runs that much over what the content ends with.
        void note_generated_transient(int pieces) { m_generated_transient = std::max(m_generated_transient, pieces); }
        void note_generated_piece(int delta)
        {
            m_generated_pieces += delta;
            note_generated_change();
        }
        std::unordered_set<const element*> skip_paint;
        std::unordered_set<const element*> skip_background_images;
        const element* bare_effects = nullptr;
        bool bare_shadows = false;
        bool has_backdrop = false;
        std::unordered_set<const element*> skip_scroll_content;
        const element* unclipped_scroll = nullptr;
        uint64_t m_style_epoch = 0;
        // Counts style computations and structure updates, so a caller can tell nothing it derived from computed
        // styles can have changed since it last looked.
        uint64_t style_epoch() const { return m_style_epoch; }
        void     note_style_change() { m_style_epoch++; }
        uint64_t m_layout_epoch       = 1;
        static std::atomic<uint64_t> s_layout_hits;
        static std::atomic<uint64_t> s_layout_misses;
        static std::atomic<uint64_t> s_layout_mismatches;
        position m_layout_viewport;
        std::vector<render_item*> m_layout_marked;
        std::vector<render_item*> m_relayout_roots;
        struct layout_box
        {
            const render_item* item;
            position           box;
        };
        std::vector<layout_box>                      m_layout_before;
        bool                                         m_layout_before_valid = false;
        bool                                         m_layout_after_render = false;
        void     snapshot_layout();
        bool     layout_cache_enabled() const;
        bool     layout_cache_check() const;
        uint64_t layout_epoch() const { return m_layout_epoch; }
        void     invalidate_layout_cache() { m_layout_epoch++; }
        void     note_layout_hit() { s_layout_hits.fetch_add(1, std::memory_order_relaxed); }
        void     note_layout_miss() { s_layout_misses.fetch_add(1, std::memory_order_relaxed); }
        void     note_layout_check_mismatch() { s_layout_mismatches.fetch_add(1, std::memory_order_relaxed); }
        void     note_layout_dirty(render_item* item) { m_layout_marked.push_back(item); }
        void     note_relayout_root(render_item* item) { m_relayout_roots.push_back(item); }
        uint64_t m_render_tree_serial = 0;
        uint64_t m_positioned_epoch   = UINT64_MAX;
        uint64_t m_positioned_tree    = UINT64_MAX;
        bool     m_has_positioned     = false;
        using ptr      = std::shared_ptr<document>;
        using weak_ptr = std::weak_ptr<document>;

      private:
        std::shared_ptr<element>                m_root;
        std::shared_ptr<render_item>            m_root_render;
        document_container*                     m_container;
        fonts_map                               m_fonts;
        css_text::vector                        m_css;
        litehtml::css                           m_styles;
        litehtml::web_color                     m_def_color;
        litehtml::css                           m_master_css;

      public:
        const litehtml::css& master_css() const { return m_master_css; }
        const litehtml::css& user_css() const { return m_user_css; } // Telegram (VENDOR.md edit 21)
        const litehtml::css& author_css() const { return m_styles; } // Telegram (VENDOR.md edit 79)

      private:
        litehtml::css                           m_user_css;
        litehtml::size                          m_size;
        position::vector                        m_fixed_boxes;
        std::shared_ptr<element>                m_over_element;
        std::shared_ptr<element>                m_active_element;
        std::list<std::shared_ptr<render_item>> m_tabular_elements;
        media_query_list_list::vector           m_media_lists;
        media_features                          m_media;
        std::string                             m_lang;
        std::string                             m_culture;
        std::string                             m_text;
        document_mode                           m_mode      = no_quirks_mode;
        bool                                    m_finalized = false;
        std::map<std::string, css_properties>   m_share_cache;
        int                                     m_next_share_id = 0;
        // Telegram: set when a style resolved a vw/vh/vmin/vmax length (see viewport_changed).
        mutable bool                            m_viewport_units = false;
        int                                     m_build_depth    = 0;
        int                                     m_build_elements = 0;
        bool                                    m_build_limited  = false;
        // Telegram (VENDOR.md edit 10). The allowance is the count of the pieces a structure patch replaces, while it
        // makes their replacements and the replaced ones are still alive.
        std::atomic<int>                        m_text_elements{0};
        std::atomic<int>                        m_pseudo_elements{0}; // Telegram (VENDOR.md edit 19)
        bool                                    m_pseudo_limited = false;
        // Telegram (VENDOR.md edit 21): the style-byte budget. Charged while an author or user sheet is applied.
        size_t                                  m_style_bytes    = 0;
        bool                                    m_style_limited  = false;
        uint32_t                                m_style_budget_epoch = 0; // Telegram (VENDOR.md edit 60)
        bool                                    m_style_charging = false;
        int                                     m_style_sheet    = 0;
        mutable long long                       m_style_rule_bytes = -1; // the payload of the largest value of each property in the author and user sheets
        bool                                    m_text_limited   = false;
        int                                     m_text_allowance = 0;
        // Telegram (VENDOR.md edit 16): a text patch session, from the first replace_text to commit_patch. The base is
        // m_text_elements when it began and the growth the net pieces added since, which the cap counts (the replaced
        // pieces stay alive until the render tree lets go of them).
        bool                                    m_patch_pending   = false;
        bool                                    m_patch_keep_tree = true;
        // Telegram (VENDOR.md edit 73): the first reason the session gave up its render tree, and the last commit's.
        std::string                             m_patch_rebuild_reason;
        std::string                             m_rebuild_reason;
        std::string                             m_retag_reason;
        // Telegram (VENDOR.md edit 90): whether the last rematch changed what the element matches (a rule started or
        // stopped matching, or its declarations changed); the elements commit_patch matched again to no change, which it
        // restyles and does not report (a later rematch that changes one takes it out).
        bool                                    m_rematch_changed = true;
        std::unordered_set<const element*>      m_patch_quiet;
        void note_rebuild(std::string why)
        {
            if(m_patch_rebuild_reason.empty())
                m_patch_rebuild_reason = std::move(why);
        }
        int                                     m_patch_text_base = 0;
        int                                     m_patch_growth    = 0;
        std::vector<std::shared_ptr<element>>   m_patch_new_text;
        // Telegram (VENDOR.md edit 17): the elements set_element_attribute re-matched in the session, which commit_patch
        // restyles.
        std::vector<std::shared_ptr<element>>   m_patch_restyle;
        // Telegram (VENDOR.md edit 42): the parents whose children the session changed and a subject positional rule
        // reaches (positions_reach): commit_patch matches their element children again.
        std::vector<std::shared_ptr<element>>   m_patch_position_parents;
        // The parents asked in the session that it reaches no child of: removals keep them so, an insertion of an element a
        // rule names asks again.
        std::unordered_set<const element*>      m_patch_position_unreached;
        // Telegram (VENDOR.md edit 88): with :empty in the sheets, the parents the session's changes of children touched,
        // each with whether it was empty (:empty's answer) before the session's first change.
        std::vector<std::pair<std::shared_ptr<element>, bool>> m_patch_empty_parents;
        std::unordered_set<const element*>      m_patch_empty_noted;
        // Telegram (VENDOR.md edit 74): what decides where a patch replaces render subtrees. An element's outer box, the
        // part of its style its parent's render structure reads; the session's seeds (the elements the sites that give
        // up the kept tree changed); the outer boxes of the seeds and their ancestors as they were before the session
        // (record_boxes, first value wins); and the items replaced since the last layout, alive until it runs.
        struct outer_box
        {
            style_display    display;
            element_float    floating;
            element_position position;
            bool             operator==(const outer_box&) const = default;
        };
        static outer_box                        outer_box_of(const element& el);
        void                                    record_boxes(const std::shared_ptr<element>& seed);
        void                                    note_replacement(const std::shared_ptr<element>& seed, std::string why);
        std::vector<std::shared_ptr<element>>   replacement_boundaries(const std::vector<std::shared_ptr<element>>& seeds,
                                                                       const std::unordered_map<const element*, outer_box>& boxes) const;
        std::vector<std::shared_ptr<element>>   m_patch_seeds;
        // Telegram (VENDOR.md edit 17): the session's matched-again elements that declared custom properties before or
        // after; commit_patch matches again the elements below them that read var().
        std::vector<std::shared_ptr<element>>   m_patch_custom_tops;
        // Telegram (VENDOR.md edit 17): how many elements' styles read var() (html_tag::reads_var).
        int                                     m_var_readers = 0;
        // Telegram (VENDOR.md edit 78): the session matched a counted element again, took one away or added one, so
        // commit_patch runs the counters again (rerun_counters).
        bool                                    m_patch_counters = false;
        // Telegram (VENDOR.md edit 77): the elements the last commit_patch restyled, each with its subtree (not kept alive).
        std::vector<std::weak_ptr<element>>     m_last_restyled;
        std::unordered_map<const element*, outer_box> m_patch_boxes;
        std::vector<std::shared_ptr<render_item>> m_replaced_hold;
        // The replacements made and not yet told to the render observer: (old, new), the old item alive here.
        std::vector<std::pair<std::shared_ptr<render_item>, std::shared_ptr<render_item>>> m_pending_replacements;
        // Telegram (VENDOR.md edit 89): the parents whose children the session inserted or removed, each once, with the
        // first of those operations ("insert", "remove") and (edit 90) the earliest child
        // index any of them changed; the links and unlinks made and not yet told to the render observer (an unlinked item
        // alive here and in m_replaced_hold).
        struct structure_change
        {
            std::shared_ptr<element> parent;
            const char*              op;
            size_t                   first;
        };
        std::vector<structure_change>           m_patch_structure;
        std::unordered_map<const element*, size_t> m_patch_structure_noted; // its place in m_patch_structure
        std::vector<std::shared_ptr<render_item>> m_pending_links;
        std::vector<std::shared_ptr<render_item>> m_pending_unlinks;
        void note_structure(const std::shared_ptr<element>& parent, const char* op, size_t index);
        mutable uint64_t                        m_replacement_steps = 0;
        // Telegram (VENDOR.md edit 17): pieces the session replaced or forgot (replaced text, a re-matched element's
        // pseudo-element content), kept alive until commit_patch and not counted by text_element_allowed, so that a patch
        // counts what a fresh build would; the count of the text pieces they hold.
        std::vector<std::shared_ptr<element>>   m_patch_hold;
        int                                     m_patch_released = 0;
        // pseudo_content_possible (bit 1, and bit 2 for a form control's parts' content); -1 until computed.
        mutable int                             m_pseudo_content = -1;
        uint64_t                                m_predicate_steps = 0; // Telegram (VENDOR.md edit 21)
        // Telegram (VENDOR.md edit 84): the generated pieces alive, and what the session released of them and of the
        // pseudo-elements; generated content made or dropped in the session (outside a re-match that made it equal); the
        // document's text and the style bytes when the session began; the replays and the last one's steps; the limits
        // the latest style pass reached.
        int                                     m_making_generated        = 0;
        int                                     m_generated_pieces        = 0;
        int                                     m_generated_transient     = 0;
        // The elements alive that a master content rule names as its subject (a build's master pass makes their
        // content before the author pass can drop it), and, read from the master sheet when first asked, the most text
        // pieces one such rule makes (max_text_elements for content that is not literal strings) and the subjects.
        int                                     m_master_content_elements = 0;
        mutable int                             m_master_content_pieces   = -1;
        mutable bool                            m_master_content_any      = false;
        mutable std::vector<string_id>          m_master_content_tags;
        int                                     m_patch_released_generated = 0;
        int                                     m_patch_pseudo_released   = 0;
        bool                                    m_generated_watch         = false;
        bool                                    m_generated_changed       = false;
        int                                     m_rematching              = 0;
        int                                     m_session_document_text   = 0;
        size_t                                  m_session_style_bytes     = 0;
        int                                     m_session_build_elements  = 0;
        uint64_t                                m_generated_replays       = 0;
        int64_t                                 m_replay_step_limit       = INT64_MAX;
        int64_t                                 m_last_replay_steps       = 0;
        int64_t                                 m_last_replay_weight      = 0;
        int64_t                                 m_last_replay_visits      = 0;
        bool                                    m_last_replay_cut         = false;
        bool                                    m_match_cut               = false;
        std::vector<std::string>                m_style_pass_limits;
        bool                                    m_recording_style_pass    = false;
        void note_generated_change()
        {
            if(m_generated_watch && m_rematching == 0)
                m_generated_changed = true;
        }
        void begin_generated_watch();
        void note_style_pass_limit(const char* kind);
        uint64_t                                m_attribute_rematches = 0;
        // Telegram (VENDOR.md edit 18): the subtrees insert_subtree linked in the session, which
        // commit_patch styles as a fresh subtree is styled.
        std::vector<std::shared_ptr<element>>   m_patch_inserted;
        // Telegram (VENDOR.md edit 18): the tags the ::before/::after content rules name, and whether one could make a
        // form control's parts' content (it names an lh-* part, or `*`); read from the sheets once (they never change
        // after finalize).
        // Telegram (VENDOR.md edit 18): the selector-step session begin_selector_steps opened on this thread.
        selector_step_session                   m_step_session;
        bool                                    m_step_session_open  = false;
        bool                                    m_step_session_auto  = false;   // opened by a patch session
        // Telegram (VENDOR.md edit 18): finalize's matching gate (set_matching_gate), and whether it declined.
        std::function<bool(size_t, size_t)>     m_matching_gate;
        bool                                    m_matching_gated     = false;
        // Telegram (VENDOR.md edit 26): the host's declarations for the root element (set_root_declarations).
        style                                   m_root_declarations;
        bool                                    m_has_root_declarations = false;
        std::string                             m_root_declarations_text; // Telegram (VENDOR.md edit 80)
        // Telegram (VENDOR.md edit 81): finalize has parsed the sheets (add_stylesheet adds none after), and the session
        // changed a <style>'s text or linked or unlinked one (commit_patch applies the sheets first).
        bool                                    m_sheets_parsed = false;
        bool                                    m_patch_sheets  = false;
        int                                     m_selector_scope = -1;
        // Telegram (VENDOR.md edit 42): the rules whose positional pseudo-classes are in their subject alone (selector_scope
        // bit 16): the subject's tag and, under a child combinator, its parent's (star_id: any).
        struct subject_position
        {
            string_id tag;
            string_id parent;
        };
        std::vector<subject_position>           m_subject_positions;
        // Telegram (VENDOR.md edit 90): a positional pseudo-class that reads following siblings outside a rule's subject;
        // one with an `of S` list that reads them, anywhere.
        bool                                    m_backward_positions = false;
        bool                                    m_backward_of_lists  = false;
        uint64_t                                m_position_scans = 0;
        int                                     m_ids_selectable = -1;
        std::unordered_set<string_id>           m_left_classes;
        std::unordered_set<string_id>           m_left_ids;
        std::unordered_set<string_id>           m_left_attrs;
        std::unordered_set<string_id>           m_left_pseudo; // Telegram (VENDOR.md edit 75)
        // Telegram (VENDOR.md edit 75): each pseudo-class's rules, the ones that name it anywhere (inside :is() too).
        std::unordered_map<string_id, std::vector<const css_selector*>> m_pseudo_class_rules;
        // Telegram (VENDOR.md edit 77): each class's, id's and attribute name's rules, the ones that name it anywhere
        // (inside :is() too; :checked, :disabled, :enabled, :link and :lang() name the attributes they read).
        std::unordered_map<string_id, std::vector<const css_selector*>> m_class_rules;
        std::unordered_map<string_id, std::vector<const css_selector*>> m_id_rules;
        std::unordered_map<string_id, std::vector<const css_selector*>> m_attr_rules;
        // Telegram (VENDOR.md edit 77): the session's attribute changes whose names reach beyond their elements, each
        // with its attributes before the session; matched over their reach by match_attribute_reach.
        std::vector<std::pair<std::shared_ptr<element>, string_map>> m_patch_attribute_changes;
        static constexpr int                    max_build_depth    = 256;
        static constexpr int                    max_build_elements = 20000;
        static constexpr int                    max_table_cells    = 200000;
        int                                     m_table_cells      = 0;
        bool                                    m_table_limited    = false;
        bool                                    m_table_quiet      = false; // Telegram (VENDOR.md edit 84)
        std::string                             m_master_styles;
        mutable uint32_t                        m_paint_generation = 1;
        uint64_t                                m_match_epoch      = 1;
        // Telegram (VENDOR.md edit 76): refusal(); refuse sets it and answers false.
        mutable const char*                     m_refusal          = "";
        bool refuse(const char* why) const
        {
            m_refusal = why;
            return false;
        }
        // Telegram (VENDOR.md edit 39): intrinsic-width measuring passes under way, and keyword boxes laying out in full
        // around the box being laid out.
        mutable int                             m_intrinsic_measuring = 0;
        mutable int                             m_intrinsic_depth     = 0;
        // Telegram (VENDOR.md edit 38): the elements every <svg> drew inside <use> instances at its last paint, and the
        // document's ids for <use>, gathered once per match epoch and paint generation.
        mutable int                                                   m_use_instanced = 0;
        mutable std::unordered_map<std::string, std::weak_ptr<element>> m_svg_ids;
        mutable uint64_t                                              m_svg_ids_epoch      = 0;
        mutable uint32_t                                              m_svg_ids_generation = 0;
        bool                                    m_has_svg          = false;
        bool                                    m_cull_paint       = false;
        std::unordered_map<const void*, std::vector<size_t>> m_node_holes;

      public:
        bool style_sharing_enabled() const;
        bool ids_selectable();
        int  next_share_id()
        {
            return ++m_next_share_id;
        }
        const css_properties* share_lookup(const std::string& key) const
        {
            auto it = m_share_cache.find(key);
            return it == m_share_cache.end() ? nullptr : &it->second;
        }
        void share_store(const std::string& key, const css_properties& props)
        {
            m_share_cache[key] = props;
        }

        document(document_container* objContainer);
        virtual ~document();

        document_container* container() const
        {
            return m_container;
        }
        document_mode mode() const
        {
            return m_mode;
        }
        uint_ptr  get_font(const font_description& descr, font_metrics* fm);
        pixel_t   render(pixel_t max_width, render_type rt = render_all);
        void      draw(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip, bool cull = false);
        uint32_t  paint_generation() const { return m_paint_generation; }
        // Telegram (VENDOR.md edit 39).
        int&      intrinsic_measuring() const { return m_intrinsic_measuring; }
        int&      intrinsic_depth() const { return m_intrinsic_depth; }
        // Telegram (VENDOR.md edit 38).
        int&                  use_instanced() const { return m_use_instanced; }
        std::shared_ptr<element> svg_element_by_id(const std::string& id) const;
        void      note_svg() { m_has_svg = true; }
        bool      has_svg() const { return m_has_svg; }
        void      invalidate_paint() const { m_paint_generation = m_paint_generation + 1 == 0 ? 1 : m_paint_generation + 1; }
        bool      culls_paint() const { return m_cull_paint; }
        void      set_culls_paint(bool cull) { m_cull_paint = cull; }
        web_color get_def_color() const
        {
            return m_def_color;
        }
        void                         cvt_units(css_length& val, const font_metrics& metrics, pixel_t size) const;
        // Telegram (VENDOR.md edit 48): what a calc's font-relative terms are worth for `metrics`.
        calc_fonts                   calc_fonts_for(const font_metrics& metrics) const;
        pixel_t                      to_pixels(const css_length& val, const font_metrics& metrics, pixel_t size) const;
        pixel_t                      width() const;
        pixel_t                      height() const;
        pixel_t                      content_width() const;
        pixel_t                      content_height() const;
        void                         add_stylesheet(const char* str, const char* baseurl, const char* media);
        bool                         on_mouse_over(pixel_t x, pixel_t y, pixel_t client_x, pixel_t client_y,
                                                   const std::function<void(const position&)>& redraw_box);
        std::vector<scroll_values>   on_scroll(pixel_t dx, pixel_t dy, pixel_t x, pixel_t y, pixel_t client_x,
                                               pixel_t client_y) const;
        bool                         on_lbutton_down(pixel_t x, pixel_t y, pixel_t client_x, pixel_t client_y,
                                                     const std::function<void(const position&)>& redraw_box);
        bool                         on_lbutton_up(pixel_t x, pixel_t y, pixel_t client_x, pixel_t client_y,
                                                   const std::function<void(const position&)>& redraw_box);
        bool                         on_button_cancel(const std::function<void(const position&)>& redraw_box);
        bool                         on_mouse_leave(const std::function<void(const position&)>& redraw_box);
        std::shared_ptr<element>     create_element(const char* tag_name, const string_map& attributes);
        std::shared_ptr<element>     root();
        std::shared_ptr<render_item> root_render();
        void                         get_fixed_boxes(position::vector& fixed_boxes);
        void                         add_fixed_box(const position& pos);
        void                         add_media_list(const media_query_list_list::ptr& list);
        // Telegram (VENDOR.md edit 73): why the last commit_patch, media_changed or viewport_changed re-created the render
        // tree ("structure: insert", "attribute: cx", "property: display", "rule: position", "media", …); "" when it
        // kept it.
        const std::string&           rebuild_reason() const { return m_rebuild_reason; }
        bool                         media_changed();
        // Telegram: re-reads the media features after the container's viewport moved (see document.cpp).
        bool                         viewport_changed();
        bool                         lang_changed();
        bool                         match_lang(const std::string& lang);
        void                         add_tabular(const std::shared_ptr<render_item>& el);
        std::shared_ptr<const element> get_over_element() const
        {
            return m_over_element;
        }

        void append_children_from_string(element& parent, const char* str, bool replace_existing);
        void dump(dumper& cout);

        // see doc/document_createFromString.txt
        static document::ptr createFromString(const estring& str, document_container* container,
                                              const std::string& master_styles = litehtml::master_css,
                                              const std::string& user_styles   = {});


        // The mode must be set before any element is created, because it is used in html_tag::set_attr.
        void set_document_mode(document_mode mode);
        // Finish a document whose element tree was built by the caller with create_element() and
        // element::appendChild() instead of being parsed from an HTML string. Runs the same
        // finalization sequence createFromString() runs after parsing. A document is finalized
        // once, when its tree is complete; any further call does nothing.
        void finalize_from_external_root(const std::shared_ptr<element>& root,
                                         const std::string&              master_styles = litehtml::master_css,
                                         const std::string&              user_styles   = {});
        // Telegram (VENDOR.md edit 12): building a document from an external DOM.
        // Splices `child` into `parent`'s children at `index` (0 = first, childCount = last) and sets its parent.
        void insert_child(const std::shared_ptr<element>& parent, size_t index, const std::shared_ptr<element>& child);
        // Unlinks `child` from its parent; re-points the hover/active elements to the nearest still-attached ancestor.
        void remove_child(const std::shared_ptr<element>& child);
        // Telegram (VENDOR.md edit 21): what `root` and its subtree hold of the style budget is given back; each element
        // leaving the tree (remove_child, a forgotten pseudo-element) goes through it.
        void release_style_charges(const std::shared_ptr<element>& root);
        // Appends `text` to `parent` as litehtml pieces, as create_node does for a gumbo text node: one piece inside a
        // raw-text parent (<style>), else split_text's words and one el_space per whitespace character. Each piece asks
        // text_element_allowed() first; at the cap it stops and answers false. `pieces` gets every piece appended.
        bool append_text(const std::shared_ptr<element>& parent, const char* text, std::vector<std::shared_ptr<element>>& pieces);
        // create_node's cap check (document.cpp:2586) for a builder outside create_node. `depth` is the new element's
        // nesting depth as m_build_depth counts it (0 at the root). Answers false when depth >= max_build_depth or the
        // document already holds max_build_elements built elements, calling sanitizer_limit("depth") or ("elements") as
        // create_node does; a true answer counts the element.
        bool external_element_allowed(int depth);
        // Telegram (VENDOR.md edit 16): text patched in place. Replaces `count` pieces of `parent`, starting at child
        // index `first`, with `text` split as append_text splits it (new pieces, even when the count is the same), and
        // collects what commit_patch restyles. Answers false, changing nothing, when can_replace_text does.
        // On true `pieces` holds the new pieces (assigned, not appended).
        bool replace_text(const std::shared_ptr<element>& parent, size_t first, size_t count, const char* text,
                          std::vector<std::shared_ptr<element>>& pieces);
        // Whether replace_text(parent, first, count, text, ...) would succeed. False for: a raw-text parent; a parent
        // inside a form control (select, option, optgroup, datalist, textarea, input, progress, meter) or an
        // svg, whose generated content or drawing reads its text; a run that is not `count` text pieces; and a text
        // that would take the document past the text cap. `pending_growth` is the net piece growth of replacements
        // already planned but not yet made (new minus old pieces), which the cap counts. `growth`, when given, gets
        // this replacement's net growth (new minus old pieces). The cap counts logically: a session's replaced pieces
        // do not count even while something still holds them.
        bool can_replace_text(const std::shared_ptr<element>& parent, size_t first, size_t count, const char* text,
                              int pending_growth = 0, int* growth = nullptr) const;
        // Applies what replace_text collected: restyle_after_patch over the new pieces, with the render tree kept when
        // every replacement could be kept (replace_text_renderers) and rebuilt from the root otherwise. Does nothing
        // when nothing was collected. The caller lays out afterwards (render()).
        void commit_patch();
        // Telegram (VENDOR.md edit 17): attributes and inline style patched in place. Sets (value != nullptr) or removes one
        // attribute of `el` and re-matches it, as apply_retag does, with the match epoch bumped first; the work joins the
        // patch session commit_patch ends. Form controls (an input) re-run their parse_attributes with children swapped
        // out. Answers false, changing nothing, where litehtml.md section (c) 3-5 says the change cannot be patched: an
        // element outside the types apply_retag re-reads completely (restylable_in_place's, and img, a, input, svg), one
        // that is not in the document or sits inside a <select>, and the caps (edits 17, 19). A name in an ancestor position
        // of a selector, sibling selectors, counters (edit 78) and an inline style touching --* or var( are patched over
        // what they reach. Setting what is already there answers true and changes nothing.
        bool set_element_attribute(const std::shared_ptr<element>& el, const char* name, const char* value);
        // Whether set_element_attribute(el, name, value) would answer true, for a caller that plans every change of a
        // flush before it makes the first. A change is judged on its own against the attributes as they are now, so
        // changes to different attributes of one element do not depend on each other.
        bool can_set_element_attribute(const std::shared_ptr<element>& el, const char* name, const char* value);
        // What a patch can add to the table-cell cap (colspan and rowspan), which a caller planning several changes
        // threads through each can_set_element_attributes; an accepted element adds its bound.
        struct attribute_growth
        {
            int cells = 0;
        };
        // Whether a ::before or ::after rule that declares `content` (other than none) could match an element of this
        // document: judged from the selectors as litehtml parsed them in the master, author and host sheets (a
        // pseudo-element in the rightmost compound plus a `content` declaration; a rule naming a tag counts only when the
        // document has an element with it). Matching an element again makes its pseudo-element content again, and a
        // build makes all of it after the text, in document order, so at the text-piece cap a patch and a rebuild cut at
        // different words: while this is true can_replace_text and can_set_element_attributes refuse once a cap has been
        // reached, and a patch that reaches one posts the limit (the caller rebuilds). Computed on the first query after a
        // finalize or a commit_patch (a patch can add elements: a form control makes its lh-* parts again), so it follows
        // the tree as it is. The walk of the tree is O(elements); a caller that charges its work pays for it
        // (WidgetRuntime charges the build's element count before asking).
        bool pseudo_content_possible() const;
        // Telegram (VENDOR.md edit 21): the heap the declared values copied onto elements may hold (see payload_bytes), per
        // document; the master sheet is not charged. Past it the elements get no further author or user declarations and
        // the container is told sanitizer_limit("style-bytes") once.
        static constexpr size_t max_style_bytes = 16u * 1024u * 1024u;
        size_t style_bytes_charged() const { return m_style_bytes; }
        // Telegram (VENDOR.md edit 60): counts the budget's restarts from zero (refresh_all_styles), which no charge made
        // before one survives.
        uint32_t style_budget_epoch() const { return m_style_budget_epoch; }
        // Telegram (VENDOR.md edit 60): charges a list item's inherited bullet URL, up to half the budget (the declarations
        // keep the rest); false, charging nothing and latching nothing, past it or once the budget was passed.
        bool   style_charge_bullet(size_t bytes, size_t& charged)
        {
            charged = 0;
            if(m_style_limited || bytes > max_style_bytes / 2 || m_style_bytes + bytes > max_style_bytes / 2)
                return false;
            m_style_bytes += bytes;
            charged = bytes;
            return true;
        }
        bool   style_bytes_limited() const { return m_style_limited; }
        // Telegram (VENDOR.md edit 21): the elements can_set_element_attributes has visited so far (its subtree bound).
        uint64_t predicate_steps() const { return m_predicate_steps; }
        // Telegram (VENDOR.md edit 17): whether the text-piece cap and the pseudo-element cap have been reached.
        bool   text_limited() const { return m_text_limited; }
        // Telegram (VENDOR.md edit 84): the document's own text pieces alive (all of text_elements() but generated
        // content's), less those the patch session released: what the text-piece cap counts first, as a build makes them.
        int    document_text_pieces() const;
        // Asked after the commit's own matching, `restyling` when the commit restyles anything: whether the generated content
        // or the style budget may now be cut elsewhere than a fresh build cuts them. True past the style budget for any
        // restyle; else when the session changed what the cut reads (generated content made or dropped and not made again
        // equal, the document's text pieces, the style bytes, the elements) and the pseudo-element cap was reached or the
        // elements and pseudo-elements pass it, or the text-piece cap was reached with content rules in the sheets, or the
        // generated pieces could reach it (a build makes an element's content again for each rule while the last is
        // alive: the document's text, the generated pieces and the most a pseudo-element held while making its next
        // content reach max_text_elements). A build's master pass gives every element a master content rule names its
        // content before the author pass can drop it, so those elements count at their most toward both caps
        // (master_content_owner). A restyle that passes the style budget replays after it (commit_patch). True at the
        // first commit after note_match_cut, whatever changed.
        bool   generated_cut_in_play(bool restyling) const;
        // Marks a document whose build's matching its selector-step session cut: a fresh build that cut nowhere would match
        // every element, so the next commit replays the style pass (within set_replay_step_limit), and the mark goes.
        void   note_match_cut() { m_match_cut = true; }
        // Whether a master sheet content rule (`::before`/`::after` with content) names `el`'s tag as its subject.
        bool   master_content_owner(const element& el) const;
        int    master_content_pieces() const;
        void   count_master_content_owners();
        // The style pass again from zero over the whole tree, in a build's order: every pseudo-element and part set aside,
        // the caps' flags and the style budget reset, then each element matched again pass by pass (the master sheet,
        // its attributes, the author sheets, the host sheet) as rerun_counters matches, making generated content as a
        // build makes it. Where an element's generated content comes out equal, its old elements go back with the new
        // match's styles; elsewhere the element is a replacement seed. Every element is restyled at the commit.
        void   replay_generated_content();
        // The most selector steps the session may have counted when the replay ends, the patch's own and the replay's (no
        // limit by default); a replay cut there sets last_replay_cut().
        void   set_replay_step_limit(int64_t limit) { m_replay_step_limit = limit; }
        int64_t last_replay_steps() const { return m_last_replay_steps; }
        // What the replay matched every rule against (matching_weight summed over its elements, as a patch's re-match is
        // weighed), and the nodes its walks visited, which no step counts.
        int64_t last_replay_weight() const { return m_last_replay_weight; }
        int64_t last_replay_visits() const { return m_last_replay_visits; }
        bool    last_replay_cut() const { return m_last_replay_cut; }
        uint64_t generated_replays() const { return m_generated_replays; }
        // Telegram (VENDOR.md edit 42): the children positions_reach has visited, for tests.
        uint64_t position_scans() const { return m_position_scans; }
        // The limits the latest style pass (a build's matching, or a replay) reached, in the order first reached, by
        // sanitizer_limit's names ("text", "elements", "style-bytes"), then "table" when the table-cell cap cut the
        // render tree.
        std::vector<std::string> style_pass_limits() const;
        // Telegram (VENDOR.md edit 83): the elements external_element_allowed counted, and the pseudo-elements alive.
        int    build_elements() const { return m_build_elements; }
        int    pseudo_elements() const { return m_pseudo_elements; }
        bool   pseudo_limited() const { return m_pseudo_limited; }
        bool   table_limited() const { return m_table_limited; } // Telegram (VENDOR.md edit 84)
        bool   style_charging() const { return m_style_charging; }
        void   set_style_charging(bool on) { m_style_charging = on; }
        // Charges `st` when an author or user sheet is being applied (answers true, charging nothing, otherwise); answers
        // false, charging nothing, when it would pass the budget or the budget was passed already.
        bool   style_admit(const style& st, const style& onto, size_t& charged);
        void   style_refund(size_t bytes) { m_style_bytes = bytes > m_style_bytes ? 0 : m_style_bytes - bytes; }
        // True when the budget was passed, or when restyling `elements` elements could reach it (the largest value of each property in the author
        // and user sheets on each); a patch refuses then, as pseudo_cap_in_play does. Coarse on purpose.
        bool   style_budget_in_play(long long elements) const;
        // Charges a var() splice of `bytes` whatever sheet is being applied (the values come from author and user sheets);
        // false, charging nothing, when it would pass the budget or the budget was passed already.
        bool   style_splice(size_t bytes, size_t& charged);
        int    style_sheet() const { return m_style_sheet; }
        void   set_style_sheet(int sheet) { m_style_sheet = sheet; }
        // refresh_styles for the whole tree. Where the replay could pass the style-byte budget (or did) it charges from
        // zero in the order a build does, so the result is a rebuild's.
        void   refresh_all_styles();
        // Replaces ALL attributes of `el` with `attrs` (lowercased names; litehtml's own list_index is kept) and re-matches
        // the element once. Answers false, changing nothing, where can_set_element_attributes does.
        bool set_element_attributes(const std::shared_ptr<element>& el, const string_map& attrs);
        // The predicate for the above (the same rules as set_element_attribute, judged over the whole difference), plus
        // pseudo_content_possible() and the table-cell cap. Counts what
        // `pending` already holds; on true adds this element's bound to it. Null `pending` counts nothing pending.
        bool can_set_element_attributes(const std::shared_ptr<element>& el, const string_map& attrs, attribute_growth* pending = nullptr);
        // Telegram (VENDOR.md edit 75): one element's pseudo-classes (:hover, :active) to set (true) or clear.
        using pseudo_flip = std::pair<std::shared_ptr<element>, std::vector<std::pair<string_id, bool>>>;
        // The flips set together, and what they reach matched again in the patch session commit_patch ends: each element;
        // its descendants when a rule names a changed class in a compound that is not its subject (m_left_pseudo); its
        // siblings and their descendants when the sheets have sibling combinators or `of S` lists. Each element keeps the
        // render tree or seeds a replacement as an attribute change's does (rematch). Answers false, changing nothing,
        // where can_set_pseudo_classes does; true and nothing changed when every class is already as asked.
        bool set_pseudo_classes(const std::vector<pseudo_flip>& flips);
        // Whether set_pseudo_classes would answer true: each element an element of the document under the root, not
        // generated content and not inside a <select>; and the caps, as can_set_element_attributes checks them (the pseudo-element cap with two for each element of the
        // reach, pseudo-element content at a cap). Each ancestor visited is a predicate step.
        bool can_set_pseudo_classes(const std::vector<pseudo_flip>& flips);
        // What set_pseudo_classes matches again, each element once; each element visited a predicate step, each once.
        std::vector<std::shared_ptr<element>> pseudo_reach(const std::vector<pseudo_flip>& flips);
        // Telegram (VENDOR.md edit 77): what an attribute change whose names a rule reads beyond the element matches again,
        // each element once: for each (element, attributes on the other side of the change), the element's subtree when
        // a changed class, id or attribute name is in an ancestor position (m_left_*), and with sibling selectors or
        // `of S` lists in the sheets every sibling's subtree too. Each element visited is a predicate step.
        std::vector<std::shared_ptr<element>> attribute_reach(
            const std::vector<std::pair<std::shared_ptr<element>, const string_map*>>& changes);
        // Telegram (VENDOR.md edit 77): the elements the last commit_patch restyled, and the subtrees it styled fresh, each
        // with its subtree, that are still alive (a caller's style-change step looks at what a patch restyled as at what a
        // build styled; a subtree inserted for a kept element built again is restyled to it); taken, not kept.
        std::vector<std::shared_ptr<element>> take_restyled()
        {
            std::vector<std::shared_ptr<element>> out;
            for(const auto& weak : m_last_restyled)
            {
                if(auto el = weak.lock())
                    out.push_back(std::move(el));
            }
            m_last_restyled.clear();
            return out;
        }
        // Telegram (VENDOR.md edit 17): the elements below `tops` whose styles read var(), each once (commit_patch matches
        // them again below an element whose custom properties may have changed); each element visited a predicate step.
        // Empty, walking nothing, when no element reads var().
        std::vector<std::shared_ptr<element>> var_readers(const std::vector<std::shared_ptr<element>>& tops);
        // Telegram (VENDOR.md edit 78): the counted elements (html_tag::counted), which commit_patch matches again when
        // the session touched one; each element visited a predicate step. Empty, walking nothing, when the sheets use no
        // counters.
        std::vector<std::shared_ptr<element>> counted_elements();
        // Telegram (VENDOR.md edits 79, 80): what applying the media features `next` (and, with `declarations_changed`,
        // new root declarations) matches again: the users of rules whose media list would flip, the elements whose style
        // read a part of the environment that changes (the viewport, the scheme), and with `declarations_changed` the
        // root; each element walked a predicate step.
        std::vector<std::shared_ptr<element>> environment_reach(const media_features& next, bool declarations_changed);
        // Telegram (VENDOR.md edits 79, 80): the container's media features read again and applied in the patch session
        // (opened here unless one is): the users of rules whose media list flipped are matched again, and when the
        // viewport or the scheme changed, the sheets and root declarations are parsed again and the elements whose style
        // read it are matched again with their subtrees. commit_patch completes it. Whether any media feature changed.
        bool environment_changed();
        // Whether the sheets use counters (selector_scope() & 4).
        bool counters_in_sheets() { return (selector_scope() & 4) != 0; }
        // html_tag's count of the elements whose styles read var().
        void note_var_reader(bool reads) { m_var_readers += reads ? 1 : -1; }
        // Telegram (VENDOR.md edit 77): the class, id and attribute names that differ between two attribute maps.
        struct name_change
        {
            std::unordered_set<string_id> classes;
            std::unordered_set<string_id> ids;
            std::unordered_set<string_id> attrs;
        };
        name_change changed_names(const string_map& before, const string_map& after) const;
        // Whether a rule reads one of `names` in an ancestor position (m_left_*).
        bool names_reach_others(const name_change& names);
        // Whether any rule names one of `names` (m_class_rules, m_id_rules, m_attr_rules): a change of no named name
        // changes no element's match.
        bool names_named(const name_change& names);
        // Adds `top` (with its subtree when `subtree`) to `reach`, each element once: a walk stops at what is already taken
        // with its subtree; each element visited a predicate step (pseudo_reach, attribute_reach).
        void take_reach(const std::shared_ptr<element>& top, bool subtree, std::vector<std::shared_ptr<element>>& reach,
                        std::unordered_set<const element*>& taken, std::unordered_set<const element*>& whole);
        // The candidates whose match by one of `rules` differs with a change made and undone by `apply` (the change applied
        // on entry and on return), a run of 256 at a time (set_pseudo_classes, match_attribute_reach).
        std::vector<std::shared_ptr<element>> differing_matches(const std::vector<std::shared_ptr<element>>& candidates,
                                                                const std::vector<const css_selector*>& rules,
                                                                const std::function<void(bool)>& apply);
        // Matches `reach` again in the session: each keeps the render tree or seeds a replacement (rematch), and the
        // reach's tops are restyled with their subtrees.
        void rematch_reach(const std::vector<std::shared_ptr<element>>& reach);
        // The session's attribute changes recorded for their reach, matched over it (edit 77); at the first of
        // set_pseudo_classes and commit_patch, so before the session's pseudo-class flips.
        void match_attribute_reach();
        // rematch's: `el` declared custom properties before or after it was matched again (m_patch_custom_tops).
        void note_custom_top(const std::shared_ptr<element>& el)
        {
            if(std::find(m_patch_custom_tops.begin(), m_patch_custom_tops.end(), el) == m_patch_custom_tops.end())
                m_patch_custom_tops.push_back(el);
        }
        // Telegram (VENDOR.md edit 76): why the last of the attribute, structure and pseudo-class predicates that answered
        // false refused, a string literal ("" before any refused).
        const char* refusal() const { return m_refusal; }
        // Re-matches made by set_element_attributes (and set_element_attribute) so far; tests.
        uint64_t attribute_rematches() const { return m_attribute_rematches; }
        // The table cells the last render-tree build counted against max_table_cells; tests.
        int table_cells() const { return m_table_cells; }
        // Telegram (VENDOR.md edit 74): `el`'s one render item in the published tree (registered, reachable from the root,
        // and outermost: its parent item is not `el`'s); null when it has none or more than one.
        std::shared_ptr<render_item> live_item(const element& el) const;
        // Telegram (VENDOR.md edit 74): the elements and render items commit_patch's replacements have stepped through;
        // tests.
        uint64_t replacement_steps() const { return m_replacement_steps; }
        // Telegram (VENDOR.md edit 18): structure patched in place. Each of these joins the patch session commit_patch
        // ends (edit 16), and commit_patch rebuilds the render tree from the root after any of them.
        // What planned structure changes add to the caps, which a caller planning several changes threads through each
        // predicate below (an accepted change adds its share): the text pieces the planned removals release (pieces
        // already made for a planned insertion count by being alive), the net elements (max_build_elements), and the
        // table cells an insertion could add (every element counted as a cell with its colspan x rowspan, an upper bound).
        struct structure_growth
        {
            int released = 0;
            int elements = 0;
            int cells    = 0;
        };
        // The depth external_element_allowed caps (an element at this depth or deeper is not built); a caller building a
        // subtree for insert_subtree stops there.
        static constexpr int max_external_depth = max_build_depth;
        // The elements external_element_allowed counts (each one a build creates, linked or not) before it refuses.
        static constexpr int max_external_elements = max_build_elements;
        // Inserts a subtree the caller built with create_element, insert_child and append_text or make_text_pieces (detached:
        // no parent) at child `index` of `parent`, and links it. commit_patch styles it as a fresh
        // subtree is styled (the master sheet, parse_attributes, the author sheets, the user sheet; the match epoch bumped), after
        // every structure change of the session, so positional matches see the final children, and marks the render tree
        // for rebuilding. Answers false, changing nothing, when can_insert_subtree does.
        bool insert_subtree(const std::shared_ptr<element>& parent, size_t index, const std::shared_ptr<element>& subtree);
        // Removes a subtree (remove_child, which re-points the hover and active elements) and marks the render tree for
        // rebuilding; its pieces stop counting against the text cap at once and stay alive until commit_patch. Answers
        // false, changing nothing, when can_remove_subtree does.
        bool remove_subtree(const std::shared_ptr<element>& subtree);
        // Telegram (VENDOR.md edit 82): the document element replaced by `root`, a detached html_tag subtree the caller
        // built as insert_subtree's, in the patch session (opened here unless one is): the old tree goes as a removal does
        // and `root` comes as an insertion does, :root and the root declarations its own, styled fresh at the commit with
        // the sheets its <style>s hold, and the render tree made again from it. False, changing nothing, where
        // can_replace_root refuses.
        bool replace_root(const std::shared_ptr<element>& root);
        // Whether insert_subtree(parent, index, subtree) would answer true, for a caller that plans every change of a flush
        // before it makes the first. False for (litehtml.md section (c) 1, 2, 4): a subtree holding a document-level
        // element (html head body style link base meta title script frameset select option optgroup datalist); a parent
        // that is not in the document, is raw text (<style>, <script>), or is inside a select, option, optgroup, datalist,
        // textarea, button, input, progress, meter or svg (their generated content or drawing reads their children); sheets
        // whose generated content a change reaches (sibling combinators, positional pseudo-classes and :empty are
        // matched again at the commit: edits 88, 90; counters run again there: edit 78); pseudo-element content at a cap: pseudo_content_possible() for the tree with the
        // subtree added (it is true, or the subtree has an element a ::before/::after content rule names by tag) while the
        // text-piece or pseudo-element cap has been reached, since a fresh build gives the pieces to content in tree order,
        // or a form control's parts' content (part_content_possible(), or a control in the subtree while an lh-* or `*`
        // content rule exists); and the caps: an element at max_build_depth or deeper, max_build_elements, the text pieces (counted logically: alive,
        // less the session's released and `pending`'s), and max_table_cells. A subtree that is not detached, and an index
        // past the end, are refused too.
        bool can_insert_subtree(const std::shared_ptr<element>& parent, size_t index, const std::shared_ptr<element>& subtree,
                                structure_growth* pending = nullptr);
        // Whether remove_subtree(subtree) would answer true: the same refusals for what it removes (a document-level element,
        // a parent inside one of those elements, the sheets' scope, pseudo-element content at a cap), and the root, a detached
        // element and generated content (::before, ::after, a form control's lh-* parts) are refused.
        bool can_remove_subtree(const std::shared_ptr<element>& subtree, structure_growth* pending = nullptr);
        // Telegram (VENDOR.md edit 82): whether replace_root would take `root`: a detached html_tag, not the document
        // element; the old tree going as can_remove_subtree asks (pseudo-element content or the pseudo-element cap at a
        // cap, a style-limited document), the new one within the depth, element, pseudo-element, text-piece and
        // table-cell caps.
        bool can_replace_root(const std::shared_ptr<element>& root, structure_growth* pending = nullptr);
        // Whether the sheets hold sibling combinators or positional pseudo-classes (selector_scope() & 3), so that a change
        // to a parent's children can change how its other children match.
        bool structure_reaches_siblings();
        // Telegram (VENDOR.md edit 42): that, or a rule whose positional pseudo-classes are in its subject alone can match
        // one of `parent`'s element children (positions_reach): a change to them then changes how the others match.
        bool structure_reaches_siblings(const std::shared_ptr<element>& parent);
        bool positions_reach(const std::shared_ptr<element>& parent);
        void note_position_parent(const std::shared_ptr<element>& parent);
        // Telegram (VENDOR.md edit 88): whether :empty is in the sheets, and whether sibling combinators are (a parent's
        // :empty can then reach its later siblings' subtrees); notes a parent the session changes the children of.
        bool empty_in_sheets() { return (selector_scope() & 8) != 0; }
        bool sibling_combinators() { return (selector_scope() & 1) != 0; }
        // Telegram (VENDOR.md edit 90): whether a positional pseudo-class that reads an element's following siblings
        // (:last-child, :last-of-type, :only-child, :only-of-type, :nth-last-child, :nth-last-of-type) is outside a rule's
        // subject compound: a change to a parent's children can then change how the children before it match.
        bool backward_positions()
        {
            selector_scope();
            return m_backward_positions;
        }
        // Telegram (VENDOR.md edit 90): whether a :nth-last-child or :nth-last-of-type with an `of S` list is in the sheets,
        // subject or not: a change of what S matches in an element's following siblings (an :empty flip, edit 88) can then
        // change how the element matches.
        bool backward_of_lists()
        {
            selector_scope();
            return m_backward_of_lists;
        }
        // The generated children of `owner` (::before, ::after, a form control's lh-* parts) by their shape and text (edit
        // 77; public for a caller's checks, edit 91).
        static std::string generated_fingerprint(const element& owner);
        void note_empty_parent(const std::shared_ptr<element>& parent);
        // The pieces append_text would append to `parent` (one in a raw-text parent, else split_text's words and one el_space
        // per whitespace character), made without a parent and without asking text_element_allowed: for a subtree that
        // insert_subtree counts, whose predicate refuses one past the cap. `pieces` gets them (appended).
        void make_text_pieces(const std::shared_ptr<element>& parent, const char* text, std::vector<std::shared_ptr<element>>& pieces);
        // Telegram (VENDOR.md edit 18): one selector-step budget per build or patch session. begin_selector_steps opens
        // the session on this thread: every outermost apply_stylesheet until end_selector_steps shares `limit` steps
        // (litehtml's own budget is 4,000,000 for each outermost pass). end_selector_steps closes it and answers the steps
        // used, more than `limit` when a selector test was refused, that is when matching was cut. A document destroyed
        // with its session open closes it. Matching replayed from an element's memo (apply_matching) counts no steps.
        // A patch session (edits 16-18: from its first change to commit_patch) opens one itself, with the default limit,
        // when none is open; a caller that wants another limit opens it first. A build (finalize) has one when its caller
        // opened it; otherwise litehtml's per-pass budget applies, as before.
        static constexpr int64_t default_selector_steps = 4000000;
        void    begin_selector_steps(int64_t limit = default_selector_steps);
        int64_t end_selector_steps();
        // The steps the open session has used so far; 0 when none is open.
        int64_t selector_steps_used() const { return m_step_session_open ? m_step_session.used : 0; }
        // The selectors of the master, author and host sheets.
        size_t  selector_count() const;
        // Asked by finalize_from_external_root before its master pass and again before its author and host passes, with
        // the passes' rule count and matching_bound of the tree with the creators of the sheets known by then (the
        // master's, then all three), so a caller can
        // tell whether it can afford apply_selector's filter loop (every rule against every element) before it runs;
        // nothing may be charged or thrown inside it, and it may lower the session's step limit. Answering false stops
        // finalize before that pass, the document unfinished (matching_gated()), for the caller to drop.
        void set_matching_gate(std::function<bool(size_t, size_t)> gate) { m_matching_gate = std::move(gate); }
        bool matching_gated() const { return m_matching_gated; }
        // Telegram (VENDOR.md edit 26): declarations the root element takes after its inline style, each time its style
        // is computed, so that with !important they are the last word over every sheet and the element's own style
        // attribute. Parsed here, on their own, so no text of the element's can run into them. Set before finalize.
        void set_root_declarations(const std::string& declarations)
        {
            m_root_declarations.clear();
            m_root_declarations.add(declarations, "", m_container);
            m_has_root_declarations  = !declarations.empty();
            m_root_declarations_text = declarations; // edit 80
        }
        const style* root_declarations() const { return m_has_root_declarations ? &m_root_declarations : nullptr; }
        // Telegram (VENDOR.md edit 80): the text they were set from.
        const std::string& root_declarations_text() const { return m_root_declarations_text; }
        // Telegram (VENDOR.md edit 81): a <style>'s text (an el_style under the root) replaced in the patch session (opened
        // here unless one is): its piece becomes one holding `text`, or none when it is empty (`pieces` gets them), and
        // the commit applies the sheets as the tree then has them (apply_sheets). False, changing nothing, for another
        // element or past the text-piece cap.
        bool replace_style_text(const std::shared_ptr<element>& style, const std::string& text,
                                std::vector<std::shared_ptr<element>>& pieces);
        // Telegram (VENDOR.md edit 80): new root declarations applied in the patch session (opened here unless one is): the
        // root is matched again, its subtree restyled, and the var() readers below it matched again at the commit.
        // False, changing nothing, when they equal the current ones.
        bool change_root_declarations(const std::string& declarations);
        // The session's step limit, lowered or read (a gate lowers it by what it set aside for the filter loop); after
        // end_selector_steps it still reads the closed session's, until the next begin_selector_steps.
        void    set_selector_step_limit(int64_t limit) { m_step_session.limit = limit; }
        int64_t selector_step_limit() const { return m_step_session.limit; }
        // The tags a match against `sheets` (the master, author and host sheets when none are named) can create
        // ::before/::after elements for, which apply_stylesheet then matches too (html_tag::apply_selector's `create`): a
        // ::before/::after selector whose content is not `none`, naming the tag, or `*` with more than the pseudo-element,
        // which names every tag (`every`); `parts` when that includes a form control's lh-* parts. One pass over the rules.
        struct pseudo_element_tags
        {
            bool                          every = false;
            bool                          parts = false;
            std::unordered_set<string_id> tags;
            bool creatable(string_id tag) const { return every || tags.count(tag) != 0; }
        };
        pseudo_element_tags pseudo_element_creators(std::initializer_list<const css*> sheets = {}) const;
        // What apply_stylesheet tests against each rule for `el`: the element (an html_tag: nothing else is matched), the
        // two pseudo-elements a match can create for it, and for a form control the lh-* parts it makes (at most three),
        // with theirs. A tag decides it, so attributes never change it.
        static size_t matching_weight(const element& el, const pseudo_element_tags& creators);
        // matching_weight summed over `root`'s subtree. Generated elements (::before and ::after, a form control's lh-*
        // parts) are their owner's weight, not counted again, so the bound is the same before matching and after, before
        // parse_attributes makes the parts and after.
        static size_t matching_bound(const std::shared_ptr<element>& root, const pseudo_element_tags& creators);

      private:
        uint_ptr add_font(const font_description& descr, font_metrics* fm);
        int      selector_scope();
        // Telegram (VENDOR.md edit 17): the style and selector checks an attribute change must pass.
        bool     attribute_change_allowed(const std::shared_ptr<element>& el, const string_map& attrs);
        // Telegram (VENDOR.md edit 17): the attributes `el` would hold after the change (list_index and the like kept).
        bool     attribute_target(const std::shared_ptr<element>& el, const char* name, const char* value, string_map& attrs);
        void     begin_patch_session();
        void     release_pieces(const std::shared_ptr<element>& root);
        // Telegram (VENDOR.md edit 91): release_pieces undone, for a subtree that goes back into the tree.
        void     unrelease_pieces(const std::shared_ptr<element>& root);
        // Telegram (VENDOR.md edit 18): the checks the structure predicates share.
        bool     structure_parent_allowed(const std::shared_ptr<element>& parent);
        bool     structure_insertable(const std::shared_ptr<element>& parent, const std::vector<std::shared_ptr<element>>& subtrees,
                                      structure_growth& growth);
        bool     structure_removable(const std::shared_ptr<element>& subtree, structure_growth& growth);
        void     link_subtree(const std::shared_ptr<element>& parent, size_t index, const std::shared_ptr<element>& subtree);
        void     unlink_subtree(const std::shared_ptr<element>& subtree);
        void     restyle_after_patch(const std::vector<std::shared_ptr<element>>& restyle,
                                     const std::vector<std::shared_ptr<element>>& new_text, bool keep_tree = false,
                                     const std::vector<std::shared_ptr<element>>& retext = {},
                                     const std::unordered_set<const element*>& background_only = {});
        // Telegram (VENDOR.md edits 17, 27, 62, 63): rematch `el` with `attrs`; whether the render tree may be kept (only
        // when `check`): every changed attribute is `class`, `style` or the animated declarations, and every changed
        // property is paint-only, or geometry-only on a box that is not inline (the caller lays the document out again).
        bool     apply_retag(const std::shared_ptr<element>& el, const string_map& attrs, bool check);
        // Telegram (VENDOR.md edit 75): apply_retag's matching and its answer, for an element whose attributes were
        // `attrs_before` before the caller changed them (or are, when nothing changed them). rematch_begin, the three
        // passes through the match memo (apply_matching), and rematch_finish.
        bool     rematch(const std::shared_ptr<element>& el, bool check, const string_map& attrs_before);
        // Telegram (VENDOR.md edit 78): rematch's phases. What rematch reads of the element before it forgets its styles;
        // one pass of its matching (`sheet` 0, 1 or 2), with the element's children set aside for the pass alone, so that
        // between passes every element holds its children and its ::before/::after (the counters' sibling lookups read
        // them); and the decision whether the render tree may be kept.
        struct rematch_state
        {
            std::shared_ptr<element>                          el;
            bool                                              check   = false;
            bool                                              neutral = false;
            bool                                              counted = false;
            std::vector<std::pair<const css_selector*, bool>> rules_before;
            // Telegram (VENDOR.md edit 79): the rules matched before, kept alive while rematch_finish compares: a rule the
            // sheets replaced (an environment change's copy, a sheet's lost rule) can have no other owner.
            std::vector<css_selector::ptr>                    held_before;
            string_map                                        attrs_before;
            // Telegram (VENDOR.md edit 84): the element's generated content before the match, by its shape and text.
            std::string                                       generated_before;
            // Telegram (VENDOR.md edit 91): the element's ::before and ::after before the match, which
            // forget_matched_styles drops (their charges given back) and rematch_settle puts back when the match changes
            // nothing; and whether one's style read var(), read before the drop forgets it.
            std::vector<std::shared_ptr<element>>             generated_aside;
            bool                                              generated_reads_var = false;
        };
        rematch_state rematch_begin(const std::shared_ptr<element>& el, bool check, const string_map& attrs_before);
        void          rematch_pass(const rematch_state& state, int sheet);
        bool          rematch_finish(const rematch_state& state);
        // Telegram (VENDOR.md edit 84): rematch_finish's own decision, whether the render tree can be kept.
        bool          rematch_settle(const rematch_state& state);
        // Telegram (VENDOR.md edit 91): the ::before and ::after the match dropped put back in place of those it made,
        // with their styles, when it made the same ones, each printing as it did and matched by the same rules; false,
        // nothing changed, otherwise.
        bool          take_back_generated(const rematch_state& state);
        // Telegram (VENDOR.md edit 78): every counted element's counters made again in a build's order: the counter
        // values cleared everywhere, then each counted element matched again, pass by pass in tree order.
        void          rerun_counters();
        // Telegram (VENDOR.md edit 79): the master sheet and the document's sheets parsed as finalize parses them, through
        // their caches (keyed by the scheme, and by the viewport where a text may hold a viewport unit: environment_key),
        // under the container's environment as it is now.
        css         parsed_master(const std::string& master_styles);
        css         parsed_author();
        std::string environment_key(const std::string& text) const;
        // Telegram (VENDOR.md edit 79): the sheets parsed again under the environment as it is now, and each selector whose
        // style read a changed part of it (`changed`: environment_* bits) replaced by a copy holding the new parse's style;
        // the media lists no selector uses dropped.
        void        reparse_environment(int changed);
        // Telegram (VENDOR.md edit 79): the elements whose style, or a ::before's or ::after's, read a part of the
        // environment in `changed`, in tree order; each element walked a predicate step.
        std::vector<std::shared_ptr<element>> environment_users(int changed);
        // Telegram (VENDOR.md edits 79, 81): what the document derived from its sheets (selector_scope and its indexes,
        // which hold rules by pointer, the content tags, the pseudo-element facts, the style-rule bytes, the share
        // cache) forgotten, made again when next asked: the sheets' rules were replaced.
        void forget_sheet_derivations();
        // Telegram (VENDOR.md edit 81): commit_patch's first step when the session touched a sheet: the <style> texts read
        // from the tree in tree order, paired with the current sheets (an unchanged sheet keeps its rules, so what uses
        // them keeps its match), parsed as finalize parses them, and the elements that hold a rule no longer there or
        // that a new rule matches matched again; what the indexes derived from the sheets is computed again.
        void apply_sheets();
        // Telegram (VENDOR.md edits 79, 80): the environment_* bits that applying `next` changes.
        int environment_change(const media_features& next) const;
        // Telegram (VENDOR.md edit 79): the elements whose matched rules hold one under a list in `lists` (m_used_styles
        // keeps a rule that matches while its list is off), in tree order; each element walked a predicate step.
        std::vector<std::shared_ptr<element>> media_users(const std::unordered_set<const media_query_list_list*>& lists);
        // Whether the session's changes under `root` (a removal's) take a counted element away.
        void          note_counted_subtree(const std::shared_ptr<element>& root);
        void     forget_positions();
        bool     replace_text_renderers(const std::vector<std::shared_ptr<element>>& current,
                                        const elements_list& replacement);

        GumboOutput* parse_html(estring str);
        void         create_node(void* gnode, elements_list& elements, bool parseTextNode, bool process_root);
        bool         update_media_lists(const media_features& features);
        void         fix_tables_layout();
        // Telegram (VENDOR.md edit 74): replaces the boundaries' render subtrees in place (the root's: the whole tree) and
        // tells the render observer; true when the root was replaced.
        bool replace_render_subtrees(const std::vector<std::shared_ptr<element>>& boundaries);
        // Telegram (VENDOR.md edits 74, 89): render subtrees let go (their tables' cells given back, out of the layout's
        // lists and their elements), and one made as a build makes it.
        void release_render_subtrees(const std::vector<render_item*>& tops);
        std::shared_ptr<render_item> make_render_subtree(const std::shared_ptr<element>& el,
                                                         const std::shared_ptr<render_item>& parent);
        // Telegram (VENDOR.md edit 89): how a parent's render children follow the session's changes to its children: why
        // they cannot be linked ("" when they can), else the children in order (a fresh block-level child to make and link,
        // or an item kept) and the items of the children removed. `fresh`: the subtrees the session inserted.
        struct child_link
        {
            std::shared_ptr<element>     fresh;
            std::shared_ptr<render_item> item;
        };
        struct link_plan
        {
            std::string                               refusal;
            std::vector<child_link>                   children;
            std::vector<std::shared_ptr<render_item>> unlinked;
        };
        link_plan plan_link(const std::shared_ptr<element>& parent, const std::unordered_set<const element*>& fresh) const;
        // Applies `plan`: the removed children's render subtrees unlinked, the fresh ones made and linked, the list items
        // numbered again (those whose number changed added to `renumbered`, those linked to `linked`).
        void link_render_children(const std::shared_ptr<element>& parent, const link_plan& plan,
                                  const std::unordered_set<const element*>& fresh,
                                  std::vector<std::shared_ptr<element>>& renumbered,
                                  std::vector<std::shared_ptr<element>>& linked);
        void replace_root_render();
        void report_replacements();
        bool inside_any(const element* el, const std::unordered_set<const element*>& set,
                        std::unordered_map<const element*, bool>& memo) const;
        void fix_table_children(const std::shared_ptr<render_item>& el_ptr, style_display disp, const char* disp_str);
        void fix_table_parent(const std::shared_ptr<render_item>& el_ptr, style_display disp, const char* disp_str);
    };

    inline std::shared_ptr<element> document::root()
    {
        return m_root;
    }

    inline std::shared_ptr<render_item> document::root_render()
    {
        return m_root_render;
    }

    inline void document::add_tabular(const std::shared_ptr<render_item>& el)
    {
        m_tabular_elements.push_back(el);
    }

    inline bool document::match_lang(const std::string& lang)
    {
        return lang == m_lang || lang == m_culture;
    }
} // namespace litehtml

#endif // LITEHTML_DOCUMENT_H
