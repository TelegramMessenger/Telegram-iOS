//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/EventFd.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/IoSlice.h"
#include "td/utils/port/path.h"
#include "td/utils/port/signals.h"
#include "td/utils/port/sleep.h"
#include "td/utils/port/Stat.h"
#include "td/utils/port/thread.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/Time.h"

#if TD_PORT_POSIX && !TD_THREAD_UNSUPPORTED
#include <algorithm>
#include <atomic>
#include <mutex>

#include <pthread.h>
#include <signal.h>
#endif

TEST(Port, files) {
  td::CSlice main_dir = "test_dir";
  td::rmrf(main_dir).ignore();
  ASSERT_TRUE(td::FileFd::open(main_dir, td::FileFd::Write).is_error());
  ASSERT_TRUE(td::walk_path(main_dir, [](td::CSlice name, td::WalkPath::Type type) { UNREACHABLE(); }).is_error());
  td::mkdir(main_dir).ensure();
  td::mkdir(PSLICE() << main_dir << TD_DIR_SLASH << "A").ensure();
  td::mkdir(PSLICE() << main_dir << TD_DIR_SLASH << "B").ensure();
  td::mkdir(PSLICE() << main_dir << TD_DIR_SLASH << "B" << TD_DIR_SLASH << "D").ensure();
  td::mkdir(PSLICE() << main_dir << TD_DIR_SLASH << "C").ensure();
  ASSERT_TRUE(td::FileFd::open(main_dir, td::FileFd::Write).is_error());
  td::string fd_path = PSTRING() << main_dir << TD_DIR_SLASH << "t.txt";
  td::string fd2_path = PSTRING() << main_dir << TD_DIR_SLASH << "C" << TD_DIR_SLASH << "t2.txt";

  auto fd = td::FileFd::open(fd_path, td::FileFd::Write | td::FileFd::CreateNew).move_as_ok();
  auto fd2 = td::FileFd::open(fd2_path, td::FileFd::Write | td::FileFd::CreateNew).move_as_ok();
  fd2.close();

  int cnt = 0;
  const int ITER_COUNT = 1000;
  for (int i = 0; i < ITER_COUNT; i++) {
    td::walk_path(main_dir, [&](td::CSlice name, td::WalkPath::Type type) {
      if (type == td::WalkPath::Type::RegularFile) {
        ASSERT_TRUE(name == fd_path || name == fd2_path);
      }
      cnt++;
    }).ensure();
  }
  ASSERT_EQ((5 * 2 + 2) * ITER_COUNT, cnt);
  bool was_abort = false;
  td::walk_path(main_dir, [&](td::CSlice name, td::WalkPath::Type type) {
    CHECK(!was_abort);
    if (type == td::WalkPath::Type::EnterDir && ends_with(name, PSLICE() << TD_DIR_SLASH << "B")) {
      was_abort = true;
      return td::WalkPath::Action::Abort;
    }
    return td::WalkPath::Action::Continue;
  }).ensure();
  CHECK(was_abort);

  cnt = 0;
  bool is_first_dir = true;
  td::walk_path(main_dir, [&](td::CSlice name, td::WalkPath::Type type) {
    cnt++;
    if (type == td::WalkPath::Type::EnterDir) {
      if (is_first_dir) {
        is_first_dir = false;
      } else {
        return td::WalkPath::Action::SkipDir;
      }
    }
    return td::WalkPath::Action::Continue;
  }).ensure();
  ASSERT_EQ(6, cnt);

  ASSERT_EQ(0u, fd.get_size().move_as_ok());
  ASSERT_EQ(12u, fd.write("Hello world!").move_as_ok());
  ASSERT_EQ(4u, fd.pwrite("abcd", 1).move_as_ok());
  char buf[100];
  td::MutableSlice buf_slice(buf, sizeof(buf));
  ASSERT_TRUE(fd.pread(buf_slice.substr(0, 4), 2).is_error());
  fd.seek(11).ensure();
  ASSERT_EQ(2u, fd.write("?!").move_as_ok());

  ASSERT_TRUE(td::FileFd::open(main_dir, td::FileFd::Read | td::FileFd::CreateNew).is_error());
  fd = td::FileFd::open(fd_path, td::FileFd::Read | td::FileFd::Create).move_as_ok();
  ASSERT_EQ(13u, fd.get_size().move_as_ok());
  ASSERT_EQ(4u, fd.pread(buf_slice.substr(0, 4), 1).move_as_ok());
  ASSERT_STREQ("abcd", buf_slice.substr(0, 4));

  fd.seek(0).ensure();
  ASSERT_EQ(13u, fd.read(buf_slice.substr(0, 13)).move_as_ok());
  ASSERT_STREQ("Habcd world?!", buf_slice.substr(0, 13));
  td::rmrf(main_dir).ensure();
}

TEST(Port, SparseFiles) {
  td::CSlice path = "sparse.txt";
  td::unlink(path).ignore();
  auto fd = td::FileFd::open(path, td::FileFd::Write | td::FileFd::CreateNew).move_as_ok();
  ASSERT_EQ(0, fd.get_size().move_as_ok());
  td::int64 offset = 100000000;
  fd.pwrite("a", offset).ensure();
  ASSERT_EQ(offset + 1, fd.get_size().move_as_ok());
  auto real_size = fd.get_real_size().move_as_ok();
  if (real_size >= offset + 1) {
    LOG(ERROR) << "File system doesn't support sparse files, rewind during streaming can be slow";
  }
  td::unlink(path).ensure();
}

TEST(Port, LargeFiles) {
  td::CSlice path = "large.txt";
  td::unlink(path).ignore();
  auto fd = td::FileFd::open(path, td::FileFd::Write | td::FileFd::CreateNew).move_as_ok();
  ASSERT_EQ(0, fd.get_size().move_as_ok());
  td::int64 offset = static_cast<td::int64>(3) << 30;
  if (fd.pwrite("abcd", offset).is_error()) {
    LOG(ERROR) << "Writing to large files isn't supported";
    td::unlink(path).ensure();
    return;
  }
  fd = td::FileFd::open(path, td::FileFd::Read).move_as_ok();
  ASSERT_EQ(offset + 4, fd.get_size().move_as_ok());
  td::string res(4, '\0');
  if (fd.pread(res, offset).is_error()) {
    LOG(ERROR) << "Reading of large files isn't supported";
    td::unlink(path).ensure();
    return;
  }
  ASSERT_STREQ(res, "abcd");
  fd.close();
  td::unlink(path).ensure();
}

TEST(Port, Writev) {
  td::vector<td::IoSlice> vec;
  td::CSlice test_file_path = "test.txt";
  td::unlink(test_file_path).ignore();
  auto fd = td::FileFd::open(test_file_path, td::FileFd::Write | td::FileFd::CreateNew).move_as_ok();
  vec.push_back(td::as_io_slice("a"));
  vec.push_back(td::as_io_slice("b"));
  vec.push_back(td::as_io_slice("cd"));
  ASSERT_EQ(4u, fd.writev(vec).move_as_ok());
  vec.clear();
  vec.push_back(td::as_io_slice("efg"));
  vec.push_back(td::as_io_slice(""));
  vec.push_back(td::as_io_slice("hi"));
  ASSERT_EQ(5u, fd.writev(vec).move_as_ok());
  fd.close();
  fd = td::FileFd::open(test_file_path, td::FileFd::Read).move_as_ok();
  td::Slice expected_content = "abcdefghi";
  ASSERT_EQ(static_cast<td::int64>(expected_content.size()), fd.get_size().ok());
  td::string content(expected_content.size(), '\0');
  ASSERT_EQ(content.size(), fd.read(content).move_as_ok());
  ASSERT_EQ(expected_content, content);

  auto stat = td::stat(test_file_path).move_as_ok();
  CHECK(!stat.is_dir_);
  CHECK(stat.is_reg_);
  CHECK(!stat.is_symbolic_link_);
  CHECK(stat.size_ == static_cast<td::int64>(expected_content.size()));

  td::unlink(test_file_path).ignore();
}

#if TD_PORT_POSIX && !TD_THREAD_UNSUPPORTED

static std::mutex m;
static td::vector<td::string> ptrs;
static td::vector<int *> addrs;
static TD_THREAD_LOCAL int thread_id;

static void on_user_signal(int sig) {
  int addr;
  addrs[thread_id] = &addr;
  std::unique_lock<std::mutex> guard(m);
  ptrs.push_back(td::to_string(thread_id));
}

TEST(Port, SignalsAndThread) {
  td::setup_signals_alt_stack().ensure();
  td::set_signal_handler(td::SignalType::User, on_user_signal).ensure();
  SCOPE_EXIT {
    td::set_signal_handler(td::SignalType::User, nullptr).ensure();
  };
  td::vector<td::string> ans = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"};
  {
    td::vector<td::thread> threads;
    int thread_n = 10;
    td::vector<td::Stage> stages(thread_n);
    ptrs.clear();
    addrs.resize(thread_n);
    for (int i = 0; i < 10; i++) {
      threads.emplace_back([&, i] {
        td::setup_signals_alt_stack().ensure();
        if (i != 0) {
          stages[i].wait(2);
        }
        thread_id = i;
        pthread_kill(pthread_self(), SIGUSR1);
        if (i + 1 < thread_n) {
          stages[i + 1].wait(2);
        }
      });
    }
    for (auto &t : threads) {
      t.join();
    }
    CHECK(ptrs == ans);

    //LOG(ERROR) << ptrs;
    //LOG(ERROR) << addrs;
  }

  {
    td::Stage stage;
    td::vector<td::thread> threads;
    int thread_n = 10;
    ptrs.clear();
    addrs.resize(thread_n);
    for (int i = 0; i < 10; i++) {
      threads.emplace_back([&, i] {
        stage.wait(thread_n);
        thread_id = i;
        pthread_kill(pthread_self(), SIGUSR1);
      });
    }
    for (auto &t : threads) {
      t.join();
    }
    std::sort(ptrs.begin(), ptrs.end());
    CHECK(ptrs == ans);
    auto addrs_size = addrs.size();
    td::unique(addrs);
    ASSERT_EQ(addrs_size, addrs.size());
    //LOG(ERROR) << addrs;
  }
}

#if !TD_EVENTFD_UNSUPPORTED
TEST(Port, EventFdAndSignals) {
  td::set_signal_handler(td::SignalType::User, [](int signal) {}).ensure();
  SCOPE_EXIT {
    td::set_signal_handler(td::SignalType::User, nullptr).ensure();
  };

  std::atomic_flag flag;
  flag.test_and_set();
  auto main_thread = pthread_self();
  td::thread interrupt_thread{[&flag, &main_thread] {
    td::setup_signals_alt_stack().ensure();
    while (flag.test_and_set()) {
      pthread_kill(main_thread, SIGUSR1);
      td::usleep_for(1000 * td::Random::fast(1, 10));  // 0.001s - 0.01s
    }
  }};

  for (int timeout_ms : {0, 1, 2, 10, 100, 500}) {
    double min_diff = 10000000;
    double max_diff = 0;
    for (int t = 0; t < td::max(5, 1000 / td::max(timeout_ms, 1)); t++) {
      td::EventFd event_fd;
      event_fd.init();
      auto start = td::Timestamp::now();
      event_fd.wait(timeout_ms);
      auto end = td::Timestamp::now();
      auto passed = end.at() - start.at();
      auto diff = passed * 1000 - timeout_ms;
      min_diff = td::min(min_diff, diff);
      max_diff = td::max(max_diff, diff);
    }

    LOG_CHECK(min_diff >= 0) << min_diff;
    // LOG_CHECK(max_diff < 10) << max_diff;
    LOG(INFO) << min_diff << " " << max_diff;
  }
  flag.clear();
}
#endif
#endif

#if TD_HAVE_THREAD_AFFINITY
TEST(Port, ThreadAffinityMask) {
  auto thread_id = td::this_thread::get_id();
  auto old_mask = td::thread::get_affinity_mask(thread_id);
  LOG(INFO) << "Initial thread " << thread_id << " affinity mask: " << old_mask;
  for (size_t i = 0; i < 64; i++) {
    auto mask = td::thread::get_affinity_mask(thread_id);
    LOG(INFO) << mask;
    auto result = td::thread::set_affinity_mask(thread_id, static_cast<td::uint64>(1) << i);
    LOG(INFO) << i << ": " << result << ' ' << td::thread::get_affinity_mask(thread_id);

    if (i <= 1) {
      td::thread thread([] {
        auto thread_id = td::this_thread::get_id();
        auto mask = td::thread::get_affinity_mask(thread_id);
        LOG(INFO) << "New thread " << thread_id << " affinity mask: " << mask;
        auto result = td::thread::set_affinity_mask(thread_id, 1);
        LOG(INFO) << "Thread " << thread_id << ": " << result << ' ' << td::thread::get_affinity_mask(thread_id);
      });
      LOG(INFO) << "Will join new thread " << thread.get_id()
                << " with affinity mask: " << td::thread::get_affinity_mask(thread.get_id());
    }
  }
  auto result = td::thread::set_affinity_mask(thread_id, old_mask);
  LOG(INFO) << result;
  old_mask = td::thread::get_affinity_mask(thread_id);
  LOG(INFO) << old_mask;
}
#endif
