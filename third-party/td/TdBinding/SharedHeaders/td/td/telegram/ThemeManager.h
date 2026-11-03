//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AccentColorId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/ThemeSettings.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class ThemeManager final : public Actor {
 public:
  ThemeManager(Td *td, ActorShared<> parent);

  void init();

  void on_update_theme(telegram_api::object_ptr<telegram_api::theme> &&theme, Promise<Unit> &&promise);

  void reload_chat_themes();

  void reload_accent_colors();

  void reload_profile_accent_colors();

  static string get_theme_parameters_json_string(const td_api::object_ptr<td_api::themeParameters> &theme);

  int32 get_accent_color_id_object(AccentColorId accent_color_id,
                                   AccentColorId fallback_accent_color_id = AccentColorId()) const;

  int32 get_profile_accent_color_id_object(AccentColorId accent_color_id) const;

  struct DialogBoostAvailableCounts {
    int32 title_color_count_ = 0;
    int32 accent_color_count_ = 0;
    int32 profile_accent_color_count_ = 0;
    int32 chat_theme_count_ = 0;
  };
  DialogBoostAvailableCounts get_dialog_boost_available_count(int32 level, bool for_megagroup);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  struct ChatTheme {
    string emoji;
    int64 id = 0;
    ThemeSettings light_theme;
    ThemeSettings dark_theme;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct ChatThemes {
    int64 hash = 0;
    vector<ChatTheme> themes;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct AccentColors {
    FlatHashMap<AccentColorId, vector<int32>, AccentColorIdHash> light_colors_;
    FlatHashMap<AccentColorId, vector<int32>, AccentColorIdHash> dark_colors_;
    vector<AccentColorId> accent_color_ids_;
    vector<int32> min_broadcast_boost_levels_;
    vector<int32> min_megagroup_boost_levels_;
    int32 hash_ = 0;

    td_api::object_ptr<td_api::updateAccentColors> get_update_accent_colors_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct ProfileAccentColor {
    vector<int32> palette_colors_;
    vector<int32> background_colors_;
    vector<int32> story_colors_;

    bool is_valid() const;

    td_api::object_ptr<td_api::profileAccentColors> get_profile_accent_colors_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  friend bool operator==(const ProfileAccentColor &lhs, const ProfileAccentColor &rhs);

  friend bool operator!=(const ProfileAccentColor &lhs, const ProfileAccentColor &rhs);

  struct ProfileAccentColors {
    FlatHashMap<AccentColorId, ProfileAccentColor, AccentColorIdHash> light_colors_;
    FlatHashMap<AccentColorId, ProfileAccentColor, AccentColorIdHash> dark_colors_;
    vector<AccentColorId> accent_color_ids_;
    vector<int32> min_broadcast_boost_levels_;
    vector<int32> min_megagroup_boost_levels_;
    int32 hash_ = 0;

    td_api::object_ptr<td_api::updateProfileAccentColors> get_update_profile_accent_colors_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  void start_up() final;

  void tear_down() final;

  void load_chat_themes();

  void load_accent_colors();

  void load_profile_accent_colors();

  void on_get_chat_themes(Result<telegram_api::object_ptr<telegram_api::account_Themes>> result);

  bool on_update_accent_colors(FlatHashMap<AccentColorId, vector<int32>, AccentColorIdHash> light_colors,
                               FlatHashMap<AccentColorId, vector<int32>, AccentColorIdHash> dark_colors,
                               vector<AccentColorId> accent_color_ids, vector<int32> min_broadcast_boost_levels,
                               vector<int32> min_megagroup_boost_levels);

  void on_get_accent_colors(Result<telegram_api::object_ptr<telegram_api::help_PeerColors>> result);

  bool on_update_profile_accent_colors(FlatHashMap<AccentColorId, ProfileAccentColor, AccentColorIdHash> light_colors,
                                       FlatHashMap<AccentColorId, ProfileAccentColor, AccentColorIdHash> dark_colors,
                                       vector<AccentColorId> accent_color_ids, vector<int32> min_broadcast_boost_levels,
                                       vector<int32> min_megagroup_boost_levels);

  ProfileAccentColor get_profile_accent_color(
      telegram_api::object_ptr<telegram_api::help_PeerColorSet> &&color_set) const;

  void on_get_profile_accent_colors(Result<telegram_api::object_ptr<telegram_api::help_PeerColors>> result);

  td_api::object_ptr<td_api::chatTheme> get_chat_theme_object(const ChatTheme &theme) const;

  td_api::object_ptr<td_api::updateChatThemes> get_update_chat_themes_object() const;

  static string get_chat_themes_database_key();

  string get_accent_colors_database_key();

  string get_profile_accent_colors_database_key();

  void save_chat_themes();

  void save_accent_colors();

  void save_profile_accent_colors();

  void send_update_chat_themes() const;

  td_api::object_ptr<td_api::updateAccentColors> get_update_accent_colors_object() const;

  td_api::object_ptr<td_api::updateProfileAccentColors> get_update_profile_accent_colors_object() const;

  void send_update_accent_colors() const;

  void send_update_profile_accent_colors() const;

  ChatThemes chat_themes_;

  AccentColors accent_colors_;

  ProfileAccentColors profile_accent_colors_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
