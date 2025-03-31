//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/port/thread.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/tests.h"

char disable_linker_warning_about_empty_file_tdutils_test_shared_slice_cpp TD_UNUSED;

#if !TD_THREAD_UNSUPPORTED
TEST(SharedSlice, Hands) {
  {
    td::SharedSlice h("hello");
    ASSERT_EQ("hello", h.as_slice());
    // auto g = h; // CE
    auto g = h.clone();
    ASSERT_EQ("hello", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
  }

  {
    td::SharedSlice h("hello");
    td::UniqueSharedSlice g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
  }
  {
    td::SharedSlice h("hello");
    td::SharedSlice t = h.clone();
    td::UniqueSharedSlice g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
    ASSERT_EQ("hello", t.as_slice());
  }

  {
    td::UniqueSharedSlice g(5);
    g.as_mutable_slice().copy_from("hello");
    td::SharedSlice h(std::move(g));
    ASSERT_EQ("hello", h);
    ASSERT_EQ("", g);
  }

  {
    td::UniqueSlice h("hello");
    td::UniqueSlice g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
  }

  {
    td::SecureString h("hello");
    td::SecureString g(std::move(h));
    ASSERT_EQ("", h.as_slice());
    ASSERT_EQ("hello", g.as_slice());
  }

  {
    td::Stage stage;
    td::SharedSlice a;
    td::SharedSlice b;
    td::vector<td::thread> threads(2);
    for (int i = 0; i < 2; i++) {
      threads[i] = td::thread([i, &stage, &a, &b] {
        for (int j = 0; j < 10000; j++) {
          if (i == 0) {
            a = td::SharedSlice("hello");
            b = a.clone();
          }
          stage.wait((2 * j + 1) * 2);
          if (i == 0) {
            ASSERT_EQ('h', a[0]);
            a.clear();
          } else {
            td::UniqueSharedSlice c(std::move(b));
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
#endif
