#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <vector>
#include "mbs_encode.h"
#include "mbs_format.h"
#include "types.h"
#include "cavlc.h"
#include "bs.h"

using namespace subcodec;
using subcodec::cavlc::read_block;

/* ---- Test 1: All-SKIP frame ---- */
static void test_encode_skip_frame(void) {
    printf("test_encode_skip_frame...\n");

    FrameParams params{};
    params.width_mbs = 6;
    params.height_mbs = 6;
    params.qp = 26;

    int num_mbs = 36;
    std::vector<MacroblockData> mbs(num_mbs);
    for (int i = 0; i < num_mbs; i++) mbs[i].mb_type = MbType::SKIP;

    auto frame = subcodec::mbs::encode_frame(params, mbs.data());
    assert(!frame.data.empty());
    assert(frame.rows.size() == 6);

    /* All rows should be all-skip */
    for (int y = 0; y < 6; y++) {
        assert(frame.rows[y].bit_count() == 0);
        assert(frame.rows[y].leading_skips == 6);
    }

    printf("  PASS\n");
}

/* ---- Test 2: I_16x16 frame ---- */
static void test_encode_i16x16_frame(void) {
    printf("test_encode_i16x16_frame...\n");

    FrameParams params{};
    params.width_mbs = 2;
    params.height_mbs = 2;
    params.qp = 26;

    MacroblockData mbs[4]{};
    for (int i = 0; i < 4; i++) {
        mbs[i].mb_type = MbType::I_16x16;
        mbs[i].intra_pred_mode = I16PredMode::DC;
        mbs[i].intra_chroma_mode = ChromaPredMode::DC;
    }

    auto frame = subcodec::mbs::encode_frame(params, mbs);
    assert(!frame.data.empty());
    assert(frame.rows.size() == 2);

    /* Both rows should have non-zero blob (I_16x16 MBs are non-skip) */
    for (int y = 0; y < 2; y++) {
        assert(frame.rows[y].bit_count() > 0);
        assert(frame.rows[y].leading_skips == 0);
        assert(frame.rows[y].trailing_skips == 0);
    }

    printf("  PASS\n");
}

/* ---- Test 3: P_16x16 with zero residual + SKIP ---- */
static void test_encode_p16x16_zero_residual(void) {
    printf("test_encode_p16x16_zero_residual...\n");

    FrameParams params{};
    params.width_mbs = 2;
    params.height_mbs = 1;
    params.qp = 26;

    MacroblockData mbs[2]{};
    mbs[0].mb_type = MbType::P_16x16;
    mbs[0].mv_x = 2;
    mbs[0].mv_y = 4;
    mbs[0].cbp_luma = 0;
    mbs[0].cbp_chroma = 0;
    mbs[1].mb_type = MbType::SKIP;

    auto frame = subcodec::mbs::encode_frame(params, mbs);
    assert(!frame.data.empty());
    assert(frame.rows.size() == 1);

    /* Row 0: [P_16x16, SKIP] — trailing_skips=1, blob has P data */
    assert(frame.rows[0].trailing_skips == 1);
    assert(frame.rows[0].leading_skips == 0);
    assert(frame.rows[0].bit_count() > 0);

    printf("  PASS\n");
}

/* ---- Test 4: P_16x16 with residual — verify CAVLC in blob ---- */
static void test_encode_p16x16_with_residual(void) {
    printf("test_encode_p16x16_with_residual...\n");

    FrameParams params{};
    params.width_mbs = 1;
    params.height_mbs = 1;
    params.qp = 26;

    MacroblockData mb{};
    mb.mb_type = MbType::P_16x16;
    mb.mv_x = 0;
    mb.mv_y = 0;
    mb.cbp_luma = 1;     /* Only 8x8 block 0 has residual */
    mb.cbp_chroma = 0;
    mb.luma_dc[0] = 5;
    mb.luma_ac[0][0] = 3;
    mb.luma_ac[0][1] = -1;

    auto frame = subcodec::mbs::encode_frame(params, &mb);
    assert(!frame.data.empty());
    assert(frame.rows.size() == 1);

    /* Row has exactly 1 non-skip MB */
    assert(frame.rows[0].leading_skips == 0);
    assert(frame.rows[0].trailing_skips == 0);
    assert(frame.rows[0].bit_count() > 0);
    assert(frame.rows[0].blob_data != nullptr);

    /* Verify the blob contains valid CAVLC by parsing it */
    bs_t b;
    bs_init(&b, const_cast<uint8_t*>(frame.rows[0].blob_data),
            (frame.rows[0].bit_count() + 7) / 8);

    /* Skip header: ue(mb_type=0) + se(mvd_x=0) + se(mvd_y=0) + ue(cbp) + se(qp_delta) */
    bs_read_ue(&b);
    bs_read_se(&b);
    bs_read_se(&b);
    bs_read_ue(&b);
    bs_read_se(&b);

    /* Block 0 should decode to [5, 3, -1, 0, ...] */
    int16_t decoded[16];
    int tc = read_block(&b, decoded, 0, 16);
    assert(tc == 3);
    assert(decoded[0] == 5);
    assert(decoded[1] == 3);
    assert(decoded[2] == -1);
    for (int i = 3; i < 16; i++) assert(decoded[i] == 0);

    printf("  PASS\n");
}

/* ---- Test 5: Zero-run metadata correctness ---- */
static void test_zero_run_metadata(void) {
    printf("test_zero_run_metadata...\n");

    /* All-skip frame: metadata should be all zeros */
    {
        FrameParams params{};
        params.width_mbs = 6;
        params.height_mbs = 6;
        params.qp = 26;

        std::vector<MacroblockData> mbs(36);
        for (auto& mb : mbs) mb.mb_type = MbType::SKIP;

        auto frame = subcodec::mbs::encode_frame(params, mbs.data());
        for (int y = 0; y < 6; y++) {
            assert(frame.rows[y].bit_count() == 0);
            assert(!frame.rows[y].has_long_zero_run());
            assert(frame.rows[y].leading_zero_bits == 0);
            assert(frame.rows[y].trailing_zero_bits == 0);
        }
    }

    /* P_16x16 with zero residual: blob starts with ue(0)=1 bit, so leading_zero_bits=0 */
    {
        FrameParams params{};
        params.width_mbs = 1;
        params.height_mbs = 1;
        params.qp = 26;

        MacroblockData mb{};
        mb.mb_type = MbType::P_16x16;
        mb.mv_x = 0;
        mb.mv_y = 0;

        auto frame = subcodec::mbs::encode_frame(params, &mb);
        assert(frame.rows[0].bit_count() > 0);
        /* ue(0) = "1" → first bit is 1, so leading_zero_bits = 0 */
        assert(frame.rows[0].leading_zero_bits == 0);
        /* Small blob, very unlikely to have 16+ consecutive zeros */
        assert(!frame.rows[0].has_long_zero_run());
    }

    printf("  PASS\n");
}

/* ---- Test 6: encode_frame_merged ---- */
static void test_encode_frame_merged() {
    printf("test_encode_frame_merged...\n");

    FrameParams params;
    params.width_mbs = 2;
    params.height_mbs = 2;
    params.qp = 26;

    // Color: one P_16x16 MB + rest SKIP
    MacroblockData color_mbs[4] = {};
    color_mbs[0].mb_type = MbType::P_16x16;
    color_mbs[0].mv_x = 2;
    color_mbs[0].mv_y = 0;

    // Alpha: all SKIP
    MacroblockData alpha_mbs[4] = {};

    int sprite_w = 2;
    int padding = 1;

    auto result = mbs::encode_frame_merged(params, color_mbs, params, alpha_mbs,
                                            sprite_w, padding);

    assert(!result.data.empty());
    assert(result.rows.size() == 2);
    assert(result.rows[0].bit_count() > 0);
    assert(result.rows[0].blob_data != nullptr);

    printf("  PASS\n");
}

int main(void) {
    test_encode_skip_frame();
    test_encode_i16x16_frame();
    test_encode_p16x16_zero_residual();
    test_encode_p16x16_with_residual();
    test_zero_run_metadata();
    test_encode_frame_merged();
    printf("All mbs_encode tests passed.\n");
    return 0;
}
