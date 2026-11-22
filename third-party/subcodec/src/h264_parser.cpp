#include "h264_parser.h"
#include "cavlc.h"
#include "bs.h"
#include "tables.h"
#include "frame_writer.h"
#include <cstdio>
#include <cstring>

using namespace subcodec;
using subcodec::tables::cbp_to_code_inter;
using subcodec::tables::cbp_to_code_intra;
using subcodec::tables::luma_block_order;
using subcodec::tables::block_to_8x8;

namespace {

// Inverse of cbp_to_code_inter: given codeNum, find cbp_luma and cbp_chroma
static int decode_cbp_inter(uint32_t code_num, uint8_t* cbp_luma, uint8_t* cbp_chroma) {
    for (int i = 0; i < 48; i++) {
        if (cbp_to_code_inter[i] == code_num) {
            *cbp_chroma = (uint8_t)(i / 16);
            *cbp_luma = (uint8_t)(i % 16);
            return 0;
        }
    }
    return -1;
}

// Inverse of cbp_to_code_intra: given codeNum, find cbp_luma and cbp_chroma
static int decode_cbp_intra(uint32_t code_num, uint8_t* cbp_luma, uint8_t* cbp_chroma) {
    for (int i = 0; i < 48; i++) {
        if (cbp_to_code_intra[i] == code_num) {
            *cbp_chroma = (uint8_t)(i / 16);
            *cbp_luma = (uint8_t)(i % 16);
            return 0;
        }
    }
    return -1;
}

// Remove emulation prevention bytes (00 00 03 -> 00 00)
static size_t remove_emulation_prevention(const uint8_t* src, size_t src_len,
                                          uint8_t* dst, size_t dst_size) {
    size_t si = 0, di = 0;
    while (si < src_len && di < dst_size) {
        if (si + 2 < src_len && src[si] == 0x00 && src[si + 1] == 0x00 && src[si + 2] == 0x03) {
            dst[di++] = 0x00;
            if (di < dst_size) dst[di++] = 0x00;
            si += 3;
        } else {
            dst[di++] = src[si++];
        }
    }
    return di;
}

// Check if there is more RBSP data (i.e., not just trailing bits)
static int more_rbsp_data(bs_t* b) {
    // If we're at or past the end, no more data
    if (bs_eof(b)) return 0;

    // Save position
    bs_t saved;
    bs_clone(&saved, b);

    // Find the last 1 bit in the remaining data
    // If all remaining bits are 0 after the current position, no data
    // If the remaining bits are exactly: 1 followed by 0s to byte boundary, no data

    // Simple approach: check if we have more than 8 bits remaining
    // (trailing bits are at most 8 bits)
    int bits_remaining = 0;
    uint8_t* p = b->p;
    int bl = b->bits_left;

    // Count remaining bits
    bits_remaining = bl;  // bits left in current byte
    if (p < b->end) {
        bits_remaining += (int)(b->end - p - 1) * 8;
    }

    if (bits_remaining <= 0) return 0;
    if (bits_remaining > 8) return 1;  // More than trailing bits

    // 8 or fewer bits remaining - check if it's just trailing bits
    // Trailing bits: 1 followed by 0s
    // Read remaining bits and check
    uint32_t remaining = 0;
    for (int i = 0; i < bits_remaining; i++) {
        remaining = (remaining << 1) | bs_read_u1(&saved);
    }

    // Check if remaining == 1 << (bits_remaining - 1) (just a stop bit + zeros)
    // Or more generally: remaining should be a power of 2
    if (remaining != 0 && (remaining & (remaining - 1)) == 0) {
        return 0;  // It's just trailing bits
    }

    return 1;  // There's real data
}

// H.264 4x4 block index <-> (x4, y4) conversions
// Block layout in a macroblock:
//  0  1  4  5
//  2  3  6  7
//  8  9 12 13
// 10 11 14 15
static inline int blk_to_x4(int blk_idx) {
    return (blk_idx & 1) | ((blk_idx >> 1) & 2);
}
static inline int blk_to_y4(int blk_idx) {
    return ((blk_idx >> 1) & 1) | ((blk_idx >> 2) & 2);
}
static inline int xy4_to_blk(int x4, int y4) {
    return (x4 & 1) | ((y4 & 1) << 1) | ((x4 & 2) << 1) | ((y4 & 2) << 2);
}

// Calculate nC for a luma 4x4 block using neighbor context
static int calc_block_nc(int blk_idx, const MbContext* out_ctx,
                         const MbContext* left, const MbContext* above) {
    int nc_left = -1, nc_above = -1;
    int x4 = blk_to_x4(blk_idx);
    int y4 = blk_to_y4(blk_idx);

    // Left neighbor
    if (x4 > 0) {
        nc_left = out_ctx->nc[xy4_to_blk(x4 - 1, y4)];
    } else if (left) {
        nc_left = left->nc[xy4_to_blk(3, y4)];
    }

    // Above neighbor
    if (y4 > 0) {
        nc_above = out_ctx->nc[xy4_to_blk(x4, y4 - 1)];
    } else if (above) {
        nc_above = above->nc[xy4_to_blk(x4, 3)];
    }

    return subcodec::cavlc::calc_nc(nc_left, nc_above);
}

// Calculate nC for a chroma 4x4 block (Cb or Cr)
static int calc_chroma_nc(int blk_idx, const int* chroma_nc,
                          const int* left_nc, const int* above_nc) {
    int cx = blk_idx % 2, cy = blk_idx / 2;
    int nc_left = -1, nc_above = -1;

    // Chroma 2x2 block layout: [0 1 / 2 3]
    if (cx > 0) nc_left = chroma_nc[blk_idx - 1];
    else if (left_nc) nc_left = left_nc[cy * 2 + 1];  // left MB's right column at same y

    if (cy > 0) nc_above = chroma_nc[blk_idx - 2];
    else if (above_nc) nc_above = above_nc[cx + 2]; // above MB's bottom row at same x

    return subcodec::cavlc::calc_nc(nc_left, nc_above);
}

// Read chroma AC blocks and update context.
static void read_chroma_ac(bs_t* b, MacroblockData* mb,
                            MbContext* out_ctx,
                            const MbContext* left,
                            const MbContext* above) {
    for (int i = 0; i < 4; i++) {
        int nc = calc_chroma_nc(i, out_ctx->nc_cb,
                                left ? left->nc_cb : NULL,
                                above ? above->nc_cb : NULL);
        int16_t coeffs[15];
        int tc = subcodec::cavlc::read_block(b, coeffs, nc, 15);
        out_ctx->nc_cb[i] = tc;
        for (int j = 0; j < 15; j++)
            mb->cb_ac[i][j] = coeffs[j];
    }
    for (int i = 0; i < 4; i++) {
        int nc = calc_chroma_nc(i, out_ctx->nc_cr,
                                left ? left->nc_cr : NULL,
                                above ? above->nc_cr : NULL);
        int16_t coeffs[15];
        int tc = subcodec::cavlc::read_block(b, coeffs, nc, 15);
        out_ctx->nc_cr[i] = tc;
        for (int j = 0; j < 15; j++)
            mb->cr_ac[i][j] = coeffs[j];
    }
}

// Read P_16x16 macroblock (inverse of write_mb_p16x16)
static void read_mb_p16x16(bs_t* b, MacroblockData* mb,
                           const MbContext* left, const MbContext* above,
                           const MbContext* above_right,
                           MbContext* out_ctx) {
    mb->mb_type = MbType::P_16x16;

    // Read MV delta and reconstruct MV
    int16_t mvp[2];
    subcodec::frame_writer::predict_mv(left, above, above_right, mvp);
    int32_t mvd_x = bs_read_se(b);
    int32_t mvd_y = bs_read_se(b);
    mb->mv_x = (int16_t)(mvp[0] + mvd_x);
    mb->mv_y = (int16_t)(mvp[1] + mvd_y);

    // Read CBP (always present per H.264 spec for P_L0_16x16)
    uint32_t cbp_code = bs_read_ue(b);
    *out_ctx = MbContext{};

    if (decode_cbp_inter(cbp_code, &mb->cbp_luma, &mb->cbp_chroma) != 0) {
        mb->cbp_luma = 0;
        mb->cbp_chroma = 0;
        out_ctx->mv[0] = mb->mv_x;
        out_ctx->mv[1] = mb->mv_y;
        return;
    }

    if (mb->cbp_luma == 0 && mb->cbp_chroma == 0) {
        // No residual
        out_ctx->mv[0] = mb->mv_x;
        out_ctx->mv[1] = mb->mv_y;
        return;
    }

    // Read mb_qp_delta (discarded)
    bs_read_se(b);

    // Read luma residual
    for (int i = 0; i < 16; i++) {
        int blk_idx = luma_block_order[i];
        int parent_8x8 = block_to_8x8[blk_idx];

        if (!(mb->cbp_luma & (1 << parent_8x8))) {
            out_ctx->nc[blk_idx] = 0;
            continue;
        }

        int nc = calc_block_nc(blk_idx, out_ctx, left, above);

        int16_t coeffs[16];
        int tc = subcodec::cavlc::read_block(b, coeffs, nc, 16);
        out_ctx->nc[blk_idx] = tc;

        // Split: coeffs[0] -> luma_dc, coeffs[1..15] -> luma_ac
        mb->luma_dc[blk_idx] = coeffs[0];
        for (int j = 0; j < 15; j++) {
            mb->luma_ac[blk_idx][j] = coeffs[j + 1];
        }
    }

    // Chroma DC
    if (mb->cbp_chroma >= 1) {
        subcodec::cavlc::read_block(b, mb->cb_dc, -1, 4);
        subcodec::cavlc::read_block(b, mb->cr_dc, -1, 4);
    }

    // Chroma AC
    if (mb->cbp_chroma == 2) {
        read_chroma_ac(b, mb, out_ctx, left, above);
    }

    out_ctx->mv[0] = mb->mv_x;
    out_ctx->mv[1] = mb->mv_y;
}

// Read P_8x8 or P_8x8ref0 macroblock (mb_type 3 or 4 in P-slice)
// We store as P_16x16 with the first sub-partition's MV for simplicity
static void read_mb_p8x8(bs_t* b, MacroblockData* mb, int is_ref0,
                          const MbContext* left, const MbContext* above,
                          const MbContext* above_right,
                          MbContext* out_ctx) {
    mb->mb_type = MbType::P_16x16;  // Approximate as P_16x16

    // Read 4 sub_mb_type values
    int sub_mb_type[4];
    int num_sub_parts[4];
    for (int i = 0; i < 4; i++) {
        sub_mb_type[i] = (int)bs_read_ue(b);
        // P sub_mb_type: 0=8x8(1 part), 1=8x4(2), 2=4x8(2), 3=4x4(4)
        switch (sub_mb_type[i]) {
            case 0: num_sub_parts[i] = 1; break;
            case 1: num_sub_parts[i] = 2; break;
            case 2: num_sub_parts[i] = 2; break;
            case 3: num_sub_parts[i] = 4; break;
            default: num_sub_parts[i] = 1; break;
        }
    }

    // ref_idx: for P_8x8 (not ref0), read ref_idx for each 8x8 partition
    if (!is_ref0) {
        for (int i = 0; i < 4; i++) {
            bs_read_ue(b);  // ref_idx_l0[i] (typically 0 with single ref)
        }
    }

    // MVD for each sub-partition
    int16_t first_mv_x = 0, first_mv_y = 0;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < num_sub_parts[i]; j++) {
            int32_t mvd_x = bs_read_se(b);
            int32_t mvd_y = bs_read_se(b);
            if (i == 0 && j == 0) {
                // Use first partition's MV as representative
                int16_t mvp[2];
                subcodec::frame_writer::predict_mv(left, above, above_right, mvp);
                first_mv_x = (int16_t)(mvp[0] + mvd_x);
                first_mv_y = (int16_t)(mvp[1] + mvd_y);
            }
        }
    }

    mb->mv_x = first_mv_x;
    mb->mv_y = first_mv_y;

    // CBP
    uint32_t cbp_code = bs_read_ue(b);
    *out_ctx = MbContext{};

    if (decode_cbp_inter(cbp_code, &mb->cbp_luma, &mb->cbp_chroma) != 0) {
        mb->cbp_luma = 0;
        mb->cbp_chroma = 0;
        out_ctx->mv[0] = mb->mv_x;
        out_ctx->mv[1] = mb->mv_y;
        return;
    }

    if (mb->cbp_luma == 0 && mb->cbp_chroma == 0) {
        out_ctx->mv[0] = mb->mv_x;
        out_ctx->mv[1] = mb->mv_y;
        return;
    }

    // mb_qp_delta
    bs_read_se(b);

    // Luma residual
    for (int i = 0; i < 16; i++) {
        int blk_idx = luma_block_order[i];
        int parent_8x8 = block_to_8x8[blk_idx];

        if (!(mb->cbp_luma & (1 << parent_8x8))) {
            out_ctx->nc[blk_idx] = 0;
            continue;
        }

        int nc = calc_block_nc(blk_idx, out_ctx, left, above);
        int16_t coeffs[16];
        int tc = subcodec::cavlc::read_block(b, coeffs, nc, 16);
        out_ctx->nc[blk_idx] = tc;
        mb->luma_dc[blk_idx] = coeffs[0];
        for (int j = 0; j < 15; j++)
            mb->luma_ac[blk_idx][j] = coeffs[j + 1];
    }

    // Chroma DC
    if (mb->cbp_chroma >= 1) {
        subcodec::cavlc::read_block(b, mb->cb_dc, -1, 4);
        subcodec::cavlc::read_block(b, mb->cr_dc, -1, 4);
    }

    // Chroma AC
    if (mb->cbp_chroma == 2) {
        read_chroma_ac(b, mb, out_ctx, left, above);
    }

    out_ctx->mv[0] = mb->mv_x;
    out_ctx->mv[1] = mb->mv_y;
}

// Read I_16x16 macroblock (inverse of write_mb_i16x16)
// offset: mb_type_code - 6 for P-slice, mb_type_code - 1 for I-slice
static void read_mb_i16x16(bs_t* b, MacroblockData* mb, int offset,
                           const MbContext* left, const MbContext* above,
                           MbContext* out_ctx) {
    mb->mb_type = MbType::I_16x16;

    int ac_has_nonzero = offset / 12;
    int cbp_chroma = (offset % 12) / 4;
    int pred_mode = offset % 4;

    mb->intra_pred_mode = static_cast<subcodec::I16PredMode>(pred_mode);
    mb->cbp_chroma = (uint8_t)cbp_chroma;

    // Read intra_chroma_pred_mode
    mb->intra_chroma_mode = static_cast<subcodec::ChromaPredMode>(bs_read_ue(b));

    // Read mb_qp_delta
    int32_t qpd = bs_read_se(b);
    *out_ctx = MbContext{};

    // Read luma DC (16 coefficients) - nC from block 0 neighbors per H.264 spec
    int dc_nc = calc_block_nc(0, out_ctx, left, above);
    int dc_tc = subcodec::cavlc::read_block(b, mb->luma_dc, dc_nc, 16);

    // Read luma AC blocks if present
    if (ac_has_nonzero) {
        for (int i = 0; i < 16; i++) {
            int blk_idx = luma_block_order[i];
            int nc = calc_block_nc(blk_idx, out_ctx, left, above);

            int16_t coeffs[15];
            int tc = subcodec::cavlc::read_block(b, coeffs, nc, 15);
            out_ctx->nc[blk_idx] = tc;

            for (int j = 0; j < 15; j++)
                mb->luma_ac[blk_idx][j] = coeffs[j];
        }
    }

    // Chroma DC
    if (cbp_chroma > 0) {
        subcodec::cavlc::read_block(b, mb->cb_dc, -1, 4);
        subcodec::cavlc::read_block(b, mb->cr_dc, -1, 4);
    }

    // Chroma AC
    if (cbp_chroma == 2) {
        read_chroma_ac(b, mb, out_ctx, left, above);
    }

    out_ctx->mv[0] = 0;
    out_ctx->mv[1] = 0;
}


} // anonymous namespace

namespace subcodec {

std::expected<std::vector<MacroblockData>, Error>
H264Parser::parse_slice(std::span<const uint8_t> nal_data,
                        const FrameParams& params) {
    return parse_slice_ex(nal_data, params, nullptr);
}

std::expected<std::vector<MacroblockData>, Error>
H264Parser::parse_slice_ex(std::span<const uint8_t> nal_data,
                           const FrameParams& params,
                           int* out_slice_qp_delta) {
    const uint8_t* buf = nal_data.data();
    size_t buf_size = nal_data.size();

    if (!buf || buf_size < 5)
        return std::unexpected(Error::INVALID_INPUT);

    // Verify start code
    if (buf[0] != 0x00 || buf[1] != 0x00 || buf[2] != 0x00 || buf[3] != 0x01)
        return std::unexpected(Error::INVALID_INPUT);

    // Read NAL header
    uint8_t nal_header = buf[4];
    int nal_ref_idc = (nal_header >> 5) & 0x3;
    int nal_unit_type = nal_header & 0x1F;
    int is_idr = (nal_unit_type == 5);

    // Remove emulation prevention bytes using member buffer
    rbsp_buf_.resize(buf_size);
    size_t rbsp_size = remove_emulation_prevention(buf + 5, buf_size - 5,
                                                    rbsp_buf_.data(), rbsp_buf_.size());

    bs_t b;
    bs_init(&b, rbsp_buf_.data(), rbsp_size);

    // Slice header
    bs_read_ue(&b);                    // first_mb_in_slice
    uint32_t slice_type = bs_read_ue(&b);  // slice_type
    bs_read_ue(&b);                    // pic_parameter_set_id
    int frame_num_bits = (params.log2_max_frame_num > 0) ? params.log2_max_frame_num : 4;
    bs_read_u(&b, frame_num_bits);     // frame_num

    int is_p_slice = (slice_type == 0 || slice_type == 5);
    int is_i_slice = (slice_type == 2 || slice_type == 7);

    if (is_idr) {
        bs_read_ue(&b);  // idr_pic_id
    }

    // pic_order_cnt parsing (depends on SPS pic_order_cnt_type)
    if (params.log2_max_frame_num > 0) {
        int poc_type = params.pic_order_cnt_type;
        if (poc_type == 0) {
            int poc_lsb_bits = (params.log2_max_pic_order_cnt_lsb > 0)
                               ? params.log2_max_pic_order_cnt_lsb : 4;
            bs_read_u(&b, poc_lsb_bits);  // pic_order_cnt_lsb
        } else if (poc_type == 1) {
            bs_read_se(&b);  // delta_pic_order_cnt[0]
        }
        // poc_type == 2: nothing in slice header
    }

    // P-slice header extras
    if (is_p_slice) {
        if (bs_read_u1(&b)) {  // num_ref_idx_active_override_flag
            bs_read_ue(&b);    // num_ref_idx_l0_active_minus1
        }
        if (bs_read_u1(&b)) {  // ref_pic_list_modification_flag_l0
            uint32_t mod_op;
            do {
                mod_op = bs_read_ue(&b);
                if (mod_op != 3) {
                    bs_read_ue(&b);
                }
            } while (mod_op != 3);
        }
    }

    // dec_ref_pic_marking
    if (nal_ref_idc > 0) {
        if (is_idr) {
            bs_read_u1(&b);  // no_output_of_prior_pics_flag
            bs_read_u1(&b);  // long_term_reference_flag
        } else {
            bs_read_u1(&b);  // adaptive_ref_pic_marking_mode_flag
        }
    }

    int32_t slice_qp_delta = bs_read_se(&b);   // slice_qp_delta
    if (out_slice_qp_delta) *out_slice_qp_delta = (int)slice_qp_delta;
    uint32_t disable_deblocking = bs_read_ue(&b);   // disable_deblocking_filter_idc
    if (disable_deblocking != 1) {
        bs_read_se(&b);  // slice_alpha_c0_offset_div2
        bs_read_se(&b);  // slice_beta_offset_div2
    }

    // Parse macroblocks
    int num_mbs = params.width_mbs * params.height_mbs;
    std::vector<MacroblockData> out_mbs(static_cast<size_t>(num_mbs));

    ctx_row_.assign(static_cast<size_t>(params.width_mbs), MbContext{});
    MbContext ctx_left = {};

    int mb_idx = 0;
    bool error = false;

    if (is_p_slice) {
        while (mb_idx < num_mbs) {
            // Read mb_skip_run (always, per H.264 spec syntax)
            uint32_t skip_run = bs_read_ue(&b);

            for (uint32_t i = 0; i < skip_run && mb_idx < num_mbs; i++) {
                int mb_x = mb_idx % params.width_mbs;
                out_mbs[mb_idx].mb_type = MbType::SKIP;
                MbContext skip_ctx = {};
                ctx_left = skip_ctx;
                ctx_row_[mb_x] = skip_ctx;
                mb_idx++;
            }

            if (skip_run > 0 && !more_rbsp_data(&b)) {
                // Fill remaining MBs as skip
                while (mb_idx < num_mbs) {
                    int mb_x2 = mb_idx % params.width_mbs;
                    out_mbs[mb_idx].mb_type = MbType::SKIP;
                    MbContext skip_ctx2 = {};
                    ctx_left = skip_ctx2;
                    ctx_row_[mb_x2] = skip_ctx2;
                    mb_idx++;
                }
                break;
            }

            if (mb_idx >= num_mbs) break;

            int mb_x = mb_idx % params.width_mbs;
            int mb_y = mb_idx / params.width_mbs;
            MbContext* above = (mb_y > 0) ? &ctx_row_[mb_x] : NULL;
            MbContext* left_ctx = (mb_x > 0) ? &ctx_left : NULL;
            MbContext* above_right = (mb_y > 0 && mb_x < params.width_mbs - 1)
                                        ? &ctx_row_[mb_x + 1] : NULL;

            uint32_t mb_type_code = bs_read_ue(&b);
            MbContext out_ctx = {};

            if (mb_type_code == 0) {
                read_mb_p16x16(&b, &out_mbs[mb_idx], left_ctx, above, above_right, &out_ctx);
            } else if (mb_type_code >= 1 && mb_type_code <= 2) {
                // P_L0_L0_16x8 or P_L0_L0_8x16 - approximate as P_16x16
                out_mbs[mb_idx].mb_type = MbType::P_16x16;
                // 2 partitions, each with MVD
                int16_t mvp[2];
                subcodec::frame_writer::predict_mv(left_ctx, above, above_right, mvp);
                int32_t mvd_x = bs_read_se(&b);
                int32_t mvd_y = bs_read_se(&b);
                out_mbs[mb_idx].mv_x = (int16_t)(mvp[0] + mvd_x);
                out_mbs[mb_idx].mv_y = (int16_t)(mvp[1] + mvd_y);
                // Second partition MVD
                bs_read_se(&b);  // mvd_x
                bs_read_se(&b);  // mvd_y

                // CBP + residual (same as P_16x16)
                uint32_t cbp_code = bs_read_ue(&b);
                out_ctx = MbContext{};
                if (decode_cbp_inter(cbp_code, &out_mbs[mb_idx].cbp_luma, &out_mbs[mb_idx].cbp_chroma) == 0 &&
                    (out_mbs[mb_idx].cbp_luma != 0 || out_mbs[mb_idx].cbp_chroma != 0)) {
                    bs_read_se(&b); // qp_delta
                    for (int i = 0; i < 16; i++) {
                        int blk_idx = luma_block_order[i];
                        int parent_8x8 = block_to_8x8[blk_idx];
                        if (!(out_mbs[mb_idx].cbp_luma & (1 << parent_8x8))) {
                            out_ctx.nc[blk_idx] = 0; continue;
                        }
                        int nc = calc_block_nc(blk_idx, &out_ctx, left_ctx, above);
                        int16_t coeffs[16];
                        out_ctx.nc[blk_idx] = subcodec::cavlc::read_block(&b, coeffs, nc, 16);
                    }
                    if (out_mbs[mb_idx].cbp_chroma >= 1) {
                        int16_t dummy4[4];
                        subcodec::cavlc::read_block(&b, dummy4, -1, 4);
                        subcodec::cavlc::read_block(&b, dummy4, -1, 4);
                    }
                    if (out_mbs[mb_idx].cbp_chroma == 2) {
                        for (int i = 0; i < 8; i++) {
                            int16_t dummy15[15];
                            subcodec::cavlc::read_block(&b, dummy15, 0, 15);
                        }
                    }
                }
                out_ctx.mv[0] = out_mbs[mb_idx].mv_x;
                out_ctx.mv[1] = out_mbs[mb_idx].mv_y;
            } else if (mb_type_code == 3) {
                read_mb_p8x8(&b, &out_mbs[mb_idx], 0, left_ctx, above, above_right, &out_ctx);
            } else if (mb_type_code == 4) {
                read_mb_p8x8(&b, &out_mbs[mb_idx], 1, left_ctx, above, above_right, &out_ctx);
            } else if (mb_type_code >= 6 && mb_type_code <= 29) {
                int offset = (int)mb_type_code - 6;
                read_mb_i16x16(&b, &out_mbs[mb_idx], offset, left_ctx, above, &out_ctx);
            } else {
                fprintf(stderr, "h264_parse: P-slice bad mb_type=%u at mb_idx=%d/%d\n",
                        mb_type_code, mb_idx, num_mbs);
                error = true;
                break;
            }

            ctx_left = out_ctx;
            ctx_row_[mb_x] = out_ctx;
            mb_idx++;

            if (!more_rbsp_data(&b)) {
                // Remaining MBs are skip (end of slice data)
                while (mb_idx < num_mbs) {
                    int mb_x2 = mb_idx % params.width_mbs;
                    out_mbs[mb_idx].mb_type = MbType::SKIP;
                    MbContext skip_ctx2 = {};
                    ctx_left = skip_ctx2;
                    ctx_row_[mb_x2] = skip_ctx2;
                    mb_idx++;
                }
                break;
            }
        }
    } else if (is_i_slice) {
        for (mb_idx = 0; mb_idx < num_mbs; mb_idx++) {
            int mb_x = mb_idx % params.width_mbs;
            int mb_y = mb_idx / params.width_mbs;
            MbContext* above = (mb_y > 0) ? &ctx_row_[mb_x] : NULL;
            MbContext* left_ctx = (mb_x > 0) ? &ctx_left : NULL;

            if (bs_eof(&b)) {
                error = true;
                break;
            }

            uint32_t mb_type_code = bs_read_ue(&b);
            MbContext out_ctx = {};

            if (mb_type_code >= 1 && mb_type_code <= 24) {
                int offset = (int)mb_type_code - 1;
                read_mb_i16x16(&b, &out_mbs[mb_idx], offset, left_ctx, above, &out_ctx);
            } else {
                fprintf(stderr, "h264_parse: I-slice bad mb_type=%u at mb_idx=%d/%d\n",
                        mb_type_code, mb_idx, num_mbs);
                error = true;
                break;
            }

            ctx_left = out_ctx;
            ctx_row_[mb_x] = out_ctx;
        }
    } else {
        error = true;
    }

    if (error) {
        return std::unexpected(Error::PARSE_ERROR);
    }

    return out_mbs;
}

} // namespace subcodec
