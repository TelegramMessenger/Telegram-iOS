#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../src/frame_writer.h"
#include "../src/h264_parser.h"
#include "../src/types.h"

using namespace subcodec;
using namespace subcodec::frame_writer;

/*
 * H.264 Slice Parser Tests
 *
 * Strategy: use write_p_frame_ex() to generate known bitstreams,
 * then parse them back with H264Parser and verify the
 * macroblock data matches.
 */

static H264Parser parser;

// Test 1: All skip MBs (2x2 frame)
static int test_parse_all_skip(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs_in = new MacroblockData[num_mbs]();

    uint8_t buf[4096];
    auto wr = write_p_frame_ex({buf, sizeof(buf)}, params, mbs_in, 1);
    delete[] mbs_in;

    if (!wr.has_value()) {
        printf("FAIL: test_parse_all_skip - write_p_frame_ex failed\n");
        return 1;
    }

    auto result = parser.parse_slice({buf, *wr}, params);
    if (!result.has_value()) {
        printf("FAIL: test_parse_all_skip - parse_slice failed\n");
        return 1;
    }

    for (int i = 0; i < num_mbs; i++) {
        if ((*result)[i].mb_type != MbType::SKIP) {
            printf("FAIL: test_parse_all_skip - MB %d: expected SKIP, got %d\n",
                   i, static_cast<int>((*result)[i].mb_type));
            return 1;
        }
    }

    printf("PASS: test_parse_all_skip\n");
    return 0;
}

// Test 2: Skip + I_16x16 (2x1 frame)
static int test_parse_skip_and_i16x16(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 1;

    MacroblockData mbs_in[2];
    mbs_in[1].mb_type = MbType::I_16x16;
    mbs_in[1].intra_pred_mode = I16PredMode::DC;
    mbs_in[1].intra_chroma_mode = ChromaPredMode::DC;
    mbs_in[1].luma_dc[0] = 12;

    uint8_t buf[8192];
    auto wr = write_p_frame_ex({buf, sizeof(buf)}, params, mbs_in, 1);
    if (!wr.has_value()) {
        printf("FAIL: test_parse_skip_and_i16x16 - write failed\n");
        return 1;
    }

    auto result = parser.parse_slice({buf, *wr}, params);
    if (!result.has_value()) {
        printf("FAIL: test_parse_skip_and_i16x16 - parse failed\n");
        return 1;
    }

    if ((*result)[0].mb_type != MbType::SKIP) {
        printf("FAIL: test_parse_skip_and_i16x16 - MB 0: expected SKIP, got %d\n", static_cast<int>((*result)[0].mb_type));
        return 1;
    }
    if ((*result)[1].mb_type != MbType::I_16x16) {
        printf("FAIL: test_parse_skip_and_i16x16 - MB 1: expected I_16x16, got %d\n", static_cast<int>((*result)[1].mb_type));
        return 1;
    }
    if ((*result)[1].luma_dc[0] != 12) {
        printf("FAIL: test_parse_skip_and_i16x16 - MB 1: luma_dc[0] expected 12, got %d\n", (*result)[1].luma_dc[0]);
        return 1;
    }

    printf("PASS: test_parse_skip_and_i16x16\n");
    return 0;
}

// Test 3: P_16x16 with MV, no residual (2x1 frame)
static int test_parse_p16x16(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 1;

    MacroblockData mbs_in[2];
    mbs_in[0].mb_type = MbType::P_16x16;
    mbs_in[0].mv_x = 4;
    mbs_in[0].mv_y = -2;

    uint8_t buf[4096];
    auto wr = write_p_frame_ex({buf, sizeof(buf)}, params, mbs_in, 2);
    if (!wr.has_value()) {
        printf("FAIL: test_parse_p16x16 - write failed\n");
        return 1;
    }

    auto result = parser.parse_slice({buf, *wr}, params);
    if (!result.has_value()) {
        printf("FAIL: test_parse_p16x16 - parse failed\n");
        return 1;
    }

    auto& out = *result;
    if (out[0].mb_type != MbType::P_16x16) {
        printf("FAIL: test_parse_p16x16 - MB 0: expected P_16x16\n");
        return 1;
    }
    if (out[0].mv_x != 4 || out[0].mv_y != -2) {
        printf("FAIL: test_parse_p16x16 - MB 0: MV expected (4,-2), got (%d,%d)\n",
               out[0].mv_x, out[0].mv_y);
        return 1;
    }
    if (out[0].cbp_luma != 0 || out[0].cbp_chroma != 0) {
        printf("FAIL: test_parse_p16x16 - MB 0: expected cbp=0\n");
        return 1;
    }
    if (out[1].mb_type != MbType::SKIP) {
        printf("FAIL: test_parse_p16x16 - MB 1: expected SKIP\n");
        return 1;
    }

    printf("PASS: test_parse_p16x16\n");
    return 0;
}

// Test 4: P_16x16 with residual (1x1 frame)
static int test_parse_p16x16_with_residual(void) {
    FrameParams params;
    params.width_mbs = 1;
    params.height_mbs = 1;

    MacroblockData mbs_in[1];
    mbs_in[0].mb_type = MbType::P_16x16;
    mbs_in[0].mv_x = 2;
    mbs_in[0].mv_y = 0;
    mbs_in[0].cbp_luma = 1;
    mbs_in[0].luma_dc[0] = 5;
    mbs_in[0].luma_ac[0][0] = 3;
    mbs_in[0].luma_ac[0][1] = -1;

    uint8_t buf[4096];
    auto wr = write_p_frame_ex({buf, sizeof(buf)}, params, mbs_in, 3);
    if (!wr.has_value()) {
        printf("FAIL: test_parse_p16x16_with_residual - write failed\n");
        return 1;
    }

    auto result = parser.parse_slice({buf, *wr}, params);
    if (!result.has_value()) {
        printf("FAIL: test_parse_p16x16_with_residual - parse failed\n");
        return 1;
    }

    auto& out = *result;
    if (out[0].mb_type != MbType::P_16x16) {
        printf("FAIL: test_parse_p16x16_with_residual - expected P_16x16\n");
        return 1;
    }
    if (out[0].mv_x != 2 || out[0].mv_y != 0) {
        printf("FAIL: test_parse_p16x16_with_residual - MV expected (2,0), got (%d,%d)\n",
               out[0].mv_x, out[0].mv_y);
        return 1;
    }
    if (out[0].cbp_luma != 1) {
        printf("FAIL: test_parse_p16x16_with_residual - cbp_luma expected 1, got %d\n",
               out[0].cbp_luma);
        return 1;
    }
    if (out[0].luma_dc[0] != 5) {
        printf("FAIL: test_parse_p16x16_with_residual - luma_dc[0] expected 5, got %d\n",
               out[0].luma_dc[0]);
        return 1;
    }
    if (out[0].luma_ac[0][0] != 3 || out[0].luma_ac[0][1] != -1) {
        printf("FAIL: test_parse_p16x16_with_residual - luma_ac mismatch\n");
        return 1;
    }

    printf("PASS: test_parse_p16x16_with_residual\n");
    return 0;
}

// Test 5: I_16x16 with DC prediction and known DC coefficients (1x1 frame)
static int test_parse_i16x16(void) {
    FrameParams params;
    params.width_mbs = 1;
    params.height_mbs = 1;

    MacroblockData mbs_in[1];
    mbs_in[0].mb_type = MbType::I_16x16;
    mbs_in[0].intra_pred_mode = I16PredMode::DC;
    mbs_in[0].intra_chroma_mode = ChromaPredMode::DC;
    mbs_in[0].luma_dc[0] = 10;
    mbs_in[0].luma_dc[1] = -5;
    mbs_in[0].luma_dc[2] = 3;

    uint8_t buf[4096];
    auto wr = write_p_frame_ex({buf, sizeof(buf)}, params, mbs_in, 4);
    if (!wr.has_value()) {
        printf("FAIL: test_parse_i16x16 - write failed\n");
        return 1;
    }

    auto result = parser.parse_slice({buf, *wr}, params);
    if (!result.has_value()) {
        printf("FAIL: test_parse_i16x16 - parse failed\n");
        return 1;
    }

    auto& out = *result;
    if (out[0].mb_type != MbType::I_16x16) {
        printf("FAIL: test_parse_i16x16 - expected I_16x16\n");
        return 1;
    }
    if (out[0].intra_pred_mode != I16PredMode::DC) {
        printf("FAIL: test_parse_i16x16 - pred_mode mismatch\n");
        return 1;
    }
    if (out[0].luma_dc[0] != 10 || out[0].luma_dc[1] != -5 || out[0].luma_dc[2] != 3) {
        printf("FAIL: test_parse_i16x16 - luma_dc mismatch: [%d, %d, %d]\n",
               out[0].luma_dc[0], out[0].luma_dc[1], out[0].luma_dc[2]);
        return 1;
    }

    printf("PASS: test_parse_i16x16\n");
    return 0;
}

// Test 6: Mixed frame with all MB types (3x2 frame)
static int test_parse_mixed_frame(void) {
    FrameParams params;
    params.width_mbs = 3;
    params.height_mbs = 2;
    int num_mbs = 6;

    MacroblockData* mbs_in = new MacroblockData[num_mbs]();

    // MB 0: Skip (default)

    // MB 1: P_16x16 with MV and residual
    mbs_in[1].mb_type = MbType::P_16x16;
    mbs_in[1].mv_x = 6;
    mbs_in[1].mv_y = -4;
    mbs_in[1].cbp_luma = 0x0F;
    mbs_in[1].luma_dc[0] = 7;
    mbs_in[1].luma_ac[0][0] = 2;

    // MB 2: I_16x16 with DC prediction
    mbs_in[2].mb_type = MbType::I_16x16;
    mbs_in[2].intra_pred_mode = I16PredMode::DC;
    mbs_in[2].intra_chroma_mode = ChromaPredMode::DC;
    mbs_in[2].luma_dc[0] = 25;

    // MB 3: I_16x16 with chroma
    mbs_in[3].mb_type = MbType::I_16x16;
    mbs_in[3].intra_pred_mode = I16PredMode::V;
    mbs_in[3].intra_chroma_mode = ChromaPredMode::H;
    mbs_in[3].cbp_chroma = 1;
    mbs_in[3].luma_dc[0] = 15;
    mbs_in[3].cb_dc[0] = 4;
    mbs_in[3].cr_dc[0] = -3;

    // MB 4, 5: Skip (default)

    uint8_t buf[16384];
    auto wr = write_p_frame_ex({buf, sizeof(buf)}, params, mbs_in, 5);
    if (!wr.has_value()) {
        printf("FAIL: test_parse_mixed_frame - write failed\n");
        delete[] mbs_in;
        return 1;
    }

    auto result = parser.parse_slice({buf, *wr}, params);
    delete[] mbs_in;

    if (!result.has_value()) {
        printf("FAIL: test_parse_mixed_frame - parse failed\n");
        return 1;
    }

    auto& out = *result;

    // Verify MB types
    MbType expected_types[] = {MbType::SKIP, MbType::P_16x16, MbType::I_16x16,
                               MbType::I_16x16, MbType::SKIP, MbType::SKIP};
    for (int i = 0; i < num_mbs; i++) {
        if (out[i].mb_type != expected_types[i]) {
            printf("FAIL: test_parse_mixed_frame - MB %d: expected type %d, got %d\n",
                   i, static_cast<int>(expected_types[i]), static_cast<int>(out[i].mb_type));
            return 1;
        }
    }

    // Verify P_16x16 MV
    if (out[1].mv_x != 6 || out[1].mv_y != -4) {
        printf("FAIL: test_parse_mixed_frame - MB 1: MV mismatch\n");
        return 1;
    }

    // Verify P_16x16 residual
    if (out[1].luma_dc[0] != 7 || out[1].luma_ac[0][0] != 2) {
        printf("FAIL: test_parse_mixed_frame - MB 1: residual mismatch\n");
        return 1;
    }

    // Verify I_16x16
    if (out[3].intra_pred_mode != I16PredMode::V) {
        printf("FAIL: test_parse_mixed_frame - MB 3: pred_mode mismatch\n");
        return 1;
    }
    if (out[3].luma_dc[0] != 15) {
        printf("FAIL: test_parse_mixed_frame - MB 3: luma_dc mismatch\n");
        return 1;
    }
    if (out[3].cb_dc[0] != 4 || out[3].cr_dc[0] != -3) {
        printf("FAIL: test_parse_mixed_frame - MB 3: chroma DC mismatch\n");
        return 1;
    }

    printf("PASS: test_parse_mixed_frame\n");
    return 0;
}

int main(void) {
    int failures = 0;

    failures += test_parse_all_skip();
    failures += test_parse_skip_and_i16x16();
    failures += test_parse_p16x16();
    failures += test_parse_p16x16_with_residual();
    failures += test_parse_i16x16();
    failures += test_parse_mixed_frame();

    printf("\n%d test(s) failed\n", failures);
    return failures;
}
