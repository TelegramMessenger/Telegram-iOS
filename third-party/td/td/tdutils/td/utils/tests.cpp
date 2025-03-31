//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/tests.h"

#include "td/utils/crypto.h"
#include "td/utils/filesystem.h"
#include "td/utils/Parser.h"
#include "td/utils/PathView.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"

#include <map>

namespace td {

string rand_string(int from, int to, size_t len) {
  string res(len, '\0');
  for (auto &c : res) {
    c = static_cast<char>(Random::fast(from, to));
  }
  return res;
}

vector<string> rand_split(Slice str) {
  vector<string> res;
  size_t pos = 0;
  while (pos < str.size()) {
    size_t len;
    if (Random::fast_bool()) {
      len = Random::fast(1, 10);
    } else {
      len = Random::fast(100, 200);
    }
    res.push_back(str.substr(pos, len).str());
    pos += len;
  }
  return res;
}

struct TestInfo {
  string name;
  string result_hash;  // base64
};

StringBuilder &operator<<(StringBuilder &sb, const TestInfo &info) {
  // should I use JSON?
  CHECK(!info.name.empty());
  CHECK(!info.result_hash.empty());
  return sb << info.name << " " << info.result_hash << "\n";
}

class RegressionTesterImpl final : public RegressionTester {
 public:
  static void destroy(CSlice db_path) {
    unlink(db_path).ignore();
  }

  RegressionTesterImpl(string db_path, string db_cache_dir)
      : db_path_(std::move(db_path)), db_cache_dir_(std::move(db_cache_dir)) {
    load_db(db_path_).ignore();
    if (db_cache_dir_.empty()) {
      db_cache_dir_ = PathView(db_path_).without_extension().str() + ".cache/";
    }
    mkdir(db_cache_dir_).ensure();
  }

  Status verify_test(Slice name, Slice result) final {
#if TD_HAVE_OPENSSL
    auto hash = PSTRING() << format::as_hex_dump<0>(Slice(sha256(result)));
#else
    auto hash = to_string(crc64(result));
#endif
    TestInfo &old_test_info = tests_[name.str()];
    if (!old_test_info.result_hash.empty() && old_test_info.result_hash != hash) {
      auto wa_path = db_cache_dir_ + "WA";
      write_file(wa_path, result).ensure();
      return Status::Error(PSLICE() << "Test " << name << " changed: " << tag("expected", old_test_info.result_hash)
                                    << tag("received", hash));
    }
    auto result_cache_path = db_cache_dir_ + hash;
    if (stat(result_cache_path).is_error()) {
      write_file(result_cache_path, result).ensure();
    }
    if (!old_test_info.result_hash.empty()) {
      return Status::OK();
    }
    old_test_info.name = name.str();
    old_test_info.result_hash = hash;
    is_dirty_ = true;

    return Status::OK();
  }

  void save_db() final {
    if (!is_dirty_) {
      return;
    }
    SCOPE_EXIT {
      is_dirty_ = false;
    };
    string buf(2000000, ' ');
    StringBuilder sb(buf);
    save_db(sb);
    string new_db_path = db_path_ + ".new";
    write_file(new_db_path, sb.as_cslice()).ensure();
    rename(new_db_path, db_path_).ensure();
  }

  Slice magic() const {
    return Slice("abce");
  }

  void save_db(StringBuilder &sb) {
    sb << magic() << "\n";
    for (const auto &it : tests_) {
      sb << it.second;
    }
  }

  Status load_db(CSlice path) {
    TRY_RESULT(data, read_file(path));
    ConstParser parser(data.as_slice());
    auto db_magic = parser.read_word();
    if (db_magic != magic()) {
      return Status::Error(PSLICE() << "Wrong magic " << db_magic);
    }
    while (true) {
      TestInfo info;
      info.name = parser.read_word().str();
      if (info.name.empty()) {
        break;
      }
      info.result_hash = parser.read_word().str();
      tests_[info.name] = info;
    }
    return Status::OK();
  }

 private:
  string db_path_;
  string db_cache_dir_;
  bool is_dirty_{false};

  std::map<string, TestInfo> tests_;
};

void RegressionTester::destroy(CSlice path) {
  RegressionTesterImpl::destroy(path);
}

unique_ptr<RegressionTester> RegressionTester::create(string db_path, string db_cache_dir) {
  return td::make_unique<RegressionTesterImpl>(std::move(db_path), std::move(db_cache_dir));
}

TestsRunner &TestsRunner::get_default() {
  static TestsRunner default_runner;
  return default_runner;
}

void TestsRunner::add_test(string name, std::function<unique_ptr<Test>()> test) {
  for (auto &it : tests_) {
    if (it.first == name) {
      LOG(FATAL) << "Test name collision " << name;
    }
  }
  tests_.emplace_back(std::move(name), TestInfo{std::move(test), nullptr});
}

void TestsRunner::add_substr_filter(string str) {
  if (str[0] != '+' && str[0] != '-') {
    str = "+" + str;
  }
  substr_filters_.push_back(std::move(str));
}

void TestsRunner::set_offset(string str) {
  offset_ = std::move(str);
}

void TestsRunner::set_regression_tester(unique_ptr<RegressionTester> regression_tester) {
  regression_tester_ = std::move(regression_tester);
}

void TestsRunner::set_stress_flag(bool flag) {
  stress_flag_ = flag;
}

void TestsRunner::run_all() {
  while (run_all_step()) {
  }
}

bool TestsRunner::run_all_step() {
  Guard guard(this);
  if (state_.it == state_.end) {
    state_.end = tests_.size();
    state_.it = 0;
  }

  bool skip_tests = true;
  while (state_.it != state_.end) {
    auto &name = tests_[state_.it].first;
    auto &test = tests_[state_.it].second.test;
    if (!state_.is_running) {
      bool ok = true;
      for (const auto &filter : substr_filters_) {
        bool is_match = name.find(filter.substr(1)) != string::npos;
        if (is_match != (filter[0] == '+')) {
          ok = false;
          break;
        }
      }
      if (name.find(offset_) != string::npos) {
        skip_tests = false;
      }
      if (!ok || skip_tests) {
        ++state_.it;
        continue;
      }
      LOG(ERROR) << "Run test " << tag("name", name);
      state_.start = Time::now();
      state_.start_unadjusted = Time::now_unadjusted();
      state_.is_running = true;

      CHECK(!test);
      test = tests_[state_.it].second.creator();
    }

    if (test->step()) {
      break;
    }

    test = {};

    auto passed = Time::now() - state_.start;
    auto real_passed = Time::now_unadjusted() - state_.start_unadjusted;
    if (real_passed + 1e-1 > passed) {
      LOG(ERROR) << format::as_time(passed);
    } else {
      LOG(ERROR) << format::as_time(real_passed) << " adjusted [" << format::as_time(real_passed) << "]";
    }
    if (regression_tester_) {
      regression_tester_->save_db();
    }
    state_.is_running = false;
    ++state_.it;
  }

  auto ret = state_.it != state_.end;
  if (!ret) {
    state_ = State();
  }
  return ret || stress_flag_;
}

Slice TestsRunner::name() {
  CHECK(state_.is_running);
  return tests_[state_.it].first;
}

Status TestsRunner::verify(Slice data) {
  if (!regression_tester_) {
    LOG(INFO) << data;
    LOG(ERROR) << "Cannot verify and save <" << name() << "> answer. Use --regression <regression_db> option";
    return Status::OK();
  }
  return regression_tester_->verify_test(PSLICE() << name() << "_default", data);
}

}  // namespace td
