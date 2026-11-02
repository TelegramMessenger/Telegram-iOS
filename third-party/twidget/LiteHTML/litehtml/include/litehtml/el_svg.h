#ifndef LITEHTML_EL_SVG_H
#define LITEHTML_EL_SVG_H

#include "html_tag.h"
#include "document.h"

namespace litehtml
{
    bool  svg_geometry(const element::ptr& el, vector_path& path);
    // Telegram (VENDOR.md edit 72): a path's box (x, y, width, height) from its points and its curves' extrema, never
    // sampled; false for a path with no points.
    bool  svg_path_bounds(const vector_path& path, float box[4]);
    // Telegram (VENDOR.md edit 72): the transform the painter applies to an SVG element in its parent's user space (its
    // CSS transform about its transform-box, else its transform attribute); identity outside an <svg>.
    transform_matrix svg_element_transform(const element::ptr& el);
    float svg_path_length(const vector_path& path, float at, float* x, float* y);
    void svg_set_group_cache_enabled(bool enabled);
    // Telegram (VENDOR.md edit 30.2): an SVG property as the painter resolves it (the element's declaration, else its
    // presentation attribute, else an ancestor's), for getComputedStyle; empty when nothing sets it.
    css_token_vector svg_computed_property(const element::ptr& el, string_id name);

    class el_svg : public html_tag
    {
        friend bool svg_geometry(const element::ptr& el, vector_path& path);
        friend transform_matrix svg_element_transform(const element::ptr& el);
        bool view_box(float box[4]) const;
        uint64_t m_last_paint_key = 0;
        int      m_stable_draws   = 0;
        uint64_t m_content_key    = 0;
        uint32_t m_content_generation = 0;
        bool     m_content_cacheable  = false;
        bool     m_group_cache_eligible = false;
        bool     cacheable_paint_key(uint64_t& key) const;
        bool     cached_paint_key(uint64_t& key);
        // Telegram (VENDOR.md edit 38): the elements this svg drew inside <use> instances at its last paint, and its share
        // of the document's budget.
        int      m_use_instanced = 0;
        int      use_budget() const;
        void     note_use_drawn(int budget, int left);

      public:
        explicit el_svg(const document::ptr& doc);
        ~el_svg() override;

        bool is_replaced() const override;
        bool has_external_intrinsic_size() const override;
        void parse_attributes() override;
        void get_content_size(size& sz, pixel_t max_width) override;
        void draw(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip,
                  const std::shared_ptr<render_item>& ri) override;
        bool paint_shapes(uint_ptr hdc, const position& pos);
        element::ptr element_at(const position& pos, pixel_t x, pixel_t y);
        void view_group(const position& pos, float view[4], paint_group& group) const;

        std::shared_ptr<render_item> create_render_item(const std::shared_ptr<render_item>& parent_ri) override;
    };
} // namespace litehtml

#endif // LITEHTML_EL_SVG_H
