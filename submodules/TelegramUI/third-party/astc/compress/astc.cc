#include <sys/time.h>

#include "astc.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "compress_texture.h"
#include "constants.h"
#include "bgra.h"
#include "compressed.h"

int64_t usecs_passed(const timeval& t1, const timeval& t2) {
  return (t2.tv_sec - t1.tv_sec) * 1000000 + (t2.tv_usec - t1.tv_usec);
}

void compress_astc(const BgraImage& image, CompressedImage* compressed) {
  compress_texture(reinterpret_cast<uint8_t*>(image.buffer), compressed->buffer, static_cast<int>(image.width), static_cast<int>(image.height));
}

/*int main(int argc, const char** argv) {
  if (argc < 3 || argc > 4) {
    fprintf(stderr, "Usage: %s [-q | --quiet] INPUT OUTPUT\n", argv[0]);
    return 1;
  }

  bool quiet = false;
  const char* input = nullptr;
  const char* output = nullptr;

  int i = 1;
  if (strcmp(argv[i], "-q") == 0 || strcmp(argv[i], "--quiet") == 0) {
    quiet = true;
    ++i;
  }
  input = argv[i];
  output = argv[i + 1];

  try {
    BgraImage image = ReadTGAFile(input);

    if (image.width % BLOCK_WIDTH != 0 || image.height % BLOCK_HEIGHT != 0) {
      fprintf(stderr,
              "Error: image size (%ldx%ld) not a multiple of block size "
              "(%ldx%ld)\n",
              image.width, image.height, BLOCK_WIDTH, BLOCK_HEIGHT);
      return 1;
    }

    CompressedImage compressed(image.width, image.height, BLOCK_WIDTH,
                               BLOCK_HEIGHT, BLOCK_BYTES);

    if (quiet) {
      compress_astc(image, &compressed);
    } else {
      timeval t1;
      gettimeofday(&t1, NULL);
      compress_astc(image, &compressed);
      timeval t2;
      gettimeofday(&t2, NULL);
      fprintf(stdout, "Time passed: %ldus\n", usecs_passed(t1, t2));
    }

    WriteASTCFile(compressed, output);
  } catch (const char* err) {
    fprintf(stderr, "Error: %s\n", err);
    return 1;
  }

  return 0;
}*/
