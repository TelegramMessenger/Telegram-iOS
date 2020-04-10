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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "td/utils/tests.h"

#include "td/utils/crypto.h"
#include "td/utils/filesystem.h"
#include "td/utils/Parser.h"
#include "td/utils/PathView.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"

#include <map>

namespace td {

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

class RegressionTesterImpl : public RegressionTester {
 public:
  static void destroy(CSlice db_path) {
    unlink(db_path).ignore();
  }

  RegressionTesterImpl(string db_path, string db_cache_dir) : db_path_(db_path), db_cache_dir_(db_cache_dir) {
    load_db(db_path);
    if (db_cache_dir_.empty()) {
      db_cache_dir_ = PathView(db_path).without_extension().str() + ".cache/";
    }
    mkdir(db_cache_dir_).ensure();
  }

  Status verify_test(Slice name, Slice result) override {
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
                                    << tag("got", hash));
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

  void save_db() override {
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
    for (auto it : tests_) {
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

void TestsRunner::add_test(string name, unique_ptr<Test> test) {
  for (auto &it : tests_) {
    if (it.first == name) {
      LOG(FATAL) << "Test name collision " << name;
    }
  }
  tests_.emplace_back(name, std::move(test));
}

void TestsRunner::add_substr_filter(string str) {
  if (str[0] != '+' && str[0] != '-') {
    str = "+" + str;
  }
  substr_filters_.push_back(std::move(str));
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

  while (state_.it != state_.end) {
    auto &name = tests_[state_.it].first;
    auto test = tests_[state_.it].second.get();
    if (!state_.is_running) {
      bool ok = true;
      for (const auto &filter : substr_filters_) {
        bool is_match = name.find(filter.substr(1)) != string::npos;
        if (is_match != (filter[0] == '+')) {
          ok = false;
          break;
        }
      }
      if (!ok) {
        ++state_.it;
        continue;
      }
      LOG(ERROR) << "Run test " << tag("name", name);
      state_.start = Time::now();
      state_.is_running = true;
    }

    if (test->step()) {
      break;
    }

    LOG(ERROR) << format::as_time(Time::now() - state_.start);
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
