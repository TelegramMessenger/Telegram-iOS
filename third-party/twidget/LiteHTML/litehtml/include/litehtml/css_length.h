#ifndef LITEHTML_CSS_LENGTH_H
#define LITEHTML_CSS_LENGTH_H

#include <string>
#include "calc_node.h"
#include "css_tokenizer.h"
#include "css_values.h"
#include "pixel_type.h"

namespace litehtml
{
    // from_token options (flags)
    enum
    {
        f_length            = 1,                       // <length> (includes unitless zero)
        f_percentage        = 2,                       // <percentage>
        f_length_percentage = f_length | f_percentage, // <length-percentage>
        f_number            = 4,                       // <number>
        f_integer           = 8,                       // <integer>
        f_positive          = 16                       // ⩾0 (non-negative)
    };

    // <length> | <percentage> | <number> | auto | none | normal
    // https://developer.mozilla.org/en-US/docs/Web/CSS/length
    class css_length
    {
#if 0
        union {
            float m_value = 0;
            int   m_predef;
        };
        css_units m_units         = css_units_none;
        bool      m_is_predefined = false;
#else
        // Telegram (VENDOR.md edit 48): a math function mixing a percentage with a length (or a font-relative term,
        // until computed) keeps its tree, one counted reference held in the union while m_is_calc is set.
        union {
            float            m_value = 0;
            int              m_predef;
            const calc_node* m_calc;
        };
        css_units m_units         = css_units_none;
        bool      m_is_predefined = false;
        bool      m_is_calc       = false;

        void clear_calc()
        {
            if(m_is_calc)
            {
                calc_ref::drop(m_calc);
                m_is_calc = false;
                m_value   = 0;
            }
        }
#endif

      public:
        css_length() = default;
        css_length(float val, css_units units = css_units_px);
        // Telegram (VENDOR.md edit 48).
        css_length(const css_length& other);
        css_length(css_length&& other) noexcept;
        css_length& operator=(const css_length& other);
        css_length& operator=(css_length&& other) noexcept;
        ~css_length() { clear_calc(); }
        bool              is_calc() const { return m_is_calc; }
        // The tree of a calc length (a new reference), null otherwise.
        calc_ref          calc() const { return m_is_calc ? calc_ref(m_calc) : calc_ref(); }
        void              set_calc(calc_ref node);
        // A calc's value at a percentage base, font-relative terms (left before compute) by `fonts`.
        pixel_t           calc_value(pixel_t percent_base, const calc_fonts& fonts) const;
        css_length& operator=(float val);

        bool              is_predefined() const;
        void              predef(int val);
        int               predef() const;
        static css_length predef_value(int val = 0);
        void              set_value(float val, css_units units);
        float             val() const;
        css_units         units() const;
        pixel_t           calc_percent(pixel_t width) const;
        bool              from_token(const css_token& token, int options, css_values predefined_keywords = {});
        std::string       to_string() const;
    };

    using length_vector = std::vector<css_length>;

    inline css_length::css_length(float val, css_units units) :
        m_value(val),
        m_units(units)
    {
    }

    inline css_length::css_length(const css_length& other) :
        m_units(other.m_units),
        m_is_predefined(other.m_is_predefined),
        m_is_calc(other.m_is_calc)
    {
        if(m_is_calc)
        {
            m_calc = other.m_calc;
            calc_ref::retain(m_calc);
        } else
        {
            m_value = other.m_value; // also m_predef: the union's bits copied
        }
    }

    inline css_length::css_length(css_length&& other) noexcept :
        m_units(other.m_units),
        m_is_predefined(other.m_is_predefined),
        m_is_calc(other.m_is_calc)
    {
        if(m_is_calc)
        {
            m_calc          = other.m_calc;
            other.m_is_calc = false;
            other.m_value   = 0;
        } else
        {
            m_value = other.m_value;
        }
    }

    inline css_length& css_length::operator=(const css_length& other)
    {
        if(this != &other)
        {
            if(other.m_is_calc)
                calc_ref::retain(other.m_calc);
            clear_calc();
            m_units         = other.m_units;
            m_is_predefined = other.m_is_predefined;
            m_is_calc       = other.m_is_calc;
            if(m_is_calc)
                m_calc = other.m_calc;
            else
                m_value = other.m_value;
        }
        return *this;
    }

    inline css_length& css_length::operator=(css_length&& other) noexcept
    {
        if(this != &other)
        {
            clear_calc();
            m_units         = other.m_units;
            m_is_predefined = other.m_is_predefined;
            m_is_calc       = other.m_is_calc;
            if(m_is_calc)
            {
                m_calc          = other.m_calc;
                other.m_is_calc = false;
                other.m_value   = 0;
            } else
            {
                m_value = other.m_value;
            }
        }
        return *this;
    }

    inline void css_length::set_calc(calc_ref node)
    {
        clear_calc();
        if(!node)
            return;
        m_is_predefined = false;
        m_is_calc       = true;
        m_calc          = node.release();
        m_units         = m_calc->has_percent() ? css_units_percentage : css_units_px;
    }

    inline pixel_t css_length::calc_value(pixel_t percent_base, const calc_fonts& fonts) const
    {
        return m_is_calc ? pixel_t(float(m_calc->eval(double(percent_base), fonts))) : 0_px;
    }

    inline css_length& css_length::operator=(float val)
    {
        clear_calc();
        m_value         = val;
        m_units         = css_units_px;
        m_is_predefined = false;
        return *this;
    }

    inline bool css_length::is_predefined() const
    {
        return m_is_predefined;
    }

    inline void css_length::predef(int val)
    {
        clear_calc();
        m_predef        = val;
        m_is_predefined = true;
    }

    inline int css_length::predef() const
    {
        if(m_is_predefined)
        {
            return m_predef;
        }
        return 0;
    }

    inline void css_length::set_value(float val, css_units units)
    {
        clear_calc();
        m_value         = val;
        m_is_predefined = false;
        m_units         = units;
    }

    inline float css_length::val() const
    {
        // Telegram (VENDOR.md edit 48): a calc's value with every percentage at 0 (calc_percent resolves it).
        if(m_is_calc)
        {
            return float(m_calc->eval(0, calc_fonts()));
        }
        if(!m_is_predefined)
        {
            return m_value;
        }
        return 0;
    }

    inline css_units css_length::units() const
    {
        return m_units;
    }

    inline pixel_t css_length::calc_percent(pixel_t width) const
    {
        // Telegram (VENDOR.md edit 48).
        if(m_is_calc)
        {
            return calc_value(width, calc_fonts());
        }
        if(!is_predefined())
        {
            if(units() == css_units_percentage)
            {
                return width * m_value / 100.0_px;
            }
            return static_cast<pixel_t>(val());
        }
        return 0_px;
    }
} // namespace litehtml

#endif // LITEHTML_CSS_LENGTH_H
