#include "bgra.h"

#include <fstream>

struct TGAHeader {
  uint8_t id_length;
  uint8_t color_map_type;
  uint8_t image_type;

  uint8_t first_entry_index[2];
  uint8_t color_map_length[2];
  uint8_t color_map_entry_size;

  uint8_t origin_x[2], origin_y[2];
  uint8_t width[2], height[2];
  uint8_t pixel_depth;
  uint8_t image_descriptor;
};
