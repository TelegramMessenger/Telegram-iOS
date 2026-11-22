//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/ReferralProgramInfo.h"
#include "td/telegram/ReferralProgramParameters.h"
#include "td/telegram/ReferralProgramSortOrder.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class ReferralProgramManager final : public Actor {
 public:
  ReferralProgramManager(Td *td, ActorShared<> parent);

  void set_dialog_referral_program(DialogId dialog_id, ReferralProgramParameters parameters, Promise<Unit> &&promise);

  void search_dialog_referral_program(const string &username, const string &referral,
                                      Promise<td_api::object_ptr<td_api::chat>> &&promise);

  void search_referral_programs(const td_api::object_ptr<td_api::AffiliateType> &affiliate,
                                ReferralProgramSortOrder sort_order, const string &offset, int32 limit,
                                Promise<td_api::object_ptr<td_api::foundAffiliatePrograms>> &&promise);

  void connect_referral_program(const td_api::object_ptr<td_api::AffiliateType> &affiliate, UserId bot_user_id,
                                Promise<td_api::object_ptr<td_api::connectedAffiliateProgram>> &&promise);

  void revoke_referral_program(const td_api::object_ptr<td_api::AffiliateType> &affiliate, const string &url,
                               Promise<td_api::object_ptr<td_api::connectedAffiliateProgram>> &&promise);

  void get_connected_referral_program(const td_api::object_ptr<td_api::AffiliateType> &affiliate, UserId bot_user_id,
                                      Promise<td_api::object_ptr<td_api::connectedAffiliateProgram>> &&promise);

  void get_connected_referral_programs(const td_api::object_ptr<td_api::AffiliateType> &affiliate, const string &offset,
                                       int32 limit,
                                       Promise<td_api::object_ptr<td_api::connectedAffiliatePrograms>> &&promise);

 private:
  class GetSuggestedStarRefBotsQuery;
  class ConnectStarRefBotQuery;
  class EditConnectedStarRefBotQuery;
  class GetConnectedStarRefBotQuery;
  class GetConnectedStarRefBotsQuery;

  class SuggestedBotStarRef {
    UserId user_id_;
    ReferralProgramInfo info_;

   public:
    explicit SuggestedBotStarRef(telegram_api::object_ptr<telegram_api::starRefProgram> &&ref);

    bool is_valid() const {
      return user_id_.is_valid() && info_.is_valid();
    }

    bool is_active() const {
      return info_.is_active();
    }

    td_api::object_ptr<td_api::foundAffiliateProgram> get_found_affiliate_program_object(Td *td) const;
  };

  class ConnectedBotStarRef {
    string url_;
    int32 date_ = 0;
    UserId user_id_;
    ReferralProgramParameters parameters_;
    int64 participant_count_ = 0;
    int64 revenue_star_count_ = 0;
    bool is_revoked_ = false;

   public:
    explicit ConnectedBotStarRef(telegram_api::object_ptr<telegram_api::connectedBotStarRef> &&ref);

    bool is_valid() const {
      return !url_.empty() && date_ > 0 && user_id_.is_valid() && parameters_.is_valid() && participant_count_ >= 0 &&
             revenue_star_count_ >= 0;
    }

    td_api::object_ptr<td_api::connectedAffiliateProgram> get_connected_affiliate_program_object(Td *td) const;
  };

  void tear_down() final;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
