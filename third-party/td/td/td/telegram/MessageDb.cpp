//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageDb.h"

#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/UserId.h"
#include "td/telegram/Version.h"

#include "td/db/SqliteConnectionSafe.h"
#include "td/db/SqliteDb.h"
#include "td/db/SqliteStatement.h"

#include "td/actor/actor.h"
#include "td/actor/SchedulerLocalStorage.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/unicode.h"
#include "td/utils/utf8.h"

#include <algorithm>
#include <array>
#include <iterator>
#include <limits>
#include <tuple>
#include <utility>

namespace td {

static constexpr int32 MESSAGE_DB_INDEX_COUNT = 30;
static constexpr int32 MESSAGE_DB_INDEX_COUNT_OLD = 9;

// NB: must happen inside a transaction
Status init_message_db(SqliteDb &db, int32 version) {
  LOG(INFO) << "Init message database " << tag("version", version);

  // Check if database exists
  TRY_RESULT(has_table, db.has_table("messages"));
  if (!has_table) {
    version = 0;
  } else if (version > current_db_version()) {
    TRY_STATUS(drop_message_db(db, version));
    version = 0;
  }

  auto add_media_indices = [&db](int begin, int end) {
    for (int i = begin; i < end; i++) {
      TRY_STATUS(db.exec(PSLICE() << "CREATE INDEX IF NOT EXISTS message_index_" << i
                                  << " ON messages (dialog_id, message_id) WHERE (index_mask & " << (1 << i)
                                  << ") != 0"));
    }
    return Status::OK();
  };

  auto add_fts = [&db] {
    TRY_STATUS(
        db.exec("CREATE INDEX IF NOT EXISTS message_by_search_id ON messages "
                "(search_id) WHERE search_id IS NOT NULL"));

    TRY_STATUS(
        db.exec("CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(text, content='messages', "
                "content_rowid='search_id', tokenize = \"unicode61 remove_diacritics 0 tokenchars '\a'\")"));
    TRY_STATUS(db.exec(
        "CREATE TRIGGER IF NOT EXISTS trigger_fts_delete BEFORE DELETE ON messages WHEN OLD.search_id IS NOT NULL"
        " BEGIN INSERT INTO messages_fts(messages_fts, rowid, text) VALUES(\'delete\', OLD.search_id, OLD.text); END"));
    TRY_STATUS(db.exec(
        "CREATE TRIGGER IF NOT EXISTS trigger_fts_insert AFTER INSERT ON messages WHEN NEW.search_id IS NOT NULL"
        " BEGIN INSERT INTO messages_fts(rowid, text) VALUES(NEW.search_id, NEW.text); END"));
    //TRY_STATUS(db.exec(
    //"CREATE TRIGGER IF NOT EXISTS trigger_fts_update AFTER UPDATE ON messages WHEN NEW.search_id IS NOT NULL OR "
    //"OLD.search_id IS NOT NULL"
    //" BEGIN "
    //"INSERT INTO messages_fts(messages_fts, rowid, text) VALUES(\'delete\', OLD.search_id, OLD.text); "
    //"INSERT INTO messages_fts(rowid, text) VALUES(NEW.search_id, NEW.text); "
    //" END"));

    return Status::OK();
  };
  auto add_call_index = [&db] {
    for (int i = static_cast<int>(MessageSearchFilter::Call) - 1; i < static_cast<int>(MessageSearchFilter::MissedCall);
         i++) {
      TRY_STATUS(db.exec(PSLICE() << "CREATE INDEX IF NOT EXISTS full_message_index_" << i
                                  << " ON messages (unique_message_id) WHERE (index_mask & " << (1 << i) << ") != 0"));
    }
    return Status::OK();
  };
  auto add_notification_id_index = [&db] {
    return db.exec(
        "CREATE INDEX IF NOT EXISTS message_by_notification_id ON messages (dialog_id, notification_id) WHERE "
        "notification_id IS NOT NULL");
  };
  auto add_scheduled_messages_table = [&db] {
    TRY_STATUS(
        db.exec("CREATE TABLE IF NOT EXISTS scheduled_messages (dialog_id INT8, message_id INT8, "
                "server_message_id INT4, data BLOB, PRIMARY KEY (dialog_id, message_id))"));

    TRY_STATUS(
        db.exec("CREATE INDEX IF NOT EXISTS message_by_server_message_id ON scheduled_messages "
                "(dialog_id, server_message_id) WHERE server_message_id IS NOT NULL"));
    return Status::OK();
  };

  if (version == 0) {
    LOG(INFO) << "Create new message database";
    TRY_STATUS(
        db.exec("CREATE TABLE IF NOT EXISTS messages (dialog_id INT8, message_id INT8, unique_message_id INT4, "
                "sender_user_id INT8, random_id INT8, data BLOB, ttl_expires_at INT4, index_mask INT4, search_id INT8, "
                "text STRING, notification_id INT4, top_thread_message_id INT8, PRIMARY KEY (dialog_id, message_id))"));

    TRY_STATUS(
        db.exec("CREATE INDEX IF NOT EXISTS message_by_random_id ON messages (dialog_id, random_id) "
                "WHERE random_id IS NOT NULL"));

    TRY_STATUS(
        db.exec("CREATE INDEX IF NOT EXISTS message_by_unique_message_id ON messages "
                "(unique_message_id) WHERE unique_message_id IS NOT NULL"));

    TRY_STATUS(
        db.exec("CREATE INDEX IF NOT EXISTS message_by_ttl ON messages "
                "(ttl_expires_at) WHERE ttl_expires_at IS NOT NULL"));

    TRY_STATUS(add_media_indices(0, MESSAGE_DB_INDEX_COUNT));

    TRY_STATUS(add_fts());

    TRY_STATUS(add_call_index());

    TRY_STATUS(add_notification_id_index());

    TRY_STATUS(add_scheduled_messages_table());

    version = current_db_version();
  }
  if (version < static_cast<int32>(DbVersion::AddMessageDbMediaIndex)) {
    TRY_STATUS(db.exec("ALTER TABLE messages ADD COLUMN index_mask INT4"));
    TRY_STATUS(add_media_indices(0, MESSAGE_DB_INDEX_COUNT_OLD));
  }
  if (version < static_cast<int32>(DbVersion::AddMessageDb30MediaIndex)) {
    TRY_STATUS(add_media_indices(MESSAGE_DB_INDEX_COUNT_OLD, MESSAGE_DB_INDEX_COUNT));
  }
  if (version < static_cast<int32>(DbVersion::AddMessageDbFts)) {
    TRY_STATUS(db.exec("ALTER TABLE messages ADD COLUMN search_id INT8"));
    TRY_STATUS(db.exec("ALTER TABLE messages ADD COLUMN text STRING"));
    TRY_STATUS(add_fts());
  }
  if (version < static_cast<int32>(DbVersion::AddMessagesCallIndex)) {
    TRY_STATUS(add_call_index());
  }
  if (version < static_cast<int32>(DbVersion::AddNotificationsSupport)) {
    TRY_STATUS(db.exec("ALTER TABLE messages ADD COLUMN notification_id INT4"));
    TRY_STATUS(add_notification_id_index());
  }
  if (version < static_cast<int32>(DbVersion::AddScheduledMessages)) {
    TRY_STATUS(add_scheduled_messages_table());
  }
  if (version < static_cast<int32>(DbVersion::AddMessageThreadSupport)) {
    TRY_STATUS(db.exec("ALTER TABLE messages ADD COLUMN top_thread_message_id INT8"));
  }
  return Status::OK();
}

// NB: must happen inside a transaction
Status drop_message_db(SqliteDb &db, int32 version) {
  LOG(WARNING) << "Drop message database " << tag("version", version)
               << tag("current_db_version", current_db_version());
  return db.exec("DROP TABLE IF EXISTS messages");
}

class MessageDbImpl final : public MessageDbSyncInterface {
 public:
  explicit MessageDbImpl(SqliteDb db) : db_(std::move(db)) {
    init().ensure();
  }

  Status init() {
    TRY_RESULT_ASSIGN(
        add_message_stmt_,
        db_.get_statement("INSERT OR REPLACE INTO messages VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)"));
    TRY_RESULT_ASSIGN(delete_message_stmt_,
                      db_.get_statement("DELETE FROM messages WHERE dialog_id = ?1 AND message_id = ?2"));
    TRY_RESULT_ASSIGN(delete_all_dialog_messages_stmt_,
                      db_.get_statement("DELETE FROM messages WHERE dialog_id = ?1 AND message_id <= ?2"));
    TRY_RESULT_ASSIGN(delete_dialog_messages_by_sender_stmt_,
                      db_.get_statement("DELETE FROM messages WHERE dialog_id = ?1 AND sender_user_id = ?2"));

    TRY_RESULT_ASSIGN(
        get_message_stmt_,
        db_.get_statement("SELECT message_id, data FROM messages WHERE dialog_id = ?1 AND message_id = ?2"));
    TRY_RESULT_ASSIGN(
        get_message_by_random_id_stmt_,
        db_.get_statement("SELECT message_id, data FROM messages WHERE dialog_id = ?1 AND random_id = ?2"));
    TRY_RESULT_ASSIGN(
        get_message_by_unique_message_id_stmt_,
        db_.get_statement("SELECT dialog_id, message_id, data FROM messages WHERE unique_message_id = ?1"));

    TRY_RESULT_ASSIGN(
        get_expiring_messages_stmt_,
        db_.get_statement("SELECT dialog_id, message_id, data FROM messages WHERE ttl_expires_at <= ?1 LIMIT ?2"));

    TRY_RESULT_ASSIGN(get_messages_stmt_.asc_stmt_,
                      db_.get_statement("SELECT data, message_id FROM messages WHERE dialog_id = ?1 AND message_id > "
                                        "?2 ORDER BY message_id ASC LIMIT ?3"));
    TRY_RESULT_ASSIGN(get_messages_stmt_.desc_stmt_,
                      db_.get_statement("SELECT data, message_id FROM messages WHERE dialog_id = ?1 AND message_id < "
                                        "?2 ORDER BY message_id DESC LIMIT ?3"));
    TRY_RESULT_ASSIGN(get_scheduled_messages_stmt_,
                      db_.get_statement("SELECT data, message_id FROM scheduled_messages WHERE dialog_id = ?1 AND "
                                        "message_id < ?2 ORDER BY message_id DESC LIMIT ?3"));
    TRY_RESULT_ASSIGN(get_messages_from_notification_id_stmt_,
                      db_.get_statement("SELECT data, message_id FROM messages WHERE dialog_id = ?1 AND "
                                        "notification_id < ?2 ORDER BY notification_id DESC LIMIT ?3"));
    TRY_RESULT_ASSIGN(get_messages_fts_stmt_,
                      db_.get_statement("SELECT dialog_id, message_id, data, search_id FROM messages WHERE search_id "
                                        "IN (SELECT rowid FROM messages_fts WHERE messages_fts MATCH ?1 AND rowid < ?2 "
                                        "ORDER BY rowid DESC LIMIT ?3) ORDER BY search_id DESC"));

    for (int32 i = 0; i < MESSAGE_DB_INDEX_COUNT; i++) {
      TRY_RESULT_ASSIGN(
          get_message_ids_stmts_[i],
          db_.get_statement(
              PSLICE() << "SELECT message_id FROM messages WHERE dialog_id = ?1 AND message_id < ?2 AND (index_mask & "
                       << (1 << i) << ") != 0 ORDER BY message_id DESC LIMIT 1000000"));

      TRY_RESULT_ASSIGN(
          get_messages_from_index_stmts_[i].desc_stmt_,
          db_.get_statement(
              PSLICE()
              << "SELECT data, message_id FROM messages WHERE dialog_id = ?1 AND message_id < ?2 AND (index_mask & "
              << (1 << i) << ") != 0 ORDER BY message_id DESC LIMIT ?3"));

      TRY_RESULT_ASSIGN(
          get_messages_from_index_stmts_[i].asc_stmt_,
          db_.get_statement(
              PSLICE()
              << "SELECT data, message_id FROM messages WHERE dialog_id = ?1 AND message_id > ?2 AND (index_mask & "
              << (1 << i) << ") != 0 ORDER BY message_id ASC LIMIT ?3"));

      // LOG(ERROR) << get_messages_from_index_stmts_[i].desc_stmt_.explain().ok();
      // LOG(ERROR) << get_messages_from_index_stmts_[i].asc_stmt_.explain().ok();
    }

    for (int i = static_cast<int>(MessageSearchFilter::Call) - 1, pos = 0;
         i < static_cast<int>(MessageSearchFilter::MissedCall); i++, pos++) {
      TRY_RESULT_ASSIGN(
          get_calls_stmts_[pos],
          db_.get_statement(
              PSLICE()
              << "SELECT dialog_id, message_id, data FROM messages WHERE unique_message_id < ?1 AND (index_mask & "
              << (1 << i) << ") != 0 ORDER BY unique_message_id DESC LIMIT ?2"));
    }

    TRY_RESULT_ASSIGN(add_scheduled_message_stmt_,
                      db_.get_statement("INSERT OR REPLACE INTO scheduled_messages VALUES(?1, ?2, ?3, ?4)"));
    TRY_RESULT_ASSIGN(
        get_scheduled_message_stmt_,
        db_.get_statement("SELECT message_id, data FROM scheduled_messages WHERE dialog_id = ?1 AND message_id = ?2"));
    TRY_RESULT_ASSIGN(
        get_scheduled_server_message_stmt_,
        db_.get_statement(
            "SELECT message_id, data FROM scheduled_messages WHERE dialog_id = ?1 AND server_message_id = ?2"));
    TRY_RESULT_ASSIGN(delete_scheduled_message_stmt_,
                      db_.get_statement("DELETE FROM scheduled_messages WHERE dialog_id = ?1 AND message_id = ?2"));
    TRY_RESULT_ASSIGN(
        delete_scheduled_server_message_stmt_,
        db_.get_statement("DELETE FROM scheduled_messages WHERE dialog_id = ?1 AND server_message_id = ?2"));

    // LOG(ERROR) << get_message_stmt_.explain().ok();
    // LOG(ERROR) << get_messages_from_notification_id_stmt.explain().ok();
    // LOG(ERROR) << get_message_by_random_id_stmt_.explain().ok();
    // LOG(ERROR) << get_message_by_unique_message_id_stmt_.explain().ok();

    // LOG(ERROR) << get_expiring_messages_stmt_.explain().ok();

    // LOG(FATAL) << "EXPLAINED";

    return Status::OK();
  }

  void add_message(MessageFullId message_full_id, ServerMessageId unique_message_id, DialogId sender_dialog_id,
                   int64 random_id, int32 ttl_expires_at, int32 index_mask, int64 search_id, string text,
                   NotificationId notification_id, MessageId top_thread_message_id, BufferSlice data) final {
    LOG(INFO) << "Add " << message_full_id << " to database";
    auto dialog_id = message_full_id.get_dialog_id();
    auto message_id = message_full_id.get_message_id();
    LOG_CHECK(dialog_id.is_valid()) << dialog_id << ' ' << message_id << ' ' << message_full_id;
    CHECK(message_id.is_valid());
    SCOPE_EXIT {
      add_message_stmt_.reset();
    };
    add_message_stmt_.bind_int64(1, dialog_id.get()).ensure();
    add_message_stmt_.bind_int64(2, message_id.get()).ensure();

    if (unique_message_id.is_valid()) {
      add_message_stmt_.bind_int32(3, unique_message_id.get()).ensure();
    } else {
      add_message_stmt_.bind_null(3).ensure();
    }

    if (sender_dialog_id.is_valid()) {
      add_message_stmt_.bind_int64(4, sender_dialog_id.get()).ensure();
    } else {
      add_message_stmt_.bind_null(4).ensure();
    }

    if (random_id != 0) {
      add_message_stmt_.bind_int64(5, random_id).ensure();
    } else {
      add_message_stmt_.bind_null(5).ensure();
    }

    add_message_stmt_.bind_blob(6, data.as_slice()).ensure();

    if (ttl_expires_at != 0) {
      add_message_stmt_.bind_int32(7, ttl_expires_at).ensure();
    } else {
      add_message_stmt_.bind_null(7).ensure();
    }

    if (index_mask != 0) {
      add_message_stmt_.bind_int32(8, index_mask).ensure();
    } else {
      add_message_stmt_.bind_null(8).ensure();
    }
    if (search_id != 0) {
      // add dialog_id to text
      text += PSTRING() << " \a" << dialog_id.get();
      if (index_mask != 0) {
        for (int i = 0; i < MESSAGE_DB_INDEX_COUNT; i++) {
          if ((index_mask & (1 << i))) {
            text += PSTRING() << " \a\a" << i;
          }
        }
      }
      add_message_stmt_.bind_int64(9, search_id).ensure();
    } else {
      text = "";
      add_message_stmt_.bind_null(9).ensure();
    }
    if (!text.empty()) {
      add_message_stmt_.bind_string(10, text).ensure();
    } else {
      add_message_stmt_.bind_null(10).ensure();
    }
    if (notification_id.is_valid()) {
      add_message_stmt_.bind_int32(11, notification_id.get()).ensure();
    } else {
      add_message_stmt_.bind_null(11).ensure();
    }
    if (top_thread_message_id.is_valid()) {
      add_message_stmt_.bind_int64(12, top_thread_message_id.get()).ensure();
    } else {
      add_message_stmt_.bind_null(12).ensure();
    }

    add_message_stmt_.step().ensure();
  }

  void add_scheduled_message(MessageFullId message_full_id, BufferSlice data) final {
    LOG(INFO) << "Add " << message_full_id << " to database";
    auto dialog_id = message_full_id.get_dialog_id();
    auto message_id = message_full_id.get_message_id();
    CHECK(dialog_id.is_valid());
    CHECK(message_id.is_valid_scheduled());
    SCOPE_EXIT {
      add_scheduled_message_stmt_.reset();
    };
    add_scheduled_message_stmt_.bind_int64(1, dialog_id.get()).ensure();
    add_scheduled_message_stmt_.bind_int64(2, message_id.get()).ensure();

    if (message_id.is_scheduled_server()) {
      add_scheduled_message_stmt_.bind_int32(3, message_id.get_scheduled_server_message_id().get()).ensure();
    } else {
      add_scheduled_message_stmt_.bind_null(3).ensure();
    }

    add_scheduled_message_stmt_.bind_blob(4, data.as_slice()).ensure();

    add_scheduled_message_stmt_.step().ensure();
  }

  void delete_message(MessageFullId message_full_id) final {
    LOG(INFO) << "Delete " << message_full_id << " from database";
    auto dialog_id = message_full_id.get_dialog_id();
    auto message_id = message_full_id.get_message_id();
    CHECK(dialog_id.is_valid());
    CHECK(message_id.is_valid() || message_id.is_valid_scheduled());
    bool is_scheduled = message_id.is_scheduled();
    bool is_scheduled_server = is_scheduled && message_id.is_scheduled_server();
    auto &stmt = is_scheduled
                     ? (is_scheduled_server ? delete_scheduled_server_message_stmt_ : delete_scheduled_message_stmt_)
                     : delete_message_stmt_;
    SCOPE_EXIT {
      stmt.reset();
    };
    stmt.bind_int64(1, dialog_id.get()).ensure();
    if (is_scheduled_server) {
      stmt.bind_int32(2, message_id.get_scheduled_server_message_id().get()).ensure();
    } else {
      stmt.bind_int64(2, message_id.get()).ensure();
    }
    stmt.step().ensure();
  }

  void delete_all_dialog_messages(DialogId dialog_id, MessageId from_message_id) final {
    LOG(INFO) << "Delete all messages in " << dialog_id << " up to " << from_message_id << " from database";
    CHECK(dialog_id.is_valid());
    CHECK(from_message_id.is_valid());
    SCOPE_EXIT {
      delete_all_dialog_messages_stmt_.reset();
    };
    delete_all_dialog_messages_stmt_.bind_int64(1, dialog_id.get()).ensure();
    delete_all_dialog_messages_stmt_.bind_int64(2, from_message_id.get()).ensure();
    auto status = delete_all_dialog_messages_stmt_.step();
    if (status.is_error()) {
      LOG(ERROR) << status;
    }
  }

  void delete_dialog_messages_by_sender(DialogId dialog_id, DialogId sender_dialog_id) final {
    LOG(INFO) << "Delete all messages in " << dialog_id << " sent by " << sender_dialog_id << " from database";
    CHECK(dialog_id.is_valid());
    CHECK(sender_dialog_id.is_valid());
    SCOPE_EXIT {
      delete_dialog_messages_by_sender_stmt_.reset();
    };
    delete_dialog_messages_by_sender_stmt_.bind_int64(1, dialog_id.get()).ensure();
    delete_dialog_messages_by_sender_stmt_.bind_int64(2, sender_dialog_id.get()).ensure();
    delete_dialog_messages_by_sender_stmt_.step().ensure();
  }

  Result<MessageDbDialogMessage> get_message(MessageFullId message_full_id) final {
    auto dialog_id = message_full_id.get_dialog_id();
    auto message_id = message_full_id.get_message_id();
    CHECK(dialog_id.is_valid());
    CHECK(message_id.is_valid() || message_id.is_valid_scheduled());
    bool is_scheduled = message_id.is_scheduled();
    bool is_scheduled_server = is_scheduled && message_id.is_scheduled_server();
    auto &stmt = is_scheduled ? (is_scheduled_server ? get_scheduled_server_message_stmt_ : get_scheduled_message_stmt_)
                              : get_message_stmt_;
    SCOPE_EXIT {
      stmt.reset();
    };

    stmt.bind_int64(1, dialog_id.get()).ensure();
    if (is_scheduled_server) {
      stmt.bind_int32(2, message_id.get_scheduled_server_message_id().get()).ensure();
    } else {
      stmt.bind_int64(2, message_id.get()).ensure();
    }
    stmt.step().ensure();
    if (!stmt.has_row()) {
      return Status::Error("Not found");
    }
    MessageId received_message_id(stmt.view_int64(0));
    Slice data = stmt.view_blob(1);
    if (is_scheduled_server) {
      CHECK(received_message_id.is_scheduled());
      CHECK(received_message_id.is_scheduled_server());
      CHECK(received_message_id.get_scheduled_server_message_id() == message_id.get_scheduled_server_message_id());
    } else {
      LOG_CHECK(received_message_id == message_id)
          << received_message_id << ' ' << message_id << ' ' << get_message_info(received_message_id, data, true).first;
    }
    return MessageDbDialogMessage{received_message_id, BufferSlice(data)};
  }

  Result<MessageDbMessage> get_message_by_unique_message_id(ServerMessageId unique_message_id) final {
    if (!unique_message_id.is_valid()) {
      return Status::Error("Invalid unique_message_id");
    }
    SCOPE_EXIT {
      get_message_by_unique_message_id_stmt_.reset();
    };
    get_message_by_unique_message_id_stmt_.bind_int32(1, unique_message_id.get()).ensure();
    get_message_by_unique_message_id_stmt_.step().ensure();
    if (!get_message_by_unique_message_id_stmt_.has_row()) {
      return Status::Error("Not found");
    }
    DialogId dialog_id(get_message_by_unique_message_id_stmt_.view_int64(0));
    MessageId message_id(get_message_by_unique_message_id_stmt_.view_int64(1));
    return MessageDbMessage{dialog_id, message_id, BufferSlice(get_message_by_unique_message_id_stmt_.view_blob(2))};
  }

  Result<MessageDbDialogMessage> get_message_by_random_id(DialogId dialog_id, int64 random_id) final {
    SCOPE_EXIT {
      get_message_by_random_id_stmt_.reset();
    };
    get_message_by_random_id_stmt_.bind_int64(1, dialog_id.get()).ensure();
    get_message_by_random_id_stmt_.bind_int64(2, random_id).ensure();
    get_message_by_random_id_stmt_.step().ensure();
    if (!get_message_by_random_id_stmt_.has_row()) {
      return Status::Error("Not found");
    }
    MessageId message_id(get_message_by_random_id_stmt_.view_int64(0));
    return MessageDbDialogMessage{message_id, BufferSlice(get_message_by_random_id_stmt_.view_blob(1))};
  }

  Result<MessageDbDialogMessage> get_dialog_message_by_date(DialogId dialog_id, MessageId first_message_id,
                                                            MessageId last_message_id, int32 date) final {
    int64 left_message_id = first_message_id.get();
    int64 right_message_id = last_message_id.get();
    LOG_CHECK(left_message_id <= right_message_id) << first_message_id << " " << last_message_id;
    auto first_messages = get_messages_inner(get_messages_stmt_.asc_stmt_, dialog_id, left_message_id - 1, 1);
    if (!first_messages.empty()) {
      MessageId real_first_message_id;
      int32 real_first_message_date;
      std::tie(real_first_message_id, real_first_message_date) = get_message_info(first_messages[0]);
      if (real_first_message_date <= date) {
        // we definitely have at least one suitable message, let's do a binary search
        left_message_id = real_first_message_id.get();

        MessageId prev_found_message_id;
        while (left_message_id <= right_message_id) {
          auto middle_message_id = left_message_id + ((right_message_id - left_message_id) >> 1);
          auto messages = get_messages_inner(get_messages_stmt_.asc_stmt_, dialog_id, middle_message_id, 1);

          MessageId message_id;
          int32 message_date = std::numeric_limits<int32>::max();
          if (!messages.empty()) {
            std::tie(message_id, message_date) = get_message_info(messages[0]);
          }
          if (message_date <= date) {
            left_message_id = message_id.get();
          } else {
            right_message_id = middle_message_id - 1;
          }

          if (prev_found_message_id == message_id) {
            // we may be very close to the result, let's check
            auto left_messages = get_messages_inner(get_messages_stmt_.asc_stmt_, dialog_id, left_message_id - 1, 2);
            CHECK(!left_messages.empty());
            if (left_messages.size() == 1) {
              // only one message has left, result is found
              break;
            }

            MessageId next_message_id;
            int32 next_message_date;
            std::tie(next_message_id, next_message_date) = get_message_info(left_messages[1]);
            if (next_message_date <= date) {
              // next message has lesser date, adjusting left message
              left_message_id = next_message_id.get();
            } else {
              // next message has bigger date, result is found
              break;
            }
          }

          prev_found_message_id = message_id;
        }

        // left_message_id is always an identifier of suitable message, let's return it
        return get_message({dialog_id, MessageId(left_message_id)});
      }
    }

    return Status::Error("Not found");
  }

  vector<MessageDbMessage> get_expiring_messages(int32 expires_till, int32 limit) final {
    SCOPE_EXIT {
      get_expiring_messages_stmt_.reset();
    };

    vector<MessageDbMessage> messages;
    get_expiring_messages_stmt_.bind_int32(1, expires_till).ensure();
    get_expiring_messages_stmt_.bind_int32(2, limit).ensure();
    get_expiring_messages_stmt_.step().ensure();

    while (get_expiring_messages_stmt_.has_row()) {
      DialogId dialog_id(get_expiring_messages_stmt_.view_int64(0));
      MessageId message_id(get_expiring_messages_stmt_.view_int64(1));
      BufferSlice data(get_expiring_messages_stmt_.view_blob(2));
      messages.push_back(MessageDbMessage{dialog_id, message_id, std::move(data)});
      get_expiring_messages_stmt_.step().ensure();
    }

    return messages;
  }

  MessageDbCalendar get_dialog_message_calendar(MessageDbDialogCalendarQuery query) final {
    auto &stmt = get_messages_from_index_stmts_[message_search_filter_index(query.filter)].desc_stmt_;
    SCOPE_EXIT {
      stmt.reset();
    };
    int32 limit = 1000;
    stmt.bind_int64(1, query.dialog_id.get()).ensure();
    stmt.bind_int64(2, query.from_message_id.get()).ensure();
    stmt.bind_int32(3, limit).ensure();

    vector<MessageDbDialogMessage> messages;
    vector<int32> total_counts;
    stmt.step().ensure();
    int32 current_day = std::numeric_limits<int32>::max();
    while (stmt.has_row()) {
      auto data_slice = stmt.view_blob(0);
      MessageId message_id(stmt.view_int64(1));
      auto info = get_message_info(message_id, data_slice, false);
      auto day = (query.tz_offset + info.second) / 86400;
      if (day >= current_day) {
        CHECK(!total_counts.empty());
        total_counts.back()++;
      } else {
        current_day = day;
        messages.push_back(MessageDbDialogMessage{message_id, BufferSlice(data_slice)});
        total_counts.push_back(1);
      }
      stmt.step().ensure();
    }
    return MessageDbCalendar{std::move(messages), std::move(total_counts)};
  }

  Result<MessageDbMessagePositions> get_dialog_sparse_message_positions(
      MessageDbGetDialogSparseMessagePositionsQuery query) final {
    auto &stmt = get_message_ids_stmts_[message_search_filter_index(query.filter)];
    SCOPE_EXIT {
      stmt.reset();
    };
    stmt.bind_int64(1, query.dialog_id.get()).ensure();
    stmt.bind_int64(2, query.from_message_id.get()).ensure();

    vector<MessageId> message_ids;
    stmt.step().ensure();
    while (stmt.has_row()) {
      message_ids.push_back(MessageId(stmt.view_int64(0)));
      stmt.step().ensure();
    }

    MessageDbMessagePositions positions;
    int32 limit = min(query.limit, static_cast<int32>(message_ids.size()));
    if (limit > 0) {
      double delta = static_cast<double>(message_ids.size()) / limit;
      positions.total_count = static_cast<int32>(message_ids.size());
      positions.positions.reserve(limit);
      for (int32 i = 0; i < limit; i++) {
        auto position = static_cast<int32>((i + 0.5) * delta);
        auto message_id = message_ids[position];
        TRY_RESULT(message, get_message({query.dialog_id, message_id}));
        auto date = get_message_info(message).second;
        positions.positions.push_back(MessageDbMessagePosition{position, date, message_id});
      }
    }
    return positions;
  }

  vector<MessageDbDialogMessage> get_messages(MessageDbMessagesQuery query) final {
    if (query.filter != MessageSearchFilter::Empty) {
      return get_messages_from_index(query.dialog_id, query.from_message_id, query.filter, query.offset, query.limit);
    }
    return get_messages_impl(get_messages_stmt_, query.dialog_id, query.from_message_id, query.offset, query.limit);
  }

  vector<MessageDbDialogMessage> get_scheduled_messages(DialogId dialog_id, int32 limit) final {
    return get_messages_inner(get_scheduled_messages_stmt_, dialog_id, std::numeric_limits<int64>::max(), limit);
  }

  vector<MessageDbDialogMessage> get_messages_from_notification_id(DialogId dialog_id,
                                                                   NotificationId from_notification_id,
                                                                   int32 limit) final {
    auto &stmt = get_messages_from_notification_id_stmt_;
    SCOPE_EXIT {
      stmt.reset();
    };
    stmt.bind_int64(1, dialog_id.get()).ensure();
    stmt.bind_int32(2, from_notification_id.get()).ensure();
    stmt.bind_int32(3, limit).ensure();

    vector<MessageDbDialogMessage> result;
    stmt.step().ensure();
    while (stmt.has_row()) {
      auto data_slice = stmt.view_blob(0);
      MessageId message_id(stmt.view_int64(1));
      result.push_back(MessageDbDialogMessage{message_id, BufferSlice(data_slice)});
      LOG(INFO) << "Load " << message_id << " in " << dialog_id << " from database";
      stmt.step().ensure();
    }
    return result;
  }

  static string prepare_query(Slice query) {
    auto is_word_character = [](uint32 a) {
      switch (get_unicode_simple_category(a)) {
        case UnicodeSimpleCategory::Letter:
        case UnicodeSimpleCategory::DecimalNumber:
        case UnicodeSimpleCategory::Number:
          return true;
        default:
          return a == '_';
      }
    };

    const size_t MAX_QUERY_SIZE = 1024;
    query = utf8_truncate(query, MAX_QUERY_SIZE);
    auto buf = StackAllocator::alloc(query.size() * 4 + 100);
    StringBuilder sb(buf.as_slice());
    bool in_word{false};

    for (auto ptr = query.ubegin(), end = query.uend(); ptr < end;) {
      uint32 code;
      auto code_ptr = ptr;
      ptr = next_utf8_unsafe(ptr, &code);
      if (is_word_character(code)) {
        if (!in_word) {
          in_word = true;
          sb << "\"";
        }
        sb << Slice(code_ptr, ptr);
      } else {
        if (in_word) {
          in_word = false;
          sb << "\" ";
        }
      }
    }
    if (in_word) {
      sb << "\" ";
    }

    if (sb.is_error()) {
      LOG(ERROR) << "StringBuilder buffer overflow";
      return "";
    }

    return sb.as_cslice().str();
  }

  MessageDbFtsResult get_messages_fts(MessageDbFtsQuery query) final {
    SCOPE_EXIT {
      get_messages_fts_stmt_.reset();
    };

    LOG(INFO) << tag("query", query.query) << query.dialog_id << tag("filter", query.filter)
              << tag("from_search_id", query.from_search_id) << tag("limit", query.limit);
    string words = prepare_query(query.query);
    LOG(INFO) << tag("from", query.query) << tag("to", words);

    // dialog_id kludge
    if (query.dialog_id.is_valid()) {
      words += PSTRING() << " \"\a" << query.dialog_id.get() << "\"";
    }

    // index_mask kludge
    if (query.filter != MessageSearchFilter::Empty) {
      words += PSTRING() << " \"\a\a" << message_search_filter_index(query.filter) << "\"";
    }

    auto &stmt = get_messages_fts_stmt_;
    stmt.bind_string(1, words).ensure();
    if (query.from_search_id == 0) {
      query.from_search_id = std::numeric_limits<int64>::max();
    }
    stmt.bind_int64(2, query.from_search_id).ensure();
    stmt.bind_int32(3, query.limit).ensure();
    MessageDbFtsResult result;
    auto status = stmt.step();
    if (status.is_error()) {
      LOG(ERROR) << status;
      return result;
    }
    while (stmt.has_row()) {
      DialogId dialog_id(stmt.view_int64(0));
      MessageId message_id(stmt.view_int64(1));
      auto data_slice = stmt.view_blob(2);
      auto search_id = stmt.view_int64(3);
      result.next_search_id = search_id;
      result.messages.push_back(MessageDbMessage{dialog_id, message_id, BufferSlice(data_slice)});
      stmt.step().ensure();
    }
    return result;
  }

  vector<MessageDbDialogMessage> get_messages_from_index(DialogId dialog_id, MessageId from_message_id,
                                                         MessageSearchFilter filter, int32 offset, int32 limit) {
    auto &stmt = get_messages_from_index_stmts_[message_search_filter_index(filter)];
    return get_messages_impl(stmt, dialog_id, from_message_id, offset, limit);
  }

  MessageDbCallsResult get_calls(MessageDbCallsQuery query) final {
    int32 pos;
    if (query.filter == MessageSearchFilter::Call) {
      pos = 0;
    } else if (query.filter == MessageSearchFilter::MissedCall) {
      pos = 1;
    } else {
      UNREACHABLE();
    }

    auto &stmt = get_calls_stmts_[pos];
    SCOPE_EXIT {
      stmt.reset();
    };

    stmt.bind_int32(1, query.from_unique_message_id).ensure();
    stmt.bind_int32(2, query.limit).ensure();

    MessageDbCallsResult result;
    stmt.step().ensure();
    while (stmt.has_row()) {
      DialogId dialog_id(stmt.view_int64(0));
      MessageId message_id(stmt.view_int64(1));
      auto data_slice = stmt.view_blob(2);
      result.messages.push_back(MessageDbMessage{dialog_id, message_id, BufferSlice(data_slice)});
      stmt.step().ensure();
    }
    return result;
  }

  Status begin_write_transaction() final {
    return db_.begin_write_transaction();
  }
  Status commit_transaction() final {
    return db_.commit_transaction();
  }

 private:
  SqliteDb db_;

  SqliteStatement add_message_stmt_;

  SqliteStatement delete_message_stmt_;
  SqliteStatement delete_all_dialog_messages_stmt_;
  SqliteStatement delete_dialog_messages_by_sender_stmt_;

  SqliteStatement get_message_stmt_;
  SqliteStatement get_message_by_random_id_stmt_;
  SqliteStatement get_message_by_unique_message_id_stmt_;
  SqliteStatement get_expiring_messages_stmt_;

  struct GetMessagesStmt {
    SqliteStatement asc_stmt_;
    SqliteStatement desc_stmt_;
  };
  GetMessagesStmt get_messages_stmt_;
  SqliteStatement get_scheduled_messages_stmt_;
  SqliteStatement get_messages_from_notification_id_stmt_;

  std::array<SqliteStatement, MESSAGE_DB_INDEX_COUNT> get_message_ids_stmts_;
  std::array<GetMessagesStmt, MESSAGE_DB_INDEX_COUNT> get_messages_from_index_stmts_;
  std::array<SqliteStatement, 2> get_calls_stmts_;

  SqliteStatement get_messages_fts_stmt_;

  SqliteStatement add_scheduled_message_stmt_;
  SqliteStatement get_scheduled_message_stmt_;
  SqliteStatement get_scheduled_server_message_stmt_;
  SqliteStatement delete_scheduled_message_stmt_;
  SqliteStatement delete_scheduled_server_message_stmt_;

  static vector<MessageDbDialogMessage> get_messages_impl(GetMessagesStmt &stmt, DialogId dialog_id,
                                                          MessageId from_message_id, int32 offset, int32 limit) {
    LOG_CHECK(dialog_id.is_valid()) << dialog_id;
    CHECK(from_message_id.is_valid());

    LOG(INFO) << "Loading messages in " << dialog_id << " from " << from_message_id << " with offset = " << offset
              << " and limit = " << limit;

    auto message_id = from_message_id.get();

    if (message_id >= MessageId::max().get()) {
      message_id--;
    }

    auto left_message_id = message_id;
    auto left_cnt = limit + offset;

    auto right_message_id = message_id - 1;
    auto right_cnt = -offset;

    vector<MessageDbDialogMessage> left;
    vector<MessageDbDialogMessage> right;

    if (left_cnt != 0) {
      if (right_cnt == 1 && false) {
        left_message_id++;
        left_cnt++;
      }

      left = get_messages_inner(stmt.desc_stmt_, dialog_id, left_message_id, left_cnt);

      if (right_cnt == 1 && !left.empty() && false /*get_message_id(left[0].as_slice()) == message_id*/) {
        right_cnt = 0;
      }
    }
    if (right_cnt != 0) {
      right = get_messages_inner(stmt.asc_stmt_, dialog_id, right_message_id, right_cnt);
      std::reverse(right.begin(), right.end());
    }
    if (left.empty()) {
      return right;
    }
    if (right.empty()) {
      return left;
    }

    right.reserve(right.size() + left.size());
    std::move(left.begin(), left.end(), std::back_inserter(right));

    return right;
  }

  static vector<MessageDbDialogMessage> get_messages_inner(SqliteStatement &stmt, DialogId dialog_id,
                                                           int64 from_message_id, int32 limit) {
    SCOPE_EXIT {
      stmt.reset();
    };
    stmt.bind_int64(1, dialog_id.get()).ensure();
    stmt.bind_int64(2, from_message_id).ensure();
    stmt.bind_int32(3, limit).ensure();

    LOG(INFO) << "Begin to load " << limit << " messages in " << dialog_id << " from " << MessageId(from_message_id)
              << " from database";
    vector<MessageDbDialogMessage> result;
    stmt.step().ensure();
    while (stmt.has_row()) {
      auto data_slice = stmt.view_blob(0);
      MessageId message_id(stmt.view_int64(1));
      result.push_back(MessageDbDialogMessage{message_id, BufferSlice(data_slice)});
      LOG(INFO) << "Loaded " << message_id << " in " << dialog_id << " from database";
      stmt.step().ensure();
    }
    return result;
  }

  static std::pair<MessageId, int32> get_message_info(const MessageDbDialogMessage &message, bool from_data = false) {
    return get_message_info(message.message_id, message.data.as_slice(), from_data);
  }

  static std::pair<MessageId, int32> get_message_info(MessageId message_id, Slice data, bool from_data) {
    LogEventParser message_date_parser(data);
    int32 flags;
    int32 flags2 = 0;
    int32 flags3 = 0;
    td::parse(flags, message_date_parser);
    if ((flags & (1 << 29)) != 0) {
      td::parse(flags2, message_date_parser);
      if ((flags2 & (1 << 29)) != 0) {
        td::parse(flags3, message_date_parser);
      }
    }
    bool has_sender = (flags & (1 << 10)) != 0;
    MessageId data_message_id;
    td::parse(data_message_id, message_date_parser);
    UserId sender_user_id;
    if (has_sender) {
      td::parse(sender_user_id, message_date_parser);
    }
    int32 date;
    td::parse(date, message_date_parser);
    LOG(INFO) << "Loaded " << message_id << "(aka " << data_message_id << ") sent at " << date << " by "
              << sender_user_id;
    return {from_data ? data_message_id : message_id, date};
  }
};

std::shared_ptr<MessageDbSyncSafeInterface> create_message_db_sync(
    std::shared_ptr<SqliteConnectionSafe> sqlite_connection) {
  class MessageDbSyncSafe final : public MessageDbSyncSafeInterface {
   public:
    explicit MessageDbSyncSafe(std::shared_ptr<SqliteConnectionSafe> sqlite_connection)
        : lsls_db_([safe_connection = std::move(sqlite_connection)] {
          return make_unique<MessageDbImpl>(safe_connection->get().clone());
        }) {
    }
    MessageDbSyncInterface &get() final {
      return *lsls_db_.get();
    }

   private:
    LazySchedulerLocalStorage<unique_ptr<MessageDbSyncInterface>> lsls_db_;
  };
  return std::make_shared<MessageDbSyncSafe>(std::move(sqlite_connection));
}

class MessageDbAsync final : public MessageDbAsyncInterface {
 public:
  MessageDbAsync(std::shared_ptr<MessageDbSyncSafeInterface> sync_db, int32 scheduler_id) {
    impl_ = create_actor_on_scheduler<Impl>("MessageDbActor", scheduler_id, std::move(sync_db));
  }

  void add_message(MessageFullId message_full_id, ServerMessageId unique_message_id, DialogId sender_dialog_id,
                   int64 random_id, int32 ttl_expires_at, int32 index_mask, int64 search_id, string text,
                   NotificationId notification_id, MessageId top_thread_message_id, BufferSlice data,
                   Promise<> promise) final {
    send_closure_later(impl_, &Impl::add_message, message_full_id, unique_message_id, sender_dialog_id, random_id,
                       ttl_expires_at, index_mask, search_id, std::move(text), notification_id, top_thread_message_id,
                       std::move(data), std::move(promise));
  }
  void add_scheduled_message(MessageFullId message_full_id, BufferSlice data, Promise<> promise) final {
    send_closure_later(impl_, &Impl::add_scheduled_message, message_full_id, std::move(data), std::move(promise));
  }

  void delete_message(MessageFullId message_full_id, Promise<> promise) final {
    send_closure_later(impl_, &Impl::delete_message, message_full_id, std::move(promise));
  }
  void delete_all_dialog_messages(DialogId dialog_id, MessageId from_message_id, Promise<> promise) final {
    send_closure_later(impl_, &Impl::delete_all_dialog_messages, dialog_id, from_message_id, std::move(promise));
  }
  void delete_dialog_messages_by_sender(DialogId dialog_id, DialogId sender_dialog_id, Promise<> promise) final {
    send_closure_later(impl_, &Impl::delete_dialog_messages_by_sender, dialog_id, sender_dialog_id, std::move(promise));
  }

  void get_message(MessageFullId message_full_id, Promise<MessageDbDialogMessage> promise) final {
    send_closure_later(impl_, &Impl::get_message, message_full_id, std::move(promise));
  }
  void get_message_by_unique_message_id(ServerMessageId unique_message_id, Promise<MessageDbMessage> promise) final {
    send_closure_later(impl_, &Impl::get_message_by_unique_message_id, unique_message_id, std::move(promise));
  }
  void get_message_by_random_id(DialogId dialog_id, int64 random_id, Promise<MessageDbDialogMessage> promise) final {
    send_closure_later(impl_, &Impl::get_message_by_random_id, dialog_id, random_id, std::move(promise));
  }
  void get_dialog_message_by_date(DialogId dialog_id, MessageId first_message_id, MessageId last_message_id, int32 date,
                                  Promise<MessageDbDialogMessage> promise) final {
    send_closure_later(impl_, &Impl::get_dialog_message_by_date, dialog_id, first_message_id, last_message_id, date,
                       std::move(promise));
  }

  void get_dialog_message_calendar(MessageDbDialogCalendarQuery query, Promise<MessageDbCalendar> promise) final {
    send_closure_later(impl_, &Impl::get_dialog_message_calendar, std::move(query), std::move(promise));
  }

  void get_dialog_sparse_message_positions(MessageDbGetDialogSparseMessagePositionsQuery query,
                                           Promise<MessageDbMessagePositions> promise) final {
    send_closure_later(impl_, &Impl::get_dialog_sparse_message_positions, std::move(query), std::move(promise));
  }

  void get_messages(MessageDbMessagesQuery query, Promise<vector<MessageDbDialogMessage>> promise) final {
    send_closure_later(impl_, &Impl::get_messages, std::move(query), std::move(promise));
  }
  void get_scheduled_messages(DialogId dialog_id, int32 limit, Promise<vector<MessageDbDialogMessage>> promise) final {
    send_closure_later(impl_, &Impl::get_scheduled_messages, dialog_id, limit, std::move(promise));
  }
  void get_messages_from_notification_id(DialogId dialog_id, NotificationId from_notification_id, int32 limit,
                                         Promise<vector<MessageDbDialogMessage>> promise) final {
    send_closure_later(impl_, &Impl::get_messages_from_notification_id, dialog_id, from_notification_id, limit,
                       std::move(promise));
  }
  void get_calls(MessageDbCallsQuery query, Promise<MessageDbCallsResult> promise) final {
    send_closure_later(impl_, &Impl::get_calls, std::move(query), std::move(promise));
  }
  void get_messages_fts(MessageDbFtsQuery query, Promise<MessageDbFtsResult> promise) final {
    send_closure_later(impl_, &Impl::get_messages_fts, std::move(query), std::move(promise));
  }
  void get_expiring_messages(int32 expires_till, int32 limit, Promise<vector<MessageDbMessage>> promise) final {
    send_closure_later(impl_, &Impl::get_expiring_messages, expires_till, limit, std::move(promise));
  }

  void close(Promise<> promise) final {
    send_closure_later(impl_, &Impl::close, std::move(promise));
  }

  void force_flush() final {
    send_closure_later(impl_, &Impl::force_flush);
  }

 private:
  class Impl final : public Actor {
   public:
    explicit Impl(std::shared_ptr<MessageDbSyncSafeInterface> sync_db_safe) : sync_db_safe_(std::move(sync_db_safe)) {
    }
    void add_message(MessageFullId message_full_id, ServerMessageId unique_message_id, DialogId sender_dialog_id,
                     int64 random_id, int32 ttl_expires_at, int32 index_mask, int64 search_id, string text,
                     NotificationId notification_id, MessageId top_thread_message_id, BufferSlice data,
                     Promise<> promise) {
      add_write_query([this, message_full_id, unique_message_id, sender_dialog_id, random_id, ttl_expires_at,
                       index_mask, search_id, text = std::move(text), notification_id, top_thread_message_id,
                       data = std::move(data), promise = std::move(promise)](Unit) mutable {
        sync_db_->add_message(message_full_id, unique_message_id, sender_dialog_id, random_id, ttl_expires_at,
                              index_mask, search_id, std::move(text), notification_id, top_thread_message_id,
                              std::move(data));
        on_write_result(std::move(promise));
      });
    }
    void add_scheduled_message(MessageFullId message_full_id, BufferSlice data, Promise<> promise) {
      add_write_query([this, message_full_id, promise = std::move(promise), data = std::move(data)](Unit) mutable {
        sync_db_->add_scheduled_message(message_full_id, std::move(data));
        on_write_result(std::move(promise));
      });
    }

    void delete_message(MessageFullId message_full_id, Promise<> promise) {
      add_write_query([this, message_full_id, promise = std::move(promise)](Unit) mutable {
        sync_db_->delete_message(message_full_id);
        on_write_result(std::move(promise));
      });
    }

    void on_write_result(Promise<Unit> &&promise) {
      // We are inside a transaction and don't know how to handle errors
      finished_writes_.push_back(std::move(promise));
    }

    void delete_all_dialog_messages(DialogId dialog_id, MessageId from_message_id, Promise<> promise) {
      add_read_query();
      sync_db_->delete_all_dialog_messages(dialog_id, from_message_id);
      promise.set_value(Unit());
    }

    void delete_dialog_messages_by_sender(DialogId dialog_id, DialogId sender_dialog_id, Promise<> promise) {
      add_read_query();
      sync_db_->delete_dialog_messages_by_sender(dialog_id, sender_dialog_id);
      promise.set_value(Unit());
    }

    void get_message(MessageFullId message_full_id, Promise<MessageDbDialogMessage> promise) {
      add_read_query();
      promise.set_result(sync_db_->get_message(message_full_id));
    }
    void get_message_by_unique_message_id(ServerMessageId unique_message_id, Promise<MessageDbMessage> promise) {
      add_read_query();
      promise.set_result(sync_db_->get_message_by_unique_message_id(unique_message_id));
    }
    void get_message_by_random_id(DialogId dialog_id, int64 random_id, Promise<MessageDbDialogMessage> promise) {
      add_read_query();
      promise.set_result(sync_db_->get_message_by_random_id(dialog_id, random_id));
    }
    void get_dialog_message_by_date(DialogId dialog_id, MessageId first_message_id, MessageId last_message_id,
                                    int32 date, Promise<MessageDbDialogMessage> promise) {
      add_read_query();
      promise.set_result(sync_db_->get_dialog_message_by_date(dialog_id, first_message_id, last_message_id, date));
    }

    void get_dialog_message_calendar(MessageDbDialogCalendarQuery query, Promise<MessageDbCalendar> promise) {
      add_read_query();
      promise.set_value(sync_db_->get_dialog_message_calendar(std::move(query)));
    }

    void get_dialog_sparse_message_positions(MessageDbGetDialogSparseMessagePositionsQuery query,
                                             Promise<MessageDbMessagePositions> promise) {
      add_read_query();
      promise.set_result(sync_db_->get_dialog_sparse_message_positions(std::move(query)));
    }

    void get_messages(MessageDbMessagesQuery query, Promise<vector<MessageDbDialogMessage>> promise) {
      add_read_query();
      promise.set_value(sync_db_->get_messages(std::move(query)));
    }
    void get_scheduled_messages(DialogId dialog_id, int32 limit, Promise<vector<MessageDbDialogMessage>> promise) {
      add_read_query();
      promise.set_value(sync_db_->get_scheduled_messages(dialog_id, limit));
    }
    void get_messages_from_notification_id(DialogId dialog_id, NotificationId from_notification_id, int32 limit,
                                           Promise<vector<MessageDbDialogMessage>> promise) {
      add_read_query();
      promise.set_value(sync_db_->get_messages_from_notification_id(dialog_id, from_notification_id, limit));
    }
    void get_calls(MessageDbCallsQuery query, Promise<MessageDbCallsResult> promise) {
      add_read_query();
      promise.set_value(sync_db_->get_calls(std::move(query)));
    }
    void get_messages_fts(MessageDbFtsQuery query, Promise<MessageDbFtsResult> promise) {
      add_read_query();
      promise.set_value(sync_db_->get_messages_fts(std::move(query)));
    }
    void get_expiring_messages(int32 expires_till, int32 limit, Promise<vector<MessageDbMessage>> promise) {
      add_read_query();
      promise.set_value(sync_db_->get_expiring_messages(expires_till, limit));
    }

    void close(Promise<> promise) {
      do_flush();
      sync_db_safe_.reset();
      sync_db_ = nullptr;
      promise.set_value(Unit());
      stop();
    }

    void force_flush() {
      do_flush();
      LOG(INFO) << "MessageDb flushed";
    }

   private:
    std::shared_ptr<MessageDbSyncSafeInterface> sync_db_safe_;
    MessageDbSyncInterface *sync_db_ = nullptr;

    static constexpr size_t MAX_PENDING_QUERIES_COUNT{50};
    static constexpr double MAX_PENDING_QUERIES_DELAY{0.01};

    //NB: order is important, destructor of pending_writes_ will change finished_writes_
    vector<Promise<Unit>> finished_writes_;
    vector<Promise<Unit>> pending_writes_;  // TODO use Action
    double wakeup_at_ = 0;

    template <class F>
    void add_write_query(F &&f) {
      pending_writes_.push_back(PromiseCreator::lambda(std::forward<F>(f)));
      if (pending_writes_.size() > MAX_PENDING_QUERIES_COUNT) {
        do_flush();
        wakeup_at_ = 0;
      } else if (wakeup_at_ == 0) {
        wakeup_at_ = Time::now_cached() + MAX_PENDING_QUERIES_DELAY;
      }
      if (wakeup_at_ != 0) {
        set_timeout_at(wakeup_at_);
      }
    }
    void add_read_query() {
      do_flush();
    }
    void do_flush() {
      if (pending_writes_.empty()) {
        return;
      }
      sync_db_->begin_write_transaction().ensure();
      set_promises(pending_writes_);
      sync_db_->commit_transaction().ensure();
      set_promises(finished_writes_);
      cancel_timeout();
    }
    void timeout_expired() final {
      do_flush();
    }

    void start_up() final {
      sync_db_ = &sync_db_safe_->get();
    }
  };
  ActorOwn<Impl> impl_;
};

std::shared_ptr<MessageDbAsyncInterface> create_message_db_async(std::shared_ptr<MessageDbSyncSafeInterface> sync_db,
                                                                 int32 scheduler_id) {
  return std::make_shared<MessageDbAsync>(std::move(sync_db), scheduler_id);
}

}  // namespace td
