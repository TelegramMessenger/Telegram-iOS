/* Lookahead lowres intra analysis
 *
 * Each intra analysis function has been implemented twice, once for scalar GPUs
 * (NV) and once for vectorized GPUs (AMD pre-Southern Islands).  x264 detects
 * the GPU type and sets the -DVECTORIZE compile flag accordingly.
 *
 * All the intra analysis functions were based on their C versions in pixel.c
 * and produce the exact same results.
 */

/* force all clamp arguments and return value to int, prevent ambiguous types */
#define clamp_int( X, MIN, MAX ) (int) clamp( (int)(X), (int)(MIN), (int)(MAX) )

#if VECTORIZE
int satd_8x4_intra_lr( const local pixel *data, int data_stride, int8 pr0, int8 pr1, int8 pr2, int8 pr3 )
{
    int8 a_v, d_v;
    int2 tmp00, tmp01, tmp02, tmp03, tmp10, tmp11, tmp12, tmp13;
    int2 tmp20, tmp21, tmp22, tmp23, tmp30, tmp31, tmp32, tmp33;

    d_v = convert_int8( vload8( 0, data ) );
    a_v.s01234567 = (d_v - pr0).s04152637;
    HADAMARD4V( tmp00, tmp01, tmp02, tmp03, a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi );

    data += data_stride;
    d_v = convert_int8( vload8( 0, data ) );
    a_v.s01234567 = (d_v - pr1).s04152637;
    HADAMARD4V( tmp10, tmp11, tmp12, tmp13, a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi );

    data += data_stride;
    d_v = convert_int8( vload8( 0, data ) );
    a_v.s01234567 = (d_v - pr2).s04152637;
    HADAMARD4V( tmp20, tmp21, tmp22, tmp23, a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi );

    data += data_stride;
    d_v = convert_int8( vload8( 0, data ) );
    a_v.s01234567 = (d_v - pr3).s04152637;
    HADAMARD4V( tmp30, tmp31, tmp32, tmp33, a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi );

    uint8 sum_v;

    HADAMARD4V( a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi, tmp00, tmp10, tmp20, tmp30 );
    sum_v = abs( a_v );

    HADAMARD4V( a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi, tmp01, tmp11, tmp21, tmp31 );
    sum_v += abs( a_v );

    HADAMARD4V( a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi, tmp02, tmp12, tmp22, tmp32 );
    sum_v += abs( a_v );

    HADAMARD4V( a_v.lo.lo, a_v.lo.hi, a_v.hi.lo, a_v.hi.hi, tmp03, tmp13, tmp23, tmp33 );
    sum_v += abs( a_v );

    uint4 sum2 = sum_v.hi + sum_v.lo;
    uint2 sum3 = sum2.hi + sum2.lo;
    return ( sum3.hi + sum3.lo ) >> 1;
}
#else
SATD_C_8x4_Q( satd_8x4_lp, const local, private )
#endif

/****************************************************************************
 * 8x8 prediction for intra luma block
 ****************************************************************************/

#define F1            rhadd
#define F2( a, b, c ) ( a+2*b+c+2 )>>2

#if VECTORIZE
int x264_predict_8x8_ddl( const local pixel *src, int src_stride, const local pixel *top )
{
    int8 pr0, pr1, pr2, pr3;

    // Upper half of pred[]
    pr0.s0 = ( 2 + top[0] + 2*top[1] + top[2] ) >> 2;
    pr0.s1 = ( 2 + top[1] + 2*top[2] + top[3] ) >> 2;
    pr0.s2 = ( 2 + top[2] + 2*top[3] + top[4] ) >> 2;
    pr0.s3 = ( 2 + top[3] + 2*top[4] + top[5] ) >> 2;
    pr0.s4 = ( 2 + top[4] + 2*top[5] + top[6] ) >> 2;
    pr0.s5 = ( 2 + top[5] + 2*top[6] + top[7] ) >> 2;
    pr0.s6 = ( 2 + top[6] + 2*top[7] + top[8] ) >> 2;
    pr0.s7 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;

    pr1.s0 = ( 2 + top[1] + 2*top[2] + top[3] ) >> 2;
    pr1.s1 = ( 2 + top[2] + 2*top[3] + top[4] ) >> 2;
    pr1.s2 = ( 2 + top[3] + 2*top[4] + top[5] ) >> 2;
    pr1.s3 = ( 2 + top[4] + 2*top[5] + top[6] ) >> 2;
    pr1.s4 = ( 2 + top[5] + 2*top[6] + top[7] ) >> 2;
    pr1.s5 = ( 2 + top[6] + 2*top[7] + top[8] ) >> 2;
    pr1.s6 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;
    pr1.s7 = ( 2 + top[8] + 2*top[9] + top[10] ) >> 2;

    pr2.s0 = ( 2 + top[2] + 2*top[3] + top[4] ) >> 2;
    pr2.s1 = ( 2 + top[3] + 2*top[4] + top[5] ) >> 2;
    pr2.s2 = ( 2 + top[4] + 2*top[5] + top[6] ) >> 2;
    pr2.s3 = ( 2 + top[5] + 2*top[6] + top[7] ) >> 2;
    pr2.s4 = ( 2 + top[6] + 2*top[7] + top[8] ) >> 2;
    pr2.s5 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;
    pr2.s6 = ( 2 + top[8] + 2*top[9] + top[10] ) >> 2;
    pr2.s7 = ( 2 + top[9] + 2*top[10] + top[11] ) >> 2;

    pr3.s0 = ( 2 + top[3] + 2*top[4] + top[5] ) >> 2;
    pr3.s1 = ( 2 + top[4] + 2*top[5] + top[6] ) >> 2;
    pr3.s2 = ( 2 + top[5] + 2*top[6] + top[7] ) >> 2;
    pr3.s3 = ( 2 + top[6] + 2*top[7] + top[8] ) >> 2;
    pr3.s4 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;
    pr3.s5 = ( 2 + top[8] + 2*top[9] + top[10] ) >> 2;
    pr3.s6 = ( 2 + top[9] + 2*top[10] + top[11] ) >> 2;
    pr3.s7 = ( 2 + top[10] + 2*top[11] + top[12] ) >> 2;
    int satd = satd_8x4_intra_lr( src, src_stride, pr0, pr1, pr2, pr3 );

    // Lower half of pred[]
    pr0.s0 = ( 2 + top[4] + 2*top[5] + top[6] ) >> 2;
    pr0.s1 = ( 2 + top[5] + 2*top[6] + top[7] ) >> 2;
    pr0.s2 = ( 2 + top[6] + 2*top[7] + top[8] ) >> 2;
    pr0.s3 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;
    pr0.s4 = ( 2 + top[8] + 2*top[9] + top[10] ) >> 2;
    pr0.s5 = ( 2 + top[9] + 2*top[10] + top[11] ) >> 2;
    pr0.s6 = ( 2 + top[10] + 2*top[11] + top[12] ) >> 2;
    pr0.s7 = ( 2 + top[11] + 2*top[12] + top[13] ) >> 2;

    pr1.s0 = ( 2 + top[5] + 2*top[6] + top[7] ) >> 2;
    pr1.s1 = ( 2 + top[6] + 2*top[7] + top[8] ) >> 2;
    pr1.s2 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;
    pr1.s3 = ( 2 + top[8] + 2*top[9] + top[10] ) >> 2;
    pr1.s4 = ( 2 + top[9] + 2*top[10] + top[11] ) >> 2;
    pr1.s5 = ( 2 + top[10] + 2*top[11] + top[12] ) >> 2;
    pr1.s6 = ( 2 + top[11] + 2*top[12] + top[13] ) >> 2;
    pr1.s7 = ( 2 + top[12] + 2*top[13] + top[14] ) >> 2;

    pr2.s0 = ( 2 + top[6] + 2*top[7] + top[8] ) >> 2;
    pr2.s1 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;
    pr2.s2 = ( 2 + top[8] + 2*top[9] + top[10] ) >> 2;
    pr2.s3 = ( 2 + top[9] + 2*top[10] + top[11] ) >> 2;
    pr2.s4 = ( 2 + top[10] + 2*top[11] + top[12] ) >> 2;
    pr2.s5 = ( 2 + top[11] + 2*top[12] + top[13] ) >> 2;
    pr2.s6 = ( 2 + top[12] + 2*top[13] + top[14] ) >> 2;
    pr2.s7 = ( 2 + top[13] + 2*top[14] + top[15] ) >> 2;

    pr3.s0 = ( 2 + top[7] + 2*top[8] + top[9] ) >> 2;
    pr3.s1 = ( 2 + top[8] + 2*top[9] + top[10] ) >> 2;
    pr3.s2 = ( 2 + top[9] + 2*top[10] + top[11] ) >> 2;
    pr3.s3 = ( 2 + top[10] + 2*top[11] + top[12] ) >> 2;
    pr3.s4 = ( 2 + top[11] + 2*top[12] + top[13] ) >> 2;
    pr3.s5 = ( 2 + top[12] + 2*top[13] + top[14] ) >> 2;
    pr3.s6 = ( 2 + top[13] + 2*top[14] + top[15] ) >> 2;
    pr3.s7 = ( 2 + top[14] + 3*top[15] ) >> 2;

    return satd + satd_8x4_intra_lr( src + (src_stride << 2), src_stride, pr0, pr1, pr2, pr3 );
}

int x264_predict_8x8_ddr( const local pixel *src, int src_stride, const local pixel *top, const local pixel *left, pixel left_top )
{
    int8 pr0, pr1, pr2, pr3;

    // Upper half of pred[]
    pr3.s0 = F2( left[1], left[2], left[3] );
    pr2.s0 = pr3.s1 = F2( left[0], left[1], left[2] );
    pr1.s0 = pr2.s1 = pr3.s2 = F2( left[1], left[0], left_top );
    pr0.s0 = pr1.s1 = pr2.s2 = pr3.s3 = F2( left[0], left_top, top[0] );
    pr0.s1 = pr1.s2 = pr2.s3 = pr3.s4 = F2( left_top, top[0], top[1] );
    pr0.s2 = pr1.s3 = pr2.s4 = pr3.s5 = F2( top[0], top[1], top[2] );
    pr0.s3 = pr1.s4 = pr2.s5 = pr3.s6 = F2( top[1], top[2], top[3] );
    pr0.s4 = pr1.s5 = pr2.s6 = pr3.s7 = F2( top[2], top[3], top[4] );
    pr0.s5 = pr1.s6 = pr2.s7 = F2( top[3], top[4], top[5] );
    pr0.s6 = pr1.s7 = F2( top[4], top[5], top[6] );
    pr0.s7 = F2( top[5], top[6], top[7] );
    int satd = satd_8x4_intra_lr( src, src_stride, pr0, pr1, pr2, pr3 );

    // Lower half of pred[]
    pr3.s0 = F2( left[5], left[6], left[7] );
    pr2.s0 = pr3.s1 = F2( left[4], left[5], left[6] );
    pr1.s0 = pr2.s1 = pr3.s2 = F2( left[3], left[4], left[5] );
    pr0.s0 = pr1.s1 = pr2.s2 = pr3.s3 = F2( left[2], left[3], left[4] );
    pr0.s1 = pr1.s2 = pr2.s3 = pr3.s4 = F2( left[1], left[2], left[3] );
    pr0.s2 = pr1.s3 = pr2.s4 = pr3.s5 = F2( left[0], left[1], left[2] );
    pr0.s3 = pr1.s4 = pr2.s5 = pr3.s6 = F2( left[1], left[0], left_top );
    pr0.s4 = pr1.s5 = pr2.s6 = pr3.s7 = F2( left[0], left_top, top[0] );
    pr0.s5 = pr1.s6 = pr2.s7 = F2( left_top, top[0], top[1] );
    pr0.s6 = pr1.s7 = F2( top[0], top[1], top[2] );
    pr0.s7 = F2( top[1], top[2], top[3] );
    return satd + satd_8x4_intra_lr( src + (src_stride << 2), src_stride, pr0, pr1, pr2, pr3 );
}

int x264_predict_8x8_vr( const local pixel *src, int src_stride, const local pixel *top, const local pixel *left, pixel left_top )
{
    int8 pr0, pr1, pr2, pr3;

    // Upper half of pred[]
    pr2.s0 = F2( left[1], left[0], left_top );
    pr3.s0 = F2( left[2], left[1], left[0] );
    pr1.s0 = pr3.s1 = F2( left[0], left_top, top[0] );
    pr0.s0 = pr2.s1 = F1( left_top, top[0] );
    pr1.s1 = pr3.s2 = F2( left_top, top[0], top[1] );
    pr0.s1 = pr2.s2 = F1( top[0], top[1] );
    pr1.s2 = pr3.s3 = F2( top[0], top[1], top[2] );
    pr0.s2 = pr2.s3 = F1( top[1], top[2] );
    pr1.s3 = pr3.s4 = F2( top[1], top[2], top[3] );
    pr0.s3 = pr2.s4 = F1( top[2], top[3] );
    pr1.s4 = pr3.s5 = F2( top[2], top[3], top[4] );
    pr0.s4 = pr2.s5 = F1( top[3], top[4] );
    pr1.s5 = pr3.s6 = F2( top[3], top[4], top[5] );
    pr0.s5 = pr2.s6 = F1( top[4], top[5] );
    pr1.s6 = pr3.s7 = F2( top[4], top[5], top[6] );
    pr0.s6 = pr2.s7 = F1( top[5], top[6] );
    pr1.s7 = F2( top[5], top[6], top[7] );
    pr0.s7 = F1( top[6], top[7] );
    int satd = satd_8x4_intra_lr( src, src_stride, pr0, pr1, pr2, pr3 );

    // Lower half of pred[]
    pr2.s0 = F2( left[5], left[4], left[3] );
    pr3.s0 = F2( left[6], left[5], left[4] );
    pr0.s0 = pr2.s1 = F2( left[3], left[2], left[1] );
    pr1.s0 = pr3.s1 = F2( left[4], left[3], left[2] );
    pr0.s1 = pr2.s2 = F2( left[1], left[0], left_top );
    pr1.s1 = pr3.s2 = F2( left[2], left[1], left[0] );
    pr1.s2 = pr3.s3 = F2( left[0], left_top, top[0] );
    pr0.s2 = pr2.s3 = F1( left_top, top[0] );
    pr1.s3 = pr3.s4 = F2( left_top, top[0], top[1] );
    pr0.s3 = pr2.s4 = F1( top[0], top[1] );
    pr1.s4 = pr3.s5 = F2( top[0], top[1], top[2] );
    pr0.s4 = pr2.s5 = F1( top[1], top[2] );
    pr1.s5 = pr3.s6 = F2( top[1], top[2], top[3] );
    pr0.s5 = pr2.s6 = F1( top[2], top[3] );
    pr1.s6 = pr3.s7 = F2( top[2], top[3], top[4] );
    pr0.s6 = pr2.s7 = F1( top[3], top[4] );
    pr1.s7 = F2( top[3], top[4], top[5] );
    pr0.s7 = F1( top[4], top[5] );
    return satd + satd_8x4_intra_lr( src + (src_stride << 2), src_stride, pr0, pr1, pr2, pr3 );
#undef PRED
}

int x264_predict_8x8_hd( const local pixel *src, int src_stride, const local pixel *top, const local pixel *left, pixel left_top )
{
    int8 pr0, pr1, pr2, pr3;

    // Upper half of pred[]
    pr0.s0 = F1( left_top, left[0] ); pr0.s1 = (left[0] + 2 * left_top + top[0] + 2) >> 2;
    pr0.s2 = F2( top[1], top[0], left_top ); pr0.s3 = F2( top[2], top[1], top[0] );
    pr0.s4 = F2( top[3], top[2], top[1] ); pr0.s5 = F2( top[4], top[3], top[2] );
    pr0.s6 = F2( top[5], top[4], top[3] ); pr0.s7 = F2( top[6], top[5], top[4] );

    pr1.s0 = F1( left[0], left[1] ); pr1.s1 = (left_top + 2 * left[0] + left[1] + 2) >> 2;
    pr1.s2 = F1( left_top, left[0] ); pr1.s3 = (left[0] + 2 * left_top + top[0] + 2) >> 2;
    pr1.s4 = F2( top[1], top[0], left_top ); pr1.s5 = F2( top[2], top[1], top[0] );
    pr1.s6 = F2( top[3], top[2], top[1] ); pr1.s7 = F2( top[4], top[3], top[2] );

    pr2.s0 = F1( left[1], left[2] ); pr2.s1 = (left[0] + 2 * left[1] + left[2] + 2) >> 2;
    pr2.s2 = F1( left[0], left[1] ); pr2.s3 = (left_top + 2 * left[0] + left[1] + 2) >> 2;
    pr2.s4 = F1( left_top, left[0] ); pr2.s5 = (left[0] + 2 * left_top + top[0] + 2) >> 2;
    pr2.s6 = F2( top[1], top[0], left_top ); pr2.s7 = F2( top[2], top[1], top[0] );

    pr3.s0 = F1( left[2], left[3] ); pr3.s1 = (left[1] + 2 * left[2] + left[3] + 2) >> 2;
    pr3.s2 = F1( left[1], left[2] ); pr3.s3 = (left[0] + 2 * left[1] + left[2] + 2) >> 2;
    pr3.s4 = F1( left[0], left[1] ); pr3.s5 = (left_top + 2 * left[0] + left[1] + 2) >> 2;
    pr3.s6 = F1( left_top, left[0] ); pr3.s7 = (left[0] + 2 * left_top + top[0] + 2) >> 2;
    int satd = satd_8x4_intra_lr( src, src_stride, pr0, pr1, pr2, pr3 );

    // Lower half of pred[]
    pr0.s0 = F1( left[3], left[4] ); pr0.s1 = (left[2] + 2 * left[3] + left[4] + 2) >> 2;
    pr0.s2 = F1( left[2], left[3] ); pr0.s3 = (left[1] + 2 * left[2] + left[3] + 2) >> 2;
    pr0.s4 = F1( left[1], left[2] ); pr0.s5 = (left[0] + 2 * left[1] + left[2] + 2) >> 2;
    pr0.s6 = F1( left[0], left[1] ); pr0.s7 = (left_top + 2 * left[0] + left[1] + 2) >> 2;

    pr1.s0 = F1( left[4], left[5] ); pr1.s1 = (left[3] + 2 * left[4] + left[5] + 2) >> 2;
    pr1.s2 = F1( left[3], left[4] ); pr1.s3 = (left[2] + 2 * left[3] + left[4] + 2) >> 2;
    pr1.s4 = F1( left[2], left[3] ); pr1.s5 = (left[1] + 2 * left[2] + left[3] + 2) >> 2;
    pr1.s6 = F1( left[1], left[2] ); pr1.s7 = (left[0] + 2 * left[1] + left[2] + 2) >> 2;

    pr2.s0 = F1( left[5], left[6] ); pr2.s1 = (left[4] + 2 * left[5] + left[6] + 2) >> 2;
    pr2.s2 = F1( left[4], left[5] ); pr2.s3 = (left[3] + 2 * left[4] + left[5] + 2) >> 2;
    pr2.s4 = F1( left[3], left[4] ); pr2.s5 = (left[2] + 2 * left[3] + left[4] + 2) >> 2;
    pr2.s6 = F1( left[2], left[3] ); pr2.s7 = (left[1] + 2 * left[2] + left[3] + 2) >> 2;

    pr3.s0 = F1( left[6], left[7] ); pr3.s1 = (left[5] + 2 * left[6] + left[7] + 2) >> 2;
    pr3.s2 = F1( left[5], left[6] ); pr3.s3 = (left[4] + 2 * left[5] + left[6] + 2) >> 2;
    pr3.s4 = F1( left[4], left[5] ); pr3.s5 = (left[3] + 2 * left[4] + left[5] + 2) >> 2;
    pr3.s6 = F1( left[3], left[4] ); pr3.s7 = (left[2] + 2 * left[3] + left[4] + 2) >> 2;
    return satd + satd_8x4_intra_lr( src + (src_stride << 2), src_stride, pr0, pr1, pr2, pr3 );
}

int x264_predict_8x8_vl( const local pixel *src, int src_stride, const local pixel *top )
{
    int8 pr0, pr1, pr2, pr3;

    // Upper half of pred[]
    pr0.s0 = F1( top[0], top[1] );
    pr1.s0 = F2( top[0], top[1], top[2] );
    pr2.s0 = pr0.s1 = F1( top[1], top[2] );
    pr3.s0 = pr1.s1 = F2( top[1], top[2], top[3] );
    pr2.s1 = pr0.s2 = F1( top[2], top[3] );
    pr3.s1 = pr1.s2 = F2( top[2], top[3], top[4] );
    pr2.s2 = pr0.s3 = F1( top[3], top[4] );
    pr3.s2 = pr1.s3 = F2( top[3], top[4], top[5] );
    pr2.s3 = pr0.s4 = F1( top[4], top[5] );
    pr3.s3 = pr1.s4 = F2( top[4], top[5], top[6] );
    pr2.s4 = pr0.s5 = F1( top[5], top[6] );
    pr3.s4 = pr1.s5 = F2( top[5], top[6], top[7] );
    pr2.s5 = pr0.s6 = F1( top[6], top[7] );
    pr3.s5 = pr1.s6 = F2( top[6], top[7], top[8] );
    pr2.s6 = pr0.s7 = F1( top[7], top[8] );
    pr3.s6 = pr1.s7 = F2( top[7], top[8], top[9] );
    pr2.s7 = F1( top[8], top[9] );
    pr3.s7 = F2( top[8], top[9], top[10] );
    int satd = satd_8x4_intra_lr( src, src_stride, pr0, pr1, pr2, pr3 );

    // Lower half of pred[]
    pr0.s0 = F1( top[2], top[3] );
    pr1.s0 = F2( top[2], top[3], top[4] );
    pr2.s0 = pr0.s1 = F1( top[3], top[4] );
    pr3.s0 = pr1.s1 = F2( top[3], top[4], top[5] );
    pr2.s1 = pr0.s2 = F1( top[4], top[5] );
    pr3.s1 = pr1.s2 = F2( top[4], top[5], top[6] );
    pr2.s2 = pr0.s3 = F1( top[5], top[6] );
    pr3.s2 = pr1.s3 = F2( top[5], top[6], top[7] );
    pr2.s3 = pr0.s4 = F1( top[6], top[7] );
    pr3.s3 = pr1.s4 = F2( top[6], top[7], top[8] );
    pr2.s4 = pr0.s5 = F1( top[7], top[8] );
    pr3.s4 = pr1.s5 = F2( top[7], top[8], top[9] );
    pr2.s5 = pr0.s6 = F1( top[8], top[9] );
    pr3.s5 = pr1.s6 = F2( top[8], top[9], top[10] );
    pr2.s6 = pr0.s7 = F1( top[9], top[10] );
    pr3.s6 = pr1.s7 = F2( top[9], top[10], top[11] );
    pr2.s7 = F1( top[10], top[11] );
    pr3.s7 = F2( top[10], top[11], top[12] );
    return satd + satd_8x4_intra_lr( src + ( src_stride << 2 ), src_stride, pr0, pr1, pr2, pr3 );
}

int x264_predict_8x8_hu( const local pixel *src, int src_stride, const local pixel *left )
{
    int8 pr0, pr1, pr2, pr3;

    // Upper half of pred[]
    pr0.s0 = F1( left[0], left[1] ); pr0.s1 = (left[0] + 2 * left[1] + left[2] + 2) >> 2;
    pr0.s2 = F1( left[1], left[2] ); pr0.s3 = (left[1] + 2 * left[2] + left[3] + 2) >> 2;
    pr0.s4 = F1( left[2], left[3] ); pr0.s5 = (left[2] + 2 * left[3] + left[4] + 2) >> 2;
    pr0.s6 = F1( left[3], left[4] ); pr0.s7 = (left[3] + 2 * left[4] + left[5] + 2) >> 2;

    pr1.s0 = F1( left[1], left[2] ); pr1.s1 = (left[1] + 2 * left[2] + left[3] + 2) >> 2;
    pr1.s2 = F1( left[2], left[3] ); pr1.s3 = (left[2] + 2 * left[3] + left[4] + 2) >> 2;
    pr1.s4 = F1( left[3], left[4] ); pr1.s5 = (left[3] + 2 * left[4] + left[5] + 2) >> 2;
    pr1.s6 = F1( left[4], left[5] ); pr1.s7 = (left[4] + 2 * left[5] + left[6] + 2) >> 2;

    pr2.s0 = F1( left[2], left[3] ); pr2.s1 = (left[2] + 2 * left[3] + left[4] + 2) >> 2;
    pr2.s2 = F1( left[3], left[4] ); pr2.s3 = (left[3] + 2 * left[4] + left[5] + 2) >> 2;
    pr2.s4 = F1( left[4], left[5] ); pr2.s5 = (left[4] + 2 * left[5] + left[6] + 2) >> 2;
    pr2.s6 = F1( left[5], left[6] ); pr2.s7 = (left[5] + 2 * left[6] + left[7] + 2) >> 2;

    pr3.s0 = F1( left[3], left[4] ); pr3.s1 = (left[3] + 2 * left[4] + left[5] + 2) >> 2;
    pr3.s2 = F1( left[4], left[5] ); pr3.s3 = (left[4] + 2 * left[5] + left[6] + 2) >> 2;
    pr3.s4 = F1( left[5], left[6] ); pr3.s5 = (left[5] + 2 * left[6] + left[7] + 2) >> 2;
    pr3.s6 = F1( left[6], left[7] ); pr3.s7 = (left[6] + 2 * left[7] + left[7] + 2) >> 2;
    int satd = satd_8x4_intra_lr( src, src_stride, pr0, pr1, pr2, pr3 );

    // Lower half of pred[]
    pr0.s0 = F1( left[4], left[5] ); pr0.s1 = (left[4] + 2 * left[5] + left[6] + 2) >> 2;
    pr0.s2 = F1( left[5], left[6] ); pr0.s3 = (left[5] + 2 * left[6] + left[7] + 2) >> 2;
    pr0.s4 = F1( left[6], left[7] ); pr0.s5 = (left[6] + 2 * left[7] + left[7] + 2) >> 2;
    pr0.s6 = left[7]; pr0.s7 = left[7];

    pr1.s0 = F1( left[5], left[6] ); pr1.s1 = (left[5] + 2 * left[6] + left[7] + 2) >> 2;
    pr1.s2 = F1( left[6], left[7] ); pr1.s3 = (left[6] + 2 * left[7] + left[7] + 2) >> 2;
    pr1.s4 = left[7]; pr1.s5 = left[7];
    pr1.s6 = left[7]; pr1.s7 = left[7];

    pr2.s0 = F1( left[6], left[7] ); pr2.s1 = (left[6] + 2 * left[7] + left[7] + 2) >> 2;
    pr2.s2 = left[7]; pr2.s3 = left[7];
    pr2.s4 = left[7]; pr2.s5 = left[7];
    pr2.s6 = left[7]; pr2.s7 = left[7];

    pr3 = (int8)left[7];

    return satd + satd_8x4_intra_lr( src + ( src_stride << 2 ), src_stride, pr0, pr1, pr2, pr3 );
}

int x264_predict_8x8c_h( const local pixel *src, int src_stride )
{
    const local pixel *src_l = src;
    int8 pr0, pr1, pr2, pr3;

    // Upper half of pred[]
    pr0 = (int8)src[-1]; src += src_stride;
    pr1 = (int8)src[-1]; src += src_stride;
    pr2 = (int8)src[-1]; src += src_stride;
    pr3 = (int8)src[-1]; src += src_stride;
    int satd = satd_8x4_intra_lr( src_l, src_stride, pr0, pr1, pr2, pr3 );

    //Lower half of pred[]
    pr0 = (int8)src[-1]; src += src_stride;
    pr1 = (int8)src[-1]; src += src_stride;
    pr2 = (int8)src[-1]; src += src_stride;
    pr3 = (int8)src[-1];
    return satd + satd_8x4_intra_lr( src_l + ( src_stride << 2 ), src_stride, pr0, pr1, pr2, pr3 );
}

int x264_predict_8x8c_v( const local pixel *src, int src_stride )
{
    int8 pred = convert_int8( vload8( 0, &src[-src_stride] ));
    return satd_8x4_intra_lr( src, src_stride, pred, pred, pred, pred ) +
           satd_8x4_intra_lr( src + ( src_stride << 2 ), src_stride, pred, pred, pred, pred );
}

int x264_predict_8x8c_p( const local pixel *src, int src_stride )
{
    int H = 0, V = 0;
    for( int i = 0; i < 4; i++ )
    {
        H += (i + 1) * (src[4 + i - src_stride] - src[2 - i - src_stride]);
        V += (i + 1) * (src[-1 + (i + 4) * src_stride] - src[-1 + (2 - i) * src_stride]);
    }

    int a = 16 * (src[-1 + 7 * src_stride] + src[7 - src_stride]);
    int b = (17 * H + 16) >> 5;
    int c = (17 * V + 16) >> 5;
    int i00 = a - 3 * b - 3 * c + 16;

    // Upper half of pred[]
    int pix = i00;
    int8 pr0, pr1, pr2, pr3;
    pr0.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;

    pix = i00;
    pr1.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;

    pix = i00;
    pr2.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;

    pix = i00;
    pr3.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;
    int satd = satd_8x4_intra_lr( src, src_stride, pr0, pr1, pr2, pr3 );

    //Lower half of pred[]
    pix = i00;
    pr0.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr0.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;

    pix = i00;
    pr1.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr1.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;

    pix = i00;
    pr2.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr2.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;

    pix = i00;
    pr3.s0 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s1 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s2 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s3 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s4 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s5 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s6 = x264_clip_pixel( pix >> 5 ); pix += b;
    pr3.s7 = x264_clip_pixel( pix >> 5 ); i00 += c;
    return satd + satd_8x4_intra_lr( src + ( src_stride << 2 ), src_stride, pr0, pr1, pr2, pr3 );
}

int x264_predict_8x8c_dc( const local pixel *src, int src_stride )
{
    int s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for( int i = 0; i < 4; i++ )
    {
        s0 += src[i - src_stride];
        s1 += src[i + 4 - src_stride];
        s2 += src[-1 + i * src_stride];
        s3 += src[-1 + (i+4)*src_stride];
    }

    // Upper half of pred[]
    int8 dc0;
    dc0.lo = (int4)( (s0 + s2 + 4) >> 3 );
    dc0.hi = (int4)( (s1 + 2) >> 2 );
    int satd = satd_8x4_intra_lr( src, src_stride, dc0, dc0, dc0, dc0 );

    // Lower half of pred[]
    dc0.lo = (int4)( (s3 + 2) >> 2 );
    dc0.hi = (int4)( (s1 + s3 + 4) >> 3 );
    return satd + satd_8x4_intra_lr( src + ( src_stride << 2 ), src_stride, dc0, dc0, dc0, dc0 );
}

#else  /* not vectorized: private is cheap registers are scarce */

int x264_predict_8x8_ddl( const local pixel *src, int src_stride, const local pixel *top )
{
    private pixel pred[32];

    // Upper half of pred[]
    for( int y = 0; y < 4; y++ )
    {
        for( int x = 0; x < 8; x++ )
        {
            pixel x_plus_y = (pixel) clamp_int( x + y, 0, 13 );
            pred[x + y*8] = ( 2 + top[x_plus_y] + 2*top[x_plus_y + 1] + top[x_plus_y + 2] ) >> 2;
        }
    }
    int satd = satd_8x4_lp( src, src_stride, pred, 8 );
    //Lower half of pred[]
    for( int y = 4; y < 8; y++ )
    {
        for( int x = 0; x < 8; x++ )
        {
            pixel x_plus_y = (pixel) clamp_int( x + y, 0, 13 );
            pred[x + ( y - 4 )*8] = ( 2 + top[x_plus_y] + 2*top[x_plus_y + 1] + top[x_plus_y + 2] ) >> 2;
        }
    }
    pred[31] = ( 2 + top[14] + 3*top[15] ) >> 2;
    satd += satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
    return satd;
}

int x264_predict_8x8_ddr( const local pixel *src, int src_stride, const local pixel *top, const local pixel *left, pixel left_top )
{
    private pixel pred[32];
#define PRED( x, y ) pred[(x) + (y)*8]
    // Upper half of pred[]
    PRED( 0, 3 ) = F2( left[1], left[2], left[3] );
    PRED( 0, 2 ) = PRED( 1, 3 ) = F2( left[0], left[1], left[2] );
    PRED( 0, 1 ) = PRED( 1, 2 ) = PRED( 2, 3 ) = F2( left[1], left[0], left_top );
    PRED( 0, 0 ) = PRED( 1, 1 ) = PRED( 2, 2 ) = PRED( 3, 3 ) = F2( left[0], left_top, top[0] );
    PRED( 1, 0 ) = PRED( 2, 1 ) = PRED( 3, 2 ) = PRED( 4, 3 ) = F2( left_top, top[0], top[1] );
    PRED( 2, 0 ) = PRED( 3, 1 ) = PRED( 4, 2 ) = PRED( 5, 3 ) = F2( top[0], top[1], top[2] );
    PRED( 3, 0 ) = PRED( 4, 1 ) = PRED( 5, 2 ) = PRED( 6, 3 ) = F2( top[1], top[2], top[3] );
    PRED( 4, 0 ) = PRED( 5, 1 ) = PRED( 6, 2 ) = PRED( 7, 3 ) = F2( top[2], top[3], top[4] );
    PRED( 5, 0 ) = PRED( 6, 1 ) = PRED( 7, 2 ) = F2( top[3], top[4], top[5] );
    PRED( 6, 0 ) = PRED( 7, 1 ) = F2( top[4], top[5], top[6] );
    PRED( 7, 0 ) = F2( top[5], top[6], top[7] );
    int satd = satd_8x4_lp( src, src_stride, pred, 8 );

    // Lower half of pred[]
    PRED( 0, 3 ) = F2( left[5], left[6], left[7] );
    PRED( 0, 2 ) = PRED( 1, 3 ) = F2( left[4], left[5], left[6] );
    PRED( 0, 1 ) = PRED( 1, 2 ) = PRED( 2, 3 ) = F2( left[3], left[4], left[5] );
    PRED( 0, 0 ) = PRED( 1, 1 ) = PRED( 2, 2 ) = PRED( 3, 3 ) = F2( left[2], left[3], left[4] );
    PRED( 1, 0 ) = PRED( 2, 1 ) = PRED( 3, 2 ) = PRED( 4, 3 ) = F2( left[1], left[2], left[3] );
    PRED( 2, 0 ) = PRED( 3, 1 ) = PRED( 4, 2 ) = PRED( 5, 3 ) = F2( left[0], left[1], left[2] );
    PRED( 3, 0 ) = PRED( 4, 1 ) = PRED( 5, 2 ) = PRED( 6, 3 ) = F2( left[1], left[0], left_top );
    PRED( 4, 0 ) = PRED( 5, 1 ) = PRED( 6, 2 ) = PRED( 7, 3 ) = F2( left[0], left_top, top[0] );
    PRED( 5, 0 ) = PRED( 6, 1 ) = PRED( 7, 2 ) = F2( left_top, top[0], top[1] );
    PRED( 6, 0 ) = PRED( 7, 1 ) = F2( top[0], top[1], top[2] );
    PRED( 7, 0 ) = F2( top[1], top[2], top[3] );
    satd += satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
    return satd;
#undef PRED
}

int x264_predict_8x8_vr( const local pixel *src, int src_stride, const local pixel *top, const local pixel *left, pixel left_top )
{
    private pixel pred[32];
#define PRED( x, y ) pred[(x) + (y)*8]
    // Upper half of pred[]
    PRED( 0, 2 ) = F2( left[1], left[0], left_top );
    PRED( 0, 3 ) = F2( left[2], left[1], left[0] );
    PRED( 0, 1 ) = PRED( 1, 3 ) = F2( left[0], left_top, top[0] );
    PRED( 0, 0 ) = PRED( 1, 2 ) = F1( left_top, top[0] );
    PRED( 1, 1 ) = PRED( 2, 3 ) = F2( left_top, top[0], top[1] );
    PRED( 1, 0 ) = PRED( 2, 2 ) = F1( top[0], top[1] );
    PRED( 2, 1 ) = PRED( 3, 3 ) = F2( top[0], top[1], top[2] );
    PRED( 2, 0 ) = PRED( 3, 2 ) = F1( top[1], top[2] );
    PRED( 3, 1 ) = PRED( 4, 3 ) = F2( top[1], top[2], top[3] );
    PRED( 3, 0 ) = PRED( 4, 2 ) = F1( top[2], top[3] );
    PRED( 4, 1 ) = PRED( 5, 3 ) = F2( top[2], top[3], top[4] );
    PRED( 4, 0 ) = PRED( 5, 2 ) = F1( top[3], top[4] );
    PRED( 5, 1 ) = PRED( 6, 3 ) = F2( top[3], top[4], top[5] );
    PRED( 5, 0 ) = PRED( 6, 2 ) = F1( top[4], top[5] );
    PRED( 6, 1 ) = PRED( 7, 3 ) = F2( top[4], top[5], top[6] );
    PRED( 6, 0 ) = PRED( 7, 2 ) = F1( top[5], top[6] );
    PRED( 7, 1 ) = F2( top[5], top[6], top[7] );
    PRED( 7, 0 ) = F1( top[6], top[7] );
    int satd = satd_8x4_lp( src, src_stride, pred, 8 );

    //Lower half of pred[]
    PRED( 0, 2 ) = F2( left[5], left[4], left[3] );
    PRED( 0, 3 ) = F2( left[6], left[5], left[4] );
    PRED( 0, 0 ) = PRED( 1, 2 ) = F2( left[3], left[2], left[1] );
    PRED( 0, 1 ) = PRED( 1, 3 ) = F2( left[4], left[3], left[2] );
    PRED( 1, 0 ) = PRED( 2, 2 ) = F2( left[1], left[0], left_top );
    PRED( 1, 1 ) = PRED( 2, 3 ) = F2( left[2], left[1], left[0] );
    PRED( 2, 1 ) = PRED( 3, 3 ) = F2( left[0], left_top, top[0] );
    PRED( 2, 0 ) = PRED( 3, 2 ) = F1( left_top, top[0] );
    PRED( 3, 1 ) = PRED( 4, 3 ) = F2( left_top, top[0], top[1] );
    PRED( 3, 0 ) = PRED( 4, 2 ) = F1( top[0], top[1] );
    PRED( 4, 1 ) = PRED( 5, 3 ) = F2( top[0], top[1], top[2] );
    PRED( 4, 0 ) = PRED( 5, 2 ) = F1( top[1], top[2] );
    PRED( 5, 1 ) = PRED( 6, 3 ) = F2( top[1], top[2], top[3] );
    PRED( 5, 0 ) = PRED( 6, 2 ) = F1( top[2], top[3] );
    PRED( 6, 1 ) = PRED( 7, 3 ) = F2( top[2], top[3], top[4] );
    PRED( 6, 0 ) = PRED( 7, 2 ) = F1( top[3], top[4] );
    PRED( 7, 1 ) = F2( top[3], top[4], top[5] );
    PRED( 7, 0 ) = F1( top[4], top[5] );
    satd += satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
    return satd;
#undef PRED
}

inline uint32_t pack16to32( uint32_t a, uint32_t b )
{
    return a + (b << 16);
}

inline uint32_t pack8to16( uint32_t a, uint32_t b )
{
    return a + (b << 8);
}

int x264_predict_8x8_hd( const local pixel *src, int src_stride, const local pixel *top, const local pixel *left, pixel left_top )
{
    private pixel pred[32];
    int satd;
    int p1 =  pack8to16( (F1( left[6], left[7] )), ((left[5] + 2 * left[6] + left[7] + 2) >> 2) );
    int p2 =  pack8to16( (F1( left[5], left[6] )), ((left[4] + 2 * left[5] + left[6] + 2) >> 2) );
    int p3 =  pack8to16( (F1( left[4], left[5] )), ((left[3] + 2 * left[4] + left[5] + 2) >> 2) );
    int p4 =  pack8to16( (F1( left[3], left[4] )), ((left[2] + 2 * left[3] + left[4] + 2) >> 2) );
    int p5 =  pack8to16( (F1( left[2], left[3] )), ((left[1] + 2 * left[2] + left[3] + 2) >> 2) );
    int p6 =  pack8to16( (F1( left[1], left[2] )), ((left[0] + 2 * left[1] + left[2] + 2) >> 2) );
    int p7 =  pack8to16( (F1( left[0], left[1] )), ((left_top + 2 * left[0] + left[1] + 2) >> 2) );
    int p8 =  pack8to16( (F1( left_top, left[0] )), ((left[0] + 2 * left_top + top[0] + 2) >> 2) );
    int p9 =  pack8to16( (F2( top[1], top[0], left_top )), (F2( top[2], top[1], top[0] )) );
    int p10 =  pack8to16( (F2( top[3], top[2], top[1] )), (F2( top[4], top[3], top[2] )) );
    int p11 =  pack8to16( (F2( top[5], top[4], top[3] )), (F2( top[6], top[5], top[4] )) );
    // Upper half of pred[]
    vstore4( as_uchar4( pack16to32( p8, p9 ) ), 0, &pred[0 + 0 * 8] );
    vstore4( as_uchar4( pack16to32( p10, p11 ) ), 0, &pred[4 + 0 * 8] );
    vstore4( as_uchar4( pack16to32( p7, p8 ) ), 0, &pred[0 + 1 * 8] );
    vstore4( as_uchar4( pack16to32( p9, p10 ) ), 0, &pred[4 + 1 * 8] );
    vstore4( as_uchar4( pack16to32( p6, p7 ) ), 0, &pred[0 + 2 * 8] );
    vstore4( as_uchar4( pack16to32( p8, p9 ) ), 0, &pred[4 + 2 * 8] );
    vstore4( as_uchar4( pack16to32( p5, p6 ) ), 0, &pred[0 + 3 * 8] );
    vstore4( as_uchar4( pack16to32( p7, p8 ) ), 0, &pred[4 + 3 * 8] );
    satd = satd_8x4_lp( src, src_stride, pred, 8 );
    // Lower half of pred[]
    vstore4( as_uchar4( pack16to32( p4, p5 ) ), 0, &pred[0 + 0 * 8] );
    vstore4( as_uchar4( pack16to32( p6, p7 ) ), 0, &pred[4 + 0 * 8] );
    vstore4( as_uchar4( pack16to32( p3, p4 ) ), 0, &pred[0 + 1 * 8] );
    vstore4( as_uchar4( pack16to32( p5, p6 ) ), 0, &pred[4 + 1 * 8] );
    vstore4( as_uchar4( pack16to32( p2, p3 ) ), 0, &pred[0 + 2 * 8] );
    vstore4( as_uchar4( pack16to32( p4, p5 ) ), 0, &pred[4 + 2 * 8] );
    vstore4( as_uchar4( pack16to32( p1, p2 ) ), 0, &pred[0 + 3 * 8] );
    vstore4( as_uchar4( pack16to32( p3, p4 ) ), 0, &pred[4 + 3 * 8] );
    satd += satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
    return satd;
}

int x264_predict_8x8_vl( const local pixel *src, int src_stride, const local pixel *top )
{
    private pixel pred[32];
    int satd;
#define PRED( x, y ) pred[(x) + (y)*8]
    // Upper half of pred[]
    PRED( 0, 0 ) = F1( top[0], top[1] );
    PRED( 0, 1 ) = F2( top[0], top[1], top[2] );
    PRED( 0, 2 ) = PRED( 1, 0 ) = F1( top[1], top[2] );
    PRED( 0, 3 ) = PRED( 1, 1 ) = F2( top[1], top[2], top[3] );
    PRED( 1, 2 ) = PRED( 2, 0 ) = F1( top[2], top[3] );
    PRED( 1, 3 ) = PRED( 2, 1 ) = F2( top[2], top[3], top[4] );
    PRED( 2, 2 ) = PRED( 3, 0 ) = F1( top[3], top[4] );
    PRED( 2, 3 ) = PRED( 3, 1 ) = F2( top[3], top[4], top[5] );
    PRED( 3, 2 ) = PRED( 4, 0 ) = F1( top[4], top[5] );
    PRED( 3, 3 ) = PRED( 4, 1 ) = F2( top[4], top[5], top[6] );
    PRED( 4, 2 ) = PRED( 5, 0 ) = F1( top[5], top[6] );
    PRED( 4, 3 ) = PRED( 5, 1 ) = F2( top[5], top[6], top[7] );
    PRED( 5, 2 ) = PRED( 6, 0 ) = F1( top[6], top[7] );
    PRED( 5, 3 ) = PRED( 6, 1 ) = F2( top[6], top[7], top[8] );
    PRED( 6, 2 ) = PRED( 7, 0 ) = F1( top[7], top[8] );
    PRED( 6, 3 ) = PRED( 7, 1 ) = F2( top[7], top[8], top[9] );
    PRED( 7, 2 ) = F1( top[8], top[9] );
    PRED( 7, 3 ) = F2( top[8], top[9], top[10] );
    satd = satd_8x4_lp( src, src_stride, pred, 8 );
    // Lower half of pred[]
    PRED( 0, 0 ) = F1( top[2], top[3] );
    PRED( 0, 1 ) = F2( top[2], top[3], top[4] );
    PRED( 0, 2 ) = PRED( 1, 0 ) = F1( top[3], top[4] );
    PRED( 0, 3 ) = PRED( 1, 1 ) = F2( top[3], top[4], top[5] );
    PRED( 1, 2 ) = PRED( 2, 0 ) = F1( top[4], top[5] );
    PRED( 1, 3 ) = PRED( 2, 1 ) = F2( top[4], top[5], top[6] );
    PRED( 2, 2 ) = PRED( 3, 0 ) = F1( top[5], top[6] );
    PRED( 2, 3 ) = PRED( 3, 1 ) = F2( top[5], top[6], top[7] );
    PRED( 3, 2 ) = PRED( 4, 0 ) = F1( top[6], top[7] );
    PRED( 3, 3 ) = PRED( 4, 1 ) = F2( top[6], top[7], top[8] );
    PRED( 4, 2 ) = PRED( 5, 0 ) = F1( top[7], top[8] );
    PRED( 4, 3 ) = PRED( 5, 1 ) = F2( top[7], top[8], top[9] );
    PRED( 5, 2 ) = PRED( 6, 0 ) = F1( top[8], top[9] );
    PRED( 5, 3 ) = PRED( 6, 1 ) = F2( top[8], top[9], top[10] );
    PRED( 6, 2 ) = PRED( 7, 0 ) = F1( top[9], top[10] );
    PRED( 6, 3 ) = PRED( 7, 1 ) = F2( top[9], top[10], top[11] );
    PRED( 7, 2 ) = F1( top[10], top[11] );
    PRED( 7, 3 ) = F2( top[10], top[11], top[12] );
    satd += satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
    return satd;
#undef PRED
}

int x264_predict_8x8_hu( const local pixel *src, int src_stride, const local pixel *left )
{
    private pixel pred[32];
    int satd;
    int p1 = pack8to16( (F1( left[0], left[1] )), ((left[0] + 2 * left[1] + left[2] + 2) >> 2) );
    int p2 = pack8to16( (F1( left[1], left[2] )), ((left[1] + 2 * left[2] + left[3] + 2) >> 2) );
    int p3 = pack8to16( (F1( left[2], left[3] )), ((left[2] + 2 * left[3] + left[4] + 2) >> 2) );
    int p4 = pack8to16( (F1( left[3], left[4] )), ((left[3] + 2 * left[4] + left[5] + 2) >> 2) );
    int p5 = pack8to16( (F1( left[4], left[5] )), ((left[4] + 2 * left[5] + left[6] + 2) >> 2) );
    int p6 = pack8to16( (F1( left[5], left[6] )), ((left[5] + 2 * left[6] + left[7] + 2) >> 2) );
    int p7 = pack8to16( (F1( left[6], left[7] )), ((left[6] + 2 * left[7] + left[7] + 2) >> 2) );
    int p8 = pack8to16( left[7], left[7] );
    // Upper half of pred[]
    vstore4( as_uchar4( pack16to32( p1, p2 ) ), 0, &pred[( 0 ) + ( 0 ) * 8] );
    vstore4( as_uchar4( pack16to32( p3, p4 ) ), 0, &pred[( 4 ) + ( 0 ) * 8] );
    vstore4( as_uchar4( pack16to32( p2, p3 ) ), 0, &pred[( 0 ) + ( 1 ) * 8] );
    vstore4( as_uchar4( pack16to32( p4, p5 ) ), 0, &pred[( 4 ) + ( 1 ) * 8] );
    vstore4( as_uchar4( pack16to32( p3, p4 ) ), 0, &pred[( 0 ) + ( 2 ) * 8] );
    vstore4( as_uchar4( pack16to32( p5, p6 ) ), 0, &pred[( 4 ) + ( 2 ) * 8] );
    vstore4( as_uchar4( pack16to32( p4, p5 ) ), 0, &pred[( 0 ) + ( 3 ) * 8] );
    vstore4( as_uchar4( pack16to32( p6, p7 ) ), 0, &pred[( 4 ) + ( 3 ) * 8] );
    satd = satd_8x4_lp( src, src_stride, pred, 8 );
    // Lower half of pred[]
    vstore4( as_uchar4( pack16to32( p5, p6 ) ), 0, &pred[( 0 ) + ( 0 ) * 8] );
    vstore4( as_uchar4( pack16to32( p7, p8 ) ), 0, &pred[( 4 ) + ( 0 ) * 8] );
    vstore4( as_uchar4( pack16to32( p6, p7 ) ), 0, &pred[( 0 ) + ( 1 ) * 8] );
    vstore4( as_uchar4( pack16to32( p8, p8 ) ), 0, &pred[( 4 ) + ( 1 ) * 8] );
    vstore4( as_uchar4( pack16to32( p7, p8 ) ), 0, &pred[( 0 ) + ( 2 ) * 8] );
    vstore4( as_uchar4( pack16to32( p8, p8 ) ), 0, &pred[( 4 ) + ( 2 ) * 8] );
    vstore4( as_uchar4( pack16to32( p8, p8 ) ), 0, &pred[( 0 ) + ( 3 ) * 8] );
    vstore4( as_uchar4( pack16to32( p8, p8 ) ), 0, &pred[( 4 ) + ( 3 ) * 8] );
    satd += satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
    return satd;
}

int x264_predict_8x8c_h( const local pixel *src, int src_stride )
{
    private pixel pred[32];
    const local pixel *src_l = src;

    // Upper half of pred[]
    vstore8( (uchar8)(src[-1]), 0, pred ); src += src_stride;
    vstore8( (uchar8)(src[-1]), 1, pred ); src += src_stride;
    vstore8( (uchar8)(src[-1]), 2, pred ); src += src_stride;
    vstore8( (uchar8)(src[-1]), 3, pred ); src += src_stride;
    int satd = satd_8x4_lp( src_l, src_stride, pred, 8 );

    // Lower half of pred[]
    vstore8( (uchar8)(src[-1]), 0, pred ); src += src_stride;
    vstore8( (uchar8)(src[-1]), 1, pred ); src += src_stride;
    vstore8( (uchar8)(src[-1]), 2, pred ); src += src_stride;
    vstore8( (uchar8)(src[-1]), 3, pred );
    return satd + satd_8x4_lp( src_l + ( src_stride << 2 ), src_stride, pred, 8 );
}

int x264_predict_8x8c_v( const local pixel *src, int src_stride )
{
    private pixel pred[32];
    uchar16 v16;
    v16.lo = vload8( 0, &src[-src_stride] );
    v16.hi = vload8( 0, &src[-src_stride] );

    vstore16( v16, 0, pred );
    vstore16( v16, 1, pred );

    return satd_8x4_lp( src, src_stride, pred, 8 ) +
           satd_8x4_lp( src + (src_stride << 2), src_stride, pred, 8 );
}

int x264_predict_8x8c_p( const local pixel *src, int src_stride )
{
    int H = 0, V = 0;
    private pixel pred[32];
    int satd;

    for( int i = 0; i < 4; i++ )
    {
        H += (i + 1) * (src[4 + i - src_stride] - src[2 - i - src_stride]);
        V += (i + 1) * (src[-1 + (i + 4) * src_stride] - src[-1 + (2 - i) * src_stride]);
    }

    int a = 16 * (src[-1 + 7 * src_stride] + src[7 - src_stride]);
    int b = (17 * H + 16) >> 5;
    int c = (17 * V + 16) >> 5;
    int i00 = a - 3 * b - 3 * c + 16;

    // Upper half of pred[]
    for( int y = 0; y < 4; y++ )
    {
        int pix = i00;
        for( int x = 0; x < 8; x++ )
        {
            pred[x + y*8] = x264_clip_pixel( pix >> 5 );
            pix += b;
        }
        i00 += c;
    }
    satd = satd_8x4_lp( src, src_stride, pred, 8 );
    // Lower half of pred[]
    for( int y = 0; y < 4; y++ )
    {
        int pix = i00;
        for( int x = 0; x < 8; x++ )
        {
            pred[x + y*8] = x264_clip_pixel( pix >> 5 );
            pix += b;
        }
        i00 += c;
    }
    satd += satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
    return satd;
}

int x264_predict_8x8c_dc( const local pixel *src, int src_stride )
{
    private pixel pred[32];
    int s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for( int i = 0; i < 4; i++ )
    {
        s0 += src[i - src_stride];
        s1 += src[i + 4 - src_stride];
        s2 += src[-1 + i * src_stride];
        s3 += src[-1 + (i+4)*src_stride];
    }

    // Upper half of pred[]
    uchar8 dc0;
    dc0.lo = (uchar4)( (s0 + s2 + 4) >> 3 );
    dc0.hi = (uchar4)( (s1 + 2) >> 2 );
    vstore8( dc0, 0, pred );
    vstore8( dc0, 1, pred );
    vstore8( dc0, 2, pred );
    vstore8( dc0, 3, pred );
    int satd = satd_8x4_lp( src, src_stride, pred, 8 );

    // Lower half of pred[]
    dc0.lo = (uchar4)( (s3 + 2) >> 2 );
    dc0.hi = (uchar4)( (s1 + s3 + 4) >> 3 );
    vstore8( dc0, 0, pred );
    vstore8( dc0, 1, pred );
    vstore8( dc0, 2, pred );
    vstore8( dc0, 3, pred );
    return satd + satd_8x4_lp( src + ( src_stride << 2 ), src_stride, pred, 8 );
}
#endif

/* Find the least cost intra mode for 32 8x8 macroblocks per workgroup
 *
 * Loads 33 macroblocks plus the pixels directly above them into local memory,
 * padding where necessary with edge pixels.  It then cooperatively calculates
 * smoothed top and left pixels for use in some of the analysis.
 *
 * Then groups of 32 threads each calculate a single intra mode for each 8x8
 * block.  Since consecutive threads are calculating the same intra mode there
 * is no code-path divergence.  8 intra costs are calculated simultaneously.  If
 * the "slow" argument is not zero, the final two (least likely) intra modes are
 * tested in a second pass.  The slow mode is only enabled for presets slow,
 * slower, and placebo.
 *
 * This allows all of the pixels functions to read pixels from local memory, and
 * avoids re-fetching edge pixels from global memory.  And it allows us to
 * calculate all of the intra mode costs simultaneously without branch divergence.
 *
 * Local dimension:    [ 32, 8 ]
 * Global dimensions:  [ paddedWidth, height ] */
kernel void mb_intra_cost_satd_8x8( read_only image2d_t  fenc,
                                    global uint16_t     *fenc_intra_cost,
                                    global int          *frame_stats,
                                    int                  lambda,
                                    int                  mb_width,
                                    int                  slow )
{
#define CACHE_STRIDE 265
#define BLOCK_OFFSET 266
    local pixel cache[2385];
    local int cost_buf[32];
    local pixel top[32 * 16];
    local pixel left[32 * 8];
    local pixel left_top[32];

    int lx = get_local_id( 0 );
    int ly = get_local_id( 1 );
    int gx = get_global_id( 0 );
    int gy = get_global_id( 1 );
    int gidx = get_group_id( 0 );
    int gidy = get_group_id( 1 );
    int linear_id = ly * get_local_size( 0 ) + lx;
    int satd = COST_MAX;
    int basex = gidx << 8;
    int basey = (gidy << 3) - 1;

    /* Load 33 8x8 macroblocks and the pixels above them into local cache */
    for( int y = 0; y < 9 && linear_id < (33<<3)>>2; y++ )
    {
        int x = linear_id << 2;
        uint4 data = read_imageui( fenc, sampler, (int2)(x + basex, y + basey) );
        cache[y * CACHE_STRIDE + 1 + x] = data.s0;
        cache[y * CACHE_STRIDE + 1 + x + 1] = data.s1;
        cache[y * CACHE_STRIDE + 1 + x + 2] = data.s2;
        cache[y * CACHE_STRIDE + 1 + x + 3] = data.s3;
    }
    /* load pixels on left edge */
    if( linear_id < 9 )
        cache[linear_id * CACHE_STRIDE] = read_imageui( fenc, sampler, (int2)( basex - 1, linear_id + basey) ).s0;

    barrier( CLK_LOCAL_MEM_FENCE );

    // Cooperatively build the top edge for the macroblock using lowpass filter
    int j = ly;
    top[lx*16 + j] = ( cache[BLOCK_OFFSET + 8*lx - CACHE_STRIDE + clamp_int( j - 1, -1, 15 )] +
                       2*cache[BLOCK_OFFSET + 8*lx - CACHE_STRIDE + clamp_int( j, 0, 15 )] +
                       cache[BLOCK_OFFSET + 8*lx - CACHE_STRIDE + clamp_int( j + 1, 0, 15 )] + 2 ) >> 2;
    j += 8;
    top[lx*16 + j] = ( cache[BLOCK_OFFSET + 8*lx - CACHE_STRIDE + clamp_int( j - 1, -1, 15 )] +
                       2*cache[BLOCK_OFFSET + 8*lx - CACHE_STRIDE + clamp_int( j, 0, 15 )] +
                       cache[BLOCK_OFFSET + 8*lx - CACHE_STRIDE + clamp_int( j + 1, 0, 15 )] + 2 ) >> 2;
    // Cooperatively build the left edge for the macroblock using lowpass filter
    left[lx*8 + ly] = ( cache[BLOCK_OFFSET + 8*lx - 1 + CACHE_STRIDE*(ly - 1)] +
                        2*cache[BLOCK_OFFSET + 8*lx - 1 + CACHE_STRIDE*ly] +
                        cache[BLOCK_OFFSET + 8*lx - 1 + CACHE_STRIDE*clamp((ly + 1), 0, 7 )] + 2 ) >> 2;
    // One left_top per macroblock
    if( 0 == ly )
    {
        left_top[lx] = ( cache[BLOCK_OFFSET + 8*lx - 1] + 2*cache[BLOCK_OFFSET + 8*lx - 1 - CACHE_STRIDE] +
                         cache[BLOCK_OFFSET + 8*lx - CACHE_STRIDE] + 2 ) >> 2;
        cost_buf[lx] = COST_MAX;
    }
    barrier( CLK_LOCAL_MEM_FENCE );

    // each warp/wavefront generates a different prediction type; no divergence
    switch( ly )
    {
        case 0:
            satd = x264_predict_8x8c_h( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE );
            break;
        case 1:
            satd = x264_predict_8x8c_v( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE );
            break;
        case 2:
            satd = x264_predict_8x8c_dc( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE );
            break;
        case 3:
            satd = x264_predict_8x8c_p( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE );
            break;
        case 4:
            satd = x264_predict_8x8_ddr( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE, &top[16*lx], &left[8*lx], left_top[lx] );
            break;
        case 5:
            satd = x264_predict_8x8_vr( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE, &top[16*lx], &left[8*lx], left_top[lx] );
            break;
        case 6:
            satd = x264_predict_8x8_hd( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE, &top[16*lx], &left[8*lx], left_top[lx] );
            break;
        case 7:
            satd = x264_predict_8x8_hu( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE, &left[8*lx] );
            break;
        default:
            break;
    }
    atom_min( &cost_buf[lx], satd );
    if( slow )
    {
        // Do the remaining two (least likely) prediction modes
        switch( ly )
        {
            case 0: // DDL
                satd = x264_predict_8x8_ddl( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE, &top[16*lx] );
                atom_min( &cost_buf[lx], satd );
                break;
            case 1: // VL
                satd = x264_predict_8x8_vl( &cache[BLOCK_OFFSET + 8*lx], CACHE_STRIDE, &top[16*lx] );
                atom_min( &cost_buf[lx], satd );
                break;
            default:
                break;
        }
    }
    barrier( CLK_LOCAL_MEM_FENCE );

    if( (0 == ly) && (gx < mb_width) )
        fenc_intra_cost[gidy * mb_width + gx] = cost_buf[lx]+ 5*lambda;

    // initialize the frame_stats[2] buffer for kernel sum_intra_cost().
    if( gx < 2 && gy == 0 )
        frame_stats[gx] = 0;
#undef CACHE_STRIDE
#undef BLOCK_OFFSET
}

/*
 * parallel sum intra costs
 *
 * global launch dimensions: [256, mb_height]
 */
kernel void sum_intra_cost( const global uint16_t *fenc_intra_cost,
                            const global uint16_t *inv_qscale_factor,
                            global int           *fenc_row_satds,
                            global int           *frame_stats,
                            int                   mb_width )
{
    int y = get_global_id( 1 );
    int mb_height = get_global_size( 1 );

    int row_satds = 0;
    int cost_est = 0;
    int cost_est_aq = 0;

    for( int x = get_global_id( 0 ); x < mb_width; x += get_global_size( 0 ))
    {
        int mb_xy = x + y * mb_width;
        int cost = fenc_intra_cost[mb_xy];
        int cost_aq = (cost * inv_qscale_factor[mb_xy] + 128) >> 8;
        int b_frame_score_mb = (x > 0 && x < mb_width - 1 && y > 0 && y < mb_height - 1) || mb_width <= 2 || mb_height <= 2;

        row_satds += cost_aq;
        if( b_frame_score_mb )
        {
            cost_est += cost;
            cost_est_aq += cost_aq;
        }
    }

    local int buffer[256];
    int x = get_global_id( 0 );

    row_satds   = parallel_sum( row_satds, x, buffer );
    cost_est    = parallel_sum( cost_est, x, buffer );
    cost_est_aq = parallel_sum( cost_est_aq, x, buffer );

    if( get_global_id( 0 ) == 0 )
    {
        fenc_row_satds[y] = row_satds;
        atomic_add( frame_stats + COST_EST,    cost_est );
        atomic_add( frame_stats + COST_EST_AQ, cost_est_aq );
    }
}
