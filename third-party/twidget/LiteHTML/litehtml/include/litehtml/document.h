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
        // The render tree was dropped and built again from the root: every item above is gone.
        virtual void tree_rebuilt() = 0;
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
        void                        observer_tree_rebuilt();
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
        void note_pseudo_element(int delta) { m_pseudo_elements += delta; }
        bool pseudo_element_allowed();
        std::unordered_set<const element*> skip_paint;
        std::unordered_set<const element*> skip_background_images;
        const element* bare_effects = nullptr;
        bool bare_shadows = false;
        bool has_backdrop = false;
        std::unordered_set<const element*> skip_scroll_content;
        const element* unclipped_scroll = nullptr;
        bool m_paint_only_patch = false;
        bool m_patch_confined   = false;
        std::vector<std::shared_ptr<element>> m_patch_regions;
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
        std::unordered_set<const element*>           m_layout_origins;
        std::vector<std::shared_ptr<element>>        m_restyle_regions;
        bool                                         m_restyle_confined = true;
        void     snapshot_layout();
        void     begin_layout_patch();
        bool     layout_dirty_regions(std::vector<position>& out);
        void     note_layout_origin(const element* el) { m_layout_origins.insert(el); }
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
        GumboOutput*                            m_gumbo = nullptr;
        bool                                    m_track_nodes = false;
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
        mutable int                             m_pseudo_rules   = -1; // any ::before/::after rule in the sheets
        bool                                    m_text_limited   = false;
        int                                     m_text_allowance = 0;
        // Telegram (VENDOR.md edit 16): a text patch session, from the first replace_text to commit_patch. The base is
        // m_text_elements when it began and the growth the net pieces added since, which the cap counts (the replaced
        // pieces stay alive until the render tree lets go of them).
        bool                                    m_patch_pending   = false;
        bool                                    m_patch_keep_tree = true;
        int                                     m_patch_text_base = 0;
        int                                     m_patch_growth    = 0;
        std::vector<std::shared_ptr<element>>   m_patch_new_text;
        // Telegram (VENDOR.md edit 17): the elements set_element_attribute re-matched in the session, which commit_patch
        // restyles.
        std::vector<std::shared_ptr<element>>   m_patch_restyle;
        // Telegram (VENDOR.md edit 42): the parents whose children the session changed and a subject positional rule
        // reaches (positions_reach): commit_patch matches their element children again.
        std::vector<std::shared_ptr<element>>   m_patch_position_parents;
        // Telegram (VENDOR.md edit 17): pieces the session replaced or forgot (replaced text, a re-matched element's
        // pseudo-element content), kept alive until commit_patch and not counted by text_element_allowed, so that a patch
        // counts what a fresh build would; the count of the text pieces they hold.
        std::vector<std::shared_ptr<element>>   m_patch_hold;
        int                                     m_patch_released = 0;
        mutable int                             m_pseudo_content = -1;
        uint64_t                                m_attribute_rematches = 0;
        // Telegram (VENDOR.md edit 18): the subtrees insert_subtree and replace_children linked in the session, which
        // commit_patch styles as update_structure styles a fresh subtree.
        std::vector<std::shared_ptr<element>>   m_patch_inserted;
        // Telegram (VENDOR.md edit 18): the tags the ::before/::after content rules name, and whether one names an lh-*
        // part; read from the sheets once (they never change after finalize).
        std::unordered_set<string_id>           m_content_tags;
        bool                                    m_content_parts      = false;
        bool                                    m_content_tags_known = false;
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
        int                                     m_selector_scope = -1;
        // Telegram (VENDOR.md edit 42): the rules whose positional pseudo-classes are in their subject alone (selector_scope
        // bit 16): the subject's tag and, under a child combinator, its parent's (star_id: any).
        struct subject_position
        {
            string_id tag;
            string_id parent;
        };
        std::vector<subject_position>           m_subject_positions;
        int                                     m_ids_selectable = -1;
        std::unordered_set<string_id>           m_left_classes;
        std::unordered_set<string_id>           m_left_ids;
        std::unordered_set<string_id>           m_left_attrs;
        static constexpr int                    max_build_depth    = 256;
        static constexpr int                    max_build_elements = 20000;
        static constexpr int                    max_table_cells    = 200000;
        int                                     m_table_cells      = 0;
        bool                                    m_table_limited    = false;
        std::unordered_map<const void*, std::vector<std::shared_ptr<element>>> m_node_elements;
        std::string                             m_master_styles;
        mutable uint32_t                        m_paint_generation = 1;
        uint64_t                                m_match_epoch      = 1;
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
        struct html_hole
        {
            bool                                  text  = false;
            bool                                  src   = false;
            bool                                  cls   = false;
            const void*                           node  = nullptr;
            std::string                           name;
            std::string                           attr;
            char                                  close = 0;
            std::string                           value;
            std::shared_ptr<element>              owner;
            std::vector<std::shared_ptr<element>> text_elements;
        };
        std::vector<std::string>                m_literals;
        std::vector<html_hole>                  m_holes;
        bool                                    m_template_ok = false;
        std::unordered_map<const element*, size_t> m_style_holes;
        std::unordered_map<const element*, std::vector<size_t>> m_owner_holes;
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

        // Like createFromString, but keeps the parse tree so update_from_string can patch the document.
        static document::ptr createUpdatableFromString(const std::string& html, document_container* container,
                                                       const std::string& master_styles);

        // Patches an updatable document to the new HTML in place when only inline `style` attribute values
        // and text change and the element structure is the same. Restyles the changed subtrees and rebuilds
        // the render tree. Returns false and leaves the document unchanged otherwise; the caller then builds
        // a new document. *changed tells whether anything differed.
        bool last_patch_paint_only() const { return m_paint_only_patch; }
        // After a paint-only patch: the elements whose border boxes hold every pixel the patch can change, or
        // false when some change may paint elsewhere.
        bool last_patch_regions(std::vector<std::shared_ptr<element>>& out) const
        {
            if(!m_paint_only_patch || !m_patch_confined)
                return false;
            out = m_patch_regions;
            return true;
        }
        bool update_from_string(const std::string& html, bool* changed);
        // Patches the inline `style` values of the given elements without an HTML string, through the same
        // checks and restyle as update_from_string. Fails, leaving the document unchanged, when an element has
        // no style attribute in the source or a value could not have come from serialized HTML.
        bool update_styles(const std::vector<std::pair<std::shared_ptr<element>, std::string>>& styles, bool* changed);
        struct hole_change
        {
            std::shared_ptr<element> owner;
            std::string              name;
            bool                     text = false;
            std::string              value;
        };
        // Patches attribute values (`name`) and the text of elements whose only content is one text run (`text`)
        // without an HTML string, through the same checks and restyle as update_from_string. Each value must be the
        // exact text serialized HTML would carry there. Fails, leaving the document unchanged, when a change has no
        // matching hole in the source.
        bool update_holes(const std::vector<hole_change>& changes, bool* changed);
        // The HTML the document currently stands for: the parsed source with every patch applied.
        bool template_html(std::string& out) const;

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
        // inside a form control (select, option, optgroup, datalist, textarea, button, input, progress, meter) or an
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
        // that is not in the document or sits inside a <select>, the name or value in an ancestor position of a selector,
        // sibling, positional or counter selectors anywhere in the sheets, and an inline style touching --*, var( or
        // counter. Setting what is already there answers true and changes nothing.
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
        // fresh build makes all of it in document order with the old of each alive beside the new, so near the text-piece
        // cap a patch and a rebuild cut at different words: while this is true no patch is made (can_replace_text and
        // can_set_element_attributes refuse). Computed on the first query after a finalize or a commit_patch (a patch can
        // add elements: a form control makes its lh-* parts again), so it follows the tree as it is. The walk of the
        // tree is O(elements); a caller that charges its work pays for it (WidgetRuntime charges the build's element
        // count before asking).
        bool pseudo_content_possible() const;
        // Telegram (VENDOR.md edit 19, W Ruling E28): true when the sheets hold any ::before/::after rule (content or
        // not) and the pseudo-element cap is, or with `extra` more elements could be, reached; a patch refuses then, as a
        // rebuild hands the remaining budget out in document order. Coarse on purpose.
        bool pseudo_cap_in_play(long long extra) const;
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
        // Re-matches made by set_element_attributes (and set_element_attribute) so far; tests.
        uint64_t attribute_rematches() const { return m_attribute_rematches; }
        // The table cells the last render-tree build counted against max_table_cells; tests.
        int table_cells() const { return m_table_cells; }
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
        // no parent) at child `index` of `parent`, and links it. commit_patch styles it as update_structure styles a fresh
        // subtree (the master sheet, parse_attributes, the author sheets, the user sheet; the match epoch bumped), after
        // every structure change of the session, so positional matches see the final children, and marks the render tree
        // for rebuilding. Answers false, changing nothing, when can_insert_subtree does.
        bool insert_subtree(const std::shared_ptr<element>& parent, size_t index, const std::shared_ptr<element>& subtree);
        // Removes a subtree (remove_child, which re-points the hover and active elements) and marks the render tree for
        // rebuilding; its pieces stop counting against the text cap at once and stay alive until commit_patch. Answers
        // false, changing nothing, when can_remove_subtree does.
        bool remove_subtree(const std::shared_ptr<element>& subtree);
        // Replaces all of `parent`'s children but its generated content (::before, ::after) with `subtrees` (each built as
        // for insert_subtree), between the generated content. The one structure change allowed while sibling combinators
        // or positional pseudo-classes are in the sheets (structure_reaches_siblings): every child is then matched afresh.
        // Answers false, changing nothing, when can_replace_children does.
        bool replace_children(const std::shared_ptr<element>& parent, const std::vector<std::shared_ptr<element>>& subtrees);
        // Whether insert_subtree(parent, index, subtree) would answer true, for a caller that plans every change of a flush
        // before it makes the first. False for (litehtml.md section (c) 1, 2, 4): a subtree holding a document-level
        // element (html head body style link base meta title script frameset select option optgroup datalist); a parent
        // that is not in the document, is raw text (<style>, <script>), or is inside a select, option, optgroup, datalist,
        // textarea, button, input, progress, meter or svg (their generated content or drawing reads their children); sheets
        // that use counters, sibling combinators or positional pseudo-classes (selector_scope() != 0: replace_children is
        // the change for the latter two); pseudo_content_possible() for the tree with the subtree added (it is true, or the
        // subtree has an element a ::before/::after content rule names by tag, or a form control while an lh-* part rule
        // exists), since the subtree's pseudo-element content would be made in the patch's order, not a fresh build's; and
        // the caps: an element at max_build_depth or deeper, max_build_elements, the text pieces (counted logically: alive,
        // less the session's released and `pending`'s), and max_table_cells. A subtree that is not detached, and an index
        // past the end, are refused too.
        bool can_insert_subtree(const std::shared_ptr<element>& parent, size_t index, const std::shared_ptr<element>& subtree,
                                structure_growth* pending = nullptr);
        // Whether remove_subtree(subtree) would answer true: the same refusals for what it removes (a document-level element,
        // a parent inside one of those elements, the sheets' scope, pseudo_content_possible()), and the root, a detached
        // element and generated content (::before, ::after, a form control's lh-* parts) are refused.
        bool can_remove_subtree(const std::shared_ptr<element>& subtree, structure_growth* pending = nullptr);
        // Whether replace_children(parent, subtrees) would answer true: the removals' and insertions' refusals, except that
        // sibling combinators and positional pseudo-classes are allowed (counters are not).
        bool can_replace_children(const std::shared_ptr<element>& parent, const std::vector<std::shared_ptr<element>>& subtrees,
                                  structure_growth* pending = nullptr);
        // Whether the sheets hold sibling combinators or positional pseudo-classes (selector_scope() & 3), so that a change
        // to a parent's children can change how its other children match.
        bool structure_reaches_siblings();
        // Telegram (VENDOR.md edit 42): that, or a rule whose positional pseudo-classes are in its subject alone can match
        // one of `parent`'s element children (positions_reach): a change to them then changes how the others match.
        bool structure_reaches_siblings(const std::shared_ptr<element>& parent);
        bool positions_reach(const std::shared_ptr<element>& parent);
        void note_position_parent(const std::shared_ptr<element>& parent);
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
        // What a patch will match: subtrees to be linked under a parent (insert_subtree, replace_children), and elements
        // set_element_attributes re-matches with their new attributes (an input's generated parts with it).
        struct selector_step_plan
        {
            std::vector<std::pair<std::shared_ptr<element>, std::shared_ptr<element>>> inserted;   // (parent, subtree)
            std::vector<std::pair<std::shared_ptr<element>, const string_map*>>        rematched;  // (element, new attrs)
        };
        // An upper bound of the selector steps matching `plan` costs, counted as html_tag.cpp counts them: for each
        // element, every selector apply_selector's filter lets through (its rightmost tag, and its first class when it
        // starts with one), twice (a test without pseudo-classes, then one with), each test bounded by the shape of the
        // selector at the deepest place and the most siblings of the plan (a descendant combinator walks every ancestor,
        // a general sibling one every sibling, :is/:not/:where test their lists, :nth-child(of S) S against each sibling;
        // the prune of find_ancestor and find_sibling is modelled where it applies). Saturates.
        int64_t selector_step_bound(const selector_step_plan& plan) const;
        // The selectors of the master, author and host sheets: the bound's own work is proportional to it.
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
            m_has_root_declarations = !declarations.empty();
        }
        const style* root_declarations() const { return m_has_root_declarations ? &m_root_declarations : nullptr; }
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
        void     build_template();
        int      update_from_template(const std::string& html, bool* changed);
        int      apply_template_values(std::vector<std::pair<size_t, std::string>>& changes, bool* changed);
        bool     update_structure(const std::string& html, bool* changed);
        int      selector_scope();
        // Telegram (VENDOR.md edit 17): retag_allowed's style and selector checks without its type and sanitizer ones.
        bool     attribute_change_allowed(const std::shared_ptr<element>& el, const string_map& attrs);
        // Telegram (VENDOR.md edit 17): the attributes `el` would hold after the change (list_index and the like kept).
        bool     attribute_target(const std::shared_ptr<element>& el, const char* name, const char* value, string_map& attrs);
        void     begin_patch_session();
        void     release_pieces(const std::shared_ptr<element>& root);
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
        bool     retag_allowed(const std::shared_ptr<element>& el, std::string name, bool svg, string_map& attrs,
                               bool blocked);
        bool     apply_retag(const std::shared_ptr<element>& el, const string_map& attrs, bool check, int* region = nullptr);
        void     forget_positions();
        bool     class_change_allowed(const html_hole& hole, const std::string& value, string_map& attrs);
        bool     retext_in_place(const std::vector<std::shared_ptr<element>>& current, const char* text,
                                 std::vector<std::string>& words) const;
        bool     replace_text_renderers(const std::vector<std::shared_ptr<element>>& current,
                                        const elements_list& replacement);

        GumboOutput* parse_html(estring str);
        void         create_node(void* gnode, elements_list& elements, bool parseTextNode, bool process_root);
        bool         update_media_lists(const media_features& features);
        void         fix_tables_layout();
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
