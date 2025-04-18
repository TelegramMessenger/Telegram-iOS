// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "plugins/gimp/file-jxl-load.h"

#include <jxl/decode.h>
#include <jxl/decode_cxx.h>

#define _PROFILE_ORIGIN_ JXL_COLOR_PROFILE_TARGET_ORIGINAL
#define _PROFILE_TARGET_ JXL_COLOR_PROFILE_TARGET_DATA
#define LOAD_PROC "file-jxl-load"

namespace jxl {

bool SetJpegXlOutBuffer(
    std::unique_ptr<JxlDecoderStruct, JxlDecoderDestroyStruct> *dec,
    JxlPixelFormat *format, size_t *buffer_size, gpointer *pixels_buffer_1) {
  if (JXL_DEC_SUCCESS !=
      JxlDecoderImageOutBufferSize(dec->get(), format, buffer_size)) {
    g_printerr(LOAD_PROC " Error: JxlDecoderImageOutBufferSize failed\n");
    return false;
  }
  *pixels_buffer_1 = g_malloc(*buffer_size);
  if (JXL_DEC_SUCCESS != JxlDecoderSetImageOutBuffer(dec->get(), format,
                                                     *pixels_buffer_1,
                                                     *buffer_size)) {
    g_printerr(LOAD_PROC " Error: JxlDecoderSetImageOutBuffer failed\n");
    return false;
  }
  return true;
}

bool LoadJpegXlImage(const gchar *const filename, gint32 *const image_id) {
  bool stop_processing = false;
  JxlDecoderStatus status = JXL_DEC_NEED_MORE_INPUT;
  std::vector<uint8_t> icc_profile;
  GimpColorProfile *profile_icc = nullptr;
  GimpColorProfile *profile_int = nullptr;
  bool is_linear = false;
  unsigned long xsize = 0, ysize = 0;
  long crop_x0 = 0, crop_y0 = 0;
  size_t layer_idx = 0;
  uint32_t frame_duration = 0;
  double tps_denom = 1.f, tps_numer = 1.f;

  gint32 layer;

  gpointer pixels_buffer_1 = nullptr;
  gpointer pixels_buffer_2 = nullptr;
  size_t buffer_size = 0;

  GimpImageBaseType image_type = GIMP_RGB;
  GimpImageType layer_type = GIMP_RGB_IMAGE;
  GimpPrecision precision = GIMP_PRECISION_U16_GAMMA;
  JxlBasicInfo info = {};
  JxlPixelFormat format = {};
  JxlAnimationHeader animation = {};
  JxlBlendMode blend_mode = JXL_BLEND_BLEND;
  char *frame_name = nullptr;  // will be realloced
  size_t frame_name_len = 0;

  format.num_channels = 4;
  format.data_type = JXL_TYPE_FLOAT;
  format.endianness = JXL_NATIVE_ENDIAN;
  format.align = 0;

  bool is_gray = false;

  JpegXlGimpProgress gimp_load_progress(
      ("Opening JPEG XL file:" + std::string(filename)).c_str());
  gimp_load_progress.update();

  // read file
  std::ifstream instream(filename, std::ios::in | std::ios::binary);
  std::vector<uint8_t> compressed((std::istreambuf_iterator<char>(instream)),
                                  std::istreambuf_iterator<char>());
  instream.close();

  gimp_load_progress.update();

  // multi-threaded parallel runner.
  auto runner = JxlResizableParallelRunnerMake(nullptr);

  auto dec = JxlDecoderMake(nullptr);
  if (JXL_DEC_SUCCESS !=
      JxlDecoderSubscribeEvents(
          dec.get(), JXL_DEC_BASIC_INFO | JXL_DEC_COLOR_ENCODING |
                         JXL_DEC_FULL_IMAGE | JXL_DEC_FRAME_PROGRESSION |
                         JXL_DEC_FRAME)) {
    g_printerr(LOAD_PROC " Error: JxlDecoderSubscribeEvents failed\n");
    return false;
  }

  if (JXL_DEC_SUCCESS != JxlDecoderSetParallelRunner(dec.get(),
                                                     JxlResizableParallelRunner,
                                                     runner.get())) {
    g_printerr(LOAD_PROC " Error: JxlDecoderSetParallelRunner failed\n");
    return false;
  }
  // TODO: make this work with coalescing set to false, while handling frames
  // with duration 0 and references to earlier frames correctly.
  if (JXL_DEC_SUCCESS != JxlDecoderSetCoalescing(dec.get(), JXL_TRUE)) {
    g_printerr(LOAD_PROC " Error: JxlDecoderSetCoalescing failed\n");
    return false;
  }

  // grand decode loop...
  JxlDecoderSetInput(dec.get(), compressed.data(), compressed.size());

  if (JXL_DEC_SUCCESS != JxlDecoderSetProgressiveDetail(
                             dec.get(), JxlProgressiveDetail::kPasses)) {
    g_printerr(LOAD_PROC " Error: JxlDecoderSetProgressiveDetail failed\n");
    return false;
  }

  while (true) {
    gimp_load_progress.update();

    if (!stop_processing) status = JxlDecoderProcessInput(dec.get());

    if (status == JXL_DEC_BASIC_INFO) {
      if (JXL_DEC_SUCCESS != JxlDecoderGetBasicInfo(dec.get(), &info)) {
        g_printerr(LOAD_PROC " Error: JxlDecoderGetBasicInfo failed\n");
        return false;
      }

      xsize = info.xsize;
      ysize = info.ysize;
      if (info.have_animation) {
        animation = info.animation;
        tps_denom = animation.tps_denominator;
        tps_numer = animation.tps_numerator;
      }

      JxlResizableParallelRunnerSetThreads(
          runner.get(), JxlResizableParallelRunnerSuggestThreads(xsize, ysize));
    } else if (status == JXL_DEC_COLOR_ENCODING) {
      // check for ICC profile
      size_t icc_size = 0;
      JxlColorEncoding color_encoding;
      if (JXL_DEC_SUCCESS !=
          JxlDecoderGetColorAsEncodedProfile(dec.get(), _PROFILE_ORIGIN_,
                                             &color_encoding)) {
        // Attempt to load ICC profile when no internal color encoding
        if (JXL_DEC_SUCCESS != JxlDecoderGetICCProfileSize(
                                   dec.get(), _PROFILE_ORIGIN_, &icc_size)) {
          g_printerr(LOAD_PROC
                     " Warning: JxlDecoderGetICCProfileSize failed\n");
        }

        if (icc_size > 0) {
          icc_profile.resize(icc_size);
          if (JXL_DEC_SUCCESS != JxlDecoderGetColorAsICCProfile(
                                     dec.get(), _PROFILE_ORIGIN_,
                                     icc_profile.data(), icc_profile.size())) {
            g_printerr(LOAD_PROC
                       " Warning: JxlDecoderGetColorAsICCProfile failed\n");
          }

          profile_icc = gimp_color_profile_new_from_icc_profile(
              icc_profile.data(), icc_profile.size(), nullptr);

          if (profile_icc) {
            is_linear = gimp_color_profile_is_linear(profile_icc);
            g_printerr(LOAD_PROC " Info: Color profile is_linear = %d\n",
                       is_linear);
          } else {
            g_printerr(LOAD_PROC " Warning: Failed to read ICC profile.\n");
          }
        } else {
          g_printerr(LOAD_PROC " Warning: Empty ICC data.\n");
        }
      }

      // Internal color profile detection...
      if (JXL_DEC_SUCCESS ==
          JxlDecoderGetColorAsEncodedProfile(dec.get(), _PROFILE_TARGET_,
                                             &color_encoding)) {
        g_printerr(LOAD_PROC " Info: Internal color encoding detected.\n");

        // figure out linearity of internal profile
        switch (color_encoding.transfer_function) {
          case JXL_TRANSFER_FUNCTION_LINEAR:
            is_linear = true;
            break;

          case JXL_TRANSFER_FUNCTION_709:
          case JXL_TRANSFER_FUNCTION_PQ:
          case JXL_TRANSFER_FUNCTION_HLG:
          case JXL_TRANSFER_FUNCTION_GAMMA:
          case JXL_TRANSFER_FUNCTION_DCI:
          case JXL_TRANSFER_FUNCTION_SRGB:
            is_linear = false;
            break;

          case JXL_TRANSFER_FUNCTION_UNKNOWN:
          default:
            if (profile_icc) {
              g_printerr(LOAD_PROC
                         " Info: Unknown transfer function.  "
                         "ICC profile is present.");
            } else {
              g_printerr(LOAD_PROC
                         " Info: Unknown transfer function.  "
                         "No ICC profile present.");
            }
            break;
        }

        switch (color_encoding.color_space) {
          case JXL_COLOR_SPACE_RGB:
            if (color_encoding.white_point == JXL_WHITE_POINT_D65 &&
                color_encoding.primaries == JXL_PRIMARIES_SRGB) {
              if (is_linear) {
                profile_int = gimp_color_profile_new_rgb_srgb_linear();
              } else {
                profile_int = gimp_color_profile_new_rgb_srgb();
              }
            } else if (!is_linear &&
                       color_encoding.white_point == JXL_WHITE_POINT_D65 &&
                       (color_encoding.primaries_green_xy[0] == 0.2100 ||
                        color_encoding.primaries_green_xy[1] == 0.7100)) {
              // Probably Adobe RGB
              profile_int = gimp_color_profile_new_rgb_adobe();
            } else if (profile_icc) {
              g_printerr(LOAD_PROC
                         " Info: Unknown RGB colorspace.  "
                         "Using ICC profile.\n");
            } else {
              g_printerr(LOAD_PROC
                         " Info: Unknown RGB colorspace.  "
                         "Treating as sRGB.\n");
              if (is_linear) {
                profile_int = gimp_color_profile_new_rgb_srgb_linear();
              } else {
                profile_int = gimp_color_profile_new_rgb_srgb();
              }
            }
            break;

          case JXL_COLOR_SPACE_GRAY:
            is_gray = true;
            if (!profile_icc ||
                color_encoding.white_point == JXL_WHITE_POINT_D65) {
              if (is_linear) {
                profile_int = gimp_color_profile_new_d65_gray_linear();
              } else {
                profile_int = gimp_color_profile_new_d65_gray_srgb_trc();
              }
            }
            break;
          case JXL_COLOR_SPACE_XYB:
          case JXL_COLOR_SPACE_UNKNOWN:
          default:
            if (profile_icc) {
              g_printerr(LOAD_PROC
                         " Info: Unknown colorspace.  Using ICC profile.\n");
            } else {
              g_error(
                  LOAD_PROC
                  " Warning: Unknown colorspace. Treating as sRGB profile.\n");

              if (is_linear) {
                profile_int = gimp_color_profile_new_rgb_srgb_linear();
              } else {
                profile_int = gimp_color_profile_new_rgb_srgb();
              }
            }
            break;
        }
      }

      // set pixel format
      if (info.num_color_channels > 1) {
        if (info.alpha_bits == 0) {
          image_type = GIMP_RGB;
          layer_type = GIMP_RGB_IMAGE;
          format.num_channels = info.num_color_channels;
        } else {
          image_type = GIMP_RGB;
          layer_type = GIMP_RGBA_IMAGE;
          format.num_channels = info.num_color_channels + 1;
        }
      } else if (info.num_color_channels == 1) {
        if (info.alpha_bits == 0) {
          image_type = GIMP_GRAY;
          layer_type = GIMP_GRAY_IMAGE;
          format.num_channels = info.num_color_channels;
        } else {
          image_type = GIMP_GRAY;
          layer_type = GIMP_GRAYA_IMAGE;
          format.num_channels = info.num_color_channels + 1;
        }
      }

      // Set image bit depth and linearity
      if (info.bits_per_sample <= 8) {
        if (is_linear) {
          precision = GIMP_PRECISION_U8_LINEAR;
        } else {
          precision = GIMP_PRECISION_U8_GAMMA;
        }
      } else if (info.bits_per_sample <= 16) {
        if (info.exponent_bits_per_sample > 0) {
          if (is_linear) {
            precision = GIMP_PRECISION_HALF_LINEAR;
          } else {
            precision = GIMP_PRECISION_HALF_GAMMA;
          }
        } else if (is_linear) {
          precision = GIMP_PRECISION_U16_LINEAR;
        } else {
          precision = GIMP_PRECISION_U16_GAMMA;
        }
      } else {
        if (info.exponent_bits_per_sample > 0) {
          if (is_linear) {
            precision = GIMP_PRECISION_FLOAT_LINEAR;
          } else {
            precision = GIMP_PRECISION_FLOAT_GAMMA;
          }
        } else if (is_linear) {
          precision = GIMP_PRECISION_U32_LINEAR;
        } else {
          precision = GIMP_PRECISION_U32_GAMMA;
        }
      }

      // create new image
      if (is_linear) {
        *image_id = gimp_image_new_with_precision(xsize, ysize, image_type,
                                                  GIMP_PRECISION_FLOAT_LINEAR);
      } else {
        *image_id = gimp_image_new_with_precision(xsize, ysize, image_type,
                                                  GIMP_PRECISION_FLOAT_GAMMA);
      }

      if (profile_int) {
        gimp_image_set_color_profile(*image_id, profile_int);
      } else if (!profile_icc) {
        g_printerr(LOAD_PROC " Warning: No color profile.\n");
      }
    } else if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
      // get image from decoder in FLOAT
      format.data_type = JXL_TYPE_FLOAT;
      if (!SetJpegXlOutBuffer(&dec, &format, &buffer_size, &pixels_buffer_1))
        return false;
    } else if (status == JXL_DEC_FULL_IMAGE) {
      // create and insert layer
      gchar *layer_name;
      if (layer_idx == 0 && !info.have_animation) {
        layer_name = g_strdup_printf("Background");
      } else {
        const GString *blend_null_flag = g_string_new("");
        const GString *blend_replace_flag = g_string_new(" (replace)");
        const GString *blend_combine_flag = g_string_new(" (combine)");
        GString *blend;
        if (blend_mode == JXL_BLEND_REPLACE) {
          blend = (GString *)blend_replace_flag;
        } else if (blend_mode == JXL_BLEND_BLEND) {
          blend = (GString *)blend_combine_flag;
        } else {
          blend = (GString *)blend_null_flag;
        }
        char *temp_frame_name = nullptr;
        bool must_free_frame_name = false;
        if (frame_name_len == 0) {
          temp_frame_name = g_strdup_printf("Frame %lu", layer_idx + 1);
          must_free_frame_name = true;
        } else {
          temp_frame_name = frame_name;
        }
        double fduration = frame_duration * 1000.f * tps_denom / tps_numer;
        layer_name = g_strdup_printf("%s (%.15gms)%s", temp_frame_name,
                                     fduration, blend->str);
        if (must_free_frame_name) free(temp_frame_name);
      }
      layer = gimp_layer_new(*image_id, layer_name, xsize, ysize, layer_type,
                             /*opacity=*/100,
                             gimp_image_get_default_new_layer_mode(*image_id));

      gimp_image_insert_layer(*image_id, layer, /*parent_id=*/-1,
                              /*position=*/0);

      pixels_buffer_2 = g_malloc(buffer_size);
      GeglBuffer *buffer = gimp_drawable_get_buffer(layer);
      const Babl *destination_format = gegl_buffer_set_format(buffer, nullptr);

      std::string babl_format_str = "";
      if (is_gray) {
        babl_format_str += "Y'";
      } else {
        babl_format_str += "R'G'B'";
      }
      if (info.alpha_bits > 0) {
        babl_format_str += "A";
      }
      babl_format_str += " float";

      const Babl *source_format = babl_format(babl_format_str.c_str());

      babl_process(babl_fish(source_format, destination_format),
                   pixels_buffer_1, pixels_buffer_2, xsize * ysize);

      gegl_buffer_set(buffer, GEGL_RECTANGLE(0, 0, xsize, ysize), 0, nullptr,
                      pixels_buffer_2, GEGL_AUTO_ROWSTRIDE);
      gimp_item_transform_translate(layer, crop_x0, crop_y0);

      g_clear_object(&buffer);
      g_free(pixels_buffer_1);
      g_free(pixels_buffer_2);
      if (stop_processing) status = JXL_DEC_SUCCESS;
      g_free(layer_name);
      layer_idx++;
    } else if (status == JXL_DEC_FRAME) {
      JxlFrameHeader frame_header;
      if (JxlDecoderGetFrameHeader(dec.get(), &frame_header) !=
          JXL_DEC_SUCCESS) {
        g_printerr(LOAD_PROC " Error: JxlDecoderSetImageOutBuffer failed\n");
        return false;
      }
      xsize = frame_header.layer_info.xsize;
      ysize = frame_header.layer_info.ysize;
      crop_x0 = frame_header.layer_info.crop_x0;
      crop_y0 = frame_header.layer_info.crop_y0;
      frame_duration = frame_header.duration;
      blend_mode = frame_header.layer_info.blend_info.blendmode;
      if (blend_mode != JXL_BLEND_BLEND && blend_mode != JXL_BLEND_REPLACE) {
        g_printerr(
            LOAD_PROC
            " Warning: JxlDecoderGetFrameHeader: Unhandled blend mode: %d\n",
            blend_mode);
      }
      if ((frame_name_len = frame_header.name_length) > 0) {
        frame_name = (char *)realloc(frame_name, frame_name_len);
        if (JXL_DEC_SUCCESS !=
            JxlDecoderGetFrameName(dec.get(), frame_name, frame_name_len)) {
          g_printerr(LOAD_PROC "Error: JxlDecoderGetFrameName failed");
          return false;
        };
      }
    } else if (status == JXL_DEC_SUCCESS) {
      // All decoding successfully finished.
      // It's not required to call JxlDecoderReleaseInput(dec.get())
      // since the decoder will be destroyed.
      break;
    } else if (status == JXL_DEC_NEED_MORE_INPUT ||
               status == JXL_DEC_FRAME_PROGRESSION) {
      stop_processing = status != JXL_DEC_FRAME_PROGRESSION;
      if (JxlDecoderFlushImage(dec.get()) == JXL_DEC_SUCCESS) {
        status = JXL_DEC_FULL_IMAGE;
        continue;
      }
      g_printerr(LOAD_PROC " Error: Already provided all input\n");
      return false;
    } else if (status == JXL_DEC_ERROR) {
      g_printerr(LOAD_PROC " Error: Decoder error\n");
      return false;
    } else {
      g_printerr(LOAD_PROC " Error: Unknown decoder status\n");
      return false;
    }
  }  // end grand decode loop

  gimp_load_progress.update();

  if (profile_icc) {
    gimp_image_set_color_profile(*image_id, profile_icc);
  }

  gimp_load_progress.update();

  // TODO(xiota): Add option to keep image as float
  if (info.bits_per_sample < 32) {
    gimp_image_convert_precision(*image_id, precision);
  }

  gimp_image_set_filename(*image_id, filename);

  gimp_load_progress.finished();
  return true;
}

}  // namespace jxl
