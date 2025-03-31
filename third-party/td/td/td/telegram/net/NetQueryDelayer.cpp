//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/NetQueryDelayer.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryDispatcher.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

namespace td {

void NetQueryDelayer::delay(NetQueryPtr query) {
  query->debug("trying to delay");
  CHECK(query->is_ready());
  CHECK(query->is_error());
  auto code = query->error().code();
  int32 timeout = 0;
  if (code < 0) {
    // skip
  } else if (code == 500) {
    auto error_message = query->error().message();
    if (error_message == "WORKER_BUSY_TOO_LONG_RETRY") {
      timeout = 1;  // it is dangerous to resend query without timeout, so use 1
    }
  } else if (code == 420) {
    auto error_message = query->error().message();
    for (auto prefix : {Slice("FLOOD_WAIT_"), Slice("SLOWMODE_WAIT_"), Slice("2FA_CONFIRM_WAIT_"),
                        Slice("TAKEOUT_INIT_DELAY_"), Slice("FLOOD_PREMIUM_WAIT_")}) {
      if (begins_with(error_message, prefix)) {
        timeout = clamp(to_integer<int>(error_message.substr(prefix.size())), 1, 14 * 24 * 60 * 60);
        if (prefix == "FLOOD_PREMIUM_WAIT_") {
          switch (query->type()) {
            case NetQuery::Type::Common:
              LOG(ERROR) << "Receive " << error_message << " for " << query;
              break;
            case NetQuery::Type::Upload:
              G()->notify_speed_limited(true);
              break;
            case NetQuery::Type::Download:
            case NetQuery::Type::DownloadSmall:
              G()->notify_speed_limited(false);
              break;
            default:
              UNREACHABLE();
          }
        }
        break;
      }
    }
    if (timeout == 0 && begins_with(error_message, "FLOOD_SKIP_FAILED_WAIT")) {
      timeout = 1;
    }
  } else {
    G()->net_query_dispatcher().dispatch(std::move(query));
    return;
  }

  if (timeout == 0) {
    timeout = query->next_timeout_;
    if (timeout < 60) {
      query->next_timeout_ *= 2;
    }
  } else {
    query->next_timeout_ = 1;
  }
  query->total_timeout_ += timeout;
  query->last_timeout_ = timeout;
  LOG(INFO) << "Set total_timeout to " << query->total_timeout_ << " for " << query->id();

  auto error = query->error().clone();
  query->resend();

  // Fix for infinity flood control
  if (!query->need_resend_on_503_ && code == -503) {
    query->set_error(Status::Error(502, "Bad Gateway"));
    query->debug("DcManager: send to DcManager");
    G()->net_query_dispatcher().dispatch(std::move(query));
    return;
  }

  if (query->total_timeout_ > query->total_timeout_limit_) {
    // TODO: support timeouts in DcAuth and GetConfig
    LOG(WARNING) << "Failed: " << query << " " << tag("timeout", timeout) << tag("total_timeout", query->total_timeout_)
                 << " because of " << error << " from " << query->source_;
    // NB: code must differ from tdapi FLOOD_WAIT code
    query->set_error(Status::Error(429, PSLICE() << "Too Many Requests: retry after " << timeout));
    query->debug("DcManager: send to DcManager");
    G()->net_query_dispatcher().dispatch(std::move(query));
    return;
  }

  LOG(WARNING) << "Delay: " << query << " " << tag("timeout", timeout) << tag("total_timeout", query->total_timeout_)
               << " because of " << error << " from " << query->source_;
  query->debug(PSTRING() << "delay for " << format::as_time(timeout));
  auto id = container_.create(QuerySlot());
  auto *query_slot = container_.get(id);
  query_slot->query_ = std::move(query);
  query_slot->timeout_.set_event(EventCreator::yield(actor_shared(this, id)));
  query_slot->timeout_.set_timeout_in(timeout);
}

void NetQueryDelayer::wakeup() {
  auto link_token = get_link_token();
  if (link_token) {
    on_slot_event(link_token);
  }
  loop();
}

void NetQueryDelayer::on_slot_event(uint64 id) {
  auto *slot = container_.get(id);
  if (slot == nullptr) {
    return;
  }
  auto query = std::move(slot->query_);
  if (!query->invoke_after().empty()) {
    // Fail query after timeout expired if it is a part of an invokeAfter chain.
    // It is not necessary but helps to avoid server problems, when previous query was lost.
    query->set_error_resend_invoke_after();
  }
  slot->timeout_.close();
  container_.erase(id);
  G()->net_query_dispatcher().dispatch(std::move(query));
}

void NetQueryDelayer::tear_down() {
  container_.for_each([](auto id, auto &query_slot) {
    query_slot.query_->set_error(Global::request_aborted_error());
    G()->net_query_dispatcher().dispatch(std::move(query_slot.query_));
  });
  parent_.reset();
}

}  // namespace td
