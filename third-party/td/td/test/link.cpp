//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/LinkManager.h"

#include "td/telegram/MessageEntity.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/tests.h"

static void check_find_urls(const td::string &url, bool is_valid) {
  auto url_lower = td::to_lower(url);
  {
    auto tg_urls = td::find_tg_urls(url);
    if (is_valid && (td::begins_with(url_lower, "tg://") || td::begins_with(url_lower, "ton://"))) {
      ASSERT_EQ(1u, tg_urls.size());
      ASSERT_STREQ(url, tg_urls[0]);
    } else {
      ASSERT_TRUE(tg_urls.empty() || tg_urls[0] != url);
    }
  }

  {
    if (is_valid && (td::begins_with(url_lower, "http") || td::begins_with(url_lower, "t.me")) &&
        url.find('.') != td::string::npos && url.find(' ') == td::string::npos && url != "http://.." &&
        url.find("ra.ph") == td::string::npos && url.find("Aph") == td::string::npos) {
      auto urls = td::find_urls(url);
      ASSERT_EQ(1u, urls.size());
      ASSERT_STREQ(url, urls[0].first);
    }
  }
}

static void check_link(const td::string &url, const td::string &expected) {
  auto result = td::LinkManager::check_link(url);
  if (result.is_ok()) {
    ASSERT_STREQ(expected, result.ok());
  } else {
    ASSERT_TRUE(expected.empty());
  }

  check_find_urls(url, result.is_ok());
}

TEST(Link, check_link) {
  check_link("sftp://google.com", "");
  check_link("tg://google_com", "tg://google_com/");
  check_link("tOn://google", "ton://google/");
  check_link("httP://google.com?1#tes", "http://google.com/?1#tes");
  check_link("httPs://google.com/?1#tes", "https://google.com/?1#tes");
  check_link("http://google.com:0", "");
  check_link("http://google.com:0000000001", "http://google.com:1/");
  check_link("http://google.com:-1", "");
  check_link("tg://google?1#tes", "tg://google?1#tes");
  check_link("tg://google/?1#tes", "tg://google?1#tes");
  check_link("TG:_", "tg://_/");
  check_link("sftp://google.com", "");
  check_link("sftp://google.com", "");
  check_link("http:google.com", "");
  check_link("tg://http://google.com", "");
  check_link("tg:http://google.com", "");
  check_link("tg:https://google.com", "");
  check_link("tg:test@google.com", "");
  check_link("tg:google.com:80", "");
  check_link("tg:google-com", "tg://google-com/");
  check_link("tg:google.com", "");
  check_link("tg:google.com:0", "");
  check_link("tg:google.com:a", "");
  check_link("tg:[2001:db8:0:0:0:ff00:42:8329]", "");
  check_link("tg:127.0.0.1", "");
  check_link("http://[2001:db8:0:0:0:ff00:42:8329]", "http://[2001:db8:0:0:0:ff00:42:8329]/");
  check_link("http://localhost", "");
  check_link("http://..", "http://../");
  check_link("..", "http://../");
  check_link("https://.", "");
  check_link("tOnSiTe://google", "tonsite://google/");
  check_link("tOnSiTe://google.ton?t=1#we", "tonsite://google.ton?t=1#we");
}

static td::td_api::object_ptr<td::td_api::InternalLinkType> get_internal_link_type_object(
    const td::unique_ptr<td::LinkManager::InternalLink> &link) {
  auto object = link->get_internal_link_type_object();
  if (object->get_id() == td::td_api::internalLinkTypeMessageDraft::ID) {
    static_cast<td::td_api::internalLinkTypeMessageDraft *>(object.get())->text_->entities_.clear();
  }
  return object;
}

static void parse_internal_link(const td::string &url, td::td_api::object_ptr<td::td_api::InternalLinkType> expected) {
  auto result = td::LinkManager::parse_internal_link(url);
  if (result != nullptr) {
    auto object = get_internal_link_type_object(result);
    ASSERT_STREQ(url + ' ' + to_string(expected), url + ' ' + to_string(object));

    for (auto is_internal : {true, false}) {
      if (!is_internal && expected->get_id() == td::td_api::internalLinkTypeChatBoost::ID) {
        // external chat boost links must be generated with getChatBoostLink
        continue;
      }
      if (!is_internal && expected->get_id() == td::td_api::internalLinkTypeMessage::ID) {
        // external message links must be generated with getMessageLink
        continue;
      }
      if (expected->get_id() == td::td_api::internalLinkTypeQrCodeAuthentication::ID) {
        // QR code authentication links must never be generated manually
        continue;
      }
      auto r_link = td::LinkManager::get_internal_link(expected, is_internal);
      if (r_link.is_error()) {
        if (r_link.error().message() == "HTTP link is unavailable for the link type") {
          // some links are tg-only
          continue;
        }
        if (r_link.error().message() == "Deep link is unavailable for the link type") {
          // some links are HTTP-only
          continue;
        }
        if (r_link.error().message() == "WALLPAPER_INVALID") {
          continue;
        }
        LOG(ERROR) << url << ' ' << r_link.error() << ' ' << to_string(expected);
        ASSERT_TRUE(r_link.is_ok());
      }
      auto new_result = td::LinkManager::parse_internal_link(r_link.ok());
      ASSERT_TRUE(new_result != nullptr);
      auto new_object = get_internal_link_type_object(new_result);

      auto new_object_str = to_string(new_object);
      auto expected_str = to_string(expected);
      if (expected->get_id() == td::td_api::internalLinkTypeBackground::ID) {
        for (auto &c : expected_str) {
          if (c == '~') {
            // getInternalLink always use '-'
            c = '-';
          }
        }
        if (new_object_str != expected_str && td::ends_with(expected_str, "\"\n}\n")) {
          // getInternalLink always adds rotation parameter, because default value differs between apps
          expected_str = expected_str.substr(0, expected_str.size() - 4) + "?rotation=0\"\n}\n";
        }
      }
      ASSERT_EQ(new_object_str, expected_str);

      r_link = td::LinkManager::get_internal_link(new_object, is_internal);
      ASSERT_TRUE(r_link.is_ok());
      new_result = td::LinkManager::parse_internal_link(r_link.ok());
      ASSERT_TRUE(new_result != nullptr);

      // the object must be the same after 2 round of conversion
      ASSERT_STREQ(to_string(new_object), to_string(get_internal_link_type_object(new_result)));
    }
  } else {
    LOG_IF(ERROR, expected != nullptr) << url;
    ASSERT_TRUE(expected == nullptr);
  }

  check_find_urls(url, result != nullptr);
}

static auto chat_administrator_rights(bool can_manage_chat, bool can_change_info, bool can_post_messages,
                                      bool can_edit_messages, bool can_delete_messages, bool can_invite_users,
                                      bool can_restrict_members, bool can_pin_messages, bool can_manage_topics,
                                      bool can_promote_members, bool can_manage_video_chats, bool can_post_stories,
                                      bool can_edit_stories, bool can_delete_stories, bool is_anonymous) {
  return td::td_api::make_object<td::td_api::chatAdministratorRights>(
      can_manage_chat, can_change_info, can_post_messages, can_edit_messages, can_delete_messages, can_invite_users,
      can_restrict_members, can_pin_messages, can_manage_topics, can_promote_members, can_manage_video_chats,
      can_post_stories, can_edit_stories, can_delete_stories, is_anonymous);
}

static auto target_chat_chosen(bool allow_users, bool allow_bots, bool allow_groups, bool allow_channels) {
  return td::td_api::make_object<td::td_api::targetChatChosen>(
      td::td_api::make_object<td::td_api::targetChatTypes>(allow_users, allow_bots, allow_groups, allow_channels));
}

static td::td_api::object_ptr<td::td_api::WebAppOpenMode> web_app_open_mode(bool is_compact, bool is_full_screen) {
  if (is_compact) {
    return td::td_api::make_object<td::td_api::webAppOpenModeCompact>();
  }
  if (is_full_screen) {
    return td::td_api::make_object<td::td_api::webAppOpenModeFullScreen>();
  }
  return td::td_api::make_object<td::td_api::webAppOpenModeFullSize>();
}

static auto active_sessions() {
  return td::td_api::make_object<td::td_api::internalLinkTypeActiveSessions>();
}

static auto attachment_menu_bot(td::td_api::object_ptr<td::td_api::targetChatChosen> chat_types,
                                td::td_api::object_ptr<td::td_api::InternalLinkType> chat_link,
                                const td::string &bot_username, const td::string &start_parameter) {
  td::td_api::object_ptr<td::td_api::TargetChat> target_chat;
  if (chat_link != nullptr) {
    target_chat = td::td_api::make_object<td::td_api::targetChatInternalLink>(std::move(chat_link));
  } else if (chat_types != nullptr) {
    target_chat = std::move(chat_types);
  } else {
    target_chat = td::td_api::make_object<td::td_api::targetChatCurrent>();
  }
  return td::td_api::make_object<td::td_api::internalLinkTypeAttachmentMenuBot>(
      std::move(target_chat), bot_username, start_parameter.empty() ? td::string() : "start://" + start_parameter);
}

static auto authentication_code(const td::string &code) {
  return td::td_api::make_object<td::td_api::internalLinkTypeAuthenticationCode>(code);
}

static auto background(const td::string &background_name) {
  return td::td_api::make_object<td::td_api::internalLinkTypeBackground>(background_name);
}

static auto bot_add_to_channel(const td::string &bot_username,
                               td::td_api::object_ptr<td::td_api::chatAdministratorRights> &&administrator_rights) {
  return td::td_api::make_object<td::td_api::internalLinkTypeBotAddToChannel>(bot_username,
                                                                              std::move(administrator_rights));
}

static auto bot_start(const td::string &bot_username, const td::string &start_parameter) {
  return td::td_api::make_object<td::td_api::internalLinkTypeBotStart>(bot_username, start_parameter, false);
}

static auto bot_start_in_group(const td::string &bot_username, const td::string &start_parameter,
                               td::td_api::object_ptr<td::td_api::chatAdministratorRights> &&administrator_rights) {
  return td::td_api::make_object<td::td_api::internalLinkTypeBotStartInGroup>(bot_username, start_parameter,
                                                                              std::move(administrator_rights));
}

static auto business_chat(const td::string &link_name) {
  return td::td_api::make_object<td::td_api::internalLinkTypeBusinessChat>(link_name);
}

static auto buy_stars(td::int64 star_count, const td::string &purpose) {
  return td::td_api::make_object<td::td_api::internalLinkTypeBuyStars>(star_count, purpose);
}

static auto change_phone_number() {
  return td::td_api::make_object<td::td_api::internalLinkTypeChangePhoneNumber>();
}

static auto chat_affiliate_program(const td::string &username, const td::string &referral) {
  return td::td_api::make_object<td::td_api::internalLinkTypeChatAffiliateProgram>(username, referral);
}

static auto chat_boost(const td::string &url) {
  return td::td_api::make_object<td::td_api::internalLinkTypeChatBoost>(url);
}

static auto chat_folder_invite(const td::string &slug) {
  return td::td_api::make_object<td::td_api::internalLinkTypeChatFolderInvite>("tg:addlist?slug=" + slug);
}

static auto chat_folder_settings() {
  return td::td_api::make_object<td::td_api::internalLinkTypeChatFolderSettings>();
}

static auto chat_invite(const td::string &hash) {
  return td::td_api::make_object<td::td_api::internalLinkTypeChatInvite>("tg:join?invite=" + hash);
}

static auto default_message_auto_delete_timer_settings() {
  return td::td_api::make_object<td::td_api::internalLinkTypeDefaultMessageAutoDeleteTimerSettings>();
}

static auto edit_profile_settings() {
  return td::td_api::make_object<td::td_api::internalLinkTypeEditProfileSettings>();
}

static auto game(const td::string &bot_username, const td::string &game_short_name) {
  return td::td_api::make_object<td::td_api::internalLinkTypeGame>(bot_username, game_short_name);
}

static auto instant_view(const td::string &url, const td::string &fallback_url) {
  return td::td_api::make_object<td::td_api::internalLinkTypeInstantView>(url, fallback_url);
}

static auto invoice(const td::string &invoice_name) {
  return td::td_api::make_object<td::td_api::internalLinkTypeInvoice>(invoice_name);
}

static auto language_pack(const td::string &language_pack_name) {
  return td::td_api::make_object<td::td_api::internalLinkTypeLanguagePack>(language_pack_name);
}

static auto language_settings() {
  return td::td_api::make_object<td::td_api::internalLinkTypeLanguageSettings>();
}

static auto main_web_app(const td::string &bot_username, const td::string &start_parameter, bool is_compact,
                         bool is_full_screen) {
  return td::td_api::make_object<td::td_api::internalLinkTypeMainWebApp>(bot_username, start_parameter,
                                                                         web_app_open_mode(is_compact, is_full_screen));
}

static auto message(const td::string &url) {
  return td::td_api::make_object<td::td_api::internalLinkTypeMessage>(url);
}

static auto message_draft(td::string text, bool contains_url) {
  auto formatted_text = td::td_api::make_object<td::td_api::formattedText>();
  formatted_text->text_ = std::move(text);
  return td::td_api::make_object<td::td_api::internalLinkTypeMessageDraft>(std::move(formatted_text), contains_url);
}

static auto passport_data_request(td::int32 bot_user_id, const td::string &scope, const td::string &public_key,
                                  const td::string &nonce, const td::string &callback_url) {
  return td::td_api::make_object<td::td_api::internalLinkTypePassportDataRequest>(bot_user_id, scope, public_key, nonce,
                                                                                  callback_url);
}

static auto phone_number_confirmation(const td::string &hash, const td::string &phone_number) {
  return td::td_api::make_object<td::td_api::internalLinkTypePhoneNumberConfirmation>(hash, phone_number);
}

static auto premium_features(const td::string &referrer) {
  return td::td_api::make_object<td::td_api::internalLinkTypePremiumFeatures>(referrer);
}

static auto premium_gift(const td::string &referrer) {
  return td::td_api::make_object<td::td_api::internalLinkTypePremiumGift>(referrer);
}

static auto premium_gift_code(const td::string &code) {
  return td::td_api::make_object<td::td_api::internalLinkTypePremiumGiftCode>(code);
}

static auto privacy_and_security_settings() {
  return td::td_api::make_object<td::td_api::internalLinkTypePrivacyAndSecuritySettings>();
}

static auto proxy_mtproto(const td::string &server, td::int32 port, const td::string &secret) {
  return td::td_api::make_object<td::td_api::internalLinkTypeProxy>(
      server, port, td::td_api::make_object<td::td_api::proxyTypeMtproto>(secret));
}

static auto proxy_socks(const td::string &server, td::int32 port, const td::string &username,
                        const td::string &password) {
  return td::td_api::make_object<td::td_api::internalLinkTypeProxy>(
      server, port, td::td_api::make_object<td::td_api::proxyTypeSocks5>(username, password));
}

static auto public_chat(const td::string &chat_username, const td::string &draft_text = td::string(),
                        bool open_profile = false) {
  return td::td_api::make_object<td::td_api::internalLinkTypePublicChat>(chat_username, draft_text, open_profile);
}

static auto qr_code_authentication() {
  return td::td_api::make_object<td::td_api::internalLinkTypeQrCodeAuthentication>();
}

static auto restore_purchases() {
  return td::td_api::make_object<td::td_api::internalLinkTypeRestorePurchases>();
}

static auto settings() {
  return td::td_api::make_object<td::td_api::internalLinkTypeSettings>();
}

static auto sticker_set(const td::string &sticker_set_name, bool expect_custom_emoji) {
  return td::td_api::make_object<td::td_api::internalLinkTypeStickerSet>(sticker_set_name, expect_custom_emoji);
}

static auto story(const td::string &sender_username, td::int32 story_id) {
  return td::td_api::make_object<td::td_api::internalLinkTypeStory>(sender_username, story_id);
}

static auto theme(const td::string &theme_name) {
  return td::td_api::make_object<td::td_api::internalLinkTypeTheme>(theme_name);
}

static auto theme_settings() {
  return td::td_api::make_object<td::td_api::internalLinkTypeThemeSettings>();
}

static auto unknown_deep_link(const td::string &link) {
  return td::td_api::make_object<td::td_api::internalLinkTypeUnknownDeepLink>(link);
}

static auto unsupported_proxy() {
  return td::td_api::make_object<td::td_api::internalLinkTypeUnsupportedProxy>();
}

static auto upgraded_gift(const td::string &name) {
  return td::td_api::make_object<td::td_api::internalLinkTypeUpgradedGift>(name);
}

static auto user_phone_number(const td::string &phone_number, const td::string &draft_text = td::string(),
                              bool open_profile = false) {
  return td::td_api::make_object<td::td_api::internalLinkTypeUserPhoneNumber>('+' + phone_number, draft_text,
                                                                              open_profile);
}

static auto user_token(const td::string &token) {
  return td::td_api::make_object<td::td_api::internalLinkTypeUserToken>(token);
}

static auto video_chat(const td::string &chat_username, const td::string &invite_hash, bool is_live_stream) {
  return td::td_api::make_object<td::td_api::internalLinkTypeVideoChat>(chat_username, invite_hash, is_live_stream);
}

static auto web_app(const td::string &bot_username, const td::string &web_app_short_name,
                    const td::string &start_parameter, bool is_compact, bool is_full_screen) {
  return td::td_api::make_object<td::td_api::internalLinkTypeWebApp>(bot_username, web_app_short_name, start_parameter,
                                                                     web_app_open_mode(is_compact, is_full_screen));
}

TEST(Link, parse_internal_link_part1) {
  parse_internal_link("t.me/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("telegram.me/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("telegram.dog/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("www.t.me/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("www%2etelegram.me/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("www%2Etelegram.dog/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("www%252Etelegram.dog/levlam/1", nullptr);
  parse_internal_link("www.t.me/s/s/s/s/s/joinchat/1", nullptr);
  parse_internal_link("www.t.me/s/s/s/s/s/joinchat/a", chat_invite("a"));
  parse_internal_link("www.t.me/s/%73/%73/s/%73/joinchat/a", chat_invite("a"));
  parse_internal_link("http://t.me/s/s/s/s/s/s/s/s/s/s/s/s/s/s/s/s/s/joinchat/a", chat_invite("a"));
  parse_internal_link("http://t.me/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("https://t.me/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("hTtp://www.t.me:443/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("httPs://t.me:80/levlam/1", message("tg://resolve?domain=levlam&post=1"));
  parse_internal_link("https://t.me:200/levlam/1", nullptr);
  parse_internal_link("http:t.me/levlam/1", nullptr);
  parse_internal_link("t.dog/levlam/1", nullptr);
  parse_internal_link("t.m/levlam/1", nullptr);
  parse_internal_link("t.men/levlam/1", nullptr);

  parse_internal_link("t.me/levlam?boos", public_chat("levlam"));
  parse_internal_link("telegram.me/levlam?booster", public_chat("levlam"));
  parse_internal_link("telegram.dog/levlam?boost", chat_boost("tg://boost?domain=levlam"));
  parse_internal_link("www.t.me/levlam?boost", chat_boost("tg://boost?domain=levlam"));
  parse_internal_link("t.me/c/l12345?boost", nullptr);
  parse_internal_link("t.me/c/12345l5431?boost", chat_boost("tg://boost?channel=12345"));
  parse_internal_link("t.me/c/12345?boost", chat_boost("tg://boost?channel=12345"));
  parse_internal_link("t.me/c/123456789012?boost", chat_boost("tg://boost?channel=123456789012"));
  parse_internal_link("t.me/c/123456789012?boost=12312&domain=123", chat_boost("tg://boost?channel=123456789012"));

  parse_internal_link("t.me/boost/s/12345", story("boost", 12345));
  parse_internal_link("t.me/boost/s", chat_boost("tg://boost?domain=s"));
  parse_internal_link("t.me/boost/12", message("tg://resolve?domain=boost&post=12"));
  parse_internal_link("t.me/boost?cc=1#c=1", public_chat("boost"));
  parse_internal_link("t.me/boost?c=-1", public_chat("boost"));
  parse_internal_link("t.me/boost?c=12telegram", chat_boost("tg://boost?channel=12"));
  parse_internal_link("t.me/bOoSt?c=12telegram", chat_boost("tg://boost?channel=12"));

  parse_internal_link("tg:boost?domain=username/12345&single", chat_boost("tg://boost?domain=username%2F12345"));
  parse_internal_link("tg:boost?domain=username&channel=12345", chat_boost("tg://boost?domain=username"));
  parse_internal_link("tg:boost?channel=12345&domain=username", chat_boost("tg://boost?domain=username"));
  parse_internal_link("tg:boost?channel=12345", chat_boost("tg://boost?channel=12345"));

  parse_internal_link("tg:resolve?domain=username&post=12345&single",
                      message("tg://resolve?domain=username&post=12345&single"));
  parse_internal_link("tg:resolve?domain=username&post=12345&single&startattach=1&attach=test",
                      message("tg://resolve?domain=username&post=12345&single"));
  parse_internal_link("tg:resolve?domain=user%31name&post=%312345&single&comment=456&t=789&single&thread=123%20%31",
                      message("tg://resolve?domain=user1name&post=12345&single&thread=123%201&comment=456&t=789"));
  parse_internal_link("TG://resolve?domain=username&post=12345&single&voicechat=aasd",
                      message("tg://resolve?domain=username&post=12345&single"));
  parse_internal_link("TG://test@resolve?domain=username&post=12345&single", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&post=12345&single", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&post=12345&single", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&post=12345&single", nullptr);
  parse_internal_link("tg:resolve?domain=&post=12345&single",
                      unknown_deep_link("tg://resolve?domain=&post=12345&single"));
  parse_internal_link("tg:resolve?domain=telegram&post=&single", public_chat("telegram"));
  parse_internal_link("tg:resolve?domain=123456&post=&single",
                      unknown_deep_link("tg://resolve?domain=123456&post=&single"));
  parse_internal_link("tg:resolve?domain=telegram&startattach", attachment_menu_bot(nullptr, nullptr, "telegram", ""));
  parse_internal_link("tg:resolve?domain=telegram&startattach=1",
                      attachment_menu_bot(nullptr, nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&startattach=1&choose=cats+dogs",
                      attachment_menu_bot(nullptr, nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&startattach=1&choose=users",
                      attachment_menu_bot(target_chat_chosen(true, false, false, false), nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&startattach=1&choose=bots",
                      attachment_menu_bot(target_chat_chosen(false, true, false, false), nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&startattach=1&choose=groups",
                      attachment_menu_bot(target_chat_chosen(false, false, true, false), nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&startattach=1&choose=channels",
                      attachment_menu_bot(target_chat_chosen(false, false, false, true), nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&startattach=1&choose=users+channels",
                      attachment_menu_bot(target_chat_chosen(true, false, false, true), nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&attach=&startattach",
                      attachment_menu_bot(nullptr, nullptr, "telegram", ""));
  parse_internal_link("tg:resolve?domain=telegram&attach=&startattach=1",
                      attachment_menu_bot(nullptr, nullptr, "telegram", "1"));
  parse_internal_link("tg:resolve?domain=telegram&attach=test&startattach",
                      attachment_menu_bot(nullptr, public_chat("telegram"), "test", ""));
  parse_internal_link("tg:resolve?domain=telegram&attach=test&startattach=1",
                      attachment_menu_bot(nullptr, public_chat("telegram"), "test", "1"));
  parse_internal_link("tg:resolve?domain=username&profile=12&asd", public_chat("username", "", true));
  parse_internal_link("tg:resolve?domain=username&profile&text=@asd", public_chat("username", " @asd", true));

  parse_internal_link("tg:resolve?phone=1", user_phone_number("1"));
  parse_internal_link("tg:resolve?phone=+1", user_phone_number("1"));
  parse_internal_link("tg:resolve?phone=123456", user_phone_number("123456"));
  parse_internal_link("tg:resolve?phone=123456&startattach", user_phone_number("123456"));
  parse_internal_link("tg:resolve?phone=123456&startattach=123", user_phone_number("123456"));
  parse_internal_link("tg:resolve?phone=123456&attach=", user_phone_number("123456"));
  parse_internal_link("tg:resolve?phone=123456&attach=&startattach", user_phone_number("123456"));
  parse_internal_link("tg:resolve?phone=123456&attach=&startattach=123", user_phone_number("123456"));
  parse_internal_link("tg:resolve?phone=123456&attach=test",
                      attachment_menu_bot(nullptr, user_phone_number("123456"), "test", ""));
  parse_internal_link("tg:resolve?phone=+123456&attach=test",
                      attachment_menu_bot(nullptr, user_phone_number("123456"), "test", ""));
  parse_internal_link("tg:resolve?phone=++123456&attach=test",
                      unknown_deep_link("tg://resolve?phone=++123456&attach=test"));
  parse_internal_link("tg:resolve?phone=123456&attach=test&startattach&choose=users",
                      attachment_menu_bot(nullptr, user_phone_number("123456"), "test", ""));
  parse_internal_link("tg:resolve?phone=123456&attach=test&startattach=123",
                      attachment_menu_bot(nullptr, user_phone_number("123456"), "test", "123"));
  parse_internal_link("tg:resolve?phone=01234567890123456789012345678912",
                      user_phone_number("01234567890123456789012345678912"));
  parse_internal_link("tg:resolve?phone=012345678901234567890123456789123",
                      unknown_deep_link("tg://resolve?phone=012345678901234567890123456789123"));
  parse_internal_link("tg:resolve?phone=", unknown_deep_link("tg://resolve?phone="));
  parse_internal_link("tg:resolve?phone=+123", user_phone_number("123"));
  parse_internal_link("tg:resolve?phone=123456 ", unknown_deep_link("tg://resolve?phone=123456 "));
  parse_internal_link("tg:resolve?domain=telegram&text=asd", public_chat("telegram", "asd"));
  parse_internal_link("tg:resolve?phone=12345678901&text=asd", user_phone_number("12345678901", "asd"));
  parse_internal_link("tg:resolve?domain=telegram&text=@asd", public_chat("telegram", " @asd"));
  parse_internal_link("tg:resolve?phone=12345678901&text=@asd", user_phone_number("12345678901", " @asd"));
  parse_internal_link("tg:resolve?domain=telegram&text=1%A02", public_chat("telegram"));
  parse_internal_link("tg:resolve?phone=12345678901&text=1%A02", user_phone_number("12345678901"));
  parse_internal_link("tg:resolve?phone=123456&profile", user_phone_number("123456", "", true));
  parse_internal_link("tg:resolve?phone=123456&profile&text=@asd", user_phone_number("123456", " @asd", true));

  parse_internal_link("tg:contact?token=1", user_token("1"));
  parse_internal_link("tg:contact?token=123456", user_token("123456"));
  parse_internal_link("tg:contact?token=123456&startattach", user_token("123456"));
  parse_internal_link("tg:contact?token=123456&startattach=123", user_token("123456"));
  parse_internal_link("tg:contact?token=123456&attach=", user_token("123456"));
  parse_internal_link("tg:contact?token=123456&attach=&startattach", user_token("123456"));
  parse_internal_link("tg:contact?token=123456&attach=&startattach=123", user_token("123456"));
  parse_internal_link("tg:contact?token=01234567890123456789012345678912",
                      user_token("01234567890123456789012345678912"));
  parse_internal_link("tg:contact?token=012345678901234567890123456789123",
                      user_token("012345678901234567890123456789123"));
  parse_internal_link("tg:contact?token=", unknown_deep_link("tg://contact?token="));
  parse_internal_link("tg:contact?token=+123", user_token(" 123"));

  parse_internal_link("tg:nft?slug=1", upgraded_gift("1"));
  parse_internal_link("tg:nft?slug=123456", upgraded_gift("123456"));
  parse_internal_link("tg:nft?slug=123456&startattach", upgraded_gift("123456"));
  parse_internal_link("tg:nft?slug=123456&startattach=123", upgraded_gift("123456"));
  parse_internal_link("tg:nft?slug=123456&attach=", upgraded_gift("123456"));
  parse_internal_link("tg:nft?slug=123456/789&attach=&startattach", upgraded_gift("123456/789"));
  parse_internal_link("tg:nft?slug=123456&attach=&startattach=123", upgraded_gift("123456"));
  parse_internal_link("tg:nft?slug=01234567890123456789012345678912",
                      upgraded_gift("01234567890123456789012345678912"));
  parse_internal_link("tg:nft?slug=012345678901234567890123456789123",
                      upgraded_gift("012345678901234567890123456789123"));
  parse_internal_link("tg:nft?slug=", unknown_deep_link("tg://nft?slug="));
  parse_internal_link("tg:nft?slug=+123", upgraded_gift(" 123"));

  parse_internal_link("t.me/username/12345?single", message("tg://resolve?domain=username&post=12345&single"));
  parse_internal_link("t.me/username/12345?asdasd", message("tg://resolve?domain=username&post=12345"));
  parse_internal_link("t.me/username/12345", message("tg://resolve?domain=username&post=12345"));
  parse_internal_link("t.me/username/12345/", message("tg://resolve?domain=username&post=12345"));
  parse_internal_link("t.me/username/12345#asdasd", message("tg://resolve?domain=username&post=12345"));
  parse_internal_link("t.me/username/12345//?voicechat=&single",
                      message("tg://resolve?domain=username&post=12345&single"));
  parse_internal_link("t.me/username/12345/asdasd//asd/asd/asd/?single",
                      message("tg://resolve?domain=username&post=12345&single"));
  parse_internal_link("t.me/username/12345/67890/asdasd//asd/asd/asd/?single",
                      message("tg://resolve?domain=username&post=67890&single&thread=12345"));
  parse_internal_link("t.me/username/1asdasdas/asdasd//asd/asd/asd/?single",
                      message("tg://resolve?domain=username&post=1&single"));
  parse_internal_link("t.me/username/0", public_chat("username"));
  parse_internal_link("t.me/username/-12345", public_chat("username"));
  parse_internal_link("t.me//12345?single", nullptr);
  parse_internal_link("https://telegram.dog/telegram/?single", public_chat("telegram"));
  parse_internal_link("t.me/username?startattach", attachment_menu_bot(nullptr, nullptr, "username", ""));
  parse_internal_link("t.me/username?startattach=1", attachment_menu_bot(nullptr, nullptr, "username", "1"));
  parse_internal_link("t.me/username?startattach=1&choose=cats+dogs",
                      attachment_menu_bot(nullptr, nullptr, "username", "1"));
  parse_internal_link("t.me/username?startattach=1&choose=users",
                      attachment_menu_bot(target_chat_chosen(true, false, false, false), nullptr, "username", "1"));
  parse_internal_link("t.me/username?startattach=1&choose=bots",
                      attachment_menu_bot(target_chat_chosen(false, true, false, false), nullptr, "username", "1"));
  parse_internal_link("t.me/username?startattach=1&choose=groups",
                      attachment_menu_bot(target_chat_chosen(false, false, true, false), nullptr, "username", "1"));
  parse_internal_link("t.me/username?startattach=1&choose=channels",
                      attachment_menu_bot(target_chat_chosen(false, false, false, true), nullptr, "username", "1"));
  parse_internal_link("t.me/username?startattach=1&choose=bots+groups",
                      attachment_menu_bot(target_chat_chosen(false, true, true, false), nullptr, "username", "1"));
  parse_internal_link("t.me/username?attach=", public_chat("username"));
  parse_internal_link("t.me/username?attach=&startattach", attachment_menu_bot(nullptr, nullptr, "username", ""));
  parse_internal_link("t.me/username?attach=&startattach=1", attachment_menu_bot(nullptr, nullptr, "username", "1"));
  parse_internal_link("t.me/username?attach=bot", attachment_menu_bot(nullptr, public_chat("username"), "bot", ""));
  parse_internal_link("t.me/username?attach=bot&startattach",
                      attachment_menu_bot(nullptr, public_chat("username"), "bot", ""));
  parse_internal_link("t.me/username?attach=bot&startattach=1&choose=users",
                      attachment_menu_bot(nullptr, public_chat("username"), "bot", "1"));
  parse_internal_link("t.me/username?asd&profile=12", public_chat("username", "", true));
  parse_internal_link("t.me/username?profile&text=@asd", public_chat("username", " @asd", true));

  parse_internal_link("tg:privatepost?domain=username/12345&single",
                      unknown_deep_link("tg://privatepost?domain=username/12345&single"));
  parse_internal_link("tg:privatepost?channel=username/12345&single",
                      unknown_deep_link("tg://privatepost?channel=username/12345&single"));
  parse_internal_link("tg:privatepost?channel=username&post=12345",
                      message("tg://privatepost?channel=username&post=12345"));

  parse_internal_link("t.me/c/12345?single", nullptr);
  parse_internal_link("t.me/c/1/c?single", nullptr);
  parse_internal_link("t.me/c/c/1?single", nullptr);
  parse_internal_link("t.me/c//1?single", nullptr);
  parse_internal_link("t.me/c/12345/123", message("tg://privatepost?channel=12345&post=123"));
  parse_internal_link("t.me/c/12345/123?single", message("tg://privatepost?channel=12345&post=123&single"));
  parse_internal_link("t.me/c/12345/123/asd/asd////?single", message("tg://privatepost?channel=12345&post=123&single"));
  parse_internal_link("t.me/c/12345/123/456/asd/asd////?single",
                      message("tg://privatepost?channel=12345&post=456&single&thread=123"));
  parse_internal_link("t.me/c/%312345/%3123?comment=456&t=789&single&thread=123%20%31",
                      message("tg://privatepost?channel=12345&post=123&single&thread=123%201&comment=456&t=789"));
  parse_internal_link("t.me/c/%312345/%3123?comment=456&t=2h3m101s&single&thread=123%20%31",
                      message("tg://privatepost?channel=12345&post=123&single&thread=123%201&comment=456&t=2h3m101s"));

  parse_internal_link("tg:bg?color=111111#asdasd", background("111111"));
  parse_internal_link("tg:bg?color=11111%31", background("111111"));
  parse_internal_link("tg:bg?color=11111%20", background("11111%20"));
  parse_internal_link("tg:bg?gradient=111111-222222", background("111111-222222"));
  parse_internal_link("tg:bg?rotation=180%20&gradient=111111-222222%20",
                      background("111111-222222%20?rotation=180%20"));
  parse_internal_link("tg:bg?gradient=111111~222222", background("111111~222222"));
  parse_internal_link("tg:bg?gradient=abacaba", background("abacaba"));
  parse_internal_link("tg:bg?slug=test#asdasd", background("test"));
  parse_internal_link("tg:bg?slug=test&mode=blur", background("test?mode=blur"));
  parse_internal_link("tg:bg?slug=test&mode=blur&text=1", background("test?mode=blur"));
  parse_internal_link("tg:bg?slug=test&mode=blur&mode=1", background("test?mode=blur"));
  parse_internal_link("tg:bg?slug=test&mode=blur&rotation=4&intensity=2&bg_color=3",
                      background("test?mode=blur&intensity=2&bg_color=3&rotation=4"));
  parse_internal_link("tg:bg?mode=blur&&slug=test&intensity=2&bg_color=3",
                      background("test?mode=blur&intensity=2&bg_color=3"));
  parse_internal_link("tg:bg?mode=blur&intensity=2&bg_color=3",
                      unknown_deep_link("tg://bg?mode=blur&intensity=2&bg_color=3"));

  parse_internal_link("tg:bg?color=111111#asdasd", background("111111"));
  parse_internal_link("tg:bg?color=11111%31", background("111111"));
  parse_internal_link("tg:bg?color=11111%20", background("11111%20"));
  parse_internal_link("tg:bg?gradient=111111-222222", background("111111-222222"));
  parse_internal_link("tg:bg?rotation=180%20&gradient=111111-222222%20",
                      background("111111-222222%20?rotation=180%20"));
  parse_internal_link("tg:bg?gradient=111111~222222&mode=blur", background("111111~222222"));
  parse_internal_link("tg:bg?gradient=abacaba", background("abacaba"));
  parse_internal_link("tg:bg?slug=test#asdasd", background("test"));
  parse_internal_link("tg:bg?slug=test&mode=blur", background("test?mode=blur"));
  parse_internal_link("tg:bg?slug=test&mode=blur&text=1", background("test?mode=blur"));
  parse_internal_link("tg:bg?slug=test&mode=blur&mode=1", background("test?mode=blur"));
  parse_internal_link("tg:bg?slug=test&mode=blur&rotation=4&intensity=2&bg_color=3",
                      background("test?mode=blur&intensity=2&bg_color=3&rotation=4"));
  parse_internal_link("tg:bg?mode=blur&&slug=test&intensity=2&bg_color=3",
                      background("test?mode=blur&intensity=2&bg_color=3"));
  parse_internal_link("tg:bg?mode=blur&intensity=2&bg_color=3",
                      unknown_deep_link("tg://bg?mode=blur&intensity=2&bg_color=3"));

  parse_internal_link("%54.me/bg/111111#asdasd", background("111111"));
  parse_internal_link("t.me/bg/11111%31", background("111111"));
  parse_internal_link("t.me/bg/11111%20", background("11111%20"));
  parse_internal_link("t.me/bg/111111-222222", background("111111-222222"));
  parse_internal_link("t.me/bg/111111-222222%20?rotation=180%20", background("111111-222222%20?rotation=180%20"));
  parse_internal_link("t.me/bg/111111~222222", background("111111~222222"));
  parse_internal_link("t.me/bg/abacaba", background("abacaba"));
  parse_internal_link("t.me/Bg/abacaba", web_app("Bg", "abacaba", "", false, false));
  parse_internal_link("t.me/bg/111111~222222#asdasd", background("111111~222222"));
  parse_internal_link("t.me/bg/111111~222222?mode=blur", background("111111~222222"));
  parse_internal_link("t.me/bg/111111~222222?mode=blur&text=1", background("111111~222222"));
  parse_internal_link("t.me/bg/111111~222222?mode=blur&mode=1", background("111111~222222"));
  parse_internal_link("t.me/bg/testteststststststststststststs?mode=blur&rotation=4&intensity=2&bg_color=3&mode=1",
                      background("testteststststststststststststs?mode=blur&intensity=2&bg_color=3&rotation=4"));
  parse_internal_link("t.me/%62g/testteststststststststststststs/?mode=blur+motion&&&intensity=2&bg_color=3",
                      background("testteststststststststststststs?mode=blur%20motion&intensity=2&bg_color=3"));
  parse_internal_link("t.me/bg//", nullptr);
  parse_internal_link("t.me/bg/%20/", background("%20"));
  parse_internal_link("t.me/bg/", nullptr);
}

TEST(Link, parse_internal_link_part2) {
  parse_internal_link("t.me/invoice?slug=abcdef", nullptr);
  parse_internal_link("t.me/invoice", nullptr);
  parse_internal_link("t.me/invoice/", nullptr);
  parse_internal_link("t.me/invoice//abcdef", nullptr);
  parse_internal_link("t.me/invoice?/abcdef", nullptr);
  parse_internal_link("t.me/invoice/?abcdef", nullptr);
  parse_internal_link("t.me/invoice/#abcdef", nullptr);
  parse_internal_link("t.me/invoice/abacaba", invoice("abacaba"));
  parse_internal_link("t.me/invoice/aba%20aba", invoice("aba aba"));
  parse_internal_link("t.me/invoice/123456a", invoice("123456a"));
  parse_internal_link("t.me/invoice/12345678901", invoice("12345678901"));
  parse_internal_link("t.me/invoice/123456", invoice("123456"));
  parse_internal_link("t.me/invoice/123456/123123/12/31/a/s//21w/?asdas#test", invoice("123456"));

  parse_internal_link("t.me/$?slug=abcdef", nullptr);
  parse_internal_link("t.me/$", nullptr);
  parse_internal_link("t.me/$/abcdef", nullptr);
  parse_internal_link("t.me/$?/abcdef", nullptr);
  parse_internal_link("t.me/$?abcdef", nullptr);
  parse_internal_link("t.me/$#abcdef", nullptr);
  parse_internal_link("t.me/$abacaba", invoice("abacaba"));
  parse_internal_link("t.me/$aba%20aba", invoice("aba aba"));
  parse_internal_link("t.me/$123456a", invoice("123456a"));
  parse_internal_link("t.me/$12345678901", invoice("12345678901"));
  parse_internal_link("t.me/$123456", invoice("123456"));
  parse_internal_link("t.me/%24123456", invoice("123456"));
  parse_internal_link("t.me/$123456/123123/12/31/a/s//21w/?asdas#test", invoice("123456"));

  parse_internal_link("tg:invoice?slug=abcdef", invoice("abcdef"));
  parse_internal_link("tg:invoice?slug=abc%30ef", invoice("abc0ef"));
  parse_internal_link("tg://invoice?slug=", unknown_deep_link("tg://invoice?slug="));

  parse_internal_link("t.me/giftcode?slug=abcdef", nullptr);
  parse_internal_link("t.me/giftcode", nullptr);
  parse_internal_link("t.me/giftcode/", nullptr);
  parse_internal_link("t.me/giftcode//abcdef", nullptr);
  parse_internal_link("t.me/giftcode?/abcdef", nullptr);
  parse_internal_link("t.me/giftcode/?abcdef", nullptr);
  parse_internal_link("t.me/giftcode/#abcdef", nullptr);
  parse_internal_link("t.me/giftcode/abacaba", premium_gift_code("abacaba"));
  parse_internal_link("t.me/giftcode/aba%20aba", premium_gift_code("aba aba"));
  parse_internal_link("t.me/giftcode/123456a", premium_gift_code("123456a"));
  parse_internal_link("t.me/giftcode/12345678901", premium_gift_code("12345678901"));
  parse_internal_link("t.me/giftcode/123456", premium_gift_code("123456"));
  parse_internal_link("t.me/giftcode/123456/123123/12/31/a/s//21w/?asdas#test", premium_gift_code("123456"));

  parse_internal_link("tg:giftcode?slug=abcdef", premium_gift_code("abcdef"));
  parse_internal_link("tg:giftcode?slug=abc%30ef", premium_gift_code("abc0ef"));
  parse_internal_link("tg://giftcode?slug=", unknown_deep_link("tg://giftcode?slug="));

  parse_internal_link("t.me/m?slug=abcdef", nullptr);
  parse_internal_link("t.me/m", nullptr);
  parse_internal_link("t.me/m/", nullptr);
  parse_internal_link("t.me/m//abcdef", nullptr);
  parse_internal_link("t.me/m?/abcdef", nullptr);
  parse_internal_link("t.me/m/?abcdef", nullptr);
  parse_internal_link("t.me/m/#abcdef", nullptr);
  parse_internal_link("t.me/m/abacaba", business_chat("abacaba"));
  parse_internal_link("t.me/m/aba%20aba", business_chat("aba aba"));
  parse_internal_link("t.me/m/123456a", business_chat("123456a"));
  parse_internal_link("t.me/m/12345678901", business_chat("12345678901"));
  parse_internal_link("t.me/m/123456", business_chat("123456"));
  parse_internal_link("t.me/m/123456/123123/12/31/a/s//21w/?asdas#test", business_chat("123456"));

  parse_internal_link("tg:message?slug=abcdef", business_chat("abcdef"));
  parse_internal_link("tg:message?slug=abc%30ef", business_chat("abc0ef"));
  parse_internal_link("tg://message?slug=", unknown_deep_link("tg://message?slug="));

  parse_internal_link("tg:share?url=google.com&text=text#asdasd", message_draft("google.com\ntext", true));
  parse_internal_link("tg:share?url=google.com&text=", message_draft("google.com", false));
  parse_internal_link("tg:share?url=&text=google.com", message_draft("google.com", false));
  parse_internal_link("tg:msg_url?url=google.com&text=text", message_draft("google.com\ntext", true));
  parse_internal_link("tg:msg_url?url=google.com&text=", message_draft("google.com", false));
  parse_internal_link("tg:msg_url?url=&text=google.com", message_draft("google.com", false));
  parse_internal_link("tg:msg?url=google.com&text=text", message_draft("google.com\ntext", true));
  parse_internal_link("tg:msg?url=google.com&text=", message_draft("google.com", false));
  parse_internal_link("tg:msg?url=&text=google.com", message_draft("google.com", false));
  parse_internal_link("tg:msg?url=&text=\n\n\n\n\n\n\n\n", nullptr);
  parse_internal_link("tg:msg?url=%20\n&text=", nullptr);
  parse_internal_link("tg:msg?url=%20\n&text=google.com", message_draft("google.com", false));
  parse_internal_link("tg:msg?url=@&text=", message_draft(" @", false));
  parse_internal_link("tg:msg?url=&text=@", message_draft(" @", false));
  parse_internal_link("tg:msg?url=@&text=@", message_draft(" @\n@", true));
  parse_internal_link("tg:msg?url=%FF&text=1", nullptr);

  parse_internal_link("https://t.me/share?url=google.com&text=text#asdasd", message_draft("google.com\ntext", true));
  parse_internal_link("https://t.me/share?url=google.com&text=", message_draft("google.com", false));
  parse_internal_link("https://t.me/share?url=&text=google.com", message_draft("google.com", false));
  parse_internal_link("https://t.me/msg?url=google.com&text=text", message_draft("google.com\ntext", true));
  parse_internal_link("https://t.me/msg?url=google.com&text=", message_draft("google.com", false));
  parse_internal_link("https://t.me/msg?url=&text=google.com", message_draft("google.com", false));
  parse_internal_link("https://t.me/msg?url=google.com&text=text", message_draft("google.com\ntext", true));
  parse_internal_link("https://t.me/msg?url=google.com&text=", message_draft("google.com", false));
  parse_internal_link("https://t.me/msg?url=&text=google.com", message_draft("google.com", false));
  parse_internal_link("https://t.me/msg?url=&text=\n\n\n\n\n\n\n\n", nullptr);
  parse_internal_link("https://t.me/msg?url=%20%0A&text=", nullptr);
  parse_internal_link("https://t.me/msg?url=%20%0A&text=google.com", message_draft("google.com", false));
  parse_internal_link("https://t.me/msg?url=@&text=", message_draft(" @", false));
  parse_internal_link("https://t.me/msg?url=&text=@", message_draft(" @", false));
  parse_internal_link("https://t.me/msg?url=@&text=@", message_draft(" @\n@", true));
  parse_internal_link("https://t.me/msg?url=%FF&text=1", nullptr);

  parse_internal_link("tg:login?codec=12345", unknown_deep_link("tg://login?codec=12345"));
  parse_internal_link("tg:login", unknown_deep_link("tg://login"));
  parse_internal_link("tg:login?code=abacaba", authentication_code("abacaba"));
  parse_internal_link("tg:login?code=123456", authentication_code("123456"));

  parse_internal_link("t.me/login?codec=12345", nullptr);
  parse_internal_link("t.me/login", nullptr);
  parse_internal_link("t.me/login/", nullptr);
  parse_internal_link("t.me/login//12345", nullptr);
  parse_internal_link("t.me/login?/12345", nullptr);
  parse_internal_link("t.me/login/?12345", nullptr);
  parse_internal_link("t.me/login/#12345", nullptr);
  parse_internal_link("t.me/login/abacaba", authentication_code("abacaba"));
  parse_internal_link("t.me/login/aba%20aba", authentication_code("aba aba"));
  parse_internal_link("t.me/login/123456a", authentication_code("123456a"));
  parse_internal_link("t.me/login/12345678901", authentication_code("12345678901"));
  parse_internal_link("t.me/login/123456", authentication_code("123456"));
  parse_internal_link("t.me/login/123456/123123/12/31/a/s//21w/?asdas#test", authentication_code("123456"));

  parse_internal_link("tg:login?token=abacaba", qr_code_authentication());
  parse_internal_link("tg:login?token=", unknown_deep_link("tg://login?token="));

  parse_internal_link("tg:restore_purchases?token=abacaba", restore_purchases());
  parse_internal_link("tg:restore_purchases?#", restore_purchases());
  parse_internal_link("tg:restore_purchases/?#", restore_purchases());
  parse_internal_link("tg:restore_purchases", restore_purchases());
  parse_internal_link("tg:restore_purchase", unknown_deep_link("tg://restore_purchase"));
  parse_internal_link("tg:restore_purchasess", unknown_deep_link("tg://restore_purchasess"));
  parse_internal_link("tg:restore_purchases/test?#", unknown_deep_link("tg://restore_purchases/test?"));

  parse_internal_link("t.me/joinchat?invite=abcdef", nullptr);
  parse_internal_link("t.me/joinchat", nullptr);
  parse_internal_link("t.me/joinchat/", nullptr);
  parse_internal_link("t.me/joinchat//abcdef", nullptr);
  parse_internal_link("t.me/joinchat?/abcdef", nullptr);
  parse_internal_link("t.me/joinchat/?abcdef", nullptr);
  parse_internal_link("t.me/joinchat/#abcdef", nullptr);
  parse_internal_link("t.me/joinchat/abacaba", chat_invite("abacaba"));
  parse_internal_link("t.me/joinchat/aba%20aba", nullptr);
  parse_internal_link("t.me/joinchat/aba%30aba", chat_invite("aba0aba"));
  parse_internal_link("t.me/joinchat/123456a", chat_invite("123456a"));
  parse_internal_link("t.me/joinchat/12345678901", nullptr);
  parse_internal_link("t.me/joinchat/123456", nullptr);
  parse_internal_link("t.me/joinchat/123456/123123/12/31/a/s//21w/?asdas#test", nullptr);
  parse_internal_link("t.me/joinchat/12345678901a", chat_invite("12345678901a"));
  parse_internal_link("t.me/joinchat/123456a", chat_invite("123456a"));
  parse_internal_link("t.me/joinchat/123456a/123123/12/31/a/s//21w/?asdas#test", chat_invite("123456a"));

  parse_internal_link("t.me/+?invite=abcdef", nullptr);
  parse_internal_link("t.me/+a", chat_invite("a"));
  parse_internal_link("t.me/+", nullptr);
  parse_internal_link("t.me/+/abcdef", nullptr);
  parse_internal_link("t.me/ ?/abcdef", nullptr);
  parse_internal_link("t.me/+?abcdef", nullptr);
  parse_internal_link("t.me/+#abcdef", nullptr);
  parse_internal_link("t.me/ abacaba", chat_invite("abacaba"));
  parse_internal_link("t.me/+aba%20aba", nullptr);
  parse_internal_link("t.me/+aba%30aba", chat_invite("aba0aba"));
  parse_internal_link("t.me/+123456a", chat_invite("123456a"));
  parse_internal_link("t.me/%2012345678901", user_phone_number("12345678901"));
  parse_internal_link("t.me/+123456", user_phone_number("123456"));
  parse_internal_link("t.me/ 123456/123123/12/31/a/s//21w/?asdas#test", user_phone_number("123456"));
  parse_internal_link("t.me/ /123456/123123/12/31/a/s//21w/?asdas#test", nullptr);
  parse_internal_link("t.me/+123456?startattach", user_phone_number("123456"));
  parse_internal_link("t.me/+123456?startattach=1", user_phone_number("123456"));
  parse_internal_link("t.me/+123456?attach=", user_phone_number("123456"));
  parse_internal_link("t.me/+123456?attach=&startattach", user_phone_number("123456"));
  parse_internal_link("t.me/+123456?attach=&startattach=1", user_phone_number("123456"));
  parse_internal_link("t.me/+123456?attach=bot", attachment_menu_bot(nullptr, user_phone_number("123456"), "bot", ""));
  parse_internal_link("t.me/+123456?attach=bot&startattach&profile",
                      attachment_menu_bot(nullptr, user_phone_number("123456"), "bot", ""));
  parse_internal_link("t.me/+123456?attach=bot&startattach=1",
                      attachment_menu_bot(nullptr, user_phone_number("123456"), "bot", "1"));
  parse_internal_link("t.me/+123456?profile", user_phone_number("123456", "", true));
  parse_internal_link("t.me/+123456?profile&text=@asd", user_phone_number("123456", " @asd", true));

  parse_internal_link("telegram.t.me?text=asd", public_chat("telegram", "asd"));
  parse_internal_link("t.me/%2012345678901?text=asd", user_phone_number("12345678901", "asd"));
  parse_internal_link("t.me/telegram?text=@asd", public_chat("telegram", " @asd"));
  parse_internal_link("t.me/%2012345678901?text=@asd", user_phone_number("12345678901", " @asd"));
  parse_internal_link("t.me/telegram?text=1%A02", public_chat("telegram"));
  parse_internal_link("t.me/%2012345678901?text=1%A02", user_phone_number("12345678901"));

  parse_internal_link("t.me/addlist?invite=abcdef", nullptr);
  parse_internal_link("t.me/addlist", nullptr);
  parse_internal_link("t.me/addlist/", nullptr);
  parse_internal_link("t.me/addlist//abcdef", nullptr);
  parse_internal_link("t.me/addlist?/abcdef", nullptr);
  parse_internal_link("t.me/addlist/?abcdef", nullptr);
  parse_internal_link("t.me/addlist/#abcdef", nullptr);
  parse_internal_link("t.me/addlist/abacaba", chat_folder_invite("abacaba"));
  parse_internal_link("t.me/addlist/aba%20aba", nullptr);
  parse_internal_link("t.me/addlist/aba%30aba", chat_folder_invite("aba0aba"));
  parse_internal_link("t.me/addlist/123456a", chat_folder_invite("123456a"));
  parse_internal_link("t.me/addlist/12345678901", chat_folder_invite("12345678901"));
  parse_internal_link("t.me/addlist/123456", chat_folder_invite("123456"));
  parse_internal_link("t.me/addlist/123456/123123/12/31/a/s//21w/?asdas#test", chat_folder_invite("123456"));
  parse_internal_link("t.me/addlist/12345678901a", chat_folder_invite("12345678901a"));
  parse_internal_link("t.me/addlist/123456a", chat_folder_invite("123456a"));
  parse_internal_link("t.me/addlist/123456a/123123/12/31/a/s//21w/?asdas#test", chat_folder_invite("123456a"));

  parse_internal_link("t.me/contact/startattach/adasd", user_token("startattach"));
  parse_internal_link("t.me/contact/startattach", user_token("startattach"));
  parse_internal_link("t.me/contact/startattach=1", user_token("startattach=1"));
  parse_internal_link("t.me/contact/", nullptr);
  parse_internal_link("t.me/contact/?attach=&startattach", nullptr);

  parse_internal_link("t.me/nft/startattach/adasd", upgraded_gift("startattach/adasd"));
  parse_internal_link("t.me/nft/startattach", upgraded_gift("startattach"));
  parse_internal_link("t.me/nft/startattach=1", upgraded_gift("startattach=1"));
  parse_internal_link("t.me/nft/", nullptr);
  parse_internal_link("t.me/nft/?attach=&startattach", nullptr);

  parse_internal_link("tg:join?invite=abcdef", chat_invite("abcdef"));
  parse_internal_link("tg:join?invite=abc%20def", unknown_deep_link("tg://join?invite=abc%20def"));
  parse_internal_link("tg://join?invite=abc%30def", chat_invite("abc0def"));
  parse_internal_link("tg:join?invite=", unknown_deep_link("tg://join?invite="));

  parse_internal_link("tg:addlist?slug=abcdef", chat_folder_invite("abcdef"));
  parse_internal_link("tg:addlist?slug=abc%20def", unknown_deep_link("tg://addlist?slug=abc%20def"));
  parse_internal_link("tg://addlist?slug=abc%30def", chat_folder_invite("abc0def"));
  parse_internal_link("tg:addlist?slug=", unknown_deep_link("tg://addlist?slug="));

  parse_internal_link("t.me/addstickers?set=abcdef", nullptr);
  parse_internal_link("t.me/addstickers", nullptr);
  parse_internal_link("t.me/addstickers/", nullptr);
  parse_internal_link("t.me/addstickers//abcdef", nullptr);
  parse_internal_link("t.me/addstickers?/abcdef", nullptr);
  parse_internal_link("t.me/addstickers/?abcdef", nullptr);
  parse_internal_link("t.me/addstickers/#abcdef", nullptr);
  parse_internal_link("t.me/addstickers/abacaba", sticker_set("abacaba", false));
  parse_internal_link("t.me/addstickers/aba%20aba", sticker_set("aba aba", false));
  parse_internal_link("t.me/addstickers/123456a", sticker_set("123456a", false));
  parse_internal_link("t.me/addstickers/12345678901", sticker_set("12345678901", false));
  parse_internal_link("t.me/addstickers/123456", sticker_set("123456", false));
  parse_internal_link("t.me/addstickers/123456/123123/12/31/a/s//21w/?asdas#test", sticker_set("123456", false));

  parse_internal_link("tg:addstickers?set=abcdef", sticker_set("abcdef", false));
  parse_internal_link("tg:addstickers?set=abc%30ef", sticker_set("abc0ef", false));
  parse_internal_link("tg://addstickers?set=", unknown_deep_link("tg://addstickers?set="));

  parse_internal_link("t.me/addemoji?set=abcdef", nullptr);
  parse_internal_link("t.me/addemoji", nullptr);
  parse_internal_link("t.me/addemoji/", nullptr);
  parse_internal_link("t.me/addemoji//abcdef", nullptr);
  parse_internal_link("t.me/addemoji?/abcdef", nullptr);
  parse_internal_link("t.me/addemoji/?abcdef", nullptr);
  parse_internal_link("t.me/addemoji/#abcdef", nullptr);
  parse_internal_link("t.me/addemoji/abacaba", sticker_set("abacaba", true));
  parse_internal_link("t.me/addemoji/aba%20aba", sticker_set("aba aba", true));
  parse_internal_link("t.me/addemoji/123456a", sticker_set("123456a", true));
  parse_internal_link("t.me/addemoji/12345678901", sticker_set("12345678901", true));
  parse_internal_link("t.me/addemoji/123456", sticker_set("123456", true));
  parse_internal_link("t.me/addemoji/123456/123123/12/31/a/s//21w/?asdas#test", sticker_set("123456", true));

  parse_internal_link("tg:addemoji?set=abcdef", sticker_set("abcdef", true));
  parse_internal_link("tg:addemoji?set=abc%30ef", sticker_set("abc0ef", true));
  parse_internal_link("tg://addemoji?set=", unknown_deep_link("tg://addemoji?set="));
}

TEST(Link, parse_internal_link_part3) {
  parse_internal_link("t.me/confirmphone?hash=abc%30ef&phone=", nullptr);
  parse_internal_link("t.me/confirmphone/123456/123123/12/31/a/s//21w/?hash=abc%30ef&phone=123456789",
                      phone_number_confirmation("abc0ef", "123456789"));
  parse_internal_link("t.me/confirmphone?hash=abc%30ef&phone=123456789",
                      phone_number_confirmation("abc0ef", "123456789"));

  parse_internal_link("tg:confirmphone?hash=abc%30ef&phone=",
                      unknown_deep_link("tg://confirmphone?hash=abc%30ef&phone="));
  parse_internal_link("tg:confirmphone?hash=abc%30ef&phone=123456789",
                      phone_number_confirmation("abc0ef", "123456789"));
  parse_internal_link("tg://confirmphone?hash=123&phone=123456789123456789",
                      phone_number_confirmation("123", "123456789123456789"));
  parse_internal_link("tg://confirmphone?hash=&phone=123456789123456789",
                      unknown_deep_link("tg://confirmphone?hash=&phone=123456789123456789"));
  parse_internal_link("tg://confirmphone?hash=123456789123456789&phone=",
                      unknown_deep_link("tg://confirmphone?hash=123456789123456789&phone="));

  parse_internal_link("t.me/setlanguage?lang=abcdef", nullptr);
  parse_internal_link("t.me/setlanguage", nullptr);
  parse_internal_link("t.me/setlanguage/", nullptr);
  parse_internal_link("t.me/setlanguage//abcdef", nullptr);
  parse_internal_link("t.me/setlanguage?/abcdef", nullptr);
  parse_internal_link("t.me/setlanguage/?abcdef", nullptr);
  parse_internal_link("t.me/setlanguage/#abcdef", nullptr);
  parse_internal_link("t.me/setlanguage/abacaba", language_pack("abacaba"));
  parse_internal_link("t.me/setlanguage/aba%20aba", language_pack("aba aba"));
  parse_internal_link("t.me/setlanguage/123456a", language_pack("123456a"));
  parse_internal_link("t.me/setlanguage/12345678901", language_pack("12345678901"));
  parse_internal_link("t.me/setlanguage/123456", language_pack("123456"));
  parse_internal_link("t.me/setlanguage/123456/123123/12/31/a/s//21w/?asdas#test", language_pack("123456"));

  parse_internal_link("tg:setlanguage?lang=abcdef", language_pack("abcdef"));
  parse_internal_link("tg:setlanguage?lang=abc%30ef", language_pack("abc0ef"));
  parse_internal_link("tg://setlanguage?lang=", unknown_deep_link("tg://setlanguage?lang="));

  parse_internal_link(
      "http://telegram.dog/iv?url=https://telegram.org&rhash=abcdef&test=1&tg_rhash=1",
      instant_view("https://t.me/iv?url=https%3A%2F%2Ftelegram.org&rhash=abcdef", "https://telegram.org"));
  parse_internal_link("t.me/iva?url=https://telegram.org&rhash=abcdef", public_chat("iva"));
  parse_internal_link("t.me/iv?url=&rhash=abcdef", nullptr);
  parse_internal_link("t.me/iv?url=https://telegram.org&rhash=",
                      instant_view("https://t.me/iv?url=https%3A%2F%2Ftelegram.org&rhash", "https://telegram.org"));
  parse_internal_link("t.me/iv//////?url=https://telegram.org&rhash=",
                      instant_view("https://t.me/iv?url=https%3A%2F%2Ftelegram.org&rhash", "https://telegram.org"));
  parse_internal_link("t.me/iv/////1/?url=https://telegram.org&rhash=", nullptr);
  parse_internal_link("t.me/iv", nullptr);
  parse_internal_link("t.me/iv?#url=https://telegram.org&rhash=abcdef", nullptr);
  parse_internal_link("tg:iv?url=https://telegram.org&rhash=abcdef",
                      unknown_deep_link("tg://iv?url=https://telegram.org&rhash=abcdef"));

  parse_internal_link("t.me/addtheme?slug=abcdef", nullptr);
  parse_internal_link("t.me/addtheme", nullptr);
  parse_internal_link("t.me/addtheme/", nullptr);
  parse_internal_link("t.me/addtheme//abcdef", nullptr);
  parse_internal_link("t.me/addtheme?/abcdef", nullptr);
  parse_internal_link("t.me/addtheme/?abcdef", nullptr);
  parse_internal_link("t.me/addtheme/#abcdef", nullptr);
  parse_internal_link("t.me/addtheme/abacaba", theme("abacaba"));
  parse_internal_link("t.me/addtheme/aba%20aba", theme("aba aba"));
  parse_internal_link("t.me/addtheme/123456a", theme("123456a"));
  parse_internal_link("t.me/addtheme/12345678901", theme("12345678901"));
  parse_internal_link("t.me/addtheme/123456", theme("123456"));
  parse_internal_link("t.me/addtheme/123456/123123/12/31/a/s//21w/?asdas#test", theme("123456"));

  parse_internal_link("tg:addtheme?slug=abcdef", theme("abcdef"));
  parse_internal_link("tg:addtheme?slug=abc%30ef", theme("abc0ef"));
  parse_internal_link("tg://addtheme?slug=", unknown_deep_link("tg://addtheme?slug="));

  parse_internal_link("t.me/proxy?server=1.2.3.4&port=80&secret=1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("1.2.3.4", 80, "1234567890abcdef1234567890abcdef"));
  parse_internal_link("t.me/proxy?server=1.2.3.4&port=80adasdas&secret=1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("1.2.3.4", 80, "1234567890abcdef1234567890abcdef"));
  parse_internal_link("t.me/proxy?server=1.2.3.4&port=adasdas&secret=1234567890abcdef1234567890ABCDEF",
                      unsupported_proxy());
  parse_internal_link("t.me/proxy?server=1.2.3.4&port=65536&secret=1234567890abcdef1234567890ABCDEF",
                      unsupported_proxy());
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=", unsupported_proxy());
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=12", unsupported_proxy());
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("google.com", 80, "1234567890abcdef1234567890abcdef"));
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=dd1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("google.com", 80, "dd1234567890abcdef1234567890abcdef"));
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=de1234567890abcdef1234567890ABCDEF",
                      unsupported_proxy());
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=ee1234567890abcdef1234567890ABCDEF",
                      unsupported_proxy());
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=ee1234567890abcdef1234567890ABCDEF0",
                      unsupported_proxy());
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=ee1234567890abcdef1234567890ABCDEF%30%30",
                      proxy_mtproto("google.com", 80, "7hI0VniQq83vEjRWeJCrze8A"));
  parse_internal_link(
      "t.me/proxy?server=google.com&port=8%30&secret=ee1234567890abcdef1234567890ABCDEF010101010101010101",
      proxy_mtproto("google.com", 80, "7hI0VniQq83vEjRWeJCrze8BAQEBAQEBAQE"));
  parse_internal_link("t.me/proxy?server=google.com&port=8%30&secret=7tAAAAAAAAAAAAAAAAAAAAAAAAcuZ29vZ2xlLmNvbQ",
                      proxy_mtproto("google.com", 80, "7tAAAAAAAAAAAAAAAAAAAAAAAAcuZ29vZ2xlLmNvbQ"));

  parse_internal_link("tg:proxy?server=1.2.3.4&port=80&secret=1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("1.2.3.4", 80, "1234567890abcdef1234567890abcdef"));
  parse_internal_link("tg:proxy?server=1.2.3.4&port=80adasdas&secret=1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("1.2.3.4", 80, "1234567890abcdef1234567890abcdef"));
  parse_internal_link("tg:proxy?server=1.2.3.4&port=adasdas&secret=1234567890abcdef1234567890ABCDEF",
                      unsupported_proxy());
  parse_internal_link("tg:proxy?server=1.2.3.4&port=65536&secret=1234567890abcdef1234567890ABCDEF",
                      unsupported_proxy());
  parse_internal_link("tg:proxy?server=google.com&port=8%30&secret=1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("google.com", 80, "1234567890abcdef1234567890abcdef"));
  parse_internal_link("tg:proxy?server=google.com&port=8%30&secret=dd1234567890abcdef1234567890ABCDEF",
                      proxy_mtproto("google.com", 80, "dd1234567890abcdef1234567890abcdef"));
  parse_internal_link("tg:proxy?server=google.com&port=8%30&secret=de1234567890abcdef1234567890ABCDEF",
                      unsupported_proxy());

  parse_internal_link("t.me/socks?server=1.2.3.4&port=80", proxy_socks("1.2.3.4", 80, "", ""));
  parse_internal_link("t.me/socks?server=1.2.3.4&port=80adasdas", proxy_socks("1.2.3.4", 80, "", ""));
  parse_internal_link("t.me/socks?server=1.2.3.4&port=adasdas", unsupported_proxy());
  parse_internal_link("t.me/socks?server=1.2.3.4&port=65536", unsupported_proxy());
  parse_internal_link("t.me/socks?server=google.com&port=8%30", proxy_socks("google.com", 80, "", ""));
  parse_internal_link("t.me/socks?server=google.com&port=8%30&user=1&pass=", proxy_socks("google.com", 80, "1", ""));
  parse_internal_link("t.me/socks?server=google.com&port=8%30&user=&pass=2", proxy_socks("google.com", 80, "", "2"));
  parse_internal_link("t.me/socks?server=google.com&port=80&user=1&pass=2", proxy_socks("google.com", 80, "1", "2"));

  parse_internal_link("tg:socks?server=1.2.3.4&port=80", proxy_socks("1.2.3.4", 80, "", ""));
  parse_internal_link("tg:socks?server=1.2.3.4&port=80adasdas", proxy_socks("1.2.3.4", 80, "", ""));
  parse_internal_link("tg:socks?server=1.2.3.4&port=adasdas", unsupported_proxy());
  parse_internal_link("tg:socks?server=1.2.3.4&port=65536", unsupported_proxy());
  parse_internal_link("tg:socks?server=google.com&port=8%30", proxy_socks("google.com", 80, "", ""));
  parse_internal_link("tg:socks?server=google.com&port=8%30&user=1&pass=", proxy_socks("google.com", 80, "1", ""));
  parse_internal_link("tg:socks?server=google.com&port=8%30&user=&pass=2", proxy_socks("google.com", 80, "", "2"));
  parse_internal_link("tg:socks?server=google.com&port=80&user=1&pass=2", proxy_socks("google.com", 80, "1", "2"));

  parse_internal_link("tg:resolve?domain=username&voice%63hat=aasdasd", video_chat("username", "aasdasd", false));
  parse_internal_link("tg:resolve?domain=username&video%63hat=aasdasd", video_chat("username", "aasdasd", false));
  parse_internal_link("tg:resolve?domain=username&livestream=aasdasd", video_chat("username", "aasdasd", true));
  parse_internal_link("TG://resolve?domain=username&voicechat=", video_chat("username", "", false));
  parse_internal_link("TG://test@resolve?domain=username&voicechat=", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&voicechat=", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&voicechat=", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&voicechat=", nullptr);
  parse_internal_link("tg:resolve?domain=&voicechat=", unknown_deep_link("tg://resolve?domain=&voicechat="));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&voicechat=%30", video_chat("telegram", "0", false));

  parse_internal_link("t.me/username/0/a//s/as?voicechat=", video_chat("username", "", false));
  parse_internal_link("t.me/username/0/a//s/as?videochat=2", video_chat("username", "2", false));
  parse_internal_link("t.me/username/0/a//s/as?livestream=3", video_chat("username", "3", true));
  parse_internal_link("t.me/username/aasdas/2?test=1&voicechat=#12312", video_chat("username", "", false));
  parse_internal_link("t.me/username/0?voicechat=", video_chat("username", "", false));
  parse_internal_link("t.me/username/-1?voicechat=asdasd", video_chat("username", "asdasd", false));
  parse_internal_link("t.me/username?voicechat=", video_chat("username", "", false));
  parse_internal_link("t.me/username#voicechat=asdas", public_chat("username"));
  parse_internal_link("t.me//username?voicechat=", nullptr);
  parse_internal_link("https://telegram.dog/tele%63ram?voi%63e%63hat=t%63st", video_chat("telecram", "tcst", false));

  parse_internal_link("tg:resolve?domain=username&start=aasdasd", bot_start("username", "aasdasd"));
  parse_internal_link("TG://resolve?domain=username&start=", bot_start("username", ""));
  parse_internal_link("TG://test@resolve?domain=username&start=", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&start=", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&start=", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&start=", nullptr);
  parse_internal_link("tg:resolve?domain=&start=", unknown_deep_link("tg://resolve?domain=&start="));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&start=%30", bot_start("telegram", "0"));

  parse_internal_link("t.me/username/0/a//s/as?start=", bot_start("username", ""));
  parse_internal_link("t.me/username/aasdas/2?test=1&start=#12312", bot_start("username", ""));
  parse_internal_link("t.me/username/0?start=", bot_start("username", ""));
  parse_internal_link("t.me/username/-1?start=asdasd", bot_start("username", "asdasd"));
  parse_internal_link("t.me/username?start=", bot_start("username", ""));
  parse_internal_link("t.me/username#start=asdas", public_chat("username"));
  parse_internal_link("t.me//username?start=", nullptr);
  parse_internal_link("https://telegram.dog/tele%63ram?start=t%63st", bot_start("telecram", "tcst"));

  parse_internal_link("tg:resolve?domain=username&start=_tgr_", bot_start("username", "_tgr_"));
  parse_internal_link("tg:resolve?domain=username&start=_tgr_aSd", chat_affiliate_program("username", "aSd"));
  parse_internal_link("tg:resolve?domain=username&start=_tgr_a%30Sd", chat_affiliate_program("username", "a0Sd"));

  parse_internal_link("t.me/username/0/a//s/as?start=_tgr_", bot_start("username", "_tgr_"));
  parse_internal_link("t.me/username/0/a//s/as?start=_tgr_aSd", chat_affiliate_program("username", "aSd"));
  parse_internal_link("t.me/username/0/a//s/as?start=_tgr_a%30Sd", chat_affiliate_program("username", "a0Sd"));

  parse_internal_link("tg:resolve?domain=username&ref=", public_chat("username"));
  parse_internal_link("tg:resolve?domain=username&ref=aSd", chat_affiliate_program("username", "aSd"));
  parse_internal_link("tg:resolve?domain=username&ref=a%30Sd", chat_affiliate_program("username", "a0Sd"));

  parse_internal_link("t.me/username/0/a//s/as?ref=", public_chat("username"));
  parse_internal_link("t.me/username/0/a//s/as?ref=aSd", chat_affiliate_program("username", "aSd"));
  parse_internal_link("t.me/username/0/a//s/as?ref=a%30Sd", chat_affiliate_program("username", "a0Sd"));

  parse_internal_link("tg:resolve?domain=username&startgroup=aasdasd",
                      bot_start_in_group("username", "aasdasd", nullptr));
  parse_internal_link("TG://resolve?domain=username&startgroup=", bot_start_in_group("username", "", nullptr));
  parse_internal_link("TG://test@resolve?domain=username&startgroup=", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&startgroup=", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&startgroup=", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&startgroup=", nullptr);
  parse_internal_link("tg:resolve?domain=&startgroup=", unknown_deep_link("tg://resolve?domain=&startgroup="));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&startgroup=%30", bot_start_in_group("telegram", "0", nullptr));

  parse_internal_link("tg:resolve?domain=username&startgroup", bot_start_in_group("username", "", nullptr));
  parse_internal_link("tg:resolve?domain=username&startgroup&admin=asdas", bot_start_in_group("username", "", nullptr));
  parse_internal_link("tg:resolve?domain=username&startgroup&admin=post_messages",
                      bot_start_in_group("username", "", nullptr));
  parse_internal_link("tg:resolve?domain=username&startgroup=1&admin=delete_messages+anonymous",
                      bot_start_in_group("username", "1",
                                         chat_administrator_rights(true, false, false, false, true, false, false, false,
                                                                   false, false, false, false, false, false, true)));
  parse_internal_link(
      "tg:resolve?domain=username&startgroup&admin=manage_chat+change_info+post_messages+edit_messages+delete_messages+"
      "invite_users+restrict_members+pin_messages+manage_topics+promote_members+manage_video_chats+post_stories+edit_"
      "stories+delete_stories+anonymous",
      bot_start_in_group("username", "",
                         chat_administrator_rights(true, true, false, false, true, true, true, true, true, true, true,
                                                   true, true, true, true)));

  parse_internal_link("tg:resolve?domain=username&startchannel", public_chat("username"));
  parse_internal_link("tg:resolve?domain=username&startchannel&admin=", public_chat("username"));
  parse_internal_link(
      "tg:resolve?domain=username&startchannel&admin=post_messages",
      bot_add_to_channel("username", chat_administrator_rights(true, false, true, false, false, false, true, false,
                                                               false, false, false, false, false, false, false)));
  parse_internal_link(
      "tg:resolve?domain=username&startchannel&admin=manage_chat+change_info+post_messages+edit_messages+delete_"
      "messages+invite_users+restrict_members+pin_messages+manage_topics+promote_members+manage_video_chats+anonymous",
      bot_add_to_channel("username", chat_administrator_rights(true, true, true, true, true, true, true, false, false,
                                                               true, true, false, false, false, false)));

  parse_internal_link("t.me/username/0/a//s/as?startgroup=", bot_start_in_group("username", "", nullptr));
  parse_internal_link("t.me/username/aasdas/2?test=1&startgroup=#12312", bot_start_in_group("username", "", nullptr));
  parse_internal_link("t.me/username/0?startgroup=", bot_start_in_group("username", "", nullptr));
  parse_internal_link("t.me/username/-1?startgroup=asdasd", bot_start_in_group("username", "asdasd", nullptr));
  parse_internal_link("t.me/username?startgroup=", bot_start_in_group("username", "", nullptr));
  parse_internal_link("t.me/username#startgroup=asdas", public_chat("username"));
  parse_internal_link("t.me//username?startgroup=", nullptr);
  parse_internal_link("https://telegram.dog/tele%63ram?startgroup=t%63st",
                      bot_start_in_group("telecram", "tcst", nullptr));

  parse_internal_link("t.me/username?startgroup", bot_start_in_group("username", "", nullptr));
  parse_internal_link("t.me/username?startgroup&admin=asdas", bot_start_in_group("username", "", nullptr));
  parse_internal_link("t.me/username?startgroup&admin=post_messages", bot_start_in_group("username", "", nullptr));
  parse_internal_link("t.me/username?startgroup=1&admin=delete_messages+anonymous",
                      bot_start_in_group("username", "1",
                                         chat_administrator_rights(true, false, false, false, true, false, false, false,
                                                                   false, false, false, false, false, false, true)));
  parse_internal_link(
      "t.me/"
      "username?startgroup&admin=manage_chat+change_info+post_messages+edit_messages+delete_messages+invite_users+"
      "restrict_members+pin_messages+manage_topics+promote_members+manage_video_chats+post_stories+edit_stories+delete_"
      "stories+anonymous",
      bot_start_in_group("username", "",
                         chat_administrator_rights(true, true, false, false, true, true, true, true, true, true, true,
                                                   true, true, true, true)));

  parse_internal_link("t.me/username?startchannel", public_chat("username"));
  parse_internal_link("t.me/username?startchannel&admin=", public_chat("username"));
  parse_internal_link(
      "t.me/username?startchannel&admin=post_messages",
      bot_add_to_channel("username", chat_administrator_rights(true, false, true, false, false, false, true, false,
                                                               false, false, false, false, false, false, false)));
  parse_internal_link(
      "t.me/"
      "username?startchannel&admin=manage_chat+change_info+post_messages+edit_messages+delete_messages+invite_users+"
      "restrict_members+pin_messages+manage_topics+promote_members+manage_video_chats+post_stories+edit_stories+delete_"
      "stories+anonymous",
      bot_add_to_channel("username", chat_administrator_rights(true, true, true, true, true, true, true, false, false,
                                                               true, true, true, true, true, false)));
}

TEST(Link, parse_internal_link_part4) {
  parse_internal_link("tg:resolve?domain=username&game=aasdasd", game("username", "aasdasd"));
  parse_internal_link("TG://resolve?domain=username&game=", public_chat("username"));
  parse_internal_link("TG://test@resolve?domain=username&game=asd", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&game=asd", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&game=asd", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&game=asd", nullptr);
  parse_internal_link("tg:resolve?domain=&game=asd", unknown_deep_link("tg://resolve?domain=&game=asd"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&game=%30", public_chat("telegram"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&game=%30ab", public_chat("telegram"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&game=ab%30", game("telegram", "ab0"));

  parse_internal_link("t.me/username/0/a//s/as?game=asd", game("username", "asd"));
  parse_internal_link("t.me/username/aasdas/2?test=1&game=asd#12312", game("username", "asd"));
  parse_internal_link("t.me/username/0?game=asd", game("username", "asd"));
  parse_internal_link("t.me/username/-1?game=asdasd", game("username", "asdasd"));
  parse_internal_link("t.me/username?game=asd", game("username", "asd"));
  parse_internal_link("t.me/username?game=", public_chat("username"));
  parse_internal_link("t.me/username#game=asdas", public_chat("username"));
  parse_internal_link("t.me//username?game=asd", nullptr);
  parse_internal_link("https://telegram.dog/tele%63ram?game=t%63st", game("telecram", "tcst"));

  parse_internal_link("tg:resolve?domain=username&story=123", story("username", 123));
  parse_internal_link("TG://resolve?domain=username&story=", public_chat("username"));
  parse_internal_link("TG://resolve?domain=username&story=0", public_chat("username"));
  parse_internal_link("TG://resolve?domain=username&story=-1", public_chat("username"));
  parse_internal_link("TG://test@resolve?domain=username&story=1", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&story=1", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&story=1", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&story=1", nullptr);
  parse_internal_link("tg:resolve?domain=&story=1", unknown_deep_link("tg://resolve?domain=&story=1"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&story=%30", public_chat("telegram"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&story=%31", story("telegram", 1));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&story=%31ab", public_chat("telegram"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&story=%31%39", story("telegram", 19));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&story=2222222222", public_chat("telegram"));

  parse_internal_link("t.me/username/s/1234", story("username", 1234));
  parse_internal_link("t.me/username/s/3?qwe=12312#12312", story("username", 3));
  parse_internal_link("t.me/username/s/1", story("username", 1));
  parse_internal_link("t.me/username/s/2", story("username", 2));
  parse_internal_link("t.me/username/s/5", story("username", 5));
  parse_internal_link("t.me/username/s/", public_chat("username"));
  parse_internal_link("t.me/username#/s/123", public_chat("username"));
  parse_internal_link("t.me/username?story=123", public_chat("username"));
  parse_internal_link("https://telegram.dog/tele%63ram/s/%31%39", story("telecram", 19));

  parse_internal_link("t.me/h", public_chat("h"));
  parse_internal_link("t.me/h/hh", public_chat("h"));
  parse_internal_link("t.me/i", nullptr);
  parse_internal_link("t.me/i/ii", nullptr);
  parse_internal_link("t.me/j", public_chat("j"));
  parse_internal_link("t.me/j/jj", public_chat("j"));

  parse_internal_link("tg:resolve?domain=username&appname=aasdasd&startapp=123asd",
                      web_app("username", "aasdasd", "123asd", false, false));
  parse_internal_link("TG://resolve?domain=username&appname=&startapp=123asd", public_chat("username"));
  parse_internal_link("TG://test@resolve?domain=username&appname=asd", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&appname=asd", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&appname=asd", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&appname=asd", nullptr);
  parse_internal_link("tg:resolve?domain=&appname=asd", unknown_deep_link("tg://resolve?domain=&appname=asd"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&appname=%41&startapp=", public_chat("telegram"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&appname=%41b&startapp=", public_chat("telegram"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&appname=%41bc&startapp=",
                      web_app("telegram", "Abc", "", false, false));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&appname=%41bc&startapp=&mode=compact",
                      web_app("telegram", "Abc", "", true, false));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&appname=%41bc&startapp=&mode=fullscreen",
                      web_app("telegram", "Abc", "", false, true));

  parse_internal_link("t.me/username/0/a//s/as?appname=asd", public_chat("username"));
  parse_internal_link("t.me/username/aasdas/2?test=1&appname=asd#12312", public_chat("username"));
  parse_internal_link("t.me/username/0?appname=asd", public_chat("username"));
  parse_internal_link("t.me/username/-1?appname=asdasd", public_chat("username"));
  parse_internal_link("t.me/username?appname=asd", public_chat("username"));
  parse_internal_link("t.me/username?appname=", public_chat("username"));
  parse_internal_link("t.me/username#appname=asdas", public_chat("username"));
  parse_internal_link("t.me//username?appname=asd", nullptr);
  parse_internal_link("https://telegram.dog/tele%63ram?appname=t%63st", public_chat("telecram"));
  parse_internal_link("t.me/username/def/asd", public_chat("username"));
  parse_internal_link("t.me/username/asd#12312&startapp=qwe", web_app("username", "asd", "", false, false));
  parse_internal_link("t.me/username/asd?12312&startapp=qwe&mode=compac",
                      web_app("username", "asd", "qwe", false, false));
  parse_internal_link("t.me/username/asd?12312&startapp=qwe&mode=compact",
                      web_app("username", "asd", "qwe", true, false));
  parse_internal_link("t.me/username/asd?12312&startapp=qwe&mode=fullscreen",
                      web_app("username", "asd", "qwe", false, true));
  parse_internal_link("t.me/username/asdasd?startapp=0", web_app("username", "asdasd", "0", false, false));
  parse_internal_link("t.me/username/asd", web_app("username", "asd", "", false, false));
  parse_internal_link("t.me/username/", public_chat("username"));
  parse_internal_link("https://telegram.dog/tele%63ram/t%63st", web_app("telecram", "tcst", "", false, false));
  parse_internal_link("https://telegram.dog/tele%63ram/t%63st?mode=compact",
                      web_app("telecram", "tcst", "", true, false));
  parse_internal_link("https://telegram.dog/tele%63ram/t%63st?mode=fullscreen",
                      web_app("telecram", "tcst", "", false, true));

  parse_internal_link("tg:resolve?domain=username&startapp=aasdasd", main_web_app("username", "aasdasd", false, false));
  parse_internal_link("TG://resolve?domain=username&startapp=&startapp=123asd",
                      main_web_app("username", "", false, false));
  parse_internal_link("TG://test@resolve?domain=username&startapp=asd", nullptr);
  parse_internal_link("tg:resolve:80?domain=username&startapp=asd", nullptr);
  parse_internal_link("tg:http://resolve?domain=username&startapp=asd", nullptr);
  parse_internal_link("tg:https://resolve?domain=username&startapp=asd", nullptr);
  parse_internal_link("tg:resolve?domain=&startapp=asd", unknown_deep_link("tg://resolve?domain=&startapp=asd"));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&startapp=%41", main_web_app("telegram", "A", false, false));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&startapp=%41b", main_web_app("telegram", "Ab", false, false));
  parse_internal_link("tg:resolve?domain=telegram&&&&&&&startapp=%41bc", main_web_app("telegram", "Abc", false, false));
  parse_internal_link("tg:resolve?domain=telegram&&mode=compact&&&&&&startapp=%41bc",
                      main_web_app("telegram", "Abc", true, false));
  parse_internal_link("tg:resolve?domain=telegram&&mode=fullscreen&&&&&&startapp=%41bc",
                      main_web_app("telegram", "Abc", false, true));

  parse_internal_link("t.me/username?startapp=qwe", main_web_app("username", "qwe", false, false));
  parse_internal_link("t.me/username?12312&startapp=qwe", main_web_app("username", "qwe", false, false));
  parse_internal_link("t.me/username?startapp=0", main_web_app("username", "0", false, false));
  parse_internal_link("https://telegram.dog/tele%63ram?startapp=t%63st",
                      main_web_app("telecram", "tcst", false, false));
  parse_internal_link("https://telegram.dog/tele%63ram?startapp=t%63st&mode=%63ompact",
                      main_web_app("telecram", "tcst", true, false));
  parse_internal_link("https://telegram.dog/tele%63ram?startapp=t%63st&mode=%66ullscreen",
                      main_web_app("telecram", "tcst", false, true));
  parse_internal_link("https://telegram.dog?startapp=t%63st", nullptr);

  parse_internal_link("tg:resolve?domain=username&Game=asd", public_chat("username"));
  parse_internal_link("TG://test@resolve?domain=username", nullptr);
  parse_internal_link("tg:resolve:80?domain=username", nullptr);
  parse_internal_link("tg:http://resolve?domain=username", nullptr);
  parse_internal_link("tg:https://resolve?domain=username", nullptr);
  parse_internal_link("tg:resolve?domain=", unknown_deep_link("tg://resolve?domain="));
  parse_internal_link("tg:resolve?&&&&&&&domain=telegram", public_chat("telegram"));

  parse_internal_link("t.me/a", public_chat("a"));
  parse_internal_link("t.me/abcdefghijklmnopqrstuvwxyz123456", public_chat("abcdefghijklmnopqrstuvwxyz123456"));
  parse_internal_link("t.me/abcdefghijklmnopqrstuvwxyz1234567", nullptr);
  parse_internal_link("t.me/abcdefghijklmnop-qrstuvwxyz", nullptr);
  parse_internal_link("t.me/abcdefghijklmnop~qrstuvwxyz", nullptr);
  parse_internal_link("t.me/_asdf", nullptr);
  parse_internal_link("t.me/0asdf", nullptr);
  parse_internal_link("t.me/9asdf", nullptr);
  parse_internal_link("t.me/Aasdf", public_chat("Aasdf"));
  parse_internal_link("t.me/asdf_", nullptr);
  parse_internal_link("t.me/asdf0", public_chat("asdf0"));
  parse_internal_link("t.me/asd__fg", nullptr);
  parse_internal_link("t.me/username/0/a//s/as?gam=asd", public_chat("username"));
  parse_internal_link("t.me/username/aasdas/2?test=1", public_chat("username"));
  parse_internal_link("t.me/username/0", public_chat("username"));
  parse_internal_link("t.me//username", nullptr);
  parse_internal_link("https://telegram.dog/tele%63ram", public_chat("telecram"));

  parse_internal_link(
      "tg://"
      "resolve?domain=telegrampassport&bot_id=543260180&scope=%7B%22v%22%3A1%2C%22d%22%3A%5B%7B%22%22%5D%7D%5D%7D&"
      "public_key=BEGIN%20PUBLIC%20KEY%0A&nonce=b8ee&callback_url=https%3A%2F%2Fcore.telegram.org%2Fpassport%2Fexample%"
      "3Fpassport_ssid%3Db8ee&payload=nonce",
      passport_data_request(543260180, "{\"v\":1,\"d\":[{\"\"]}]}", "BEGIN PUBLIC KEY\n", "b8ee",
                            "https://core.telegram.org/passport/example?passport_ssid=b8ee"));
  parse_internal_link("tg://resolve?domain=telegrampassport&bot_id=12345&public_key=key&scope=asd&payload=nonce",
                      passport_data_request(12345, "asd", "key", "nonce", ""));
  parse_internal_link("tg://passport?bot_id=12345&public_key=key&scope=asd&payload=nonce",
                      passport_data_request(12345, "asd", "key", "nonce", ""));
  parse_internal_link("tg://passport?bot_id=0&public_key=key&scope=asd&payload=nonce",
                      unknown_deep_link("tg://passport?bot_id=0&public_key=key&scope=asd&payload=nonce"));
  parse_internal_link("tg://passport?bot_id=-1&public_key=key&scope=asd&payload=nonce",
                      unknown_deep_link("tg://passport?bot_id=-1&public_key=key&scope=asd&payload=nonce"));
  parse_internal_link("tg://passport?bot_id=12345&public_key=&scope=asd&payload=nonce",
                      unknown_deep_link("tg://passport?bot_id=12345&public_key=&scope=asd&payload=nonce"));
  parse_internal_link("tg://passport?bot_id=12345&public_key=key&scope=&payload=nonce",
                      unknown_deep_link("tg://passport?bot_id=12345&public_key=key&scope=&payload=nonce"));
  parse_internal_link("tg://passport?bot_id=12345&public_key=key&scope=asd&payload=",
                      unknown_deep_link("tg://passport?bot_id=12345&public_key=key&scope=asd&payload="));
  parse_internal_link("t.me/telegrampassport?bot_id=12345&public_key=key&scope=asd&payload=nonce",
                      public_chat("telegrampassport"));

  parse_internal_link("tg:premium_offer?ref=abcdef", premium_features("abcdef"));
  parse_internal_link("tg:premium_offer?ref=abc%30ef", premium_features("abc0ef"));
  parse_internal_link("tg://premium_offer?ref=", premium_features(""));

  parse_internal_link("tg:premium_multigift?ref=abcdef", premium_gift("abcdef"));
  parse_internal_link("tg:premium_multigift?ref=abc%30ef", premium_gift("abc0ef"));
  parse_internal_link("tg://premium_multigift?ref=", premium_gift(""));

  parse_internal_link("tg://settings", settings());
  parse_internal_link("tg://setting", unknown_deep_link("tg://setting"));
  parse_internal_link("tg://settings?asdsa?D?SADasD?asD", settings());
  parse_internal_link("tg://settings#test", settings());
  parse_internal_link("tg://settings/#test", settings());
  parse_internal_link("tg://settings/aadsa#test", settings());
  parse_internal_link("tg://settings/theme#test", settings());
  parse_internal_link("tg://settings/themes#test", theme_settings());
  parse_internal_link("tg://settings/themesa#test", settings());
  parse_internal_link("tg://settings/themes/?as#rad", theme_settings());
  parse_internal_link("tg://settings/themes/a", settings());
  parse_internal_link("tg://settings/asdsathemesasdas/devices", settings());
  parse_internal_link("tg://settings/auto_delete", default_message_auto_delete_timer_settings());
  parse_internal_link("tg://settings/devices", active_sessions());
  parse_internal_link("tg://settings/change_number", change_phone_number());
  parse_internal_link("tg://settings/edit_profile", edit_profile_settings());
  parse_internal_link("tg://settings/folders", chat_folder_settings());
  parse_internal_link("tg://settings/filters", settings());
  parse_internal_link("tg://settings/language", language_settings());
  parse_internal_link("tg://settings/privacy", privacy_and_security_settings());

  parse_internal_link("tg://stars_topup", unknown_deep_link("tg://stars_topup"));
  parse_internal_link("tg://stars_topup?balance=", unknown_deep_link("tg://stars_topup?balance="));
  parse_internal_link("tg://stars_topup?balance=test", buy_stars(1, ""));
  parse_internal_link("tg://stars_topup?balance=10&purpose=%30test", buy_stars(10, "0test"));
  parse_internal_link("tg://stars_topup?balance=100000000000&purpose=subs", buy_stars(100000000000, "subs"));

  parse_internal_link("username.t.me////0/a//s/as?start=", bot_start("username", ""));
  parse_internal_link("username.t.me?start=as", bot_start("username", "as"));
  parse_internal_link("username.t.me", public_chat("username"));
  parse_internal_link("aAAb.t.me/12345?single", message("tg://resolve?domain=aaab&post=12345&single"));
  parse_internal_link("telegram.t.me/195", message("tg://resolve?domain=telegram&post=195"));
  parse_internal_link("shares.t.me", public_chat("shares"));

  parse_internal_link("c.t.me/12345?single", nullptr);
  parse_internal_link("aaa.t.me/12345?single", nullptr);
  parse_internal_link("aaa_.t.me/12345?single", nullptr);
  parse_internal_link("0aaa.t.me/12345?single", nullptr);
  parse_internal_link("_aaa.t.me/12345?single", nullptr);
  parse_internal_link("a.t.me", nullptr);
  parse_internal_link("b.t.me", nullptr);
  parse_internal_link("k.t.me", nullptr);
  parse_internal_link("z.t.me", nullptr);
  parse_internal_link("web.t.me", nullptr);
  parse_internal_link("addemoji.t.me", nullptr);
  parse_internal_link("addlist.t.me", nullptr);
  parse_internal_link("addstickers.t.me", nullptr);
  parse_internal_link("addtheme.t.me", nullptr);
  parse_internal_link("auth.t.me", nullptr);
  parse_internal_link("boost.t.me", nullptr);
  parse_internal_link("confirmphone.t.me", nullptr);
  parse_internal_link("contact.t.me", nullptr);
  parse_internal_link("giftcode.t.me", nullptr);
  parse_internal_link("invoice.t.me", nullptr);
  parse_internal_link("joinchat.t.me", nullptr);
  parse_internal_link("login.t.me", nullptr);
  parse_internal_link("m.t.me", nullptr);
  parse_internal_link("nft.t.me", nullptr);
  parse_internal_link("proxy.t.me", nullptr);
  parse_internal_link("setlanguage.t.me", nullptr);
  parse_internal_link("share.t.me", nullptr);
  parse_internal_link("socks.t.me", nullptr);

  parse_internal_link("www.telegra.ph/", nullptr);
  parse_internal_link("www.telegrA.ph/#", nullptr);
  parse_internal_link("www.telegrA.ph/?", instant_view("https://telegra.ph/?", "www.telegrA.ph/?"));
  parse_internal_link("http://te.leGra.ph/?", instant_view("https://telegra.ph/?", "http://te.leGra.ph/?"));
  parse_internal_link("https://grAph.org/12345", instant_view("https://telegra.ph/12345", "https://grAph.org/12345"));
}
