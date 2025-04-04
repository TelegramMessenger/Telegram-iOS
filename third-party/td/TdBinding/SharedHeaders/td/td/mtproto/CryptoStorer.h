//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/AuthData.h"
#include "td/mtproto/MessageId.h"
#include "td/mtproto/MtprotoQuery.h"
#include "td/mtproto/PacketStorer.h"
#include "td/mtproto/utils.h"

#include "td/mtproto/mtproto_api.h"

#include "td/utils/common.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/StorerBase.h"
#include "td/utils/Time.h"

namespace td {
namespace mtproto_api {
class msg_container {
 public:
  static const int32 ID = 0x73f1f8dc;
};
}  // namespace mtproto_api

namespace mtproto {

template <class Object, class ObjectStorer>
class ObjectImpl {
 public:
  ObjectImpl(bool not_empty, Object &&object, AuthData *auth_data)
      : not_empty_(not_empty), object_(std::move(object)), object_storer_(object_) {
    if (empty()) {
      return;
    }
    message_id_ = auth_data->next_message_id(Time::now_cached());
    seq_no_ = auth_data->next_seq_no(false);
  }
  template <class StorerT>
  void do_store(StorerT &storer) const {
    if (empty()) {
      return;
    }
    storer.store_binary(message_id_);
    storer.store_binary(seq_no_);
    storer.store_binary(static_cast<int32>(object_storer_.size()));
    storer.store_storer(object_storer_);
  }
  bool not_empty() const {
    return not_empty_;
  }
  bool empty() const {
    return !not_empty_;
  }
  MessageId get_message_id() const {
    return message_id_;
  }

 private:
  bool not_empty_;
  Object object_;
  ObjectStorer object_storer_;
  MessageId message_id_;
  int32 seq_no_;
};

using AckImpl = ObjectImpl<mtproto_api::msgs_ack, TLObjectStorer<mtproto_api::msgs_ack>>;
using PingImpl = ObjectImpl<mtproto_api::ping_delay_disconnect, TLStorer<mtproto_api::ping_delay_disconnect>>;
using HttpWaitImpl = ObjectImpl<mtproto_api::http_wait, TLStorer<mtproto_api::http_wait>>;
using GetFutureSaltsImpl = ObjectImpl<mtproto_api::get_future_salts, TLStorer<mtproto_api::get_future_salts>>;
using ResendImpl = ObjectImpl<mtproto_api::msg_resend_req, TLObjectStorer<mtproto_api::msg_resend_req>>;
using CancelImpl = ObjectImpl<mtproto_api::rpc_drop_answer, TLStorer<mtproto_api::rpc_drop_answer>>;
using GetInfoImpl = ObjectImpl<mtproto_api::msgs_state_req, TLObjectStorer<mtproto_api::msgs_state_req>>;
using DestroyAuthKeyImpl = ObjectImpl<mtproto_api::destroy_auth_key, TLStorer<mtproto_api::destroy_auth_key>>;

class CancelVectorImpl {
 public:
  CancelVectorImpl(bool not_empty, const vector<int64> &to_cancel, AuthData *auth_data) {
    storers_.reserve(to_cancel.size());
    for (auto &request_id : to_cancel) {
      storers_.emplace_back(true, mtproto_api::rpc_drop_answer(request_id), auth_data);
    }
  }

  template <class StorerT>
  void do_store(StorerT &storer) const {
    for (auto &s : storers_) {
      storer.store_storer(s);
    }
  }
  bool not_empty() const {
    return !storers_.empty();
  }
  MessageId get_message_id() const {
    CHECK(storers_.size() == 1);
    return storers_[0].get_message_id();
  }

 private:
  vector<PacketStorer<CancelImpl>> storers_;
};

class InvokeAfter {
 public:
  explicit InvokeAfter(Span<MessageId> message_ids) : message_ids_(message_ids) {
  }
  template <class StorerT>
  void store(StorerT &storer) const {
    if (message_ids_.empty()) {
      return;
    }
    if (message_ids_.size() == 1) {
      storer.store_int(static_cast<int32>(0xcb9f372d));
      storer.store_binary(message_ids_[0].get());
      return;
    }
    //  invokeAfterMsgs#3dc4b4f0 {X:Type} msg_ids:Vector<long> query:!X = X;
    storer.store_int(static_cast<int32>(0x3dc4b4f0));
    storer.store_int(static_cast<int32>(0x1cb5c415));
    storer.store_int(narrow_cast<int32>(message_ids_.size()));
    for (auto message_id : message_ids_) {
      storer.store_binary(message_id.get());
    }
  }

 private:
  Span<MessageId> message_ids_;
};

class QueryImpl {
 public:
  QueryImpl(const MtprotoQuery &query, Slice header) : query_(query), header_(header) {
  }

  template <class StorerT>
  void do_store(StorerT &storer) const {
    storer.store_binary(query_.message_id);
    storer.store_binary(query_.seq_no);

    InvokeAfter invoke_after(query_.invoke_after_message_ids);
    auto invoke_after_storer = create_default_storer(invoke_after);

    Slice data = query_.packet.as_slice();
    mtproto_api::gzip_packed packed(data);
    auto plain_storer = create_storer(data);
    auto gzip_storer = TLObjectStorer<mtproto_api::gzip_packed>(packed);
    const Storer &data_storer =
        query_.gzip_flag ? static_cast<const Storer &>(gzip_storer) : static_cast<const Storer &>(plain_storer);
    auto header_storer = create_storer(header_);
    auto suff_storer = create_storer(invoke_after_storer, data_storer);
    auto all_storer = create_storer(header_storer, suff_storer);

    storer.store_binary(static_cast<uint32>(all_storer.size()));
    storer.store_storer(all_storer);
  }

 private:
  const MtprotoQuery &query_;
  Slice header_;
};

class QueryVectorImpl {
 public:
  QueryVectorImpl(const vector<MtprotoQuery> &to_send, Slice header) : to_send_(to_send), header_(header) {
  }

  template <class StorerT>
  void do_store(StorerT &storer) const {
    if (to_send_.empty()) {
      return;
    }
    for (auto &query : to_send_) {
      storer.store_storer(PacketStorer<QueryImpl>(query, header_));
    }
  }

 private:
  const vector<MtprotoQuery> &to_send_;
  Slice header_;
};

class ContainerImpl {
 public:
  ContainerImpl(int32 cnt, Storer &storer) : cnt_(cnt), storer_(storer) {
  }

  template <class StorerT>
  void do_store(StorerT &storer) const {
    storer.store_binary(mtproto_api::msg_container::ID);
    storer.store_binary(cnt_);
    storer.store_storer(storer_);
  }

 private:
  int32 cnt_;
  Storer &storer_;
};

class CryptoImpl {
 public:
  CryptoImpl(const vector<MtprotoQuery> &to_send, Slice header, vector<int64> &&to_ack, int64 ping_id, int ping_timeout,
             int max_delay, int max_after, int max_wait, int future_salt_n, vector<int64> get_info,
             vector<int64> resend, const vector<int64> &cancel, bool destroy_key, AuthData *auth_data,
             MessageId *container_message_id, MessageId *get_info_message_id, MessageId *resend_message_id,
             MessageId *ping_message_id, MessageId *parent_message_id)
      : query_storer_(to_send, header)
      , ack_empty_(to_ack.empty())
      , ack_storer_(!ack_empty_, mtproto_api::msgs_ack(std::move(to_ack)), auth_data)
      , http_wait_storer_(max_delay >= 0, mtproto_api::http_wait(max_delay, max_after, max_wait), auth_data)
      , get_future_salts_storer_(future_salt_n > 0, mtproto_api::get_future_salts(future_salt_n), auth_data)
      , get_info_not_empty_(!get_info.empty())
      , get_info_storer_(get_info_not_empty_, mtproto_api::msgs_state_req(std::move(get_info)), auth_data)
      , resend_not_empty_(!resend.empty())
      , resend_storer_(resend_not_empty_, mtproto_api::msg_resend_req(std::move(resend)), auth_data)
      , cancel_not_empty_(!cancel.empty())
      , cancel_cnt_(static_cast<int32>(cancel.size()))
      , cancel_storer_(cancel_not_empty_, cancel, auth_data)
      , destroy_key_storer_(destroy_key, mtproto_api::destroy_auth_key(), auth_data)
      , ping_storer_(ping_id != 0, mtproto_api::ping_delay_disconnect(ping_id, ping_timeout), auth_data)
      , tmp_storer_(query_storer_, ack_storer_)
      , tmp2_storer_(tmp_storer_, http_wait_storer_)
      , tmp3_storer_(tmp2_storer_, get_future_salts_storer_)
      , tmp4_storer_(tmp3_storer_, get_info_storer_)
      , tmp5_storer_(tmp4_storer_, resend_storer_)
      , tmp6_storer_(tmp5_storer_, cancel_storer_)
      , tmp7_storer_(tmp6_storer_, destroy_key_storer_)
      , concat_storer_(tmp7_storer_, ping_storer_)
      , cnt_(static_cast<int32>(to_send.size()) + ack_storer_.not_empty() + ping_storer_.not_empty() +
             http_wait_storer_.not_empty() + get_future_salts_storer_.not_empty() + get_info_storer_.not_empty() +
             resend_storer_.not_empty() + cancel_cnt_ + destroy_key_storer_.not_empty())
      , container_storer_(cnt_, concat_storer_) {
    CHECK(cnt_ != 0);
    if (get_info_storer_.not_empty() && get_info_message_id) {
      *get_info_message_id = get_info_storer_.get_message_id();
    }
    if (resend_storer_.not_empty() && resend_message_id) {
      *resend_message_id = resend_storer_.get_message_id();
    }
    if (ping_storer_.not_empty() && ping_message_id) {
      *ping_message_id = ping_storer_.get_message_id();
    }

    if (cnt_ > 1 ||
        (!to_send.empty() && !auth_data->is_valid_outbound_msg_id(to_send[0].message_id, Time::now_cached()))) {
      type_ = Mixed;
      message_id_ = auth_data->next_message_id(Time::now_cached());
      seq_no_ = auth_data->next_seq_no(false);

      *container_message_id = message_id_;
      *parent_message_id = message_id_;
    } else if (!to_send.empty()) {
      CHECK(to_send.size() == 1u);
      type_ = OnlyQuery;
      *parent_message_id = to_send[0].message_id;
    } else if (ack_storer_.not_empty()) {
      type_ = OnlyAck;
      *parent_message_id = ack_storer_.get_message_id();
    } else if (ping_storer_.not_empty()) {
      type_ = OnlyPing;
      *parent_message_id = ping_storer_.get_message_id();
    } else if (http_wait_storer_.not_empty()) {
      type_ = OnlyHttpWait;
      *parent_message_id = http_wait_storer_.get_message_id();
    } else if (get_future_salts_storer_.not_empty()) {
      type_ = OnlyGetFutureSalts;
      *parent_message_id = get_future_salts_storer_.get_message_id();
    } else if (get_info_storer_.not_empty()) {
      type_ = OnlyGetInfo;
      *parent_message_id = get_info_storer_.get_message_id();
    } else if (resend_storer_.not_empty()) {
      type_ = OnlyResend;
      *parent_message_id = resend_storer_.get_message_id();
    } else if (cancel_storer_.not_empty()) {
      type_ = OnlyCancel;
      *parent_message_id = cancel_storer_.get_message_id();
    } else if (destroy_key_storer_.not_empty()) {
      type_ = OnlyDestroyKey;
      *parent_message_id = destroy_key_storer_.get_message_id();
    } else {
      UNREACHABLE();
    }
  }

  template <class StorerT>
  void do_store(StorerT &storer) const {
    switch (type_) {
      case OnlyAck:
        return storer.store_storer(ack_storer_);

      case OnlyQuery:
        return storer.store_storer(query_storer_);

      case OnlyPing:
        return storer.store_storer(ping_storer_);

      case OnlyHttpWait:
        return storer.store_storer(http_wait_storer_);

      case OnlyGetFutureSalts:
        return storer.store_storer(get_future_salts_storer_);

      case OnlyResend:
        return storer.store_storer(resend_storer_);

      case OnlyCancel:
        return storer.store_storer(cancel_storer_);

      case OnlyGetInfo:
        return storer.store_storer(get_info_storer_);

      case OnlyDestroyKey:
        return storer.store_storer(destroy_key_storer_);

      default:
        storer.store_binary(message_id_);
        storer.store_binary(seq_no_);
        storer.store_binary(static_cast<int32>(container_storer_.size()));
        storer.store_storer(container_storer_);
    }
  }

 private:
  PacketStorer<QueryVectorImpl> query_storer_;
  bool ack_empty_;
  PacketStorer<AckImpl> ack_storer_;
  PacketStorer<HttpWaitImpl> http_wait_storer_;
  PacketStorer<GetFutureSaltsImpl> get_future_salts_storer_;
  bool get_info_not_empty_;
  PacketStorer<GetInfoImpl> get_info_storer_;
  bool resend_not_empty_;
  PacketStorer<ResendImpl> resend_storer_;
  bool cancel_not_empty_;
  int32 cancel_cnt_;
  PacketStorer<CancelVectorImpl> cancel_storer_;
  PacketStorer<DestroyAuthKeyImpl> destroy_key_storer_;
  PacketStorer<PingImpl> ping_storer_;
  ConcatStorer tmp_storer_;
  ConcatStorer tmp2_storer_;
  ConcatStorer tmp3_storer_;
  ConcatStorer tmp4_storer_;
  ConcatStorer tmp5_storer_;
  ConcatStorer tmp6_storer_;
  ConcatStorer tmp7_storer_;
  ConcatStorer concat_storer_;
  int32 cnt_;
  PacketStorer<ContainerImpl> container_storer_;
  enum Type {
    OnlyQuery,
    OnlyAck,
    OnlyPing,
    OnlyHttpWait,
    OnlyGetFutureSalts,
    OnlyResend,
    OnlyCancel,
    OnlyGetInfo,
    OnlyDestroyKey,
    Mixed
  };
  Type type_;
  MessageId message_id_;
  int32 seq_no_;
};

}  // namespace mtproto
}  // namespace td
