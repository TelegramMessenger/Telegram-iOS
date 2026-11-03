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
#define NUM_FRAMES    4
#define SPRITE_PX     64
#define PADDED_PX     96   /* 64 + 2*16 */
#define CANVAS_PX     192  /* PADDED_PX * 2 (double-wide) */
#define SPRITE_MBS    4    /* 64/16 */
#define PADDED_MBS    6    /* 96/16 */
#define CANVAS_MBS    12   /* PADDED_MBS * 2 (double-wide) */
#define PADDING_MBS   1

/* Alpha MuxSurface layout:
 * slot_w = sprite_w * 2 - padding = 6*2 - 1 = 11 MBs (176px)
 * stride_x = slot_w - padding = 10 MBs (160px)
 * For 2 sprites: cols=2, total_w = 10*2 + 1 = 21 MBs (336px)
 * total_h = 6 MBs (96px)
 */
#define SLOT_W_MBS    11
#define STRIDE_X_MBS  10
#define EXPECTED_W    (STRIDE_X_MBS * 2 + PADDING_MBS)  /* 21 MBs = 336px */
#define EXPECTED_H    PADDED_MBS                          /* 6 MBs = 96px */
#define EXPECTED_W_PX (EXPECTED_W * 16)
#define EXPECTED_H_PX (EXPECTED_H * 16)

/* ---- Sprite generation with varying alpha ---- */

static void generate_sprite_frame(uint8_t* y_plane, uint8_t* cb_plane,
                                  uint8_t* cr_plane, uint8_t* alpha_plane,
                                  int sprite_id, int frame) {
    uint8_t cb_val = (uint8_t)(128 + sprite_id * 30);
    uint8_t cr_val = (uint8_t)(128 - sprite_id * 30);

    for (int py = 0; py < SPRITE_PX; py++) {
        for (int px = 0; px < SPRITE_PX; px++) {
            uint8_t y_val;
            uint8_t a_val;
            switch (sprite_id) {
                case 0:
                    y_val = (uint8_t)((px + frame * 8) % 256);
                    /* Horizontal gradient alpha */
                    a_val = (uint8_t)(px * 255 / 63);
                    break;
                case 1:
                    y_val = (uint8_t)((py + frame * 8) % 256);
                    /* Vertical gradient alpha */
                    a_val = (uint8_t)(py * 255 / 63);
                    break;
                default:
                    y_val = 128;
                    a_val = 255;
                    break;
            }
            y_plane[py * SPRITE_PX + px] = y_val;
            alpha_plane[py * SPRITE_PX + px] = a_val;
        }
    }

    for (int cy = 0; cy < SPRITE_PX / 2; cy++) {
        for (int cx = 0; cx < SPRITE_PX / 2; cx++) {
            cb_plane[cy * (SPRITE_PX / 2) + cx] = cb_val;
            cr_plane[cy * (SPRITE_PX / 2) + cx] = cr_val;
        }
    }
}

/* ---- Encode sprite via SpriteEncoder (captures NAL data for reference decode) ---- */

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
    uint8_t sprite_alpha[SPRITE_PX * SPRITE_PX];
    uint8_t canvas_y[PADDED_PX * PADDED_PX];
    uint8_t canvas_cb[PADDED_PX / 2 * PADDED_PX / 2];
    uint8_t canvas_cr[PADDED_PX / 2 * PADDED_PX / 2];
    uint8_t canvas_alpha[PADDED_PX * PADDED_PX];

    for (int f = 0; f < NUM_FRAMES; f++) {
        generate_sprite_frame(sprite_y, sprite_cb, sprite_cr, sprite_alpha, sprite_id, f);

        /* Pad color to canvas (Y=0 black, Cb/Cr=128 neutral) */
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

        /* Pad alpha (0 = transparent border) */
        memset(canvas_alpha, 0, PADDED_PX * PADDED_PX);
        for (int y = 0; y < SPRITE_PX; y++)
            memcpy(canvas_alpha + (y + 16) * PADDED_PX + 16, sprite_alpha + y * SPRITE_PX, SPRITE_PX);

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

/* ---- Save sprite to .mbs temp file via SpriteExtractor ---- */

static int save_sprite_mbs(int sprite_id, const char* path) {
    auto ext_result = SpriteExtractor::create(
        {.sprite_size = SPRITE_PX, .qp = 26}, path);
    if (!ext_result) return -1;
    auto& ext = *ext_result;

    uint8_t sprite_y[SPRITE_PX * SPRITE_PX];
    uint8_t sprite_cb[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t sprite_cr[SPRITE_PX / 2 * SPRITE_PX / 2];
    uint8_t sprite_alpha[SPRITE_PX * SPRITE_PX];

    for (int f = 0; f < NUM_FRAMES; f++) {
        generate_sprite_frame(sprite_y, sprite_cb, sprite_cr, sprite_alpha, sprite_id, f);
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

/* ---- Reference: decode a single sprite's double-wide NAL stream ---- */

static int decode_sprite_ref(sprite_result_t* sprite, decoded_frame_t* out_frames) {
    /* NAL data is from double-wide canvas (CANVAS_MBS x PADDED_MBS) */
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

    /* Decode double-wide frames -- keep full width for separate color/alpha comparison */
    return decode_stream(stream.data(), total, out_frames, NUM_FRAMES);
}

/* ---- Pixel comparison: compare a region of the composite against a reference frame region ---- */

static int compare_region(const decoded_frame_t* composite, int comp_x, int comp_y,
                          const decoded_frame_t* reference, int ref_x, int ref_y,
                          int w, int h,
                          const char* label, int frame_idx, int sprite_id) {
    int mismatches = 0;
    int comp_stride = composite->width;
    int ref_stride = reference->width;

    /* Y plane */
    for (int py = 0; py < h; py++) {
        for (int px = 0; px < w; px++) {
            int cx = comp_x + px;
            int cy = comp_y + py;
            int rx = ref_x + px;
            int ry = ref_y + py;
            uint8_t comp_val = composite->y[cy * comp_stride + cx];
            uint8_t ref_val = reference->y[ry * ref_stride + rx];
            if (comp_val != ref_val) {
                if (mismatches < 3)
                    printf("  %s Y mismatch sprite %d frame %d at (%d,%d): comp=%d ref=%d\n",
                           label, sprite_id, frame_idx, px, py, comp_val, ref_val);
                mismatches++;
            }
        }
    }

    /* Cb/Cr planes */
    int comp_cstride = comp_stride / 2;
    int ref_cstride = ref_stride / 2;
    int ch = h / 2;
    int cw = w / 2;
    for (int py = 0; py < ch; py++) {
        for (int px = 0; px < cw; px++) {
            int ccx = comp_x / 2 + px;
            int ccy = comp_y / 2 + py;
            int rcx = ref_x / 2 + px;
            int rcy = ref_y / 2 + py;
            if (composite->cb[ccy * comp_cstride + ccx] != reference->cb[rcy * ref_cstride + rcx])
                mismatches++;
            if (composite->cr[ccy * comp_cstride + ccx] != reference->cr[rcy * ref_cstride + rcx])
                mismatches++;
        }
    }

    return mismatches;
}

/* ---- Main test ---- */

int main(void) {
    printf("=== End-to-End Alpha Mux Verification Test ===\n\n");

    /* ================================================================ */
    /* Phase 1: Encode sprites with varying alpha                        */
    /* ================================================================ */
    printf("Phase 1: Encoding %d sprites with alpha...\n", NUM_SPRITES);

    sprite_result_t sprites[NUM_SPRITES];
    const char* mbs_paths[NUM_SPRITES] = {
        "/tmp/test_mux_alpha_0.mbs",
        "/tmp/test_mux_alpha_1.mbs"
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

    /* ================================================================ */
    /* Phase 2: Decode reference streams (double-wide)                   */
    /* ================================================================ */
    printf("\nPhase 2: Decoding reference sprites (double-wide)...\n");

    decoded_frame_t ref_frames[NUM_SPRITES][NUM_FRAMES];
    for (int s = 0; s < NUM_SPRITES; s++) {
        int dec = decode_sprite_ref(&sprites[s], ref_frames[s]);
        if (dec != NUM_FRAMES) {
            fprintf(stderr, "FAIL: sprite %d decoded %d frames (expected %d)\n",
                    s, dec, NUM_FRAMES);
            return 1;
        }
        printf("  Sprite %d: decoded %d frames (%dx%d)\n",
               s, dec, ref_frames[s][0].width, ref_frames[s][0].height);
    }
    printf("  Done.\n");

    /* ================================================================ */
    /* Phase 3: Build composite via MuxSurface with has_alpha=true       */
    /* ================================================================ */
    printf("\nPhase 3: Building composite via mux surface (has_alpha=true)...\n");

    std::vector<uint8_t> stream;
    auto sink = [&](std::span<const uint8_t> data) {
        stream.insert(stream.end(), data.begin(), data.end());
    };

    MuxSurface::Params params;
    params.sprite_width = SPRITE_PX;
    params.sprite_height = SPRITE_PX;
    params.max_slots = NUM_SPRITES;
    params.qp = 26;
    params.qp_delta_idr = 0;
    params.qp_delta_p = 0;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "FAIL: MuxSurface::create\n");
        return 1;
    }
    auto& surface = *create_result;

    printf("  Grid: %d x %d MBs (%d x %d px)\n",
           surface.width_mbs(), surface.height_mbs(),
           surface.width_mbs() * 16, surface.height_mbs() * 16);

    /* Verify expected dimensions */
    if (surface.width_mbs() != EXPECTED_W || surface.height_mbs() != EXPECTED_H) {
        fprintf(stderr, "FAIL: unexpected grid: %d x %d MBs (expected %d x %d)\n",
                surface.width_mbs(), surface.height_mbs(), EXPECTED_W, EXPECTED_H);
        return 1;
    }

    /* Add all sprites */
    for (int s = 0; s < NUM_SPRITES; s++) {
        auto slot = surface.add_sprite(mbs_paths[s]);
        if (!slot.has_value()) {
            fprintf(stderr, "FAIL: add_sprite %d\n", s);
            return 1;
        }
        printf("  Added sprite %d to slot %d\n", s, slot->slot);
    }

    /* Advance NUM_FRAMES P-frames */
    for (int f = 0; f < NUM_FRAMES; f++) {
        auto result = surface.advance_frame(sink);
        if (!result.has_value()) {
            fprintf(stderr, "FAIL: advance_frame %d\n", f);
            return 1;
        }
    }
    printf("  Total composite: %zu bytes, %d frames (IDR + %d P)\n",
           stream.size(), NUM_FRAMES + 1, NUM_FRAMES);

    /* ================================================================ */
    /* Phase 4: Decode composite                                         */
    /* ================================================================ */
    printf("\nPhase 4: Decoding composite stream...\n");

    int total_comp_frames = NUM_FRAMES + 1;  /* 1 IDR + NUM_FRAMES P */
    decoded_frame_t* comp_frames = new decoded_frame_t[total_comp_frames];
    int dec_count = decode_stream(stream.data(), stream.size(), comp_frames, total_comp_frames);
    printf("  Decoded %d frames\n", dec_count);

    if (dec_count != total_comp_frames) {
        fprintf(stderr, "FAIL: decoded %d frames (expected %d)\n",
                dec_count, total_comp_frames);
        delete[] comp_frames;
        return 1;
    }

    /* ================================================================ */
    /* Phase 5: Verify frame dimensions                                  */
    /* ================================================================ */
    printf("\nPhase 5: Verifying frame dimensions...\n");

    for (int f = 0; f < dec_count; f++) {
        if (comp_frames[f].width != EXPECTED_W_PX || comp_frames[f].height != EXPECTED_H_PX) {
            fprintf(stderr, "FAIL: frame %d dimensions %dx%d (expected %dx%d)\n",
                    f, comp_frames[f].width, comp_frames[f].height,
                    EXPECTED_W_PX, EXPECTED_H_PX);
            delete[] comp_frames;
            return 1;
        }
    }
    printf("  All frames %dx%d - OK\n", EXPECTED_W_PX, EXPECTED_H_PX);

    /* ================================================================ */
    /* Phase 6: Verify IDR is all-black                                  */
    /* ================================================================ */
    printf("\nPhase 6: Verifying IDR frame is black...\n");

    int idr_nonblack = 0;
    auto& idr = comp_frames[0];
    for (int i = 0; i < idr.width * idr.height; i++) {
        if (idr.y[i] != 0) idr_nonblack++;
    }
    int idr_chroma_off = 0;
    for (int i = 0; i < (idr.width / 2) * (idr.height / 2); i++) {
        if (idr.cb[i] != 128) idr_chroma_off++;
        if (idr.cr[i] != 128) idr_chroma_off++;
    }
    printf("  IDR: %d non-black luma, %d off-neutral chroma\n", idr_nonblack, idr_chroma_off);
    if (idr_nonblack > 0 || idr_chroma_off > 0) {
        fprintf(stderr, "FAIL: IDR not black\n");
        delete[] comp_frames;
        return 1;
    }
    printf("  IDR all-black - OK\n");

    /* ================================================================ */
    /* Phase 7: Pixel-identical verification (color + alpha)             */
    /*                                                                    */
    /* Composite slot layout (per slot, 11 MBs = 176px):                 */
    /*   [pad 1MB][color 4MB][pad 1MB | pad 1MB][alpha 4MB][pad 1MB]    */
    /*   Color half: first sprite_w MBs, alpha half: last sprite_w MBs  */
    /*   Shared padding in the middle.                                   */
    /*                                                                    */
    /* Reference frame (192x96 double-wide):                             */
    /*   Left half [0..95]: color (padded)                               */
    /*   Right half [96..191]: alpha as luma (padded)                    */
    /*                                                                    */
    /* Color region in composite: slot_col * STRIDE_X_MBS * 16          */
    /*   Compare against reference left half [0..95]                     */
    /* Alpha region in composite:                                        */
    /*   (slot_col * STRIDE_X_MBS + sprite_w - padding) * 16            */
    /*   Compare against reference right half [96..191]                  */
    /* ================================================================ */
    printf("\nPhase 7: Pixel-identical verification (color + alpha)...\n");

    int total_mismatches = 0;

    for (int f = 1; f <= NUM_FRAMES; f++) {
        int sprite_frame = f - 1;  /* composite frame 1 = sprite frame 0 */
        for (int s = 0; s < NUM_SPRITES; s++) {
            int slot_col = s;  /* cols=2, so sprite 0 -> col 0, sprite 1 -> col 1 */

            /* Color region: composite vs reference left half */
            int color_comp_x = slot_col * STRIDE_X_MBS * 16;
            int mm_color = compare_region(
                &comp_frames[f], color_comp_x, 0,
                &ref_frames[s][sprite_frame], 0, 0,
                PADDED_PX, PADDED_PX,
                "COLOR", f, s);

            /* Alpha region: composite vs reference right half */
            int alpha_comp_x = (slot_col * STRIDE_X_MBS + PADDED_MBS - PADDING_MBS) * 16;
            int mm_alpha = compare_region(
                &comp_frames[f], alpha_comp_x, 0,
                &ref_frames[s][sprite_frame], PADDED_PX, 0,
                PADDED_PX, PADDED_PX,
                "ALPHA", f, s);

            if (mm_color > 0 || mm_alpha > 0) {
                printf("  Frame %d sprite %d: %d color mismatches, %d alpha mismatches\n",
                       f, s, mm_color, mm_alpha);
            }
            total_mismatches += mm_color + mm_alpha;
        }
    }

    /* Cleanup */
    delete[] comp_frames;

    /* ================================================================ */
    /* Result                                                            */
    /* ================================================================ */
    printf("\n=== Results ===\n");
    printf("  Total pixel mismatches: %d\n", total_mismatches);

    if (total_mismatches == 0) {
        printf("PASS: end-to-end alpha mux verification\n");
        return 0;
    } else {
        printf("FAIL: pixel mismatches detected\n");
        return 1;
    }
}
