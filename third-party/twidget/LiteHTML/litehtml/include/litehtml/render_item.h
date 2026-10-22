#ifndef LITEHTML_RENDER_ITEM_H
#define LITEHTML_RENDER_ITEM_H

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <list>
#include <tuple>
#include "html.h"
#include "types.h"
#include "line_box.h"
#include "table.h"
#include "formatting_context.h"
#include "element.h"
#include "scroll_view.h"

namespace litehtml
{
    class render_item;
    extern thread_local std::vector<const render_item*>* g_paint_trace;

    class element;

    struct paint_ink
    {
        float l         = 0;
        float t         = 0;
        float r         = 0;
        float b         = 0;
        bool  empty     = true;
        bool  unbounded = false;

        void add(float left, float top, float right, float bottom)
        {
            if(std::isnan(left) || std::isnan(top) || std::isnan(right) || std::isnan(bottom))
                return;
            if(empty)
            {
                l = left;
                t = top;
                r = right;
                b = bottom;
                empty = false;
                return;
            }
            l = std::min(l, left);
            t = std::min(t, top);
            r = std::max(r, right);
            b = std::max(b, bottom);
        }
        void add(const position& box, float reach)
        {
            add(box.x.value() - reach, box.y.value() - reach, box.x.value() + box.width.value() + reach,
                box.y.value() + box.height.value() + reach);
        }
        void add(const paint_ink& other, float dx, float dy)
        {
            if(other.unbounded)
                unbounded = true;
            else if(!other.empty)
                add(other.l + dx, other.t + dy, other.r + dx, other.b + dy);
        }
        bool misses(const position& clip, float dx, float dy) const
        {
            if(unbounded)
                return false;
            if(empty)
                return true;
            return r + dx < clip.x.value() || l + dx > clip.x.value() + clip.width.value() || b + dy < clip.y.value() ||
                   t + dy > clip.y.value() + clip.height.value();
        }
    };

    class render_item : public std::enable_shared_from_this<render_item>
    {
      protected:
        std::shared_ptr<element>                  m_element;
        std::weak_ptr<render_item>                m_parent;
        std::list<std::shared_ptr<render_item>>   m_children;
        margins                                   m_margins;
        margins                                   m_padding;
        margins                                   m_borders;
        position                                  m_pos;
        bool                                      m_skip = false;
        std::vector<std::shared_ptr<render_item>> m_positioned;
        std::shared_ptr<scroll_view>              m_scroll_view;
        paint_ink                                 m_ink;
        paint_ink                                 m_drawn_ink;
        uint32_t                                  m_ink_generation = 0;

        virtual void add_children_ink(uint32_t generation, paint_ink& ink);

        struct layout_entry
        {
            containing_block_context cb;
            rendered_width           ret;
            bool                     second_pass = false;
            bool                     valid       = false;
            pixel_t                  outer_height = 0_px;
        };
        bool         m_layout_dirty   = true;
        bool         m_relayout_pending = false;
        // Telegram (VENDOR.md edit 40): text-overflow: ellipsis. A text piece cut at its line's ellipsis draws only its
        // first m_ellipsis_bytes bytes (-1: all), then the ellipsis m_ellipsis_at past its left in m_ellipsis_block's
        // font and colour (it is part of the piece's own paint); a piece after it is not drawn.
        int                    m_ellipsis_bytes  = -1;
        bool                   m_ellipsis_hidden = false;
        pixel_t                m_ellipsis_at     = 0_px;
        std::weak_ptr<element> m_ellipsis_block;
        bool         m_out_of_flow    = true;
        uint64_t     m_layout_epoch   = 0;
        layout_entry m_last_layout;
        position     m_last_pos;
        pixel_t      m_last_x = 0_px;
        pixel_t      m_last_y = 0_px;
        margins      m_last_margins;
        margins      m_last_padding;
        margins      m_last_borders;
        layout_entry m_measured[2];
        int          m_measured_next = 0;

        bool                 layout_cacheable(formatting_context* fmt_ctx) const;
        bool                 layout_reusable() const;
        static bool          same_layout_input(const layout_entry& entry, const containing_block_context& cb, bool second_pass);

        containing_block_context calculate_containing_block_context(const containing_block_context& cb_context);
        void                     calc_cb_length(const css_length& len, pixel_t percent_base,
                                                containing_block_context::typed_pixel& out_value) const;
        virtual rendered_width   _render(pixel_t /*x*/, pixel_t /*y*/,
                                         const containing_block_context& /*containing_block_size*/,
                                         formatting_context* /*fmt_ctx*/, bool /*second_pass = false*/)
        {
            return {0_px, 0_px};
        }

      public:
        explicit render_item(std::shared_ptr<element> src_el);

        virtual ~render_item() = default;

        pixel_t get_scroll_left() const
        {
            return m_scroll_view ? m_scroll_view->get_left() : 0_px;
        }

        pixel_t get_scroll_top() const
        {
            return m_scroll_view ? m_scroll_view->get_top() : 0_px;
        }

        const scroll_view* get_scroll_view() const
        {
            return m_scroll_view.get();
        }

        void scroll_to(pixel_t left, pixel_t top)
        {
            if(m_scroll_view)
            {
                m_scroll_view->scroll_to(left, top);
            }
        }

        void scroll_box(position& box) const
        {
            if(m_scroll_view)
            {
                box.x -= m_scroll_view->get_left();
                box.y -= m_scroll_view->get_top();
            }
        }

        pixel_t h_scroll(pixel_t dx)
        {
            return m_scroll_view ? m_scroll_view->h_scroll(dx) : 0_px;
        }

        pixel_t v_scroll(pixel_t dy)
        {
            return m_scroll_view ? m_scroll_view->v_scroll(dy) : 0_px;
        }

        bool is_h_scrollable(const pixel_t dx) const
        {
            return m_scroll_view ? m_scroll_view->is_h_scrollable(dx) : false;
        }

        bool is_v_scrollable(const pixel_t dy) const
        {
            return m_scroll_view ? m_scroll_view->is_v_scrollable(dy) : false;
        }

        std::list<std::shared_ptr<render_item>>& children()
        {
            return m_children;
        }

        // Access to the m_pos
        const position& pos_const() const
        {
            return m_pos;
        }

        position& pos()
        {
            return m_pos;
        }

        // Calculates the position of the element in the document
        // This position is relative to the x and y arguments
        // Scroll shifts are applied to the position
        position calc_placement(int x = 0, int y = 0) const
        {
            position pos  = m_pos;
            const auto sticky = sticky_offset();
            pos.x        += pixel_t(x) - get_scroll_left() + sticky.x;
            pos.y        += pixel_t(y) - get_scroll_top() + sticky.y;
            return pos;
        }

        bool skip() const
        {
            return m_skip;
        }

        void skip(bool val)
        {
            m_skip = val;
        }

        pixel_t right() const
        {
            return left() + width();
        }

        pixel_t left() const
        {
            return m_pos.left() - m_margins.left - m_padding.left - m_borders.left;
        }

        pixel_t top() const
        {
            return m_pos.top() - m_margins.top - m_padding.top - m_borders.top;
        }

        pixel_t bottom() const
        {
            return top() + height();
        }

        pixel_t height() const
        {
            return m_pos.height + m_margins.height() + m_padding.height() + m_borders.height();
        }

        pixel_t width() const
        {
            return m_pos.width + m_margins.width() + m_padding.width() + m_borders.width();
        }

        pixel_t padding_top() const
        {
            return m_padding.top;
        }

        pixel_t padding_bottom() const
        {
            return m_padding.bottom;
        }

        pixel_t padding_left() const
        {
            return m_padding.left;
        }

        pixel_t padding_right() const
        {
            return m_padding.right;
        }

        pixel_t border_top() const
        {
            return m_borders.top;
        }

        pixel_t border_bottom() const
        {
            return m_borders.bottom;
        }

        pixel_t border_left() const
        {
            return m_borders.left;
        }

        pixel_t border_right() const
        {
            return m_borders.right;
        }

        pixel_t margin_top() const
        {
            return m_margins.top;
        }

        pixel_t margin_bottom() const
        {
            return m_margins.bottom;
        }

        pixel_t margin_left() const
        {
            return m_margins.left;
        }

        pixel_t margin_right() const
        {
            return m_margins.right;
        }

        std::shared_ptr<render_item> parent() const
        {
            return m_parent.lock();
        }

        margins& get_margins()
        {
            return m_margins;
        }

        margins& get_paddings()
        {
            return m_padding;
        }

        const margins& get_paddings_const() const
        {
            return m_padding;
        }

        const margins& get_borders_const() const
        {
            return m_borders;
        }

        void set_paddings(const margins& val)
        {
            m_padding = val;
        }

        margins& get_borders()
        {
            return m_borders;
        }

        /**
         * Top offset to the element content. Includes paddings, margins and borders.
         */
        pixel_t content_offset_top() const
        {
            return m_margins.top + m_padding.top + m_borders.top;
        }

        /**
         * Bottom offset to the element content. Includes paddings, margins and borders.
         */
        pixel_t content_offset_bottom() const
        {
            return m_margins.bottom + m_padding.bottom + m_borders.bottom;
        }

        /**
         * Left offset to the element content. Includes paddings, margins and borders.
         */
        pixel_t content_offset_left() const
        {
            return m_margins.left + m_padding.left + m_borders.left;
        }

        /**
         * Right offset to the element content. Includes paddings, margins and borders.
         */
        pixel_t content_offset_right() const
        {
            return m_margins.right + m_padding.right + m_borders.right;
        }

        /**
         * Sum of left and right offsets to the element content. Includes paddings, margins and borders.
         */
        pixel_t content_offset_width() const
        {
            return content_offset_left() + content_offset_right();
        }

        /**
         * Sum of top and bottom offsets to the element content. Includes paddings, margins and borders.
         */
        pixel_t content_offset_height() const
        {
            return content_offset_top() + content_offset_bottom();
        }

        pixel_t render_offset_left() const
        {
            if(css().get_box_sizing() == box_sizing_content_box)
            {
                return m_margins.left + m_borders.left + m_padding.left;
            }
            return m_margins.left;
        }

        pixel_t render_offset_right() const
        {
            if(css().get_box_sizing() == box_sizing_content_box)
            {
                return m_margins.right + m_borders.right + m_padding.right;
            }
            return m_margins.right;
        }

        pixel_t render_offset_width() const
        {
            return render_offset_left() + render_offset_right();
        }

        pixel_t render_offset_top() const
        {
            if(css().get_box_sizing() == box_sizing_content_box)
            {
                return m_margins.top + m_borders.top + m_padding.top;
            }
            return m_margins.top;
        }

        pixel_t render_offset_bottom() const
        {
            if(css().get_box_sizing() == box_sizing_content_box)
            {
                return m_margins.bottom + m_borders.bottom + m_padding.bottom;
            }
            return m_margins.bottom;
        }

        pixel_t render_offset_height() const
        {
            return render_offset_top() + render_offset_bottom();
        }

        pixel_t box_sizing_left() const
        {
            if(css().get_box_sizing() == box_sizing_border_box)
            {
                return m_padding.left + m_borders.left;
            }
            return 0_px;
        }

        pixel_t box_sizing_right() const
        {
            if(css().get_box_sizing() == box_sizing_border_box)
            {
                return m_padding.right + m_borders.right;
            }
            return 0_px;
        }

        pixel_t box_sizing_width() const
        {
            return box_sizing_left() + box_sizing_right();
        }

        pixel_t box_sizing_top() const
        {
            if(css().get_box_sizing() == box_sizing_border_box)
            {
                return m_padding.top + m_borders.top;
            }
            return 0_px;
        }

        pixel_t box_sizing_bottom() const
        {
            if(css().get_box_sizing() == box_sizing_border_box)
            {
                return m_padding.bottom + m_borders.bottom;
            }
            return 0_px;
        }

        pixel_t box_sizing_height() const
        {
            return box_sizing_top() + box_sizing_bottom();
        }

        void parent(const std::shared_ptr<render_item>& par)
        {
            m_parent = par;
        }

        const std::shared_ptr<element>& src_el() const
        {
            return m_element;
        }

        const css_properties& css() const
        {
            return m_element->css();
        }

        void add_child(const std::shared_ptr<render_item>& ri)
        {
            m_children.push_back(ri);
            ri->parent(shared_from_this());
        }

        bool is_root() const
        {
            return m_parent.expired();
        }

        bool collapse_top_margin() const
        {
            return m_borders.top == 0_px && m_padding.top == 0_px && m_element->in_normal_flow() &&
                   m_element->css().get_float() == float_none && m_margins.top >= 0_px && !is_flex_item() &&
                   !is_root() && !is_one_of(css().get_overflow(), overflow_hidden, overflow_scroll, overflow_auto) &&
                   !css().contains(contain_layout | contain_paint);
        }

        bool collapse_bottom_margin() const
        {
            return m_borders.bottom == 0_px && m_padding.bottom == 0_px && m_element->in_normal_flow() &&
                   m_element->css().get_float() == float_none && m_margins.bottom >= 0_px && !is_root() &&
                   !is_one_of(css().get_overflow(), overflow_hidden, overflow_scroll, overflow_auto) &&
                   !css().contains(contain_layout | contain_paint);
        }

        bool is_visible() const
        {
            return !m_skip && src_el()->css().get_display() != display_none &&
                   src_el()->css().get_visibility() == visibility_visible;
        }

        bool is_flex_item() const
        {
            auto par = parent();
            return par && (par->css().get_display() == display_inline_flex || par->css().get_display() == display_flex ||
                           par->css().get_display() == display_grid || par->css().get_display() == display_inline_grid);
        }

        rendered_width render(pixel_t x, pixel_t y, const containing_block_context& containing_block_size,
                              formatting_context* fmt_ctx, bool second_pass = false);
        virtual rendered_width measure(pixel_t x, pixel_t y, const containing_block_context& containing_block_size,
                               formatting_context* fmt_ctx, bool second_pass = false, pixel_t* measured_height = nullptr);
        pixel_t measure_height(pixel_t x, pixel_t y, const containing_block_context& containing_block_size,
                               formatting_context* fmt_ctx, bool second_pass = false);
        void           mark_layout_dirty();
        // Telegram (VENDOR.md edit 40).
        int            ellipsis_bytes() const { return m_ellipsis_bytes; }
        bool           ellipsis_hidden() const { return m_ellipsis_hidden; }
        pixel_t        ellipsis_at() const { return m_ellipsis_at; }
        std::shared_ptr<element> ellipsis_block() const { return m_ellipsis_block.lock(); }
        void           set_ellipsis(int bytes, bool hidden, pixel_t at = 0_px, const std::shared_ptr<element>& block = nullptr)
        {
            m_ellipsis_bytes  = bytes;
            m_ellipsis_hidden = hidden;
            m_ellipsis_at     = at;
            m_ellipsis_block  = block;
        }
        bool           relayout_boundary() const;
        void           relayout();
        bool           layout_dirty() const { return m_layout_dirty; }
        void           set_out_of_flow(bool value) { m_out_of_flow = value; }
        void           apply_relative_shift(const containing_block_context& containing_block_size);
        void           calc_outlines(pixel_t parent_width);
        pixel_t        calc_auto_margins(pixel_t parent_width); // returns left margin

        virtual std::shared_ptr<render_item> init();
        virtual void                         apply_vertical_align() {}
        /**
         * Get first baseline position. Default position is element bottom without bottom margin.
         * @returns offset of the first baseline from element top
         */
        virtual pixel_t get_first_baseline()
        {
            return height() - margin_bottom();
        }
        /**
         * Get the last baseline position.  The default position is element bottom without bottom margin.
         * @returns offset of the last baseline from element top
         */
        virtual pixel_t get_last_baseline()
        {
            return height() - margin_bottom();
        }

        virtual std::shared_ptr<render_item> clone()
        {
            return std::make_shared<render_item>(src_el());
        }
        std::tuple<std::shared_ptr<litehtml::render_item>, std::shared_ptr<litehtml::render_item>,
                   std::shared_ptr<litehtml::render_item>>
             split_inlines();
        bool fetch_positioned();
        void render_positioned(render_type rt = render_all);
        // returns element offset related to the containing block
        std::tuple<pixel_t, pixel_t> element_static_offset(const std::shared_ptr<litehtml::render_item>& el);

        void add_positioned(const std::shared_ptr<litehtml::render_item>& el);
        void get_redraw_box(litehtml::position& pos, pixel_t x = 0_px, pixel_t y = 0_px);
        void calc_document_size(litehtml::size& sz, pixel_t x = 0_px, pixel_t y = 0_px);

        /**
         * @brief Call func for all inline boxes
         * @param process function to call for boxes. "first "argument is true for the first box, "last" argument is
         * true for the last box. Function should return true to continue.
         * @return returns true if supported, else returns false
         */
        virtual bool for_inline_boxes(
            [[maybe_unused]] const std::function<bool(const position& box, bool first, bool last)>& process) const
        {
            return false;
        }

        virtual void set_inline_boxes(position::vector& /*boxes*/) {};
        virtual void add_inline_box(const position& /*box*/) {};
        virtual void clear_inline_boxes() {};
        const paint_ink& ink(uint32_t generation, bool drawn);
        void             add_self_ink(paint_ink& ink, float dx, float dy) const;
        void draw_stacking_context(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip, bool with_positioned);
        void draw_group(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip,
                        const std::shared_ptr<render_item>& el);
        virtual void    draw_children(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip, draw_flag flag,
                                      int zindex);
        virtual pixel_t get_draw_vertical_offset()
        {
            return 0_px;
        }
        static bool inside_paint_group(const std::shared_ptr<render_item>& el);
        virtual std::shared_ptr<element> get_child_by_point(
            pixel_t x, pixel_t y, pixel_t client_x, pixel_t client_y, draw_flag flag, int zindex,
            const std::function<bool(const std::shared_ptr<render_item>&)>& check);
        std::shared_ptr<element> get_element_by_point(
            pixel_t x, pixel_t y, pixel_t client_x, pixel_t client_y,
            const std::function<bool(const std::shared_ptr<render_item>&)>& check);
        virtual bool is_point_inside(pixel_t x, pixel_t y) const;
        void         dump(litehtml::dumper& cout);
        position     get_placement() const;
        transform_matrix get_visual_transform() const;
        position     sticky_offset() const;
        virtual void y_shift(pixel_t delta);
        /**
         * Returns the boxes of rendering element. All coordinates are absolute
         *
         * @param redraw_box function to be called on every rendering box
         * @return
         */
        void get_rendering_boxes(const std::function<void(const position&)>& redraw_box) const;

        // Telegram (VENDOR.md edit 20): the geometry this item had before the running layout wrote it, saved by its first
        // write in the document's observed epoch (observe_geometry) and compared when that layout ends
        // (document::render), so the render_observer hears of each changed box once, at the write, with nothing walked
        // for it. An inline context also keeps its inline content's geometry, which layout writes without render().
        uint32_t              m_observed_epoch = 0;
        position              m_observed_pos;
        margins               m_observed_padding;
        margins               m_observed_borders;
        std::vector<position> m_observed_inline;
        void                  observe_geometry();
        // render_observer::moved | resized | reflowed, against what observe_geometry saved.
        unsigned              observed_change() const;
    };

    // Telegram (VENDOR.md edit 20): the traversal draw() performs, with a visitor where draw() paints an item. A walk IS
    // draw(): walk_paint_order calls document::draw with the visitor installed, so the container receives every call
    // draw() makes outside an item's own paint (overflow clips, groups, clip paths, filters, backdrops, clip escapes),
    // in draw()'s order, and the visitor is told where painting contexts and draw_children passes begin and end, and is
    // handed each item's own paint (element::draw, or a table row's draw_background) to run or not. With no visitor
    // installed every hook below does exactly what the line it sits beside did, so draw() is unchanged.
    enum class paint_context
    {
        root,     // the document's root: draw_stacking_context of the root item
        stacking, // draw_stacking_context(…, true): a positioned item
        pseudo,   // draw_stacking_context(…, false): a float, an inline-block, inline-flex or inline-grid
        group     // draw_group: opacity, transform, filter, backdrop-filter, clip-path, sticky
    };
    struct paint_visitor
    {
        virtual ~paint_visitor() = default;
        // A painting context begins (its item's own paint, for every kind but a group, came just before) and ends.
        virtual void open_context(const std::shared_ptr<render_item>& item, paint_context kind) = 0;
        virtual void close_context() noexcept = 0;
        // draw_children(item, pass, zindex) begins and ends: what item clips, it clips between the two.
        virtual void open_pass(const std::shared_ptr<render_item>& item, draw_flag pass, int zindex) = 0;
        virtual void close_pass() noexcept = 0;
        // Where draw() paints `item` itself, in `pass` (draw_root for a context's own paint), at (x, y). `paint` runs that
        // paint, with no visitor installed while it does.
        virtual void paint_element(const std::shared_ptr<render_item>& item, draw_flag pass, pixel_t x, pixel_t y,
                                   const std::function<void()>& paint) = 0;
    };
    extern thread_local paint_visitor* g_paint_visitor;
    // document::draw(hdc, x, y, nullptr) with `visitor` installed: litehtml's own paint order, painting nothing itself.
    void walk_paint_order(document& doc, paint_visitor& visitor, uint_ptr hdc, pixel_t x, pixel_t y);
    // Runs `run` (a part of draw(): an item's draw_children, a draw_group) with `visitor` installed.
    void with_paint_visitor(paint_visitor& visitor, const std::function<void()>& run);
    // An item draw site: the visitor's paint_element when a walk runs, else the paint itself.
    void paint_or_visit(const std::shared_ptr<render_item>& item, draw_flag pass, uint_ptr hdc, pixel_t x, pixel_t y,
                        const position* clip, bool background = false);
    // Tells the walk's visitor where a context or a pass begins, and where it ends (the scope's end). Nothing without one.
    struct paint_context_scope
    {
        paint_visitor* visitor = nullptr;
        paint_context_scope(render_item* item, paint_context kind);
        ~paint_context_scope();
        paint_context_scope(const paint_context_scope&)            = delete;
        paint_context_scope& operator=(const paint_context_scope&) = delete;
    };
    struct paint_pass_scope
    {
        paint_visitor* visitor = nullptr;
        paint_pass_scope(render_item* item, draw_flag pass, int zindex);
        ~paint_pass_scope();
        paint_pass_scope(const paint_pass_scope&)            = delete;
        paint_pass_scope& operator=(const paint_pass_scope&) = delete;
    };
    // Where draw() paints `item` itself: the (x, y) its own draw and its draw_children get, by draw()'s arithmetic (a cell
    // or a row at its table's, a fixed item at (0, 0), a paint group shifted by its sticky offset; `before_sticky`: the
    // (x, y) draw_group is called with, before it adds the item's own sticky offset).
    void paint_origin(const render_item& item, pixel_t& x, pixel_t& y, bool before_sticky = false);
    // The clip draw_children(x, y) opens for `item`, as it computes it; false when it opens none.
    bool paint_clip(const render_item& item, pixel_t x, pixel_t y, position& box, border_radiuses& radius);
} // namespace litehtml

#endif // LITEHTML_RENDER_ITEM_H
