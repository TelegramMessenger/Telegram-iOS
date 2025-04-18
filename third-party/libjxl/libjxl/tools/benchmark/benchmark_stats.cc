// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/benchmark/benchmark_stats.h"

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include <algorithm>
#include <cmath>

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"
#include "tools/benchmark/benchmark_args.h"

namespace jpegxl {
namespace tools {

#define ADD_NAME(val, name) \
  case JXL_ENC_STAT_##val:  \
    return name
const char* JxlStatsName(JxlEncoderStatsKey key) {
  switch (key) {
    ADD_NAME(HEADER_BITS, "Header bits");
    ADD_NAME(TOC_BITS, "TOC bits");
    ADD_NAME(DICTIONARY_BITS, "Patch dictionary bits");
    ADD_NAME(SPLINES_BITS, "Splines bits");
    ADD_NAME(NOISE_BITS, "Noise bits");
    ADD_NAME(QUANT_BITS, "Quantizer bits");
    ADD_NAME(MODULAR_TREE_BITS, "Modular tree bits");
    ADD_NAME(MODULAR_GLOBAL_BITS, "Modular global bits");
    ADD_NAME(DC_BITS, "DC bits");
    ADD_NAME(MODULAR_DC_GROUP_BITS, "Modular DC group bits");
    ADD_NAME(CONTROL_FIELDS_BITS, "Control field bits");
    ADD_NAME(COEF_ORDER_BITS, "Coeff order bits");
    ADD_NAME(AC_HISTOGRAM_BITS, "AC histogram bits");
    ADD_NAME(AC_BITS, "AC token bits");
    ADD_NAME(MODULAR_AC_GROUP_BITS, "Modular AC group bits");
    ADD_NAME(NUM_SMALL_BLOCKS, "Number of small blocks");
    ADD_NAME(NUM_DCT4X8_BLOCKS, "Number of 4x8 blocks");
    ADD_NAME(NUM_AFV_BLOCKS, "Number of AFV blocks");
    ADD_NAME(NUM_DCT8_BLOCKS, "Number of 8x8 blocks");
    ADD_NAME(NUM_DCT8X32_BLOCKS, "Number of 8x32 blocks");
    ADD_NAME(NUM_DCT16_BLOCKS, "Number of 16x16 blocks");
    ADD_NAME(NUM_DCT16X32_BLOCKS, "Number of 16x32 blocks");
    ADD_NAME(NUM_DCT32_BLOCKS, "Number of 32x32 blocks");
    ADD_NAME(NUM_DCT32X64_BLOCKS, "Number of 32x64 blocks");
    ADD_NAME(NUM_DCT64_BLOCKS, "Number of 64x64 blocks");
    ADD_NAME(NUM_BUTTERAUGLI_ITERS, "Butteraugli iters");
    default:
      return "";
  };
  return "";
}
#undef ADD_NAME

void JxlStats::Print() const {
  for (int i = 0; i < JXL_ENC_NUM_STATS; ++i) {
    JxlEncoderStatsKey key = static_cast<JxlEncoderStatsKey>(i);
    size_t value = JxlEncoderStatsGet(stats.get(), key);
    if (value) printf("%-25s  %10" PRIuS "\n", JxlStatsName(key), value);
  }
}

namespace {

// Computes longest codec name from Args()->codec, for table alignment.
uint32_t ComputeLargestCodecName() {
  std::vector<std::string> methods = SplitString(Args()->codec, ',');
  size_t max = strlen("Aggregate:");  // Include final row's name
  for (const auto& method : methods) {
    max = std::max(max, method.size());
  }
  return max;
}

// The benchmark result is a table of heterogeneous data, the column type
// specifies its data type. The type affects how it is printed as well as how
// aggregate values are computed.
enum ColumnType {
  // Formatted string
  TYPE_STRING,
  // Positive size, prints 0 as "---"
  TYPE_SIZE,
  // Floating point value (double precision) which is interpreted as
  // "not applicable" if <= 0, must be strictly positive to be valid but can be
  // set to 0 or negative to be printed as "---", for example for a speed that
  // is not measured.
  TYPE_POSITIVE_FLOAT,
  // Counts of some event
  TYPE_COUNT,
};

struct ColumnDescriptor {
  // Column name
  std::string label;
  // Total width to render the values of this column. If t his is a floating
  // point value, make sure this is large enough to contain a space and the
  // point, plus precision digits after the point, plus the max amount of
  // integer digits you expect in front of the point.
  uint32_t width;
  // Amount of digits after the point, or 0 if not a floating point value.
  uint32_t precision;
  ColumnType type;
  bool more;  // Whether to print only if more_columns is enabled
};

static ColumnDescriptor ExtraMetricDescriptor() {
  ColumnDescriptor d{{"DO NOT USE"}, 12, 4, TYPE_POSITIVE_FLOAT, false};
  return d;
}

// To add or change a column to the benchmark ASCII table output, add/change
// an entry here with table header line 1, table header line 2, width of the
// column, precision after the point in case of floating point, and the
// data type. Then add/change the corresponding formula or formatting in
// the function ComputeColumns.
std::vector<ColumnDescriptor> GetColumnDescriptors(size_t num_extra_metrics) {
  // clang-format off
  std::vector<ColumnDescriptor> result = {
      {{"Encoding"}, ComputeLargestCodecName() + 1, 0, TYPE_STRING, false},
      {{"kPixels"},        10,  0, TYPE_SIZE, false},
      {{"Bytes"},           9,  0, TYPE_SIZE, false},
      {{"BPP"},            13,  7, TYPE_POSITIVE_FLOAT, false},
      {{"E MP/s"},          8,  3, TYPE_POSITIVE_FLOAT, false},
      {{"D MP/s"},          8,  3, TYPE_POSITIVE_FLOAT, false},
      {{"Max norm"},       13,  8, TYPE_POSITIVE_FLOAT, false},
      {{"SSIMULACRA2"},    13,  8, TYPE_POSITIVE_FLOAT, false},
      {{"PSNR"},            7,  2, TYPE_POSITIVE_FLOAT, false},
      {{"pnorm"},          13,  8, TYPE_POSITIVE_FLOAT, false},
      {{"BPP*pnorm"},      16, 12, TYPE_POSITIVE_FLOAT, false},
      {{"QABPP"},           8,  3, TYPE_POSITIVE_FLOAT, false},
      {{"Bugs"},            7,  5, TYPE_COUNT, false},
  };
  // clang-format on

  for (size_t i = 0; i < num_extra_metrics; i++) {
    result.push_back(ExtraMetricDescriptor());
  }

  return result;
}

// Computes throughput [megapixels/s] as reported in the report table
static double ComputeSpeed(size_t pixels, double time_s) {
  if (time_s == 0.0) return 0;
  return pixels * 1E-6 / time_s;
}

static std::string FormatFloat(const ColumnDescriptor& label, double value) {
  std::string result =
      StringPrintf("%*.*f", label.width - 1, label.precision, value);

  // Reduce precision if the value is too wide for the column. However, keep
  // at least one digit to the right of the point, and especially the integer
  // digits.
  if (result.size() >= label.width) {
    size_t point = result.rfind('.');
    if (point != std::string::npos) {
      int end = std::max<int>(point + 2, label.width - 1);
      result.resize(end);
    }
  }
  return result;
}

}  // namespace

std::string StringPrintf(const char* format, ...) {
  char buf[2000];
  va_list args;
  va_start(args, format);
  vsnprintf(buf, sizeof(buf), format, args);
  va_end(args);
  return std::string(buf);
}

void BenchmarkStats::Assimilate(const BenchmarkStats& victim) {
  total_input_files += victim.total_input_files;
  total_input_pixels += victim.total_input_pixels;
  total_compressed_size += victim.total_compressed_size;
  total_adj_compressed_size += victim.total_adj_compressed_size;
  total_time_encode += victim.total_time_encode;
  total_time_decode += victim.total_time_decode;
  max_distance += pow(victim.max_distance, 2.0) * victim.total_input_pixels;
  distance_p_norm += victim.distance_p_norm;
  ssimulacra2 += victim.ssimulacra2;
  psnr += victim.psnr;
  distances.insert(distances.end(), victim.distances.begin(),
                   victim.distances.end());
  total_errors += victim.total_errors;
  jxl_stats.Assimilate(victim.jxl_stats);
  if (extra_metrics.size() < victim.extra_metrics.size()) {
    extra_metrics.resize(victim.extra_metrics.size());
  }
  for (size_t i = 0; i < victim.extra_metrics.size(); i++) {
    extra_metrics[i] += victim.extra_metrics[i];
  }
}

void BenchmarkStats::PrintMoreStats() const {
  if (Args()->print_more_stats) {
    jxl_stats.Print();
  }
  if (Args()->print_distance_percentiles) {
    std::vector<float> sorted = distances;
    std::sort(sorted.begin(), sorted.end());
    int p50idx = 0.5 * distances.size();
    int p90idx = 0.9 * distances.size();
    printf("50th/90th percentile distance: %.8f  %.8f\n", sorted[p50idx],
           sorted[p90idx]);
  }
}

std::vector<ColumnValue> BenchmarkStats::ComputeColumns(
    const std::string& codec_desc, size_t corpus_size) const {
  JXL_CHECK(total_input_files == corpus_size);
  const double comp_bpp = total_compressed_size * 8.0 / total_input_pixels;
  const double adj_comp_bpp =
      total_adj_compressed_size * 8.0 / total_input_pixels;
  // Note: this is not affected by alpha nor bit depth.
  const double compression_speed =
      ComputeSpeed(total_input_pixels, total_time_encode);
  const double decompression_speed =
      ComputeSpeed(total_input_pixels, total_time_decode);
  const double psnr_avg = psnr / total_input_pixels;
  const double p_norm_avg = distance_p_norm / total_input_pixels;
  const double ssimulacra2_avg = ssimulacra2 / total_input_pixels;
  const double bpp_p_norm = p_norm_avg * comp_bpp;

  const double max_distance_avg = sqrt(max_distance / total_input_pixels);

  std::vector<ColumnValue> values(
      GetColumnDescriptors(extra_metrics.size()).size());

  values[0].s = codec_desc;
  values[1].i = total_input_pixels / 1000;
  values[2].i = total_compressed_size;
  values[3].f = comp_bpp;
  values[4].f = compression_speed;
  values[5].f = decompression_speed;
  values[6].f = static_cast<double>(max_distance_avg);
  values[7].f = ssimulacra2_avg;
  values[8].f = psnr_avg;
  values[9].f = p_norm_avg;
  values[10].f = bpp_p_norm;
  values[11].f = adj_comp_bpp;
  values[12].i = total_errors;
  for (size_t i = 0; i < extra_metrics.size(); i++) {
    values[13 + i].f = extra_metrics[i] / total_input_files;
  }
  return values;
}

static std::string PrintFormattedEntries(
    size_t num_extra_metrics, const std::vector<ColumnValue>& values) {
  const auto& descriptors = GetColumnDescriptors(num_extra_metrics);

  std::string out;
  for (size_t i = 0; i < descriptors.size(); i++) {
    if (!Args()->more_columns && descriptors[i].more) continue;
    std::string value;
    if (descriptors[i].type == TYPE_STRING) {
      value = values[i].s;
    } else if (descriptors[i].type == TYPE_SIZE) {
      value = values[i].i ? StringPrintf("%" PRIdS, values[i].i) : "---";
    } else if (descriptors[i].type == TYPE_POSITIVE_FLOAT) {
      value = FormatFloat(descriptors[i], values[i].f);
      value = FormatFloat(descriptors[i], values[i].f);
    } else if (descriptors[i].type == TYPE_COUNT) {
      value = StringPrintf("%" PRIdS, values[i].i);
    }

    int numspaces = descriptors[i].width - value.size();
    if (numspaces < 1) {
      numspaces = 1;
    }
    // All except the first one are right-aligned, the first one is the name,
    // others are numbers with digits matching from the right.
    if (i == 0) out += value.c_str();
    out += std::string(numspaces, ' ');
    if (i != 0) out += value.c_str();
  }
  return out + "\n";
}

std::string BenchmarkStats::PrintLine(const std::string& codec_desc,
                                      size_t corpus_size) const {
  std::vector<ColumnValue> values = ComputeColumns(codec_desc, corpus_size);
  return PrintFormattedEntries(extra_metrics.size(), values);
}

std::string PrintHeader(const std::vector<std::string>& extra_metrics_names) {
  std::string out;
  // Extra metrics are handled separately.
  const auto& descriptors = GetColumnDescriptors(0);
  for (size_t i = 0; i < descriptors.size(); i++) {
    if (!Args()->more_columns && descriptors[i].more) continue;
    const std::string& label = descriptors[i].label;
    int numspaces = descriptors[i].width - label.size();
    // All except the first one are right-aligned.
    if (i == 0) out += label.c_str();
    out += std::string(numspaces, ' ');
    if (i != 0) out += label.c_str();
  }
  for (const std::string& em : extra_metrics_names) {
    int numspaces = ExtraMetricDescriptor().width - em.size();
    JXL_CHECK(numspaces >= 1);
    out += std::string(numspaces, ' ');
    out += em;
  }
  out += '\n';
  for (const auto& descriptor : descriptors) {
    if (!Args()->more_columns && descriptor.more) continue;
    out += std::string(descriptor.width, '-');
  }
  out += std::string(ExtraMetricDescriptor().width * extra_metrics_names.size(),
                     '-');
  return out + "\n";
}

std::string PrintAggregate(
    size_t num_extra_metrics,
    const std::vector<std::vector<ColumnValue>>& aggregate) {
  const auto& descriptors = GetColumnDescriptors(num_extra_metrics);

  for (size_t i = 0; i < aggregate.size(); i++) {
    // Check when statistics has wrong amount of column entries
    JXL_CHECK(aggregate[i].size() == descriptors.size());
  }

  std::vector<ColumnValue> result(descriptors.size());

  // Statistics for the aggregate row are combined together with different
  // formulas than Assimilate uses for combining the statistics of files.
  for (size_t i = 0; i < descriptors.size(); i++) {
    if (descriptors[i].type == TYPE_STRING) {
      // "---" for the Iters column since this does not have meaning for
      // the aggregate stats.
      result[i].s = i == 0 ? "Aggregate:" : "---";
      continue;
    }
    if (descriptors[i].type == TYPE_COUNT) {
      size_t sum = 0;
      for (size_t j = 0; j < aggregate.size(); j++) {
        sum += aggregate[j][i].i;
      }
      result[i].i = sum;
      continue;
    }

    ColumnType type = descriptors[i].type;

    double logsum = 0;
    size_t numvalid = 0;
    for (size_t j = 0; j < aggregate.size(); j++) {
      double value =
          (type == TYPE_SIZE) ? aggregate[j][i].i : aggregate[j][i].f;
      if (value > 0) {
        numvalid++;
        logsum += std::log2(value);
      }
    }
    double geomean = numvalid ? std::exp2(logsum / numvalid) : 0.0;

    if (type == TYPE_SIZE || type == TYPE_COUNT) {
      result[i].i = static_cast<size_t>(geomean + 0.5);
    } else if (type == TYPE_POSITIVE_FLOAT) {
      result[i].f = geomean;
    } else {
      JXL_ABORT("unknown entry type");
    }
  }

  return PrintFormattedEntries(num_extra_metrics, result);
}

}  // namespace tools
}  // namespace jpegxl
