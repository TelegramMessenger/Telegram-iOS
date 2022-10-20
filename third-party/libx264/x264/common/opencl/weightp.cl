/* Weightp filter a downscaled image into a temporary output buffer.
 * This kernel is launched once for each scale.
 *
 * Launch dimensions: width x height (in pixels)
 */
kernel void weightp_scaled_images( read_only image2d_t in_plane,
                                   write_only image2d_t out_plane,
                                   uint offset,
                                   uint scale,
                                   uint denom )
{
    int gx = get_global_id( 0 );
    int gy = get_global_id( 1 );
    uint4 input_val;
    uint4 output_val;

    input_val = read_imageui( in_plane, sampler, (int2)(gx, gy));
    output_val = (uint4)(offset) + ( ( ((uint4)(scale)) * input_val ) >> ((uint4)(denom)) );
    write_imageui( out_plane, (int2)(gx, gy), output_val );
}

/* Weightp filter for the half-pel interpolated image
 *
 * Launch dimensions: width x height (in pixels)
 */
kernel void weightp_hpel( read_only image2d_t in_plane,
                          write_only image2d_t out_plane,
                          uint offset,
                          uint scale,
                          uint denom )
{
    int gx = get_global_id( 0 );
    int gy = get_global_id( 1 );
    uint input_val;
    uint output_val;

    input_val = read_imageui( in_plane, sampler, (int2)(gx, gy)).s0;
    //Unpack
    uint4 temp;
    temp.s0 = input_val & 0x00ff; temp.s1 = (input_val >> 8) & 0x00ff;
    temp.s2 = (input_val >> 16) & 0x00ff; temp.s3 = (input_val >> 24) & 0x00ff;

    temp = (uint4)(offset) + ( ( ((uint4)(scale)) * temp ) >> ((uint4)(denom)) );

    //Pack
    output_val = temp.s0 | (temp.s1 << 8) | (temp.s2 << 16) | (temp.s3 << 24);
    write_imageui( out_plane, (int2)(gx, gy), output_val );
}
