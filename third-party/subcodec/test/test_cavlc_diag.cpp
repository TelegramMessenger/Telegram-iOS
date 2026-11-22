// Diagnostic test: finds the exact CAVLC block where parsing desyncs
// when reading OpenH264-encoded dense random content.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

#include "codec_api.h"
#include "codec_app_def.h"
#include "codec_def.h"

#include "frame_writer.h"
#include "h264_parser.h"
#include "types.h"
#include "sprite_encode.h"

using namespace subcodec;

#define PADDED_PX  96
#define PADDED_MBS 6
#define CANVAS_MBS 12  /* PADDED_MBS * 2 (double-wide) */
#define NUM_FRAMES 10
#define SPRITE_PX  64

// Generate random perturbation content that stresses CAVLC
static void generate_random_frame(uint8_t* y, uint8_t* cb, uint8_t* cr,
                                   int frame, uint8_t* prev_y) {
    if (frame == 0) {
        // IDR: random initial content
        for (int i = 0; i < SPRITE_PX * SPRITE_PX; i++)
            y[i] = (uint8_t)(rand() % 256);
        for (int i = 0; i < SPRITE_PX/2 * SPRITE_PX/2; i++) {
            cb[i] = (uint8_t)(rand() % 256);
            cr[i] = (uint8_t)(rand() % 256);
        }
    } else {
        // P-frame: perturb previous by +/-30
        for (int i = 0; i < SPRITE_PX * SPRITE_PX; i++) {
            int v = prev_y[i] + (rand() % 61) - 30;
            y[i] = (uint8_t)(v < 0 ? 0 : (v > 255 ? 255 : v));
        }
        for (int i = 0; i < SPRITE_PX/2 * SPRITE_PX/2; i++) {
            cb[i] = (uint8_t)(rand() % 256);
            cr[i] = (uint8_t)(rand() % 256);
        }
    }
    memcpy(prev_y, y, SPRITE_PX * SPRITE_PX);
}

static void pad_to_canvas(const uint8_t* src_y, const uint8_t* src_cb, const uint8_t* src_cr,
                           uint8_t* dst_y, uint8_t* dst_cb, uint8_t* dst_cr) {
    memset(dst_y, 0, PADDED_PX * PADDED_PX);
    for (int y = 0; y < SPRITE_PX; y++)
        memcpy(dst_y + (y + 16) * PADDED_PX + 16, src_y + y * SPRITE_PX, SPRITE_PX);

    int cp = PADDED_PX / 2, cs = SPRITE_PX / 2;
    memset(dst_cb, 128, cp * cp);
    memset(dst_cr, 128, cp * cp);
    for (int y = 0; y < cs; y++) {
        memcpy(dst_cb + (y + 8) * cp + 8, src_cb + y * cs, cs);
        memcpy(dst_cr + (y + 8) * cp + 8, src_cr + y * cs, cs);
    }
}

// Find slice NAL and return its start/size
static bool find_slice_nal(const uint8_t* data, size_t size,
                           const uint8_t** out_nal, size_t* out_size) {
    size_t pos = 0;
    while (pos + 4 < size) {
        int sc_len = 0;
        if (data[pos]==0 && data[pos+1]==0 && data[pos+2]==0 && data[pos+3]==1) sc_len = 4;
        else if (data[pos]==0 && data[pos+1]==0 && data[pos+2]==1) sc_len = 3;
        if (sc_len == 0) { pos++; continue; }

        uint8_t nal_type = data[pos + sc_len] & 0x1F;
        size_t nal_start = pos;
        size_t next = pos + sc_len + 1;
        while (next + 3 <= size) {
            if (data[next]==0 && data[next+1]==0 &&
                ((next+2 < size && data[next+2]==1) ||
                 (next+3 < size && data[next+2]==0 && data[next+3]==1)))
                break;
            next++;
        }
        size_t nal_end = (next + 3 <= size) ? next : size;

        if (nal_type == 1 || nal_type == 5) {
            *out_nal = data + nal_start;
            *out_size = nal_end - nal_start;
            return true;
        }
        pos = nal_end;
    }
    return false;
}

int main(int argc, char** argv) {
    int seed = 42;
    if (argc > 1) seed = atoi(argv[1]);

    printf("=== CAVLC Diagnostic Test (seed=%d) ===\n", seed);
    srand(seed);

    auto enc_result = SpriteEncoder::create({SPRITE_PX, SPRITE_PX, 26});
    if (!enc_result) { fprintf(stderr, "Failed to create encoder\n"); return 1; }
    auto& enc = *enc_result;

    // Parse params use canvas (double-wide) dimensions since that's what OpenH264 encoded
    FrameParams params;
    params.width_mbs = CANVAS_MBS;
    params.height_mbs = PADDED_MBS;
    params.log2_max_frame_num = 4;
    params.pic_order_cnt_type = 0;
    params.log2_max_pic_order_cnt_lsb = 5;
    params.qp = 26;

    H264Parser parser;

    uint8_t sprite_y[SPRITE_PX * SPRITE_PX];
    uint8_t sprite_cb[SPRITE_PX/2 * SPRITE_PX/2];
    uint8_t sprite_cr[SPRITE_PX/2 * SPRITE_PX/2];
    uint8_t canvas_y[PADDED_PX * PADDED_PX];
    uint8_t canvas_cb[PADDED_PX/2 * PADDED_PX/2];
    uint8_t canvas_cr[PADDED_PX/2 * PADDED_PX/2];
    uint8_t prev_y[SPRITE_PX * SPRITE_PX];

    int total_failures = 0;

    for (int f = 0; f < NUM_FRAMES; f++) {
        generate_random_frame(sprite_y, sprite_cb, sprite_cr, f, prev_y);
        pad_to_canvas(sprite_y, sprite_cb, sprite_cr, canvas_y, canvas_cb, canvas_cr);

        // Create opaque alpha buffer
        uint8_t canvas_alpha[PADDED_PX * PADDED_PX];
        memset(canvas_alpha, 255, PADDED_PX * PADDED_PX);

        std::vector<uint8_t> nal_data;
        auto encode_result = enc.encode(canvas_y, PADDED_PX,
                                         canvas_cb, PADDED_PX/2,
                                         canvas_cr, PADDED_PX/2,
                                         canvas_alpha, PADDED_PX,
                                         f, &nal_data);
        if (!encode_result) {
            printf("Frame %d: encode failed\n", f);
            total_failures++;
            continue;
        }
        auto& mbs = encode_result->color;

        if (f == 0) {
            // IDR frame - parsed as I_16x16 by sprite_encoder
            printf("Frame %d: IDR (parsed as I_16x16)\n", f);
            continue;
        }

        // For P-frames, parse with our reader and then re-encode to verify
        const uint8_t* slice_nal;
        size_t slice_size;
        if (!find_slice_nal(nal_data.data(), nal_data.size(), &slice_nal, &slice_size)) {
            printf("Frame %d: no slice NAL found\n", f);
            total_failures++;
            continue;
        }

        // Normalize to 4-byte start code
        std::vector<uint8_t> normalized;
        if (slice_nal[0]==0 && slice_nal[1]==0 && slice_nal[2]==1) {
            normalized.push_back(0x00);
            normalized.insert(normalized.end(), slice_nal, slice_nal + slice_size);
        } else {
            normalized.assign(slice_nal, slice_nal + slice_size);
        }

        // Parse with our reader
        auto parse_result = parser.parse_slice({normalized.data(), normalized.size()}, params);

        if (!parse_result) {
            printf("Frame %d: PARSE FAILED\n", f);
            total_failures++;
            continue;
        }
        auto& full_parsed_mbs = *parse_result;

        // Extract left half (color) from full double-wide parsed MBs
        std::vector<MacroblockData> parsed_mbs(PADDED_MBS * PADDED_MBS);
        for (int mb_y = 0; mb_y < PADDED_MBS; mb_y++)
            for (int mb_x = 0; mb_x < PADDED_MBS; mb_x++)
                parsed_mbs[mb_y * PADDED_MBS + mb_x] = full_parsed_mbs[mb_y * CANVAS_MBS + mb_x];

        // Compare: re-encode the parsed color half and compare size
        FrameParams half_params = params;
        half_params.width_mbs = PADDED_MBS;
        uint8_t rebuf[64 * 1024];
        auto rewrite = frame_writer::write_p_frame_ex({rebuf, sizeof(rebuf)}, half_params, parsed_mbs.data(), f);
        size_t resize = rewrite.has_value() ? *rewrite : 0;

        // Count MB types from parsed data
        int n_skip = 0, n_p16 = 0, n_i16 = 0, n_other = 0;
        for (int i = 0; i < PADDED_MBS * PADDED_MBS; i++) {
            switch (parsed_mbs[i].mb_type) {
                case MbType::SKIP: n_skip++; break;
                case MbType::P_16x16: n_p16++; break;
                case MbType::I_16x16: n_i16++; break;
                default: n_other++; break;
            }
        }

        // Count non-zero coefficients in parsed vs encoder output
        int parsed_nonzero = 0, enc_nonzero = 0;
        for (int i = 0; i < PADDED_MBS * PADDED_MBS; i++) {
            for (int j = 0; j < 16; j++) {
                if (parsed_mbs[i].luma_dc[j] != 0) parsed_nonzero++;
                if (mbs[i].luma_dc[j] != 0) enc_nonzero++;
                for (int k = 0; k < 15; k++) {
                    if (parsed_mbs[i].luma_ac[j][k] != 0) parsed_nonzero++;
                    if (mbs[i].luma_ac[j][k] != 0) enc_nonzero++;
                }
            }
        }

        // slice_size is full double-wide; resize is color half only
        // With uniform alpha (all-255), ratio is near 1.0; with complex alpha, ~0.5
        double size_ratio = (double)resize / (double)(slice_size);
        int match = (size_ratio > 0.3 && size_ratio < 1.2);

        printf("Frame %d: skip=%d p16=%d i16=%d other=%d | "
               "orig=%zu re=%zu ratio=%.2f | "
               "parsed_nz=%d enc_nz=%d | %s\n",
               f, n_skip, n_p16, n_i16, n_other,
               slice_size, resize, size_ratio,
               parsed_nonzero, enc_nonzero,
               match ? "OK" : "MISMATCH");

        if (!match) {
            total_failures++;

            printf("  --- MB-by-MB comparison ---\n");
            for (int i = 0; i < PADDED_MBS * PADDED_MBS; i++) {
                if (parsed_mbs[i].mb_type != mbs[i].mb_type ||
                    parsed_mbs[i].cbp_luma != mbs[i].cbp_luma ||
                    parsed_mbs[i].cbp_chroma != mbs[i].cbp_chroma) {
                    printf("  MB[%d]: parsed type=%d cbp=%d/%d | "
                           "encoder type=%d cbp=%d/%d\n",
                           i, static_cast<int>(parsed_mbs[i].mb_type),
                           parsed_mbs[i].cbp_luma, parsed_mbs[i].cbp_chroma,
                           static_cast<int>(mbs[i].mb_type),
                           mbs[i].cbp_luma, mbs[i].cbp_chroma);
                }
            }
            if (total_failures == 1) {
                printf("  --- First divergent MB coefficients ---\n");
                for (int i = 0; i < PADDED_MBS * PADDED_MBS; i++) {
                    int differs = 0;
                    for (int j = 0; j < 16 && !differs; j++) {
                        if (parsed_mbs[i].luma_dc[j] != mbs[i].luma_dc[j]) differs = 1;
                        for (int k = 0; k < 15 && !differs; k++)
                            if (parsed_mbs[i].luma_ac[j][k] != mbs[i].luma_ac[j][k]) differs = 1;
                    }
                    if (differs) {
                        printf("  MB[%d] (type parsed=%d enc=%d):\n", i,
                               static_cast<int>(parsed_mbs[i].mb_type), static_cast<int>(mbs[i].mb_type));
                        for (int j = 0; j < 16; j++) {
                            int blk_diff = (parsed_mbs[i].luma_dc[j] != mbs[i].luma_dc[j]);
                            for (int k = 0; k < 15 && !blk_diff; k++)
                                blk_diff = (parsed_mbs[i].luma_ac[j][k] != mbs[i].luma_ac[j][k]);
                            if (blk_diff) {
                                printf("    Block[%d] dc: parsed=%d enc=%d\n",
                                       j, parsed_mbs[i].luma_dc[j], mbs[i].luma_dc[j]);
                                printf("    Block[%d] ac parsed:", j);
                                for (int k = 0; k < 15; k++) printf(" %d", parsed_mbs[i].luma_ac[j][k]);
                                printf("\n    Block[%d] ac enc:   ", j);
                                for (int k = 0; k < 15; k++) printf(" %d", mbs[i].luma_ac[j][k]);
                                printf("\n");
                                break;
                            }
                        }
                        break;
                    }
                }
            }
        }
    }

    printf("\n=== %d/%d frames had issues ===\n", total_failures, NUM_FRAMES - 1);
    return total_failures > 0 ? 1 : 0;
}
