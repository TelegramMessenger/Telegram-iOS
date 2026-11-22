// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/decode.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <memory>
#include <mutex>
#include <numeric>
#include <string>
#include <utility>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/extras/dec/color_hints.h"
#include "lib/extras/enc/apng.h"
#include "lib/extras/metrics.h"
#include "lib/extras/time.h"
#include "lib/jxl/alpha.h"
#include "lib/jxl/base/cache_aligned.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/jpeg/enc_jpeg_data.h"
#include "tools/benchmark/benchmark_args.h"
#include "tools/benchmark/benchmark_codec.h"
#include "tools/benchmark/benchmark_file_io.h"
#include "tools/benchmark/benchmark_stats.h"
#include "tools/benchmark/benchmark_utils.h"
#include "tools/codec_config.h"
#include "tools/file_io.h"
#include "tools/speed_stats.h"
#include "tools/ssimulacra2.h"
#include "tools/thread_pool_internal.h"

namespace jpegxl {
namespace tools {
namespace {

using ::jxl::ButteraugliParams;
using ::jxl::CodecInOut;
using ::jxl::ColorEncoding;
using ::jxl::Image3F;
using ::jxl::ImageBundle;
using ::jxl::ImageF;
using ::jxl::PaddedBytes;
using ::jxl::Rng;
using ::jxl::Status;
using ::jxl::ThreadPool;

Status WriteImage(Image3F&& image, ThreadPool* pool,
                  const std::string& filename) {
  CodecInOut io;
  io.metadata.m.SetUintSamples(8);
  io.metadata.m.color_encoding = ColorEncoding::SRGB();
  io.SetFromImage(std::move(image), io.metadata.m.color_encoding);
  std::vector<uint8_t> encoded;
  return Encode(io, filename, &encoded, pool) && WriteFile(filename, encoded);
}

Status ReadPNG(const std::string& filename, Image3F* image) {
  CodecInOut io;
  std::vector<uint8_t> encoded;
  JXL_CHECK(ReadFile(filename, &encoded));
  JXL_CHECK(jxl::SetFromBytes(jxl::Span<const uint8_t>(encoded),
                              jxl::extras::ColorHints(), &io));
  *image = Image3F(io.xsize(), io.ysize());
  CopyImageTo(*io.Main().color(), image);
  return true;
}

std::string CodecToExtension(std::string codec_name, char sep) {
  std::string result;
  // Add in the parameters of the codec_name in reverse order, so that the
  // name of the file format (e.g. jxl) is last.
  int pos = static_cast<int>(codec_name.size()) - 1;
  while (pos > 0) {
    int prev = codec_name.find_last_of(sep, pos);
    if (prev > pos) prev = -1;
    result += '.' + codec_name.substr(prev + 1, pos - prev);
    pos = prev - 1;
  }
  return result;
}

void DoCompress(const std::string& filename, const CodecInOut& io,
                const std::vector<std::string>& extra_metrics_commands,
                ImageCodec* codec, ThreadPool* inner_pool,
                std::vector<uint8_t>* compressed, BenchmarkStats* s) {
  ++s->total_input_files;

  if (io.frames.size() != 1) {
    // Multiple frames not supported (io.xsize() will checkfail)
    s->total_errors++;
    if (!Args()->silent_errors) {
      JXL_WARNING("multiframe input image not supported %s", filename.c_str());
    }
    return;
  }
  const size_t xsize = io.xsize();
  const size_t ysize = io.ysize();
  const size_t input_pixels = xsize * ysize;

  jpegxl::tools::SpeedStats speed_stats;
  jpegxl::tools::SpeedStats::Summary summary;

  bool valid = true;  // false if roundtrip, encoding or decoding errors occur.

  if (!Args()->decode_only && (io.xsize() == 0 || io.ysize() == 0)) {
    // This means the benchmark couldn't load the image, e.g. due to invalid
    // ICC profile. Warning message about that was already printed. Continue
    // this function to indicate it as error in the stats.
    valid = false;
  }

  std::string ext = FileExtension(filename);
  if (valid && !Args()->decode_only) {
    for (size_t i = 0; i < Args()->encode_reps; ++i) {
      if (codec->CanRecompressJpeg() && (ext == ".jpg" || ext == ".jpeg")) {
        std::vector<uint8_t> data_in;
        JXL_CHECK(ReadFile(filename, &data_in));
        JXL_CHECK(
            codec->RecompressJpeg(filename, data_in, compressed, &speed_stats));
      } else {
        Status status = codec->Compress(filename, &io, inner_pool, compressed,
                                        &speed_stats);
        if (!status) {
          valid = false;
          if (!Args()->silent_errors) {
            std::string message = codec->GetErrorMessage();
            if (!message.empty()) {
              fprintf(stderr, "Error in %s codec: %s\n",
                      codec->description().c_str(), message.c_str());
            } else {
              fprintf(stderr, "Error in %s codec\n",
                      codec->description().c_str());
            }
          }
        }
      }
    }
    JXL_CHECK(speed_stats.GetSummary(&summary));
    s->total_time_encode += summary.central_tendency;
  }

  if (valid && Args()->decode_only) {
    std::vector<uint8_t> data_in;
    JXL_CHECK(ReadFile(filename, &data_in));
    compressed->insert(compressed->end(), data_in.begin(), data_in.end());
  }

  // Decompress
  CodecInOut io2;
  io2.metadata.m = io.metadata.m;
  if (valid) {
    speed_stats = jpegxl::tools::SpeedStats();
    for (size_t i = 0; i < Args()->decode_reps; ++i) {
      if (!codec->Decompress(filename, Span<const uint8_t>(*compressed),
                             inner_pool, &io2, &speed_stats)) {
        if (!Args()->silent_errors) {
          fprintf(stderr,
                  "%s failed to decompress encoded image. Original source:"
                  " %s\n",
                  codec->description().c_str(), filename.c_str());
        }
        valid = false;
      }
      // TODO(veluca): this is a hack. codec->Decompress should set the bitdepth
      // correctly, but for jxl it currently sets it from the pixel format (i.e.
      // 32-bit float).
      io2.metadata.m.bit_depth = io.metadata.m.bit_depth;
    }
    for (const auto& frame : io2.frames) {
      s->total_input_pixels += frame.color().xsize() * frame.color().ysize();
    }
    JXL_CHECK(speed_stats.GetSummary(&summary));
    s->total_time_decode += summary.central_tendency;
  }

  std::string name = FileBaseName(filename);
  std::string codec_name = codec->description();

  if (!valid) {
    s->total_errors++;
  }

  if (io.frames.size() != io2.frames.size()) {
    if (!Args()->silent_errors) {
      // Animated gifs not supported yet?
      fprintf(stderr,
              "Frame sizes not equal, is this an animated gif? %s %s %" PRIuS
              " %" PRIuS "\n",
              codec_name.c_str(), name.c_str(), io.frames.size(),
              io2.frames.size());
    }
    valid = false;
  }

  bool skip_butteraugli = Args()->skip_butteraugli || Args()->decode_only;
  ImageF distmap;
  float max_distance = 1.0f;

  if (valid && !skip_butteraugli) {
    JXL_ASSERT(io.frames.size() == io2.frames.size());
    for (size_t i = 0; i < io.frames.size(); i++) {
      const ImageBundle& ib1 = io.frames[i];
      ImageBundle& ib2 = io2.frames[i];

      // Verify output
      float distance;
      if (SameSize(ib1, ib2)) {
        ButteraugliParams params;
        if (ib1.metadata()->IntensityTarget() !=
            ib2.metadata()->IntensityTarget()) {
          fprintf(stderr,
                  "WARNING: input and output images have different intensity "
                  "targets");
        }
        params.intensity_target = ib1.metadata()->IntensityTarget();
        // Hack the default intensity target value to be 80.0, the intensity
        // target of sRGB images and a more reasonable viewing default than
        // JPEG XL file format's default.
        if (fabs(params.intensity_target - 255.0f) < 1e-3) {
          params.intensity_target = 80.0;
        }
        distance =
            ButteraugliDistance(ib1, ib2, params, jxl::GetJxlCms(), &distmap,
                                inner_pool, codec->IgnoreAlpha());
      } else {
        // TODO(veluca): re-upsample and compute proper distance.
        distance = 1e+4f;
        distmap = ImageF(1, 1);
        distmap.Row(0)[0] = distance;
      }
      // Update stats
      s->psnr +=
          compressed->empty()
              ? 0
              : jxl::ComputePSNR(ib1, ib2, jxl::GetJxlCms()) * input_pixels;
      s->distance_p_norm +=
          ComputeDistanceP(distmap, ButteraugliParams(), Args()->error_pnorm) *
          input_pixels;
      s->ssimulacra2 += ComputeSSIMULACRA2(ib1, ib2).Score() * input_pixels;
      s->max_distance = std::max(s->max_distance, distance);
      s->distances.push_back(distance);
      max_distance = std::max(max_distance, distance);
    }
  }

  s->total_compressed_size += compressed->size();
  s->total_adj_compressed_size += compressed->size() * max_distance;
  codec->GetMoreStats(s);

  if (io2.frames.size() == 1 &&
      (Args()->save_compressed || Args()->save_decompressed)) {
    JXL_ASSERT(io2.frames.size() == 1);
    ImageBundle& ib2 = io2.Main();

    // By default the benchmark will save the image after roundtrip with the
    // same color encoding as the image before roundtrip. Not all codecs
    // necessarily preserve the amount of channels (1 for gray, 3 for RGB)
    // though, since not all image formats necessarily allow a way to remember
    // what amount of channels you happened to give the benchmark codec
    // input (say, an RGB-only format) and that is fine since in the end what
    // matters is that the pixels look the same on a 3-channel RGB monitor
    // while using grayscale encoding is an internal compression optimization.
    // If that is the case, output with the current color model instead,
    // because CodecInOut does not automatically convert between 1 or 3
    // channels, and giving a ColorEncoding  with a different amount of
    // channels is not allowed.
    const ColorEncoding* c_desired =
        (ib2.metadata()->color_encoding.Channels() ==
         ib2.c_current().Channels())
            ? &ib2.metadata()->color_encoding
            : &ib2.c_current();
    // Allow overriding via --output_encoding.
    if (!Args()->output_description.empty()) {
      c_desired = &Args()->output_encoding;
    }

    std::string dir = FileDirName(filename);
    std::string outdir =
        Args()->output_dir.empty() ? dir + "/out" : Args()->output_dir;
    std::string compressed_fn =
        outdir + "/" + name + CodecToExtension(codec_name, ':');
    std::string decompressed_fn = compressed_fn + Args()->output_extension;
    std::string heatmap_fn;
    if (jxl::extras::GetAPNGEncoder()) {
      heatmap_fn = compressed_fn + ".heatmap.png";
    } else {
      heatmap_fn = compressed_fn + ".heatmap.ppm";
    }
    JXL_CHECK(MakeDir(outdir));
    if (Args()->save_compressed) {
      JXL_CHECK(WriteFile(compressed_fn, *compressed));
    }
    if (Args()->save_decompressed && valid) {
      // For verifying HDR: scale output.
      if (Args()->mul_output != 0.0) {
        fprintf(stderr, "WARNING: scaling outputs by %f\n", Args()->mul_output);
        JXL_CHECK(ib2.TransformTo(ColorEncoding::LinearSRGB(ib2.IsGray()),
                                  jxl::GetJxlCms(), inner_pool));
        ScaleImage(static_cast<float>(Args()->mul_output), ib2.color());
      }

      std::vector<uint8_t> encoded;
      JXL_CHECK(Encode(io2, *c_desired,
                       ib2.metadata()->bit_depth.bits_per_sample,
                       decompressed_fn, &encoded));
      JXL_CHECK(WriteFile(decompressed_fn, encoded));
      if (!skip_butteraugli) {
        float good = Args()->heatmap_good > 0.0f
                         ? Args()->heatmap_good
                         : jxl::ButteraugliFuzzyInverse(1.5);
        float bad = Args()->heatmap_bad > 0.0f
                        ? Args()->heatmap_bad
                        : jxl::ButteraugliFuzzyInverse(0.5);
        if (Args()->save_heatmap) {
          JXL_CHECK(WriteImage(CreateHeatMapImage(distmap, good, bad),
                               inner_pool, heatmap_fn));
        }
      }
    }
  }
  if (!extra_metrics_commands.empty()) {
    CodecInOut in_copy;
    in_copy.SetFromImage(std::move(*io.Main().Copy().color()),
                         io.Main().c_current());
    TemporaryFile tmp_in("original", "pfm");
    TemporaryFile tmp_out("decoded", "pfm");
    TemporaryFile tmp_res("result", "txt");
    std::string tmp_in_fn, tmp_out_fn, tmp_res_fn;
    JXL_CHECK(tmp_in.GetFileName(&tmp_in_fn));
    JXL_CHECK(tmp_out.GetFileName(&tmp_out_fn));
    JXL_CHECK(tmp_res.GetFileName(&tmp_res_fn));

    // Convert everything to non-linear SRGB - this is what most metrics expect.
    const ColorEncoding& c_desired = ColorEncoding::SRGB(io.Main().IsGray());
    std::vector<uint8_t> encoded;
    JXL_CHECK(Encode(io, c_desired, io.metadata.m.bit_depth.bits_per_sample,
                     tmp_in_fn, &encoded));
    JXL_CHECK(WriteFile(tmp_in_fn, encoded));
    JXL_CHECK(Encode(io2, c_desired, io.metadata.m.bit_depth.bits_per_sample,
                     tmp_out_fn, &encoded));
    JXL_CHECK(WriteFile(tmp_out_fn, encoded));
    if (io.metadata.m.IntensityTarget() != io2.metadata.m.IntensityTarget()) {
      fprintf(stderr,
              "WARNING: original and decoded have different intensity targets "
              "(%f vs. %f).\n",
              io.metadata.m.IntensityTarget(),
              io2.metadata.m.IntensityTarget());
    }
    std::string intensity_target;
    {
      std::ostringstream intensity_target_oss;
      intensity_target_oss << io.metadata.m.IntensityTarget();
      intensity_target = intensity_target_oss.str();
    }
    for (size_t i = 0; i < extra_metrics_commands.size(); i++) {
      float res = nanf("");
      bool error = false;
      if (RunCommand(extra_metrics_commands[i],
                     {tmp_in_fn, tmp_out_fn, tmp_res_fn, intensity_target})) {
        FILE* f = fopen(tmp_res_fn.c_str(), "r");
        if (fscanf(f, "%f", &res) != 1) {
          error = true;
        }
        fclose(f);
      } else {
        error = true;
      }
      if (error) {
        fprintf(stderr,
                "WARNING: Computation of metric with command %s failed\n",
                extra_metrics_commands[i].c_str());
      }
      s->extra_metrics.push_back(res);
    }
  }

  if (Args()->show_progress) {
    fprintf(stderr, ".");
    fflush(stderr);
  }
}

// Makes a base64 data URI for embedded image in HTML
std::string Base64Image(const std::string& filename) {
  PaddedBytes bytes;
  if (!ReadFile(filename, &bytes)) {
    return "";
  }
  static const char* symbols =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string result;
  for (size_t i = 0; i < bytes.size(); i += 3) {
    uint8_t o0 = bytes[i + 0];
    uint8_t o1 = (i + 1 < bytes.size()) ? bytes[i + 1] : 0;
    uint8_t o2 = (i + 2 < bytes.size()) ? bytes[i + 2] : 0;
    uint32_t value = (o0 << 16) | (o1 << 8) | o2;
    for (size_t j = 0; j < 4; j++) {
      result += (i + j <= bytes.size()) ? symbols[(value >> (6 * (3 - j))) & 63]
                                        : '=';
    }
  }
  // NOTE: Chrome supports max 2MB of data this way for URLs, but appears to
  // support larger images anyway as long as it's embedded in the HTML file
  // itself. If more data is needed, use createObjectURL.
  return "data:image;base64," + result;
}

struct Task {
  ImageCodecPtr codec;
  size_t idx_image;
  size_t idx_method;
  const CodecInOut* image;
  BenchmarkStats stats;
};

void WriteHtmlReport(const std::string& codec_desc,
                     const std::vector<std::string>& fnames,
                     const std::vector<const Task*>& tasks,
                     const std::vector<const CodecInOut*>& images,
                     bool add_heatmap, bool self_contained) {
  std::string toggle_js =
      "<script type=\"text/javascript\">\n"
      "  var codecname = '" +
      codec_desc + "';\n";
  if (add_heatmap) {
    toggle_js += R"(
  var maintitle = codecname + ' - click images to toggle, press space to' +
      ' toggle all, h to toggle all heatmaps. Zoom in with CTRL+wheel or' +
      ' CTRL+plus.';
  document.title = maintitle;
  var counter = [];
  function setState(i, s) {
    var preview = document.getElementById("preview" + i);
    var orig = document.getElementById("orig" + i);
    var hm = document.getElementById("hm" + i);
    if (s == 0) {
      preview.style.display = 'none';
      orig.style.display = 'block';
      hm.style.display = 'none';
    } else if (s == 1) {
      preview.style.display = 'block';
      orig.style.display = 'none';
      hm.style.display = 'none';
    } else if (s == 2) {
      preview.style.display = 'none';
      orig.style.display = 'none';
      hm.style.display = 'block';
    }
  }
  function toggle(i) {
    for (index = counter.length; index <= i; index++) {
      counter.push(1);
    }
    setState(i, counter[i]);
    counter[i] = (counter[i] + 1) % 3;
    document.title = maintitle;
  }
  var toggleall_state = 1;
  document.body.onkeydown = function(e) {
    // space (32) to toggle orig/compr, 'h' (72) to toggle heatmap/compr
    if (e.keyCode == 32 || e.keyCode == 72) {
      var divs = document.getElementsByTagName('div');
      var key_state = (e.keyCode == 32) ? 0 : 2;
      toggleall_state = (toggleall_state == key_state) ? 1 : key_state;
      document.title = codecname + ' - ' + (toggleall_state == 0 ?
          'originals' : (toggleall_state == 1 ? 'compressed' : 'heatmaps'));
      for (var i = 0; i < divs.length; i++) {
        setState(i, toggleall_state);
      }
      return false;
    }
  };
</script>
)";
  } else {
    toggle_js += R"(
  var maintitle = codecname + ' - click images to toggle, press space to' +
      ' toggle all. Zoom in with CTRL+wheel or CTRL+plus.';
  document.title = maintitle;
  var counter = [];
  function setState(i, s) {
    var preview = document.getElementById("preview" + i);
    var orig = document.getElementById("orig" + i);
    if (s == 0) {
      preview.style.display = 'none';
      orig.style.display = 'block';
    } else if (s == 1) {
      preview.style.display = 'block';
      orig.style.display = 'none';
    }
  }
  function toggle(i) {
    for (index = counter.length; index <= i; index++) {
      counter.push(1);
    }
    setState(i, counter[i]);
    counter[i] = 1 - counter[i];
    document.title = maintitle;
  }
  var toggleall_state = 1;
  document.body.onkeydown = function(e) {
    // space (32) to toggle orig/compr
    if (e.keyCode == 32) {
      var divs = document.getElementsByTagName('div');
      toggleall_state = 1 - toggleall_state;
      document.title = codecname + ' - ' + (toggleall_state == 0 ?
          'originals' : 'compressed');
      for (var i = 0; i < divs.length; i++) {
        setState(i, toggleall_state);
      }
      return false;
    }
  };
</script>
)";
  }
  std::string out_html;
  std::string outdir;
  out_html += "<body bgcolor=\"#000\">\n";
  out_html += "<style>img { image-rendering: pixelated; }</style>\n";
  std::string codec_name = codec_desc;
  // Make compatible for filename
  std::replace(codec_name.begin(), codec_name.end(), ':', '_');
  for (size_t i = 0; i < fnames.size(); ++i) {
    std::string name = FileBaseName(fnames[i]);
    std::string dir = FileDirName(fnames[i]);
    outdir = Args()->output_dir.empty() ? dir + "/out" : Args()->output_dir;
    std::string name_out = name + CodecToExtension(codec_name, '_');
    if (Args()->html_report_use_decompressed) {
      name_out += Args()->output_extension;
    }
    std::string heatmap_out =
        name + CodecToExtension(codec_name, '_') + ".heatmap.png";

    std::string fname_orig = fnames[i];
    std::string fname_out = outdir + "/" + name_out;
    std::string fname_heatmap = outdir + "/" + heatmap_out;
    std::string url_orig = Args()->originals_url.empty()
                               ? ("file://" + fnames[i])
                               : (Args()->originals_url + "/" + name);
    std::string url_out = name_out;
    std::string url_heatmap = heatmap_out;
    if (self_contained) {
      url_orig = Base64Image(fname_orig);
      url_out = Base64Image(fname_out);
      url_heatmap = Base64Image(fname_heatmap);
    }
    std::string number = StringPrintf("%" PRIuS, i);
    const CodecInOut& image = *images[i];
    size_t xsize = image.frames.size() == 1 ? image.xsize() : 0;
    size_t ysize = image.frames.size() == 1 ? image.ysize() : 0;
    std::string html_width = StringPrintf("%" PRIuS "px", xsize);
    std::string html_height = StringPrintf("%" PRIuS "px", ysize);
    double bpp = tasks[i]->stats.total_compressed_size * 8.0 /
                 tasks[i]->stats.total_input_pixels;
    double pnorm =
        tasks[i]->stats.distance_p_norm / tasks[i]->stats.total_input_pixels;
    double max_dist = tasks[i]->stats.max_distance;
    std::string compressed_title = StringPrintf(
        "compressed. bpp: %f, pnorm: %f, max dist: %f", bpp, pnorm, max_dist);
    out_html += "<div onclick=\"toggle(" + number +
                ");\" style=\"display:inline-block;width:" + html_width +
                ";height:" + html_height +
                ";\">\n"
                "  <img title=\"" +
                compressed_title + "\" id=\"preview" + number + "\" src=";
    out_html += "\"" + url_out + "\"style=\"display:block;\"/>\n";
    out_html += "  <img title=\"original\" id=\"orig" + number + "\" src=";
    out_html += "\"" + url_orig + "\"style=\"display:none;\"/>\n";
    if (add_heatmap) {
      out_html = "  <img title=\"heatmap\" id=\"hm" + number + "\" src=";
      out_html += "\"" + url_heatmap + "\"style=\"display:none;\"/>\n";
    }
    out_html += "</div>\n";
  }
  out_html += "</body>\n";
  out_html += toggle_js;
  JXL_CHECK(WriteFile(outdir + "/index." + codec_name + ".html", out_html));
}

// Prints the detailed and aggregate statistics, in the correct order but as
// soon as possible when multithreaded tasks are done.
struct StatPrinter {
  StatPrinter(const std::vector<std::string>& methods,
              const std::vector<std::string>& extra_metrics_names,
              const std::vector<std::string>& fnames,
              const std::vector<Task>& tasks)
      : methods_(&methods),
        extra_metrics_names_(&extra_metrics_names),
        fnames_(&fnames),
        tasks_(&tasks),
        tasks_done_(0),
        stats_printed_(0),
        details_printed_(0) {
    stats_done_.resize(methods.size(), 0);
    details_done_.resize(tasks.size(), 0);
    max_fname_width_ = 0;
    for (const auto& fname : fnames) {
      max_fname_width_ = std::max(max_fname_width_, FileBaseName(fname).size());
    }
    max_method_width_ = 0;
    for (const auto& method : methods) {
      max_method_width_ =
          std::max(max_method_width_, FileBaseName(method).size());
    }
  }

  void TaskDone(size_t task_index, const Task& t) {
    std::lock_guard<std::mutex> guard(mutex);
    tasks_done_++;
    if (Args()->print_details || Args()->show_progress) {
      if (Args()->print_details) {
        // Render individual results as soon as they are ready and all previous
        // ones in task order are ready.
        details_done_[task_index] = 1;
        if (task_index == details_printed_) {
          while (details_printed_ < tasks_->size() &&
                 details_done_[details_printed_]) {
            PrintDetails((*tasks_)[details_printed_]);
            details_printed_++;
          }
        }
      }
      // When using "show_progress" or "print_details", the table must be
      // rendered at the very end, else the details or progress would be
      // rendered in-between the table rows.
      if (tasks_done_ == tasks_->size()) {
        PrintStatsHeader();
        for (size_t i = 0; i < methods_->size(); i++) {
          PrintStats((*methods_)[i], i);
        }
        PrintStatsFooter();
      }
    } else {
      if (tasks_done_ == 1) {
        PrintStatsHeader();
      }
      // Render lines of the table as soon as it is ready and all previous
      // lines have been printed.
      stats_done_[t.idx_method]++;
      if (stats_done_[t.idx_method] == fnames_->size() &&
          t.idx_method == stats_printed_) {
        while (stats_printed_ < stats_done_.size() &&
               stats_done_[stats_printed_] == fnames_->size()) {
          PrintStats((*methods_)[stats_printed_], stats_printed_);
          stats_printed_++;
        }
      }
      if (tasks_done_ == tasks_->size()) {
        PrintStatsFooter();
      }
    }
  }

  void PrintDetails(const Task& t) {
    double comp_bpp =
        t.stats.total_compressed_size * 8.0 / t.stats.total_input_pixels;
    double p_norm = t.stats.distance_p_norm / t.stats.total_input_pixels;
    double psnr = t.stats.psnr / t.stats.total_input_pixels;
    double ssimulacra2 = t.stats.ssimulacra2 / t.stats.total_input_pixels;
    double bpp_p_norm = p_norm * comp_bpp;

    const double adj_comp_bpp =
        t.stats.total_adj_compressed_size * 8.0 / t.stats.total_input_pixels;

    size_t pixels = t.stats.total_input_pixels;

    const double enc_mps =
        t.stats.total_input_pixels / (1000000.0 * t.stats.total_time_encode);
    const double dec_mps =
        t.stats.total_input_pixels / (1000000.0 * t.stats.total_time_decode);
    if (Args()->print_details_csv) {
      printf("%s,%s,%" PRIdS ",%" PRIdS ",%" PRIdS
             ",%.8f,%.8f,%.8f,%.8f,%.8f,%.8f,%.8f,%.8f",
             (*methods_)[t.idx_method].c_str(),
             FileBaseName((*fnames_)[t.idx_image]).c_str(),
             t.stats.total_errors, t.stats.total_compressed_size, pixels,
             enc_mps, dec_mps, comp_bpp, t.stats.max_distance, psnr, p_norm,
             bpp_p_norm, adj_comp_bpp);
      for (float m : t.stats.extra_metrics) {
        printf(",%.8f", m);
      }
      printf("\n");
    } else {
      printf("%s", (*methods_)[t.idx_method].c_str());
      for (size_t i = (*methods_)[t.idx_method].size(); i <= max_method_width_;
           i++) {
        printf(" ");
      }
      printf("%s", FileBaseName((*fnames_)[t.idx_image]).c_str());
      for (size_t i = FileBaseName((*fnames_)[t.idx_image]).size();
           i <= max_fname_width_; i++) {
        printf(" ");
      }
      printf(
          "error:%" PRIdS "    size:%8" PRIdS "    pixels:%9" PRIdS
          "    enc_speed:%8.8f    dec_speed:%8.8f    bpp:%10.8f    dist:%10.8f"
          "    psnr:%10.8f    ssimulacra2:%.2f   p:%10.8f    bppp:%10.8f    "
          "qabpp:%10.8f ",
          t.stats.total_errors, t.stats.total_compressed_size, pixels, enc_mps,
          dec_mps, comp_bpp, t.stats.max_distance, psnr, ssimulacra2, p_norm,
          bpp_p_norm, adj_comp_bpp);
      for (size_t i = 0; i < t.stats.extra_metrics.size(); i++) {
        printf(" %s:%.8f", (*extra_metrics_names_)[i].c_str(),
               t.stats.extra_metrics[i]);
      }
      printf("\n");
    }
    fflush(stdout);
  }

  void PrintStats(const std::string& method, size_t idx_method) {
    // Assimilate all tasks with the same idx_method.
    BenchmarkStats method_stats;
    std::vector<const CodecInOut*> images;
    std::vector<const Task*> tasks;
    for (const Task& t : *tasks_) {
      if (t.idx_method == idx_method) {
        method_stats.Assimilate(t.stats);
        images.push_back(t.image);
        tasks.push_back(&t);
      }
    }

    std::string out;

    method_stats.PrintMoreStats();  // not concurrent
    out += method_stats.PrintLine(method, fnames_->size());

    if (Args()->write_html_report) {
      WriteHtmlReport(method, *fnames_, tasks, images,
                      Args()->save_heatmap && Args()->html_report_add_heatmap,
                      Args()->html_report_self_contained);
    }

    stats_aggregate_.push_back(
        method_stats.ComputeColumns(method, fnames_->size()));

    printf("%s", out.c_str());
    fflush(stdout);
  }

  void PrintStatsHeader() {
    if (Args()->markdown) {
      if (Args()->show_progress) {
        fprintf(stderr, "\n");
        fflush(stderr);
      }
      printf("```\n");
    }
    if (fnames_->size() == 1) printf("%s\n", (*fnames_)[0].c_str());
    printf("%s", PrintHeader(*extra_metrics_names_).c_str());
    fflush(stdout);
  }

  void PrintStatsFooter() {
    printf(
        "%s",
        PrintAggregate(extra_metrics_names_->size(), stats_aggregate_).c_str());
    if (Args()->markdown) printf("```\n");
    printf("\n");
    fflush(stdout);
  }

  const std::vector<std::string>* methods_;
  const std::vector<std::string>* extra_metrics_names_;
  const std::vector<std::string>* fnames_;
  const std::vector<Task>* tasks_;

  size_t tasks_done_;

  size_t stats_printed_;
  std::vector<size_t> stats_done_;

  size_t details_printed_;
  std::vector<size_t> details_done_;

  size_t max_fname_width_;
  size_t max_method_width_;

  std::vector<std::vector<ColumnValue>> stats_aggregate_;

  std::mutex mutex;
};

class Benchmark {
  using StringVec = std::vector<std::string>;

 public:
  // Return the exit code of the program.
  static int Run() {
    int ret = EXIT_SUCCESS;
    {
      const StringVec methods = GetMethods();
      const StringVec extra_metrics_names = GetExtraMetricsNames();
      const StringVec extra_metrics_commands = GetExtraMetricsCommands();
      const StringVec fnames = GetFilenames();
      // (non-const because Task.stats are updated)
      std::vector<Task> tasks = CreateTasks(methods, fnames);

      std::unique_ptr<ThreadPoolInternal> pool;
      std::vector<std::unique_ptr<ThreadPoolInternal>> inner_pools;
      InitThreads(tasks.size(), &pool, &inner_pools);

      const std::vector<CodecInOut> loaded_images = LoadImages(fnames, &*pool);

      if (RunTasks(methods, extra_metrics_names, extra_metrics_commands, fnames,
                   loaded_images, &*pool, inner_pools, &tasks) != 0) {
        ret = EXIT_FAILURE;
        if (!Args()->silent_errors) {
          fprintf(stderr, "There were error(s) in the benchmark.\n");
        }
      }
    }

    jxl::CacheAligned::PrintStats();
    return ret;
  }

 private:
  static size_t NumOuterThreads(const size_t num_hw_threads,
                                const size_t num_tasks) {
    // Default to #cores
    size_t num_threads = num_hw_threads;
    if (Args()->num_threads >= 0) {
      num_threads = static_cast<size_t>(Args()->num_threads);
    }

    // As a safety precaution, limit the number of threads to 4x the number of
    // available CPUs.
    num_threads =
        std::min<size_t>(num_threads, 4 * std::thread::hardware_concurrency());

    // Don't create more threads than there are tasks (pointless/wasteful).
    num_threads = std::min(num_threads, num_tasks);

    // Just one thread is counterproductive.
    if (num_threads == 1) num_threads = 0;

    return num_threads;
  }

  static int NumInnerThreads(const size_t num_hw_threads,
                             const size_t num_threads) {
    size_t num_inner;

    // Default: distribute remaining cores among tasks.
    if (Args()->inner_threads < 0) {
      if (num_threads == 0) {
        num_inner = num_hw_threads;
      } else if (num_hw_threads <= num_threads) {
        num_inner = 1;
      } else {
        num_inner = (num_hw_threads - num_threads) / num_threads;
      }
    } else {
      num_inner = static_cast<size_t>(Args()->inner_threads);
    }

    // Just one thread is counterproductive.
    if (num_inner == 1) num_inner = 0;

    return num_inner;
  }

  static void InitThreads(
      size_t num_tasks, std::unique_ptr<ThreadPoolInternal>* pool,
      std::vector<std::unique_ptr<ThreadPoolInternal>>* inner_pools) {
    const size_t num_hw_threads = std::thread::hardware_concurrency();
    const size_t num_threads = NumOuterThreads(num_hw_threads, num_tasks);
    const size_t num_inner = NumInnerThreads(num_hw_threads, num_threads);

    fprintf(stderr,
            "%" PRIuS " total threads, %" PRIuS " tasks, %" PRIuS
            " threads, %" PRIuS " inner threads\n",
            num_hw_threads, num_tasks, num_threads, num_inner);

    pool->reset(new ThreadPoolInternal(num_threads));
    // Main thread OR worker threads in pool each get a possibly empty nested
    // pool (helps use all available cores when #tasks < #threads)
    for (size_t i = 0; i < std::max<size_t>(num_threads, 1); ++i) {
      inner_pools->emplace_back(new ThreadPoolInternal(num_inner));
    }
  }

  static StringVec GetMethods() {
    StringVec methods = SplitString(Args()->codec, ',');
    for (auto it = methods.begin(); it != methods.end();) {
      if (it->empty()) {
        it = methods.erase(it);
      } else {
        ++it;
      }
    }
    return methods;
  }

  static StringVec GetExtraMetricsNames() {
    StringVec metrics = SplitString(Args()->extra_metrics, ',');
    for (auto it = metrics.begin(); it != metrics.end();) {
      if (it->empty()) {
        it = metrics.erase(it);
      } else {
        *it = SplitString(*it, ':')[0];
        ++it;
      }
    }
    return metrics;
  }

  static StringVec GetExtraMetricsCommands() {
    StringVec metrics = SplitString(Args()->extra_metrics, ',');
    for (auto it = metrics.begin(); it != metrics.end();) {
      if (it->empty()) {
        it = metrics.erase(it);
      } else {
        auto s = SplitString(*it, ':');
        JXL_CHECK(s.size() == 2);
        *it = s[1];
        ++it;
      }
    }
    return metrics;
  }

  static StringVec SampleFromInput(const StringVec& fnames,
                                   const std::string& sample_tmp_dir,
                                   int num_samples, size_t size) {
    JXL_CHECK(!sample_tmp_dir.empty());
    fprintf(stderr, "Creating samples of %" PRIuS "x%" PRIuS " tiles...\n",
            size, size);
    StringVec fnames_out;
    std::vector<Image3F> images;
    std::vector<size_t> offsets;
    size_t total_num_tiles = 0;
    for (const auto& fname : fnames) {
      Image3F img;
      JXL_CHECK(ReadPNG(fname, &img));
      JXL_CHECK(img.xsize() >= size);
      JXL_CHECK(img.ysize() >= size);
      total_num_tiles += (img.xsize() - size + 1) * (img.ysize() - size + 1);
      offsets.push_back(total_num_tiles);
      images.emplace_back(std::move(img));
    }
    JXL_CHECK(MakeDir(sample_tmp_dir));
    Rng rng(0);
    for (int i = 0; i < num_samples; ++i) {
      int val = rng.UniformI(0, offsets.back());
      size_t idx = (std::lower_bound(offsets.begin(), offsets.end(), val) -
                    offsets.begin());
      JXL_CHECK(idx < images.size());
      const Image3F& img = images[idx];
      int x0 = rng.UniformI(0, img.xsize() - size);
      int y0 = rng.UniformI(0, img.ysize() - size);
      Image3F sample(size, size);
      for (size_t c = 0; c < 3; ++c) {
        for (size_t y = 0; y < size; ++y) {
          const float* JXL_RESTRICT row_in = img.PlaneRow(c, y0 + y);
          float* JXL_RESTRICT row_out = sample.PlaneRow(c, y);
          memcpy(row_out, &row_in[x0], size * sizeof(row_out[0]));
        }
      }
      std::string fn_output =
          StringPrintf("%s/%s.crop_%dx%d+%d+%d.png", sample_tmp_dir.c_str(),
                       FileBaseName(fnames[idx]).c_str(), size, size, x0, y0);
      ThreadPool* null_pool = nullptr;
      JXL_CHECK(WriteImage(std::move(sample), null_pool, fn_output));
      fnames_out.push_back(fn_output);
    }
    fprintf(stderr, "Created %d sample tiles\n", num_samples);
    return fnames_out;
  }

  static StringVec GetFilenames() {
    StringVec fnames;
    JXL_CHECK(MatchFiles(Args()->input, &fnames));
    if (fnames.empty()) {
      JXL_ABORT("No input file matches pattern: '%s'", Args()->input.c_str());
    }
    if (Args()->print_details) {
      std::sort(fnames.begin(), fnames.end());
    }

    if (Args()->num_samples > 0) {
      fnames = SampleFromInput(fnames, Args()->sample_tmp_dir,
                               Args()->num_samples, Args()->sample_dimensions);
    }
    return fnames;
  }

  // (Load only once, not for every codec)
  static std::vector<CodecInOut> LoadImages(const StringVec& fnames,
                                            ThreadPool* pool) {
    std::vector<CodecInOut> loaded_images;
    loaded_images.resize(fnames.size());
    const auto process_image = [&](const uint32_t task, size_t /*thread*/) {
      const size_t i = static_cast<size_t>(task);
      Status ok = true;

      if (!Args()->decode_only) {
        PaddedBytes encoded;
        ok = ReadFile(fnames[i], &encoded);
        if (ok) {
          ok = jxl::SetFromBytes(Span<const uint8_t>(encoded),
                                 Args()->color_hints, &loaded_images[i]);
        }
        if (ok && Args()->intensity_target != 0) {
          loaded_images[i].metadata.m.SetIntensityTarget(
              Args()->intensity_target);
        }
      }
      if (!ok) {
        if (!Args()->silent_errors) {
          fprintf(stderr, "Failed to load image %s\n", fnames[i].c_str());
        }
        return;
      }

      if (!Args()->decode_only && Args()->override_bitdepth != 0) {
        if (Args()->override_bitdepth == 32) {
          loaded_images[i].metadata.m.SetFloat32Samples();
        } else {
          loaded_images[i].metadata.m.SetUintSamples(Args()->override_bitdepth);
        }
      }
    };
    JXL_CHECK(jxl::RunOnPool(pool, 0, static_cast<uint32_t>(fnames.size()),
                             ThreadPool::NoInit, process_image, "Load images"));
    return loaded_images;
  }

  static std::vector<Task> CreateTasks(const StringVec& methods,
                                       const StringVec& fnames) {
    std::vector<Task> tasks;
    tasks.reserve(methods.size() * fnames.size());
    for (size_t idx_image = 0; idx_image < fnames.size(); ++idx_image) {
      for (size_t idx_method = 0; idx_method < methods.size(); ++idx_method) {
        tasks.emplace_back();
        Task& t = tasks.back();
        t.codec = CreateImageCodec(methods[idx_method]);
        t.idx_image = idx_image;
        t.idx_method = idx_method;
        // t.stats is default-initialized.
      }
    }
    JXL_ASSERT(tasks.size() == tasks.capacity());
    return tasks;
  }

  // Return the total number of errors.
  static size_t RunTasks(
      const StringVec& methods, const StringVec& extra_metrics_names,
      const StringVec& extra_metrics_commands, const StringVec& fnames,
      const std::vector<CodecInOut>& loaded_images, ThreadPool* pool,
      const std::vector<std::unique_ptr<ThreadPoolInternal>>& inner_pools,
      std::vector<Task>* tasks) {
    StatPrinter printer(methods, extra_metrics_names, fnames, *tasks);
    if (Args()->print_details_csv) {
      // Print CSV header
      printf(
          "method,image,error,size,pixels,enc_speed,dec_speed,"
          "bpp,dist,psnr,p,bppp,qabpp");
      for (const std::string& s : extra_metrics_names) {
        printf(",%s", s.c_str());
      }
      printf("\n");
    }

    std::vector<uint64_t> errors_thread;
    JXL_CHECK(jxl::RunOnPool(
        pool, 0, tasks->size(),
        [&](const size_t num_threads) {
          // Reduce false sharing by only writing every 8th slot (64 bytes).
          errors_thread.resize(8 * num_threads);
          return true;
        },
        [&](const uint32_t i, const size_t thread) {
          Task& t = (*tasks)[i];
          const CodecInOut& image = loaded_images[t.idx_image];
          t.image = &image;
          std::vector<uint8_t> compressed;
          DoCompress(fnames[t.idx_image], image, extra_metrics_commands,
                     t.codec.get(), &*inner_pools[thread], &compressed,
                     &t.stats);
          printer.TaskDone(i, t);
          errors_thread[8 * thread] += t.stats.total_errors;
        },
        "Benchmark tasks"));
    if (Args()->show_progress) fprintf(stderr, "\n");
    return std::accumulate(errors_thread.begin(), errors_thread.end(),
                           size_t(0));
  }
};

int BenchmarkMain(int argc, const char** argv) {
  fprintf(stderr, "benchmark_xl %s\n",
          jpegxl::tools::CodecConfigString(JxlDecoderVersion()).c_str());

  JXL_CHECK(Args()->AddCommandLineOptions());

  if (!Args()->Parse(argc, argv)) {
    fprintf(stderr, "Use '%s -h' for more information\n", argv[0]);
    return 1;
  }

  if (Args()->cmdline.HelpFlagPassed()) {
    Args()->PrintHelp();
    return 0;
  }
  if (!Args()->ValidateArgs()) {
    fprintf(stderr, "Use '%s -h' for more information\n", argv[0]);
    return 1;
  }
  return Benchmark::Run();
}

}  // namespace
}  // namespace tools
}  // namespace jpegxl

int main(int argc, const char** argv) {
  return jpegxl::tools::BenchmarkMain(argc, argv);
}
