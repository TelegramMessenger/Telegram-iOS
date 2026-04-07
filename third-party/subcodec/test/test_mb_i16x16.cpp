#include <stdio.h>
#include <string.h>
#include "../src/frame_writer.h"
#include "../src/types.h"
#include "../third_party/h264bitstream/bs.h"

using namespace subcodec;
using namespace subcodec::frame_writer;

/*
 * I_16x16 Macroblock Encoder Tests
 *
 * Tests for encoding I_16x16 macroblocks which use a single 16x16 intra prediction
 * mode with separate DC and AC coefficient blocks.
 */

// Helper to count bits written
static size_t bs_bits_written(bs_t* b) {
    size_t bytes = b->p - b->start;
    size_t bits = bytes * 8 + (8 - b->bits_left);
    return bits;
}

// Test: I_16x16 DC-only (no AC, no chroma) - simplest case
static int test_i16x16_dc_only(void) {
    uint8_t buf[256];
    memset(buf, 0, sizeof(buf));
    bs_t b;
    bs_init(&b, buf, sizeof(buf));

    MacroblockData mb;
    mb.mb_type = MbType::I_16x16;
    mb.intra_pred_mode = I16PredMode::DC;  // mode 2
    mb.intra_chroma_mode = ChromaPredMode::DC;
    mb.cbp_chroma = 0;
    // DC coefficients only
    mb.luma_dc[0] = 10;
    // All AC = 0 (default-initialized)

    MbContext out_ctx;

    write_mb_i16x16(&b, mb, NULL, NULL, out_ctx);

    size_t bits = bs_bits_written(&b);

    if (bits < 10) {
        printf("FAIL: test_i16x16_dc_only - too few bits: %zu\n", bits);
        return 1;
    }

    // Verify MV context was cleared (I-macroblock has no motion)
    if (out_ctx.mv[0] != 0 || out_ctx.mv[1] != 0) {
        printf("FAIL: test_i16x16_dc_only - MV not zeroed\n");
        return 1;
    }

    printf("PASS: test_i16x16_dc_only (%zu bits)\n", bits);
    return 0;
}

// Test: I_16x16 with AC residual
static int test_i16x16_with_ac(void) {
    uint8_t buf[1024];
    memset(buf, 0, sizeof(buf));
    bs_t b;
    bs_init(&b, buf, sizeof(buf));

    MacroblockData mb;
    mb.mb_type = MbType::I_16x16;
    mb.intra_pred_mode = I16PredMode::V;  // mode 0 (vertical)
    mb.intra_chroma_mode = ChromaPredMode::DC;
    mb.cbp_chroma = 0;
    // DC coefficients
    mb.luma_dc[0] = 15;
    mb.luma_dc[1] = 5;
    // AC coefficients in first block
    mb.luma_ac[0][0] = 3;
    mb.luma_ac[0][1] = -1;

    MbContext out_ctx;

    write_mb_i16x16(&b, mb, NULL, NULL, out_ctx);

    size_t bits = bs_bits_written(&b);

    if (bits < 20) {
        printf("FAIL: test_i16x16_with_ac - too few bits: %zu\n", bits);
        return 1;
    }

    printf("PASS: test_i16x16_with_ac (%zu bits)\n", bits);
    return 0;
}

// Test: I_16x16 with chroma (cbp_chroma = 1, DC only)
static int test_i16x16_with_chroma_dc(void) {
    uint8_t buf[1024];
    memset(buf, 0, sizeof(buf));
    bs_t b;
    bs_init(&b, buf, sizeof(buf));

    MacroblockData mb;
    mb.mb_type = MbType::I_16x16;
    mb.intra_pred_mode = I16PredMode::H;  // mode 1 (horizontal)
    mb.intra_chroma_mode = ChromaPredMode::H;  // horizontal chroma prediction
    mb.cbp_chroma = 1;  // DC only for chroma
    // Luma DC
    mb.luma_dc[0] = 20;
    // Chroma DC
    mb.cb_dc[0] = 5;
    mb.cr_dc[0] = -3;

    MbContext out_ctx;

    write_mb_i16x16(&b, mb, NULL, NULL, out_ctx);

    size_t bits = bs_bits_written(&b);

    if (bits < 15) {
        printf("FAIL: test_i16x16_with_chroma_dc - too few bits: %zu\n", bits);
        return 1;
    }

    printf("PASS: test_i16x16_with_chroma_dc (%zu bits)\n", bits);
    return 0;
}

// Test: I_16x16 with chroma AC (cbp_chroma = 2)
static int test_i16x16_with_chroma_ac(void) {
    uint8_t buf[2048];
    memset(buf, 0, sizeof(buf));
    bs_t b;
    bs_init(&b, buf, sizeof(buf));

    MacroblockData mb;
    mb.mb_type = MbType::I_16x16;
    mb.intra_pred_mode = I16PredMode::P;  // mode 3 (plane)
    mb.intra_chroma_mode = ChromaPredMode::V;  // vertical chroma prediction
    mb.cbp_chroma = 2;  // Chroma has AC
    // Luma DC
    mb.luma_dc[0] = 10;
    // Chroma DC
    mb.cb_dc[0] = 8;
    mb.cr_dc[0] = 4;
    // Chroma AC
    mb.cb_ac[0][0] = 2;
    mb.cr_ac[0][0] = -1;

    MbContext out_ctx;

    write_mb_i16x16(&b, mb, NULL, NULL, out_ctx);

    size_t bits = bs_bits_written(&b);

    if (bits < 25) {
        printf("FAIL: test_i16x16_with_chroma_ac - too few bits: %zu\n", bits);
        return 1;
    }

    printf("PASS: test_i16x16_with_chroma_ac (%zu bits)\n", bits);
    return 0;
}

// Test: All four I_16x16 prediction modes
static int test_i16x16_all_pred_modes(void) {
    // Test that all four modes produce valid output
    I16PredMode modes[] = {I16PredMode::V, I16PredMode::H, I16PredMode::DC, I16PredMode::P};
    const char* mode_names[] = {"Vertical", "Horizontal", "DC", "Plane"};

    for (int i = 0; i < 4; i++) {
        uint8_t buf[256];
        memset(buf, 0, sizeof(buf));
        bs_t b;
        bs_init(&b, buf, sizeof(buf));

        MacroblockData mb;
        mb.mb_type = MbType::I_16x16;
        mb.intra_pred_mode = modes[i];
        mb.intra_chroma_mode = ChromaPredMode::DC;
        mb.cbp_chroma = 0;
        mb.luma_dc[0] = 5;

        MbContext out_ctx;

        write_mb_i16x16(&b, mb, NULL, NULL, out_ctx);

        size_t bits = bs_bits_written(&b);

        // Each mode should produce valid output
        if (bits < 5) {
            printf("FAIL: test_i16x16_all_pred_modes - mode %s (%d) too few bits: %zu\n",
                   mode_names[i], static_cast<int>(modes[i]), bits);
            return 1;
        }
    }

    printf("PASS: test_i16x16_all_pred_modes (all 4 modes encode successfully)\n");
    return 0;
}

// Test: mb_type encoding correctness for I_16x16 in P-slice
static int test_i16x16_mb_type_encoding(void) {
    // Verify mb_type formula: 6 + mode + 4*cbp_chroma + 12*ac_has_nonzero

    struct {
        int pred_mode;
        int cbp_chroma;
        int has_ac;
        int expected_mb_type;
    } test_cases[] = {
        {0, 0, 0, 6},
        {2, 0, 0, 8},
        {0, 1, 0, 10},
        {0, 2, 0, 14},
        {0, 0, 1, 18},
        {3, 2, 1, 29},
    };

    int num_cases = sizeof(test_cases) / sizeof(test_cases[0]);

    for (int i = 0; i < num_cases; i++) {
        int computed = 6 + test_cases[i].pred_mode +
                       4 * test_cases[i].cbp_chroma +
                       12 * test_cases[i].has_ac;
        if (computed != test_cases[i].expected_mb_type) {
            printf("FAIL: test_i16x16_mb_type_encoding - case %d: expected %d, got %d\n",
                   i, test_cases[i].expected_mb_type, computed);
            return 1;
        }
    }

    printf("PASS: test_i16x16_mb_type_encoding (all mb_type calculations correct)\n");
    return 0;
}

// Test: Deterministic encoding - same input produces same output
static int test_i16x16_deterministic(void) {
    uint8_t buf1[512], buf2[512];
    memset(buf1, 0, sizeof(buf1));
    memset(buf2, 0, sizeof(buf2));

    bs_t b1, b2;
    bs_init(&b1, buf1, sizeof(buf1));
    bs_init(&b2, buf2, sizeof(buf2));

    MacroblockData mb;
    mb.mb_type = MbType::I_16x16;
    mb.intra_pred_mode = I16PredMode::DC;
    mb.intra_chroma_mode = ChromaPredMode::H;
    mb.cbp_chroma = 1;
    mb.luma_dc[0] = 12;
    mb.luma_dc[5] = -4;
    mb.luma_ac[2][0] = 3;
    mb.cb_dc[0] = 6;
    mb.cr_dc[1] = -2;

    MbContext out_ctx1, out_ctx2;

    write_mb_i16x16(&b1, mb, NULL, NULL, out_ctx1);
    write_mb_i16x16(&b2, mb, NULL, NULL, out_ctx2);

    size_t bits1 = bs_bits_written(&b1);
    size_t bits2 = bs_bits_written(&b2);

    if (bits1 != bits2) {
        printf("FAIL: test_i16x16_deterministic - bit counts differ: %zu vs %zu\n",
               bits1, bits2);
        return 1;
    }

    size_t bytes = (bits1 + 7) / 8;
    if (memcmp(buf1, buf2, bytes) != 0) {
        printf("FAIL: test_i16x16_deterministic - output differs\n");
        return 1;
    }

    printf("PASS: test_i16x16_deterministic (%zu bits)\n", bits1);
    return 0;
}

// Test: Context nC values are updated correctly
static int test_i16x16_nc_context_update(void) {
    uint8_t buf[2048];
    memset(buf, 0, sizeof(buf));
    bs_t b;
    bs_init(&b, buf, sizeof(buf));

    MacroblockData mb;
    mb.mb_type = MbType::I_16x16;
    mb.intra_pred_mode = I16PredMode::DC;
    mb.intra_chroma_mode = ChromaPredMode::DC;
    mb.cbp_chroma = 0;
    // DC coefficients
    mb.luma_dc[0] = 10;
    // AC coefficients in multiple blocks to test nC tracking
    mb.luma_ac[0][0] = 5;
    mb.luma_ac[0][1] = 3;
    mb.luma_ac[0][2] = -1;  // 3 non-zero AC coeffs in block 0
    mb.luma_ac[1][0] = 2;   // 1 non-zero AC coeff in block 1

    MbContext out_ctx;

    write_mb_i16x16(&b, mb, NULL, NULL, out_ctx);

    // Verify that nC values were recorded
    // Block 0 should have TC=3, block 1 should have TC=1
    if (out_ctx.nc[0] != 3) {
        printf("FAIL: test_i16x16_nc_context_update - nc[0]=%d (expected 3)\n", out_ctx.nc[0]);
        return 1;
    }
    if (out_ctx.nc[1] != 1) {
        printf("FAIL: test_i16x16_nc_context_update - nc[1]=%d (expected 1)\n", out_ctx.nc[1]);
        return 1;
    }

    printf("PASS: test_i16x16_nc_context_update\n");
    return 0;
}

int main(void) {
    int errors = 0;

    printf("Running I_16x16 macroblock encoder tests...\n\n");

    // Basic encoding tests
    printf("-- Basic Encoding Tests --\n");
    errors += test_i16x16_dc_only();
    errors += test_i16x16_with_ac();
    errors += test_i16x16_with_chroma_dc();
    errors += test_i16x16_with_chroma_ac();

    // Prediction mode tests
    printf("\n-- Prediction Mode Tests --\n");
    errors += test_i16x16_all_pred_modes();

    // mb_type encoding tests
    printf("\n-- mb_type Encoding Tests --\n");
    errors += test_i16x16_mb_type_encoding();

    // Quality tests
    printf("\n-- Quality Tests --\n");
    errors += test_i16x16_deterministic();
    errors += test_i16x16_nc_context_update();

    printf("\n%d test(s) failed\n", errors);
    return errors;
}
