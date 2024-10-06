#import <FFMpegBinding/FFMpegLiveMuxer.h>
#import <FFMpegBinding/FFMpegAVIOContext.h>

#include "libavutil/timestamp.h"
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libswresample/swresample.h"

#define MOV_TIMESCALE 1000

@implementation FFMpegLiveMuxer

+ (bool)remux:(NSString * _Nonnull)path to:(NSString * _Nonnull)outPath offsetSeconds:(double)offsetSeconds {
    AVFormatContext *input_format_context = NULL, *output_format_context = NULL;
    AVPacket packet;
    const char *in_filename, *out_filename;
    int ret, i;
    int stream_index = 0;
    int *streams_list = NULL;
    int number_of_streams = 0;

    in_filename  = [path UTF8String];
    out_filename = [outPath UTF8String];

    if ((ret = avformat_open_input(&input_format_context, in_filename, av_find_input_format("mp4"), NULL)) < 0) {
        fprintf(stderr, "Could not open input file '%s'\n", in_filename);
        goto end;
    }
    if ((ret = avformat_find_stream_info(input_format_context, NULL)) < 0) {
        fprintf(stderr, "Failed to retrieve input stream information\n");
        goto end;
    }

    avformat_alloc_output_context2(&output_format_context, NULL, "mpegts", out_filename);

    if (!output_format_context) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    number_of_streams = input_format_context->nb_streams;
    streams_list = av_malloc_array(number_of_streams, sizeof(*streams_list));

    if (!streams_list) {
        ret = AVERROR(ENOMEM);
        goto end;
    }

    for (i = 0; i < input_format_context->nb_streams; i++) {
        AVStream *out_stream;
        AVStream *in_stream = input_format_context->streams[i];
        AVCodecParameters *in_codecpar = in_stream->codecpar;

        if (in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO && in_codecpar->codec_type != AVMEDIA_TYPE_VIDEO) {
            streams_list[i] = -1;
            continue;
        }

        streams_list[i] = stream_index++;

        if (in_codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            out_stream = avformat_new_stream(output_format_context, NULL);
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
            out_stream->time_base = in_stream->time_base;
            out_stream->duration = in_stream->duration;
        } else if (in_codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            if (in_codecpar->codec_id != AV_CODEC_ID_AAC) {
                streams_list[i] = -1;
                continue;
            }
            
            out_stream = avformat_new_stream(output_format_context, NULL);
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
            out_stream->time_base = in_stream->time_base;
            out_stream->duration = in_stream->duration;
        }
    }

    if (!(output_format_context->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&output_format_context->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open output file '%s'\n", out_filename);
            goto end;
        }
    }

    AVDictionary* opts = NULL;
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

        in_stream = input_format_context->streams[packet.stream_index];
        if (packet.stream_index >= number_of_streams || streams_list[packet.stream_index] < 0) {
            av_packet_unref(&packet);
            continue;
        }

        packet.stream_index = streams_list[packet.stream_index];
        out_stream = output_format_context->streams[packet.stream_index];

        if (in_stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            packet.pts = av_rescale_q_rnd(packet.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
            packet.dts = av_rescale_q_rnd(packet.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
            packet.pts += (int64_t)(offsetSeconds * out_stream->time_base.den);
            packet.dts += (int64_t)(offsetSeconds * out_stream->time_base.den);
            packet.duration = av_rescale_q(packet.duration, in_stream->time_base, out_stream->time_base);
            packet.pos = -1;

            ret = av_interleaved_write_frame(output_format_context, &packet);
            if (ret < 0) {
                fprintf(stderr, "Error muxing packet\n");
                av_packet_unref(&packet);
                break;
            }
        } else {
            packet.pts = av_rescale_q_rnd(packet.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
            packet.dts = av_rescale_q_rnd(packet.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
            packet.pts += (int64_t)(offsetSeconds * out_stream->time_base.den);
            packet.dts += (int64_t)(offsetSeconds * out_stream->time_base.den);
            packet.duration = av_rescale_q(packet.duration, in_stream->time_base, out_stream->time_base);
            packet.pos = -1;

            ret = av_interleaved_write_frame(output_format_context, &packet);
            if (ret < 0) {
                fprintf(stderr, "Error muxing packet\n");
                av_packet_unref(&packet);
                break;
            }
        }

        av_packet_unref(&packet);
    }

    av_write_trailer(output_format_context);

end:
    if (input_format_context) {
        avformat_close_input(&input_format_context);
    }
    if (output_format_context && !(output_format_context->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&output_format_context->pb);
    }
    if (output_format_context) {
        avformat_free_context(output_format_context);
    }
    if (streams_list) {
        av_freep(&streams_list);
    }
    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return false;
    }

    //printf("Remuxed video into %s\n", outPath.UTF8String);
    return true;
}

@end
