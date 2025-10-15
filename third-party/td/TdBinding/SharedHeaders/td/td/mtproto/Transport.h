//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/PacketInfo.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StorerBase.h"
#include "td/utils/UInt.h"

#include <utility>

namespace td {

extern int VERBOSITY_NAME(raw_mtproto);

namespace mtproto {

class AuthKey;

class Transport {
 public:
  class ReadResult {
   public:
    enum Type { Packet, Nop, Error, Quickack };

    static ReadResult make_nop() {
      return {};
    }
    static ReadResult make_error(int32 error_code) {
      ReadResult res;
      res.type_ = Error;
      res.error_code_ = error_code;
      return res;
    }
    static ReadResult make_packet(MutableSlice packet) {
      CHECK(!packet.empty());
      ReadResult res;
      res.type_ = Packet;
      res.packet_ = packet;
      return res;
    }
    static ReadResult make_quick_ack(uint32 quick_ack) {
      ReadResult res;
      res.type_ = Quickack;
      res.quick_ack_ = quick_ack;
      return res;
    }

    Type type() const {
      return type_;
    }

    MutableSlice packet() const {
      CHECK(type_ == Packet);
      return packet_;
    }
    uint32 quick_ack() const {
      CHECK(type_ == Quickack);
      return quick_ack_;
    }
    int32 error() const {
      CHECK(type_ == Error);
      return error_code_;
    }

   private:
    Type type_ = Nop;
    MutableSlice packet_;
    int32 error_code_ = 0;
    uint32 quick_ack_ = 0;
  };

  static Result<uint64> read_auth_key_id(Slice message);

  // Reads MTProto packet from [message] and saves it into [data].
  // If message is encrypted, [auth_key] is used.
  // Decryption and unpacking is made inplace, so [data] will be subslice of [message].
  // Returns size of MTProto packet.
  // If dest.size() >= size, the packet is also written into [dest].
  // If auth_key is nonempty, encryption will be used.
  static Result<ReadResult> read(MutableSlice message, const AuthKey &auth_key,
                                 PacketInfo *packet_info) TD_WARN_UNUSED_RESULT;

  static BufferWriter write(const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                            size_t prepend_size = 0, size_t append_size = 0);

  // public for testing purposes
  static std::pair<uint32, UInt128> calc_message_key2(const AuthKey &auth_key, int X, Slice to_encrypt);

 private:
  template <class HeaderT>
  static std::pair<uint32, UInt128> calc_message_ack_and_key(const HeaderT &head, size_t data_size);

  template <class HeaderT>
  static size_t calc_crypto_size(size_t data_size);

  template <class HeaderT>
  static size_t calc_crypto_size2(size_t data_size, PacketInfo *packet_info);

  static size_t calc_no_crypto_size(size_t data_size);

  static Status read_no_crypto(MutableSlice message, PacketInfo *packet_info, MutableSlice *data) TD_WARN_UNUSED_RESULT;

  static Status read_crypto(MutableSlice message, const AuthKey &auth_key, PacketInfo *packet_info,
                            MutableSlice *data) TD_WARN_UNUSED_RESULT;

  static Status read_e2e_crypto(MutableSlice message, const AuthKey &auth_key, PacketInfo *packet_info,
                                MutableSlice *data) TD_WARN_UNUSED_RESULT;

  template <class HeaderT, class PrefixT>
  static Status read_crypto_impl(int X, MutableSlice message, const AuthKey &auth_key, HeaderT **header_ptr,
                                 PrefixT **prefix_ptr, MutableSlice *data,
                                 PacketInfo *packet_info) TD_WARN_UNUSED_RESULT;

  static BufferWriter write_no_crypto(const Storer &storer, PacketInfo *packet_info, size_t prepend_size,
                                      size_t append_size);

  static BufferWriter write_crypto(const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                                   size_t prepend_size, size_t append_size);

  static BufferWriter write_e2e_crypto(const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                                       size_t prepend_size, size_t append_size);

  template <class HeaderT>
  static void write_crypto_impl(int X, const Storer &storer, const AuthKey &auth_key, PacketInfo *packet_info,
                                HeaderT *header, size_t data_size, size_t padded_size);
};

}  // namespace mtproto
}  // namespace td
