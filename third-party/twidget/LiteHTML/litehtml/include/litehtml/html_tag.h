#ifndef LITEHTML_HTML_TAG_H
#define LITEHTML_HTML_TAG_H

#include <algorithm>
#include <unordered_map>
#include "element.h"
#include "background.h"
#include "css_selector.h"
#include "line_box.h"
#include "style.h"
#include "stylesheet.h"
#include "table.h"

namespace litehtml
{
    // Telegram (VENDOR.md edit 27): the render-only attribute an animated element's sampled declarations travel in. The
    // space makes it a name no DOM attribute can have, so only the host sets it.
    constexpr const char* animated_style_attribute = "animated style";

    class html_tag : public element
    {
        friend class elements_iterator;
        friend class el_table;
        friend class table_grid;
        friend class line_box;

      public:
        uint64_t paint_signature() const override;
        using ptr = std::shared_ptr<html_tag>;

      protected:
        string_id              m_tag = empty_id;
        string_id              m_id  = empty_id;
        string_vector          m_str_classes;
        std::vector<string_id> m_classes;
        style                  m_style;
        style                  m_style_base;
        bool                   m_has_style_base = false;
#if 0
        size_t                 m_style_charged  = 0; // Telegram (VENDOR.md edit 21): what add_style charged this element
#else
        mutable size_t         m_style_charged  = 0; // Telegram (VENDOR.md edit 21): what add_style charged this element
#endif
        // Telegram (VENDOR.md edit 60): what the inherited bullet URL this element holds charged the style budget, and
        // the budget's epoch then (a full refresh charges from zero, so an earlier charge is not given back).
        mutable size_t         m_inherited_charged = 0;
        mutable uint32_t       m_inherited_epoch   = 0;
        bool m_anonymous_style = false;
        mutable bool m_reads_var = false; // Telegram (VENDOR.md edit 17)
        void note_reads_var(bool reads) const;
        // Telegram (VENDOR.md edit 21): what each property's last var() splices charged (begin_splice).
        struct splice_charge
        {
            size_t   bytes = 0;
            uint64_t round = 0;
        };
        mutable std::unordered_map<string_id, splice_charge> m_splice_charges;
        mutable string_id                                     m_splice_property = empty_id;
        mutable uint64_t                                      m_splice_round    = 0;
        // Gives back every splice charge this element holds.
        void refund_splices() const;
        string_map             m_attrs;
        std::vector<string_id> m_pseudo_classes;
        const elements_list*   m_children_for_matching = nullptr; // Telegram (VENDOR.md edit 31.5)

        struct match_memo
        {
            uint64_t                       epoch = 0;
            string_map                     attrs;
            std::vector<css_selector::ptr> rules[3];
        };
        std::vector<match_memo> m_match_memos;

        struct flip_state
        {
            // Move-only (it holds unique_ptrs), and declared so: a vector moves an element only when it
            // cannot copy it or the move cannot throw, and MSVC's std::map move may throw.
            flip_state()                        = default;
            flip_state(flip_state&&)            = default;
            flip_state& operator=(flip_state&&) = default;

            std::string                                 value;
            uint64_t                                    epoch     = 0;
            int                                         parent_id = -1;
            string_map                                  others;
            string_vector                               str_classes;
            std::vector<string_id>                      classes;
            style                                       st;
            style                                       st_base;
            bool                                        has_base = false;
            used_selector::vector                       used;
            css_properties                              css;
            std::vector<css_properties>                 kids;
            std::map<std::string, int>                  regions;
        };
        std::vector<flip_state> m_flips;

        void select_all(const css_selector& selector, elements_list& res) override;

      public:
        explicit html_tag(const std::shared_ptr<document>& doc);
        // constructor for anonymous wrapper boxes
        explicit html_tag(const std::shared_ptr<element>& parent, const std::string& style = "display: block");

        bool                          appendChild(const element::ptr& el) override;
        bool                          accepts_child(string_id /*tag*/) const override { return true; } // Telegram (VENDOR.md edit 83)
        bool                          accepts_text() const override { return true; }
        bool                          removeChild(const element::ptr& el) override;
        void                          clearRecursive() override;
        string_id                     tag() const override;
        string_id                     id() const override;
        const char*                   get_tagName() const override;
        void                          set_tagName(const char* tag) override;
        void                          set_data(const char* data) override;
        const std::vector<string_id>& classes() const
        {
            return m_classes;
        }
        const string_vector& str_classes() const
        {
            return m_str_classes;
        }

        void        set_attr(const char* name, const char* val) override;
        const char* get_attr(const char* name, const char* def = nullptr) const override;
        void        apply_stylesheet(const litehtml::css& stylesheet) override;
        void        apply_matching(const litehtml::css* sheets[3], uint64_t epoch);
        // Telegram (VENDOR.md edit 78): one of apply_matching's three passes (`sheet` 0 master, 1 author with the
        // attributes parsed first, 2 user), charged as it charges them, with no match memo.
        void        apply_matching_pass(const litehtml::css& stylesheet, int sheet, bool parse = true);
        // Telegram (VENDOR.md edit 84): parse_attributes on this element alone, its children set aside and what it makes
        // (a form control's parts) added to them; the attributes pass a build runs between the master and author passes.
        void        parse_own_attributes();
        // Takes `other`'s match: its style, its matched rules and what they charged, giving it this element's. For an
        // element whose generated content a replay made again equal: the old one stays in the tree with the new match.
        void        adopt_matched(html_tag& other);
        // The rules matched, by selector, with whether each applied: sorted.
        std::vector<std::pair<const css_selector*, bool>> used_rules() const;
        // Telegram (VENDOR.md edit 78): the pass's rules applied to this element's generated children, where a build's
        // apply_stylesheet reaches them: its ::before and a form control's lh-* parts right after its own rules
        // (`after` false), its ::after once its descendants are matched (`after` true).
        void        apply_matching_pass_generated(const litehtml::css& stylesheet, bool after);
        bool        flip_class(const std::string& from, const std::string& to, uint64_t epoch, int* region);
        void        note_flip(const std::string& from, const std::string& to, int region);
        void        forget_flips() { m_flips.clear(); }
        void        apply_selector(const std::shared_ptr<css_selector>& sel);
        void        refresh_styles() override;
        // Puts back the style the element had before its inline `style` attribute was applied, so a changed
        // attribute can be applied by compute_styles exactly like on a freshly built element.
        void        restore_base_style();
        const string_map& attributes() const
        {
            return m_attrs;
        }
        // Replaces every attribute, as if the element had been created with `attrs`.
        void reset_attributes(const string_map& attrs);
        // Drops everything stylesheets and attributes contributed, including ::before and ::after, so the
        // element can be matched again exactly like a freshly built one.
        void forget_matched_styles();
        // Telegram (VENDOR.md edit 17): whether this element's style read var() when it was last computed from its
        // matched rules (a restyle substitutes nothing again: subst_vars replaces the var()s in the style).
        bool reads_var() const { return m_reads_var; }
        // Telegram (VENDOR.md edit 79): the environment its style's parses read (style::environment).
        int style_environment() const { return m_style.environment(); }
        // Telegram (VENDOR.md edit 17): whether its style, or its inline or animated style, declares a custom property.
        bool declares_custom_properties() const;
        // Telegram (VENDOR.md edit 21): gives back what this element holds of the style budget, as it leaves the tree.
        void release_style_charges() const;
        // Telegram (VENDOR.md edit 78): whether its match takes part in counting: its style declares counter-reset or
        // counter-increment, it holds counter values, or a ::before or ::after of it reads a counter.
        bool counted() const;
        // Telegram (VENDOR.md edit 31.5): the children :empty reads while document::apply_retag matches this element
        // again with them set aside (null: its own).
        void set_children_for_matching(const elements_list* children) { m_children_for_matching = children; }

        bool is_white_space() const override;
        bool is_body() const override;
        bool is_break() const override;

        bool on_mouse_over() override;
        bool on_mouse_leave() override;
        bool on_lbutton_down() override;
        bool on_lbutton_up(bool is_click) override;
        void on_click() override;
        bool set_pseudo_class(string_id cls, bool add) override;
        bool has_pseudo_class(string_id cls) const override
        {
            return std::find(m_pseudo_classes.begin(), m_pseudo_classes.end(), cls) != m_pseudo_classes.end();
        }
        bool set_class(const char* pclass, bool add) override;
        bool is_replaced() const override;
        void compute_styles(bool recursive = true) override;
        bool background_color_is_local() const;
        void compute_background_style();
        // Telegram (VENDOR.md edit 26): document::root_declarations, on the root element only.
        void add_root_declarations();
        // Telegram (VENDOR.md edit 80): an SVG paint attribute naming light-dark() marks the style as reading the scheme.
        void note_paint_attributes();
        // Telegram (VENDOR.md edit 27): the animated_style_attribute's declarations, after the style attribute's.
        void add_animated_style();
        void draw(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip,
                  const std::shared_ptr<render_item>& ri) override;
        void draw_background(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip,
                             const std::shared_ptr<render_item>& ri) override;

        template <class Type>
        const Type& get_property(string_id name, bool inherited, const Type& default_value,
                                 uint_ptr css_properties_member_offset) const;
        std::string raw_declaration(const std::string& name) const;
        bool        get_custom_property(string_id name, css_token_vector& result) const;
        // Telegram (VENDOR.md edit 21): the value get_custom_property would copy, without copying it (null if none).
        const css_token_vector* find_custom_property(string_id name) const;
        // Charges a var() splice of `bytes` to the style-byte budget (and to this element, for refresh); false if refused.
        bool        charge_splice(size_t bytes) const;
        // Telegram (VENDOR.md edit 21): the property the splices that follow are for (empty_id: none), until end_splice.
        // A property spliced again (a restyle adds the inline, animated or base style's var()s again) gives back what its
        // last splice charged before it is charged again.
        void        begin_splice(string_id property) const;
        void        end_splice() const { m_splice_property = empty_id; }
        // Telegram (VENDOR.md edit 60): charges the inherited bullet URL this list item holds (false if refused), and gives
        // back what it charged, before the element is computed again.
        bool        charge_inherited(size_t bytes) const;
        void        refund_inherited() const;
        // Telegram (VENDOR.md edit 33): the master sheet's cascaded value of `name` for this element (nullptr if it
        // declares none): its matched master rules that style the element itself, in the order they applied. Edit 50:
        // with `layer` (revert-layer), the master's @layer rules' value when they set one, else the engine's.
        const property_value* master_value(string_id name, bool layer = false) const;
        // Replaces revert declarations with master_value, charging a copy as a var() splice; before subst_vars.
        void                  resolve_reverts();
        // Telegram (VENDOR.md edit 21): refresh in document order, for a document whose replay could pass the budget.
        void        refresh_clear_styles();
        void        refresh_replay_styles(int sheet);
        // Telegram (VENDOR.md edit 21): the element declares a string of its own for `name`: exactly what
        // get_property<std::string> tests, so an unresolved var(), `inherit` or nothing all inherit.
#if 0
        bool declares_value(string_id name) const
        {
            const property_value& value = m_style.get_property(name);
            return !value.is<invalid>() && !value.is<inherit>();
        }
#else
        bool declares_value(string_id name) const
        {
            return m_style.get_property(name).is<std::string>();
        }
#endif
#if 0
        bool has_own_property(string_id name) const
        {
            const property_value& value = m_style.get_property(name);
            return !value.is<invalid>();
        }
#else
        // Telegram (VENDOR.md edit 33): unset is no declaration of its own.
        bool has_own_property(string_id name) const
        {
            const property_value& value = m_style.get_property(name);
            return !value.is<invalid>() && !value.is<unset>();
        }
#endif
        // Telegram (VENDOR.md edit 54): the element's cascaded value of `name` as litehtml parsed it (invalid without one),
        // shorthands expanded, for getComputedStyle's longhands litehtml computes on some elements only.
        const property_value& own_property(string_id name) const
        {
            return m_style.get_property(name);
        }
        const css_token_vector* get_token_property(string_id name) const
        {
            const property_value& value = m_style.get_property(name);
            return value.is<css_token_vector>() ? &value.get<css_token_vector>() : nullptr;
        }

        elements_list& children();

        int select(const css_selector::vector& selector_list, bool apply_pseudo = true) override;
        int select(const std::string& selector) override;
        int select(const css_selector& selector, bool apply_pseudo = true) override;
        int select(const css_element_selector& selector, bool apply_pseudo = true) override;
        int select_pseudoclass(const css_attribute_selector& sel);
        int select_attribute(const css_attribute_selector& sel) const;

        elements_list select_all(const std::string& selector) override;
        elements_list select_all(const css_selector& selector) override;

        element::ptr select_one(const std::string& selector) override;
        element::ptr select_one(const css_selector& selector) override;

        element::ptr find_ancestor(const css_selector& selector, bool apply_pseudo = true,
                                   bool* is_pseudo = nullptr) override;
        element::ptr find_adjacent_sibling(const element::ptr& el, const css_selector& selector,
                                           bool apply_pseudo = true, bool* is_pseudo = nullptr) override;
        element::ptr find_sibling(const element::ptr& el, const css_selector& selector, bool apply_pseudo = true,
                                  bool* is_pseudo = nullptr) override;
        void         get_text(std::string& text) const override;
        void         parse_attributes() override;

        void get_content_size(size& sz, pixel_t max_width) override;
        void add_style(const style& style) override;

        bool              is_nth_child(const element::ptr& el, int num, int off, bool of_type,
                                       const css_selector::vector& selector_list) const override;
        bool              is_nth_last_child(const element::ptr& el, int num, int off, bool of_type,
                                            const css_selector::vector& selector_list) const override;
        bool              is_only_child(const element::ptr& el, bool of_type) const override;
        const background* get_background(bool own_only = false) override;

        std::string dump_get_name() override;

      protected:
        void         draw_list_marker(uint_ptr hdc, const position& pos, const std::shared_ptr<render_item>& ri);
        std::string  get_list_marker_text(int index);
        element::ptr get_element_before(const style& style, bool create);
        element::ptr get_element_after(const style& style, bool create);

        void map_to_pixel_length_property(string_id prop_name, const std::string& attr_value);
        void map_to_pixel_length_property_with_default_value(string_id prop_name, const std::string& attr_value,
                                                             int default_value);
        void map_to_dimension_property(string_id prop_name, const std::string& attr_value);
        void map_to_dimension_property_ignoring_zero(string_id prop_name, const std::string& attr_value);

      private:
        void handle_counter_properties();
    };

    /************************************************************************/
    /*                        Inline Functions                              */
    /************************************************************************/

    inline elements_list& html_tag::children()
    {
        return m_children;
    }

    template <class Type>
    const Type& html_tag::get_property(string_id name, bool inherited, const Type& default_value,
                                       uint_ptr css_properties_member_offset) const
    {
        const property_value& value = m_style.get_property(name);

        if(value.is<Type>())
        {
            return value.get<Type>();
        }
        // Telegram (VENDOR.md edit 33): initial is the initial value; unset falls through as no declaration does.
        if(value.is<initial>())
        {
            return default_value;
        }
        if(inherited || value.is<inherit>())
        {
            if(auto _parent = parent())
            {
                // NOLINTBEGIN(cppcoreguidelines-pro-type-reinterpret-cast)
                return *reinterpret_cast<const Type*>(reinterpret_cast<const byte*>(&_parent->css()) +
                                                      css_properties_member_offset);
                // NOLINTEND(cppcoreguidelines-pro-type-reinterpret-cast)
            }
            return default_value;
        }
        return default_value;
    }

} // namespace litehtml

#endif // LITEHTML_HTML_TAG_H
