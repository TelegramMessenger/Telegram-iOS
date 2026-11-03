#include "cavlc.h"
#include <cassert>
#include <cstring>

namespace subcodec::cavlc {

// coeff_token VLC tables from H.264 spec Table 9-5
// Format: {code, length} for each (TotalCoeff, TrailingOnes) pair
// Indexed by [trailing_ones][total_coeff]

struct vlc_t {
    uint16_t code;
    uint8_t len;
};

// Table 9-5(a): 0 <= nC < 2
// Indexed by [trailing_ones][total_coeff]
// trailing_ones: 0-3, total_coeff: 0-16
static const vlc_t coeff_token_table_0[4][17] = {
    // TrailingOnes = 0
    {
        {0x01,  1}, {0x05,  6}, {0x07,  8}, {0x07,  9}, {0x07, 10}, {0x07, 11}, {0x0F, 13}, {0x0B, 13}, {0x08, 13},
        {0x0F, 14}, {0x0B, 14}, {0x0F, 15}, {0x0B, 15}, {0x0F, 16}, {0x0B, 16}, {0x07, 16}, {0x04, 16},
    },
    // TrailingOnes = 1
    {
        {0x00, 0}, {0x01,  2}, {0x04,  6}, {0x06,  8}, {0x06,  9}, {0x06, 10}, {0x06, 11}, {0x0E, 13}, {0x0A, 13},
        {0x0E, 14}, {0x0A, 14}, {0x0E, 15}, {0x0A, 15}, {0x01, 15}, {0x0E, 16}, {0x0A, 16}, {0x06, 16},
    },
    // TrailingOnes = 2
    {
        {0x00, 0}, {0x00, 0}, {0x01,  3}, {0x05,  7}, {0x05,  8}, {0x05,  9}, {0x05, 10}, {0x05, 11}, {0x0D, 13},
        {0x09, 13}, {0x0D, 14}, {0x09, 14}, {0x0D, 15}, {0x09, 15}, {0x0D, 16}, {0x09, 16}, {0x05, 16},
    },
    // TrailingOnes = 3
    {
        {0x00, 0}, {0x00, 0}, {0x00, 0}, {0x03,  5}, {0x03,  6}, {0x04,  7}, {0x04,  8}, {0x04,  9}, {0x04, 10},
        {0x04, 11}, {0x0C, 13}, {0x0C, 14}, {0x08, 14}, {0x0C, 15}, {0x08, 15}, {0x0C, 16}, {0x08, 16},
    },
};

// Table 9-5(b): 2 <= nC < 4
static const vlc_t coeff_token_table_2[4][17] = {
    // TrailingOnes = 0
    {
        {0x03,  2}, {0x0B,  6}, {0x07,  6}, {0x07,  7}, {0x07,  8}, {0x04,  8}, {0x07,  9}, {0x0F, 11}, {0x0B, 11},
        {0x0F, 12}, {0x0B, 12}, {0x08, 12}, {0x0F, 13}, {0x0B, 13}, {0x07, 13}, {0x09, 14}, {0x07, 14},
    },
    // TrailingOnes = 1
    {
        {0x00, 0}, {0x02,  2}, {0x07,  5}, {0x0A,  6}, {0x06,  6}, {0x06,  7}, {0x06,  8}, {0x06,  9}, {0x0E, 11},
        {0x0A, 11}, {0x0E, 12}, {0x0A, 12}, {0x0E, 13}, {0x0A, 13}, {0x0B, 14}, {0x08, 14}, {0x06, 14},
    },
    // TrailingOnes = 2
    {
        {0x00, 0}, {0x00, 0}, {0x03,  3}, {0x09,  6}, {0x05,  6}, {0x05,  7}, {0x05,  8}, {0x05,  9}, {0x0D, 11},
        {0x09, 11}, {0x0D, 12}, {0x09, 12}, {0x0D, 13}, {0x09, 13}, {0x06, 13}, {0x0A, 14}, {0x05, 14},
    },
    // TrailingOnes = 3
    {
        {0x00, 0}, {0x00, 0}, {0x00, 0}, {0x05,  4}, {0x04,  4}, {0x06,  5}, {0x08,  6}, {0x04,  6}, {0x04,  7},
        {0x04,  9}, {0x0C, 11}, {0x08, 11}, {0x0C, 12}, {0x0C, 13}, {0x08, 13}, {0x01, 13}, {0x04, 14},
    },
};

// Table 9-5(c): 4 <= nC < 8
static const vlc_t coeff_token_table_4[4][17] = {
    // TrailingOnes = 0
    {
        {0x0F,  4}, {0x0F,  6}, {0x0B,  6}, {0x08,  6}, {0x0F,  7}, {0x0B,  7}, {0x09,  7}, {0x08,  7}, {0x0F,  8},
        {0x0B,  8}, {0x0F,  9}, {0x0B,  9}, {0x08,  9}, {0x0D, 10}, {0x09, 10}, {0x05, 10}, {0x01, 10},
    },
    // TrailingOnes = 1
    {
        {0x00, 0}, {0x0E,  4}, {0x0F,  5}, {0x0C,  5}, {0x0A,  5}, {0x08,  5}, {0x0E,  6}, {0x0A,  6}, {0x0E,  7},
        {0x0E,  8}, {0x0A,  8}, {0x0E,  9}, {0x0A,  9}, {0x07,  9}, {0x0C, 10}, {0x08, 10}, {0x04, 10},
    },
    // TrailingOnes = 2
    {
        {0x00, 0}, {0x00, 0}, {0x0D,  4}, {0x0E,  5}, {0x0B,  5}, {0x09,  5}, {0x0D,  6}, {0x09,  6}, {0x0D,  7},
        {0x0A,  7}, {0x0D,  8}, {0x09,  8}, {0x0D,  9}, {0x09,  9}, {0x0B, 10}, {0x07, 10}, {0x03, 10},
    },
    // TrailingOnes = 3
    {
        {0x00, 0}, {0x00, 0}, {0x00, 0}, {0x0C,  4}, {0x0B,  4}, {0x0A,  4}, {0x09,  4}, {0x08,  4}, {0x0D,  5},
        {0x0C,  6}, {0x0C,  7}, {0x0C,  8}, {0x08,  8}, {0x0C,  9}, {0x0A, 10}, {0x06, 10}, {0x02, 10},
    },
};

// Table 9-5(e): ChromaDCLevel (nC == -1), 4:2:0
// Chroma DC has max 4 coefficients
static const vlc_t coeff_token_chroma_dc[4][5] = {
    // TrailingOnes = 0
    {
        {0x01, 2},   // TotalCoeff = 0
        {0x07, 6},   // TotalCoeff = 1
        {0x04, 6},   // TotalCoeff = 2
        {0x03, 6},   // TotalCoeff = 3
        {0x02, 6},   // TotalCoeff = 4
    },
    // TrailingOnes = 1
    {
        {0x00, 0},   // TotalCoeff = 0 (invalid)
        {0x01, 1},   // TotalCoeff = 1
        {0x06, 6},   // TotalCoeff = 2
        {0x03, 7},   // TotalCoeff = 3
        {0x03, 8},   // TotalCoeff = 4
    },
    // TrailingOnes = 2
    {
        {0x00, 0},   // TotalCoeff = 0 (invalid)
        {0x00, 0},   // TotalCoeff = 1 (invalid)
        {0x01, 3},   // TotalCoeff = 2
        {0x02, 7},   // TotalCoeff = 3
        {0x02, 8},   // TotalCoeff = 4
    },
    // TrailingOnes = 3
    {
        {0x00, 0},   // TotalCoeff = 0 (invalid)
        {0x00, 0},   // TotalCoeff = 1 (invalid)
        {0x00, 0},   // TotalCoeff = 2 (invalid)
        {0x05, 6},   // TotalCoeff = 3
        {0x00, 7},   // TotalCoeff = 4
    },
};

// Table 9-7: total_zeros for 4x4 blocks (chroma AC or luma)
// Indexed by [total_coeff - 1][total_zeros]
// total_coeff ranges from 1 to 15 (0 coeffs means no total_zeros coded)
// total_zeros ranges from 0 to (16 - total_coeff)
static const vlc_t total_zeros_table[15][16] = {
    // total_coeff = 1: total_zeros can be 0-15
    {{0x1, 1}, {0x3, 3}, {0x2, 3}, {0x3, 4}, {0x2, 4}, {0x3, 5}, {0x2, 5}, {0x3, 6},
     {0x2, 6}, {0x3, 7}, {0x2, 7}, {0x3, 8}, {0x2, 8}, {0x3, 9}, {0x2, 9}, {0x1, 9}},
    // total_coeff = 2: total_zeros can be 0-14
    {{0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 3}, {0x5, 4}, {0x4, 4}, {0x3, 4},
     {0x2, 4}, {0x3, 5}, {0x2, 5}, {0x3, 6}, {0x2, 6}, {0x1, 6}, {0x0, 6}, {0x0, 0}},
    // total_coeff = 3: total_zeros can be 0-13
    {{0x5, 4}, {0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 4}, {0x3, 4}, {0x4, 3}, {0x3, 3},
     {0x2, 4}, {0x3, 5}, {0x2, 5}, {0x1, 6}, {0x1, 5}, {0x0, 6}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 4: total_zeros can be 0-12
    {{0x3, 5}, {0x7, 3}, {0x5, 4}, {0x4, 4}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 4},
     {0x3, 3}, {0x2, 4}, {0x2, 5}, {0x1, 5}, {0x0, 5}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 5: total_zeros can be 0-11
    {{0x5, 4}, {0x4, 4}, {0x3, 4}, {0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 3},
     {0x2, 4}, {0x1, 5}, {0x1, 4}, {0x0, 5}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 6: total_zeros can be 0-10
    {{0x1, 6}, {0x1, 5}, {0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 3}, {0x2, 3},
     {0x1, 4}, {0x1, 3}, {0x0, 6}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 7: total_zeros can be 0-9
    {{0x1, 6}, {0x1, 5}, {0x5, 3}, {0x4, 3}, {0x3, 3}, {0x3, 2}, {0x2, 3}, {0x1, 4},
     {0x1, 3}, {0x0, 6}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 8: total_zeros can be 0-8
    {{0x1, 6}, {0x1, 4}, {0x1, 5}, {0x3, 3}, {0x3, 2}, {0x2, 2}, {0x2, 3}, {0x1, 3},
     {0x0, 6}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 9: total_zeros can be 0-7
    {{0x1, 6}, {0x0, 6}, {0x1, 4}, {0x3, 2}, {0x2, 2}, {0x1, 3}, {0x1, 2}, {0x1, 5},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 10: total_zeros can be 0-6
    {{0x1, 5}, {0x0, 5}, {0x1, 3}, {0x3, 2}, {0x2, 2}, {0x1, 2}, {0x1, 4},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 11: total_zeros can be 0-5
    {{0x0, 4}, {0x1, 4}, {0x1, 3}, {0x2, 3}, {0x1, 1}, {0x3, 3},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 12: total_zeros can be 0-4
    {{0x0, 4}, {0x1, 4}, {0x1, 2}, {0x1, 1}, {0x1, 3},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 13: total_zeros can be 0-3
    {{0x0, 3}, {0x1, 3}, {0x1, 1}, {0x1, 2},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 14: total_zeros can be 0-2
    {{0x0, 2}, {0x1, 2}, {0x1, 1},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 15: total_zeros can be 0-1
    {{0x0, 1}, {0x1, 1},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
};

// Table 9-8: total_zeros for 15-coefficient blocks (I_16x16 AC blocks)
// Indexed by [total_coeff - 1][total_zeros]
// total_coeff ranges from 1 to 14 (0 coeffs means no total_zeros coded)
// total_zeros ranges from 0 to (15 - total_coeff)
static const vlc_t total_zeros_table_15[14][15] = {
    // total_coeff = 1: total_zeros can be 0-14
    {{0x1, 1}, {0x3, 3}, {0x2, 3}, {0x3, 4}, {0x2, 4}, {0x3, 5}, {0x2, 5}, {0x3, 6},
     {0x2, 6}, {0x3, 7}, {0x2, 7}, {0x3, 8}, {0x2, 8}, {0x3, 9}, {0x2, 9}},
    // total_coeff = 2: total_zeros can be 0-13
    {{0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 3}, {0x5, 4}, {0x4, 4}, {0x3, 4},
     {0x2, 4}, {0x3, 5}, {0x2, 5}, {0x3, 6}, {0x2, 6}, {0x1, 6}, {0x0, 0}},
    // total_coeff = 3: total_zeros can be 0-12
    {{0x5, 4}, {0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 4}, {0x3, 4}, {0x4, 3}, {0x3, 3},
     {0x2, 4}, {0x3, 5}, {0x2, 5}, {0x1, 6}, {0x1, 5}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 4: total_zeros can be 0-11
    {{0x3, 5}, {0x7, 3}, {0x5, 4}, {0x4, 4}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 4},
     {0x3, 3}, {0x2, 4}, {0x2, 5}, {0x1, 5}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 5: total_zeros can be 0-10
    {{0x5, 4}, {0x4, 4}, {0x3, 4}, {0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 3},
     {0x2, 4}, {0x1, 5}, {0x1, 4}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 6: total_zeros can be 0-9
    {{0x1, 6}, {0x1, 5}, {0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 3}, {0x2, 3},
     {0x1, 4}, {0x1, 3}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 7: total_zeros can be 0-8
    {{0x1, 6}, {0x1, 5}, {0x5, 3}, {0x4, 3}, {0x3, 3}, {0x3, 2}, {0x2, 3}, {0x1, 4},
     {0x1, 3}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 8: total_zeros can be 0-7
    {{0x1, 6}, {0x1, 4}, {0x1, 5}, {0x3, 3}, {0x3, 2}, {0x2, 2}, {0x2, 3}, {0x1, 3},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 9: total_zeros can be 0-6
    {{0x1, 6}, {0x0, 6}, {0x1, 4}, {0x3, 2}, {0x2, 2}, {0x1, 3}, {0x1, 2},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 10: total_zeros can be 0-5
    {{0x1, 5}, {0x0, 5}, {0x1, 3}, {0x3, 2}, {0x2, 2}, {0x1, 2},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 11: total_zeros can be 0-4
    {{0x0, 4}, {0x1, 4}, {0x1, 3}, {0x2, 3}, {0x1, 1},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 12: total_zeros can be 0-3
    {{0x0, 4}, {0x1, 4}, {0x1, 2}, {0x1, 1},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 13: total_zeros can be 0-2
    {{0x0, 3}, {0x1, 3}, {0x1, 1},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // total_coeff = 14: total_zeros can be 0-1
    {{0x0, 2}, {0x1, 2},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
};

// Table 9-9: total_zeros for chroma DC 4:2:0
// Indexed by [total_coeff - 1][total_zeros]
// total_coeff ranges from 1 to 3 (max 4 coeffs, so if TotalCoeff=4, no zeros)
// total_zeros ranges from 0 to (4 - total_coeff)
static const vlc_t total_zeros_chroma_dc[3][4] = {
    // total_coeff = 1: total_zeros can be 0-3
    {{0x1, 1}, {0x1, 2}, {0x1, 3}, {0x0, 3}},
    // total_coeff = 2: total_zeros can be 0-2
    {{0x1, 1}, {0x1, 2}, {0x0, 2}, {0x0, 0}},
    // total_coeff = 3: total_zeros can be 0-1
    {{0x1, 1}, {0x0, 1}, {0x0, 0}, {0x0, 0}},
};

// Table 9-10: run_before
// Indexed by [min(zeros_left - 1, 6)][run_before]
// zeros_left: remaining zeros to distribute
// run_before: zeros before this coefficient (0 to zeros_left)
static const vlc_t run_before_table[7][15] = {
    // zeros_left = 1
    {{0x1, 1}, {0x0, 1},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // zeros_left = 2
    {{0x1, 1}, {0x1, 2}, {0x0, 2},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // zeros_left = 3
    {{0x3, 2}, {0x2, 2}, {0x1, 2}, {0x0, 2},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // zeros_left = 4
    {{0x3, 2}, {0x2, 2}, {0x1, 2}, {0x1, 3}, {0x0, 3},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // zeros_left = 5
    {{0x3, 2}, {0x2, 2}, {0x3, 3}, {0x2, 3}, {0x1, 3}, {0x0, 3},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // zeros_left = 6
    {{0x3, 2}, {0x0, 3}, {0x1, 3}, {0x3, 3}, {0x2, 3}, {0x5, 3}, {0x4, 3},
     {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}, {0x0, 0}},
    // zeros_left >= 7
    {{0x7, 3}, {0x6, 3}, {0x5, 3}, {0x4, 3}, {0x3, 3}, {0x2, 3}, {0x1, 3}, {0x1, 4}, {0x1, 5}, {0x1, 6}, {0x1, 7}, {0x1, 8}, {0x1, 9}, {0x1, 10}, {0x1, 11}},
};

void write_coeff_token(bs_t* b, int total_coeff, int trailing_ones, int nc) {
    // Input validation
    assert(trailing_ones >= 0 && trailing_ones <= 3);
    assert(total_coeff >= 0);
    if (nc == -1) {
        assert(total_coeff <= 4);  // Chroma DC 4:2:0 has max 4 coefficients
    } else {
        assert(total_coeff <= 16);
    }

    const vlc_t* entry;

    if (nc == -1) {
        // Chroma DC (4:2:0)
        entry = &coeff_token_chroma_dc[trailing_ones][total_coeff];
    } else if (nc < 2) {
        entry = &coeff_token_table_0[trailing_ones][total_coeff];
    } else if (nc < 4) {
        entry = &coeff_token_table_2[trailing_ones][total_coeff];
    } else if (nc < 8) {
        entry = &coeff_token_table_4[trailing_ones][total_coeff];
    } else {
        // nC >= 8: Table 9-5(d) - fixed-length 6-bit encoding
        // code=3 → tc=0; otherwise code = ((tc-1) << 2) | t1
        int code;
        if (total_coeff == 0) {
            code = 3;
        } else {
            code = ((total_coeff - 1) << 2) | trailing_ones;
        }
        bs_write_u(b, 6, code);
        return;
    }

    assert(entry->len > 0);  // Invalid coeff_token combination
    bs_write_u(b, entry->len, entry->code);
}

void write_level_prefix(bs_t* b, int level_prefix) {
    // level_prefix is encoded as level_prefix zeros followed by a 1
    for (int i = 0; i < level_prefix; i++) {
        bs_write_u1(b, 0);
    }
    bs_write_u1(b, 1);
}

void write_total_zeros(bs_t* b, int total_zeros, int total_coeff, int max_num_coeff) {
    assert(total_coeff > 0);
    assert(total_zeros >= 0);

    const vlc_t* entry;
    if (max_num_coeff == 4) {
        // Chroma DC 4:2:0
        assert(total_coeff <= 3);
        assert(total_zeros <= 4 - total_coeff);
        entry = &total_zeros_chroma_dc[total_coeff - 1][total_zeros];
    } else if (max_num_coeff == 15) {
        // AC blocks for I_16x16 (Table 9-8)
        assert(total_coeff <= 14);
        assert(total_zeros <= 15 - total_coeff);
        entry = &total_zeros_table_15[total_coeff - 1][total_zeros];
    } else if (max_num_coeff == 16) {
        // 4x4 luma block (full)
        assert(total_coeff <= 15);
        assert(total_zeros <= 16 - total_coeff);
        entry = &total_zeros_table[total_coeff - 1][total_zeros];
    } else {
        assert(0 && "Unsupported max_num_coeff value");
        return;
    }

    assert(entry->len > 0);
    bs_write_u(b, entry->len, entry->code);
}

void write_run_before(bs_t* b, int run_before, int zeros_left) {
    assert(zeros_left > 0);
    assert(run_before >= 0 && run_before <= zeros_left);

    int idx = (zeros_left > 7) ? 6 : zeros_left - 1;
    const vlc_t* entry = &run_before_table[idx][run_before];

    assert(entry->len > 0);
    bs_write_u(b, entry->len, entry->code);
}

// Static helper for level encoding with suffix_length adaptation
void write_level(bs_t* b, int level, int* suffix_length) {
    int sign = (level < 0) ? 1 : 0;
    int abs_level = sign ? -level : level;

    // levelCode = 2 * abs_level - 2 + sign (for abs_level > 0)
    // But we've already adjusted for first non-T1 level
    int level_code = (abs_level << 1) - 2 + sign;

    // Determine level_prefix and level_suffix
    int level_prefix;
    int level_suffix_size = *suffix_length;
    int level_suffix = 0;

    if (*suffix_length == 0) {
        // level_prefix = min(14, level_code)
        // If level_code >= 14, level_suffix uses escape coding
        level_prefix = (level_code < 14) ? level_code : 14;
        if (level_code >= 14) {
            level_suffix_size = 4;
            level_suffix = level_code - 14;
            if (level_code >= 30) {
                // Extended escape
                level_prefix = 15;
                level_suffix_size = 12;
                level_suffix = level_code - 30;
            }
        } else {
            level_suffix_size = 0;
        }
    } else {
        // Normal case with suffix
        // Escape threshold: level_prefix 0..14 with suffixLength suffix bits
        // can represent levelCodes 0..(15 << suffixLength)-1
        int threshold = (15 << *suffix_length);
        if (level_code < threshold) {
            level_prefix = level_code >> *suffix_length;
            level_suffix = level_code & ((1 << *suffix_length) - 1);
        } else {
            // Escape: level_prefix = 15, 12-bit suffix
            level_prefix = 15;
            level_suffix_size = 12;
            level_suffix = level_code - threshold;
        }
    }

    write_level_prefix(b, level_prefix);
    if (level_suffix_size > 0) {
        bs_write_u(b, level_suffix_size, level_suffix);
    }

    // NOTE: suffix_length update is done by the caller (write_block)
    // so it can use the original abs_level before first-non-T1 adjustment.
}

// --- Read (decode) helpers ---

// Read coeff_token by searching VLC table for matching code
// Sets *total_coeff and *trailing_ones, returns 0 on success
static int read_coeff_token_vlc(bs_t* b, const vlc_t table[][17],
                                       int max_tc, int* total_coeff, int* trailing_ones) {
    // We need to match against variable-length codes.
    // Strategy: try all valid entries, find the one that matches the next bits.
    // Since codes are prefix-free, peek at enough bits and check each candidate.
    // Max code length in tables is 16 bits.
    uint32_t lookahead = bs_next_bits(b, 16);

    for (int t1 = 0; t1 <= 3; t1++) {
        for (int tc = 0; tc <= max_tc; tc++) {
            if (t1 > tc) continue;  // invalid: trailing_ones > total_coeff
            if (tc == 0 && t1 != 0) continue;
            const vlc_t* e = &table[t1][tc];
            if (e->len == 0) continue;  // invalid entry
            uint32_t code = lookahead >> (16 - e->len);
            if (code == e->code) {
                *total_coeff = tc;
                *trailing_ones = t1;
                bs_skip_u(b, e->len);
                return 0;
            }
        }
    }
    return -1;  // no match found
}

static int read_coeff_token_chroma_dc(bs_t* b, int* total_coeff, int* trailing_ones) {
    uint32_t lookahead = bs_next_bits(b, 8);

    for (int t1 = 0; t1 <= 3; t1++) {
        for (int tc = 0; tc <= 4; tc++) {
            if (t1 > tc) continue;
            if (tc == 0 && t1 != 0) continue;
            const vlc_t* e = &coeff_token_chroma_dc[t1][tc];
            if (e->len == 0) continue;
            uint32_t code = lookahead >> (8 - e->len);
            if (code == e->code) {
                *total_coeff = tc;
                *trailing_ones = t1;
                bs_skip_u(b, e->len);
                return 0;
            }
        }
    }
    return -1;
}

int read_coeff_token(bs_t* b, int nc, int* total_coeff, int* trailing_ones) {
    if (nc == -1) {
        return read_coeff_token_chroma_dc(b, total_coeff, trailing_ones);
    } else if (nc >= 8) {
        // Fixed-length 6-bit code (H.264 Table 9-5(d))
        // code=3 → tc=0; otherwise tc = (code>>2)+1, t1 = code&3
        uint32_t code = bs_read_u(b, 6);
        if (code == 3) {
            *total_coeff = 0;
            *trailing_ones = 0;
        } else {
            *total_coeff = (int)(code >> 2) + 1;
            *trailing_ones = (int)(code & 3);
        }
        return 0;
    } else {
        const vlc_t (*table)[17];
        if (nc < 2)      table = coeff_token_table_0;
        else if (nc < 4)  table = coeff_token_table_2;
        else              table = coeff_token_table_4;
        return read_coeff_token_vlc(b, table, 16, total_coeff, trailing_ones);
    }
}

// Read level_prefix (unary: count zeros before a 1)
static int read_level_prefix(bs_t* b) {
    int prefix = 0;
    while (bs_read_u1(b) == 0 && !bs_eof(b)) {
        prefix++;
    }
    return prefix;
}

// Read a level value given current suffix_length, update suffix_length
// Per H.264 spec section 9.2.2.1 (Table 9-6)
static int read_level(bs_t* b, int* suffix_length) {
    int level_prefix = read_level_prefix(b);
    int level_code;
    int level_suffix_size;
    int level_suffix = 0;

    // Determine suffix size per spec
    if (level_prefix == 14 && *suffix_length == 0) {
        level_suffix_size = 4;
    } else if (level_prefix >= 15) {
        level_suffix_size = level_prefix - 3;
    } else {
        level_suffix_size = *suffix_length;
    }

    if (level_suffix_size > 0) {
        level_suffix = bs_read_u(b, level_suffix_size);
    }

    // Compute levelCode per spec:
    // levelCode = (Min(15, level_prefix) << suffixLength) + level_suffix
    int capped_prefix = (level_prefix < 15) ? level_prefix : 15;
    level_code = (capped_prefix << *suffix_length) + level_suffix;

    // Additional adjustments per spec
    if (level_prefix >= 15 && *suffix_length == 0) {
        level_code += 15;
    }
    if (level_prefix >= 16) {
        level_code += (1 << (level_prefix - 3)) - 4096;
    }

    // Decode level from level_code
    int sign = level_code & 1;
    int abs_level = (level_code + 2) >> 1;
    int level = sign ? -abs_level : abs_level;

    // NOTE: suffix_length update is done by the caller (read_block)
    // so it can use the adjusted abs_level after first-non-T1 correction.

    return level;
}

// Read total_zeros by searching VLC table
static int read_total_zeros_from_table(bs_t* b, const vlc_t* row, int max_zeros) {
    uint32_t lookahead = bs_next_bits(b, 16);
    for (int tz = 0; tz <= max_zeros; tz++) {
        if (row[tz].len == 0) continue;
        uint32_t code = lookahead >> (16 - row[tz].len);
        if (code == row[tz].code) {
            bs_skip_u(b, row[tz].len);
            return tz;
        }
    }
    return -1;
}

static int read_total_zeros(bs_t* b, int total_coeff, int max_num_coeff) {
    if (max_num_coeff == 4) {
        // Chroma DC
        int max_zeros = 4 - total_coeff;
        return read_total_zeros_from_table(b, total_zeros_chroma_dc[total_coeff - 1], max_zeros);
    } else if (max_num_coeff == 15) {
        int max_zeros = 15 - total_coeff;
        return read_total_zeros_from_table(b, total_zeros_table_15[total_coeff - 1], max_zeros);
    } else {
        int max_zeros = 16 - total_coeff;
        return read_total_zeros_from_table(b, total_zeros_table[total_coeff - 1], max_zeros);
    }
}

// Read run_before by searching VLC table
static int read_run_before(bs_t* b, int zeros_left) {
    int idx = (zeros_left > 7) ? 6 : zeros_left - 1;
    int max_run = (zeros_left > 14) ? 14 : zeros_left;
    uint32_t lookahead = bs_next_bits(b, 16);

    for (int rb = 0; rb <= max_run; rb++) {
        const vlc_t* e = &run_before_table[idx][rb];
        if (e->len == 0) continue;
        uint32_t code = lookahead >> (16 - e->len);
        if (code == e->code) {
            bs_skip_u(b, e->len);
            return rb;
        }
    }
    return -1;
}

int read_block(bs_t* b, int16_t* coeffs, int nc, int max_num_coeff) {
    memset(coeffs, 0, max_num_coeff * sizeof(int16_t));

    // Step 1: Read coeff_token
    int total_coeff = 0, trailing_ones = 0;
    if (read_coeff_token(b, nc, &total_coeff, &trailing_ones) < 0) {
        return -1;
    }

    if (total_coeff == 0) {
        return 0;
    }

    // levels[] in reverse scan order (same as writer: [0] = last nonzero, etc.)
    int16_t levels[16];

    // Step 2: Read trailing ones signs
    for (int i = trailing_ones - 1; i >= 0; i--) {
        int sign = bs_read_u1(b);
        levels[i] = sign ? -1 : 1;
    }

    // Step 3: Read remaining levels
    int suffix_length = (total_coeff > 10 && trailing_ones < 3) ? 1 : 0;
    for (int i = trailing_ones; i < total_coeff; i++) {
        int level = read_level(b, &suffix_length);

        // First non-T1 level adjustment (inverse of writer)
        if (i == trailing_ones && trailing_ones < 3) {
            level = (level >= 0) ? level + 1 : level - 1;
        }

        levels[i] = (int16_t)level;

        // Update suffix_length using the final abs_level (after adjustment)
        int abs_level = (level < 0) ? -level : level;
        if (suffix_length == 0) {
            suffix_length = 1;
        }
        if (abs_level > (3 << (suffix_length - 1)) && suffix_length < 6) {
            suffix_length++;
        }
    }

    // Step 4: Read total_zeros
    int total_zeros = 0;
    if (total_coeff < max_num_coeff) {
        total_zeros = read_total_zeros(b, total_coeff, max_num_coeff);
        if (total_zeros < 0) {
            return -1;
        }
    }

    // Step 5: Read run_before for each coefficient and place in output
    int zeros_left = total_zeros;
    int runs[16] = {0};
    for (int i = 0; i < total_coeff - 1; i++) {
        if (zeros_left > 0) {
            runs[i] = read_run_before(b, zeros_left);
            if (runs[i] < 0) {
                return -1;
            }
            zeros_left -= runs[i];
        }
    }
    // Last coefficient gets remaining zeros
    runs[total_coeff - 1] = zeros_left;

    // Step 6: Place coefficients in zig-zag order
    // levels[0] is the highest-frequency nonzero coeff, levels[total_coeff-1] is lowest
    // runs[i] is the number of zeros between levels[i] and levels[i+1] (going downward)
    // Start at the highest occupied position and work down
    int pos = total_coeff + total_zeros - 1;

    for (int i = 0; i < total_coeff; i++) {
        if (pos < 0 || pos >= max_num_coeff) {
            return -1;
        }
        coeffs[pos] = levels[i];
        pos--;
        pos -= runs[i];
    }

    return total_coeff;
}

int calc_nc(int nc_left, int nc_above) {
    if (nc_left < 0 && nc_above < 0) return 0;
    if (nc_left < 0) return nc_above;
    if (nc_above < 0) return nc_left;
    return (nc_left + nc_above + 1) >> 1;
}

int write_block(bs_t* b, const int16_t* coeffs, int nc, int max_num_coeff) {
    // Step 1: Scan coefficients to find non-zeros
    // Coefficients are in zig-zag order. We need to:
    // - Count TotalCoeff (total non-zero coefficients)
    // - Count TrailingOnes (up to 3 consecutive +/-1 at the end)
    // - Build arrays of levels[] and runs[] for encoding

    int16_t levels[16];  // Non-zero coefficient values (reverse order)
    int total_coeff = 0;
    int trailing_ones = 0;

    // Scan from end to start (high frequency to low frequency)
    int last_nz = -1;
    for (int i = max_num_coeff - 1; i >= 0; i--) {
        if (coeffs[i] != 0) {
            if (last_nz < 0) last_nz = i;
            levels[total_coeff] = coeffs[i];
            total_coeff++;
        }
    }

    if (total_coeff == 0) {
        // No coefficients - just write coeff_token(0, 0)
        write_coeff_token(b, 0, 0, nc);
        return 0;
    }

    // Count trailing ones (must be +/-1, up to 3 consecutive from the end)
    for (int i = 0; i < total_coeff && i < 3; i++) {
        if (levels[i] == 1 || levels[i] == -1) {
            trailing_ones++;
        } else {
            break;
        }
    }

    // Step 2: Write coeff_token
    write_coeff_token(b, total_coeff, trailing_ones, nc);

    // Step 3: Write trailing ones signs (in reverse order)
    for (int i = trailing_ones - 1; i >= 0; i--) {
        bs_write_u1(b, levels[i] < 0 ? 1 : 0);
    }

    // Step 4: Write remaining levels
    // Per H.264 spec 9.2.2: Start with suffixLength=1 when TotalCoeff > 10 and T1 < 3
    int suffix_length = (total_coeff > 10 && trailing_ones < 3) ? 1 : 0;
    for (int i = trailing_ones; i < total_coeff; i++) {
        int original_level = levels[i];
        int level = original_level;

        // First non-T1 level adjustment
        if (i == trailing_ones && trailing_ones < 3) {
            // Subtract 1 from magnitude (encoded level can't be +/-1)
            level = (level > 0) ? level - 1 : level + 1;
        }

        write_level(b, level, &suffix_length);

        // Update suffix_length using the ORIGINAL abs_level (before adjustment)
        int abs_level = (original_level < 0) ? -original_level : original_level;
        if (suffix_length == 0) {
            suffix_length = 1;
        }
        if (abs_level > (3 << (suffix_length - 1)) && suffix_length < 6) {
            suffix_length++;
        }
    }

    // Step 5: Write total_zeros (if TotalCoeff < max_num_coeff)
    if (total_coeff < max_num_coeff) {
        int total_zeros = last_nz + 1 - total_coeff;
        write_total_zeros(b, total_zeros, total_coeff, max_num_coeff);
    }

    // Step 6: Compute and write run_before values
    // Need to re-scan to get the actual runs
    int zeros_left = last_nz + 1 - total_coeff;
    int coeff_idx = 0;
    for (int i = max_num_coeff - 1; i >= 0 && coeff_idx < total_coeff - 1; i--) {
        if (coeffs[i] != 0) {
            // Count zeros before this coefficient
            int run = 0;
            for (int j = i - 1; j >= 0; j--) {
                if (coeffs[j] == 0) run++;
                else break;
            }
            if (zeros_left > 0) {
                write_run_before(b, run, zeros_left);
                zeros_left -= run;
            }
            coeff_idx++;
        }
    }

    return total_coeff;
}

int copy_tail(bs_t* src, bs_t* dst, int tc, int t1, int max_num_coeff) {
    if (tc == 0) return 0;

    /* 1. Copy trailing_ones sign bits */
    for (int i = 0; i < t1; i++) {
        bs_write_u1(dst, bs_read_u1(src));
    }

    /* 2. Parse and copy level codes (must track suffix_length) */
    int suffix_length = (tc > 10 && t1 < 3) ? 1 : 0;
    for (int i = t1; i < tc; i++) {
        /* Read and copy level_prefix (unary) */
        int level_prefix = 0;
        while (bs_read_u1(src) == 0) {
            bs_write_u1(dst, 0);
            level_prefix++;
        }
        bs_write_u1(dst, 1);

        /* Determine suffix size (Table 9-6) */
        int level_suffix_size;
        if (level_prefix == 14 && suffix_length == 0) {
            level_suffix_size = 4;
        } else if (level_prefix >= 15) {
            level_suffix_size = level_prefix - 3;
        } else {
            level_suffix_size = suffix_length;
        }

        /* Copy suffix bits */
        int level_suffix = 0;
        if (level_suffix_size > 0) {
            level_suffix = (int)bs_read_u(src, level_suffix_size);
            bs_write_u(dst, level_suffix_size, (uint32_t)level_suffix);
        }

        /* Reconstruct level_code for suffix_length update */
        int capped_prefix = (level_prefix < 15) ? level_prefix : 15;
        int level_code = (capped_prefix << suffix_length) + level_suffix;
        if (level_prefix >= 15 && suffix_length == 0) {
            level_code += 15;
        }
        if (level_prefix >= 16) {
            level_code += (1 << (level_prefix - 3)) - 4096;
        }

        /* Decode abs_level */
        int abs_level = (level_code + 2) >> 1;

        /* First non-trailing-one adjustment */
        if (i == t1 && t1 < 3) {
            abs_level += 1;
        }

        /* Update suffix_length */
        if (suffix_length == 0) suffix_length = 1;
        if (abs_level > (3 << (suffix_length - 1)) && suffix_length < 6) {
            suffix_length++;
        }
    }

    /* 3. Decode and re-encode total_zeros (same VLC tables, bit-identical) */
    int total_zeros = 0;
    if (tc < max_num_coeff) {
        total_zeros = read_total_zeros(src, tc, max_num_coeff);
        if (total_zeros < 0) return -1;
        write_total_zeros(dst, total_zeros, tc, max_num_coeff);
    }

    /* 4. Decode and re-encode run_before */
    int zeros_left = total_zeros;
    for (int i = 0; i < tc - 1 && zeros_left > 0; i++) {
        int run = read_run_before(src, zeros_left);
        if (run < 0) return -1;
        write_run_before(dst, run, zeros_left);
        zeros_left -= run;
    }

    return 0;
}

} // namespace subcodec::cavlc
