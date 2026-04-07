#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

#include "sprite_extractor.h"

using namespace subcodec;

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

typedef struct {
    AVFormatContext* fmt_ctx;
    AVCodecContext* dec_ctx;
    struct SwsContext* sws_ctx;
    int video_stream_idx;
    int target_size;
} decode_ctx_t;

static void cleanup_decoder(decode_ctx_t* ctx);

static int init_decoder(decode_ctx_t* ctx, const char* path, int target_size) {
    ctx->target_size = target_size;
    AVCodecParameters* par = NULL;
    const AVCodec* dec = NULL;

    if (avformat_open_input(&ctx->fmt_ctx, path, NULL, NULL) < 0) {
        fprintf(stderr, "Error: Could not open input file '%s'\n", path);
        return -1;
    }
    if (avformat_find_stream_info(ctx->fmt_ctx, NULL) < 0) {
        fprintf(stderr, "Error: Could not find stream information\n");
        goto fail;
    }

    ctx->video_stream_idx = -1;
    for (unsigned i = 0; i < ctx->fmt_ctx->nb_streams; i++) {
        if (ctx->fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            ctx->video_stream_idx = i;
            break;
        }
    }
    if (ctx->video_stream_idx < 0) {
        fprintf(stderr, "Error: No video stream found\n");
        goto fail;
    }

    par = ctx->fmt_ctx->streams[ctx->video_stream_idx]->codecpar;
    dec = avcodec_find_decoder(par->codec_id);
    if (!dec) { fprintf(stderr, "Error: Decoder not found\n"); goto fail; }

    ctx->dec_ctx = avcodec_alloc_context3(dec);
    if (!ctx->dec_ctx) { fprintf(stderr, "Error: Could not allocate decoder context\n"); goto fail; }
    if (avcodec_parameters_to_context(ctx->dec_ctx, par) < 0) { goto fail; }
    if (avcodec_open2(ctx->dec_ctx, dec, NULL) < 0) { goto fail; }

    ctx->sws_ctx = sws_getContext(
        ctx->dec_ctx->width, ctx->dec_ctx->height, ctx->dec_ctx->pix_fmt,
        target_size, target_size, AV_PIX_FMT_YUV420P,
        SWS_BILINEAR, NULL, NULL, NULL);
    if (!ctx->sws_ctx) { fprintf(stderr, "Error: Could not create scaler\n"); goto fail; }

    printf("  Source: %dx%d %s\n", ctx->dec_ctx->width, ctx->dec_ctx->height,
           av_get_pix_fmt_name(ctx->dec_ctx->pix_fmt));
    return 0;

fail:
    cleanup_decoder(ctx);
    return -1;
}

static int decode_frame(decode_ctx_t* ctx, AVFrame* out_frame) {
    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();
    if (!pkt || !frame) {
        av_packet_free(&pkt);
        av_frame_free(&frame);
        return -1;
    }
    int got_frame = 0;

    while (!got_frame && av_read_frame(ctx->fmt_ctx, pkt) >= 0) {
        if (pkt->stream_index != ctx->video_stream_idx) {
            av_packet_unref(pkt);
            continue;
        }
        int ret = avcodec_send_packet(ctx->dec_ctx, pkt);
        av_packet_unref(pkt);
        if (ret < 0) continue;

        ret = avcodec_receive_frame(ctx->dec_ctx, frame);
        if (ret == 0) {
            sws_scale(ctx->sws_ctx,
                      (const uint8_t* const*)frame->data, frame->linesize,
                      0, ctx->dec_ctx->height,
                      out_frame->data, out_frame->linesize);
            got_frame = 1;
        }
        av_frame_unref(frame);
    }

    if (!got_frame) {
        avcodec_send_packet(ctx->dec_ctx, NULL);
        while (avcodec_receive_frame(ctx->dec_ctx, frame) == 0) {
            sws_scale(ctx->sws_ctx,
                      (const uint8_t* const*)frame->data, frame->linesize,
                      0, ctx->dec_ctx->height,
                      out_frame->data, out_frame->linesize);
            av_frame_unref(frame);
            got_frame = 1;
            break;
        }
    }

    av_frame_free(&frame);
    av_packet_free(&pkt);
    return got_frame ? 0 : -1;
}

static void cleanup_decoder(decode_ctx_t* ctx) {
    if (ctx->sws_ctx) sws_freeContext(ctx->sws_ctx);
    if (ctx->dec_ctx) avcodec_free_context(&ctx->dec_ctx);
    if (ctx->fmt_ctx) avformat_close_input(&ctx->fmt_ctx);
}

static void print_usage(const char* prog) {
    fprintf(stderr, "Usage: %s --size <N> [--offset <N>] [--count <N>] <input.mp4> <output.mbs>\n", prog);
    fprintf(stderr, "\n");
    fprintf(stderr, "Extract sprite frames from video and save as macroblock dump.\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  --size N     Target sprite size in pixels (must be multiple of 16)\n");
    fprintf(stderr, "  --offset N   Skip the first N frames (default: 0)\n");
    fprintf(stderr, "  --count N    Extract at most N frames (default: all)\n");
    fprintf(stderr, "  --qp N       Quantization parameter 0-51 (default: 26)\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "The input video will be resized to NxN and processed.\n");
}

int main(int argc, char* argv[]) {
    if (argc < 5) {
        print_usage(argv[0]);
        return 1;
    }

    int size = 0;
    int offset = 0;
    int count = 0;
    int qp = 26;
    const char* input_path = NULL;
    const char* output_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--size") == 0 && i + 1 < argc) {
            size = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--offset") == 0 && i + 1 < argc) {
            offset = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--count") == 0 && i + 1 < argc) {
            count = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--qp") == 0 && i + 1 < argc) {
            qp = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (!input_path) {
            input_path = argv[i];
        } else if (!output_path) {
            output_path = argv[i];
        }
    }

    if (size <= 0) {
        fprintf(stderr, "Error: --size must be a positive integer\n");
        print_usage(argv[0]);
        return 1;
    }
    if (size % 16 != 0) {
        fprintf(stderr, "Error: --size must be a multiple of 16 (macroblock size)\n");
        return 1;
    }
    if (size > 4096) {
        fprintf(stderr, "Error: --size exceeds maximum (4096 pixels)\n");
        return 1;
    }
    if (!input_path || !output_path) {
        fprintf(stderr, "Error: input and output paths required\n");
        print_usage(argv[0]);
        return 1;
    }
    if (offset < 0) {
        fprintf(stderr, "Error: --offset must be non-negative\n");
        return 1;
    }
    if (count < 0) {
        fprintf(stderr, "Error: --count must be non-negative\n");
        return 1;
    }
    if (qp < 0 || qp > 51) {
        fprintf(stderr, "Error: --qp must be between 0 and 51\n");
        return 1;
    }

    printf("Sprite extraction parameters:\n");
    printf("  Input:  %s\n", input_path);
    printf("  Output: %s\n", output_path);
    printf("  Size:   %dx%d pixels (%dx%d macroblocks)\n",
           size, size, size/16, size/16);
    printf("  QP:     %d\n", qp);

    decode_ctx_t dec;
    memset(&dec, 0, sizeof(dec));
    if (init_decoder(&dec, input_path, size) < 0) return 1;

    printf("  Encoding with OpenH264 (%dx%d content)...\n", size, size);

    auto ext_result = SpriteExtractor::create(
        {.sprite_size = size, .qp = qp}, output_path);
    if (!ext_result) {
        fprintf(stderr, "Error: SpriteExtractor::create failed\n");
        cleanup_decoder(&dec);
        return 1;
    }
    auto& ext = *ext_result;

    // Skip offset frames
    AVFrame* yuv_frame = av_frame_alloc();
    if (!yuv_frame) { cleanup_decoder(&dec); return 1; }
    yuv_frame->format = AV_PIX_FMT_YUV420P;
    yuv_frame->width = size;
    yuv_frame->height = size;
    if (av_frame_get_buffer(yuv_frame, 0) < 0) {
        av_frame_free(&yuv_frame); cleanup_decoder(&dec); return 1;
    }

    if (offset > 0) {
        printf("  Skipping %d frames...\n", offset);
        for (int i = 0; i < offset; i++) {
            if (decode_frame(&dec, yuv_frame) < 0) {
                fprintf(stderr, "Error: Video has fewer than %d frames (only %d available)\n",
                        offset, i);
                av_frame_free(&yuv_frame); cleanup_decoder(&dec); return 1;
            }
        }
    }

    int frame_count = 0;
    int max_frames = (count > 0) ? count : 1024;
    if (max_frames > 1024) max_frames = 1024;

    while (frame_count < max_frames) {
        if (decode_frame(&dec, yuv_frame) < 0) break;

        // No alpha source from video: pass opaque (all-255) alpha
        static std::vector<uint8_t> opaque_alpha;
        int luma_w = yuv_frame->width;
        int luma_h = yuv_frame->height;
        if ((int)opaque_alpha.size() < luma_w * luma_h)
            opaque_alpha.assign(luma_w * luma_h, 255);
        auto result = ext.add_frame(
            yuv_frame->data[0], yuv_frame->linesize[0],
            yuv_frame->data[1], yuv_frame->linesize[1],
            yuv_frame->data[2], yuv_frame->linesize[2],
            opaque_alpha.data(), luma_w);

        if (!result) {
            fprintf(stderr, "Error: add_frame failed at frame %d\n", frame_count);
            av_frame_free(&yuv_frame); cleanup_decoder(&dec); return 1;
        }
        frame_count++;
    }

    av_frame_free(&yuv_frame);
    cleanup_decoder(&dec);

    if (frame_count == 0) {
        fprintf(stderr, "Error: No frames decoded\n");
        return 1;
    }

    printf("  Encoded %d frames (offset=%d)\n", frame_count, offset);

    auto fin = ext.finalize();
    if (!fin) {
        fprintf(stderr, "Error: finalize failed\n");
        return 1;
    }

    printf("  Wrote %d frames to %s (.mbs format)\n", frame_count, output_path);
    return 0;
}
