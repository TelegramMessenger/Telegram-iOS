#include "render_image.h"
#include "document.h"
#include "types.h"

litehtml::rendered_width litehtml::render_item_image::_render(pixel_t x, pixel_t y,
                                                              const containing_block_context& containing_block_size,
                                                              formatting_context* /*fmt_ctx*/, bool /*second_pass*/)
{
    pixel_t                  parent_width = containing_block_size.width;
    containing_block_context self_size    = calculate_containing_block_context(containing_block_size);

    calc_outlines(parent_width);

    m_pos.move_to(x, y);

    document::ptr doc = src_el()->get_document();

    litehtml::size sz;
    src_el()->get_content_size(sz, containing_block_size.width);

    m_pos.width  = sz.width;
    m_pos.height = sz.height;

    src_el()->css_w().line_height_w().computed_value = height();

    // Telegram (VENDOR.md edit 69): a percentage height whose containing block's height is indefinite computes to auto
    // (CSS 2.1 §10.5), so the size follows the width and the natural ratio: a grid measuring its rows lays an
    // auto-height button out, and a mark at 58 % of it is not 58 % of the grid.
    const css_length& css_height  = src_el()->css().get_height();
    const bool        height_auto = css_height.is_predefined() ||
                             (css_height.units() == css_units_percentage &&
                              containing_block_size.height.type == containing_block_context::cbc_value_type_auto);

    if(height_auto && src_el()->css().get_width().is_predefined())
    {
        m_pos.height = sz.height;
        m_pos.width  = sz.width;

        // check for max-width
        if(!src_el()->css().get_max_width().is_predefined())
        {
            pixel_t max_width = doc->to_pixels(css().get_max_width(), css().get_font_metrics(), parent_width);
            if(m_pos.width > max_width)
            {
                m_pos.width = max_width;
            }
            if(sz.width != 0_px)
            {
                m_pos.height = m_pos.width * sz.height / sz.width;
            } else
            {
                m_pos.height = sz.height;
            }
        }

        // check for max-height
        if(!src_el()->css().get_max_height().is_predefined())
        {
            pixel_t max_height = calc_max_height(sz.height, containing_block_size.height);
            if(m_pos.height > max_height)
            {
                m_pos.height = max_height;
            }
            if(sz.height != 0_px)
            {
                m_pos.width = m_pos.height * sz.width / sz.height;
            } else
            {
                m_pos.width = sz.width;
            }
        }
    } else if(!height_auto && src_el()->css().get_width().is_predefined())
    {
        if(self_size.height.type != containing_block_context::cbc_value_type_auto && self_size.height.value > 0_px)
        {
            m_pos.height = self_size.height;
        }

        // check for max-height
        if(!src_el()->css().get_max_height().is_predefined())
        {
            pixel_t max_height = calc_max_height(sz.height, containing_block_size.height);
            if(m_pos.height > max_height)
            {
                m_pos.height = max_height;
            }
        }

        if(sz.height != 0_px)
        {
            m_pos.width = m_pos.height * sz.width / sz.height;
        } else
        {
            m_pos.width = sz.width;
        }
    } else if(height_auto && !src_el()->css().get_width().is_predefined())
    {
        m_pos.width = src_el()->css().get_width().calc_percent(parent_width);

        // check for max-width
        if(!src_el()->css().get_max_width().is_predefined())
        {
            pixel_t max_width = doc->to_pixels(css().get_max_width(), css().get_font_metrics(), parent_width);
            if(m_pos.width > max_width)
            {
                m_pos.width = max_width;
            }
        }

        if(sz.width != 0_px)
        {
            m_pos.height = m_pos.width * sz.height / sz.width;
        } else
        {
            m_pos.height = sz.height;
        }
    } else
    {
        m_pos.width  = src_el()->css().get_width().calc_percent(parent_width);
        m_pos.height = 0_px;
        if(self_size.height.type != containing_block_context::cbc_value_type_auto && self_size.height.value > 0_px)
        {
            m_pos.height = self_size.height;
        }

        // check for max-height
        if(!src_el()->css().get_max_height().is_predefined())
        {
            pixel_t max_height = calc_max_height(sz.height, containing_block_size.height);
            if(m_pos.height > max_height)
            {
                m_pos.height = max_height;
            }
        }

        // check for max-height
        if(!src_el()->css().get_max_width().is_predefined())
        {
            pixel_t max_width = doc->to_pixels(css().get_max_width(), css().get_font_metrics(), parent_width);
            if(m_pos.width > max_width)
            {
                m_pos.width = max_width;
            }
        }
    }

    m_pos.x += content_offset_left();
    m_pos.y += content_offset_top();

    rendered_width ret;
    ret.natural_width = ret.min_width = m_pos.width + content_offset_left() + content_offset_right();
    // Telegram (VENDOR.md edit 68): a replaced element sized by a percentage width or max-width is compressible (CSS
    // Sizing 3 §5.2.2): its min-content contribution resolves the percentage against zero, so a mark at 58 % of its
    // grid cell does not widen the cell's track to 58 % of the grid.
    const css_length& width     = src_el()->css().get_width();
    const css_length& max_width = src_el()->css().get_max_width();
    if((!width.is_predefined() && width.units() == css_units_percentage) ||
       (!max_width.is_predefined() && max_width.units() == css_units_percentage))
    {
        ret.min_width = content_offset_left() + content_offset_right();
    }

    return ret;
}

litehtml::pixel_t litehtml::render_item_image::calc_max_height(pixel_t image_height, pixel_t containing_block_height)
{
    document::ptr doc = src_el()->get_document();
    return doc->to_pixels(css().get_max_height(), css().get_font_metrics(),
                          containing_block_height == 0_px ? image_height : containing_block_height);
}
