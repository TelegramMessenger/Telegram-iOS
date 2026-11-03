#include <stdio.h>
#include <string.h>
#include "../src/cavlc.h"

using namespace subcodec::cavlc;

/*
 * CAVLC Read (Inverse) Round-Trip Tests
 *
 * Each test writes a coefficient block using write_block, then reads
 * it back using read_block, and verifies the coefficients match.
 */

// Helper: write block then read it back, compare
static int roundtrip(const int16_t* input, int nc, int max_num_coeff,
                     const char* name) {
    uint8_t buf[256];
    memset(buf, 0, sizeof(buf));

    // Write
    bs_t bw;
    bs_init(&bw, buf, sizeof(buf));
    int tc_write = write_block(&bw, input, nc, max_num_coeff);

    // Read back from same buffer
    bs_t br;
    bs_init(&br, buf, sizeof(buf));
    int16_t output[16] = {0};
    int tc_read = read_block(&br, output, nc, max_num_coeff);

    // Verify TotalCoeff matches
    if (tc_write != tc_read) {
        printf("FAIL: %s - TotalCoeff mismatch: write=%d read=%d\n",
               name, tc_write, tc_read);
        return 1;
    }

    // Verify coefficients match
    for (int i = 0; i < max_num_coeff; i++) {
        if (input[i] != output[i]) {
            printf("FAIL: %s - coeff[%d] mismatch: expected=%d got=%d\n",
                   name, i, input[i], output[i]);
            return 1;
        }
    }

    printf("PASS: %s (TC=%d)\n", name, tc_read);
    return 0;
}

static int test_read_block_zero(void) {
    int16_t coeffs[16] = {0};
    return roundtrip(coeffs, 0, 16, "test_read_block_zero");
}

static int test_read_block_dc_only(void) {
    int16_t coeffs[16] = {5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    return roundtrip(coeffs, 0, 16, "test_read_block_dc_only");
}

static int test_read_block_trailing_ones(void) {
    // 3 trailing +/-1 values plus a larger level
    int16_t coeffs[16] = {7, 1, -1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    return roundtrip(coeffs, 0, 16, "test_read_block_trailing_ones");
}

static int test_read_block_chroma_dc(void) {
    int16_t coeffs[4] = {10, 0, -5, 0};
    return roundtrip(coeffs, -1, 4, "test_read_block_chroma_dc");
}

static int test_read_block_ac_only(void) {
    // AC block (max_num_coeff=15), first coeff is AC[1]
    int16_t coeffs[15] = {3, 0, -2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    return roundtrip(coeffs, 0, 15, "test_read_block_ac_only");
}

static int test_read_block_all_nc_ranges(void) {
    int errors = 0;
    // nC values spanning all 5 VLC tables:
    // Table (a): nC < 2  -> 0, 1
    // Table (b): 2 <= nC < 4 -> 2, 3
    // Table (c): 4 <= nC < 8 -> 4, 5, 6, 7
    // Table (d): nC >= 8 -> 8, 9, 12
    // Table (e): nC == -1 (chroma DC, tested separately)
    int nc_values[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 12};
    int num_nc = sizeof(nc_values) / sizeof(nc_values[0]);

    int16_t coeffs[16] = {5, 0, -1, 3, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0};

    for (int i = 0; i < num_nc; i++) {
        char name[64];
        snprintf(name, sizeof(name), "test_read_block_all_nc_ranges (nc=%d)", nc_values[i]);
        errors += roundtrip(coeffs, nc_values[i], 16, name);
    }

    return errors;
}

int main(void) {
    int errors = 0;

    printf("test_cavlc_read:\n\n");

    errors += test_read_block_zero();
    errors += test_read_block_dc_only();
    errors += test_read_block_trailing_ones();
    errors += test_read_block_chroma_dc();
    errors += test_read_block_ac_only();
    errors += test_read_block_all_nc_ranges();

    printf("\n%d errors\n", errors);
    return errors;
}
