// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/box/box.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <utility>

#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/testing.h"

TEST(BoxTest, BoxTest) {
  size_t test_size = 256;
  jxl::PaddedBytes exif(test_size);
  jxl::PaddedBytes xml0(test_size);
  jxl::PaddedBytes xml1(test_size);
  jxl::PaddedBytes jumb(test_size);
  jxl::PaddedBytes codestream(test_size);
  // Generate arbitrary data for the codestreams: the test is not testing
  // the contents of them but whether they are preserved in the container.
  uint8_t v = 0;
  for (size_t i = 0; i < test_size; ++i) {
    exif[i] = v++;
    xml0[i] = v++;
    xml1[i] = v++;
    jumb[i] = v++;
    codestream[i] = v++;
  }

  jpegxl::tools::JpegXlContainer container;
  container.exif = exif.data();
  container.exif_size = exif.size();
  container.xml.emplace_back(xml0.data(), xml0.size());
  container.xml.emplace_back(xml1.data(), xml1.size());
  container.xmlc.emplace_back(xml1.data(), xml1.size());
  container.jumb = jumb.data();
  container.jumb_size = jumb.size();
  container.codestream = std::move(codestream);

  jxl::PaddedBytes file;
  EXPECT_EQ(true,
            jpegxl::tools::EncodeJpegXlContainerOneShot(container, &file));

  jpegxl::tools::JpegXlContainer container2;
  EXPECT_EQ(true, jpegxl::tools::DecodeJpegXlContainerOneShot(
                      file.data(), file.size(), &container2));

  EXPECT_EQ(exif.size(), container2.exif_size);
  EXPECT_EQ(0, memcmp(exif.data(), container2.exif, container2.exif_size));
  EXPECT_EQ(2u, container2.xml.size());
  if (container2.xml.size() == 2) {
    EXPECT_EQ(xml0.size(), container2.xml[0].second);
    EXPECT_EQ(0, memcmp(xml0.data(), container2.xml[0].first,
                        container2.xml[0].second));
    EXPECT_EQ(xml1.size(), container2.xml[1].second);
    EXPECT_EQ(0, memcmp(xml1.data(), container2.xml[1].first,
                        container2.xml[1].second));
  }
  EXPECT_EQ(1u, container2.xmlc.size());
  if (container2.xmlc.size() == 1) {
    EXPECT_EQ(xml1.size(), container2.xmlc[0].second);
    EXPECT_EQ(0, memcmp(xml1.data(), container2.xmlc[0].first,
                        container2.xmlc[0].second));
  }
  EXPECT_EQ(jumb.size(), container2.jumb_size);
  EXPECT_EQ(0, memcmp(jumb.data(), container2.jumb, container2.jumb_size));
  EXPECT_EQ(container.codestream.size(), container2.codestream.size());
  EXPECT_EQ(0, memcmp(container.codestream.data(), container2.codestream.data(),
                      container2.codestream.size()));
}
