#ifndef LITEHTML_DOCUMENT_CONTAINER_H
#define LITEHTML_DOCUMENT_CONTAINER_H

#include "types.h"
#include "web_color.h"
#include "background.h"
#include "borders.h"
#include "css_effects.h"
#include "element.h"
#include "font_description.h"
#include <memory>
#include <functional>

namespace litehtml
{
    class text_breaker
    {
      public:
        virtual ~text_breaker() = default;
        virtual size_t fit(size_t start, pixel_t width) = 0;
        virtual pixel_t minimum_width() = 0;
    };

    struct list_marker
    {
        std::string     image;
        const char*     baseurl;
        list_style_type marker_type;
        web_color       color;
        position        pos;
        int             index;
        uint_ptr        font;
    };

    enum mouse_event
    {
        mouse_event_enter,
        mouse_event_leave,
    };

    // call back interface to draw text, images and other elements
    class document_container
    {
      public:
        virtual litehtml::uint_ptr create_font(const font_description& descr, const document* doc,
                                               litehtml::font_metrics* fm)                                          = 0;
        virtual void               delete_font(litehtml::uint_ptr hFont)                                            = 0;
        virtual pixel_t            text_width(const char* text, litehtml::uint_ptr hFont)                           = 0;
        virtual std::shared_ptr<text_breaker> create_text_breaker(const std::string&, uint_ptr) { return nullptr; }
        // Telegram (VENDOR.md edit 47): the bidi embedding level (UAX #9, after rule I2) of each of a line's units, its
        // text in UTF-8 (U+FFFC for an atomic inline), in a paragraph of direction `rtl`. False, or levels of another
        // size, keeps the logical order.
        virtual bool bidi_levels(const std::vector<std::string>& runs, bool rtl, std::vector<uint8_t>& levels) { return false; }
        virtual void               draw_text(litehtml::uint_ptr hdc, const char* text, litehtml::uint_ptr hFont,
                                             litehtml::web_color color, const litehtml::position& pos)              = 0;
        virtual pixel_t            pt_to_px(float pt) const                                                         = 0;
        virtual pixel_t            get_default_font_size() const                                                    = 0;
        virtual const char*        get_default_font_name() const                                                    = 0;
        virtual void               draw_list_marker(litehtml::uint_ptr hdc, const litehtml::list_marker& marker)    = 0;
        virtual void               load_image(const char* src, const char* baseurl, bool redraw_on_ready)           = 0;
        virtual void               get_image_size(const char* src, const char* baseurl, litehtml::size& sz)         = 0;
        virtual void draw_image(litehtml::uint_ptr hdc, const background_layer& layer, const std::string& url,
                                const std::string& base_url)                                                        = 0;
        virtual void draw_solid_fill(litehtml::uint_ptr hdc, const background_layer& layer, const web_color& color) = 0;
        virtual void draw_linear_gradient(litehtml::uint_ptr hdc, const background_layer& layer,
                                          const background_layer::linear_gradient& gradient)                        = 0;
        virtual void draw_radial_gradient(litehtml::uint_ptr hdc, const background_layer& layer,
                                          const background_layer::radial_gradient& gradient)                        = 0;
        virtual void draw_conic_gradient(litehtml::uint_ptr hdc, const background_layer& layer,
                                         const background_layer::conic_gradient& gradient)                          = 0;
        virtual void draw_borders(litehtml::uint_ptr hdc, const litehtml::borders& borders,
                                  const litehtml::position& draw_pos, bool root)                                    = 0;

        virtual void set_caption(const char* caption)                                                       = 0;
        virtual void set_base_url(const char* base_url)                                                     = 0;
        virtual void link(const std::shared_ptr<litehtml::document>& doc, const litehtml::element::ptr& el) = 0;
        virtual void on_anchor_click(const char* url, const litehtml::element::ptr& el)                     = 0;
        virtual bool on_element_click(const litehtml::element::ptr& /*el*/)
        {
            return false;
        };
        virtual void on_mouse_event(const litehtml::element::ptr& el, litehtml::mouse_event event)        = 0;
        virtual void set_cursor(const char* cursor)                                                       = 0;
        virtual void transform_text(std::string& text, litehtml::text_transform tt)                       = 0;
        virtual void import_css(std::string& text, const std::string& url, std::string& baseurl)          = 0;
        virtual void set_clip(const litehtml::position& pos, const litehtml::border_radiuses& bdr_radius) = 0;
        virtual void del_clip()                                                                           = 0;
        virtual void suspend_clips() {}
        virtual void resume_clips() {}
        virtual void get_viewport(litehtml::position& viewport) const                                     = 0;
        virtual litehtml::element::ptr create_element(const char* tag_name, const litehtml::string_map& attributes,
                                                      const std::shared_ptr<litehtml::document>& doc)     = 0;

        virtual void        get_media_features(litehtml::media_features& media) const       = 0;
        virtual void        get_language(std::string& language, std::string& culture) const = 0;
        virtual std::string resolve_color(const std::string& /*color*/) const
        {
            return {};
        }
        virtual void split_text(const char* text, const std::function<void(const char*)>& on_word,
                                const std::function<void(const char*)>& on_space);
        virtual void draw_box_shadow(litehtml::uint_ptr /*hdc*/, const position& /*box*/,
                                     const border_radiuses& /*radius*/, const shadow_paint& /*shadow*/)
        {
        }
        virtual void set_clip_path(const vector_path& path) {}
        virtual bool point_in_clip_path(const vector_path& path, pixel_t x, pixel_t y) { return true; }
        virtual void begin_group(litehtml::uint_ptr /*hdc*/, const paint_group& /*group*/) {}
        virtual void draw_filtered(litehtml::uint_ptr hdc, const filter_paint& /*filter*/,
                                   const std::function<void(litehtml::uint_ptr)>& paint)
        {
            paint(hdc);
        }
        virtual void draw_backdrop(litehtml::uint_ptr /*hdc*/, const filter_paint& /*filter*/) {}
        virtual void draw_path(litehtml::uint_ptr /*hdc*/, const vector_path& /*path*/) {}
        virtual void end_group(litehtml::uint_ptr /*hdc*/) {}
        virtual bool draw_cached(litehtml::uint_ptr /*hdc*/, const position& /*box*/, uint64_t /*key*/,
                                 const std::function<void(litehtml::uint_ptr)>& /*paint*/)
        {
            return false;
        }
        virtual void draw_isolated(litehtml::uint_ptr hdc, const position& /*box*/, const std::function<void(litehtml::uint_ptr)>& paint)
        {
            paint(hdc);
        }

        virtual bool sanitize_element(std::string& /*tag*/, bool /*svg*/, string_map& /*attrs*/) { return true; }
        virtual bool sanitize_declaration(const std::string& /*name*/, const css_token_vector& /*value*/) { return true; }
        virtual bool sanitize_at_rule(const std::string& /*name*/) { return true; }
        virtual void sanitizer_limit(const char* /*what*/) {}
        virtual void trusted_styles(bool /*trusted*/) {}
        // Telegram (VENDOR.md edit 29): the profile hooks (WidgetRuntime's V4 policy). Every default keeps litehtml's
        // behaviour, so a container overriding none of them (LHContainer) is unchanged.
        // 29.1: a declaration as it is added; may rewrite its name, value or importance; false drops it.
        virtual bool profile_declaration(std::string& name, css_token_vector& value, bool& /*important*/)
        {
            return sanitize_declaration(name, value);
        }
        // 29.2: a style rule's selector list, one comma group each; may erase or rewrite groups (none left: the rule is
        // dropped). The kept groups are parsed strictly as before.
        virtual void sanitize_selector_list(std::vector<css_token_vector>& /*groups*/) {}
        // 29.3: an @media prelude, or a <style media> attribute; false drops the rule or the sheet.
        virtual bool sanitize_media_query(const css_token_vector& /*prelude*/) { return true; }
        // 29.4: an @supports condition: 1 true, 0 false, -1 litehtml's own evaluation.
        virtual int evaluate_supports(const css_token_vector& /*condition*/) { return -1; }
        // 29.6: a non-custom declaration's value after var() substitution; may rewrite it; false drops it.
        virtual bool profile_substituted(const std::string& /*name*/, css_token_vector& /*value*/) { return true; }
        // 29.7: mixed into the declaration, author-sheet and master-sheet cache keys, so containers whose hooks differ
        // never share a cached parse.
        virtual uint32_t sanitizer_key() const { return 0; }
        virtual bool controls_active() const { return false; }
        virtual web_color control_accent() const { return web_color(0, 122, 255); }

      protected:
        virtual ~document_container() = default;
    };
} // namespace litehtml

#endif // LITEHTML_DOCUMENT_CONTAINER_H
