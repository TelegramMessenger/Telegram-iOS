#include "html.h"
#include "el_text.h"
#include "render_item.h"
#include "render_inline.h"
#include "document_container.h"

litehtml::el_text::el_text(const char* text, const document::ptr& doc) :
    element(doc)
{
    if(text)
    {
        m_text = text;
    }
    m_use_transformed = false;
    m_draw_spaces     = true;
    css_w().set_display(display_inline_text);
    // Telegram (VENDOR.md edit 10).
    if(doc)
    {
        doc->note_text_element(1);
        // Telegram (VENDOR.md edit 84): generated content's pieces are counted apart from the document's own text.
        if(doc->making_generated())
        {
            m_generated = true;
            doc->note_generated_piece(1);
        }
    }
}

// Telegram (VENDOR.md edit 10). A document being destroyed is no longer reachable here, and needs no count.
litehtml::el_text::~el_text()
{
    if(auto doc = get_document())
    {
        doc->note_text_element(-1);
        if(m_generated)
            doc->note_generated_piece(-1); // Telegram (VENDOR.md edit 84)
    }
}

void litehtml::el_text::get_content_size(size& sz, pixel_t /*max_width*/)
{
    sz = m_size;
}

void litehtml::el_text::get_text(std::string& text) const
{
    text += m_text;
}

void litehtml::el_text::set_text(const std::string& text)
{
    m_text = text;
    m_transformed_text.clear();
    m_use_transformed = false;
    m_draw_spaces     = true;
    m_size            = size();
    m_measured_font   = 0;
    m_breaker.reset();
    mark_layout_dirty();
    css_w()           = css_properties();
    css_w().set_display(display_inline_text);
}

void litehtml::el_text::compute_styles(bool /*recursive*/)
{
    mark_layout_dirty();
    element::ptr el_parent = parent();
    if(el_parent)
    {
        css_w().line_height_w() = el_parent->css().line_height();
        css_w().set_font(el_parent->css().get_font());
        css_w().set_font_metrics(el_parent->css().get_font_metrics());
        css_w().set_white_space(el_parent->css().get_white_space());
        css_w().set_overflow_wrap(el_parent->css().get_overflow_wrap());
        // Telegram (VENDOR.md edit 32.2): word-break: break-all (and the legacy break-word) breaks anywhere, as
        // overflow-wrap: anywhere does; keep-all is not modelled.
        if(el_parent->css().get_word_break() == word_break_break_all || el_parent->css().get_word_break() == word_break_break_word)
            css_w().set_overflow_wrap(overflow_wrap_anywhere);
        css_w().set_text_transform(el_parent->css().get_text_transform());
    }
    css_w().set_display(display_inline_text);
    css_w().set_float(float_none);

    if(m_css.get_text_transform() != text_transform_none)
    {
        m_transformed_text = m_text;
        m_use_transformed  = true;
        get_document()->container()->transform_text(m_transformed_text, m_css.get_text_transform());
    } else
    {
        m_use_transformed = false;
    }

    element::ptr p = parent();
    while(p && p->css().get_display() == display_inline)
    {
        if(p->css().get_position() == element_position_relative)
        {
            css_w().set_offsets(p->css().get_offsets());
            css_w().set_position(element_position_relative);
            break;
        }
        p = p->parent();
    }
    if(p)
    {
        css_w().set_position(element_position_static);
    }

    if(is_white_space())
    {
        m_transformed_text = " ";
        m_use_transformed  = true;
    } else
    {
        if(m_text == "\t")
        {
            m_transformed_text = "    ";
            m_use_transformed  = true;
        }
        if(m_text == "\n" || m_text == "\r")
        {
            m_transformed_text = "";
            m_use_transformed  = true;
        }
    }

    font_metrics fm;
    uint_ptr     font = 0;
    if(el_parent)
    {
        font = el_parent->css().get_font();
        fm   = el_parent->css().get_font_metrics();
    }
    if(is_break() || !font)
    {
        m_size.height      = 0;
        m_size.width       = 0;
        m_measured_font    = 0;
    } else
    {
        m_size.height = fm.height;
        const int transform = m_use_transformed ? (is_white_space() ? -2 : int(m_css.get_text_transform())) : -3;
        if(m_measured_font != font || m_measured_transform != transform)
        {
            m_breaker.reset();
            m_size.width = get_document()->container()->text_width(
                m_use_transformed ? m_transformed_text.c_str() : m_text.c_str(), font);
            m_measured_font      = font;
            m_measured_transform = transform;
            m_measured_width     = m_size.width; // Telegram (VENDOR.md edit 32.3)
        }
        // Telegram (VENDOR.md edit 32.3): word-spacing widens each space.
        if(is_white_space() && el_parent)
        {
            m_size.width = m_measured_width + el_parent->css().get_word_spacing();
        }
    }
    m_draw_spaces = fm.draw_spaces;
}

std::shared_ptr<litehtml::text_breaker> litehtml::el_text::breaker()
{
    if(!m_breaker)
        m_breaker = doc_ptr()->container()->create_text_breaker(display_text(), css().get_font());
    return m_breaker;
}

void litehtml::el_text::draw(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip,
                             const std::shared_ptr<render_item>& ri)
{
    if(is_white_space() && !m_draw_spaces)
    {
        return;
    }

    const auto text_item = std::dynamic_pointer_cast<render_text>(ri);
    if(text_item && !text_item->fragments.empty())
    {
        for(const auto& fragment : text_item->fragments)
            draw(hdc, x, y, clip, fragment);
        return;
    }

    position pos  = ri->pos();
    pos.x        += x;
    pos.y        += y;
    {
        const float k = pixel_snap_scale();
        pos.y         = std::round(pos.y.value() * k) / k;
    }

    position ink = pos;
    {
        const pixel_t slack = std::max(pixel_t(4), ink.height / 2_px);
        ink.x     -= slack;
        ink.y     -= slack;
        ink.width += slack * 2_px;
        ink.height += slack * 2_px;
    }
    if(ink.does_intersect(clip))
    {
        element::ptr el_parent = parent();
        if(el_parent)
        {
            document* doc = doc_ptr();

            uint_ptr font = el_parent->css().get_font();
            if(font)
            {
                web_color color = el_parent->css().get_color();
#if 0
                doc->container()->draw_text(hdc, text_item && text_item->is_fragment ? text_item->fragment_text.c_str() : display_text().c_str(), font,
                                            color, pos);
#else
                // Telegram (VENDOR.md edit 40): a piece cut at its line's ellipsis draws only what fits.
                const std::string& drawn = text_item && text_item->is_fragment ? text_item->fragment_text : display_text();
                const int          bytes = ri->ellipsis_bytes();
                if(bytes < 0)
                    doc->container()->draw_text(hdc, drawn.c_str(), font, color, pos);
                else if(bytes > 0)
                    doc->container()->draw_text(hdc, drawn.substr(0, static_cast<size_t>(bytes)).c_str(), font, color, pos);
                // The ellipsis, on this piece's baseline, in the block's font and colour.
                const auto block = bytes >= 0 ? ri->ellipsis_block() : nullptr;
                if(const uint_ptr block_font = block ? block->css().get_font() : 0)
                {
                    const char* const   glyph = "\xE2\x80\xA6";
                    const font_metrics& fm    = block->css().get_font_metrics();
                    position ellipsis(pos.x + ri->ellipsis_at(),
                                      pos.y + el_parent->css().get_font_metrics().ascent - fm.ascent,
                                      doc->container()->text_width(glyph, block_font), fm.height);
                    doc->container()->draw_text(hdc, glyph, block_font, block->css().get_color(), ellipsis);
                }
#endif
            }
        }
    }
}

std::string litehtml::el_text::dump_get_name()
{
    return "text: \"" + get_escaped_string(m_text) + "\"";
}

std::vector<std::tuple<std::string, std::string>> litehtml::el_text::dump_get_attrs()
{
    return {};
}
