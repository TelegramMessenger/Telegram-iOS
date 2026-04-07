#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <filesystem>
#include <span>
#include <chrono>
#include <algorithm>
#include <numeric>
#include <os/signpost.h>

#include "sprite_extractor.h"
#include "types.h"
#include "mux_surface.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

struct Args {
    std::string input;         // --input <video_path>
    std::string mbs_path;      // --mbs-path <path>
    int sprite_size = 64;      // --sprite-size <pixels>
    int sprite_count = 1764;   // --sprite-count <N>
    int frame_count = 160;     // --frame-count <F>
    int loops = 50;            // --loops <N> (repeats frame_count N times)
    int qp = 26;               // --qp <N>
    bool profile_resize = false;   // --profile-resize
    int resize_from = 420;         // --resize-from <N> (active sprites before resize)
    int resize_to = 882;           // --resize-to <N> (target max_slots after resize)
    int resize_loops = 10;         // --resize-loops <N> (repeat resize for averaging)
};

static void print_usage(const char* prog) {
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  %s --input <video> [options]\n", prog);
    fprintf(stderr, "  %s --mbs-path <file.mbs> [options]\n", prog);
    fprintf(stderr, "\nOptions:\n");
    fprintf(stderr, "  --sprite-size  <N>  Content sprite size in pixels (default: 64, must be multiple of 16)\n");
    fprintf(stderr, "  --sprite-count <N>  Number of sprites in mux grid (default: 100)\n");
    fprintf(stderr, "  --frame-count  <N>  Number of frames per loop (default: 160)\n");
    fprintf(stderr, "  --loops        <N>  Number of mux loops (default: 50, total frames = frame-count * loops)\n");
    fprintf(stderr, "  --qp           <N>  Quantization parameter 0-51 (default: 26)\n");
    fprintf(stderr, "  --profile-resize    Profile MuxSurface::resize instead of advance_frame\n");
    fprintf(stderr, "  --resize-from  <N>  Active sprites before resize (default: 420)\n");
    fprintf(stderr, "  --resize-to    <N>  Target max_slots after resize (default: 882)\n");
    fprintf(stderr, "  --resize-loops <N>  Repeat resize for averaging (default: 10)\n");
}

static bool parse_args(int argc, char* argv[], Args& args) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--input") == 0 && i + 1 < argc) {
            args.input = argv[++i];
        } else if (strcmp(argv[i], "--mbs-path") == 0 && i + 1 < argc) {
            args.mbs_path = argv[++i];
        } else if (strcmp(argv[i], "--sprite-size") == 0 && i + 1 < argc) {
            args.sprite_size = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--sprite-count") == 0 && i + 1 < argc) {
            args.sprite_count = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--frame-count") == 0 && i + 1 < argc) {
            args.frame_count = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--loops") == 0 && i + 1 < argc) {
            args.loops = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--qp") == 0 && i + 1 < argc) {
            args.qp = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--profile-resize") == 0) {
            args.profile_resize = true;
        } else if (strcmp(argv[i], "--resize-from") == 0 && i + 1 < argc) {
            args.resize_from = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--resize-to") == 0 && i + 1 < argc) {
            args.resize_to = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--resize-loops") == 0 && i + 1 < argc) {
            args.resize_loops = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return false;
        } else {
            fprintf(stderr, "Unknown argument: %s\n", argv[i]);
            print_usage(argv[0]);
            return false;
        }
    }

    if (args.input.empty() && args.mbs_path.empty()) {
        fprintf(stderr, "Error: must specify --input or --mbs-path\n");
        print_usage(argv[0]);
        return false;
    }
    if (!args.input.empty() && !args.mbs_path.empty()) {
        fprintf(stderr, "Error: specify --input or --mbs-path, not both\n");
        return false;
    }
    if (args.sprite_size <= 0 || args.sprite_size % 16 != 0) {
        fprintf(stderr, "Error: --sprite-size must be a positive multiple of 16\n");
        return false;
    }
    if (args.sprite_count <= 0) {
        fprintf(stderr, "Error: --sprite-count must be positive\n");
        return false;
    }
    if (args.frame_count <= 0) {
        fprintf(stderr, "Error: --frame-count must be positive\n");
        return false;
    }
    if (args.loops <= 0) {
        fprintf(stderr, "Error: --loops must be positive\n");
        return false;
    }
    if (args.qp < 0 || args.qp > 51) {
        fprintf(stderr, "Error: --qp must be between 0 and 51\n");
        return false;
    }
    return true;
}

// Extract video to .mbs file using SpriteExtractor. Returns temp path on success.
static std::string extract_mbs(const std::string& input_path, int sprite_size, int qp) {
    std::string tmp_path = "/tmp/bench_profile_sprite.mbs";

    AVFormatContext* fmt_ctx = nullptr;
    if (avformat_open_input(&fmt_ctx, input_path.c_str(), nullptr, nullptr) < 0) {
        fprintf(stderr, "Error: could not open '%s'\n", input_path.c_str());
        return {};
    }
    if (avformat_find_stream_info(fmt_ctx, nullptr) < 0) {
        avformat_close_input(&fmt_ctx);
        return {};
    }

    int video_idx = -1;
    for (unsigned i = 0; i < fmt_ctx->nb_streams; i++) {
        if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_idx = (int)i;
            break;
        }
    }
    if (video_idx < 0) {
        fprintf(stderr, "Error: no video stream\n");
        avformat_close_input(&fmt_ctx);
        return {};
    }

    auto* par = fmt_ctx->streams[video_idx]->codecpar;
    const AVCodec* dec = avcodec_find_decoder(par->codec_id);
    AVCodecContext* dec_ctx = avcodec_alloc_context3(dec);
    avcodec_parameters_to_context(dec_ctx, par);
    avcodec_open2(dec_ctx, dec, nullptr);

    auto* sws = sws_getContext(
        dec_ctx->width, dec_ctx->height, dec_ctx->pix_fmt,
        sprite_size, sprite_size, AV_PIX_FMT_YUV420P,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    auto ext_result = subcodec::SpriteExtractor::create(
        {.sprite_size = sprite_size, .qp = qp}, tmp_path);
    if (!ext_result) {
        fprintf(stderr, "Error: SpriteExtractor::create failed\n");
        sws_freeContext(sws); avcodec_free_context(&dec_ctx); avformat_close_input(&fmt_ctx);
        return {};
    }
    auto& ext = *ext_result;

    AVFrame* yuv = av_frame_alloc();
    yuv->format = AV_PIX_FMT_YUV420P;
    yuv->width = sprite_size;
    yuv->height = sprite_size;
    av_frame_get_buffer(yuv, 0);

    AVPacket* pkt = av_packet_alloc();
    AVFrame* raw = av_frame_alloc();
    std::vector<uint8_t> alpha(sprite_size * sprite_size, 255);
    int frame_count = 0;

    auto try_receive = [&]() {
        while (avcodec_receive_frame(dec_ctx, raw) == 0) {
            sws_scale(sws, (const uint8_t* const*)raw->data, raw->linesize,
                      0, dec_ctx->height, yuv->data, yuv->linesize);
            av_frame_unref(raw);
            ext.add_frame(
                yuv->data[0], yuv->linesize[0],
                yuv->data[1], yuv->linesize[1],
                yuv->data[2], yuv->linesize[2],
                alpha.data(), sprite_size);
            frame_count++;
        }
    };

    while (av_read_frame(fmt_ctx, pkt) >= 0) {
        if (pkt->stream_index == video_idx)
            avcodec_send_packet(dec_ctx, pkt);
        av_packet_unref(pkt);
        try_receive();
    }
    avcodec_send_packet(dec_ctx, nullptr);
    try_receive();

    av_frame_free(&raw);
    av_packet_free(&pkt);
    av_frame_free(&yuv);
    sws_freeContext(sws);
    avcodec_free_context(&dec_ctx);
    avformat_close_input(&fmt_ctx);

    if (frame_count == 0) {
        fprintf(stderr, "Error: no frames decoded\n");
        return {};
    }

    auto fin = ext.finalize();
    if (!fin) {
        fprintf(stderr, "Error: finalize failed\n");
        return {};
    }

    printf("  Extracted %d frames to %s\n", frame_count, tmp_path.c_str());
    return tmp_path;
}

int main(int argc, char* argv[]) {
    Args args;
    if (!parse_args(argc, argv, args)) return 1;

    printf("bench_profile configuration:\n");
    if (!args.input.empty())
        printf("  input:        %s\n", args.input.c_str());
    else
        printf("  mbs-path:     %s\n", args.mbs_path.c_str());
    printf("  sprite-size:  %d\n", args.sprite_size);
    printf("  sprite-count: %d\n", args.sprite_count);
    printf("  frame-count:  %d\n", args.frame_count);
    printf("  loops:        %d (total frames: %d)\n", args.loops, args.frame_count * args.loops);
    printf("  qp:           %d\n", args.qp);

    // Resolve .mbs path
    std::string mbs_path = args.mbs_path;
    if (!args.input.empty()) {
        printf("Extracting sprite from video...\n");
        mbs_path = extract_mbs(args.input, args.sprite_size, args.qp);
        if (mbs_path.empty()) return 1;
    }

    // Verify .mbs file loads
    auto test_load = subcodec::MbsSprite::load(mbs_path);
    if (!test_load) {
        fprintf(stderr, "Error: failed to load %s\n", mbs_path.c_str());
        return 1;
    }
    printf("  Loaded .mbs: %dx%d MBs, %d frames\n",
           test_load->width_mbs, test_load->height_mbs, test_load->num_frames);

    os_log_t log = os_log_create("com.subcodec.bench", "profile");

    // Determine content dimensions from loaded .mbs metadata
    // MBS stores padded dimensions (width_mbs, height_mbs). Padding is always 1 MB per side.
    int content_w = (test_load->width_mbs - 2) * 16;
    int content_h = (test_load->height_mbs - 2) * 16;

    size_t total_bytes = 0;
    auto sink = [&total_bytes](std::span<const uint8_t> data) {
        total_bytes += data.size();
    };

    if (args.profile_resize) {
        /* ---- Profiled: MuxSurface::resize ---- */
        printf("\n=== MuxSurface::resize (%d active -> %d slots, %d loops) ===\n",
               args.resize_from, args.resize_to, args.resize_loops);

        std::vector<double> times_ms;
        times_ms.reserve(args.resize_loops);

        for (int loop = 0; loop < args.resize_loops; loop++) {
            /* Fresh MuxSurface each loop */
            subcodec::MuxSurface::Params mux_params;
            mux_params.sprite_width = content_w;
            mux_params.sprite_height = content_h;
            mux_params.max_slots = args.resize_from;
            mux_params.qp = test_load->qp;
            mux_params.qp_delta_idr = test_load->qp_delta_idr;
            mux_params.qp_delta_p = test_load->qp_delta_p;

            auto mux_result = subcodec::MuxSurface::create(mux_params, sink);
            if (!mux_result) {
                fprintf(stderr, "Error: MuxSurface::create failed\n");
                return 1;
            }
            auto& mux = *mux_result;

            /* Load and add sprites */
            for (int i = 0; i < args.resize_from; i++) {
                auto sp = subcodec::MbsSprite::load(mbs_path);
                if (!sp) { fprintf(stderr, "Error: load failed\n"); return 1; }
                auto slot = mux.add_sprite(std::move(*sp));
                if (!slot) { fprintf(stderr, "Error: add_sprite failed\n"); return 1; }
            }

            /* Advance one frame so we have valid state */
            auto adv = mux.advance_frame(sink);
            if (!adv) { fprintf(stderr, "Error: advance_frame failed\n"); return 1; }

            /* Build synthetic decoded YUV (black + neutral chroma) */
            int w_px = mux.width_mbs() * 16;
            int h_px = mux.height_mbs() * 16;
            int cw = w_px / 2, ch = h_px / 2;
            std::vector<uint8_t> dec_y(w_px * h_px, 0);
            std::vector<uint8_t> dec_cb(cw * ch, 128);
            std::vector<uint8_t> dec_cr(cw * ch, 128);

            /* Timed resize */
            os_signpost_id_t rid = os_signpost_id_generate(log);
            os_signpost_interval_begin(log, rid, "resize", "loop=%d from=%d to=%d",
                                       loop, args.resize_from, args.resize_to);
            auto t0 = std::chrono::high_resolution_clock::now();

            auto result = mux.resize(
                args.resize_to,
                dec_y, dec_cb, dec_cr,
                w_px, h_px, w_px, cw, cw, sink);

            auto t1 = std::chrono::high_resolution_clock::now();
            os_signpost_interval_end(log, rid, "resize");

            if (!result) {
                fprintf(stderr, "Error: resize failed at loop %d\n", loop);
                return 1;
            }

            double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
            times_ms.push_back(ms);
            printf("  [%d] resize %d -> %d slots: %.2f ms (%zu regions)\n",
                   loop, args.resize_from, args.resize_to, ms,
                   result->regions.size());
        }

        std::sort(times_ms.begin(), times_ms.end());
        double sum = std::accumulate(times_ms.begin(), times_ms.end(), 0.0);
        printf("\n  Results (%d runs):\n", args.resize_loops);
        printf("    p50:  %.2f ms\n", times_ms[times_ms.size() / 2]);
        printf("    avg:  %.2f ms\n", sum / times_ms.size());
        printf("    min:  %.2f ms\n", times_ms.front());
        printf("    max:  %.2f ms\n", times_ms.back());

    } else {
        /* ---- Profiled: MuxSurface::advance_frame ---- */
        printf("\n=== MuxSurface (%d sprites, %d frames) ===\n",
               args.sprite_count, args.frame_count);

        subcodec::MuxSurface::Params mux_params;
        mux_params.sprite_width = content_w;
        mux_params.sprite_height = content_h;
        mux_params.max_slots = args.sprite_count;
        mux_params.qp = test_load->qp;
        mux_params.qp_delta_idr = test_load->qp_delta_idr;
        mux_params.qp_delta_p = test_load->qp_delta_p;

        auto mux_result = subcodec::MuxSurface::create(mux_params, sink);
        if (!mux_result) {
            fprintf(stderr, "Error: MuxSurface::create failed\n");
            return 1;
        }
        auto& mux = *mux_result;

        printf("  Grid: %dx%d MBs (%dx%d pixels)\n",
               mux.width_mbs(), mux.height_mbs(),
               mux.width_mbs() * 16, mux.height_mbs() * 16);

        // Pre-load all sprites into memory (unprofiled setup)
        printf("  Loading %d sprites into memory...\n", args.sprite_count);
        std::vector<subcodec::MbsSprite> sprites;
        sprites.reserve(args.sprite_count);
        for (int i = 0; i < args.sprite_count; i++) {
            auto sp = subcodec::MbsSprite::load(mbs_path);
            if (!sp) {
                fprintf(stderr, "Error: load failed at %d\n", i);
                return 1;
            }
            sprites.push_back(std::move(*sp));
        }

        // Add sprites to mux surface (unprofiled setup)
        printf("  Adding sprites to surface...\n");
        for (int i = 0; i < args.sprite_count; i++) {
            auto slot = mux.add_sprite(std::move(sprites[i]));
            if (!slot) {
                fprintf(stderr, "Error: add_sprite failed at %d\n", i);
                return 1;
            }
        }
        sprites.clear();
        printf("  Added %d sprites\n", args.sprite_count);

        // Advance frames (primary profiling target)
        int total_frames = args.frame_count * args.loops;
        printf("  Advancing %d frames (%d x %d loops)...\n",
               total_frames, args.frame_count, args.loops);
        for (int f = 0; f < total_frames; f++) {
            os_signpost_id_t fid = os_signpost_id_generate(log);
            os_signpost_interval_begin(log, fid, "advance_frame", "frame=%d", f);

            auto result = mux.advance_frame(sink);

            os_signpost_interval_end(log, fid, "advance_frame");

            if (!result) {
                fprintf(stderr, "Error: advance_frame failed at frame %d\n", f);
                return 1;
            }
        }

        printf("  Total output: %zu bytes (%.1f MB)\n",
               total_bytes, total_bytes / (1024.0 * 1024.0));
    }

    printf("\nDone.\n");
    return 0;
}
