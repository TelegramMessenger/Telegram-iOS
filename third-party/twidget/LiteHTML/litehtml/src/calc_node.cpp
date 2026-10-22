// Telegram (VENDOR.md edit 48): math functions that keep a percentage until layout.
#include "html.h"
#include "calc_node.h"
#include "css_tokenizer.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <limits>

namespace litehtml
{
    namespace
    {
        std::atomic<int64_t> g_live{0};

        // A sum while parsing: its terms and its children (min, max, clamp) with their factors, and the nodes the
        // children hold.
        struct calc_lin
        {
            calc_terms                               terms;
            std::vector<std::pair<double, calc_ref>> children;
            uint32_t                                 nodes = 0;
        };

        // A value while parsing: a <number>, or a length-percentage (a sum).
        struct calc_operand
        {
            bool     number = false;
            double   value  = 0;
            calc_lin sum;
        };

        void scale(calc_lin& sum, double factor)
        {
            calc_terms& t = sum.terms;
            t.px *= factor, t.percent *= factor, t.em *= factor, t.rem *= factor, t.ex *= factor, t.ch *= factor;
            for(auto& child : sum.children)
                child.first *= factor;
        }

        // Every term and factor a float can hold: the parse-time fold refuses an overflow at every step, and a length
        // is a float wherever it is used.
        bool representable(const calc_lin& sum)
        {
            const calc_terms& t = sum.terms;
            for(double v : {t.px, t.percent, t.em, t.rem, t.ex, t.ch})
                if(!(std::fabs(v) <= double(std::numeric_limits<float>::max())))
                    return false;
            for(const auto& child : sum.children)
                if(!(std::fabs(child.first) <= double(std::numeric_limits<float>::max())))
                    return false;
            return true;
        }

        calc_ref make_node(calc_lin sum)
        {
            if(!representable(sum))
                return calc_ref();
            // A single child alone is that child.
            const calc_terms& t = sum.terms;
            if(sum.children.size() == 1 && sum.children[0].first == 1 && t.px == 0 && t.percent == 0 && t.em == 0 &&
               t.rem == 0 && t.ex == 0 && t.ch == 0)
                return sum.children[0].second;
            auto* node     = new calc_node();
            node->kind     = calc_node::sum;
            node->terms    = sum.terms;
            node->children = std::move(sum.children);
            node->nodes    = 1 + sum.nodes;
            return calc_ref(node);
        }

        // A length unit's terms for one unit: absolute ones in px at 96 per inch, font-relative ones kept.
        bool unit_terms(const std::string& unit, double value, calc_terms& terms)
        {
            const std::string u = lowcase(unit);
            if(u == "px")
                terms.px = value;
            else if(u == "in")
                terms.px = value * 96;
            else if(u == "cm")
                terms.px = value * 96 / 2.54;
            else if(u == "mm")
                terms.px = value * 96 / 25.4;
            else if(u == "q")
                terms.px = value * 96 / 101.6;
            else if(u == "pt")
                terms.px = value * 96 / 72;
            else if(u == "pc")
                terms.px = value * 16;
            else if(u == "em")
                terms.em = value;
            else if(u == "rem")
                terms.rem = value;
            else if(u == "ex")
                terms.ex = value;
            else if(u == "ch")
                terms.ch = value;
            else
                return false;
            return true;
        }

        void skip_space(const css_token_vector& tokens, size_t& index)
        {
            while(index < tokens.size() && tokens[index].type == WHITESPACE)
                index++;
        }

        bool parse_sum(const css_token_vector& tokens, size_t& index, calc_operand& out, int depth);

        // The arguments of min(), max() or clamp(), each a sum, all of one type.
        bool parse_arguments(const css_token& fn, std::vector<calc_operand>& args, int depth)
        {
            size_t index = 0;
            while(true)
            {
                calc_operand arg;
                if(!parse_sum(fn.value, index, arg, depth + 1))
                    return false;
                args.push_back(std::move(arg));
                if(args.size() > 32)
                    return false;
                skip_space(fn.value, index);
                if(index == fn.value.size())
                    break;
                if(fn.value[index].ch != ',')
                    return false;
                index++;
            }
            for(const auto& arg : args)
                if(arg.number != args[0].number)
                    return false;
            return true;
        }

        bool parse_atom(const css_token_vector& tokens, size_t& index, calc_operand& out, int depth)
        {
            skip_space(tokens, index);
            if(index >= tokens.size() || depth > 16)
                return false;
            const css_token& tok = tokens[index++];
            if(tok.type == NUMBER)
            {
                out.number = true;
                out.value  = tok.n.number;
                return true;
            }
            if(tok.type == PERCENTAGE)
            {
                out.sum.terms.percent = tok.n.number;
                return true;
            }
            if(tok.type == DIMENSION)
                return unit_terms(tok.unit(), tok.n.number, out.sum.terms);
            if(tok.type == CV_FUNCTION && is_one_of(lowcase(tok.name()), "min", "max", "clamp"))
            {
                const std::string        name = lowcase(tok.name());
                std::vector<calc_operand> args;
                if(!parse_arguments(tok, args, depth) || (name == "clamp" && args.size() != 3))
                    return false;
                if(args[0].number)
                {
                    double value = args[0].value;
                    if(name == "clamp")
                        value = std::max(args[0].value, std::min(args[1].value, args[2].value));
                    else
                        for(const auto& arg : args)
                            value = name == "min" ? std::min(value, arg.value) : std::max(value, arg.value);
                    out.number = true;
                    out.value  = value;
                    return std::isfinite(value);
                }
                auto* node = new calc_node();
                node->kind = name == "min" ? calc_node::min : name == "max" ? calc_node::max : calc_node::clamp;
                calc_ref ref(node);
                for(auto& arg : args)
                {
                    calc_ref child = make_node(std::move(arg.sum));
                    if(!child)
                        return false;
                    node->children.emplace_back(1.0, std::move(child));
                    node->nodes += node->children.back().second->nodes;
                    if(node->nodes > calc_node::max_nodes)
                        return false;
                }
                out.sum.nodes += node->nodes;
                if(out.sum.nodes >= calc_node::max_nodes)
                    return false;
                out.sum.children.emplace_back(1.0, std::move(ref));
                return true;
            }
            if(tok.type == ROUND_BLOCK || (tok.type == CV_FUNCTION && lowcase(tok.name()) == "calc"))
            {
                size_t inner = 0;
                if(!parse_sum(tok.value, inner, out, depth + 1))
                    return false;
                skip_space(tok.value, inner);
                return inner == tok.value.size();
            }
            return false;
        }

        int parse_operator(const css_token_vector& tokens, size_t& index, const char* allowed)
        {
            size_t probe = index;
            skip_space(tokens, probe);
            if(probe < tokens.size() && tokens[probe].ch > 0 && tokens[probe].ch < 128 && strchr(allowed, tokens[probe].ch))
            {
                index = probe + 1;
                return tokens[probe].ch;
            }
            return 0;
        }

        bool parse_product(const css_token_vector& tokens, size_t& index, calc_operand& out, int depth)
        {
            if(!parse_atom(tokens, index, out, depth))
                return false;
            while(int op = parse_operator(tokens, index, "*/"))
            {
                calc_operand right;
                if(!parse_atom(tokens, index, right, depth))
                    return false;
                if(op == '*')
                {
                    if(!out.number && !right.number)
                        return false;
                    if(out.number && right.number)
                    {
                        out.value *= right.value;
                    } else if(out.number)
                    {
                        const double factor = out.value;
                        out                 = std::move(right);
                        scale(out.sum, factor);
                    } else
                    {
                        scale(out.sum, right.value);
                    }
                } else
                {
                    if(!right.number || right.value == 0)
                        return false;
                    if(out.number)
                        out.value /= right.value;
                    else
                        scale(out.sum, 1 / right.value);
                }
                if(out.number && !std::isfinite(out.value))
                    return false;
            }
            return true;
        }

        bool parse_sum(const css_token_vector& tokens, size_t& index, calc_operand& out, int depth)
        {
            if(!parse_product(tokens, index, out, depth))
                return false;
            while(int op = parse_operator(tokens, index, "+-"))
            {
                calc_operand right;
                if(!parse_product(tokens, index, right, depth))
                    return false;
                const double sign = op == '+' ? 1 : -1;
                if(out.number && right.number)
                {
                    out.value += sign * right.value;
                    continue;
                }
                // A <number> zero added to a length reads as a zero length, as the parse-time fold allows.
                if(out.number || right.number)
                {
                    if((out.number && out.value != 0) || (right.number && right.value != 0))
                        return false;
                    if(out.number)
                    {
                        out = std::move(right);
                        if(sign < 0)
                            scale(out.sum, -1);
                    }
                    continue;
                }
                if(sign < 0)
                    scale(right.sum, -1);
                calc_terms&       a = out.sum.terms;
                const calc_terms& b = right.sum.terms;
                a.px += b.px, a.percent += b.percent, a.em += b.em, a.rem += b.rem, a.ex += b.ex, a.ch += b.ch;
                for(auto& child : right.sum.children)
                    out.sum.children.push_back(std::move(child));
                out.sum.nodes += right.sum.nodes;
                // The sum's own node makes one more.
                if(out.sum.nodes >= calc_node::max_nodes)
                    return false;
            }
            return true;
        }

        void append_number(std::string& out, const char* name, double value)
        {
            if(value == 0)
                return;
            char buffer[48];
            std::snprintf(buffer, sizeof(buffer), "%s%s:%.6g", out.back() == '(' ? "" : ",", name, value);
            out += buffer;
        }
    } // namespace

    calc_ref::calc_ref(const calc_node* node) :
        m_node(node)
    {
        retain(node);
    }

    calc_ref::calc_ref(const calc_ref& other) :
        m_node(other.m_node)
    {
        retain(m_node);
    }

    calc_ref::calc_ref(calc_ref&& other) noexcept :
        m_node(other.m_node)
    {
        other.m_node = nullptr;
    }

    calc_ref& calc_ref::operator=(const calc_ref& other)
    {
        if(this != &other)
        {
            retain(other.m_node);
            drop(m_node);
            m_node = other.m_node;
        }
        return *this;
    }

    calc_ref& calc_ref::operator=(calc_ref&& other) noexcept
    {
        if(this != &other)
        {
            drop(m_node);
            m_node       = other.m_node;
            other.m_node = nullptr;
        }
        return *this;
    }

    calc_ref::~calc_ref()
    {
        drop(m_node);
    }

    const calc_node* calc_ref::release()
    {
        const calc_node* node = m_node;
        m_node                = nullptr;
        return node;
    }

    void calc_ref::retain(const calc_node* node)
    {
        if(node)
            node->m_refs.fetch_add(1, std::memory_order_relaxed);
    }

    void calc_ref::drop(const calc_node* node)
    {
        if(node && node->m_refs.fetch_sub(1, std::memory_order_acq_rel) == 1)
            delete node;
    }

    calc_node::calc_node()
    {
        g_live.fetch_add(1, std::memory_order_relaxed);
    }

    calc_node::~calc_node()
    {
        g_live.fetch_sub(1, std::memory_order_relaxed);
    }

    int64_t calc_node::live()
    {
        return g_live.load(std::memory_order_relaxed);
    }

    bool calc_node::has_percent() const
    {
        if(terms.percent != 0)
            return true;
        for(const auto& child : children)
            if(child.second->has_percent())
                return true;
        return false;
    }

    bool calc_node::has_font_terms() const
    {
        if(terms.em != 0 || terms.rem != 0 || terms.ex != 0 || terms.ch != 0)
            return true;
        for(const auto& child : children)
            if(child.second->has_font_terms())
                return true;
        return false;
    }

    double calc_node::eval(double percent_base, const calc_fonts& fonts) const
    {
        switch(kind)
        {
        case sum:
        {
            double value = terms.px + terms.percent * percent_base / 100 + terms.em * fonts.em + terms.rem * fonts.rem +
                           terms.ex * fonts.ex + terms.ch * fonts.ch;
            for(const auto& child : children)
                value += child.first * child.second->eval(percent_base, fonts);
            return value;
        }
        case min:
        case max:
        {
            double value = children.empty() ? 0 : children[0].second->eval(percent_base, fonts);
            for(const auto& child : children)
            {
                const double v = child.second->eval(percent_base, fonts);
                value          = kind == min ? std::min(value, v) : std::max(value, v);
            }
            return value;
        }
        case clamp:
            if(children.size() != 3)
                return 0;
            return std::max(children[0].second->eval(percent_base, fonts),
                            std::min(children[1].second->eval(percent_base, fonts), children[2].second->eval(percent_base, fonts)));
        }
        return 0;
    }

    std::string calc_node::to_string() const
    {
        static const char* const names[] = {"sum", "min", "max", "clamp"};
        std::string out = names[kind];
        out += '(';
        append_number(out, "px", terms.px);
        append_number(out, "%", terms.percent);
        append_number(out, "em", terms.em);
        append_number(out, "rem", terms.rem);
        append_number(out, "ex", terms.ex);
        append_number(out, "ch", terms.ch);
        for(const auto& child : children)
        {
            if(out.back() != '(')
                out += ',';
            if(child.first != 1)
            {
                char buffer[32];
                std::snprintf(buffer, sizeof(buffer), "%.6g*", child.first);
                out += buffer;
            }
            out += child.second->to_string();
        }
        out += ')';
        return out;
    }

    calc_ref calc_node::parse(const css_token& fn)
    {
        if(fn.type != CV_FUNCTION || !is_one_of(lowcase(fn.name()), "calc", "min", "max", "clamp"))
            return calc_ref();
        css_token_vector single = {fn};
        size_t           index  = 0;
        calc_operand     value;
        if(!parse_atom(single, index, value, 0) || value.number)
            return calc_ref();
        return make_node(std::move(value.sum));
    }

    calc_ref calc_node::at_least_zero(const calc_ref& node)
    {
        if(!node)
            return node;
        auto*    clamped = new calc_node();
        calc_ref ref(clamped);
        clamped->kind = calc_node::max;
        auto* zero    = new calc_node();
        clamped->children.emplace_back(1.0, calc_ref(zero));
        clamped->children.emplace_back(1.0, node);
        clamped->nodes = 2 + node->nodes;
        return ref;
    }

    calc_ref calc_node::fold_fonts(const calc_ref& node, const calc_fonts& fonts)
    {
        if(!node || !node->has_font_terms())
            return node;
        auto* folded  = new calc_node();
        calc_ref ref(folded);
        folded->kind  = node->kind;
        folded->terms = node->terms;
        folded->terms.px += node->terms.em * fonts.em + node->terms.rem * fonts.rem + node->terms.ex * fonts.ex +
                            node->terms.ch * fonts.ch;
        folded->terms.em = folded->terms.rem = folded->terms.ex = folded->terms.ch = 0;
        folded->nodes    = node->nodes;
        for(const auto& child : node->children)
            folded->children.emplace_back(child.first, fold_fonts(child.second, fonts));
        return ref;
    }
} // namespace litehtml
