//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/SharedObjectPool.h"
#include "td/utils/tests.h"

#include <memory>

TEST(AtomicRefCnt, simple) {
  td::detail::AtomicRefCnt cnt{0};
  cnt.inc();
  cnt.inc();
  CHECK(!cnt.dec());
  cnt.inc();
  CHECK(!cnt.dec());
  CHECK(cnt.dec());
  cnt.inc();
  CHECK(cnt.dec());
}

template <class T, class D>
using Ptr = td::detail::SharedPtr<T, D>;
class Deleter {
 public:
  template <class T>
  void operator()(T *t) {
    std::default_delete<T>()(t);
    was_delete() = true;
  }
  static bool &was_delete() {
    static bool flag = false;
    return flag;
  }
};

TEST(SharedPtr, simple) {
  CHECK(!Deleter::was_delete());
  Ptr<std::string, Deleter> ptr = Ptr<std::string, Deleter>::create("hello");
  auto ptr2 = ptr;
  CHECK(*ptr == "hello");
  CHECK(*ptr2 == "hello");
  ptr.reset();
  CHECK(*ptr2 == "hello");
  CHECK(ptr.empty());
  Ptr<std::string, Deleter> ptr3 = std::move(ptr2);
  CHECK(ptr2.empty());
  CHECK(*ptr3 == "hello");
  ptr = ptr3;
  CHECK(*ptr3 == "hello");
  ptr3.reset();
  CHECK(*ptr == "hello");
  ptr2 = std::move(ptr);
  CHECK(ptr.empty());
  CHECK(*ptr2 == "hello");
#if TD_CLANG
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-pragmas"
#pragma clang diagnostic ignored "-Wunknown-warning-option"
#pragma clang diagnostic ignored "-Wself-assign-overloaded"
#endif
  ptr2 = ptr2;
#if TD_CLANG
#pragma clang diagnostic pop
#endif
  CHECK(*ptr2 == "hello");
  CHECK(!Deleter::was_delete());
  ptr2.reset();
  CHECK(Deleter::was_delete());
  CHECK(ptr2.empty());
}

TEST(SharedObjectPool, simple) {
  class Node {
   public:
    Node() {
      cnt()++;
    };
    ~Node() {
      cnt()--;
    }
    static int &cnt() {
      static int cnt_ = 0;
      return cnt_;
    }
  };
  {
    td::SharedObjectPool<Node> pool;
    { auto ptr1 = pool.alloc(); }
    { auto ptr2 = pool.alloc(); }
    { auto ptr3 = pool.alloc(); }
    { auto ptr4 = pool.alloc(); }
    { auto ptr5 = pool.alloc(); }
    CHECK(Node::cnt() == 0);
    CHECK(pool.total_size() == 1);
    CHECK(pool.calc_free_size() == 1);
    { auto ptr6 = pool.alloc(), ptr7 = pool.alloc(), ptr8 = pool.alloc(); }
    CHECK(pool.total_size() == 3);
    CHECK(pool.calc_free_size() == 3);
  }
  CHECK(Node::cnt() == 0);
}
