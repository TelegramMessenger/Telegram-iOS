//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TopDialogCategory.h"

namespace td {

CSlice get_top_dialog_category_name(TopDialogCategory category) {
  switch (category) {
    case TopDialogCategory::Correspondent:
      return CSlice("correspondent");
    case TopDialogCategory::BotPM:
      return CSlice("bot_pm");
    case TopDialogCategory::BotInline:
      return CSlice("bot_inline");
    case TopDialogCategory::Group:
      return CSlice("group");
    case TopDialogCategory::Channel:
      return CSlice("channel");
    case TopDialogCategory::Call:
      return CSlice("call");
    case TopDialogCategory::ForwardUsers:
      return CSlice("forward_users");
    case TopDialogCategory::ForwardChats:
      return CSlice("forward_chats");
    case TopDialogCategory::BotApp:
      return CSlice("bot_app");
    default:
      UNREACHABLE();
      return CSlice();
  }
}

TopDialogCategory get_top_dialog_category(const td_api::object_ptr<td_api::TopChatCategory> &category) {
  if (category == nullptr) {
    return TopDialogCategory::Size;
  }
  switch (category->get_id()) {
    case td_api::topChatCategoryUsers::ID:
      return TopDialogCategory::Correspondent;
    case td_api::topChatCategoryBots::ID:
      return TopDialogCategory::BotPM;
    case td_api::topChatCategoryInlineBots::ID:
      return TopDialogCategory::BotInline;
    case td_api::topChatCategoryGroups::ID:
      return TopDialogCategory::Group;
    case td_api::topChatCategoryChannels::ID:
      return TopDialogCategory::Channel;
    case td_api::topChatCategoryCalls::ID:
      return TopDialogCategory::Call;
    case td_api::topChatCategoryForwardChats::ID:
      return TopDialogCategory::ForwardUsers;
    case td_api::topChatCategoryWebAppBots::ID:
      return TopDialogCategory::BotApp;
    default:
      UNREACHABLE();
      return TopDialogCategory::Size;
  }
}

TopDialogCategory get_top_dialog_category(const telegram_api::object_ptr<telegram_api::TopPeerCategory> &category) {
  CHECK(category != nullptr);
  switch (category->get_id()) {
    case telegram_api::topPeerCategoryCorrespondents::ID:
      return TopDialogCategory::Correspondent;
    case telegram_api::topPeerCategoryBotsPM::ID:
      return TopDialogCategory::BotPM;
    case telegram_api::topPeerCategoryBotsInline::ID:
      return TopDialogCategory::BotInline;
    case telegram_api::topPeerCategoryGroups::ID:
      return TopDialogCategory::Group;
    case telegram_api::topPeerCategoryChannels::ID:
      return TopDialogCategory::Channel;
    case telegram_api::topPeerCategoryPhoneCalls::ID:
      return TopDialogCategory::Call;
    case telegram_api::topPeerCategoryForwardUsers::ID:
      return TopDialogCategory::ForwardUsers;
    case telegram_api::topPeerCategoryForwardChats::ID:
      return TopDialogCategory::ForwardChats;
    case telegram_api::topPeerCategoryBotsApp::ID:
      return TopDialogCategory::BotApp;
    default:
      UNREACHABLE();
      return TopDialogCategory::Size;
  }
}

telegram_api::object_ptr<telegram_api::TopPeerCategory> get_input_top_peer_category(TopDialogCategory category) {
  switch (category) {
    case TopDialogCategory::Correspondent:
      return make_tl_object<telegram_api::topPeerCategoryCorrespondents>();
    case TopDialogCategory::BotPM:
      return make_tl_object<telegram_api::topPeerCategoryBotsPM>();
    case TopDialogCategory::BotInline:
      return make_tl_object<telegram_api::topPeerCategoryBotsInline>();
    case TopDialogCategory::Group:
      return make_tl_object<telegram_api::topPeerCategoryGroups>();
    case TopDialogCategory::Channel:
      return make_tl_object<telegram_api::topPeerCategoryChannels>();
    case TopDialogCategory::Call:
      return make_tl_object<telegram_api::topPeerCategoryPhoneCalls>();
    case TopDialogCategory::ForwardUsers:
      return make_tl_object<telegram_api::topPeerCategoryForwardUsers>();
    case TopDialogCategory::ForwardChats:
      return make_tl_object<telegram_api::topPeerCategoryForwardChats>();
    case TopDialogCategory::BotApp:
      return make_tl_object<telegram_api::topPeerCategoryBotsApp>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

}  // namespace td
