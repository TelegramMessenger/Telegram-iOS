/*
 * downscale lowres luma: full-res buffer to down scale image, and to packed hpel image
 *
 * --
 *
 * fenc_img is an output image (area of memory referenced through a texture
 * cache). A read of any pixel location (x,y) returns four pixel values:
 *
 * val.s0 = P(x,y)
 * val.s1 = P(x+1,y)
 * val.s2 = P(x+2,y)
 * val.s3 = P(x+3,y)
 *
 * This is a 4x replication of the lowres pixels, a trade-off between memory
 * size and read latency.
 *
 * --
 *
 * hpel_planes is an output image that contains the four HPEL planes used for
 * subpel refinement. A read of any pixel location (x,y) returns a UInt32 with
 * the four planar values C | V | H | F
 *
 * launch dimensions:  [lowres-width, lowres-height]
 */
kernel void downscale_hpel( const global pixel *fenc,
                            write_only image2d_t fenc_img,
                            write_only image2d_t hpel_planes,
                            int stride )
{
    int x = get_global_id( 0 );
    int y = get_global_id( 1 );
    uint4 values;

    fenc += y * stride * 2;
    const global pixel *src1 = fenc + stride;
    const global pixel *src2 = (y == get_global_size( 1 )-1) ? src1 : src1 + stride;
    int2 pos = (int2)(x, y);
    pixel right, left;

    right = rhadd( fenc[x*2], src1[x*2] );
    left  = rhadd( fenc[x*2+1], src1[x*2+1] );
    values.s0 = rhadd( right, left );           // F

    right = rhadd( fenc[2*x+1], src1[2*x+1] );
    left  = rhadd( fenc[2*x+2], src1[2*x+2] );
    values.s1 = rhadd( right, left );           // H

    right = rhadd( src1[2*x], src2[2*x] );
    left  = rhadd( src1[2*x+1], src2[2*x+1] );
    values.s2 = rhadd( right, left );           // V

    right = rhadd( src1[2*x+1], src2[2*x+1] );
    left  = rhadd( src1[2*x+2], src2[2*x+2] );
    values.s3 = rhadd( right, left );           // C

    uint4 val = (uint4) ((values.s3 & 0xff) << 24) | ((values.s2 & 0xff) << 16) | ((values.s1 & 0xff) << 8) | (values.s0 & 0xff);
    write_imageui( hpel_planes, pos, val );

    x = select( x, x+1, x+1 < get_global_size( 0 ) );
    right = rhadd( fenc[x*2], src1[x*2] );
    left  = rhadd( fenc[x*2+1], src1[x*2+1] );
    values.s1 = rhadd( right, left );

    x = select( x, x+1, x+1 < get_global_size( 0 ) );
    right = rhadd( fenc[x*2], src1[x*2] );
    left  = rhadd( fenc[x*2+1], src1[x*2+1] );
    values.s2 = rhadd( right, left );

    x = select( x, x+1, x+1 < get_global_size( 0 ) );
    right = rhadd( fenc[x*2], src1[x*2] );
    left  = rhadd( fenc[x*2+1], src1[x*2+1] );
    values.s3 = rhadd( right, left );

    write_imageui( fenc_img, pos, values );
}

/*
 * downscale lowres hierarchical motion search image, copy from one image to
 * another decimated image.  This kernel is called iteratively to generate all
 * of the downscales.
 *
 * launch dimensions:  [lower_res width, lower_res height]
 */
kernel void downscale1( read_only image2d_t higher_res, write_only image2d_t lower_res )
{
    int x = get_global_id( 0 );
    int y = get_global_id( 1 );
    int2 pos = (int2)(x, y);
    int gs = get_global_size( 0 );
    uint4 top, bot, values;
    top = read_imageui( higher_res, sampler, (int2)(x*2, 2*y) );
    bot = read_imageui( higher_res, sampler, (int2)(x*2, 2*y+1) );
    values.s0 = rhadd( rhadd( top.s0, bot.s0 ), rhadd( top.s1, bot.s1 ) );

    /* these select statements appear redundant, and they should be, but tests break when
     * they are not here.  I believe this was caused by a driver bug
     */
    values.s1 = select( values.s0, rhadd( rhadd( top.s2, bot.s2 ), rhadd( top.s3, bot.s3 ) ), ( x + 1 < gs) );
    top = read_imageui( higher_res, sampler, (int2)(x*2+4, 2*y) );
    bot = read_imageui( higher_res, sampler, (int2)(x*2+4, 2*y+1) );
    values.s2 = select( values.s1, rhadd( rhadd( top.s0, bot.s0 ), rhadd( top.s1, bot.s1 ) ), ( x + 2 < gs ) );
    values.s3 = select( values.s2, rhadd( rhadd( top.s2, bot.s2 ), rhadd( top.s3, bot.s3 ) ), ( x + 3 < gs ) );
    write_imageui( lower_res, pos, (uint4)(values) );
}

/*
 * Second copy of downscale kernel, no differences. This is a (no perf loss)
 * workaround for a scheduling bug in current Tahiti drivers.  This bug has
 * theoretically been fixed in the July 2012 driver release from AMD.
 */
kernel void downscale2( read_only image2d_t higher_res, write_only image2d_t lower_res )
{
    int x = get_global_id( 0 );
    int y = get_global_id( 1 );
    int2 pos = (int2)(x, y);
    int gs = get_global_size( 0 );
    uint4 top, bot, values;
    top = read_imageui( higher_res, sampler, (int2)(x*2, 2*y) );
    bot = read_imageui( higher_res, sampler, (int2)(x*2, 2*y+1) );
    values.s0 = rhadd( rhadd( top.s0, bot.s0 ), rhadd( top.s1, bot.s1 ) );

    // see comment in above function copy
    values.s1 = select( values.s0, rhadd( rhadd( top.s2, bot.s2 ), rhadd( top.s3, bot.s3 ) ), ( x + 1 < gs) );
    top = read_imageui( higher_res, sampler, (int2)(x*2+4, 2*y) );
    bot = read_imageui( higher_res, sampler, (int2)(x*2+4, 2*y+1) );
    values.s2 = select( values.s1, rhadd( rhadd( top.s0, bot.s0 ), rhadd( top.s1, bot.s1 ) ), ( x + 2 < gs ) );
    values.s3 = select( values.s2, rhadd( rhadd( top.s2, bot.s2 ), rhadd( top.s3, bot.s3 ) ), ( x + 3 < gs ) );
    write_imageui( lower_res, pos, (uint4)(values) );
}

/* OpenCL 1.2 finally added a memset command, but we're not targeting 1.2 */
kernel void memset_int16( global int16_t *buf, int16_t value )
{
    buf[get_global_id( 0 )] = value;
}
