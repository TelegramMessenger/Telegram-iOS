// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/iaca.h"

#include "lib/jxl/testing.h"

namespace jxl {
namespace {

TEST(IacaTest, MarkersDefaultToDisabledAndDoNotCrash) {
  BeginIACA();
  EndIACA();
}

TEST(IacaTest, ScopeDefaultToDisabledAndDoNotCrash) { ScopeIACA iaca; }

}  // namespace
}  // namespace jxl
