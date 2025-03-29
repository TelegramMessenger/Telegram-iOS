//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/tests.h"

#include "td/utils/buffer.h"
#include "td/utils/Random.h"

TEST(Buffer, buffer_builder) {
  {
    td::BufferBuilder builder;
    builder.append("b");
    builder.prepend("a");
    builder.append("c");
    ASSERT_EQ(builder.extract().as_slice(), "abc");
  }
  {
    td::BufferBuilder builder{"hello", 0, 0};
    ASSERT_EQ(builder.extract().as_slice(), "hello");
  }
  {
    td::BufferBuilder builder{"hello", 1, 1};
    builder.prepend("A ");
    builder.append(" B");
    ASSERT_EQ(builder.extract().as_slice(), "A hello B");
  }
  {
    auto str = td::rand_string('a', 'z', 10000);
    auto split_str = td::rand_split(str);

    int l = td::Random::fast(0, static_cast<int>(split_str.size() - 1));
    int r = l;
    td::BufferBuilder builder(split_str[l], 123, 1000);
    while (l != 0 || r != static_cast<int>(split_str.size()) - 1) {
      if (l == 0 || (td::Random::fast_bool() && r != static_cast<int>(split_str.size() - 1))) {
        r++;
        if (td::Random::fast_bool()) {
          builder.append(split_str[r]);
        } else {
          builder.append(td::BufferSlice(split_str[r]));
        }
      } else {
        l--;
        if (td::Random::fast_bool()) {
          builder.prepend(split_str[l]);
        } else {
          builder.prepend(td::BufferSlice(split_str[l]));
        }
      }
    }
    ASSERT_EQ(builder.extract().as_slice(), str);
  }
}
