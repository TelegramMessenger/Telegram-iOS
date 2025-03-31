//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "data.h"

#if TD_DARWIN_WATCH_OS
#include "td/net/DarwinHttp.h"
#endif

#include "td/net/HttpChunkedByteFlow.h"
#include "td/net/HttpHeaderCreator.h"
#include "td/net/HttpQuery.h"
#include "td/net/HttpReader.h"

#include "td/utils/AesCtrByteFlow.h"
#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/ByteFlow.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/Gzip.h"
#include "td/utils/GzipByteFlow.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"
#include "td/utils/UInt.h"

#include <algorithm>
#include <condition_variable>
#include <limits>
#include <mutex>

static td::string make_chunked(const td::string &str) {
  auto v = td::rand_split(str);
  td::string res;
  for (auto &s : v) {
    res += PSTRING() << td::format::as_hex_dump(static_cast<td::int32>(s.size()));
    res += "\r\n";
    res += s;
    res += "\r\n";
  }
  res += "0\r\n\r\n";
  return res;
}

static td::string gen_http_content() {
  int t = td::Random::fast(0, 2);
  int len;
  if (t == 0) {
    len = td::Random::fast(1, 10);
  } else if (t == 1) {
    len = td::Random::fast(100, 200);
  } else {
    len = td::Random::fast(1000, 20000);
  }
  return td::rand_string(std::numeric_limits<char>::min(), std::numeric_limits<char>::max(), len);
}

static td::string make_http_query(td::string content, td::string content_type, bool is_chunked, bool is_gzip,
                                  double gzip_k = 5, td::string zip_override = td::string()) {
  td::HttpHeaderCreator hc;
  hc.init_post("/");
  hc.add_header("jfkdlsahhjk", td::rand_string('a', 'z', td::Random::fast(1, 2000)));
  if (!content_type.empty()) {
    hc.add_header("content-type", content_type);
  }
  if (is_gzip) {
    td::BufferSlice zip;
    if (zip_override.empty()) {
      zip = td::gzencode(content, gzip_k);
    } else {
      zip = td::BufferSlice(zip_override);
    }
    if (!zip.empty()) {
      hc.add_header("content-encoding", "gzip");
      content = zip.as_slice().str();
    }
  }
  if (is_chunked) {
    hc.add_header("transfer-encoding", "chunked");
    content = make_chunked(content);
  } else {
    hc.set_content_size(content.size());
  }
  auto r_header = hc.finish();
  CHECK(r_header.is_ok());
  return PSTRING() << r_header.ok() << content;
}

static td::string rand_http_query(td::string content) {
  bool is_chunked = td::Random::fast_bool();
  bool is_gzip = td::Random::fast_bool();
  return make_http_query(std::move(content), td::string(), is_chunked, is_gzip);
}

static td::string join(const td::vector<td::string> &v) {
  td::string res;
  for (auto &s : v) {
    res += s;
  }
  return res;
}

TEST(Http, stack_overflow) {
  td::ChainBufferWriter writer;
  td::BufferSlice slice(td::string(256, 'A'));
  for (int i = 0; i < 1000000; i++) {
    td::ChainBufferWriter tmp_writer;
    writer.append(slice.clone());
  }
  {
    auto reader = writer.extract_reader();
    reader.sync_with_writer();
  }
}

TEST(Http, reader) {
#if TD_ANDROID || TD_TIZEN
  return;
#endif
  td::clear_thread_locals();
  auto start_mem = td::BufferAllocator::get_buffer_mem();
  auto start_size = td::BufferAllocator::get_buffer_slice_size();
  {
    td::BufferSlice a("test test");
    td::BufferSlice b = std::move(a);
#if TD_CLANG
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-pragmas"
#pragma clang diagnostic ignored "-Wunknown-warning-option"
#pragma clang diagnostic ignored "-Wself-move"
#endif
#if TD_GCC
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpragmas"
#pragma GCC diagnostic ignored "-Wself-move"
#endif
    a = std::move(a);
    b = std::move(b);
#if TD_GCC
#pragma GCC diagnostic pop
#endif
#if TD_CLANG
#pragma clang diagnostic pop
#endif
    a = std::move(b);
    td::BufferSlice c = a.from_slice(a);
    CHECK(c.size() == a.size());
  }
  td::clear_thread_locals();
  ASSERT_EQ(start_mem, td::BufferAllocator::get_buffer_mem());
  ASSERT_EQ(start_size, td::BufferAllocator::get_buffer_slice_size());
  for (int i = 0; i < 20; i++) {
    td::ChainBufferWriter input_writer;
    auto input = input_writer.extract_reader();
    td::HttpReader reader;
    int max_post_size = 10000;
    reader.init(&input, max_post_size, 0);

    td::vector<td::string> contents(100);
    std::generate(contents.begin(), contents.end(), gen_http_content);
    auto v = td::transform(contents, rand_http_query);
    auto vec_str = td::rand_split(join(v));

    td::HttpQuery q;
    td::vector<td::string> res;
    for (auto &str : vec_str) {
      input_writer.append(str);
      input.sync_with_writer();
      while (true) {
        auto r_state = reader.read_next(&q);
        LOG_IF(ERROR, r_state.is_error()) << r_state.error() << td::tag("ok", res.size());
        ASSERT_TRUE(r_state.is_ok());
        auto state = r_state.ok();
        if (state == 0) {
          if (q.files_.empty()) {
            ASSERT_TRUE(td::narrow_cast<int>(q.content_.size()) <= max_post_size);
            auto expected = contents[res.size()];
            ASSERT_EQ(expected, q.content_.str());
            res.push_back(q.content_.str());
          } else {
            auto r_fd = td::FileFd::open(q.files_[0].temp_file_name, td::FileFd::Read);
            ASSERT_TRUE(r_fd.is_ok());
            auto fd = r_fd.move_as_ok();
            td::string content(td::narrow_cast<std::size_t>(q.files_[0].size), '\0');
            auto r_size = fd.read(td::MutableSlice(content));
            ASSERT_TRUE(r_size.is_ok());
            ASSERT_TRUE(r_size.ok() == content.size());
            ASSERT_TRUE(td::narrow_cast<int>(content.size()) > max_post_size);
            ASSERT_EQ(contents[res.size()], content);
            res.push_back(content);
            fd.close();
          }
        } else {
          break;
        }
      }
    }
    ASSERT_EQ(contents.size(), res.size());
    ASSERT_EQ(contents, res);
  }
  td::clear_thread_locals();
  ASSERT_EQ(start_mem, td::BufferAllocator::get_buffer_mem());
  ASSERT_EQ(start_size, td::BufferAllocator::get_buffer_slice_size());
}

TEST(Http, gzip_bomb) {
#if TD_ANDROID || TD_TIZEN || TD_EMSCRIPTEN  // the test must be disabled on low-memory systems
  return;
#endif
  auto gzip_bomb_str =
      td::gzdecode(td::gzdecode(td::base64url_decode(td::Slice(gzip_bomb, gzip_bomb_size)).ok()).as_slice())
          .as_slice()
          .str();

  auto query = make_http_query(td::string(), td::string(), false, true, 0.01, gzip_bomb_str);
  auto parts = td::rand_split(query);
  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::HttpReader reader;
  td::HttpQuery q;
  reader.init(&input, 100000000, 0);
  for (auto &part : parts) {
    input_writer.append(part);
    input.sync_with_writer();
    auto r_state = reader.read_next(&q);
    if (r_state.is_error()) {
      LOG(INFO) << r_state.error();
      return;
    }
    ASSERT_TRUE(r_state.ok() != 0);
  }
}

TEST(Http, gzip) {
  auto gzip_str = td::gzdecode(td::base64url_decode(td::Slice(gzip, gzip_size)).ok()).as_slice().str();

  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();

  td::HttpReader reader;
  reader.init(&input, 0, 0);

  auto query = make_http_query(td::string(), "application/json", false, true, 0.01, gzip_str);
  input_writer.append(query);
  input.sync_with_writer();

  td::HttpQuery q;
  auto r_state = reader.read_next(&q);
  ASSERT_TRUE(r_state.is_error());
  ASSERT_EQ(413, r_state.error().code());
}

TEST(Http, aes_ctr_encode_decode_flow) {
  auto str = td::rand_string('a', 'z', 1000000);
  auto parts = td::rand_split(str);
  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::UInt256 key;
  td::UInt128 iv;
  td::Random::secure_bytes(key.raw, sizeof(key));
  td::Random::secure_bytes(iv.raw, sizeof(iv));
  td::AesCtrByteFlow aes_encode;
  aes_encode.init(key, iv);
  td::AesCtrByteFlow aes_decode;
  aes_decode.init(key, iv);
  td::ByteFlowSink sink;
  source >> aes_encode >> aes_decode >> sink;

  ASSERT_TRUE(!sink.is_ready());
  for (auto &part : parts) {
    input_writer.append(part);
    source.wakeup();
  }
  ASSERT_TRUE(!sink.is_ready());
  source.close_input(td::Status::OK());
  ASSERT_TRUE(sink.is_ready());
  LOG_IF(ERROR, sink.status().is_error()) << sink.status();
  ASSERT_TRUE(sink.status().is_ok());
  ASSERT_EQ(str, sink.result()->move_as_buffer_slice().as_slice().str());
}

TEST(Http, aes_file_encryption) {
  auto str = td::rand_string('a', 'z', 1000000);
  td::CSlice name = "test_encryption";
  td::unlink(name).ignore();
  td::UInt256 key;
  td::UInt128 iv;
  td::Random::secure_bytes(key.raw, sizeof(key));
  td::Random::secure_bytes(iv.raw, sizeof(iv));

  {
    td::BufferedFdBase<td::FileFd> fd(td::FileFd::open(name, td::FileFd::Write | td::FileFd::Create).move_as_ok());

    auto parts = td::rand_split(str);

    td::ChainBufferWriter output_writer;
    auto output_reader = output_writer.extract_reader();
    td::ByteFlowSource source(&output_reader);
    td::AesCtrByteFlow aes_encode;
    aes_encode.init(key, iv);
    td::ByteFlowSink sink;

    source >> aes_encode >> sink;
    fd.set_output_reader(sink.get_output());

    for (auto &part : parts) {
      output_writer.append(part);
      source.wakeup();
      fd.flush_write().ensure();
    }
    fd.close();
  }

  {
    td::BufferedFdBase<td::FileFd> fd(td::FileFd::open(name, td::FileFd::Read).move_as_ok());

    td::ChainBufferWriter input_writer;
    auto input_reader = input_writer.extract_reader();
    td::ByteFlowSource source(&input_reader);
    td::AesCtrByteFlow aes_encode;
    aes_encode.init(key, iv);
    td::ByteFlowSink sink;
    source >> aes_encode >> sink;
    fd.set_input_writer(&input_writer);

    fd.get_poll_info().add_flags(td::PollFlags::Read());
    while (can_read_local(fd)) {
      fd.flush_read(4096).ensure();
      source.wakeup();
    }

    fd.close();

    source.close_input(td::Status::OK());
    ASSERT_TRUE(sink.is_ready());
    LOG_IF(ERROR, sink.status().is_error()) << sink.status();
    ASSERT_TRUE(sink.status().is_ok());
    auto result = sink.result()->move_as_buffer_slice().as_slice().str();
    ASSERT_EQ(str, result);
  }
  td::unlink(name).ignore();
}

TEST(Http, chunked_flow) {
  auto str = td::rand_string('a', 'z', 100);
  auto parts = td::rand_split(make_chunked(str));
  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::HttpChunkedByteFlow chunked_flow;
  td::ByteFlowSink sink;
  source >> chunked_flow >> sink;

  for (auto &part : parts) {
    input_writer.append(part);
    source.wakeup();
  }
  source.close_input(td::Status::OK());
  ASSERT_TRUE(sink.is_ready());
  LOG_IF(ERROR, sink.status().is_error()) << sink.status();
  ASSERT_TRUE(sink.status().is_ok());
  auto res = sink.result()->move_as_buffer_slice().as_slice().str();
  ASSERT_EQ(str.size(), res.size());
  ASSERT_EQ(str, res);
}

TEST(Http, chunked_flow_error) {
  auto str = td::rand_string('a', 'z', 100000);
  for (int d = 1; d < 100; d += 10) {
    auto new_str = make_chunked(str);
    new_str.resize(str.size() - d);
    auto parts = td::rand_split(new_str);
    td::ChainBufferWriter input_writer;
    auto input = input_writer.extract_reader();
    td::ByteFlowSource source(&input);
    td::HttpChunkedByteFlow chunked_flow;
    td::ByteFlowSink sink;
    source >> chunked_flow >> sink;

    for (auto &part : parts) {
      input_writer.append(part);
      source.wakeup();
    }
    ASSERT_TRUE(!sink.is_ready());
    source.close_input(td::Status::OK());
    ASSERT_TRUE(sink.is_ready());
    ASSERT_TRUE(!sink.status().is_ok());
  }
}

TEST(Http, gzip_chunked_flow) {
  auto str = td::rand_string('a', 'z', 1000000);
  auto parts = td::rand_split(make_chunked(td::gzencode(str, 2.0).as_slice().str()));

  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::HttpChunkedByteFlow chunked_flow;
  td::GzipByteFlow gzip_flow(td::Gzip::Mode::Decode);
  td::ByteFlowSink sink;
  source >> chunked_flow >> gzip_flow >> sink;

  for (auto &part : parts) {
    input_writer.append(part);
    source.wakeup();
  }
  source.close_input(td::Status::OK());
  ASSERT_TRUE(sink.is_ready());
  LOG_IF(ERROR, sink.status().is_error()) << sink.status();
  ASSERT_TRUE(sink.status().is_ok());
  ASSERT_EQ(str, sink.result()->move_as_buffer_slice().as_slice().str());
}

TEST(Http, gzip_bomb_with_limit) {
  td::string gzip_bomb_str;
  {
    td::ChainBufferWriter input_writer;
    auto input = input_writer.extract_reader();
    td::GzipByteFlow gzip_flow(td::Gzip::Mode::Encode);
    td::ByteFlowSource source(&input);
    td::ByteFlowSink sink;
    source >> gzip_flow >> sink;

    td::string s(1 << 16, 'a');
    for (int i = 0; i < 1000; i++) {
      input_writer.append(s);
      source.wakeup();
    }
    source.close_input(td::Status::OK());
    ASSERT_TRUE(sink.is_ready());
    LOG_IF(ERROR, sink.status().is_error()) << sink.status();
    ASSERT_TRUE(sink.status().is_ok());
    gzip_bomb_str = sink.result()->move_as_buffer_slice().as_slice().str();
  }

  auto query = make_http_query(td::string(), td::string(), false, true, 0.01, gzip_bomb_str);
  auto parts = td::rand_split(query);
  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::HttpReader reader;
  td::HttpQuery q;
  reader.init(&input, 1000000);
  bool ok = false;
  for (auto &part : parts) {
    input_writer.append(part);
    input.sync_with_writer();
    auto r_state = reader.read_next(&q);
    if (r_state.is_error()) {
      LOG(FATAL) << r_state.error();
      return;
    } else if (r_state.ok() == 0) {
      ok = true;
    }
  }
  ASSERT_TRUE(ok);
}

TEST(Http, partial_form_data) {
  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();

  td::HttpReader reader;
  reader.init(&input, 0, 0);

  auto query =
      make_http_query("------abcd\r\nCo", "Content-Type: multipart/form-data; boundary=----abcd", false, false);
  input_writer.append(query);
  input.sync_with_writer();

  td::HttpQuery q;
  auto r_state = reader.read_next(&q);
  ASSERT_TRUE(r_state.is_error());
  ASSERT_EQ(400, r_state.error().code());
}

TEST(Http, form_data) {
  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();

  td::HttpReader reader;
  reader.init(&input, 0, 1);

  auto query = make_http_query(
      "------abcd\r\n"
      "Content-Disposition: form-data; name=\"text\"\r\n"
      "\r\n"
      "some text\r\n"
      "------abcd\r\n"
      "Content-Disposition: form-data; name=\"text2\"\r\n"
      "\r\n"
      "some text\r\n"
      "more text\r\n"
      "------abcd\r\n"
      "Content-Disposition: form-data; name=\"file\"; filename=\"file.txt\"\r\n"
      "Content-Type: text/plain\r\n"
      "\r\n"
      "File content\r\n"
      "------abcd--",
      "Content-Type: multipart/form-data; boundary=----abcd", false, false);
  input_writer.append(query);
  input.sync_with_writer();

  td::HttpQuery q;
  auto r_state = reader.read_next(&q);
  ASSERT_TRUE(r_state.is_ok());
  ASSERT_EQ(2u, q.args_.size());
  ASSERT_EQ("text", q.args_[0].first);
  ASSERT_EQ("some text", q.args_[0].second);
  ASSERT_EQ("text2", q.args_[1].first);
  ASSERT_EQ("some text\r\nmore text", q.args_[1].second);
  ASSERT_EQ(1u, q.files_.size());
  ASSERT_EQ("file.txt", q.files_[0].name);
  ASSERT_EQ("file", q.files_[0].field_name);
  ASSERT_EQ("text/plain", q.files_[0].content_type);
  ASSERT_EQ(12, q.files_[0].size);
  ASSERT_TRUE(!q.files_[0].temp_file_name.empty());
}

#if TD_DARWIN_WATCH_OS
struct Baton {
  std::mutex mutex;
  std::condition_variable cond;
  bool is_ready{false};

  void wait() {
    std::unique_lock<std::mutex> lock(mutex);
    cond.wait(lock, [&] { return is_ready; });
  }

  void post() {
    {
      std::unique_lock<std::mutex> lock(mutex);
      is_ready = true;
    }
    cond.notify_all();
  }

  void reset() {
    is_ready = false;
  }
};

TEST(Http, Darwin) {
  Baton baton;
  td::DarwinHttp::get("http://example.com", [&](td::BufferSlice data) { baton.post(); });
  baton.wait();
}
#endif
