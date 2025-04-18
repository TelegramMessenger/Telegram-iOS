// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/color_description.h"

#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {

// Verify ParseDescription(Description) yields the same ColorEncoding
TEST(ColorDescriptionTest, RoundTripAll) {
  for (const auto& cdesc : test::AllEncodings()) {
    const ColorEncoding c_original = test::ColorEncodingFromDescriptor(cdesc);
    const std::string description = Description(c_original);
    printf("%s\n", description.c_str());

    JxlColorEncoding c_external = {};
    EXPECT_TRUE(ParseDescription(description, &c_external));
    ColorEncoding c_internal;
    EXPECT_TRUE(
        ConvertExternalToInternalColorEncoding(c_external, &c_internal));
    EXPECT_TRUE(c_original.SameColorEncoding(c_internal))
        << "Where c_original=" << c_original
        << " and c_internal=" << c_internal;
  }
}

TEST(ColorDescriptionTest, NanGamma) {
  const std::string description = "Gra_2_Per_gnan";
  JxlColorEncoding c;
  EXPECT_FALSE(ParseDescription(description, &c));
}

}  // namespace jxl
