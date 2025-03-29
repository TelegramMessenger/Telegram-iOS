//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/NetQueryCreator.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/Gzip.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/Storer.h"

namespace td {

NetQueryCreator::NetQueryCreator(std::shared_ptr<NetQueryStats> net_query_stats)
    : net_query_stats_(std::move(net_query_stats))
    , current_scheduler_id_(Scheduler::instance() == nullptr ? -2 : Scheduler::instance()->sched_id()) {
  object_pool_.set_check_empty(true);
}

NetQueryPtr NetQueryCreator::create(const telegram_api::Function &function, vector<ChainId> chain_ids, DcId dc_id,
                                    NetQuery::Type type) {
  return create(UniqueId::next(), nullptr, function, std::move(chain_ids), dc_id, type, NetQuery::AuthFlag::On);
}

NetQueryPtr NetQueryCreator::create_with_prefix(const telegram_api::object_ptr<telegram_api::Function> &prefix,
                                                const telegram_api::Function &function, DcId dc_id,
                                                vector<ChainId> chain_ids, NetQuery::Type type) {
  return create(UniqueId::next(), prefix, function, std::move(chain_ids), dc_id, type, NetQuery::AuthFlag::On);
}

NetQueryPtr NetQueryCreator::create(uint64 id, const telegram_api::object_ptr<telegram_api::Function> &prefix,
                                    const telegram_api::Function &function, vector<ChainId> &&chain_ids, DcId dc_id,
                                    NetQuery::Type type, NetQuery::AuthFlag auth_flag) {
  LOG(INFO) << "Create query " << to_string(function);
  string prefix_str;
  if (prefix != nullptr) {
    auto storer = DefaultStorer<telegram_api::Function>(*prefix);
    prefix_str.resize(storer.size());
    auto real_size = storer.store(MutableSlice(prefix_str).ubegin());
    CHECK(real_size == prefix_str.size());
  }

  auto storer = DefaultStorer<telegram_api::Function>(function);
  BufferSlice slice(prefix_str.size() + storer.size());
  auto real_size = storer.store(slice.as_mutable_slice().ubegin() + prefix_str.size());
  LOG_CHECK(prefix_str.size() + real_size == slice.size())
      << prefix_str.size() << ' ' << real_size << ' ' << slice.size() << ' '
      << format::as_hex_dump<4>(slice.as_slice());
  if (prefix != nullptr) {
    slice.as_mutable_slice().copy_from(prefix_str);
  }

  size_t min_gzipped_size = 128;
  int32 tl_constructor = function.get_id();
  int32 total_timeout_limit = 60;

  if (Scheduler::instance() != nullptr && current_scheduler_id_ == Scheduler::instance()->sched_id() &&
      !G()->close_flag()) {
    auto td = G()->td();
    if (!td.empty()) {
      auto auth_manager = td.get_actor_unsafe()->auth_manager_.get();
      if (auth_manager != nullptr && auth_manager->is_bot()) {
        total_timeout_limit = 8;
        min_gzipped_size = 1024;
      }
      if ((auth_manager == nullptr || !auth_manager->was_authorized()) && auth_flag == NetQuery::AuthFlag::On &&
          tl_constructor != telegram_api::auth_exportAuthorization::ID &&
          tl_constructor != telegram_api::auth_bindTempAuthKey::ID) {
        LOG(ERROR) << "Send query before authorization: " << to_string(function);
      }
    }
  }

  auto gzip_flag = slice.size() < min_gzipped_size ? NetQuery::GzipFlag::Off : NetQuery::GzipFlag::On;
  if (slice.size() >= 16384) {
    // test compression ratio for the middle part
    // if it is less than 0.9, then try to compress the whole request
    size_t TESTED_SIZE = 1024;
    BufferSlice compressed_part = gzencode(slice.as_slice().substr((slice.size() - TESTED_SIZE) / 2, TESTED_SIZE), 0.9);
    if (compressed_part.empty()) {
      gzip_flag = NetQuery::GzipFlag::Off;
    }
  }
  if (gzip_flag == NetQuery::GzipFlag::On) {
    BufferSlice compressed = gzencode(slice.as_slice(), 0.9);
    if (compressed.empty()) {
      gzip_flag = NetQuery::GzipFlag::Off;
    } else {
      slice = std::move(compressed);
    }
  }

  auto query = object_pool_.create(id, std::move(slice), dc_id, type, auth_flag, gzip_flag, tl_constructor,
                                   total_timeout_limit, net_query_stats_.get(), std::move(chain_ids));
  query->set_cancellation_token(query.generation());
  return query;
}

}  // namespace td
