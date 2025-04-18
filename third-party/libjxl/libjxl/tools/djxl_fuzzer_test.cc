// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/thread_parallel_runner.h>
#include <jxl/thread_parallel_runner_cxx.h>

#include <sstream>
#include <string>
#include <vector>

#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size);

std::vector<uint64_t> AllTestIds() {
  return {
      4546077333782528, 4716049045520384, 4718378999218176, 4729306868219904,
      4787817341911040, 4816304719134720, 4848606801166336, 4859247059402752,
      4887504894951424, 4984529666834432, 5014934495297536, 5112097090961408,
      5189497920290816, 5381727462227968, 5382562858532864, 5392074930782208,
      5467620336336896, 5473482434019328, 5489367788945408, 5556400888086528,
      5582808628723712, 5631220790198272, 5685623166468096, 5737500246671360,
      5785438255710208, 5800733037953024, 5849986531721216, 5858549672050688,
      5899664422993920, 5900921718046720, 5906295376445440, 5914266367557632,
      6013780411154432, 6165169006313472, 6277573962760192, 6329817929220096,
      6355777170833408, 6375307931680768, 6448658097242112, 6515680276512768,
      6569981946494976, 6735607318052864, 6737321070821376, 6748486320652288,
  };
}

class DjxlFuzzerTest : public ::testing::TestWithParam<uint64_t> {};
JXL_GTEST_INSTANTIATE_TEST_SUITE_P(DjxlFuzzerTestInstantiation, DjxlFuzzerTest,
                                   ::testing::ValuesIn(AllTestIds()));
TEST_P(DjxlFuzzerTest, TestOne) {
  uint64_t id = GetParam();
  std::ostringstream os;
  os << "oss-fuzz/clusterfuzz-testcase-minimized-djxl_fuzzer-" << id;
  printf("Testing %s\n", os.str().c_str());
  const jxl::PaddedBytes input = jxl::test::ReadTestData(os.str());
  LLVMFuzzerTestOneInput(input.data(), input.size());
}
