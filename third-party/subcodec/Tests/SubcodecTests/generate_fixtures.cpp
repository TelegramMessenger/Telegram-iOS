// Tests/SubcodecTests/generate_fixtures.cpp
#include <cstdio>
#include <cstdint>
#include <cstdlib>

#define SPRITE_PX  64
#define NUM_FRAMES 160

static void generate_sprite_frame(uint8_t* y_plane, uint8_t* cb_plane, uint8_t* cr_plane,
                                  int sprite_id, int frame) {
    uint8_t cb_val = (uint8_t)(128 + sprite_id * 20);
    uint8_t cr_val = (uint8_t)(128 - sprite_id * 20);

    for (int py = 0; py < SPRITE_PX; py++) {
        for (int px = 0; px < SPRITE_PX; px++) {
            uint8_t y_val;
            switch (sprite_id) {
                case 0: y_val = (uint8_t)((px + frame * 8) % 256); break;
                case 1: y_val = (uint8_t)((py + frame * 8) % 256); break;
                case 2: y_val = (uint8_t)((px + py + frame * 8) % 256); break;
                default: y_val = 128; break;
            }
            y_plane[py * SPRITE_PX + px] = y_val;
        }
    }

    for (int cy = 0; cy < SPRITE_PX / 2; cy++) {
        for (int cx = 0; cx < SPRITE_PX / 2; cx++) {
            cb_plane[cy * (SPRITE_PX / 2) + cx] = cb_val;
            cr_plane[cy * (SPRITE_PX / 2) + cx] = cr_val;
        }
    }
}

int main(int argc, char** argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <output_dir>\n", argv[0]);
        return 1;
    }

    const char* dir = argv[1];
    const int y_size = SPRITE_PX * SPRITE_PX;
    const int c_size = (SPRITE_PX / 2) * (SPRITE_PX / 2);

    uint8_t y[y_size], cb[c_size], cr[c_size];

    for (int s = 0; s < 3; s++) {
        char path[512];
        snprintf(path, sizeof(path), "%s/sprite%d.yuv", dir, s);
        FILE* f = fopen(path, "wb");
        if (!f) { perror(path); return 1; }

        for (int frame = 0; frame < NUM_FRAMES; frame++) {
            generate_sprite_frame(y, cb, cr, s, frame);
            fwrite(y, 1, y_size, f);
            fwrite(cb, 1, c_size, f);
            fwrite(cr, 1, c_size, f);
        }

        fclose(f);
        printf("Wrote %s (%d frames, %d bytes)\n", path, NUM_FRAMES,
               NUM_FRAMES * (y_size + c_size + c_size));
    }
    return 0;
}
