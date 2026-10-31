#include "html.h"
#include "el_before_after.h"
#include "el_text.h"
#include "el_space.h"
#include "el_image.h"
#include "utf8_strings.h"
#include "css_parser.h" // Telegram (VENDOR.md edit 19): max_css_list

namespace litehtml
{
    namespace
    {
        // Telegram (VENDOR.md edit 19): a content url() image, counted like its pseudo-element.
        class el_pseudo_image : public el_image
        {
          public:
            explicit el_pseudo_image(const document::ptr& doc) :
                el_image(doc)
            {
                if(doc)
                    doc->note_pseudo_element(1);
            }
            ~el_pseudo_image() override
            {
                if(const auto doc = get_document())
                    doc->note_pseudo_element(-1);
            }
        };
    } // namespace
} // namespace litehtml

litehtml::el_before_after_base::el_before_after_base(const std::shared_ptr<document>& doc, bool before) :
    html_tag(doc)
{
    m_tag = before ? __tag_before_ : __tag_after_;
    if(doc)
        doc->note_pseudo_element(1); // Telegram (VENDOR.md edit 19)
}

// Telegram (VENDOR.md edit 19).
litehtml::el_before_after_base::~el_before_after_base()
{
    if(const auto doc = get_document())
        doc->note_pseudo_element(-1);
}

void litehtml::el_before_after_base::add_style(const style& style)
{
    html_tag::add_style(style);

    auto children = m_children;
    m_children.clear();
    // Telegram (VENDOR.md edit 84): the content made before stays alive, and counted, while this one is made.
    if(const auto doc = get_document())
        doc->note_generated_transient(int(children.size()));

    const auto& content_property = style.get_property(_content_);
    if(content_property.is<std::string>() && !content_property.get<std::string>().empty())
    {
        const auto& str = content_property.get<std::string>();
        auto        idx = css_values(content_property_strings).value_index(str);
        if(!idx.has_value())
        {
            std::string            fnc;
            std::string::size_type i = 0;
            // Telegram (VENDOR.md edit 19): at most max_css_list items (strings and functions) are kept.
            size_t items = 0;
            while(i < str.length() && i != std::string::npos)
            {
                if(items >= max_css_list && fnc.empty())
                {
                    break;
                }
                if(str.at(i) == '"' || str.at(i) == '\'')
                {
                    auto chr = str.at(i);
                    fnc.clear();
                    i++;
                    std::string::size_type pos = str.find(chr, i);
                    std::string            txt;
                    if(pos == std::string::npos)
                    {
                        txt = str.substr(i);
                        i   = std::string::npos;
                    } else
                    {
                        txt = str.substr(i, pos - i);
                        i   = pos + 1;
                    }
                    items++;
                    add_text(txt);
                } else if(str.at(i) == '(')
                {
                    i++;
                    litehtml::trim(fnc);
                    litehtml::lcase(fnc);
                    std::string::size_type pos = str.find(')', i);
                    std::string            params;
                    if(pos == std::string::npos)
                    {
                        params = str.substr(i);
                        i      = std::string::npos;
                    } else
                    {
                        params = str.substr(i, pos - i);
                        i      = pos + 1;
                    }
                    items++;
                    add_function(fnc, params);
                    fnc.clear();
                } else
                {
                    fnc += str.at(i);
                    i++;
                }
            }
        }
    }

    if(m_children.empty())
    {
        m_children = children;
    }
}

void litehtml::el_before_after_base::add_text(const std::string& txt)
{
    const document::generated_scope generated(get_document().get()); // Telegram (VENDOR.md edit 84)
    std::string word;
    std::string esc;
    // Telegram (VENDOR.md edit 10): content is made again on every restyle, for every element it matches, so it
    // stops at the document's text cap like parsed text does.
    const auto doc = get_document();

    for(auto chr : txt)
    {
        if(chr == '\\' || (!esc.empty() && esc.length() < 5 &&
                           ((chr >= '0' && chr <= '9') || (chr >= 'A' && chr <= 'Z') || (chr >= 'a' && chr <= 'z'))))
        {
            if(!esc.empty() && chr == '\\')
            {
                word += convert_escape(esc.c_str() + 1);
                esc.clear();
            }
            esc += chr;
        } else
        {
            if(!esc.empty())
            {
                word += convert_escape(esc.c_str() + 1);
                esc.clear();
            }
            if(isspace(static_cast<unsigned char>(chr)))
            {
                if(!word.empty())
                {
                    if(doc && !doc->text_element_allowed())
                        return;
                    element::ptr el = std::make_shared<el_text>(word.c_str(), get_document());
                    appendChild(el);
                    word.clear();
                }
                if(doc && !doc->text_element_allowed())
                    return;
                word            += chr;
                element::ptr el  = std::make_shared<el_space>(word.c_str(), get_document());
                appendChild(el);
                word.clear();
            } else
            {
                word += chr;
            }
        }
    }

    if(!esc.empty())
    {
        word += convert_escape(esc.c_str() + 1);
    }
    if(!word.empty())
    {
        if(doc && !doc->text_element_allowed())
            return;
        element::ptr el = std::make_shared<el_text>(word.c_str(), get_document());
        appendChild(el);
        word.clear();
    }
}

void litehtml::el_before_after_base::add_function(const std::string& fnc, const std::string& params)
{
    constexpr auto content_function_strings = split_css_values<4>("attr;counter;counters;url");

    auto idx = css_values(content_function_strings).value_index(fnc);
    if(!idx.has_value())
    {
        return;
    }
    switch(idx.value())
    {
    // attr
    case 0:
        {
            std::string p_name = params;
            trim(p_name);
            lcase(p_name);
            element::ptr el_parent = parent();
            if(el_parent)
            {
                const char* attr_value = el_parent->get_attr(p_name.c_str());
                if(attr_value)
                {
                    add_text(attr_value);
                }
            }
        }
        break;
    // counter
    case 1:
        m_reads_counters = true; // Telegram (VENDOR.md edit 78)
        add_text(get_counter_value(params));
        break;
    // counters
    case 2:
        {
            m_reads_counters = true; // Telegram (VENDOR.md edit 78)
            string_vector tokens;
            split_string(params, tokens, ",");
            for(auto& str : tokens)
            {
                trim(str);
            }
            add_text(get_counters_value(tokens));
        }
        break;
    // url
    case 3:
        {
            std::string p_url = params;
            trim(p_url);
            if(!p_url.empty())
            {
                if(p_url.at(0) == '\'' || p_url.at(0) == '\"')
                {
                    p_url.erase(0, 1);
                }
            }
            if(!p_url.empty())
            {
                if(p_url.at(p_url.length() - 1) == '\'' || p_url.at(p_url.length() - 1) == '\"')
                {
                    p_url.erase(p_url.length() - 1, 1);
                }
            }
            if(!p_url.empty())
            {
                // Telegram (VENDOR.md edit 19): the element cap counts the image.
                const auto doc = get_document();
                if(doc && !doc->pseudo_element_allowed())
                {
                    return;
                }
#if 0
                element::ptr el = std::make_shared<el_image>(get_document());
#else
                element::ptr el = std::make_shared<el_pseudo_image>(get_document());
#endif
                el->set_attr("src", p_url.c_str());
                el->set_attr("style", "display:inline-block");
                el->set_tagName("img");
                appendChild(el);
                el->parse_attributes();
            }
        }
        break;
    }
}

std::string litehtml::el_before_after_base::convert_escape(const char* txt)
{
    char*    str_end;
    char32_t u_str[2];
    u_str[0] = static_cast<char32_t>(strtol(txt, &str_end, 16));
    u_str[1] = 0;
    return litehtml_from_utf32(u_str).c_str();
}
