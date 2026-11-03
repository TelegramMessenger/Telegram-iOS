#pragma once

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <span>
#include <expected>
#include <vector>
#include <tuple>
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif
#include "types.h"
#include "error.h"
#include "bs.h"
#include "mbs_format.h"
#include "cavlc.h"

namespace subcodec::mux {

/* ---- Exp-golomb LUT ---- */

struct UeEntry {
    uint32_t pattern;  /* bit pattern, MSB-first */
    uint8_t len;       /* number of bits (max 25 for values up to 4095) */
};

static constexpr int UE_LUT_SIZE = 4096;
extern UeEntry ue_lut[UE_LUT_SIZE];

void build_ue_lut();

/* ---- EbspWriter: single-pass direct EBSP output ---- */

/* Writes bits directly to an output buffer with inline EBSP escape byte
 * insertion (0x00 0x00 [0x00-0x03] → 0x00 0x00 0x03 [0x00-0x03]).
 * Replaces the two-stage bs_t→RBSP + rbsp_to_ebsp pipeline. */
struct EbspWriter {
    uint8_t* out;       /* next complete-byte write position */
    uint32_t partial;   /* accumulated bits not yet flushed (MSB-first) */
    int bits;           /* number of valid bits in partial (0-7) */
    int zero_count;     /* consecutive 0x00 bytes written (for EBSP escaping) */

    /* Write one complete byte with EBSP escape check. */
    inline void flush_byte(uint8_t byte) {
        if (zero_count >= 2 && byte <= 3) {
            *out++ = 0x03;
            zero_count = 0;
        }
        *out++ = byte;
        zero_count = (byte == 0) ? zero_count + 1 : 0;
    }

    /* Accumulate n bits (max 25) and flush complete bytes.
     * val must have its bits in the low n positions. */
    inline void write_bits(uint32_t val, int n) {
        partial = (partial << n) | val;
        bits += n;
        while (bits >= 8) {
            bits -= 8;
            flush_byte(static_cast<uint8_t>((partial >> bits) & 0xFF));
        }
    }

    /* Write unsigned exp-golomb code. Uses LUT for values < 4096,
     * falls back to computed encoding for larger values. */
    inline void write_ue(uint32_t val) {
        if (val < UE_LUT_SIZE) {
            const auto& e = ue_lut[val];
            write_bits(e.pattern, e.len);
        } else {
            /* Fallback: compute exp-golomb encoding */
            uint32_t v = val + 1;
            int len = 0;
            uint32_t tmp = v;
            while (tmp > 0) { tmp >>= 1; len++; }
            write_bits(v, 2 * len - 1);
        }
    }

    /* Write signed exp-golomb code. */
    inline void write_se(int32_t val) {
        if (val <= 0)
            write_ue(static_cast<uint32_t>(-val * 2));
        else
            write_ue(static_cast<uint32_t>(val * 2 - 1));
    }

    /* Bulk write complete bytes with EBSP escaping.
     * Requires bits == 0 (byte-aligned). Uses NEON to detect zero bytes
     * and bulk-copy safe regions. For I_PCM pixel data. */
    void flush_bytes(const uint8_t* src, int nbytes);

    /* Bulk copy blob bits into output with inline EBSP escaping.
     * src is a byte array; nbits bits starting from bit 0 are copied.
     * Handles both aligned (bits == 0) and non-aligned cases. */
    void copy_blob(const uint8_t* src, int nbits);

    /* Bulk copy blob bits with fast path when blob has no 16+ consecutive zero bits.
     * has_long_zero_run: if false, interior bytes are guaranteed EBSP-safe.
     * leading_zero_bits/trailing_zero_bits: for boundary handling. */
    void copy_blob(const uint8_t* src, int nbits,
                   bool has_long_zero_run, uint8_t leading_zero_bits,
                   uint8_t trailing_zero_bits);
};

/* ---- RbspWriter: branchless bitstream writer for RBSP staging ---- */

/* No EBSP escape checking — caller must run rbsp_to_ebsp after.
 * Used in the two-pass P-frame mux path. */
struct RbspWriter {
    uint8_t* out;       /* next complete-byte write position */
    uint32_t partial;   /* accumulated bits not yet flushed (MSB-first) */
    int bits;           /* number of valid bits in partial (0-7) */

    inline void write_bits(uint32_t val, int n) {
        partial = (partial << n) | val;
        bits += n;
        while (bits >= 8) {
            bits -= 8;
            *out++ = static_cast<uint8_t>((partial >> bits) & 0xFF);
        }
    }

    inline void write_ue(uint32_t val) {
        if (val < UE_LUT_SIZE) {
            const auto& e = ue_lut[val];
            write_bits(e.pattern, e.len);
        } else {
            uint32_t v = val + 1;
            int len = 0;
            uint32_t tmp = v;
            while (tmp > 0) { tmp >>= 1; len++; }
            write_bits(v, 2 * len - 1);
        }
    }

    inline void write_se(int32_t val) {
        if (val <= 0) write_ue(static_cast<uint32_t>(-val * 2));
        else          write_ue(static_cast<uint32_t>(val * 2 - 1));
    }

    /* Bulk copy blob bits — no EBSP checking.
     * Aligned: memcpy. Non-aligned: NEON shift+write. */
    void copy_blob(const uint8_t* src, int nbits);
};

/* ---- Coeff_token LUT ---- */

void build_ct_lut();

/* ---- Grid layout helpers ---- */

int ceil_div(int a, int b);
int ceil_sqrt(int n);

/* ---- Row plan types (precomputed composite layout) ---- */

struct RowOp {
    uint16_t slot_idx;      /* which slot this sprite is in */
    uint16_t sprite_row;    /* which row within the sprite */
    uint16_t pre_skip;      /* composite skip MBs from previous sprite-region end
                               (or row start) to this sprite-region start.
                               Clamped to >= 0. Fixed for a given layout. */
    uint16_t overlap;       /* MBs at start of this sprite's region already covered
                               by the previous sprite (shared padding). The mux loop
                               uses this as `already_inside` — same role as in the
                               current grid walk code. 0 for the first sprite in a row
                               or when there's a gap between sprites. */
};

struct CompositeRowPlan {
    uint16_t trailing_skips; /* composite skip MBs after last sprite-region end */
    uint16_t ops_offset;     /* index into flat ops array */
    uint16_t ops_count;      /* number of RowOps in this row */
};

/* Build precomputed row plans from slot active state.
 * Called from MuxSurface::add_sprite / remove_sprite. */
void build_row_plans(
    const bool* slot_active, int max_slots,
    int sprite_w, int sprite_h, int padding,
    int total_w, int total_h,
    std::vector<CompositeRowPlan>& row_plans,
    std::vector<RowOp>& row_ops);

/* Pre-resolved blob operation for the tight mux loop.
 * Built once per frame from row_ops + slot state.
 * Only active blobs with data appear — inactive slots and
 * all-skip rows are folded into skip counts. */
struct MicroOp {
    const uint8_t* blob_data;
    uint16_t blob_bits;       /* bit count (lower 15 bits of blob_bit_count) */
    uint16_t skip;            /* composite skip MBs to write before this blob */
    uint8_t flags;            /* [0] = has_long_zero_run */
    uint8_t leading_zb;
    uint8_t trailing_zb;
    uint8_t _pad;
};

/* ---- Zero-run scanning ---- */

/* Scan blob bits for zero-run metadata.
 * Returns: {max_consecutive_zero_bits, leading_zero_bits, trailing_zero_bits} */
std::tuple<int, int, int> scan_zero_runs(const uint8_t* blob, int blob_bits);

/* ---- Bit writing helpers ---- */

/* Bulk copy nbits from src byte array at src_bit_offset into dst bs_t.
 * Uses byte-level operations where possible for speed. */
void bs_copy_bits(bs_t* dst, const uint8_t* src, int src_bit_offset, int nbits);

/* ---- RBSP to EBSP ---- */

size_t rbsp_to_ebsp(const uint8_t* rbsp, size_t rbsp_size,
                     uint8_t* ebsp, size_t ebsp_size);

/* NEON-accelerated EBSP escape insertion.
 * Scans 16 bytes at a time for zero bytes; bulk-copies safe regions.
 * Returns output byte count, 0 on error. */
size_t rbsp_to_ebsp_neon(const uint8_t* rbsp, size_t rbsp_size,
                          uint8_t* ebsp, size_t ebsp_size);

/* ---- Frame writers ---- */

/* Write all-black IDR frame (I_16x16 DC prediction for every MB). */
std::expected<size_t, Error> write_idr_black(
    int total_w, int total_h,
    int8_t qp_delta_idr, int log2_max_frame_num,
    std::span<uint8_t> output);

/* Write all-I_PCM IDR frame from caller-provided decoded YUV planes.
 * Every MB is I_PCM (384 raw bytes: 256 luma + 64 Cb + 64 Cr).
 * Inline: enables cross-TU inlining into MuxSurface::resize at -O2. */
inline std::expected<size_t, Error> write_idr_ipcm(
    int total_w, int total_h,
    int log2_max_frame_num,
    const uint8_t* y_plane, int stride_y,
    const uint8_t* cb_plane, int stride_cb,
    const uint8_t* cr_plane, int stride_cr,
    std::span<uint8_t> output) {

    int num_mbs = total_w * total_h;
    size_t needed = static_cast<size_t>(num_mbs) * 580 + 4096;
    if (output.size() < needed)
        return std::unexpected(Error::OUT_OF_SPACE);

    uint8_t* buf = output.data();

    /* NAL header: nal_ref_idc=3, nal_unit_type=5 (IDR) */
    buf[0] = 0x00; buf[1] = 0x00; buf[2] = 0x00; buf[3] = 0x01;
    buf[4] = (3 << 5) | 5;

    /* Single-pass: write directly to EBSP output via EbspWriter. */
    EbspWriter w;
    w.out = buf + 5;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;

    /* Slice header */
    w.write_ue(0);                          /* first_mb_in_slice */
    w.write_ue(7);                          /* slice_type = I */
    w.write_ue(0);                          /* pps_id */
    w.write_bits(0, log2_max_frame_num);    /* frame_num = 0 */
    w.write_ue(0);                          /* idr_pic_id */
    w.write_bits(0, 1);                     /* no_output_of_prior_pics_flag */
    w.write_bits(0, 1);                     /* long_term_reference_flag */
    w.write_se(0);                          /* slice_qp_delta = 0 */
    w.write_ue(1);                          /* disable_deblocking_filter_idc */

    /* Precompute EBSP-escaped all-zero luma pattern (256 input zeros → 384 output bytes).
     * After mb_type + alignment, zero_count == 1 (from alignment byte 0x00).
     * Each pair of input zeros produces [0x00, 0x03, 0x00] (3 bytes). */
    uint8_t black_luma_ebsp[384];
    for (int i = 0; i < 128; i++) {
        black_luma_ebsp[i * 3 + 0] = 0x00;
        black_luma_ebsp[i * 3 + 1] = 0x03;
        black_luma_ebsp[i * 3 + 2] = 0x00;
    }

    uint8_t neutral_chroma[128];
    memset(neutral_chroma, 0x80, 128);

    /* Write MBs — fast path for all-black MBs (Y=0, Cb=Cr=128). */
    for (int mb_idx = 0; mb_idx < num_mbs; mb_idx++) {
        int mb_x = mb_idx % total_w;
        int mb_y = mb_idx / total_w;

        w.write_ue(25);  /* mb_type = I_PCM */

        if (w.bits > 0) {
            w.write_bits(0, 8 - w.bits);  /* byte-align */
        }

        int y_base = mb_y * 16;
        int x_base = mb_x * 16;
        int cb_y_base = mb_y * 8;
        int cb_x_base = mb_x * 8;

        bool is_black = true;
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
        {
            uint8x16_t vzero = vdupq_n_u8(0);
            uint8x16_t v128 = vdupq_n_u8(128);
            for (int row = 0; row < 16 && is_black; row++) {
                uint8x16_t v = vld1q_u8(y_plane + (y_base + row) * stride_y + x_base);
                if (vmaxvq_u8(v) != 0) is_black = false;
            }
            for (int row = 0; row < 8 && is_black; row++) {
                uint8x8_t v = vld1_u8(cb_plane + (cb_y_base + row) * stride_cb + cb_x_base);
                uint8x8_t cmp = vceq_u8(v, vget_low_u8(v128));
                if (vminv_u8(cmp) == 0) is_black = false;
            }
            for (int row = 0; row < 8 && is_black; row++) {
                uint8x8_t v = vld1_u8(cr_plane + (cb_y_base + row) * stride_cr + cb_x_base);
                uint8x8_t cmp = vceq_u8(v, vget_low_u8(v128));
                if (vminv_u8(cmp) == 0) is_black = false;
            }
        }
#else
        if (y_plane[y_base * stride_y + x_base] != 0) is_black = false;
        if (is_black && cb_plane[cb_y_base * stride_cb + cb_x_base] != 128) is_black = false;
#endif

        if (is_black) {
            memcpy(w.out, black_luma_ebsp, 384);
            w.out += 384;
            memcpy(w.out, neutral_chroma, 128);
            w.out += 128;
            w.zero_count = 0;
        } else {
            /* Gather MB samples into contiguous buffer for bulk EBSP processing.
             * 256 luma + 64 Cb + 64 Cr = 384 bytes → flush_bytes processes
             * 24 NEON chunks (16 bytes each) instead of 384 scalar flush_byte calls. */
            uint8_t mb_buf[384];
            uint8_t* dst = mb_buf;
            for (int row = 0; row < 16; row++) {
                memcpy(dst, y_plane + (y_base + row) * stride_y + x_base, 16);
                dst += 16;
            }
            for (int row = 0; row < 8; row++) {
                memcpy(dst, cb_plane + (cb_y_base + row) * stride_cb + cb_x_base, 8);
                dst += 8;
            }
            for (int row = 0; row < 8; row++) {
                memcpy(dst, cr_plane + (cb_y_base + row) * stride_cr + cb_x_base, 8);
                dst += 8;
            }
            w.flush_bytes(mb_buf, 384);
        }
    }

    w.write_bits(1, 1);  /* RBSP trailing bits */
    if (w.bits > 0) {
        w.write_bits(0, 8 - w.bits);
    }

    return static_cast<size_t>(w.out - buf);
}

/* Per-slot info needed by the row-blob mux path */
struct SlotInfo {
    const MbsSprite* sprite = nullptr;
    int frame_index = 0;
};

/* Build flat micro-op array from row plans and current frame state.
 * Returns trailing skip count (MBs after the last blob). */
int build_micro_ops(
    const SlotInfo* slots,
    const CompositeRowPlan* row_plans, int num_rows,
    const RowOp* row_ops,
    int sprite_w, int padding,
    std::vector<MicroOp>& ops);

/* Two-pass P-frame writer using pre-resolved micro-ops.
 * Pass 1: write to RBSP staging buffer via RbspWriter (no EBSP checking).
 * Pass 2: NEON-accelerated EBSP escape insertion.
 * micro_ops/trailing_skip: from build_micro_ops().
 * rbsp_buf: staging buffer (caller-owned, at least output.size() bytes). */
std::expected<size_t, Error> write_p_frame_rbsp(
    const MicroOp* micro_ops, int num_ops, int trailing_skip,
    int frame_idx, int log2_max_frame_num,
    int8_t qp_delta_p,
    std::span<uint8_t> rbsp_buf,
    std::span<uint8_t> output);

/* Single-pass P-frame writer using pre-resolved micro-ops + EbspWriter.
 * Uses EbspWriter's inline EBSP escaping with fast-path for escape-free blobs.
 * micro_ops/trailing_skip: from build_micro_ops(). */
std::expected<size_t, Error> write_p_frame_micro(
    const MicroOp* micro_ops, int num_ops, int trailing_skip,
    int frame_idx, int log2_max_frame_num,
    int8_t qp_delta_p,
    std::span<uint8_t> output);

} // namespace subcodec::mux
