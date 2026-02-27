// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Note: This encoder binary does extensive flag-validity checking (in
// order to produce meaningful error messages), and on top of that
// checks all libjxl C API call return values. The downside of this
// vs. libjxl providing meaningful error messages is that a change to
// the accepted range of a flag-specified parameter in libjxl will
// also require a change to the range-check here. The advantage is
// that this minimizes the size of libjxl.

#include <jxl/codestream_header.h>
#include <jxl/encode.h>
#include <jxl/encode_cxx.h>
#include <jxl/thread_parallel_runner.h>
#include <jxl/thread_parallel_runner_cxx.h>
#include <jxl/types.h>
#include <stdint.h>

#include <cmath>
#include <cstdlib>
#include <functional>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <type_traits>
#include <vector>

#include "lib/extras/dec/apng.h"
#include "lib/extras/dec/color_hints.h"
#include "lib/extras/dec/decode.h"
#include "lib/extras/enc/jxl.h"
#include "lib/extras/time.h"
#include "lib/jxl/base/override.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/exif.h"
#include "tools/args.h"
#include "tools/cmdline.h"
#include "tools/codec_config.h"
#include "tools/file_io.h"
#include "tools/speed_stats.h"

namespace jpegxl {
namespace tools {

namespace {
inline bool ParsePhotonNoiseParameter(const char* arg, float* out) {
  return ParseFloat(arg, out) && *out >= 0;
}
inline bool ParseIntensityTarget(const char* arg, float* out) {
  return ParseFloat(arg, out) && *out > 0;
}
}  // namespace

enum CjxlRetCode : int {
  OK = 0,
  ERR_PARSE,
  ERR_INVALID_ARG,
  ERR_LOAD_INPUT,
  ERR_INVALID_INPUT,
  ERR_ENCODING,
  ERR_CONTAINER,
  ERR_WRITE,
  DROPPED_JBRD,
};

struct CompressArgs {
  // CompressArgs() = default;
  void AddCommandLineOptions(CommandLineParser* cmdline) {
    std::string input_help("the input can be ");
    if (jxl::extras::CanDecode(jxl::extras::Codec::kPNG)) {
      input_help.append("PNG, APNG, ");
    }
    if (jxl::extras::CanDecode(jxl::extras::Codec::kGIF)) {
      input_help.append("GIF, ");
    }
    if (jxl::extras::CanDecode(jxl::extras::Codec::kJPG)) {
      input_help.append("JPEG, ");
    } else {
      input_help.append("JPEG (lossless recompression only), ");
    }
    if (jxl::extras::CanDecode(jxl::extras::Codec::kEXR)) {
      input_help.append("EXR, ");
    }
    input_help.append("PPM, PFM, PAM, PGX, or JXL");
    // Positional arguments.
    cmdline->AddPositionalOption("INPUT", /* required = */ true, input_help,
                                 &file_in);
    cmdline->AddPositionalOption("OUTPUT", /* required = */ true,
                                 "the compressed JXL output file", &file_out);

    // Flags.

    cmdline->AddHelpText("\nBasic options:", 0);

    // Target distance/size/bpp
    opt_distance_id = cmdline->AddOptionValue(
        'd', "distance", "DISTANCE",
        "Target visual distance in JND units, lower = higher quality.\n"
        "    0.0 = mathematically lossless. Default for already-lossy input "
        "(JPEG/GIF).\n"
        "    1.0 = visually lossless. Default for other input.\n"
        "    Recommended range: 0.5 .. 3.0. Allowed range: 0.0 ... 25.0. "
        "Mutually exclusive with --quality.",
        &distance, &ParseFloat);

    // High-level options
    opt_quality_id = cmdline->AddOptionValue(
        'q', "quality", "QUALITY",
        "Quality setting, higher value = higher quality. This is internally "
        "mapped to --distance.\n"
        "    100 = mathematically lossless. 90 = visually lossless.\n"
        "    Quality values roughly match libjpeg quality.\n"
        "    Recommended range: 68 .. 96. Allowed range: 0 .. 100. Mutually "
        "exclusive with --distance.",
        &quality, &ParseFloat);

    cmdline->AddOptionValue(
        'e', "effort", "EFFORT",
        "Encoder effort setting. Range: 1 .. 9.\n"
        "    Default: 7. Higher numbers allow more computation "
        "at the expense of time.\n"
        "    For lossless, generally it will produce smaller files.\n"
        "    For lossy, higher effort should more accurately reach "
        "the target quality.",
        &effort, &ParseUnsigned);

    cmdline->AddOptionFlag('V', "version",
                           "Print encoder library version number and exit.",
                           &version, &SetBooleanTrue);
    cmdline->AddOptionFlag('\0', "quiet", "Be more silent", &quiet,
                           &SetBooleanTrue);
    cmdline->AddOptionFlag('v', "verbose",
                           "Verbose output; can be repeated and also applies "
                           "to help (!).",
                           &verbose, &SetBooleanTrue);

    cmdline->AddHelpText("\nAdvanced options:", 1);

    opt_alpha_distance_id = cmdline->AddOptionValue(
        'a', "alpha_distance", "A_DISTANCE",
        "Target visual distance for the alpha channel, lower = higher "
        "quality.\n"
        "    0.0 = mathematically lossless. 1.0 = visually lossless.\n"
        "    Default is to use the same value as for the color image.\n"
        "    Recommended range: 0.5 .. 3.0. Allowed range: 0.0 ... 25.0.",
        &alpha_distance, &ParseFloat, 1);

    cmdline->AddOptionFlag('p', "progressive",
                           "Enable (more) progressive/responsive decoding.",
                           &progressive, &SetBooleanTrue, 1);

    cmdline->AddOptionValue(
        '\0', "group_order", "0|1",
        "Order in which 256x256 groups are stored "
        "in the codestream for progressive rendering.\n"
        "    0 = scanline order, 1 = center-first order. Default: 0.",
        &group_order, &ParseOverride, 1);

    cmdline->AddOptionValue(
        '\0', "container", "0|1",
        "0 = Avoid the container format unless it is needed (default)\n"
        "    1 = Force using the container format even if it is not needed.",
        &container, &ParseOverride, 1);

    cmdline->AddOptionValue('\0', "compress_boxes", "0|1",
                            "Disable/enable Brotli compression for metadata "
                            "boxes. Default is 1 (enabled).",
                            &compress_boxes, &ParseOverride, 1);

    cmdline->AddOptionValue(
        '\0', "brotli_effort", "B_EFFORT",
        "Brotli effort setting. Range: 0 .. 11.\n"
        "    Default: 9. Higher number is more effort (slower).",
        &brotli_effort, &ParseUnsigned, 1);

    cmdline->AddOptionValue(
        'm', "modular", "0|1",
        "Use modular mode (default = encoder chooses, 0 = enforce VarDCT, "
        "1 = enforce modular mode).",
        &modular, &ParseOverride, 1);

    // JPEG modes: parallel Brunsli, pixels to JPEG, or JPEG to Brunsli
    opt_lossless_jpeg_id = cmdline->AddOptionValue(
        'j', "lossless_jpeg", "0|1",
        "If the input is JPEG, losslessly transcode JPEG, "
        "rather than using reencode pixels.",
        &lossless_jpeg, &ParseUnsigned, 1);

    cmdline->AddOptionValue(
        '\0', "num_threads", "N",
        "Number of worker threads (-1 == use machine default, "
        "0 == do not use multithreading).",
        &num_threads, &ParseSigned, 1);

    cmdline->AddOptionValue(
        '\0', "photon_noise_iso", "ISO_FILM_SPEED",
        "Adds noise to the image emulating photographic film or sensor noise.\n"
        "    Higher number = grainier image, e.g. 100 gives a low amount of "
        "noise,\n"
        "    3200 gives a lot of noise. Default is 0.",
        &photon_noise_iso, &ParsePhotonNoiseParameter, 1);

    cmdline->AddOptionValue(
        '\0', "intensity_target", "N",
        "Upper bound on the intensity level present in the image, in nits.\n"
        "    Default is 0, which means 'choose a sensible default "
        "value based on the color encoding.",
        &intensity_target, &ParseIntensityTarget, 1);

    cmdline->AddOptionValue(
        'x', "dec-hints", "key=value",
        "This is useful for 'raw' formats like PPM that cannot store "
        "colorspace information\n"
        "    and metadata, or to strip or modify metadata in formats that do.\n"
        "    The key 'color_space' indicates an enumerated ColorEncoding, for "
        "example:\n"
        "      -x color_space=RGB_D65_SRG_Per_SRG is sRGB with perceptual "
        "rendering intent\n"
        "      -x color_space=RGB_D65_202_Rel_PeQ is Rec.2100 PQ with relative "
        "rendering intent\n"
        "    The key 'icc_pathname' refers to a binary file containing an ICC "
        "profile.\n"
        "    The keys 'exif', 'xmp', and 'jumbf' refer to a binary file "
        "containing metadata;\n"
        "    existing metadata of the same type will be overwritten.\n"
        "    Specific metadata can be stripped using e.g. -x strip=exif",
        &color_hints_proxy, &ParseAndAppendKeyValue<ColorHintsProxy>, 1);

    cmdline->AddHelpText("\nExpert options:", 2);

    cmdline->AddOptionValue(
        '\0', "jpeg_store_metadata", "0|1",
        ("If --lossless_jpeg=1, store JPEG reconstruction "
         "metadata in the JPEG XL container.\n"
         "    This allows reconstruction of the JPEG codestream. Default: 1."),
        &jpeg_store_metadata, &ParseUnsigned, 2);

    cmdline->AddOptionValue('\0', "codestream_level", "K",
                            "The codestream level. Either `-1`, `5` or `10`.",
                            &codestream_level, &ParseInt64, 2);

    cmdline->AddOptionValue('\0', "faster_decoding", "0|1|2|3|4",
                            "0 = default, higher values improve decode speed "
                            "at the expense of quality or density.",
                            &faster_decoding, &ParseUnsigned, 2);

    cmdline->AddOptionValue('\0', "premultiply", "-1|0|1",
                            "Force premultiplied (associated) alpha.",
                            &premultiply, &ParseSigned, 2);

    cmdline->AddOptionValue('\0', "keep_invisible", "0|1",
                            "disable/enable preserving color of invisible "
                            "pixels (default: 1 if lossless, 0 if lossy).",
                            &keep_invisible, &ParseOverride, 2);

    cmdline->AddOptionValue(
        '\0', "center_x", "-1..XSIZE",
        "Determines the horizontal position of center for the center-first "
        "group order.\n"
        "    Default -1 means 'middle of the image', "
        "values [0..xsize) set this to a particular coordinate.",
        &center_x, &ParseInt64, 2);

    cmdline->AddOptionValue(
        '\0', "center_y", "-1..YSIZE",
        "Determines the vertical position of center for the center-first "
        "group order.\n"
        "    Default -1 means 'middle of the image', "
        "values [0..ysize) set this to a particular coordinate.",
        &center_y, &ParseInt64, 2);

    // Flags.
    cmdline->AddOptionFlag('\0', "progressive_ac",
                           "Use the progressive mode for AC.", &progressive_ac,
                           &SetBooleanTrue, 2);

    cmdline->AddOptionFlag(
        '\0', "qprogressive_ac",
        "Use the progressive mode for AC with shift quantization.",
        &qprogressive_ac, &SetBooleanTrue, 2);

    cmdline->AddOptionValue(
        '\0', "progressive_dc", "num_dc_frames",
        "Progressive-DC setting. Valid values are: -1, 0, 1, 2.",
        &progressive_dc, &ParseInt64, 2);

    cmdline->AddOptionValue('\0', "resampling", "-1|1|2|4|8",
                            "Resampling for color channels. Default of -1 "
                            "applies resampling only for very low quality.\n"
                            "    1 = downsampling (1x1), 2 = 2x2 downsampling, "
                            "4 = 4x4 downsampling, 8 = 8x8 downsampling.",
                            &resampling, &ParseInt64, 2);

    cmdline->AddOptionValue('\0', "ec_resampling", "-1|1|2|4|8",
                            "Resampling for extra channels. Same as "
                            "--resampling but for extra channels like alpha.",
                            &ec_resampling, &ParseInt64, 2);

    cmdline->AddOptionFlag('\0', "already_downsampled",
                           "Do not downsample before encoding, "
                           "but still signal that the decoder should upsample.",
                           &already_downsampled, &SetBooleanTrue, 2);

    cmdline->AddOptionValue(
        '\0', "upsampling_mode", "-1|0|1",
        "Upsampling mode the decoder should use. Mostly useful in combination "
        "with --already_downsampled. Value -1 means default (non-separable "
        "upsampling), 0 means nearest neighbor (useful for pixel art)",
        &upsampling_mode, &ParseInt64, 2);

    cmdline->AddOptionValue(
        '\0', "epf", "-1|0|1|2|3",
        "Edge preserving filter level, 0-3. "
        "Default -1 means encoder chooses, 0-3 set a strength.",
        &epf, &ParseInt64, 2);

    cmdline->AddOptionValue('\0', "gaborish", "0|1",
                            "Force disable/enable the gaborish filter. Default "
                            "is 'encoder chooses'",
                            &gaborish, &ParseOverride, 2);

    cmdline->AddOptionValue('\0', "override_bitdepth", "BITDEPTH",
                            "Default is zero (use the input image bit depth); "
                            "if nonzero, override the bit depth",
                            &override_bitdepth, &ParseUnsigned, 2);

    cmdline->AddHelpText("\nOptions for experimentation / benchmarking:", 3);

    cmdline->AddOptionValue('\0', "noise", "0|1",
                            "Force disable/enable adaptive noise generation "
                            "(experimental). Default "
                            "is 'encoder chooses'",
                            &noise, &ParseOverride, 3);

    cmdline->AddOptionValue(
        '\0', "jpeg_reconstruction_cfl", "0|1",
        "Enable/disable chroma-from-luma (CFL) for lossless "
        "JPEG reconstruction.",
        &jpeg_reconstruction_cfl, &ParseOverride, 3);

    cmdline->AddOptionValue('\0', "num_reps", "N",
                            "How many times to compress. (For benchmarking).",
                            &num_reps, &ParseUnsigned, 3);

    cmdline->AddOptionFlag('\0', "disable_output",
                           "No output file will be written (for benchmarking)",
                           &disable_output, &SetBooleanTrue, 3);

    cmdline->AddOptionValue(
        '\0', "dots", "0|1",
        "Force disable/enable dots generation. "
        "(not provided = default, 0 = disable, 1 = enable).",
        &dots, &ParseOverride, 3);

    cmdline->AddOptionValue(
        '\0', "patches", "0|1",
        "Force disable/enable patches generation. "
        "(not provided = default, 0 = disable, 1 = enable).",
        &patches, &ParseOverride, 3);

    cmdline->AddOptionValue(
        '\0', "frame_indexing", "INDICES",
        // TODO(tfish): Add a more convenient vanilla alternative.
        "INDICES is of the form '^(0*|1[01]*)'. The i-th position indicates "
        "whether the\n"
        "    i-th frame will be indexed in the frame index box.",
        &frame_indexing, &ParseString, 3);

    cmdline->AddOptionFlag('\0', "allow_expert_options",
                           "Allow specifying advanced options; this allows "
                           "setting effort to 10, for\n"
                           "    somewhat better lossless compression at the "
                           "cost of a massive speed hit.",
                           &allow_expert_options, &SetBooleanTrue, 3);

    cmdline->AddHelpText("\nModular mode options:", 4);

    // modular mode options
    cmdline->AddOptionValue(
        'I', "iterations", "PERCENT",
        "Percentage of pixels used to learn MA trees. Higher values use\n"
        "    more encoder memory and can result in better compression. Default "
        "of -1 means\n"
        "    the encoder chooses. Zero means no MA trees are used.",
        &modular_ma_tree_learning_percent, &ParseFloat, 4);

    cmdline->AddOptionValue(
        'C', "modular_colorspace", "K",
        ("Color transform: -1 = default (try several per group, depending\n"
         "    on effort), 0 = RGB (none), 1-41 = fixed RCT (6 = YCoCg)."),
        &modular_colorspace, &ParseInt64, 4);

    opt_modular_group_size_id = cmdline->AddOptionValue(
        'g', "modular_group_size", "K",
        "Group size: -1 = default (let the encoder choose),\n"
        "    0 = 128x128, 1 = 256x256, 2 = 512x512, 3 = 1024x1024.",
        &modular_group_size, &ParseInt64, 4);

    cmdline->AddOptionValue(
        'P', "modular_predictor", "K",
        "Predictor(s) to use: 0=zero, 1=left, 2=top, 3=avg0, 4=select,\n"
        "    5=gradient, 6=weighted, 7=topright, 8=topleft, 9=leftleft, "
        "10=avg1, 11=avg2, 12=avg3,\n"
        "    13=toptop predictive average, 14=mix 5 and 6, 15=mix everything.\n"
        "    Default is 14 at effort < 9 and 15 at effort 9.",
        &modular_predictor, &ParseInt64, 4);

    cmdline->AddOptionValue(
        'E', "modular_nb_prev_channels", "K",
        "Number of extra (previous-channel) MA tree properties to use.",
        &modular_nb_prev_channels, &ParseInt64, 4);

    cmdline->AddOptionValue(
        '\0', "modular_palette_colors", "K",
        "Use palette if number of colors is smaller than or equal to this.",
        &modular_palette_colors, &ParseInt64, 4);

    cmdline->AddOptionFlag(
        '\0', "modular_lossy_palette",
        "Use delta palette in a lossy way; it is recommended to also\n"
        "    set --modular_palette_colors=0 with this "
        "option to use the default palette only.",
        &modular_lossy_palette, &SetBooleanTrue, 4);

    cmdline->AddOptionValue('X', "pre-compact", "PERCENT",
                            "Use global channel palette if the number of "
                            "sample values is smaller\n"
                            "    than this percentage of the nominal range. ",
                            &modular_channel_colors_global_percent, &ParseFloat,
                            4);

    cmdline->AddOptionValue(
        'Y', "post-compact", "PERCENT",
        "Use local (per-group) channel palette if the "
        "number of sample values is\n"
        "    smaller than this percentage of the nominal range.",
        &modular_channel_colors_group_percent, &ParseFloat, 4);

    opt_responsive_id =
        cmdline->AddOptionValue('R', "responsive", "K",
                                "Do the Squeeze transform, 0=false, "
                                "1=true (default: 1 if lossy, 0 if lossless)",
                                &responsive, &ParseInt64, 4);
  }

  // Common flags.
  bool version = false;
  jxl::Override container = jxl::Override::kDefault;
  bool quiet = false;
  bool disable_output = false;

  const char* file_in = nullptr;
  const char* file_out = nullptr;
  jxl::Override print_profile = jxl::Override::kDefault;

  // Decoding source image flags
  ColorHintsProxy color_hints_proxy;

  // JXL flags
  size_t override_bitdepth = 0;
  int32_t num_threads = -1;
  size_t num_reps = 1;
  float intensity_target = 0;

  // Whether to perform lossless transcoding with kVarDCT or kJPEG encoding.
  // If true, attempts to load JPEG coefficients instead of pixels.
  // Reset to false if input image is not a JPEG.
  size_t lossless_jpeg = 1;

  size_t jpeg_store_metadata = 1;

  float quality = -1001.f;  // Default to lossless if input is already lossy,
                            // or to VarDCT otherwise.
  bool verbose = false;
  bool progressive = false;
  bool progressive_ac = false;
  bool qprogressive_ac = false;
  int64_t progressive_dc = -1;
  bool modular_lossy_palette = false;
  int32_t premultiply = -1;
  bool already_downsampled = false;
  int64_t upsampling_mode = -1;
  jxl::Override jpeg_reconstruction_cfl = jxl::Override::kDefault;
  jxl::Override modular = jxl::Override::kDefault;
  jxl::Override keep_invisible = jxl::Override::kDefault;
  jxl::Override dots = jxl::Override::kDefault;
  jxl::Override patches = jxl::Override::kDefault;
  jxl::Override gaborish = jxl::Override::kDefault;
  jxl::Override group_order = jxl::Override::kDefault;
  jxl::Override compress_boxes = jxl::Override::kDefault;
  jxl::Override noise = jxl::Override::kDefault;

  size_t faster_decoding = 0;
  int64_t resampling = -1;
  int64_t ec_resampling = -1;
  int64_t epf = -1;
  int64_t center_x = -1;
  int64_t center_y = -1;
  int64_t modular_group_size = -1;
  int64_t modular_predictor = -1;
  int64_t modular_colorspace = -1;
  float modular_channel_colors_global_percent = -1.f;
  float modular_channel_colors_group_percent = -1.f;
  int64_t modular_palette_colors = -1;
  int64_t modular_nb_prev_channels = -1;
  float modular_ma_tree_learning_percent = -1.f;
  float photon_noise_iso = 0;
  int64_t codestream_level = -1;
  int64_t responsive = -1;
  float distance = 1.0;
  float alpha_distance = 1.0;
  size_t effort = 7;
  size_t brotli_effort = 9;
  std::string frame_indexing;

  bool allow_expert_options = false;

  // References (ids) of specific options to check if they were matched.
  CommandLineParser::OptionId opt_lossless_jpeg_id = -1;
  CommandLineParser::OptionId opt_responsive_id = -1;
  CommandLineParser::OptionId opt_distance_id = -1;
  CommandLineParser::OptionId opt_alpha_distance_id = -1;
  CommandLineParser::OptionId opt_quality_id = -1;
  CommandLineParser::OptionId opt_modular_group_size_id = -1;
};

const char* ModeFromArgs(const CompressArgs& args) {
  if (args.lossless_jpeg) return "JPEG";
  if (args.modular == jxl::Override::kOn || args.distance == 0)
    return "Modular";
  return "VarDCT";
}

std::string DistanceFromArgs(const CompressArgs& args) {
  char buf[100];
  if (args.lossless_jpeg) {
    snprintf(buf, sizeof(buf), "lossless transcode");
  } else if (args.distance == 0) {
    snprintf(buf, sizeof(buf), "lossless");
  } else {
    snprintf(buf, sizeof(buf), "d%.3f", args.distance);
  }
  return buf;
}

void PrintMode(jxl::extras::PackedPixelFile& ppf, const double decode_mps,
               size_t num_bytes, const CompressArgs& args,
               jpegxl::tools::CommandLineParser& cmdline) {
  const char* mode = ModeFromArgs(args);
  const std::string distance = DistanceFromArgs(args);
  if (args.lossless_jpeg) {
    cmdline.VerbosePrintf(1, "Read JPEG image with %" PRIuS " bytes.\n",
                          num_bytes);
  } else {
    cmdline.VerbosePrintf(
        1, "Read %" PRIuS "x%" PRIuS " image, %" PRIuS " bytes, %.1f MP/s\n",
        static_cast<size_t>(ppf.info.xsize),
        static_cast<size_t>(ppf.info.ysize), num_bytes, decode_mps);
  }
  cmdline.VerbosePrintf(
      0, "Encoding [%s%s, %s, effort: %" PRIuS,
      (args.container == jxl::Override::kOn ? "Container | " : ""), mode,
      distance.c_str(), args.effort);
  if (args.container == jxl::Override::kOn) {
    if (args.lossless_jpeg && args.jpeg_store_metadata)
      cmdline.VerbosePrintf(0, " | JPEG reconstruction data");
    if (!ppf.metadata.exif.empty())
      cmdline.VerbosePrintf(0, " | %" PRIuS "-byte Exif",
                            ppf.metadata.exif.size());
    if (!ppf.metadata.xmp.empty())
      cmdline.VerbosePrintf(0, " | %" PRIuS "-byte XMP",
                            ppf.metadata.xmp.size());
    if (!ppf.metadata.jumbf.empty())
      cmdline.VerbosePrintf(0, " | %" PRIuS "-byte JUMBF",
                            ppf.metadata.jumbf.size());
  }
  cmdline.VerbosePrintf(0, "]\n");
}

bool IsJPG(const std::vector<uint8_t>& image_data) {
  return (image_data.size() >= 2 && image_data[0] == 0xFF &&
          image_data[1] == 0xD8);
}

using flag_check_fn = std::function<std::string(int64_t)>;
using flag_check_float_fn = std::function<std::string(float)>;

template <typename T>
void ProcessFlag(
    const char* flag_name, T flag_value,
    JxlEncoderFrameSettingId encoder_option,
    jxl::extras::JXLCompressParams* params,
    flag_check_fn flag_check = [](T x) { return std::string(); }) {
  std::string error = flag_check(flag_value);
  if (!error.empty()) {
    std::cerr << "Invalid flag value for --" << flag_name << ": " << error
              << std::endl;
    exit(EXIT_FAILURE);
  }
  params->options.emplace_back(
      jxl::extras::JXLOption(encoder_option, flag_value, 0));
}

void ProcessBoolFlag(jxl::Override flag_value,
                     JxlEncoderFrameSettingId encoder_option,
                     jxl::extras::JXLCompressParams* params) {
  if (flag_value != jxl::Override::kDefault) {
    int64_t value = flag_value == jxl::Override::kOn ? 1 : 0;
    params->options.emplace_back(
        jxl::extras::JXLOption(encoder_option, value, 0));
  }
}

void SetDistanceFromFlags(CommandLineParser* cmdline, CompressArgs* args,
                          jxl::extras::JXLCompressParams* params,
                          const jxl::extras::Codec& codec) {
  bool distance_set = cmdline->GetOption(args->opt_distance_id)->matched();
  bool alpha_distance_set =
      cmdline->GetOption(args->opt_alpha_distance_id)->matched();
  bool quality_set = cmdline->GetOption(args->opt_quality_id)->matched();
  if (((distance_set && (args->distance != 0.0)) ||
       (quality_set && (args->quality != 100))) &&
      args->lossless_jpeg) {
    std::cerr << "Must not set quality below 100 nor non-zero distance in "
                 "combination with --lossless_jpeg=1."
              << std::endl;
    exit(EXIT_FAILURE);
  }
  if (quality_set) {
    if (distance_set) {
      std::cerr << "Must not set both --distance and --quality." << std::endl;
      exit(EXIT_FAILURE);
    }
    double distance = args->quality >= 100 ? 0.0
                      : args->quality >= 30
                          ? 0.1 + (100 - args->quality) * 0.09
                          : 53.0 / 3000.0 * args->quality * args->quality -
                                23.0 / 20.0 * args->quality + 25.0;
    args->distance = distance;
    distance_set = true;
  }
  if (!distance_set) {
    bool lossy_input = (codec == jxl::extras::Codec::kJPG ||
                        codec == jxl::extras::Codec::kGIF);
    args->distance = lossy_input ? 0.0 : 1.0;
  } else if (args->distance > 0) {
    args->lossless_jpeg = 0;
  }
  params->distance = args->distance;
  params->alpha_distance =
      alpha_distance_set ? args->alpha_distance : params->distance;
}

void ProcessFlags(const jxl::extras::Codec codec,
                  const jxl::extras::PackedPixelFile& ppf,
                  const std::vector<uint8_t>* jpeg_bytes,
                  CommandLineParser* cmdline, CompressArgs* args,
                  jxl::extras::JXLCompressParams* params) {
  // Tuning flags.
  ProcessBoolFlag(args->modular, JXL_ENC_FRAME_SETTING_MODULAR, params);
  ProcessBoolFlag(args->keep_invisible, JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE,
                  params);
  ProcessBoolFlag(args->dots, JXL_ENC_FRAME_SETTING_DOTS, params);
  ProcessBoolFlag(args->patches, JXL_ENC_FRAME_SETTING_PATCHES, params);
  ProcessBoolFlag(args->gaborish, JXL_ENC_FRAME_SETTING_GABORISH, params);
  ProcessBoolFlag(args->group_order, JXL_ENC_FRAME_SETTING_GROUP_ORDER, params);
  ProcessBoolFlag(args->noise, JXL_ENC_FRAME_SETTING_NOISE, params);

  params->allow_expert_options = args->allow_expert_options;

  if (!args->frame_indexing.empty()) {
    bool must_be_all_zeros = args->frame_indexing[0] != '1';
    for (char c : args->frame_indexing) {
      if (c == '1') {
        if (must_be_all_zeros) {
          std::cerr << "Invalid --frame_indexing. If the first character is "
                       "'0', all must be '0'."
                    << std::endl;
          exit(EXIT_FAILURE);
        }
      } else if (c != '0') {
        std::cerr << "Invalid --frame_indexing. Must match the pattern "
                     "'^(0*|1[01]*)$'."
                  << std::endl;
        exit(EXIT_FAILURE);
      }
    }
  }

  ProcessFlag(
      "effort", static_cast<int64_t>(args->effort),
      JXL_ENC_FRAME_SETTING_EFFORT, params, [args](int64_t x) -> std::string {
        if (args->allow_expert_options) {
          return (1 <= x && x <= 10) ? "" : "Valid range is {1, 2, ..., 10}.";
        } else {
          return (1 <= x && x <= 9) ? "" : "Valid range is {1, 2, ..., 9}.";
        }
      });
  ProcessFlag("brotli_effort", static_cast<int64_t>(args->brotli_effort),
              JXL_ENC_FRAME_SETTING_BROTLI_EFFORT, params,
              [](int64_t x) -> std::string {
                return (-1 <= x && x <= 11)
                           ? ""
                           : "Valid range is {-1, 0, 1, ..., 11}.";
              });
  ProcessFlag(
      "epf", args->epf, JXL_ENC_FRAME_SETTING_EPF, params,
      [](int64_t x) -> std::string {
        return (-1 <= x && x <= 3) ? "" : "Valid range is {-1, 0, 1, 2, 3}.\n";
      });
  ProcessFlag("faster_decoding", static_cast<int64_t>(args->faster_decoding),
              JXL_ENC_FRAME_SETTING_DECODING_SPEED, params,
              [](int64_t x) -> std::string {
                return (0 <= x && x <= 4) ? ""
                                          : "Valid range is {0, 1, 2, 3, 4}.\n";
              });
  ProcessFlag("resampling", args->resampling, JXL_ENC_FRAME_SETTING_RESAMPLING,
              params, [](int64_t x) -> std::string {
                return (x == -1 || x == 1 || x == 2 || x == 4 || x == 8)
                           ? ""
                           : "Valid values are {-1, 1, 2, 4, 8}.\n";
              });
  ProcessFlag("ec_resampling", args->ec_resampling,
              JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING, params,
              [](int64_t x) -> std::string {
                return (x == -1 || x == 1 || x == 2 || x == 4 || x == 8)
                           ? ""
                           : "Valid values are {-1, 1, 2, 4, 8}.\n";
              });
  ProcessFlag("photon_noise_iso", args->photon_noise_iso,
              JXL_ENC_FRAME_SETTING_PHOTON_NOISE, params);
  ProcessFlag("already_downsampled",
              static_cast<int64_t>(args->already_downsampled),
              JXL_ENC_FRAME_SETTING_ALREADY_DOWNSAMPLED, params);
  if (args->already_downsampled) params->already_downsampled = args->resampling;

  SetDistanceFromFlags(cmdline, args, params, codec);

  if (args->group_order != jxl::Override::kOn &&
      (args->center_x != -1 || args->center_y != -1)) {
    std::cerr << "Invalid flag combination. Setting --center_x or --center_y "
              << "requires setting --group_order=1" << std::endl;
    exit(EXIT_FAILURE);
  }
  ProcessFlag("center_x", args->center_x,
              JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_X, params,
              [](int64_t x) -> std::string {
                if (x < -1) {
                  return "Valid values are: -1 or [0 .. xsize).";
                }
                return "";
              });
  ProcessFlag("center_y", args->center_y,
              JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_Y, params,
              [](int64_t x) -> std::string {
                if (x < -1) {
                  return "Valid values are: -1 or [0 .. ysize).";
                }
                return "";
              });

  // Progressive/responsive mode settings.
  bool responsive_set = cmdline->GetOption(args->opt_responsive_id)->matched();

  ProcessFlag("progressive_dc", args->progressive_dc,
              JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC, params,
              [](int64_t x) -> std::string {
                return (-1 <= x && x <= 2) ? ""
                                           : "Valid range is {-1, 0, 1, 2}.\n";
              });
  ProcessFlag("progressive_ac", static_cast<int64_t>(args->progressive_ac),
              JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC, params);

  if (args->progressive) {
    args->qprogressive_ac = true;
    args->responsive = 1;
    responsive_set = true;
  }
  if (responsive_set) {
    ProcessFlag("responsive", args->responsive,
                JXL_ENC_FRAME_SETTING_RESPONSIVE, params);
  }
  if (args->qprogressive_ac) {
    ProcessFlag("qprogressive_ac", static_cast<int64_t>(1),
                JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC, params);
  }

  // Modular mode related.
  ProcessFlag("modular_group_size", args->modular_group_size,
              JXL_ENC_FRAME_SETTING_MODULAR_GROUP_SIZE, params,
              [](int64_t x) -> std::string {
                return (-1 <= x && x <= 3)
                           ? ""
                           : "Invalid --modular_group_size. Valid "
                             "range is {-1, 0, 1, 2, 3}.\n";
              });
  ProcessFlag("modular_predictor", args->modular_predictor,
              JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR, params,
              [](int64_t x) -> std::string {
                return (-1 <= x && x <= 15)
                           ? ""
                           : "Invalid --modular_predictor. Valid "
                             "range is {-1, 0, 1, ..., 15}.\n";
              });
  ProcessFlag("modular_colorspace", args->modular_colorspace,
              JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE, params,
              [](int64_t x) -> std::string {
                return (-1 <= x && x <= 41)
                           ? ""
                           : "Invalid --modular_colorspace. Valid range is "
                             "{-1, 0, 1, ..., 41}.\n";
              });
  ProcessFlag("modular_ma_tree_learning_percent",
              args->modular_ma_tree_learning_percent,
              JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT, params,
              [](float x) -> std::string {
                return -1 <= x && x <= 100
                           ? ""
                           : "Invalid --modular_ma_tree_learning_percent, Valid"
                             "rang is [-1, 100].\n";
              });
  ProcessFlag("modular_nb_prev_channels", args->modular_nb_prev_channels,
              JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS, params,
              [](int64_t x) -> std::string {
                return (-1 <= x && x <= 11)
                           ? ""
                           : "Invalid --modular_nb_prev_channels. Valid "
                             "range is {-1, 0, 1, ..., 11}.\n";
              });
  if (args->modular_lossy_palette) {
    if (args->progressive || args->qprogressive_ac) {
      fprintf(stderr,
              "WARNING: --modular_lossy_palette is ignored in "
              "progressive mode.\n");
      args->modular_lossy_palette = false;
    }
  }
  ProcessFlag("modular_lossy_palette",
              static_cast<int64_t>(args->modular_lossy_palette),
              JXL_ENC_FRAME_SETTING_LOSSY_PALETTE, params);
  ProcessFlag("modular_palette_colors", args->modular_palette_colors,
              JXL_ENC_FRAME_SETTING_PALETTE_COLORS, params,
              [](int64_t x) -> std::string {
                return -1 <= x ? ""
                               : "Invalid --modular_palette_colors, must "
                                 "be -1 or non-negative\n";
              });
  ProcessFlag("modular_channel_colors_global_percent",
              args->modular_channel_colors_global_percent,
              JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GLOBAL_PERCENT, params,
              [](float x) -> std::string {
                return (-1 <= x && x <= 100)
                           ? ""
                           : "Invalid --modular_channel_colors_global_percent. "
                             "Valid "
                             "range is [-1, 100].\n";
              });
  ProcessFlag("modular_channel_colors_group_percent",
              args->modular_channel_colors_group_percent,
              JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GROUP_PERCENT, params,
              [](float x) -> std::string {
                return (-1 <= x && x <= 100)
                           ? ""
                           : "Invalid --modular_channel_colors_group_percent. "
                             "Valid "
                             "range is [-1, 100].\n";
              });

  if (args->num_threads < -1) {
    std::cerr
        << "Invalid flag value for --num_threads: must be -1, 0 or positive."
        << std::endl;
    exit(EXIT_FAILURE);
  }
  // JPEG specific options.
  if (jpeg_bytes) {
    ProcessBoolFlag(args->jpeg_reconstruction_cfl,
                    JXL_ENC_FRAME_SETTING_JPEG_RECON_CFL, params);
    ProcessBoolFlag(args->compress_boxes,
                    JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES, params);
  }
  // Set per-frame options.
  for (size_t num_frame = 0; num_frame < ppf.frames.size(); ++num_frame) {
    if (num_frame < args->frame_indexing.size() &&
        args->frame_indexing[num_frame] == '1') {
      int64_t value = 1;
      params->options.emplace_back(
          jxl::extras::JXLOption(JXL_ENC_FRAME_INDEX_BOX, value, num_frame));
    }
  }
  // Copy over the rest of the non-option params.
  params->use_container = args->container == jxl::Override::kOn;
  params->jpeg_store_metadata = args->jpeg_store_metadata;
  params->intensity_target = args->intensity_target;
  params->override_bitdepth = args->override_bitdepth;
  params->codestream_level = args->codestream_level;
  params->premultiply = args->premultiply;
  params->compress_boxes = args->compress_boxes != jxl::Override::kOff;
  params->upsampling_mode = args->upsampling_mode;
  if (codec == jxl::extras::Codec::kPNM &&
      ppf.info.exponent_bits_per_sample == 0) {
    params->input_bitdepth.type = JXL_BIT_DEPTH_FROM_CODESTREAM;
  }

  // If a metadata field is set to an empty value, it is stripped.
  // Make sure we also strip it when the input image is read with AddJPEGFrame
  (void)args->color_hints_proxy.target.Foreach(
      [&params](const std::string& key,
                const std::string& value) -> jxl::Status {
        if (value == "") {
          if (key == "exif") params->jpeg_strip_exif = true;
          if (key == "xmp") params->jpeg_strip_xmp = true;
          if (key == "jumbf") params->jpeg_strip_jumbf = true;
        }
        return true;
      });
}

}  // namespace tools
}  // namespace jpegxl

int main(int argc, char** argv) {
  std::string version = jpegxl::tools::CodecConfigString(JxlEncoderVersion());
  jpegxl::tools::CompressArgs args;
  jpegxl::tools::CommandLineParser cmdline;
  args.AddCommandLineOptions(&cmdline);

  if (!cmdline.Parse(argc, const_cast<const char**>(argv))) {
    // Parse already printed the actual error cause.
    fprintf(stderr, "Use '%s -h' for more information\n", argv[0]);
    return jpegxl::tools::CjxlRetCode::ERR_PARSE;
  }

  if (args.version) {
    fprintf(stdout, "cjxl %s\n", version.c_str());
    fprintf(stdout, "Copyright (c) the JPEG XL Project\n");
    return jpegxl::tools::CjxlRetCode::OK;
  }

  if (!args.quiet) {
    fprintf(stderr, "JPEG XL encoder %s\n", version.c_str());
  }

  if (cmdline.HelpFlagPassed() || !args.file_in) {
    cmdline.PrintHelp();
    return jpegxl::tools::CjxlRetCode::OK;
  }

  if (!args.file_out && !args.disable_output) {
    std::cerr
        << "No output file specified and --disable_output flag not passed."
        << std::endl;
    exit(EXIT_FAILURE);
  }

  if (args.file_out && args.disable_output && !args.quiet) {
    fprintf(stderr,
            "Encoding will be performed, but the result will be discarded.\n");
  }

  // Loading the input.
  // Depending on flags-settings, we want to either load a JPEG and
  // faithfully convert it to JPEG XL, or load (JPEG or non-JPEG)
  // pixel data.
  std::vector<uint8_t> image_data;
  jxl::extras::PackedPixelFile ppf;
  jxl::extras::Codec codec = jxl::extras::Codec::kUnknown;
  std::vector<uint8_t>* jpeg_bytes = nullptr;
  double decode_mps = 0;
  size_t pixels = 0;
  if (!jpegxl::tools::ReadFile(args.file_in, &image_data)) {
    std::cerr << "Reading image data failed." << std::endl;
    exit(EXIT_FAILURE);
  }
  if (!jpegxl::tools::IsJPG(image_data)) args.lossless_jpeg = 0;
  jxl::extras::JXLCompressParams params;
  ProcessFlags(codec, ppf, jpeg_bytes, &cmdline, &args, &params);
  if (!args.lossless_jpeg) {
    const double t0 = jxl::Now();
    jxl::Status status = jxl::extras::DecodeBytes(
        jxl::Span<const uint8_t>(image_data), args.color_hints_proxy.target,
        &ppf, nullptr, &codec);

    if (!status) {
      std::cerr << "Getting pixel data failed." << std::endl;
      exit(EXIT_FAILURE);
    }
    if (ppf.frames.empty()) {
      std::cerr << "No frames on input file." << std::endl;
      exit(EXIT_FAILURE);
    }

    const double t1 = jxl::Now();
    pixels = ppf.info.xsize * ppf.info.ysize;
    decode_mps = pixels * ppf.info.num_color_channels * 1E-6 / (t1 - t0);
  }
  if (args.lossless_jpeg && jpegxl::tools::IsJPG(image_data)) {
    if (!cmdline.GetOption(args.opt_lossless_jpeg_id)->matched()) {
      std::cerr << "Note: Implicit-default for JPEG is lossless-transcoding. "
                << "To silence this message, set --lossless_jpeg=(1|0)."
                << std::endl;
    }
    jpeg_bytes = &image_data;
  }

  ProcessFlags(codec, ppf, jpeg_bytes, &cmdline, &args, &params);

  if (!ppf.metadata.exif.empty()) {
    jxl::InterpretExif(ppf.metadata.exif, &ppf.info.orientation);
  }

  if (!ppf.metadata.exif.empty() || !ppf.metadata.xmp.empty() ||
      !ppf.metadata.jumbf.empty() || !ppf.metadata.iptc.empty() ||
      (args.lossless_jpeg && args.jpeg_store_metadata)) {
    if (args.container == jxl::Override::kDefault) {
      args.container = jxl::Override::kOn;
    } else if (args.container == jxl::Override::kOff) {
      cmdline.VerbosePrintf(
          1, "Stripping all metadata due to explicit container=0\n");
      ppf.metadata.exif.clear();
      ppf.metadata.xmp.clear();
      ppf.metadata.jumbf.clear();
      ppf.metadata.iptc.clear();
      args.jpeg_store_metadata = 0;
    }
  }

  if (!args.quiet) {
    PrintMode(ppf, decode_mps, image_data.size(), args, cmdline);
  }

  size_t num_worker_threads = JxlThreadParallelRunnerDefaultNumWorkerThreads();
  int64_t flag_num_worker_threads = args.num_threads;
  if (flag_num_worker_threads > -1) {
    num_worker_threads = flag_num_worker_threads;
  }
  JxlThreadParallelRunnerPtr runner = JxlThreadParallelRunnerMake(
      /*memory_manager=*/nullptr, num_worker_threads);
  params.runner = JxlThreadParallelRunner;
  params.runner_opaque = runner.get();

  jpegxl::tools::SpeedStats stats;
  std::vector<uint8_t> compressed;
  for (size_t num_rep = 0; num_rep < args.num_reps; ++num_rep) {
    const double t0 = jxl::Now();
    if (!EncodeImageJXL(params, ppf, jpeg_bytes, &compressed)) {
      fprintf(stderr, "EncodeImageJXL() failed.\n");
      return EXIT_FAILURE;
    }
    const double t1 = jxl::Now();
    stats.NotifyElapsed(t1 - t0);
    stats.SetImageSize(ppf.info.xsize, ppf.info.ysize);
  }

  if (args.file_out && !args.disable_output) {
    if (!jpegxl::tools::WriteFile(args.file_out, compressed)) {
      std::cerr << "Could not write jxl file." << std::endl;
      return EXIT_FAILURE;
    }
  }
  if (!args.quiet) {
    if (compressed.size() < 100000) {
      cmdline.VerbosePrintf(0, "Compressed to %" PRIuS " bytes ",
                            compressed.size());
    } else {
      cmdline.VerbosePrintf(0, "Compressed to %.1f kB ",
                            compressed.size() * 0.001);
    }
    // For lossless jpeg-reconstruction, we don't print some stats, since we
    // don't have easy access to the image dimensions.
    if (args.container == jxl::Override::kOn) {
      cmdline.VerbosePrintf(0, "including container ");
    }
    if (!args.lossless_jpeg) {
      const double bpp =
          static_cast<double>(compressed.size() * jxl::kBitsPerByte) / pixels;
      cmdline.VerbosePrintf(0, "(%.3f bpp%s).\n", bpp / ppf.frames.size(),
                            ppf.frames.size() == 1 ? "" : "/frame");
      JXL_CHECK(stats.Print(num_worker_threads));
    } else {
      cmdline.VerbosePrintf(0, "\n");
    }
  }
  return EXIT_SUCCESS;
}
