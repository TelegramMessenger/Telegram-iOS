//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/algorithm.h"
#include "td/utils/as.h"
#include "td/utils/base64.h"
#include "td/utils/benchmark.h"
#include "td/utils/BigNum.h"
#include "td/utils/bits.h"
#include "td/utils/CancellationToken.h"
#include "td/utils/common.h"
#include "td/utils/ExitGuard.h"
#include "td/utils/FloodControlFast.h"
#include "td/utils/Hash.h"
#include "td/utils/HashMap.h"
#include "td/utils/HashSet.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/invoke.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/EventFd.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/path.h"
#include "td/utils/port/sleep.h"
#include "td/utils/port/Stat.h"
#include "td/utils/port/thread.h"
#include "td/utils/port/uname.h"
#include "td/utils/port/wstring_convert.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/translit.h"
#include "td/utils/uint128.h"
#include "td/utils/unicode.h"
#include "td/utils/unique_value_ptr.h"
#include "td/utils/utf8.h"

#include <algorithm>
#include <atomic>
#include <limits>
#include <locale>
#include <unordered_map>
#include <utility>

#if TD_HAVE_ABSL
#include <absl/container/flat_hash_map.h>
#include <absl/hash/hash.h>
#endif

struct CheckExitGuard {
  explicit CheckExitGuard(bool expected_value) : expected_value_(expected_value) {
  }
  CheckExitGuard(CheckExitGuard &&) = delete;
  CheckExitGuard &operator=(CheckExitGuard &&) = delete;
  CheckExitGuard(const CheckExitGuard &) = delete;
  CheckExitGuard &operator=(const CheckExitGuard &) = delete;
  ~CheckExitGuard() {
    ASSERT_EQ(expected_value_, td::ExitGuard::is_exited());
  }

  bool expected_value_;
};

static CheckExitGuard check_exit_guard_true{true};
static td::ExitGuard exit_guard;

#if TD_LINUX || TD_DARWIN
TEST(Misc, update_atime_saves_mtime) {
  td::string name = "test_file";
  td::unlink(name).ignore();
  auto r_file = td::FileFd::open(name, td::FileFd::Read | td::FileFd::Flags::Create | td::FileFd::Flags::Truncate);
  LOG_IF(ERROR, r_file.is_error()) << r_file.error();
  ASSERT_TRUE(r_file.is_ok());
  r_file.move_as_ok().close();

  auto info = td::stat(name).ok();
  td::int32 tests_wa = 0;
  for (int i = 0; i < 10000; i++) {
    td::update_atime(name).ensure();
    auto new_info = td::stat(name).ok();
    if (info.mtime_nsec_ != new_info.mtime_nsec_) {
      tests_wa++;
      info.mtime_nsec_ = new_info.mtime_nsec_;
    }
    ASSERT_EQ(info.mtime_nsec_, new_info.mtime_nsec_);
    td::usleep_for(td::Random::fast(0, 1000));
  }
  if (tests_wa > 0) {
    LOG(ERROR) << "Access time was unexpectedly updated " << tests_wa << " times";
  }
  td::unlink(name).ensure();
}

TEST(Misc, update_atime_change_atime) {
  td::string name = "test_file";
  td::unlink(name).ignore();
  auto r_file = td::FileFd::open(name, td::FileFd::Read | td::FileFd::Flags::Create | td::FileFd::Flags::Truncate);
  LOG_IF(ERROR, r_file.is_error()) << r_file.error();
  ASSERT_TRUE(r_file.is_ok());
  r_file.move_as_ok().close();
  auto info = td::stat(name).ok();
  // not enough for fat and e.t.c.
  td::usleep_for(5000000);
  td::update_atime(name).ensure();
  auto new_info = td::stat(name).ok();
  if (info.atime_nsec_ == new_info.atime_nsec_) {
    LOG(ERROR) << "Access time was unexpectedly not changed";
  }
  td::unlink(name).ensure();
}
#endif

TEST(Misc, errno_tls_bug) {
  // That's a problem that should be avoided
  // errno = 0;
  // impl_.alloc(123);
  // CHECK(errno == 0);

#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  td::EventFd test_event_fd;
  test_event_fd.init();
  std::atomic<int> s{0};
  s = 1;
  td::thread th([&] {
    while (s != 1) {
    }
    test_event_fd.acquire();
  });
  th.join();

  for (int i = 0; i < 1000; i++) {
    td::vector<td::EventFd> events(10);
    td::vector<td::thread> threads;
    for (auto &event : events) {
      event.init();
      event.release();
    }
    for (auto &event : events) {
      threads.emplace_back([&] {
        {
          td::EventFd tmp;
          tmp.init();
          tmp.acquire();
        }
        event.acquire();
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
#endif
}

TEST(Misc, get_last_argument) {
  auto a = td::make_unique<int>(5);
  ASSERT_EQ(*td::get_last_argument(std::move(a)), 5);
  ASSERT_EQ(*td::get_last_argument(1, 2, 3, 4, a), 5);
  ASSERT_EQ(*td::get_last_argument(a), 5);
  auto b = td::get_last_argument(1, 2, 3, std::move(a));
  ASSERT_TRUE(!a);
  ASSERT_EQ(*b, 5);
}

TEST(Misc, call_n_arguments) {
  auto f = [](int, int) {
  };
  td::call_n_arguments<2>(f, 1, 3, 4);
}

TEST(Misc, base64) {
  ASSERT_TRUE(td::is_base64("dGVzdA=="));
  ASSERT_TRUE(!td::is_base64("dGVzdB=="));
  ASSERT_TRUE(!td::is_base64("dGVzdA="));
  ASSERT_TRUE(!td::is_base64("dGVzdA"));
  ASSERT_TRUE(!td::is_base64("dGVzd"));
  ASSERT_TRUE(td::is_base64("dGVz"));
  ASSERT_TRUE(!td::is_base64("dGVz===="));
  ASSERT_TRUE(td::is_base64(""));
  ASSERT_TRUE(td::is_base64("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));
  ASSERT_TRUE(!td::is_base64("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="));
  ASSERT_TRUE(!td::is_base64("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-/"));
  ASSERT_TRUE(!td::is_base64("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"));
  ASSERT_TRUE(!td::is_base64("===="));

  ASSERT_TRUE(td::is_base64url("dGVzdA=="));
  ASSERT_TRUE(!td::is_base64url("dGVzdB=="));
  ASSERT_TRUE(!td::is_base64url("dGVzdA="));
  ASSERT_TRUE(td::is_base64url("dGVzdA"));
  ASSERT_TRUE(!td::is_base64url("dGVzd"));
  ASSERT_TRUE(td::is_base64url("dGVz"));
  ASSERT_TRUE(!td::is_base64url("dGVz===="));
  ASSERT_TRUE(td::is_base64url(""));
  ASSERT_TRUE(td::is_base64url("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"));
  ASSERT_TRUE(!td::is_base64url("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_="));
  ASSERT_TRUE(!td::is_base64url("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-/"));
  ASSERT_TRUE(!td::is_base64url("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));
  ASSERT_TRUE(!td::is_base64url("===="));

  ASSERT_TRUE(!td::is_base64_characters("dGVzdA=="));
  ASSERT_TRUE(!td::is_base64_characters("dGVzdB=="));
  ASSERT_TRUE(!td::is_base64_characters("dGVzdA="));
  ASSERT_TRUE(td::is_base64_characters("dGVzdA"));
  ASSERT_TRUE(td::is_base64_characters("dGVz"));
  ASSERT_TRUE(td::is_base64_characters(""));
  ASSERT_TRUE(td::is_base64_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));
  ASSERT_TRUE(!td::is_base64_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="));
  ASSERT_TRUE(!td::is_base64_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-/"));
  ASSERT_TRUE(!td::is_base64_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"));
  ASSERT_TRUE(!td::is_base64_characters("===="));

  ASSERT_TRUE(!td::is_base64url_characters("dGVzdA=="));
  ASSERT_TRUE(!td::is_base64url_characters("dGVzdB=="));
  ASSERT_TRUE(!td::is_base64url_characters("dGVzdA="));
  ASSERT_TRUE(td::is_base64url_characters("dGVzdA"));
  ASSERT_TRUE(td::is_base64url_characters("dGVz"));
  ASSERT_TRUE(td::is_base64url_characters(""));
  ASSERT_TRUE(td::is_base64url_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"));
  ASSERT_TRUE(!td::is_base64url_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_="));
  ASSERT_TRUE(!td::is_base64url_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-/"));
  ASSERT_TRUE(!td::is_base64url_characters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));
  ASSERT_TRUE(!td::is_base64url_characters("===="));

  for (int l = 0; l < 300000; l += l / 20 + l / 1000 * 500 + 1) {
    for (int t = 0; t < 10; t++) {
      auto s = td::rand_string(std::numeric_limits<char>::min(), std::numeric_limits<char>::max(), l);
      auto encoded = td::base64url_encode(s);
      auto decoded = td::base64url_decode(encoded);
      ASSERT_TRUE(decoded.is_ok());
      ASSERT_EQ(decoded.ok(), s);

      encoded = td::base64_encode(s);
      decoded = td::base64_decode(encoded);
      ASSERT_TRUE(decoded.is_ok());
      ASSERT_EQ(decoded.ok(), s);

      auto decoded_secure = td::base64_decode_secure(encoded);
      ASSERT_TRUE(decoded_secure.is_ok());
      ASSERT_EQ(decoded_secure.ok().as_slice(), s);
    }
  }

  ASSERT_TRUE(td::base64url_decode("dGVzdA").is_ok());
  ASSERT_TRUE(td::base64url_decode("dGVzdB").is_error());
  ASSERT_EQ(td::base64_encode(td::base64url_decode("dGVzdA").ok()), "dGVzdA==");
  ASSERT_EQ(td::base64_encode("any carnal pleas"), "YW55IGNhcm5hbCBwbGVhcw==");
  ASSERT_EQ(td::base64_encode("any carnal pleasu"), "YW55IGNhcm5hbCBwbGVhc3U=");
  ASSERT_EQ(td::base64_encode("any carnal pleasur"), "YW55IGNhcm5hbCBwbGVhc3Vy");
  ASSERT_EQ(td::base64_encode("      /'.;.';≤.];,].',[.;/,.;/]/..;!@#!*(%?::;!%\";"),
            "ICAgICAgLycuOy4nO+KJpC5dOyxdLicsWy47LywuOy9dLy4uOyFAIyEqKCU/Ojo7ISUiOw==");
  ASSERT_EQ(td::base64url_encode("ab><"), "YWI-PA");
  ASSERT_EQ(td::base64url_encode("ab><c"), "YWI-PGM");
  ASSERT_EQ(td::base64url_encode("ab><cd"), "YWI-PGNk");
}

static void test_zero_encode(td::Slice str, td::Slice expected_zero = td::Slice(),
                             td::Slice expected_zero_one = td::Slice()) {
  auto encoded = td::zero_encode(str);
  if (!expected_zero.empty()) {
    ASSERT_EQ(encoded, expected_zero);
  }
  ASSERT_EQ(td::zero_decode(encoded), str);

  encoded = td::zero_one_encode(str);
  if (!expected_zero_one.empty()) {
    ASSERT_EQ(encoded, expected_zero_one);
  }
  ASSERT_EQ(td::zero_one_decode(encoded), str);
}

TEST(Misc, zero_encode) {
  td::string str;
  for (unsigned char i = 1; i < 255; i++) {
    str += static_cast<char>(i);
  }
  test_zero_encode(str, str, str);

  test_zero_encode("");
  test_zero_encode(td::Slice("\0"), td::Slice("\0\1"), td::Slice("\0\1"));
  test_zero_encode(td::Slice("\0\xff\0\xff\0\xff\0\xff\0\xff\0\xff\0\xff"),
                   td::Slice("\0\1\xff\0\1\xff\0\1\xff\0\1\xff\0\1\xff\0\1\xff\0\1\xff"),
                   td::Slice("\0\1\xff\1\0\1\xff\1\0\1\xff\1\0\1\xff\1\0\1\xff\1\0\1\xff\1\0\1\xff\1"));
  test_zero_encode(td::Slice("\0\0\xff\xff\0\0\xff\xff\0\0\xff\xff\0\0\xff\xff\0\0\xff\xff\0\0\xff\xff"),
                   td::Slice("\0\2\xff\xff\0\2\xff\xff\0\2\xff\xff\0\2\xff\xff\0\2\xff\xff\0\2\xff\xff"),
                   td::Slice("\0\2\xff\2\0\2\xff\2\0\2\xff\2\0\2\xff\2\0\2\xff\2\0\2\xff\2"));
  test_zero_encode(td::Slice("\0\0\0\0\0\xff\xff\xff\xff\xff"), td::Slice("\0\5\xff\xff\xff\xff\xff"),
                   td::Slice("\0\5\xff\5"));
  test_zero_encode(td::Slice(
      "\0\0\0\0\0\xff\xff\xff\xff\xff\0\0\0\0\0\xff\xff\xff\xff\xff\0\0\0\0\0\xff\xff\xff\xff\xff\0\0\0\0\0\xff\xff\xff"
      "\xff\xff\0\0\0\0\0\xff\xff\xff\xff\xff\0\0\0\0\0\xff\xff\xff\xff\xff\0\0\0\0\0\xff\xff\xff\xff\xff"));
  test_zero_encode(td::string(1000, '\0'));
  test_zero_encode(str + td::string(1000, '\0') + str + td::string(1000, '\xff') + str);
}

class ZeroEncodeBenchmark final : public td::Benchmark {
 public:
  td::string get_description() const final {
    return "ZeroEncodeBenchmark";
  }

  void run(int n) final {
    for (int i = 0; i < n; i++) {
      zero_encode(
          td::Slice("\x02\x00\x00\x02\x01\x00\x00\x00\x19\x01\x00\x00\x7c\xc8\x64\xc1\x04\xec\x82\xb8\x20\x9e\xa0\x8d"
                    "\x1e\xbe\xb2\x79\xc4\x5a\x4c\x1e\x49\x1e\x00\x00\xa9\xa7\x31\x1b\x80\x9f\x11\x46\xfc\x97\xde\x6a"
                    "\x18\x6e\xc0\x73\x01\x00\x00\x00\x02\x00\x00\x00\x6d\x00\x00\x00\x30\x04"));
    }
  }
};

TEST(Misc, bench_zero_encode) {
  td::bench(ZeroEncodeBenchmark());
}

static void test_vector_split(td::vector<char> v, std::size_t size, const td::vector<td::vector<char>> &expected) {
  auto split = td::vector_split(std::move(v), size);
  if (expected != split) {
    LOG(FATAL) << "Receive " << split << ", expected " << expected << " in vector_split";
  }
}

TEST(Misc, vector_split) {
  test_vector_split({}, 1, {});
  test_vector_split({}, 2, {});
  test_vector_split({'1'}, 1, {{'1'}});
  test_vector_split({'1'}, 2, {{'1'}});
  td::vector<char> v{'1', '2', '3', '4', '5', '6'};
  test_vector_split(v, 1, {{'1'}, {'2'}, {'3'}, {'4'}, {'5'}, {'6'}});
  test_vector_split(v, 2, {{'1', '2'}, {'3', '4'}, {'5', '6'}});
  test_vector_split(v, 3, {{'1', '2', '3'}, {'4', '5', '6'}});
  test_vector_split(v, 4, {{'1', '2', '3', '4'}, {'5', '6'}});
  test_vector_split(v, 5, {{'1', '2', '3', '4', '5'}, {'6'}});
  test_vector_split(v, 6, {v});
  test_vector_split(v, 7, {v});
  test_vector_split(v, 107, {v});
  v.push_back('7');
  test_vector_split(v, 2, {{'1', '2'}, {'3', '4'}, {'5', '6'}, {'7'}});
}

template <class T>
static void test_remove_if(td::vector<int> v, const T &func, const td::vector<int> &expected) {
  td::remove_if(v, func);
  if (expected != v) {
    LOG(FATAL) << "Receive " << v << ", expected " << expected << " in remove_if";
  }
}

TEST(Misc, remove_if) {
  auto odd = [](int x) {
    return x % 2 == 1;
  };
  auto even = [](int x) {
    return x % 2 == 0;
  };
  auto all = [](int x) {
    return true;
  };
  auto none = [](int x) {
    return false;
  };

  td::vector<int> v{1, 2, 3, 4, 5, 6};
  test_remove_if(v, odd, {2, 4, 6});
  test_remove_if(v, even, {1, 3, 5});
  test_remove_if(v, all, {});
  test_remove_if(v, none, v);

  v = td::vector<int>{1, 3, 5, 2, 4, 6};
  test_remove_if(v, odd, {2, 4, 6});
  test_remove_if(v, even, {1, 3, 5});
  test_remove_if(v, all, {});
  test_remove_if(v, none, v);

  v.clear();
  test_remove_if(v, odd, v);
  test_remove_if(v, even, v);
  test_remove_if(v, all, v);
  test_remove_if(v, none, v);

  v.push_back(-1);
  test_remove_if(v, odd, v);
  test_remove_if(v, even, v);
  test_remove_if(v, all, {});
  test_remove_if(v, none, v);

  v[0] = 1;
  test_remove_if(v, odd, {});
  test_remove_if(v, even, v);
  test_remove_if(v, all, {});
  test_remove_if(v, none, v);

  v[0] = 2;
  test_remove_if(v, odd, v);
  test_remove_if(v, even, {});
  test_remove_if(v, all, {});
  test_remove_if(v, none, v);
}

static void test_remove(td::vector<int> v, int value, const td::vector<int> &expected) {
  bool is_found = expected != v;
  ASSERT_EQ(is_found, td::remove(v, value));
  if (expected != v) {
    LOG(FATAL) << "Receive " << v << ", expected " << expected << " in remove";
  }
}

TEST(Misc, remove) {
  td::vector<int> v{1, 2, 3, 4, 5, 6};
  test_remove(v, 0, {1, 2, 3, 4, 5, 6});
  test_remove(v, 1, {2, 3, 4, 5, 6});
  test_remove(v, 2, {1, 3, 4, 5, 6});
  test_remove(v, 3, {1, 2, 4, 5, 6});
  test_remove(v, 4, {1, 2, 3, 5, 6});
  test_remove(v, 5, {1, 2, 3, 4, 6});
  test_remove(v, 6, {1, 2, 3, 4, 5});
  test_remove(v, 7, {1, 2, 3, 4, 5, 6});

  v.clear();
  test_remove(v, -1, v);
  test_remove(v, 0, v);
  test_remove(v, 1, v);
}

static void test_add_to_top(td::vector<int> v, size_t max_size, int new_value, const td::vector<int> &expected) {
  auto u = v;
  td::add_to_top(v, max_size, new_value);
  ASSERT_EQ(expected, v);

  td::add_to_top_if(u, max_size, new_value, [new_value](int value) { return value == new_value; });
  ASSERT_EQ(expected, u);
}

static void test_add_to_top_if(td::vector<int> v, int max_size, int new_value, const td::vector<int> &expected) {
  td::add_to_top_if(v, max_size, new_value, [new_value](int value) { return value % 10 == new_value % 10; });
  ASSERT_EQ(expected, v);
}

TEST(Misc, add_to_top) {
  test_add_to_top({}, 0, 1, {1});
  test_add_to_top({}, 1, 1, {1});
  test_add_to_top({}, 6, 1, {1});

  test_add_to_top({1, 2, 3, 4, 5, 6}, 3, 2, {2, 1, 3, 4, 5, 6});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 6, 1, {1, 2, 3, 4, 5, 6});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 7, 1, {1, 2, 3, 4, 5, 6});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 6, 2, {2, 1, 3, 4, 5, 6});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 7, 2, {2, 1, 3, 4, 5, 6});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 6, 4, {4, 1, 2, 3, 5, 6});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 7, 4, {4, 1, 2, 3, 5, 6});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 6, 6, {6, 1, 2, 3, 4, 5});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 7, 6, {6, 1, 2, 3, 4, 5});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 6, 7, {7, 1, 2, 3, 4, 5});
  test_add_to_top({1, 2, 3, 4, 5, 6}, 7, 7, {7, 1, 2, 3, 4, 5, 6});

  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 6, 11, {1, 2, 3, 4, 5, 6});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 7, 21, {1, 2, 3, 4, 5, 6});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 6, 32, {2, 1, 3, 4, 5, 6});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 7, 42, {2, 1, 3, 4, 5, 6});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 6, 54, {4, 1, 2, 3, 5, 6});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 7, 64, {4, 1, 2, 3, 5, 6});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 6, 76, {6, 1, 2, 3, 4, 5});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 7, 86, {6, 1, 2, 3, 4, 5});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 6, 97, {97, 1, 2, 3, 4, 5});
  test_add_to_top_if({1, 2, 3, 4, 5, 6}, 7, 87, {87, 1, 2, 3, 4, 5, 6});
}

static void test_unique(td::vector<int> v, const td::vector<int> &expected) {
  auto v_str = td::transform(v, &td::to_string<int>);
  auto expected_str = td::transform(expected, &td::to_string<int>);

  td::unique(v);
  ASSERT_EQ(expected, v);

  td::unique(v_str);
  ASSERT_EQ(expected_str, v_str);
}

TEST(Misc, unique) {
  test_unique({1, 2, 3, 4, 5, 6}, {1, 2, 3, 4, 5, 6});
  test_unique({5, 2, 1, 6, 3, 4}, {1, 2, 3, 4, 5, 6});
  test_unique({}, {});
  test_unique({0}, {0});
  test_unique({0, 0}, {0});
  test_unique({0, 1}, {0, 1});
  test_unique({1, 0}, {0, 1});
  test_unique({1, 1}, {1});
  test_unique({1, 1, 0, 0}, {0, 1});
  test_unique({3, 3, 3, 3, 3, 2, 2, 2, 1, 1, 0}, {0, 1, 2, 3});
  test_unique({3, 3, 3, 3, 3}, {3});
  test_unique({3, 3, -1, 3, 3}, {-1, 3});
}

TEST(Misc, contains) {
  td::vector<int> v{1, 3, 5, 7, 4, 2};
  for (int i = -10; i < 20; i++) {
    ASSERT_EQ(td::contains(v, i), (1 <= i && i <= 5) || i == 7);
  }

  v.clear();
  ASSERT_TRUE(!td::contains(v, 0));
  ASSERT_TRUE(!td::contains(v, 1));

  td::string str = "abacaba";
  ASSERT_TRUE(!td::contains(str, '0'));
  ASSERT_TRUE(!td::contains(str, 0));
  ASSERT_TRUE(!td::contains(str, 'd'));
  ASSERT_TRUE(td::contains(str, 'a'));
  ASSERT_TRUE(td::contains(str, 'b'));
  ASSERT_TRUE(td::contains(str, 'c'));
}

TEST(Misc, base32) {
  ASSERT_EQ("", td::base32_encode(""));
  ASSERT_EQ("me", td::base32_encode("a"));
  td::base32_decode("me").ensure();
  ASSERT_EQ("mfra", td::base32_encode("ab"));
  ASSERT_EQ("mfrgg", td::base32_encode("abc"));
  ASSERT_EQ("mfrggza", td::base32_encode("abcd"));
  ASSERT_EQ("mfrggzdg", td::base32_encode("abcdf"));
  ASSERT_EQ("mfrggzdgm4", td::base32_encode("abcdfg"));
  for (int l = 0; l < 300000; l += l / 20 + l / 1000 * 500 + 1) {
    for (int t = 0; t < 10; t++) {
      auto s = td::rand_string(std::numeric_limits<char>::min(), std::numeric_limits<char>::max(), l);
      auto encoded = td::base32_encode(s);
      auto decoded = td::base32_decode(encoded);
      ASSERT_TRUE(decoded.is_ok());
      ASSERT_TRUE(decoded.ok() == s);
    }
  }
}

TEST(Misc, to_integer) {
  ASSERT_EQ(td::to_integer<td::int32>("-1234567"), -1234567);
  ASSERT_EQ(td::to_integer<td::int64>("-1234567"), -1234567);
  ASSERT_EQ(td::to_integer<td::uint32>("-1234567"), 0u);
  ASSERT_EQ(td::to_integer<td::int16>("-1234567"), 10617);
  ASSERT_EQ(td::to_integer<td::uint16>("-1234567"), 0u);
  ASSERT_EQ(td::to_integer<td::int16>("-1254567"), -9383);
  ASSERT_EQ(td::to_integer<td::uint16>("1254567"), 9383u);
  ASSERT_EQ(td::to_integer<td::int64>("-12345678910111213"), -12345678910111213);
  ASSERT_EQ(td::to_integer<td::uint64>("12345678910111213"), 12345678910111213ull);

  ASSERT_EQ(td::to_integer_safe<td::int32>("-1234567").ok(), -1234567);
  ASSERT_EQ(td::to_integer_safe<td::int64>("-1234567").ok(), -1234567);
  ASSERT_TRUE(td::to_integer_safe<td::uint32>("-1234567").is_error());
  ASSERT_TRUE(td::to_integer_safe<td::int16>("-1234567").is_error());
  ASSERT_TRUE(td::to_integer_safe<td::uint16>("-1234567").is_error());
  ASSERT_TRUE(td::to_integer_safe<td::int16>("-1254567").is_error());
  ASSERT_TRUE(td::to_integer_safe<td::uint16>("1254567").is_error());
  ASSERT_EQ(td::to_integer_safe<td::int64>("-12345678910111213").ok(), -12345678910111213);
  ASSERT_EQ(td::to_integer_safe<td::uint64>("12345678910111213").ok(), 12345678910111213ull);
  ASSERT_TRUE(td::to_integer_safe<td::uint64>("-12345678910111213").is_error());
}

static void test_to_double_one(td::CSlice str, td::Slice expected, int precision = 6) {
  auto result = PSTRING() << td::StringBuilder::FixedDouble(to_double(str), precision);
  if (expected != result) {
    LOG(ERROR) << "To double conversion failed: have " << str << ", expected " << expected << ", parsed "
               << to_double(str) << ", receive " << result;
  }
}

static void test_to_double() {
  test_to_double_one("0", "0.000000");
  test_to_double_one("1", "1.000000");
  test_to_double_one("-10", "-10.000000");
  test_to_double_one("1.234", "1.234000");
  test_to_double_one("-1.234e2", "-123.400000");
  test_to_double_one("inf", "inf");
  test_to_double_one("  inF  asdasd", "inf");
  test_to_double_one("  inFasdasd", "0.000000");
  test_to_double_one("  NaN", "nan");
  test_to_double_one("  12345678910111213141516171819  asdasd", "12345678910111213670658736128.000000");
  test_to_double_one("1.234567891011121314E123",
                     "1234567891011121363209105003376291141757777526749278953577304234065881343284952489418916814035346"
                     "625663604561924259911303168.000000");
  test_to_double_one("1.234567891011121314E-9", "0.000000");
  test_to_double_one("123456789", "123456789.000000");
  test_to_double_one("-1,234567891011121314E123", "-1.000000");
  test_to_double_one("123456789", "123456789", 0);
  test_to_double_one("1.23456789", "1", 0);
  test_to_double_one("1.23456789", "1.2", 1);
  test_to_double_one("1.23456789", "1.23", 2);
  test_to_double_one("1.23456789", "1.235", 3);
  test_to_double_one("1.23456789", "1.2346", 4);
  test_to_double_one("1.23456789", "1.23457", 5);
  test_to_double_one("1.23456789", "1.234568", 6);
  test_to_double_one("1.23456789", "1.2345679", 7);
  test_to_double_one("1.23456789", "1.23456789", 8);
  test_to_double_one("1.23456789", "1.234567890", 9);
  test_to_double_one("1.23456789", "1.2345678900", 10);
}

TEST(Misc, to_double) {
  test_to_double();
  std::locale new_locale("C");
  auto host_locale = std::locale::global(new_locale);
  test_to_double();
  new_locale = std::locale::global(std::locale::classic());
  test_to_double();
  auto classic_locale = std::locale::global(host_locale);
  test_to_double();
}

TEST(Misc, print_int) {
  ASSERT_STREQ("-9223372036854775808", PSLICE() << -9223372036854775807 - 1);
  ASSERT_STREQ("-2147483649", PSLICE() << -2147483649ll);
  ASSERT_STREQ("-2147483648", PSLICE() << -2147483647 - 1);
  ASSERT_STREQ("-2147483647", PSLICE() << -2147483647);
  ASSERT_STREQ("-123456789", PSLICE() << -123456789);
  ASSERT_STREQ("-1", PSLICE() << -1);
  ASSERT_STREQ("0", PSLICE() << 0);
  ASSERT_STREQ("1", PSLICE() << 1);
  ASSERT_STREQ("9", PSLICE() << 9);
  ASSERT_STREQ("10", PSLICE() << 10);
  ASSERT_STREQ("2147483647", PSLICE() << 2147483647);
  ASSERT_STREQ("2147483648", PSLICE() << 2147483648ll);
  ASSERT_STREQ("2147483649", PSLICE() << 2147483649ll);
  ASSERT_STREQ("9223372036854775807", PSLICE() << 9223372036854775807ll);
}

TEST(Misc, print_uint) {
  ASSERT_STREQ("0", PSLICE() << 0u);
  ASSERT_STREQ("1", PSLICE() << 1u);
  ASSERT_STREQ("9", PSLICE() << 9u);
  ASSERT_STREQ("10", PSLICE() << 10u);
  ASSERT_STREQ("2147483647", PSLICE() << 2147483647u);
  ASSERT_STREQ("2147483648", PSLICE() << 2147483648u);
  ASSERT_STREQ("2147483649", PSLICE() << 2147483649u);
  ASSERT_STREQ("9223372036854775807", PSLICE() << 9223372036854775807u);
}

static void test_idn_to_ascii_one(const td::string &host, const td::string &result) {
  if (result != td::idn_to_ascii(host).ok()) {
    LOG(ERROR) << "Failed to convert " << host << " to " << result << ", receive \"" << td::idn_to_ascii(host).ok()
               << "\"";
  }
}

TEST(Misc, idn_to_ascii) {
  test_idn_to_ascii_one("::::::::::::::::::::::::::::::::::::::@/", "::::::::::::::::::::::::::::::::::::::@/");
  test_idn_to_ascii_one("", "");
  test_idn_to_ascii_one("%30", "%30");
  test_idn_to_ascii_one("127.0.0.1", "127.0.0.1");
  test_idn_to_ascii_one("fe80::", "fe80::");
  test_idn_to_ascii_one("fe80:0:0:0:200:f8ff:fe21:67cf", "fe80:0:0:0:200:f8ff:fe21:67cf");
  test_idn_to_ascii_one("2001:0db8:11a3:09d7:1f34:8a2e:07a0:765d", "2001:0db8:11a3:09d7:1f34:8a2e:07a0:765d");
  test_idn_to_ascii_one("::ffff:192.0.2.1", "::ffff:192.0.2.1");
  test_idn_to_ascii_one("ABCDEF", "abcdef");
  test_idn_to_ascii_one("abcdef", "abcdef");
  test_idn_to_ascii_one("abæcdöef", "xn--abcdef-qua4k");
  test_idn_to_ascii_one("schön", "xn--schn-7qa");
  test_idn_to_ascii_one("ยจฆฟคฏข", "xn--22cdfh1b8fsa");
  test_idn_to_ascii_one("☺", "xn--74h");
  test_idn_to_ascii_one("правда", "xn--80aafi6cg");
  test_idn_to_ascii_one("büücher", "xn--bcher-kvaa");
  test_idn_to_ascii_one("BüüCHER", "xn--bcher-kvaa");
  test_idn_to_ascii_one("bücüher", "xn--bcher-kvab");
  test_idn_to_ascii_one("bücherü", "xn--bcher-kvae");
  test_idn_to_ascii_one("ýbücher", "xn--bcher-kvaf");
  test_idn_to_ascii_one("übücher", "xn--bcher-jvab");
  test_idn_to_ascii_one("bücher.tld", "xn--bcher-kva.tld");
  test_idn_to_ascii_one("кто.рф", "xn--j1ail.xn--p1ai");
  test_idn_to_ascii_one("wіkіреdіа.org", "xn--wkd-8cdx9d7hbd.org");
  test_idn_to_ascii_one("cnwin2k8中国.avol.com", "xn--cnwin2k8-sd0mx14e.avol.com");
  test_idn_to_ascii_one("win-2k12r2-addc.阿伯测阿伯测ad.hai.com", "win-2k12r2-addc.xn--ad-tl3ca3569aba8944eca.hai.com");
  test_idn_to_ascii_one("✌.ws", "xn--7bi.ws");
  //  test_idn_to_ascii_one("✌️.ws", "xn--7bi.ws"); // needs nameprep to succeed
  test_idn_to_ascii_one("⛧", "xn--59h");
  test_idn_to_ascii_one("--рф.рф", "xn-----mmcq.xn--p1ai");
  ASSERT_TRUE(td::idn_to_ascii("\xc0").is_error());
}

#if TD_WINDOWS
static void test_to_wstring_one(const td::string &str) {
  ASSERT_STREQ(str, td::from_wstring(td::to_wstring(str).ok()).ok());
}

TEST(Misc, to_wstring) {
  test_to_wstring_one("");
  for (int i = 0; i < 10; i++) {
    test_to_wstring_one("test");
    test_to_wstring_one("тест");
  }
  td::string str;
  for (td::uint32 i = 0; i <= 0xD7FF; i++) {
    td::append_utf8_character(str, i);
  }
  for (td::uint32 i = 0xE000; i <= 0x10FFFF; i++) {
    td::append_utf8_character(str, i);
  }
  test_to_wstring_one(str);
  ASSERT_TRUE(td::to_wstring("\xc0").is_error());
  auto emoji = td::to_wstring("🏟").ok();
  ASSERT_TRUE(td::from_wstring(emoji).ok() == "🏟");
  ASSERT_TRUE(emoji.size() == 2);
  auto emoji2 = emoji;
  emoji[0] = emoji[1];
  emoji2[1] = emoji2[0];
  ASSERT_TRUE(td::from_wstring(emoji).is_error());
  ASSERT_TRUE(td::from_wstring(emoji2).is_error());
  emoji2[0] = emoji[0];
  ASSERT_TRUE(td::from_wstring(emoji2).is_error());
}
#endif

static void test_translit(const td::string &word, const td::vector<td::string> &result, bool allow_partial = true) {
  ASSERT_EQ(result, td::get_word_transliterations(word, allow_partial));
}

TEST(Misc, translit) {
  test_translit("word", {"word", "ворд"});
  test_translit("", {});
  test_translit("ььььььььь", {"ььььььььь"});
  test_translit("крыло", {"krylo", "крыло"});
  test_translit("krylo", {"krylo", "крило"});
  test_translit("crylo", {"crylo", "крило"});
  test_translit("cheiia", {"cheiia", "кхеииа", "чейия"});
  test_translit("cheii", {"cheii", "кхеии", "чейи", "чейий", "чейия"});
  test_translit("s", {"s", "с", "ш", "щ"});
  test_translit("y", {"e", "y", "е", "и", "ю", "я"});
  test_translit("j", {"e", "j", "е", "й", "ю", "я"});
  test_translit("yo", {"e", "yo", "е", "ио"});
  test_translit("artjom", {"artem", "artjom", "артем", "артйом"});
  test_translit("artyom", {"artem", "artyom", "артем", "артиом"});
  test_translit("arty", {"arte", "arty", "арте", "арти", "артю", "артя"});
  test_translit("льи", {"li", "lia", "ly", "льи"});
  test_translit("y", {"y", "и"}, false);
  test_translit("yo", {"e", "yo", "е", "ио"}, false);
}

static void test_unicode(td::uint32 (*func)(td::uint32)) {
  for (td::uint32 i = 0; i <= 0x110000; i++) {
    auto res = func(i);
    CHECK(res <= 0x10ffff);
  }
}

TEST(Misc, unicode) {
  test_unicode(td::prepare_search_character);
  test_unicode(td::unicode_to_lower);
  test_unicode(td::remove_diacritics);
}

TEST(Misc, get_unicode_simple_category) {
  td::uint32 result = 0;
  for (size_t t = 0; t < 100; t++) {
    for (td::uint32 i = 0; i <= 0x10ffff; i++) {
      result = result * 123 + static_cast<td::uint32>(static_cast<int>(td::get_unicode_simple_category(i)));
    }
  }
  LOG(INFO) << result;
}

TEST(Misc, get_unicode_simple_category_small) {
  td::uint32 result = 0;
  for (size_t t = 0; t < 1000; t++) {
    for (td::uint32 i = 0; i <= 0xffff; i++) {
      result = result * 123 + static_cast<td::uint32>(static_cast<int>(td::get_unicode_simple_category(i)));
    }
  }
  LOG(INFO) << result;
}

TEST(BigNum, from_decimal) {
  ASSERT_TRUE(td::BigNum::from_decimal("").is_error());
  ASSERT_TRUE(td::BigNum::from_decimal("a").is_error());
  ASSERT_TRUE(td::BigNum::from_decimal("123a").is_error());
  ASSERT_TRUE(td::BigNum::from_decimal("-123a").is_error());
  // ASSERT_TRUE(td::BigNum::from_decimal("-").is_error());
  ASSERT_TRUE(td::BigNum::from_decimal("123").is_ok());
  ASSERT_TRUE(td::BigNum::from_decimal("-123").is_ok());
  ASSERT_TRUE(td::BigNum::from_decimal("0").is_ok());
  ASSERT_TRUE(td::BigNum::from_decimal("-0").is_ok());
  ASSERT_TRUE(td::BigNum::from_decimal("-999999999999999999999999999999999999999999999999").is_ok());
  ASSERT_TRUE(td::BigNum::from_decimal("999999999999999999999999999999999999999999999999").is_ok());
}

TEST(BigNum, from_binary) {
  ASSERT_STREQ(td::BigNum::from_binary("").to_decimal(), "0");
  ASSERT_STREQ(td::BigNum::from_binary("a").to_decimal(), "97");
  ASSERT_STREQ(td::BigNum::from_binary("\x00\xff").to_decimal(), "255");
  ASSERT_STREQ(td::BigNum::from_binary("\x00\x01\x00\x00").to_decimal(), "65536");
  ASSERT_STREQ(td::BigNum::from_le_binary("").to_decimal(), "0");
  ASSERT_STREQ(td::BigNum::from_le_binary("a").to_decimal(), "97");
  ASSERT_STREQ(td::BigNum::from_le_binary("\x00\xff").to_decimal(), "65280");
  ASSERT_STREQ(td::BigNum::from_le_binary("\x00\x01\x00\x00").to_decimal(), "256");
  ASSERT_STREQ(td::BigNum::from_decimal("255").move_as_ok().to_binary(), "\xff");
  ASSERT_STREQ(td::BigNum::from_decimal("255").move_as_ok().to_le_binary(), "\xff");
  ASSERT_STREQ(td::BigNum::from_decimal("255").move_as_ok().to_binary(2), "\x00\xff");
  ASSERT_STREQ(td::BigNum::from_decimal("255").move_as_ok().to_le_binary(2), "\xff\x00");
  ASSERT_STREQ(td::BigNum::from_decimal("65280").move_as_ok().to_binary(), "\xff\x00");
  ASSERT_STREQ(td::BigNum::from_decimal("65280").move_as_ok().to_le_binary(), "\x00\xff");
  ASSERT_STREQ(td::BigNum::from_decimal("65280").move_as_ok().to_binary(2), "\xff\x00");
  ASSERT_STREQ(td::BigNum::from_decimal("65280").move_as_ok().to_le_binary(2), "\x00\xff");
  ASSERT_STREQ(td::BigNum::from_decimal("65536").move_as_ok().to_binary(), "\x01\x00\x00");
  ASSERT_STREQ(td::BigNum::from_decimal("65536").move_as_ok().to_le_binary(), "\x00\x00\x01");
  ASSERT_STREQ(td::BigNum::from_decimal("65536").move_as_ok().to_binary(4), "\x00\x01\x00\x00");
  ASSERT_STREQ(td::BigNum::from_decimal("65536").move_as_ok().to_le_binary(4), "\x00\x00\x01\x00");
}

static void test_get_ipv4(td::uint32 ip) {
  td::IPAddress ip_address;
  ip_address.init_ipv4_port(td::IPAddress::ipv4_to_str(ip), 80).ensure();
  ASSERT_EQ(ip_address.get_ipv4(), ip);
}

TEST(Misc, IPAddress_get_ipv4) {
  test_get_ipv4(0x00000000);
  test_get_ipv4(0x010000FF);
  test_get_ipv4(0xFF000001);
  test_get_ipv4(0x01020304);
  test_get_ipv4(0x04030201);
  test_get_ipv4(0xFFFFFFFF);
}

static void test_is_reserved(const td::string &ip, bool is_reserved) {
  td::IPAddress ip_address;
  ip_address.init_ipv4_port(ip, 80).ensure();
  ASSERT_EQ(is_reserved, ip_address.is_reserved());
}

TEST(Misc, IPAddress_is_reserved) {
  test_is_reserved("0.0.0.0", true);
  test_is_reserved("0.255.255.255", true);
  test_is_reserved("1.0.0.0", false);
  test_is_reserved("5.0.0.0", false);
  test_is_reserved("9.255.255.255", false);
  test_is_reserved("10.0.0.0", true);
  test_is_reserved("10.255.255.255", true);
  test_is_reserved("11.0.0.0", false);
  test_is_reserved("100.63.255.255", false);
  test_is_reserved("100.64.0.0", true);
  test_is_reserved("100.127.255.255", true);
  test_is_reserved("100.128.0.0", false);
  test_is_reserved("126.255.255.255", false);
  test_is_reserved("127.0.0.0", true);
  test_is_reserved("127.255.255.255", true);
  test_is_reserved("128.0.0.0", false);
  test_is_reserved("169.253.255.255", false);
  test_is_reserved("169.254.0.0", true);
  test_is_reserved("169.254.255.255", true);
  test_is_reserved("169.255.0.0", false);
  test_is_reserved("172.15.255.255", false);
  test_is_reserved("172.16.0.0", true);
  test_is_reserved("172.31.255.255", true);
  test_is_reserved("172.32.0.0", false);
  test_is_reserved("191.255.255.255", false);
  test_is_reserved("192.0.0.0", true);
  test_is_reserved("192.0.0.255", true);
  test_is_reserved("192.0.1.0", false);
  test_is_reserved("192.0.1.255", false);
  test_is_reserved("192.0.2.0", true);
  test_is_reserved("192.0.2.255", true);
  test_is_reserved("192.0.3.0", false);
  test_is_reserved("192.88.98.255", false);
  test_is_reserved("192.88.99.0", true);
  test_is_reserved("192.88.99.255", true);
  test_is_reserved("192.88.100.0", false);
  test_is_reserved("192.167.255.255", false);
  test_is_reserved("192.168.0.0", true);
  test_is_reserved("192.168.255.255", true);
  test_is_reserved("192.169.0.0", false);
  test_is_reserved("198.17.255.255", false);
  test_is_reserved("198.18.0.0", true);
  test_is_reserved("198.19.255.255", true);
  test_is_reserved("198.20.0.0", false);
  test_is_reserved("198.51.99.255", false);
  test_is_reserved("198.51.100.0", true);
  test_is_reserved("198.51.100.255", true);
  test_is_reserved("198.51.101.0", false);
  test_is_reserved("203.0.112.255", false);
  test_is_reserved("203.0.113.0", true);
  test_is_reserved("203.0.113.255", true);
  test_is_reserved("203.0.114.0", false);
  test_is_reserved("223.255.255.255", false);
  test_is_reserved("224.0.0.0", true);
  test_is_reserved("239.255.255.255", true);
  test_is_reserved("240.0.0.0", true);
  test_is_reserved("255.255.255.254", true);
  test_is_reserved("255.255.255.255", true);
}

TEST(Misc, ipv6_clear) {
  td::IPAddress ip_address;
  ip_address.init_host_port("2001:0db8:85a3:0000:0000:8a2e:0370:7334", 123).ensure();
  ASSERT_EQ("2001:db8:85a3::8a2e:370:7334", ip_address.get_ip_str());
  ip_address.clear_ipv6_interface();
  ASSERT_EQ("2001:db8:85a3::", ip_address.get_ip_str());
}

static void test_split(td::Slice str, std::pair<td::Slice, td::Slice> expected) {
  ASSERT_EQ(expected, td::split(str));
}

TEST(Misc, split) {
  test_split("", {"", ""});
  test_split(" ", {"", ""});
  test_split("abcdef", {"abcdef", ""});
  test_split("abc def", {"abc", "def"});
  test_split("a bcdef", {"a", "bcdef"});
  test_split(" abcdef", {"", "abcdef"});
  test_split("abcdef ", {"abcdef", ""});
  test_split("ab cd ef", {"ab", "cd ef"});
  test_split("ab cdef ", {"ab", "cdef "});
  test_split(" abcd ef", {"", "abcd ef"});
  test_split(" abcdef ", {"", "abcdef "});
}

static void test_full_split(td::Slice str, const td::vector<td::Slice> &expected) {
  ASSERT_EQ(expected, td::full_split(str));
}

static void test_full_split(td::Slice str, char c, std::size_t max_parts, const td::vector<td::Slice> &expected) {
  ASSERT_EQ(expected, td::full_split(str, c, max_parts));
}

TEST(Misc, full_split) {
  test_full_split("", {});
  test_full_split(" ", {"", ""});
  test_full_split("  ", {"", "", ""});
  test_full_split("abcdef", {"abcdef"});
  test_full_split("abc def", {"abc", "def"});
  test_full_split("a bcdef", {"a", "bcdef"});
  test_full_split(" abcdef", {"", "abcdef"});
  test_full_split("abcdef ", {"abcdef", ""});
  test_full_split("ab cd ef", {"ab", "cd", "ef"});
  test_full_split("ab cdef ", {"ab", "cdef", ""});
  test_full_split(" abcd ef", {"", "abcd", "ef"});
  test_full_split(" abcdef ", {"", "abcdef", ""});
  test_full_split(" ab cd ef ", {"", "ab", "cd", "ef", ""});
  test_full_split("  ab  cd  ef  ", {"", "", "ab", "", "cd", "", "ef", "", ""});
  test_full_split("ab cd ef gh", ' ', 3, {"ab", "cd", "ef gh"});
}

TEST(Misc, StringBuilder) {
  auto small_str = td::string{"abcdefghij"};
  auto big_str = td::string(1000, 'a');
  using V = td::vector<td::string>;
  for (auto use_buf : {false, true}) {
    for (std::size_t initial_buffer_size : {0, 1, 5, 10, 100, 1000, 2000}) {
      for (const auto &test :
           {V{small_str}, V{small_str, big_str, big_str, small_str}, V{big_str, small_str, big_str}}) {
        td::string buf(initial_buffer_size, '\0');
        td::StringBuilder sb(buf, use_buf);
        td::string res;
        for (const auto &x : test) {
          res += x;
          sb << x;
        }
        if (use_buf) {
          ASSERT_EQ(res, sb.as_cslice());
        } else {
          auto sb_result = sb.as_cslice();
          res.resize(sb_result.size());
          ASSERT_EQ(res, sb_result);
        }
      }
    }
  }
}

TEST(Misc, As) {
  char buf[100];
  td::as<int>(buf) = 123;
  ASSERT_EQ(123, td::as<int>(static_cast<const char *>(buf)));
  ASSERT_EQ(123, td::as<int>(static_cast<char *>(buf)));
  char buf2[100];
  td::as<int>(buf2) = td::as<int>(buf);
  ASSERT_EQ(123, td::as<int>(static_cast<const char *>(buf2)));
  ASSERT_EQ(123, td::as<int>(static_cast<char *>(buf2)));
}

TEST(Misc, Regression) {
  td::string name = "regression_db";
  td::RegressionTester::destroy(name);

  {
    auto tester = td::RegressionTester::create(name);
    tester->save_db();
    tester->verify_test("one_plus_one", "two").ensure();
    tester->verify_test("one_plus_one", "two").ensure();
    tester->verify_test("two_plus_one", "three").ensure();
    tester->verify_test("one_plus_one", "two").ensure();
    tester->verify_test("two_plus_one", "three").ensure();
    tester->save_db();
  }
  {
    auto tester = td::RegressionTester::create(name);
    tester->save_db();
    tester->verify_test("one_plus_one", "two").ensure();
    tester->verify_test("one_plus_one", "two").ensure();
    tester->verify_test("two_plus_one", "three").ensure();
    tester->verify_test("one_plus_one", "two").ensure();
    tester->verify_test("two_plus_one", "three").ensure();
    tester->save_db();
    tester->verify_test("one_plus_one", "three").ensure_error();
    tester->verify_test("two_plus_one", "two").ensure_error();
  }
  {
    auto tester = td::RegressionTester::create(name);
    tester->verify_test("one_plus_one", "three").ensure_error();
    tester->verify_test("two_plus_one", "two").ensure_error();
  }
}

TEST(Misc, Bits) {
  ASSERT_EQ(32, td::count_leading_zeroes32(0));
  ASSERT_EQ(64, td::count_leading_zeroes64(0));
  ASSERT_EQ(32, td::count_trailing_zeroes32(0));
  ASSERT_EQ(64, td::count_trailing_zeroes64(0));

  for (int i = 0; i < 32; i++) {
    ASSERT_EQ(31 - i, td::count_leading_zeroes32(1u << i));
    ASSERT_EQ(i, td::count_trailing_zeroes32(1u << i));
    ASSERT_EQ(31 - i, td::count_leading_zeroes_non_zero32(1u << i));
    ASSERT_EQ(i, td::count_trailing_zeroes_non_zero32(1u << i));
  }
  for (int i = 0; i < 64; i++) {
    ASSERT_EQ(63 - i, td::count_leading_zeroes64(1ull << i));
    ASSERT_EQ(i, td::count_trailing_zeroes64(1ull << i));
    ASSERT_EQ(63 - i, td::count_leading_zeroes_non_zero64(1ull << i));
    ASSERT_EQ(i, td::count_trailing_zeroes_non_zero64(1ull << i));
  }

  ASSERT_EQ(0x12345678u, td::bswap32(0x78563412u));
  ASSERT_EQ(0x12345678abcdef67ull, td::bswap64(0x67efcdab78563412ull));

  td::uint8 buf[8] = {1, 90, 2, 18, 129, 255, 0, 2};
  td::uint64 num2 = td::bswap64(td::as<td::uint64>(buf));
  td::uint64 num = (static_cast<td::uint64>(buf[0]) << 56) | (static_cast<td::uint64>(buf[1]) << 48) |
                   (static_cast<td::uint64>(buf[2]) << 40) | (static_cast<td::uint64>(buf[3]) << 32) |
                   (static_cast<td::uint64>(buf[4]) << 24) | (static_cast<td::uint64>(buf[5]) << 16) |
                   (static_cast<td::uint64>(buf[6]) << 8) | (static_cast<td::uint64>(buf[7]));
  ASSERT_EQ(num, num2);

  ASSERT_EQ(0, td::count_bits32(0));
  ASSERT_EQ(0, td::count_bits64(0));
  ASSERT_EQ(4, td::count_bits32((1u << 31) | 7));
  ASSERT_EQ(4, td::count_bits64((1ull << 63) | 7));
}

TEST(Misc, BitsRange) {
  auto to_vec_a = [](td::uint64 x) {
    td::vector<td::int32> bits;
    for (auto i : td::BitsRange(x)) {
      bits.push_back(i);
    }
    return bits;
  };

  auto to_vec_b = [](td::uint64 x) {
    td::vector<td::int32> bits;
    td::int32 pos = 0;
    while (x != 0) {
      if ((x & 1) != 0) {
        bits.push_back(pos);
      }
      x >>= 1;
      pos++;
    }
    return bits;
  };

  auto do_check = [](const td::vector<td::int32> &a, const td::vector<td::int32> &b) {
    ASSERT_EQ(b, a);
  };
  auto check = [&](td::uint64 x) {
    do_check(to_vec_a(x), to_vec_b(x));
  };

  do_check(to_vec_a(21), {0, 2, 4});
  for (int x = 0; x < 100; x++) {
    check(x);
    check(std::numeric_limits<td::uint32>::max() - x);
    check(std::numeric_limits<td::uint64>::max() - x);
  }
}

#if !TD_THREAD_UNSUPPORTED
TEST(Misc, Time) {
  td::Stage run;
  td::Stage check;
  td::Stage finish;

  std::size_t threads_n = 3;
  td::vector<td::thread> threads;
  td::vector<std::atomic<double>> ts(threads_n);
  for (std::size_t i = 0; i < threads_n; i++) {
    threads.emplace_back([&, thread_id = i] {
      for (td::uint64 round = 1; round < 10000; round++) {
        ts[thread_id] = 0;
        run.wait(round * threads_n);
        ts[thread_id] = td::Time::now();
        check.wait(round * threads_n);
        for (auto &ts_ref : ts) {
          auto other_ts = ts_ref.load();
          if (other_ts != 0) {
            ASSERT_TRUE(other_ts <= td::Time::now_cached());
          }
        }

        finish.wait(round * threads_n);
      }
    });
  }
  for (auto &thread : threads) {
    thread.join();
  }
}
#endif

TEST(Misc, uint128) {
  td::vector<td::uint64> parts = {0,
                                  1,
                                  2000,
                                  2001,
                                  std::numeric_limits<td::uint64>::max(),
                                  std::numeric_limits<td::uint64>::max() - 1,
                                  std::numeric_limits<td::uint32>::max(),
                                  static_cast<td::uint64>(std::numeric_limits<td::uint32>::max()) + 1};
  td::vector<td::int64> signed_parts = {0,
                                        1,
                                        2000,
                                        2001,
                                        -1,
                                        -2000,
                                        -2001,
                                        std::numeric_limits<td::int64>::max(),
                                        std::numeric_limits<td::int64>::max() - 1,
                                        std::numeric_limits<td::int64>::min(),
                                        std::numeric_limits<td::int64>::min() + 1,
                                        std::numeric_limits<td::int32>::max(),
                                        static_cast<td::int64>(std::numeric_limits<td::int32>::max()) + 1,
                                        std::numeric_limits<td::int32>::max() - 1,
                                        std::numeric_limits<td::int32>::min(),
                                        std::numeric_limits<td::int32>::min() + 1,
                                        static_cast<td::int64>(std::numeric_limits<td::int32>::min()) - 1};

#if TD_HAVE_INT128
  auto to_intrinsic = [](td::uint128_emulated num) {
    return td::uint128_intrinsic(num.hi(), num.lo());
  };
  auto eq = [](td::uint128_emulated a, td::uint128_intrinsic b) {
    return a.hi() == b.hi() && a.lo() == b.lo();
  };
  auto ensure_eq = [&](td::uint128_emulated a, td::uint128_intrinsic b) {
    if (!eq(a, b)) {
      LOG(FATAL) << "[" << a.hi() << ";" << a.lo() << "] vs [" << b.hi() << ";" << b.lo() << "]";
    }
  };
#endif

  td::vector<td::uint128_emulated> nums;
  for (auto hi : parts) {
    for (auto lo : parts) {
      auto a = td::uint128_emulated(hi, lo);
#if TD_HAVE_INT128
      auto ia = td::uint128_intrinsic(hi, lo);
      ensure_eq(a, ia);
#endif
      nums.push_back(a);
      nums.pop_back();
      nums.push_back({hi, lo});
    }
  }

#if TD_HAVE_INT128
  for (auto a : nums) {
    auto ia = to_intrinsic(a);
    ensure_eq(a, ia);
    CHECK(a.is_zero() == ia.is_zero());
    for (int i = 0; i <= 130; i++) {
      ensure_eq(a.shl(i), ia.shl(i));
      ensure_eq(a.shr(i), ia.shr(i));
    }
    for (auto b : parts) {
      ensure_eq(a.mult(b), ia.mult(b));
    }
    for (auto b : signed_parts) {
      ensure_eq(a.mult_signed(b), ia.mult_signed(b));
      if (b == 0) {
        continue;
      }
      td::int64 q;
      td::int64 r;
      a.divmod_signed(b, &q, &r);
      td::int64 iq;
      td::int64 ir;
      ia.divmod_signed(b, &iq, &ir);
      ASSERT_EQ(q, iq);
      ASSERT_EQ(r, ir);
    }
    for (auto b : nums) {
      auto ib = to_intrinsic(b);
      //LOG(ERROR) << ia.hi() << ";" << ia.lo() << " " << ib.hi() << ";" << ib.lo();
      ensure_eq(a.mult(b), ia.mult(ib));
      ensure_eq(a.add(b), ia.add(ib));
      ensure_eq(a.sub(b), ia.sub(ib));
      if (!b.is_zero()) {
        ensure_eq(a.div(b), ia.div(ib));
        ensure_eq(a.mod(b), ia.mod(ib));
      }
    }
  }

  for (auto signed_part : signed_parts) {
    auto a = td::uint128_emulated::from_signed(signed_part);
    auto ia = td::uint128_intrinsic::from_signed(signed_part);
    ensure_eq(a, ia);
  }
#endif
}

template <template <class T> class HashT, class ValueT>
static td::Status test_hash(const td::vector<ValueT> &values) {
  for (std::size_t i = 0; i < values.size(); i++) {
    for (std::size_t j = i; j < values.size(); j++) {
      auto &a = values[i];
      auto &b = values[j];
      auto a_hash = HashT<ValueT>()(a);
      auto b_hash = HashT<ValueT>()(b);
      if (a == b) {
        if (a_hash != b_hash) {
          return td::Status::Error("Hash differs for same values");
        }
      } else {
        if (a_hash == b_hash) {
          return td::Status::Error("Hash is the same for different values");
        }
      }
    }
  }
  return td::Status::OK();
}

class BadValue {
 public:
  explicit BadValue(std::size_t value) : value_(value) {
  }

  template <class H>
  friend H AbslHashValue(H hasher, const BadValue &value) {
    return hasher;
  }
  bool operator==(const BadValue &other) const {
    return value_ == other.value_;
  }

 private:
  std::size_t value_;
};

class ValueA {
 public:
  explicit ValueA(std::size_t value) : value_(value) {
  }
  template <class H>
  friend H AbslHashValue(H hasher, ValueA value) {
    return H::combine(std::move(hasher), value.value_);
  }
  bool operator==(const ValueA &other) const {
    return value_ == other.value_;
  }

 private:
  std::size_t value_;
};

class ValueB {
 public:
  explicit ValueB(std::size_t value) : value_(value) {
  }

  template <class H>
  friend H AbslHashValue(H hasher, ValueB value) {
    return H::combine(std::move(hasher), value.value_);
  }
  bool operator==(const ValueB &other) const {
    return value_ == other.value_;
  }

 private:
  std::size_t value_;
};

template <template <class T> class HashT>
static void test_hash() {
  // Just check that the following compiles
  AbslHashValue(td::Hasher(), ValueA{1});
  HashT<ValueA>()(ValueA{1});
  std::unordered_map<ValueA, int, HashT<ValueA>> s;
  s[ValueA{1}] = 1;
  td::HashMap<ValueA, int> su;
  su[ValueA{1}] = 1;
  td::HashSet<ValueA> su2;
  su2.insert(ValueA{1});
#if TD_HAVE_ABSL
  std::unordered_map<ValueA, int, absl::Hash<ValueA>> x;
  absl::flat_hash_map<ValueA, int, HashT<ValueA>> sa;
  sa[ValueA{1}] = 1;
#endif

  test_hash<HashT, std::size_t>({1, 2, 3, 4, 5}).ensure();
  test_hash<HashT, BadValue>({BadValue{1}, BadValue{2}}).ensure_error();
  test_hash<HashT, ValueA>({ValueA{1}, ValueA{2}}).ensure();
  test_hash<HashT, ValueB>({ValueB{1}, ValueB{2}}).ensure();
  test_hash<HashT, std::pair<int, int>>({{1, 1}, {1, 2}}).ensure();
  // FIXME: use some better hash
  //test_hash<HashT, std::pair<int, int>>({{1, 1}, {1, 2}, {2, 1}, {2, 2}}).ensure();
}

TEST(Misc, Hasher) {
  test_hash<td::TdHash>();
#if TD_HAVE_ABSL
  test_hash<td::AbslHash>();
#endif
}

TEST(Misc, CancellationToken) {
  td::CancellationTokenSource source;
  source.cancel();
  auto token1 = source.get_cancellation_token();
  auto token2 = source.get_cancellation_token();
  CHECK(!token1);
  source.cancel();
  CHECK(token1);
  CHECK(token2);
  auto token3 = source.get_cancellation_token();
  CHECK(!token3);
  source.cancel();
  CHECK(token3);

  auto token4 = source.get_cancellation_token();
  CHECK(!token4);
  source = td::CancellationTokenSource{};
  CHECK(token4);
}

TEST(Misc, Xorshift128plus) {
  td::Random::Xorshift128plus rnd(123);
  ASSERT_EQ(11453256657207062272ull, rnd());
  ASSERT_EQ(14917490455889357332ull, rnd());
  ASSERT_EQ(5645917797309401285ull, rnd());
  ASSERT_EQ(13554822455746959330ull, rnd());
}

TEST(Misc, uname) {
  auto first_version = td::get_operating_system_version();
  auto second_version = td::get_operating_system_version();
  ASSERT_STREQ(first_version, second_version);
  ASSERT_EQ(first_version.begin(), second_version.begin());
  ASSERT_TRUE(!first_version.empty());
}

TEST(Misc, serialize) {
  td::int32 x = 1;
  ASSERT_EQ(td::base64_encode(td::serialize(x)), td::base64_encode(td::string("\x01\x00\x00\x00", 4)));
  td::int64 y = -2;
  ASSERT_EQ(td::base64_encode(td::serialize(y)), td::base64_encode(td::string("\xfe\xff\xff\xff\xff\xff\xff\xff", 8)));
}

TEST(Misc, check_reset_guard) {
  CheckExitGuard check_exit_guard{false};
}

TEST(FloodControl, Fast) {
  td::FloodControlFast fc;
  fc.add_limit(1, 5);
  fc.add_limit(5, 10);

  td::int32 count = 0;
  double now = 0;
  for (int i = 0; i < 100; i++) {
    now = fc.get_wakeup_at();
    fc.add_event(now);
    LOG(INFO) << ++count << ": " << now;
  }
}

TEST(UniqueValuePtr, Basic) {
  auto a = td::make_unique_value<int>(5);
  td::unique_value_ptr<int> b;
  ASSERT_TRUE(b == nullptr);
  ASSERT_TRUE(a != nullptr);
  ASSERT_TRUE(a != b);
  b = a;
  ASSERT_TRUE(a != nullptr);
  ASSERT_TRUE(b != nullptr);
  ASSERT_TRUE(a == b);
  *a = 6;
  ASSERT_TRUE(a != nullptr);
  ASSERT_TRUE(b != nullptr);
  ASSERT_TRUE(a != b);
  b = std::move(a);
  ASSERT_TRUE(a == nullptr);
  ASSERT_TRUE(b != nullptr);
  ASSERT_TRUE(a != b);
  auto c = td::make_unique_value<td::unique_value_ptr<int>>(a);
  ASSERT_TRUE(*c == a);
  ASSERT_TRUE(*c == nullptr);
  c = td::make_unique_value<td::unique_value_ptr<int>>(b);
  ASSERT_TRUE(*c == b);
  ASSERT_TRUE(**c == 6);
  auto d = c;
  ASSERT_TRUE(c == d);
  ASSERT_TRUE(6 == **d);
}
