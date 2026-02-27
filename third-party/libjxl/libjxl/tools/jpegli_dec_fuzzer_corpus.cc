// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#if defined(_WIN32) || defined(_WIN64)
#include "third_party/dirent.h"
#else
#include <dirent.h>
#include <unistd.h>
#endif

#include <algorithm>
#include <iostream>
#include <mutex>
#include <random>
#include <vector>

#include "lib/jpegli/encode.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/random.h"
#include "tools/file_io.h"
#include "tools/thread_pool_internal.h"

namespace {

const size_t kMaxWidth = 50000;
const size_t kMaxHeight = 50000;
const size_t kMaxPixels = 20 * (1 << 20);  // 20 MP

std::mutex stderr_mutex;

std::vector<uint8_t> GetSomeTestImage(size_t xsize, size_t ysize,
                                      size_t num_channels, uint16_t seed) {
  // Cause more significant image difference for successive seeds.
  jxl::Rng generator(seed);

  // Returns random integer in interval [0, max_value)
  auto rng = [&generator](size_t max_value) -> size_t {
    return generator.UniformU(0, max_value);
  };

  // Dark background gradient color
  uint16_t r0 = rng(32768);
  uint16_t g0 = rng(32768);
  uint16_t b0 = rng(32768);
  uint16_t r1 = rng(32768);
  uint16_t g1 = rng(32768);
  uint16_t b1 = rng(32768);

  // Circle with different color
  size_t circle_x = rng(xsize);
  size_t circle_y = rng(ysize);
  size_t circle_r = rng(std::min(xsize, ysize));

  // Rectangle with random noise
  size_t rect_x0 = rng(xsize);
  size_t rect_y0 = rng(ysize);
  size_t rect_x1 = rng(xsize);
  size_t rect_y1 = rng(ysize);
  if (rect_x1 < rect_x0) std::swap(rect_x0, rect_y1);
  if (rect_y1 < rect_y0) std::swap(rect_y0, rect_y1);

  size_t num_pixels = xsize * ysize;
  std::vector<uint8_t> pixels(num_pixels * num_channels);
  // Create pixel content to test.
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      uint16_t r = r0 * (ysize - y - 1) / ysize + r1 * y / ysize;
      uint16_t g = g0 * (ysize - y - 1) / ysize + g1 * y / ysize;
      uint16_t b = b0 * (ysize - y - 1) / ysize + b1 * y / ysize;
      // put some shape in there for visual debugging
      if ((x - circle_x) * (x - circle_x) + (y - circle_y) * (y - circle_y) <
          circle_r * circle_r) {
        r = (65535 - x * y) ^ seed;
        g = (x << 8) + y + seed;
        b = (y << 8) + x * seed;
      } else if (x > rect_x0 && x < rect_x1 && y > rect_y0 && y < rect_y1) {
        r = rng(65536);
        g = rng(65536);
        b = rng(65536);
      }
      size_t i = (y * xsize + x) * num_channels;
      pixels[i + 0] = (r >> 8);
      if (num_channels == 3) {
        pixels[i + 1] = (g >> 8);
        pixels[i + 2] = (b >> 8);
      }
    }
  }
  return pixels;
}

// ImageSpec needs to be a packed struct to allow us to use the raw memory of
// the struct for hashing to create a consistent id.
#pragma pack(push, 1)
struct ImageSpec {
  bool Validate() const {
    if (width > kMaxWidth || height > kMaxHeight ||
        width * height > kMaxPixels) {
      return false;
    }
    return true;
  }

  friend std::ostream& operator<<(std::ostream& o, const ImageSpec& spec) {
    o << "ImageSpec<"
      << "size=" << spec.width << "x" << spec.height
      << " * chan=" << spec.num_channels << " q=" << spec.quality
      << " p=" << spec.progressive_level << " r=" << spec.restart_interval
      << ">";
    return o;
  }

  void SpecHash(uint8_t hash[16]) const {
    const uint8_t* from = reinterpret_cast<const uint8_t*>(this);
    std::seed_seq hasher(from, from + sizeof(*this));
    uint32_t* to = reinterpret_cast<uint32_t*>(hash);
    hasher.generate(to, to + 4);
  }

  uint32_t width = 256;
  uint32_t height = 256;
  uint32_t num_channels = 3;
  uint32_t quality = 90;
  uint32_t sampling = 0x11111111;
  uint32_t progressive_level = 2;
  uint32_t restart_interval = 0;
  uint32_t fraction = 100;
  // The seed for the PRNG.
  uint32_t seed = 7777;
};
#pragma pack(pop)
static_assert(sizeof(ImageSpec) % 4 == 0, "Add padding to ImageSpec.");

bool EncodeWithJpegli(const ImageSpec& spec, const std::vector<uint8_t>& pixels,
                      std::vector<uint8_t>* compressed) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    jpeg_error_mgr jerr;
    jmp_buf env;
    cinfo.err = jpegli_std_error(&jerr);
    if (setjmp(env)) {
      return false;
    }
    cinfo.client_data = reinterpret_cast<void*>(&env);
    cinfo.err->error_exit = [](j_common_ptr cinfo) {
      (*cinfo->err->output_message)(cinfo);
      jmp_buf* env = reinterpret_cast<jmp_buf*>(cinfo->client_data);
      jpegli_destroy(cinfo);
      longjmp(*env, 1);
    };
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = spec.width;
    cinfo.image_height = spec.height;
    cinfo.input_components = spec.num_channels;
    cinfo.in_color_space = spec.num_channels == 1 ? JCS_GRAYSCALE : JCS_RGB;
    jpegli_set_defaults(&cinfo);
    jpegli_set_quality(&cinfo, spec.quality, TRUE);
    uint32_t sampling = spec.sampling;
    for (int c = 0; c < cinfo.num_components; ++c) {
      cinfo.comp_info[c].h_samp_factor = sampling & 0xf;
      cinfo.comp_info[c].v_samp_factor = (sampling >> 4) & 0xf;
      sampling >>= 8;
    }
    jpegli_set_progressive_level(&cinfo, spec.progressive_level);
    cinfo.restart_interval = spec.restart_interval;
    jpegli_start_compress(&cinfo, TRUE);
    size_t stride = cinfo.image_width * cinfo.input_components;
    std::vector<uint8_t> row_bytes(stride);
    for (size_t y = 0; y < cinfo.image_height; ++y) {
      memcpy(&row_bytes[0], &pixels[y * stride], stride);
      JSAMPROW row[] = {row_bytes.data()};
      jpegli_write_scanlines(&cinfo, row, 1);
    }
    jpegli_finish_compress(&cinfo);
    return true;
  };
  bool success = try_catch_block();
  jpegli_destroy_compress(&cinfo);
  if (success) {
    buffer_size = buffer_size * spec.fraction / 100;
    compressed->assign(buffer, buffer + buffer_size);
  }
  if (buffer) std::free(buffer);
  return success;
}

bool GenerateFile(const char* output_dir, const ImageSpec& spec,
                  bool regenerate, bool quiet) {
  // Compute a checksum of the ImageSpec to name the file. This is just to keep
  // the output of this program repeatable.
  uint8_t checksum[16];
  spec.SpecHash(checksum);
  std::string hash_str(sizeof(checksum) * 2, ' ');
  static const char* hex_chars = "0123456789abcdef";
  for (size_t i = 0; i < sizeof(checksum); i++) {
    hash_str[2 * i] = hex_chars[checksum[i] >> 4];
    hash_str[2 * i + 1] = hex_chars[checksum[i] % 0x0f];
  }
  std::string output_fn = std::string(output_dir) + "/" + hash_str + ".jpg";

  // Don't regenerate files if they already exist on disk to speed-up
  // consecutive calls when --regenerate is not used.
  struct stat st;
  if (!regenerate && stat(output_fn.c_str(), &st) == 0 && S_ISREG(st.st_mode)) {
    return true;
  }

  if (!quiet) {
    std::unique_lock<std::mutex> lock(stderr_mutex);
    std::cerr << "Generating " << spec << " as " << hash_str << std::endl;
  }

  uint8_t hash[16];
  spec.SpecHash(hash);
  std::mt19937 mt(spec.seed);

  std::vector<uint8_t> pixels =
      GetSomeTestImage(spec.width, spec.height, spec.num_channels, spec.seed);
  std::vector<uint8_t> compressed;
  JXL_CHECK(EncodeWithJpegli(spec, pixels, &compressed));

  // Append 4 bytes with the flags used by jpegli_dec_fuzzer to select the
  // decoding output.
  std::uniform_int_distribution<> dis256(0, 255);
  for (size_t i = 0; i < 4; ++i) {
    compressed.push_back(dis256(mt));
  }

  if (!jpegxl::tools::WriteFile(output_fn, compressed)) {
    return false;
  }
  if (!quiet) {
    std::unique_lock<std::mutex> lock(stderr_mutex);
    std::cerr << "Stored " << output_fn << " size: " << compressed.size()
              << std::endl;
  }

  return true;
}

void Usage() {
  fprintf(stderr,
          "Use: fuzzer_corpus [-r] [-q] [-j THREADS] [output_dir]\n"
          "\n"
          "  -r Regenerate files if already exist.\n"
          "  -q Be quiet.\n"
          "  -j THREADS Number of parallel jobs to run.\n");
}

}  // namespace

int main(int argc, const char** argv) {
  const char* dest_dir = nullptr;
  bool regenerate = false;
  bool quiet = false;
  size_t num_threads = std::thread::hardware_concurrency();
  for (int optind = 1; optind < argc;) {
    if (!strcmp(argv[optind], "-r")) {
      regenerate = true;
      optind++;
    } else if (!strcmp(argv[optind], "-q")) {
      quiet = true;
      optind++;
    } else if (!strcmp(argv[optind], "-j")) {
      optind++;
      if (optind < argc) {
        num_threads = atoi(argv[optind++]);
      } else {
        fprintf(stderr, "-j needs an argument value.\n");
        Usage();
        return 1;
      }
    } else if (dest_dir == nullptr) {
      dest_dir = argv[optind++];
    } else {
      fprintf(stderr, "Unknown parameter: \"%s\".\n", argv[optind]);
      Usage();
      return 1;
    }
  }
  if (!dest_dir) {
    dest_dir = "corpus";
  }

  struct stat st;
  memset(&st, 0, sizeof(st));
  if (stat(dest_dir, &st) != 0 || !S_ISDIR(st.st_mode)) {
    fprintf(stderr, "Output path \"%s\" is not a directory.\n", dest_dir);
    Usage();
    return 1;
  }

  std::mt19937 mt(77777);

  std::vector<std::pair<uint32_t, uint32_t>> image_sizes = {
      {8, 8},     {32, 32},   {128, 128}, {10000, 1}, {10000, 2}, {1, 10000},
      {2, 10000}, {555, 256}, {257, 513}, {512, 265}, {264, 520},
  };
  std::vector<uint32_t> sampling_ratios = {
      0x11111111,  // 444
      0x11111112,  // 422
      0x11111121,  // 440
      0x11111122,  // 420
      0x11222211,  // luma subsampling
  };

  ImageSpec spec;
  std::vector<ImageSpec> specs;
  for (auto img_size : image_sizes) {
    spec.width = img_size.first;
    spec.height = img_size.second;
    for (uint32_t num_channels : {1, 3}) {
      spec.num_channels = num_channels;
      for (uint32_t sampling : sampling_ratios) {
        spec.sampling = sampling;
        if (num_channels == 1 && sampling != 0x11111111) continue;
        for (uint32_t restart : {0, 1, 1024}) {
          spec.restart_interval = restart;
          for (uint32_t prog_level : {0, 1, 2}) {
            spec.progressive_level = prog_level;
            for (uint32_t quality : {10, 90, 100}) {
              spec.quality = quality;
              for (uint32_t fraction : {10, 70, 100}) {
                spec.fraction = fraction;
                spec.seed = mt() % 777777;
                if (!spec.Validate()) {
                  if (!quiet) {
                    std::cerr << "Skipping " << spec << std::endl;
                  }
                } else {
                  specs.push_back(spec);
                }
              }
            }
          }
        }
      }
    }
  }

  jpegxl::tools::ThreadPoolInternal pool{num_threads};
  const auto generate = [&specs, dest_dir, regenerate, quiet](
                            const uint32_t task, size_t /* thread */) {
    const ImageSpec& spec = specs[task];
    GenerateFile(dest_dir, spec, regenerate, quiet);
  };
  if (!RunOnPool(&pool, 0, specs.size(), jxl::ThreadPool::NoInit, generate,
                 "FuzzerCorpus")) {
    std::cerr << "Error generating fuzzer corpus" << std::endl;
    return 1;
  }
  std::cerr << "Finished generating fuzzer corpus" << std::endl;
  return 0;
}
