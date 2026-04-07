/*
 * test_cavlc_split.c — CAVLC split round-trip test
 *
 * Verifies that splitting a CAVLC block into (TC, T1, tail_blob) and
 * reconstructing with a different nC-selected coeff_token produces valid
 * CAVLC that decodes to the same coefficients.
 *
 * The "tail blob" is everything after coeff_token:
 *   trailing-ones signs + levels + total_zeros + run_before
 *
 * Re-encoding means: write coeff_token(tc, t1, dst_nc) + copy tail bits.
 * This mimics the compositor re-encoding CAVLC with corrected neighbor context.
 */

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "../src/cavlc.h"

using namespace subcodec::cavlc;

/* ---- Helpers ---- */

/* Count bits written to a bs_t since bs_init */
static int bs_bits_written(const bs_t* b) {
    int bytes = (int)(b->p - b->start);
    int bits_used = 8 - b->bits_left;
    return bytes * 8 + bits_used;
}

/*
 * Encode the tail of a CAVLC block (everything after coeff_token):
 *   trailing-ones signs, levels, total_zeros, run_before.
 *
 * Returns the number of tail bits written, and sets *out_tc and *out_t1.
 * tail_buf must be at least 64 bytes.
 */
static int encode_tail(const int16_t* coeffs, int max_num_coeff,
                       uint8_t* tail_buf, size_t tail_buf_size,
                       int* out_tc, int* out_t1) {
    int16_t levels[16];
    int total_coeff = 0;
    int trailing_ones = 0;
    int last_nz = -1;

    /* Scan from high-freq end to low-freq end */
    for (int i = max_num_coeff - 1; i >= 0; i--) {
        if (coeffs[i] != 0) {
            if (last_nz < 0) last_nz = i;
            levels[total_coeff] = coeffs[i];
            total_coeff++;
        }
    }

    *out_tc = total_coeff;

    if (total_coeff == 0) {
        *out_t1 = 0;
        return 0;
    }

    /* Count trailing ones */
    for (int i = 0; i < total_coeff && i < 3; i++) {
        if (levels[i] == 1 || levels[i] == -1) {
            trailing_ones++;
        } else {
            break;
        }
    }
    *out_t1 = trailing_ones;

    memset(tail_buf, 0, tail_buf_size);
    bs_t b;
    bs_init(&b, tail_buf, tail_buf_size);

    /* Trailing-ones signs (reverse order) */
    for (int i = trailing_ones - 1; i >= 0; i--) {
        bs_write_u1(&b, levels[i] < 0 ? 1 : 0);
    }

    /* Remaining levels */
    int suffix_length = (total_coeff > 10 && trailing_ones < 3) ? 1 : 0;
    for (int i = trailing_ones; i < total_coeff; i++) {
        int original_level = levels[i];
        int level = original_level;
        if (i == trailing_ones && trailing_ones < 3) {
            level = (level > 0) ? level - 1 : level + 1;
        }
        write_level(&b, level, &suffix_length);
        int abs_level = (original_level < 0) ? -original_level : original_level;
        if (suffix_length == 0) suffix_length = 1;
        if (abs_level > (3 << (suffix_length - 1)) && suffix_length < 6)
            suffix_length++;
    }

    /* total_zeros */
    if (total_coeff < max_num_coeff) {
        int total_zeros = last_nz + 1 - total_coeff;
        write_total_zeros(&b, total_zeros, total_coeff, max_num_coeff);
    }

    /* run_before */
    int zeros_left = last_nz + 1 - total_coeff;
    int coeff_idx = 0;
    for (int i = max_num_coeff - 1; i >= 0 && coeff_idx < total_coeff - 1; i--) {
        if (coeffs[i] != 0) {
            int run = 0;
            for (int j = i - 1; j >= 0; j--) {
                if (coeffs[j] == 0) run++;
                else break;
            }
            if (zeros_left > 0) {
                write_run_before(&b, run, zeros_left);
                zeros_left -= run;
            }
            coeff_idx++;
        }
    }

    return bs_bits_written(&b);
}

/*
 * Reconstruct a CAVLC block with a new nC by writing coeff_token(tc, t1,
 * dst_nc) followed by the raw tail bits, then decode back and compare.
 *
 * Returns 0 on pass, 1 on failure.
 */
static int roundtrip_split(const int16_t* orig, int max_num_coeff,
                           int src_nc, int dst_nc,
                           const char* test_name) {
    /* Step 1: encode tail blob */
    uint8_t tail_buf[128];
    int tc, t1;
    int tail_bits = encode_tail(orig, max_num_coeff,
                                tail_buf, sizeof(tail_buf), &tc, &t1);

    /* Step 2: reconstruct: coeff_token(tc, t1, dst_nc) + tail bits */
    uint8_t reenc_buf[256];
    memset(reenc_buf, 0, sizeof(reenc_buf));
    bs_t bw;
    bs_init(&bw, reenc_buf, sizeof(reenc_buf));

    write_coeff_token(&bw, tc, t1, dst_nc);

    /* Append tail bits */
    for (int i = 0; i < tail_bits; i++) {
        int byte_idx = i / 8;
        int bit_idx  = 7 - (i % 8);
        int bit = (tail_buf[byte_idx] >> bit_idx) & 1;
        bs_write_u1(&bw, (uint32_t)bit);
    }

    /* Step 3: decode with dst_nc */
    bs_t br;
    bs_init(&br, reenc_buf, sizeof(reenc_buf));
    int16_t decoded[16];
    memset(decoded, 0, sizeof(decoded));
    int tc_read = read_block(&br, decoded, dst_nc, max_num_coeff);

    /* Step 4: compare */
    int fail = 0;

    if (tc_read != tc) {
        printf("FAIL: %s src_nc=%d dst_nc=%d — TC mismatch: expected %d, got %d\n",
               test_name, src_nc, dst_nc, tc, tc_read);
        fail = 1;
    }

    for (int i = 0; i < max_num_coeff && !fail; i++) {
        if (decoded[i] != orig[i]) {
            printf("FAIL: %s src_nc=%d dst_nc=%d — coeff[%d] expected %d got %d\n",
                   test_name, src_nc, dst_nc, i, orig[i], decoded[i]);
            fail = 1;
        }
    }

    if (!fail) {
        printf("PASS: %s src_nc=%d dst_nc=%d (TC=%d T1=%d tail_bits=%d)\n",
               test_name, src_nc, dst_nc, tc, t1, tail_bits);
    }

    return fail;
}

/* ---- Test vectors ---- */

static int test_all_zeros(void) {
    int16_t coeffs[16] = {0};
    int errors = 0;
    int nc_vals[] = {0, 1, 2, 3, 4, 6, 8, 12};
    int num_nc = (int)(sizeof(nc_vals) / sizeof(nc_vals[0]));
    for (int i = 0; i < num_nc; i++)
        for (int j = 0; j < num_nc; j++)
            errors += roundtrip_split(coeffs, 16, nc_vals[i], nc_vals[j], "all_zeros");
    return errors;
}

static int test_dc_only(void) {
    /* TC=1, T1=0 */
    int16_t coeffs[16] = {5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    int errors = 0;
    int nc_vals[] = {0, 1, 2, 3, 4, 6, 8, 12};
    int num_nc = (int)(sizeof(nc_vals) / sizeof(nc_vals[0]));
    for (int i = 0; i < num_nc; i++)
        for (int j = 0; j < num_nc; j++)
            errors += roundtrip_split(coeffs, 16, nc_vals[i], nc_vals[j], "dc_only");
    return errors;
}

static int test_tc3_t1_2(void) {
    /* TC=3, T1=2: two trailing ±1, one larger level */
    int16_t coeffs[16] = {3, 1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    int errors = 0;
    int nc_vals[] = {0, 1, 2, 3, 4, 6, 8, 12};
    int num_nc = (int)(sizeof(nc_vals) / sizeof(nc_vals[0]));
    for (int i = 0; i < num_nc; i++)
        for (int j = 0; j < num_nc; j++)
            errors += roundtrip_split(coeffs, 16, nc_vals[i], nc_vals[j], "tc3_t1_2");
    return errors;
}

static int test_tc7_t1_3(void) {
    /* TC=7, T1=3: 3 trailing ±1, 4 larger levels scattered */
    int16_t coeffs[16] = {0, 4, 0, -2, 3, 0, 1, -1, 1, 0, 0, 0, 0, 0, 0, 0};
    int errors = 0;
    int nc_vals[] = {0, 1, 2, 3, 4, 6, 8, 12};
    int num_nc = (int)(sizeof(nc_vals) / sizeof(nc_vals[0]));
    for (int i = 0; i < num_nc; i++)
        for (int j = 0; j < num_nc; j++)
            errors += roundtrip_split(coeffs, 16, nc_vals[i], nc_vals[j], "tc7_t1_3");
    return errors;
}

static int test_max_coeff_15(void) {
    /* max_num_coeff=15 (AC block), TC=15 */
    int16_t coeffs[15] = {2, -1, 1, -1, 3, -2, 1, -1, 1, 4, -1, 1, -1, 1, -1};
    int errors = 0;
    int nc_vals[] = {0, 1, 2, 3, 4, 6, 8, 12};
    int num_nc = (int)(sizeof(nc_vals) / sizeof(nc_vals[0]));
    for (int i = 0; i < num_nc; i++)
        for (int j = 0; j < num_nc; j++)
            errors += roundtrip_split(coeffs, 15, nc_vals[i], nc_vals[j], "max_coeff_15");
    return errors;
}

int main(void) {
    int errors = 0;

    printf("=== test_all_zeros ===\n");
    errors += test_all_zeros();

    printf("\n=== test_dc_only ===\n");
    errors += test_dc_only();

    printf("\n=== test_tc3_t1_2 ===\n");
    errors += test_tc3_t1_2();

    printf("\n=== test_tc7_t1_3 ===\n");
    errors += test_tc7_t1_3();

    printf("\n=== test_max_coeff_15 ===\n");
    errors += test_max_coeff_15();

    printf("\nCAVLC split round-trip: %d errors total\n", errors);
    if (errors == 0) {
        printf("PASS\n");
        return 0;
    } else {
        printf("FAIL\n");
        return 1;
    }
}
