/*
 * test_ct_lut.c — Coeff_token LUT correctness test
 *
 * Verifies that the coeff_token LUT in mbs_mux (rebuilt here via the same
 * algorithm) matches direct write_coeff_token() encoding bit-for-bit
 * for all valid (nC, TC, T1) combinations.
 */

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "../src/cavlc.h"

using namespace subcodec::cavlc;

/* ---- LUT types (mirroring mbs_mux.c) ---- */

typedef struct {
    uint32_t code;
    int len;
} ct_entry_t;

#define CT_NR 4
#define CT_TC 17
#define CT_T1 4

static ct_entry_t ct_lut[CT_NR][CT_TC][CT_T1];

/* nC representative values for each range */
static const int nc_for_range[CT_NR] = {0, 2, 4, 8};

static void build_ct_lut(void) {
    for (int nr = 0; nr < CT_NR; nr++) {
        int nc = nc_for_range[nr];
        for (int tc = 0; tc <= 16; tc++) {
            for (int t1 = 0; t1 <= 3; t1++) {
                if (t1 > tc || (tc == 0 && t1 != 0)) {
                    ct_lut[nr][tc][t1].code = 0;
                    ct_lut[nr][tc][t1].len  = 0;
                    continue;
                }

                uint8_t tmp[8];
                memset(tmp, 0, sizeof(tmp));
                bs_t b;
                bs_init(&b, tmp, sizeof(tmp));

                write_coeff_token(&b, tc, t1, nc);

                int bits = (int)(b.p - b.start) * 8 + (8 - b.bits_left);
                uint32_t code = 0;
                for (int i = 0; i < bits; i++) {
                    int byte_idx = i / 8;
                    int bit_idx  = 7 - (i % 8);
                    code = (code << 1) | ((tmp[byte_idx] >> bit_idx) & 1);
                }

                ct_lut[nr][tc][t1].code = code;
                ct_lut[nr][tc][t1].len  = bits;
            }
        }
    }
}

/* Map an nC value to a range index */
static int nc_to_range(int nc) {
    if (nc < 2) return 0;
    if (nc < 4) return 1;
    if (nc < 8) return 2;
    return 3;
}

/*
 * For a given (tc, t1, nc):
 *   1. Encode directly with write_coeff_token() → extract bits/code.
 *   2. Look up LUT entry for the same (tc, t1, range(nc)).
 *   3. Compare.
 * Returns 0 on pass, 1 on failure.
 */
static int check_one(int tc, int t1, int nc, int* combos_tested) {
    /* Encode directly */
    uint8_t direct_buf[8];
    memset(direct_buf, 0, sizeof(direct_buf));
    bs_t bd;
    bs_init(&bd, direct_buf, sizeof(direct_buf));
    write_coeff_token(&bd, tc, t1, nc);

    int direct_bits = (int)(bd.p - bd.start) * 8 + (8 - bd.bits_left);
    uint32_t direct_code = 0;
    for (int i = 0; i < direct_bits; i++) {
        int byte_idx = i / 8;
        int bit_idx  = 7 - (i % 8);
        direct_code = (direct_code << 1) | ((direct_buf[byte_idx] >> bit_idx) & 1);
    }

    /* Encode via LUT: bs_write_u(len, code) */
    int nr = nc_to_range(nc);
    ct_entry_t* e = &ct_lut[nr][tc][t1];

    uint8_t lut_buf[8];
    memset(lut_buf, 0, sizeof(lut_buf));
    bs_t bl;
    bs_init(&bl, lut_buf, sizeof(lut_buf));
    if (e->len > 0) {
        bs_write_u(&bl, e->len, e->code);
    }
    int lut_bits = (int)(bl.p - bl.start) * 8 + (8 - bl.bits_left);
    uint32_t lut_code = 0;
    for (int i = 0; i < lut_bits; i++) {
        int byte_idx = i / 8;
        int bit_idx  = 7 - (i % 8);
        lut_code = (lut_code << 1) | ((lut_buf[byte_idx] >> bit_idx) & 1);
    }

    (*combos_tested)++;

    if (direct_bits != lut_bits || direct_code != lut_code) {
        printf("FAIL: nc=%d (range %d) tc=%d t1=%d — "
               "direct(%d bits, code=0x%X) != lut(%d bits, code=0x%X)\n",
               nc, nr, tc, t1,
               direct_bits, direct_code,
               lut_bits, lut_code);
        return 1;
    }
    return 0;
}

int main(void) {
    build_ct_lut();

    /* nC test values spanning all ranges: 0,1 (range 0), 2,3 (range 1),
     * 4,5,6,7 (range 2), 8,12,16 (range 3) */
    const int nc_values[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 16};
    const int num_nc = (int)(sizeof(nc_values) / sizeof(nc_values[0]));

    int errors = 0;
    int combos_tested = 0;

    for (int ni = 0; ni < num_nc; ni++) {
        int nc = nc_values[ni];
        int max_tc = (nc == -1) ? 4 : 16;
        for (int tc = 0; tc <= max_tc; tc++) {
            int max_t1 = (tc < 3) ? tc : 3;
            for (int t1 = 0; t1 <= max_t1; t1++) {
                errors += check_one(tc, t1, nc, &combos_tested);
            }
        }
    }

    printf("\ncoeff_token LUT test: %d combinations tested, %d errors\n",
           combos_tested, errors);

    if (errors == 0) {
        printf("PASS: all coeff_token LUT entries match direct encoding\n");
        return 0;
    } else {
        printf("FAIL: %d mismatches found\n", errors);
        return 1;
    }
}
