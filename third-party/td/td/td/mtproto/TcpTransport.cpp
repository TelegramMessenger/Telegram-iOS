//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/TcpTransport.h"

#include "td/utils/as.h"
#include "td/utils/common.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"

#include <algorithm>

namespace td {
namespace mtproto {
namespace tcp {

size_t IntermediateTransport::read_from_stream(ChainBufferReader *stream, BufferSlice *message, uint32 *quick_ack) {
  CHECK(message);
  size_t stream_size = stream->size();
  size_t header_size = 4;
  if (stream->size() < header_size) {
    return header_size;
  }
  uint32 data_size;
  auto it = stream->clone();
  it.advance(header_size, MutableSlice(reinterpret_cast<uint8 *>(&data_size), sizeof(data_size)));
  if (data_size & (1u << 31)) {
    if (quick_ack) {
      *quick_ack = data_size;
    }
    stream->advance(header_size);
    return 0;
  }

  size_t total_size = data_size + header_size;
  if (stream_size < total_size) {
    // optimization
    // stream->make_solid(total_size);
    return total_size;
  }

  stream->advance(header_size);
  *message = stream->cut_head(data_size).move_as_buffer_slice();
  return 0;
}

void IntermediateTransport::write_prepare_inplace(BufferWriter *message, bool quick_ack) {
  size_t size = message->size();
  CHECK(size % 4 == 0);
  CHECK(size < (1 << 24));
  if (quick_ack) {
    size |= static_cast<size_t>(1) << 31;
  }

  size_t prepend_size = 4;
  MutableSlice prepend = message->prepare_prepend();
  CHECK(prepend.size() >= prepend_size);
  message->confirm_prepend(prepend_size);

  size_t append_size = 0;
  if (with_padding()) {
    append_size = Random::secure_uint32() % 16;
    MutableSlice append = message->prepare_append().substr(0, append_size);
    CHECK(append.size() == append_size);
    Random::secure_bytes(append);
    message->confirm_append(append.size());
  }

  as<uint32>(message->as_mutable_slice().begin()) = static_cast<uint32>(size + append_size);
}

void IntermediateTransport::init_output_stream(ChainBufferWriter *stream) {
  const uint32 magic = with_padding() ? 0xdddddddd : 0xeeeeeeee;
  stream->append(Slice(reinterpret_cast<const char *>(&magic), 4));
}

void ObfuscatedTransport::init(ChainBufferReader *input, ChainBufferWriter *output) {
  input_ = input;
  output_ = output;

  const size_t header_size = 64;
  string header(header_size, '\0');
  MutableSlice header_slice = header;
  int32 try_cnt = 0;
  while (true) {
    try_cnt++;
    CHECK(try_cnt < 10);
    Random::secure_bytes(header_slice.ubegin(), header.size());
    if (secret_.emulate_tls()) {
      break;
    }
    if (as<uint8>(header.data()) == 0xef) {
      continue;
    }
    uint32 first_int = as<uint32>(header.data());
    if (first_int == 0x44414548 || first_int == 0x54534f50 || first_int == 0x20544547 || first_int == 0x4954504f ||
        first_int == 0xdddddddd || first_int == 0xeeeeeeee || first_int == 0x02010316) {
      continue;
    }
    uint32 second_int = as<uint32>(header.data() + sizeof(uint32));
    if (second_int == 0) {
      continue;
    }
    break;
  }
  as<uint32>(header_slice.begin() + 56) = impl_.with_padding() ? 0xdddddddd : 0xeeeeeeee;
  if (dc_id_ != 0) {
    as<int16>(header_slice.begin() + 60) = dc_id_;
  }

  string rheader = header;
  std::reverse(rheader.begin(), rheader.end());
  UInt256 key = as<UInt256>(rheader.data() + 8);
  Slice proxy_secret = secret_.get_proxy_secret();
  auto fix_key = [&](UInt256 &key) {
    if (!proxy_secret.empty()) {
      Sha256State state;
      state.init();
      state.feed(as_slice(key));
      state.feed(proxy_secret);
      state.extract(as_mutable_slice(key));
    }
  };
  fix_key(key);
  aes_ctr_byte_flow_.init(key, as<UInt128>(rheader.data() + 8 + 32));
  if (secret_.emulate_tls()) {
    tls_reader_byte_flow_.set_input(input_);
    tls_reader_byte_flow_ >> aes_ctr_byte_flow_;
  } else {
    aes_ctr_byte_flow_.set_input(input_);
  }
  aes_ctr_byte_flow_ >> byte_flow_sink_;

  output_key_ = as<UInt256>(header.data() + 8);
  fix_key(output_key_);
  output_state_.init(as_slice(output_key_), Slice(header.data() + 8 + 32, 16));
  header_ = header;
  output_state_.encrypt(header_slice, header_slice);
  MutableSlice(header_).substr(56).copy_from(header_slice.substr(56));
}

Result<size_t> ObfuscatedTransport::read_next(BufferSlice *message, uint32 *quick_ack) {
  if (secret_.emulate_tls()) {
    tls_reader_byte_flow_.wakeup();
  } else {
    aes_ctr_byte_flow_.wakeup();
  }
  return impl_.read_from_stream(byte_flow_sink_.get_output(), message, quick_ack);
}

void ObfuscatedTransport::write(BufferWriter &&message, bool quick_ack) {
  impl_.write_prepare_inplace(&message, quick_ack);
  output_state_.encrypt(message.as_slice(), message.as_mutable_slice());
  if (secret_.emulate_tls()) {
    do_write_tls(std::move(message));
  } else {
    do_write_main(std::move(message));
  }
}

void ObfuscatedTransport::do_write_main(BufferWriter &&message) {
  BufferBuilder builder(std::move(message));
  if (!header_.empty()) {
    builder.prepend(header_);
    header_ = {};
  }
  do_write(builder.extract());
}

void ObfuscatedTransport::do_write_tls(BufferWriter &&message) {
  CHECK(header_.size() <= MAX_TLS_PACKET_LENGTH);
  if (message.size() + header_.size() > MAX_TLS_PACKET_LENGTH) {
    auto buffer_slice = message.as_buffer_slice();
    auto slice = buffer_slice.as_slice();
    while (!slice.empty()) {
      auto buf = buffer_slice.from_slice(slice.substr(0, MAX_TLS_PACKET_LENGTH - header_.size()));
      slice.remove_prefix(buf.size());
      BufferBuilder builder;
      builder.append(std::move(buf));
      do_write_tls(std::move(builder));
    }
    return;
  }

  BufferBuilder builder(std::move(message));
  do_write_tls(std::move(builder));
}

void ObfuscatedTransport::do_write_tls(BufferBuilder &&builder) {
  if (!header_.empty()) {
    builder.prepend(header_);
    header_ = {};
  }

  size_t size = builder.size();
  CHECK(size <= MAX_TLS_PACKET_LENGTH);

  char buf[] = "\x17\x03\x03\x00\x00";
  buf[3] = static_cast<char>((size >> 8) & 0xff);
  buf[4] = static_cast<char>(size & 0xff);
  builder.prepend(Slice(buf, 5));

  if (is_first_tls_packet_) {
    is_first_tls_packet_ = false;
    Slice first_prefix("\x14\x03\x03\x00\x01\x01");
    builder.prepend(first_prefix);
  }

  do_write(builder.extract());
}

void ObfuscatedTransport::do_write(BufferSlice &&message) {
  output_->append(std::move(message));
}

}  // namespace tcp
}  // namespace mtproto
}  // namespace td
