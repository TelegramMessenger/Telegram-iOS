#pragma once

#include <cstdint>
#include "bs.h"

namespace subcodec::cavlc {

void write_coeff_token(bs_t* b, int total_coeff, int trailing_ones, int nc);
void write_level_prefix(bs_t* b, int level_prefix);
void write_total_zeros(bs_t* b, int total_zeros, int total_coeff, int max_num_coeff);
void write_run_before(bs_t* b, int run_before, int zeros_left);
int  write_block(bs_t* b, const int16_t* coeffs, int nc, int max_num_coeff);
int  read_block(bs_t* b, int16_t* coeffs, int nc, int max_num_coeff);
void write_level(bs_t* b, int level, int* suffix_length);
int  calc_nc(int nc_left, int nc_above);
int  read_coeff_token(bs_t* b, int nc, int* total_coeff, int* trailing_ones);
int  copy_tail(bs_t* src, bs_t* dst, int tc, int t1, int max_num_coeff);

} // namespace subcodec::cavlc
