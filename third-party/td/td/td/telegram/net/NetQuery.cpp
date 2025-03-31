//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/NetQuery.h"

#include "td/telegram/ChainId.h"
#include "td/telegram/Global.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/as.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

#include <algorithm>

namespace td {

int VERBOSITY_NAME(net_query) = VERBOSITY_NAME(INFO);

void NetQuery::debug(string state, bool may_be_lost) {
  may_be_lost_ = may_be_lost;
  VLOG(net_query) << *this << " [" << state << ']';
  {
    auto guard = lock();
    auto &data = get_data_unsafe();
    data.state_ = std::move(state);
    data.state_timestamp_ = Time::now();
    data.state_change_count_++;
  }
}

NetQuery::NetQuery(uint64 id, BufferSlice &&query, DcId dc_id, Type type, AuthFlag auth_flag, GzipFlag gzip_flag,
                   int32 tl_constructor, int32 total_timeout_limit, NetQueryStats *stats, vector<ChainId> chain_ids)
    : state_(State::Query)
    , type_(type)
    , auth_flag_(auth_flag)
    , gzip_flag_(gzip_flag)
    , dc_id_(dc_id)
    , status_()
    , id_(id)
    , query_(std::move(query))
    , tl_constructor_(tl_constructor)
    , total_timeout_limit_(total_timeout_limit) {
  CHECK(id_ != 0);
  chain_ids_ = transform(chain_ids, [](ChainId chain_id) { return chain_id.get() == 0 ? 1 : chain_id.get(); });
  td::unique(chain_ids_);

  auto &data = get_data_unsafe();
  data.my_id_ = G()->get_option_integer("my_id");
  data.start_timestamp_ = data.state_timestamp_ = Time::now();
  LOG(INFO) << *this;
  if (stats) {
    nq_counter_ = stats->register_query(this);
  }
}

void NetQuery::clear() {
  if (!is_ready()) {
    auto guard = lock();
    LOG(ERROR) << "Destroy not ready query " << *this << " " << tag("state", get_data_unsafe().state_);
  }
  // TODO: CHECK if net_query is lost here
  cancel_slot_.close();
  *this = NetQuery();
}

void NetQuery::resend(DcId new_dc_id) {
  VLOG(net_query) << "Resend " << *this;
  {
    auto guard = lock();
    get_data_unsafe().resend_count_++;
  }
  dc_id_ = new_dc_id;
  status_ = Status::OK();
  state_ = State::Query;
}

bool NetQuery::update_is_ready() {
  if (state_ == State::Query) {
    if (cancellation_token_.load(std::memory_order_relaxed) == 0 || cancel_slot_.was_signal()) {
      set_error_canceled();
      return true;
    }
    return false;
  }
  return true;
}

void NetQuery::set_ok(BufferSlice slice) {
  VLOG(net_query) << "Receive answer " << *this;
  CHECK(state_ == State::Query);
  answer_ = std::move(slice);
  state_ = State::OK;
}

void NetQuery::on_net_write(size_t size) {
  const auto &callbacks = G()->get_net_stats_file_callbacks();
  if (static_cast<size_t>(file_type_) < callbacks.size()) {
    callbacks[file_type_]->on_write(size);
  }
}

void NetQuery::on_net_read(size_t size) {
  const auto &callbacks = G()->get_net_stats_file_callbacks();
  if (static_cast<size_t>(file_type_) < callbacks.size()) {
    callbacks[file_type_]->on_read(size);
  }
}

int32 NetQuery::tl_magic(const BufferSlice &buffer_slice) {
  auto slice = buffer_slice.as_slice();
  if (slice.size() < 4) {
    return 0;
  }
  return as<int32>(slice.begin());
}

void NetQuery::set_error(Status status, string source) {
  if (status.code() == Error::Resend || status.code() == Error::Canceled || status.code() == Error::ResendInvokeAfter) {
    return set_error_impl(Status::Error(200, PSLICE() << status), std::move(source));
  }

  if (begins_with(status.message(), "INPUT_METHOD_INVALID")) {
    LOG(ERROR) << "Receive INPUT_METHOD_INVALID for query " << format::as_hex_dump<4>(query_.as_slice());
  }
  if (status.message() == "BOT_METHOD_INVALID") {
    auto id = tl_constructor();
    if (id != telegram_api::help_getNearestDc::ID && id != telegram_api::help_getAppConfig::ID) {
      LOG(ERROR) << "Receive BOT_METHOD_INVALID for query " << format::as_hex(id);
    }
  }
  if (status.message() == "MSG_WAIT_FAILED" && status.code() != 400) {
    status = Status::Error(400, "MSG_WAIT_FAILED");
  }
  set_error_impl(std::move(status), std::move(source));
}

void NetQuery::set_error_impl(Status status, string source) {
  VLOG(net_query) << "Receive error " << *this << " " << status;
  status_ = std::move(status);
  state_ = State::Error;
  source_ = std::move(source);
}

StringBuilder &operator<<(StringBuilder &string_builder, const NetQuery &net_query) {
  string_builder << "[Query:";
  string_builder << tag("id", net_query.id());
  string_builder << tag("tl", format::as_hex(net_query.tl_constructor()));
  auto message_id = net_query.message_id();
  if (message_id != 0) {
    string_builder << tag("msg_id", format::as_hex(message_id));
  }
  if (net_query.is_error()) {
    string_builder << net_query.error();
  } else if (net_query.is_ok()) {
    string_builder << tag("result_tl", format::as_hex(net_query.ok_tl_constructor()));
  }
  string_builder << ']';
  return string_builder;
}

StringBuilder &operator<<(StringBuilder &string_builder, const NetQueryPtr &net_query_ptr) {
  if (net_query_ptr.empty()) {
    return string_builder << "[Query: null]";
  }
  return string_builder << *net_query_ptr;
}

void NetQuery::add_verification_prefix(const string &prefix) {
  CHECK(is_ready());
  CHECK(is_error());
  CHECK(!query_.empty());
  BufferSlice query(prefix.size() + query_.size() - verification_prefix_length_);
  query.as_mutable_slice().copy_from(prefix);
  query.as_mutable_slice().substr(prefix.size()).copy_from(query_.as_slice().substr(verification_prefix_length_));
  verification_prefix_length_ = narrow_cast<int32>(prefix.size());
  query_ = std::move(query);
}

}  // namespace td
