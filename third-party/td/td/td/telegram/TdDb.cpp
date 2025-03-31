//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TdDb.h"

#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/DialogDb.h"
#include "td/telegram/files/FileDb.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessageDb.h"
#include "td/telegram/MessageThreadDb.h"
#include "td/telegram/StoryDb.h"
#include "td/telegram/Td.h"
#include "td/telegram/Version.h"

#include "td/db/binlog/Binlog.h"
#include "td/db/binlog/ConcurrentBinlog.h"
#include "td/db/BinlogKeyValue.h"
#include "td/db/SqliteConnectionSafe.h"
#include "td/db/SqliteDb.h"
#include "td/db/SqliteKeyValue.h"
#include "td/db/SqliteKeyValueAsync.h"
#include "td/db/SqliteKeyValueSafe.h"

#include "td/actor/actor.h"
#include "td/actor/MultiPromise.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"

#include <algorithm>

namespace td {

namespace {

std::string get_binlog_path(const TdDb::Parameters &parameters) {
  return PSTRING() << parameters.database_directory_ << "td" << (parameters.is_test_dc_ ? "_test" : "") << ".binlog";
}

std::string get_sqlite_path(const TdDb::Parameters &parameters) {
  const string db_name = "db" + (parameters.is_test_dc_ ? string("_test") : string());
  return parameters.database_directory_ + db_name + ".sqlite";
}

Status init_binlog(Binlog &binlog, string path, BinlogKeyValue<Binlog> &binlog_pmc, BinlogKeyValue<Binlog> &config_pmc,
                   TdDb::OpenedDatabase &events, DbKey key) {
  auto r_binlog_stat = stat(path);
  if (r_binlog_stat.is_ok()) {
    auto since_last_open = Clocks::system() - static_cast<double>(r_binlog_stat.ok().mtime_nsec_) * 1e-9;
    if (since_last_open >= 86400) {
      LOG(WARNING) << "Binlog wasn't opened for " << since_last_open << " seconds";
    }
    if (since_last_open > 0 && since_last_open < 1e12) {
      events.since_last_open = static_cast<int64>(since_last_open);
    }
  }

  auto callback = [&](const BinlogEvent &event) {
    switch (event.type_) {
      case LogEvent::HandlerType::SecretChats:
        events.to_secret_chats_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::Users:
        events.user_events.push_back(event.clone());
        break;
      case LogEvent::HandlerType::Chats:
        events.chat_events.push_back(event.clone());
        break;
      case LogEvent::HandlerType::Channels:
        events.channel_events.push_back(event.clone());
        break;
      case LogEvent::HandlerType::SecretChatInfos:
        events.secret_chat_events.push_back(event.clone());
        break;
      case LogEvent::HandlerType::WebPages:
        events.web_page_events.push_back(event.clone());
        break;
      case LogEvent::HandlerType::SetPollAnswer:
      case LogEvent::HandlerType::StopPoll:
        events.to_poll_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::ReorderPinnedDialogsOnServer:
      case LogEvent::HandlerType::ToggleDialogIsBlockedOnServer:
      case LogEvent::HandlerType::ToggleDialogIsMarkedAsUnreadOnServer:
      case LogEvent::HandlerType::ToggleDialogIsPinnedOnServer:
      case LogEvent::HandlerType::ToggleDialogIsTranslatableOnServer:
      case LogEvent::HandlerType::ToggleDialogReportSpamStateOnServer:
      case LogEvent::HandlerType::ToggleDialogViewAsMessagesOnServer:
        events.to_dialog_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::BlockMessageSenderFromRepliesOnServer:
      case LogEvent::HandlerType::DeleteAllCallMessagesOnServer:
      case LogEvent::HandlerType::DeleteAllChannelMessagesFromSenderOnServer:
      case LogEvent::HandlerType::DeleteDialogHistoryOnServer:
      case LogEvent::HandlerType::DeleteDialogMessagesByDateOnServer:
      case LogEvent::HandlerType::DeleteMessagesOnServer:
      case LogEvent::HandlerType::DeleteScheduledMessagesOnServer:
      case LogEvent::HandlerType::DeleteTopicHistoryOnServer:
      case LogEvent::HandlerType::ReadAllDialogMentionsOnServer:
      case LogEvent::HandlerType::ReadAllDialogReactionsOnServer:
      case LogEvent::HandlerType::ReadMessageContentsOnServer:
      case LogEvent::HandlerType::UnpinAllDialogMessagesOnServer:
        events.to_message_query_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::SendMessage:
      case LogEvent::HandlerType::DeleteMessage:
      case LogEvent::HandlerType::ReadHistoryOnServer:
      case LogEvent::HandlerType::ForwardMessages:
      case LogEvent::HandlerType::SendBotStartMessage:
      case LogEvent::HandlerType::SendScreenshotTakenNotificationMessage:
      case LogEvent::HandlerType::SendInlineQueryResultMessage:
      case LogEvent::HandlerType::SaveDialogDraftMessageOnServer:
      case LogEvent::HandlerType::UpdateDialogNotificationSettingsOnServer:
      case LogEvent::HandlerType::RegetDialog:
      case LogEvent::HandlerType::GetChannelDifference:
      case LogEvent::HandlerType::ReadHistoryInSecretChat:
      case LogEvent::HandlerType::SetDialogFolderIdOnServer:
      case LogEvent::HandlerType::ReadMessageThreadHistoryOnServer:
      case LogEvent::HandlerType::SendQuickReplyShortcutMessages:
        events.to_messages_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::DeleteStoryOnServer:
      case LogEvent::HandlerType::ReadStoriesOnServer:
      case LogEvent::HandlerType::LoadDialogExpiringStories:
      case LogEvent::HandlerType::SendStory:
      case LogEvent::HandlerType::EditStory:
        events.to_story_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::ResetAllNotificationSettingsOnServer:
      case LogEvent::HandlerType::UpdateScopeNotificationSettingsOnServer:
      case LogEvent::HandlerType::UpdateReactionNotificationSettingsOnServer:
        events.to_notification_settings_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::AddMessagePushNotification:
      case LogEvent::HandlerType::EditMessagePushNotification:
        events.to_notification_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::SaveAppLog:
        events.save_app_log_events.push_back(event.clone());
        break;
      case LogEvent::HandlerType::ChangeAuthorizationSettingsOnServer:
      case LogEvent::HandlerType::InvalidateSignInCodesOnServer:
      case LogEvent::HandlerType::ResetAuthorizationOnServer:
      case LogEvent::HandlerType::ResetAuthorizationsOnServer:
      case LogEvent::HandlerType::ResetWebAuthorizationOnServer:
      case LogEvent::HandlerType::ResetWebAuthorizationsOnServer:
      case LogEvent::HandlerType::SetAccountTtlOnServer:
      case LogEvent::HandlerType::SetAuthorizationTtlOnServer:
      case LogEvent::HandlerType::SetDefaultHistoryTtlOnServer:
        events.to_account_manager.push_back(event.clone());
        break;
      case LogEvent::HandlerType::BinlogPmcMagic:
        binlog_pmc.external_init_handle(event);
        break;
      case LogEvent::HandlerType::ConfigPmcMagic:
        config_pmc.external_init_handle(event);
        break;
      default:
        LOG(FATAL) << "Unsupported log event type " << event.type_;
    }
  };

  auto init_status = binlog.init(std::move(path), callback, std::move(key));
  if (init_status.is_error()) {
    if (init_status.code() == static_cast<int>(Binlog::Error::WrongPassword)) {
      return Status::Error(401, "Wrong database encryption key");
    }
    return Status::Error(400, init_status.message());
  }
  return Status::OK();
}

}  // namespace

std::shared_ptr<FileDbInterface> TdDb::get_file_db_shared() {
  return file_db_;
}

std::shared_ptr<SqliteConnectionSafe> &TdDb::get_sqlite_connection_safe() {
  return sql_connection_;
}

BinlogInterface *TdDb::get_binlog_impl(const char *file, int line) {
  LOG_CHECK(binlog_) << G()->close_flag() << " " << file << " " << line;
  return binlog_.get();
}

std::shared_ptr<KeyValueSyncInterface> TdDb::get_binlog_pmc_shared() {
  CHECK(binlog_pmc_);
  return binlog_pmc_;
}

std::shared_ptr<KeyValueSyncInterface> TdDb::get_config_pmc_shared() {
  CHECK(config_pmc_);
  return config_pmc_;
}

KeyValueSyncInterface *TdDb::get_binlog_pmc_impl(const char *file, int line) {
  LOG_CHECK(binlog_pmc_) << G()->close_flag() << ' ' << file << ' ' << line;
  return binlog_pmc_.get();
}

KeyValueSyncInterface *TdDb::get_config_pmc() {
  CHECK(config_pmc_);
  return config_pmc_.get();
}

SqliteKeyValue *TdDb::get_sqlite_sync_pmc() {
  CHECK(common_kv_safe_);
  return &common_kv_safe_->get();
}

SqliteKeyValueAsyncInterface *TdDb::get_sqlite_pmc() {
  CHECK(common_kv_async_);
  return common_kv_async_.get();
}

MessageDbSyncInterface *TdDb::get_message_db_sync() {
  return &message_db_sync_safe_->get();
}

MessageDbAsyncInterface *TdDb::get_message_db_async() {
  return message_db_async_.get();
}

MessageThreadDbSyncInterface *TdDb::get_message_thread_db_sync() {
  return &message_thread_db_sync_safe_->get();
}

MessageThreadDbAsyncInterface *TdDb::get_message_thread_db_async() {
  return message_thread_db_async_.get();
}

DialogDbSyncInterface *TdDb::get_dialog_db_sync() {
  return &dialog_db_sync_safe_->get();
}

DialogDbAsyncInterface *TdDb::get_dialog_db_async() {
  return dialog_db_async_.get();
}

StoryDbSyncInterface *TdDb::get_story_db_sync() {
  return &story_db_sync_safe_->get();
}

StoryDbAsyncInterface *TdDb::get_story_db_async() {
  return story_db_async_.get();
}

void TdDb::flush_all() {
  LOG(INFO) << "Flush all databases";
  if (message_db_async_) {
    message_db_async_->force_flush();
  }
  if (message_thread_db_async_) {
    message_thread_db_async_->force_flush();
  }
  if (dialog_db_async_) {
    dialog_db_async_->force_flush();
  }
  if (story_db_async_) {
    story_db_async_->force_flush();
  }
  CHECK(binlog_ != nullptr);
  binlog_->force_flush();
}

void TdDb::close(int32 scheduler_id, bool destroy_flag, Promise<Unit> on_finished) {
  Scheduler::instance()->run_on_scheduler(scheduler_id,
                                          [this, destroy_flag, on_finished = std::move(on_finished)](Unit) mutable {
                                            do_close(destroy_flag, std::move(on_finished));
                                          });
}

void TdDb::do_close(bool destroy_flag, Promise<Unit> on_finished) {
  if (destroy_flag) {
    LOG(INFO) << "Destroy all databases";
  } else {
    LOG(INFO) << "Close all databases";
  }
  MultiPromiseActorSafe mpas{"TdDbCloseMultiPromiseActor"};
  mpas.add_promise(PromiseCreator::lambda(
      [promise = std::move(on_finished), sql_connection = std::move(sql_connection_), destroy_flag](Unit) mutable {
        if (sql_connection) {
          if (destroy_flag) {
            sql_connection->close_and_destroy();
          } else {
            sql_connection->close();
          }
          sql_connection.reset();
        }
        promise.set_value(Unit());
      }));
  auto lock = mpas.get_promise();

  if (file_db_) {
    file_db_->close(mpas.get_promise());
    file_db_.reset();
  }

  common_kv_safe_.reset();
  if (common_kv_async_) {
    common_kv_async_->close(mpas.get_promise());
  }

  message_db_sync_safe_.reset();
  if (message_db_async_) {
    message_db_async_->close(mpas.get_promise());
  }

  message_thread_db_sync_safe_.reset();
  if (message_thread_db_async_) {
    message_thread_db_async_->close(mpas.get_promise());
  }

  dialog_db_sync_safe_.reset();
  if (dialog_db_async_) {
    dialog_db_async_->close(mpas.get_promise());
  }

  story_db_sync_safe_.reset();
  if (story_db_async_) {
    story_db_async_->close(mpas.get_promise());
  }

  // binlog_pmc is dependent on binlog_ and anyway it doesn't support close_and_destroy
  binlog_pmc_.reset();
  config_pmc_.reset();

  if (binlog_) {
    if (destroy_flag) {
      binlog_->close_and_destroy(mpas.get_promise());
    } else {
      binlog_->close(mpas.get_promise());
    }
    binlog_.reset();
  }

  lock.set_value(Unit());
}

Status TdDb::init_sqlite(const Parameters &parameters, const DbKey &key, const DbKey &old_key,
                         BinlogKeyValue<Binlog> &binlog_pmc) {
  CHECK(!parameters.use_message_database_ || parameters.use_chat_info_database_);
  CHECK(!parameters.use_chat_info_database_ || parameters.use_file_database_);

  const string sql_database_path = get_sqlite_path(parameters);

  bool use_sqlite = parameters.use_file_database_;
  bool use_file_database = parameters.use_file_database_;
  bool use_dialog_db = parameters.use_message_database_;
  bool use_message_thread_db = parameters.use_message_database_ && false;
  bool use_message_database = parameters.use_message_database_;
  bool use_story_database = parameters.use_message_database_;

  was_dialog_db_created_ = false;

  if (!use_sqlite) {
    SqliteDb::destroy(sql_database_path).ignore();
    return Status::OK();
  }

  TRY_RESULT(db_instance, SqliteDb::change_key(sql_database_path, true, key, old_key));
  sql_connection_ = std::make_shared<SqliteConnectionSafe>(sql_database_path, key, db_instance.get_cipher_version());
  sql_connection_->set(std::move(db_instance));
  auto &db = sql_connection_->get();
  TRY_STATUS(db.exec("PRAGMA journal_mode=WAL"));
  TRY_STATUS(db.exec("PRAGMA secure_delete=1"));

  // Init databases
  // Do initialization once and before everything else to avoid "database is locked" error.
  // Must be in a transaction

  // NB: when database is dropped we should also drop corresponding binlog events
  TRY_STATUS(db.exec("BEGIN TRANSACTION"));

  // Get 'PRAGMA user_version'
  TRY_RESULT(user_version, db.user_version());
  LOG(INFO) << "Have PRAGMA user_version = " << user_version;

  // init DialogDb
  if (use_dialog_db) {
    TRY_STATUS(init_dialog_db(db, user_version, binlog_pmc, was_dialog_db_created_));
  } else {
    TRY_STATUS(drop_dialog_db(db, user_version));
  }

  // init MessageThreadDb
  if (use_message_thread_db) {
    TRY_STATUS(init_message_thread_db(db, user_version));
  } else {
    TRY_STATUS(drop_message_thread_db(db, user_version));
  }

  // init MessageDb
  if (use_message_database) {
    TRY_STATUS(init_message_db(db, user_version));
  } else {
    TRY_STATUS(drop_message_db(db, user_version));
  }

  // init StoryDb
  if (use_story_database) {
    TRY_STATUS(init_story_db(db, user_version));
  } else {
    TRY_STATUS(drop_story_db(db, user_version));
  }

  // init FileDb
  if (use_file_database) {
    TRY_STATUS(init_file_db(db, user_version));
  } else {
    TRY_STATUS(drop_file_db(db, user_version));
  }

  // Update 'PRAGMA user_version'
  auto db_version = current_db_version();
  if (db_version != user_version) {
    LOG(WARNING) << "Set PRAGMA user_version = " << db_version;
    TRY_STATUS(db.set_user_version(db_version));
  }

  if (was_dialog_db_created_) {
    binlog_pmc.erase_by_prefix("pinned_dialog_ids");
    binlog_pmc.erase_by_prefix("last_server_dialog_date");
    binlog_pmc.erase_by_prefix("unread_message_count");
    binlog_pmc.erase_by_prefix("unread_dialog_count");
    binlog_pmc.erase("sponsored_dialog_id");
    binlog_pmc.erase_by_prefix("top_dialogs#");
    binlog_pmc.erase("dlds_counter");
    binlog_pmc.erase_by_prefix("dlds#");
    binlog_pmc.erase("fetched_marks_as_unread");
    binlog_pmc.erase_by_prefix("public_channels");
    binlog_pmc.erase("channels_to_send_stories");
    binlog_pmc.erase_by_prefix("saved_messages_tags");
  }
  if (user_version == 0) {
    binlog_pmc.erase("next_contacts_sync_date");
    binlog_pmc.erase("saved_contact_count");
    binlog_pmc.erase("old_featured_sticker_set_count");
    binlog_pmc.erase("invalidate_old_featured_sticker_sets");
    binlog_pmc.erase(AttachMenuManager::get_attach_menu_bots_database_key());
  }
  binlog_pmc.force_sync(Auto(), "init_sqlite");

  TRY_STATUS(db.exec("COMMIT TRANSACTION"));

  file_db_ = create_file_db(sql_connection_);

  common_kv_safe_ = std::make_shared<SqliteKeyValueSafe>("common", sql_connection_);
  common_kv_async_ = create_sqlite_key_value_async(common_kv_safe_);

  if (was_dialog_db_created_) {
    auto *sqlite_pmc = get_sqlite_sync_pmc();
    sqlite_pmc->erase("calls_db_state");
    sqlite_pmc->erase("di_active_live_location_messages");
    sqlite_pmc->erase_by_prefix("channel_recommendations");
  }

  if (use_dialog_db) {
    dialog_db_sync_safe_ = create_dialog_db_sync(sql_connection_);
    dialog_db_async_ = create_dialog_db_async(dialog_db_sync_safe_);
  }

  if (use_message_thread_db) {
    message_thread_db_sync_safe_ = create_message_thread_db_sync(sql_connection_);
    message_thread_db_async_ = create_message_thread_db_async(message_thread_db_sync_safe_);
  }

  if (use_message_database) {
    message_db_sync_safe_ = create_message_db_sync(sql_connection_);
    message_db_async_ = create_message_db_async(message_db_sync_safe_);
  }

  if (use_story_database) {
    story_db_sync_safe_ = create_story_db_sync(sql_connection_);
    story_db_async_ = create_story_db_async(story_db_sync_safe_);
  }

  return Status::OK();
}

void TdDb::open(int32 scheduler_id, Parameters parameters, Promise<OpenedDatabase> &&promise) {
  Scheduler::instance()->run_on_scheduler(
      scheduler_id, [parameters = std::move(parameters), promise = std::move(promise)](Unit) mutable {
        TdDb::open_impl(std::move(parameters), std::move(promise));
      });
}

void TdDb::open_impl(Parameters parameters, Promise<OpenedDatabase> &&promise) {
  TRY_STATUS_PROMISE(promise, check_parameters(parameters));

  OpenedDatabase result;

  // Init pmc
  Binlog *binlog_ptr = nullptr;
  auto binlog = std::shared_ptr<Binlog>(new Binlog, [&](Binlog *ptr) { binlog_ptr = ptr; });

  auto binlog_pmc = make_unique<BinlogKeyValue<Binlog>>();
  auto config_pmc = make_unique<BinlogKeyValue<Binlog>>();
  binlog_pmc->external_init_begin(static_cast<int32>(LogEvent::HandlerType::BinlogPmcMagic));
  config_pmc->external_init_begin(static_cast<int32>(LogEvent::HandlerType::ConfigPmcMagic));

  bool encrypt_binlog = !parameters.encryption_key_.is_empty();
  VLOG(td_init) << "Start binlog loading";
  TRY_STATUS_PROMISE(promise, init_binlog(*binlog, get_binlog_path(parameters), *binlog_pmc, *config_pmc, result,
                                          std::move(parameters.encryption_key_)));
  VLOG(td_init) << "Finish binlog loading";

  binlog_pmc->external_init_finish(binlog);
  VLOG(td_init) << "Finish initialization of binlog PMC";
  config_pmc->external_init_finish(binlog);
  VLOG(td_init) << "Finish initialization of config PMC";

  if (parameters.use_file_database_ && binlog_pmc->get("auth").empty()) {
    LOG(INFO) << "Destroy SQLite database, because wasn't authorized yet";
    SqliteDb::destroy(get_sqlite_path(parameters)).ignore();
  }

  DbKey new_sqlite_key;
  DbKey old_sqlite_key;
  bool encrypt_sqlite = encrypt_binlog;
  bool drop_sqlite_key = false;
  auto sqlite_key = binlog_pmc->get("sqlite_key");
  if (encrypt_sqlite) {
    if (sqlite_key.empty()) {
      sqlite_key = string(32, ' ');
      Random::secure_bytes(sqlite_key);
      binlog_pmc->set("sqlite_key", sqlite_key);
      if (parameters.use_file_database_) {
        binlog_pmc->force_sync(Auto(), "TdDb::open_impl 1");
      }
    }
    new_sqlite_key = DbKey::raw_key(std::move(sqlite_key));
  } else {
    if (!sqlite_key.empty()) {
      old_sqlite_key = DbKey::raw_key(std::move(sqlite_key));
      drop_sqlite_key = true;
    }
  }
  VLOG(td_init) << "Start to init database";
  auto db = make_unique<TdDb>();
  auto init_sqlite_status = db->init_sqlite(parameters, new_sqlite_key, old_sqlite_key, *binlog_pmc);
  VLOG(td_init) << "Finish to init database";
  if (init_sqlite_status.is_error()) {
    LOG(ERROR) << "Destroy bad SQLite database because of " << init_sqlite_status;
    if (db->sql_connection_ != nullptr) {
      db->sql_connection_->get().close();
    }
    SqliteDb::destroy(get_sqlite_path(parameters)).ignore();
    init_sqlite_status = db->init_sqlite(parameters, new_sqlite_key, old_sqlite_key, *binlog_pmc);
    if (init_sqlite_status.is_error()) {
      return promise.set_error(Status::Error(400, init_sqlite_status.message()));
    }
  }
  if (drop_sqlite_key) {
    binlog_pmc->erase("sqlite_key");
    binlog_pmc->force_sync(Auto(), "TdDb::open_impl 2");
  }

  VLOG(td_init) << "Create concurrent_binlog_pmc";
  auto concurrent_binlog_pmc = std::make_shared<BinlogKeyValue<ConcurrentBinlog>>();
  concurrent_binlog_pmc->external_init_begin(binlog_pmc->get_magic());
  concurrent_binlog_pmc->external_init_handle(std::move(*binlog_pmc));

  VLOG(td_init) << "Create concurrent_config_pmc";
  auto concurrent_config_pmc = std::make_shared<BinlogKeyValue<ConcurrentBinlog>>();
  concurrent_config_pmc->external_init_begin(config_pmc->get_magic());
  concurrent_config_pmc->external_init_handle(std::move(*config_pmc));

  binlog.reset();
  binlog_pmc.reset();
  config_pmc.reset();

  CHECK(binlog_ptr != nullptr);
  VLOG(td_init) << "Create concurrent_binlog";
  auto concurrent_binlog = std::make_shared<ConcurrentBinlog>(unique_ptr<Binlog>(binlog_ptr));

  VLOG(td_init) << "Init concurrent_binlog_pmc";
  concurrent_binlog_pmc->external_init_finish(concurrent_binlog);
  VLOG(td_init) << "Init concurrent_config_pmc";
  concurrent_config_pmc->external_init_finish(concurrent_binlog);

  LOG(INFO) << "Successfully inited database in directory " << parameters.database_directory_ << " and files directory "
            << parameters.files_directory_;

  db->parameters_ = std::move(parameters);
  db->binlog_pmc_ = std::move(concurrent_binlog_pmc);
  db->config_pmc_ = std::move(concurrent_config_pmc);
  db->binlog_ = std::move(concurrent_binlog);

  result.database = std::move(db);

  promise.set_value(std::move(result));
}

TdDb::TdDb() = default;

TdDb::~TdDb() {
  LOG_IF(ERROR, binlog_ != nullptr) << "Failed to close the database";
}

Status TdDb::check_parameters(Parameters &parameters) {
  if (parameters.database_directory_.empty()) {
    parameters.database_directory_ = ".";
  }
  if (parameters.use_message_database_ && !parameters.use_chat_info_database_) {
    parameters.use_chat_info_database_ = true;
  }
  if (parameters.use_chat_info_database_ && !parameters.use_file_database_) {
    parameters.use_file_database_ = true;
  }

  auto prepare_dir = [](string dir) -> Result<string> {
    CHECK(!dir.empty());
    if (dir.back() != TD_DIR_SLASH) {
      dir += TD_DIR_SLASH;
    }
    TRY_STATUS(mkpath(dir, 0750));
    TRY_RESULT(real_dir, realpath(dir, true));
    if (real_dir.empty()) {
      return Status::Error(PSTRING() << "Failed to get realpath for \"" << dir << '"');
    }
    if (real_dir.back() != TD_DIR_SLASH) {
      real_dir += TD_DIR_SLASH;
    }
    return real_dir;
  };

  auto r_database_directory = prepare_dir(parameters.database_directory_);
  if (r_database_directory.is_error()) {
    VLOG(td_init) << "Invalid database directory";
    return Status::Error(400, PSLICE() << "Can't init database in the directory \"" << parameters.database_directory_
                                       << "\": " << r_database_directory.error());
  }
  parameters.database_directory_ = r_database_directory.move_as_ok();

  if (parameters.files_directory_.empty()) {
    parameters.files_directory_ = parameters.database_directory_;
  } else {
    auto r_files_directory = prepare_dir(parameters.files_directory_);
    if (r_files_directory.is_error()) {
      VLOG(td_init) << "Invalid files directory";
      return Status::Error(400, PSLICE() << "Can't init files directory \"" << parameters.files_directory_
                                         << "\": " << r_files_directory.error());
    }
    parameters.files_directory_ = r_files_directory.move_as_ok();
  }

  return Status::OK();
}

DbKey TdDb::as_db_key(string key) {
  if (key.empty()) {
    return DbKey::raw_key("cucumber");
  }
  return DbKey::raw_key(std::move(key));
}

void TdDb::change_key(DbKey key, Promise<> promise) {
  get_binlog()->change_key(std::move(key), std::move(promise));
}

Status TdDb::destroy(const Parameters &parameters) {
  SqliteDb::destroy(get_sqlite_path(parameters)).ignore();
  Binlog::destroy(get_binlog_path(parameters)).ignore();
  return Status::OK();
}

void TdDb::with_db_path(const std::function<void(CSlice)> &callback) {
  SqliteDb::with_db_path(get_sqlite_path(parameters_), callback);
  CHECK(binlog_ != nullptr);
  callback(binlog_->get_path());
}

Result<string> TdDb::get_stats() {
  auto sb = StringBuilder({}, true);
  auto &sql = sql_connection_->get();
  auto run_query = [&](CSlice query, Slice desc) -> Status {
    TRY_RESULT(stmt, sql.get_statement(query));
    TRY_STATUS(stmt.step());
    CHECK(stmt.has_row());
    auto key_size = stmt.view_int64(0);
    auto value_size = stmt.view_int64(1);
    auto count = stmt.view_int64(2);
    sb << query << "\n";
    sb << desc << ":\n";
    sb << format::as_size(key_size + value_size) << "\t";
    sb << format::as_size(key_size) << "\t";
    sb << format::as_size(value_size) << "\t";
    sb << format::as_size((key_size + value_size) / (count ? count : 1)) << "\t";
    sb << "\n";
    return Status::OK();
  };
  auto run_kv_query = [&](Slice mask, Slice table = Slice("common")) {
    return run_query(PSLICE() << "SELECT SUM(length(k)), SUM(length(v)), COUNT(*) FROM " << table << " WHERE k like '"
                              << mask << "'",
                     PSLICE() << table << ":" << mask);
  };
  TRY_STATUS(run_query("SELECT 0, SUM(length(data)), COUNT(*) FROM stories WHERE 1", "stories"));
  TRY_STATUS(run_query("SELECT 0, SUM(length(data)), COUNT(*) FROM messages WHERE 1", "messages"));
  TRY_STATUS(run_query("SELECT 0, SUM(length(data)), COUNT(*) FROM dialogs WHERE 1", "dialogs"));
  TRY_STATUS(run_kv_query("%", "common"));
  TRY_STATUS(run_kv_query("%", "files"));
  TRY_STATUS(run_kv_query("wp%"));
  TRY_STATUS(run_kv_query("wpurl%"));
  TRY_STATUS(run_kv_query("wpiv%"));
  TRY_STATUS(run_kv_query("us%"));
  TRY_STATUS(run_kv_query("ch%"));
  TRY_STATUS(run_kv_query("ss%"));
  TRY_STATUS(run_kv_query("gr%"));

  vector<int32> prev(1);
  size_t count = 0;
  int32 max_bad_to = 0;
  size_t bad_count = 0;
  file_db_->pmc().get_by_range("file0", "file:", [&](Slice key, Slice value) {
    if (value.substr(0, 2) != "@@") {
      return true;
    }
    count++;
    auto from = to_integer<int32>(key.substr(4));
    auto to = to_integer<int32>(value.substr(2));
    if (from <= to) {
      LOG(DEBUG) << "Have forward reference from " << from << " to " << to;
      if (to > max_bad_to) {
        max_bad_to = to;
      }
      bad_count++;
      return true;
    }
    if (static_cast<size_t>(from) >= prev.size()) {
      prev.resize(from + 1);
    }
    if (static_cast<size_t>(to) >= prev.size()) {
      prev.resize(to + 1);
    }
    prev[from] = to;
    return true;
  });
  for (size_t i = 1; i < prev.size(); i++) {
    if (!prev[i]) {
      continue;
    }
    prev[i] = prev[prev[i]] + 1;
  }
  sb << "Max file database depth out of " << prev.size() << '/' << count
     << " elements: " << *std::max_element(prev.begin(), prev.end()) << "\n";
  sb << "Have " << bad_count << " forward references with maximum reference to " << max_bad_to;

  return sb.as_cslice().str();
}

}  // namespace td
