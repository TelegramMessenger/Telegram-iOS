#ifndef IMAGE_COMPRESSED_H_
#define IMAGE_COMPRESSED_H_

#include <cassert>
#include <cstddef>
#include <cstdint>

class CompressedImage {
 public:
  CompressedImage(size_t width,
                  size_t height,
                  size_t block_width,
                  size_t block_height,
                  size_t bytes_per_block_)
      : xdim(block_width),
        ydim(block_height),
        xsize(width),
        ysize(height),
        xblocks(width / xdim),
        yblocks(height / ydim),
        block_count(yblocks * xblocks),
        bytes_per_block(bytes_per_block_),
        buffer_size(block_count * bytes_per_block),
        buffer(new uint8_t[buffer_size]) {
    assert(width % xdim == 0);
    assert(height % ydim == 0);
  }

  CompressedImage(CompressedImage&& other)
      : xdim(other.xdim),
        ydim(other.ydim),
        xsize(other.xsize),
        ysize(other.ysize),
        xblocks(other.xblocks),
        yblocks(other.yblocks),
        block_count(other.block_count),
        bytes_per_block(other.bytes_per_block),
        buffer_size(other.buffer_size),
        buffer(other.buffer) {
    other.buffer = nullptr;
  }

  CompressedImage(const CompressedImage&) = delete;
  CompressedImage& operator=(const CompressedImage&) = delete;

  ~CompressedImage() { delete[] buffer; }

  size_t xdim, ydim;
  size_t xsize, ysize;
  size_t xblocks, yblocks;

  size_t block_count;

  size_t bytes_per_block;
  size_t buffer_size;
  uint8_t* buffer;
};

void WriteASTCFile(const CompressedImage&, const char* file_path);

#endif  // IMAGE_COMPRESSED_H_
