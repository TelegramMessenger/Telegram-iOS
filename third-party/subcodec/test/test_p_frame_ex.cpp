#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../src/frame_writer.h"
#include "../src/types.h"

using namespace subcodec;
using namespace subcodec::frame_writer;

/*
 * Extended P-frame Writer Tests
 *
 * Tests for write_p_frame_ex() which encodes P-frames using an array of
 * MacroblockData, supporting SKIP, P_16x16, and I_16x16 types.
 */

// Test: All skip macroblocks (simplest case)
static int test_p_frame_ex_all_skip(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs = new MacroblockData[num_mbs]();

    // All macroblocks are SKIP (default)

    uint8_t buf[4096];
    auto result = write_p_frame_ex({buf, sizeof(buf)}, params, mbs, 1);
    delete[] mbs;

    if (!result.has_value()) {
        printf("FAIL: test_p_frame_ex_all_skip - write_p_frame_ex failed\n");
        return 1;
    }
    size_t size = *result;

    if (size < 8 || size > 100) {
        printf("FAIL: test_p_frame_ex_all_skip - unexpected size: %zu\n", size);
        return 1;
    }

    if (buf[0] != 0x00 || buf[1] != 0x00 || buf[2] != 0x00 || buf[3] != 0x01) {
        printf("FAIL: test_p_frame_ex_all_skip - bad start code\n");
        return 1;
    }

    if (buf[4] != 0x41) {
        printf("FAIL: test_p_frame_ex_all_skip - bad NAL header: 0x%02x\n", buf[4]);
        return 1;
    }

    printf("PASS: test_p_frame_ex_all_skip (%zu bytes)\n", size);
    return 0;
}

// Test: All I_16x16 macroblocks
static int test_p_frame_ex_all_i16x16(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs = new MacroblockData[num_mbs]();
    for (int i = 0; i < num_mbs; i++) {
        mbs[i].mb_type = MbType::I_16x16;
        mbs[i].intra_pred_mode = I16PredMode::DC;
        mbs[i].intra_chroma_mode = ChromaPredMode::DC;
    }

    uint8_t buf[4096];
    auto result = write_p_frame_ex({buf, sizeof(buf)}, params, mbs, 1);
    delete[] mbs;

    if (!result.has_value()) {
        printf("FAIL: test_p_frame_ex_all_i16x16 - write failed\n");
        return 1;
    }
    size_t size = *result;

    if (size < 8 || size > 200) {
        printf("FAIL: test_p_frame_ex_all_i16x16 - unexpected size: %zu\n", size);
        return 1;
    }

    printf("PASS: test_p_frame_ex_all_i16x16 (%zu bytes)\n", size);
    return 0;
}

// Test: Mixed SKIP and I_16x16
static int test_p_frame_ex_skip_and_i16x16(void) {
    FrameParams params;
    params.width_mbs = 4;
    params.height_mbs = 1;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs = new MacroblockData[num_mbs]();

    // Pattern: SKIP, I_16x16, SKIP, SKIP
    mbs[1].mb_type = MbType::I_16x16;
    mbs[1].intra_pred_mode = I16PredMode::DC;
    mbs[1].intra_chroma_mode = ChromaPredMode::DC;

    uint8_t buf[4096];
    auto result = write_p_frame_ex({buf, sizeof(buf)}, params, mbs, 1);
    delete[] mbs;

    if (!result.has_value()) {
        printf("FAIL: test_p_frame_ex_skip_and_i16x16 - write failed\n");
        return 1;
    }
    size_t size = *result;

    if (size < 8 || size > 200) {
        printf("FAIL: test_p_frame_ex_skip_and_i16x16 - unexpected size: %zu\n", size);
        return 1;
    }

    printf("PASS: test_p_frame_ex_skip_and_i16x16 (%zu bytes)\n", size);
    return 0;
}

// Test: Mixed SKIP, P_16x16, I_16x16
static int test_p_frame_ex_mixed(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs = new MacroblockData[num_mbs]();

    // MB 0: SKIP (default)

    // MB 1: P_16x16 with motion
    mbs[1].mb_type = MbType::P_16x16;
    mbs[1].mv_x = 4;
    mbs[1].mv_y = 2;

    // MB 2: I_16x16 with DC
    mbs[2].mb_type = MbType::I_16x16;
    mbs[2].intra_pred_mode = I16PredMode::DC;
    mbs[2].intra_chroma_mode = ChromaPredMode::DC;
    mbs[2].luma_dc[0] = 100;

    // MB 3: SKIP (default)

    uint8_t buf[4096];
    auto result = write_p_frame_ex({buf, sizeof(buf)}, params, mbs, 1);
    delete[] mbs;

    if (!result.has_value()) {
        printf("FAIL: test_p_frame_ex_mixed - write failed\n");
        return 1;
    }
    size_t size = *result;

    if (size < 10 || size > 200) {
        printf("FAIL: test_p_frame_ex_mixed - unexpected size: %zu\n", size);
        return 1;
    }

    printf("PASS: test_p_frame_ex_mixed (%zu bytes)\n", size);
    return 0;
}

// Test: P_16x16 with neighbor context (MV prediction)
static int test_p_frame_ex_p16x16_row(void) {
    FrameParams params;
    params.width_mbs = 4;
    params.height_mbs = 1;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs = new MacroblockData[num_mbs]();

    for (int i = 0; i < num_mbs; i++) {
        mbs[i].mb_type = MbType::P_16x16;
        mbs[i].mv_x = 8;
        mbs[i].mv_y = 4;
    }

    uint8_t buf[4096];
    auto result = write_p_frame_ex({buf, sizeof(buf)}, params, mbs, 1);
    delete[] mbs;

    if (!result.has_value()) {
        printf("FAIL: test_p_frame_ex_p16x16_row - write failed\n");
        return 1;
    }
    size_t size = *result;

    if (size < 10 || size > 100) {
        printf("FAIL: test_p_frame_ex_p16x16_row - unexpected size: %zu\n", size);
        return 1;
    }

    printf("PASS: test_p_frame_ex_p16x16_row (%zu bytes)\n", size);
    return 0;
}

// Test: Multiple rows (tests above neighbor context)
static int test_p_frame_ex_multirow(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 3;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs = new MacroblockData[num_mbs]();

    // Row 0: P_16x16
    mbs[0].mb_type = MbType::P_16x16;
    mbs[0].mv_x = 2;
    mbs[0].mv_y = 2;
    mbs[1].mb_type = MbType::P_16x16;
    mbs[1].mv_x = 2;
    mbs[1].mv_y = 2;

    // Row 1: I_16x16
    mbs[2].mb_type = MbType::I_16x16;
    mbs[2].intra_pred_mode = I16PredMode::V;
    mbs[2].luma_dc[0] = 50;
    mbs[3].mb_type = MbType::I_16x16;
    mbs[3].intra_pred_mode = I16PredMode::H;
    mbs[3].luma_dc[0] = 60;

    // Row 2: SKIP (default)

    uint8_t buf[4096];
    auto result = write_p_frame_ex({buf, sizeof(buf)}, params, mbs, 1);
    delete[] mbs;

    if (!result.has_value()) {
        printf("FAIL: test_p_frame_ex_multirow - write failed\n");
        return 1;
    }
    size_t size = *result;

    if (size < 10 || size > 200) {
        printf("FAIL: test_p_frame_ex_multirow - unexpected size: %zu\n", size);
        return 1;
    }

    printf("PASS: test_p_frame_ex_multirow (%zu bytes)\n", size);
    return 0;
}

// Test: Frame number wrapping (frame_num uses 4 bits)
static int test_p_frame_ex_frame_num(void) {
    FrameParams params;
    params.width_mbs = 1;
    params.height_mbs = 1;

    MacroblockData mb;  // SKIP by default

    uint8_t buf1[256], buf2[256];

    auto r1 = write_p_frame_ex({buf1, sizeof(buf1)}, params, &mb, 1);
    auto r2 = write_p_frame_ex({buf2, sizeof(buf2)}, params, &mb, 17);

    if (!r1.has_value() || !r2.has_value()) {
        printf("FAIL: test_p_frame_ex_frame_num - write failed\n");
        return 1;
    }
    size_t size1 = *r1, size2 = *r2;

    if (size1 != size2) {
        printf("FAIL: test_p_frame_ex_frame_num - sizes differ: %zu vs %zu\n", size1, size2);
        return 1;
    }

    if (memcmp(buf1 + 5, buf2 + 5, size1 - 5) != 0) {
        printf("FAIL: test_p_frame_ex_frame_num - content differs\n");
        return 1;
    }

    printf("PASS: test_p_frame_ex_frame_num\n");
    return 0;
}

// Test: Deterministic output
static int test_p_frame_ex_deterministic(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;
    int num_mbs = params.width_mbs * params.height_mbs;

    MacroblockData* mbs = new MacroblockData[num_mbs]();

    mbs[1].mb_type = MbType::P_16x16;
    mbs[1].mv_x = 4;
    mbs[1].mv_y = -2;
    mbs[2].mb_type = MbType::I_16x16;
    mbs[2].intra_pred_mode = I16PredMode::DC;
    mbs[2].luma_dc[0] = 80;

    uint8_t buf1[4096], buf2[4096];
    auto r1 = write_p_frame_ex({buf1, sizeof(buf1)}, params, mbs, 5);
    auto r2 = write_p_frame_ex({buf2, sizeof(buf2)}, params, mbs, 5);
    delete[] mbs;

    if (!r1.has_value() || !r2.has_value()) {
        printf("FAIL: test_p_frame_ex_deterministic - write failed\n");
        return 1;
    }
    size_t size1 = *r1, size2 = *r2;

    if (size1 != size2) {
        printf("FAIL: test_p_frame_ex_deterministic - sizes differ: %zu vs %zu\n", size1, size2);
        return 1;
    }

    if (memcmp(buf1, buf2, size1) != 0) {
        printf("FAIL: test_p_frame_ex_deterministic - content differs\n");
        return 1;
    }

    printf("PASS: test_p_frame_ex_deterministic (%zu bytes)\n", size1);
    return 0;
}

// Test: All four MB types in one frame
static int test_p_frame_ex_all_types(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;

    MacroblockData mbs[4];

    mbs[1].mb_type = MbType::P_16x16;
    mbs[1].mv_x = 2;
    mbs[1].mv_y = -4;

    mbs[2].mb_type = MbType::I_16x16;
    mbs[2].intra_pred_mode = I16PredMode::H;
    mbs[2].luma_dc[0] = 64;

    mbs[3].mb_type = MbType::I_16x16;
    mbs[3].intra_pred_mode = I16PredMode::V;
    mbs[3].intra_chroma_mode = ChromaPredMode::DC;
    mbs[3].luma_dc[0] = 32;

    uint8_t buf[4096];
    auto result = write_p_frame_ex({buf, sizeof(buf)}, params, mbs, 2);

    if (!result.has_value()) {
        printf("FAIL: test_p_frame_ex_all_types - write failed\n");
        return 1;
    }
    size_t size = *result;

    if (size < 10 || size > 200) {
        printf("FAIL: test_p_frame_ex_all_types - unexpected size: %zu\n", size);
        return 1;
    }

    printf("PASS: test_p_frame_ex_all_types (%zu bytes)\n", size);
    return 0;
}

int main(void) {
    int errors = 0;

    printf("Running Extended P-frame Writer tests...\n\n");

    printf("-- Basic Tests --\n");
    errors += test_p_frame_ex_all_skip();
    errors += test_p_frame_ex_all_i16x16();
    errors += test_p_frame_ex_skip_and_i16x16();

    printf("\n-- Mixed MB Type Tests --\n");
    errors += test_p_frame_ex_mixed();
    errors += test_p_frame_ex_all_types();

    printf("\n-- Context Tracking Tests --\n");
    errors += test_p_frame_ex_p16x16_row();
    errors += test_p_frame_ex_multirow();

    printf("\n-- Quality Tests --\n");
    errors += test_p_frame_ex_frame_num();
    errors += test_p_frame_ex_deterministic();

    printf("\n%d test(s) failed\n", errors);
    return errors;
}
