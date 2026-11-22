#ifndef LITEHTML_STYLE_H
#define LITEHTML_STYLE_H

#include "background.h"
#include "css_length.h"
#include "css_position.h"
#include "css_tokenizer.h"
#include "gradient.h"
#include "web_color.h"

#include <functional>

namespace litehtml
{
    struct invalid
    {
    }; // indicates "not found" condition in style::get_property
    struct inherit
    {
    }; // "inherit" was specified as the value of this property
    // Telegram (VENDOR.md edit 33): the other CSS-wide keywords as declared values. html_tag::get_property answers
    // initial with the property's initial value and unset as if nothing were declared; html_tag::resolve_reverts
    // replaces revert (and revert-layer) with the master sheet's value before the element computes.
    struct initial
    {
    };
    struct unset
    {
    };
    struct revert
    {
        // Telegram (VENDOR.md edit 50): revert-layer, which stops at the master's @layer (edit 41) where revert skips it.
        bool layer = false;
    };

#if 0
    struct property_value
        : variant<invalid, inherit, int, int_vector, css_length, length_vector, float, web_color, std::vector<image>,
                  std::string, std::vector<std::string>, size_vector, css_token_vector>
#else
    struct property_value
        : variant<invalid, inherit, int, int_vector, css_length, length_vector, float, web_color, std::vector<image>,
                  std::string, std::vector<std::string>, size_vector, css_token_vector, initial, unset, revert>
#endif
    {
        bool m_important = false;
        bool m_has_var   = false; // css_token_vector, parsing is delayed because of var()
        int  m_order     = 0;

        property_value() = default;
        template <class T>
        property_value(const T& val, bool important, bool has_var = false) :
            base(val),
            m_important(important),
            m_has_var(has_var)
        {
        }
    };

    class html_tag;
    string_id raw_declaration_id(string_id name);
    bool      is_raw_declaration(string_id name);
    using props_map = std::map<string_id, property_value>;

    // Telegram (VENDOR.md edit 79): what a declaration's parse read of the container's environment, which a change of it
    // makes stale: a viewport unit folded to pixels (fold_math), and the colour scheme (edit 80).
    constexpr int environment_viewport = 1;
    constexpr int environment_scheme   = 2;
    // Marks the declaration being parsed (style::add_property) as reading `bits` of the environment.
    void note_environment(int bits);
    // Whether a declaration's text may hold a viewport unit (edit 11's conservative scan).
    bool text_may_hold_viewport_unit(const std::string& text);

    // represents a style block, eg. "color: black; display: inline"
    class style
    {
      public:
        using ptr    = std::shared_ptr<style>;
        using vector = std::vector<style::ptr>;

      private:
        props_map                              m_properties;
        int                                    m_counter = 0;
        int                                    m_environment = 0; // Telegram (VENDOR.md edit 79)
        static std::map<string_id, css_values>& m_valid_values;

      public:
        void add(const css_token_vector& tokens, const std::string& baseurl = "",
                 document_container* container = nullptr);
        void add(const std::string& txt, const std::string& baseurl = "", document_container* container = nullptr);

        void add_property(string_id name, const css_token_vector& tokens, const std::string& baseurl = "",
                          bool important = false, document_container* container = nullptr);
        void add_property(string_id name, const std::string& val, const std::string& baseurl = "",
                          bool important = false, document_container* container = nullptr);

        const property_value& get_property(string_id name) const;

        bool empty() const
        {
            return m_properties.empty();
        }

        bool declares_custom_property() const
        {
            for(const auto& p : m_properties)
            {
                const std::string& name = _s(p.first);
                if(name.size() > 2 && name[0] == '-' && name[1] == '-')
                    return true;
            }
            return false;
        }

        template <class F> bool only_declares(F allowed) const
        {
            for(const auto& p : m_properties)
                if(!allowed(p.first))
                    return false;
            return true;
        }

        bool has_var_property() const
        {
            for(const auto& p : m_properties)
                if(p.second.m_has_var)
                    return true;
            return false;
        }

        void combine(const style& src);
        // Telegram (VENDOR.md edit 21): the heap a copy of this style's values holds (strings, string vectors, token
        // vectors); fixed-size values hold none. What combine copies onto an element, which document::style_admit charges.
        size_t payload_bytes() const;
        // What combining this style onto `base` grows base's payload by: a value replacing one of the same property
        // charges only what it holds beyond the one it replaces (a cascade of rules for one property holds one value).
        size_t payload_growth_over(const style& base) const;
        // For each property, raises `most` to the payload of this style's value: the most one element can keep of it.
        void max_payload_into(std::map<string_id, size_t>& most) const;
        // The heap payload of a token vector (what a var() splice of it copies).
        static size_t token_payload_bytes(const css_token_vector& tokens);
        // Counts the declarations holding var() and raises `largest_custom` to the largest custom property value.
        void var_stats(size_t& var_uses, size_t& largest_custom) const;
        // Combines only the properties whose values hold no heap payload (the rule past the style-byte budget).
        void combine_fixed(const style& src);
        void clear()
        {
            m_properties.clear();
            m_environment = 0;
        }
        // Telegram (VENDOR.md edit 79): the environment its declarations' parses read (environment_* bits), its own and
        // what combine brought.
        int environment() const { return m_environment; }
        // Telegram (VENDOR.md edit 80): marks it as reading `bits` of the environment outside a declaration's parse (an
        // element's paint attribute that resolves light-dark() at draw).
        void add_environment(int bits) { m_environment |= bits; }

        void subst_vars(const html_tag* el);
        // Telegram (VENDOR.md edit 33): replaces each revert with `master(name)`, the master sheet's value (nullptr:
        // none, so it is unset), keeping the reverting declaration's importance and order. `admit` is asked for the
        // heap a copy holds before it is made; refused, the property is unset.
        void resolve_reverts(const std::function<const property_value*(string_id, bool)>& master,
                             const std::function<bool(string_id, size_t)>&                 admit);

      private:
        void inherit_property(string_id name, bool important);
        // Telegram (VENDOR.md edit 33): `marker` (initial, unset or revert) over a shorthand's longhands, as
        // inherit_property does.
        void global_keyword_property(string_id name, const property_value& marker);

        void parse_background(const css_token_vector& tokens, const std::string& baseurl, bool important,
                              document_container* container);
        bool parse_bg_layer(const css_token_vector& tokens, document_container* container, background& bg,
                            bool final_layer);
        // parse the value of background-image property, which is comma-separated list of <bg-image>s
        void parse_background_image(const css_token_vector& tokens, const std::string& baseurl, bool important,
                                    document_container* container);

        // parse comma-separated list of keywords
        void parse_keyword_comma_list(string_id name, const css_token_vector& tokens, bool important);
        void parse_background_position(const css_token_vector& tokens, bool important);
        void parse_background_size(const css_token_vector& tokens, bool important);

        void parse_border(const css_token_vector& tokens, bool important, document_container* container);
        void parse_border_side(string_id name, const css_token_vector& tokens, bool important,
                               document_container* container);
        void parse_border_radius(const css_token_vector& tokens, bool important);

        bool parse_list_style_image(const css_token& tok, std::string& url);
        void parse_list_style(const css_token_vector& tokens, const std::string& baseurl, bool important);

        void parse_font(css_token_vector tokens, bool important);
        void parse_text_decoration(const css_token_vector& tokens, bool important, document_container* container);
        bool parse_text_decoration_color(const css_token& token, bool important, document_container* container);
        void parse_text_decoration_line(const css_token_vector& tokens, bool important);

        void parse_text_emphasis(const css_token_vector& tokens, bool important, document_container* container);
        bool parse_text_emphasis_color(const css_token& token, bool important, document_container* container);
        void parse_text_emphasis_position(const css_token_vector& tokens, bool important);

        void parse_flex_flow(const css_token_vector& tokens, bool important);
        void parse_flex(const css_token_vector& tokens, bool important);
        void parse_align_self(string_id name, const css_token_vector& tokens, bool important);

        void add_parsed_property(string_id name, const property_value& propval);
        void add_length_property(string_id name, const css_token& val, const css_values& keywords, int options,
                                 bool important);
        template <class T> void add_four_properties(string_id top_name, T val[4], int n, bool important);
        void                    remove_property(string_id name, bool important);
    };

    bool parse_url(const css_token& token, std::string& url);
    bool parse_length(const css_token& tok, css_length& length, int options, css_values keywords = {});
    bool parse_angle(const css_token& tok, float& angle, bool percents_allowed = false);
    bool parse_bg_position(const css_token_vector& tokens, int& index, css_length& x, css_length& y,
                           bool convert_keywords_to_percents);

    template <typename Enum>
    bool parse_keyword(const css_token& tok, Enum& val, css_values keywords, int first_keyword_value = 0)
    {
        // Telegram (VENDOR.md edit 31.3): only an identifier is a keyword (ident() is "" for any other token).
        if(tok.type != IDENT)
        {
            return false;
        }
        auto idx = keywords.value_index(tok.ident());
        if(!idx.has_value())
        {
            return false;
        }
        val = static_cast<Enum>(first_keyword_value + *idx);
        return true;
    }

} // namespace litehtml

#endif // LITEHTML_STYLE_H
