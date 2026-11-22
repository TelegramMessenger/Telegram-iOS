#ifndef LITEHTML_CALC_NODE_H
#define LITEHTML_CALC_NODE_H

// Telegram (VENDOR.md edit 48): a math function that mixes a percentage with a length (calc(50% - 10px),
// min(50px, 30%), clamp(20px, 50%, 60px)) cannot fold to one value while parsing: its percentage resolves against the
// containing block at layout. css_length keeps such a value as an immutable tree, shared by reference.

#include <atomic>
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace litehtml
{
    class css_token;
    class calc_node;

    // A counted reference to an immutable calc_node. The count is atomic: a laid-out document's lengths are copied into
    // trees another thread reads.
    class calc_ref
    {
        const calc_node* m_node = nullptr;

      public:
        calc_ref() = default;
        // Takes a new node (its count 0) or shares a live one.
        explicit calc_ref(const calc_node* node);
        calc_ref(const calc_ref& other);
        calc_ref(calc_ref&& other) noexcept;
        calc_ref& operator=(const calc_ref& other);
        calc_ref& operator=(calc_ref&& other) noexcept;
        ~calc_ref();
        const calc_node* get() const { return m_node; }
        const calc_node* operator->() const { return m_node; }
        explicit         operator bool() const { return m_node != nullptr; }
        // Hands the reference to the caller (the count it held stays with it).
        const calc_node* release();
        // A count held by hand (css_length keeps its node in a union): one more, one less (the last deletes it).
        static void      retain(const calc_node* node);
        static void      drop(const calc_node* node);
    };

    // A length's linear terms, each in its own unit.
    struct calc_terms
    {
        double px      = 0;
        double percent = 0;
        double em      = 0;
        double rem     = 0;
        double ex      = 0;
        double ch      = 0;
    };

    // What a calc's font-relative terms are worth in px, where it is computed.
    struct calc_fonts
    {
        double em  = 16;
        double rem = 16;
        double ex  = 8;
        double ch  = 8;
    };

    class calc_node
    {
      public:
        enum kind_t : uint8_t
        {
            sum,   // terms + every child × its factor
            min,   // the least child
            max,   // the greatest child
            clamp, // max(child 0, min(child 1, child 2))
        };

        // The most nodes one tree may hold. A tree is shared by every element a cached declaration styles and evaluated
        // for each of them at every layout, so its size must not follow the declaration's.
        static constexpr uint32_t max_nodes = 64;

        kind_t                                 kind = sum;
        calc_terms                             terms;
        std::vector<std::pair<double, calc_ref>> children;
        // The nodes in this tree, itself included.
        uint32_t                               nodes = 1;

        calc_node();
        ~calc_node();
        calc_node(const calc_node&)            = delete;
        calc_node& operator=(const calc_node&) = delete;

        // Whether a percentage appears anywhere in the tree.
        bool        has_percent() const;
        // Whether a font-relative term appears anywhere in the tree.
        bool        has_font_terms() const;
        // The value in px, a percentage of `percent_base`, font-relative terms by `fonts`.
        double      eval(double percent_base, const calc_fonts& fonts) const;
        // One canonical form (fixed precision, terms in a fixed order), for layout dumps.
        std::string to_string() const;

        // The calc(), min(), max() or clamp() function `fn` as a length-percentage: null when it is not one (a type
        // mismatch, a unit litehtml does not know, a division by zero or by a length, nesting past 16).
        static calc_ref parse(const css_token& fn);
        // `node` with its font-relative terms folded into px.
        static calc_ref fold_fonts(const calc_ref& node, const calc_fonts& fonts);
        // max(0px, node): a property that takes no negative value clamps the result at 0, as CSS clamps a math function
        // to the property's range.
        static calc_ref at_least_zero(const calc_ref& node);

        // Nodes alive in the process, for leak tests.
        static int64_t live();

      private:
        friend class calc_ref;
        mutable std::atomic<int32_t> m_refs{0};
    };
} // namespace litehtml

#endif // LITEHTML_CALC_NODE_H
