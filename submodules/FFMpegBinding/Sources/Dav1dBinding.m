#import <FFMpegBinding/Dav1dBinding.h>

#import "dav1d/dav1d.h"

/*static CFDataRef ff_videotoolbox_av1c_extradata_create(Dav1dSequenceHeader *header) {
    uint8_t *buf;
    CFDataRef data;
    
    header->

    buf = malloc(s->seq_data_ref->size + 4);
    if (!buf)
        return NULL;
    buf[0] = 0x81; // version and marker (constant)
    buf[1] = s->raw_seq->seq_profile << 5 | s->raw_seq->seq_level_idx[0];
    buf[2] = s->raw_seq->seq_tier[0]                << 7 |
             s->raw_seq->color_config.high_bitdepth << 6 |
             s->raw_seq->color_config.twelve_bit    << 5 |
             s->raw_seq->color_config.mono_chrome   << 4 |
             s->raw_seq->color_config.subsampling_x << 3 |
             s->raw_seq->color_config.subsampling_y << 2 |
             s->raw_seq->color_config.chroma_sample_position;

    if (s->raw_seq->initial_display_delay_present_flag)
        buf[3] = 0 << 5 |
                 s->raw_seq->initial_display_delay_present_flag << 4 |
                 s->raw_seq->initial_display_delay_minus_1[0];
    else
        buf[3] = 0x00;
    memcpy(buf + 4, s->seq_data_ref->data, s->seq_data_ref->size);
    data = CFDataCreate(kCFAllocatorDefault, buf, s->seq_data_ref->size + 4);
    av_free(buf);
    return data;
}*/

CMFormatDescriptionRef _Nullable createAV1FormatDescription(NSData *bitstreamData) CF_RETURNS_RETAINED {
    Dav1dSequenceHeader header;
    if (dav1d_parse_sequence_header(&header, bitstreamData.bytes, bitstreamData.length) != 0) {
        return nil;
    }
    
    return nil;
}

