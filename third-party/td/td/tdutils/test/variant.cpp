//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/Variant.h"

static const size_t BUF_SIZE = 1024 * 1024;
static char buf[BUF_SIZE], buf2[BUF_SIZE];
static td::StringBuilder sb(td::MutableSlice(buf, BUF_SIZE - 1));
static td::StringBuilder sb2(td::MutableSlice(buf2, BUF_SIZE - 1));

static td::string move_sb() {
  auto res = sb.as_cslice().str();
  sb.clear();
  return res;
}

static td::string name(int id) {
  if (id == 1) {
    return "A";
  }
  if (id == 2) {
    return "B";
  }
  if (id == 3) {
    return "C";
  }
  return "";
}

template <int id>
class Class {
 public:
  Class() {
    sb << "+" << name(id);
  }
  Class(const Class &) = delete;
  Class &operator=(const Class &) = delete;
  Class(Class &&) = delete;
  Class &operator=(Class &&) = delete;
  ~Class() {
    sb << "-" << name(id);
  }
};

using A = Class<1>;
using B = Class<2>;
using C = Class<3>;

TEST(Variant, simple) {
  {
    td::Variant<td::unique_ptr<A>, td::unique_ptr<B>, td::unique_ptr<C>> abc;
    ASSERT_STREQ("", sb.as_cslice());
    abc = td::make_unique<A>();
    ASSERT_STREQ("+A", sb.as_cslice());
    sb.clear();
    abc = td::make_unique<B>();
    ASSERT_STREQ("+B-A", sb.as_cslice());
    sb.clear();
    abc = td::make_unique<C>();
    ASSERT_STREQ("+C-B", sb.as_cslice());
    sb.clear();
  }
  ASSERT_STREQ("-C", move_sb());
  sb.clear();
}
