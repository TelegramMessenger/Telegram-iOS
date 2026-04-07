#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <span>
#include "types.h"
#include "mux_surface.h"

using namespace subcodec;

#define MAX_COMPOSITE_MBS 256  // 4096 / 16 = 256 MBs per dimension

static void usage(const char* prog) {
    fprintf(stderr, "Usage: %s -o <output.h264> [--offset N] <input1.mbs> [input2.mbs ...]\n", prog);
    fprintf(stderr, "  --offset N  Stagger each sprite's start by N frames\n");
}

static int ceil_div_local(int a, int b) { return (a + b - 1) / b; }
static int ceil_sqrt_local(int n) {
    if (n <= 0) return 0;
    int s = (int)sqrt((double)n);
    while (s * s < n) s++;
    while (s > 1 && (s-1)*(s-1) >= n) s--;
    return s;
}

int main(int argc, char** argv) {
    // Parse flags
    const char* output_path = NULL;
    int frame_offset = 0;
    int first_input = -1;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: -o requires an argument\n");
                usage(argv[0]);
                return 1;
            }
            output_path = argv[++i];
        } else if (strcmp(argv[i], "--offset") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: --offset requires an argument\n");
                usage(argv[0]);
                return 1;
            }
            frame_offset = atoi(argv[++i]);
            if (frame_offset < 0) {
                fprintf(stderr, "Error: --offset must be non-negative\n");
                return 1;
            }
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "Error: unknown option '%s'\n", argv[i]);
            usage(argv[0]);
            return 1;
        } else {
            if (first_input < 0) first_input = i;
        }
    }

    if (!output_path || first_input < 0) {
        usage(argv[0]);
        return 1;
    }

    int num_inputs = 0;
    const char** input_paths = nullptr;
    {
        // Count inputs
        for (int i = first_input; i < argc; i++) {
            if (strcmp(argv[i], "-o") == 0) { i++; continue; }
            num_inputs++;
        }

        if (num_inputs == 0) {
            fprintf(stderr, "Error: no input files specified\n");
            usage(argv[0]);
            return 1;
        }

        input_paths = static_cast<const char**>(calloc((size_t)num_inputs, sizeof(const char*)));
        if (!input_paths) {
            fprintf(stderr, "Error: allocation failed\n");
            return 1;
        }

        int idx = 0;
        for (int i = first_input; i < argc; i++) {
            if (strcmp(argv[i], "-o") == 0) { i++; continue; }
            input_paths[idx++] = argv[i];
        }
    }

    // Read first sprite to get dimensions
    auto first_result = MbsSprite::load(input_paths[0]);
    if (!first_result) {
        fprintf(stderr, "Error: failed to read '%s'\n", input_paths[0]);
        free(input_paths);
        return 1;
    }

    uint16_t w = first_result->width_mbs;
    uint16_t h = first_result->height_mbs;
    uint16_t nf = first_result->num_frames;
    uint8_t sprite_qp = first_result->qp;
    int8_t qp_delta_idr = first_result->qp_delta_idr;
    int8_t qp_delta_p = first_result->qp_delta_p;

    // Validate all sprites match
    for (int i = 1; i < num_inputs; i++) {
        auto result = MbsSprite::load(input_paths[i]);
        if (!result) {
            fprintf(stderr, "Error: failed to read '%s'\n", input_paths[i]);
            free(input_paths);
            return 1;
        }
        if (result->width_mbs != w || result->height_mbs != h) {
            fprintf(stderr, "Error: resolution mismatch: '%s' is %dx%d MBs, "
                    "but '%s' is %dx%d MBs\n",
                    input_paths[0], w, h,
                    input_paths[i], result->width_mbs, result->height_mbs);
            free(input_paths);
            return 1;
        }
        if (result->num_frames != nf) {
            fprintf(stderr, "Error: frame count mismatch\n");
            free(input_paths);
            return 1;
        }
    }

    int content_w = ((int)w - 2) * 16;
    int content_h = ((int)h - 2) * 16;

    // Check composite dimensions
    constexpr int padding_mbs = 1;
    int cols = ceil_sqrt_local(num_inputs);
    int rows = ceil_div_local(num_inputs, cols);
    int sw = (int)w;
    int slot_w = sw * 2 - padding_mbs;
    int stride_x = slot_w - padding_mbs;
    int stride_y = (int)h - padding_mbs;
    int total_w = stride_x * cols + padding_mbs;
    int total_h = stride_y * rows + padding_mbs;

    if (total_w > MAX_COMPOSITE_MBS || total_h > MAX_COMPOSITE_MBS) {
        fprintf(stderr, "Error: composite resolution %dx%d pixels (%dx%d MBs) "
                "exceeds 4096x4096 limit\n",
                total_w * 16, total_h * 16, total_w, total_h);
        free(input_paths);
        return 1;
    }

    int total_frames;
    if (frame_offset == 0) {
        total_frames = (int)nf;
    } else {
        total_frames = (int)nf + (num_inputs - 1) * frame_offset;
    }

    FILE* out = fopen(output_path, "wb");
    if (!out) {
        fprintf(stderr, "Error: cannot open '%s' for writing\n", output_path);
        free(input_paths);
        return 1;
    }

    size_t encoded_size = 0;
    auto sink = [&](std::span<const uint8_t> data) {
        fwrite(data.data(), 1, data.size(), out);
        encoded_size += data.size();
    };

    MuxSurface::Params params;
    params.sprite_width = content_w;
    params.sprite_height = content_h;
    params.max_slots = num_inputs;
    params.qp = sprite_qp;
    params.qp_delta_idr = qp_delta_idr;
    params.qp_delta_p = qp_delta_p;

    auto create_result = MuxSurface::create(params, sink);
    if (!create_result) {
        fprintf(stderr, "Error: MuxSurface::create failed\n");
        fclose(out); free(input_paths);
        return 1;
    }
    auto& surface = *create_result;

    // Advance frames, adding sprites at their start frame
    int next_sprite = 0;
    for (int f = 0; f < total_frames; f++) {
        // Add all sprites whose start frame is f
        while (next_sprite < num_inputs &&
               (frame_offset == 0 ? f == 0 : f == next_sprite * frame_offset)) {
            auto slot = surface.add_sprite(input_paths[next_sprite]);
            if (!slot) {
                fprintf(stderr, "Error: failed to add sprite %d at frame %d\n",
                        next_sprite, f);
                fclose(out); free(input_paths);
                return 1;
            }
            next_sprite++;
        }

        auto result = surface.advance_frame(sink);
        if (!result) {
            fprintf(stderr, "Error: advance_frame failed at frame %d\n", f);
            fclose(out); free(input_paths);
            return 1;
        }
    }

    fclose(out);

    if (encoded_size == 0) {
        fprintf(stderr, "Error: muxing failed\n");
        free(input_paths);
        return 1;
    }

    // Print summary
    fprintf(stderr, "Sprites: %d (%dx%d MBs each, %d frames)\n",
            (int)num_inputs, w, h, (int)nf);
    if (frame_offset > 0) {
        fprintf(stderr, "Offset: %d frames between sprites (%d total frames)\n",
                frame_offset, total_frames + 1);
    }
    fprintf(stderr, "Grid: %dx%d MBs (%dx%d pixels)\n",
            total_w, total_h, total_w * 16, total_h * 16);
    fprintf(stderr, "Output: %zu bytes -> %s\n", encoded_size, output_path);

    free(input_paths);
    return 0;
}
