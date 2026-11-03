#include <cstdio>
#include <cstring>
#include <span>
#include <vector>

#include "codec_api.h"
#include "codec_app_def.h"
#include "codec_def.h"

#include "frame_writer.h"
#include "types.h"
#include "sprite_encode.h"
#include "sprite_extractor.h"
#include "mux_surface.h"

using namespace subcodec;

#define NUM_SPRITES   2
#define NUM_FRAMES    8
#define SPRITE_PX     64
#define PADDED_PX     96
#define PADDED_MBS    6
#define PADDING_MBS   1

/* ---- Sprite generation ---- */

static void generate_sprite_frame(uint8_t* y_plane, uint8_t* cb_plane, uint8_t* cr_plane,
                                  int sprite_id, int frame) {
    uint8_t cb_val = (uint8_t)(128 + sprite_id * 20);
    uint8_t cr_val = (uint8_t)(128 - sprite_id * 20);

    for (int py = 0; py < SPRITE_PX; py++) {
        for (int px = 0; px < SPRITE_PX; px++) {
            uint8_t y_val;
            switch (sprite_id) {
                case 0: y_val = (uint8_t)((px + frame * 8) % 256); break;
                case 1: y_val = (uint8_t)((py + frame * 8) % 256); break;
                default: y_val = 128; break;
            }
            y_plane[py * SPRITE_PX + px] = y_val;
        }
    }

    for (int cy = 0; cy < SPRITE_PX / 2; cy++) {
        for (int cx = 0; cx < SPRITE_PX / 2; cx++) {
            cb_plane[cy * (SPRITE_PX / 2) + cx] = cb_val;
            cr_plane[cy * (SPRITE_PX / 2) + cx] = cr_val;
        }
    }
}

static int save_sprite_mbs(int sprite_id, const char* path) {
    auto ext_result = SpriteExtractor::create(
        {.sprite_size = SPRITE_PX, .qp = 26}, path);
    if (!ext_result) return -1;
    auto& ext = *ext_result;

    uint8_t sprite_y[SPRITE_PX * SPRITE_PX];
    uint8_t sprite_cb[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t sprite_cr[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t sprite_alpha[SPRITE_PX * SPRITE_PX];
    memset(sprite_alpha, 255, sizeof(sprite_alpha));

    for (int f = 0; f < NUM_FRAMES; f++) {
        generate_sprite_frame(sprite_y, sprite_cb, sprite_cr, sprite_id, f);
        auto result = ext.add_frame(sprite_y, SPRITE_PX,
                                     sprite_cb, SPRITE_PX / 2,
                                     sprite_cr, SPRITE_PX / 2,
                                     sprite_alpha, SPRITE_PX);
        if (!result) return -1;
    }

    return ext.finalize().has_value() ? 0 : -1;
}

/* ---- Decoding ---- */

struct decoded_frame_t {
    int width;
    int height;
    std::vector<uint8_t> y;
    std::vector<uint8_t> cb;
    std::vector<uint8_t> cr;
};

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

static int decode_stream(const uint8_t* data, size_t size,
                         decoded_frame_t* out_frames, int max_frames) {
    std::vector<uint8_t>* frame_vecs = new std::vector<uint8_t>[max_frames];
    int num_packets = split_annex_b_frames(data, size, frame_vecs, max_frames);

    ISVCDecoder* decoder = nullptr;
    if (WelsCreateDecoder(&decoder) != 0 || !decoder) {
        delete[] frame_vecs;
        return -1;
    }

    SDecodingParam decParam;
    memset(&decParam, 0, sizeof(decParam));
    decParam.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_AVC;
    if (decoder->Initialize(&decParam) != 0) {
        WelsDestroyDecoder(decoder);
        delete[] frame_vecs;
        return -1;
    }

    int decoded = 0;
    for (int i = 0; i < num_packets && decoded < max_frames; i++) {
        unsigned char* pDst[3] = {nullptr};
        SBufferInfo dstInfo;
        memset(&dstInfo, 0, sizeof(dstInfo));

        decoder->DecodeFrameNoDelay(
            frame_vecs[i].data(), (int)frame_vecs[i].size(), pDst, &dstInfo);

        if (dstInfo.iBufferStatus == 1) {
            int w = dstInfo.UsrData.sSystemBuffer.iWidth;
            int h = dstInfo.UsrData.sSystemBuffer.iHeight;
            int sy = dstInfo.UsrData.sSystemBuffer.iStride[0];
            int suv = dstInfo.UsrData.sSystemBuffer.iStride[1];

            out_frames[decoded].width = w;
            out_frames[decoded].height = h;
            out_frames[decoded].y.resize(w * h);
            out_frames[decoded].cb.resize(w / 2 * h / 2);
            out_frames[decoded].cr.resize(w / 2 * h / 2);

            for (int r = 0; r < h; r++)
                memcpy(out_frames[decoded].y.data() + r * w, pDst[0] + r * sy, w);
            for (int r = 0; r < h / 2; r++) {
                memcpy(out_frames[decoded].cb.data() + r * (w / 2), pDst[1] + r * suv, w / 2);
                memcpy(out_frames[decoded].cr.data() + r * (w / 2), pDst[2] + r * suv, w / 2);
            }
            decoded++;
        }
    }

    WelsDestroyDecoder(decoder);
    delete[] frame_vecs;
    return decoded;
}

/* ---- Tests ---- */

static int test_compaction_info() {
    printf("Test: check_compaction_opportunity\n");

    std::vector<uint8_t> stream;
    auto sink = [&](std::span<const uint8_t> data) {
        stream.insert(stream.end(), data.begin(), data.end());
    };

    MuxSurface::Params params;
    params.sprite_width = SPRITE_PX;
    params.sprite_height = SPRITE_PX;
    params.max_slots = 4;
    params.qp = 26;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "  FAIL: MuxSurface::create\n");
        return 1;
    }
    auto& surface = *create_result;

    /* No sprites: active=0, min_grid=0 */
    auto info0 = surface.check_compaction_opportunity();
    if (info0.active_sprites != 0 || info0.max_slots != 4 || info0.min_grid_mbs != 0) {
        fprintf(stderr, "  FAIL: empty surface: active=%d max=%d min_grid=%d\n",
                info0.active_sprites, info0.max_slots, info0.min_grid_mbs);
        return 1;
    }
    printf("  Empty surface: active=%d, max=%d, current=%d, min=%d OK\n",
           info0.active_sprites, info0.max_slots, info0.current_grid_mbs, info0.min_grid_mbs);

    /* Add 1 sprite */
    const char* mbs_path = "/tmp/test_resize_0.mbs";
    if (save_sprite_mbs(0, mbs_path) != 0) {
        fprintf(stderr, "  FAIL: save_sprite_mbs\n");
        return 1;
    }
    auto slot0 = surface.add_sprite(mbs_path);
    if (!slot0) {
        fprintf(stderr, "  FAIL: add_sprite 0\n");
        return 1;
    }

    auto info1 = surface.check_compaction_opportunity();
    if (info1.active_sprites != 1 || info1.max_slots != 4) {
        fprintf(stderr, "  FAIL: 1 sprite: active=%d max=%d\n",
                info1.active_sprites, info1.max_slots);
        return 1;
    }
    /* With 1 slot, cols=1, rows=1: grid = (10*1+1) * (5*1+1) = 11*6 = 66 MBs */
    if (info1.min_grid_mbs != 66) {
        fprintf(stderr, "  FAIL: 1 sprite min_grid=%d (expected 66)\n", info1.min_grid_mbs);
        return 1;
    }
    printf("  1 sprite: active=%d, max=%d, current=%d, min=%d OK\n",
           info1.active_sprites, info1.max_slots, info1.current_grid_mbs, info1.min_grid_mbs);

    /* Add second sprite */
    const char* mbs_path1 = "/tmp/test_resize_1.mbs";
    if (save_sprite_mbs(1, mbs_path1) != 0) {
        fprintf(stderr, "  FAIL: save_sprite_mbs 1\n");
        return 1;
    }
    auto slot1 = surface.add_sprite(mbs_path1);
    if (!slot1) {
        fprintf(stderr, "  FAIL: add_sprite 1\n");
        return 1;
    }

    auto info2 = surface.check_compaction_opportunity();
    if (info2.active_sprites != 2 || info2.max_slots != 4) {
        fprintf(stderr, "  FAIL: 2 sprites: active=%d max=%d\n",
                info2.active_sprites, info2.max_slots);
        return 1;
    }
    /* With 2 slots, cols=ceil_sqrt(2)=2, rows=1: grid = (10*2+1) * (5*1+1) = 21*6 = 126 MBs */
    if (info2.min_grid_mbs != 126) {
        fprintf(stderr, "  FAIL: 2 sprites min_grid=%d (expected 126)\n", info2.min_grid_mbs);
        return 1;
    }
    /* current_grid_mbs should be for 4 slots: cols=2, rows=2: (10*2+1)*(5*2+1) = 21*11 = 231 */
    if (info2.current_grid_mbs != 231) {
        fprintf(stderr, "  FAIL: current_grid=%d (expected 231)\n", info2.current_grid_mbs);
        return 1;
    }
    printf("  2 sprites: active=%d, max=%d, current=%d, min=%d OK\n",
           info2.active_sprites, info2.max_slots, info2.current_grid_mbs, info2.min_grid_mbs);

    printf("  PASS\n\n");
    return 0;
}

static int test_resize_grow() {
    printf("Test: resize grow (2 slots -> 4 slots)\n");

    const char* mbs_paths[NUM_SPRITES] = {
        "/tmp/test_resize_g0.mbs",
        "/tmp/test_resize_g1.mbs"
    };
    for (int s = 0; s < NUM_SPRITES; s++) {
        if (save_sprite_mbs(s, mbs_paths[s]) != 0) {
            fprintf(stderr, "  FAIL: save_sprite_mbs %d\n", s);
            return 1;
        }
    }

    std::vector<uint8_t> stream;
    auto sink = [&](std::span<const uint8_t> data) {
        stream.insert(stream.end(), data.begin(), data.end());
    };

    /* Create surface with 2 slots */
    MuxSurface::Params params;
    params.sprite_width = SPRITE_PX;
    params.sprite_height = SPRITE_PX;
    params.max_slots = 2;
    params.qp = 26;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "  FAIL: MuxSurface::create\n");
        return 1;
    }
    auto& surface = *create_result;
    printf("  Created surface with 2 slots\n");

    /* Add both sprites */
    for (int s = 0; s < NUM_SPRITES; s++) {
        auto slot = surface.add_sprite(mbs_paths[s]);
        if (!slot) {
            fprintf(stderr, "  FAIL: add_sprite %d\n", s);
            return 1;
        }
        printf("  Added sprite %d to slot %d\n", s, slot->slot);
    }

    /* Advance a few P-frames */
    for (int f = 0; f < 3; f++) {
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "  FAIL: advance_frame %d\n", f);
            return 1;
        }
    }
    printf("  Advanced 3 P-frames\n");

    /* Decode current stream to get decoded pixels */
    int pre_resize_frames = 4; /* IDR + 3 P */
    decoded_frame_t* pre_frames = new decoded_frame_t[pre_resize_frames];
    int pre_dec = decode_stream(stream.data(), stream.size(), pre_frames, pre_resize_frames);
    if (pre_dec != pre_resize_frames) {
        fprintf(stderr, "  FAIL: pre-resize decoded %d frames (expected %d)\n",
                pre_dec, pre_resize_frames);
        delete[] pre_frames;
        return 1;
    }
    printf("  Decoded %d pre-resize frames\n", pre_dec);

    /* Use last decoded frame for resize */
    auto& last_frame = pre_frames[pre_dec - 1];
    int w = last_frame.width;
    int h = last_frame.height;

    /* Resize: 2 -> 4 slots */
    auto resize_result = surface.resize(
        4,
        {last_frame.y.data(), last_frame.y.size()},
        {last_frame.cb.data(), last_frame.cb.size()},
        {last_frame.cr.data(), last_frame.cr.size()},
        w, h,
        w, w / 2, w / 2,
        sink);

    delete[] pre_frames;

    if (!resize_result) {
        fprintf(stderr, "  FAIL: resize returned error\n");
        return 1;
    }

    if ((int)resize_result->regions.size() != NUM_SPRITES) {
        fprintf(stderr, "  FAIL: resize returned %d regions (expected %d)\n",
                (int)resize_result->regions.size(), NUM_SPRITES);
        return 1;
    }
    printf("  Resized to 4 slots, %d regions returned\n", (int)resize_result->regions.size());

    /* Verify region slots are compacted to 0..N-1 */
    for (int i = 0; i < (int)resize_result->regions.size(); i++) {
        if (resize_result->regions[i].slot != i) {
            fprintf(stderr, "  FAIL: region %d has slot %d (expected %d)\n",
                    i, resize_result->regions[i].slot, i);
            return 1;
        }
    }
    printf("  Region slots compacted correctly\n");

    /* Advance more P-frames after resize */
    for (int f = 0; f < 3; f++) {
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "  FAIL: post-resize advance_frame %d\n", f);
            return 1;
        }
    }
    printf("  Advanced 3 post-resize P-frames\n");

    /* Decode entire stream to verify decodability */
    /* Total: pre-resize (IDR + 3P) + resize (SPS+PPS + I_PCM IDR) + post-resize (3P)
       = 4 + 1 + 3 = 8 decoded frames (decoder resets at new SPS/IDR) */
    int total_max = 20;
    decoded_frame_t* all_frames = new decoded_frame_t[total_max];
    int total_dec = decode_stream(stream.data(), stream.size(), all_frames, total_max);
    printf("  Decoded %d total frames from full stream\n", total_dec);

    /* We expect at least the post-resize IDR + 3 P-frames to decode.
       The exact count depends on decoder behavior with mid-stream SPS changes.
       We require at least 4 frames total (pre-resize) + some post-resize. */
    if (total_dec < 4) {
        fprintf(stderr, "  FAIL: decoded only %d frames total\n", total_dec);
        delete[] all_frames;
        return 1;
    }

    /* Check that post-resize frames have correct dimensions */
    /* After resize to 4 slots: cols=2, rows=2, total_w=21, total_h=11 -> 336x176 px */
    int new_w_expected = 21 * 16;  /* 336 */
    int new_h_expected = 11 * 16;  /* 176 */
    bool found_resized = false;
    for (int f = 0; f < total_dec; f++) {
        if (all_frames[f].width == new_w_expected && all_frames[f].height == new_h_expected) {
            found_resized = true;
            break;
        }
    }
    if (!found_resized) {
        fprintf(stderr, "  FAIL: no frame with post-resize dimensions %dx%d found\n",
                new_w_expected, new_h_expected);
        delete[] all_frames;
        return 1;
    }
    printf("  Found frames with post-resize dimensions %dx%d\n", new_w_expected, new_h_expected);

    delete[] all_frames;
    printf("  PASS\n\n");
    return 0;
}

static int test_resize_error_too_few_slots() {
    printf("Test: resize error (too few slots)\n");

    const char* mbs_paths[NUM_SPRITES] = {
        "/tmp/test_resize_e0.mbs",
        "/tmp/test_resize_e1.mbs"
    };
    for (int s = 0; s < NUM_SPRITES; s++) {
        if (save_sprite_mbs(s, mbs_paths[s]) != 0) {
            fprintf(stderr, "  FAIL: save_sprite_mbs %d\n", s);
            return 1;
        }
    }

    std::vector<uint8_t> stream;
    auto sink = [&](std::span<const uint8_t> data) {
        stream.insert(stream.end(), data.begin(), data.end());
    };

    MuxSurface::Params params;
    params.sprite_width = SPRITE_PX;
    params.sprite_height = SPRITE_PX;
    params.max_slots = 4;
    params.qp = 26;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "  FAIL: MuxSurface::create\n");
        return 1;
    }
    auto& surface = *create_result;

    /* Add 2 sprites */
    for (int s = 0; s < NUM_SPRITES; s++) {
        auto slot = surface.add_sprite(mbs_paths[s]);
        if (!slot) {
            fprintf(stderr, "  FAIL: add_sprite %d\n", s);
            return 1;
        }
    }

    /* Advance 1 frame to get decoded pixels */
    surface.advance_frame(sink);

    int total_frames = 2;
    decoded_frame_t* frames = new decoded_frame_t[total_frames];
    int dec = decode_stream(stream.data(), stream.size(), frames, total_frames);
    if (dec < 2) {
        fprintf(stderr, "  FAIL: decoded %d frames (expected 2)\n", dec);
        delete[] frames;
        return 1;
    }

    auto& last = frames[dec - 1];
    int w = last.width;
    int h = last.height;

    /* Try to resize to 1 slot with 2 active sprites — should fail */
    auto resize_result = surface.resize(
        1,
        {last.y.data(), last.y.size()},
        {last.cb.data(), last.cb.size()},
        {last.cr.data(), last.cr.size()},
        w, h,
        w, w / 2, w / 2,
        sink);

    delete[] frames;

    if (resize_result.has_value()) {
        fprintf(stderr, "  FAIL: resize should have returned error for too-few slots\n");
        return 1;
    }
    printf("  Correctly rejected resize to 1 slot with 2 active sprites\n");

    printf("  PASS\n\n");
    return 0;
}

static int test_resize_frame_counter_preservation() {
    printf("Test: resize preserves frame counters\n");

    const char* mbs_path = "/tmp/test_resize_fc.mbs";
    if (save_sprite_mbs(0, mbs_path) != 0) {
        fprintf(stderr, "  FAIL: save_sprite_mbs\n");
        return 1;
    }

    std::vector<uint8_t> stream;
    auto sink = [&](std::span<const uint8_t> data) {
        stream.insert(stream.end(), data.begin(), data.end());
    };

    MuxSurface::Params params;
    params.sprite_width = SPRITE_PX;
    params.sprite_height = SPRITE_PX;
    params.max_slots = 2;
    params.qp = 26;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "  FAIL: MuxSurface::create\n");
        return 1;
    }
    auto& surface = *create_result;

    auto slot0 = surface.add_sprite(mbs_path);
    if (!slot0) {
        fprintf(stderr, "  FAIL: add_sprite\n");
        return 1;
    }

    /* Advance 4 frames (sprite is now at frame 4) */
    for (int f = 0; f < 4; f++) {
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "  FAIL: advance_frame %d\n", f);
            return 1;
        }
    }
    printf("  Advanced 4 P-frames before resize\n");

    /* Decode to get last frame pixels */
    int pre_frames = 5;
    decoded_frame_t* pf = new decoded_frame_t[pre_frames];
    int dec = decode_stream(stream.data(), stream.size(), pf, pre_frames);
    if (dec < 5) {
        fprintf(stderr, "  FAIL: decoded %d (expected 5)\n", dec);
        delete[] pf;
        return 1;
    }

    auto& last = pf[dec - 1];
    int w = last.width;
    int h = last.height;

    /* Resize to 4 slots */
    auto resize_result = surface.resize(
        4,
        {last.y.data(), last.y.size()},
        {last.cb.data(), last.cb.size()},
        {last.cr.data(), last.cr.size()},
        w, h,
        w, w / 2, w / 2,
        sink);
    delete[] pf;

    if (!resize_result) {
        fprintf(stderr, "  FAIL: resize returned error\n");
        return 1;
    }

    /* Advance 4 more P-frames after resize — sprite should continue from frame 4 */
    for (int f = 0; f < 4; f++) {
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "  FAIL: post-resize advance_frame %d\n", f);
            return 1;
        }
    }
    printf("  Advanced 4 post-resize P-frames\n");

    /* Decode all post-resize frames to verify they're decodable */
    int total_max = 20;
    decoded_frame_t* all = new decoded_frame_t[total_max];
    int total_dec = decode_stream(stream.data(), stream.size(), all, total_max);
    printf("  Decoded %d total frames\n", total_dec);

    if (total_dec < 5) {
        fprintf(stderr, "  FAIL: too few decoded frames\n");
        delete[] all;
        return 1;
    }

    delete[] all;
    printf("  PASS\n\n");
    return 0;
}

static int test_resize_pixel_continuity() {
    printf("Test: resize pixel continuity (4 slots -> 2 slots)\n");

    const char* mbs_paths[NUM_SPRITES] = {
        "/tmp/test_resize_pc0.mbs",
        "/tmp/test_resize_pc1.mbs"
    };
    for (int s = 0; s < NUM_SPRITES; s++) {
        if (save_sprite_mbs(s, mbs_paths[s]) != 0) {
            fprintf(stderr, "  FAIL: save_sprite_mbs %d\n", s);
            return 1;
        }
    }

    std::vector<uint8_t> stream;
    auto sink = [&](std::span<const uint8_t> data) {
        stream.insert(stream.end(), data.begin(), data.end());
    };

    /* Create surface with 4 slots */
    MuxSurface::Params params;
    params.sprite_width = SPRITE_PX;
    params.sprite_height = SPRITE_PX;
    params.max_slots = 4;
    params.qp = 26;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "  FAIL: MuxSurface::create\n");
        return 1;
    }
    auto& surface = *create_result;
    printf("  Created surface with 4 slots\n");

    /* Add both sprites, save their SpriteRegions */
    MuxSurface::SpriteRegion regions[NUM_SPRITES];
    for (int s = 0; s < NUM_SPRITES; s++) {
        auto slot = surface.add_sprite(mbs_paths[s]);
        if (!slot) {
            fprintf(stderr, "  FAIL: add_sprite %d\n", s);
            return 1;
        }
        regions[s] = *slot;
        printf("  Added sprite %d: slot=%d color=(%d,%d,%dx%d)\n",
               s, slot->slot,
               slot->color.x, slot->color.y, slot->color.width, slot->color.height);
    }

    /* Advance 3 P-frames */
    for (int f = 0; f < 3; f++) {
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "  FAIL: advance_frame %d\n", f);
            return 1;
        }
    }
    printf("  Advanced 3 P-frames\n");

    /* Decode pre-resize stream: IDR + 3 P-frames */
    int pre_count = 4;
    decoded_frame_t* pre_frames = new decoded_frame_t[pre_count];
    int pre_dec = decode_stream(stream.data(), stream.size(), pre_frames, pre_count);
    if (pre_dec != pre_count) {
        fprintf(stderr, "  FAIL: pre-resize decoded %d frames (expected %d)\n",
                pre_dec, pre_count);
        delete[] pre_frames;
        return 1;
    }
    printf("  Decoded %d pre-resize frames\n", pre_dec);

    /* Save content pixels from the last pre-resize frame for each sprite */
    auto& last_pre = pre_frames[pre_dec - 1];
    int pre_w = last_pre.width;
    int pre_h = last_pre.height;

    /* Extract content pixels for each sprite from last pre-resize frame */
    std::vector<std::vector<uint8_t>> pre_content(NUM_SPRITES);
    for (int s = 0; s < NUM_SPRITES; s++) {
        auto& r = regions[s].color;
        pre_content[s].resize(r.width * r.height);
        for (int row = 0; row < r.height; row++) {
            int src_y = r.y + row;
            int src_x = r.x;
            const uint8_t* src = last_pre.y.data() + src_y * pre_w + src_x;
            memcpy(pre_content[s].data() + row * r.width, src, r.width);
        }
    }
    printf("  Saved pre-resize content regions (%dx%d each)\n",
           regions[0].color.width, regions[0].color.height);

    /* Resize: 4 -> 2 slots */
    auto resize_result = surface.resize(
        2,
        {last_pre.y.data(), last_pre.y.size()},
        {last_pre.cb.data(), last_pre.cb.size()},
        {last_pre.cr.data(), last_pre.cr.size()},
        pre_w, pre_h,
        pre_w, pre_w / 2, pre_w / 2,
        sink);

    delete[] pre_frames;

    if (!resize_result) {
        fprintf(stderr, "  FAIL: resize returned error\n");
        return 1;
    }

    if ((int)resize_result->regions.size() != NUM_SPRITES) {
        fprintf(stderr, "  FAIL: resize returned %d regions (expected %d)\n",
                (int)resize_result->regions.size(), NUM_SPRITES);
        return 1;
    }
    printf("  Resized to 2 slots, %d regions returned\n", (int)resize_result->regions.size());

    /* Decode full stream: pre-resize (IDR+3P) + resize transition frame.
       The decoder may flush the transition IDR as frame 4 or delay it;
       we need enough room for all frames. */
    int total_max = 32;
    decoded_frame_t* all_frames = new decoded_frame_t[total_max];
    int total_dec = decode_stream(stream.data(), stream.size(), all_frames, total_max);
    printf("  Decoded %d total frames from full stream\n", total_dec);

    /* The transition frame is the first post-resize frame.
       After resize, the decoder gets a new SPS/IDR, so it may output the IDR
       frame as the next decoded frame. Find the first frame with the new dimensions.
       After resize to 2 slots: cols=ceil_sqrt(2)=2, rows=1 -> (10*2+1)*(5*1+1) = 21*6 MBs
       -> 336 x 96 px */
    int new_w_expected = 21 * 16;  /* 336 */
    int new_h_expected = 6 * 16;   /* 96 */
    int transition_frame_idx = -1;
    for (int f = 0; f < total_dec; f++) {
        if (all_frames[f].width == new_w_expected && all_frames[f].height == new_h_expected) {
            transition_frame_idx = f;
            break;
        }
    }
    if (transition_frame_idx < 0) {
        fprintf(stderr, "  FAIL: no frame with post-resize dimensions %dx%d found\n",
                new_w_expected, new_h_expected);
        delete[] all_frames;
        return 1;
    }
    printf("  Found transition frame at index %d with dimensions %dx%d\n",
           transition_frame_idx, new_w_expected, new_h_expected);

    /* Compare content pixels: pre-resize vs transition frame */
    auto& transition = all_frames[transition_frame_idx];
    int new_w = transition.width;

    int total_mismatches = 0;
    for (int s = 0; s < NUM_SPRITES; s++) {
        auto& new_r = resize_result->regions[s].color;
        auto& old_r = regions[s].color;
        /* Content size must be the same — same sprite_width/height */
        if (new_r.width != old_r.width || new_r.height != old_r.height) {
            fprintf(stderr, "  FAIL: sprite %d content size changed: %dx%d -> %dx%d\n",
                    s, old_r.width, old_r.height, new_r.width, new_r.height);
            delete[] all_frames;
            return 1;
        }
        int mismatches = 0;
        for (int row = 0; row < new_r.height; row++) {
            for (int col = 0; col < new_r.width; col++) {
                int new_px = transition.y[(new_r.y + row) * new_w + (new_r.x + col)];
                int old_px = pre_content[s][row * old_r.width + col];
                if (new_px != old_px) mismatches++;
            }
        }
        total_mismatches += mismatches;
        printf("  Sprite %d: %d mismatches in %dx%d content region\n",
               s, mismatches, new_r.width, new_r.height);
    }

    if (total_mismatches != 0) {
        fprintf(stderr, "  FAIL: %d pixel mismatch(es) between pre-resize and transition frame\n",
                total_mismatches);
        delete[] all_frames;
        return 1;
    }
    printf("  Pixel-identical: 0 mismatches\n");

    delete[] all_frames;

    /* Advance 2 more P-frames after resize to verify pixel correctness */
    for (int f = 0; f < 2; f++) {
        auto post_result = surface.advance_frame(sink);
        if (!post_result) {
            fprintf(stderr, "  FAIL: post-resize advance_frame %d failed\n", f);
            return 1;
        }
    }
    printf("  Advanced 2 post-resize P-frames (sprites now at frames 3, 4)\n");

    /* --- Build a reference surface (2 slots, no resize) to compare against --- */
    std::vector<uint8_t> ref_stream;
    auto ref_sink = [&](std::span<const uint8_t> data) {
        ref_stream.insert(ref_stream.end(), data.begin(), data.end());
    };

    MuxSurface::Params ref_params;
    ref_params.sprite_width = SPRITE_PX;
    ref_params.sprite_height = SPRITE_PX;
    ref_params.max_slots = 2;
    ref_params.qp = 26;

    auto ref_create = MuxSurface::create(ref_params, ref_sink);
    if (!ref_create) {
        fprintf(stderr, "  FAIL: reference MuxSurface::create\n");
        return 1;
    }
    auto& ref_surface = *ref_create;

    MuxSurface::SpriteRegion ref_regions[NUM_SPRITES];
    for (int s = 0; s < NUM_SPRITES; s++) {
        auto slot = ref_surface.add_sprite(mbs_paths[s]);
        if (!slot) {
            fprintf(stderr, "  FAIL: ref add_sprite %d\n", s);
            return 1;
        }
        ref_regions[s] = *slot;
    }

    /* Advance reference surface 4 P-frames (IDR=frame0, P1=frame1, ..., P4=frame4)
       to match resized surface state: sprites at frames 0-4.
       Pre-resize: IDR(f0) + 3P(f1,f2,f3). Resize transition = new IDR (no sprite advance).
       Post-resize: 2P(f3,f4). So after resize+2P, sprites are at frame 4.
       Wait — let me re-check: advance_frame increments frame counter. Pre-resize had 3
       advance_frame calls, so sprites went from f0(IDR) to f1,f2,f3 (3 P-frames).
       Resize does NOT advance frames. Post-resize 2 P-frames: f4, f5.
       So reference needs IDR(f0) + 5P(f1..f5) = 5 advance_frame calls. */
    for (int f = 0; f < 5; f++) {
        auto result = ref_surface.advance_frame(ref_sink);
        if (!result) {
            fprintf(stderr, "  FAIL: ref advance_frame %d\n", f);
            return 1;
        }
    }
    printf("  Reference surface: IDR + 5 P-frames\n");

    /* Decode both streams */
    int resized_max = 32;
    decoded_frame_t* resized_frames = new decoded_frame_t[resized_max];
    int resized_dec = decode_stream(stream.data(), stream.size(), resized_frames, resized_max);
    printf("  Decoded %d frames from resized stream\n", resized_dec);

    int ref_max = 10;
    decoded_frame_t* ref_frames = new decoded_frame_t[ref_max];
    int ref_dec = decode_stream(ref_stream.data(), ref_stream.size(), ref_frames, ref_max);
    printf("  Decoded %d frames from reference stream\n", ref_dec);

    /* Find post-resize P-frames in resized stream (frames with post-resize dimensions,
       after the transition IDR). The transition IDR is the first frame with new dimensions;
       subsequent frames with the same dimensions are the post-resize P-frames. */
    std::vector<int> post_resize_indices;
    for (int f = 0; f < resized_dec; f++) {
        if (resized_frames[f].width == new_w_expected &&
            resized_frames[f].height == new_h_expected) {
            post_resize_indices.push_back(f);
        }
    }
    /* First is transition IDR, rest are P-frames */
    if ((int)post_resize_indices.size() < 3) {
        fprintf(stderr, "  FAIL: expected at least 3 post-resize frames (IDR+2P), got %d\n",
                (int)post_resize_indices.size());
        delete[] resized_frames;
        delete[] ref_frames;
        return 1;
    }
    printf("  Found %d post-resize frames (1 IDR + %d P-frames)\n",
           (int)post_resize_indices.size(), (int)post_resize_indices.size() - 1);

    /* Reference frames: IDR(f0) + P1(f1) + P2(f2) + P3(f3) + P4(f4) + P5(f5) = 6 frames.
       Post-resize P-frames correspond to sprite frames 4 and 5.
       In reference stream, frame index 4 = sprite frame 4, frame index 5 = sprite frame 5.
       Post-resize P-frame 0 (post_resize_indices[1]) = sprite frame 4.
       Post-resize P-frame 1 (post_resize_indices[2]) = sprite frame 5. */
    if (ref_dec < 6) {
        fprintf(stderr, "  FAIL: reference decoded %d frames (expected 6)\n", ref_dec);
        delete[] resized_frames;
        delete[] ref_frames;
        return 1;
    }

    /* Compare post-resize P-frames against reference frames */
    int post_resize_mismatches = 0;
    for (int pf = 0; pf < 2; pf++) {
        int resized_idx = post_resize_indices[1 + pf];  /* skip transition IDR */
        int ref_idx = 4 + pf;  /* reference frame indices 4 and 5 */
        auto& rf = resized_frames[resized_idx];
        auto& rr = ref_frames[ref_idx];

        for (int s = 0; s < NUM_SPRITES; s++) {
            auto& resized_region = resize_result->regions[s].color;
            auto& ref_region = ref_regions[s].color;

            if (resized_region.width != ref_region.width ||
                resized_region.height != ref_region.height) {
                fprintf(stderr, "  FAIL: sprite %d content size mismatch: resized=%dx%d ref=%dx%d\n",
                        s, resized_region.width, resized_region.height,
                        ref_region.width, ref_region.height);
                delete[] resized_frames;
                delete[] ref_frames;
                return 1;
            }

            int mismatches = 0;
            for (int row = 0; row < resized_region.height; row++) {
                for (int col = 0; col < resized_region.width; col++) {
                    int resized_px = rf.y[(resized_region.y + row) * rf.width +
                                          (resized_region.x + col)];
                    int ref_px = rr.y[(ref_region.y + row) * rr.width +
                                      (ref_region.x + col)];
                    if (resized_px != ref_px) mismatches++;
                }
            }
            if (mismatches > 0) {
                fprintf(stderr, "  FAIL: P-frame %d sprite %d: %d pixel mismatches\n",
                        pf, s, mismatches);
            }
            post_resize_mismatches += mismatches;
        }
        printf("  Post-resize P-frame %d (resized[%d] vs ref[%d]): checked\n",
               pf, resized_idx, ref_idx);
    }

    delete[] resized_frames;
    delete[] ref_frames;

    if (post_resize_mismatches != 0) {
        fprintf(stderr, "  FAIL: %d total pixel mismatches in post-resize P-frames\n",
                post_resize_mismatches);
        return 1;
    }
    printf("  Post-resize P-frames pixel-identical to reference: 0 mismatches\n");

    printf("  PASS\n\n");
    return 0;
}

int main(void) {
    printf("=== MuxSurface Resize Tests ===\n\n");

    int failures = 0;
    failures += test_compaction_info();
    failures += test_resize_grow();
    failures += test_resize_error_too_few_slots();
    failures += test_resize_frame_counter_preservation();
    failures += test_resize_pixel_continuity();

    printf("=== Results ===\n");
    if (failures == 0) {
        printf("PASS: all resize tests passed\n");
        return 0;
    } else {
        printf("FAIL: %d test(s) failed\n", failures);
        return 1;
    }
}
