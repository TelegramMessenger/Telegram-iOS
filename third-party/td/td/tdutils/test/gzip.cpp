//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/ByteFlow.h"
#include "td/utils/common.h"
#include "td/utils/Gzip.h"
#include "td/utils/GzipByteFlow.h"
#include "td/utils/logging.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"
#include "td/utils/Time.h"

static void encode_decode(const td::string &s) {
  auto r = td::gzencode(s, 2);
  ASSERT_TRUE(!r.empty());
  ASSERT_EQ(s, td::gzdecode(r.as_slice()));
}

TEST(Gzip, gzencode_gzdecode) {
  encode_decode(td::rand_string(0, 255, 1000));
  encode_decode(td::rand_string('a', 'z', 1000000));
  encode_decode(td::string(1000000, 'a'));
}

static void test_gzencode(const td::string &s) {
  auto begin_time = td::Time::now();
  auto r = td::gzencode(s, td::max(2, static_cast<int>(100 / s.size())));
  ASSERT_TRUE(!r.empty());
  LOG(INFO) << "Encoded string of size " << s.size() << " in " << (td::Time::now() - begin_time)
            << " seconds with compression ratio " << static_cast<double>(r.size()) / static_cast<double>(s.size());
}

TEST(Gzip, gzencode) {
  for (size_t len = 1; len <= 10000000; len *= 10) {
    test_gzencode(td::rand_string('a', 'a', len));
    test_gzencode(td::rand_string('a', 'z', len));
    test_gzencode(td::rand_string(0, 255, len));
  }
}

TEST(Gzip, flow) {
  auto str = td::rand_string('a', 'z', 1000000);
  auto parts = td::rand_split(str);

  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::GzipByteFlow gzip_flow(td::Gzip::Mode::Encode);
  gzip_flow = td::GzipByteFlow(td::Gzip::Mode::Encode);
  td::ByteFlowSink sink;

  source >> gzip_flow >> sink;

  ASSERT_TRUE(!sink.is_ready());
  for (auto &part : parts) {
    input_writer.append(part);
    source.wakeup();
  }
  ASSERT_TRUE(!sink.is_ready());
  source.close_input(td::Status::OK());
  ASSERT_TRUE(sink.is_ready());
  ASSERT_TRUE(sink.status().is_ok());
  auto res = sink.result()->move_as_buffer_slice().as_slice().str();
  ASSERT_TRUE(!res.empty());
  ASSERT_EQ(td::gzencode(str, 2).as_slice().str(), res);
}
TEST(Gzip, flow_error) {
  auto str = td::rand_string('a', 'z', 1000000);
  auto zip = td::gzencode(str, 0.9).as_slice().str();
  ASSERT_TRUE(!zip.empty());
  zip.resize(zip.size() - 1);
  auto parts = td::rand_split(zip);

  auto input_writer = td::ChainBufferWriter();
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::GzipByteFlow gzip_flow(td::Gzip::Mode::Decode);
  td::ByteFlowSink sink;

  source >> gzip_flow >> sink;

  ASSERT_TRUE(!sink.is_ready());
  for (auto &part : parts) {
    input_writer.append(part);
    source.wakeup();
  }
  ASSERT_TRUE(!sink.is_ready());
  source.close_input(td::Status::OK());
  ASSERT_TRUE(sink.is_ready());
  ASSERT_TRUE(!sink.status().is_ok());
}

TEST(Gzip, encode_decode_flow) {
  auto str = td::rand_string('a', 'z', 1000000);
  auto parts = td::rand_split(str);
  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::GzipByteFlow gzip_encode_flow(td::Gzip::Mode::Encode);
  td::GzipByteFlow gzip_decode_flow(td::Gzip::Mode::Decode);
  td::GzipByteFlow gzip_encode_flow2(td::Gzip::Mode::Encode);
  td::GzipByteFlow gzip_decode_flow2(td::Gzip::Mode::Decode);
  td::ByteFlowSink sink;
  source >> gzip_encode_flow >> gzip_decode_flow >> gzip_encode_flow2 >> gzip_decode_flow2 >> sink;

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

TEST(Gzip, encode_decode_flow_big) {
  td::clear_thread_locals();
  auto start_mem = td::BufferAllocator::get_buffer_mem();
  {
    auto str = td::string(200000, 'a');
    td::ChainBufferWriter input_writer;
    auto input = input_writer.extract_reader();
    td::ByteFlowSource source(&input);
    td::GzipByteFlow gzip_encode_flow(td::Gzip::Mode::Encode);
    td::GzipByteFlow gzip_decode_flow(td::Gzip::Mode::Decode);
    td::GzipByteFlow gzip_encode_flow2(td::Gzip::Mode::Encode);
    td::GzipByteFlow gzip_decode_flow2(td::Gzip::Mode::Decode);
    td::ByteFlowSink sink;
    source >> gzip_encode_flow >> gzip_decode_flow >> gzip_encode_flow2 >> gzip_decode_flow2 >> sink;

    ASSERT_TRUE(!sink.is_ready());
    size_t n = 200;
    size_t left_size = n * str.size();
    auto validate = [&](td::Slice chunk) {
      CHECK(chunk.size() <= left_size);
      left_size -= chunk.size();
      ASSERT_TRUE(td::all_of(chunk, [](auto c) { return c == 'a'; }));
    };

    for (size_t i = 0; i < n; i++) {
      input_writer.append(str);
      source.wakeup();
      auto extra_mem = td::BufferAllocator::get_buffer_mem() - start_mem;
      // limit means nothing. just check that we do not use 200Mb or so
      CHECK(extra_mem < (10 << 20));

      auto size = sink.get_output()->size();
      validate(sink.get_output()->cut_head(size).move_as_buffer_slice().as_slice());
    }
    ASSERT_TRUE(!sink.is_ready());
    source.close_input(td::Status::OK());
    ASSERT_TRUE(sink.is_ready());
    LOG_IF(ERROR, sink.status().is_error()) << sink.status();
    ASSERT_TRUE(sink.status().is_ok());
    validate(sink.result()->move_as_buffer_slice().as_slice());
    ASSERT_EQ(0u, left_size);
  }
  td::clear_thread_locals();
  ASSERT_EQ(start_mem, td::BufferAllocator::get_buffer_mem());
}

TEST(Gzip, decode_encode_flow_bomb) {
  td::string gzip_bomb_str;
  size_t N = 200;
  {
    td::ChainBufferWriter input_writer;
    auto input = input_writer.extract_reader();
    td::GzipByteFlow gzip_flow(td::Gzip::Mode::Encode);
    td::ByteFlowSource source(&input);
    td::ByteFlowSink sink;
    source >> gzip_flow >> sink;

    td::string s(1 << 16, 'a');
    for (size_t i = 0; i < N; i++) {
      input_writer.append(s);
      source.wakeup();
    }
    source.close_input(td::Status::OK());
    ASSERT_TRUE(sink.is_ready());
    LOG_IF(ERROR, sink.status().is_error()) << sink.status();
    ASSERT_TRUE(sink.status().is_ok());
    gzip_bomb_str = sink.result()->move_as_buffer_slice().as_slice().str();
  }

  td::clear_thread_locals();
  auto start_mem = td::BufferAllocator::get_buffer_mem();
  {
    td::ChainBufferWriter input_writer;
    auto input = input_writer.extract_reader();
    td::ByteFlowSource source(&input);
    td::GzipByteFlow::Options decode_options;
    decode_options.write_watermark.low = 2 << 20;
    decode_options.write_watermark.high = 4 << 20;
    td::GzipByteFlow::Options encode_options;
    encode_options.read_watermark.low = 2 << 20;
    encode_options.read_watermark.high = 4 << 20;
    td::GzipByteFlow gzip_decode_flow(td::Gzip::Mode::Decode);
    gzip_decode_flow.set_options(decode_options);
    td::GzipByteFlow gzip_encode_flow(td::Gzip::Mode::Encode);
    gzip_encode_flow.set_options(encode_options);
    td::GzipByteFlow gzip_decode_flow2(td::Gzip::Mode::Decode);
    gzip_decode_flow2.set_options(decode_options);
    td::GzipByteFlow gzip_encode_flow2(td::Gzip::Mode::Encode);
    gzip_encode_flow2.set_options(encode_options);
    td::GzipByteFlow gzip_decode_flow3(td::Gzip::Mode::Decode);
    gzip_decode_flow3.set_options(decode_options);
    td::ByteFlowSink sink;
    source >> gzip_decode_flow >> gzip_encode_flow >> gzip_decode_flow2 >> gzip_encode_flow2 >> gzip_decode_flow3 >>
        sink;

    ASSERT_TRUE(!sink.is_ready());
    size_t left_size = N * (1 << 16);
    auto validate = [&](td::Slice chunk) {
      CHECK(chunk.size() <= left_size);
      left_size -= chunk.size();
      ASSERT_TRUE(td::all_of(chunk, [](auto c) { return c == 'a'; }));
    };

    input_writer.append(gzip_bomb_str);
    source.close_input(td::Status::OK());

    do {
      gzip_decode_flow3.wakeup();
      gzip_decode_flow2.wakeup();
      gzip_decode_flow.wakeup();
      source.wakeup();
      auto extra_mem = td::BufferAllocator::get_buffer_mem() - start_mem;
      // limit means nothing. just check that we do not use 15Mb or so
      CHECK(extra_mem < (5 << 20));
      auto size = sink.get_output()->size();
      validate(sink.get_output()->cut_head(size).move_as_buffer_slice().as_slice());
    } while (!sink.is_ready());
    ASSERT_EQ(0u, left_size);
  }
  td::clear_thread_locals();
  ASSERT_EQ(start_mem, td::BufferAllocator::get_buffer_mem());
}
