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

    struct SwrContext *swr_ctx = NULL;

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

    const AVCodec *aac_codec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!aac_codec) {
        fprintf(stderr, "Could not find AAC encoder\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    AVCodecContext *aac_codec_context = avcodec_alloc_context3(aac_codec);
    if (!aac_codec_context) {
        fprintf(stderr, "Could not allocate AAC codec context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    const AVCodec *opus_decoder = avcodec_find_decoder(AV_CODEC_ID_OPUS);
    if (!opus_decoder) {
        fprintf(stderr, "Could not find Opus decoder\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    AVCodecContext *opus_decoder_context = avcodec_alloc_context3(opus_decoder);
    if (!opus_decoder_context) {
        fprintf(stderr, "Could not allocate Opus decoder context\n");
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
            out_stream = avformat_new_stream(output_format_context, aac_codec);
            if (!out_stream) {
                fprintf(stderr, "Failed allocating output stream\n");
                ret = AVERROR_UNKNOWN;
                goto end;
            }

            // Set the codec parameters for the AAC encoder
            aac_codec_context->sample_rate = in_codecpar->sample_rate;
            aac_codec_context->channel_layout = in_codecpar->channel_layout ? in_codecpar->channel_layout : AV_CH_LAYOUT_STEREO;
            aac_codec_context->channels = av_get_channel_layout_nb_channels(aac_codec_context->channel_layout);
            aac_codec_context->sample_fmt = aac_codec->sample_fmts ? aac_codec->sample_fmts[0] : AV_SAMPLE_FMT_FLTP;  // Use the first supported sample format
            aac_codec_context->bit_rate = 128000;  // Set a default bitrate, you can adjust this as needed
            //aac_codec_context->time_base = (AVRational){1, 90000};

            ret = avcodec_open2(aac_codec_context, aac_codec, NULL);
            if (ret < 0) {
                fprintf(stderr, "Could not open AAC encoder\n");
                goto end;
            }

            ret = avcodec_parameters_from_context(out_stream->codecpar, aac_codec_context);
            if (ret < 0) {
                fprintf(stderr, "Failed initializing audio output stream\n");
                goto end;
            }

            out_stream->time_base = (AVRational){1, 90000};
            out_stream->duration = av_rescale_q(in_stream->duration, in_stream->time_base, out_stream->time_base);

            // Set up the Opus decoder context
            ret = avcodec_parameters_to_context(opus_decoder_context, in_codecpar);
            if (ret < 0) {
                fprintf(stderr, "Could not copy codec parameters to decoder context\n");
                goto end;
            }
            if (opus_decoder_context->channel_layout == 0) {
                opus_decoder_context->channel_layout = av_get_default_channel_layout(opus_decoder_context->channels);
            }
            ret = avcodec_open2(opus_decoder_context, opus_decoder, NULL);
            if (ret < 0) {
                fprintf(stderr, "Could not open Opus decoder\n");
                goto end;
            }
            
            // Reset the channel layout if it was unset before opening the codec
            if (opus_decoder_context->channel_layout == 0) {
                opus_decoder_context->channel_layout = av_get_default_channel_layout(opus_decoder_context->channels);
            }
        }
    }

    // Set up the resampling context
    swr_ctx = swr_alloc_set_opts(NULL,
                                 aac_codec_context->channel_layout, aac_codec_context->sample_fmt, aac_codec_context->sample_rate,
                                 opus_decoder_context->channel_layout, opus_decoder_context->sample_fmt, opus_decoder_context->sample_rate,
                                 0, NULL);
    if (!swr_ctx) {
        fprintf(stderr, "Could not allocate resampler context\n");
        ret = AVERROR(ENOMEM);
        goto end;
    }

    if ((ret = swr_init(swr_ctx)) < 0) {
        fprintf(stderr, "Failed to initialize the resampling context\n");
        goto end;
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
            ret = avcodec_send_packet(opus_decoder_context, &packet);
            if (ret < 0) {
                fprintf(stderr, "Error sending packet to decoder\n");
                av_packet_unref(&packet);
                continue;
            }

            AVFrame *frame = av_frame_alloc();
            ret = avcodec_receive_frame(opus_decoder_context, frame);
            if (ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF) {
                fprintf(stderr, "Error receiving frame from decoder\n");
                av_frame_free(&frame);
                av_packet_unref(&packet);
                continue;
            }

            if (ret >= 0) {
                frame->pts = frame->best_effort_timestamp;

                AVFrame *resampled_frame = av_frame_alloc();
                resampled_frame->channel_layout = aac_codec_context->channel_layout;
                resampled_frame->sample_rate = aac_codec_context->sample_rate;
                resampled_frame->format = aac_codec_context->sample_fmt;
                resampled_frame->nb_samples = aac_codec_context->frame_size;

                if ((ret = av_frame_get_buffer(resampled_frame, 0)) < 0) {
                    fprintf(stderr, "Could not allocate resampled frame buffer\n");
                    av_frame_free(&resampled_frame);
                    av_frame_free(&frame);
                    av_packet_unref(&packet);
                    continue;
                }
                
                memset(resampled_frame->data[0], 0, resampled_frame->nb_samples * 2 * 2);
                //arc4random_buf(resampled_frame->data[0], resampled_frame->nb_samples * 2 * 2);
                //memset(frame->data[0], 0, frame->nb_samples * 2 * 2);

                if ((ret = swr_convert(swr_ctx,
                                       resampled_frame->data, resampled_frame->nb_samples,
                                       (const uint8_t **)frame->data, frame->nb_samples)) < 0) {
                    fprintf(stderr, "Error while converting\n");
                    av_frame_free(&resampled_frame);
                    av_frame_free(&frame);
                    av_packet_unref(&packet);
                    continue;
                }

                resampled_frame->pts = av_rescale_q(frame->pts, opus_decoder_context->time_base, aac_codec_context->time_base);

                ret = avcodec_send_frame(aac_codec_context, resampled_frame);
                if (ret < 0) {
                    fprintf(stderr, "Error sending frame to encoder\n");
                    av_frame_free(&resampled_frame);
                    av_frame_free(&frame);
                    av_packet_unref(&packet);
                    continue;
                }

                AVPacket out_packet;
                av_init_packet(&out_packet);
                out_packet.data = NULL;
                out_packet.size = 0;

                ret = avcodec_receive_packet(aac_codec_context, &out_packet);
                if (ret >= 0) {
                    out_packet.pts = av_rescale_q_rnd(packet.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
                    out_packet.dts = av_rescale_q_rnd(packet.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
                    out_packet.pts += (int64_t)(offsetSeconds * out_stream->time_base.den);
                    out_packet.dts += (int64_t)(offsetSeconds * out_stream->time_base.den);
                    out_packet.duration = av_rescale_q(out_packet.duration, aac_codec_context->time_base, out_stream->time_base);
                    out_packet.stream_index = packet.stream_index;

                    ret = av_interleaved_write_frame(output_format_context, &out_packet);
                    if (ret < 0) {
                        fprintf(stderr, "Error muxing packet\n");
                        av_packet_unref(&out_packet);
                        av_frame_free(&resampled_frame);
                        av_frame_free(&frame);
                        av_packet_unref(&packet);
                        break;
                    }
                    av_packet_unref(&out_packet);
                }
                av_frame_free(&resampled_frame);
                av_frame_free(&frame);
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
    avformat_close_input(&input_format_context);
    if (output_format_context && !(output_format_context->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&output_format_context->pb);
    }
    avformat_free_context(output_format_context);
    avcodec_free_context(&aac_codec_context);
    avcodec_free_context(&opus_decoder_context);
    av_freep(&streams_list);
    if (swr_ctx) {
        swr_free(&swr_ctx);
    }
    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return false;
    }

    printf("Remuxed video into %s\n", outPath.UTF8String);
    return true;
}

@end
