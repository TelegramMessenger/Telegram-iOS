#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "types.h"
#include "mbs_format.h"
#include "mbs_encode.h"

using namespace subcodec;

/* Helper: make an all-skip merged frame with slot_w leading_skips per row */
static MbsEncodedFrame make_skip_frame(int height, int slot_w) {
    MbsEncodedFrame ef;
    ef.rows.resize(height);
    ef.data.resize(height * 6, 0);
    uint8_t* dp = ef.data.data();
    for (int y = 0; y < height; y++) {
        dp[0] = static_cast<uint8_t>(slot_w);  // leading_skips
        dp[1] = 0;
        dp[2] = 0; dp[3] = 0;  // blob_bit_count = 0
        dp[4] = 0; dp[5] = 0;
        ef.rows[y].leading_skips = dp[0];
        ef.rows[y].trailing_skips = 0;
        ef.rows[y].blob_bit_count = 0;
        ef.rows[y].leading_zero_bits = 0;
        ef.rows[y].trailing_zero_bits = 0;
        ef.rows[y].blob_data = nullptr;
        dp += 6;
    }
    return ef;
}

/* Test 1: 6x6 MBs, 3 frames, all SKIP */
static void test_skip_only_roundtrip(void) {
    const int width  = 6;
    const int height = 6;
    const int nframes = 3;
    const int slot_w = width * 2 - 1;  // sprite_w * 2 - padding

    MbsSprite sprite;
    sprite.width_mbs    = width;
    sprite.height_mbs   = height;
    sprite.qp           = 28;
    sprite.qp_delta_idr = -2;
    sprite.qp_delta_p   = 1;

    std::vector<MbsEncodedFrame> enc(nframes);
    for (int i = 0; i < nframes; i++) {
        enc[i] = make_skip_frame(height, slot_w);
    }
    sprite.set_frames(std::move(enc));

    const char* path = "/tmp/test_skip_only_v6.mbs";
    auto save_result = sprite.save(path);
    assert(save_result.has_value());

    auto load_result = MbsSprite::load(path);
    assert(load_result.has_value());
    auto& got = *load_result;

    assert(got.width_mbs    == sprite.width_mbs);
    assert(got.height_mbs   == sprite.height_mbs);
    assert(got.num_frames   == sprite.num_frames);
    assert(got.qp           == sprite.qp);
    assert(got.qp_delta_idr == sprite.qp_delta_idr);
    assert(got.qp_delta_p   == sprite.qp_delta_p);

    for (int i = 0; i < nframes; i++) {
        assert(got.frames[i].merged_rows.size() == (size_t)height);
        /* All rows should be all-skip */
        for (int y = 0; y < height; y++) {
            assert(got.frames[i].merged_rows[y].bit_count() == 0);
        }
    }

    printf("test_skip_only_roundtrip: PASS\n");
}

/* Test 2: 2x2 MBs, 1 frame with P_16x16 and SKIP — uses encode_frame_merged */
static void test_mixed_mb_roundtrip(void) {
    const int width = 2;
    const int height = 2;
    const int padding = 1;
    const int slot_w = width * 2 - padding;

    FrameParams params{};
    params.width_mbs = width;
    params.height_mbs = height;
    params.qp = 32;

    MacroblockData color_mbs[4]{};
    color_mbs[0].mb_type = MbType::SKIP;
    color_mbs[1].mb_type = MbType::P_16x16;
    color_mbs[1].mv_x = 2; color_mbs[1].mv_y = 0;
    color_mbs[2].mb_type = MbType::SKIP;
    color_mbs[3].mb_type = MbType::SKIP;

    MacroblockData alpha_mbs[4]{};
    for (auto& mb : alpha_mbs) mb.mb_type = MbType::SKIP;

    MbsSprite sprite;
    sprite.width_mbs   = width;
    sprite.height_mbs  = height;
    sprite.qp          = 32;

    std::vector<MbsEncodedFrame> enc(1);
    enc[0] = subcodec::mbs::encode_frame_merged(params, color_mbs, params, alpha_mbs, width, padding);
    sprite.set_frames(std::move(enc));

    const char* path = "/tmp/test_mixed_mb_v6.mbs";
    auto save_result = sprite.save(path);
    assert(save_result.has_value());

    auto load_result = MbsSprite::load(path);
    assert(load_result.has_value());
    auto& got = *load_result;

    assert(got.width_mbs  == width);
    assert(got.height_mbs == height);
    assert(got.num_frames == 1);
    assert(got.frames[0].merged_rows.size() == (size_t)height);

    /* Row 0: merged color+alpha — color has [SKIP, P_16x16], alpha is all-skip.
     * The merged row should have blob data (from the P_16x16 MB). */
    assert(got.frames[0].merged_rows[0].bit_count() > 0);

    /* Row 1: all skip in both color and alpha */
    assert(got.frames[0].merged_rows[1].bit_count() == 0);
    assert(got.frames[0].merged_rows[1].leading_skips == slot_w);

    printf("test_mixed_mb_roundtrip: PASS\n");
}

/* Test 3: 20x20 MBs, 1 frame, all SKIP. Verify round-trip. */
static void test_large_frame_roundtrip(void) {
    const int w = 20, h = 20;
    const int slot_w = w * 2 - 1;

    MbsSprite sprite;
    sprite.width_mbs   = w;
    sprite.height_mbs  = h;
    sprite.qp          = 28;

    std::vector<MbsEncodedFrame> enc(1);
    enc[0] = make_skip_frame(h, slot_w);
    sprite.set_frames(std::move(enc));

    const char* path = "/tmp/test_large_frame_v6.mbs";
    auto save_result = sprite.save(path);
    assert(save_result.has_value());

    auto load_result = MbsSprite::load(path);
    assert(load_result.has_value());
    auto& got = *load_result;

    assert(got.width_mbs  == w);
    assert(got.height_mbs == h);
    assert(got.num_frames == 1);
    assert(got.frames[0].merged_rows.size() == (size_t)h);

    /* All rows all-skip */
    for (int y = 0; y < h; y++) {
        assert(got.frames[0].merged_rows[y].bit_count() == 0);
    }

    printf("test_large_frame_roundtrip: PASS\n");
}

/* Test 4: Zero-run metadata survives save/load round-trip */
static void test_metadata_roundtrip(void) {
    const int width = 2;
    const int height = 2;
    const int padding = 1;

    FrameParams params{};
    params.width_mbs = width;
    params.height_mbs = height;
    params.qp = 32;

    MacroblockData color_mbs[4]{};
    color_mbs[0].mb_type = MbType::SKIP;
    color_mbs[1].mb_type = MbType::P_16x16;
    color_mbs[1].mv_x = 2; color_mbs[1].mv_y = 0;
    color_mbs[2].mb_type = MbType::SKIP;
    color_mbs[3].mb_type = MbType::SKIP;

    MacroblockData alpha_mbs[4]{};
    for (auto& mb : alpha_mbs) mb.mb_type = MbType::SKIP;

    auto ef = subcodec::mbs::encode_frame_merged(params, color_mbs, params, alpha_mbs, width, padding);

    /* Capture metadata from merged row 0 before save */
    uint16_t orig_bbc = ef.rows[0].blob_bit_count;
    uint8_t orig_leading = ef.rows[0].leading_zero_bits;
    uint8_t orig_trailing = ef.rows[0].trailing_zero_bits;

    MbsSprite sprite;
    sprite.width_mbs   = width;
    sprite.height_mbs  = height;
    sprite.qp          = 32;

    std::vector<MbsEncodedFrame> enc;
    enc.push_back(std::move(ef));
    sprite.set_frames(std::move(enc));

    const char* path = "/tmp/test_metadata_v6.mbs";
    auto save_result = sprite.save(path);
    assert(save_result.has_value());

    auto load_result = MbsSprite::load(path);
    assert(load_result.has_value());
    auto& got = *load_result;

    /* Metadata must survive round-trip */
    assert(got.frames[0].merged_rows[0].blob_bit_count == orig_bbc);
    assert(got.frames[0].merged_rows[0].leading_zero_bits == orig_leading);
    assert(got.frames[0].merged_rows[0].trailing_zero_bits == orig_trailing);

    /* All-skip row should have zero metadata */
    assert(got.frames[0].merged_rows[1].bit_count() == 0);
    assert(got.frames[0].merged_rows[1].leading_zero_bits == 0);
    assert(got.frames[0].merged_rows[1].trailing_zero_bits == 0);

    printf("test_metadata_roundtrip: PASS\n");
}

/* Test 5: Alpha round-trip — encode_frame_merged produces merged rows,
 * verify they survive save/load round-trip correctly. */
static void test_alpha_roundtrip(void) {
    const int width  = 6;
    const int height = 6;
    const int mbs_per_frame = width * height;
    const int padding = 1;

    FrameParams params{};
    params.width_mbs  = width;
    params.height_mbs = height;
    params.qp         = 28;

    /* Color plane: all SKIP */
    std::vector<MacroblockData> color_mbs(mbs_per_frame);
    for (auto& mb : color_mbs) mb.mb_type = MbType::SKIP;

    /* Alpha plane: one P_16x16 MB with non-zero coefficients so blobs have
     * real data and the round-trip is not trivially vacuous. */
    std::vector<MacroblockData> alpha_mbs(mbs_per_frame);
    for (auto& mb : alpha_mbs) mb.mb_type = MbType::SKIP;
    // MB at position (1,0): P_16x16 with a small luma AC coefficient
    alpha_mbs[1].mb_type      = MbType::P_16x16;
    alpha_mbs[1].mv_x         = 2;
    alpha_mbs[1].mv_y         = 0;
    alpha_mbs[1].cbp_luma     = 0x1;   // block 0 has coefficients
    alpha_mbs[1].luma_ac[0][0] = 3;    // one non-zero AC coeff

    /* Encode merged frame */
    auto ef = subcodec::mbs::encode_frame_merged(params, color_mbs.data(), params, alpha_mbs.data(), width, padding);

    /* Build sprite */
    MbsSprite sprite;
    sprite.width_mbs    = width;
    sprite.height_mbs   = height;
    sprite.qp           = 28;
    sprite.qp_delta_idr = 0;
    sprite.qp_delta_p   = 0;

    /* Capture pre-save merged row metadata for comparison */
    std::vector<MbsRow> orig_rows(ef.rows.begin(), ef.rows.end());

    std::vector<MbsEncodedFrame> enc;
    enc.push_back(std::move(ef));
    sprite.set_frames(std::move(enc));

    assert(sprite.num_frames == 1);
    assert(sprite.frames[0].merged_rows.size() == (size_t)height);

    /* Save and load */
    const char* path = "/tmp/test_alpha_v6.mbs";
    auto save_result = sprite.save(path);
    assert(save_result.has_value());

    auto load_result = MbsSprite::load(path);
    assert(load_result.has_value());
    auto& got = *load_result;

    /* Verify structure */
    assert(got.num_frames == 1);
    assert(got.width_mbs  == width);
    assert(got.height_mbs == height);
    assert(got.frames[0].merged_rows.size() == (size_t)height);

    /* Verify merged row metadata matches original */
    for (int y = 0; y < height; y++) {
        auto& orig   = orig_rows[y];
        auto& loaded = got.frames[0].merged_rows[y];
        assert(loaded.leading_skips      == orig.leading_skips);
        assert(loaded.trailing_skips     == orig.trailing_skips);
        assert(loaded.blob_bit_count     == orig.blob_bit_count);
        assert(loaded.leading_zero_bits  == orig.leading_zero_bits);
        assert(loaded.trailing_zero_bits == orig.trailing_zero_bits);
    }

    /* Row 0: alpha has P_16x16 at position (1,0), so merged blob should have data */
    assert(got.frames[0].merged_rows[0].bit_count() > 0);
    assert(got.frames[0].merged_rows[0].blob_data != nullptr);

    /* Remaining rows are all-skip in both color and alpha */
    for (int y = 1; y < height; y++) {
        assert(got.frames[0].merged_rows[y].bit_count() == 0);
    }

    printf("test_alpha_roundtrip: PASS\n");
}

int main(void) {
    test_skip_only_roundtrip();
    test_mixed_mb_roundtrip();
    test_large_frame_roundtrip();
    test_metadata_roundtrip();
    test_alpha_roundtrip();
    printf("All tests passed.\n");
    return 0;
}
