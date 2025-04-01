//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DialogBoostLinkInfo.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageLinkInfo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

class Proxy;
class Td;

class LinkManager final : public Actor {
 public:
  LinkManager(Td *td, ActorShared<> parent);

  LinkManager(const LinkManager &) = delete;
  LinkManager &operator=(const LinkManager &) = delete;
  LinkManager(LinkManager &&) = delete;
  LinkManager &operator=(LinkManager &&) = delete;
  ~LinkManager() final;

  class InternalLink {
   public:
    InternalLink() = default;
    InternalLink(const InternalLink &) = delete;
    InternalLink &operator=(const InternalLink &) = delete;
    InternalLink(InternalLink &&) = delete;
    InternalLink &operator=(InternalLink &&) = delete;
    virtual ~InternalLink() = default;

    virtual td_api::object_ptr<td_api::InternalLinkType> get_internal_link_type_object() const = 0;
  };

  // checks whether the link is a valid tg, ton or HTTP(S) URL and returns it in a canonical form
  static Result<string> check_link(CSlice link, bool http_only = false, bool https_only = false);

  // same as check_link, but returns an empty string instead of an error
  static string get_checked_link(Slice link, bool http_only = false, bool https_only = false);

  // returns whether a link is an internal link, supported or not
  static bool is_internal_link(Slice link);

  // checks whether the link is a supported tg or t.me link and parses it
  static unique_ptr<InternalLink> parse_internal_link(Slice link, bool is_trusted = false);

  static Result<string> get_internal_link(const td_api::object_ptr<td_api::InternalLinkType> &type, bool is_internal);

  void update_autologin_token(string autologin_token);

  void update_autologin_domains(vector<string> autologin_domains, vector<string> url_auth_domains,
                                vector<string> whitelisted_domains);

  void get_recent_me_urls(const string &referrer, Promise<td_api::object_ptr<td_api::tMeUrls>> &&promise);

  void get_deep_link_info(Slice link, Promise<td_api::object_ptr<td_api::deepLinkInfo>> &&promise);

  void get_external_link_info(string &&link, Promise<td_api::object_ptr<td_api::LoginUrlInfo>> &&promise);

  void get_login_url_info(MessageFullId message_full_id, int64 button_id,
                          Promise<td_api::object_ptr<td_api::LoginUrlInfo>> &&promise);

  void get_login_url(MessageFullId message_full_id, int64 button_id, bool allow_write_access,
                     Promise<td_api::object_ptr<td_api::httpUrl>> &&promise);

  void get_link_login_url(const string &url, bool allow_write_access,
                          Promise<td_api::object_ptr<td_api::httpUrl>> &&promise);

  static Result<string> get_background_url(const string &name,
                                           td_api::object_ptr<td_api::BackgroundType> background_type);

  static td_api::object_ptr<td_api::BackgroundType> get_background_type_object(const string &link, bool is_pattern);

  static string get_dialog_filter_invite_link_slug(Slice invite_link);

  static string get_dialog_filter_invite_link(Slice slug, bool is_internal);

  static string get_dialog_invite_link_hash(Slice invite_link);

  static string get_dialog_invite_link(Slice invite_hash, bool is_internal);

  static string get_instant_view_link_url(Slice link);

  static string get_instant_view_link_rhash(Slice link);

  static string get_instant_view_link(Slice url, Slice rhash);

  static string get_public_dialog_link(Slice username, Slice draft_text, bool open_profile, bool is_internal);

  static Result<string> get_proxy_link(const Proxy &proxy, bool is_internal);

  static UserId get_link_user_id(Slice url);

  static string get_t_me_url();

  static Result<CustomEmojiId> get_link_custom_emoji_id(Slice url);

  static Result<DialogBoostLinkInfo> get_dialog_boost_link_info(Slice url);

  static Result<MessageLinkInfo> get_message_link_info(Slice url);

 private:
  void start_up() final;

  void tear_down() final;

  class InternalLinkActiveSessions;
  class InternalLinkAttachMenuBot;
  class InternalLinkAuthenticationCode;
  class InternalLinkBackground;
  class InternalLinkBotAddToChannel;
  class InternalLinkBotStart;
  class InternalLinkBotStartInGroup;
  class InternalLinkBusinessChat;
  class InternalLinkBuyStars;
  class InternalLinkChangePhoneNumber;
  class InternalLinkConfirmPhone;
  class InternalLinkDefaultMessageAutoDeleteTimerSettings;
  class InternalLinkDialogBoost;
  class InternalLinkDialogFolderInvite;
  class InternalLinkDialogFolderSettings;
  class InternalLinkDialogInvite;
  class InternalLinkDialogReferralProgram;
  class InternalLinkEditProfileSettings;
  class InternalLinkGame;
  class InternalLinkInstantView;
  class InternalLinkInvoice;
  class InternalLinkLanguage;
  class InternalLinkLanguageSettings;
  class InternalLinkMainWebApp;
  class InternalLinkMessage;
  class InternalLinkMessageDraft;
  class InternalLinkPassportDataRequest;
  class InternalLinkPremiumFeatures;
  class InternalLinkPremiumGift;
  class InternalLinkPremiumGiftCode;
  class InternalLinkPrivacyAndSecuritySettings;
  class InternalLinkProxy;
  class InternalLinkPublicDialog;
  class InternalLinkQrCodeAuthentication;
  class InternalLinkRestorePurchases;
  class InternalLinkSettings;
  class InternalLinkStickerSet;
  class InternalLinkStory;
  class InternalLinkTheme;
  class InternalLinkThemeSettings;
  class InternalLinkUnknownDeepLink;
  class InternalLinkUnsupportedProxy;
  class InternalLinkUpgradedGift;
  class InternalLinkUserPhoneNumber;
  class InternalLinkUserToken;
  class InternalLinkVoiceChat;
  class InternalLinkWebApp;

  enum class LinkType : int32 { External, TMe, Tg, Telegraph };

  struct LinkInfo {
    LinkType type_ = LinkType::External;
    string query_;
  };
  // returns information about the link
  static LinkInfo get_link_info(Slice link);

  static unique_ptr<InternalLink> parse_tg_link_query(Slice query, bool is_trusted);

  static unique_ptr<InternalLink> parse_t_me_link_query(Slice query, bool is_trusted);

  static unique_ptr<InternalLink> get_internal_link_passport(Slice query, const vector<std::pair<string, string>> &args,
                                                             bool allow_unknown);

  static unique_ptr<InternalLink> get_internal_link_message_draft(Slice url, Slice text);

  static Result<string> get_internal_link_impl(const td_api::InternalLinkType *type_ptr, bool is_internal);

  static Result<string> check_link_impl(Slice link, bool http_only, bool https_only);

  Td *td_;
  ActorShared<> parent_;

  string autologin_token_;
  vector<string> autologin_domains_;
  double autologin_update_time_ = 0.0;
  vector<string> url_auth_domains_;
  vector<string> whitelisted_domains_;
};

}  // namespace td
