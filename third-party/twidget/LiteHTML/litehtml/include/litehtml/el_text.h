#ifndef LITEHTML_EL_TEXT_H
#define LITEHTML_EL_TEXT_H

#include "element.h"
#include "document.h"

namespace litehtml
{
    class text_breaker;
    class el_text : public element
    {
      protected:
        std::string m_text;
        std::string m_transformed_text;
        size        m_size;
        bool        m_use_transformed;
        bool        m_draw_spaces;
        // Telegram (VENDOR.md edit 84): made as generated content (::before/::after content, a form control's parts).
        bool        m_generated = false;
        uint_ptr    m_measured_font = 0;
        // Telegram (VENDOR.md edit 32.3): the measured width, before word-spacing.
        pixel_t     m_measured_width = 0;
        int         m_measured_transform = -1;
        std::shared_ptr<text_breaker> m_breaker;

      public:
        el_text(const char* text, const document::ptr& doc);
        // Telegram (VENDOR.md edit 10): the document counts the text pieces it holds.
        ~el_text() override;
        bool generated() const { return m_generated; } // Telegram (VENDOR.md edit 84)

        void get_text(std::string& text) const override;
        void set_text(const std::string& text);
        void compute_styles(bool recursive) override;
        const std::string& display_text() const { return m_use_transformed ? m_transformed_text : m_text; }
        std::shared_ptr<text_breaker> breaker();
        bool is_text() const override
        {
            return true;
        }

        void        draw(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip,
                         const std::shared_ptr<render_item>& ri) override;
        std::string dump_get_name() override;

        std::vector<std::tuple<std::string, std::string>> dump_get_attrs() override;

      protected:
        void get_content_size(size& sz, pixel_t max_width) override;
    };
} // namespace litehtml

#endif // LITEHTML_EL_TEXT_H
