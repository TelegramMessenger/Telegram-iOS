#import <FFMpegBinding/FFMpegRemuxer.h>

#import <FFMpegBinding/FFMpegAVIOContext.h>

#include "libavutil/timestamp.h"
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"

#define MOV_TIMESCALE 1000

@interface FFMpegRemuxerContext : NSObject {
    @public
    int _fd;
    int64_t _offset;
}

@end

@implementation FFMpegRemuxerContext

- (instancetype)initWithFileName:(NSString *)fileName {
    self = [super init];
    if (self != nil) {
        _fd = open(fileName.UTF8String, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    }
    return self;
}

- (void)dealloc {
    if (_fd > 0) {
        close(_fd);
    }
}

@end

static int readPacketImpl(void * _Nullable opaque, uint8_t * _Nullable buffer, int length) {
    FFMpegRemuxerContext *context = (__bridge FFMpegRemuxerContext *)opaque;
    context->_offset += length;
    printf("read %lld bytes (offset is now %lld)\n", length, context->_offset);
    return read(context->_fd, buffer, length);
}

static int writePacketImpl(void * _Nullable opaque, uint8_t * _Nullable buffer, int length) {
    FFMpegRemuxerContext *context = (__bridge FFMpegRemuxerContext *)opaque;
    context->_offset += length;
    printf("write %lld bytes (offset is now %lld)\n", length, context->_offset);
    return write(context->_fd, buffer, length);
}

static int64_t seekImpl(void * _Nullable opaque, int64_t offset, int whence) {
    FFMpegRemuxerContext *context = (__bridge FFMpegRemuxerContext *)opaque;
    printf("seek to %lld\n", offset);
    if (whence == FFMPEG_AVSEEK_SIZE) {
        return 0;
    } else {
        context->_offset = offset;
        return lseek(context->_fd, offset, SEEK_SET);
    }
}

@implementation FFMpegRemuxer

+ (bool)remux:(NSString * _Nonnull)path to:(NSString * _Nonnull)outPath {
    AVFormatContext *input_format_context = NULL, *output_format_context = NULL;
    AVPacket packet;
    const char *in_filename, *out_filename;
    int ret, i;
    int stream_index = 0;
    int *streams_list = NULL;
    int number_of_streams = 0;
    int fragmented_mp4_options = 1;
    
    in_filename  = [path UTF8String];
    out_filename = [outPath UTF8String];
    
    //FFMpegRemuxerContext *outputContext = [[FFMpegRemuxerContext alloc] initWithFileName:outPath];
    //FFMpegAVIOContext *outputIoContext = [[FFMpegAVIOContext alloc] initWithBufferSize:1024 opaqueContext:(__bridge void *)outputContext readPacket:&readPacketImpl writePacket:&writePacketImpl seek:&seekImpl];
    
    if ((ret = avformat_open_input(&input_format_context, in_filename, av_find_input_format("mov"), NULL)) < 0) {
        fprintf(stderr, "Could not open input file '%s'", in_filename);
        goto end;
    }
    if ((ret = avformat_find_stream_info(input_format_context, NULL)) < 0) {
        fprintf(stderr, "Failed to retrieve input stream information");
        goto end;
    }
    
    avformat_alloc_output_context2(&output_format_context, NULL, NULL, out_filename);
    //output_format_context = avformat_alloc_context();
    //output_format_context->pb = outputIoContext.impl;
    //output_format_context->flags |= AVFMT_FLAG_CUSTOM_IO;
    //output_format_context->oformat = av_guess_format("mp4", NULL, NULL);
    
    if (!output_format_context) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    
    number_of_streams = input_format_context->nb_streams;
    streams_list = av_mallocz_array(number_of_streams, sizeof(*streams_list));
    
    if (!streams_list) {
        ret = AVERROR(ENOMEM);
        goto end;
    }
    
    int64_t maxTrackLength = 0;
    
    for (i = 0; i < input_format_context->nb_streams; i++) {
        AVStream *out_stream;
        AVStream *in_stream = input_format_context->streams[i];
        
        AVCodecParameters *in_codecpar = in_stream->codecpar;
        if (in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
            in_codecpar->codec_type != AVMEDIA_TYPE_VIDEO &&
            in_codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            streams_list[i] = -1;
            continue;
        }
        
        if (in_stream->time_base.den != 0) {
            int64_t trackLength = av_rescale_rnd(in_stream->duration, MOV_TIMESCALE, (int64_t)in_stream->time_base.den, AV_ROUND_UP);
            maxTrackLength = MAX(trackLength, maxTrackLength);
            /*int64_t max_track_len_temp = av_rescale_rnd(mov->tracks[i].track_duration,
                                                        MOV_TIMESCALE,
                                                        mov->tracks[i].timescale,
                                                        AV_ROUND_UP);*/
            
        }
        
        streams_list[i] = stream_index++;
        out_stream = avformat_new_stream(output_format_context, NULL);
        out_stream->time_base = in_stream->time_base;
        out_stream->duration = in_stream->duration;
        if (!out_stream) {
            fprintf(stderr, "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        ret = avcodec_parameters_copy(out_stream->codecpar, in_codecpar);
        if (ret < 0) {
            fprintf(stderr, "Failed to copy codec parameters\n");
            goto end;
        }
    }
    // https://ffmpeg.org/doxygen/trunk/group__lavf__misc.html#gae2645941f2dc779c307eb6314fd39f10
    //av_dump_format(output_format_context, 0, out_filename, 1);
    
    // unless it's a no file (we'll talk later about that) write to the disk (FLAG_WRITE)
    // but basically it's a way to save the file to a buffer so you can store it
    // wherever you want.
    if (!(output_format_context->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&output_format_context->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open output file '%s'", out_filename);
            goto end;
        }
    }
    AVDictionary* opts = NULL;
    
    if (fragmented_mp4_options) {
        // https://developer.mozilla.org/en-US/docs/Web/API/Media_Source_Extensions_API/Transcoding_assets_for_MSE
        av_dict_set(&opts, "movflags", "dash+faststart+global_sidx+skip_trailer", 0);
        if (maxTrackLength > 0) {
            //av_dict_set_int(&opts, "custom_maxTrackLength", maxTrackLength, 0);
        }
    }
    // https://ffmpeg.org/doxygen/trunk/group__lavf__encoding.html#ga18b7b10bb5b94c4842de18166bc677cb
    ret = avformat_write_header(output_format_context, &opts);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file\n");
        goto end;
    }
    while (1) {
        AVStream *in_stream, *out_stream;
        ret = av_read_frame(input_format_context, &packet);
        if (ret < 0)
            break;
        in_stream  = input_format_context->streams[packet.stream_index];
        if (packet.stream_index >= number_of_streams || streams_list[packet.stream_index] < 0) {
            av_packet_unref(&packet);
            continue;
        }
        packet.stream_index = streams_list[packet.stream_index];
        out_stream = output_format_context->streams[packet.stream_index];
        /* copy packet */
        packet.pts = av_rescale_q_rnd(packet.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        packet.dts = av_rescale_q_rnd(packet.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        packet.duration = av_rescale_q(packet.duration, in_stream->time_base, out_stream->time_base);
        // https://ffmpeg.org/doxygen/trunk/structAVPacket.html#ab5793d8195cf4789dfb3913b7a693903
        packet.pos = -1;
        
        //https://ffmpeg.org/doxygen/trunk/group__lavf__encoding.html#ga37352ed2c63493c38219d935e71db6c1
        ret = av_interleaved_write_frame(output_format_context, &packet);
        if (ret < 0) {
            fprintf(stderr, "Error muxing packet\n");
            break;
        }
        av_packet_unref(&packet);
    }
    //https://ffmpeg.org/doxygen/trunk/group__lavf__encoding.html#ga7f14007e7dc8f481f054b21614dfec13
    av_write_trailer(output_format_context);
end:
    avformat_close_input(&input_format_context);
    /* close output */
    if (output_format_context && !(output_format_context->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&output_format_context->pb);
    }
    avformat_free_context(output_format_context);
    av_freep(&streams_list);
    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return false;
    }
    
    printf("Remuxed video into %s\n", outPath.UTF8String);
    
    return true;
}

@end
