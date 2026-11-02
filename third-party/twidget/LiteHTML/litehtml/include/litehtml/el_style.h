#ifndef LITEHTML_EL_STYLE_H
#define LITEHTML_EL_STYLE_H

#include "element.h"

namespace litehtml
{
    class el_style : public element
    {
        elements_list m_children;

      public:
        explicit el_style(const std::shared_ptr<document>& doc);

        void        parse_attributes() override;
        bool        appendChild(const ptr& el) override;
        bool        accepts_child(string_id /*tag*/) const override { return false; } // Telegram (VENDOR.md edit 83)
        bool        accepts_text() const override { return true; }
        // Telegram (VENDOR.md edit 81): its text pieces (its own list: element::children() never holds them), and the list
        // replaced.
        const elements_list& sheet_pieces() const { return m_children; }
        void                 replace_pieces(elements_list pieces) { m_children = std::move(pieces); }
        void        compute_styles(bool recursive) override;
        string_id   tag() const override;
        const char* get_tagName() const override;
    };
} // namespace litehtml

#endif // LITEHTML_EL_STYLE_H
