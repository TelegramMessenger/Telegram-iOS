/*
 * test_bs_copy_bits.cpp — Unit test for bs_copy_bits bulk bit copy
 *
 * Standalone test (no framework). Return 0=PASS, 1=FAIL.
 */

#include "mbs_mux_common.h"
#include "bs.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>

using namespace subcodec::mux;

static int failures = 0;

#define CHECK(cond, msg) do { \
    if (!(cond)) { \
        printf("  FAIL: %s\n", msg); \
        failures++; \
        return; \
    } \
} while(0)

/* Helper: count bits written to a bs_t */
static int bs_bits_written(bs_t* b) {
    return (int)(b->p - b->start) * 8 + (8 - b->bits_left);
}

/* Helper: extract bit i from a byte array (MSB-first) */
static int get_bit(const uint8_t* data, int bit_idx) {
    return (data[bit_idx / 8] >> (7 - (bit_idx % 8))) & 1;
}

/* ---- Test: aligned copy ---- */
static void test_aligned_copy() {
    printf("test_aligned_copy: ");

    uint8_t src[4] = {0xDE, 0xAD, 0xBE, 0xEF};
    uint8_t dst_buf[8] = {};
    bs_t dst;
    bs_init(&dst, dst_buf, sizeof(dst_buf));

    bs_copy_bits(&dst, src, 0, 32);

    CHECK(bs_bits_written(&dst) == 32, "should write 32 bits");
    CHECK(dst_buf[0] == 0xDE, "byte 0");
    CHECK(dst_buf[1] == 0xAD, "byte 1");
    CHECK(dst_buf[2] == 0xBE, "byte 2");
    CHECK(dst_buf[3] == 0xEF, "byte 3");

    printf("PASS\n");
}

/* ---- Test: offset copy ---- */
static void test_offset_copy() {
    printf("test_offset_copy: ");

    // src = 0xDE = 1101_1110, we skip 4 bits, read 12 bits
    // bits at offset 4: 1110 + next 8 bits of 0xAD = 1010_1101
    // so 12 bits = 1110_1010_1101
    uint8_t src[4] = {0xDE, 0xAD, 0xBE, 0xEF};
    uint8_t dst_buf[8] = {};
    bs_t dst;
    bs_init(&dst, dst_buf, sizeof(dst_buf));

    bs_copy_bits(&dst, src, 4, 12);

    CHECK(bs_bits_written(&dst) == 12, "should write 12 bits");

    // Verify bit by bit
    for (int i = 0; i < 12; i++) {
        int expected = get_bit(src, 4 + i);
        int actual = get_bit(dst_buf, i);
        if (expected != actual) {
            printf("  FAIL: bit %d expected %d got %d\n", i, expected, actual);
            failures++;
            return;
        }
    }

    printf("PASS\n");
}

/* ---- Test: unaligned dst ---- */
static void test_unaligned_dst() {
    printf("test_unaligned_dst: ");

    uint8_t src[4] = {0xDE, 0xAD, 0xBE, 0xEF};
    uint8_t dst_buf[8] = {};
    bs_t dst;
    bs_init(&dst, dst_buf, sizeof(dst_buf));

    // Write 3 bits first to misalign dst
    bs_write_u(&dst, 3, 0x5);  // 101

    bs_copy_bits(&dst, src, 0, 16);

    CHECK(bs_bits_written(&dst) == 19, "should write 3+16=19 bits");

    // Verify: first 3 bits = 101, then 16 bits of 0xDEAD
    // Bit-by-bit check
    // dst_buf should start with: 101_11011_110_10101_101...
    // = 1011_1011 1101_0101 101x_xxxx
    // First verify the 16 copied bits match src
    for (int i = 0; i < 16; i++) {
        int expected = get_bit(src, i);
        int actual = get_bit(dst_buf, 3 + i);
        if (expected != actual) {
            printf("  FAIL: bit %d expected %d got %d\n", i, expected, actual);
            failures++;
            return;
        }
    }

    printf("PASS\n");
}

/* ---- Test: zero bits ---- */
static void test_zero_bits() {
    printf("test_zero_bits: ");

    uint8_t src[4] = {0xFF, 0xFF, 0xFF, 0xFF};
    uint8_t dst_buf[8] = {};
    bs_t dst;
    bs_init(&dst, dst_buf, sizeof(dst_buf));

    bs_copy_bits(&dst, src, 0, 0);

    CHECK(bs_bits_written(&dst) == 0, "should write 0 bits");
    CHECK(dst_buf[0] == 0, "dst should be untouched");

    printf("PASS\n");
}

/* ---- Test: round-trip vs bit-by-bit ---- */
static void test_round_trip() {
    printf("test_round_trip (100 trials): ");

    srand(42);

    for (int trial = 0; trial < 100; trial++) {
        int src_offset = rand() % 8;
        int nbits = 1 + (rand() % 64);

        // Need enough source bytes
        int src_bytes = (src_offset + nbits + 7) / 8 + 1;
        uint8_t src[16] = {};
        for (int i = 0; i < src_bytes && i < 16; i++) {
            src[i] = (uint8_t)(rand() & 0xFF);
        }

        // Reference: bit-by-bit copy
        uint8_t ref_buf[16] = {};
        bs_t ref;
        bs_init(&ref, ref_buf, sizeof(ref_buf));
        {
            // Use a read bs to extract bits
            bs_t rd;
            bs_init(&rd, src, sizeof(src));
            // Skip to src_offset
            for (int i = 0; i < src_offset; i++) bs_read_u1(&rd);
            for (int i = 0; i < nbits; i++) {
                bs_write_u1(&ref, bs_read_u1(&rd));
            }
        }
        int ref_bits = bs_bits_written(&ref);

        // Test: bs_copy_bits
        uint8_t test_buf[16] = {};
        bs_t test;
        bs_init(&test, test_buf, sizeof(test_buf));
        bs_copy_bits(&test, src, src_offset, nbits);
        int test_bits = bs_bits_written(&test);

        if (ref_bits != test_bits) {
            printf("  FAIL trial %d: ref wrote %d bits, test wrote %d\n",
                   trial, ref_bits, test_bits);
            failures++;
            return;
        }

        int ref_bytes = (ref_bits + 7) / 8;
        // Compare only the bits that were written (mask trailing bits in last byte)
        for (int i = 0; i < ref_bytes; i++) {
            uint8_t mask = 0xFF;
            if (i == ref_bytes - 1) {
                int tail = ref_bits % 8;
                if (tail != 0) mask = (uint8_t)(0xFF << (8 - tail));
            }
            if ((ref_buf[i] & mask) != (test_buf[i] & mask)) {
                printf("  FAIL trial %d: byte %d ref=0x%02X test=0x%02X (mask=0x%02X)\n",
                       trial, i, ref_buf[i] & mask, test_buf[i] & mask, mask);
                printf("    src_offset=%d nbits=%d\n", src_offset, nbits);
                failures++;
                return;
            }
        }
    }

    printf("PASS\n");
}

/* ---- Test: unaligned dst + offset src ---- */
static void test_both_unaligned() {
    printf("test_both_unaligned: ");

    srand(123);

    for (int trial = 0; trial < 100; trial++) {
        int dst_pre = 1 + (rand() % 7);   // 1-7 bits pre-written to dst
        int src_offset = rand() % 8;
        int nbits = 1 + (rand() % 48);

        int src_bytes = (src_offset + nbits + 7) / 8 + 1;
        uint8_t src[16] = {};
        for (int i = 0; i < src_bytes && i < 16; i++) {
            src[i] = (uint8_t)(rand() & 0xFF);
        }

        uint8_t pre_val = (uint8_t)(rand() & ((1 << dst_pre) - 1));

        // Reference: bit-by-bit
        uint8_t ref_buf[16] = {};
        bs_t ref;
        bs_init(&ref, ref_buf, sizeof(ref_buf));
        bs_write_u(&ref, dst_pre, pre_val);
        {
            bs_t rd;
            bs_init(&rd, src, sizeof(src));
            for (int i = 0; i < src_offset; i++) bs_read_u1(&rd);
            for (int i = 0; i < nbits; i++) {
                bs_write_u1(&ref, bs_read_u1(&rd));
            }
        }
        int ref_bits = bs_bits_written(&ref);

        // Test
        uint8_t test_buf[16] = {};
        bs_t test;
        bs_init(&test, test_buf, sizeof(test_buf));
        bs_write_u(&test, dst_pre, pre_val);
        bs_copy_bits(&test, src, src_offset, nbits);
        int test_bits = bs_bits_written(&test);

        if (ref_bits != test_bits) {
            printf("  FAIL trial %d: ref %d bits, test %d bits\n",
                   trial, ref_bits, test_bits);
            failures++;
            return;
        }

        int bytes = (ref_bits + 7) / 8;
        for (int i = 0; i < bytes; i++) {
            uint8_t mask = 0xFF;
            if (i == bytes - 1) {
                int tail = ref_bits % 8;
                if (tail != 0) mask = (uint8_t)(0xFF << (8 - tail));
            }
            if ((ref_buf[i] & mask) != (test_buf[i] & mask)) {
                printf("  FAIL trial %d: byte %d ref=0x%02X test=0x%02X\n",
                       trial, i, ref_buf[i] & mask, test_buf[i] & mask);
                failures++;
                return;
            }
        }
    }

    printf("PASS\n");
}

int main() {
    printf("=== test_bs_copy_bits ===\n");

    test_aligned_copy();
    test_offset_copy();
    test_unaligned_dst();
    test_zero_bits();
    test_round_trip();
    test_both_unaligned();

    printf("\n%s (%d failure%s)\n",
           failures ? "FAILED" : "ALL PASSED",
           failures, failures == 1 ? "" : "s");
    return failures ? 1 : 0;
}
