#include "frame_writer.h"
#include "types.h"
#include "cavlc.h"
#include "h264_stream.h"
#include "bs.h"
#include "tables.h"
#include <cstring>
#include <vector>

namespace subcodec::frame_writer {

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
static int calc_nc(int blk_idx, const MbContext* out_ctx,
                   const MbContext* left, const MbContext* above) {
    int nc_left = -1, nc_above = -1;
    int x4 = blk_to_x4(blk_idx);
    int y4 = blk_to_y4(blk_idx);

    if (x4 > 0) {
        nc_left = out_ctx->nc[xy4_to_blk(x4 - 1, y4)];
    } else if (left) {
        nc_left = left->nc[xy4_to_blk(3, y4)];
    }

    if (y4 > 0) {
        nc_above = out_ctx->nc[xy4_to_blk(x4, y4 - 1)];
    } else if (above) {
        nc_above = above->nc[xy4_to_blk(x4, 3)];
    }

    return subcodec::cavlc::calc_nc(nc_left, nc_above);
}

// Calculate nC for a chroma 2x2 block using neighbor context
// Chroma 2x2 layout: [0 1 / 2 3] — same as h264_parse.c calc_chroma_nc
static int calc_chroma_nc(int blk_idx, const int* chroma_nc,
                          const int* left_nc, const int* above_nc) {
    int cx = blk_idx % 2, cy = blk_idx / 2;
    int nc_left = -1, nc_above = -1;

    if (cx > 0) nc_left = chroma_nc[blk_idx - 1];
    else if (left_nc) nc_left = left_nc[cy * 2 + 1];

    if (cy > 0) nc_above = chroma_nc[blk_idx - 2];
    else if (above_nc) nc_above = above_nc[cx + 2];

    return subcodec::cavlc::calc_nc(nc_left, nc_above);
}

// Table 9-4(b): Coded block pattern mapping for Inter prediction
using subcodec::tables::cbp_to_code_inter;
using subcodec::tables::luma_block_order;
using subcodec::tables::block_to_8x8;

// Write a NAL unit with start code to buffer
// Returns bytes written
static size_t write_nal_with_start_code(uint8_t* buf, size_t buf_size,
                                        h264_stream_t* h) {
    if (buf_size < 5) return 0;

    // Start code
    buf[0] = 0x00;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x01;

    // Write NAL unit to a temp buffer
    // h264bitstream's write_nal_unit has a quirk: it prepends an extra 0x00 byte
    // So we write to buf+3, then the actual NAL starts at buf+4
    uint8_t temp[1024];
    int nal_size = write_nal_unit(h, temp, (int)sizeof(temp));
    if (nal_size < 1) return 0;

    // Skip the spurious leading 0x00 byte from write_nal_unit
    // Copy the rest starting at position 1
    if ((size_t)(nal_size - 1) > buf_size - 4) return 0;
    memcpy(buf + 4, temp + 1, (size_t)(nal_size - 1));

    return 4 + (size_t)(nal_size - 1);
}

size_t write_headers(std::span<uint8_t> output, const FrameParams& params) {
    h264_stream_t* h = h264_new();
    if (!h) return 0;

    uint8_t* buf = output.data();
    size_t buf_size = output.size();
    size_t offset = 0;

    // SPS
    h->nal->nal_ref_idc = 3;
    h->nal->nal_unit_type = NAL_UNIT_TYPE_SPS;

    sps_t* sps = h->sps;

    /* Pick the lowest level that supports this frame size (MB count).
     * Baseline Profile supports up to Level 5.2 (36,864 MBs).
     * High Profile is needed for Level 6.0+ (up to 139,264 MBs). */
    int total_mbs = params.width_mbs * params.height_mbs;
    bool need_high = (total_mbs > 36864);

    sps->profile_idc = need_high ? 100 : 66;  // High or Baseline
    sps->constraint_set0_flag = need_high ? 0 : 1;
    sps->constraint_set1_flag = need_high ? 0 : 1;
    sps->constraint_set2_flag = 0;
    sps->constraint_set3_flag = 0;
    sps->constraint_set4_flag = 0;
    sps->constraint_set5_flag = 0;

    if (need_high) {
        /* High Profile SPS extensions — all at simplest/default values.
         * We still use CAVLC, no 8x8 transform, no scaling matrices. */
        sps->chroma_format_idc = 1;  // 4:2:0
        sps->bit_depth_luma_minus8 = 0;
        sps->bit_depth_chroma_minus8 = 0;
        sps->qpprime_y_zero_transform_bypass_flag = 0;
        sps->seq_scaling_matrix_present_flag = 0;
    }

    int level;
    if      (total_mbs <=   1620) level = 30;  // Level 3.0
    else if (total_mbs <=   3600) level = 31;  // Level 3.1
    else if (total_mbs <=   5120) level = 32;  // Level 3.2
    else if (total_mbs <=   8192) level = 40;  // Level 4.0
    else if (total_mbs <=   8704) level = 42;  // Level 4.2
    else if (total_mbs <=  22080) level = 50;  // Level 5.0
    else if (total_mbs <=  36864) level = 51;  // Level 5.1
    else                          level = 60;  // Level 6.0 (139,264 MBs)
    sps->level_idc = level;
    sps->seq_parameter_set_id = 0;
    int log2mfn = (params.log2_max_frame_num > 4) ? params.log2_max_frame_num : 4;
    sps->log2_max_frame_num_minus4 = log2mfn - 4;
    sps->pic_order_cnt_type = 2;  // No POC, infer from frame_num
    sps->num_ref_frames = 1;
    sps->gaps_in_frame_num_value_allowed_flag = 0;
    sps->pic_width_in_mbs_minus1 = params.width_mbs - 1;
    sps->pic_height_in_map_units_minus1 = params.height_mbs - 1;
    sps->frame_mbs_only_flag = 1;
    sps->direct_8x8_inference_flag = 1;
    sps->frame_cropping_flag = 0;
    sps->vui_parameters_present_flag = 0;

    size_t sps_size = write_nal_with_start_code(buf + offset, buf_size - offset, h);
    if (sps_size == 0) { h264_free(h); return 0; }
    offset += sps_size;

    // PPS
    h->nal->nal_ref_idc = 3;
    h->nal->nal_unit_type = NAL_UNIT_TYPE_PPS;

    pps_t* pps = h->pps;
    pps->pic_parameter_set_id = 0;
    pps->seq_parameter_set_id = 0;
    pps->entropy_coding_mode_flag = 0;  // CAVLC
    pps->pic_order_present_flag = 0;
    pps->num_slice_groups_minus1 = 0;
    pps->num_ref_idx_l0_active_minus1 = 0;
    pps->num_ref_idx_l1_active_minus1 = 0;
    pps->weighted_pred_flag = 0;
    pps->weighted_bipred_idc = 0;
    int qp = (params.qp > 0) ? params.qp : 26;
    pps->pic_init_qp_minus26 = qp - 26;
    pps->pic_init_qs_minus26 = 0;
    pps->chroma_qp_index_offset = 0;
    pps->deblocking_filter_control_present_flag = 1;
    pps->constrained_intra_pred_flag = 0;
    pps->redundant_pic_cnt_present_flag = 0;

    size_t pps_size = write_nal_with_start_code(buf + offset, buf_size - offset, h);
    if (pps_size == 0) { h264_free(h); return 0; }
    offset += pps_size;

    h264_free(h);
    return offset;
}

// Return median of three int16_t values
int16_t median3(int16_t a, int16_t b, int16_t c) {
    if ((a <= b && b <= c) || (c <= b && b <= a)) return b;
    if ((b <= a && a <= c) || (c <= a && a <= b)) return a;
    return c;
}

// Predict motion vector using median of neighbors
// Unavailable neighbors are treated as (0, 0)
void predict_mv(const MbContext* left, const MbContext* above,
                const MbContext* above_right, int16_t* mvp) {
    int16_t mv_a[2] = {0, 0};  // left
    int16_t mv_b[2] = {0, 0};  // above
    int16_t mv_c[2] = {0, 0};  // above-right

    if (left) {
        mv_a[0] = left->mv[0];
        mv_a[1] = left->mv[1];
    }
    if (above) {
        mv_b[0] = above->mv[0];
        mv_b[1] = above->mv[1];
    }
    if (above_right) {
        mv_c[0] = above_right->mv[0];
        mv_c[1] = above_right->mv[1];
    }

    mvp[0] = median3(mv_a[0], mv_b[0], mv_c[0]);
    mvp[1] = median3(mv_a[1], mv_b[1], mv_c[1]);
}

// Write P_16x16 macroblock to bitstream
void write_mb_p16x16(bs_t* b, const MacroblockData& mb,
                     const MbContext* left, const MbContext* above,
                     const MbContext* above_right,
                     MbContext& out_ctx) {
    // 1. mb_type = 0 for P_L0_16x16 in P-slice (ref_idx_l0=0 implied for single ref)
    bs_write_ue(b, 0);

    // 2. Motion vector delta (predicted MV subtracted)
    int16_t mvp[2];
    predict_mv(left, above, above_right, mvp);
    bs_write_se(b, mb.mv_x - mvp[0]);
    bs_write_se(b, mb.mv_y - mvp[1]);

    // 3. coded_block_pattern (always written per H.264 spec for P_L0_16x16)
    int cbp = (mb.cbp_chroma << 4) | mb.cbp_luma;

    // Write CBP using mapped exp-golomb code (Table 9-4(b))
    bs_write_ue(b, cbp_to_code_inter[cbp]);

    if (cbp != 0) {
        // mb_qp_delta = 0 (no QP change)
        bs_write_se(b, 0);

        // 4. Write residual with CAVLC
        // For P_16x16, residual structure is:
        //   - 16 luma 4x4 blocks (in raster scan of 8x8 blocks, then 4x4 within)
        //   - Chroma DC Cb, Chroma DC Cr (if cbp_chroma >= 1)
        //   - 4 Chroma AC Cb blocks, 4 Chroma AC Cr blocks (if cbp_chroma == 2)

        // Initialize nC tracking for output context
        for (int i = 0; i < 16; i++) {
            out_ctx.nc[i] = 0;
        }

        // Luma residual: 4 8x8 blocks, each containing 4 4x4 blocks
        for (int i = 0; i < 16; i++) {
            int blk_idx = luma_block_order[i];
            int parent_8x8 = block_to_8x8[blk_idx];

            // Check if this 8x8 block has coefficients
            if (!(mb.cbp_luma & (1 << parent_8x8))) {
                out_ctx.nc[blk_idx] = 0;
                continue;
            }

            int nc = calc_nc(blk_idx, &out_ctx, left, above);

            // Write the 4x4 block coefficients
            int16_t coeffs[16];
            coeffs[0] = mb.luma_dc[blk_idx];  // Use luma_dc for the DC coefficient
            for (int j = 0; j < 15; j++) {
                coeffs[j + 1] = mb.luma_ac[blk_idx][j];
            }

            int tc = subcodec::cavlc::write_block(b, coeffs, nc, 16);
            out_ctx.nc[blk_idx] = tc;
        }

        // Chroma DC (if cbp_chroma >= 1)
        if (mb.cbp_chroma >= 1) {
            // Cb DC (4 coefficients for 4:2:0)
            subcodec::cavlc::write_block(b, mb.cb_dc, -1, 4);
            // Cr DC (4 coefficients for 4:2:0)
            subcodec::cavlc::write_block(b, mb.cr_dc, -1, 4);
        }

        // Chroma AC (if cbp_chroma == 2)
        if (mb.cbp_chroma == 2) {
            for (int i = 0; i < 4; i++) {
                int nc = calc_chroma_nc(i, out_ctx.nc_cb,
                                        left ? left->nc_cb : NULL,
                                        above ? above->nc_cb : NULL);
                out_ctx.nc_cb[i] = subcodec::cavlc::write_block(b, mb.cb_ac[i], nc, 15);
            }
            for (int i = 0; i < 4; i++) {
                int nc = calc_chroma_nc(i, out_ctx.nc_cr,
                                        left ? left->nc_cr : NULL,
                                        above ? above->nc_cr : NULL);
                out_ctx.nc_cr[i] = subcodec::cavlc::write_block(b, mb.cr_ac[i], nc, 15);
            }
        }
    } else {
        // No residual - just initialize context
        for (int i = 0; i < 16; i++) {
            out_ctx.nc[i] = 0;
        }
    }

    // 5. Update output context with this macroblock's MV
    out_ctx.mv[0] = mb.mv_x;
    out_ctx.mv[1] = mb.mv_y;
}

// Compute I_16x16 mb_type in P-slice
// I_16x16 mb_type in P-slice: 6 + mode + 4*cbp_chroma + 12*cbp_dc
// mode: 0=Vertical, 1=Horizontal, 2=DC, 3=Plane
// cbp_chroma: 0, 1, or 2
// ac_has_nonzero: 0 or 1 (whether any of the 16 AC blocks have non-zero coeffs)
static int i16x16_mb_type_p_slice(int pred_mode, int cbp_chroma, int ac_has_nonzero) {
    return 6 + pred_mode + 4 * cbp_chroma + 12 * ac_has_nonzero;
}

// Write I_16x16 macroblock to bitstream
void write_mb_i16x16(bs_t* b, const MacroblockData& mb,
                     const MbContext* left, const MbContext* above,
                     MbContext& out_ctx) {
    // 1. Determine if any AC block has non-zero coefficients
    int ac_has_nonzero = 0;
    for (int i = 0; i < 16; i++) {
        for (int j = 0; j < 15; j++) {
            if (mb.luma_ac[i][j] != 0) {
                ac_has_nonzero = 1;
                break;
            }
        }
        if (ac_has_nonzero) break;
    }

    // 2. Write mb_type (I_16x16 in P-slice)
    int mb_type = i16x16_mb_type_p_slice(static_cast<int>(mb.intra_pred_mode), mb.cbp_chroma, ac_has_nonzero);
    bs_write_ue(b, (uint32_t)mb_type);

    // 3. Write intra_chroma_pred_mode
    bs_write_ue(b, static_cast<uint32_t>(mb.intra_chroma_mode));

    // 4. Write mb_qp_delta = 0
    bs_write_se(b, 0);

    // 5. Write Luma DC block (nC from block 0 neighbors, max_num_coeff = 16)
    {
        int dc_nc = calc_nc(0, &out_ctx, left, above);
        subcodec::cavlc::write_block(b, mb.luma_dc, dc_nc, 16);
    }

    // Initialize nC tracking for output context
    for (int i = 0; i < 16; i++) {
        out_ctx.nc[i] = 0;
    }

    // 6. Write 16 Luma AC blocks (max_num_coeff = 15, DC is separate)
    if (ac_has_nonzero) {
        for (int i = 0; i < 16; i++) {
            int blk_idx = luma_block_order[i];
            int nc = calc_nc(blk_idx, &out_ctx, left, above);
            // Write the AC block (15 coefficients, no DC)
            out_ctx.nc[blk_idx] = subcodec::cavlc::write_block(b, mb.luma_ac[blk_idx], nc, 15);
        }
    }

    // 7. Write chroma DC blocks (nC = -1 for chroma DC, max_num_coeff = 4)
    // Cb DC then Cr DC
    if (mb.cbp_chroma > 0) {
        subcodec::cavlc::write_block(b, mb.cb_dc, -1, 4);
        subcodec::cavlc::write_block(b, mb.cr_dc, -1, 4);
    }

    // 8. Write chroma AC blocks if cbp_chroma == 2
    if (mb.cbp_chroma == 2) {
        for (int i = 0; i < 4; i++) {
            int nc = calc_chroma_nc(i, out_ctx.nc_cb,
                                    left ? left->nc_cb : NULL,
                                    above ? above->nc_cb : NULL);
            out_ctx.nc_cb[i] = subcodec::cavlc::write_block(b, mb.cb_ac[i], nc, 15);
        }
        for (int i = 0; i < 4; i++) {
            int nc = calc_chroma_nc(i, out_ctx.nc_cr,
                                    left ? left->nc_cr : NULL,
                                    above ? above->nc_cr : NULL);
            out_ctx.nc_cr[i] = subcodec::cavlc::write_block(b, mb.cr_ac[i], nc, 15);
        }
    }

    // 9. Update context - I-macroblock has no motion vector
    out_ctx.mv[0] = 0;
    out_ctx.mv[1] = 0;
}

std::expected<size_t, Error> write_p_frame_ex(
    std::span<uint8_t> output,
    const FrameParams& params,
    const MacroblockData* mbs,
    int frame_num) {

    uint8_t* buf = output.data();
    size_t buf_size = output.size();

    if (buf_size < 8) return std::unexpected(Error::OUT_OF_SPACE);

    // NAL header
    buf[0] = 0x00;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x01;
    buf[4] = (2 << 5) | 1;  // nal_ref_idc=2, nal_unit_type=1 (non-IDR slice)

    uint8_t rbsp[256 * 1024];
    bs_t b;
    bs_init(&b, rbsp, sizeof(rbsp));

    // Slice header (same as write_p_frame)
    bs_write_ue(&b, 0);  // first_mb_in_slice = 0
    bs_write_ue(&b, 5);  // slice_type = 5 (P, all macroblocks)
    bs_write_ue(&b, 0);  // pic_parameter_set_id = 0
    {
        int l2mfn = (params.log2_max_frame_num > 4) ? params.log2_max_frame_num : 4;
        int max_fn = 1 << l2mfn;
        bs_write_u(&b, l2mfn, frame_num % max_fn);
    }

    // num_ref_idx_active_override_flag
    bs_write_u(&b, 1, 0);

    // ref_pic_list_modification - no modifications
    bs_write_u(&b, 1, 0);  // ref_pic_list_modification_flag_l0

    // dec_ref_pic_marking - adaptive_ref_pic_marking_mode_flag
    bs_write_u(&b, 1, 0);

    // slice_qp_delta
    bs_write_se(&b, params.slice_qp_delta);

    // deblocking_filter_control_present_flag = 1, so:
    bs_write_ue(&b, 1);  // disable_deblocking_filter_idc = 1 (disabled)

    // Allocate context for neighbor tracking
    int num_mbs = params.width_mbs * params.height_mbs;
    std::vector<MbContext> ctx_row_vec(params.width_mbs);
    MbContext* ctx_row = ctx_row_vec.data();
    MbContext ctx_left = {};

    int mb_idx = 0;
    int prev_was_skip = 0;  // Track if previous iteration was a skip run
    while (mb_idx < num_mbs) {
        const MacroblockData& mb = mbs[mb_idx];
        int mb_x = mb_idx % params.width_mbs;
        int mb_y = mb_idx / params.width_mbs;

        // Get neighbor contexts
        MbContext* above = (mb_y > 0) ? &ctx_row[mb_x] : NULL;
        MbContext* left_ctx = (mb_x > 0) ? &ctx_left : NULL;
        MbContext* above_right = (mb_y > 0 && mb_x < params.width_mbs - 1)
                                    ? &ctx_row[mb_x + 1] : NULL;

        // Handle skip run
        if (mb.mb_type == MbType::SKIP) {
            int skip_count = 1;
            while (mb_idx + skip_count < num_mbs &&
                   mbs[mb_idx + skip_count].mb_type == MbType::SKIP) {
                skip_count++;
            }
            bs_write_ue(&b, (uint32_t)skip_count);

            // Update context for skipped MBs (MV=0, nC=0)
            for (int i = 0; i < skip_count; i++) {
                int idx = mb_idx + i;
                int x = idx % params.width_mbs;
                MbContext skip_ctx = {};
                ctx_left = skip_ctx;
                ctx_row[x] = skip_ctx;
            }
            mb_idx += skip_count;
            prev_was_skip = 1;
            continue;
        }

        // Non-skip: write mb_skip_run = 0 only if we didn't just write a skip run
        if (!prev_was_skip) {
            bs_write_ue(&b, 0);
        }
        prev_was_skip = 0;

        // Write macroblock based on type
        MbContext out_ctx = {};
        switch (mb.mb_type) {
            case MbType::P_16x16:
                write_mb_p16x16(&b, mb, left_ctx, above, above_right, out_ctx);
                break;
            case MbType::I_16x16:
                write_mb_i16x16(&b, mb, left_ctx, above, out_ctx);
                break;
            default:
                // Unknown type, treat as skip (should not happen)
                out_ctx = MbContext{};
                break;
        }

        // Update context
        ctx_left = out_ctx;
        ctx_row[mb_x] = out_ctx;
        mb_idx++;
    }

    // RBSP trailing bits
    write_rbsp_trailing_bits(&b);

    size_t rbsp_size = (size_t)bs_pos(&b);

    // Copy RBSP to output with emulation prevention
    size_t out_pos = 5;
    int zero_count = 0;
    for (size_t i = 0; i < rbsp_size && out_pos < buf_size; i++) {
        uint8_t byte = rbsp[i];
        if (zero_count >= 2 && byte <= 3) {
            if (out_pos >= buf_size) {
                return std::unexpected(Error::OUT_OF_SPACE);
            }
            buf[out_pos++] = 0x03;
            zero_count = 0;
        }
        if (out_pos >= buf_size) {
            return std::unexpected(Error::OUT_OF_SPACE);
        }
        buf[out_pos++] = byte;
        zero_count = (byte == 0) ? zero_count + 1 : 0;
    }

    return out_pos;
}

// Compute I_16x16 mb_type in I-slice
// I_16x16 mb_type in I-slice: 1 + pred_mode + 4*cbp_chroma + 12*ac_has_nonzero
// (offset is 1, not 6 as in P-slice)
static int i16x16_mb_type_i_slice(int pred_mode, int cbp_chroma, int ac_has_nonzero) {
    return 1 + pred_mode + 4 * cbp_chroma + 12 * ac_has_nonzero;
}

std::expected<size_t, Error> write_idr_frame_ex(
    std::span<uint8_t> output,
    const FrameParams& params,
    const MacroblockData* mbs) {

    uint8_t* buf = output.data();
    size_t buf_size = output.size();

    if (buf_size < 8) return std::unexpected(Error::OUT_OF_SPACE);

    // NAL header: nal_ref_idc=3, nal_unit_type=5 (IDR slice)
    buf[0] = 0x00;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x01;
    buf[4] = (3 << 5) | 5;

    uint8_t rbsp[256 * 1024];
    bs_t b;
    bs_init(&b, rbsp, sizeof(rbsp));

    // Slice header for IDR I-slice
    bs_write_ue(&b, 0);       // first_mb_in_slice = 0
    bs_write_ue(&b, 7);       // slice_type = 7 (I, all macroblocks)
    bs_write_ue(&b, 0);       // pic_parameter_set_id = 0
    {
        int l2mfn = (params.log2_max_frame_num > 4) ? params.log2_max_frame_num : 4;
        bs_write_u(&b, l2mfn, 0);  // frame_num = 0
    }
    bs_write_ue(&b, 0);       // idr_pic_id = 0

    // dec_ref_pic_marking for IDR with nal_ref_idc > 0
    bs_write_u(&b, 1, 0);    // no_output_of_prior_pics_flag = 0
    bs_write_u(&b, 1, 0);    // long_term_reference_flag = 0

    bs_write_se(&b, params.slice_qp_delta);  // slice_qp_delta

    // deblocking_filter_control_present_flag = 1, so:
    bs_write_ue(&b, 1);       // disable_deblocking_filter_idc = 1 (disabled)

    // Allocate context for neighbor tracking
    int num_mbs = params.width_mbs * params.height_mbs;
    std::vector<MbContext> ctx_row_vec(params.width_mbs);
    MbContext* ctx_row = ctx_row_vec.data();
    MbContext ctx_left = {};

    for (int mb_idx = 0; mb_idx < num_mbs; mb_idx++) {
        const MacroblockData& mb = mbs[mb_idx];
        int mb_x = mb_idx % params.width_mbs;
        int mb_y = mb_idx / params.width_mbs;

        // Get neighbor contexts
        MbContext* above = (mb_y > 0) ? &ctx_row[mb_x] : NULL;
        MbContext* left_ctx = (mb_x > 0) ? &ctx_left : NULL;

        MbContext out_ctx = {};

        switch (mb.mb_type) {
            case MbType::I_16x16: {
                // Determine if any AC block has non-zero coefficients
                int ac_has_nonzero = 0;
                for (int i = 0; i < 16; i++) {
                    for (int j = 0; j < 15; j++) {
                        if (mb.luma_ac[i][j] != 0) {
                            ac_has_nonzero = 1;
                            break;
                        }
                    }
                    if (ac_has_nonzero) break;
                }

                // Write mb_type (I_16x16 in I-slice, offset 1)
                int mbt = i16x16_mb_type_i_slice(static_cast<int>(mb.intra_pred_mode), mb.cbp_chroma, ac_has_nonzero);
                bs_write_ue(&b, (uint32_t)mbt);

                // Write intra_chroma_pred_mode
                bs_write_ue(&b, static_cast<uint32_t>(mb.intra_chroma_mode));

                // Write mb_qp_delta = 0
                bs_write_se(&b, 0);

                // Write Luma DC block (nC from block 0 neighbors, max_num_coeff = 16)
                {
                    int dc_nc = calc_nc(0, &out_ctx, left_ctx, above);
                    subcodec::cavlc::write_block(&b, mb.luma_dc, dc_nc, 16);
                }

                // Initialize nC tracking
                for (int i = 0; i < 16; i++) {
                    out_ctx.nc[i] = 0;
                }

                // Write 16 Luma AC blocks if ac_has_nonzero
                if (ac_has_nonzero) {
                    for (int i = 0; i < 16; i++) {
                        int blk_idx = luma_block_order[i];
                        int nc = calc_nc(blk_idx, &out_ctx, left_ctx, above);
                        out_ctx.nc[blk_idx] = subcodec::cavlc::write_block(&b, mb.luma_ac[blk_idx], nc, 15);
                    }
                }

                // Write chroma DC blocks
                if (mb.cbp_chroma > 0) {
                    subcodec::cavlc::write_block(&b, mb.cb_dc, -1, 4);
                    subcodec::cavlc::write_block(&b, mb.cr_dc, -1, 4);
                }

                // Write chroma AC blocks if cbp_chroma == 2
                if (mb.cbp_chroma == 2) {
                    for (int i = 0; i < 4; i++) {
                        subcodec::cavlc::write_block(&b, mb.cb_ac[i], 0, 15);
                    }
                    for (int i = 0; i < 4; i++) {
                        subcodec::cavlc::write_block(&b, mb.cr_ac[i], 0, 15);
                    }
                }

                // I-macroblock has no motion vector
                out_ctx.mv[0] = 0;
                out_ctx.mv[1] = 0;
                break;
            }

            default:
                // Unknown type - treat as empty (should not happen in IDR)
                out_ctx = MbContext{};
                break;
        }

        // Update context
        ctx_left = out_ctx;
        ctx_row[mb_x] = out_ctx;
    }

    // RBSP trailing bits
    write_rbsp_trailing_bits(&b);

    size_t rbsp_size = (size_t)bs_pos(&b);

    // Copy RBSP to output with emulation prevention
    size_t out_pos = 5;
    int zero_count = 0;
    for (size_t i = 0; i < rbsp_size && out_pos < buf_size; i++) {
        uint8_t byte = rbsp[i];
        if (zero_count >= 2 && byte <= 3) {
            if (out_pos >= buf_size) {
                return std::unexpected(Error::OUT_OF_SPACE);
            }
            buf[out_pos++] = 0x03;
            zero_count = 0;
        }
        if (out_pos >= buf_size) {
            return std::unexpected(Error::OUT_OF_SPACE);
        }
        buf[out_pos++] = byte;
        zero_count = (byte == 0) ? zero_count + 1 : 0;
    }

    return out_pos;
}

} // namespace subcodec::frame_writer
