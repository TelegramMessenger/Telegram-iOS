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

#define NUM_SPRITES   3
#define NUM_FRAMES    8
#define SPRITE_PX     64
#define PADDED_PX     96
#define CANVAS_PX     192  /* PADDED_PX * 2 (double-wide) */
#define SPRITE_MBS    4
#define PADDED_MBS    6
#define CANVAS_MBS    12   /* PADDED_MBS * 2 (double-wide) */
#define PADDING_MBS   1
#define LOOP_FRAMES   16   // 2× NUM_FRAMES for looping test

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
                case 2: y_val = (uint8_t)((px + py + frame * 8) % 256); break;
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

struct sprite_result_t {
    std::vector<uint8_t> frame_nal_data[NUM_FRAMES];
};

static int encode_sprite(int sprite_id, sprite_result_t* out) {
    auto enc_result = SpriteEncoder::create({SPRITE_PX, SPRITE_PX, 26});
    if (!enc_result) return -1;
    auto& enc = *enc_result;

    uint8_t sprite_y[SPRITE_PX * SPRITE_PX];
    uint8_t sprite_cb[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t sprite_cr[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t canvas_y[PADDED_PX * PADDED_PX];
    uint8_t canvas_cb[PADDED_PX / 2 * PADDED_PX / 2];
    uint8_t canvas_cr[PADDED_PX / 2 * PADDED_PX / 2];

    for (int f = 0; f < NUM_FRAMES; f++) {
        generate_sprite_frame(sprite_y, sprite_cb, sprite_cr, sprite_id, f);

        // Pad to canvas (Y=0 black, Cb/Cr=128 neutral)
        memset(canvas_y, 0, PADDED_PX * PADDED_PX);
        for (int y = 0; y < SPRITE_PX; y++)
            memcpy(canvas_y + (y + 16) * PADDED_PX + 16, sprite_y + y * SPRITE_PX, SPRITE_PX);

        int chroma_padded = PADDED_PX / 2;
        int chroma_sprite = SPRITE_PX / 2;
        memset(canvas_cb, 128, chroma_padded * chroma_padded);
        memset(canvas_cr, 128, chroma_padded * chroma_padded);
        for (int y = 0; y < chroma_sprite; y++) {
            memcpy(canvas_cb + (y + 8) * chroma_padded + 8, sprite_cb + y * chroma_sprite, chroma_sprite);
            memcpy(canvas_cr + (y + 8) * chroma_padded + 8, sprite_cr + y * chroma_sprite, chroma_sprite);
        }

        // Create opaque alpha buffer
        uint8_t canvas_alpha[PADDED_PX * PADDED_PX];
        memset(canvas_alpha, 255, PADDED_PX * PADDED_PX);

        std::vector<uint8_t> nal;
        auto result = enc.encode(canvas_y, PADDED_PX,
                                  canvas_cb, PADDED_PX / 2,
                                  canvas_cr, PADDED_PX / 2,
                                  canvas_alpha, PADDED_PX,
                                  f, &nal);
        if (!result) return -1;
        out->frame_nal_data[f] = std::move(nal);
    }

    return 0;
}

/* ---- Save sprite to .mbs temp file ---- */

static int save_sprite_mbs(int sprite_id, const char* path) {
    auto ext_result = SpriteExtractor::create(
        {.sprite_size = SPRITE_PX, .qp = 26}, path);
    if (!ext_result) return -1;
    auto& ext = *ext_result;

    uint8_t sprite_y[SPRITE_PX * SPRITE_PX];
    uint8_t sprite_cb[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t sprite_cr[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t sprite_alpha[SPRITE_PX * SPRITE_PX];
    memset(sprite_alpha, 255, sizeof(sprite_alpha));  // opaque

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
            int stride_y = dstInfo.UsrData.sSystemBuffer.iStride[0];
            int stride_uv = dstInfo.UsrData.sSystemBuffer.iStride[1];

            out_frames[decoded].width = w;
            out_frames[decoded].height = h;
            out_frames[decoded].y.resize(w * h);
            out_frames[decoded].cb.resize(w / 2 * h / 2);
            out_frames[decoded].cr.resize(w / 2 * h / 2);

            for (int r = 0; r < h; r++)
                memcpy(out_frames[decoded].y.data() + r * w, pDst[0] + r * stride_y, w);
            for (int r = 0; r < h / 2; r++) {
                memcpy(out_frames[decoded].cb.data() + r * (w / 2), pDst[1] + r * stride_uv, w / 2);
                memcpy(out_frames[decoded].cr.data() + r * (w / 2), pDst[2] + r * stride_uv, w / 2);
            }
            decoded++;
        }
    }

    WelsDestroyDecoder(decoder);
    delete[] frame_vecs;
    return decoded;
}

/* ---- Reference: decode a single sprite's NAL stream independently ---- */

static int decode_sprite_ref(sprite_result_t* sprite, decoded_frame_t* out_frames) {
    // NAL data is from double-wide canvas (CANVAS_MBS x PADDED_MBS)
    FrameParams fp;
    fp.width_mbs = CANVAS_MBS;
    fp.height_mbs = PADDED_MBS;
    fp.qp = 26;
    fp.log2_max_frame_num = 4;

    uint8_t hdr[128];
    size_t hdr_size = frame_writer::write_headers({hdr, sizeof(hdr)}, fp);

    size_t total = hdr_size;
    for (int f = 0; f < NUM_FRAMES; f++) total += sprite->frame_nal_data[f].size();

    std::vector<uint8_t> stream(total);
    memcpy(stream.data(), hdr, hdr_size);
    size_t off = hdr_size;
    for (int f = 0; f < NUM_FRAMES; f++) {
        memcpy(stream.data() + off, sprite->frame_nal_data[f].data(), sprite->frame_nal_data[f].size());
        off += sprite->frame_nal_data[f].size();
    }

    // Decode double-wide frames, then extract left half (color) into out_frames
    decoded_frame_t wide_frames[NUM_FRAMES];
    int count = decode_stream(stream.data(), total, wide_frames, NUM_FRAMES);

    for (int i = 0; i < count; i++) {
        int w = wide_frames[i].width;
        int h = wide_frames[i].height;
        int half_w = w / 2;

        out_frames[i].width = half_w;
        out_frames[i].height = h;
        out_frames[i].y.resize(half_w * h);
        out_frames[i].cb.resize(half_w / 2 * h / 2);
        out_frames[i].cr.resize(half_w / 2 * h / 2);

        // Extract left half of luma
        for (int r = 0; r < h; r++)
            memcpy(out_frames[i].y.data() + r * half_w,
                   wide_frames[i].y.data() + r * w, half_w);
        // Extract left half of chroma
        for (int r = 0; r < h / 2; r++) {
            memcpy(out_frames[i].cb.data() + r * (half_w / 2),
                   wide_frames[i].cb.data() + r * (w / 2), half_w / 2);
            memcpy(out_frames[i].cr.data() + r * (half_w / 2),
                   wide_frames[i].cr.data() + r * (w / 2), half_w / 2);
        }
    }

    return count;
}

/* ---- Pixel region comparison ---- */

static int compare_sprite_region(const decoded_frame_t* composite, int ox_px, int oy_px,
                                  const decoded_frame_t* reference,
                                  int frame_idx, int sprite_id) {
    int mismatches = 0;
    int comp_w = composite->width;

    for (int py = 0; py < PADDED_PX; py++) {
        for (int px = 0; px < PADDED_PX; px++) {
            int cx = ox_px + px;
            int cy = oy_px + py;
            uint8_t comp_val = composite->y[cy * comp_w + cx];
            uint8_t ref_val = reference->y[py * PADDED_PX + px];
            if (comp_val != ref_val) {
                if (mismatches < 3) {
                    printf("  Y mismatch sprite %d frame %d at (%d,%d): "
                           "composite=%d ref=%d\n",
                           sprite_id, frame_idx, px, py, comp_val, ref_val);
                }
                mismatches++;
            }
        }
    }

    int comp_cw = comp_w / 2;
    int ref_cw = PADDED_PX / 2;
    for (int py = 0; py < PADDED_PX / 2; py++) {
        for (int px = 0; px < PADDED_PX / 2; px++) {
            int cx = ox_px / 2 + px;
            int cy = oy_px / 2 + py;
            if (composite->cb[cy * comp_cw + cx] != reference->cb[py * ref_cw + px])
                mismatches++;
            if (composite->cr[cy * comp_cw + cx] != reference->cr[py * ref_cw + px])
                mismatches++;
        }
    }

    return mismatches;
}

/* ---- Main test ---- */

int main(void) {
    printf("=== Mux Surface End-to-End Test ===\n\n");

    /* Phase 1: Encode sprites and save as .mbs */
    printf("Phase 1: Encoding %d sprites...\n", NUM_SPRITES);

    sprite_result_t sprites[NUM_SPRITES];
    const char* mbs_paths[NUM_SPRITES] = {
        "/tmp/test_mux_surface_0.mbs",
        "/tmp/test_mux_surface_1.mbs",
        "/tmp/test_mux_surface_2.mbs"
    };

    for (int s = 0; s < NUM_SPRITES; s++) {
        if (encode_sprite(s, &sprites[s]) < 0) {
            fprintf(stderr, "FAIL: encode_sprite %d\n", s);
            return 1;
        }
        if (save_sprite_mbs(s, mbs_paths[s]) != 0) {
            fprintf(stderr, "FAIL: save_sprite_mbs %d\n", s);
            return 1;
        }
    }
    printf("  Done.\n");

    /* Phase 2: Decode sprite reference streams */
    printf("\nPhase 2: Decoding reference sprites...\n");

    decoded_frame_t ref_frames[NUM_SPRITES][NUM_FRAMES];
    for (int s = 0; s < NUM_SPRITES; s++) {
        int dec = decode_sprite_ref(&sprites[s], ref_frames[s]);
        if (dec != NUM_FRAMES) {
            fprintf(stderr, "FAIL: sprite %d decoded %d frames (expected %d)\n",
                    s, dec, NUM_FRAMES);
            return 1;
        }
    }
    printf("  Done.\n");

    /* Phase 3: Build composite stream via mux surface */
    printf("\nPhase 3: Building composite via mux surface...\n");

    std::vector<uint8_t> stream;
    auto sink = [&](std::span<const uint8_t> data) {
        stream.insert(stream.end(), data.begin(), data.end());
    };

    /* Create surface: 4 slots, emits SPS+PPS+IDR */
    MuxSurface::Params params;
    params.sprite_width = SPRITE_PX;
    params.sprite_height = SPRITE_PX;
    params.max_slots = 4;
    params.qp = 26;
    params.qp_delta_idr = 0;
    params.qp_delta_p = 0;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "FAIL: MuxSurface::create\n");

        return 1;
    }
    auto& surface = *create_result;
    printf("  Created surface: %zu bytes (SPS+PPS+IDR)\n", stream.size());

    /* Add sprite 0 */
    auto slot0_result = surface.add_sprite(mbs_paths[0]);
    if (!slot0_result) {
        fprintf(stderr, "FAIL: add_sprite 0\n");

        return 1;
    }
    int slot0 = slot0_result->slot;
    printf("  Added sprite 0 to slot %d\n", slot0);

    /* Frames 1-2: sprite 0 playing */
    for (int f = 1; f <= 2; f++) {
        size_t before = stream.size();
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "FAIL: advance_frame %d\n", f);

            return 1;
        }
        printf("  Frame %d: %zu bytes\n", f, stream.size() - before);
    }

    /* Add sprite 1 */
    auto slot1_result = surface.add_sprite(mbs_paths[1]);
    if (!slot1_result) {
        fprintf(stderr, "FAIL: add_sprite 1\n");

        return 1;
    }
    int slot1 = slot1_result->slot;
    printf("  Added sprite 1 to slot %d\n", slot1);

    /* Frames 3-4: sprite 0 + sprite 1 */
    for (int f = 3; f <= 4; f++) {
        size_t before = stream.size();
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "FAIL: advance_frame %d\n", f);

            return 1;
        }
        printf("  Frame %d: %zu bytes\n", f, stream.size() - before);
    }

    /* Remove sprite 0 */
    surface.remove_sprite(slot0);
    printf("  Removed sprite 0 from slot %d\n", slot0);

    /* Frame 5: sprite 1 only, slot 0 is SKIP */
    {
        size_t before = stream.size();
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "FAIL: advance_frame 5\n");

            return 1;
        }
        printf("  Frame 5: %zu bytes\n", stream.size() - before);
    }

    /* Add sprite 2 to reuse slot 0 */
    auto slot2_result = surface.add_sprite(mbs_paths[2]);
    if (!slot2_result) {
        fprintf(stderr, "FAIL: add_sprite 2\n");

        return 1;
    }
    int slot2 = slot2_result->slot;
    printf("  Added sprite 2 to slot %d (reuse)\n", slot2);

    /* Frames 6-7: sprite 2 + sprite 1 */
    for (int f = 6; f <= 7; f++) {
        size_t before = stream.size();
        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "FAIL: advance_frame %d\n", f);

            return 1;
        }
        printf("  Frame %d: %zu bytes\n", f, stream.size() - before);
    }

    printf("  Total composite: %zu bytes, 8 frames (IDR + 7 P)\n", stream.size());

    /* Phase 4: Decode composite */
    printf("\nPhase 4: Decoding composite stream...\n");

    int total_composite_frames = 8;
    decoded_frame_t* comp_frames = new decoded_frame_t[total_composite_frames];
    int dec_count = decode_stream(stream.data(), stream.size(), comp_frames, total_composite_frames);
    printf("  Decoded %d frames\n", dec_count);

    if (dec_count != total_composite_frames) {
        fprintf(stderr, "FAIL: decoded %d frames (expected %d)\n",
                dec_count, total_composite_frames);

        delete[] comp_frames;
        return 1;
    }

    /* Phase 5: Verify pixel content */
    printf("\nPhase 5: Verifying pixels...\n");

    /* slot_w = sprite_w * 2 - padding = 11, stride_x = 10 MBs
     * stride_y = sprite_h - padding = 5 MBs */
    int stride_x_px = (PADDED_MBS * 2 - PADDING_MBS - PADDING_MBS) * 16;
    int stride_y_px = (PADDED_MBS - PADDING_MBS) * 16;
    int cols = 2;

    int slot_ox[4], slot_oy[4];
    for (int i = 0; i < 4; i++) {
        slot_ox[i] = (i % cols) * stride_x_px;
        slot_oy[i] = (i / cols) * stride_y_px;
    }

    int total_mismatches = 0;

    struct { int sprite; int frame; } slot_content[8][4];

    for (int f = 0; f < 8; f++)
        for (int s = 0; s < 4; s++)
            slot_content[f][s] = {-1, -1};

    slot_content[1][0] = {0, 0};
    slot_content[2][0] = {0, 1};
    slot_content[3][0] = {0, 2};
    slot_content[3][1] = {1, 0};
    slot_content[4][0] = {0, 3};
    slot_content[4][1] = {1, 1};
    slot_content[5][0] = {0, 3};
    slot_content[5][1] = {1, 2};
    slot_content[6][0] = {2, 0};
    slot_content[6][1] = {1, 3};
    slot_content[7][0] = {2, 1};
    slot_content[7][1] = {1, 4};

    for (int f = 0; f < 8; f++) {
        for (int s = 0; s < 2; s++) {
            int sp = slot_content[f][s].sprite;
            int sf = slot_content[f][s].frame;

            if (sp < 0) {
                int black_mismatch = 0;
                for (int py = 16; py < 16 + SPRITE_PX; py++) {
                    for (int px = 16; px < 16 + SPRITE_PX; px++) {
                        int cx = slot_ox[s] + px;
                        int cy = slot_oy[s] + py;
                        uint8_t val = comp_frames[f].y[cy * comp_frames[f].width + cx];
                        if (val != 0) black_mismatch++;
                    }
                }
                if (black_mismatch > 0) {
                    printf("  Frame %d slot %d: %d non-black pixels (expected black)\n",
                           f, s, black_mismatch);
                    total_mismatches += black_mismatch;
                }
                continue;
            }

            int mm = compare_sprite_region(&comp_frames[f],
                                            slot_ox[s], slot_oy[s],
                                            &ref_frames[sp][sf],
                                            f, sp);
            if (mm > 0) {
                printf("  Frame %d slot %d (sprite %d frame %d): %d mismatches\n",
                       f, s, sp, sf, mm);
                total_mismatches += mm;
            }
        }
    }

    /* Cleanup */
    delete[] comp_frames;

    /* ================================================================ */
    /* Phase 6: Looping test — 1 sprite, 2 full cycles                  */
    /* ================================================================ */
    printf("\n=== Looping Test ===\n");

    /* Create a new surface with 1 slot */
    std::vector<uint8_t> loop_stream;
    auto loop_sink = [&](std::span<const uint8_t> data) {
        loop_stream.insert(loop_stream.end(), data.begin(), data.end());
    };

    MuxSurface::Params loop_params;
    loop_params.sprite_width = SPRITE_PX;
    loop_params.sprite_height = SPRITE_PX;
    loop_params.max_slots = 1;
    loop_params.qp = 26;
    loop_params.qp_delta_idr = 0;
    loop_params.qp_delta_p = 0;

    auto loop_create = MuxSurface::create(loop_params, loop_sink);
    if (!loop_create) {
        fprintf(stderr, "FAIL: MuxSurface::create (loop test)\n");
        return 1;
    }
    auto& loop_surface = *loop_create;

    /* Add sprite 0 */
    auto loop_slot = loop_surface.add_sprite(mbs_paths[0]);
    if (!loop_slot) {
        fprintf(stderr, "FAIL: add_sprite (loop test)\n");
        return 1;
    }
    printf("  Added sprite 0 to slot %d\n", loop_slot->slot);

    /* Advance LOOP_FRAMES P-frames (2 full cycles of NUM_FRAMES) */
    for (int f = 1; f <= LOOP_FRAMES; f++) {
        auto result = loop_surface.advance_frame(loop_sink);
        if (!result) {
            fprintf(stderr, "FAIL: advance_frame %d (loop test)\n", f);
            return 1;
        }
    }
    printf("  Generated %d P-frames (2 loops of %d)\n", LOOP_FRAMES, NUM_FRAMES);

    /* Decode loop stream */
    int loop_total_frames = 1 + LOOP_FRAMES;  /* IDR + 16 P-frames */
    decoded_frame_t* loop_frames = new decoded_frame_t[loop_total_frames];
    int loop_dec = decode_stream(loop_stream.data(), loop_stream.size(),
                                  loop_frames, loop_total_frames);
    printf("  Decoded %d frames\n", loop_dec);

    if (loop_dec != loop_total_frames) {
        fprintf(stderr, "FAIL: loop test decoded %d frames (expected %d)\n",
                loop_dec, loop_total_frames);
        delete[] loop_frames;
        return 1;
    }

    /* Verify: frame f in cycle 2 must match frame f in cycle 1.
       Cycle 1: composite frames 1..8  (sprite frames 0..7)
       Cycle 2: composite frames 9..16 (sprite frames 0..7, looped)
       Compare full frame pixels (only 1 slot, so compare entire decoded frame). */
    int loop_mismatches = 0;
    for (int f = 0; f < NUM_FRAMES; f++) {
        int c1 = 1 + f;             /* cycle 1 composite frame index */
        int c2 = 1 + NUM_FRAMES + f; /* cycle 2 composite frame index */
        auto& f1 = loop_frames[c1];
        auto& f2 = loop_frames[c2];

        int w = f1.width;
        int h = f1.height;

        /* Y plane */
        for (int i = 0; i < w * h; i++) {
            if (f1.y[i] != f2.y[i]) loop_mismatches++;
        }
        /* Cb plane */
        for (int i = 0; i < (w / 2) * (h / 2); i++) {
            if (f1.cb[i] != f2.cb[i]) loop_mismatches++;
        }
        /* Cr plane */
        for (int i = 0; i < (w / 2) * (h / 2); i++) {
            if (f1.cr[i] != f2.cr[i]) loop_mismatches++;
        }

        if (loop_mismatches > 0) {
            printf("  Loop mismatch at sprite frame %d (composite %d vs %d): %d\n",
                   f, c1, c2, loop_mismatches);
        }
    }

    delete[] loop_frames;

    printf("  Loop pixel mismatches: %d\n", loop_mismatches);
    total_mismatches += loop_mismatches;

    /* Result */
    printf("\n=== Results ===\n");
    printf("  Decoded frames: %d\n", dec_count);
    printf("  Pixel mismatches: %d\n", total_mismatches);

    if (total_mismatches == 0) {
        printf("PASS: mux_surface end-to-end verification\n");
        return 0;
    } else {
        printf("FAIL: pixel mismatches detected\n");
        return 1;
    }
}
