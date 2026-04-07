#include "mbs_encode.h"
#include "cavlc.h"
#include "bs.h"
#include "tables.h"
#include "frame_writer.h"
#include "mbs_mux_common.h"
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <tuple>
#include <vector>

namespace subcodec::mbs {

using subcodec::tables::cbp_to_code_inter;
using subcodec::tables::luma_block_order;
using subcodec::tables::block_to_8x8;
using subcodec::frame_writer::predict_mv;

/* ---- nC computation (same algorithm as mbs_mux_common) ---- */

static int blk_to_x4(int blk_idx) {
    return (blk_idx & 1) | ((blk_idx >> 1) & 2);
}

static int blk_to_y4(int blk_idx) {
    return ((blk_idx >> 1) & 1) | ((blk_idx >> 2) & 2);
}

static int xy4_to_blk(int x4, int y4) {
    return (x4 & 1) | ((y4 & 1) << 1) | ((x4 & 2) << 1) | ((y4 & 2) << 2);
}

static int enc_calc_nc(int nc_left, int nc_above) {
    if (nc_left >= 0 && nc_above >= 0) return (nc_left + nc_above + 1) >> 1;
    if (nc_left >= 0) return nc_left;
    if (nc_above >= 0) return nc_above;
    return 0;
}

static int enc_calc_nc_luma(int blk_idx, const MbContext* cur,
                            const MbContext* left, const MbContext* above) {
    int nc_left = -1, nc_above = -1;
    int x4 = blk_to_x4(blk_idx);
    int y4 = blk_to_y4(blk_idx);

    if (x4 > 0) {
        nc_left = cur->nc[xy4_to_blk(x4 - 1, y4)];
    } else if (left) {
        nc_left = left->nc[xy4_to_blk(3, y4)];
    }

    if (y4 > 0) {
        nc_above = cur->nc[xy4_to_blk(x4, y4 - 1)];
    } else if (above) {
        nc_above = above->nc[xy4_to_blk(x4, 3)];
    }

    return enc_calc_nc(nc_left, nc_above);
}

static int enc_calc_nc_chroma(int blk_idx, const int* cur_nc,
                              const int* left_nc, const int* above_nc) {
    int cx = blk_idx % 2, cy = blk_idx / 2;
    int nc_left = -1, nc_above = -1;

    if (cx > 0) nc_left = cur_nc[blk_idx - 1];
    else if (left_nc) nc_left = left_nc[cy * 2 + 1];

    if (cy > 0) nc_above = cur_nc[blk_idx - 2];
    else if (above_nc) nc_above = above_nc[cx + 2];

    return enc_calc_nc(nc_left, nc_above);
}

/* ---- Per-MB bitstream encoding into a temporary buffer ---- */

/* Compute bit count from a bs_t state */
static int bs_bit_count(bs_t* b) {
    int byte_count = (int)(b->p - b->start);
    int partial = (b->bits_left < 8) ? (8 - b->bits_left) : 0;
    return byte_count * 8 + partial;
}

/* Byte-align a bs_t and return total bytes written */
static int bs_byte_align(bs_t* b) {
    if (b->bits_left != 8) {
        b->p++;
        b->bits_left = 8;
    }
    return (int)(b->p - b->start);
}

/* Encode P_16x16 MB bitstream (exp-golomb header + CAVLC blocks) into bs_t.
 * Returns 0 on success, -1 on error. Populates out_ctx. */
static int encode_mb_p16x16_bs(bs_t* b, const MacroblockData* mb,
                                const MbContext* left, const MbContext* above,
                                const MbContext* above_right,
                                MbContext* out_ctx) {
    /* Header blob: ue(0) + se(mvd_x) + se(mvd_y) + ue(cbp_code) [+ se(qp_delta)] */
    bs_write_ue(b, 0);  /* mb_type = P_L0_16x16 */

    int16_t mvp[2];
    predict_mv(left, above, above_right, mvp);
    bs_write_se(b, mb->mv_x - mvp[0]);
    bs_write_se(b, mb->mv_y - mvp[1]);

    int cbp = (mb->cbp_chroma << 4) | mb->cbp_luma;
    bs_write_ue(b, cbp_to_code_inter[cbp]);

    if (cbp != 0) {
        bs_write_se(b, 0);  /* qp_delta */
    }

    /* Initialize output context */
    *out_ctx = MbContext{};

    if (cbp != 0) {
        /* Luma blocks — real nC from neighbor context */
        for (int i = 0; i < 16; i++) {
            int blk_idx = luma_block_order[i];
            int parent_8x8 = block_to_8x8[blk_idx];

            if (!(mb->cbp_luma & (1 << parent_8x8))) {
                out_ctx->nc[blk_idx] = 0;
                continue;
            }

            int16_t coeffs[16];
            coeffs[0] = mb->luma_dc[blk_idx];
            for (int j = 0; j < 15; j++) {
                coeffs[j + 1] = mb->luma_ac[blk_idx][j];
            }

            int nc = enc_calc_nc_luma(blk_idx, out_ctx, left, above);
            int tc = subcodec::cavlc::write_block(b, coeffs, nc, 16);
            out_ctx->nc[blk_idx] = tc;
        }

        /* Chroma DC — canonical nC=-1 */
        if (mb->cbp_chroma >= 1) {
            subcodec::cavlc::write_block(b, mb->cb_dc, -1, 4);
            subcodec::cavlc::write_block(b, mb->cr_dc, -1, 4);
        }

        /* Chroma AC — real nC from neighbor context */
        if (mb->cbp_chroma == 2) {
            for (int i = 0; i < 4; i++) {
                int nc = enc_calc_nc_chroma(i, out_ctx->nc_cb,
                    left ? left->nc_cb : nullptr,
                    above ? above->nc_cb : nullptr);
                int tc = subcodec::cavlc::write_block(b, mb->cb_ac[i], nc, 15);
                out_ctx->nc_cb[i] = tc;
            }
            for (int i = 0; i < 4; i++) {
                int nc = enc_calc_nc_chroma(i, out_ctx->nc_cr,
                    left ? left->nc_cr : nullptr,
                    above ? above->nc_cr : nullptr);
                int tc = subcodec::cavlc::write_block(b, mb->cr_ac[i], nc, 15);
                out_ctx->nc_cr[i] = tc;
            }
        }
    }

    /* Update MV in context */
    out_ctx->mv[0] = mb->mv_x;
    out_ctx->mv[1] = mb->mv_y;

    return 0;
}

/* Encode I_16x16 MB bitstream (exp-golomb header + CAVLC blocks) into bs_t.
 * Returns 0 on success, -1 on error. Populates out_ctx. */
static int encode_mb_i16x16_bs(bs_t* b, const MacroblockData* mb,
                                const MbContext* left, const MbContext* above,
                                MbContext* out_ctx) {
    /* Determine if any AC block has non-zero coefficients */
    int ac_has_nonzero = 0;
    for (int i = 0; i < 16 && !ac_has_nonzero; i++) {
        for (int j = 0; j < 15; j++) {
            if (mb->luma_ac[i][j] != 0) {
                ac_has_nonzero = 1;
                break;
            }
        }
    }

    /* Header blob */
    int mb_type = 6 + static_cast<int>(mb->intra_pred_mode) + 4 * mb->cbp_chroma + 12 * ac_has_nonzero;
    bs_write_ue(b, (uint32_t)mb_type);
    bs_write_ue(b, static_cast<uint32_t>(mb->intra_chroma_mode));
    bs_write_se(b, 0);  /* qp_delta */

    /* Initialize output context */
    *out_ctx = MbContext{};

    /* Luma DC: real nC */
    {
        int nc = enc_calc_nc_luma(0, out_ctx, left, above);
        subcodec::cavlc::write_block(b, mb->luma_dc, nc, 16);
    }

    /* Luma AC: real nC from neighbor context */
    if (ac_has_nonzero) {
        for (int i = 0; i < 16; i++) {
            int blk_idx = luma_block_order[i];
            int nc = enc_calc_nc_luma(blk_idx, out_ctx, left, above);
            int tc = subcodec::cavlc::write_block(b, mb->luma_ac[blk_idx], nc, 15);
            out_ctx->nc[blk_idx] = tc;
        }
    }

    /* Chroma DC: canonical nC=-1 */
    if (mb->cbp_chroma >= 1) {
        subcodec::cavlc::write_block(b, mb->cb_dc, -1, 4);
        subcodec::cavlc::write_block(b, mb->cr_dc, -1, 4);
    }

    /* Chroma AC: real nC from neighbor context */
    if (mb->cbp_chroma == 2) {
        for (int i = 0; i < 4; i++) {
            int nc = enc_calc_nc_chroma(i, out_ctx->nc_cb,
                left ? left->nc_cb : nullptr,
                above ? above->nc_cb : nullptr);
            int tc = subcodec::cavlc::write_block(b, mb->cb_ac[i], nc, 15);
            out_ctx->nc_cb[i] = tc;
        }
        for (int i = 0; i < 4; i++) {
            int nc = enc_calc_nc_chroma(i, out_ctx->nc_cr,
                left ? left->nc_cr : nullptr,
                above ? above->nc_cr : nullptr);
            int tc = subcodec::cavlc::write_block(b, mb->cr_ac[i], nc, 15);
            out_ctx->nc_cr[i] = tc;
        }
    }

    out_ctx->mv[0] = 0;
    out_ctx->mv[1] = 0;

    return 0;
}

/* ---- Row blob assembly ---- */

/* Per-MB encoded data (temporary, before row assembly) */
struct MbEncoded {
    bool is_skip;
    int bit_count;          /* bits in bitstream (0 for SKIP) */
    uint8_t buf[4096];      /* bitstream data (only valid if !is_skip) */
};

/* Assemble row blob from per-MB encoded data.
 * Appends [leading_skips][trailing_skips][blob_bit_count LE][blob bytes...] to out.
 * For all-skip rows, appends just [leading_skips=width][trailing_skips=0][blob_bit_count=0]. */
static void assemble_row_blob(const MbEncoded* mbs, int width,
                               std::vector<uint8_t>& out) {
    /* Find first and last non-skip */
    int first_nonskip = -1, last_nonskip = -1;
    for (int i = 0; i < width; i++) {
        if (!mbs[i].is_skip) {
            if (first_nonskip < 0) first_nonskip = i;
            last_nonskip = i;
        }
    }

    if (first_nonskip < 0) {
        /* All-skip row */
        out.push_back(static_cast<uint8_t>(width));  /* leading_skips */
        out.push_back(0);                              /* trailing_skips */
        uint16_t zero = 0;
        out.push_back(static_cast<uint8_t>(zero & 0xFF));
        out.push_back(static_cast<uint8_t>((zero >> 8) & 0xFF));
        out.push_back(0);  /* leading_zero_bits */
        out.push_back(0);  /* trailing_zero_bits */
        return;
    }

    uint8_t leading = static_cast<uint8_t>(first_nonskip);
    uint8_t trailing = static_cast<uint8_t>(width - 1 - last_nonskip);

    /* Build the blob: non-skip MB bitstreams with interleaved ue(skip_count) */
    /* First, compute total bits needed */
    /* We need a temporary bs_t to write the blob */
    /* Max size: sum of all MB bitstreams + skip run exp-golomb codes */
    int total_mb_bits = 0;
    for (int i = first_nonskip; i <= last_nonskip; i++) {
        if (!mbs[i].is_skip) {
            total_mb_bits += mbs[i].bit_count;
        }
    }
    /* Skip run ue() codes: at most width * 32 bits each (generous) */
    int max_blob_bytes = (total_mb_bits + width * 32 + 7) / 8 + 16;

    std::vector<uint8_t> blob_buf(max_blob_bytes, 0);
    bs_t blob;
    bs_init(&blob, blob_buf.data(), blob_buf.size());

    bool first_coded = true;
    int skip_count = 0;

    for (int i = first_nonskip; i <= last_nonskip; i++) {
        if (mbs[i].is_skip) {
            skip_count++;
            continue;
        }

        if (!first_coded) {
            /* Write ue(skip_count) before this non-skip MB */
            bs_write_ue(&blob, (uint32_t)skip_count);
            skip_count = 0;
        } else {
            first_coded = false;
            skip_count = 0;
        }

        /* Copy MB bitstream into blob */
        subcodec::mux::bs_copy_bits(&blob, mbs[i].buf, 0, mbs[i].bit_count);
    }

    int blob_bits = bs_bit_count(&blob);
    auto [max_run, leading_zb, trailing_zb] = subcodec::mux::scan_zero_runs(blob_buf.data(), blob_bits);

    /* Byte-align the blob */
    int blob_bytes = bs_byte_align(&blob);

    /* Write 6-byte row header + blob to output */
    out.push_back(leading);
    out.push_back(trailing);
    uint16_t bbc = static_cast<uint16_t>(blob_bits);
    if (max_run >= 16) bbc |= 0x8000;
    out.push_back(static_cast<uint8_t>(bbc & 0xFF));
    out.push_back(static_cast<uint8_t>((bbc >> 8) & 0xFF));
    out.push_back(static_cast<uint8_t>(std::min(leading_zb, 255)));
    out.push_back(static_cast<uint8_t>(std::min(trailing_zb, 255)));

    /* Append blob bytes */
    out.insert(out.end(), blob_buf.data(), blob_buf.data() + blob_bytes);
}

/* ---- Public API ---- */

MbsEncodedFrame encode_frame(
    const FrameParams& params,
    const MacroblockData* mbs) {

    int width = params.width_mbs;
    int height = params.height_mbs;
    int num_mbs = width * height;
    if (num_mbs <= 0 || !mbs) return {};

    MbsEncodedFrame result;
    result.data.reserve(4096);
    result.rows.resize(height);

    /* Allocate context row for nC / MV prediction */
    std::vector<MbContext> ctx_row(width);
    MbContext ctx_left{};

    /* Temporary per-MB encoded data for one row */
    std::vector<MbEncoded> row_mbs(width);

    int err = 0;
    for (int mb_y = 0; mb_y < height && !err; mb_y++) {
        ctx_left = MbContext{};

        for (int mb_x = 0; mb_x < width && !err; mb_x++) {
            int mb_idx = mb_y * width + mb_x;
            const MacroblockData* mb = &mbs[mb_idx];

            MbContext* above = (mb_y > 0) ? &ctx_row[mb_x] : nullptr;
            MbContext* left_ptr = (mb_x > 0) ? &ctx_left : nullptr;
            MbContext* above_right = (mb_y > 0 && mb_x < width - 1)
                                        ? &ctx_row[mb_x + 1] : nullptr;

            MbContext out_ctx{};
            MbEncoded& enc = row_mbs[mb_x];

            switch (mb->mb_type) {
                case MbType::SKIP:
                    enc.is_skip = true;
                    enc.bit_count = 0;
                    break;
                case MbType::P_16x16: {
                    enc.is_skip = false;
                    memset(enc.buf, 0, sizeof(enc.buf));
                    bs_t b;
                    bs_init(&b, enc.buf, sizeof(enc.buf));
                    err = encode_mb_p16x16_bs(&b, mb, left_ptr, above,
                                               above_right, &out_ctx);
                    enc.bit_count = bs_bit_count(&b);
                    break;
                }
                case MbType::I_16x16: {
                    enc.is_skip = false;
                    memset(enc.buf, 0, sizeof(enc.buf));
                    bs_t b;
                    bs_init(&b, enc.buf, sizeof(enc.buf));
                    err = encode_mb_i16x16_bs(&b, mb, left_ptr, above, &out_ctx);
                    enc.bit_count = bs_bit_count(&b);
                    break;
                }
                default:
                    err = -1;
                    break;
            }

            ctx_left = out_ctx;
            ctx_row[mb_x] = out_ctx;
        }

        if (!err) {
            /* Record where this row's data starts in result.data */
            size_t row_data_start = result.data.size();

            /* Assemble row blob and append to result.data */
            assemble_row_blob(row_mbs.data(), width, result.data);

            /* Parse the row descriptor from what we just wrote */
            MbsRow& row = result.rows[mb_y];
            const uint8_t* rp = result.data.data() + row_data_start;
            row.leading_skips = rp[0];
            row.trailing_skips = rp[1];
            row.blob_bit_count = static_cast<uint16_t>(rp[2]) |
                                 (static_cast<uint16_t>(rp[3]) << 8);
            row.leading_zero_bits = rp[4];
            row.trailing_zero_bits = rp[5];
            if (row.bit_count() > 0) {
                row.blob_data = rp + 6;
            } else {
                row.blob_data = nullptr;
            }
        }
    }

    if (err) return {};

    /* Fix up blob_data pointers (they may have been invalidated by vector growth).
     * Re-parse from the final data buffer. */
    {
        const uint8_t* dp = result.data.data();
        for (int mb_y = 0; mb_y < height; mb_y++) {
            MbsRow& row = result.rows[mb_y];
            row.leading_skips = dp[0];
            row.trailing_skips = dp[1];
            row.blob_bit_count = static_cast<uint16_t>(dp[2]) |
                                 (static_cast<uint16_t>(dp[3]) << 8);
            row.leading_zero_bits = dp[4];
            row.trailing_zero_bits = dp[5];
            int blob_bytes = (row.bit_count() + 7) / 8;
            if (row.bit_count() > 0) {
                row.blob_data = dp + 6;
            } else {
                row.blob_data = nullptr;
            }
            dp += 6 + blob_bytes;
        }
    }

    return result;
}

/* ---- Merged row blob (local copy for encode_frame_merged) ---- */

static MbsRow merge_color_alpha_row_local(
    const MbsRow& color, const MbsRow& alpha,
    int sprite_w, int padding,
    std::vector<uint8_t>& out_data) {

    int slot_w = sprite_w * 2 - padding;
    bool has_color = color.bit_count() > 0;
    bool has_alpha = alpha.bit_count() > 0;

    MbsRow merged;
    merged.blob_data = nullptr;

    if (!has_color && !has_alpha) {
        merged.leading_skips = static_cast<uint8_t>(std::min(slot_w, 255));
        merged.trailing_skips = 0;
        merged.blob_bit_count = 0;
        merged.leading_zero_bits = 0;
        merged.trailing_zero_bits = 0;
        return merged;
    }

    /* Compute merged leading/trailing skips */
    int merged_leading, merged_trailing;
    if (has_color) {
        merged_leading = color.leading_skips;
    } else {
        merged_leading = (sprite_w - padding) + alpha.leading_skips;
    }

    if (has_alpha) {
        merged_trailing = alpha.trailing_skips;
    } else {
        merged_trailing = color.trailing_skips + (sprite_w - padding);
    }

    /* Build merged blob bitstream */
    int max_bits = (has_color ? color.bit_count() : 0) +
                   25 /* max ue bits */ +
                   (has_alpha ? alpha.bit_count() : 0);
    int max_bytes = (max_bits + 7) / 8 + 4;
    size_t blob_start = out_data.size();
    out_data.resize(blob_start + max_bytes, 0);

    bs_t bs;
    bs_init(&bs, out_data.data() + blob_start, max_bytes);

    if (has_color) {
        subcodec::mux::bs_copy_bits(&bs, color.blob_data, 0, color.bit_count());
    }

    if (has_color && has_alpha) {
        int inter_skip;
        if (padding >= alpha.leading_skips) {
            inter_skip = color.trailing_skips;
        } else {
            inter_skip = color.trailing_skips + alpha.leading_skips - padding;
        }
        bs_write_ue(&bs, static_cast<uint32_t>(inter_skip));
    }

    if (has_alpha) {
        subcodec::mux::bs_copy_bits(&bs, alpha.blob_data, 0, alpha.bit_count());
    }

    int merged_bits = static_cast<int>(bs.p - bs.start) * 8 + (8 - bs.bits_left);
    if (bs.bits_left < 8) { bs.p++; bs.bits_left = 8; }
    int merged_bytes = (merged_bits + 7) / 8;
    out_data.resize(blob_start + merged_bytes);

    auto [max_run, leading_zb, trailing_zb] = subcodec::mux::scan_zero_runs(
        out_data.data() + blob_start, merged_bits);

    merged.leading_skips = static_cast<uint8_t>(std::min(merged_leading, 255));
    merged.trailing_skips = static_cast<uint8_t>(std::min(merged_trailing, 255));
    uint16_t bbc = static_cast<uint16_t>(merged_bits & 0x7FFF);
    if (max_run >= 16) bbc |= 0x8000;
    merged.blob_bit_count = bbc;
    merged.leading_zero_bits = static_cast<uint8_t>(std::min(leading_zb, 255));
    merged.trailing_zero_bits = static_cast<uint8_t>(std::min(trailing_zb, 255));
    merged.blob_data = out_data.data() + blob_start;
    return merged;
}

/* ---- encode_frame_merged ---- */

MbsEncodedFrame encode_frame_merged(
    const FrameParams& color_params, const MacroblockData* color_mbs,
    const FrameParams& alpha_params, const MacroblockData* alpha_mbs,
    int sprite_w, int padding) {

    // Encode color and alpha halves separately
    auto color_ef = encode_frame(color_params, color_mbs);
    if (color_ef.data.empty()) return {};

    auto alpha_ef = encode_frame(alpha_params, alpha_mbs);
    if (alpha_ef.data.empty()) return {};

    int height = color_params.height_mbs;

    // Merge each row pair
    MbsEncodedFrame result;
    result.rows.resize(height);

    std::vector<uint8_t> merged_data;
    merged_data.reserve(color_ef.data.size() + alpha_ef.data.size());
    std::vector<size_t> blob_offsets(height, SIZE_MAX);

    for (int y = 0; y < height; y++) {
        size_t offset_before = merged_data.size();
        MbsRow merged = merge_color_alpha_row_local(
            color_ef.rows[y], alpha_ef.rows[y],
            sprite_w, padding, merged_data);

        result.rows[y] = merged;
        if (merged.blob_data) {
            blob_offsets[y] = offset_before;
        }
    }

    // Consolidate blob data and fix up pointers
    result.data = std::move(merged_data);
    for (int y = 0; y < height; y++) {
        if (blob_offsets[y] != SIZE_MAX) {
            result.rows[y].blob_data = result.data.data() + blob_offsets[y];
        }
    }

    // Write serialized form: 6-byte header + blob bytes per row
    std::vector<uint8_t> serialized;
    serialized.reserve(result.data.size() + height * 6);
    for (int y = 0; y < height; y++) {
        const MbsRow& row = result.rows[y];
        serialized.push_back(row.leading_skips);
        serialized.push_back(row.trailing_skips);
        serialized.push_back(static_cast<uint8_t>(row.blob_bit_count & 0xFF));
        serialized.push_back(static_cast<uint8_t>((row.blob_bit_count >> 8) & 0xFF));
        serialized.push_back(row.leading_zero_bits);
        serialized.push_back(row.trailing_zero_bits);
        int blob_bytes = (row.bit_count() + 7) / 8;
        if (blob_bytes > 0 && row.blob_data) {
            serialized.insert(serialized.end(), row.blob_data, row.blob_data + blob_bytes);
        }
    }

    // Replace data with serialized form and re-parse row pointers
    result.data = std::move(serialized);
    const uint8_t* dp = result.data.data();
    for (int y = 0; y < height; y++) {
        MbsRow& row = result.rows[y];
        row.leading_skips = dp[0];
        row.trailing_skips = dp[1];
        row.blob_bit_count = static_cast<uint16_t>(dp[2]) | (static_cast<uint16_t>(dp[3]) << 8);
        row.leading_zero_bits = dp[4];
        row.trailing_zero_bits = dp[5];
        int blob_bytes = (row.bit_count() + 7) / 8;
        row.blob_data = (row.bit_count() > 0) ? dp + 6 : nullptr;
        dp += 6 + blob_bytes;
    }

    return result;
}

} // namespace subcodec::mbs
