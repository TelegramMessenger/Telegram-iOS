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
#include "td/utils/SharedSlice.h"

using namespace td;

TEST(SharedSlice, Hands) {
  {
    SharedSlice h("hello");
    ASSERT_EQ("hello", h.as_slice());
    // auto g = h; // CE
    auto g = h.clone();
    ASSERT_EQ("hello", g.as_slice());
  }

  {
    SharedSlice h("hello");
    UniqueSharedSlice g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
  }
  {
    SharedSlice h("hello");
    SharedSlice t = h.clone();
    UniqueSharedSlice g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
    ASSERT_EQ("hello", t.as_slice());
  }

  {
    UniqueSharedSlice g(5);
    g.as_mutable_slice().copy_from("hello");
    SharedSlice h(std::move(g));
    ASSERT_EQ("hello", h);
    ASSERT_EQ("", g);
  }

  {
    UniqueSlice h("hello");
    UniqueSlice g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
  }

  {
    SecureString h("hello");
    SecureString g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
  }

  {
    Stage stage;
    SharedSlice a, b;
    std::vector<td::thread> threads(2);
    for (int i = 0; i < 2; i++) {
      threads[i] = td::thread([i, &stage, &a, &b] {
        for (int j = 0; j < 10000; j++) {
          if (i == 0) {
            a = SharedSlice("hello");
            b = a.clone();
          }
          stage.wait((2 * j + 1) * 2);
          if (i == 0) {
            ASSERT_EQ('h', a[0]);
            a.clear();
          } else {
            UniqueSharedSlice c(std::move(b));
            c.as_mutable_slice()[0] = '!';
          }
          stage.wait((2 * j + 2) * 2);
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
}
