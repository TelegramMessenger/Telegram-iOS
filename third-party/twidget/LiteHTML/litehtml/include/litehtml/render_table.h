#ifndef LITEHTML_RENDER_TABLE_H
#define LITEHTML_RENDER_TABLE_H

#include "render_item.h"

namespace litehtml
{
    class render_item_table : public render_item
    {
      protected:
        // data for table rendering
        std::unique_ptr<table_grid> m_grid;
        pixel_t                     m_border_spacing_x;
        pixel_t                     m_border_spacing_y;

      public:
        // Telegram (VENDOR.md edit 74): the cells this table's grids were granted, every init's (a flex wrapper inits its
        // item twice, and a build counts both); a replaced table gives them back.
        int cells_taken() const { return m_cells_taken; }
        int m_cells_taken = 0;

      protected:

        rendered_width _render(pixel_t x, pixel_t y, const containing_block_context& containing_block_size,
                               formatting_context* fmt_ctx, bool second_pass) override;
        void           add_children_ink(uint32_t generation, paint_ink& ink) override;

      public:
        explicit render_item_table(std::shared_ptr<element> src_el);

        std::shared_ptr<render_item> clone() override
        {
            return std::make_shared<render_item_table>(src_el());
        }
        void    draw_children(uint_ptr hdc, pixel_t x, pixel_t y, const position* clip, draw_flag flag,
                              int zindex) override;
        pixel_t get_draw_vertical_offset() override;
        std::shared_ptr<render_item> init() override;
        // Telegram (VENDOR.md edit 61): the border box of one of this table's rows or row groups, placed as its cells are
        // (get_placement): across the grid's columns, over the row's height (a group: from its first row's top to its last
        // row's bottom); false for anything else. The grid keeps the cells, and the rows are never init()ed, so a row or a
        // group has no render item of its own to place.
        bool part_placement(const element* part, position& out) const;
    };

    class render_item_table_part : public render_item
    {
      public:
        explicit render_item_table_part(std::shared_ptr<element> src_el) :
            render_item(std::move(src_el))
        {
        }

        std::shared_ptr<render_item> clone() override
        {
            return std::make_shared<render_item_table_part>(src_el());
        }
    };

    class render_item_table_row : public render_item
    {
      public:
        explicit render_item_table_row(std::shared_ptr<element> src_el) :
            render_item(std::move(src_el))
        {
        }

        std::shared_ptr<render_item> clone() override
        {
            return std::make_shared<render_item_table_row>(src_el());
        }
        bool for_inline_boxes([[maybe_unused]] const std::function<bool(const position& box, bool first, bool last)>&
                                  process) const override;
        bool is_point_inside(pixel_t x, pixel_t y) const override;
    };
} // namespace litehtml

#endif // LITEHTML_RENDER_TABLE_H
