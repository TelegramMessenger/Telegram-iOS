#include "mbs_mux_common.h"
#include "tables.h"
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <algorithm>
#include <vector>
#include <arm_neon.h>

namespace subcodec::mux {

/* ---- Coeff_token LUT ---- */

struct CtEntry {
    uint32_t code;
    int len;
};

static constexpr int CT_NR = 4;
static constexpr int CT_TC = 17;
static constexpr int CT_T1 = 4;

static CtEntry ct_lut[CT_NR][CT_TC][CT_T1];
static int ct_lut_built = 0;

void build_ct_lut() {
    if (ct_lut_built) return;

    int nc_for_range[CT_NR] = {0, 2, 4, 8};

    for (int nr = 0; nr < CT_NR; nr++) {
        int nc = nc_for_range[nr];
        for (int tc = 0; tc <= 16; tc++) {
            for (int t1 = 0; t1 <= 3; t1++) {
                if (t1 > tc || (tc == 0 && t1 != 0)) {
                    ct_lut[nr][tc][t1].code = 0;
                    ct_lut[nr][tc][t1].len = 0;
                    continue;
                }

                uint8_t tmp[8];
                memset(tmp, 0, sizeof(tmp));
                bs_t b;
                bs_init(&b, tmp, sizeof(tmp));

                subcodec::cavlc::write_coeff_token(&b, tc, t1, nc);

                int bits = (int)(b.p - b.start) * 8 + (8 - b.bits_left);
                uint32_t code = 0;
                for (int i = 0; i < bits; i++) {
                    int byte_idx = i / 8;
                    int bit_idx = 7 - (i % 8);
                    code = (code << 1) | ((tmp[byte_idx] >> bit_idx) & 1);
                }

                ct_lut[nr][tc][t1].code = code;
                ct_lut[nr][tc][t1].len = bits;
            }
        }
    }
    ct_lut_built = 1;
}

/* ---- Exp-golomb LUT ---- */

UeEntry ue_lut[UE_LUT_SIZE];
static int ue_lut_built = 0;

void build_ue_lut() {
    if (ue_lut_built) return;

    for (uint32_t val = 0; val < UE_LUT_SIZE; val++) {
        uint32_t v = val + 1;
        int len = 0;
        uint32_t tmp = v;
        while (tmp > 0) { tmp >>= 1; len++; }
        ue_lut[val].pattern = v;
        ue_lut[val].len = static_cast<uint8_t>(2 * len - 1);
    }

    ue_lut_built = 1;
}

/* ---- Grid layout helpers ---- */

int ceil_div(int a, int b) {
    return (a + b - 1) / b;
}

int ceil_sqrt(int n) {
    if (n <= 0) return 0;
    int s = (int)sqrt((double)n);
    while (s * s < n) s++;
    while (s > 1 && (s - 1) * (s - 1) >= n) s--;
    return s;
}

/* ---- Row plan builder ---- */

void build_row_plans(
    const bool* slot_active, int max_slots,
    int sprite_w, int sprite_h, int padding,
    int total_w, int total_h,
    std::vector<CompositeRowPlan>& row_plans,
    std::vector<RowOp>& row_ops) {

    int slot_w = sprite_w * 2 - padding;
    int stride_x = slot_w - padding;
    int stride_y = sprite_h - padding;
    int cols = ceil_sqrt(max_slots);

    row_plans.clear();
    row_plans.resize(static_cast<size_t>(total_h));
    row_ops.clear();
    row_ops.reserve(static_cast<size_t>(total_h) * static_cast<size_t>(cols));

    for (int cy = 0; cy < total_h; cy++) {
        auto& plan = row_plans[cy];
        plan.ops_offset = static_cast<uint16_t>(row_ops.size());
        plan.ops_count = 0;

        int cx = 0;
        int prev_end = 0;       /* geometric extent of last sprite region (active or not) */
        int last_active_end = 0; /* extent of last active sprite region */

        while (cx < total_w) {
            int grid_col = (stride_x > 0) ? cx / stride_x : 0;
            int grid_row = (stride_y > 0) ? cy / stride_y : 0;

            if (grid_col >= cols) grid_col = cols - 1;
            int rows_count = ceil_div(max_slots, cols);
            if (grid_row >= rows_count) grid_row = rows_count - 1;

            int slot_idx = grid_row * cols + grid_col;

            int sprite_ox = grid_col * stride_x;
            int sprite_oy = grid_row * stride_y;
            int sprite_end_x = sprite_ox + slot_w;
            int sprite_end_y = sprite_oy + sprite_h;

            if (sprite_end_x > total_w) sprite_end_x = total_w;
            if (sprite_end_y > total_h) sprite_end_y = total_h;

            if (slot_idx >= max_slots || cx < sprite_ox || cx >= sprite_end_x ||
                cy < sprite_oy || cy >= sprite_end_y) {
                cx++;
                continue;
            }

            int sprite_row = cy - sprite_oy;
            int overlap = (prev_end > sprite_ox) ? prev_end - sprite_ox : 0;

            if (slot_active[slot_idx]) {
                /* pre_skip: all MBs from last active sprite's end to this
                 * sprite's effective entry point. Uses max(sprite_ox, prev_end)
                 * to account for shared padding MBs from inactive sprites
                 * that overlap this sprite's region. */
                int effective_start = (prev_end > sprite_ox) ? prev_end : sprite_ox;
                int pre_skip = effective_start - last_active_end;

                RowOp op;
                op.slot_idx = static_cast<uint16_t>(slot_idx);
                op.sprite_row = static_cast<uint16_t>(sprite_row);
                op.pre_skip = static_cast<uint16_t>(pre_skip);
                op.overlap = static_cast<uint16_t>(overlap);
                row_ops.push_back(op);
                plan.ops_count++;
                last_active_end = sprite_end_x;
            }

            prev_end = sprite_end_x;
            cx = sprite_end_x;
        }

        plan.trailing_skips = static_cast<uint16_t>(total_w - last_active_end);
    }
}

/* ---- MicroOp builder ---- */

int build_micro_ops(
    const SlotInfo* slots,
    const CompositeRowPlan* row_plans, int num_rows,
    const RowOp* row_ops,
    int sprite_w, int padding,
    std::vector<MicroOp>& ops) {

    ops.clear();
    int skip_accum = 0;
    int slot_w = sprite_w * 2 - padding;

    for (int cy = 0; cy < num_rows; cy++) {
        const auto& plan = row_plans[cy];
        const RowOp* row_op = row_ops + plan.ops_offset;

        for (int j = 0; j < plan.ops_count; j++) {
            const auto& op = row_op[j];
            const SlotInfo& slot = slots[op.slot_idx];

            /* Prefetch next op's merged row data */
            if (j + 1 < plan.ops_count) {
                const SlotInfo& ns = slots[row_op[j + 1].slot_idx];
                if (ns.sprite) {
                    const MbsRow& nr = ns.sprite->frames[ns.frame_index]
                        .merged_rows[row_op[j + 1].sprite_row];
                    __builtin_prefetch(nr.blob_data, 0, 0);
                    __builtin_prefetch(&nr, 0, 1);
                }
            }

            skip_accum += op.pre_skip;

            if (!slot.sprite) {
                skip_accum += slot_w - op.overlap;
                continue;
            }

            const MbsFrame& frame = slot.sprite->frames[slot.frame_index];
            const MbsRow& row = frame.merged_rows[op.sprite_row];
            int already_inside = static_cast<int>(op.overlap);

            if (row.bit_count() > 0) {
                int blob_start = row.leading_skips;
                int blob_end = slot_w - 1 - row.trailing_skips;

                if (already_inside > blob_end) {
                    skip_accum += slot_w - already_inside;
                } else if (already_inside >= blob_start) {
                    ops.push_back({row.blob_data, static_cast<uint16_t>(row.bit_count()),
                                   static_cast<uint16_t>(skip_accum),
                                   static_cast<uint8_t>(row.has_long_zero_run() ? 1 : 0),
                                   row.leading_zero_bits, row.trailing_zero_bits, 0});
                    skip_accum = row.trailing_skips;
                } else {
                    skip_accum += blob_start - already_inside;
                    ops.push_back({row.blob_data, static_cast<uint16_t>(row.bit_count()),
                                   static_cast<uint16_t>(skip_accum),
                                   static_cast<uint8_t>(row.has_long_zero_run() ? 1 : 0),
                                   row.leading_zero_bits, row.trailing_zero_bits, 0});
                    skip_accum = row.trailing_skips;
                }
            } else {
                skip_accum += slot_w - already_inside;
            }
        }

        /* Cross-row prefetch: first op of next row */
        if (cy + 1 < num_rows) {
            const auto& next_plan = row_plans[cy + 1];
            if (next_plan.ops_count > 0) {
                const auto& first_op = row_ops[next_plan.ops_offset];
                const SlotInfo& ns = slots[first_op.slot_idx];
                if (ns.sprite) {
                    const MbsRow& nr = ns.sprite->frames[ns.frame_index]
                        .merged_rows[first_op.sprite_row];
                    __builtin_prefetch(nr.blob_data, 0, 0);
                    __builtin_prefetch(&nr, 0, 1);
                }
            }
        }

        skip_accum += plan.trailing_skips;
    }

    return skip_accum;
}

/* ---- Zero-run scanning ---- */

std::tuple<int, int, int> scan_zero_runs(const uint8_t* blob, int blob_bits) {
    if (blob_bits <= 0) return {0, 0, 0};

    int max_run = 0, cur_run = 0;
    int leading = 0;
    bool found_one = false;

    for (int i = 0; i < blob_bits; i++) {
        int byte_idx = i / 8;
        int bit_idx = 7 - (i % 8);
        int bit = (blob[byte_idx] >> bit_idx) & 1;

        if (bit == 0) {
            cur_run++;
            if (!found_one) leading++;
        } else {
            if (cur_run > max_run) max_run = cur_run;
            cur_run = 0;
            found_one = true;
        }
    }
    if (cur_run > max_run) max_run = cur_run;

    int trailing = 0;
    for (int i = blob_bits - 1; i >= 0; i--) {
        int byte_idx = i / 8;
        int bit_idx = 7 - (i % 8);
        if ((blob[byte_idx] >> bit_idx) & 1) break;
        trailing++;
    }

    return {max_run, leading, trailing};
}

/* ---- Bit writing helpers ---- */

void bs_copy_bits(bs_t* dst, const uint8_t* src, int src_bit_offset, int nbits) {
    if (nbits <= 0) return;

    int si = src_bit_offset;  // current source bit index

    // Fast path: both aligned and nbits >= 8 — use memcpy for full bytes
    if (dst->bits_left == 8 && (si % 8) == 0) {
        int full_bytes = nbits / 8;
        if (full_bytes > 0) {
            memcpy(dst->p, src + si / 8, full_bytes);
            dst->p += full_bytes;
            si += full_bytes * 8;
            nbits -= full_bytes * 8;
        }
        // Remaining < 8 bits: slow path
        for (int i = 0; i < nbits; i++) {
            int bit = (src[si / 8] >> (7 - (si % 8))) & 1;
            bs_write_u1(dst, (uint32_t)bit);
            si++;
        }
        return;
    }

    // Medium path: process 8 bits at a time
    while (nbits >= 8) {
        // Extract 8 bits from src at bit position si
        int byte_idx = si / 8;
        int bit_off = si % 8;
        uint32_t val;
        if (bit_off == 0) {
            val = src[byte_idx];
        } else {
            val = ((uint32_t)src[byte_idx] << bit_off) |
                  ((uint32_t)src[byte_idx + 1] >> (8 - bit_off));
            val &= 0xFF;
        }

        if (dst->bits_left == 8) {
            *dst->p = (uint8_t)val;
            dst->p++;
            // bits_left stays 8
        } else {
            *dst->p |= (uint8_t)(val >> (8 - dst->bits_left));
            dst->p++;
            *dst->p = (uint8_t)(val << dst->bits_left);
            // bits_left stays the same
        }

        si += 8;
        nbits -= 8;
    }

    // Slow path: remaining < 8 bits
    for (int i = 0; i < nbits; i++) {
        int bit = (src[si / 8] >> (7 - (si % 8))) & 1;
        bs_write_u1(dst, (uint32_t)bit);
        si++;
    }
}

/* ---- RBSP to EBSP ---- */

/* ---- RbspWriter copy_blob ---- */

void RbspWriter::copy_blob(const uint8_t* src, int nbits) {
    if (nbits <= 0) return;

    int full_bytes = nbits / 8;
    int tail_bits = nbits % 8;

    if (bits == 0) {
        /* Aligned: direct memcpy */
        if (full_bytes > 0) {
            memcpy(out, src, full_bytes);
            out += full_bytes;
        }
    } else {
        /* Non-aligned: first byte merges with partial */
        int i = 0;
        if (full_bytes > 0) {
            partial = (partial << 8) | src[0];
            *out++ = static_cast<uint8_t>((partial >> bits) & 0xFF);
            i = 1;
        }

        /* NEON bulk shift+write for interior */
        if (i < full_bytes) {
            int8x16_t rshift = vdupq_n_s8(static_cast<int8_t>(-bits));
            int8x16_t lshift = vdupq_n_s8(static_cast<int8_t>(8 - bits));

            while (i + 16 <= full_bytes) {
                uint8x16_t cur  = vld1q_u8(src + i);
                uint8x16_t prev = vld1q_u8(src + i - 1);
                uint8x16_t hi = vshlq_u8(cur,  rshift);
                uint8x16_t lo = vshlq_u8(prev, lshift);
                vst1q_u8(out, vorrq_u8(hi, lo));
                out += 16;
                i += 16;
            }

            /* Sync partial with last processed byte */
            if (i > 1) partial = src[i - 1];

            /* Scalar tail */
            while (i < full_bytes) {
                partial = (partial << 8) | src[i];
                *out++ = static_cast<uint8_t>((partial >> bits) & 0xFF);
                i++;
            }
        }
    }

    if (tail_bits > 0) {
        uint32_t val = static_cast<uint32_t>(src[full_bytes]) >> (8 - tail_bits);
        write_bits(val, tail_bits);
    }
}

size_t rbsp_to_ebsp(const uint8_t* rbsp, size_t rbsp_size,
                     uint8_t* ebsp, size_t ebsp_size) {
    size_t out = 0;
    int zero_count = 0;
    for (size_t i = 0; i < rbsp_size; i++) {
        uint8_t byte = rbsp[i];
        if (zero_count >= 2 && byte <= 3) {
            if (out >= ebsp_size) return 0;
            ebsp[out++] = 0x03;
            zero_count = 0;
        }
        if (out >= ebsp_size) return 0;
        ebsp[out++] = byte;
        zero_count = (byte == 0) ? zero_count + 1 : 0;
    }
    return out;
}

/* ---- NEON-accelerated RBSP to EBSP ---- */

size_t rbsp_to_ebsp_neon(const uint8_t* rbsp, size_t rbsp_size,
                          uint8_t* ebsp, size_t ebsp_size) {
    size_t out = 0;
    int zero_count = 0;
    size_t i = 0;

    uint8x16_t vzero = vdupq_n_u8(0);

    while (i + 16 <= rbsp_size) {
        /* Drain any dangerous zero_count state via scalar */
        while (zero_count >= 2 && i < rbsp_size) {
            uint8_t byte = rbsp[i];
            if (byte <= 3) {
                if (out >= ebsp_size) return 0;
                ebsp[out++] = 0x03;
                zero_count = 0;
            }
            if (out >= ebsp_size) return 0;
            ebsp[out++] = byte;
            zero_count = (byte == 0) ? zero_count + 1 : 0;
            i++;
        }
        if (i + 16 > rbsp_size) break;

        uint8x16_t v = vld1q_u8(rbsp + i);
        uint8x16_t cmp = vceqq_u8(v, vzero);

        /* vmaxvq_u8: max element across vector.
         * If 0, no byte matched zero -> entire chunk is escape-safe. */
        if (vmaxvq_u8(cmp) == 0) {
            if (out + 16 > ebsp_size) return 0;
            vst1q_u8(ebsp + out, v);
            out += 16;
            zero_count = 0;
            /* But the last bytes might be zero -- count trailing zeros */
            for (int j = 15; j >= 0; j--) {
                if (rbsp[i + j] != 0) break;
                zero_count++;
            }
            i += 16;
        } else {
            /* Has zero bytes -- process scalar for this chunk */
            size_t chunk_end = i + 16;
            if (chunk_end > rbsp_size) chunk_end = rbsp_size;
            while (i < chunk_end) {
                uint8_t byte = rbsp[i++];
                if (zero_count >= 2 && byte <= 3) {
                    if (out >= ebsp_size) return 0;
                    ebsp[out++] = 0x03;
                    zero_count = 0;
                }
                if (out >= ebsp_size) return 0;
                ebsp[out++] = byte;
                zero_count = (byte == 0) ? zero_count + 1 : 0;
            }
        }
    }

    /* Scalar tail */
    while (i < rbsp_size) {
        uint8_t byte = rbsp[i++];
        if (zero_count >= 2 && byte <= 3) {
            if (out >= ebsp_size) return 0;
            ebsp[out++] = 0x03;
            zero_count = 0;
        }
        if (out >= ebsp_size) return 0;
        ebsp[out++] = byte;
        zero_count = (byte == 0) ? zero_count + 1 : 0;
    }

    return out;
}

/* ---- IDR frame writer ---- */

/* Compute the CAVLC level value for luma DC of the first MB (0,0)
   in an all-black I_16x16 IDR frame.

   MB(0,0) has no neighbors, so I_16x16 DC prediction defaults to 128.
   We need residual = -128 to reconstruct Y=0.

   Decoder chain: level → inverse Hadamard → dequant → IDCT → + prediction
     DC_val = ((level * (dequant[QP][0] << 4)) + 32) >> 6
     pixel  = 128 + ((DC_val + 32) >> 6)

   We find the level closest to zero that produces pixel = 0. */
static int16_t black_dc_level(int qp) {
    /* H.264 dequant table position (0,0) — cycles every 6 QPs */
    static const uint16_t dequant_base[6] = {10, 11, 13, 14, 16, 18};
    int qp_per = qp / 6;
    int qp_rem = qp % 6;
    int32_t kiQMul = static_cast<int32_t>(dequant_base[qp_rem]) << (qp_per + 4);

    /* Binary search: find smallest |L| where pixel clips to 0 */
    for (int16_t L = -1; L >= -32767; L--) {
        int32_t dc_val = (static_cast<int32_t>(L) * kiQMul + 32) >> 6;
        int32_t residual = (dc_val + 32) >> 6;
        if (128 + residual <= 0) return L;
    }
    return -1; /* unreachable */
}

std::expected<size_t, Error> write_idr_black(
    int total_w, int total_h,
    int8_t qp_delta_idr, int log2_max_frame_num,
    std::span<uint8_t> output) {

    if (output.size() < 8) return std::unexpected(Error::OUT_OF_SPACE);

    uint8_t* buf = output.data();

    /* NAL header */
    buf[0] = 0x00; buf[1] = 0x00; buf[2] = 0x00; buf[3] = 0x01;
    buf[4] = (3 << 5) | 5;

    int num_mbs = total_w * total_h;
    /* I_16x16 MBs are ~1-2 bytes each; MB(0,0) is ~8 bytes */
    std::vector<uint8_t> rbsp(static_cast<size_t>(num_mbs) * 4 + 4096);

    bs_t b;
    bs_init(&b, rbsp.data(), rbsp.size());

    /* Slice header */
    bs_write_ue(&b, 0);                      /* first_mb_in_slice */
    bs_write_ue(&b, 7);                      /* slice_type = I */
    bs_write_ue(&b, 0);                      /* pps_id */
    bs_write_u(&b, log2_max_frame_num, 0);   /* frame_num = 0 */
    bs_write_ue(&b, 0);                      /* idr_pic_id */
    bs_write_u(&b, 1, 0);                    /* no_output_of_prior_pics_flag */
    bs_write_u(&b, 1, 0);                    /* long_term_reference_flag */
    bs_write_se(&b, qp_delta_idr);           /* slice_qp_delta */
    bs_write_ue(&b, 1);                      /* disable_deblocking_filter_idc */

    /* Luma DC for MB(0,0): compensates DC prediction=128 to produce Y=0.
       All other MBs predict 0 from neighbors → zero residual. */
    int qp = 26 + qp_delta_idr;
    int16_t first_dc[16] = {};
    first_dc[0] = black_dc_level(qp);

    int16_t zero_dc[16] = {};

    /* I_16x16, DC pred (mode 2), cbp_chroma=0, ac_has_nonzero=0
       → mb_type = 1 + 2 + 0 + 0 = 3 in I-slice */
    for (int i = 0; i < num_mbs; i++) {
        bs_write_ue(&b, 3);   /* mb_type */
        bs_write_ue(&b, 0);   /* intra_chroma_pred_mode = DC */
        bs_write_se(&b, 0);   /* mb_qp_delta */

        /* Luma DC block — nC=0 for all MBs (all neighbors have zero AC) */
        cavlc::write_block(&b, (i == 0) ? first_dc : zero_dc, 0, 16);
    }

    /* RBSP trailing bits */
    bs_write_u1(&b, 1);
    while (((b.p - b.start) * 8 + (8 - b.bits_left)) % 8 != 0) {
        bs_write_u1(&b, 0);
    }

    size_t rbsp_size = (size_t)bs_pos(&b);
    size_t ebsp_len = rbsp_to_ebsp(rbsp.data(), rbsp_size, buf + 5, output.size() - 5);

    if (ebsp_len == 0 && rbsp_size > 0) return std::unexpected(Error::OUT_OF_SPACE);
    return 5 + ebsp_len;
}

/* ---- Skip-run splitting ---- */

/* Maximum mb_skip_run value before splitting with dummy P_16x16 zero-residual MBs.
 * Workaround for VideoToolbox decoder limitation: VT rejects structurally valid
 * H.264 P-frames when long skip_runs interact with certain CAVLC blob patterns
 * in partially-filled grids. Splitting large skip_runs into smaller chunks with
 * interleaved dummy MBs (P_16x16, MV=0, CBP=0) avoids the issue.
 * A dummy MB costs 4 bits: ue(0) + se(0) + se(0) + ue(0) = 1+1+1+1 bits. */
static constexpr int MAX_SKIP_RUN = 2048;

/* Write a skip_run, splitting if it exceeds MAX_SKIP_RUN by inserting
 * dummy P_16x16 zero-residual MBs (semantically identical to SKIP). */
template<typename Writer>
static inline void write_skip_safe(Writer& w, int skip) {
    while (skip > MAX_SKIP_RUN) {
        w.write_ue(static_cast<uint32_t>(MAX_SKIP_RUN));
        w.write_bits(0xF, 4);  /* P_16x16 zero: ue(0)+se(0)+se(0)+ue(0) */
        skip -= MAX_SKIP_RUN + 1;
    }
    if (skip > 0) {
        w.write_ue(static_cast<uint32_t>(skip));
    }
}

/* ---- Two-pass P-frame writer (micro-ops + RBSP staging) ---- */

std::expected<size_t, Error> write_p_frame_rbsp(
    const MicroOp* micro_ops, int num_ops, int trailing_skip,
    int frame_idx, int log2_max_frame_num,
    int8_t qp_delta_p,
    std::span<uint8_t> rbsp_buf,
    std::span<uint8_t> output) {

    if (output.size() < 8 || rbsp_buf.size() < 8)
        return std::unexpected(Error::OUT_OF_SPACE);

    /* --- Pass 1: Write RBSP via branchless RbspWriter --- */

    RbspWriter w;
    w.out = rbsp_buf.data();
    w.partial = 0;
    w.bits = 0;

    /* Slice header */
    w.write_ue(0);                                              /* first_mb_in_slice */
    w.write_ue(5);                                              /* slice_type = P */
    w.write_ue(0);                                              /* pps_id */
    int max_fn = 1 << log2_max_frame_num;
    w.write_bits(static_cast<uint32_t>(frame_idx % max_fn),
                 log2_max_frame_num);                           /* frame_num */
    w.write_bits(0, 1);                                         /* ref_pic_list_mod */
    w.write_bits(0, 1);                                         /* adaptive_ref_pic_marking */
    w.write_bits(0, 1);                                         /* adaptive_ref_pic_marking */
    w.write_se(qp_delta_p);                                     /* slice_qp_delta */
    w.write_ue(1);                                              /* disable_deblocking_filter_idc */

    /* Tight micro-op loop */
    for (int i = 0; i < num_ops; i++) {
        const auto& op = micro_ops[i];
        write_skip_safe(w, op.skip);
        w.copy_blob(op.blob_data, op.blob_bits);
    }

    /* Trailing skips */
    write_skip_safe(w, trailing_skip);

    /* RBSP trailing bits */
    w.write_bits(1, 1);
    if (w.bits > 0) {
        w.write_bits(0, 8 - w.bits);
    }

    size_t rbsp_size = static_cast<size_t>(w.out - rbsp_buf.data());

    /* --- Pass 2: NEON EBSP escape insertion --- */

    uint8_t* buf = output.data();

    /* NAL header: nal_ref_idc=2, nal_type=1 (non-IDR slice) */
    buf[0] = 0x00; buf[1] = 0x00; buf[2] = 0x00; buf[3] = 0x01;
    buf[4] = (2 << 5) | 1;

    size_t ebsp_len = rbsp_to_ebsp_neon(
        rbsp_buf.data(), rbsp_size,
        buf + 5, output.size() - 5);

    if (ebsp_len == 0 && rbsp_size > 0)
        return std::unexpected(Error::OUT_OF_SPACE);

    return 5 + ebsp_len;
}

/* ---- Single-pass P-frame writer (EbspWriter + micro-ops) ---- */

std::expected<size_t, Error> write_p_frame_micro(
    const MicroOp* micro_ops, int num_ops, int trailing_skip,
    int frame_idx, int log2_max_frame_num,
    int8_t qp_delta_p,
    std::span<uint8_t> output) {

    if (output.size() < 8)
        return std::unexpected(Error::OUT_OF_SPACE);

    uint8_t* buf = output.data();

    /* NAL header: nal_ref_idc=2, nal_type=1 (non-IDR slice) */
    buf[0] = 0x00; buf[1] = 0x00; buf[2] = 0x00; buf[3] = 0x01;
    buf[4] = (2 << 5) | 1;

    EbspWriter w;
    w.out = buf + 5;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;

    /* Slice header */
    w.write_ue(0);                                              /* first_mb_in_slice */
    w.write_ue(5);                                              /* slice_type = P */
    w.write_ue(0);                                              /* pps_id */
    int max_fn = 1 << log2_max_frame_num;
    w.write_bits(static_cast<uint32_t>(frame_idx % max_fn),
                 log2_max_frame_num);                           /* frame_num */
    w.write_bits(0, 1);                                         /* ref_pic_list_mod */
    w.write_bits(0, 1);                                         /* adaptive_ref_pic_marking */
    w.write_bits(0, 1);                                         /* adaptive_ref_pic_marking */
    w.write_se(qp_delta_p);                                     /* slice_qp_delta */
    w.write_ue(1);                                              /* disable_deblocking_filter_idc */

    /* Tight micro-op loop with inline EBSP escaping */
    for (int i = 0; i < num_ops; i++) {
        const auto& op = micro_ops[i];
        /* Prefetch next blob data */
        if (i + 1 < num_ops) {
            __builtin_prefetch(micro_ops[i + 1].blob_data, 0, 0);
        }
        write_skip_safe(w, op.skip);
        w.copy_blob(op.blob_data, op.blob_bits,
                    (op.flags & 1) != 0, op.leading_zb, op.trailing_zb);
    }

    /* Trailing skips */
    write_skip_safe(w, trailing_skip);

    /* RBSP trailing bits */
    w.write_bits(1, 1);
    if (w.bits > 0) {
        w.write_bits(0, 8 - w.bits);
    }

    return static_cast<size_t>(w.out - buf);
}

/* ---- EbspWriter flush_bytes ---- */

/* SWAR zero-byte detection: returns true if any byte in v is 0x00 */
static inline bool has_zero_byte(uint64_t v) {
    return ((v - 0x0101010101010101ULL) & ~v & 0x8080808080808080ULL) != 0;
}

void EbspWriter::flush_bytes(const uint8_t* src, int nbytes) {
    /* Fast path: process 16 bytes at a time using NEON zero detection.
     * If no zero bytes in chunk and zero_count < 2, memcpy directly. */
    int i = 0;

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    uint8x16_t vzero = vdupq_n_u8(0);

    while (i + 16 <= nbytes) {
        /* If zero_count >= 2, drain scalar until safe */
        while (zero_count >= 2 && i < nbytes) {
            flush_byte(src[i++]);
        }
        if (i + 16 > nbytes) break;

        uint8x16_t v = vld1q_u8(src + i);
        uint8x16_t cmp = vceqq_u8(v, vzero);

        if (vmaxvq_u8(cmp) == 0) {
            /* No zero bytes — safe to memcpy directly */
            memcpy(out, src + i, 16);
            out += 16;
            /* Count trailing zeros for zero_count state */
            zero_count = 0;
            for (int j = 15; j >= 0; j--) {
                if (src[i + j] != 0) break;
                zero_count++;
            }
            i += 16;
        } else {
            /* Has zero bytes — process scalar for this chunk */
            int end = i + 16;
            while (i < end) {
                flush_byte(src[i++]);
            }
        }
    }
#endif

    /* Scalar tail */
    while (i < nbytes) {
        flush_byte(src[i++]);
    }
}

/* ---- EbspWriter copy_blob ---- */

__attribute__((always_inline))
void EbspWriter::copy_blob(const uint8_t* src, int nbits) {
    if (nbits <= 0) return;

    int full_bytes = nbits / 8;
    int tail_bits = nbits % 8;

    if (bits == 0) {
        /* Aligned path: output cursor is byte-aligned.
         * Drain any dangerous zero_count state first. */
        int i = 0;
        while (zero_count >= 2 && i < full_bytes) {
            flush_byte(src[i++]);
        }

        /* SWAR fast path: process 8 bytes at a time when no zero bytes present */
        while (i + 8 <= full_bytes) {
            uint64_t v;
            memcpy(&v, src + i, 8);
            if (!has_zero_byte(v)) {
                /* All bytes non-zero → no EBSP escaping possible.
                 * Safe to memcpy. zero_count → 0 (last byte is non-zero). */
                memcpy(out, src + i, 8);
                out += 8;
                zero_count = 0;
                i += 8;
            } else {
                /* Contains zero bytes — process scalar for this chunk */
                for (int j = 0; j < 8; j++) {
                    flush_byte(src[i++]);
                }
            }
        }

        /* Remaining full bytes */
        while (i < full_bytes) {
            flush_byte(src[i++]);
        }

        /* Tail bits */
        if (tail_bits > 0) {
            uint32_t val = static_cast<uint32_t>(src[full_bytes]) >> (8 - tail_bits);
            write_bits(val, tail_bits);
        }
    } else {
        /* Non-aligned path: shift-copy byte-at-a-time through flush_byte.
         * For each source byte, merge with pending partial bits. */
        for (int i = 0; i < full_bytes; i++) {
            uint32_t byte_val = src[i];
            /* Merge: partial has 'bits' bits, add 8 from source → bits+8 bits.
             * Flush the top 8 bits as one byte. */
            partial = (partial << 8) | byte_val;
            bits += 8;
            /* bits is now shift+8 (9-15). Flush one byte. */
            bits -= 8;
            flush_byte(static_cast<uint8_t>((partial >> bits) & 0xFF));
            /* bits is back to original value (1-7). */
        }

        /* Tail bits */
        if (tail_bits > 0) {
            uint32_t val = static_cast<uint32_t>(src[full_bytes]) >> (8 - tail_bits);
            write_bits(val, tail_bits);
        }
    }
}

__attribute__((always_inline))
void EbspWriter::copy_blob(const uint8_t* src, int nbits,
                           bool long_zero_run, uint8_t leading_zb,
                           uint8_t trailing_zb) {
    (void)leading_zb;
    (void)trailing_zb;
    /* Fall back to safe (old) path if blob has long zero runs */
    if (long_zero_run) {
        copy_blob(src, nbits);
        return;
    }

    if (nbits <= 0) return;

    int full_bytes = nbits / 8;
    int tail_bits = nbits % 8;

    /* For very small blobs, just use the existing path */
    if (full_bytes < 4) {
        copy_blob(src, nbits);
        return;
    }

    /* Number of boundary bytes to process through flush_byte.
     * After 3 bytes through flush_byte, zero_count is guaranteed <= 1
     * (blob has no 16+ zero-bit run, so no two consecutive 0x00 output bytes
     *  can come from blob internals). */
    const int boundary = 3;

    if (bits == 0) {
        /* === Aligned fast path === */

        /* Boundary bytes through flush_byte */
        int i = 0;
        int safe_start = (boundary < full_bytes) ? boundary : full_bytes;
        for (; i < safe_start; i++) {
            flush_byte(src[i]);
        }

        if (i < full_bytes) {
            /* Interior: memcpy directly — no EBSP escaping possible */
            int interior = full_bytes - i;
            memcpy(out, src + i, interior);
            out += interior;

            /* Compute outgoing zero_count from trailing bytes.
             * Count consecutive 0x00 bytes at the end of the memcpy'd region. */
            zero_count = 0;
            for (int j = full_bytes - 1; j >= i && src[j] == 0x00; j--) {
                zero_count++;
            }
        }
    } else {
        /* === Non-aligned fast path (NEON) === */

        /* Boundary bytes through shift + flush_byte */
        int i = 0;
        int safe_start = (boundary < full_bytes) ? boundary : full_bytes;
        for (; i < safe_start; i++) {
            partial = (partial << 8) | src[i];
            bits += 8;
            bits -= 8;
            flush_byte(static_cast<uint8_t>((partial >> bits) & 0xFF));
        }

        if (i < full_bytes) {
            /* Interior: bulk shift+write without EBSP checking.
             * Each output byte is: (src[j-1] << (8-bits)) | (src[j] >> bits).
             * NEON processes 16 bytes per iteration. */
            int remaining = full_bytes - i;

            /* Set up NEON shift vectors (constant across all iterations).
             * vshlq_u8 with negative shift = shift right. */
            int8x16_t rshift = vdupq_n_s8(static_cast<int8_t>(-bits));
            int8x16_t lshift = vdupq_n_s8(static_cast<int8_t>(8 - bits));

            /* Process 16 bytes at a time via NEON */
            while (remaining >= 16) {
                uint8x16_t cur  = vld1q_u8(src + i);      /* src[j]   */
                uint8x16_t prev = vld1q_u8(src + i - 1);  /* src[j-1] */
                uint8x16_t hi = vshlq_u8(cur,  rshift);
                uint8x16_t lo = vshlq_u8(prev, lshift);
                vst1q_u8(out, vorrq_u8(hi, lo));
                out += 16;
                i += 16;
                remaining -= 16;
            }

            /* Sync partial with last source byte before scalar tail.
             * NEON wrote directly to output without updating partial.
             * The low 'bits' bits of src[i-1] are the correct leftover. */
            partial = src[i - 1];

            /* Scalar tail: remaining < 16 bytes */
            while (remaining > 0) {
                partial = (partial << 8) | src[i];
                *out++ = static_cast<uint8_t>((partial >> bits) & 0xFF);
                i++;
                remaining--;
            }

            /* Compute outgoing zero_count.
             * Blob has no 16+ consecutive zero bits, so zero_count <= 1
             * in practice — this loop terminates in 0-1 iterations. */
            zero_count = 0;
            uint8_t* check = out - 1;
            int interior_bytes = full_bytes - safe_start;
            while (check >= out - interior_bytes && *check == 0x00) {
                zero_count++;
                check--;
            }
        }
    }

    /* Tail bits */
    if (tail_bits > 0) {
        uint32_t val = static_cast<uint32_t>(src[full_bytes]) >> (8 - tail_bits);
        write_bits(val, tail_bits);
    }
}

} // namespace subcodec::mux
