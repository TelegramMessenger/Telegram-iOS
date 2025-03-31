//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/telegram_api.hpp"

#include "td/utils/algorithm.h"
#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/EventFd.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/RwMutex.h"
#include "td/utils/port/Stat.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/ThreadSafeCounter.h"

#if !TD_WINDOWS
#include <unistd.h>
#include <utime.h>
#endif

#if TD_LINUX || TD_ANDROID || TD_TIZEN
#include <semaphore.h>
#endif

#include <algorithm>
#include <array>
#include <atomic>
#include <cstdint>
#include <set>

class F {
  td::uint32 &sum;

 public:
  explicit F(td::uint32 &sum) : sum(sum) {
  }

  template <class T>
  void operator()(const T &x) const {
    sum += static_cast<td::uint32>(reinterpret_cast<std::uintptr_t>(&x));
  }
};

BENCH(TlCall, "TL Call") {
  td::tl_object_ptr<td::telegram_api::Function> x = td::make_tl_object<td::telegram_api::account_getWallPapers>(0);
  td::uint32 res = 0;
  F f(res);
  for (int i = 0; i < n; i++) {
    downcast_call(*x, f);
  }
  td::do_not_optimize_away(res);
}

static td::td_api::object_ptr<td::td_api::file> get_file_object() {
  return td::td_api::make_object<td::td_api::file>(
      12345, 123456, 123456,
      td::td_api::make_object<td::td_api::localFile>(
          "/android/data/0/data/org.telegram.data/files/photos/12345678901234567890_123.jpg", true, true, false, true,
          0, 123456, 123456),
      td::td_api::make_object<td::td_api::remoteFile>("abacabadabacabaeabacabadabacabafabacabadabacabaeabacabadabacaba",
                                                      "abacabadabacabaeabacabadabacaba", false, true, 123456));
}

BENCH(ToStringIntSmall, "to_string<int> small") {
  auto buf = td::StackAllocator::alloc(1000);
  td::StringBuilder sb(buf.as_slice());
  for (int i = 0; i < n; i++) {
    sb << td::Random::fast(0, 100);
    sb.clear();
  }
}

BENCH(ToStringIntBig, "to_string<int> big") {
  auto buf = td::StackAllocator::alloc(1000);
  td::StringBuilder sb(buf.as_slice());
  for (int i = 0; i < n; i++) {
    sb << 1234567890;
    sb.clear();
  }
}

BENCH(TlToStringUpdateFile, "TL to_string updateFile") {
  auto x = td::td_api::make_object<td::td_api::updateFile>(get_file_object());

  std::size_t res = 0;
  for (int i = 0; i < n; i++) {
    res += to_string(x).size();
  }
  td::do_not_optimize_away(res);
}

BENCH(TlToStringMessage, "TL to_string message") {
  auto x = td::td_api::make_object<td::td_api::message>();
  x->id_ = 123456000111;
  x->sender_id_ = td::td_api::make_object<td::td_api::messageSenderUser>(123456000112);
  x->chat_id_ = 123456000112;
  x->sending_state_ = td::td_api::make_object<td::td_api::messageSendingStatePending>(0);
  x->date_ = 1699999999;
  auto photo = td::td_api::make_object<td::td_api::photo>();
  for (int i = 0; i < 4; i++) {
    photo->sizes_.push_back(td::td_api::make_object<td::td_api::photoSize>(
        "a", get_file_object(), 160, 160,
        td::vector<td::int32>{10000, 20000, 30000, 50000, 70000, 90000, 120000, 150000, 180000, 220000}));
  }
  x->content_ = td::td_api::make_object<td::td_api::messagePhoto>(
      std::move(photo), td::td_api::make_object<td::td_api::formattedText>(), false, false, false);

  std::size_t res = 0;
  for (int i = 0; i < n; i++) {
    res += to_string(x).size();
  }
  td::do_not_optimize_away(res);
}

#if !TD_EVENTFD_UNSUPPORTED
BENCH(EventFd, "EventFd") {
  td::EventFd fd;
  fd.init();
  for (int i = 0; i < n; i++) {
    fd.release();
    fd.acquire();
  }
  fd.close();
}
#endif

BENCH(NewInt, "new int + delete") {
  std::uintptr_t res = 0;
  for (int i = 0; i < n; i++) {
    int *x = new int;
    res += reinterpret_cast<std::uintptr_t>(x);
    delete x;
  }
  td::do_not_optimize_away(res);
}

BENCH(NewObj, "new struct, then delete") {
  struct A {
    td::int32 a = 0;
    td::int32 b = 0;
    td::int32 c = 0;
    td::int32 d = 0;
  };
  std::uintptr_t res = 0;
  A **ptr = new A *[n];
  for (int i = 0; i < n; i++) {
    ptr[i] = new A();
    res += reinterpret_cast<std::uintptr_t>(ptr[i]);
  }
  for (int i = 0; i < n; i++) {
    delete ptr[i];
  }
  delete[] ptr;
  td::do_not_optimize_away(res);
}

#if !TD_THREAD_UNSUPPORTED
BENCH(ThreadNew, "new struct, then delete in 2 threads") {
  NewObjBench a;
  NewObjBench b;
  td::thread ta([&] { a.run(n / 2); });
  td::thread tb([&] { b.run(n - n / 2); });
  ta.join();
  tb.join();
}
#endif
/*
// Too hard for clang (?)
BENCH(Time, "Clocks::monotonic") {
  double res = 0;
  for (int i = 0; i < n; i++) {
    res += td::Clocks::monotonic();
  }
  td::do_not_optimize_away(res);
}
*/
#if !TD_WINDOWS
class PipeBench final : public td::Benchmark {
 public:
  int p[2];

  td::string get_description() const final {
    return "pipe write + read int32";
  }

  void start_up() final {
    int res = pipe(p);
    CHECK(res == 0);
  }

  void run(int n) final {
    int res = 0;
    for (int i = 0; i < n; i++) {
      int val = 1;
      auto write_len = write(p[1], &val, sizeof(val));
      CHECK(write_len == sizeof(val));
      auto read_len = read(p[0], &val, sizeof(val));
      CHECK(read_len == sizeof(val));
      res += val;
    }
    td::do_not_optimize_away(res);
  }

  void tear_down() final {
    close(p[0]);
    close(p[1]);
  }
};
#endif

#if TD_LINUX || TD_ANDROID || TD_TIZEN
class SemBench final : public td::Benchmark {
  sem_t sem;

 public:
  td::string get_description() const final {
    return "sem post + wait";
  }

  void start_up() final {
    int err = sem_init(&sem, 0, 0);
    CHECK(err != -1);
  }

  void run(int n) final {
    for (int i = 0; i < n; i++) {
      sem_post(&sem);
      sem_wait(&sem);
    }
  }

  void tear_down() final {
    sem_destroy(&sem);
  }
};
#endif

#if !TD_WINDOWS
class UtimeBench final : public td::Benchmark {
 public:
  void start_up() final {
    td::FileFd::open("test", td::FileFd::Create | td::FileFd::Write).move_as_ok().close();
  }
  td::string get_description() const final {
    return "utime";
  }
  void run(int n) final {
    for (int i = 0; i < n; i++) {
      int err = utime("test", nullptr);
      CHECK(err >= 0);
      utimbuf buf;
      buf.modtime = 123;
      buf.actime = 321;
      err = utime("test", &buf);
      CHECK(err >= 0);
    }
  }
};
#endif

BENCH(Pwrite, "pwrite") {
  auto fd = td::FileFd::open("test", td::FileFd::Create | td::FileFd::Write).move_as_ok();
  for (int i = 0; i < n; i++) {
    fd.pwrite("a", 0).ok();
  }
  fd.close();
}

class CreateFileBench final : public td::Benchmark {
  td::string get_description() const final {
    return "create_file";
  }
  void start_up() final {
    td::mkdir("A").ensure();
  }
  void run(int n) final {
    for (int i = 0; i < n; i++) {
      td::FileFd::open(PSLICE() << "A/" << i, td::FileFd::Write | td::FileFd::Create).move_as_ok().close();
    }
  }
  void tear_down() final {
    td::rmrf("A/").ignore();
  }
};

class WalkPathBench final : public td::Benchmark {
  td::string get_description() const final {
    return "walk_path";
  }
  void start_up_n(int n) final {
    td::mkdir("A").ensure();
    for (int i = 0; i < n; i++) {
      td::FileFd::open(PSLICE() << "A/" << i, td::FileFd::Write | td::FileFd::Create).move_as_ok().close();
    }
  }
  void run(int n) final {
    int cnt = 0;
    td::walk_path("A/", [&](td::CSlice path, auto type) {
      if (type == td::WalkPath::Type::EnterDir) {
        return;
      }
      td::stat(path).ok();
      cnt++;
    }).ignore();
  }
  void tear_down() final {
    td::rmrf("A/").ignore();
  }
};

#if !TD_THREAD_UNSUPPORTED
template <int ThreadN = 2>
class AtomicReleaseIncBench final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "AtomicReleaseInc" << ThreadN;
  }

  static std::atomic<td::uint64> a_;
  void run(int n) final {
    td::vector<td::thread> threads;
    for (int i = 0; i < ThreadN; i++) {
      threads.emplace_back([&] {
        for (int i = 0; i < n / ThreadN; i++) {
          a_.fetch_add(1, std::memory_order_release);
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
};
template <int ThreadN>
std::atomic<td::uint64> AtomicReleaseIncBench<ThreadN>::a_;

template <int ThreadN = 2>
class AtomicReleaseCasIncBench final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "AtomicReleaseCasInc" << ThreadN;
  }

  static std::atomic<td::uint64> a_;
  void run(int n) final {
    td::vector<td::thread> threads;
    for (int i = 0; i < ThreadN; i++) {
      threads.emplace_back([&] {
        for (int i = 0; i < n / ThreadN; i++) {
          auto value = a_.load(std::memory_order_relaxed);
          while (!a_.compare_exchange_strong(value, value + 1, std::memory_order_release, std::memory_order_relaxed)) {
          }
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
};
template <int ThreadN>
std::atomic<td::uint64> AtomicReleaseCasIncBench<ThreadN>::a_;

template <int ThreadN>
class RwMutexReadBench final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "RwMutexRead" << ThreadN;
  }
  td::RwMutex mutex_;
  void run(int n) final {
    td::vector<td::thread> threads;
    for (int i = 0; i < ThreadN; i++) {
      threads.emplace_back([&] {
        for (int i = 0; i < n / ThreadN; i++) {
          auto lock = mutex_.lock_read();
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
};

template <int ThreadN>
class RwMutexWriteBench final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "RwMutexWrite" << ThreadN;
  }
  td::RwMutex mutex_;
  void run(int n) final {
    td::vector<td::thread> threads;
    for (int i = 0; i < ThreadN; i++) {
      threads.emplace_back([&] {
        for (int i = 0; i < n / ThreadN; i++) {
          auto lock = mutex_.lock_write();
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
};

class ThreadSafeCounterBench final : public td::Benchmark {
  static td::ThreadSafeCounter counter_;
  int thread_count_;

  td::string get_description() const final {
    return PSTRING() << "ThreadSafeCounter" << thread_count_;
  }
  void run(int n) final {
    counter_.clear();
    td::vector<td::thread> threads;
    for (int i = 0; i < thread_count_; i++) {
      threads.emplace_back([n] {
        for (int i = 0; i < n; i++) {
          counter_.add(1);
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
    CHECK(counter_.sum() == n * thread_count_);
  }

 public:
  explicit ThreadSafeCounterBench(int thread_count) : thread_count_(thread_count) {
  }
};
td::ThreadSafeCounter ThreadSafeCounterBench::counter_;

template <bool StrictOrder>
class AtomicCounterBench final : public td::Benchmark {
  static std::atomic<td::int64> counter_;
  int thread_count_;

  td::string get_description() const final {
    return PSTRING() << "AtomicCounter" << thread_count_;
  }
  void run(int n) final {
    counter_.store(0);
    td::vector<td::thread> threads;
    for (int i = 0; i < thread_count_; i++) {
      threads.emplace_back([n] {
        for (int i = 0; i < n; i++) {
          counter_.fetch_add(1, StrictOrder ? std::memory_order_seq_cst : std::memory_order_relaxed);
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
    CHECK(counter_.load() == n * thread_count_);
  }

 public:
  explicit AtomicCounterBench(int thread_count) : thread_count_(thread_count) {
  }
};
template <bool StrictOrder>
std::atomic<td::int64> AtomicCounterBench<StrictOrder>::counter_;

#endif

class IdDuplicateCheckerOld {
 public:
  static td::string get_description() {
    return "Old";
  }
  td::Status check(td::uint64 message_id) {
    if (saved_message_ids_.size() == MAX_SAVED_MESSAGE_IDS) {
      auto oldest_message_id = *saved_message_ids_.begin();
      if (message_id < oldest_message_id) {
        return td::Status::Error(2, PSLICE() << "Ignore very old message " << message_id
                                             << " older than the oldest known message " << oldest_message_id);
      }
    }
    if (saved_message_ids_.count(message_id) != 0) {
      return td::Status::Error(1, PSLICE() << "Ignore already processed message " << message_id);
    }

    saved_message_ids_.insert(message_id);
    if (saved_message_ids_.size() > MAX_SAVED_MESSAGE_IDS) {
      saved_message_ids_.erase(saved_message_ids_.begin());
    }
    return td::Status::OK();
  }

 private:
  static constexpr size_t MAX_SAVED_MESSAGE_IDS = 1000;
  std::set<td::uint64> saved_message_ids_;
};

template <size_t MAX_SAVED_MESSAGE_IDS>
class IdDuplicateCheckerNew {
 public:
  static td::string get_description() {
    return PSTRING() << "New" << MAX_SAVED_MESSAGE_IDS;
  }
  td::Status check(td::uint64 message_id) {
    auto insert_result = saved_message_ids_.insert(message_id);
    if (!insert_result.second) {
      return td::Status::Error(1, PSLICE() << "Ignore already processed message " << message_id);
    }
    if (saved_message_ids_.size() == MAX_SAVED_MESSAGE_IDS + 1) {
      auto begin_it = saved_message_ids_.begin();
      bool is_very_old = begin_it == insert_result.first;
      saved_message_ids_.erase(begin_it);
      if (is_very_old) {
        return td::Status::Error(2, PSLICE() << "Ignore very old message " << message_id
                                             << " older than the oldest known message " << *saved_message_ids_.begin());
      }
    }
    return td::Status::OK();
  }

 private:
  std::set<td::uint64> saved_message_ids_;
};

class IdDuplicateCheckerNewOther {
 public:
  static td::string get_description() {
    return "NewOther";
  }
  td::Status check(td::uint64 message_id) {
    if (!saved_message_ids_.insert(message_id).second) {
      return td::Status::Error(1, PSLICE() << "Ignore already processed message " << message_id);
    }
    if (saved_message_ids_.size() == MAX_SAVED_MESSAGE_IDS + 1) {
      auto begin_it = saved_message_ids_.begin();
      bool is_very_old = *begin_it == message_id;
      saved_message_ids_.erase(begin_it);
      if (is_very_old) {
        return td::Status::Error(2, PSLICE() << "Ignore very old message " << message_id
                                             << " older than the oldest known message " << *saved_message_ids_.begin());
      }
    }
    return td::Status::OK();
  }

 private:
  static constexpr size_t MAX_SAVED_MESSAGE_IDS = 1000;
  std::set<td::uint64> saved_message_ids_;
};

class IdDuplicateCheckerNewSimple {
 public:
  static td::string get_description() {
    return "NewSimple";
  }
  td::Status check(td::uint64 message_id) {
    auto insert_result = saved_message_ids_.insert(message_id);
    if (!insert_result.second) {
      return td::Status::Error(1, "Ignore already processed message");
    }
    if (saved_message_ids_.size() == MAX_SAVED_MESSAGE_IDS + 1) {
      auto begin_it = saved_message_ids_.begin();
      bool is_very_old = begin_it == insert_result.first;
      saved_message_ids_.erase(begin_it);
      if (is_very_old) {
        return td::Status::Error(2, "Ignore very old message");
      }
    }
    return td::Status::OK();
  }

 private:
  static constexpr size_t MAX_SAVED_MESSAGE_IDS = 1000;
  std::set<td::uint64> saved_message_ids_;
};

template <size_t max_size>
class IdDuplicateCheckerArray {
 public:
  static td::string get_description() {
    return PSTRING() << "Array" << max_size;
  }
  td::Status check(td::uint64 message_id) {
    if (end_pos_ == 2 * max_size) {
      std::copy_n(&saved_message_ids_[max_size], max_size, &saved_message_ids_[0]);
      end_pos_ = max_size;
    }
    if (end_pos_ == 0 || message_id > saved_message_ids_[end_pos_ - 1]) {
      // fast path
      saved_message_ids_[end_pos_++] = message_id;
      return td::Status::OK();
    }
    if (end_pos_ >= max_size && message_id < saved_message_ids_[0]) {
      return td::Status::Error(2, PSLICE() << "Ignore very old message " << message_id
                                           << " older than the oldest known message " << saved_message_ids_[0]);
    }
    auto it = std::lower_bound(&saved_message_ids_[0], &saved_message_ids_[end_pos_], message_id);
    if (*it == message_id) {
      return td::Status::Error(1, PSLICE() << "Ignore already processed message " << message_id);
    }
    std::copy_backward(it, &saved_message_ids_[end_pos_], &saved_message_ids_[end_pos_ + 1]);
    *it = message_id;
    ++end_pos_;
    return td::Status::OK();
  }

 private:
  std::array<td::uint64, 2 * max_size> saved_message_ids_;
  std::size_t end_pos_ = 0;
};

template <class T>
class DuplicateCheckerBench final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "DuplicateCheckerBench" << T::get_description();
  }
  void run(int n) final {
    T checker_;
    for (int i = 0; i < n; i++) {
      checker_.check(i).ensure();
    }
  }
};

template <class T>
class DuplicateCheckerBenchRepeat final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "DuplicateCheckerBenchRepeat" << T::get_description();
  }
  void run(int n) final {
    T checker_;
    for (int i = 0; i < n; i++) {
      auto iter = i >> 10;
      auto pos = i - (iter << 10);
      if (pos < 768) {
        if (iter >= 3 && pos == 0) {
          auto error = checker_.check((iter - 3) * 768 + pos);
          CHECK(error.error().code() == 2);
        }
        checker_.check(iter * 768 + pos).ensure();
      } else {
        checker_.check(iter * 768 + pos - 256).ensure_error();
      }
    }
  }
};

template <class T>
class DuplicateCheckerBenchRepeatOnly final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "DuplicateCheckerBenchRepeatOnly" << T::get_description();
  }
  void run(int n) final {
    T checker_;
    for (int i = 0; i < n; i++) {
      auto result = checker_.check(i & 255);
      CHECK(result.is_error() == (i >= 256));
    }
  }
};

template <class T>
class DuplicateCheckerBenchReverse final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "DuplicateCheckerBenchReverseAdd" << T::get_description();
  }
  void run(int n) final {
    T checker_;
    for (int i = 0; i < n; i++) {
      auto pos = i & 255;
      checker_.check(i - pos + (255 - pos)).ensure();
    }
  }
};

template <class T>
class DuplicateCheckerBenchEvenOdd final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "DuplicateCheckerBenchEvenOdd" << T::get_description();
  }
  void run(int n) final {
    T checker_;
    for (int i = 0; i < n; i++) {
      auto pos = i & 255;
      checker_.check(i - pos + (pos * 2) % 256 + (pos * 2) / 256).ensure();
    }
  }
};

BENCH(AddToTopStd, "add_to_top std") {
  td::vector<int> v;
  for (int i = 0; i < n; i++) {
    for (size_t j = 0; j < 10; j++) {
      auto value = td::Random::fast(0, 9);
      auto it = std::find(v.begin(), v.end(), value);
      if (it == v.end()) {
        if (v.size() == 8) {
          v.back() = value;
        } else {
          v.push_back(value);
        }
        it = v.end() - 1;
      }
      std::rotate(v.begin(), it, it + 1);
    }
  }
}

BENCH(AddToTopTd, "add_to_top td") {
  td::vector<int> v;
  for (int i = 0; i < n; i++) {
    for (size_t j = 0; j < 10; j++) {
      td::add_to_top(v, 8, td::Random::fast(0, 9));
    }
  }
}

BENCH(AnyOfStd, "any_of std") {
  td::vector<int> v;
  for (int i = 0; i < 100; i++) {
    v.push_back(i);
  }
  int res = 0;
  for (int i = 0; i < n; i++) {
    int rem = td::Random::fast(0, 127);
    res += static_cast<int>(std::any_of(v.begin(), v.end(), [rem](int x) { return (x & 127) == rem; }));
  }
  td::do_not_optimize_away(res);
}

BENCH(AnyOfTd, "any_of td") {
  td::vector<int> v;
  for (int i = 0; i < 100; i++) {
    v.push_back(i);
  }
  int res = 0;
  for (int i = 0; i < n; i++) {
    int rem = td::Random::fast(0, 127);
    res += static_cast<int>(td::any_of(v, [rem](int x) { return (x & 127) == rem; }));
  }
  td::do_not_optimize_away(res);
}

int main() {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(DEBUG));

  td::bench(AnyOfStdBench());
  td::bench(AnyOfTdBench());

  td::bench(ToStringIntSmallBench());
  td::bench(ToStringIntBigBench());

  td::bench(AddToTopStdBench());
  td::bench(AddToTopTdBench());

  td::bench(TlToStringUpdateFileBench());
  td::bench(TlToStringMessageBench());

  td::bench(DuplicateCheckerBenchEvenOdd<IdDuplicateCheckerNew<1000>>());
  td::bench(DuplicateCheckerBenchEvenOdd<IdDuplicateCheckerNew<300>>());
  td::bench(DuplicateCheckerBenchEvenOdd<IdDuplicateCheckerArray<1000>>());
  td::bench(DuplicateCheckerBenchEvenOdd<IdDuplicateCheckerArray<300>>());

  td::bench(DuplicateCheckerBenchReverse<IdDuplicateCheckerNew<1000>>());
  td::bench(DuplicateCheckerBenchReverse<IdDuplicateCheckerNew<300>>());
  td::bench(DuplicateCheckerBenchReverse<IdDuplicateCheckerArray<1000>>());
  td::bench(DuplicateCheckerBenchReverse<IdDuplicateCheckerArray<300>>());

  td::bench(DuplicateCheckerBenchRepeatOnly<IdDuplicateCheckerNew<1000>>());
  td::bench(DuplicateCheckerBenchRepeatOnly<IdDuplicateCheckerNew<300>>());
  td::bench(DuplicateCheckerBenchRepeatOnly<IdDuplicateCheckerArray<1000>>());
  td::bench(DuplicateCheckerBenchRepeatOnly<IdDuplicateCheckerArray<300>>());

  td::bench(DuplicateCheckerBenchRepeat<IdDuplicateCheckerOld>());
  td::bench(DuplicateCheckerBenchRepeat<IdDuplicateCheckerNew<1000>>());
  td::bench(DuplicateCheckerBenchRepeat<IdDuplicateCheckerNewOther>());
  td::bench(DuplicateCheckerBenchRepeat<IdDuplicateCheckerNewSimple>());
  td::bench(DuplicateCheckerBenchRepeat<IdDuplicateCheckerNew<300>>());
  td::bench(DuplicateCheckerBenchRepeat<IdDuplicateCheckerArray<1000>>());
  td::bench(DuplicateCheckerBenchRepeat<IdDuplicateCheckerArray<300>>());

  td::bench(DuplicateCheckerBench<IdDuplicateCheckerOld>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerNew<1000>>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerNewOther>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerNewSimple>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerNew<300>>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerNew<100>>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerNew<10>>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerArray<1000>>());
  td::bench(DuplicateCheckerBench<IdDuplicateCheckerArray<300>>());

#if !TD_THREAD_UNSUPPORTED
  for (int i = 1; i <= 16; i *= 2) {
    td::bench(ThreadSafeCounterBench(i));
    td::bench(AtomicCounterBench<false>(i));
    td::bench(AtomicCounterBench<true>(i));
  }

  td::bench(AtomicReleaseIncBench<1>());
  td::bench(AtomicReleaseIncBench<2>());
  td::bench(AtomicReleaseCasIncBench<1>());
  td::bench(AtomicReleaseCasIncBench<2>());
  td::bench(RwMutexWriteBench<1>());
  td::bench(RwMutexReadBench<1>());
  td::bench(RwMutexWriteBench<2>());
  td::bench(RwMutexReadBench<2>());
#endif
#if !TD_WINDOWS
  td::bench(UtimeBench());
#endif
  td::bench(WalkPathBench());
  td::bench(CreateFileBench());
  td::bench(PwriteBench());

  td::bench(TlCallBench());
#if !TD_THREAD_UNSUPPORTED
  td::bench(ThreadNewBench());
#endif
#if !TD_EVENTFD_UNSUPPORTED
  td::bench(EventFdBench());
#endif
  td::bench(NewObjBench());
  td::bench(NewIntBench());
#if !TD_WINDOWS
  td::bench(PipeBench());
#endif
#if TD_LINUX || TD_ANDROID || TD_TIZEN
  td::bench(SemBench());
#endif
}
