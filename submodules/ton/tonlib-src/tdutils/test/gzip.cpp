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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/utils/buffer.h"
#include "td/utils/ByteFlow.h"
#include "td/utils/Gzip.h"
#include "td/utils/GzipByteFlow.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"

static void encode_decode(td::string s) {
  auto r = td::gzencode(s, 2);
  ASSERT_TRUE(!r.empty());
  if (r.empty()) {
    return;
  }
  auto new_s = td::gzdecode(r.as_slice());
  ASSERT_TRUE(!new_s.empty());
  if (new_s.empty()) {
    return;
  }
  ASSERT_EQ(s, new_s.as_slice().str());
}

TEST(Gzip, gzencode_gzdecode) {
  auto str = td::rand_string(0, 127, 1000);
  encode_decode(str);
  str = td::rand_string('a', 'z', 1000000);
  encode_decode(str);
  str = td::string(1000000, 'a');
  encode_decode(str);
}

TEST(Gzip, flow) {
  auto str = td::rand_string('a', 'z', 1000000);
  auto parts = td::rand_split(str);

  td::ChainBufferWriter input_writer;
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::GzipByteFlow gzip_flow(td::Gzip::Encode);
  gzip_flow = td::GzipByteFlow(td::Gzip::Encode);
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
  auto zip = td::gzencode(str).as_slice().str();
  zip.resize(zip.size() - 1);
  auto parts = td::rand_split(zip);

  auto input_writer = td::ChainBufferWriter();
  auto input = input_writer.extract_reader();
  td::ByteFlowSource source(&input);
  td::GzipByteFlow gzip_flow(td::Gzip::Decode);
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
  td::GzipByteFlow gzip_encode_flow(td::Gzip::Encode);
  td::GzipByteFlow gzip_decode_flow(td::Gzip::Decode);
  td::GzipByteFlow gzip_encode_flow2(td::Gzip::Encode);
  td::GzipByteFlow gzip_decode_flow2(td::Gzip::Decode);
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
