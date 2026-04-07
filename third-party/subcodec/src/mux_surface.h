#pragma once

#include <cstdint>
#include <cstddef>
#include <memory>
#include <span>
#include <expected>
#include <functional>
#include <vector>
#include <optional>
#include <filesystem>
#include "types.h"
#include "error.h"
#include "mbs_mux_common.h"

namespace subcodec {

using FrameSink = std::function<void(std::span<const uint8_t>)>;

struct CompactionInfo {
    int active_sprites;
    int max_slots;
    int current_grid_mbs;
    int min_grid_mbs;
};

class MuxSurface {
public:
    struct Params {
        int sprite_width = 0;    // Content width in pixels (multiple of 16)
        int sprite_height = 0;   // Content height in pixels (multiple of 16)
        int max_slots = 0;
        uint8_t qp = 0;
        int8_t qp_delta_idr = 0;
        int8_t qp_delta_p = 0;
    };

    struct SpriteRegion {
        int slot;
        struct Rect { int x, y, width, height; };
        Rect color;
        Rect alpha;
    };

    struct ResizeResult {
        std::vector<SpriteRegion> regions;
    };

    static std::expected<MuxSurface, Error>
    create(const Params& params, FrameSink sink);

    ~MuxSurface() = default;
    MuxSurface(MuxSurface&&) = default;
    MuxSurface& operator=(MuxSurface&&) = default;

    std::expected<SpriteRegion, Error> add_sprite(const std::filesystem::path& mbs_path);
    std::expected<SpriteRegion, Error> add_sprite(MbsSprite sprite);
    void remove_sprite(int slot);
    std::expected<void, Error> advance_frame(FrameSink sink);
    void advance_sprite(int slot);
    std::expected<bool, Error> emit_frame_if_needed(FrameSink sink);

    std::expected<ResizeResult, Error> resize(
        int new_max_slots,
        std::span<const uint8_t> decoded_y,
        std::span<const uint8_t> decoded_cb,
        std::span<const uint8_t> decoded_cr,
        int decoded_width,
        int decoded_height,
        int stride_y,
        int stride_cb,
        int stride_cr,
        FrameSink sink);

    CompactionInfo check_compaction_opportunity() const;

    [[nodiscard]] int width_mbs() const { return total_w_; }
    [[nodiscard]] int height_mbs() const { return total_h_; }
    [[nodiscard]] int frame_num() const { return frame_num_; }

private:
    MuxSurface() = default;

    Params params_;
    int sprite_w_mbs_ = 0;     // padded sprite width in MBs
    int sprite_h_mbs_ = 0;     // padded sprite height in MBs
    int content_w_ = 0;        // content width in pixels
    int content_h_ = 0;        // content height in pixels
    int total_w_ = 0, total_h_ = 0;
    int cols_ = 0, rows_ = 0;
    int stride_x_ = 0, stride_y_ = 0;
    int frame_num_ = 0;
    int log2_max_frame_num_ = 8;
    int num_mbs_ = 0;

    struct Slot {
        std::optional<MbsSprite> sprite;
        int current_frame = 0;
        bool active = false;
        bool needs_emit = false;  // set by advance_sprite, cleared by emit
    };

    void rebuild_row_plans_();

    std::vector<Slot> slots_;
    std::vector<mux::SlotInfo> slot_infos_;
    std::unique_ptr<uint8_t[]> buf_;
    size_t buf_size_ = 0;
    std::vector<mux::CompositeRowPlan> row_plans_;
    std::vector<mux::RowOp> row_ops_;
    bool plans_dirty_ = true;
    bool dirty_ = false;
    std::unique_ptr<uint8_t[]> rbsp_buf_;
    size_t rbsp_buf_size_ = 0;
    std::vector<mux::MicroOp> micro_ops_;
};

} // namespace subcodec
