/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/utils/tests.h"

#include "td/utils/buffer.h"
#include "td/utils/Random.h"

using namespace td;

TEST(Buffer, buffer_builder) {
  {
    BufferBuilder builder;
    builder.append("b");
    builder.prepend("a");
    builder.append("c");
    ASSERT_EQ(builder.extract().as_slice(), "abc");
  }
  {
    BufferBuilder builder{"hello", 0, 0};
    ASSERT_EQ(builder.extract().as_slice(), "hello");
  }
  {
    BufferBuilder builder{"hello", 1, 1};
    builder.prepend("A ");
    builder.append(" B");
    ASSERT_EQ(builder.extract().as_slice(), "A hello B");
  }
  {
    std::string str = rand_string('a', 'z', 10000);
    auto splitted_str = rand_split(str);

    int l = Random::fast(0, static_cast<int32>(splitted_str.size() - 1));
    int r = l;
    BufferBuilder builder(splitted_str[l], 123, 1000);
    while (l != 0 || r != static_cast<int32>(splitted_str.size()) - 1) {
      if (l == 0 || (Random::fast(0, 1) == 1 && r != static_cast<int32>(splitted_str.size() - 1))) {
        r++;
        if (Random::fast(0, 1) == 1) {
          builder.append(splitted_str[r]);
        } else {
          builder.append(BufferSlice(splitted_str[r]));
        }
      } else {
        l--;
        if (Random::fast(0, 1) == 1) {
          builder.prepend(splitted_str[l]);
        } else {
          builder.prepend(BufferSlice(splitted_str[l]));
        }
      }
    }
    ASSERT_EQ(builder.extract().as_slice(), str);
  }
}
