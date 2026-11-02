#include "html.h"
#include "css_properties.h"
#include <cmath>
#include "document.h"
#include "html_tag.h"
#include "document_container.h"
#include "types.h"
#include <cstddef>
#include "css_parser.h" // Telegram (VENDOR.md edit 32.1): normalize

#define offset(member) offsetof(litehtml::css_properties, member)
// #define offset(func)	[](const css_properties& css) { return css.func; }

// Telegram (VENDOR.md edit 21, Ruling E50): an inherited string (one the element does not declare) is copied into the computed style of every descendant,
// which no charge on the declaring element bounds. Every inherited std::string computed member goes through this: a
// value over 1 KiB is cut at a comma or a character boundary; a URL (or a value holding url()) over 1 KiB is dropped for
// `fallback`, because a cut URL loads another image.
static constexpr size_t max_inherited_string_bytes = 1024;

static void bound_inherited_string(const litehtml::html_tag* el, litehtml::string_id name, std::string& value, bool is_url, const char* fallback)
{
    // A value the element declares itself is charged to the style-byte budget; the copies descendants inherit are not.
    if(el->declares_value(name))
        return;
    if(value.size() <= max_inherited_string_bytes)
        return;
    if(is_url || value.find("url(") != std::string::npos)
    {
        value = fallback;
        return;
    }
    size_t cut = value.rfind(',', max_inherited_string_bytes);
    if(cut == std::string::npos || cut == 0)
    {
        cut = max_inherited_string_bytes;
        while(cut > 0 && (static_cast<unsigned char>(value[cut]) & 0xC0) == 0x80)
            cut--;
    }
    value.resize(cut);
    value.shrink_to_fit();
}

// Telegram (VENDOR.md edit 60): an image bullet set on a list reaches its items however long its URL. The element's
// list-style-image as get_property<std::string> resolves it (its own string; nothing for initial; else its parent's), the
// parent's shared rather than copied. The copies cost a pointer, but a list item hashes and copies the URL as it lays out
// and paints its marker, so a list item inheriting one over 1 KiB is charged its length (style_charge_bullet).
static std::shared_ptr<const std::string> computed_list_style_image(const litehtml::html_tag* el, bool list_item)
{
    const litehtml::property_value& value = el->own_property(litehtml::_list_style_image_);
    if(value.is<std::string>())
    {
        const std::string& url = value.get<std::string>();
        return url.empty() ? nullptr : std::make_shared<const std::string>(url);
    }
    if(value.is<litehtml::initial>())
        return nullptr;
    const auto parent = el->parent();
    if(!parent)
        return nullptr;
    std::shared_ptr<const std::string> url = parent->css().get_list_style_image_shared();
    if(url && list_item && url->size() > max_inherited_string_bytes && !el->charge_inherited(url->size()))
        return nullptr;
    return url;
}

// Out of line (edit 60): an empty string a header's inline function held as a static would be constant-initialized in
// read-only memory by a C++20 caller and constructed at run time by a C++17 one (the fork), which then writes to it.
const std::string& litehtml::css_properties::get_list_style_image() const
{
    static const std::string none;
    return m_list_style_image ? *m_list_style_image : none;
}

void litehtml::css_properties::charge_inherited_list_style_image(const html_tag* el)
{
    if(m_list_style_image && m_display == display_list_item && m_list_style_image->size() > max_inherited_string_bytes &&
       !el->declares_value(_list_style_image_) && !el->charge_inherited(m_list_style_image->size()))
        m_list_style_image.reset();
}

void litehtml::css_properties::compute(const html_tag* el, const document::ptr& doc)
{
    m_color = el->get_property<web_color>(_color_, true, web_color::black, offset(m_color));

    m_el_position = static_cast<element_position>(
        el->get_property<int>(_position_, false, element_position_static, offset(m_el_position)));
    m_display = static_cast<style_display>(el->get_property<int>(_display_, false, display_inline, offset(m_display)));
    m_visibility =
        static_cast<visibility>(el->get_property<int>(_visibility_, true, visibility_visible, offset(m_visibility)));
    m_float = static_cast<element_float>(el->get_property<int>(_float_, false, float_none, offset(m_float)));
    m_clear = static_cast<element_clear>(el->get_property<int>(_clear_, false, clear_none, offset(m_clear)));
    m_appearance =
        static_cast<appearance>(el->get_property<int>(_appearance_, false, appearance_none, offset(m_appearance)));
    m_resize = static_cast<resize>(el->get_property<int>(_resize_, false, resize_none, offset(m_resize)));
    m_box_sizing = static_cast<box_sizing>(
        el->get_property<int>(_box_sizing_, false, box_sizing_content_box, offset(m_box_sizing)));
    m_overflow_x = static_cast<overflow>(el->get_property<int>(_overflow_x_, false, overflow_visible, offset(m_overflow_x)));
    m_overflow_y = static_cast<overflow>(el->get_property<int>(_overflow_y_, false, overflow_visible, offset(m_overflow_y)));
    m_overflow   = m_overflow_y != overflow_visible ? m_overflow_y : m_overflow_x;
    m_text_align =
        static_cast<text_align>(el->get_property<int>(_text_align_, true, text_align_start, offset(m_text_align)));
    if(m_text_align == text_align_th_center)
    {
        const text_align inherited = el->parent() ? el->parent()->css().get_text_align() : text_align_start;
        m_text_align               = inherited == text_align_start ? text_align_center : inherited;
    }
    m_vertical_align = static_cast<vertical_align>(
        el->get_property<int>(_vertical_align_, false, va_baseline, offset(m_vertical_align)));
    m_text_transform = static_cast<text_transform>(
        el->get_property<int>(_text_transform_, true, text_transform_none, offset(m_text_transform)));
    m_font_smoothing = static_cast<font_smoothing>(
        el->get_property<int>(__webkit_font_smoothing_, true, font_smoothing_auto, offset(m_font_smoothing)));
    m_white_space =
        static_cast<white_space>(el->get_property<int>(_white_space_, true, white_space_normal, offset(m_white_space)));
    m_overflow_wrap = static_cast<overflow_wrap>(el->get_property<int>(_overflow_wrap_, true, overflow_wrap_normal, offset(m_overflow_wrap)));
    // Telegram (VENDOR.md edit 32.2).
    m_word_break = el->get_property<int>(_word_break_, true, word_break_normal, offset(m_word_break));
    // Telegram (VENDOR.md edit 46).
    m_direction = el->get_property<int>(_direction_, true, direction_ltr, offset(m_direction));
    m_caption_side = static_cast<caption_side>(
        el->get_property<int>(_caption_side_, true, caption_side_top, offset(m_caption_side)));

    // https://www.w3.org/TR/CSS22/visuren.html#dis-pos-flo
    if(m_display == display_none)
    {
        // 1. If 'display' has the value 'none', then 'position' and 'float' do not apply. In this case, the element
        //    generates no box.
        m_float = float_none;
    } else
    {
        // 2. Otherwise, if 'position' has the value 'absolute' or 'fixed', the box is absolutely positioned,
        //    the computed value of 'float' is 'none', and display is set according to the table below.
        //    The position of the box will be determined by the 'top', 'right', 'bottom' and 'left' properties
        //    and the box's containing block.
        if(m_el_position == element_position_absolute || m_el_position == element_position_fixed)
        {
            m_float = float_none;

            if(m_display == display_inline_table)
            {
                m_display = display_table;
            } else if(m_display == display_inline || m_display == display_table_row_group ||
                      m_display == display_table_column || m_display == display_table_column_group ||
                      m_display == display_table_header_group || m_display == display_table_footer_group ||
                      m_display == display_table_row || m_display == display_table_cell ||
                      m_display == display_table_caption || m_display == display_inline_block)
            {
                m_display = display_block;
            }
        } else if(m_float != float_none)
        {
            // 3. Otherwise, if 'float' has a value other than 'none', the box is floated and 'display' is set
            //    according to the table below.
            if(m_display == display_inline_table)
            {
                m_display = display_table;
            } else if(m_display == display_inline || m_display == display_table_row_group ||
                      m_display == display_table_column || m_display == display_table_column_group ||
                      m_display == display_table_header_group || m_display == display_table_footer_group ||
                      m_display == display_table_row || m_display == display_table_cell ||
                      m_display == display_table_caption || m_display == display_inline_block)
            {
                m_display = display_block;
            }
        } else if(el->is_root())
        {
            // 4. Otherwise, if the element is the root element, 'display' is set according to the table below,
            //    except that it is undefined in CSS 2.2 whether a specified value of 'list-item' becomes a
            //    computed value of 'block' or 'list-item'.
            if(m_display == display_inline_table)
            {
                m_display = display_table;
            } else if(m_display == display_inline || m_display == display_table_row_group ||
                      m_display == display_table_column || m_display == display_table_column_group ||
                      m_display == display_table_header_group || m_display == display_table_footer_group ||
                      m_display == display_table_row || m_display == display_table_cell ||
                      m_display == display_table_caption || m_display == display_inline_block ||
                      m_display == display_list_item)
            {
                m_display = display_block;
            }
        } else if(el->is_replaced() && m_display == display_inline)
        {
            m_display = display_inline_block;
        }
    }
    // 5. Otherwise, the remaining 'display' property values apply as specified.

    compute_font(el, doc);
    pixel_t font_size = get_font_size();

    const css_length _auto = css_length::predef_value(0);
    const css_length none = _auto, normal = _auto;

    m_css_width  = el->get_property<css_length>(_width_, false, _auto, offset(m_css_width));
    m_css_height = el->get_property<css_length>(_height_, false, _auto, offset(m_css_height));

    m_css_min_width  = el->get_property<css_length>(_min_width_, false, _auto, offset(m_css_min_width));
    m_css_min_height = el->get_property<css_length>(_min_height_, false, _auto, offset(m_css_min_height));

    m_css_max_width  = el->get_property<css_length>(_max_width_, false, none, offset(m_css_max_width));
    m_css_max_height = el->get_property<css_length>(_max_height_, false, none, offset(m_css_max_height));

    doc->cvt_units(m_css_width, m_font_metrics, 0_px);
    m_cell_width = m_css_width;
    doc->cvt_units(m_css_height, m_font_metrics, 0_px);

    doc->cvt_units(m_css_min_width, m_font_metrics, 0_px);
    doc->cvt_units(m_css_min_height, m_font_metrics, 0_px);

    doc->cvt_units(m_css_max_width, m_font_metrics, 0_px);
    doc->cvt_units(m_css_max_height, m_font_metrics, 0_px);

    m_css_margins.left   = el->get_property<css_length>(_margin_left_, false, 0.0, offset(m_css_margins.left));
    m_css_margins.right  = el->get_property<css_length>(_margin_right_, false, 0.0, offset(m_css_margins.right));
    m_css_margins.top    = el->get_property<css_length>(_margin_top_, false, 0.0, offset(m_css_margins.top));
    m_css_margins.bottom = el->get_property<css_length>(_margin_bottom_, false, 0.0, offset(m_css_margins.bottom));

    doc->cvt_units(m_css_margins.left, m_font_metrics, 0_px);
    doc->cvt_units(m_css_margins.right, m_font_metrics, 0_px);
    doc->cvt_units(m_css_margins.top, m_font_metrics, 0_px);
    doc->cvt_units(m_css_margins.bottom, m_font_metrics, 0_px);

    m_css_padding.left   = el->get_property<css_length>(_padding_left_, false, 0.0, offset(m_css_padding.left));
    m_css_padding.right  = el->get_property<css_length>(_padding_right_, false, 0.0, offset(m_css_padding.right));
    m_css_padding.top    = el->get_property<css_length>(_padding_top_, false, 0.0, offset(m_css_padding.top));
    m_css_padding.bottom = el->get_property<css_length>(_padding_bottom_, false, 0.0, offset(m_css_padding.bottom));

    doc->cvt_units(m_css_padding.left, m_font_metrics, 0_px);
    doc->cvt_units(m_css_padding.right, m_font_metrics, 0_px);
    doc->cvt_units(m_css_padding.top, m_font_metrics, 0_px);
    doc->cvt_units(m_css_padding.bottom, m_font_metrics, 0_px);

    m_css_borders.left.color =
        get_color_property(el, _border_left_color_, false, m_color, offset(m_css_borders.left.color));
    m_css_borders.right.color =
        get_color_property(el, _border_right_color_, false, m_color, offset(m_css_borders.right.color));
    m_css_borders.top.color =
        get_color_property(el, _border_top_color_, false, m_color, offset(m_css_borders.top.color));
    m_css_borders.bottom.color =
        get_color_property(el, _border_bottom_color_, false, m_color, offset(m_css_borders.bottom.color));

    m_css_borders.left.style = static_cast<border_style>(
        el->get_property<int>(_border_left_style_, false, border_style_none, offset(m_css_borders.left.style)));
    m_css_borders.right.style = static_cast<border_style>(
        el->get_property<int>(_border_right_style_, false, border_style_none, offset(m_css_borders.right.style)));
    m_css_borders.top.style = static_cast<border_style>(
        el->get_property<int>(_border_top_style_, false, border_style_none, offset(m_css_borders.top.style)));
    m_css_borders.bottom.style = static_cast<border_style>(
        el->get_property<int>(_border_bottom_style_, false, border_style_none, offset(m_css_borders.bottom.style)));

    m_css_borders.left.width   = el->get_property<css_length>(_border_left_width_, false, border_width_medium_value,
                                                              offset(m_css_borders.left.width));
    m_css_borders.right.width  = el->get_property<css_length>(_border_right_width_, false, border_width_medium_value,
                                                              offset(m_css_borders.right.width));
    m_css_borders.top.width    = el->get_property<css_length>(_border_top_width_, false, border_width_medium_value,
                                                              offset(m_css_borders.top.width));
    m_css_borders.bottom.width = el->get_property<css_length>(_border_bottom_width_, false, border_width_medium_value,
                                                              offset(m_css_borders.bottom.width));

    if(m_css_borders.left.style == border_style_none || m_css_borders.left.style == border_style_hidden)
    {
        m_css_borders.left.width = 0;
    }
    if(m_css_borders.right.style == border_style_none || m_css_borders.right.style == border_style_hidden)
    {
        m_css_borders.right.width = 0;
    }
    if(m_css_borders.top.style == border_style_none || m_css_borders.top.style == border_style_hidden)
    {
        m_css_borders.top.width = 0;
    }
    if(m_css_borders.bottom.style == border_style_none || m_css_borders.bottom.style == border_style_hidden)
    {
        m_css_borders.bottom.width = 0;
    }

    snap_border_width(m_css_borders.left.width, doc);
    snap_border_width(m_css_borders.right.width, doc);
    snap_border_width(m_css_borders.top.width, doc);
    snap_border_width(m_css_borders.bottom.width, doc);

    m_css_borders.radius.top_left_x =
        el->get_property<css_length>(_border_top_left_radius_x_, false, 0.0, offset(m_css_borders.radius.top_left_x));
    m_css_borders.radius.top_left_y =
        el->get_property<css_length>(_border_top_left_radius_y_, false, 0.0, offset(m_css_borders.radius.top_left_y));

    m_css_borders.radius.top_right_x =
        el->get_property<css_length>(_border_top_right_radius_x_, false, 0.0, offset(m_css_borders.radius.top_right_x));
    m_css_borders.radius.top_right_y =
        el->get_property<css_length>(_border_top_right_radius_y_, false, 0.0, offset(m_css_borders.radius.top_right_y));

    m_css_borders.radius.bottom_left_x = el->get_property<css_length>(_border_bottom_left_radius_x_, false, 0.0,
                                                                      offset(m_css_borders.radius.bottom_left_x));
    m_css_borders.radius.bottom_left_y = el->get_property<css_length>(_border_bottom_left_radius_y_, false, 0.0,
                                                                      offset(m_css_borders.radius.bottom_left_y));

    m_css_borders.radius.bottom_right_x = el->get_property<css_length>(_border_bottom_right_radius_x_, false, 0.0,
                                                                       offset(m_css_borders.radius.bottom_right_x));
    m_css_borders.radius.bottom_right_y = el->get_property<css_length>(_border_bottom_right_radius_y_, false, 0.0,
                                                                       offset(m_css_borders.radius.bottom_right_y));

    doc->cvt_units(m_css_borders.radius.top_left_x, m_font_metrics, 0_px);
    doc->cvt_units(m_css_borders.radius.top_left_y, m_font_metrics, 0_px);
    doc->cvt_units(m_css_borders.radius.top_right_x, m_font_metrics, 0_px);
    doc->cvt_units(m_css_borders.radius.top_right_y, m_font_metrics, 0_px);
    doc->cvt_units(m_css_borders.radius.bottom_left_x, m_font_metrics, 0_px);
    doc->cvt_units(m_css_borders.radius.bottom_left_y, m_font_metrics, 0_px);
    doc->cvt_units(m_css_borders.radius.bottom_right_x, m_font_metrics, 0_px);
    doc->cvt_units(m_css_borders.radius.bottom_right_y, m_font_metrics, 0_px);

    m_border_collapse = static_cast<border_collapse>(
        el->get_property<int>(_border_collapse_, true, border_collapse_separate, offset(m_border_collapse)));
    m_table_layout = static_cast<table_layout>(
        el->get_property<int>(_table_layout_, false, table_layout_auto, offset(m_table_layout)));

    m_css_border_spacing_x =
        el->get_property<css_length>(__litehtml_border_spacing_x_, true, 0, offset(m_css_border_spacing_x));
    m_css_border_spacing_y =
        el->get_property<css_length>(__litehtml_border_spacing_y_, true, 0, offset(m_css_border_spacing_y));

    doc->cvt_units(m_css_border_spacing_x, m_font_metrics, 0_px);
    doc->cvt_units(m_css_border_spacing_y, m_font_metrics, 0_px);

    m_css_offsets.left   = el->get_property<css_length>(_left_, false, _auto, offset(m_css_offsets.left));
    m_css_offsets.right  = el->get_property<css_length>(_right_, false, _auto, offset(m_css_offsets.right));
    m_css_offsets.top    = el->get_property<css_length>(_top_, false, _auto, offset(m_css_offsets.top));
    m_css_offsets.bottom = el->get_property<css_length>(_bottom_, false, _auto, offset(m_css_offsets.bottom));

    doc->cvt_units(m_css_offsets.left, m_font_metrics, 0_px);
    doc->cvt_units(m_css_offsets.right, m_font_metrics, 0_px);
    doc->cvt_units(m_css_offsets.top, m_font_metrics, 0_px);
    doc->cvt_units(m_css_offsets.bottom, m_font_metrics, 0_px);

    m_z_index = el->get_property<css_length>(_z_index_, false, _auto, offset(m_z_index));
    m_content = el->get_property<std::string>(_content_, false, "", offset(m_content));
    m_cursor  = el->get_property<std::string>(_cursor_, true, "auto", offset(m_cursor));
    bound_inherited_string(el, _cursor_, m_cursor, false, "auto"); // Telegram (VENDOR.md edit 21)
    // Telegram (VENDOR.md edit 32.4): quotes, inherited; "" is auto.
    m_quotes = el->get_property<std::string>(_quotes_, true, "", offset(m_quotes));
    bound_inherited_string(el, _quotes_, m_quotes, false, "");

    m_css_text_indent = el->get_property<css_length>(_text_indent_, true, 0, offset(m_css_text_indent));
    doc->cvt_units(m_css_text_indent, m_font_metrics, 0_px);

    m_line_height.css_value =
        el->get_property<css_length>(_line_height_, true, normal, offset(m_line_height.css_value));
    if(m_line_height.css_value.is_predefined())
    {
        m_line_height.computed_value = m_font_metrics.height;
    } else if(m_line_height.css_value.units() == css_units_none)
    {
#if 0 // Telegram: a line height keeps its fraction, as WebKit's does (VENDOR.md edit 9).
        m_line_height.computed_value = pixel_t(std::floor(m_line_height.css_value.val() * font_size.value()));
#else
        m_line_height.computed_value = pixel_t(m_line_height.css_value.val() * font_size.value());
#endif
    } else
    {
        m_line_height.computed_value =
#if 0 // Telegram: a line height keeps its fraction, as WebKit's does (VENDOR.md edit 9).
            pixel_t(std::floor(doc->to_pixels(m_line_height.css_value, m_font_metrics, m_font_metrics.font_size).value()));
#else
            doc->to_pixels(m_line_height.css_value, m_font_metrics, m_font_metrics.font_size);
#endif
        m_line_height.css_value = static_cast<float>(m_line_height.computed_value);
    }

    m_list_style_type = static_cast<list_style_type>(
        el->get_property<int>(_list_style_type_, true, list_style_type_disc, offset(m_list_style_type)));
    m_list_style_position = static_cast<list_style_position>(
        el->get_property<int>(_list_style_position_, true, list_style_position_outside, offset(m_list_style_position)));

#if 0
    m_list_style_image = el->get_property<std::string>(_list_style_image_, true, "", offset(m_list_style_image));
    bound_inherited_string(el, _list_style_image_, m_list_style_image, true, ""); // Telegram (VENDOR.md edit 21)
    if(!m_list_style_image.empty())
#else
    m_list_style_image = computed_list_style_image(el, m_display == display_list_item); // Telegram (VENDOR.md edit 60)
    if(m_list_style_image)
#endif
    {
        m_list_style_image_baseurl =
            el->get_property<std::string>(_list_style_image_baseurl_, true, "", offset(m_list_style_image_baseurl));
        bound_inherited_string(el, _list_style_image_baseurl_, m_list_style_image_baseurl, true, ""); // Telegram (VENDOR.md edit 21)
#if 0
        doc->container()->load_image(get_list_style_image().c_str(), m_list_style_image_baseurl.c_str(), true);
#else
        // Telegram (VENDOR.md edit 60): only a list item draws the image; the others only pass the string on.
        if(m_display == display_list_item)
            doc->container()->load_image(get_list_style_image().c_str(), m_list_style_image_baseurl.c_str(), true);
#endif
    }

    m_order = el->get_property<int>(_order_, false, 0, offset(m_order));

    compute_background(el, doc);
    compute_flex(el, doc);
    compute_grid(el, doc);
    compute_effects(el, doc);
}

// used for all color properties except `color` (color:currentcolor is converted to color:inherit during parsing)
litehtml::web_color litehtml::css_properties::get_color_property(const html_tag* el, string_id name, bool inherited,
                                                                 web_color default_value, uint_ptr member_offset) const
{
    web_color color = el->get_property<web_color>(name, inherited, default_value, member_offset);
    if(color.is_current_color)
    {
        color = m_color;
    }
    return color;
}

namespace litehtml
{
    static const litehtml::pixel_t font_size_table[8][7] = {
        {9_px, 9_px,  9_px,  9_px,  11_px, 14_px, 18_px},
        {9_px, 9_px,  9_px,  10_px, 12_px, 15_px, 20_px},
        {9_px, 9_px,  9_px,  11_px, 13_px, 17_px, 22_px},
        {9_px, 9_px,  10_px, 12_px, 14_px, 18_px, 24_px},
        {9_px, 9_px,  10_px, 13_px, 16_px, 20_px, 26_px},
        {9_px, 9_px,  11_px, 14_px, 17_px, 21_px, 28_px},
        {9_px, 10_px, 12_px, 15_px, 17_px, 23_px, 30_px},
        {9_px, 10_px, 13_px, 16_px, 18_px, 24_px, 32_px}
    };
} // namespace litehtml

void litehtml::css_properties::compute_font(const html_tag* el, const document::ptr& doc)
{
    // initialize font size
    css_length sz = el->get_property<css_length>(_font_size_, true, css_length::predef_value(font_size_medium),
                                                 offset(m_font_size));

    pixel_t      parent_sz     = 0_px;
    pixel_t      doc_font_size = doc->container()->get_default_font_size();
    element::ptr el_parent     = el->parent();
    if(el_parent)
    {
        parent_sz = el_parent->css().get_font_size();
    } else
    {
        parent_sz = doc_font_size;
    }

    pixel_t font_size = parent_sz;

    if(sz.is_predefined())
    {
        int idx_in_table = round_f(doc_font_size.value() - 9);
        if(idx_in_table >= 0 && idx_in_table <= 7)
        {
            if(sz.predef() >= font_size_xx_small && sz.predef() <= font_size_xx_large)
            {
                font_size = font_size_table[idx_in_table][sz.predef()];
            } else if(sz.predef() == font_size_smaller)
            {
                font_size = parent_sz / 1.2_px;
            } else if(sz.predef() == font_size_larger)
            {
                font_size = parent_sz * 1.2_px;
            } else
            {
                font_size = parent_sz;
            }
        } else
        {
            switch(sz.predef())
            {
            case font_size_xx_small:
                font_size = doc_font_size * 3_px / 5_px;
                break;
            case font_size_x_small:
                font_size = doc_font_size * 3_px / 4_px;
                break;
            case font_size_small:
                font_size = doc_font_size * 8_px / 9_px;
                break;
            case font_size_large:
                font_size = doc_font_size * 6_px / 5_px;
                break;
            case font_size_x_large:
                font_size = doc_font_size * 3_px / 2_px;
                break;
            case font_size_xx_large:
                font_size = doc_font_size * 2_px;
                break;
            case font_size_smaller:
                font_size = parent_sz / 1.2_px;
                break;
            case font_size_larger:
                font_size = parent_sz * 1.2_px;
                break;
            default:
                font_size = parent_sz;
                break;
            }
        }
    } else
    {
        // Telegram (VENDOR.md edit 49): a calc with a percentage reads its em as the parent's size, as the
        // non-percentage path's to_pixels does.
        if(sz.is_calc() && sz.units() == css_units_percentage)
        {
            font_metrics fm;
            fm.x_height = fm.font_size = parent_sz;
            font_size                  = sz.calc_value(parent_sz, doc->calc_fonts_for(fm));
        } else
        if(sz.units() == css_units_percentage)
        {
            font_size = sz.calc_percent(parent_sz);
        } else
        {
            font_metrics fm;
            fm.x_height = fm.font_size = parent_sz;
            font_size                  = doc->to_pixels(sz, fm, 0_px);
        }
    }

    m_font_family = el->get_property<std::string>(_font_family_, true, doc->container()->get_default_font_name(),
                                                  offset(m_font_family));
    bound_inherited_string(el, _font_family_, m_font_family, false, ""); // Telegram (VENDOR.md edit 21)

    bool parent_keyword = el_parent ? el_parent->css().m_keyword_size : true;
    bool parent_mono    = el_parent ? el_parent->css().m_generic_mono : false;
    bool own_size       = el->has_own_property(_font_size_);
    m_keyword_size      = own_size ? sz.is_predefined() && sz.predef() <= font_size_xx_large : parent_keyword;
    std::string family  = m_font_family;
    trim(family, " \t\"'");
    m_generic_mono = m_keyword_size && t_strcasecmp(family.c_str(), "monospace") == 0;
    if(m_generic_mono && (own_size || !parent_mono))
    {
        font_size = font_size * 13_px / 16_px;
    } else if(!m_generic_mono && parent_mono && !own_size)
    {
        font_size = font_size * 16_px / 13_px;
    }

    m_font_size = static_cast<float>(font_size);

    m_font_weight = el->get_property<css_length>(_font_weight_, true, css_length::predef_value(font_weight_normal),
                                                 offset(m_font_weight));
    m_font_style =
        static_cast<font_style>(el->get_property<int>(_font_style_, true, font_style_normal, offset(m_font_style)));
    bool propagate_decoration =
        !is_one_of(m_display, display_inline_block, display_inline_table, display_inline_flex, display_inline_grid) &&
        m_float == float_none && !is_one_of(m_el_position, element_position_absolute, element_position_fixed);

    m_text_decoration_line = el->get_property<int>(_text_decoration_line_, propagate_decoration,
                                                   text_decoration_line_none, offset(m_text_decoration_line));

    // Merge parent text decoration with child text decoration
    if(propagate_decoration && el->parent())
    {
        m_text_decoration_line |= el->parent()->css().get_text_decoration_line();
    }

    if(m_text_decoration_line)
    {
        m_text_decoration_thickness = el->get_property<css_length>(
            _text_decoration_thickness_, propagate_decoration, css_length::predef_value(text_decoration_thickness_auto),
            offset(m_text_decoration_thickness));
        m_text_decoration_style = static_cast<text_decoration_style>(
            el->get_property<int>(_text_decoration_style_, propagate_decoration, text_decoration_style_solid,
                                  offset(m_text_decoration_style)));
        m_text_decoration_color = get_color_property(el, _text_decoration_color_, propagate_decoration,
                                                     web_color::current_color, offset(m_text_decoration_color));
    } else
    {
        m_text_decoration_thickness = css_length::predef_value(text_decoration_thickness_auto);
        m_text_decoration_color     = web_color::current_color;
    }

    // text-emphasis
    m_text_emphasis_style =
        el->get_property<std::string>(_text_emphasis_style_, true, "", offset(m_text_emphasis_style));
    bound_inherited_string(el, _text_emphasis_style_, m_text_emphasis_style, false, ""); // Telegram (VENDOR.md edit 21)
    m_text_emphasis_position = el->get_property<int>(_text_emphasis_position_, true, text_emphasis_position_over,
                                                     offset(m_text_emphasis_position));
    m_text_emphasis_color =
        get_color_property(el, _text_emphasis_color_, true, web_color::current_color, offset(m_text_emphasis_color));

    if(el->parent())
    {
        if(m_text_emphasis_style.empty() || m_text_emphasis_style == "initial" || m_text_emphasis_style == "unset")
        {
            m_text_emphasis_style = el->parent()->css().get_text_emphasis_style();
        }
        if(m_text_emphasis_color == web_color::current_color)
        {
            m_text_emphasis_color = el->parent()->css().get_text_emphasis_color();
        }
        m_text_emphasis_position |= el->parent()->css().get_text_emphasis_position();
    }

    if(m_font_weight.is_predefined())
    {
        switch(m_font_weight.predef())
        {
        case font_weight_bold:
            m_font_weight = 700;
            break;
        case font_weight_bolder:
            {
                const int inherited = static_cast<int>(el->parent()->css().m_font_weight.val());
                if(inherited < 400)
                {
                    m_font_weight = 400;
                } else if(inherited >= 400 && inherited < 600)
                {
                    m_font_weight = 700;
                } else
                {
                    m_font_weight = 900;
                }
            }
            break;
        case font_weight_lighter:
            {
                const int inherited = static_cast<int>(el->parent()->css().m_font_weight.val());
                if(inherited < 600)
                {
                    m_font_weight = 100;
                } else if(inherited >= 600 && inherited < 800)
                {
                    m_font_weight = 400;
                } else
                {
                    m_font_weight = 700;
                }
            }
            break;
        default:
            m_font_weight = 400;
            break;
        }
    }

    css_length letter_spacing = el->get_property<css_length>(_letter_spacing_, true, css_length::predef_value(0),
                                                             offset(m_letter_spacing));
    if(letter_spacing.is_predefined())
    {
        m_letter_spacing = 0;
    } else
    {
        font_metrics fm;
        fm.x_height = fm.font_size = font_size;
        m_letter_spacing           = static_cast<float>(doc->to_pixels(letter_spacing, fm, 0_px));
    }

    // Telegram (VENDOR.md edit 32.3): word-spacing, as letter-spacing.
    css_length word_spacing = el->get_property<css_length>(_word_spacing_, true, css_length::predef_value(0),
                                                           offset(m_word_spacing));
    if(word_spacing.is_predefined())
    {
        m_word_spacing = 0;
    } else
    {
        font_metrics fm;
        fm.x_height = fm.font_size = font_size;
        m_word_spacing             = static_cast<float>(doc->to_pixels(word_spacing, fm, 0_px));
    }

    m_text_shadows.clear();
    if(const auto* tokens = el->get_token_property(_text_shadow_))
    {
        if(parse_box_shadow(*tokens, m_text_shadows, doc->container()))
        {
            font_metrics fm;
            fm.x_height = fm.font_size = font_size;
            for(auto& shadow : m_text_shadows)
            {
                for(auto* len : {&shadow.x, &shadow.y, &shadow.blur})
                {
                    *len = static_cast<float>(doc->to_pixels(*len, fm, 0_px));
                }
            }
        }
    } else if(el->parent())
    {
        m_text_shadows = el->parent()->css().m_text_shadows;
    }

    font_description descr;
    descr.letter_spacing       = m_letter_spacing.val();
    descr.smoothing            = m_font_smoothing;
    if(!m_text_shadows.empty() && !m_text_shadows.front().inset)
    {
        const auto& shadow = m_text_shadows.front();
        descr.shadow_x     = shadow.x.val();
        descr.shadow_y     = shadow.y.val();
        descr.shadow_blur  = std::max(0.f, shadow.blur.val());
        descr.shadow_color = shadow.color.is_current_color ? m_color : shadow.color;
        for(size_t i = 1; i < m_text_shadows.size() && i < 8; i++)
        {
            const auto& extra = m_text_shadows[i];
            if(extra.inset)
                continue;
            descr.extra_shadows.push_back({extra.x.val(), extra.y.val(), std::max(0.f, extra.blur.val()), extra.color.is_current_color ? m_color : extra.color});
        }
    }
    descr.family               = m_font_family;
    descr.size                 = font_size.value();
    descr.style                = m_font_style;
    descr.weight               = static_cast<int>(m_font_weight.val());
    descr.decoration_line      = m_text_decoration_line;
    descr.decoration_thickness = m_text_decoration_thickness;
    descr.decoration_style     = m_text_decoration_style;
    descr.decoration_color     = m_text_decoration_color;
    descr.emphasis_style       = m_text_emphasis_style;
    descr.emphasis_color       = m_text_emphasis_color;
    descr.emphasis_position    = m_text_emphasis_position;
    // Telegram: font-variant-numeric is inherited like font-variant; tabular-nums reaches the font.
    m_font_variant_numeric = el->get_property<std::string>(_font_variant_numeric_, true, "", offset(m_font_variant_numeric));
    bound_inherited_string(el, _font_variant_numeric_, m_font_variant_numeric, false, ""); // Telegram (VENDOR.md edit 21)
    descr.tabular_nums     = m_font_variant_numeric.find("tabular-nums") != std::string::npos;
    // Telegram (VENDOR.md edit 32.1): font-feature-settings "tnum" (on, or a non-zero value) asks for tabular figures
    // too; the other features are not read.
    m_font_feature_settings = el->get_property<std::string>(_font_feature_settings_, true, "", offset(m_font_feature_settings));
    bound_inherited_string(el, _font_feature_settings_, m_font_feature_settings, false, "");
    if(!descr.tabular_nums && !m_font_feature_settings.empty())
    {
        css_token_vector features = normalize(m_font_feature_settings, f_componentize | f_remove_whitespace);
        bool tnum = false;
        for(size_t i = 0; i < features.size(); i++)
        {
            if(features[i].type != STRING || lowcase(features[i].str()) != "tnum")
                continue;
            tnum = true;
            if(i + 1 < features.size())
            {
                const css_token& next = features[i + 1];
                if((next.type == NUMBER && next.n.number == 0) || (next.type == IDENT && lowcase(next.ident()) == "off"))
                    tnum = false;
            }
        }
        descr.tabular_nums = tnum;
    }

    m_font = doc->get_font(descr, &m_font_metrics);
}

void litehtml::css_properties::compute_background_color(const html_tag* el)
{
    m_bg.m_color = get_color_property(el, _background_color_, false, web_color::transparent, offset(m_bg.m_color));
}

void litehtml::css_properties::compute_background(const html_tag* el, const document::ptr& doc)
{
    compute_background_color(el);

    const css_size auto_auto(css_length::predef_value(background_size_auto),
                             css_length::predef_value(background_size_auto));
    m_bg.m_position_x = el->get_property<length_vector>(
        _background_position_x_, false, {css_length(0, css_units_percentage)}, offset(m_bg.m_position_x));
    m_bg.m_position_y = el->get_property<length_vector>(
        _background_position_y_, false, {css_length(0, css_units_percentage)}, offset(m_bg.m_position_y));
    m_bg.m_size = el->get_property<size_vector>(_background_size_, false, {auto_auto}, offset(m_bg.m_size));

    for(auto& x : m_bg.m_position_x)
    {
        doc->cvt_units(x, m_font_metrics, 0_px);
    }
    for(auto& y : m_bg.m_position_y)
    {
        doc->cvt_units(y, m_font_metrics, 0_px);
    }
    for(auto& size : m_bg.m_size)
    {
        doc->cvt_units(size.width, m_font_metrics, 0_px);
        doc->cvt_units(size.height, m_font_metrics, 0_px);
    }

    m_bg.m_attachment = el->get_property<int_vector>(_background_attachment_, false, {background_attachment_scroll},
                                                     offset(m_bg.m_attachment));
    m_bg.m_repeat =
        el->get_property<int_vector>(_background_repeat_, false, {background_repeat_repeat}, offset(m_bg.m_repeat));
    m_bg.m_clip = el->get_property<int_vector>(_background_clip_, false, {background_box_border}, offset(m_bg.m_clip));
    m_bg.m_origin =
        el->get_property<int_vector>(_background_origin_, false, {background_box_padding}, offset(m_bg.m_origin));

    m_bg.m_image   = el->get_property<std::vector<image>>(_background_image_, false, {image()}, offset(m_bg.m_image));
    m_bg.m_baseurl = el->get_property<std::string>(_background_image_baseurl_, false, "", offset(m_bg.m_baseurl));

    for(auto& image : m_bg.m_image)
    {
        switch(image.type)
        {

        case image::type_none:
            break;
        case image::type_url:
            if(!image.url.empty())
            {
                doc->container()->load_image(image.url.c_str(), m_bg.m_baseurl.c_str(), true);
            }
            break;
        case image::type_gradient:
            for(auto& item : image.m_gradient.m_colors)
            {
                if(item.length)
                {
                    doc->cvt_units(*item.length, m_font_metrics, 0_px);
                }
            }
            break;
        }
    }
}

void litehtml::css_properties::compute_flex(const html_tag* el, const document::ptr& doc)
{
    if(m_display == display_grid || m_display == display_inline_grid)
    {
        m_flex_justify_content = static_cast<flex_justify_content>(el->get_property<int>(
            _justify_content_, false, flex_justify_content_flex_start, offset(m_flex_justify_content)));
        m_flex_align_items = static_cast<flex_align_items>(
            el->get_property<int>(_align_items_, false, flex_align_items_normal, offset(m_flex_align_items)));
        m_flex_align_content = static_cast<flex_align_content>(
            el->get_property<int>(_align_content_, false, flex_align_content_stretch, offset(m_flex_align_content)));
    }
    if(m_display == display_flex || m_display == display_inline_flex)
    {
        m_flex_direction = static_cast<flex_direction>(
            el->get_property<int>(_flex_direction_, false, flex_direction_row, offset(m_flex_direction)));
        m_flex_wrap =
            static_cast<flex_wrap>(el->get_property<int>(_flex_wrap_, false, flex_wrap_nowrap, offset(m_flex_wrap)));

        m_flex_justify_content = static_cast<flex_justify_content>(el->get_property<int>(
            _justify_content_, false, flex_justify_content_flex_start, offset(m_flex_justify_content)));
        m_flex_align_items     = static_cast<flex_align_items>(
            el->get_property<int>(_align_items_, false, flex_align_items_normal, offset(m_flex_align_items)));
        m_flex_align_content = static_cast<flex_align_content>(
            el->get_property<int>(_align_content_, false, flex_align_content_stretch, offset(m_flex_align_content)));
    }
    m_flex_align_self = static_cast<flex_align_items>(
        el->get_property<int>(_align_self_, false, flex_align_items_auto, offset(m_flex_align_self)));
    auto parent = el->parent();
    if(parent && (parent->css().m_display == display_flex || parent->css().m_display == display_inline_flex))
    {
        m_flex_grow   = el->get_property<float>(_flex_grow_, false, 0, offset(m_flex_grow));
        m_flex_shrink = el->get_property<float>(_flex_shrink_, false, 1, offset(m_flex_shrink));
        m_flex_basis  = el->get_property<css_length>(_flex_basis_, false, css_length::predef_value(flex_basis_auto),
                                                     offset(m_flex_basis));
        if(!m_flex_basis.is_predefined() && m_flex_basis.units() == css_units_none &&
           pixel_t(m_flex_basis.val()) != 0_px)
        {
            // flex-basis property must contain units
            m_flex_basis.predef(flex_basis_auto);
        }
        doc->cvt_units(m_flex_basis, m_font_metrics, 0_px);
        if(m_display == display_inline || m_display == display_inline_block)
        {
            m_display = display_block;
        } else if(m_display == display_inline_table)
        {
            m_display = display_table;
        } else if(m_display == display_inline_flex)
        {
            m_display = display_flex;
        }
    }
}

void litehtml::css_properties::compute_grid(const html_tag* el, const document::ptr& doc)
{
    if(m_display == display_grid || m_display == display_inline_grid)
    {
        if(const auto* tokens = el->get_token_property(_grid_template_columns_))
        {
            parse_grid_track_list(*tokens, m_grid_template_columns);
        }
        if(const auto* tokens = el->get_token_property(_grid_template_rows_))
        {
            parse_grid_track_list(*tokens, m_grid_template_rows);
        }
        if(const auto* tokens = el->get_token_property(_grid_auto_rows_))
        {
            parse_grid_track_list(*tokens, m_grid_auto_rows);
        }
        for(auto* list : {&m_grid_template_columns, &m_grid_template_rows, &m_grid_auto_rows})
        {
            for(auto* sizes : {&list->tracks, &list->repeat})
            {
                for(auto& size : *sizes)
                {
                    doc->cvt_units(size.min_len, m_font_metrics, 0_px);
                    doc->cvt_units(size.max_len, m_font_metrics, 0_px);
                }
            }
        }
        m_justify_items = static_cast<flex_align_items>(
            el->get_property<int>(_justify_items_, false, flex_align_items_normal, offset(m_justify_items)));
    }

    auto parent = el->parent();
    if(!parent || (parent->css().m_display != display_grid && parent->css().m_display != display_inline_grid))
    {
        return;
    }
    m_justify_self = static_cast<flex_align_items>(
        el->get_property<int>(_justify_self_, false, flex_align_items_auto, offset(m_justify_self)));
    auto placement = [&](string_id shorthand, string_id start, string_id end, grid_placement& out) {
        if(const auto* tokens = el->get_token_property(shorthand))
        {
            parse_grid_placement(*tokens, out);
        }
        grid_placement part;
        if(const auto* tokens = el->get_token_property(start); tokens && parse_grid_placement(*tokens, part))
        {
            out.start = part.start;
            out.span  = part.span ? part.span : out.span;
        }
        if(const auto* tokens = el->get_token_property(end); tokens && parse_grid_placement(*tokens, part))
        {
            out.end  = part.start;
            out.span = part.span ? part.span : out.span;
        }
    };
    placement(_grid_column_, _grid_column_start_, _grid_column_end_, m_grid_column);
    placement(_grid_row_, _grid_row_start_, _grid_row_end_, m_grid_row);
    if(m_display == display_inline || m_display == display_inline_block)
    {
        m_display = display_block;
    } else if(m_display == display_inline_table)
    {
        m_display = display_table;
    } else if(m_display == display_inline_flex)
    {
        m_display = display_flex;
    } else if(m_display == display_inline_grid)
    {
        m_display = display_grid;
    }
}

void litehtml::css_properties::compute_effects(const html_tag* el, const document::ptr& doc)
{
    const css_length normal = css_length::predef_value(0);
    m_row_gap               = el->get_property<css_length>(_row_gap_, false, normal, offset(m_row_gap));
    m_column_gap            = el->get_property<css_length>(_column_gap_, false, normal, offset(m_column_gap));
    for(auto* gap : {&m_row_gap, &m_column_gap})
    {
        if(gap->is_predefined())
        {
            *gap = 0;
        } else
        {
            doc->cvt_units(*gap, m_font_metrics, 0_px);
        }
    }

    m_opacity         = el->get_property<float>(_opacity_, false, 1.f, offset(m_opacity));
    m_aspect_ratio    = el->get_property<float>(_aspect_ratio_, false, 0.f, offset(m_aspect_ratio));
    m_backface_hidden = el->get_property<int>(_backface_visibility_, false, 0, offset(m_backface_hidden));
    m_transform_box   = el->get_property<int>(_transform_box_, false, transform_box_view_box, offset(m_transform_box));
    m_contain         = el->get_property<int>(_contain_, false, 0, offset(m_contain));
    if(m_contain)
    {
        if(is_one_of(m_display, display_inline, display_none, display_table_row, display_table_row_group,
                     display_table_header_group, display_table_footer_group, display_table_column,
                     display_table_column_group))
            m_contain = 0;
        else if(is_one_of(m_display, display_table, display_inline_table, display_table_cell, display_table_caption))
            m_contain &= ~(contain_size | contain_inline_size);
    }
    m_accent_color =
        el->get_property<web_color>(_accent_color_, true, web_color::transparent, offset(m_accent_color));
    m_dark_scheme = el->get_property<int>(_color_scheme_, true, 0, offset(m_dark_scheme));

    m_outline.style = static_cast<border_style>(
        el->get_property<int>(_outline_style_, false, border_style_none, offset(m_outline.style)));
    m_outline.color = get_color_property(el, _outline_color_, false, m_color, offset(m_outline.color));
    m_outline.width = el->get_property<css_length>(_outline_width_, false, border_width_medium_value,
                                                   offset(m_outline.width));
    if(m_outline.style == border_style_none || m_outline.style == border_style_hidden)
    {
        m_outline.width = 0;
    }
    snap_border_width(m_outline.width, doc);
    m_outline_offset = el->get_property<css_length>(_outline_offset_, false, 0, offset(m_outline_offset));
    doc->cvt_units(m_outline_offset, m_font_metrics, 0_px);

    m_box_shadows.clear();
    if(const auto* tokens = el->get_token_property(_box_shadow_))
    {
        if(parse_box_shadow(*tokens, m_box_shadows, doc->container()))
        {
            for(auto& shadow : m_box_shadows)
            {
                for(auto* len : {&shadow.x, &shadow.y, &shadow.blur, &shadow.spread})
                {
                    doc->cvt_units(*len, m_font_metrics, 0_px);
                }
                if(shadow.color.is_current_color)
                {
                    shadow.color = m_color;
                }
            }
            // Telegram: a finite length that converts to a non-finite one (1e38em) leaves the value unset too.
            bool finite = true;
            for(const auto& shadow : m_box_shadows)
                finite = finite && std::isfinite(shadow.x.val()) && std::isfinite(shadow.y.val()) &&
                         std::isfinite(shadow.blur.val()) && std::isfinite(shadow.spread.val());
            if(!finite)
                m_box_shadows.clear();
        }
    }

    for(auto [id, list] : {std::pair<string_id, filter_vector*>{_filter_, &m_filter}, {_backdrop_filter_, &m_backdrop_filter}})
    {
        list->clear();
        if(const auto* tokens = el->get_token_property(id))
        {
            if(parse_filter(*tokens, *list, doc->container()))
            {
                for(auto& fn : *list)
                {
                    for(auto* len : {&fn.x, &fn.y, &fn.radius})
                    {
                        doc->cvt_units(*len, m_font_metrics, 0_px);
                    }
                    fn.radius = css_length(std::min(fn.radius.val(), 256.f), css_units_px);
                    fn.x      = css_length(std::clamp(fn.x.val(), -1024.f, 1024.f), css_units_px);
                    fn.y      = css_length(std::clamp(fn.y.val(), -1024.f, 1024.f), css_units_px);
                    if(fn.color.is_current_color)
                    {
                        fn.color = m_color;
                    }
                }
            }
        }
    }
    if(!m_backdrop_filter.empty())
    {
        doc->has_backdrop = true;
    }

    m_clip_path = clip_path_shape();
    if(const auto* tokens = el->get_token_property(_clip_path_))
    {
        if(parse_clip_path(*tokens, m_clip_path))
        {
            for(auto& len : m_clip_path.values)
                doc->cvt_units(len, m_font_metrics, 0_px);
        }
    }

    m_transform.clear();
    if(const auto* tokens = el->get_token_property(_transform_))
    {
        if(parse_transform(*tokens, m_transform))
        {
            for(auto& fn : m_transform)
            {
                doc->cvt_units(fn.x, m_font_metrics, 0_px);
                doc->cvt_units(fn.y, m_font_metrics, 0_px);
            }
            // Telegram: as for box-shadow, a length that converts to a non-finite one leaves the transform unset.
            bool finite = true;
            for(const auto& fn : m_transform)
                finite = finite && std::isfinite(fn.x.val()) && std::isfinite(fn.y.val());
            if(!finite)
                m_transform.clear();
        }
    }
    // Telegram (VENDOR.md edit 37): object-fit and object-position (as background-position: one or two values).
    m_object_fit        = el->get_property<int>(_object_fit_, false, object_fit_fill, offset(m_object_fit));
    m_text_overflow     = el->get_property<int>(_text_overflow_, false, text_overflow_clip, offset(m_text_overflow)); // edit 40
    m_object_position_x = css_length(50, css_units_percentage);
    m_object_position_y = css_length(50, css_units_percentage);
    if(const auto* tokens = el->get_token_property(_object_position_))
    {
        int        index = 0;
        css_length x, y;
        if(parse_bg_position(*tokens, index, x, y, true) && index == static_cast<int>(tokens->size()))
        {
            doc->cvt_units(x, m_font_metrics, 0_px);
            doc->cvt_units(y, m_font_metrics, 0_px);
            m_object_position_x = x;
            m_object_position_y = y;
        }
    }
    // Telegram (VENDOR.md edit 34): translate, rotate and scale, before transform's functions in that order (CSS
    // Transforms 2 §6: translate · rotate · scale · transform, about the origin).
    m_transform_individual = 0;
    {
        transform_vector individual;
        for(string_id name : {_translate_, _rotate_, _scale_})
        {
            const auto*        tokens = el->get_token_property(name);
            transform_function fn;
            if(!tokens || !parse_individual_transform(name, *tokens, fn))
                continue;
            doc->cvt_units(fn.x, m_font_metrics, 0_px);
            doc->cvt_units(fn.y, m_font_metrics, 0_px);
            if(std::isfinite(fn.x.val()) && std::isfinite(fn.y.val()))
                individual.push_back(fn);
        }
        m_transform.insert(m_transform.begin(), individual.begin(), individual.end());
        m_transform_individual = individual.size();
    }
    if(const auto* tokens = el->get_token_property(_transform_origin_))
    {
        if(parse_transform_origin(*tokens, m_transform_origin_x, m_transform_origin_y))
        {
            doc->cvt_units(m_transform_origin_x, m_font_metrics, 0_px);
            doc->cvt_units(m_transform_origin_y, m_font_metrics, 0_px);
        }
    }
}

// https://www.w3.org/TR/css-values-4/#snap-a-length-as-a-border-width
void litehtml::css_properties::snap_border_width(css_length& width, const std::shared_ptr<document>& doc)
{
    if(width.is_predefined() || width.units() == css_units_percentage)
    {
        return;
    }

    pixel_t px = doc->to_pixels(width, m_font_metrics, 0_px);

    if(px > 0_px && px < 0.5_px)
    {
        px = 0.5_px;
    } else
    {
        px = std::floor(px.value() * 2) / 2;
    }

    width.set_value(px.value(), css_units_px);
}

std::vector<std::tuple<std::string, std::string>> litehtml::css_properties::dump_get_attrs()
{
    std::vector<std::tuple<std::string, std::string>> ret;

    ret.emplace_back("display", css_values(style_display_strings).value_by_index(m_display));
    ret.emplace_back("el_position", css_values(element_position_strings).value_by_index(m_el_position));
    ret.emplace_back("text_align", css_values(text_align_strings).value_by_index(m_text_align));
    ret.emplace_back("font_size", m_font_size.to_string());
    ret.emplace_back("overflow", css_values(overflow_strings).value_by_index(m_overflow));
    ret.emplace_back("white_space", css_values(white_space_strings).value_by_index(m_white_space));
    ret.emplace_back("visibility", css_values(visibility_strings).value_by_index(m_visibility));
    ret.emplace_back("appearance", css_values(appearance_strings).value_by_index(m_appearance));
    ret.emplace_back("box_sizing", css_values(box_sizing_strings).value_by_index(m_box_sizing));
    ret.emplace_back("z_index", m_z_index.to_string());
    ret.emplace_back("vertical_align", css_values(vertical_align_strings).value_by_index(m_vertical_align));
    ret.emplace_back("float", css_values(element_float_strings).value_by_index(m_float));
    ret.emplace_back("clear", css_values(element_clear_strings).value_by_index(m_clear));
    ret.emplace_back("margins", m_css_margins.to_string());
    ret.emplace_back("padding", m_css_padding.to_string());
    ret.emplace_back("borders", m_css_borders.to_string());
    ret.emplace_back("width", m_css_width.to_string());
    ret.emplace_back("height", m_css_height.to_string());
    ret.emplace_back("min_width", m_css_min_width.to_string());
    ret.emplace_back("min_height", m_css_min_width.to_string());
    ret.emplace_back("max_width", m_css_max_width.to_string());
    ret.emplace_back("max_height", m_css_max_width.to_string());
    ret.emplace_back("offsets", m_css_offsets.to_string());
    ret.emplace_back("text_indent", m_css_text_indent.to_string());
    ret.emplace_back("line_height", std::to_string(m_line_height.computed_value.value()));
    ret.emplace_back("list_style_type", css_values(list_style_type_strings).value_by_index(m_list_style_type));
    ret.emplace_back("list_style_position",
                     css_values(list_style_position_strings).value_by_index(m_list_style_position));
    ret.emplace_back("border_spacing_x", m_css_border_spacing_x.to_string());
    ret.emplace_back("border_spacing_y", m_css_border_spacing_y.to_string());

    return ret;
}
