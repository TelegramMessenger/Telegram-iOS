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
#include "td/utils/Enumerator.h"
#include "td/utils/tests.h"

TEST(Enumerator, simple) {
  td::Enumerator<std::string> e;
  auto b = e.add("b");
  auto a = e.add("a");
  auto d = e.add("d");
  auto c = e.add("c");
  ASSERT_STREQ(e.get(a), "a");
  ASSERT_STREQ(e.get(b), "b");
  ASSERT_STREQ(e.get(c), "c");
  ASSERT_STREQ(e.get(d), "d");
  ASSERT_EQ(a, e.add("a"));
  ASSERT_EQ(b, e.add("b"));
  ASSERT_EQ(c, e.add("c"));
  ASSERT_EQ(d, e.add("d"));
}
