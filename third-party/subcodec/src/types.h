#pragma once

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <vector>
#include <span>
#include <memory>
#include <expected>
#include <filesystem>
#include "error.h"

namespace subcodec {

enum class MbType : uint8_t {
    SKIP = 0,
    P_16x16 = 1,
    I_16x16 = 2,
};

enum class I16PredMode : uint8_t {
    V = 0, H = 1, DC = 2, P = 3,
};

enum class ChromaPredMode : uint8_t {
    DC = 0, H = 1, V = 2, P = 3,
};

struct MacroblockData {
    MbType mb_type = MbType::SKIP;
    int16_t mv_x = 0;
    int16_t mv_y = 0;
    I16PredMode intra_pred_mode = I16PredMode::V;
    ChromaPredMode intra_chroma_mode = ChromaPredMode::DC;
    int16_t luma_dc[16] = {};
    int16_t luma_ac[16][15] = {};
    int16_t cb_dc[4] = {};
    int16_t cr_dc[4] = {};
    int16_t cb_ac[4][15] = {};
    int16_t cr_ac[4][15] = {};
    uint8_t cbp_luma = 0;
    uint8_t cbp_chroma = 0;
};

struct FrameParams {
    uint16_t width_mbs = 0;
    uint16_t height_mbs = 0;
    uint8_t qp = 0;
    int8_t slice_qp_delta = 0;
    uint8_t log2_max_frame_num = 0;
    uint8_t pic_order_cnt_type = 0;
    uint8_t log2_max_pic_order_cnt_lsb = 0;
};

struct MbContext {
    int16_t mv[2] = {};
    int nc[16] = {};
    int nc_cb[4] = {};
    int nc_cr[4] = {};
};

// Per-row blob descriptor (populated at load or encode time)
struct MbsRow {
    uint8_t leading_skips = 0;      // content SKIPs before first non-skip
    uint8_t trailing_skips = 0;     // content SKIPs after last non-skip
    uint16_t blob_bit_count = 0;    // [14:0] = bit count, [15] = has_long_zero_run
    uint8_t leading_zero_bits = 0;  // zero bits at blob start (capped at 255)
    uint8_t trailing_zero_bits = 0; // zero bits at blob end (capped at 255)
    const uint8_t* blob_data = nullptr;

    uint16_t bit_count() const { return blob_bit_count & 0x7FFF; }
    bool has_long_zero_run() const { return (blob_bit_count & 0x8000) != 0; }
};

// Owned frame data returned by mbs::encode_frame()
struct MbsEncodedFrame {
    std::vector<uint8_t> data;      // raw frame data (row metadata + blobs)
    std::vector<MbsRow> rows;       // parsed row descriptors
};

// View into bulk-owned frame data (used by MbsSprite after load or set_frames)
struct MbsFrame {
    std::span<MbsRow> merged_rows;  // pre-merged color+alpha rows (slot_w-relative skips)
};

// Complete sprite in .mbs serialized format
class MbsSprite {
public:
    uint16_t width_mbs = 0;
    uint16_t height_mbs = 0;
    uint16_t num_frames = 0;
    uint8_t qp = 0;
    int8_t qp_delta_idr = 0;
    int8_t qp_delta_p = 0;
    std::vector<MbsFrame> frames;

    MbsSprite() = default;
    ~MbsSprite() = default;
    MbsSprite(MbsSprite&&) = default;
    MbsSprite& operator=(MbsSprite&&) = default;
    MbsSprite(const MbsSprite&) = delete;
    MbsSprite& operator=(const MbsSprite&) = delete;

    static std::expected<MbsSprite, Error> load(const std::filesystem::path& path);
    std::expected<void, Error> save(const std::filesystem::path& path) const;

    // Consolidate encoded frames into bulk storage and set up views
    void set_frames(std::vector<MbsEncodedFrame>&& encoded);

private:
    std::unique_ptr<uint8_t[]> bulk_data_;
    std::vector<MbsRow> all_rows_;
};

} // namespace subcodec
