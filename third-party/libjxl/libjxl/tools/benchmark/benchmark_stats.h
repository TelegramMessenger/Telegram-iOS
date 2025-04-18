// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_BENCHMARK_BENCHMARK_STATS_H_
#define TOOLS_BENCHMARK_BENCHMARK_STATS_H_

#include <jxl/stats.h>
#include <stddef.h>
#include <stdint.h>

#include <memory>
#include <string>
#include <vector>

namespace jpegxl {
namespace tools {

std::string StringPrintf(const char* format, ...);

struct JxlStats {
  JxlStats()
      : num_inputs(0), stats(JxlEncoderStatsCreate(), JxlEncoderStatsDestroy) {}
  void Assimilate(const JxlStats& victim) {
    num_inputs += victim.num_inputs;
    JxlEncoderStatsMerge(stats.get(), victim.stats.get());
  }
  void Print() const;

  size_t num_inputs;
  std::unique_ptr<JxlEncoderStats, decltype(JxlEncoderStatsDestroy)*> stats;
};

// The value of an entry in the table. Depending on the ColumnType, the string,
// size_t or double should be used.
struct ColumnValue {
  std::string s;  // for TYPE_STRING
  size_t i;       // for TYPE_SIZE and TYPE_COUNT
  double f;       // for TYPE_POSITIVE_FLOAT
};

struct BenchmarkStats {
  void Assimilate(const BenchmarkStats& victim);

  std::vector<ColumnValue> ComputeColumns(const std::string& codec_desc,
                                          size_t corpus_size) const;

  std::string PrintLine(const std::string& codec_desc,
                        size_t corpus_size) const;

  void PrintMoreStats() const;

  size_t total_input_files = 0;
  size_t total_input_pixels = 0;
  size_t total_compressed_size = 0;
  size_t total_adj_compressed_size = 0;
  double total_time_encode = 0.0;
  double total_time_decode = 0.0;
  float max_distance = -1.0;  // Max butteraugli score
  // sum of 8th powers of butteraugli distmap pixels.
  double distance_p_norm = 0.0;
  double psnr = 0.0;
  double ssimulacra2 = 0.0;
  std::vector<float> distances;
  size_t total_errors = 0;
  JxlStats jxl_stats;
  std::vector<float> extra_metrics;
};

std::string PrintHeader(const std::vector<std::string>& extra_metrics_names);

// Given the rows of all printed statistics, print an aggregate row.
std::string PrintAggregate(
    size_t num_extra_metrics,
    const std::vector<std::vector<ColumnValue>>& aggregate);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BENCHMARK_BENCHMARK_STATS_H_
