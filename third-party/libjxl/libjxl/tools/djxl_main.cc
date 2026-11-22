// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/decode.h>
#include <jxl/thread_parallel_runner.h>
#include <jxl/thread_parallel_runner_cxx.h>
#include <jxl/types.h>

#include <climits>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/extras/dec/decode.h"
#include "lib/extras/dec/jxl.h"
#include "lib/extras/enc/apng.h"
#include "lib/extras/enc/encode.h"
#include "lib/extras/enc/exr.h"
#include "lib/extras/enc/jpg.h"
#include "lib/extras/enc/pnm.h"
#include "lib/extras/packed_image.h"
#include "lib/extras/time.h"
#include "lib/jxl/base/printf_macros.h"
#include "tools/cmdline.h"
#include "tools/codec_config.h"
#include "tools/file_io.h"
#include "tools/speed_stats.h"

namespace jpegxl {
namespace tools {

struct DecompressArgs {
  DecompressArgs() = default;

  void AddCommandLineOptions(CommandLineParser* cmdline) {
    std::string output_help("The output format can be ");
    if (jxl::extras::GetAPNGEncoder()) {
      output_help.append("PNG, APNG, ");
    }
    if (jxl::extras::GetJPEGEncoder()) {
      output_help.append("JPEG, ");
    } else {
      output_help.append("JPEG (lossless reconstruction only), ");
    }
    if (jxl::extras::GetEXREncoder()) {
      output_help.append("EXR, ");
    }
    output_help.append(
        "PPM, PFM, or PAM.\n"
        "    To extract metadata, use output format EXIF, XMP, or JUMBF.\n"
        "    The format is selected based on extension ('filename.png') or "
        "prefix ('png:filename').\n"
        "    Use '-' for output to stdout (e.g. 'ppm:-')");
    cmdline->AddPositionalOption(
        "INPUT", /* required = */ true,
        "The compressed input file (JXL). Use '-' for input from stdin.",
        &file_in);

    cmdline->AddPositionalOption("OUTPUT", /* required = */ true, output_help,
                                 &file_out);

    cmdline->AddHelpText("\nBasic options:", 0);

    cmdline->AddOptionFlag('V', "version", "Print version number and exit.",
                           &version, &SetBooleanTrue, 0);
    cmdline->AddOptionFlag('\0', "quiet", "Silence output (except for errors).",
                           &quiet, &SetBooleanTrue, 0);
    cmdline->AddOptionFlag('v', "verbose",
                           "Verbose output; can be repeated and also applies "
                           "to help (!).",
                           &verbose, &SetBooleanTrue);

    cmdline->AddHelpText("\nAdvanced options:", 1);

    cmdline->AddOptionValue('\0', "num_threads", "N",
                            "Number of worker threads (-1 == use machine "
                            "default, 0 == do not use multithreading).",
                            &num_threads, &ParseSigned, 1);

    opt_bits_per_sample_id = cmdline->AddOptionValue(
        '\0', "bits_per_sample", "N",
        "Sets the output bit depth. The value 0 (default for PNM) "
        "means the original (input) bit depth.\n"
        "    The value -1 (default for other codecs) means it depends on the "
        "output format capabilities\n"
        "    and the input bit depth (e.g. decoding a 12-bit image to PNG will "
        "produce a 16-bit PNG).",
        &bits_per_sample, &ParseSigned, 1);

    cmdline->AddOptionValue('\0', "display_nits", "N",
                            "If set to a non-zero value, tone maps the image "
                            "the given peak display luminance.",
                            &display_nits, &ParseDouble, 1);

    cmdline->AddOptionValue(
        '\0', "color_space", "COLORSPACE_DESC",
        "Sets the desired output color space of the image. For example:\n"
        "      --color_space=RGB_D65_SRG_Per_SRG is sRGB with perceptual "
        "rendering intent\n"
        "      --color_space=RGB_D65_202_Rel_PeQ is Rec.2100 PQ with relative "
        "rendering intent",
        &color_space, &ParseString, 1);

    cmdline->AddOptionValue('s', "downsampling", "1|2|4|8",
                            "If the input JXL stream is contains hints for "
                            "target downsampling ratios,\n"
                            "    only decode what is needed to produce an "
                            "image intended for this downsampling ratio.",
                            &downsampling, &ParseUint32, 1);

    cmdline->AddOptionFlag('\0', "allow_partial_files",
                           "Allow decoding of truncated files.",
                           &allow_partial_files, &SetBooleanTrue, 1);

    if (jxl::extras::GetJPEGEncoder()) {
      cmdline->AddOptionFlag(
          'j', "pixels_to_jpeg",
          "By default, if the input JXL is a recompressed JPEG file, "
          "djxl reconstructs that JPEG file.\n"
          "    This flag causes the decoder to instead decode to pixels and "
          "encode a new (lossy) JPEG.",
          &pixels_to_jpeg, &SetBooleanTrue, 1);

      opt_jpeg_quality_id = cmdline->AddOptionValue(
          'q', "jpeg_quality", "N",
          "Sets the JPEG output quality, default is 95. "
          "Setting this option implies --pixels_to_jpeg.",
          &jpeg_quality, &ParseUnsigned, 1);
    }

    cmdline->AddHelpText("\nOptions for experimentation / benchmarking:", 2);

    cmdline->AddOptionValue('\0', "num_reps", "N",
                            "Sets the number of times to decompress the image. "
                            "Useful for benchmarking. Default is 1.",
                            &num_reps, &ParseUnsigned, 2);

    cmdline->AddOptionFlag('\0', "disable_output",
                           "No output file will be written (for benchmarking)",
                           &disable_output, &SetBooleanTrue, 2);

    cmdline->AddOptionFlag('\0', "use_sjpeg",
                           "Use sjpeg instead of libjpeg for JPEG output.",
                           &use_sjpeg, &SetBooleanTrue, 2);

    cmdline->AddOptionFlag('\0', "norender_spotcolors",
                           "Disables rendering of spot colors.",
                           &render_spotcolors, &SetBooleanFalse, 2);

    cmdline->AddOptionValue('\0', "preview_out", "FILENAME",
                            "If specified, writes the preview image to this "
                            "file.",
                            &preview_out, &ParseString, 2);

    cmdline->AddOptionValue(
        '\0', "icc_out", "FILENAME",
        "If specified, writes the ICC profile of the decoded image to "
        "this file.",
        &icc_out, &ParseString, 2);

    cmdline->AddOptionValue(
        '\0', "orig_icc_out", "FILENAME",
        "If specified, writes the ICC profile of the original image to "
        "this file\n"
        "    This can be different from the ICC profile of the "
        "decoded image if --color_space was specified.",
        &orig_icc_out, &ParseString, 2);

    cmdline->AddOptionValue('\0', "metadata_out", "FILENAME",
                            "If specified, writes metadata info to a JSON "
                            "file. Used by the conformance test script",
                            &metadata_out, &ParseString, 2);

    cmdline->AddOptionFlag('\0', "print_read_bytes",
                           "Print total number of decoded bytes.",
                           &print_read_bytes, &SetBooleanTrue, 2);
  }

  // Validate the passed arguments, checking whether all passed options are
  // compatible. Returns whether the validation was successful.
  bool ValidateArgs(const CommandLineParser& cmdline) {
    if (file_in == nullptr) {
      fprintf(stderr, "Missing INPUT filename.\n");
      return false;
    }
    if (num_threads < -1) {
      fprintf(
          stderr,
          "Invalid flag value for --num_threads: must be -1, 0 or positive.\n");
      return false;
    }
    return true;
  }

  const char* file_in = nullptr;
  const char* file_out = nullptr;
  bool version = false;
  bool verbose = false;
  size_t num_reps = 1;
  bool disable_output = false;
  int32_t num_threads = -1;
  int bits_per_sample = -1;
  double display_nits = 0.0;
  std::string color_space;
  uint32_t downsampling = 0;
  bool allow_partial_files = false;
  bool pixels_to_jpeg = false;
  size_t jpeg_quality = 95;
  bool use_sjpeg = false;
  bool render_spotcolors = true;
  std::string preview_out;
  std::string icc_out;
  std::string orig_icc_out;
  std::string metadata_out;
  bool print_read_bytes = false;
  bool quiet = false;
  // References (ids) of specific options to check if they were matched.
  CommandLineParser::OptionId opt_bits_per_sample_id = -1;
  CommandLineParser::OptionId opt_jpeg_quality_id = -1;
};

}  // namespace tools
}  // namespace jpegxl

namespace {

bool WriteOptionalOutput(const std::string& filename,
                         const std::vector<uint8_t>& bytes) {
  if (filename.empty() || bytes.empty()) {
    return true;
  }
  return jpegxl::tools::WriteFile(filename, bytes);
}

std::string Filename(const std::string& base, const std::string& extension,
                     int layer_index, int frame_index, int num_layers,
                     int num_frames) {
  if (base == "-") return "-";
  auto digits = [](int n) { return 1 + static_cast<int>(std::log10(n)); };
  std::string out = base;
  if (num_frames > 1) {
    std::vector<char> buf(2 + digits(num_frames));
    snprintf(buf.data(), buf.size(), "-%0*d", digits(num_frames), frame_index);
    out.append(buf.data());
  }
  if (num_layers > 1) {
    std::vector<char> buf(4 + digits(num_layers));
    snprintf(buf.data(), buf.size(), "-ec%0*d", digits(num_layers),
             layer_index);
    out.append(buf.data());
  }
  if (extension == ".ppm" && layer_index > 0) {
    out.append(".pgm");
  } else {
    out.append(extension);
  }
  return out;
}

bool DecompressJxlReconstructJPEG(const jpegxl::tools::DecompressArgs& args,
                                  const std::vector<uint8_t>& compressed,
                                  void* runner,
                                  std::vector<uint8_t>* jpeg_bytes,
                                  jpegxl::tools::SpeedStats* stats) {
  const double t0 = jxl::Now();
  jxl::extras::PackedPixelFile ppf;  // for JxlBasicInfo
  jxl::extras::JXLDecompressParams dparams;
  dparams.allow_partial_input = args.allow_partial_files;
  dparams.runner = JxlThreadParallelRunner;
  dparams.runner_opaque = runner;
  if (!jxl::extras::DecodeImageJXL(compressed.data(), compressed.size(),
                                   dparams, nullptr, &ppf, jpeg_bytes)) {
    return false;
  }
  const double t1 = jxl::Now();
  if (stats) {
    stats->NotifyElapsed(t1 - t0);
    stats->SetImageSize(ppf.info.xsize, ppf.info.ysize);
    stats->SetFileSize(jpeg_bytes->size());
  }
  return true;
}

bool DecompressJxlToPackedPixelFile(
    const jpegxl::tools::DecompressArgs& args,
    const std::vector<uint8_t>& compressed,
    const std::vector<JxlPixelFormat>& accepted_formats, void* runner,
    jxl::extras::PackedPixelFile* ppf, size_t* decoded_bytes,
    jpegxl::tools::SpeedStats* stats) {
  jxl::extras::JXLDecompressParams dparams;
  dparams.max_downsampling = args.downsampling;
  dparams.accepted_formats = accepted_formats;
  dparams.display_nits = args.display_nits;
  dparams.color_space = args.color_space;
  dparams.render_spotcolors = args.render_spotcolors;
  dparams.runner = JxlThreadParallelRunner;
  dparams.runner_opaque = runner;
  dparams.allow_partial_input = args.allow_partial_files;
  dparams.need_icc = !args.icc_out.empty();
  if (args.bits_per_sample == 0) {
    dparams.output_bitdepth.type = JXL_BIT_DEPTH_FROM_CODESTREAM;
  } else if (args.bits_per_sample > 0) {
    dparams.output_bitdepth.type = JXL_BIT_DEPTH_CUSTOM;
    dparams.output_bitdepth.bits_per_sample = args.bits_per_sample;
  }
  const double t0 = jxl::Now();
  if (!jxl::extras::DecodeImageJXL(compressed.data(), compressed.size(),
                                   dparams, decoded_bytes, ppf)) {
    return false;
  }
  const double t1 = jxl::Now();
  if (stats) {
    stats->NotifyElapsed(t1 - t0);
    stats->SetImageSize(ppf->info.xsize, ppf->info.ysize);
  }
  return true;
}

}  // namespace

int main(int argc, const char* argv[]) {
  std::string version = jpegxl::tools::CodecConfigString(JxlDecoderVersion());
  jpegxl::tools::DecompressArgs args;
  jpegxl::tools::CommandLineParser cmdline;
  args.AddCommandLineOptions(&cmdline);

  if (!cmdline.Parse(argc, argv)) {
    // Parse already printed the actual error cause.
    fprintf(stderr, "Use '%s -h' for more information\n", argv[0]);
    return EXIT_FAILURE;
  }

  if (args.version) {
    fprintf(stdout, "djxl %s\n", version.c_str());
    fprintf(stdout, "Copyright (c) the JPEG XL Project\n");
    return EXIT_SUCCESS;
  }
  if (!args.quiet) {
    fprintf(stderr, "JPEG XL decoder %s\n", version.c_str());
  }

  if (cmdline.HelpFlagPassed() || !args.file_in) {
    cmdline.PrintHelp();
    return EXIT_SUCCESS;
  }

  if (!args.ValidateArgs(cmdline)) {
    // ValidateArgs already printed the actual error cause.
    fprintf(stderr, "Use '%s -h' for more information\n", argv[0]);
    return EXIT_FAILURE;
  }

  std::vector<uint8_t> compressed;
  // Reading compressed JPEG XL input
  if (!jpegxl::tools::ReadFile(args.file_in, &compressed)) {
    fprintf(stderr, "couldn't load %s\n", args.file_in);
    return EXIT_FAILURE;
  }
  if (!args.quiet) {
    cmdline.VerbosePrintf(1, "Read %" PRIuS " compressed bytes.\n",
                          compressed.size());
  }

  if (!args.file_out && !args.disable_output) {
    std::cerr
        << "No output file specified and --disable_output flag not passed."
        << std::endl;
    return EXIT_FAILURE;
  }

  if (args.file_out && args.disable_output && !args.quiet) {
    fprintf(stderr,
            "Decoding will be performed, but the result will be discarded.\n");
  }

  std::string filename_out;
  std::string base;
  std::string extension;
  jxl::extras::Codec codec = jxl::extras::Codec::kUnknown;
  if (args.file_out && !args.disable_output) {
    filename_out = std::string(args.file_out);
    codec = jxl::extras::CodecFromPath(
        filename_out, /* bits_per_sample */ nullptr, &base, &extension);
  }
  if (codec == jxl::extras::Codec::kEXR) {
    std::string force_colorspace = "RGB_D65_SRG_Rel_Lin";
    if (!args.color_space.empty() && args.color_space != force_colorspace) {
      fprintf(stderr, "Warning: colorspace ignored for EXR output\n");
    }
    args.color_space = force_colorspace;
  }
  if (codec == jxl::extras::Codec::kPNM && extension != ".pfm" &&
      (args.opt_jpeg_quality_id < 0 ||
       !cmdline.GetOption(args.opt_jpeg_quality_id)->matched())) {
    args.bits_per_sample = 0;
  }

  jpegxl::tools::SpeedStats stats;
  size_t num_worker_threads = JxlThreadParallelRunnerDefaultNumWorkerThreads();
  {
    int64_t flag_num_worker_threads = args.num_threads;
    if (flag_num_worker_threads > -1) {
      num_worker_threads = flag_num_worker_threads;
    }
  }
  auto runner = JxlThreadParallelRunnerMake(
      /*memory_manager=*/nullptr, num_worker_threads);

  bool decode_to_pixels = (codec != jxl::extras::Codec::kJPG);
  if (args.opt_jpeg_quality_id >= 0 &&
      (args.pixels_to_jpeg ||
       cmdline.GetOption(args.opt_jpeg_quality_id)->matched())) {
    decode_to_pixels = true;
  }

  size_t num_reps = args.num_reps;
  if (!decode_to_pixels) {
    std::vector<uint8_t> bytes;
    for (size_t i = 0; i < num_reps; ++i) {
      if (!DecompressJxlReconstructJPEG(args, compressed, runner.get(), &bytes,
                                        &stats)) {
        if (bytes.empty()) {
          if (!args.quiet) {
            fprintf(stderr,
                    "Warning: could not decode losslessly to JPEG. Retrying "
                    "with --pixels_to_jpeg...\n");
          }
          decode_to_pixels = true;
          break;
        }
        return EXIT_FAILURE;
      }
    }
    if (!bytes.empty()) {
      if (!args.quiet) cmdline.VerbosePrintf(0, "Reconstructed to JPEG.\n");
      if (!filename_out.empty() &&
          !jpegxl::tools::WriteFile(base == "-" ? "-" : filename_out.c_str(),
                                    bytes)) {
        return EXIT_FAILURE;
      }
    }
  }
  if (decode_to_pixels) {
    std::vector<JxlPixelFormat> accepted_formats;
    std::unique_ptr<jxl::extras::Encoder> encoder;
    if (!filename_out.empty()) {
      encoder = jxl::extras::Encoder::FromExtension(extension);
      if (encoder == nullptr) {
        fprintf(stderr, "can't decode to the file extension '%s'\n",
                extension.c_str());
        return EXIT_FAILURE;
      }
      accepted_formats = encoder->AcceptedFormats();
    }
    jxl::extras::PackedPixelFile ppf;
    size_t decoded_bytes = 0;
    for (size_t i = 0; i < num_reps; ++i) {
      if (!DecompressJxlToPackedPixelFile(args, compressed, accepted_formats,
                                          runner.get(), &ppf, &decoded_bytes,
                                          &stats)) {
        fprintf(stderr, "DecompressJxlToPackedPixelFile failed\n");
        return EXIT_FAILURE;
      }
    }
    if (!args.quiet) cmdline.VerbosePrintf(0, "Decoded to pixels.\n");
    if (args.print_read_bytes) {
      fprintf(stderr, "Decoded bytes: %" PRIuS "\n", decoded_bytes);
    }
    if (encoder) {
      std::ostringstream os;
      os << args.jpeg_quality;
      encoder->SetOption("q", os.str());
    }
    if (encoder && args.use_sjpeg) {
      encoder->SetOption("jpeg_encoder", "sjpeg");
    }
    jxl::extras::EncodedImage encoded_image;
    if (encoder) {
      if (!args.quiet) cmdline.VerbosePrintf(2, "Encoding decoded image\n");
      if (!encoder->Encode(ppf, &encoded_image)) {
        fprintf(stderr, "Encode failed\n");
        return EXIT_FAILURE;
      }
    }
    size_t nlayers = 1 + encoded_image.extra_channel_bitstreams.size();
    size_t nframes = encoded_image.bitstreams.size();
    for (size_t i = 0; i < nlayers; ++i) {
      for (size_t j = 0; j < nframes; ++j) {
        const std::vector<uint8_t>& bitstream =
            (i == 0 ? encoded_image.bitstreams[j]
                    : encoded_image.extra_channel_bitstreams[i - 1][j]);
        std::string fn = Filename(base, extension, i, j, nlayers, nframes);
        if (!jpegxl::tools::WriteFile(fn.c_str(), bitstream)) {
          return EXIT_FAILURE;
        }
        if (!args.quiet)
          cmdline.VerbosePrintf(1, "Wrote output to %s\n", fn.c_str());
      }
    }
    if (!WriteOptionalOutput(args.preview_out,
                             encoded_image.preview_bitstream) ||
        !WriteOptionalOutput(args.icc_out, ppf.icc) ||
        !WriteOptionalOutput(args.orig_icc_out, ppf.orig_icc) ||
        !WriteOptionalOutput(args.metadata_out, encoded_image.metadata)) {
      return EXIT_FAILURE;
    }
  }
  if (!args.quiet) {
    stats.Print(num_worker_threads);
  }
  return EXIT_SUCCESS;
}
