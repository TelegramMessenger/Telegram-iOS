//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/Transport.h"

#include "td/mtproto/AuthKey.h"
#include "td/mtproto/KDF.h"
#include "td/mtproto/MessageId.h"

#include "td/utils/as.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

#include <array>
#include <tuple>

namespace td {

int VERBOSITY_NAME(raw_mtproto) = VERBOSITY_NAME(DEBUG) + 10;

namespace mtproto {

#pragma pack(push, 4)
#if TD_MSVC
#pragma warning(push)
#pragma warning(disable : 4200)
#endif

struct CryptoHeader {
  uint64 auth_key_id;
  UInt128 message_key;

  // encrypted part
  uint64 salt;
  uint64 session_id;

  // It is weird to generate message_id and seq_no while writing a packet.
  //
  // uint64 msg_id;
  // uint32 seq_no;
  // uint32 message_data_length;
  uint8 data[0];  // use compiler extension

  static size_t encrypted_header_size() {
    return sizeof(salt) + sizeof(session_id);
  }

  uint8 *encrypt_begin() {
    return reinterpret_cast<uint8 *>(&salt);
  }

  const uint8 *encrypt_begin() const {
    return reinterpret_cast<const uint8 *>(&salt);
  }

  CryptoHeader() = delete;
  CryptoHeader(const CryptoHeader &) = delete;
  CryptoHeader(CryptoHeader &&) = delete;
  CryptoHeader &operator=(const CryptoHeader &) = delete;
  CryptoHeader &operator=(CryptoHeader &&) = delete;
  ~CryptoHeader() = delete;
};

struct CryptoPrefix {
  uint64 msg_id;
  uint32 seq_no;
  uint32 message_data_length;
};

struct EndToEndHeader {
  uint64 auth_key_id;
  UInt128 message_key;

  // encrypted part
  // uint32 message_data_length;
  uint8 data[0];  // use compiler extension

  static size_t encrypted_header_size() {
    return 0;
  }

  uint8 *encrypt_begin() {
    return reinterpret_cast<uint8 *>(&data);
  }

  const uint8 *encrypt_begin() const {
    return reinterpret_cast<const uint8 *>(&data);
  }

  EndToEndHeader() = delete;
  EndToEndHeader(const EndToEndHeader &) = delete;
  EndToEndHeader(EndToEndHeader &&) = delete;
  EndToEndHeader &operator=(const EndToEndHeader &) = delete;
  EndToEndHeader &operator=(EndToEndHeader &&) = delete;
  ~EndToEndHeader() = delete;
};

struct EndToEndPrefix {
  uint32 message_data_length;
};

struct NoCryptoHeader {
  uint64 auth_key_id;

  // msg_id is removed from CryptoHeader. Should be removed from here too.
  //
  // uint64 msg_id;
  // uint32 message_data_length;
  uint8 data[0];  // use compiler extension

  NoCryptoHeader() = delete;
  NoCryptoHeader(const NoCryptoHeader &) = delete;
  NoCryptoHeader(NoCryptoHeader &&) = delete;
  NoCryptoHeader &operator=(const NoCryptoHeader &) = delete;
  NoCryptoHeader &operator=(NoCryptoHeader &&) = delete;
  ~NoCryptoHeader() = delete;
};

#if TD_MSVC
#pragma warning(pop)
#endif
#pragma pack(pop)

// MTProto v1.0
template <class HeaderT>
std::pair<uint32, UInt128> Transport::calc_message_ack_and_key(const HeaderT &head, size_t data_size) {
  Slice part(head.encrypt_begin(), head.data + data_size);
  UInt<160> message_sha1;
  sha1(part, message_sha1.raw);
  return std::make_pair(as<uint32>(message_sha1.raw) | (1u << 31), as<UInt128>(message_sha1.raw + 4));
}

template <class HeaderT>
size_t Transport::calc_crypto_size(size_t data_size) {
  size_t enc_size = HeaderT::encrypted_header_size();
  size_t raw_size = sizeof(HeaderT) - enc_size;
  return raw_size + ((enc_size + data_size + 15) & ~15);
}

// MTProto v2.0
std::pair<uint32, UInt128> Transport::calc_message_key2(const AuthKey &auth_key, int X, Slice to_encrypt) {
  // msg_key_large = SHA256 (substr (auth_key, 88+x, 32) + plaintext + random_padding);
  Sha256State state;
  state.init();
  state.feed(Slice(auth_key.key()).substr(88 + X, 32));
  state.feed(to_encrypt);

  uint8 msg_key_large_raw[32];
  MutableSlice msg_key_large(msg_key_large_raw, sizeof(msg_key_large_raw));
  state.extract(msg_key_large, true);

  // msg_key = substr (msg_key_large, 8, 16);
  UInt128 res;
  as_mutable_slice(res).copy_from(msg_key_large.substr(8, 16));

  return std::make_pair(as<uint32>(msg_key_large_raw) | (1u << 31), res);
}

namespace {
size_t do_calc_crypto_size2_basic(size_t data_size, size_t enc_size, size_t raw_size) {
  size_t encrypted_size = (enc_size + data_size + 12 + 15) & ~15;

  std::array<size_t, 10> sizes{{64, 128, 192, 256, 384, 512, 768, 1024, 1280}};
  for (auto size : sizes) {
    if (encrypted_size <= size) {
      return raw_size + size;
    }
  }
  encrypted_size = (encrypted_size - 1280 + 447) / 448 * 448 + 1280;

  return raw_size + encrypted_size;
}

size_t do_calc_crypto_size2_rand(size_t data_size, size_t enc_size, size_t raw_size) {
  size_t rand_data_size = Random::secure_uint32() & 0xff;
  size_t encrypted_size = (enc_size + data_size + rand_data_size + 12 + 15) & ~15;
  return raw_size + encrypted_size;
}
}  // namespace

template <class HeaderT>
size_t Transport::calc_crypto_size2(size_t data_size, PacketInfo *packet_info) {
  size_t enc_size = HeaderT::encrypted_header_size();
  size_t raw_size = sizeof(HeaderT) - enc_size;
  if (packet_info->use_random_padding) {
    return do_calc_crypto_size2_rand(data_size, enc_size, raw_size);
  } else {
    return do_calc_crypto_size2_basic(data_size, enc_size, raw_size);
  }
}

size_t Transport::calc_no_crypto_size(size_t data_size) {
  return sizeof(NoCryptoHeader) + data_size;
}

Status Transport::read_no_crypto(MutableSlice message, PacketInfo *packet_info, MutableSlice *data) {
  if (message.size() < sizeof(NoCryptoHeader)) {
    return Status::Error(PSLICE() << "Invalid MTProto message: too small [message.size() = " << message.size()
                                  << "] < [sizeof(NoCryptoHeader) = " << sizeof(NoCryptoHeader) << "]");
  }
  size_t data_size = message.size() - sizeof(NoCryptoHeader);
  CHECK(message.size() == calc_no_crypto_size(data_size));
  *data = MutableSlice(message.begin() + sizeof(NoCryptoHeader), data_size);
  return Status::OK();
}

template <class HeaderT, class PrefixT>
Status Transport::read_crypto_impl(int X, MutableSlice message, const AuthKey &auth_key, HeaderT **header_ptr,
                                   PrefixT **prefix_ptr, MutableSlice *data, PacketInfo *packet_info) {
  if (message.size() < sizeof(HeaderT)) {
    return Status::Error(PSLICE() << "Invalid MTProto message: too small [message.size() = " << message.size()
                                  << "] < [sizeof(HeaderT) = " << sizeof(HeaderT) << "]");
  }
  //FIXME: rewrite without reinterpret cast
  auto *header = reinterpret_cast<HeaderT *>(message.begin());
  *header_ptr = header;
  auto to_decrypt = MutableSlice(header->encrypt_begin(), message.uend());
  to_decrypt.remove_suffix(to_decrypt.size() & 15);

  if (header->auth_key_id != auth_key.id()) {
    return Status::Error(PSLICE() << "Invalid MTProto message: auth_key_id mismatch [found = "
                                  << format::as_hex(header->auth_key_id)
                                  << "] [expected = " << format::as_hex(auth_key.id()) << "]");
  }

  UInt256 aes_key;
  UInt256 aes_iv;
  if (packet_info->version == 1) {
    KDF(auth_key.key(), header->message_key, X, &aes_key, &aes_iv);
  } else {
    KDF2(auth_key.key(), header->message_key, X, &aes_key, &aes_iv);
  }

  aes_ige_decrypt(as_slice(aes_key), as_mutable_slice(aes_iv), to_decrypt, to_decrypt);

  size_t tail_size = message.end() - reinterpret_cast<char *>(header->data);
  if (tail_size < sizeof(PrefixT)) {
    return Status::Error("Too small encrypted part");
  }
  //FIXME: rewrite without reinterpret cast
  auto *prefix = reinterpret_cast<PrefixT *>(header->data);
  *prefix_ptr = prefix;
  size_t data_size = prefix->message_data_length + sizeof(PrefixT);
  bool is_length_bad = false;
  UInt128 real_message_key;

  if (packet_info->version == 1) {
    is_length_bad |= packet_info->check_mod4 && prefix->message_data_length % 4 != 0;
    auto expected_size = calc_crypto_size<HeaderT>(data_size);
    is_length_bad |= expected_size != message.size();
    auto check_size = data_size * (1 - is_length_bad) + tail_size * is_length_bad;
    std::tie(packet_info->message_ack, real_message_key) = calc_message_ack_and_key(*header, check_size);
  } else {
    std::tie(packet_info->message_ack, real_message_key) = calc_message_key2(auth_key, X, to_decrypt);
  }

  int is_key_bad = false;
  for (size_t i = 0; i < sizeof(real_message_key.raw); i++) {
    is_key_bad |= real_message_key.raw[i] ^ header->message_key.raw[i];
  }
  if (is_key_bad != 0) {
    return Status::Error(PSLICE() << "Invalid MTProto message: message_key mismatch [found = "
                                  << format::as_hex_dump(header->message_key)
                                  << "] [expected = " << format::as_hex_dump(real_message_key) << "]");
  }

  if (packet_info->version == 2) {
    if (packet_info->check_mod4 && prefix->message_data_length % 4 != 0) {
      return Status::Error(PSLICE() << "Invalid MTProto message: invalid length (not divisible by four)"
                                    << tag("total_size", message.size())
                                    << tag("message_data_length", prefix->message_data_length));
    }
    if (tail_size - sizeof(PrefixT) < prefix->message_data_length) {
      return Status::Error(PSLICE() << "Invalid MTProto message: invalid length (message_data_length is too big)"
                                    << tag("total_size", message.size())
                                    << tag("message_data_length", prefix->message_data_length));
    }
    size_t pad_size = tail_size - data_size;
    if (pad_size < 12 || pad_size > 1024) {
      return Status::Error(PSLICE() << "Invalid MTProto message: invalid length (invalid padding length)"
                                    << tag("padding_size", pad_size) << tag("total_size", message.size())
                                    << tag("message_data_length", prefix->message_data_length));
    }
  } else {
    if (is_length_bad) {
      return Status::Error(PSLICE() << "Invalid MTProto message: invalid length " << tag("total_size", message.size())
                                    << tag("message_data_length", prefix->message_data_length));
    }
  }

  *data = MutableSlice(header->data, data_size);
  return Status::OK();
}

Status Transport::read_crypto(MutableSlice message, const AuthKey &auth_key, PacketInfo *packet_info,
                              MutableSlice *data) {
  CryptoHeader *header = nullptr;
  CryptoPrefix *prefix = nullptr;
  TRY_STATUS(read_crypto_impl(8, message, auth_key, &header, &prefix, data, packet_info));
  CHECK(header != nullptr);
  CHECK(prefix != nullptr);
  CHECK(packet_info != nullptr);
  packet_info->type = PacketInfo::Common;
  packet_info->salt = header->salt;
  packet_info->session_id = header->session_id;
  packet_info->message_id = MessageId(prefix->msg_id);
  packet_info->seq_no = prefix->seq_no;
  return Status::OK();
}
Status Transport::read_e2e_crypto(MutableSlice message, const AuthKey &auth_key, PacketInfo *packet_info,
                                  MutableSlice *data) {
  EndToEndHeader *header = nullptr;
  EndToEndPrefix *prefix = nullptr;
  TRY_STATUS(read_crypto_impl(packet_info->is_creator && packet_info->version != 1 ? 8 : 0, message, auth_key, &header,
                              &prefix, data, packet_info));
  CHECK(header != nullptr);
  CHECK(prefix != nullptr);
  CHECK(packet_info != nullptr);
  packet_info->type = PacketInfo::EndToEnd;
  return Status::OK();
}

BufferWriter Transport::write_no_crypto(const Storer &storer, PacketInfo *packet_info, size_t prepend_size,
                                        size_t append_size) {
  size_t size = calc_no_crypto_size(storer.size());
  auto packet = BufferWriter{size, prepend_size, append_size};

  // NoCryptoHeader
  auto *begin = packet.as_mutable_slice().ubegin();
  as<uint64>(begin) = 0;
  auto real_size = storer.store(begin + sizeof(uint64));
  CHECK(real_size == storer.size());
  return packet;
}

template <class HeaderT>
void Transport::write_crypto_impl(int X, const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                                  HeaderT *header, size_t data_size, size_t padded_size) {
  auto real_data_size = storer.store(header->data);
  CHECK(real_data_size == data_size);
  VLOG(raw_mtproto) << "Send packet of size " << data_size << ':'
                    << format::as_hex_dump<4>(Slice(header->data, data_size));
  size_t pad_size = padded_size - (sizeof(HeaderT) + data_size);
  MutableSlice pad(header->data + data_size, pad_size);
  Random::secure_bytes(pad.ubegin(), pad.size());
  MutableSlice to_encrypt = MutableSlice(header->encrypt_begin(), pad.uend());

  UInt256 aes_key;
  UInt256 aes_iv;
  if (packet_info->version == 1) {
    std::tie(packet_info->message_ack, header->message_key) = calc_message_ack_and_key(*header, data_size);
    KDF(auth_key.key(), header->message_key, X, &aes_key, &aes_iv);
  } else {
    std::tie(packet_info->message_ack, header->message_key) = calc_message_key2(auth_key, X, to_encrypt);
    KDF2(auth_key.key(), header->message_key, X, &aes_key, &aes_iv);
  }

  aes_ige_encrypt(as_slice(aes_key), as_mutable_slice(aes_iv), to_encrypt, to_encrypt);
}

BufferWriter Transport::write_crypto(const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                                     size_t prepend_size, size_t append_size) {
  size_t data_size = storer.size();
  size_t padded_size;
  if (packet_info->version == 1) {
    padded_size = calc_crypto_size<CryptoHeader>(data_size);
  } else {
    padded_size = calc_crypto_size2<CryptoHeader>(data_size, packet_info);
  }
  auto packet = BufferWriter{padded_size, prepend_size, append_size};

  //FIXME: rewrite without reinterpret cast
  auto &header = *reinterpret_cast<CryptoHeader *>(packet.as_mutable_slice().begin());
  header.auth_key_id = auth_key.id();
  header.salt = packet_info->salt;
  header.session_id = packet_info->session_id;

  write_crypto_impl(0, storer, auth_key, packet_info, &header, data_size, padded_size);

  return packet;
}

BufferWriter Transport::write_e2e_crypto(const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                                         size_t prepend_size, size_t append_size) {
  size_t data_size = storer.size();
  size_t padded_size;
  if (packet_info->version == 1) {
    padded_size = calc_crypto_size<EndToEndHeader>(data_size);
  } else {
    padded_size = calc_crypto_size2<EndToEndHeader>(data_size, packet_info);
  }
  auto packet = BufferWriter{padded_size, prepend_size, append_size};

  //FIXME: rewrite without reinterpret cast
  auto &header = *reinterpret_cast<EndToEndHeader *>(packet.as_mutable_slice().begin());
  header.auth_key_id = auth_key.id();

  write_crypto_impl(packet_info->is_creator || packet_info->version == 1 ? 0 : 8, storer, auth_key, packet_info,
                    &header, data_size, padded_size);

  return packet;
}

Result<uint64> Transport::read_auth_key_id(Slice message) {
  if (message.size() < 8) {
    return Status::Error(PSLICE() << "Invalid MTProto message: smaller than 8 bytes [size = " << message.size() << "]");
  }
  return as<uint64>(message.begin());
}

Result<Transport::ReadResult> Transport::read(MutableSlice message, const AuthKey &auth_key, PacketInfo *packet_info) {
  if (message.size() < 16) {
    if (message.size() < 4) {
      return Status::Error(PSLICE() << "Invalid MTProto message: smaller than 4 bytes [size = " << message.size()
                                    << "]");
    }

    int32 code = as<int32>(message.begin());
    if (code == 0) {
      return ReadResult::make_nop();
    } else if (code == -1 && message.size() >= 8) {
      return ReadResult::make_quick_ack(as<uint32>(message.begin() + 4));
    } else {
      return ReadResult::make_error(code);
    }
  }

  packet_info->no_crypto_flag = as<int64>(message.begin()) == 0;
  MutableSlice data;
  if (packet_info->type == PacketInfo::EndToEnd) {
    TRY_STATUS(read_e2e_crypto(message, auth_key, packet_info, &data));
  } else if (packet_info->no_crypto_flag) {
    TRY_STATUS(read_no_crypto(message, packet_info, &data));
  } else {
    if (auth_key.empty()) {
      return Status::Error("Failed to decrypt MTProto message: auth key is empty");
    }
    TRY_STATUS(read_crypto(message, auth_key, packet_info, &data));
  }
  return ReadResult::make_packet(data);
}

BufferWriter Transport::write(const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                              size_t prepend_size, size_t append_size) {
  if (packet_info->type == PacketInfo::EndToEnd) {
    return write_e2e_crypto(storer, auth_key, packet_info, prepend_size, append_size);
  }
  if (packet_info->no_crypto_flag) {
    return write_no_crypto(storer, packet_info, prepend_size, append_size);
  } else {
    CHECK(!auth_key.empty());
    return write_crypto(storer, auth_key, packet_info, prepend_size, append_size);
  }
}

}  // namespace mtproto
}  // namespace td
