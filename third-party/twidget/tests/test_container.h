// A deterministic document_container for host tests of the vendored litehtml: every glyph is
// 8 px wide, fonts have ascent 12 / descent 4, images are refused, and every drawing callback is
// recorded with the `hdc` it arrived with (the fork's per-element token, see VENDOR.md).
#pragma once

#include <litehtml.h>

#include <cstdio>
#include <string>
#include <vector>

namespace litehtml_test {

struct DrawCall {
    std::string kind;
    litehtml::uint_ptr hdc = 0;
};

class TestContainer : public litehtml::document_container {
public:
    std::vector<DrawCall> calls;
    std::vector<litehtml::font_description> fonts;
    int width = 300;
    int scheme = 0;    // media_features::color_scheme
    int reduced = 0;   // media_features::reduced_motion

    litehtml::uint_ptr create_font(const litehtml::font_description& descr, const litehtml::document*, litehtml::font_metrics* fm) override {
        fonts.push_back(descr);
        if (fm) {
            fm->font_size = descr.size;
            fm->ascent = 12;
            fm->descent = 4;
            fm->height = 16;
            fm->x_height = 6;
            fm->ch_width = 8;
            fm->draw_spaces = false;
            fm->sub_shift = 2;
            fm->super_shift = 4;
        }
        return litehtml::uint_ptr(fonts.size());
    }
    void delete_font(litehtml::uint_ptr) override {}
    litehtml::pixel_t text_width(const char* text, litehtml::uint_ptr) override {
        return litehtml::pixel_t(float(8 * std::string(text).size()));
    }
    void draw_text(litehtml::uint_ptr hdc, const char*, litehtml::uint_ptr, litehtml::web_color, const litehtml::position&) override { calls.push_back({"text", hdc}); }
    litehtml::pixel_t pt_to_px(float pt) const override { return litehtml::pixel_t(pt * 96.0f / 72.0f); }
    litehtml::pixel_t get_default_font_size() const override { return 16; }
    const char* get_default_font_name() const override { return "sans-serif"; }
    void draw_list_marker(litehtml::uint_ptr hdc, const litehtml::list_marker&) override { calls.push_back({"marker", hdc}); }
    void load_image(const char*, const char*, bool) override {}
    void get_image_size(const char*, const char*, litehtml::size& sz) override { sz.width = 0; sz.height = 0; }
    void draw_image(litehtml::uint_ptr hdc, const litehtml::background_layer&, const std::string&, const std::string&) override { calls.push_back({"image", hdc}); }
    void draw_solid_fill(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::web_color&) override { calls.push_back({"fill", hdc}); }
    void draw_linear_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::background_layer::linear_gradient&) override { calls.push_back({"linear", hdc}); }
    void draw_radial_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::background_layer::radial_gradient&) override { calls.push_back({"radial", hdc}); }
    void draw_conic_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::background_layer::conic_gradient&) override { calls.push_back({"conic", hdc}); }
    void draw_borders(litehtml::uint_ptr hdc, const litehtml::borders&, const litehtml::position&, bool) override { calls.push_back({"borders", hdc}); }
    void set_caption(const char*) override {}
    void set_base_url(const char*) override {}
    void link(const std::shared_ptr<litehtml::document>&, const litehtml::element::ptr&) override {}
    void on_anchor_click(const char*, const litehtml::element::ptr&) override {}
    void on_mouse_event(const litehtml::element::ptr&, litehtml::mouse_event) override {}
    void set_cursor(const char*) override {}
    void transform_text(std::string&, litehtml::text_transform) override {}
    void import_css(std::string& text, const std::string&, std::string&) override { text.clear(); }
    void set_clip(const litehtml::position&, const litehtml::border_radiuses&) override {}
    void del_clip() override {}
    void get_viewport(litehtml::position& v) const override { v.x = 0; v.y = 0; v.width = litehtml::pixel_t(float(width)); v.height = 600; }
    litehtml::element::ptr create_element(const char*, const litehtml::string_map&, const std::shared_ptr<litehtml::document>&) override { return nullptr; }
    void get_media_features(litehtml::media_features& m) const override {
        m.type = litehtml::media_type_screen;
        m.width = litehtml::pixel_t(float(width));
        m.height = 600;
        m.device_width = m.width;
        m.device_height = m.height;
        m.color = 8;
        m.color_index = 256;
        m.monochrome = 0;
        m.resolution = 96;
        m.color_scheme = scheme;
        m.reduced_motion = reduced;
    }
    void get_language(std::string& language, std::string& culture) const override { language = "en"; culture.clear(); }
};

/// Parses and lays `html` out at `width`; the container is reused so callers can inspect it.
inline litehtml::document::ptr layout(TestContainer& c, const std::string& html, int width = 300) {
    c.width = width;
    auto doc = litehtml::document::createFromString(litehtml::estring(html), &c);
    doc->render(litehtml::pixel_t(float(width)));
    return doc;
}

} // namespace litehtml_test

#define CHECK(c) do { if (!(c)) { std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); failures++; } } while (0)
