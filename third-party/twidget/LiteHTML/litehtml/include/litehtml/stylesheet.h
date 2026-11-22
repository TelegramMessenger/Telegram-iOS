#ifndef LITEHTML_STYLESHEET_H
#define LITEHTML_STYLESHEET_H

#include <unordered_map>
#include <utility>

#include "css_selector.h"
#include "css_tokenizer.h"

namespace litehtml
{

    // https://www.w3.org/TR/cssom-1/#css-declarations
    struct raw_declaration
    {
        using vector = std::vector<raw_declaration>;

        // property name
        std::string name;
        // default value is specified here to get rid of gcc warning "missing initializer for member"
        css_token_vector value;

        bool important = false;

        operator bool() const
        {
            return name != "";
        }
    };

    // intermediate half-parsed rule that is used internally by the parser
    class raw_rule
    {
      public:
        using ptr    = std::shared_ptr<raw_rule>;
        using vector = std::vector<ptr>;

        enum rule_type
        {
            qualified,
            at
        };

        raw_rule(rule_type type, std::string name = {}) :
            type(type),
            name(std::move(name))
        {
        }

        rule_type type;
        // An at-rule has a name, a prelude consisting of a list of component values, and an optional block consisting
        // of a simple {} block.
        std::string name;
        // https://www.w3.org/TR/css-syntax-3/#qualified-rule
        // A qualified rule has a prelude consisting of a list of component values, and a block consisting of a simple
        // {} block. Note: Most qualified rules will be style rules, where the prelude is a selector and the block a
        // list of declarations.
        css_token_vector prelude;
        css_token        block;
    };

    class css
    {
        css_selector::vector m_selectors;
        // Telegram (VENDOR.md edit 81): the selectors in parse order, and each parsed sheet's end in it.
        css_selector::vector m_parsed;
        std::vector<int>     m_sheet_ends;
        // Telegram (VENDOR.md edit 41): whether each @layer block's rules rank above the sheet's unlayered ones (the
        // master sheet's), the block being parsed (0: none) and the last one numbered.
        bool m_layered_origins = false;
        int  m_layer           = 0;
        int  m_layer_count     = 0;

      public:
        void set_layered_origins(bool value) { m_layered_origins = value; } // Telegram (VENDOR.md edit 41)

        const css_selector::vector& selectors() const
        {
            return m_selectors;
        }
        // Telegram (VENDOR.md edit 81): the selectors in parse order (css_selector::m_order numbers them as parsed), and the
        // end in it of each sheet parse_css_stylesheet parsed before an end_sheet; a sheet the caller skipped ends where
        // the one before it did.
        const css_selector::vector& parsed() const { return m_parsed; }
        const std::vector<int>&     sheet_ends() const { return m_sheet_ends; }
        void                        end_sheet() { m_sheet_ends.push_back(static_cast<int>(m_parsed.size())); }
        // Telegram (VENDOR.md edits 79, 81): selectors replaced in place, in both orders, each by the one `with` maps it to
        // (an environment change's re-parse, a sheet change keeping a sheet's rules).
        void replace_selectors(const std::unordered_map<const css_selector*, css_selector::ptr>& with)
        {
            for(css_selector::vector* list : {&m_selectors, &m_parsed})
            {
                for(auto& selector : *list)
                {
                    auto found = with.find(selector.get());
                    if(found != with.end())
                        selector = found->second;
                }
            }
        }

        template <class Input>
        void parse_css_stylesheet(const Input& input, const std::string& baseurl, const std::shared_ptr<document>& doc,
                                  const media_query_list_list::ptr& media = nullptr, bool top_level = true);

        void sort_selectors();

      private:
        bool parse_style_rule(const raw_rule::ptr& rule, const std::string& baseurl,
                              const std::shared_ptr<document>& doc, const media_query_list_list::ptr& media);
        void parse_import_rule(const raw_rule::ptr& rule, const std::string& baseurl,
                               const std::shared_ptr<document>& doc, const media_query_list_list::ptr& media);
        void add_selector(const css_selector::ptr& selector);
    };

    inline void css::add_selector(const css_selector::ptr& selector)
    {
        selector->m_order = static_cast<int>(m_selectors.size());
        selector->m_layer = m_layer; // Telegram (VENDOR.md edit 41)
        m_selectors.push_back(selector);
        m_parsed.push_back(selector); // Telegram (VENDOR.md edit 81)
    }

} // namespace litehtml

#endif // LITEHTML_STYLESHEET_H
