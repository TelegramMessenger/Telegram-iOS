//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/AsyncFileLog.h"
#include "td/utils/benchmark.h"
#include "td/utils/CombinedLog.h"
#include "td/utils/FileLog.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/MemoryLog.h"
#include "td/utils/NullLog.h"
#include "td/utils/port/path.h"
#include "td/utils/port/thread.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/TsFileLog.h"
#include "td/utils/TsLog.h"

#include <functional>
#include <limits>

char disable_linker_warning_about_empty_file_tdutils_test_log_cpp TD_UNUSED;

#if !TD_THREAD_UNSUPPORTED
template <class Log>
class LogBenchmark final : public td::Benchmark {
 public:
  LogBenchmark(std::string name, int threads_n, bool test_full_logging, std::function<td::unique_ptr<Log>()> creator)
      : name_(std::move(name))
      , threads_n_(threads_n)
      , test_full_logging_(test_full_logging)
      , creator_(std::move(creator)) {
  }
  std::string get_description() const final {
    return PSTRING() << name_ << " " << (test_full_logging_ ? "ERROR" : "PLAIN") << " "
                     << td::tag("threads_n", threads_n_);
  }
  void start_up() final {
    log_ = creator_();
    threads_.resize(threads_n_);
  }
  void tear_down() final {
    if (log_ == nullptr) {
      return;
    }
    for (const auto &path : log_->get_file_paths()) {
      td::unlink(path).ignore();
    }
    log_.reset();
  }
  void run(int n) final {
    auto old_log_interface = td::log_interface;
    if (log_ != nullptr) {
      td::log_interface = log_.get();
    }

    for (auto &thread : threads_) {
      thread = td::thread([this, n] { this->run_thread(n); });
    }
    for (auto &thread : threads_) {
      thread.join();
    }

    td::log_interface = old_log_interface;
  }

  void run_thread(int n) {
    auto str = PSTRING() << "#" << n << " : fsjklfdjsklfjdsklfjdksl\n";
    for (int i = 0; i < n; i++) {
      if (i % 10000 == 0 && log_ != nullptr) {
        log_->after_rotation();
      }
      if (test_full_logging_) {
        LOG(ERROR) << str;
      } else {
        LOG(PLAIN) << str;
      }
    }
  }

 private:
  std::string name_;
  td::unique_ptr<td::LogInterface> log_;
  int threads_n_{0};
  bool test_full_logging_{false};
  std::function<td::unique_ptr<Log>()> creator_;
  std::vector<td::thread> threads_;
};

template <class F>
static void bench_log(std::string name, F &&f) {
  for (auto test_full_logging : {false, true}) {
    for (auto threads_n : {1, 4, 8}) {
      bench(LogBenchmark<typename decltype(f())::element_type>(name, threads_n, test_full_logging, f));
    }
  }
}

TEST(Log, Bench) {
  bench_log("NullLog", [] { return td::make_unique<td::NullLog>(); });

  // bench_log("Default", []() -> td::unique_ptr<td::NullLog> { return nullptr; });

  bench_log("MemoryLog", [] { return td::make_unique<td::MemoryLog<1 << 20>>(); });

  bench_log("CombinedLogEmpty", [] { return td::make_unique<td::CombinedLog>(); });

  bench_log("CombinedLogMemory", [] {
    auto result = td::make_unique<td::CombinedLog>();
    static td::NullLog null_log;
    static td::MemoryLog<1 << 20> memory_log;
    result->set_first(&null_log);
    result->set_second(&memory_log);
    result->set_first_verbosity_level(VERBOSITY_NAME(DEBUG));
    result->set_second_verbosity_level(VERBOSITY_NAME(DEBUG));
    return result;
  });

  bench_log("TsFileLog",
            [] { return td::TsFileLog::create("tmplog", std::numeric_limits<td::int64>::max(), false).move_as_ok(); });

  bench_log("FileLog + TsLog", [] {
    class FileLog final : public td::LogInterface {
     public:
      FileLog() {
        file_log_.init("tmplog", std::numeric_limits<td::int64>::max(), false).ensure();
        ts_log_.init(&file_log_);
      }
      void do_append(int log_level, td::CSlice slice) final {
        static_cast<td::LogInterface &>(ts_log_).do_append(log_level, slice);
      }
      std::vector<std::string> get_file_paths() final {
        return file_log_.get_file_paths();
      }

     private:
      td::FileLog file_log_;
      td::TsLog ts_log_{nullptr};
    };
    return td::make_unique<FileLog>();
  });

  bench_log("FileLog", [] {
    class FileLog final : public td::LogInterface {
     public:
      FileLog() {
        file_log_.init("tmplog", std::numeric_limits<td::int64>::max(), false).ensure();
      }
      void do_append(int log_level, td::CSlice slice) final {
        static_cast<td::LogInterface &>(file_log_).do_append(log_level, slice);
      }
      std::vector<std::string> get_file_paths() final {
        return file_log_.get_file_paths();
      }

     private:
      td::FileLog file_log_;
    };
    return td::make_unique<FileLog>();
  });

#if !TD_EVENTFD_UNSUPPORTED
  bench_log("AsyncFileLog", [] {
    class AsyncFileLog final : public td::LogInterface {
     public:
      AsyncFileLog() {
        file_log_.init("tmplog", std::numeric_limits<td::int64>::max(), false).ensure();
      }
      void do_append(int log_level, td::CSlice slice) final {
        static_cast<td::LogInterface &>(file_log_).do_append(log_level, slice);
      }
      std::vector<std::string> get_file_paths() final {
        return static_cast<td::LogInterface &>(file_log_).get_file_paths();
      }

     private:
      td::AsyncFileLog file_log_;
    };
    return td::make_unique<AsyncFileLog>();
  });
#endif
}
#endif
