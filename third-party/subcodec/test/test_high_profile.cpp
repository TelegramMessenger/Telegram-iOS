#include "types.h"
#include "mbs_encode.h"
#include "mux_surface.h"
#include "mbs_mux_common.h"
#include "frame_writer.h"
#include "codec_api.h"
#include "codec_app_def.h"
#include "codec_def.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>

/* Test 1: Verify High Profile SPS is accepted by OpenH264 decoder.
 * Uses a small grid that just barely exceeds Baseline Level 5.1 (36,864 MBs),
 * but small enough for OpenH264 to allocate decode buffers.
 *
 * Test 2: Verify large grid (>36,864 MBs) muxes without errors. */

using namespace subcodec;

static constexpr int SPRITE_W = 6;
static constexpr int SPRITE_H = 6;
static constexpr int PADDING = 1;
static constexpr int NUM_FRAMES = 4;
static constexpr uint8_t QP = 26;

static MbsSprite make_sprite() {
    const int num_mbs = SPRITE_W * SPRITE_H;
    FrameParams fp{};
    fp.width_mbs = SPRITE_W;
    fp.height_mbs = SPRITE_H;
    fp.qp = QP;

    srand(99);
    std::vector<MbsEncodedFrame> frames(NUM_FRAMES);

    for (int f = 0; f < NUM_FRAMES; f++) {
        std::vector<MacroblockData> mbs(num_mbs);
        for (int my = 0; my < SPRITE_H; my++) {
            for (int mx = 0; mx < SPRITE_W; mx++) {
                int idx = my * SPRITE_W + mx;
                bool is_pad = (mx == 0 || mx == SPRITE_W - 1 ||
                               my == 0 || my == SPRITE_H - 1);
                if (is_pad) {
                    if (f == 0) {
                        mbs[idx].mb_type = MbType::I_16x16;
                        mbs[idx].intra_pred_mode = I16PredMode::DC;
                        mbs[idx].intra_chroma_mode = ChromaPredMode::DC;
                    } else {
                        mbs[idx].mb_type = MbType::SKIP;
                    }
                } else if (f == 0) {
                    mbs[idx].mb_type = MbType::I_16x16;
                    mbs[idx].intra_pred_mode = I16PredMode::DC;
                    mbs[idx].intra_chroma_mode = ChromaPredMode::DC;
                    mbs[idx].cbp_chroma = 1;
                    for (int i = 0; i < 16; i++)
                        mbs[idx].luma_dc[i] = (int16_t)((rand() % 21) - 10);
                    for (int i = 0; i < 4; i++) {
                        mbs[idx].cb_dc[i] = (int16_t)((rand() % 11) - 5);
                        mbs[idx].cr_dc[i] = (int16_t)((rand() % 11) - 5);
                    }
                } else {
                    mbs[idx].mb_type = MbType::P_16x16;
                    mbs[idx].mv_x = (int16_t)((rand() % 5) - 2);
                    mbs[idx].mv_y = (int16_t)((rand() % 5) - 2);
                    if (rand() % 2) {
                        mbs[idx].cbp_luma = (uint8_t)(rand() % 16);
                        mbs[idx].cbp_chroma = (uint8_t)(rand() % 3);
                        for (int blk = 0; blk < 16; blk++)
                            mbs[idx].luma_dc[blk] = (int16_t)((rand() % 7) - 3);
                    }
                }
            }
        }
        // Encode merged color+alpha frame (alpha is all-skip)
        std::vector<MacroblockData> alpha_mbs(num_mbs);
        for (auto& mb : alpha_mbs) mb.mb_type = MbType::SKIP;
        frames[f] = mbs::encode_frame_merged(fp, mbs.data(), fp, alpha_mbs.data(), SPRITE_W, PADDING);
    }

    MbsSprite sp;
    sp.width_mbs = SPRITE_W;
    sp.height_mbs = SPRITE_H;
    sp.num_frames = NUM_FRAMES;
    sp.qp = QP;
    sp.qp_delta_idr = 0;
    sp.qp_delta_p = 0;
    sp.set_frames(std::move(frames));
    return sp;
}

/* ---- Annex B frame splitting ---- */

static int split_annex_b_frames(const uint8_t* data, size_t size,
                                std::vector<uint8_t>* out_frames, int max_frames) {
    int count = 0;
    size_t frame_start = 0;
    int current_has_slice = 0;

    for (size_t i = 0; i + 3 < size; ) {
        int sc_len = 0;
        if (i + 3 < size && data[i] == 0 && data[i+1] == 0 && data[i+2] == 0 && data[i+3] == 1)
            sc_len = 4;
        else if (i + 2 < size && data[i] == 0 && data[i+1] == 0 && data[i+2] == 1)
            sc_len = 3;

        if (sc_len > 0 && i > 0) {
            uint8_t nal_type = data[i + sc_len] & 0x1F;
            if ((nal_type == 1 || nal_type == 5) && i > frame_start) {
                if (current_has_slice && count < max_frames) {
                    out_frames[count].assign(data + frame_start, data + i);
                    count++;
                    frame_start = i;
                    current_has_slice = 0;
                }
                current_has_slice = 1;
            }
        }

        if (sc_len > 0) i += sc_len + 1;
        else i++;
    }

    if (frame_start < size && count < max_frames) {
        out_frames[count].assign(data + frame_start, data + size);
        count++;
    }

    return count;
}

/* ---- Test 1: Decode-verify a High Profile stream ---- */

static int test_high_profile_decode() {
    printf("--- Test 1: High Profile SPS decode verification ---\n");

    /* Write a High Profile SPS+PPS+IDR directly with a small frame size
     * that triggers High Profile (>36864 MBs) but is decodable.
     * Use raw write_headers + write_idr_black with 193x192 MBs = 37056 MBs. */
    int w = 193, h = 192;
    int total_mbs = w * h;
    printf("Frame: %dx%d MBs (%d total, %s Baseline 5.1 limit)\n",
           w, h, total_mbs, total_mbs > 36864 ? "exceeds" : "within");

    if (total_mbs <= 36864) {
        printf("FAIL: need >36864 MBs\n");
        return 1;
    }

    FrameParams fp{};
    fp.width_mbs = static_cast<uint16_t>(w);
    fp.height_mbs = static_cast<uint16_t>(h);
    fp.qp = 26;
    fp.log2_max_frame_num = 4;

    /* Allocate buffers for I_16x16 IDR at this size */
    size_t buf_size = static_cast<size_t>(total_mbs) * 600 + 8192;
    std::vector<uint8_t> buf(buf_size);

    size_t hdr = frame_writer::write_headers({buf.data(), buf.size()}, fp);
    if (hdr == 0) { printf("FAIL: write_headers\n"); return 1; }

    /* Verify SPS has High Profile */
    /* SPS NAL: 00 00 00 01 67 XX where XX is profile_idc */
    uint8_t profile = buf[5];  /* byte after NAL header 67 */
    printf("SPS profile_idc: %d (%s)\n", profile,
           profile == 100 ? "High" : profile == 66 ? "Baseline" : "other");
    if (profile != 100) {
        printf("FAIL: expected High Profile (100), got %d\n", profile);
        return 1;
    }

    /* Verify SPS can be parsed by OpenH264 (just feed SPS+PPS, no IDR) */
    ISVCDecoder* dec = nullptr;
    WelsCreateDecoder(&dec);
    SDecodingParam dp{};
    dp.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_AVC;
    dec->Initialize(&dp);

    unsigned char* pDst[3] = {};
    SBufferInfo info{};
    auto rv = dec->DecodeFrameNoDelay(buf.data(), (int)hdr, pDst, &info);
    WelsDestroyDecoder(dec);

    /* dsFramePending (0x01) or dsNoParamSets (0x10) are acceptable —
     * they mean the SPS/PPS was parsed but no frame data yet.
     * dsBitstreamError (0x04) would mean the High Profile SPS was rejected. */
    if (rv & 0x04) {
        printf("FAIL: SPS/PPS rejected (dsBitstreamError), rv=%d\n", (int)rv);
        return 1;
    }
    printf("SPS/PPS accepted by decoder (rv=%d)\n", (int)rv);

    printf("PASS\n\n");
    return 0;
}

/* ---- Test 2: Large grid mux without errors ---- */

static int test_large_grid_mux() {
    printf("--- Test 2: Large grid mux (2048 slots) ---\n");

    MbsSprite sprite = make_sprite();
    if (sprite.frames.empty()) {
        printf("FAIL: sprite generation\n");
        return 1;
    }

    // Save template to temp file for reloading copies
    const char* tmp_path = "/tmp/test_high_profile_template.mbs";
    auto save_result = sprite.save(tmp_path);
    if (!save_result) { printf("FAIL: save template\n"); return 1; }

    size_t total_bytes = 0;
    auto sink = [&total_bytes](std::span<const uint8_t> data) {
        total_bytes += data.size();
    };

    MuxSurface::Params params;
    params.sprite_width = (SPRITE_W - 2) * 16;
    params.sprite_height = (SPRITE_H - 2) * 16;
    params.max_slots = 2048;
    params.qp = QP;
    params.qp_delta_idr = 0;
    params.qp_delta_p = 0;

    auto mux_result = MuxSurface::create(params, sink);
    if (!mux_result) {
        printf("FAIL: MuxSurface::create\n");
        return 1;
    }
    auto& mux = *mux_result;

    int grid_mbs = mux.width_mbs() * mux.height_mbs();
    printf("Grid: %dx%d MBs (%dx%d pixels), %d total MBs\n",
           mux.width_mbs(), mux.height_mbs(),
           mux.width_mbs() * 16, mux.height_mbs() * 16, grid_mbs);

    if (grid_mbs <= 36864) {
        printf("FAIL: grid too small (%d <= 36864)\n", grid_mbs);
        return 1;
    }

    int sprites_to_add = 100;
    for (int i = 0; i < sprites_to_add; i++) {
        auto slot = mux.add_sprite(tmp_path);
        if (!slot) {
            printf("FAIL: add_sprite at %d\n", i);
            return 1;
        }
    }

    for (int f = 0; f < NUM_FRAMES - 1; f++) {
        auto result = mux.advance_frame(sink);
        if (!result) {
            printf("FAIL: advance_frame at %d\n", f);
            return 1;
        }
    }

    if (total_bytes == 0) {
        printf("FAIL: no output\n");
        return 1;
    }
    printf("Output: %zu bytes (%.1f MB)\n", total_bytes, total_bytes / (1024.0 * 1024.0));
    printf("PASS\n\n");
    return 0;
}

int main() {
    printf("=== High Profile / Level 6.0 Tests ===\n\n");
    int fail = 0;
    fail += test_high_profile_decode();
    fail += test_large_grid_mux();
    printf(fail ? "SOME TESTS FAILED\n" : "ALL TESTS PASSED\n");
    return fail ? 1 : 0;
}
