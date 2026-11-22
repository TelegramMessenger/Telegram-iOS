#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "../src/frame_writer.h"
#include "../src/h264_parser.h"
#include "../src/types.h"

using namespace subcodec;
using namespace subcodec::frame_writer;

static H264Parser parser;

/*
 * Extended IDR Frame Writer Tests
 *
 * Tests for write_idr_frame_ex() which encodes IDR frames using
 * MacroblockData, supporting I_16x16 type.
 */

// Test 1: All I_16x16 DC -- parse back and verify
static int test_idr_all_i16x16(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;

    MacroblockData mbs[4];
    for (int i = 0; i < 4; i++) {
        mbs[i].mb_type = MbType::I_16x16;
        mbs[i].intra_pred_mode = I16PredMode::DC;
        mbs[i].intra_chroma_mode = ChromaPredMode::DC;
    }

    uint8_t buf[16384];
    auto wr = write_idr_frame_ex({buf, sizeof(buf)}, params, mbs);
    assert(wr.has_value());

    auto result = parser.parse_slice({buf, *wr}, params);
    assert(result.has_value());

    for (int i = 0; i < 4; i++) {
        assert((*result)[i].mb_type == MbType::I_16x16);
        assert((*result)[i].intra_pred_mode == I16PredMode::DC);
    }
    printf("  PASS: idr_all_i16x16\n");
    return 0;
}

// Test 2: I_16x16 with varying prediction modes
static int test_idr_mixed_pred(void) {
    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 1;

    MacroblockData mbs[2];
    mbs[0].mb_type = MbType::I_16x16;
    mbs[0].intra_pred_mode = I16PredMode::DC;
    mbs[0].intra_chroma_mode = ChromaPredMode::DC;
    mbs[0].luma_dc[0] = 20;
    mbs[1].mb_type = MbType::I_16x16;
    mbs[1].intra_pred_mode = I16PredMode::H;
    mbs[1].intra_chroma_mode = ChromaPredMode::DC;
    mbs[1].luma_dc[0] = 35;

    uint8_t buf[16384];
    auto wr = write_idr_frame_ex({buf, sizeof(buf)}, params, mbs);
    assert(wr.has_value());

    auto result = parser.parse_slice({buf, *wr}, params);
    assert(result.has_value());

    auto& out = *result;
    assert(out[0].mb_type == MbType::I_16x16);
    assert(out[0].intra_pred_mode == I16PredMode::DC);
    assert(out[0].luma_dc[0] == 20);
    assert(out[1].mb_type == MbType::I_16x16);
    assert(out[1].intra_pred_mode == I16PredMode::H);
    assert(out[1].luma_dc[0] == 35);
    printf("  PASS: idr_mixed_pred\n");
    return 0;
}

int main(void) {
    printf("test_idr_frame_ex\n");
    int failures = 0;
    failures += test_idr_all_i16x16();
    failures += test_idr_mixed_pred();
    if (failures == 0) {
        printf("All tests passed.\n");
    } else {
        printf("%d test(s) failed.\n", failures);
    }
    return failures;
}
