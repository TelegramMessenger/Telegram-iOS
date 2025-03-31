//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpQuery.h"
#include "td/net/HttpReader.h"

#include "td/utils/benchmark.h"
#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/find_boundary.h"
#include "td/utils/logging.h"

static std::string http_query = "GET / HTTP/1.1\r\nConnection:keep-alive\r\nhost:127.0.0.1:8080\r\n\r\n";
static const size_t block_size = 2500;

class HttpReaderBench final : public td::Benchmark {
  std::string get_description() const final {
    return "HttpReaderBench";
  }

  void run(int n) final {
    auto cnt = static_cast<int>(block_size / http_query.size());
    td::HttpQuery q;
    int parsed = 0;
    int sent = 0;
    for (int i = 0; i < n; i += cnt) {
      for (int j = 0; j < cnt; j++) {
        writer_.append(http_query);
        sent++;
      }
      reader_.sync_with_writer();
      while (true) {
        auto wait = http_reader_.read_next(&q).ok();
        if (wait != 0) {
          break;
        }
        parsed++;
      }
    }
    CHECK(parsed == sent);
  }
  td::ChainBufferWriter writer_;
  td::ChainBufferReader reader_;
  td::HttpReader http_reader_;

  void start_up() final {
    writer_ = {};
    reader_ = writer_.extract_reader();
    http_reader_.init(&reader_, 10000, 0);
  }
};

class BufferBench final : public td::Benchmark {
  std::string get_description() const final {
    return "BufferBench";
  }

  void run(int n) final {
    auto cnt = static_cast<int>(block_size / http_query.size());
    for (int i = 0; i < n; i += cnt) {
      for (int j = 0; j < cnt; j++) {
        writer_.append(http_query);
      }
      reader_.sync_with_writer();
      for (int j = 0; j < cnt; j++) {
        auto result = reader_.cut_head(http_query.size());
      }
    }
  }
  td::ChainBufferWriter writer_;
  td::ChainBufferReader reader_;
  td::HttpReader http_reader_;

  void start_up() final {
    writer_ = {};
    reader_ = writer_.extract_reader();
  }
};

class FindBoundaryBench final : public td::Benchmark {
  std::string get_description() const final {
    return "FindBoundaryBench";
  }

  void run(int n) final {
    auto cnt = static_cast<int>(block_size / http_query.size());
    for (int i = 0; i < n; i += cnt) {
      for (int j = 0; j < cnt; j++) {
        writer_.append(http_query);
      }
      reader_.sync_with_writer();
      for (int j = 0; j < cnt; j++) {
        size_t len = 0;
        find_boundary(reader_.clone(), "\r\n\r\n", len);
        CHECK(size_t(len) + 4 == http_query.size());
        auto result = reader_.cut_head(len + 2);
        reader_.advance(2);
      }
    }
  }
  td::ChainBufferWriter writer_;
  td::ChainBufferReader reader_;
  td::HttpReader http_reader_;

  void start_up() final {
    writer_ = {};
    reader_ = writer_.extract_reader();
  }
};

int main() {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(WARNING));
  td::bench(BufferBench());
  td::bench(FindBoundaryBench());
  td::bench(HttpReaderBench());
}
