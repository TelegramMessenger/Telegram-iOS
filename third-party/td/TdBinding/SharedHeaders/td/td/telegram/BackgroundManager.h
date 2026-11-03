//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BackgroundId.h"
#include "td/telegram/BackgroundType.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <memory>
#include <utility>

namespace td {

class Td;

class BackgroundManager final : public Actor {
 public:
  BackgroundManager(Td *td, ActorShared<> parent);

  void get_backgrounds(bool for_dark_theme, Promise<td_api::object_ptr<td_api::backgrounds>> &&promise);

  void reload_background(BackgroundId background_id, int64 access_hash, Promise<Unit> &&promise);

  std::pair<BackgroundId, BackgroundType> search_background(const string &name, Promise<Unit> &&promise);

  void set_background(const td_api::InputBackground *input_background, const td_api::BackgroundType *background_type,
                      bool for_dark_theme, Promise<td_api::object_ptr<td_api::background>> &&promise);

  void delete_background(bool for_dark_theme, Promise<Unit> &&promise);

  void remove_background(BackgroundId background_id, Promise<Unit> &&promise);

  void reset_backgrounds(Promise<Unit> &&promise);

  void set_dialog_background(DialogId dialog_id, const td_api::InputBackground *input_background,
                             const td_api::BackgroundType *background_type, int32 dark_theme_dimming, bool for_both,
                             Promise<Unit> &&promise);

  void delete_dialog_background(DialogId dialog_id, bool restore_previous, Promise<Unit> &&promise);

  td_api::object_ptr<td_api::background> get_background_object(BackgroundId background_id, bool for_dark_theme,
                                                               const BackgroundType *type) const;

  std::pair<BackgroundId, BackgroundType> on_get_background(
      BackgroundId expected_background_id, const string &expected_background_name,
      telegram_api::object_ptr<telegram_api::WallPaper> wallpaper_ptr, bool replace_type, bool allow_empty);

  FileSourceId get_background_file_source_id(BackgroundId background_id, int64 access_hash);

  void on_uploaded_background_file(FileUploadId file_upload_id, const BackgroundType &type, DialogId dialog_id,
                                   bool for_dark_theme, telegram_api::object_ptr<telegram_api::WallPaper> wallpaper,
                                   Promise<td_api::object_ptr<td_api::background>> &&promise);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

  void store_background(BackgroundId background_id, LogEventStorerCalcLength &storer);

  void store_background(BackgroundId background_id, LogEventStorerUnsafe &storer);

  void parse_background(BackgroundId &background_id, LogEventParser &parser);

 private:
  struct Background {
    BackgroundId id;
    int64 access_hash = 0;
    string name;
    FileId file_id;
    bool is_creator = false;
    bool is_default = false;
    bool is_dark = false;
    bool has_new_local_id = true;
    BackgroundType type;
    FileSourceId file_source_id;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct LocalBackgroundHash {
    uint32 operator()(const Background &background) const {
      return Hash<string>()(background.name);
    }
  };

  struct LocalBackgroundEquals {
    bool operator()(const Background &lhs, const Background &rhs) const {
      return lhs.name == rhs.name && lhs.type == rhs.type && lhs.is_creator == rhs.is_creator &&
             lhs.is_default == rhs.is_default && lhs.is_dark == rhs.is_dark;
    }
  };

  class BackgroundLogEvent;
  class BackgroundsLogEvent;

  class UploadBackgroundFileCallback;

  void start_up() final;

  void tear_down() final;

  static string get_background_database_key(bool for_dark_theme);

  static string get_local_backgrounds_database_key(bool for_dark_theme);

  void save_background_id(bool for_dark_theme);

  void save_local_backgrounds(bool for_dark_theme);

  void reload_background_from_server(BackgroundId background_id, const string &background_name,
                                     telegram_api::object_ptr<telegram_api::InputWallPaper> &&input_wallpaper,
                                     Promise<Unit> &&promise) const;

  td_api::object_ptr<td_api::updateDefaultBackground> get_update_default_background_object(bool for_dark_theme) const;

  td_api::object_ptr<td_api::backgrounds> get_backgrounds_object(bool for_dark_theme) const;

  void send_update_default_background(bool for_dark_theme) const;

  void set_max_local_background_id(BackgroundId background_id);

  BackgroundId get_next_local_background_id();

  void set_local_background_id(Background &background);

  void add_local_background_to_cache(const Background &background);

  BackgroundId add_local_background(const BackgroundType &type);

  void add_background(const Background &background, bool replace_type);

  Background *get_background_ref(BackgroundId background_id);

  const Background *get_background(BackgroundId background_id) const;

  static string get_background_name_database_key(const string &name);

  void on_load_background_from_database(string name, string value);

  void on_get_backgrounds(Result<telegram_api::object_ptr<telegram_api::account_WallPapers>> result);

  Result<FileId> prepare_input_file(const tl_object_ptr<td_api::InputFile> &input_file);

  Result<DialogId> get_background_dialog(DialogId dialog_id);

  void do_set_dialog_background(DialogId dialog_id, BackgroundId background_id, BackgroundType type, bool for_both,
                                Promise<Unit> &&promise);

  void send_set_dialog_background_query(DialogId dialog_id,
                                        telegram_api::object_ptr<telegram_api::InputWallPaper> input_wallpaper,
                                        telegram_api::object_ptr<telegram_api::wallPaperSettings> settings,
                                        MessageId old_message_id, bool for_both, Promise<Unit> &&promise);

  void set_background(BackgroundId background_id, BackgroundType type, bool for_dark_theme,
                      Promise<td_api::object_ptr<td_api::background>> &&promise);

  void on_installed_background(BackgroundId background_id, BackgroundType type, bool for_dark_theme,
                               Result<Unit> &&result, Promise<td_api::object_ptr<td_api::background>> &&promise);

  void set_background_id(BackgroundId background_id, const BackgroundType &type, bool for_dark_theme);

  void on_removed_background(BackgroundId background_id, Result<Unit> &&result, Promise<Unit> &&promise);

  void on_reset_background(Result<Unit> &&result, Promise<Unit> &&promise);

  void upload_background_file(FileId file_id, const BackgroundType &type, DialogId dialog_id, bool for_dark_theme,
                              Promise<td_api::object_ptr<td_api::background>> &&promise);

  void on_upload_background_file(FileUploadId file_upload_id,
                                 telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_background_file_error(FileUploadId file_upload_id, Status status);

  void do_upload_background_file(FileUploadId file_upload_id, const BackgroundType &type, DialogId dialog_id,
                                 bool for_dark_theme, telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
                                 Promise<td_api::object_ptr<td_api::background>> &&promise);

  FlatHashMap<BackgroundId, unique_ptr<Background>, BackgroundIdHash> backgrounds_;

  FlatHashMap<BackgroundId, std::pair<int64, FileSourceId>, BackgroundIdHash>
      background_id_to_file_source_id_;  // background_id -> [access_hash, file_source_id]

  FlatHashMap<string, BackgroundId> name_to_background_id_;

  FlatHashMap<FileId, BackgroundId, FileIdHash> file_id_to_background_id_;

  FlatHashSet<string> loaded_from_database_backgrounds_;
  FlatHashMap<string, vector<Promise<Unit>>> being_loaded_from_database_backgrounds_;

  BackgroundId set_background_id_[2];
  BackgroundType set_background_type_[2];

  vector<std::pair<BackgroundId, BackgroundType>> installed_backgrounds_;

  vector<std::pair<bool, Promise<td_api::object_ptr<td_api::backgrounds>>>> pending_get_backgrounds_queries_;

  std::shared_ptr<UploadBackgroundFileCallback> upload_background_file_callback_;

  struct UploadedFileInfo {
    BackgroundType type_;
    DialogId dialog_id_;
    bool for_dark_theme_;
    Promise<td_api::object_ptr<td_api::background>> promise_;

    UploadedFileInfo(BackgroundType type, DialogId dialog_id, bool for_dark_theme,
                     Promise<td_api::object_ptr<td_api::background>> &&promise)
        : type_(type), dialog_id_(dialog_id), for_dark_theme_(for_dark_theme), promise_(std::move(promise)) {
    }
  };
  FlatHashMap<FileUploadId, UploadedFileInfo, FileUploadIdHash> being_uploaded_files_;

  FlatHashMap<Background, BackgroundId, LocalBackgroundHash, LocalBackgroundEquals> local_backgrounds_;

  BackgroundId max_local_background_id_;
  vector<BackgroundId> local_background_ids_[2];

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
