#include "types.h"
#include "mbs_encode.h"
#include "mux_surface.h"
#include "mbs_mux_common.h"
#include <cstdio>
#include <cstring>
#include <chrono>
#include <vector>
#include <cstdlib>
#include <algorithm>
#include <numeric>

using namespace subcodec;

static constexpr int SPRITE_W = 6;
static constexpr int SPRITE_H = 6;
static constexpr int PADDING = 1;
static constexpr int NUM_FRAMES = 160;
static constexpr int NUM_SPRITES = 1764;
static constexpr uint8_t QP = 26;

/* Build a synthetic MbsSprite with realistic content:
 *   Frame 0: I_16x16 DC border, I_16x16 DC-only content (4x4 inner)
 *   Frames 1-159: SKIP border, P_16x16 content with small MVs,
 *                  ~50% of content MBs have coded residual */
static MbsSprite make_sprite() {
    const int num_mbs = SPRITE_W * SPRITE_H;
    FrameParams fp{};
    fp.width_mbs = SPRITE_W;
    fp.height_mbs = SPRITE_H;
    fp.qp = QP;

    std::vector<MbsEncodedFrame> frames(NUM_FRAMES);

    for (int f = 0; f < NUM_FRAMES; f++) {
        std::vector<MacroblockData> mbs(num_mbs);

        for (int row = 0; row < SPRITE_H; row++) {
            for (int col = 0; col < SPRITE_W; col++) {
                int idx = row * SPRITE_W + col;
                bool is_border = (row < PADDING || row >= SPRITE_H - PADDING ||
                                  col < PADDING || col >= SPRITE_W - PADDING);

                if (f == 0) {
                    // IDR frame
                    if (is_border) {
                        mbs[idx].mb_type = MbType::I_16x16;
                        mbs[idx].intra_pred_mode = I16PredMode::DC;
                        mbs[idx].intra_chroma_mode = ChromaPredMode::DC;
                    } else {
                        mbs[idx].mb_type = MbType::I_16x16;
                        mbs[idx].intra_pred_mode = I16PredMode::DC;
                        mbs[idx].intra_chroma_mode = ChromaPredMode::DC;
                        // DC-only coefficients
                        mbs[idx].luma_dc[0] = (int16_t)(50 + row * 10 + col * 5);
                        mbs[idx].cbp_luma = 0;
                        mbs[idx].cbp_chroma = 0;
                    }
                } else {
                    // P-frame
                    if (is_border) {
                        mbs[idx].mb_type = MbType::SKIP;
                    } else {
                        mbs[idx].mb_type = MbType::P_16x16;
                        // Small MVs
                        mbs[idx].mv_x = (int16_t)((col % 3) - 1);
                        mbs[idx].mv_y = (int16_t)((row % 3) - 1);

                        // ~50% of content MBs have coded residual
                        if ((row + col + f) % 2 == 0) {
                            mbs[idx].cbp_luma = 0x01;  // first 8x8 block has coeffs
                            mbs[idx].cbp_chroma = 1;
                            // Sparse coefficients
                            mbs[idx].luma_ac[0][0] = (int16_t)(3 + (f % 5));
                            mbs[idx].luma_ac[0][1] = (int16_t)(-(f % 3));
                            mbs[idx].cb_ac[0][0] = 2;
                            mbs[idx].cr_ac[0][0] = -1;
                        }
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

int main() {
    printf("=== Mux Performance Stress Test ===\n");
    printf("Sprites: %d, Frames: %d, Sprite size: %dx%d MBs\n",
           NUM_SPRITES, NUM_FRAMES, SPRITE_W, SPRITE_H);

    // 1. Generate synthetic sprite
    printf("Generating synthetic sprite...\n");
    auto t0 = std::chrono::high_resolution_clock::now();
    MbsSprite template_sprite = make_sprite();
    auto t1 = std::chrono::high_resolution_clock::now();
    double gen_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    printf("  Sprite generation: %.1f ms\n", gen_ms);

    // 2. Create MuxSurface
    size_t total_bytes = 0;
    auto sink = [&total_bytes](std::span<const uint8_t> data) {
        total_bytes += data.size();
    };

    MuxSurface::Params params;
    params.sprite_width = (SPRITE_W - 2) * 16;
    params.sprite_height = (SPRITE_H - 2) * 16;
    params.max_slots = NUM_SPRITES;
    params.qp = QP;
    params.qp_delta_idr = 0;
    params.qp_delta_p = 0;

    auto mux_result = MuxSurface::create(params, sink);
    if (!mux_result) {
        printf("FAIL: MuxSurface::create failed\n");
        return 1;
    }
    auto& mux = *mux_result;

    printf("Grid: %dx%d MBs (%dx%d pixels)\n",
           mux.width_mbs(), mux.height_mbs(),
           mux.width_mbs() * 16, mux.height_mbs() * 16);

    // Save template sprite to temp file for reloading copies
    const char* tmp_path = "/tmp/test_mux_perf_template.mbs";
    auto save_result = template_sprite.save(tmp_path);
    if (!save_result) { printf("FAIL: save template\n"); return 1; }

    // 3. Add 1764 copies of the sprite
    printf("Adding %d sprites...\n", NUM_SPRITES);
    auto t_add_start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < NUM_SPRITES; i++) {
        auto slot = mux.add_sprite(tmp_path);
        if (!slot) {
            printf("FAIL: add_sprite failed at slot %d\n", i);
            return 1;
        }
    }
    auto t_add_end = std::chrono::high_resolution_clock::now();
    double add_ms = std::chrono::duration<double, std::milli>(t_add_end - t_add_start).count();
    printf("  Sprite add time: %.1f ms (%.2f ms/sprite)\n", add_ms, add_ms / NUM_SPRITES);

    // 4. Advance 160 frames, measuring per-frame time
    printf("Advancing %d frames...\n", NUM_FRAMES);
    std::vector<double> frame_times(NUM_FRAMES);

    for (int f = 0; f < NUM_FRAMES; f++) {
        auto fs = std::chrono::high_resolution_clock::now();
        auto result = mux.advance_frame(sink);
        auto fe = std::chrono::high_resolution_clock::now();

        if (!result) {
            printf("FAIL: advance_frame failed at frame %d\n", f);
            return 1;
        }

        frame_times[f] = std::chrono::duration<double, std::milli>(fe - fs).count();

        if (f < 3 || f == NUM_FRAMES - 1) {
            printf("  Frame %3d: %.1f ms\n", f, frame_times[f]);
        } else if (f == 3) {
            printf("  ...\n");
        }
    }

    // 5. Compute statistics
    std::vector<double> sorted_times = frame_times;
    std::sort(sorted_times.begin(), sorted_times.end());

    double total_time = std::accumulate(frame_times.begin(), frame_times.end(), 0.0);
    double avg = total_time / NUM_FRAMES;
    double min_t = sorted_times.front();
    double max_t = sorted_times.back();
    double p50 = sorted_times[NUM_FRAMES / 2];
    double p95 = sorted_times[(int)(NUM_FRAMES * 0.95)];
    double p99 = sorted_times[(int)(NUM_FRAMES * 0.99)];

    printf("\n=== Results ===\n");
    printf("Grid size:     %dx%d MBs (%dx%d pixels)\n",
           mux.width_mbs(), mux.height_mbs(),
           mux.width_mbs() * 16, mux.height_mbs() * 16);
    printf("Total bytes:   %zu (%.1f MB)\n", total_bytes, total_bytes / (1024.0 * 1024.0));
    printf("Total time:    %.1f ms\n", total_time);
    printf("Per-frame avg: %.2f ms\n", avg);
    printf("Per-frame min: %.2f ms\n", min_t);
    printf("Per-frame p50: %.2f ms\n", p50);
    printf("Per-frame p95: %.2f ms\n", p95);
    printf("Per-frame p99: %.2f ms\n", p99);
    printf("Per-frame max: %.2f ms\n", max_t);

    // 6. Sanity check
    if (total_bytes == 0) {
        printf("\nFAIL: total_bytes == 0\n");
        return 1;
    }

    printf("\nPASS\n");
    return 0;
}
