//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Client.h"
#include "td/telegram/ClientActor.h"
#include "td/telegram/td_api_json.h"

#include "td/net/HttpQuery.h"
#include "td/net/HttpReader.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "memprof/memprof.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/CombinedLog.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/ExitGuard.h"
#include "td/utils/FileLog.h"
#include "td/utils/filesystem.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/format.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/NullLog.h"
#include "td/utils/OptionParser.h"
#include "td/utils/port/detail/ThreadIdGuard.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/port/signals.h"
#include "td/utils/port/Stat.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/TsLog.h"
#include "td/utils/utf8.h"

#ifndef USE_READLINE
#include "td/utils/find_boundary.h"
#endif

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <iostream>
#include <limits>
#include <locale>
#include <memory>
#include <queue>
#include <tuple>
#include <utility>

#ifdef USE_READLINE
/* Standard readline include files. */
#include <readline/history.h>
#include <readline/readline.h>
#endif

namespace td {

static void dump_memory_usage() {
  if (is_memprof_on()) {
    LOG(WARNING) << "Memory dump:";
    clear_thread_locals();
    std::vector<AllocInfo> alloc_info;
    dump_alloc([&](const AllocInfo &info) { alloc_info.push_back(info); });
    std::sort(alloc_info.begin(), alloc_info.end(),
              [](const AllocInfo &lhs, const AllocInfo &rhs) { return lhs.size > rhs.size; });
    size_t total_size = 0;
    size_t other_size = 0;
    int cnt = 0;
    for (auto &info : alloc_info) {
      if (cnt++ < 50) {
        LOG(WARNING) << format::as_size(info.size) << format::as_array(info.backtrace);
      } else {
        other_size += info.size;
      }
      total_size += info.size;
    }
    LOG(WARNING) << tag("other", format::as_size(other_size));
    LOG(WARNING) << tag("total", format::as_size(total_size));
    LOG(WARNING) << tag("total traces", get_ht_size());
    LOG(WARNING) << tag("fast_backtrace_success_rate", get_fast_backtrace_success_rate());
  }
}

#ifdef USE_READLINE
const char *prompt = "td_cli> ";
static int32 saved_point;
static string saved_line;
static std::atomic_flag readline_lock = ATOMIC_FLAG_INIT;

static void deactivate_readline() {
  while (readline_lock.test_and_set(std::memory_order_acquire)) {
    // spin
  }

  saved_point = rl_point;
  saved_line = string(rl_line_buffer, rl_end);

  rl_set_prompt("");
  rl_replace_line("", 0);
  rl_redisplay();
}

static void reactivate_readline() {
  rl_set_prompt(prompt);
  rl_replace_line(saved_line.c_str(), 0);
  rl_point = saved_point;
  rl_redisplay();

  readline_lock.clear(std::memory_order_release);
}

static char *command_generator(const char *text, int state) {
  static const vector<CSlice> commands{"Search",
                                       "SearchA",
                                       "SearchM",
                                       "SearchP",
                                       "SearchG",
                                       "SearchC",
                                       "SearchAudio",
                                       "SearchDocument",
                                       "SearchPhoto",
                                       "SearchChatPhoto",
                                       "GetChatAdministrators",
                                       "GetSupergroupAdministrators",
                                       "GetSupergroupBanned",
                                       "GetSupergroupBots",
                                       "GetSupergroupContacts",
                                       "GetSupergroupMembers",
                                       "GetSupergroupRestricted",
                                       "SearchSupergroupMembers",
                                       "SearchSupergroupMentions"};
  static size_t cmd_i;
  if (state == 0) {
    cmd_i = 0;
  }

  while (cmd_i < commands.size()) {
    const char *a = commands[cmd_i++].c_str();
    const char *b = text;
    const char *c = b;
    while (*c && to_lower(*c) == *c) {
      c++;
    }
    bool only_lowercase = !is_alpha(*c);
    while (*a && *b) {
      if (*a == *b || (only_lowercase && *a == to_upper(*b))) {
        b++;
      }
      a++;
    }
    if (*b == 0) {
// TODO call to strdup is completely wrong. Readline will try to call std::free() on the returned char*,
// which may be incompatible with the std::malloc() called by strdup
// It is especially likely to happen if Readline is used as dynamic library
// Unfortunately Readline doesn't provide memory allocation functions/memory deallocation callbacks to fix this
#if TD_MSVC
      return _strdup(commands[cmd_i - 1].c_str());
#else
      return strdup(commands[cmd_i - 1].c_str());
#endif
    }
  }
  return nullptr;
}

static char **tg_cli_completion(const char *text, int start, int end) {
  char **matches = nullptr;
  if (start == 0) {
    matches = rl_completion_matches(text, command_generator);
  }
  return matches;
}
#endif

class CliLog final : public LogInterface {
  void do_append(int log_level, CSlice slice) final {
#ifdef USE_READLINE
    deactivate_readline();
    SCOPE_EXIT {
      reactivate_readline();
    };
#endif
    default_log_interface->do_append(log_level, slice);
  }
};

static CombinedLog combined_log;

struct SendMessageInfo {
  double start_time = 0;
  double quick_ack_time = 0;
  double ack_time = 0;
  bool empty() const {
    return quick_ack_time != 0 || ack_time != 0;
  }
};

StringBuilder &operator<<(StringBuilder &sb, const SendMessageInfo &info) {
  sb << format::cond(info.quick_ack_time != 0, tag("quick_ack", info.quick_ack_time - info.start_time));
  sb << format::cond(info.ack_time != 0, tag("ack", info.ack_time - info.start_time));
  return sb;
}

class CliClient final : public Actor {
 public:
  CliClient(ConcurrentScheduler *scheduler, bool use_test_dc, bool get_chat_list, bool disable_network, int32 api_id,
            string api_hash)
      : scheduler_(scheduler)
      , use_test_dc_(use_test_dc)
      , get_chat_list_(get_chat_list)
      , disable_network_(disable_network)
      , api_id_(api_id)
      , api_hash_(std::move(api_hash)) {
  }

  static void quit_instance() {
    instance_->quit();
  }

 private:
  void start_up() final {
    yield();
  }

  FlatHashMap<uint64, SendMessageInfo> query_id_to_send_message_info_;
  FlatHashMap<uint64, SendMessageInfo> message_id_to_send_message_info_;

  struct User {
    string first_name;
    string last_name;
    string username;
  };

  FlatHashMap<int64, unique_ptr<User>> users_;
  FlatHashMap<string, int64> username_to_user_id_;

  vector<string> authentication_tokens_;

  void register_user(const td_api::user &user) {
    auto &new_user_ptr = users_[user.id_];
    if (new_user_ptr == nullptr) {
      new_user_ptr = make_unique<User>();
    }
    User &new_user = *new_user_ptr;
    new_user.first_name = user.first_name_;
    new_user.last_name = user.last_name_;
    if (user.usernames_ != nullptr) {
      for (auto &username : user.usernames_->active_usernames_) {
        username_to_user_id_[to_lower(username)] = user.id_;
      }
    }
  }

  void print_user(Logger &log, int64 user_id, bool full = false) {
    const User *user = users_[user_id].get();
    CHECK(user != nullptr);
    log << user->first_name << " " << user->last_name << " #" << user_id;
  }

  void update_users(const td_api::users &users) {
    Logger log{*log_interface, LogOptions::plain(), VERBOSITY_NAME(PLAIN)};
    for (auto &user_id : users.user_ids_) {
      if (user_id == 0) {
        continue;
      }
      print_user(log, user_id);
      log << "\n";
    }
  }

  FlatHashMap<string, int64> username_to_supergroup_id_;
  void register_supergroup(const td_api::supergroup &supergroup) {
    if (supergroup.usernames_ != nullptr) {
      for (auto &username : supergroup.usernames_->active_usernames_) {
        username_to_supergroup_id_[to_lower(username)] = supergroup.id_;
      }
    }
  }

  void update_option(const td_api::updateOption &option) {
    if (option.name_ == "my_id" && option.value_->get_id() == td_api::optionValueInteger::ID) {
      my_id_ = static_cast<const td_api::optionValueInteger *>(option.value_.get())->value_;
      LOG(INFO) << "Set my user identifier to " << my_id_;
    }
    if (option.name_ == "authentication_token" && option.value_->get_id() == td_api::optionValueString::ID) {
      authentication_tokens_.insert(authentication_tokens_.begin(),
                                    static_cast<const td_api::optionValueString *>(option.value_.get())->value_);
    }
  }

  int64 get_log_chat_id_ = 0;
  void on_get_chat_events(const td_api::chatEvents &events) {
    if (get_log_chat_id_ != 0) {
      int64 last_event_id = 0;
      for (auto &event : events.events_) {
        if (event->member_id_->get_id() == td_api::messageSenderUser::ID) {
          LOG(PLAIN) << event->date_ << ' '
                     << static_cast<const td_api::messageSenderUser &>(*event->member_id_).user_id_;
        }
        last_event_id = event->id_;
      }

      if (last_event_id > 0) {
        send_request(
            td_api::make_object<td_api::getChatEventLog>(get_log_chat_id_, "", last_event_id, 100, nullptr, Auto()));
      } else {
        get_log_chat_id_ = 0;
      }
    }
  }

  int64 get_history_chat_id_ = 0;
  int64 search_chat_id_ = 0;
  void on_get_messages(const td_api::messages &messages) {
    if (get_history_chat_id_ != 0) {
      int64 last_message_id = 0;
      int32 last_message_date = 0;
      for (auto &m : messages.messages_) {
        // LOG(PLAIN) << to_string(m);
        if (m->content_->get_id() == td_api::messageText::ID) {
          LOG(PLAIN) << oneline(static_cast<const td_api::messageText *>(m->content_.get())->text_->text_) << "\n";
        }
        last_message_id = m->id_;
        last_message_date = m->date_;
      }

      if (last_message_id > 0 && last_message_date > 1660000000) {
        send_request(td_api::make_object<td_api::getChatHistory>(get_history_chat_id_, last_message_id, 0, 100, false));
      } else {
        get_history_chat_id_ = 0;
      }
    }
    if (search_chat_id_ != 0) {
      if (!messages.messages_.empty()) {
        auto last_message_id = messages.messages_.back()->id_;
        LOG(ERROR) << (last_message_id >> 20);
        send_request(td_api::make_object<td_api::searchChatMessages>(
            search_chat_id_, string(), nullptr, last_message_id, 0, 100, as_search_messages_filter("pvi"), 0,
            get_saved_messages_topic_id()));
      } else {
        search_chat_id_ = 0;
      }
    }
  }

  void on_get_message(const td_api::message &message) {
    if (message.sending_state_ != nullptr &&
        message.sending_state_->get_id() == td_api::messageSendingStatePending::ID) {
      // send_request(td_api::make_object<td_api::deleteMessages>(message.chat_id_, vector<int64>{message.id_}, true));
    }
  }

  void on_get_file(const td_api::file &file) {
    if (being_downloaded_files_.count(file.id_) == 0 && file.local_->is_downloading_active_) {
      being_downloaded_files_[file.id_] = Time::now();
    }

    if (being_downloaded_files_.count(file.id_) != 0 && !file.local_->is_downloading_active_) {
      double elapsed_time = Time::now() - being_downloaded_files_[file.id_];
      being_downloaded_files_.erase(file.id_);
      if (file.local_->is_downloading_completed_) {
        LOG(ERROR) << "File " << file.id_ << " was downloaded in " << elapsed_time << " seconds";
      } else {
        LOG(ERROR) << "File " << file.id_ << " has failed to download in " << elapsed_time << " seconds";
      }
    }
  }

  struct FileGeneration {
    int64 id = 0;
    string destination;
    string source;
    int64 part_size = 0;
    int64 local_size = 0;
    int64 size = 0;
    bool test_local_size_decrease = false;
  };

  vector<FileGeneration> pending_file_generations_;

  void on_file_generation_start(const td_api::updateFileGenerationStart &update) {
    FileGeneration file_generation;
    file_generation.id = update.generation_id_;
    file_generation.destination = update.destination_path_;
    if (update.conversion_ == "#url#" || update.conversion_ == "url") {
      // TODO: actually download
      file_generation.source = "test.jpg";
      file_generation.part_size = 1000000;
    } else if (update.conversion_ == "skip") {
      return;
    } else {
      file_generation.source = update.original_path_;
      file_generation.part_size = to_integer<int64>(update.conversion_);
      file_generation.test_local_size_decrease = !update.conversion_.empty() && update.conversion_.back() == 't';
    }

    auto r_stat = stat(file_generation.source);
    if (r_stat.is_ok()) {
      auto size = r_stat.ok().size_;
      if (size <= 0 || size > (static_cast<int64>(4000) << 20)) {
        r_stat = Status::Error(400, size == 0 ? Slice("File is empty") : Slice("File is too big"));
      }
    }
    if (r_stat.is_ok()) {
      file_generation.size = narrow_cast<int32>(r_stat.ok().size_);
      if (file_generation.part_size <= 0) {
        file_generation.part_size = file_generation.size;
      }
      pending_file_generations_.push_back(std::move(file_generation));
      timeout_expired();
    } else {
      send_request(td_api::make_object<td_api::finishFileGeneration>(
          update.generation_id_, td_api::make_object<td_api::error>(400, r_stat.error().message().str())));
    }
  }

  void on_update_authorization_state(td_api::object_ptr<td_api::AuthorizationState> &&state) {
    authorization_state_ = std::move(state);
    switch (authorization_state_->get_id()) {
      case td_api::authorizationStateWaitTdlibParameters::ID: {
        auto request = td_api::make_object<td_api::setTdlibParameters>();
        // request->database_encryption_key_ = "!";
        request->use_test_dc_ = use_test_dc_;
        request->use_message_database_ = true;
        request->use_chat_info_database_ = true;
        request->use_secret_chats_ = true;
        request->api_id_ = api_id_;
        request->api_hash_ = api_hash_;
        request->system_language_code_ = "en";
        request->device_model_ = "Desktop";
        request->application_version_ = "1.0";
        send_request(
            td_api::make_object<td_api::setOption>("use_pfs", td_api::make_object<td_api::optionValueBoolean>(true)));
        send_request(std::move(request));
        break;
      }
      case td_api::authorizationStateReady::ID:
        LOG(INFO) << "Logged in";
        break;
      case td_api::authorizationStateClosed::ID:
        LOG(WARNING) << "Td closed";
        td_client_.reset();
        if (!close_flag_) {
          create_td("ClientActor3");
        }
        break;
      default:
        break;
    }
  }

  static char get_delimiter(Slice str) {
    FlatHashSet<char> chars;
    for (auto c : trim(str)) {
      if (!is_alnum(c) && c != '_' && c != '-' && c != '@' && c != '.' && c != '/' && c != '\0' && c != '$' &&
          static_cast<uint8>(c) <= 127) {
        chars.insert(c);
      }
    }
    if (chars.empty()) {
      return ' ';
    }
    if (chars.size() == 1) {
      return *chars.begin();
    }
    LOG(ERROR) << "Failed to determine delimiter in \"" << str << '"';
    return ' ';
  }

  static vector<Slice> autosplit(Slice str) {
    return full_split(trim(str), get_delimiter(str));
  }

  static vector<string> autosplit_str(Slice str) {
    return transform(autosplit(str), [](Slice slice) { return slice.str(); });
  }

  int64 as_chat_id(Slice str) const {
    str = trim(str);
    if (str == "me") {
      return my_id_;
    }
    if (str == ".") {
      return opened_chat_id_;
    }
    if (str[0] == '@') {
      str.remove_prefix(1);
    }
    if (is_alpha(str[0])) {
      auto it = username_to_user_id_.find(to_lower(str));
      if (it != username_to_user_id_.end()) {
        return it->second;
      }
      auto it2 = username_to_supergroup_id_.find(to_lower(str));
      if (it2 != username_to_supergroup_id_.end()) {
        auto supergroup_id = it2->second;
        return static_cast<int64>(-1000'000'000'000ll) - supergroup_id;
      }
      LOG(ERROR) << "Can't resolve " << str;
      return 0;
    }
    return to_integer<int64>(str);
  }

  static int32 as_chat_folder_id(Slice str) {
    return to_integer<int32>(trim(str));
  }

  static vector<int32> as_chat_folder_ids(Slice chat_folder_ids) {
    return transform(autosplit(chat_folder_ids), as_chat_folder_id);
  }

  static td_api::object_ptr<td_api::ChatList> as_chat_list(string chat_list) {
    if (!chat_list.empty() && chat_list.back() == 'a') {
      return td_api::make_object<td_api::chatListArchive>();
    }
    if (chat_list.find('-') != string::npos) {
      return td_api::make_object<td_api::chatListFolder>(as_chat_folder_id(chat_list.substr(chat_list.find('-') + 1)));
    }
    return td_api::make_object<td_api::chatListMain>();
  }

  static td_api::object_ptr<td_api::StoryList> as_story_list(string story_list) {
    if (story_list.empty() || story_list.back() == 'e') {
      return nullptr;
    }
    if (story_list.back() == 'a') {
      return td_api::make_object<td_api::storyListArchive>();
    }
    return td_api::make_object<td_api::storyListMain>();
  }

  static td_api::object_ptr<td_api::BlockList> as_block_list(string block_list) {
    if (block_list.empty()) {
      return nullptr;
    }
    if (block_list.back() == 's') {
      return td_api::make_object<td_api::blockListStories>();
    }
    return td_api::make_object<td_api::blockListMain>();
  }

  vector<int64> as_chat_ids(Slice chat_ids) const {
    return transform(autosplit(chat_ids), [this](Slice str) { return as_chat_id(str); });
  }

  static int64 as_message_id(Slice str) {
    str = trim(str);
    if (!str.empty() && str.back() == 's') {
      return to_integer<int64>(str) << 20;
    }
    return to_integer<int64>(str);
  }

  static vector<int64> as_message_ids(Slice message_ids) {
    return transform(autosplit(message_ids), as_message_id);
  }

  static int64 as_message_thread_id(Slice str) {
    return as_message_id(str);
  }

  static vector<int64> as_message_thread_ids(Slice str) {
    return as_message_ids(str);
  }

  td_api::object_ptr<td_api::MessageSender> as_message_sender(Slice sender_id) const {
    sender_id = trim(sender_id);
    auto user_id = as_user_id(sender_id, true);
    if (sender_id.empty() || user_id > 0) {
      return td_api::make_object<td_api::messageSenderUser>(user_id);
    } else {
      return td_api::make_object<td_api::messageSenderChat>(as_chat_id(sender_id));
    }
  }

  static int32 as_story_id(Slice str) {
    return to_integer<int32>(trim(str));
  }

  td_api::object_ptr<td_api::businessRecipients> as_business_recipients(string chat_ids) const {
    return td_api::make_object<td_api::businessRecipients>(as_chat_ids(chat_ids), vector<int64>(), false, false, false,
                                                           false, true);
  }

  static td_api::object_ptr<td_api::StickerFormat> as_sticker_format(string sticker_format) {
    if (!sticker_format.empty() && sticker_format.back() == 'a') {
      return td_api::make_object<td_api::stickerFormatTgs>();
    }
    if (!sticker_format.empty() && sticker_format.back() == 'v') {
      return td_api::make_object<td_api::stickerFormatWebm>();
    }
    return td_api::make_object<td_api::stickerFormatWebp>();
  }

  static td_api::object_ptr<td_api::StickerType> as_sticker_type(string sticker_type) {
    if (!sticker_type.empty() && sticker_type.back() == 'e') {
      return td_api::make_object<td_api::stickerTypeCustomEmoji>();
    }
    if (!sticker_type.empty() && sticker_type.back() == 'm') {
      return td_api::make_object<td_api::stickerTypeMask>();
    }
    return Random::fast_bool() ? nullptr : td_api::make_object<td_api::stickerTypeRegular>();
  }

  static td_api::object_ptr<td_api::maskPosition> as_mask_position(string sticker_type) {
    if (!sticker_type.empty() && sticker_type.back() == 'm') {
      auto position = td_api::make_object<td_api::maskPosition>(td_api::make_object<td_api::maskPointEyes>(),
                                                                Random::fast(-5, 5), Random::fast(-5, 5), 1.0);
      return Random::fast_bool() ? nullptr : std::move(position);
    }
    return nullptr;
  }

  static int32 as_limit(Slice str, int32 default_limit = 10) {
    if (str.empty()) {
      return default_limit;
    }
    return to_integer<int32>(trim(str));
  }

  int64 as_user_id(Slice str, bool expect_error = false) const {
    str = trim(str);
    if (str == "me") {
      return my_id_;
    }
    if (str == ".") {
      return opened_chat_id_;
    }
    if (str[0] == '@') {
      str.remove_prefix(1);
    }
    if (is_alpha(str[0])) {
      auto it = username_to_user_id_.find(to_lower(str));
      if (it != username_to_user_id_.end()) {
        return it->second;
      }
      if (!expect_error) {
        LOG(ERROR) << "Can't find user " << str;
      }
      return 0;
    }
    return to_integer<int64>(str);
  }

  vector<int64> as_user_ids(Slice user_ids) const {
    return transform(autosplit(user_ids), [this](Slice str) { return as_user_id(str); });
  }

  int64 as_basic_group_id(Slice str) const {
    str = trim(str);
    auto result = to_integer<int64>(str);
    if (str == ".") {
      result = opened_chat_id_;
    }
    if (result < 0) {
      return -result;
    }
    return result;
  }

  int64 as_supergroup_id(Slice str) const {
    str = trim(str);
    if (str[0] == '@') {
      str.remove_prefix(1);
    }
    if (is_alpha(str[0])) {
      auto it = username_to_supergroup_id_.find(to_lower(str));
      if (it == username_to_supergroup_id_.end()) {
        return 0;
      }
      return it->second;
    }
    auto result = to_integer<int64>(str);
    if (str == ".") {
      result = opened_chat_id_;
    }
    auto shift = static_cast<int64>(-1000000000000ll);
    if (result <= shift) {
      return shift - result;
    }
    return result;
  }

  int32 as_secret_chat_id(Slice str) const {
    str = trim(str);
    auto result = to_integer<int64>(str);
    if (str == ".") {
      result = opened_chat_id_;
    }
    auto shift = static_cast<int64>(-2000000000000ll);
    if (result <= shift + std::numeric_limits<int32>::max()) {
      return static_cast<int32>(result - shift);
    }
    return static_cast<int32>(result);
  }

  static int32 as_file_id(Slice str) {
    return to_integer<int32>(trim(str));
  }

  static vector<int32> as_file_ids(Slice str) {
    return transform(autosplit(str), as_file_id);
  }

  static td_api::object_ptr<td_api::InputFile> as_input_file_id(Slice str) {
    return td_api::make_object<td_api::inputFileId>(as_file_id(str));
  }

  static td_api::object_ptr<td_api::InputFile> as_local_file(string path) {
    return td_api::make_object<td_api::inputFileLocal>(trim(std::move(path)));
  }

  static td_api::object_ptr<td_api::InputFile> as_remote_file(string id) {
    return td_api::make_object<td_api::inputFileRemote>(trim(std::move(id)));
  }

  static td_api::object_ptr<td_api::InputFile> as_generated_file(string original_path, string conversion,
                                                                 int64 expected_size = 0) {
    return td_api::make_object<td_api::inputFileGenerated>(trim(std::move(original_path)), trim(std::move(conversion)),
                                                           expected_size);
  }

  static td_api::object_ptr<td_api::InputFile> as_input_file(Slice str) {
    str = trim(str);
    if ((str.size() >= 20 && is_base64url(str)) || begins_with(str, "http")) {
      return as_remote_file(str.str());
    }
    auto r_file_id = to_integer_safe<int32>(str);
    if (r_file_id.is_ok()) {
      return as_input_file_id(str);
    }
    if (str.find(';') < str.size()) {
      auto res = split(str, ';');
      return as_generated_file(res.first.str(), res.second.str());
    }
    return as_local_file(str.str());
  }

  td_api::object_ptr<td_api::formattedText> get_caption() const {
    if (caption_.empty()) {
      return nullptr;
    }
    return as_caption(caption_);
  }

  td_api::object_ptr<td_api::InputFile> get_input_cover() const {
    if (cover_.empty()) {
      return nullptr;
    }
    return as_input_file(cover_);
  }

  td_api::object_ptr<td_api::inputThumbnail> get_input_thumbnail() const {
    if (thumbnail_.empty()) {
      return nullptr;
    }
    return td_api::make_object<td_api::inputThumbnail>(as_input_file(thumbnail_), 0, 0);
  }

  vector<int32> get_added_sticker_file_ids() const {
    return added_sticker_file_ids_;
  }

  struct CallId {
    int32 call_id = 0;

    operator int32() const {
      return call_id;
    }
  };

  void get_args(string &args, CallId &arg) const {
    arg.call_id = to_integer<int32>(trim(args));
  }

  struct GroupCallId {
    int32 group_call_id = 0;

    operator int32() const {
      return group_call_id;
    }
  };

  void get_args(string &args, GroupCallId &arg) const {
    arg.group_call_id = to_integer<int32>(trim(args));
  }

  static int32 as_proxy_id(string str) {
    return to_integer<int32>(trim(std::move(str)));
  }

  static int64 as_custom_emoji_id(Slice str) {
    return to_integer<int64>(trim(str));
  }

  static td_api::object_ptr<td_api::location> as_location(const string &latitude, const string &longitude,
                                                          const string &accuracy) {
    if (trim(latitude).empty() && trim(longitude).empty()) {
      return nullptr;
    }
    return td_api::make_object<td_api::location>(to_double(latitude), to_double(longitude), to_double(accuracy));
  }

  static td_api::object_ptr<td_api::ReactionType> as_reaction_type(Slice type) {
    type = trim(type);
    if (type.empty()) {
      return nullptr;
    }
    if (type == "$") {
      return td_api::make_object<td_api::reactionTypePaid>();
    }
    auto r_custom_emoji_id = to_integer_safe<int64>(type);
    if (r_custom_emoji_id.is_ok()) {
      return td_api::make_object<td_api::reactionTypeCustomEmoji>(r_custom_emoji_id.ok());
    }
    return td_api::make_object<td_api::reactionTypeEmoji>(type.str());
  }

  static bool as_bool(string str) {
    str = to_lower(trim(str));
    return str == "true" || str == "1";
  }

  template <class T>
  static vector<T> to_integers(Slice integers) {
    return transform(transform(autosplit(integers), trim<Slice>), to_integer<T>);
  }

  static void get_args(string &args, string &arg) {
    if (&args != &arg) {
      arg = std::move(args);
    }
  }

  static void get_args(string &args, bool &arg) {
    arg = as_bool(args);
  }

  struct SearchQuery {
    int32 limit = 0;
    string query;
  };

  static void get_args(string &args, SearchQuery &arg) {
    string limit;
    std::tie(limit, arg.query) = split(trim(args));
    auto r_limit = to_integer_safe<int32>(limit);
    if (r_limit.is_ok() && r_limit.ok() > 0) {
      arg.limit = r_limit.ok();
    } else {
      arg.limit = 10;
      arg.query = std::move(args);
    }
    args.clear();
  }

  static void get_args(string &args, int32 &arg) {
    arg = to_integer<int32>(args);
  }

  static void get_args(string &args, int64 &arg) {
    arg = to_integer<int64>(args);
  }

  static void get_args(string &args, double &arg) {
    arg = to_double(args);
  }

  struct ChatId {
    int64 chat_id = 0;

    operator int64() const {
      return chat_id;
    }
  };

  void get_args(string &args, ChatId &arg) const {
    arg.chat_id = as_chat_id(args);
  }

  struct MessageId {
    int64 message_id = 0;

    operator int64() const {
      return message_id;
    }
  };

  void get_args(string &args, MessageId &arg) const {
    arg.message_id = as_message_id(args);
  }

  struct MessageThreadId {
    int64 message_thread_id = 0;

    operator int64() const {
      return message_thread_id;
    }
  };

  void get_args(string &args, MessageThreadId &arg) const {
    arg.message_thread_id = as_message_thread_id(args);
  }

  struct UserId {
    int64 user_id = 0;

    operator int64() const {
      return user_id;
    }
  };

  void get_args(string &args, UserId &arg) const {
    arg.user_id = as_user_id(args);
  }

  struct ChatFolderId {
    int32 chat_folder_id = 0;

    operator int32() const {
      return chat_folder_id;
    }
  };

  void get_args(string &args, ChatFolderId &arg) const {
    arg.chat_folder_id = as_chat_folder_id(args);
  }

  struct StoryId {
    int32 story_id = 0;

    operator int32() const {
      return story_id;
    }
  };

  void get_args(string &args, StoryId &arg) const {
    arg.story_id = as_story_id(args);
  }

  struct FileId {
    int32 file_id = 0;

    operator int32() const {
      return file_id;
    }
  };

  void get_args(string &args, FileId &arg) const {
    arg.file_id = as_file_id(args);
  }

  struct ShortcutId {
    int32 shortcut_id = 0;

    operator int32() const {
      return shortcut_id;
    }
  };

  void get_args(string &args, ShortcutId &arg) const {
    arg.shortcut_id = as_shortcut_id(args);
  }

  static int32 as_shortcut_id(Slice str) {
    return to_integer<int32>(trim(str));
  }

  vector<int32> as_shortcut_ids(Slice shortcut_ids) const {
    return transform(autosplit(shortcut_ids), as_shortcut_id);
  }

  td_api::object_ptr<td_api::InputMessageReplyTo> get_input_message_reply_to() const {
    if (reply_message_id_ != 0) {
      td_api::object_ptr<td_api::inputTextQuote> quote;
      if (!reply_quote_.empty()) {
        quote = td_api::make_object<td_api::inputTextQuote>(as_formatted_text(reply_quote_), reply_quote_position_);
      }
      if (reply_chat_id_ == 0) {
        return td_api::make_object<td_api::inputMessageReplyToMessage>(reply_message_id_, std::move(quote));
      }
      return td_api::make_object<td_api::inputMessageReplyToExternalMessage>(reply_chat_id_, reply_message_id_,
                                                                             std::move(quote));
    }
    if (reply_story_chat_id_ != 0 || reply_story_id_ != 0) {
      return td_api::make_object<td_api::inputMessageReplyToStory>(reply_story_chat_id_, reply_story_id_);
    }
    return nullptr;
  }

  td_api::object_ptr<td_api::storyFullId> get_reposted_story_full_id() const {
    if (reposted_story_chat_id_ || reposted_story_id_) {
      return td_api::make_object<td_api::storyFullId>(reposted_story_chat_id_, reposted_story_id_);
    }
    return nullptr;
  }

  int64 as_saved_messages_topic_id(int64 saved_messages_topic_id) const {
    if (saved_messages_topic_id == -1) {
      return 2666000;
    }
    return saved_messages_topic_id;
  }

  int64 get_saved_messages_topic_id() const {
    return as_saved_messages_topic_id(saved_messages_topic_id_);
  }

  td_api::object_ptr<td_api::linkPreviewOptions> get_link_preview_options() const {
    if (!link_preview_is_disabled_ && link_preview_url_.empty() && !link_preview_force_small_media_ &&
        !link_preview_force_large_media_ && !link_preview_show_above_text_) {
      return nullptr;
    }
    return td_api::make_object<td_api::linkPreviewOptions>(
        link_preview_is_disabled_, link_preview_url_, link_preview_force_small_media_, link_preview_force_large_media_,
        link_preview_show_above_text_);
  }

  struct ReportReason {
    string report_reason;

    operator td_api::object_ptr<td_api::ReportReason>() const {
      return as_report_reason(report_reason);
    }
  };

  void get_args(string &args, ReportReason &arg) const {
    arg.report_reason = std::move(args);
  }

  struct InputInvoice {
    int64 chat_id = 0;
    int64 message_id = 0;
    string invoice_name;
    string invite_link;
    string gift_codes;

    operator td_api::object_ptr<td_api::InputInvoice>() const {
      if (!invite_link.empty()) {
        return td_api::make_object<td_api::inputInvoiceTelegram>(
            td_api::make_object<td_api::telegramPaymentPurposeJoinChat>(invite_link));
      } else if (!invoice_name.empty()) {
        return td_api::make_object<td_api::inputInvoiceName>(invoice_name);
      } else if (!gift_codes.empty()) {
        string user_id;
        string amount;
        string month_count;
        string text;
        std::tie(user_id, text) = split(gift_codes, ',');
        std::tie(amount, text) = split(text, ',');
        std::tie(month_count, text) = split(text, ',');
        return td_api::make_object<td_api::inputInvoiceTelegram>(
            td_api::make_object<td_api::telegramPaymentPurposePremiumGift>(
                "XTR", to_integer<int64>(amount), to_integer<int64>(user_id), to_integer<int32>(month_count),
                as_formatted_text(text)));
      } else {
        return td_api::make_object<td_api::inputInvoiceMessage>(chat_id, message_id);
      }
    }
  };

  void get_args(string &args, InputInvoice &arg) const {
    if (args.size() > 1 && (args[0] == '#' || args[0] == '$')) {
      arg.invoice_name = args.substr(1);
    } else if (args[0] == '+' || begins_with(args, "https://t.me/+")) {
      arg.invite_link = args;
    } else if (args.size() > 1 && args[0] == '%') {
      arg.gift_codes = args.substr(1);
    } else {
      string chat_id;
      string message_id;
      std::tie(chat_id, message_id) = split(args, get_delimiter(args));
      arg.chat_id = as_chat_id(chat_id);
      arg.message_id = as_message_id(message_id);
    }
  }

  struct GiveawayParameters {
    int64 chat_id = 0;
    vector<int64> additional_chat_ids;
    int32 date;
    vector<string> country_codes;

    operator td_api::object_ptr<td_api::giveawayParameters>() const {
      if (chat_id == 0) {
        return nullptr;
      }
      return td_api::make_object<td_api::giveawayParameters>(chat_id, vector<int64>(additional_chat_ids), date,
                                                             rand_bool(), rand_bool(), vector<string>(country_codes),
                                                             "prize");
    }
  };

  void get_args(string &args, GiveawayParameters &arg) const {
    auto parts = autosplit(args);
    if (args.size() < 3) {
      return;
    }
    arg.chat_id = as_chat_id(parts[0]);
    arg.date = to_integer<int32>(parts[parts.size() - 2]);
    arg.country_codes.push_back(parts[parts.size() - 1].str());
    for (size_t i = 1; i + 2 < parts.size(); i++) {
      arg.additional_chat_ids.push_back(as_chat_id(parts[i]));
    }
  }

  struct ChatPhotoSticker {
    int64 sticker_set_id = 0;
    int64 sticker_id = 0;

    operator td_api::object_ptr<td_api::chatPhotoSticker>() const {
      if (sticker_set_id != 0) {
        return td_api::make_object<td_api::chatPhotoSticker>(
            td_api::make_object<td_api::chatPhotoStickerTypeRegularOrMask>(sticker_set_id, sticker_id),
            as_background_fill(0x7FFFFFFF));
      } else {
        return td_api::make_object<td_api::chatPhotoSticker>(
            td_api::make_object<td_api::chatPhotoStickerTypeCustomEmoji>(sticker_id),
            as_background_fill({0x000000, 0xFF0000, 0x00FF00, 0x0000FF}));
      }
    }
  };

  void get_args(string &args, ChatPhotoSticker &arg) const {
    string sticker_set_id;
    string sticker_id;
    std::tie(sticker_set_id, sticker_id) = split(args, get_delimiter(args));
    if (sticker_id.empty()) {
      arg.sticker_id = to_integer<int64>(sticker_set_id);
    } else {
      arg.sticker_set_id = to_integer<int64>(sticker_set_id);
      arg.sticker_id = to_integer<int64>(sticker_id);
    }
  }

  struct InputChatPhoto {
    enum class Type : int32 { Null, Previous, Static, Animation, Sticker };
    Type type = Type::Null;
    int64 profile_photo_id = 0;
    string photo;
    string main_frame_timestamp;
    ChatPhotoSticker sticker;

    operator td_api::object_ptr<td_api::InputChatPhoto>() const {
      switch (type) {
        case Type::Null:
          return nullptr;
        case Type::Previous:
          return td_api::make_object<td_api::inputChatPhotoPrevious>(profile_photo_id);
        case Type::Static:
          return td_api::make_object<td_api::inputChatPhotoStatic>(as_input_file(photo));
        case Type::Animation:
          return td_api::make_object<td_api::inputChatPhotoAnimation>(as_input_file(photo),
                                                                      to_double(main_frame_timestamp));
        case Type::Sticker:
          return td_api::make_object<td_api::inputChatPhotoSticker>(sticker);
        default:
          UNREACHABLE();
          return nullptr;
      }
    }
  };

  void get_args(string &args, InputChatPhoto &arg) const {
    args = trim(args);
    if (args.empty()) {
      return;
    }
    if (to_integer_safe<int64>(args).is_ok()) {
      arg.type = InputChatPhoto::Type::Previous;
      arg.profile_photo_id = to_integer<int64>(args);
    } else if (args[0] == 'p') {
      arg.type = InputChatPhoto::Type::Static;
      arg.photo = args.substr(1);
    } else if (args[0] == 'a') {
      arg.type = InputChatPhoto::Type::Animation;
      std::tie(arg.photo, arg.main_frame_timestamp) = split(args.substr(1), get_delimiter(args));
    } else if (args[0] == 's') {
      arg.type = InputChatPhoto::Type::Sticker;
      args = args.substr(1);
      get_args(args, arg.sticker);
    } else {
      LOG(ERROR) << "Invalid InputChatPhoto = " << args;
    }
  }

  struct CustomEmojiId {
    int64 custom_emoji_id = 0;

    operator int64() const {
      return custom_emoji_id;
    }
  };

  void get_args(string &args, CustomEmojiId &arg) const {
    arg.custom_emoji_id = as_custom_emoji_id(args);
  }

  struct AffiliateType {
    int64 id = 0;

    operator td_api::object_ptr<td_api::AffiliateType>() const {
      if (id == 0) {
        return td_api::make_object<td_api::affiliateTypeCurrentUser>();
      }
      if (id > 0) {
        return td_api::make_object<td_api::affiliateTypeBot>(id);
      }
      return td_api::make_object<td_api::affiliateTypeChannel>(id);
    }
  };

  void get_args(string &args, AffiliateType &arg) const {
    arg.id = as_chat_id(args);
    if (arg.id == my_id_) {
      arg.id = 0;
    }
  }

  struct InputBackground {
    string background_file;
    // or
    int64 background_id = 0;
    // or
    int64 message_id = 0;

    operator td_api::object_ptr<td_api::InputBackground>() const {
      if (!background_file.empty()) {
        return td_api::make_object<td_api::inputBackgroundLocal>(as_input_file(background_file));
      }
      if (background_id != 0) {
        return td_api::make_object<td_api::inputBackgroundRemote>(background_id);
      }
      if (message_id != 0) {
        return td_api::make_object<td_api::inputBackgroundPrevious>(message_id);
      }
      return nullptr;
    }
  };

  void get_args(string &args, InputBackground &arg) const {
    args = trim(args);
    if (args.empty()) {
      return;
    }
    if (to_integer_safe<int64>(args).is_ok()) {
      arg.background_id = to_integer<int64>(args);
    } else if (args.back() == 's' && to_integer_safe<int32>(args.substr(0, args.size() - 1)).is_ok()) {
      arg.message_id = as_message_id(args);
    } else {
      arg.background_file = std::move(args);
    }
  }

  struct BackgroundType {
    enum class Type : int32 {
      Null,
      Wallpaper,
      SolidPattern,
      GradientPattern,
      FreeformGradientPattern,
      Fill,
      ChatTheme
    };
    Type type = Type::Null;
    vector<int32> colors;
    string theme_name;

    operator td_api::object_ptr<td_api::BackgroundType>() const {
      switch (type) {
        case Type::Null:
          return nullptr;
        case Type::Wallpaper:
          return as_wallpaper_background(rand_bool(), rand_bool());
        case Type::SolidPattern:
          return as_solid_pattern_background(0xABCDef, 49, true);
        case Type::GradientPattern:
          return as_gradient_pattern_background(0xABCDEF, 0xFE, 51, rand_bool(), false);
        case Type::FreeformGradientPattern:
          return as_freeform_gradient_pattern_background({0xABCDEF, 0xFE, 0xFF0000}, 52, rand_bool(), rand_bool());
        case Type::Fill:
          if (colors.size() == 1) {
            return as_solid_background(colors[0]);
          }
          if (colors.size() == 2) {
            return as_gradient_background(colors[0], colors[1]);
          }
          return as_freeform_gradient_background(colors);
        case Type::ChatTheme:
          return as_chat_theme_background(theme_name);
        default:
          UNREACHABLE();
          return nullptr;
      }
    }
  };

  void get_args(string &args, BackgroundType &arg) const {
    args = trim(args);
    if (args.empty()) {
      return;
    }
    if (args == "w") {
      arg.type = BackgroundType::Type::Wallpaper;
    } else if (args == "sp") {
      arg.type = BackgroundType::Type::SolidPattern;
    } else if (args == "gp") {
      arg.type = BackgroundType::Type::GradientPattern;
    } else if (args == "fgp") {
      arg.type = BackgroundType::Type::FreeformGradientPattern;
    } else if (args[0] == 't') {
      arg.type = BackgroundType::Type::ChatTheme;
      arg.theme_name = args.substr(1);
    } else {
      arg.type = BackgroundType::Type::Fill;
      arg.colors = to_integers<int32>(args);
    }
  }

  struct ReactionNotificationSource {
    string source;

    operator td_api::object_ptr<td_api::ReactionNotificationSource>() const {
      if (source == "none" || source == "n") {
        return td_api::make_object<td_api::reactionNotificationSourceNone>();
      }
      if (source == "contacts" || source == "c") {
        return td_api::make_object<td_api::reactionNotificationSourceContacts>();
      }
      if (source == "all" || source == "a") {
        return td_api::make_object<td_api::reactionNotificationSourceAll>();
      }
      return nullptr;
    }
  };

  void get_args(string &args, ReactionNotificationSource &arg) const {
    arg.source = trim(args);
  }

  struct PrivacyRules {
    string rules_str;

    operator td_api::object_ptr<td_api::userPrivacySettingRules>() const {
      vector<td_api::object_ptr<td_api::UserPrivacySettingRule>> rules;
      for (size_t i = 0; i < rules_str.size(); i++) {
        auto arg = vector<int64>{to_integer<int64>(Slice(rules_str).substr(i + 1))};
        if (rules_str[i] == 'a') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleAllowAll>());
        } else if (rules_str[i] == 'A') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleRestrictAll>());
        } else if (rules_str[i] == 'c') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleAllowContacts>());
        } else if (rules_str[i] == 'C') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleRestrictContacts>());
        } else if (rules_str[i] == 'u') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleAllowUsers>(std::move(arg)));
        } else if (rules_str[i] == 'U') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleRestrictUsers>(std::move(arg)));
        } else if (rules_str[i] == 'm') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleAllowChatMembers>(std::move(arg)));
        } else if (rules_str[i] == 'M') {
          rules.push_back(td_api::make_object<td_api::userPrivacySettingRuleRestrictChatMembers>(std::move(arg)));
        } else if (!is_digit(rules_str[i]) && rules_str[i] != '-') {
          LOG(ERROR) << "Invalid character " << rules_str[i] << " in privacy rules " << rules_str;
          break;
        }
      }
      return td_api::make_object<td_api::userPrivacySettingRules>(std::move(rules));
    }
  };

  void get_args(string &args, PrivacyRules &arg) const {
    arg.rules_str = trim(args);
    if (arg.rules_str.empty()) {
      arg.rules_str = "a";
    }
  }

  struct StoryPrivacySettings {
    string settings;
    vector<int64> user_ids;

    operator td_api::object_ptr<td_api::StoryPrivacySettings>() const {
      if (settings == "f" || settings == "cf") {
        return td_api::make_object<td_api::storyPrivacySettingsCloseFriends>();
      }
      if (!settings.empty()) {
        if (settings[0] == 'a' || settings[0] == 'e') {
          return td_api::make_object<td_api::storyPrivacySettingsEveryone>(vector<int64>(user_ids));
        }
        if (settings[0] == 'c') {
          return td_api::make_object<td_api::storyPrivacySettingsContacts>(vector<int64>(user_ids));
        }
        if (settings[0] == 'u') {
          return td_api::make_object<td_api::storyPrivacySettingsSelectedUsers>(vector<int64>(user_ids));
        }
      }
      return td_api::make_object<td_api::storyPrivacySettingsContacts>();
    }
  };

  void get_args(string &args, StoryPrivacySettings &arg) const {
    arg.settings = trim(args);
    if (!arg.settings.empty() && arg.settings != "cf") {
      arg.user_ids = as_user_ids(Slice(arg.settings).substr(1));
    }
  }

  struct InputStoryAreas {
    string areas;

    operator td_api::object_ptr<td_api::inputStoryAreas>() const {
      if (areas.empty()) {
        return nullptr;
      }
      auto result = td_api::make_object<td_api::inputStoryAreas>();
      for (const auto &area : full_split(areas, ';')) {
        if (area.empty()) {
          continue;
        }
        auto position = td_api::make_object<td_api::storyAreaPosition>(Random::fast(1, 99), Random::fast(1, 99),
                                                                       Random::fast(1, 99), Random::fast(1, 99),
                                                                       Random::fast(0, 360), Random::fast(1, 19));
        td_api::object_ptr<td_api::InputStoryAreaType> type;
        if (area == "l") {
          type = td_api::make_object<td_api::inputStoryAreaTypeLocation>(
              td_api::make_object<td_api::location>(Random::fast(-50, 50), Random::fast(-50, 50), 0.0),
              td_api::make_object<td_api::locationAddress>("US", "ZZ", "Deniles", "Road"));
        } else if (area[0] == 'v') {
          string query_id;
          string result_id;
          std::tie(query_id, result_id) = split(area.substr(1), ':');
          type = td_api::make_object<td_api::inputStoryAreaTypeFoundVenue>(to_integer<int64>(query_id), result_id);
        } else if (area[0] == 'p') {
          string venue_provider;
          string venue_id;
          std::tie(venue_provider, venue_id) = split(area.substr(1), ':');
          type = td_api::make_object<td_api::inputStoryAreaTypePreviousVenue>(venue_provider, venue_id);
        } else if (area[0] == 'r') {
          type = td_api::make_object<td_api::inputStoryAreaTypeSuggestedReaction>(as_reaction_type(area.substr(1)),
                                                                                  rand_bool(), rand_bool());
        } else if (area[0] == 'm') {
          string chat_id;
          string message_id;
          std::tie(chat_id, message_id) = split(area.substr(1), ':');
          type = td_api::make_object<td_api::inputStoryAreaTypeMessage>(to_integer<int64>(chat_id),
                                                                        as_message_id(message_id));
        } else if (area[0] == 'u') {
          type = td_api::make_object<td_api::inputStoryAreaTypeLink>(area.substr(1));
        } else if (area[0] == 'w') {
          type = td_api::make_object<td_api::inputStoryAreaTypeWeather>(20.1, "☀️", to_integer<int32>(area.substr(1)));
        } else if (area[0] == 'g') {
          type = td_api::make_object<td_api::inputStoryAreaTypeUpgradedGift>(area.substr(1));
        }
        result->areas_.push_back(td_api::make_object<td_api::inputStoryArea>(std::move(position), std::move(type)));
      }
      return result;
    }
  };

  void get_args(string &args, InputStoryAreas &arg) const {
    arg.areas = trim(args);
  }

  template <class FirstType, class SecondType, class... Types>
  void get_args(string &args, FirstType &first_arg, SecondType &second_arg, Types &...other_args) const {
    string arg;
    std::tie(arg, args) = split(args);
    get_args(arg, first_arg);
    get_args(args, second_arg, other_args...);
  }

  void on_result(uint64 generation, uint64 id, td_api::object_ptr<td_api::Object> result) {
    auto result_str = to_string(result);
    if (result != nullptr) {
      switch (result->get_id()) {
        case td_api::stickerSets::ID: {
          auto sticker_sets = static_cast<const td_api::stickerSets *>(result.get());
          result_str = PSTRING() << "StickerSets { total_count = " << sticker_sets->total_count_
                                 << ", count = " << sticker_sets->sets_.size();
          for (auto &sticker_set : sticker_sets->sets_) {
            result_str += PSTRING() << ", " << sticker_set->name_;
          }
          result_str += " }";
          break;
        }
        case td_api::trendingStickerSets::ID: {
          auto sticker_sets = static_cast<const td_api::trendingStickerSets *>(result.get());
          result_str = PSTRING() << "TrendingStickerSets { is_premium = " << sticker_sets->is_premium_
                                 << ", total_count = " << sticker_sets->total_count_
                                 << ", count = " << sticker_sets->sets_.size();
          for (auto &sticker_set : sticker_sets->sets_) {
            result_str += PSTRING() << ", " << sticker_set->name_;
          }
          result_str += " }";
          break;
        }
        default:
          break;
      }
    }

    if (id > 0 && combined_log.get_first_verbosity_level() < get_log_tag_verbosity_level("td_requests")) {
      LOG(ERROR) << "Receive result [" << generation << "][id=" << id << "] " << result_str;
    }

    auto as_json_str = json_encode<std::string>(ToJson(result));
    // LOG(INFO) << "Receive result [" << generation << "][id=" << id << "] " << as_json_str;
    //auto copy_as_json_str = as_json_str;
    //auto as_json_value = json_decode(copy_as_json_str).move_as_ok();
    //td_api::object_ptr<td_api::Object> object;
    //from_json(object, as_json_value).ensure();
    //CHECK(object != nullptr);
    //auto as_json_str2 = json_encode<std::string>(ToJson(object));
    //LOG_CHECK(as_json_str == as_json_str2) << "\n" << tag("a", as_json_str) << "\n" << tag("b", as_json_str2);
    // LOG(INFO) << "Receive result [" << generation << "][id=" << id << "] " << as_json_str;

    if (generation != generation_) {
      LOG(INFO) << "Drop received from previous Client " << result_str;
      return;
    }

    int32 result_id = result == nullptr ? 0 : result->get_id();

    [&] {
      if (id != 0) {
        auto it = query_id_to_send_message_info_.find(id);
        if (it == query_id_to_send_message_info_.end()) {
          return;
        }
        auto info = it->second;
        query_id_to_send_message_info_.erase(id);

        if (result_id == td_api::message::ID) {
          auto *message = static_cast<const td_api::message *>(result.get());
          message_id_to_send_message_info_[message->id_] = info;
        }
      }
    }();
    [&] {
      if (result_id == td_api::updateMessageSendAcknowledged::ID) {
        auto *message = static_cast<const td_api::updateMessageSendAcknowledged *>(result.get());
        auto it = message_id_to_send_message_info_.find(message->message_id_);
        if (it == message_id_to_send_message_info_.end()) {
          return;
        }
        auto &info = it->second;
        info.quick_ack_time = Time::now();
      }
    }();
    [&] {
      if (result_id == td_api::updateMessageSendSucceeded::ID) {
        auto *message = static_cast<const td_api::updateMessageSendSucceeded *>(result.get());
        auto it = message_id_to_send_message_info_.find(message->old_message_id_);
        if (it == message_id_to_send_message_info_.end()) {
          return;
        }
        auto info = it->second;
        message_id_to_send_message_info_.erase(it);
        info.ack_time = Time::now();
        LOG(INFO) << info;
      }
    }();

    switch (result_id) {
      case td_api::updateUser::ID:
        register_user(*static_cast<const td_api::updateUser *>(result.get())->user_);
        break;
      case td_api::updateSupergroup::ID:
        register_supergroup(*static_cast<const td_api::updateSupergroup *>(result.get())->supergroup_);
        break;
      case td_api::users::ID:
        update_users(*static_cast<const td_api::users *>(result.get()));
        break;
      case td_api::updateOption::ID:
        update_option(*static_cast<const td_api::updateOption *>(result.get()));
        break;
      case td_api::message::ID:
        on_get_message(*static_cast<const td_api::message *>(result.get()));
        break;
      case td_api::messages::ID:
        on_get_messages(*static_cast<const td_api::messages *>(result.get()));
        break;
      case td_api::chatEvents::ID:
        on_get_chat_events(*static_cast<const td_api::chatEvents *>(result.get()));
        break;
      case td_api::updateFileGenerationStart::ID:
        on_file_generation_start(*static_cast<const td_api::updateFileGenerationStart *>(result.get()));
        break;
      case td_api::updateAuthorizationState::ID:
        LOG(WARNING) << result_str;
        on_update_authorization_state(
            std::move(static_cast<td_api::updateAuthorizationState *>(result.get())->authorization_state_));
        break;
      case td_api::updateChatLastMessage::ID: {
        auto message = static_cast<const td_api::updateChatLastMessage *>(result.get())->last_message_.get();
        if (message != nullptr && message->content_->get_id() == td_api::messageText::ID) {
          // auto text = static_cast<const td_api::messageText *>(message->content_.get())->text_->text_;
        }
        break;
      }
      case td_api::updateNewMessage::ID: {
        auto message = static_cast<const td_api::updateNewMessage *>(result.get())->message_.get();
        if (message != nullptr && message->content_->get_id() == td_api::messageText::ID) {
          // auto chat_id = message->chat_id_;
          auto text = static_cast<const td_api::messageText *>(message->content_.get())->text_->text_;
          if (text == "/start" && !message->is_outgoing_ && use_test_dc_) {
            // on_cmd(PSTRING() << "sm " << chat_id << " Hi!");
          }
        }
        break;
      }
      case td_api::updateNewBusinessMessage::ID: {
        const auto *update = static_cast<const td_api::updateNewBusinessMessage *>(result.get());
        const auto *message = update->message_->message_.get();
        if (!message->is_outgoing_ && use_test_dc_) {
          auto old_business_connection_id = std::move(business_connection_id_);
          business_connection_id_ = update->connection_id_;
          on_cmd("gbc");
          send_message(message->chat_id_,
                       td_api::make_object<td_api::inputMessageText>(as_formatted_text("Welcome!"),
                                                                     get_link_preview_options(), true),
                       false, false);
          business_connection_id_ = std::move(old_business_connection_id);
        }
        break;
      }
      case td_api::updateNewPreCheckoutQuery::ID:
        if (use_test_dc_) {
          const auto *update = static_cast<const td_api::updateNewPreCheckoutQuery *>(result.get());
          send_request(td_api::make_object<td_api::answerPreCheckoutQuery>(update->id_, string()));
        }
        break;
      case td_api::file::ID:
        on_get_file(*static_cast<const td_api::file *>(result.get()));
        break;
      case td_api::updateFile::ID:
        on_get_file(*static_cast<const td_api::updateFile *>(result.get())->file_);
        break;
      case td_api::updateConnectionState::ID:
        LOG(WARNING) << result_str;
        break;
      default:
        break;
    }
  }

  void on_error(uint64 generation, uint64 id, td_api::object_ptr<td_api::error> error) {
    if (id > 0 && combined_log.get_first_verbosity_level() < get_log_tag_verbosity_level("td_requests")) {
      LOG(ERROR) << "Receive error [" << generation << "][id=" << id << "] " << to_string(error);
    }
  }

  void on_closed(uint64 generation) {
    LOG(WARNING) << "Td with generation " << generation << " is closed";
    closed_td_++;
    if (closed_td_ == generation_) {
      LOG(WARNING) << "Ready to stop";
      ready_to_stop_ = true;
      if (close_flag_) {
        yield();
      }
    }
  }

  void quit() {
    if (close_flag_) {
      return;
    }

    LOG(WARNING) << "QUIT";
    close_flag_ = true;
    dump_memory_usage();
    td_client_.reset();
    Scheduler::unsubscribe(stdin_.get_poll_info().get_pollable_fd_ref());
    is_stdin_reader_stopped_ = true;
    yield();
  }

  BufferedStdin stdin_;
  static CliClient *instance_;

#ifdef USE_READLINE
  /* Callback function called for each line when accept-line executed, EOF
   *    seen, or EOF character read.  This sets a flag and returns; it could
   *       also call exit. */
  static void static_add_cmd(char *line) {
    /* Can use ^D (stty eof) to exit. */
    if (line == nullptr) {
      LOG(FATAL) << "Closed";
      return;
    }
    if (*line) {
      add_history(line);
    }
    instance_->add_cmd(line);
    rl_free(line);
  }
  static int static_getc(FILE *) {
    return instance_->stdin_getc();
  }
#endif

  uint64 generation_ = 0;
  uint64 closed_td_ = 0;
  void create_td(Slice name) {
    if (ready_to_stop_) {
      return;
    }

    LOG(WARNING) << "Creating new Td " << name << " with generation " << generation_ + 1;
    class TdCallbackImpl final : public TdCallback {
     public:
      TdCallbackImpl(CliClient *client, uint64 generation) : client_(client), generation_(generation) {
      }
      void on_result(uint64 id, td_api::object_ptr<td_api::Object> result) final {
        client_->on_result(generation_, id, std::move(result));
      }
      void on_error(uint64 id, td_api::object_ptr<td_api::error> error) final {
        client_->on_error(generation_, id, std::move(error));
      }
      TdCallbackImpl(const TdCallbackImpl &) = delete;
      TdCallbackImpl &operator=(const TdCallbackImpl &) = delete;
      TdCallbackImpl(TdCallbackImpl &&) = delete;
      TdCallbackImpl &operator=(TdCallbackImpl &&) = delete;
      ~TdCallbackImpl() final {
        client_->on_closed(generation_);
      }

     private:
      CliClient *client_;
      uint64 generation_;
    };

    ClientActor::Options options;
    options.net_query_stats = net_query_stats_;

    td_client_ = create_actor<ClientActor>(name, make_unique<TdCallbackImpl>(this, ++generation_), std::move(options));

    if (get_chat_list_) {
      send_request(td_api::make_object<td_api::getChats>(nullptr, 10000));
    }
    if (disable_network_) {
      send_request(td_api::make_object<td_api::setNetworkType>(td_api::make_object<td_api::networkTypeNone>()));
    }
  }

  void init_td() {
    close_flag_ = false;
    ready_to_stop_ = false;
    generation_ = 0;
    closed_td_ = 0;

    create_td("ClientActor1");

    bool test_init = false;
    if (test_init) {
      create_td("ClientActor2");

      for (int i = 0; i < 4; i++) {
        send_closure_later(td_client_, &ClientActor::request, std::numeric_limits<uint64>::max(),
                           td_api::make_object<td_api::setAlarm>(0.001 + 1000 * (i / 2)));
      }

      send_request(td_api::make_object<td_api::getStorageStatistics>(10));
      send_request(td_api::make_object<td_api::getStorageStatisticsFast>());

      send_request(td_api::make_object<td_api::getTextEntities>(
          "@telegram /test_command https://telegram.org telegram.me @gif @test"));

      send_request(
          td_api::make_object<td_api::setOption>("xxx", td_api::make_object<td_api::optionValueBoolean>(true)));
      send_request(td_api::make_object<td_api::setOption>("xxx", td_api::make_object<td_api::optionValueInteger>(1)));
      send_request(td_api::make_object<td_api::setOption>("xxx", td_api::make_object<td_api::optionValueString>("2")));
      send_request(td_api::make_object<td_api::setOption>("xxx", td_api::make_object<td_api::optionValueEmpty>()));

      send_request(td_api::make_object<td_api::getOption>("use_pfs"));
      send_request(td_api::make_object<td_api::setOption>(
          "use_pfs", td_api::make_object<td_api::optionValueBoolean>(std::time(nullptr) / 86400 % 2 == 0)));
      send_request(td_api::make_object<td_api::setOption>("notification_group_count_max",
                                                          td_api::make_object<td_api::optionValueInteger>(1)));
      send_request(td_api::make_object<td_api::setOption>("use_storage_optimizer",
                                                          td_api::make_object<td_api::optionValueBoolean>(false)));
      send_request(td_api::make_object<td_api::setOption>(
          "use_pfs", td_api::make_object<td_api::optionValueBoolean>(std::time(nullptr) / 86400 % 2 == 0)));
      send_request(td_api::make_object<td_api::setOption>("disable_contact_registered_notifications",
                                                          td_api::make_object<td_api::optionValueBoolean>(true)));

      send_request(td_api::make_object<td_api::setNetworkType>(td_api::make_object<td_api::networkTypeWiFi>()));
      send_request(td_api::make_object<td_api::getNetworkStatistics>());
      send_request(td_api::make_object<td_api::getCountryCode>());
      send_request(
          td_api::make_object<td_api::addProxy>("1.1.1.1", 1111, true, td_api::make_object<td_api::proxyTypeSocks5>()));
      send_request(td_api::make_object<td_api::addProxy>("1.1.1.1", 1112, false,
                                                         td_api::make_object<td_api::proxyTypeSocks5>()));
      send_request(td_api::make_object<td_api::pingProxy>(0));

      auto bad_request = td_api::make_object<td_api::setTdlibParameters>();
      bad_request->database_directory_ = "/..";
      bad_request->api_id_ = api_id_;
      bad_request->api_hash_ = api_hash_;
      send_request(std::move(bad_request));
    }
  }

  void init() {
    instance_ = this;

    init_td();

#ifdef USE_READLINE
    deactivate_readline();
    rl_getc_function = static_getc;
    rl_callback_handler_install(prompt, static_add_cmd);
    rl_attempted_completion_function = tg_cli_completion;
    reactivate_readline();
#endif
    Scheduler::subscribe(stdin_.get_poll_info().extract_pollable_fd(this), PollFlags::Read());
  }
#ifndef USE_READLINE
  size_t buffer_pos_ = 0;
  Result<BufferSlice> process_stdin(ChainBufferReader *buffer) {
    auto found = find_boundary(buffer->clone(), "\n", buffer_pos_);

    if (!found) {
      return Status::Error("End of line not found");
    }

    auto data = buffer->cut_head(buffer_pos_).move_as_buffer_slice();
    if (!data.empty() && data[data.size() - 1] == '\r') {
      data.truncate(data.size() - 1);
    }
    buffer->advance(1);
    buffer_pos_ = 0;
    return std::move(data);
  }
#endif

  static td_api::object_ptr<td_api::formattedText> as_formatted_text(
      const string &text, vector<td_api::object_ptr<td_api::textEntity>> entities = {}) {
    if (entities.empty() && !text.empty()) {
      Slice unused_reserved_characters("#+-={}.");
      string new_text;
      for (size_t i = 0; i < text.size(); i++) {
        auto c = text[i];
        if (c == '\\' && text[i + 1] == 'n') {
          new_text += '\n';
          i++;
          continue;
        }
        if (unused_reserved_characters.find(c) != Slice::npos) {
          new_text += '\\';
        }
        new_text += c;
      }
      auto parsed_text = ClientActor::execute(td_api::make_object<td_api::parseTextEntities>(
          new_text, td_api::make_object<td_api::textParseModeMarkdown>(2)));
      if (parsed_text->get_id() == td_api::formattedText::ID) {
        return td_api::move_object_as<td_api::formattedText>(parsed_text);
      }
    }
    return td_api::make_object<td_api::formattedText>(text, std::move(entities));
  }

  static td_api::object_ptr<td_api::formattedText> as_caption(
      const string &caption, vector<td_api::object_ptr<td_api::textEntity>> entities = {}) {
    return as_formatted_text(caption, std::move(entities));
  }

  static td_api::object_ptr<td_api::NotificationSettingsScope> as_notification_settings_scope(Slice scope) {
    if (scope.empty()) {
      return nullptr;
    }
    if (scope == "channels" || scope == "ch") {
      return td_api::make_object<td_api::notificationSettingsScopeChannelChats>();
    }
    if (scope == "chats" || scope == "groups" || as_bool(scope.str())) {
      return td_api::make_object<td_api::notificationSettingsScopeGroupChats>();
    }
    return td_api::make_object<td_api::notificationSettingsScopePrivateChats>();
  }

  static td_api::object_ptr<td_api::UserPrivacySetting> as_user_privacy_setting(MutableSlice setting) {
    setting = trim(setting);
    to_lower_inplace(setting);
    if (setting == "invite") {
      return td_api::make_object<td_api::userPrivacySettingAllowChatInvites>();
    }
    if (setting == "status") {
      return td_api::make_object<td_api::userPrivacySettingShowStatus>();
    }
    if (setting == "call") {
      return td_api::make_object<td_api::userPrivacySettingAllowCalls>();
    }
    if (setting == "p2p") {
      return td_api::make_object<td_api::userPrivacySettingAllowPeerToPeerCalls>();
    }
    if (setting == "forward") {
      return td_api::make_object<td_api::userPrivacySettingShowLinkInForwardedMessages>();
    }
    if (setting == "photo") {
      return td_api::make_object<td_api::userPrivacySettingShowProfilePhoto>();
    }
    if (setting == "phone_number") {
      return td_api::make_object<td_api::userPrivacySettingShowPhoneNumber>();
    }
    if (setting == "bio") {
      return td_api::make_object<td_api::userPrivacySettingShowBio>();
    }
    if (setting == "find") {
      return td_api::make_object<td_api::userPrivacySettingAllowFindingByPhoneNumber>();
    }
    if (setting == "birth") {
      return td_api::make_object<td_api::userPrivacySettingShowBirthdate>();
    }
    if (setting == "gift") {
      return td_api::make_object<td_api::userPrivacySettingAutosaveGifts>();
    }
    return nullptr;
  }

  static td_api::object_ptr<td_api::SearchMessagesFilter> as_search_messages_filter(Slice filter) {
    filter = trim(filter);
    string lowered_filter = to_lower(filter);
    filter = lowered_filter;
    if (begins_with(filter, "search")) {
      filter.remove_prefix(6);
    }
    if (filter == "an" || filter == "animation") {
      return td_api::make_object<td_api::searchMessagesFilterAnimation>();
    }
    if (filter == "au" || filter == "audio") {
      return td_api::make_object<td_api::searchMessagesFilterAudio>();
    }
    if (filter == "d" || filter == "document") {
      return td_api::make_object<td_api::searchMessagesFilterDocument>();
    }
    if (filter == "p" || filter == "photo") {
      return td_api::make_object<td_api::searchMessagesFilterPhoto>();
    }
    if (filter == "vi" || filter == "video") {
      return td_api::make_object<td_api::searchMessagesFilterVideo>();
    }
    if (filter == "vo" || filter == "voice") {
      return td_api::make_object<td_api::searchMessagesFilterVoiceNote>();
    }
    if (filter == "pvi") {
      return td_api::make_object<td_api::searchMessagesFilterPhotoAndVideo>();
    }
    if (filter == "u" || filter == "url") {
      return td_api::make_object<td_api::searchMessagesFilterUrl>();
    }
    if (filter == "cp" || filter == "chatphoto") {
      return td_api::make_object<td_api::searchMessagesFilterChatPhoto>();
    }
    if (filter == "vn" || filter == "videonote") {
      return td_api::make_object<td_api::searchMessagesFilterVideoNote>();
    }
    if (filter == "vvn" || filter == "voicevideonote") {
      return td_api::make_object<td_api::searchMessagesFilterVoiceAndVideoNote>();
    }
    if (filter == "m" || filter == "mention") {
      return td_api::make_object<td_api::searchMessagesFilterMention>();
    }
    if (filter == "um" || filter == "umention") {
      return td_api::make_object<td_api::searchMessagesFilterUnreadMention>();
    }
    if (filter == "ur" || filter == "ureaction") {
      return td_api::make_object<td_api::searchMessagesFilterUnreadReaction>();
    }
    if (filter == "f" || filter == "failed") {
      return td_api::make_object<td_api::searchMessagesFilterFailedToSend>();
    }
    if (filter == "pi" || filter == "pinned") {
      return td_api::make_object<td_api::searchMessagesFilterPinned>();
    }
    if (!filter.empty()) {
      LOG(ERROR) << "Unsupported message filter " << filter;
    }
    return nullptr;
  }

  static td_api::object_ptr<td_api::ChatMembersFilter> as_chat_members_filter(MutableSlice filter) {
    filter = trim(filter);
    to_lower_inplace(filter);
    if (filter == "a" || filter == "admin" || filter == "administrators") {
      return td_api::make_object<td_api::chatMembersFilterAdministrators>();
    }
    if (filter == "b" || filter == "banned") {
      return td_api::make_object<td_api::chatMembersFilterBanned>();
    }
    if (filter == "bot" || filter == "bots") {
      return td_api::make_object<td_api::chatMembersFilterBots>();
    }
    if (filter == "c" || filter == "contacts") {
      return td_api::make_object<td_api::chatMembersFilterContacts>();
    }
    if (filter == "m" || filter == "members") {
      return td_api::make_object<td_api::chatMembersFilterMembers>();
    }
    if (begins_with(filter, "@")) {
      return td_api::make_object<td_api::chatMembersFilterMention>(as_message_thread_id(filter.substr(1)));
    }
    if (filter == "r" || filter == "rest" || filter == "restricted") {
      return td_api::make_object<td_api::chatMembersFilterRestricted>();
    }
    if (!filter.empty()) {
      LOG(ERROR) << "Unsupported chat member filter " << filter;
    }
    return nullptr;
  }

  static td_api::object_ptr<td_api::SupergroupMembersFilter> as_supergroup_members_filter(MutableSlice filter,
                                                                                          const string &query,
                                                                                          Slice message_thread_id) {
    filter = trim(filter);
    to_lower_inplace(filter);
    if (begins_with(filter, "get")) {
      filter.remove_prefix(3);
    }
    if (begins_with(filter, "search")) {
      filter.remove_prefix(6);
    }
    if (begins_with(filter, "supergroup")) {
      filter.remove_prefix(10);
    }
    if (filter == "administrators") {
      return td_api::make_object<td_api::supergroupMembersFilterAdministrators>();
    }
    if (filter == "banned") {
      return td_api::make_object<td_api::supergroupMembersFilterBanned>(query);
    }
    if (filter == "bots") {
      return td_api::make_object<td_api::supergroupMembersFilterBots>();
    }
    if (filter == "contacts") {
      return td_api::make_object<td_api::supergroupMembersFilterContacts>(query);
    }
    if (filter == "members") {
      if (query.empty()) {
        return td_api::make_object<td_api::supergroupMembersFilterRecent>();
      } else {
        return td_api::make_object<td_api::supergroupMembersFilterSearch>(query);
      }
    }
    if (filter == "restricted") {
      return td_api::make_object<td_api::supergroupMembersFilterRestricted>(query);
    }
    if (filter == "mentions") {
      return td_api::make_object<td_api::supergroupMembersFilterMention>(query,
                                                                         as_message_thread_id(message_thread_id));
    }
    return nullptr;
  }

  static bool rand_bool() {
    return Random::fast_bool();
  }

  td_api::object_ptr<td_api::chatFolder> as_chat_folder(string filter, bool is_shareable = false) const {
    string title;
    string icon_name;
    string pinned_chat_ids;
    string included_chat_ids;
    string excluded_chat_ids;
    get_args(filter, title, icon_name, pinned_chat_ids, included_chat_ids, excluded_chat_ids);
    return td_api::make_object<td_api::chatFolder>(
        td_api::make_object<td_api::chatFolderName>(td_api::make_object<td_api::formattedText>(title, Auto()), true),
        td_api::make_object<td_api::chatFolderIcon>(icon_name), -1, is_shareable, as_chat_ids(pinned_chat_ids),
        as_chat_ids(included_chat_ids), as_chat_ids(excluded_chat_ids), rand_bool(), rand_bool(), rand_bool(),
        rand_bool(), rand_bool(), rand_bool(), rand_bool(), rand_bool());
  }

  static td_api::object_ptr<td_api::chatAdministratorRights> as_chat_administrator_rights(
      bool can_manage_chat, bool can_change_info, bool can_post_messages, bool can_edit_messages,
      bool can_delete_messages, bool can_invite_users, bool can_restrict_members, bool can_pin_messages,
      bool can_manage_topics, bool can_promote_members, bool can_manage_video_chats, bool can_post_stories,
      bool can_edit_stories, bool can_delete_stories, bool is_anonymous) {
    return td_api::make_object<td_api::chatAdministratorRights>(
        can_manage_chat, can_change_info, can_post_messages, can_edit_messages, can_delete_messages, can_invite_users,
        can_restrict_members, can_pin_messages, can_manage_topics, can_promote_members, can_manage_video_chats,
        can_post_stories, can_edit_stories, can_delete_stories, is_anonymous);
  }

  static td_api::object_ptr<td_api::TopChatCategory> as_top_chat_category(MutableSlice category) {
    category = trim(category);
    to_lower_inplace(category);
    if (!category.empty() && category.back() == 's') {
      category.remove_suffix(1);
    }
    if (category == "bot") {
      return td_api::make_object<td_api::topChatCategoryBots>();
    } else if (category == "group") {
      return td_api::make_object<td_api::topChatCategoryGroups>();
    } else if (category == "channel") {
      return td_api::make_object<td_api::topChatCategoryChannels>();
    } else if (category == "inline") {
      return td_api::make_object<td_api::topChatCategoryInlineBots>();
    } else if (category == "app") {
      return td_api::make_object<td_api::topChatCategoryWebAppBots>();
    } else if (category == "call") {
      return td_api::make_object<td_api::topChatCategoryCalls>();
    } else if (category == "forward") {
      return td_api::make_object<td_api::topChatCategoryForwardChats>();
    } else {
      return td_api::make_object<td_api::topChatCategoryUsers>();
    }
  }

  static td_api::object_ptr<td_api::ChatAction> as_chat_action(MutableSlice action) {
    action = trim(action);
    to_lower_inplace(action);
    if (action == "c" || action == "cancel") {
      return td_api::make_object<td_api::chatActionCancel>();
    }
    if (action == "rvi" || action == "record_video") {
      return td_api::make_object<td_api::chatActionRecordingVideo>();
    }
    if (action == "uvi" || action == "upload_video") {
      return td_api::make_object<td_api::chatActionUploadingVideo>(50);
    }
    if (action == "rvo" || action == "record_voice") {
      return td_api::make_object<td_api::chatActionRecordingVoiceNote>();
    }
    if (action == "uvo" || action == "upload_voice") {
      return td_api::make_object<td_api::chatActionUploadingVoiceNote>(50);
    }
    if (action == "up" || action == "upload_photo") {
      return td_api::make_object<td_api::chatActionUploadingPhoto>(50);
    }
    if (action == "ud" || action == "upload_document") {
      return td_api::make_object<td_api::chatActionUploadingDocument>(50);
    }
    if (action == "fl" || action == "find_location") {
      return td_api::make_object<td_api::chatActionChoosingLocation>();
    }
    if (action == "cc" || action == "choose_contact") {
      return td_api::make_object<td_api::chatActionChoosingContact>();
    }
    if (action == "spg" || action == "start_play_game") {
      return td_api::make_object<td_api::chatActionStartPlayingGame>();
    }
    if (action == "rvn" || action == "record_video_note") {
      return td_api::make_object<td_api::chatActionRecordingVideoNote>();
    }
    if (action == "uvn" || action == "upload_video_note") {
      return td_api::make_object<td_api::chatActionUploadingVideoNote>(50);
    }
    if (action == "cs" || action == "choose_sticker") {
      return td_api::make_object<td_api::chatActionChoosingSticker>();
    }
    if (begins_with(action, "wa")) {
      return td_api::make_object<td_api::chatActionWatchingAnimations>(action.substr(2).str());
    }
    return td_api::make_object<td_api::chatActionTyping>();
  }

  static td_api::object_ptr<td_api::ReportReason> as_report_reason(string reason) {
    reason = trim(reason);
    if (reason == "null") {
      return nullptr;
    }
    if (reason == "spam") {
      return td_api::make_object<td_api::reportReasonSpam>();
    }
    if (reason == "violence") {
      return td_api::make_object<td_api::reportReasonViolence>();
    }
    if (reason == "porno") {
      return td_api::make_object<td_api::reportReasonPornography>();
    }
    if (reason == "ca") {
      return td_api::make_object<td_api::reportReasonChildAbuse>();
    }
    if (reason == "copyright") {
      return td_api::make_object<td_api::reportReasonCopyright>();
    }
    if (reason == "geo" || reason == "location") {
      return td_api::make_object<td_api::reportReasonUnrelatedLocation>();
    }
    if (reason == "fake") {
      return td_api::make_object<td_api::reportReasonFake>();
    }
    if (reason == "drugs") {
      return td_api::make_object<td_api::reportReasonIllegalDrugs>();
    }
    if (reason == "pd") {
      return td_api::make_object<td_api::reportReasonPersonalDetails>();
    }
    return td_api::make_object<td_api::reportReasonCustom>();
  }

  static td_api::object_ptr<td_api::NetworkType> as_network_type(MutableSlice type) {
    type = trim(type);
    to_lower_inplace(type);
    if (type == "none") {
      return td_api::make_object<td_api::networkTypeNone>();
    }
    if (type == "mobile") {
      return td_api::make_object<td_api::networkTypeMobile>();
    }
    if (type == "roaming") {
      return td_api::make_object<td_api::networkTypeMobileRoaming>();
    }
    if (type == "wifi") {
      return td_api::make_object<td_api::networkTypeWiFi>();
    }
    if (type == "other") {
      return td_api::make_object<td_api::networkTypeOther>();
    }
    return nullptr;
  }

  td_api::object_ptr<td_api::SuggestedAction> as_suggested_action(Slice action) const {
    if (action == "unarchive") {
      return td_api::make_object<td_api::suggestedActionEnableArchiveAndMuteNewChats>();
    }
    if (action == "pass") {
      return td_api::make_object<td_api::suggestedActionCheckPassword>();
    }
    if (action == "number") {
      return td_api::make_object<td_api::suggestedActionCheckPhoneNumber>();
    }
    if (action == "checks") {
      return td_api::make_object<td_api::suggestedActionViewChecksHint>();
    }
    if (action == "extend") {
      return td_api::make_object<td_api::suggestedActionExtendPremium>("");
    }
    if (action == "annual") {
      return td_api::make_object<td_api::suggestedActionSubscribeToAnnualPremium>();
    }
    if (begins_with(action, "giga")) {
      return td_api::make_object<td_api::suggestedActionConvertToBroadcastGroup>(as_supergroup_id(action.substr(4)));
    }
    if (begins_with(action, "spass")) {
      return td_api::make_object<td_api::suggestedActionSetPassword>(to_integer<int32>(action.substr(5)));
    }
    return nullptr;
  }

  static td_api::object_ptr<td_api::EmailAddressAuthentication> as_email_address_authentication(Slice arg) {
    if (begins_with(arg, "a ")) {
      return td_api::make_object<td_api::emailAddressAuthenticationAppleId>(arg.substr(2).str());
    } else if (begins_with(arg, "g ")) {
      return td_api::make_object<td_api::emailAddressAuthenticationGoogleId>(arg.substr(2).str());
    } else if (!arg.empty()) {
      return td_api::make_object<td_api::emailAddressAuthenticationCode>(arg.str());
    }
    return nullptr;
  }

  static td_api::object_ptr<td_api::PassportElementType> as_passport_element_type(Slice passport_element_type) {
    if (passport_element_type == "address" || passport_element_type == "a") {
      return td_api::make_object<td_api::passportElementTypeAddress>();
    }
    if (passport_element_type == "email" || passport_element_type == "e") {
      return td_api::make_object<td_api::passportElementTypeEmailAddress>();
    }
    if (passport_element_type == "phone" || passport_element_type == "p") {
      return td_api::make_object<td_api::passportElementTypePhoneNumber>();
    }
    if (passport_element_type == "pd") {
      return td_api::make_object<td_api::passportElementTypePersonalDetails>();
    }
    if (passport_element_type == "dl") {
      return td_api::make_object<td_api::passportElementTypeDriverLicense>();
    }
    if (passport_element_type == "ip") {
      return td_api::make_object<td_api::passportElementTypeInternalPassport>();
    }
    if (passport_element_type == "ic") {
      return td_api::make_object<td_api::passportElementTypeIdentityCard>();
    }
    if (passport_element_type == "ra") {
      return td_api::make_object<td_api::passportElementTypeRentalAgreement>();
    }
    if (passport_element_type == "pr") {
      return td_api::make_object<td_api::passportElementTypePassportRegistration>();
    }
    if (passport_element_type == "tr") {
      return td_api::make_object<td_api::passportElementTypeTemporaryRegistration>();
    }
    return td_api::make_object<td_api::passportElementTypePassport>();
  }

  static auto as_passport_element_types(Slice types) {
    return transform(autosplit(types), as_passport_element_type);
  }

  static td_api::object_ptr<td_api::InputPassportElement> as_input_passport_element(const string &passport_element_type,
                                                                                    const string &arg,
                                                                                    bool with_selfie) {
    vector<td_api::object_ptr<td_api::InputFile>> input_files;
    td_api::object_ptr<td_api::InputFile> selfie;
    if (!arg.empty()) {
      auto files = autosplit(arg);
      CHECK(!files.empty());
      if (with_selfie) {
        selfie = as_input_file(files.back());
        files.pop_back();
      }
      for (const auto &file : files) {
        input_files.push_back(as_input_file(file));
      }
    }
    if (passport_element_type == "address" || passport_element_type == "a") {
      return td_api::make_object<td_api::inputPassportElementAddress>(
          td_api::make_object<td_api::address>("US", "CA", "Los Angeles", "Washington", "", "90001"));
    } else if (passport_element_type == "email" || passport_element_type == "e") {
      return td_api::make_object<td_api::inputPassportElementEmailAddress>(arg);
    } else if (passport_element_type == "phone" || passport_element_type == "p") {
      return td_api::make_object<td_api::inputPassportElementPhoneNumber>(arg);
    } else if (passport_element_type == "pd") {
      return td_api::make_object<td_api::inputPassportElementPersonalDetails>(
          td_api::make_object<td_api::personalDetails>("Mike", "Jr", "Towers", u8"Mike\u2708", u8"Jr\u26fd",
                                                       u8"Towers\u2757", td_api::make_object<td_api::date>(29, 2, 2000),
                                                       "male", "US", "GB"));
    } else if (passport_element_type == "driver_license" || passport_element_type == "dl") {
      if (input_files.size() >= 2) {
        auto front_side = std::move(input_files[0]);
        input_files.erase(input_files.begin());
        auto reverse_side = std::move(input_files[0]);
        input_files.erase(input_files.begin());
        return td_api::make_object<td_api::inputPassportElementDriverLicense>(
            td_api::make_object<td_api::inputIdentityDocument>(
                "1234567890", td_api::make_object<td_api::date>(1, 3, 2029), std::move(front_side),
                std::move(reverse_side), std::move(selfie), std::move(input_files)));
      }
    } else if (passport_element_type == "identity_card" || passport_element_type == "ic") {
      if (input_files.size() >= 2) {
        auto front_side = std::move(input_files[0]);
        input_files.erase(input_files.begin());
        auto reverse_side = std::move(input_files[0]);
        input_files.erase(input_files.begin());
        return td_api::make_object<td_api::inputPassportElementIdentityCard>(
            td_api::make_object<td_api::inputIdentityDocument>("1234567890", nullptr, std::move(front_side),
                                                               std::move(reverse_side), std::move(selfie),
                                                               std::move(input_files)));
      }
    } else if (passport_element_type == "internal_passport" || passport_element_type == "ip") {
      if (!input_files.empty()) {
        auto front_side = std::move(input_files[0]);
        input_files.erase(input_files.begin());
        return td_api::make_object<td_api::inputPassportElementInternalPassport>(
            td_api::make_object<td_api::inputIdentityDocument>("1234567890", nullptr, std::move(front_side), nullptr,
                                                               std::move(selfie), std::move(input_files)));
      }
    } else if (passport_element_type == "rental_agreement" || passport_element_type == "ra") {
      vector<td_api::object_ptr<td_api::InputFile>> translation;
      if (selfie != nullptr) {
        translation.push_back(std::move(selfie));
      }
      return td_api::make_object<td_api::inputPassportElementRentalAgreement>(
          td_api::make_object<td_api::inputPersonalDocument>(std::move(input_files), std::move(translation)));
    }

    LOG(ERROR) << "Unsupported passport element type " << passport_element_type;
    return nullptr;
  }

  static td_api::object_ptr<td_api::languagePackInfo> as_language_pack_info(const string &language_code,
                                                                            const string &name,
                                                                            const string &native_name) {
    return td_api::make_object<td_api::languagePackInfo>(language_code, "test", name, native_name, "en", true, true,
                                                         true, true, -1, 5, 3, "abacaba");
  }

  td_api::object_ptr<td_api::MessageSelfDestructType> get_message_self_destruct_type() const {
    if (message_self_destruct_time_ == -1) {
      return td_api::make_object<td_api::messageSelfDestructTypeImmediately>();
    }
    if (message_self_destruct_time_ > 0) {
      return td_api::make_object<td_api::messageSelfDestructTypeTimer>(message_self_destruct_time_);
    }
    return nullptr;
  }

  static td_api::object_ptr<td_api::MessageSchedulingState> as_message_scheduling_state(Slice date) {
    date = trim(date);
    if (date.empty()) {
      return nullptr;
    }
    auto send_date = to_integer<int32>(date);
    if (send_date == -1) {
      return td_api::make_object<td_api::messageSchedulingStateSendWhenOnline>();
    }
    return td_api::make_object<td_api::messageSchedulingStateSendAtDate>(send_date);
  }

  static td_api::object_ptr<td_api::themeParameters> as_theme_parameters() {
    return td_api::make_object<td_api::themeParameters>(0, 1, -1, 123, 256, 65536, 123456789, 65535, 5, 55, 555, 5555,
                                                        55555, 555555, 123);
  }

  static td_api::object_ptr<td_api::webAppOpenParameters> as_web_app_open_parameters() {
    return td_api::make_object<td_api::webAppOpenParameters>(as_theme_parameters(), "android",
                                                             td_api::make_object<td_api::webAppOpenModeFullScreen>());
  }

  static td_api::object_ptr<td_api::BackgroundFill> as_background_fill(int32 color) {
    return td_api::make_object<td_api::backgroundFillSolid>(color);
  }

  static td_api::object_ptr<td_api::BackgroundFill> as_background_fill(int32 top_color, int32 bottom_color) {
    return td_api::make_object<td_api::backgroundFillGradient>(top_color, bottom_color, Random::fast(1, 7) * 45);
  }

  static td_api::object_ptr<td_api::BackgroundFill> as_background_fill(vector<int32> colors) {
    return td_api::make_object<td_api::backgroundFillFreeformGradient>(std::move(colors));
  }

  static td_api::object_ptr<td_api::backgroundTypeWallpaper> as_wallpaper_background(bool is_blurred, bool is_moving) {
    return td_api::make_object<td_api::backgroundTypeWallpaper>(is_blurred, is_moving);
  }

  static td_api::object_ptr<td_api::BackgroundType> as_solid_pattern_background(int32 color, int32 intensity,
                                                                                bool is_moving) {
    return as_gradient_pattern_background(color, color, intensity, false, is_moving);
  }

  static td_api::object_ptr<td_api::BackgroundType> as_gradient_pattern_background(int32 top_color, int32 bottom_color,
                                                                                   int32 intensity, bool is_inverted,
                                                                                   bool is_moving) {
    return td_api::make_object<td_api::backgroundTypePattern>(as_background_fill(top_color, bottom_color), intensity,
                                                              is_inverted, is_moving);
  }

  static td_api::object_ptr<td_api::BackgroundType> as_freeform_gradient_pattern_background(vector<int32> colors,
                                                                                            int32 intensity,
                                                                                            bool is_inverted,
                                                                                            bool is_moving) {
    return td_api::make_object<td_api::backgroundTypePattern>(as_background_fill(std::move(colors)), intensity,
                                                              is_inverted, is_moving);
  }

  static td_api::object_ptr<td_api::BackgroundType> as_solid_background(int32 color) {
    return td_api::make_object<td_api::backgroundTypeFill>(as_background_fill(color));
  }

  static td_api::object_ptr<td_api::BackgroundType> as_gradient_background(int32 top_color, int32 bottom_color) {
    return td_api::make_object<td_api::backgroundTypeFill>(as_background_fill(top_color, bottom_color));
  }

  static td_api::object_ptr<td_api::BackgroundType> as_freeform_gradient_background(vector<int32> colors) {
    return td_api::make_object<td_api::backgroundTypeFill>(as_background_fill(std::move(colors)));
  }

  static td_api::object_ptr<td_api::BackgroundType> as_chat_theme_background(const string &theme_name) {
    return td_api::make_object<td_api::backgroundTypeChatTheme>(theme_name);
  }

  td_api::object_ptr<td_api::phoneNumberAuthenticationSettings> as_phone_number_authentication_settings() const {
    return td_api::make_object<td_api::phoneNumberAuthenticationSettings>(false, true, false, false, false, nullptr,
                                                                          vector<string>(authentication_tokens_));
  }

  static td_api::object_ptr<td_api::Object> execute(td_api::object_ptr<td_api::Function> f) {
    if (combined_log.get_first_verbosity_level() < get_log_tag_verbosity_level("td_requests")) {
      LOG(ERROR) << "Execute request: " << to_string(f);
    }
    auto res = ClientActor::execute(std::move(f));
    if (combined_log.get_first_verbosity_level() < get_log_tag_verbosity_level("td_requests")) {
      LOG(ERROR) << "Execute response: " << to_string(res);
    }
    return res;
  }

  uint64 send_request(td_api::object_ptr<td_api::Function> f) {
    static uint64 query_num = 1;
    if (!td_client_.empty()) {
      auto id = query_num++;
      send_closure_later(td_client_, &ClientActor::request, id, std::move(f));
      return id;
    } else {
      LOG(ERROR) << "Failed to send: " << to_string(f);
      return 0;
    }
  }

  static int32 get_log_tag_verbosity_level(const string &name) {
    auto level = ClientActor::execute(td_api::make_object<td_api::getLogTagVerbosityLevel>(name));
    if (level->get_id() == td_api::error::ID) {
      return -1;
    }
    CHECK(level->get_id() == td_api::logVerbosityLevel::ID);
    return static_cast<const td_api::logVerbosityLevel *>(level.get())->verbosity_level_;
  }

  void send_message(int64 chat_id, td_api::object_ptr<td_api::InputMessageContent> &&input_message_content,
                    bool disable_notification = false, bool from_background = false) {
    if (!business_connection_id_.empty()) {
      send_request(td_api::make_object<td_api::sendBusinessMessage>(
          business_connection_id_, chat_id, get_input_message_reply_to(), disable_notification, rand_bool(),
          message_effect_id_, nullptr, std::move(input_message_content)));
      return;
    }
    if (!quick_reply_shortcut_name_.empty()) {
      send_request(td_api::make_object<td_api::addQuickReplyShortcutMessage>(
          quick_reply_shortcut_name_, reply_message_id_, std::move(input_message_content)));
      return;
    }
    auto id = send_request(td_api::make_object<td_api::sendMessage>(
        chat_id, message_thread_id_, get_input_message_reply_to(),
        td_api::make_object<td_api::messageSendOptions>(
            disable_notification, from_background, false, use_test_dc_, paid_message_star_count_, false,
            as_message_scheduling_state(schedule_date_), message_effect_id_, Random::fast(1, 1000), only_preview_),
        nullptr, std::move(input_message_content)));
    if (id != 0) {
      query_id_to_send_message_info_[id].start_time = Time::now();
    }
  }

  td_api::object_ptr<td_api::messageSendOptions> default_message_send_options() const {
    return td_api::make_object<td_api::messageSendOptions>(false, false, false, use_test_dc_, paid_message_star_count_,
                                                           true, as_message_scheduling_state(schedule_date_),
                                                           message_effect_id_, Random::fast(1, 1000), only_preview_);
  }

  void send_get_background_url(td_api::object_ptr<td_api::BackgroundType> &&background_type) {
    send_request(td_api::make_object<td_api::getBackgroundUrl>("asd", std::move(background_type)));
  }

  void on_cmd(string cmd) {
    for (size_t i = 0; i < cmd.size();) {
      // https://en.wikipedia.org/wiki/ANSI_escape_code#Terminal_input_sequences
      if (cmd[i] == 27 && cmd[i + 1] == '[') {
        // likely an ANSI escape code
        auto j = i + 2;
        if ('1' <= cmd[j] && cmd[j] <= '9') {
          while ('0' <= cmd[j] && cmd[j] <= '9') {
            j++;
          }
        }
        if ('A' <= cmd[j] && cmd[j] <= 'Z') {
          // xterm sequence
          cmd = cmd.substr(0, i) + cmd.substr(j + 1);
          continue;
        }
        if (cmd[j] == ';' && '1' <= cmd[j + 1] && cmd[j + 1] <= '9') {
          j += 2;
          while ('0' <= cmd[j] && cmd[j] <= '9') {
            j++;
          }
        }
        if (cmd[j] == '~') {
          // vt sequence
          cmd = cmd.substr(0, i) + cmd.substr(j + 1);
          continue;
        }
      }
      i++;
    }
    td::remove_if(cmd, [](unsigned char c) { return c < 32; });
    LOG(INFO) << "CMD:[" << cmd << "]";

    string op;
    string args;
    std::tie(op, args) = split(cmd);

    const int32 OP_BLOCK_COUNT = 19;
    int32 op_not_found_count = 0;

    if (op == "gas") {
      LOG(ERROR) << to_string(authorization_state_);
    } else if (op == "sap" || op == "sapn") {
      send_request(
          td_api::make_object<td_api::setAuthenticationPhoneNumber>(args, as_phone_number_authentication_settings()));
    } else if (op == "sae" || op == "saea") {
      send_request(td_api::make_object<td_api::setAuthenticationEmailAddress>(args));
    } else if (op == "rac") {
      send_request(td_api::make_object<td_api::resendAuthenticationCode>(nullptr));
    } else if (op == "sdek") {
      send_request(td_api::make_object<td_api::setDatabaseEncryptionKey>(args));
    } else if (op == "caec") {
      send_request(td_api::make_object<td_api::checkAuthenticationEmailCode>(as_email_address_authentication(args)));
    } else if (op == "cac") {
      send_request(td_api::make_object<td_api::checkAuthenticationCode>(args));
    } else if (op == "racmg") {
      send_request(td_api::make_object<td_api::reportAuthenticationCodeMissing>(args));
    } else if (op == "ru" || op == "rus") {
      string first_name;
      string last_name;
      get_args(args, first_name, last_name);
      send_request(td_api::make_object<td_api::registerUser>(first_name, last_name, op == "rus"));
    } else if (op == "cap") {
      send_request(td_api::make_object<td_api::checkAuthenticationPassword>(args));
    } else if (op == "cabt") {
      send_request(td_api::make_object<td_api::checkAuthenticationBotToken>(args));
    } else if (op == "qr") {
      send_request(td_api::make_object<td_api::requestQrCodeAuthentication>(as_user_ids(args)));
    } else if (op == "cqr") {
      send_request(td_api::make_object<td_api::confirmQrCodeAuthentication>(args));
    } else if (op == "gcs") {
      send_request(td_api::make_object<td_api::getCurrentState>());
    } else if (op == "raea") {
      send_request(td_api::make_object<td_api::resetAuthenticationEmailAddress>());
    } else if (op == "rapr") {
      send_request(td_api::make_object<td_api::requestAuthenticationPasswordRecovery>());
    } else if (op == "caprc") {
      string recovery_code = args;
      send_request(td_api::make_object<td_api::checkAuthenticationPasswordRecoveryCode>(recovery_code));
    } else if (op == "rap") {
      string recovery_code;
      string new_password;
      string new_hint;
      get_args(args, recovery_code, new_password, new_hint);
      send_request(td_api::make_object<td_api::recoverAuthenticationPassword>(recovery_code, new_password, new_hint));
    } else if (op == "lo") {
      send_request(td_api::make_object<td_api::logOut>());
    } else if (op == "destroy") {
      send_request(td_api::make_object<td_api::destroy>());
    } else if (op == "reset") {
      td_client_.reset();
    } else if (op == "close_td") {
      // send_request(td_api::make_object<td_api::getCurrentState>());
      send_request(td_api::make_object<td_api::close>());
      // send_request(td_api::make_object<td_api::getCurrentState>());
      // send_request(td_api::make_object<td_api::close>());
    } else if (op == "DeleteAccountYesIReallyWantToDeleteMyAccount") {
      string password;
      string reason;
      get_args(args, password, reason);
      send_request(td_api::make_object<td_api::deleteAccount>(reason, password));
    } else if (op == "gps") {
      send_request(td_api::make_object<td_api::getPasswordState>());
    } else if (op == "spass") {
      string password;
      string new_password;
      string new_hint;
      string recovery_email_address;
      get_args(args, password, new_password, new_hint, recovery_email_address);
      if (password == "#") {
        password = "";
      }
      if (new_password == "#") {
        new_password = "";
      }
      if (new_hint == "#") {
        new_hint = "";
      }
      if (recovery_email_address == "#") {
        recovery_email_address = "";
      }
      send_request(
          td_api::make_object<td_api::setPassword>(password, new_password, new_hint, true, recovery_email_address));
    } else if (op == "gpafhttp") {
      ChainBufferWriter writer;
      writer.append(PSLICE() << "GET " << args << " HTTP/1.1\r\n\r\n\r\n");
      ChainBufferReader reader = writer.extract_reader();
      HttpReader http_reader;
      http_reader.init(&reader);
      HttpQuery query;
      auto r_size = http_reader.read_next(&query);
      if (r_size.is_error()) {
        LOG(ERROR) << r_size.error();
        return;
      }
      string bot_user_id = query.get_arg("bot_id").str();
      string scope = query.get_arg("scope").str();
      string public_key = query.get_arg("public_key").str();
      string payload = query.get_arg("payload").str();
      LOG(INFO) << "Callback URL:" << query.get_arg("callback_url");
      send_request(td_api::make_object<td_api::getPassportAuthorizationForm>(as_user_id(bot_user_id), scope, public_key,
                                                                             payload));
    } else if (op == "gpaf") {
      UserId bot_user_id;
      string scope;
      string public_key =
          "-----BEGIN PUBLIC KEY-----\n"
          "MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAzmgKr0fPP4rB/TsNEweC\n"
          "hoG3ntUxuBTmHsFBW6CpABGdaTmKZSjAI/cTofhBgtRQIOdX0YRGHHHhwyLf49Wv\n"
          "9l+XexbJOa0lTsJSNMj8Y/9sZbqUl5ur8ZOTM0sxbXC0XKexu1tM9YavH+Lbrobk\n"
          "jt0+cmo/zEYZWNtLVihnR2IDv+7tSgiDoFWi/koAUdfJ1VMw+hReUaLg3vE9CmPK\n"
          "tQiTy+NvmrYaBPb75I0Jz3Lrz1+mZSjLKO25iT84RIsxarBDd8iYh2avWkCmvtiR\n"
          "Lcif8wLxi2QWC1rZoCA3Ip+Hg9J9vxHlzl6xT01WjUStMhfwrUW6QBpur7FJ+aKM\n"
          "oaMoHieFNCG4qIkWVEHHSsUpLum4SYuEnyNH3tkjbrdldZanCvanGq+TZyX0buRt\n"
          "4zk7FGcu8iulUkAP/o/WZM0HKinFN/vuzNVA8iqcO/BBhewhzpqmmTMnWmAO8WPP\n"
          "DJMABRtXJnVuPh1CI5pValzomLJM4/YvnJGppzI1QiHHNA9JtxVmj2xf8jaXa1LJ\n"
          "WUNJK+RvUWkRUxpWiKQQO9FAyTPLRtDQGN9eUeDR1U0jqRk/gNT8smHGN6I4H+NR\n"
          "3X3/1lMfcm1dvk654ql8mxjCA54IpTPr/icUMc7cSzyIiQ7Tp9PZTl1gHh281ZWf\n"
          "P7d2+fuJMlkjtM7oAwf+tI8CAwEAAQ==\n"
          "-----END PUBLIC KEY-----";
      string payload;
      get_args(args, bot_user_id, scope, payload);
      send_request(td_api::make_object<td_api::getPassportAuthorizationForm>(bot_user_id, scope, public_key, payload));
    } else if (op == "gpafae") {
      int32 form_id;
      string password;
      get_args(args, form_id, password);
      send_request(td_api::make_object<td_api::getPassportAuthorizationFormAvailableElements>(form_id, password));
    } else if (op == "spaf") {
      int32 form_id;
      string types;
      get_args(args, form_id, types);
      send_request(
          td_api::make_object<td_api::sendPassportAuthorizationForm>(form_id, as_passport_element_types(types)));
    } else if (op == "gpcl") {
      send_request(td_api::make_object<td_api::getPreferredCountryLanguage>(args));
    } else if (op == "seavc") {
      send_request(td_api::make_object<td_api::sendEmailAddressVerificationCode>(args));
    } else if (op == "ceavc") {
      send_request(td_api::make_object<td_api::checkEmailAddressVerificationCode>(args));
    } else if (op == "reavc") {
      send_request(td_api::make_object<td_api::resendEmailAddressVerificationCode>());
    } else if (op == "slea") {
      send_request(td_api::make_object<td_api::setLoginEmailAddress>(args));
    } else if (op == "rleac") {
      send_request(td_api::make_object<td_api::resendLoginEmailAddressCode>());
    } else if (op == "cleac") {
      send_request(td_api::make_object<td_api::checkLoginEmailAddressCode>(as_email_address_authentication(args)));
    } else if (op == "srea") {
      string password;
      string recovery_email_address;
      get_args(args, password, recovery_email_address);
      send_request(td_api::make_object<td_api::setRecoveryEmailAddress>(password, recovery_email_address));
    } else if (op == "grea") {
      send_request(td_api::make_object<td_api::getRecoveryEmailAddress>(args));
    } else if (op == "creac") {
      send_request(td_api::make_object<td_api::checkRecoveryEmailAddressCode>(args));
    } else if (op == "rreac") {
      send_request(td_api::make_object<td_api::resendRecoveryEmailAddressCode>());
    } else if (op == "creav") {
      send_request(td_api::make_object<td_api::cancelRecoveryEmailAddressVerification>());
    } else {
      op_not_found_count++;
    }

    if (op == "rpr") {
      send_request(td_api::make_object<td_api::requestPasswordRecovery>());
    } else if (op == "cprc") {
      string recovery_code = args;
      send_request(td_api::make_object<td_api::checkPasswordRecoveryCode>(recovery_code));
    } else if (op == "rp") {
      string recovery_code;
      string new_password;
      string new_hint;
      get_args(args, recovery_code, new_password, new_hint);
      send_request(td_api::make_object<td_api::recoverPassword>(recovery_code, new_password, new_hint));
    } else if (op == "resetp") {
      send_request(td_api::make_object<td_api::resetPassword>());
    } else if (op == "cpr") {
      send_request(td_api::make_object<td_api::cancelPasswordReset>());
    } else if (op == "gtp") {
      send_request(td_api::make_object<td_api::getTemporaryPasswordState>());
    } else if (op == "ctp") {
      send_request(td_api::make_object<td_api::createTemporaryPassword>(args, 60 * 6));
    } else if (op == "gpe") {
      string password;
      string passport_element_type;
      get_args(args, password, passport_element_type);
      send_request(
          td_api::make_object<td_api::getPassportElement>(as_passport_element_type(passport_element_type), password));
    } else if (op == "gape") {
      string password = args;
      send_request(td_api::make_object<td_api::getAllPassportElements>(password));
    } else if (op == "spe" || op == "spes") {
      string password;
      string passport_element_type;
      string arg;
      get_args(args, password, passport_element_type, arg);
      send_request(td_api::make_object<td_api::setPassportElement>(
          as_input_passport_element(passport_element_type, arg, op == "spes"), password));
    } else if (op == "dpe") {
      const string &passport_element_type = args;
      send_request(td_api::make_object<td_api::deletePassportElement>(as_passport_element_type(passport_element_type)));
    } else if (op == "ppn") {
      send_request(td_api::make_object<td_api::processPushNotification>(args));
    } else if (op == "gpri") {
      send_request(td_api::make_object<td_api::getPushReceiverId>(args));
    } else if (op == "rda") {
      send_request(td_api::make_object<td_api::registerDevice>(
          td_api::make_object<td_api::deviceTokenApplePush>(args, true), as_user_ids("")));
    } else if (op == "rdb") {
      send_request(td_api::make_object<td_api::registerDevice>(
          td_api::make_object<td_api::deviceTokenBlackBerryPush>(args), as_user_ids("")));
    } else if (op == "rdf") {
      send_request(td_api::make_object<td_api::registerDevice>(
          td_api::make_object<td_api::deviceTokenFirebaseCloudMessaging>(args, true), as_user_ids("")));
    } else if (op == "rdt") {
      string token;
      string other_user_ids_str;
      get_args(args, token, other_user_ids_str);
      send_request(td_api::make_object<td_api::registerDevice>(td_api::make_object<td_api::deviceTokenTizenPush>(token),
                                                               as_user_ids(other_user_ids_str)));
    } else if (op == "rdu") {
      string token;
      string other_user_ids_str;
      get_args(args, token, other_user_ids_str);
      send_request(td_api::make_object<td_api::registerDevice>(
          td_api::make_object<td_api::deviceTokenUbuntuPush>(token), as_user_ids(other_user_ids_str)));
    } else if (op == "rdw") {
      string endpoint;
      string key;
      string secret;
      string other_user_ids_str;
      get_args(args, endpoint, key, secret, other_user_ids_str);
      send_request(td_api::make_object<td_api::registerDevice>(
          td_api::make_object<td_api::deviceTokenWebPush>(endpoint, key, secret), as_user_ids(other_user_ids_str)));
    } else if (op == "gbci") {
      send_request(td_api::make_object<td_api::getBankCardInfo>(args));
    } else if (op == "gpf") {
      InputInvoice input_invoice;
      get_args(args, input_invoice);
      send_request(td_api::make_object<td_api::getPaymentForm>(input_invoice, as_theme_parameters()));
    } else if (op == "voi") {
      InputInvoice input_invoice;
      bool allow_save;
      get_args(args, input_invoice, allow_save);
      send_request(td_api::make_object<td_api::validateOrderInfo>(input_invoice, nullptr, allow_save));
    } else if (op == "spfs") {
      InputInvoice input_invoice;
      int64 tip_amount;
      int64 payment_form_id;
      string order_info_id;
      string shipping_option_id;
      string saved_credentials_id;
      get_args(args, input_invoice, tip_amount, payment_form_id, order_info_id, shipping_option_id,
               saved_credentials_id);
      send_request(td_api::make_object<td_api::sendPaymentForm>(
          input_invoice, payment_form_id, order_info_id, shipping_option_id,
          td_api::make_object<td_api::inputCredentialsSaved>(saved_credentials_id), tip_amount));
    } else if (op == "spfn") {
      InputInvoice input_invoice;
      int64 tip_amount;
      int64 payment_form_id;
      string order_info_id;
      string shipping_option_id;
      string data;
      get_args(args, input_invoice, tip_amount, payment_form_id, order_info_id, shipping_option_id, data);
      send_request(td_api::make_object<td_api::sendPaymentForm>(
          input_invoice, payment_form_id, order_info_id, shipping_option_id,
          td_api::make_object<td_api::inputCredentialsNew>(data, true), tip_amount));
    } else if (op == "spfstar") {
      InputInvoice input_invoice;
      int64 payment_form_id;
      get_args(args, input_invoice, payment_form_id);
      send_request(
          td_api::make_object<td_api::sendPaymentForm>(input_invoice, payment_form_id, string(), string(), nullptr, 0));
    } else if (op == "gpre") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getPaymentReceipt>(chat_id, message_id));
    } else if (op == "gsoi") {
      send_request(td_api::make_object<td_api::getSavedOrderInfo>());
    } else if (op == "dsoi") {
      send_request(td_api::make_object<td_api::deleteSavedOrderInfo>());
    } else if (op == "dsc") {
      send_request(td_api::make_object<td_api::deleteSavedCredentials>());
    } else if (op == "gag") {
      send_request(td_api::make_object<td_api::getAvailableGifts>());
    } else if (op == "sendg" || op == "sendgp" || op == "sgift") {
      int64 gift_id;
      string owner_id;
      bool pay_for_upgrade;
      string text;
      get_args(args, gift_id, owner_id, pay_for_upgrade, text);
      send_request(td_api::make_object<td_api::sendGift>(gift_id, as_message_sender(owner_id), as_formatted_text(text),
                                                         op == "sendgp", pay_for_upgrade));
    } else if (op == "sellg") {
      string star_gift_id;
      get_args(args, star_gift_id);
      send_request(td_api::make_object<td_api::sellGift>(star_gift_id));
    } else if (op == "tgis") {
      string star_gift_id;
      bool is_saved;
      get_args(args, star_gift_id, is_saved);
      send_request(td_api::make_object<td_api::toggleGiftIsSaved>(star_gift_id, is_saved));
    } else if (op == "spg") {
      string owner_id;
      string received_story_ids;
      get_args(args, owner_id, received_story_ids);
      send_request(
          td_api::make_object<td_api::setPinnedGifts>(as_message_sender(owner_id), full_split(received_story_ids)));
    } else if (op == "tcgn") {
      ChatId chat_id;
      bool are_enabled;
      get_args(args, chat_id, are_enabled);
      send_request(td_api::make_object<td_api::toggleChatGiftNotifications>(chat_id, are_enabled));
    } else if (op == "ggup") {
      int64 gift_id;
      get_args(args, gift_id);
      send_request(td_api::make_object<td_api::getGiftUpgradePreview>(gift_id));
    } else if (op == "ug") {
      string received_gift_id;
      bool keep_original_details;
      int64 star_count;
      get_args(args, received_gift_id, keep_original_details, star_count);
      send_request(td_api::make_object<td_api::upgradeGift>(received_gift_id, keep_original_details, star_count));
    } else if (op == "tg") {
      string received_gift_id;
      string new_owner_id;
      int64 star_count;
      get_args(args, received_gift_id, new_owner_id, star_count);
      send_request(
          td_api::make_object<td_api::transferGift>(received_gift_id, as_message_sender(new_owner_id), star_count));
    } else if (op == "grgs" || op == "grgsp") {
      string owner_id;
      int32 limit;
      string offset;
      bool exclude_unsaved;
      bool exclude_saved;
      bool exclude_unlimited;
      bool exclude_limited;
      bool exclude_upgraded;
      get_args(args, owner_id, limit, offset, exclude_unsaved, exclude_saved, exclude_unlimited, exclude_limited,
               exclude_upgraded);
      send_request(td_api::make_object<td_api::getReceivedGifts>(as_message_sender(owner_id), exclude_unsaved,
                                                                 exclude_saved, exclude_unlimited, exclude_limited,
                                                                 exclude_upgraded, op == "grgsp", offset, limit));
    } else if (op == "grg") {
      string received_gift_id;
      get_args(args, received_gift_id);
      send_request(td_api::make_object<td_api::getReceivedGift>(received_gift_id));
    } else if (op == "gug") {
      string name;
      get_args(args, name);
      send_request(td_api::make_object<td_api::getUpgradedGift>(name));
    } else if (op == "gugwu") {
      string received_gift_id;
      string password;
      get_args(args, received_gift_id, password);
      send_request(td_api::make_object<td_api::getUpgradedGiftWithdrawalUrl>(received_gift_id, password));
    } else if (op == "rsp") {
      UserId user_id;
      string telegram_payment_charge_id;
      get_args(args, user_id, telegram_payment_charge_id);
      send_request(td_api::make_object<td_api::refundStarPayment>(user_id, telegram_payment_charge_id));
    } else if (op == "gpr") {
      send_request(td_api::make_object<td_api::getUserPrivacySettingRules>(as_user_privacy_setting(args)));
    } else if (op == "spr") {
      string setting;
      PrivacyRules rules;
      get_args(args, setting, rules);
      send_request(td_api::make_object<td_api::setUserPrivacySettingRules>(as_user_privacy_setting(setting), rules));
    } else if (op == "spncc") {
      send_request(td_api::make_object<td_api::sendPhoneNumberCode>(
          args, nullptr, td_api::make_object<td_api::phoneNumberCodeTypeChange>()));
    } else if (op == "spncv") {
      send_request(td_api::make_object<td_api::sendPhoneNumberCode>(
          args, nullptr, td_api::make_object<td_api::phoneNumberCodeTypeVerify>()));
    } else if (op == "spncco") {
      string hash;
      string phone_number;
      get_args(args, hash, phone_number);
      send_request(td_api::make_object<td_api::sendPhoneNumberCode>(
          phone_number, nullptr, td_api::make_object<td_api::phoneNumberCodeTypeConfirmOwnership>(hash)));
    } else if (op == "spnfs") {
      send_request(td_api::make_object<td_api::sendPhoneNumberFirebaseSms>(args));
    } else if (op == "rpncm") {
      send_request(td_api::make_object<td_api::reportPhoneNumberCodeMissing>(args));
    } else if (op == "rpnc") {
      send_request(td_api::make_object<td_api::resendPhoneNumberCode>(nullptr));
    } else if (op == "cpnc") {
      send_request(td_api::make_object<td_api::checkPhoneNumberCode>(args));
    } else if (op == "gco") {
      if (args.empty()) {
        send_request(td_api::make_object<td_api::getContacts>());
      } else {
        send_request(td_api::make_object<td_api::searchContacts>("", as_limit(args)));
      }
    } else if (op == "gcfr") {
      send_request(td_api::make_object<td_api::getCloseFriends>());
    } else if (op == "scfr") {
      send_request(td_api::make_object<td_api::setCloseFriends>(as_user_ids(args)));
    } else if (op == "gul") {
      send_request(td_api::make_object<td_api::getUserLink>());
    } else if (op == "subt") {
      send_request(td_api::make_object<td_api::searchUserByToken>(args));
    } else if (op == "aco") {
      UserId user_id;
      string first_name;
      string last_name;
      get_args(args, user_id, first_name, last_name);
      send_request(td_api::make_object<td_api::addContact>(
          td_api::make_object<td_api::contact>(string(), first_name, last_name, string(), user_id), false));
    } else if (op == "subpn" || op == "subpnl") {
      string phone_number;
      get_args(args, phone_number);
      send_request(td_api::make_object<td_api::searchUserByPhoneNumber>(phone_number, op == "subpnl"));
    } else if (op == "spn") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::sharePhoneNumber>(user_id));
    } else if (op == "ic" || op == "cic") {
      vector<string> contacts_str = full_split(args, ';');
      vector<td_api::object_ptr<td_api::contact>> contacts;
      for (auto c : contacts_str) {
        string phone_number;
        string first_name;
        string last_name;
        std::tie(phone_number, c) = split(c, ',');
        std::tie(first_name, last_name) = split(c, ',');
        contacts.push_back(td_api::make_object<td_api::contact>(phone_number, first_name, last_name, string(), 0));
      }
      if (op == "cic") {
        send_request(td_api::make_object<td_api::changeImportedContacts>(std::move(contacts)));
      } else {
        send_request(td_api::make_object<td_api::importContacts>(std::move(contacts)));
      }
    } else if (op == "rco") {
      send_request(td_api::make_object<td_api::removeContacts>(as_user_ids(args)));
    } else if (op == "gicc") {
      send_request(td_api::make_object<td_api::getImportedContactCount>());
    } else if (op == "cico") {
      send_request(td_api::make_object<td_api::clearImportedContacts>());
    } else {
      op_not_found_count++;
    }

    if (op == "gc" || op == "gca" || begins_with(op, "gc-")) {
      send_request(td_api::make_object<td_api::getChats>(as_chat_list(op), as_limit(args, 10000)));
    } else if (op == "lc" || op == "lca" || begins_with(op, "lc-")) {
      send_request(td_api::make_object<td_api::loadChats>(as_chat_list(op), as_limit(args, 10000)));
    } else if (op == "gctest") {
      send_request(td_api::make_object<td_api::getChats>(nullptr, 1));
      send_request(td_api::make_object<td_api::getChats>(nullptr, 10));
      send_request(td_api::make_object<td_api::getChats>(nullptr, 5));
    } else if (op == "lsmt") {
      string limit;
      get_args(args, limit);
      send_request(td_api::make_object<td_api::loadSavedMessagesTopics>(as_limit(limit)));
    } else if (op == "gsmth") {
      MessageId from_message_id;
      int32 offset;
      string limit;
      get_args(args, from_message_id, offset, limit);
      send_request(td_api::make_object<td_api::getSavedMessagesTopicHistory>(get_saved_messages_topic_id(),
                                                                             from_message_id, offset, as_limit(limit)));
    } else if (op == "gsmtmbd") {
      send_request(td_api::make_object<td_api::getSavedMessagesTopicMessageByDate>(get_saved_messages_topic_id(),
                                                                                   to_integer<int32>(args)));
    } else if (op == "dsmth" && args.empty()) {
      send_request(td_api::make_object<td_api::deleteSavedMessagesTopicHistory>(get_saved_messages_topic_id()));
    } else if (op == "dsmtmbd") {
      int32 min_date;
      int32 max_date;
      get_args(args, min_date, max_date);
      send_request(td_api::make_object<td_api::deleteSavedMessagesTopicMessagesByDate>(get_saved_messages_topic_id(),
                                                                                       min_date, max_date));
    } else if (op == "tsmtip") {
      bool is_pinned;
      get_args(args, is_pinned);
      send_request(
          td_api::make_object<td_api::toggleSavedMessagesTopicIsPinned>(get_saved_messages_topic_id(), is_pinned));
    } else if (op == "spsmt") {
      send_request(td_api::make_object<td_api::setPinnedSavedMessagesTopics>(
          transform(autosplit(args), [this](Slice str) { return as_saved_messages_topic_id(as_chat_id(str)); })));
    } else if (op == "gcc") {
      UserId user_id;
      ChatId offset_chat_id;
      string limit;
      get_args(args, user_id, offset_chat_id, limit);
      send_request(td_api::make_object<td_api::getGroupsInCommon>(user_id, offset_chat_id, as_limit(limit, 100)));
    } else if (op == "gh" || op == "ghl" || op == "gmth") {
      ChatId chat_id;
      MessageId thread_message_id;
      MessageId from_message_id;
      int32 offset;
      string limit;
      get_args(args, chat_id, args);
      if (op == "gmth") {
        get_args(args, thread_message_id, args);
      }
      get_args(args, from_message_id, offset, limit);
      if (op == "gmth") {
        send_request(td_api::make_object<td_api::getMessageThreadHistory>(chat_id, thread_message_id, from_message_id,
                                                                          offset, as_limit(limit)));
      } else {
        send_request(td_api::make_object<td_api::getChatHistory>(chat_id, from_message_id, offset, as_limit(limit),
                                                                 op == "ghl"));
      }
    } else if (op == "gcsm") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatScheduledMessages>(chat_id));
    } else if (op == "sdrt") {
      string reaction;
      get_args(args, reaction);
      send_request(td_api::make_object<td_api::setDefaultReactionType>(as_reaction_type(reaction)));
    } else if (op == "ger") {
      string emoji;
      get_args(args, emoji);
      send_request(td_api::make_object<td_api::getEmojiReaction>(emoji));
    } else if (op == "gcera") {
      send_request(td_api::make_object<td_api::getCustomEmojiReactionAnimations>());
    } else if (op == "gmar") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getMessageAvailableReactions>(chat_id, message_id, 8));
    } else if (op == "crr") {
      send_request(td_api::make_object<td_api::clearRecentReactions>());
    } else if (op == "amr" || op == "react") {
      ChatId chat_id;
      MessageId message_id;
      string reaction;
      bool is_big;
      bool update_recent_reactions;
      get_args(args, chat_id, message_id, reaction, is_big, update_recent_reactions);
      send_request(td_api::make_object<td_api::addMessageReaction>(chat_id, message_id, as_reaction_type(reaction),
                                                                   is_big, update_recent_reactions));
    } else if (op == "rmr") {
      ChatId chat_id;
      MessageId message_id;
      string reaction;
      get_args(args, chat_id, message_id, reaction);
      send_request(td_api::make_object<td_api::removeMessageReaction>(chat_id, message_id, as_reaction_type(reaction)));
    } else if (op == "reactbot" || op == "reactbotbig") {
      ChatId chat_id;
      MessageId message_id;
      string reactions;
      get_args(args, chat_id, message_id, reactions);
      auto reaction_types = transform(autosplit_str(reactions), as_reaction_type);
      send_request(td_api::make_object<td_api::setMessageReactions>(chat_id, message_id, std::move(reaction_types),
                                                                    op == "reactbotbig"));
    } else if (op == "gcapmrs") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatAvailablePaidMessageReactionSenders>(chat_id));
    } else if (op == "appmr" || op == "appmra" || op == "appmrd") {
      ChatId chat_id;
      MessageId message_id;
      int64 star_count;
      ChatId reaction_chat_id;
      get_args(args, chat_id, message_id, star_count, reaction_chat_id);
      td_api::object_ptr<td_api::PaidReactionType> type;
      if (op == "appmr") {
        if (reaction_chat_id != 0) {
          type = td_api::make_object<td_api::paidReactionTypeChat>(reaction_chat_id);
        } else {
          type = td_api::make_object<td_api::paidReactionTypeRegular>();
        }
      } else if (op == "appmra") {
        type = td_api::make_object<td_api::paidReactionTypeAnonymous>();
      }
      send_request(
          td_api::make_object<td_api::addPendingPaidMessageReaction>(chat_id, message_id, star_count, std::move(type)));
    } else if (op == "cppmr") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::commitPendingPaidMessageReactions>(chat_id, message_id));
    } else if (op == "rppmr") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::removePendingPaidMessageReactions>(chat_id, message_id));
    } else if (op == "spmrt" || op == "spmrta") {
      ChatId chat_id;
      MessageId message_id;
      ChatId reaction_chat_id;
      get_args(args, chat_id, message_id, reaction_chat_id);
      td_api::object_ptr<td_api::PaidReactionType> type;
      if (op == "spmrt") {
        if (reaction_chat_id != 0) {
          type = td_api::make_object<td_api::paidReactionTypeChat>(reaction_chat_id);
        } else {
          type = td_api::make_object<td_api::paidReactionTypeRegular>();
        }
      } else if (op == "spmrta") {
        type = td_api::make_object<td_api::paidReactionTypeAnonymous>();
      }
      send_request(td_api::make_object<td_api::setPaidMessageReactionType>(chat_id, message_id, std::move(type)));
    } else if (op == "gmars") {
      ChatId chat_id;
      MessageId message_id;
      string reaction;
      string offset;
      string limit;
      get_args(args, chat_id, message_id, reaction, offset, limit);
      send_request(td_api::make_object<td_api::getMessageAddedReactions>(
          chat_id, message_id, as_reaction_type(reaction), offset, as_limit(limit)));
    } else if (op == "gsmts") {
      send_request(td_api::make_object<td_api::getSavedMessagesTags>(get_saved_messages_topic_id()));
    } else if (op == "ssmtl") {
      string reaction;
      string label;
      get_args(args, reaction, label);
      send_request(td_api::make_object<td_api::setSavedMessagesTagLabel>(as_reaction_type(reaction), label));
    } else if (op == "gme") {
      send_request(td_api::make_object<td_api::getMessageEffect>(to_integer<int64>(args)));
    } else if (op == "gmpf") {
      ChatId chat_id;
      MessageId message_id;
      string offset;
      string limit;
      get_args(args, chat_id, message_id, offset, limit);
      send_request(td_api::make_object<td_api::getMessagePublicForwards>(chat_id, message_id, offset, as_limit(limit)));
    } else if (op == "gspf") {
      ChatId chat_id;
      StoryId story_id;
      string offset;
      string limit;
      get_args(args, chat_id, story_id, offset, limit);
      send_request(td_api::make_object<td_api::getStoryPublicForwards>(chat_id, story_id, offset, as_limit(limit)));
    } else if (op == "ghf") {
      get_history_chat_id_ = as_chat_id(args);
      send_request(td_api::make_object<td_api::getChatHistory>(get_history_chat_id_, std::numeric_limits<int64>::max(),
                                                               0, 100, false));
    } else if (op == "replies") {
      ChatId chat_id;
      string filter;
      get_args(args, chat_id, filter);
      send_request(td_api::make_object<td_api::searchChatMessages>(chat_id, "", nullptr, 0, 0, 100,
                                                                   as_search_messages_filter(filter),
                                                                   message_thread_id_, get_saved_messages_topic_id()));
    } else if (op == "spvf") {
      search_chat_id_ = as_chat_id(args);
      send_request(td_api::make_object<td_api::searchChatMessages>(
          search_chat_id_, "", nullptr, 0, 0, 100, as_search_messages_filter("pvi"), 0, get_saved_messages_topic_id()));
    } else if (op == "Search" || op == "SearchA" || op == "SearchM" || op == "SearchP" || op == "SearchG" ||
               op == "SearchC") {
      string query;
      string limit;
      string filter;
      string offset;
      get_args(args, query, limit, filter, offset);
      td_api::object_ptr<td_api::ChatList> chat_list;
      if (op == "SearchA") {
        chat_list = td_api::make_object<td_api::chatListArchive>();
      }
      if (op == "SearchM") {
        chat_list = td_api::make_object<td_api::chatListMain>();
      }
      td_api::object_ptr<td_api::SearchMessagesChatTypeFilter> chat_type_filter;
      if (op == "SearchP") {
        chat_type_filter = td_api::make_object<td_api::searchMessagesChatTypeFilterPrivate>();
      }
      if (op == "SearchG") {
        chat_type_filter = td_api::make_object<td_api::searchMessagesChatTypeFilterGroup>();
      }
      if (op == "SearchC") {
        chat_type_filter = td_api::make_object<td_api::searchMessagesChatTypeFilterChannel>();
      }
      send_request(td_api::make_object<td_api::searchMessages>(std::move(chat_list), query, offset, as_limit(limit),
                                                               as_search_messages_filter(filter),
                                                               std::move(chat_type_filter), 1, 2147483647));
    } else if (op == "SCM") {
      ChatId chat_id;
      SearchQuery query;
      get_args(args, chat_id, query);
      send_request(td_api::make_object<td_api::searchChatMessages>(chat_id, query.query, nullptr, 0, 0, query.limit,
                                                                   nullptr, 0, get_saved_messages_topic_id()));
    } else if (op == "SMME") {
      ChatId chat_id;
      string limit;
      get_args(args, chat_id, limit);
      send_request(td_api::make_object<td_api::searchChatMessages>(
          chat_id, "", td_api::make_object<td_api::messageSenderUser>(my_id_), 0, 0, as_limit(limit), nullptr, 0,
          get_saved_messages_topic_id()));
    } else if (op == "SMU" || op == "SMC") {
      ChatId chat_id;
      string sender_id;
      MessageId from_message_id;
      string limit;
      get_args(args, chat_id, sender_id, from_message_id, limit);
      send_request(td_api::make_object<td_api::searchChatMessages>(chat_id, "", as_message_sender(sender_id),
                                                                   from_message_id, 0, as_limit(limit), nullptr, 0,
                                                                   get_saved_messages_topic_id()));
    } else if (op == "SM") {
      ChatId chat_id;
      string filter;
      string limit;
      MessageId offset_message_id;
      int32 offset;
      get_args(args, chat_id, filter, limit, offset_message_id, offset);
      send_request(td_api::make_object<td_api::searchChatMessages>(chat_id, "", nullptr, offset_message_id, offset,
                                                                   as_limit(limit), as_search_messages_filter(filter),
                                                                   0, get_saved_messages_topic_id()));
    } else if (op == "SC") {
      string limit;
      string offset;
      bool only_missed;
      get_args(args, limit, offset, only_missed);
      send_request(td_api::make_object<td_api::searchCallMessages>(offset, as_limit(limit), only_missed));
    } else if (op == "sodm") {
      SearchQuery query;
      get_args(args, query);
      send_request(td_api::make_object<td_api::searchOutgoingDocumentMessages>(query.query, query.limit));
    } else if (op == "spmbt") {
      string tag;
      string limit;
      string offset;
      get_args(args, tag, limit, offset);
      send_request(td_api::make_object<td_api::searchPublicMessagesByTag>(tag, offset, as_limit(limit)));
    } else if (op == "spsbt") {
      ChatId chat_id;
      string tag;
      string limit;
      string offset;
      get_args(args, chat_id, tag, limit, offset);
      send_request(td_api::make_object<td_api::searchPublicStoriesByTag>(chat_id, tag, offset, as_limit(limit)));
    } else if (op == "spsbl") {
      string country_code;
      string state;
      string city;
      string street;
      string venue_id;
      string limit;
      string offset;
      get_args(args, country_code, state, city, street, limit, offset);
      send_request(td_api::make_object<td_api::searchPublicStoriesByLocation>(
          td_api::make_object<td_api::locationAddress>(country_code, state, city, street), offset, as_limit(limit)));
    } else if (op == "spsbv") {
      string venue_provider;
      string venue_id;
      string limit;
      string offset;
      get_args(args, venue_provider, venue_id, limit, offset);
      send_request(
          td_api::make_object<td_api::searchPublicStoriesByVenue>(venue_provider, venue_id, offset, as_limit(limit)));
    } else if (op == "gsfh") {
      string tag_prefix;
      string limit;
      get_args(args, tag_prefix, limit);
      send_request(td_api::make_object<td_api::getSearchedForTags>(tag_prefix, as_limit(limit)));
    } else if (op == "rsfh") {
      string tag;
      get_args(args, tag);
      send_request(td_api::make_object<td_api::removeSearchedForTag>(tag));
    } else if (op == "csfh" || op == "csfc") {
      send_request(td_api::make_object<td_api::clearSearchedForTags>(op == "csfc"));
    } else if (op == "dacm") {
      bool revoke = as_bool(args);
      send_request(td_api::make_object<td_api::deleteAllCallMessages>(revoke));
    } else if (op == "scrlm") {
      ChatId chat_id;
      string limit;
      get_args(args, chat_id, limit);
      send_request(td_api::make_object<td_api::searchChatRecentLocationMessages>(chat_id, as_limit(limit)));
    } else if (op == "gcmca") {
      ChatId chat_id;
      string filter;
      MessageId from_message_id;
      get_args(args, chat_id, filter, from_message_id);
      send_request(td_api::make_object<td_api::getChatMessageCalendar>(chat_id, as_search_messages_filter(filter),
                                                                       from_message_id, get_saved_messages_topic_id()));
    } else if (op == "SearchAudio" || op == "SearchDocument" || op == "SearchPhoto" || op == "SearchChatPhoto") {
      ChatId chat_id;
      MessageId offset_message_id;
      SearchQuery query;
      get_args(args, chat_id, offset_message_id, query);
      send_request(td_api::make_object<td_api::searchChatMessages>(chat_id, query.query, nullptr, offset_message_id, 0,
                                                                   query.limit, as_search_messages_filter(op), 0,
                                                                   get_saved_messages_topic_id()));
    } else if (op == "ssms") {
      string tag;
      MessageId from_message_id;
      int32 offset;
      SearchQuery query;
      get_args(args, tag, from_message_id, offset, query);
      send_request(td_api::make_object<td_api::searchSavedMessages>(
          get_saved_messages_topic_id(), as_reaction_type(tag), query.query, from_message_id, offset, query.limit));
    } else if (op == "gcmbd") {
      ChatId chat_id;
      int32 date;
      get_args(args, chat_id, date);
      send_request(td_api::make_object<td_api::getChatMessageByDate>(chat_id, date));
    } else if (op == "gcsmp") {
      ChatId chat_id;
      string filter;
      MessageId from_message_id;
      string limit;
      get_args(args, chat_id, filter, from_message_id, limit);
      send_request(td_api::make_object<td_api::getChatSparseMessagePositions>(
          chat_id, as_search_messages_filter(filter), from_message_id, as_limit(limit), get_saved_messages_topic_id()));
    } else if (op == "gcmc") {
      ChatId chat_id;
      string filter;
      bool return_local;
      get_args(args, chat_id, filter, return_local);
      send_request(td_api::make_object<td_api::getChatMessageCount>(chat_id, as_search_messages_filter(filter),
                                                                    get_saved_messages_topic_id(), return_local));
    } else if (op == "gcmp") {
      ChatId chat_id;
      MessageId message_id;
      string filter;
      get_args(args, chat_id, message_id, filter);
      send_request(td_api::make_object<td_api::getChatMessagePosition>(
          chat_id, message_id, as_search_messages_filter(filter), message_thread_id_, get_saved_messages_topic_id()));
    } else if (op == "gup" || op == "gupp") {
      UserId user_id;
      int32 offset;
      string limit;
      get_args(args, user_id, offset, limit);
      send_request(td_api::make_object<td_api::getUserProfilePhotos>(user_id, offset, as_limit(limit)));
    } else if (op == "dcrm") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::deleteChatReplyMarkup>(chat_id, message_id));
    } else if (op == "glti") {
      send_request(td_api::make_object<td_api::getLocalizationTargetInfo>(as_bool(args)));
    } else if (op == "glpi") {
      send_request(td_api::make_object<td_api::getLanguagePackInfo>(args));
    } else if (op == "glps") {
      string language_code;
      string keys;
      get_args(args, language_code, keys);
      send_request(td_api::make_object<td_api::getLanguagePackStrings>(language_code, autosplit_str(keys)));
    } else if (op == "glpss") {
      string language_database_path;
      string language_pack;
      string language_code;
      string key;
      get_args(args, language_database_path, language_pack, language_code, key);
      send_request(td_api::make_object<td_api::getLanguagePackString>(language_database_path, language_pack,
                                                                      language_code, key));
    } else if (op == "synclp") {
      const string &language_code = args;
      send_request(td_api::make_object<td_api::synchronizeLanguagePack>(language_code));
    } else if (op == "acslp") {
      const string &language_code = args;
      send_request(td_api::make_object<td_api::addCustomServerLanguagePack>(language_code));
    } else if (op == "sclp") {
      string language_code;
      string name;
      string native_name;
      string key;
      get_args(args, language_code, name, native_name, key);
      vector<td_api::object_ptr<td_api::languagePackString>> strings;
      strings.push_back(td_api::make_object<td_api::languagePackString>(
          key, td_api::make_object<td_api::languagePackStringValueOrdinary>("Ordinary value")));
      strings.push_back(td_api::make_object<td_api::languagePackString>(
          "Plu", td_api::make_object<td_api::languagePackStringValuePluralized>("Zero", string("One\0One", 7), "Two",
                                                                                "Few", "Many", "Other")));
      strings.push_back(td_api::make_object<td_api::languagePackString>(
          "DELETED", td_api::make_object<td_api::languagePackStringValueDeleted>()));
      send_request(td_api::make_object<td_api::setCustomLanguagePack>(
          as_language_pack_info(language_code, name, native_name), std::move(strings)));
    } else if (op == "eclpi") {
      string language_code;
      string name;
      string native_name;
      get_args(args, language_code, name, native_name);
      send_request(td_api::make_object<td_api::editCustomLanguagePackInfo>(
          as_language_pack_info(language_code, name, native_name)));
    } else if (op == "sclpsv" || op == "sclpsp" || op == "sclpsd") {
      string language_code;
      string key;
      string value;
      get_args(args, language_code, key, value);
      td_api::object_ptr<td_api::languagePackString> str =
          td_api::make_object<td_api::languagePackString>(key, nullptr);
      if (op == "sclsv") {
        str->value_ = td_api::make_object<td_api::languagePackStringValueOrdinary>(value);
      } else if (op == "sclsp") {
        str->value_ = td_api::make_object<td_api::languagePackStringValuePluralized>(value, string("One\0One", 7),
                                                                                     "Two", "Few", "Many", "Other");
      } else {
        str->value_ = td_api::make_object<td_api::languagePackStringValueDeleted>();
      }
      send_request(td_api::make_object<td_api::setCustomLanguagePackString>(language_code, std::move(str)));
    } else if (op == "dlp") {
      send_request(td_api::make_object<td_api::deleteLanguagePack>(args));
    } else {
      op_not_found_count++;
    }

    if (op == "on" || op == "off") {
      send_request(td_api::make_object<td_api::setOption>("online",
                                                          td_api::make_object<td_api::optionValueBoolean>(op == "on")));
    } else if (op == "go") {
      send_request(td_api::make_object<td_api::getOption>(args));
    } else if (op == "gos") {
      execute(td_api::make_object<td_api::getOption>(args));
    } else if (op == "sob") {
      string name;
      bool value;
      get_args(args, name, value);
      send_request(
          td_api::make_object<td_api::setOption>(name, td_api::make_object<td_api::optionValueBoolean>(value)));
    } else if (op == "soe") {
      send_request(td_api::make_object<td_api::setOption>(args, td_api::make_object<td_api::optionValueEmpty>()));
    } else if (op == "soi") {
      string name;
      int64 value;
      get_args(args, name, value);
      send_request(
          td_api::make_object<td_api::setOption>(name, td_api::make_object<td_api::optionValueInteger>(value)));
    } else if (op == "sos") {
      string name;
      string value;
      get_args(args, name, value);
      send_request(td_api::make_object<td_api::setOption>(name, td_api::make_object<td_api::optionValueString>(value)));
    } else if (op == "me") {
      send_request(td_api::make_object<td_api::getMe>());
    } else if (op == "sdmadt") {
      int32 auto_delete_time;
      get_args(args, auto_delete_time);
      send_request(td_api::make_object<td_api::setDefaultMessageAutoDeleteTime>(
          td_api::make_object<td_api::messageAutoDeleteTime>(auto_delete_time)));
    } else if (op == "gdmadt") {
      send_request(td_api::make_object<td_api::getDefaultMessageAutoDeleteTime>());
    } else if (op == "sattl") {
      int32 days;
      get_args(args, days);
      send_request(td_api::make_object<td_api::setAccountTtl>(td_api::make_object<td_api::accountTtl>(days)));
    } else if (op == "gattl") {
      send_request(td_api::make_object<td_api::getAccountTtl>());
    } else if (op == "devices" || op == "sessions") {
      send_request(td_api::make_object<td_api::getActiveSessions>());
    } else if (op == "ts") {
      int64 session_id;
      get_args(args, session_id);
      send_request(td_api::make_object<td_api::terminateSession>(session_id));
    } else if (op == "taos") {
      send_request(td_api::make_object<td_api::terminateAllOtherSessions>());
    } else if (op == "cse") {
      int64 session_id;
      get_args(args, session_id);
      send_request(td_api::make_object<td_api::confirmSession>(session_id));
    } else if (op == "tscac") {
      int64 session_id;
      bool can_accept_calls;
      get_args(args, session_id, can_accept_calls);
      send_request(td_api::make_object<td_api::toggleSessionCanAcceptCalls>(session_id, can_accept_calls));
    } else if (op == "tscasc") {
      int64 session_id;
      bool can_accept_secret_chats;
      get_args(args, session_id, can_accept_secret_chats);
      send_request(td_api::make_object<td_api::toggleSessionCanAcceptSecretChats>(session_id, can_accept_secret_chats));
    } else if (op == "sist") {
      int32 inactive_session_ttl_days;
      get_args(args, inactive_session_ttl_days);
      send_request(td_api::make_object<td_api::setInactiveSessionTtl>(inactive_session_ttl_days));
    } else if (op == "gcw") {
      send_request(td_api::make_object<td_api::getConnectedWebsites>());
    } else if (op == "dw") {
      int64 website_id;
      get_args(args, website_id);
      send_request(td_api::make_object<td_api::disconnectWebsite>(website_id));
    } else if (op == "daw") {
      send_request(td_api::make_object<td_api::disconnectAllWebsites>());
    } else if (op == "gib") {
      send_request(td_api::make_object<td_api::getInstalledBackgrounds>(as_bool(args)));
    } else if (op == "gbgu") {
      send_get_background_url(as_wallpaper_background(false, false));
      send_get_background_url(as_wallpaper_background(false, true));
      send_get_background_url(as_wallpaper_background(true, false));
      send_get_background_url(as_wallpaper_background(true, true));
      send_get_background_url(as_solid_pattern_background(-1, 0, false));
      send_get_background_url(as_solid_pattern_background(0x1000000, 0, true));
      send_get_background_url(as_solid_pattern_background(0, -1, false));
      send_get_background_url(as_solid_pattern_background(0, 101, false));
      send_get_background_url(as_solid_pattern_background(0, 0, false));
      send_get_background_url(as_solid_pattern_background(0xFFFFFF, 100, true));
      send_get_background_url(as_solid_pattern_background(0xABCDEF, 49, true));
      send_get_background_url(as_gradient_pattern_background(0, 0, 0, false, false));
      send_get_background_url(as_gradient_pattern_background(0, 0, 0, true, false));
      send_get_background_url(as_gradient_pattern_background(0xFFFFFF, 0, 100, false, true));
      send_get_background_url(as_gradient_pattern_background(0xFFFFFF, 0, 100, true, true));
      send_get_background_url(as_gradient_pattern_background(0xABCDEF, 0xFEDCBA, 49, false, true));
      send_get_background_url(as_gradient_pattern_background(0, 0x1000000, 49, false, true));
      send_get_background_url(as_freeform_gradient_pattern_background({0xABCDEF, 0xFEDCBA}, 49, false, true));
      send_get_background_url(as_freeform_gradient_pattern_background({0xABCDEF, 0x111111, 0x222222}, 49, true, true));
      send_get_background_url(
          as_freeform_gradient_pattern_background({0xABCDEF, 0xFEDCBA, 0x111111, 0x222222}, 49, false, true));
      send_get_background_url(as_solid_background(-1));
      send_get_background_url(as_solid_background(0xABCDEF));
      send_get_background_url(as_solid_background(0x1000000));
      send_get_background_url(as_gradient_background(0xABCDEF, 0xFEDCBA));
      send_get_background_url(as_gradient_background(0, 0));
      send_get_background_url(as_gradient_background(-1, -1));
      send_get_background_url(as_freeform_gradient_background({0xFEDCBA, 0x222222}));
      send_get_background_url(as_freeform_gradient_background({0xFEDCBA, 0x111111, 0x222222}));
      send_get_background_url(as_freeform_gradient_background({0xABCDEF, 0xFEDCBA, 0x111111, 0x222222}));
      send_get_background_url(as_chat_theme_background(args));
    } else {
      op_not_found_count++;
    }

    if (op == "sbg") {
      send_request(td_api::make_object<td_api::searchBackground>(args));
    } else if (op == "sdb" || op == "sdbd") {
      InputBackground input_background;
      BackgroundType background_type;
      get_args(args, input_background, background_type);
      send_request(td_api::make_object<td_api::setDefaultBackground>(input_background, background_type, op == "sdbd"));
    } else if (op == "ddb" || op == "ddbd") {
      send_request(td_api::make_object<td_api::deleteDefaultBackground>(op == "ddbd"));
    } else if (op == "rib") {
      int64 background_id;
      get_args(args, background_id);
      send_request(td_api::make_object<td_api::removeInstalledBackground>(background_id));
    } else if (op == "ribs") {
      send_request(td_api::make_object<td_api::resetInstalledBackgrounds>());
    } else if (op == "scbg" || op == "scbgs") {
      ChatId chat_id;
      InputBackground input_background;
      BackgroundType background_type;
      int32 dark_theme_dimming;
      get_args(args, chat_id, input_background, background_type, dark_theme_dimming);
      send_request(td_api::make_object<td_api::setChatBackground>(chat_id, input_background, background_type,
                                                                  dark_theme_dimming, op == "scbgs"));
    } else if (op == "dcb" || op == "dcbr") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::deleteChatBackground>(chat_id, op == "dcbr"));
    } else if (op == "gcos") {
      send_request(td_api::make_object<td_api::getCountries>());
    } else if (op == "gcoc") {
      send_request(td_api::make_object<td_api::getCountryCode>());
    } else if (op == "gpni") {
      send_request(td_api::make_object<td_api::getPhoneNumberInfo>(args));
    } else if (op == "gpnis") {
      execute(td_api::make_object<td_api::getPhoneNumberInfoSync>(rand_bool() ? "en" : "", args));
    } else if (op == "gciu") {
      send_request(td_api::make_object<td_api::getCollectibleItemInfo>(
          td_api::make_object<td_api::collectibleItemTypeUsername>(args)));
    } else if (op == "gcipn") {
      send_request(td_api::make_object<td_api::getCollectibleItemInfo>(
          td_api::make_object<td_api::collectibleItemTypePhoneNumber>(args)));
    } else if (op == "gadl") {
      send_request(td_api::make_object<td_api::getApplicationDownloadLink>());
    } else if (op == "gprl") {
      auto limit_type = td_api::make_object<td_api::premiumLimitTypeChatFolderCount>();
      send_request(td_api::make_object<td_api::getPremiumLimit>(std::move(limit_type)));
    } else if (op == "gprf") {
      auto source = td_api::make_object<td_api::premiumSourceLimitExceeded>(
          td_api::make_object<td_api::premiumLimitTypeChatFolderCount>());
      send_request(td_api::make_object<td_api::getPremiumFeatures>(std::move(source)));
    } else if (op == "gprse") {
      send_request(td_api::make_object<td_api::getPremiumStickerExamples>());
    } else if (op == "gpis") {
      int32 month_count;
      get_args(args, month_count);
      send_request(td_api::make_object<td_api::getPremiumInfoSticker>(month_count));
    } else if (op == "vprf") {
      auto feature = td_api::make_object<td_api::premiumFeatureProfileBadge>();
      send_request(td_api::make_object<td_api::viewPremiumFeature>(std::move(feature)));
    } else if (op == "cprsb") {
      send_request(td_api::make_object<td_api::clickPremiumSubscriptionButton>());
    } else if (op == "gprs") {
      send_request(td_api::make_object<td_api::getPremiumState>());
    } else if (op == "gpgpo") {
      send_request(td_api::make_object<td_api::getPremiumGiftPaymentOptions>());
    } else if (op == "gpgapo") {
      ChatId boosted_chat_id;
      get_args(args, boosted_chat_id);
      send_request(td_api::make_object<td_api::getPremiumGiveawayPaymentOptions>(boosted_chat_id));
    } else if (op == "cpgc") {
      send_request(td_api::make_object<td_api::checkPremiumGiftCode>(args));
    } else if (op == "apgc") {
      send_request(td_api::make_object<td_api::applyPremiumGiftCode>(args));
    } else if (op == "lpg") {
      int64 giveaway_id;
      int32 user_count;
      int64 star_count;
      GiveawayParameters parameters;
      get_args(args, giveaway_id, user_count, star_count, parameters);
      send_request(td_api::make_object<td_api::launchPrepaidGiveaway>(giveaway_id, parameters, user_count, star_count));
    } else if (op == "ggi") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getGiveawayInfo>(chat_id, message_id));
    } else if (op == "gspo") {
      send_request(td_api::make_object<td_api::getStarPaymentOptions>());
    } else if (op == "gsgpo") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::getStarGiftPaymentOptions>(user_id));
    } else if (op == "gsgapo") {
      send_request(td_api::make_object<td_api::getStarGiveawayPaymentOptions>());
    } else if (op == "gsta" || op == "gsti" || op == "gsto") {
      string owner_id;
      string subscription_id;
      string offset;
      string limit;
      get_args(args, owner_id, subscription_id, offset, limit);
      td_api::object_ptr<td_api::StarTransactionDirection> direction;
      if (op == "gsti") {
        direction = td_api::make_object<td_api::starTransactionDirectionIncoming>();
      } else if (op == "gsto") {
        direction = td_api::make_object<td_api::starTransactionDirectionOutgoing>();
      }
      send_request(td_api::make_object<td_api::getStarTransactions>(as_message_sender(owner_id), subscription_id,
                                                                    std::move(direction), offset, as_limit(limit)));
    } else if (op == "gssu") {
      bool only_expiring;
      string offset;
      get_args(args, only_expiring, offset);
      send_request(td_api::make_object<td_api::getStarSubscriptions>(only_expiring, offset));
    } else if (op == "ess") {
      string subscription_id;
      bool is_canceled;
      get_args(args, subscription_id, is_canceled);
      send_request(td_api::make_object<td_api::editStarSubscription>(subscription_id, is_canceled));
    } else if (op == "rss") {
      string subscription_id;
      get_args(args, subscription_id);
      send_request(td_api::make_object<td_api::reuseStarSubscription>(subscription_id));
    } else if (op == "scap" || op == "scapd") {
      ChatId chat_id;
      int32 commission;
      int32 month_count;
      get_args(args, chat_id, commission, month_count);
      send_request(td_api::make_object<td_api::setChatAffiliateProgram>(
          chat_id,
          op == "scapd" ? nullptr : td_api::make_object<td_api::affiliateProgramParameters>(commission, month_count)));
    } else if (op == "scapr") {
      string username;
      string referrer;
      get_args(args, username, referrer);
      send_request(td_api::make_object<td_api::searchChatAffiliateProgram>(username, referrer));
    } else if (op == "sapc" || op == "sapd" || op == "sapr") {
      AffiliateType affiliate;
      string limit;
      string offset;
      get_args(args, affiliate, limit, offset);
      td_api::object_ptr<td_api::AffiliateProgramSortOrder> sort_order;
      if (op == "sapd") {
        sort_order = td_api::make_object<td_api::affiliateProgramSortOrderCreationDate>();
      } else if (op == "sapr") {
        sort_order = td_api::make_object<td_api::affiliateProgramSortOrderRevenue>();
      }
      send_request(td_api::make_object<td_api::searchAffiliatePrograms>(affiliate, std::move(sort_order), offset,
                                                                        as_limit(limit)));
    } else if (op == "capr") {
      AffiliateType affiliate;
      UserId bot_user_id;
      get_args(args, affiliate, bot_user_id);
      send_request(td_api::make_object<td_api::connectAffiliateProgram>(affiliate, bot_user_id));
    } else if (op == "dapr") {
      AffiliateType affiliate;
      string url;
      get_args(args, affiliate, url);
      send_request(td_api::make_object<td_api::disconnectAffiliateProgram>(affiliate, url));
    } else if (op == "gcapr") {
      AffiliateType affiliate;
      UserId bot_user_id;
      get_args(args, affiliate, bot_user_id);
      send_request(td_api::make_object<td_api::getConnectedAffiliateProgram>(affiliate, bot_user_id));
    } else if (op == "gcaprs") {
      AffiliateType affiliate;
      string limit;
      string offset;
      get_args(args, affiliate, limit, offset);
      send_request(td_api::make_object<td_api::getConnectedAffiliatePrograms>(affiliate, offset, as_limit(limit)));
    } else if (op == "cpfs" || op == "cpfsb") {
      UserId user_id;
      string currency;
      int64 amount;
      ChatId boosted_chat_id;
      get_args(args, user_id, currency, amount, boosted_chat_id);
      if (currency.empty()) {
        send_request(td_api::make_object<td_api::canPurchaseFromStore>(
            td_api::make_object<td_api::storePaymentPurposePremiumSubscription>(false, false)));
      } else {
        send_request(td_api::make_object<td_api::canPurchaseFromStore>(
            td_api::make_object<td_api::storePaymentPurposePremiumGiftCodes>(boosted_chat_id, currency, amount,
                                                                             vector<int64>{user_id}, nullptr)));
      }
    } else if (op == "cpfsg") {
      GiveawayParameters parameters;
      string currency;
      int64 amount;
      get_args(args, parameters, currency, amount);
      send_request(td_api::make_object<td_api::canPurchaseFromStore>(
          td_api::make_object<td_api::storePaymentPurposePremiumGiveaway>(parameters, currency, amount)));
    } else if (op == "cpfssg") {
      GiveawayParameters parameters;
      string currency;
      int64 amount;
      int32 user_count;
      int64 star_count;
      get_args(args, parameters, currency, amount, user_count, star_count);
      send_request(td_api::make_object<td_api::canPurchaseFromStore>(
          td_api::make_object<td_api::storePaymentPurposeStarGiveaway>(parameters, currency, amount, user_count,
                                                                       star_count)));
    } else if (op == "cpfss") {
      string currency;
      int64 amount;
      int64 star_count;
      get_args(args, currency, amount, star_count);
      send_request(td_api::make_object<td_api::canPurchaseFromStore>(
          td_api::make_object<td_api::storePaymentPurposeStars>(currency, amount, star_count)));
    } else if (op == "cpfsgs") {
      UserId user_id;
      string currency;
      int64 amount;
      int64 star_count;
      get_args(args, user_id, currency, amount, star_count);
      send_request(td_api::make_object<td_api::canPurchaseFromStore>(
          td_api::make_object<td_api::storePaymentPurposeGiftedStars>(user_id, currency, amount, star_count)));
    } else if (op == "gbf") {
      send_request(td_api::make_object<td_api::getBusinessFeatures>(nullptr));
    } else if (op == "atos") {
      send_request(td_api::make_object<td_api::acceptTermsOfService>(args));
    } else if (op == "gdli") {
      send_request(td_api::make_object<td_api::getDeepLinkInfo>(args));
    } else if (op == "tme") {
      send_request(td_api::make_object<td_api::getRecentlyVisitedTMeUrls>(args));
    } else if (op == "gbms") {
      string block_list;
      int32 offset;
      string limit;
      get_args(args, block_list, offset, limit);
      send_request(
          td_api::make_object<td_api::getBlockedMessageSenders>(as_block_list(block_list), offset, as_limit(limit)));
    } else if (op == "gu") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::getUser>(user_id));
    } else if (op == "gsu") {
      send_request(td_api::make_object<td_api::getSupportUser>());
    } else if (op == "gso" || op == "gsoa" || op == "gsoc") {
      int32 sticker_file_id;
      get_args(args, sticker_file_id);
      send_request(td_api::make_object<td_api::getStickerOutline>(sticker_file_id, op == "gsoa", op == "gsoc"));
    } else if (op == "gs" || op == "gsmm" || op == "gsee" || op == "gseeme") {
      SearchQuery query;
      get_args(args, query);
      send_request(td_api::make_object<td_api::getStickers>(as_sticker_type(op), query.query, query.limit,
                                                            op == "gseeme" ? my_id_ : 0));
    } else if (op == "gaser" || op == "gasem" || op == "gase" || op == "gaseme") {
      string query;
      bool return_only_main_emoji;
      get_args(args, query, return_only_main_emoji);
      send_request(td_api::make_object<td_api::getAllStickerEmojis>(
          as_sticker_type(op), query, op == "gaseme" ? my_id_ : 0, return_only_main_emoji));
    } else if (op == "sst" || op == "sstm" || op == "sste") {
      string limit;
      string emoji;
      string query;
      string input_language_codes;
      int32 offset;
      get_args(args, limit, emoji, query, input_language_codes, offset);
      send_request(td_api::make_object<td_api::searchStickers>(
          as_sticker_type(op), emoji, query, autosplit_str(input_language_codes), offset, as_limit(limit)));
    } else if (op == "ggs") {
      send_request(td_api::make_object<td_api::getGreetingStickers>());
    } else if (op == "gprst") {
      string limit;
      get_args(args, limit);
      send_request(td_api::make_object<td_api::getPremiumStickers>(as_limit(limit)));
    } else if (op == "gss") {
      int64 sticker_set_id;
      get_args(args, sticker_set_id);
      send_request(td_api::make_object<td_api::getStickerSet>(sticker_set_id));
    } else if (op == "gssn") {
      int64 sticker_set_id;
      get_args(args, sticker_set_id);
      send_request(td_api::make_object<td_api::getStickerSetName>(sticker_set_id));
    } else if (op == "giss" || op == "gissm" || op == "gisse") {
      send_request(td_api::make_object<td_api::getInstalledStickerSets>(as_sticker_type(op)));
    } else if (op == "gass" || op == "gassm" || op == "gasse") {
      int64 offset_sticker_set_id;
      string limit;
      get_args(args, offset_sticker_set_id, limit);
      send_request(td_api::make_object<td_api::getArchivedStickerSets>(as_sticker_type(op), offset_sticker_set_id,
                                                                       as_limit(limit)));
    } else if (op == "gtss" || op == "gtssm" || op == "gtsse") {
      int32 offset;
      string limit;
      get_args(args, offset, limit);
      send_request(
          td_api::make_object<td_api::getTrendingStickerSets>(as_sticker_type(op), offset, as_limit(limit, 1000)));
    } else if (op == "gatss") {
      FileId file_id;
      get_args(args, file_id);
      send_request(td_api::make_object<td_api::getAttachedStickerSets>(file_id));
    } else {
      op_not_found_count++;
    }

    if (op == "storage") {
      int32 chat_limit;
      get_args(args, chat_limit);
      send_request(td_api::make_object<td_api::getStorageStatistics>(chat_limit));
    } else if (op == "storage_fast") {
      send_request(td_api::make_object<td_api::getStorageStatisticsFast>());
    } else if (op == "database") {
      send_request(td_api::make_object<td_api::getDatabaseStatistics>());
    } else if (op == "optimize_storage" || op == "optimize_storage_all") {
      string chat_ids;
      string exclude_chat_ids;
      int32 chat_ids_limit;
      get_args(args, chat_ids, exclude_chat_ids, chat_ids_limit);
      send_request(td_api::make_object<td_api::optimizeStorage>(
          10000000, -1, -1, 0, std::vector<td_api::object_ptr<td_api::FileType>>(), as_chat_ids(chat_ids),
          as_chat_ids(exclude_chat_ids), op == "optimize_storage", chat_ids_limit));
    } else if (op == "clean_storage_default") {
      send_request(td_api::make_object<td_api::optimizeStorage>());
    } else if (op == "clean_photos") {
      std::vector<td_api::object_ptr<td_api::FileType>> types;
      types.emplace_back(td_api::make_object<td_api::fileTypePhoto>());
      send_request(td_api::make_object<td_api::optimizeStorage>(0, 0, 0, 0, std::move(types), as_chat_ids(""),
                                                                as_chat_ids(""), true, 20));
    } else if (op == "clean_storage") {
      std::vector<td_api::object_ptr<td_api::FileType>> types;
      types.emplace_back(td_api::make_object<td_api::fileTypeThumbnail>());
      types.emplace_back(td_api::make_object<td_api::fileTypeProfilePhoto>());
      types.emplace_back(td_api::make_object<td_api::fileTypePhoto>());
      types.emplace_back(td_api::make_object<td_api::fileTypeVoiceNote>());
      types.emplace_back(td_api::make_object<td_api::fileTypeVideo>());
      types.emplace_back(td_api::make_object<td_api::fileTypeDocument>());
      types.emplace_back(td_api::make_object<td_api::fileTypeSecret>());
      types.emplace_back(td_api::make_object<td_api::fileTypeUnknown>());
      types.emplace_back(td_api::make_object<td_api::fileTypeSticker>());
      types.emplace_back(td_api::make_object<td_api::fileTypeAudio>());
      types.emplace_back(td_api::make_object<td_api::fileTypeAnimation>());
      types.emplace_back(td_api::make_object<td_api::fileTypeVideoNote>());
      types.emplace_back(td_api::make_object<td_api::fileTypeSecure>());
      send_request(td_api::make_object<td_api::optimizeStorage>(0, -1, -1, 0, std::move(types), as_chat_ids(args),
                                                                as_chat_ids(""), true, 20));
    } else if (op == "network") {
      send_request(td_api::make_object<td_api::getNetworkStatistics>());
    } else if (op == "current_network") {
      send_request(td_api::make_object<td_api::getNetworkStatistics>(true));
    } else if (op == "reset_network") {
      send_request(td_api::make_object<td_api::resetNetworkStatistics>());
    } else if (op == "snt") {
      send_request(td_api::make_object<td_api::setNetworkType>(as_network_type(args)));
    } else if (op == "gadsp") {
      send_request(td_api::make_object<td_api::getAutoDownloadSettingsPresets>());
    } else if (op == "sads") {
      send_request(td_api::make_object<td_api::setAutoDownloadSettings>(
          td_api::make_object<td_api::autoDownloadSettings>(), as_network_type(args)));
    } else if (op == "gaus") {
      send_request(td_api::make_object<td_api::getAutosaveSettings>());
    } else if (op == "saus") {
      string scope_str;
      bool autosave_photos;
      bool autosave_videos;
      int64 max_video_file_size;
      get_args(args, scope_str, autosave_photos, autosave_videos, max_video_file_size);
      auto scope = [&]() -> td_api::object_ptr<td_api::AutosaveSettingsScope> {
        if (scope_str == "users") {
          return td_api::make_object<td_api::autosaveSettingsScopePrivateChats>();
        }
        if (scope_str == "groups") {
          return td_api::make_object<td_api::autosaveSettingsScopeGroupChats>();
        }
        if (scope_str == "channels") {
          return td_api::make_object<td_api::autosaveSettingsScopeChannelChats>();
        }
        auto chat_id = as_chat_id(scope_str);
        if (chat_id != 0) {
          return td_api::make_object<td_api::autosaveSettingsScopeChat>(chat_id);
        }
        return nullptr;
      }();
      send_request(td_api::make_object<td_api::setAutosaveSettings>(
          std::move(scope),
          td_api::make_object<td_api::scopeAutosaveSettings>(autosave_photos, autosave_videos, max_video_file_size)));
    } else if (op == "cause") {
      send_request(td_api::make_object<td_api::clearAutosaveSettingsExceptions>());
    } else if (op == "ansc") {
      int32 sent_bytes;
      int32 received_bytes;
      string duration;
      string network_type;
      get_args(args, sent_bytes, received_bytes, duration, network_type);
      send_request(
          td_api::make_object<td_api::addNetworkStatistics>(td_api::make_object<td_api::networkStatisticsEntryCall>(
              as_network_type(network_type), sent_bytes, received_bytes, to_double(duration))));
    } else if (op == "ans") {
      int32 sent_bytes;
      int32 received_bytes;
      string network_type;
      get_args(args, sent_bytes, received_bytes, network_type);
      send_request(
          td_api::make_object<td_api::addNetworkStatistics>(td_api::make_object<td_api::networkStatisticsEntryFile>(
              td_api::make_object<td_api::fileTypeDocument>(), as_network_type(network_type), sent_bytes,
              received_bytes)));
    } else if (op == "gtc") {
      send_request(td_api::make_object<td_api::getTopChats>(as_top_chat_category(args), 50));
    } else if (op == "rtc") {
      ChatId chat_id;
      string category;
      get_args(args, chat_id, category);
      send_request(td_api::make_object<td_api::removeTopChat>(as_top_chat_category(category), chat_id));
    } else if (op == "gsssn") {
      const string &title = args;
      send_request(td_api::make_object<td_api::getSuggestedStickerSetName>(title));
    } else if (op == "cssn") {
      const string &name = args;
      send_request(td_api::make_object<td_api::checkStickerSetName>(name));
    } else if (op == "usf" || op == "usfa" || op == "usfv") {
      send_request(td_api::make_object<td_api::uploadStickerFile>(-1, as_sticker_format(op), as_input_file(args)));
    } else if (op == "cnss" || op == "cnssa" || op == "cnssv" || op == "cnssm" || op == "cnsse") {
      string title;
      string name;
      string stickers;
      get_args(args, title, name, stickers);
      auto input_stickers =
          transform(autosplit(stickers), [op](Slice sticker) -> td_api::object_ptr<td_api::inputSticker> {
            return td_api::make_object<td_api::inputSticker>(as_input_file(sticker), as_sticker_format(op), "😀",
                                                             as_mask_position(op), vector<string>{"keyword"});
          });
      send_request(td_api::make_object<td_api::createNewStickerSet>(my_id_, title, name, as_sticker_type(op), false,
                                                                    std::move(input_stickers), "tg_cli"));
    } else if (op == "goss") {
      int64 sticker_set_id;
      string limit;
      get_args(args, sticker_set_id, limit);
      send_request(td_api::make_object<td_api::getOwnedStickerSets>(sticker_set_id, as_limit(limit)));
    } else if (op == "sss" || op == "sssf") {
      send_request(td_api::make_object<td_api::searchStickerSet>(args, op == "sssf"));
    } else if (op == "siss") {
      send_request(td_api::make_object<td_api::searchInstalledStickerSets>(nullptr, args, 2));
    } else if (op == "ssss" || op == "ssssm" || op == "sssse") {
      send_request(td_api::make_object<td_api::searchStickerSets>(as_sticker_type(op), args));
    } else if (op == "css") {
      int64 set_id;
      bool is_installed;
      bool is_archived;
      get_args(args, set_id, is_installed, is_archived);
      send_request(td_api::make_object<td_api::changeStickerSet>(set_id, is_installed, is_archived));
    } else if (op == "vtss") {
      send_request(td_api::make_object<td_api::viewTrendingStickerSets>(to_integers<int64>(args)));
    } else if (op == "riss" || op == "rissm" || op == "risse") {
      string new_order;
      get_args(args, new_order);
      send_request(
          td_api::make_object<td_api::reorderInstalledStickerSets>(as_sticker_type(op), to_integers<int64>(new_order)));
    } else if (op == "grs") {
      send_request(td_api::make_object<td_api::getRecentStickers>(as_bool(args)));
    } else if (op == "ars") {
      bool is_attached;
      string sticker_id;
      get_args(args, is_attached, sticker_id);
      send_request(td_api::make_object<td_api::addRecentSticker>(is_attached, as_input_file_id(sticker_id)));
    } else if (op == "rrs") {
      bool is_attached;
      string sticker_id;
      get_args(args, is_attached, sticker_id);
      send_request(td_api::make_object<td_api::removeRecentSticker>(is_attached, as_input_file_id(sticker_id)));
    } else if (op == "gfs") {
      send_request(td_api::make_object<td_api::getFavoriteStickers>());
    } else if (op == "afs") {
      send_request(td_api::make_object<td_api::addFavoriteSticker>(as_input_file_id(args)));
    } else if (op == "rfs") {
      send_request(td_api::make_object<td_api::removeFavoriteSticker>(as_input_file_id(args)));
    } else if (op == "crs") {
      send_request(td_api::make_object<td_api::clearRecentStickers>(as_bool(args)));
    } else if (op == "gse") {
      send_request(td_api::make_object<td_api::getStickerEmojis>(as_input_file_id(args)));
    } else if (op == "se") {
      send_request(td_api::make_object<td_api::searchEmojis>(args, vector<string>()));
    } else if (op == "seru") {
      send_request(td_api::make_object<td_api::searchEmojis>(args, vector<string>{"ru_RU"}));
    } else if (op == "gke") {
      send_request(td_api::make_object<td_api::getKeywordEmojis>(args, vector<string>()));
    } else if (op == "gkeru") {
      send_request(td_api::make_object<td_api::getKeywordEmojis>(args, vector<string>{"ru_RU"}));
    } else if (op == "gec" || op == "geces" || op == "geccp" || op == "gecrs") {
      auto type = [&]() -> td_api::object_ptr<td_api::EmojiCategoryType> {
        if (op == "geces") {
          return td_api::make_object<td_api::emojiCategoryTypeEmojiStatus>();
        }
        if (op == "geccp") {
          return td_api::make_object<td_api::emojiCategoryTypeChatPhoto>();
        }
        if (op == "gecrs") {
          return td_api::make_object<td_api::emojiCategoryTypeRegularStickers>();
        }
        return td_api::make_object<td_api::emojiCategoryTypeDefault>();
      }();
      send_request(td_api::make_object<td_api::getEmojiCategories>(std::move(type)));
    } else if (op == "gae") {
      send_request(td_api::make_object<td_api::getAnimatedEmoji>(args));
    } else if (op == "gesu") {
      send_request(td_api::make_object<td_api::getEmojiSuggestionsUrl>(args));
    } else if (op == "gces") {
      send_request(td_api::make_object<td_api::getCustomEmojiStickers>(to_integers<int64>(args)));
    } else if (op == "gdcpces") {
      send_request(td_api::make_object<td_api::getDefaultChatPhotoCustomEmojiStickers>());
    } else if (op == "gdppces") {
      send_request(td_api::make_object<td_api::getDefaultProfilePhotoCustomEmojiStickers>());
    } else if (op == "gdbces") {
      send_request(td_api::make_object<td_api::getDefaultBackgroundCustomEmojiStickers>());
    } else if (op == "gsan") {
      send_request(td_api::make_object<td_api::getSavedAnimations>());
    } else if (op == "asan") {
      send_request(td_api::make_object<td_api::addSavedAnimation>(as_input_file_id(args)));
    } else if (op == "rsan") {
      send_request(td_api::make_object<td_api::removeSavedAnimation>(as_input_file_id(args)));
    } else {
      op_not_found_count++;
    }

    if (op == "guf") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::getUserFullInfo>(user_id));
    } else if (op == "gbg") {
      send_request(td_api::make_object<td_api::getBasicGroup>(as_basic_group_id(args)));
    } else if (op == "gbgf") {
      send_request(td_api::make_object<td_api::getBasicGroupFullInfo>(as_basic_group_id(args)));
    } else if (op == "gsg" || op == "gch") {
      send_request(td_api::make_object<td_api::getSupergroup>(as_supergroup_id(args)));
    } else if (op == "gsgf" || op == "gchf") {
      send_request(td_api::make_object<td_api::getSupergroupFullInfo>(as_supergroup_id(args)));
    } else if (op == "gsc") {
      send_request(td_api::make_object<td_api::getSecretChat>(as_secret_chat_id(args)));
    } else if (op == "scm") {
      ChatId chat_id;
      string filter;
      SearchQuery query;
      get_args(args, chat_id, filter, query);
      send_request(td_api::make_object<td_api::searchChatMembers>(chat_id, query.query, query.limit,
                                                                  as_chat_members_filter(filter)));
    } else if (op == "gcm") {
      ChatId chat_id;
      string member_id;
      get_args(args, chat_id, member_id);
      send_request(td_api::make_object<td_api::getChatMember>(chat_id, as_message_sender(member_id)));
    } else if (op == "GetChatAdministrators") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatAdministrators>(chat_id));
    } else if (op == "GetSupergroupAdministrators" || op == "GetSupergroupBanned" || op == "GetSupergroupBots" ||
               op == "GetSupergroupContacts" || op == "GetSupergroupMembers" || op == "GetSupergroupRestricted" ||
               op == "SearchSupergroupMembers" || op == "SearchSupergroupMentions") {
      string supergroup_id;
      string message_thread_id;
      int32 offset;
      SearchQuery query;
      if (op == "SearchSupergroupMentions") {
        get_args(args, message_thread_id, args);
      }
      get_args(args, supergroup_id, offset, query);
      send_request(td_api::make_object<td_api::getSupergroupMembers>(
          as_supergroup_id(supergroup_id), as_supergroup_members_filter(op, query.query, message_thread_id), offset,
          query.limit));
    } else if (op == "gd") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChat>(chat_id));
    } else if (op == "open") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::openChat>(chat_id));
      opened_chat_id_ = chat_id;
    } else if (op == "close") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::closeChat>(chat_id));
    } else if (op == "gm") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getMessage>(chat_id, message_id));
    } else if (op == "gmf") {
      ChatId chat_id;
      int64 from_message_id;
      int64 to_message_id;
      get_args(args, chat_id, from_message_id, to_message_id);
      for (auto message_id = from_message_id; message_id <= to_message_id; message_id++) {
        send_request(td_api::make_object<td_api::getMessage>(chat_id, message_id << 20));
      }
    } else if (op == "gml") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getMessageLocally>(chat_id, message_id));
    } else if (op == "grm") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getRepliedMessage>(chat_id, message_id));
    } else if (op == "gmt") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getMessageThread>(chat_id, message_id));
    } else if (op == "gmrd") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getMessageReadDate>(chat_id, message_id));
    } else if (op == "gmv") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getMessageViewers>(chat_id, message_id));
    } else if (op == "gcpm") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatPinnedMessage>(chat_id));
    } else if (op == "gms") {
      ChatId chat_id;
      string message_ids;
      get_args(args, chat_id, message_ids);
      send_request(td_api::make_object<td_api::getMessages>(chat_id, as_message_ids(message_ids)));
    } else if (op == "gmp") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getMessageProperties>(chat_id, message_id));
    } else if (op == "gcspm") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatSponsoredMessages>(chat_id));
    } else if (op == "ccspm") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(
          td_api::make_object<td_api::clickChatSponsoredMessage>(chat_id, message_id, rand_bool(), rand_bool()));
    } else if (op == "rcspm") {
      ChatId chat_id;
      MessageId message_id;
      string option_id;
      get_args(args, chat_id, message_id, option_id);
      send_request(td_api::make_object<td_api::reportChatSponsoredMessage>(chat_id, message_id, option_id));
    } else if (op == "gmlink") {
      ChatId chat_id;
      MessageId message_id;
      int32 media_timestamp;
      bool for_album;
      bool for_comment;
      get_args(args, chat_id, message_id, media_timestamp, for_album, for_comment);
      send_request(
          td_api::make_object<td_api::getMessageLink>(chat_id, message_id, media_timestamp, for_album, for_comment));
    } else if (op == "gmec") {
      ChatId chat_id;
      MessageId message_id;
      bool for_album;
      get_args(args, chat_id, message_id, for_album);
      send_request(td_api::make_object<td_api::getMessageEmbeddingCode>(chat_id, message_id, for_album));
    } else if (op == "gmli") {
      send_request(td_api::make_object<td_api::getMessageLinkInfo>(args));
    } else if (op == "tt") {
      string text;
      string to_language_code;
      get_args(args, to_language_code, text);
      send_request(td_api::make_object<td_api::translateText>(as_formatted_text(text), to_language_code));
    } else if (op == "tmt") {
      ChatId chat_id;
      MessageId message_id;
      string to_language_code;
      get_args(args, chat_id, message_id, to_language_code);
      send_request(td_api::make_object<td_api::translateMessageText>(chat_id, message_id, to_language_code));
    } else if (op == "rs") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::recognizeSpeech>(chat_id, message_id));
    } else if (op == "rsr") {
      ChatId chat_id;
      MessageId message_id;
      bool is_good;
      get_args(args, chat_id, message_id, is_good);
      send_request(td_api::make_object<td_api::rateSpeechRecognition>(chat_id, message_id, is_good));
    } else if (op == "gf") {
      FileId file_id;
      get_args(args, file_id);
      send_request(td_api::make_object<td_api::getFile>(file_id));
    } else if (op == "gfdps") {
      FileId file_id;
      int64 offset;
      get_args(args, file_id, offset);
      send_request(td_api::make_object<td_api::getFileDownloadedPrefixSize>(file_id, offset));
    } else if (op == "rfp") {
      FileId file_id;
      int64 offset;
      int64 count;
      get_args(args, file_id, offset, count);
      send_request(td_api::make_object<td_api::readFilePart>(file_id, offset, count));
    } else if (op == "grf") {
      send_request(td_api::make_object<td_api::getRemoteFile>(args, nullptr));
    } else if (op == "gmtf") {
      string latitude;
      string longitude;
      int32 zoom;
      int32 width;
      int32 height;
      int32 scale;
      ChatId chat_id;
      get_args(args, latitude, longitude, zoom, width, height, scale, chat_id);
      send_request(td_api::make_object<td_api::getMapThumbnailFile>(as_location(latitude, longitude, string()), zoom,
                                                                    width, height, scale, chat_id));
    } else if (op == "df" || op == "dff" || op == "dfs") {
      FileId file_id;
      int64 offset;
      int64 limit;
      int32 priority;
      get_args(args, file_id, offset, limit, priority);
      if (priority <= 0) {
        priority = 1;
      }
      int32 max_file_id = file_id.file_id;
      int32 min_file_id = (op == "dff" ? 1 : max_file_id);
      for (int32 i = min_file_id; i <= max_file_id; i++) {
        send_request(td_api::make_object<td_api::downloadFile>(i, priority, offset, limit, op == "dfs"));
      }
    } else if (op == "cdf") {
      FileId file_id;
      get_args(args, file_id);
      send_request(td_api::make_object<td_api::cancelDownloadFile>(file_id, false));
    } else if (op == "gsfn") {
      FileId file_id;
      string directory_name;
      get_args(args, file_id, directory_name);
      send_request(td_api::make_object<td_api::getSuggestedFileName>(file_id, directory_name));
    } else if (op == "uf" || op == "ufs" || op == "ufse") {
      string file_path;
      int32 priority;
      get_args(args, file_path, priority);
      if (priority <= 0) {
        priority = 1;
      }
      td_api::object_ptr<td_api::FileType> type = td_api::make_object<td_api::fileTypePhoto>();
      if (op == "ufs") {
        type = td_api::make_object<td_api::fileTypeSecret>();
      }
      if (op == "ufse") {
        type = td_api::make_object<td_api::fileTypeSecure>();
      }
      send_request(
          td_api::make_object<td_api::preliminaryUploadFile>(as_input_file(file_path), std::move(type), priority));
    } else if (op == "ufg") {
      string file_path;
      string conversion;
      get_args(args, file_path, conversion);
      send_request(td_api::make_object<td_api::preliminaryUploadFile>(as_generated_file(file_path, conversion),
                                                                      td_api::make_object<td_api::fileTypePhoto>(), 1));
    } else if (op == "cuf") {
      FileId file_id;
      get_args(args, file_id);
      send_request(td_api::make_object<td_api::cancelPreliminaryUploadFile>(file_id));
    } else if (op == "delf") {
      FileId file_id;
      get_args(args, file_id);
      send_request(td_api::make_object<td_api::deleteFile>(file_id));
    } else if (op == "aftd") {
      FileId file_id;
      ChatId chat_id;
      MessageId message_id;
      int32 priority;
      get_args(args, file_id, chat_id, message_id, priority);
      send_request(td_api::make_object<td_api::addFileToDownloads>(file_id, chat_id, message_id, max(priority, 1)));
    } else if (op == "tdip") {
      FileId file_id;
      bool is_paused;
      get_args(args, file_id, is_paused);
      send_request(td_api::make_object<td_api::toggleDownloadIsPaused>(file_id, is_paused));
    } else if (op == "tadap") {
      bool are_paused;
      get_args(args, are_paused);
      send_request(td_api::make_object<td_api::toggleAllDownloadsArePaused>(are_paused));
    } else if (op == "rffd") {
      FileId file_id;
      bool delete_from_cache;
      get_args(args, file_id, delete_from_cache);
      send_request(td_api::make_object<td_api::removeFileFromDownloads>(file_id, delete_from_cache));
    } else if (op == "raffd" || op == "raffda" || op == "raffdc") {
      bool delete_from_cache;
      get_args(args, delete_from_cache);
      send_request(td_api::make_object<td_api::removeAllFilesFromDownloads>(op.back() == 'a', op.back() == 'c',
                                                                            delete_from_cache));
    } else if (op == "sfd" || op == "sfda" || op == "sfdc") {
      string offset;
      SearchQuery query;
      get_args(args, offset, query);
      send_request(td_api::make_object<td_api::searchFileDownloads>(query.query, op.back() == 'a', op.back() == 'c',
                                                                    offset, query.limit));
    } else if (op == "dm" || op == "dmr") {
      ChatId chat_id;
      string message_ids;
      get_args(args, chat_id, message_ids);
      send_request(td_api::make_object<td_api::deleteMessages>(chat_id, as_message_ids(message_ids), op == "dmr"));
    } else if (op == "fm" || op == "cm") {
      ChatId chat_id;
      ChatId from_chat_id;
      string message_ids;
      get_args(args, chat_id, from_chat_id, message_ids);
      send_request(td_api::make_object<td_api::forwardMessages>(
          chat_id, message_thread_id_, from_chat_id, as_message_ids(message_ids), default_message_send_options(),
          op[0] == 'c', rand_bool()));
    } else if (op == "sqrsm") {
      ChatId chat_id;
      ShortcutId shortcut_id;
      get_args(args, chat_id, shortcut_id);
      send_request(
          td_api::make_object<td_api::sendQuickReplyShortcutMessages>(chat_id, shortcut_id, Random::fast(-1000, -1)));
    } else if (op == "resend") {
      ChatId chat_id;
      string message_ids;
      string quote;
      int32 quote_position;
      get_args(args, chat_id, message_ids, quote, quote_position);
      if (quick_reply_shortcut_name_.empty()) {
        send_request(td_api::make_object<td_api::resendMessages>(
            chat_id, as_message_ids(message_ids),
            td_api::make_object<td_api::inputTextQuote>(as_formatted_text(quote), quote_position),
            paid_message_star_count_));
      } else {
        send_request(td_api::make_object<td_api::readdQuickReplyShortcutMessages>(quick_reply_shortcut_name_,
                                                                                  as_message_ids(message_ids)));
      }
    } else if (op == "csc") {
      send_request(td_api::make_object<td_api::createSecretChat>(as_secret_chat_id(args)));
    } else if (op == "cnsc") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::createNewSecretChat>(user_id));
    } else if (op == "closeSC" || op == "cancelSC") {
      send_request(td_api::make_object<td_api::closeSecretChat>(as_secret_chat_id(args)));
    } else {
      op_not_found_count++;
    }

    if (op == "cc") {
      UserId user_id;
      GroupCallId group_call_id;
      get_args(args, user_id, group_call_id);
      send_request(td_api::make_object<td_api::createCall>(
          user_id, td_api::make_object<td_api::callProtocol>(true, true, 65, 65, vector<string>{"2.6", "3.0"}),
          rand_bool(), group_call_id));
    } else if (op == "ac") {
      CallId call_id;
      get_args(args, call_id);
      send_request(td_api::make_object<td_api::acceptCall>(
          call_id, td_api::make_object<td_api::callProtocol>(true, true, 65, 65, vector<string>{"2.6", "3.0"})));
    } else if (op == "scsd") {
      CallId call_id;
      get_args(args, call_id);
      send_request(td_api::make_object<td_api::sendCallSignalingData>(call_id, "abacaba"));
    } else if (op == "dc") {
      CallId call_id;
      bool is_disconnected;
      get_args(args, call_id, is_disconnected);
      send_request(td_api::make_object<td_api::discardCall>(call_id, is_disconnected, 0, rand_bool(), 0));
    } else if (op == "scr") {
      CallId call_id;
      int32 rating;
      get_args(args, call_id, rating);
      vector<td_api::object_ptr<td_api::CallProblem>> problems;
      problems.emplace_back(td_api::make_object<td_api::callProblemNoise>());
      problems.emplace_back(td_api::make_object<td_api::callProblemNoise>());
      problems.emplace_back(td_api::make_object<td_api::callProblemDistortedVideo>());
      problems.emplace_back(nullptr);
      problems.emplace_back(td_api::make_object<td_api::callProblemNoise>());
      problems.emplace_back(td_api::make_object<td_api::callProblemEcho>());
      problems.emplace_back(td_api::make_object<td_api::callProblemPixelatedVideo>());
      problems.emplace_back(td_api::make_object<td_api::callProblemDistortedSpeech>());
      send_request(td_api::make_object<td_api::sendCallRating>(call_id, rating, "Wow, such good call! (TDLib test)",
                                                               std::move(problems)));
    } else if (op == "scdi") {
      CallId call_id;
      get_args(args, call_id);
      send_request(td_api::make_object<td_api::sendCallDebugInformation>(call_id, "{}"));
    } else if (op == "sclog") {
      CallId call_id;
      string log_file;
      get_args(args, call_id, log_file);
      send_request(td_api::make_object<td_api::sendCallLog>(call_id, as_input_file(log_file)));
    } else if (op == "gvcap") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getVideoChatAvailableParticipants>(chat_id));
    } else if (op == "svcdp") {
      ChatId chat_id;
      string participant_id;
      get_args(args, chat_id, participant_id);
      send_request(
          td_api::make_object<td_api::setVideoChatDefaultParticipant>(chat_id, as_message_sender(participant_id)));
    } else if (op == "cvc") {
      ChatId chat_id;
      string title;
      int32 start_date;
      bool is_rtmp_stream;
      get_args(args, chat_id, title, start_date, is_rtmp_stream);
      send_request(td_api::make_object<td_api::createVideoChat>(chat_id, title, start_date, is_rtmp_stream));
    } else if (op == "cgc") {
      CallId call_id;
      get_args(args, call_id);
      send_request(td_api::make_object<td_api::createGroupCall>(call_id));
    } else if (op == "gvcru") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getVideoChatRtmpUrl>(chat_id));
    } else if (op == "rvcru") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::replaceVideoChatRtmpUrl>(chat_id));
    } else if (op == "ggc") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::getGroupCall>(group_call_id));
    } else if (op == "ggcs") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::getGroupCallStreams>(group_call_id));
    } else if (op == "ggcss") {
      GroupCallId group_call_id;
      int32 channel_id;
      get_args(args, group_call_id, channel_id);
      send_request(td_api::make_object<td_api::getGroupCallStreamSegment>(
          group_call_id, (std::time(nullptr) - 5) * 1000, 0, channel_id, nullptr));
    } else if (op == "ssgc") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::startScheduledGroupCall>(group_call_id));
    } else if (op == "tgcesn" || op == "tgcesne") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(
          td_api::make_object<td_api::toggleGroupCallEnabledStartNotification>(group_call_id, op == "tgcesne"));
    } else if (op == "jgc" || op == "jgcv" || op == "sgcss") {
      GroupCallId group_call_id;
      string participant_id;
      string invite_hash;
      int64 key_fingerprint;
      get_args(args, group_call_id, participant_id, invite_hash, key_fingerprint);

      auto payload = PSTRING() << "{\"ufrag\":\"ufrag\",\"pwd\":\"pwd\",\"fingerprints\":[{\"hash\":\"hash\",\"setup\":"
                                  "\"setup\",\"fingerprint\":\"fingerprint\"},{\"hash\":\"h2\",\"setup\":\"s2\","
                                  "\"fingerprint\":\"fingerprint2\"}],\"ssrc\":"
                               << group_call_source_ << ',';
      if (op == "jgc") {
        payload.back() = '}';
      } else {
        string sim_sources = "[1,2]";
        string fid_sources = "[3,4]";
        if (op == "sgcss") {
          sim_sources = "[5,6]";
          fid_sources = "[7,8]";
        }
        payload +=
            "\"payload-types\":[{\"id\":12345,\"name\":\"opus\",\"clockrate\":48000,\"channels\":2,\"rtcp-fbs\":[{"
            "\"type\":\"transport-cc\",\"subtype\":\"subtype1\"},{\"type\":\"type2\",\"subtype\":\"subtype2\"}],"
            "\"parameters\":{\"minptime\":\"10\",\"useinbandfec\":\"1\"}}],\"rtp-hdrexts\":[{\"id\":1,\"uri\":\"urn:"
            "ietf:params:rtp-hdrext:ssrc-audio-level\"}],\"ssrc-groups\":[{\"sources\":" +
            sim_sources + ",\"semantics\":\"SIM\"},{\"sources\":" + fid_sources + ",\"semantics\":\"FID\"}]}";
      }
      if (op == "sgcss") {
        send_request(td_api::make_object<td_api::startGroupCallScreenSharing>(group_call_id, group_call_source_ + 1,
                                                                              std::move(payload)));
      } else {
        send_request(td_api::make_object<td_api::joinGroupCall>(group_call_id, as_message_sender(participant_id),
                                                                group_call_source_, std::move(payload), true, true,
                                                                invite_hash, key_fingerprint));
      }
    } else if (op == "tgcssip") {
      GroupCallId group_call_id;
      bool is_paused;
      get_args(args, group_call_id, is_paused);
      send_request(td_api::make_object<td_api::toggleGroupCallScreenSharingIsPaused>(group_call_id, is_paused));
    } else if (op == "egcss") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::endGroupCallScreenSharing>(group_call_id));
    } else if (op == "sgct") {
      GroupCallId group_call_id;
      string title;
      get_args(args, group_call_id, title);
      send_request(td_api::make_object<td_api::setGroupCallTitle>(group_call_id, title));
    } else if (op == "tgcmnp" || op == "tgcmnpe") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::toggleGroupCallMuteNewParticipants>(group_call_id, op == "tgcmnpe"));
    } else if (op == "rgcil") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::revokeGroupCallInviteLink>(group_call_id));
    } else if (op == "tgcimvp") {
      GroupCallId group_call_id;
      bool is_my_video_paused;
      get_args(args, group_call_id, is_my_video_paused);
      send_request(td_api::make_object<td_api::toggleGroupCallIsMyVideoPaused>(group_call_id, is_my_video_paused));
    } else if (op == "tgcimve") {
      GroupCallId group_call_id;
      bool is_my_video_enabled;
      get_args(args, group_call_id, is_my_video_enabled);
      send_request(td_api::make_object<td_api::toggleGroupCallIsMyVideoEnabled>(group_call_id, is_my_video_enabled));
    } else if (op == "sgcpis") {
      GroupCallId group_call_id;
      int32 source_id;
      bool is_speaking;
      get_args(args, group_call_id, source_id, is_speaking);
      send_request(
          td_api::make_object<td_api::setGroupCallParticipantIsSpeaking>(group_call_id, source_id, is_speaking));
    } else if (op == "igcp") {
      GroupCallId group_call_id;
      string user_ids;
      get_args(args, group_call_id, user_ids);
      send_request(td_api::make_object<td_api::inviteGroupCallParticipants>(group_call_id, as_user_ids(user_ids)));
    } else if (op == "ggcil") {
      GroupCallId group_call_id;
      bool can_self_unmute;
      get_args(args, group_call_id, can_self_unmute);
      send_request(td_api::make_object<td_api::getGroupCallInviteLink>(group_call_id, can_self_unmute));
    } else if (op == "sgcr") {
      GroupCallId group_call_id;
      string title;
      bool record_video;
      bool use_portrait_orientation;
      get_args(args, group_call_id, title, record_video, use_portrait_orientation);
      send_request(td_api::make_object<td_api::startGroupCallRecording>(group_call_id, title, record_video,
                                                                        use_portrait_orientation));
    } else if (op == "egcr") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::endGroupCallRecording>(group_call_id));
    } else if (op == "tgcpim") {
      GroupCallId group_call_id;
      string participant_id;
      bool is_muted;
      get_args(args, group_call_id, participant_id, is_muted);
      send_request(td_api::make_object<td_api::toggleGroupCallParticipantIsMuted>(
          group_call_id, as_message_sender(participant_id), is_muted));
    } else if (op == "sgcpvl") {
      GroupCallId group_call_id;
      string participant_id;
      int32 volume_level;
      get_args(args, group_call_id, participant_id, volume_level);
      send_request(td_api::make_object<td_api::setGroupCallParticipantVolumeLevel>(
          group_call_id, as_message_sender(participant_id), volume_level));
    } else if (op == "tgcpihr") {
      GroupCallId group_call_id;
      string participant_id;
      bool is_hand_raised;
      get_args(args, group_call_id, participant_id, is_hand_raised);
      send_request(td_api::make_object<td_api::toggleGroupCallParticipantIsHandRaised>(
          group_call_id, as_message_sender(participant_id), is_hand_raised));
    } else if (op == "lgcp") {
      GroupCallId group_call_id;
      string limit;
      get_args(args, group_call_id, limit);
      send_request(td_api::make_object<td_api::loadGroupCallParticipants>(group_call_id, as_limit(limit)));
    } else if (op == "lgc") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::leaveGroupCall>(group_call_id));
    } else if (op == "egc") {
      GroupCallId group_call_id;
      get_args(args, group_call_id);
      send_request(td_api::make_object<td_api::endGroupCall>(group_call_id));
    } else {
      op_not_found_count++;
    }

    if (op == "rpcil") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::replacePrimaryChatInviteLink>(chat_id));
    } else if (op == "ccilt") {
      ChatId chat_id;
      string name;
      int32 expiration_date;
      int32 member_limit;
      bool creates_join_request;
      get_args(args, chat_id, name, expiration_date, member_limit, creates_join_request);
      send_request(td_api::make_object<td_api::createChatInviteLink>(chat_id, name, expiration_date, member_limit,
                                                                     creates_join_request));
    } else if (op == "ccsil") {
      ChatId chat_id;
      string name;
      int32 period;
      int64 star_count;
      get_args(args, chat_id, name, period, star_count);
      send_request(td_api::make_object<td_api::createChatSubscriptionInviteLink>(
          chat_id, name, td_api::make_object<td_api::starSubscriptionPricing>(period, star_count)));
    } else if (op == "ecil") {
      ChatId chat_id;
      string invite_link;
      string name;
      int32 expiration_date;
      int32 member_limit;
      bool creates_join_request;
      get_args(args, chat_id, invite_link, name, expiration_date, member_limit, creates_join_request);
      send_request(td_api::make_object<td_api::editChatInviteLink>(chat_id, invite_link, name, expiration_date,
                                                                   member_limit, creates_join_request));
    } else if (op == "ecsil") {
      ChatId chat_id;
      string invite_link;
      string name;
      get_args(args, chat_id, invite_link, name);
      send_request(td_api::make_object<td_api::editChatSubscriptionInviteLink>(chat_id, invite_link, name));
    } else if (op == "rcil") {
      ChatId chat_id;
      string invite_link;
      get_args(args, chat_id, invite_link);
      send_request(td_api::make_object<td_api::revokeChatInviteLink>(chat_id, invite_link));
    } else if (op == "gcilc") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatInviteLinkCounts>(chat_id));
    } else if (op == "gcil") {
      ChatId chat_id;
      string invite_link;
      get_args(args, chat_id, invite_link);
      send_request(td_api::make_object<td_api::getChatInviteLink>(chat_id, invite_link));
    } else if (op == "gcils" || op == "gcilr") {
      ChatId chat_id;
      UserId creator_user_id;
      int32 offset_date;
      string offset_invite_link;
      string limit;
      get_args(args, chat_id, creator_user_id, offset_date, offset_invite_link, limit);
      send_request(td_api::make_object<td_api::getChatInviteLinks>(chat_id, creator_user_id, op == "gcilr", offset_date,
                                                                   offset_invite_link, as_limit(limit)));
    } else if (op == "gcilm" || op == "gcilme") {
      ChatId chat_id;
      string invite_link;
      UserId offset_user_id;
      int32 offset_date;
      string limit;
      get_args(args, chat_id, invite_link, offset_user_id, offset_date, limit);
      send_request(td_api::make_object<td_api::getChatInviteLinkMembers>(
          chat_id, invite_link, op == "gcilme",
          td_api::make_object<td_api::chatInviteLinkMember>(offset_user_id, offset_date, false, 0), as_limit(limit)));
    } else if (op == "gcjr") {
      ChatId chat_id;
      string invite_link;
      string query;
      UserId offset_user_id;
      int32 offset_date;
      string limit;
      get_args(args, chat_id, invite_link, query, offset_user_id, offset_date, limit);
      send_request(td_api::make_object<td_api::getChatJoinRequests>(
          chat_id, invite_link, query,
          td_api::make_object<td_api::chatJoinRequest>(offset_user_id, offset_date, string()), as_limit(limit)));
    } else if (op == "pcjr") {
      ChatId chat_id;
      UserId user_id;
      bool approve;
      get_args(args, chat_id, user_id, approve);
      send_request(td_api::make_object<td_api::processChatJoinRequest>(chat_id, user_id, approve));
    } else if (op == "pcjrs") {
      ChatId chat_id;
      string invite_link;
      bool approve;
      get_args(args, chat_id, invite_link, approve);
      send_request(td_api::make_object<td_api::processChatJoinRequests>(chat_id, invite_link, approve));
    } else if (op == "drcil") {
      ChatId chat_id;
      string invite_link;
      get_args(args, chat_id, invite_link);
      send_request(td_api::make_object<td_api::deleteRevokedChatInviteLink>(chat_id, invite_link));
    } else if (op == "darcil") {
      ChatId chat_id;
      UserId creator_user_id;
      get_args(args, chat_id, creator_user_id);
      send_request(td_api::make_object<td_api::deleteAllRevokedChatInviteLinks>(chat_id, creator_user_id));
    } else if (op == "ccil") {
      send_request(td_api::make_object<td_api::checkChatInviteLink>(args));
    } else if (op == "jcbil") {
      send_request(td_api::make_object<td_api::joinChatByInviteLink>(args));
    } else if (op == "sq") {
      string text;
      string quote;
      int32 quote_position;
      get_args(args, text, quote, quote_position);
      execute(
          td_api::make_object<td_api::searchQuote>(as_formatted_text(text), as_formatted_text(quote), quote_position));
    } else if (op == "gte") {
      send_request(td_api::make_object<td_api::getTextEntities>(args));
    } else if (op == "gtee") {
      execute(td_api::make_object<td_api::getTextEntities>(args));
    } else if (op == "pm") {
      send_request(
          td_api::make_object<td_api::parseMarkdown>(td_api::make_object<td_api::formattedText>(args, Auto())));
    } else if (op == "pte") {
      send_request(
          td_api::make_object<td_api::parseTextEntities>(args, td_api::make_object<td_api::textParseModeMarkdown>(2)));
    } else if (op == "pteh") {
      send_request(
          td_api::make_object<td_api::parseTextEntities>(args, td_api::make_object<td_api::textParseModeHTML>()));
    } else if (op == "ptes") {
      execute(
          td_api::make_object<td_api::parseTextEntities>(args, td_api::make_object<td_api::textParseModeMarkdown>(2)));
    } else if (op == "ptehs") {
      execute(td_api::make_object<td_api::parseTextEntities>(args, td_api::make_object<td_api::textParseModeHTML>()));
    } else if (op == "ssbp") {
      string strings;
      string query;
      string limit;
      bool return_none_for_empty_query;
      get_args(args, strings, query, limit, return_none_for_empty_query);
      execute(td_api::make_object<td_api::searchStringsByPrefix>(autosplit_str(strings), query, as_limit(limit),
                                                                 return_none_for_empty_query));
    } else if (op == "gcfe") {
      execute(td_api::make_object<td_api::getCountryFlagEmoji>(trim(args)));
    } else if (op == "gfmt") {
      execute(td_api::make_object<td_api::getFileMimeType>(trim(args)));
    } else if (op == "gfe") {
      execute(td_api::make_object<td_api::getFileExtension>(trim(args)));
    } else if (op == "cfn") {
      execute(td_api::make_object<td_api::cleanFileName>(args));
    } else if (op == "gjv") {
      execute(td_api::make_object<td_api::getJsonValue>(args));
    } else if (op == "gjvtest") {
      execute(td_api::make_object<td_api::getJsonValue>("\"aba\200caba\""));
      execute(td_api::make_object<td_api::getJsonValue>("\"\\u0080\""));
      execute(td_api::make_object<td_api::getJsonValue>("\"\\uD800\""));
    } else if (op == "gjs") {
      auto test_get_json_string = [&](td_api::object_ptr<td_api::JsonValue> &&json_value) {
        execute(td_api::make_object<td_api::getJsonString>(std::move(json_value)));
      };

      test_get_json_string(nullptr);
      test_get_json_string(td_api::make_object<td_api::jsonValueNull>());
      test_get_json_string(td_api::make_object<td_api::jsonValueBoolean>(true));
      test_get_json_string(td_api::make_object<td_api::jsonValueNumber>(123456789123.0));
      test_get_json_string(td_api::make_object<td_api::jsonValueString>(string("aba\0caba", 8)));
      test_get_json_string(td_api::make_object<td_api::jsonValueString>("aba\200caba"));

      auto inner_array = td_api::make_object<td_api::jsonValueArray>();
      inner_array->values_.emplace_back(td_api::make_object<td_api::jsonValueBoolean>(false));
      auto array = td_api::make_object<td_api::jsonValueArray>();
      array->values_.emplace_back(nullptr);
      array->values_.emplace_back(std::move(inner_array));
      array->values_.emplace_back(td_api::make_object<td_api::jsonValueNull>());
      array->values_.emplace_back(td_api::make_object<td_api::jsonValueNumber>(-1));
      test_get_json_string(std::move(array));

      auto object = td_api::make_object<td_api::jsonValueObject>();
      object->members_.emplace_back(
          td_api::make_object<td_api::jsonObjectMember>("", td_api::make_object<td_api::jsonValueString>("test")));
      object->members_.emplace_back(td_api::make_object<td_api::jsonObjectMember>("a", nullptr));
      object->members_.emplace_back(td_api::make_object<td_api::jsonObjectMember>("\x80", nullptr));
      object->members_.emplace_back(nullptr);
      object->members_.emplace_back(
          td_api::make_object<td_api::jsonObjectMember>("a", td_api::make_object<td_api::jsonValueNull>()));
      test_get_json_string(std::move(object));
    } else if (op == "gtpjs") {
      execute(td_api::make_object<td_api::getThemeParametersJsonString>(as_theme_parameters()));
    } else if (op == "gac") {
      send_request(td_api::make_object<td_api::getApplicationConfig>());
    } else if (op == "sale") {
      string type;
      ChatId chat_id;
      string json;
      get_args(args, type, chat_id, json);
      auto result = execute(td_api::make_object<td_api::getJsonValue>(json));
      if (result->get_id() == td_api::error::ID) {
        LOG(ERROR) << to_string(result);
      } else {
        send_request(td_api::make_object<td_api::saveApplicationLogEvent>(
            type, chat_id, move_tl_object_as<td_api::JsonValue>(result)));
      }
    } else {
      op_not_found_count++;
    }

    if (op == "scdm") {
      ChatId chat_id;
      string message;
      get_args(args, chat_id, message);
      td_api::object_ptr<td_api::draftMessage> draft_message;
      auto reply_to = get_input_message_reply_to();
      if (reply_to != nullptr || !message.empty()) {
        vector<td_api::object_ptr<td_api::textEntity>> entities;
        if (!message.empty()) {
          entities.push_back(
              td_api::make_object<td_api::textEntity>(0, 1, td_api::make_object<td_api::textEntityTypePre>()));
        }
        draft_message = td_api::make_object<td_api::draftMessage>(
            std::move(reply_to), 0,
            td_api::make_object<td_api::inputMessageText>(as_formatted_text(message, std::move(entities)),
                                                          get_link_preview_options(), false),
            message_effect_id_);
      }
      send_request(
          td_api::make_object<td_api::setChatDraftMessage>(chat_id, message_thread_id_, std::move(draft_message)));
    } else if (op == "scdmvn") {
      ChatId chat_id;
      string video;
      get_args(args, chat_id, video);
      send_request(td_api::make_object<td_api::setChatDraftMessage>(
          chat_id, message_thread_id_,
          td_api::make_object<td_api::draftMessage>(
              nullptr, 0,
              td_api::make_object<td_api::inputMessageVideoNote>(as_input_file(video), get_input_thumbnail(), 10, 5,
                                                                 get_message_self_destruct_type()),
              message_effect_id_)));
    } else if (op == "scdmvoice") {
      ChatId chat_id;
      string voice;
      get_args(args, chat_id, voice);
      send_request(td_api::make_object<td_api::setChatDraftMessage>(
          chat_id, message_thread_id_,
          td_api::make_object<td_api::draftMessage>(
              nullptr, 0,
              td_api::make_object<td_api::inputMessageVoiceNote>(as_input_file(voice), 0, "abacaba", get_caption(),
                                                                 get_message_self_destruct_type()),
              message_effect_id_)));
    } else if (op == "cadm") {
      send_request(td_api::make_object<td_api::clearAllDraftMessages>());
    } else if (op == "tchpc") {
      ChatId chat_id;
      bool has_protected_content;
      get_args(args, chat_id, has_protected_content);
      send_request(td_api::make_object<td_api::toggleChatHasProtectedContent>(chat_id, has_protected_content));
    } else if (op == "tcip" || op == "tcipa" || begins_with(op, "tcip-")) {
      ChatId chat_id;
      bool is_pinned;
      get_args(args, chat_id, is_pinned);
      send_request(td_api::make_object<td_api::toggleChatIsPinned>(as_chat_list(op), chat_id, is_pinned));
    } else if (op == "tcimau") {
      ChatId chat_id;
      bool is_marked_as_unread;
      get_args(args, chat_id, is_marked_as_unread);
      send_request(td_api::make_object<td_api::toggleChatIsMarkedAsUnread>(chat_id, is_marked_as_unread));
    } else if (op == "tcvat") {
      ChatId chat_id;
      bool view_as_topics;
      get_args(args, chat_id, view_as_topics);
      send_request(td_api::make_object<td_api::toggleChatViewAsTopics>(chat_id, view_as_topics));
    } else if (op == "tcit") {
      ChatId chat_id;
      bool is_translatable;
      get_args(args, chat_id, is_translatable);
      send_request(td_api::make_object<td_api::toggleChatIsTranslatable>(chat_id, is_translatable));
    } else if (op == "smsbl") {
      string sender_id;
      string block_list;
      get_args(args, sender_id, block_list);
      send_request(td_api::make_object<td_api::setMessageSenderBlockList>(as_message_sender(sender_id),
                                                                          as_block_list(block_list)));
    } else if (op == "bmsfr") {
      MessageId message_id;
      bool delete_message;
      bool delete_all_messages;
      bool report_spam;
      get_args(args, message_id, delete_message, delete_all_messages, report_spam);
      send_request(td_api::make_object<td_api::blockMessageSenderFromReplies>(message_id, delete_message,
                                                                              delete_all_messages, report_spam));
    } else if (op == "tcddn") {
      ChatId chat_id;
      bool default_disable_notification;
      get_args(args, chat_id, default_disable_notification);
      send_request(
          td_api::make_object<td_api::toggleChatDefaultDisableNotification>(chat_id, default_disable_notification));
    } else if (op == "spchats" || op == "spchatsa" || begins_with(op, "spchats-")) {
      send_request(td_api::make_object<td_api::setPinnedChats>(as_chat_list(op), as_chat_ids(args)));
    } else if (op == "rcl" || op == "rcla" || begins_with(op, "rcl-")) {
      send_request(td_api::make_object<td_api::readChatList>(as_chat_list(op)));
    } else if (op == "gcwe") {
      string latitude;
      string longitude;
      get_args(args, latitude, longitude);
      send_request(td_api::make_object<td_api::getCurrentWeather>(as_location(latitude, longitude, "0.0")));
    } else if (op == "gst" || op == "gstl") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      get_args(args, story_sender_chat_id, story_id);
      send_request(td_api::make_object<td_api::getStory>(story_sender_chat_id, story_id, op == "gstl"));
    } else if (op == "gctss") {
      send_request(td_api::make_object<td_api::getChatsToSendStories>());
    } else if (op == "csst") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::canSendStory>(chat_id));
    } else if (op == "srsfi") {
      get_args(args, reposted_story_chat_id_, reposted_story_id_);
    } else if (op == "ssp" || op == "sspp") {
      ChatId chat_id;
      string photo;
      StoryPrivacySettings rules;
      InputStoryAreas areas;
      int32 active_period;
      bool protect_content;
      get_args(args, chat_id, photo, rules, areas, active_period, protect_content);
      send_request(td_api::make_object<td_api::sendStory>(
          chat_id,
          td_api::make_object<td_api::inputStoryContentPhoto>(as_input_file(photo), get_added_sticker_file_ids()),
          areas, get_caption(), rules, active_period ? active_period : 86400, get_reposted_story_full_id(),
          op == "sspp", protect_content));
    } else if (op == "ssv" || op == "ssvp") {
      ChatId chat_id;
      string video;
      StoryPrivacySettings rules;
      InputStoryAreas areas;
      int32 active_period;
      double duration;
      bool protect_content;
      get_args(args, chat_id, video, rules, areas, active_period, duration, protect_content);
      send_request(td_api::make_object<td_api::sendStory>(
          chat_id,
          td_api::make_object<td_api::inputStoryContentVideo>(as_input_file(video), get_added_sticker_file_ids(),
                                                              duration, 0.5, true),
          areas, get_caption(), rules, active_period ? active_period : 86400, get_reposted_story_full_id(),
          op == "ssvp", protect_content));
    } else if (op == "esc") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      InputStoryAreas areas;
      get_args(args, story_sender_chat_id, story_id, areas);
      send_request(
          td_api::make_object<td_api::editStory>(story_sender_chat_id, story_id, nullptr, areas, get_caption()));
    } else if (op == "esp") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      string photo;
      InputStoryAreas areas;
      get_args(args, story_sender_chat_id, story_id, photo, areas);
      send_request(td_api::make_object<td_api::editStory>(
          story_sender_chat_id, story_id,
          td_api::make_object<td_api::inputStoryContentPhoto>(as_input_file(photo), get_added_sticker_file_ids()),
          areas, get_caption()));
    } else if (op == "esv") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      string video;
      InputStoryAreas areas;
      int32 duration;
      get_args(args, story_sender_chat_id, story_id, video, duration);
      send_request(td_api::make_object<td_api::editStory>(
          story_sender_chat_id, story_id,
          td_api::make_object<td_api::inputStoryContentVideo>(as_input_file(video), get_added_sticker_file_ids(),
                                                              duration, 0.0, false),
          areas, get_caption()));
    } else if (op == "esco") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      double cover_frame_timetamp;
      get_args(args, story_sender_chat_id, story_id, cover_frame_timetamp);
      send_request(td_api::make_object<td_api::editStoryCover>(story_sender_chat_id, story_id, cover_frame_timetamp));
    } else if (op == "ssps") {
      StoryId story_id;
      StoryPrivacySettings rules;
      get_args(args, story_id, rules);
      send_request(td_api::make_object<td_api::setStoryPrivacySettings>(story_id, rules));
    } else if (op == "tsiptcp") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      bool is_posted_to_chat_page;
      get_args(args, story_sender_chat_id, story_id, is_posted_to_chat_page);
      send_request(td_api::make_object<td_api::toggleStoryIsPostedToChatPage>(story_sender_chat_id, story_id,
                                                                              is_posted_to_chat_page));
    } else if (op == "ds") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      get_args(args, story_sender_chat_id, story_id);
      send_request(td_api::make_object<td_api::deleteStory>(story_sender_chat_id, story_id));
    } else if (op == "las" || op == "lasa" || op == "lase") {
      send_request(td_api::make_object<td_api::loadActiveStories>(as_story_list(op)));
    } else if (op == "scasl" || op == "scasla" || op == "scasle") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::setChatActiveStoriesList>(chat_id, as_story_list(op)));
    } else if (op == "gcptcps") {
      ChatId chat_id;
      StoryId from_story_id;
      string limit;
      get_args(args, chat_id, from_story_id, limit);
      send_request(
          td_api::make_object<td_api::getChatPostedToChatPageStories>(chat_id, from_story_id, as_limit(limit)));
    } else if (op == "gcast") {
      ChatId chat_id;
      StoryId from_story_id;
      string limit;
      get_args(args, chat_id, from_story_id, limit);
      send_request(td_api::make_object<td_api::getChatArchivedStories>(chat_id, from_story_id, as_limit(limit)));
    } else if (op == "scps") {
      ChatId chat_id;
      get_args(args, chat_id, args);
      vector<int32> story_ids;
      while (true) {
        StoryId story_id;
        get_args(args, story_id, args);
        if (story_id <= 0) {
          break;
        }
        story_ids.push_back(story_id);
      }
      send_request(td_api::make_object<td_api::setChatPinnedStories>(chat_id, std::move(story_ids)));
    } else if (op == "gsnse") {
      send_request(td_api::make_object<td_api::getStoryNotificationSettingsExceptions>());
    } else if (op == "gcas") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatActiveStories>(chat_id));
    } else if (op == "os") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      get_args(args, story_sender_chat_id, story_id);
      send_request(td_api::make_object<td_api::openStory>(story_sender_chat_id, story_id));
    } else if (op == "cs") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      get_args(args, story_sender_chat_id, story_id);
      send_request(td_api::make_object<td_api::closeStory>(story_sender_chat_id, story_id));
    } else if (op == "gsar") {
      int32 row_size;
      get_args(args, row_size);
      send_request(td_api::make_object<td_api::getStoryAvailableReactions>(row_size));
    } else if (op == "ssr") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      string reaction;
      bool update_recent_reactions;
      get_args(args, story_sender_chat_id, story_id, reaction, update_recent_reactions);
      send_request(td_api::make_object<td_api::setStoryReaction>(story_sender_chat_id, story_id,
                                                                 as_reaction_type(reaction), update_recent_reactions));
    } else if (op == "gsi") {
      StoryId story_id;
      string limit;
      string offset;
      string query;
      bool only_contacts;
      bool prefer_forwards;
      bool prefer_with_reaction;
      get_args(args, story_id, limit, offset, query, only_contacts, prefer_forwards, prefer_with_reaction);
      send_request(td_api::make_object<td_api::getStoryInteractions>(story_id, query, only_contacts, prefer_forwards,
                                                                     prefer_with_reaction, offset, as_limit(limit)));
    } else if (op == "gcsi") {
      ChatId chat_id;
      StoryId story_id;
      string limit;
      string offset;
      string reaction_type;
      bool prefer_forwards;
      get_args(args, chat_id, story_id, limit, offset, reaction_type, prefer_forwards);
      send_request(td_api::make_object<td_api::getChatStoryInteractions>(
          chat_id, story_id, as_reaction_type(reaction_type), prefer_forwards, offset, as_limit(limit)));
    } else if (op == "rst") {
      ChatId story_sender_chat_id;
      StoryId story_id;
      string option_id;
      string text;
      get_args(args, story_sender_chat_id, story_id, option_id, text);
      send_request(td_api::make_object<td_api::reportStory>(story_sender_chat_id, story_id, option_id, text));
    } else if (op == "assm") {
      send_request(td_api::make_object<td_api::activateStoryStealthMode>());
    } else if (op == "gcblf") {
      bool is_channel;
      int32 level;
      get_args(args, is_channel, level);
      send_request(td_api::make_object<td_api::getChatBoostLevelFeatures>(is_channel, level));
    } else if (op == "gcbf") {
      bool is_channel;
      get_args(args, is_channel);
      send_request(td_api::make_object<td_api::getChatBoostFeatures>(is_channel));
    } else if (op == "gacbs") {
      send_request(td_api::make_object<td_api::getAvailableChatBoostSlots>());
    } else if (op == "gcbs") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatBoostStatus>(chat_id));
    } else if (op == "bc") {
      ChatId chat_id;
      string slot_ids;
      get_args(args, chat_id, slot_ids);
      send_request(td_api::make_object<td_api::boostChat>(chat_id, to_integers<int32>(slot_ids)));
    } else if (op == "gcbl") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatBoostLink>(chat_id));
    } else if (op == "gcbli") {
      send_request(td_api::make_object<td_api::getChatBoostLinkInfo>(args));
    } else if (op == "gcb") {
      ChatId chat_id;
      bool only_gift_codes;
      string offset;
      string limit;
      get_args(args, chat_id, only_gift_codes, offset, limit);
      send_request(td_api::make_object<td_api::getChatBoosts>(chat_id, only_gift_codes, offset, as_limit(limit)));
    } else if (op == "gucb") {
      ChatId chat_id;
      UserId user_id;
      get_args(args, chat_id, user_id);
      send_request(td_api::make_object<td_api::getUserChatBoosts>(chat_id, user_id));
    } else {
      op_not_found_count++;
    }

    if (op == "gamb") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::getAttachmentMenuBot>(user_id));
    } else if (op == "tbiatam") {
      UserId user_id;
      bool is_added;
      bool allow_write_access;
      get_args(args, user_id, is_added, allow_write_access);
      send_request(
          td_api::make_object<td_api::toggleBotIsAddedToAttachmentMenu>(user_id, is_added, allow_write_access));
    } else if (op == "ggwab") {
      string offset;
      string limit;
      get_args(args, offset, limit);
      send_request(td_api::make_object<td_api::getGrossingWebAppBots>(offset, as_limit(limit)));
    } else if (op == "swa") {
      UserId bot_user_id;
      string short_name;
      get_args(args, bot_user_id, short_name);
      send_request(td_api::make_object<td_api::searchWebApp>(bot_user_id, short_name));
    } else if (op == "gwap") {
      UserId bot_user_id;
      get_args(args, bot_user_id);
      send_request(td_api::make_object<td_api::getWebAppPlaceholder>(bot_user_id));
    } else if (op == "gwalu") {
      ChatId chat_id;
      UserId bot_user_id;
      string short_name;
      string start_parameter;
      get_args(args, chat_id, bot_user_id, short_name, start_parameter);
      send_request(td_api::make_object<td_api::getWebAppLinkUrl>(chat_id, bot_user_id, short_name, start_parameter,
                                                                 true, as_web_app_open_parameters()));
    } else if (op == "gmwa") {
      ChatId chat_id;
      UserId bot_user_id;
      string start_parameter;
      get_args(args, chat_id, bot_user_id, start_parameter);
      send_request(td_api::make_object<td_api::getMainWebApp>(chat_id, bot_user_id, start_parameter,
                                                              as_web_app_open_parameters()));
    } else if (op == "gwau") {
      UserId bot_user_id;
      string url;
      get_args(args, bot_user_id, url);
      send_request(td_api::make_object<td_api::getWebAppUrl>(bot_user_id, url, as_web_app_open_parameters()));
    } else if (op == "swad") {
      UserId bot_user_id;
      string button_text;
      string data;
      get_args(args, bot_user_id, button_text, data);
      send_request(td_api::make_object<td_api::sendWebAppData>(bot_user_id, button_text, data));
    } else if (op == "owa") {
      ChatId chat_id;
      UserId bot_user_id;
      string url;
      get_args(args, chat_id, bot_user_id, url);
      send_request(td_api::make_object<td_api::openWebApp>(chat_id, bot_user_id, url, message_thread_id_,
                                                           get_input_message_reply_to(), as_web_app_open_parameters()));
    } else if (op == "cwa") {
      int64 launch_id;
      get_args(args, launch_id);
      send_request(td_api::make_object<td_api::closeWebApp>(launch_id));
    } else if (op == "cwafd") {
      UserId bot_user_id;
      string file_name;
      string url;
      get_args(args, bot_user_id, file_name, url);
      send_request(td_api::make_object<td_api::checkWebAppFileDownload>(bot_user_id, file_name, url));
    } else if (op == "sca") {
      ChatId chat_id;
      string action;
      get_args(args, chat_id, action);
      send_request(td_api::make_object<td_api::sendChatAction>(chat_id, message_thread_id_, business_connection_id_,
                                                               as_chat_action(action)));
    } else if (op == "smt" || op == "smtp" || op == "smtf" || op == "smtpf") {
      ChatId chat_id;
      get_args(args, chat_id);
      for (int i = 1; i <= 200; i++) {
        string message = PSTRING() << (Random::fast(0, 3) == 0 && i > 90 ? "sleep " : "") << "#" << i;
        if (i == 6 || (op.back() == 'f' && i % 2 == 0)) {
          message = string(4097, 'a');
        }
        if (op[3] == 'p') {
          send_message(chat_id, td_api::make_object<td_api::inputMessagePhoto>(
                                    as_local_file("rgb.jpg"), get_input_thumbnail(), get_added_sticker_file_ids(), 0, 0,
                                    as_caption(message), show_caption_above_media_, get_message_self_destruct_type(),
                                    has_spoiler_));
        } else {
          send_message(chat_id, td_api::make_object<td_api::inputMessageText>(as_formatted_text(message),
                                                                              get_link_preview_options(), true));
        }
      }
    } else if (op == "ssm") {
      ChatId chat_id;
      string filter;
      string offset;
      SearchQuery query;
      get_args(args, chat_id, filter, offset, query);
      send_request(td_api::make_object<td_api::searchSecretMessages>(chat_id, query.query, offset, query.limit,
                                                                     as_search_messages_filter(filter)));
    } else if (op == "ssd") {
      schedule_date_ = std::move(args);
    } else if (op == "smei") {
      message_effect_id_ = to_integer<int64>(args);
    } else if (op == "smpmsc") {
      paid_message_star_count_ = to_integer<int64>(args);
    } else if (op == "sop") {
      only_preview_ = as_bool(args);
    } else if (op == "smti") {
      get_args(args, message_thread_id_);
    } else if (op == "sbci") {
      business_connection_id_ = args;
    } else if (op == "shs") {
      has_spoiler_ = as_bool(args);
    } else if (op == "smsdt") {
      message_self_destruct_time_ = to_integer<int32>(args);
    } else if (op == "gcams") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatAvailableMessageSenders>(chat_id));
    } else if (op == "scmsr") {
      ChatId chat_id;
      string sender_id;
      get_args(args, chat_id, sender_id);
      send_request(td_api::make_object<td_api::setChatMessageSender>(chat_id, as_message_sender(sender_id)));
    } else if (op == "smr") {
      get_args(args, reply_message_id_, reply_chat_id_);
    } else if (op == "smrq") {
      reply_quote_ = args;
    } else if (op == "smrqp") {
      reply_quote_position_ = to_integer<int32>(args);
    } else if (op == "smrs") {
      get_args(args, reply_story_chat_id_, reply_story_id_);
    } else if (op == "slpo") {
      get_args(args, link_preview_is_disabled_, link_preview_url_, link_preview_force_small_media_,
               link_preview_force_large_media_, link_preview_show_above_text_);
    } else if (op == "sscam") {
      get_args(args, show_caption_above_media_);
    } else if (op == "ssmt") {
      saved_messages_topic_id_ = as_chat_id(args);
    } else if (op == "sqrs") {
      quick_reply_shortcut_name_ = args;
    } else if (op == "smas") {
      added_sticker_file_ids_ = as_file_ids(args);
    } else if (op == "smc") {
      caption_ = args;
    } else if (op == "smco") {
      cover_ = args;
    } else if (op == "smth") {
      thumbnail_ = args;
    } else if (op == "smst") {
      start_timestamp_ = to_integer<int32>(args);
    } else if (op == "sm" || op == "sms" || op == "smf") {
      ChatId chat_id;
      string message;
      get_args(args, chat_id, message);
      if (op == "smf") {
        message = string(5097, 'a');
      }
      send_message(
          chat_id,
          td_api::make_object<td_api::inputMessageText>(as_formatted_text(message), get_link_preview_options(), true),
          op == "sms", false);
    } else if (op == "smce") {
      ChatId chat_id;
      get_args(args, chat_id);
      vector<td_api::object_ptr<td_api::textEntity>> entities;
      entities.push_back(td_api::make_object<td_api::textEntity>(
          0, 2, td_api::make_object<td_api::textEntityTypeCustomEmoji>(5368324170671202286)));
      entities.push_back(td_api::make_object<td_api::textEntity>(
          3, 2, td_api::make_object<td_api::textEntityTypeCustomEmoji>(5377637695583426942)));
      entities.push_back(td_api::make_object<td_api::textEntity>(
          6, 5, td_api::make_object<td_api::textEntityTypeCustomEmoji>(5368324170671202286)));
      auto text = as_formatted_text("👍 😉 🧑‍🚒", std::move(entities));
      send_message(chat_id,
                   td_api::make_object<td_api::inputMessageText>(std::move(text), get_link_preview_options(), true));
    } else if (op == "alm") {
      ChatId chat_id;
      string sender_id;
      string message;
      get_args(args, chat_id, sender_id, message);
      send_request(td_api::make_object<td_api::addLocalMessage>(
          chat_id, as_message_sender(sender_id), get_input_message_reply_to(), false,
          td_api::make_object<td_api::inputMessageText>(as_formatted_text(message), get_link_preview_options(), true)));
    } else if (op == "spmp") {
      ChatId chat_id;
      get_args(args, chat_id, args);
      auto paid_media = transform(full_split(args), [&](const string &photo) {
        return td_api::make_object<td_api::inputPaidMedia>(td_api::make_object<td_api::inputPaidMediaTypePhoto>(),
                                                           as_input_file(photo), get_input_thumbnail(),
                                                           get_added_sticker_file_ids(), 0, 0);
      });
      send_message(chat_id, td_api::make_object<td_api::inputMessagePaidMedia>(11, std::move(paid_media), get_caption(),
                                                                               rand_bool(), "photo"));
    } else if (op == "spmv") {
      ChatId chat_id;
      get_args(args, chat_id, args);
      auto paid_media = transform(full_split(args), [&](const string &video) {
        return td_api::make_object<td_api::inputPaidMedia>(
            td_api::make_object<td_api::inputPaidMediaTypeVideo>(get_input_cover(), start_timestamp_, 10, true),
            as_input_file(video), get_input_thumbnail(), get_added_sticker_file_ids(), 0, 0);
      });
      send_message(chat_id, td_api::make_object<td_api::inputMessagePaidMedia>(12, std::move(paid_media), get_caption(),
                                                                               rand_bool(), "video"));
    } else if (op == "smap" || op == "smad" || op == "smav") {
      ChatId chat_id;
      get_args(args, chat_id, args);
      auto input_message_contents = transform(full_split(args), [&](const string &file) {
        td_api::object_ptr<td_api::InputMessageContent> content;
        if (op == "smap") {
          content = td_api::make_object<td_api::inputMessagePhoto>(
              as_input_file(file), get_input_thumbnail(), get_added_sticker_file_ids(), 0, 0, get_caption(),
              show_caption_above_media_, rand_bool() ? get_message_self_destruct_type() : nullptr,
              has_spoiler_ && rand_bool());
        } else if (op == "smad") {
          content = td_api::make_object<td_api::inputMessageDocument>(as_input_file(file), get_input_thumbnail(), true,
                                                                      get_caption());
        } else if (op == "smav") {
          content = td_api::make_object<td_api::inputMessageVideo>(
              as_input_file(file), get_input_thumbnail(), get_input_cover(), start_timestamp_,
              get_added_sticker_file_ids(), 1, 2, 3, true, get_caption(), show_caption_above_media_,
              get_message_self_destruct_type(), has_spoiler_);
        }
        return content;
      });
      if (!business_connection_id_.empty()) {
        send_request(td_api::make_object<td_api::sendBusinessMessageAlbum>(
            business_connection_id_, chat_id, get_input_message_reply_to(), rand_bool(), rand_bool(),
            message_effect_id_, std::move(input_message_contents)));
      } else if (!quick_reply_shortcut_name_.empty()) {
        send_request(td_api::make_object<td_api::addQuickReplyShortcutMessageAlbum>(
            quick_reply_shortcut_name_, reply_message_id_, std::move(input_message_contents)));
      } else {
        send_request(td_api::make_object<td_api::sendMessageAlbum>(
            chat_id, message_thread_id_, get_input_message_reply_to(), default_message_send_options(),
            std::move(input_message_contents)));
      }
    } else if (op == "savt") {
      int64 verification_id;
      string token;
      get_args(args, verification_id, token);
      send_request(td_api::make_object<td_api::setApplicationVerificationToken>(verification_id, token));
    } else if (op == "gmft") {
      auto r_message_file_head = read_file_str(args, 2 << 10);
      if (r_message_file_head.is_error()) {
        LOG(ERROR) << r_message_file_head.error();
      } else {
        auto message_file_head = r_message_file_head.move_as_ok();
        while (!check_utf8(message_file_head)) {
          message_file_head.pop_back();
        }
        send_request(td_api::make_object<td_api::getMessageFileType>(message_file_head));
      }
    } else if (op == "gmict") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getMessageImportConfirmationText>(chat_id));
    } else if (op == "im") {
      ChatId chat_id;
      string message_file;
      vector<string> attached_files;
      get_args(args, chat_id, message_file, args);
      attached_files = full_split(args);
      send_request(td_api::make_object<td_api::importMessages>(chat_id, as_input_file(message_file),
                                                               transform(attached_files, as_input_file)));
    } else if (op == "em") {
      ChatId chat_id;
      MessageId message_id;
      string message;
      get_args(args, chat_id, message_id, message);
      auto input_text =
          td_api::make_object<td_api::inputMessageText>(as_formatted_text(message), get_link_preview_options(), true);
      if (!business_connection_id_.empty()) {
        send_request(td_api::make_object<td_api::editBusinessMessageText>(business_connection_id_, chat_id, message_id,
                                                                          nullptr, std::move(input_text)));
      } else {
        send_request(td_api::make_object<td_api::editMessageText>(chat_id, message_id, nullptr, std::move(input_text)));
      }
    } else if (op == "eqrm") {
      ShortcutId shortcut_id;
      MessageId message_id;
      string message;
      get_args(args, shortcut_id, message_id, message);
      send_request(td_api::make_object<td_api::editQuickReplyMessage>(
          shortcut_id, message_id,
          td_api::make_object<td_api::inputMessageText>(as_formatted_text(message), get_link_preview_options(), true)));
    } else if (op == "eman") {
      ChatId chat_id;
      MessageId message_id;
      string animation;
      get_args(args, chat_id, message_id, animation);
      send_request(td_api::make_object<td_api::editMessageMedia>(
          chat_id, message_id, nullptr,
          td_api::make_object<td_api::inputMessageAnimation>(as_input_file(animation), get_input_thumbnail(),
                                                             get_added_sticker_file_ids(), 0, 0, 0, get_caption(),
                                                             show_caption_above_media_, has_spoiler_)));
    } else if (op == "emc") {
      ChatId chat_id;
      MessageId message_id;
      string caption;
      get_args(args, chat_id, message_id, caption);
      send_request(td_api::make_object<td_api::editMessageCaption>(
          chat_id, message_id, nullptr, as_caption(caption.empty() ? caption_ : caption), show_caption_above_media_));
    } else if (op == "emd") {
      ChatId chat_id;
      MessageId message_id;
      string document;
      get_args(args, chat_id, message_id, document);
      auto input_document = td_api::make_object<td_api::inputMessageDocument>(
          as_input_file(document), get_input_thumbnail(), false, get_caption());
      if (!business_connection_id_.empty()) {
        send_request(td_api::make_object<td_api::editBusinessMessageMedia>(business_connection_id_, chat_id, message_id,
                                                                           nullptr, std::move(input_document)));
      } else {
        send_request(
            td_api::make_object<td_api::editMessageMedia>(chat_id, message_id, nullptr, std::move(input_document)));
      }
    } else if (op == "eqrmd") {
      ShortcutId shortcut_id;
      MessageId message_id;
      string document;
      get_args(args, shortcut_id, message_id, document);
      send_request(td_api::make_object<td_api::editQuickReplyMessage>(
          shortcut_id, message_id,
          td_api::make_object<td_api::inputMessageDocument>(as_input_file(document), get_input_thumbnail(), false,
                                                            get_caption())));
    } else if (op == "emp") {
      ChatId chat_id;
      MessageId message_id;
      string photo;
      get_args(args, chat_id, message_id, photo);
      auto input_photo = td_api::make_object<td_api::inputMessagePhoto>(
          as_input_file(photo), get_input_thumbnail(), get_added_sticker_file_ids(), 0, 0, get_caption(),
          show_caption_above_media_, get_message_self_destruct_type(), has_spoiler_);
      if (!business_connection_id_.empty()) {
        send_request(td_api::make_object<td_api::editBusinessMessageMedia>(business_connection_id_, chat_id, message_id,
                                                                           nullptr, std::move(input_photo)));
      } else {
        send_request(
            td_api::make_object<td_api::editMessageMedia>(chat_id, message_id, nullptr, std::move(input_photo)));
      }
    } else if (op == "eqrmp") {
      ShortcutId shortcut_id;
      MessageId message_id;
      string photo;
      get_args(args, shortcut_id, message_id, photo);
      send_request(td_api::make_object<td_api::editQuickReplyMessage>(
          shortcut_id, message_id,
          td_api::make_object<td_api::inputMessagePhoto>(as_input_file(photo), get_input_thumbnail(),
                                                         get_added_sticker_file_ids(), 0, 0, get_caption(),
                                                         show_caption_above_media_, nullptr, has_spoiler_)));
    } else if (op == "eqrmv") {
      ShortcutId shortcut_id;
      MessageId message_id;
      string video;
      get_args(args, shortcut_id, message_id, video);
      send_request(td_api::make_object<td_api::editQuickReplyMessage>(
          shortcut_id, message_id,
          td_api::make_object<td_api::inputMessageVideo>(as_input_file(video), get_input_thumbnail(), get_input_cover(),
                                                         start_timestamp_, get_added_sticker_file_ids(), 1, 2, 3, true,
                                                         get_caption(), show_caption_above_media_,
                                                         get_message_self_destruct_type(), has_spoiler_)));
    } else if (op == "emv") {
      ChatId chat_id;
      MessageId message_id;
      string video;
      get_args(args, chat_id, message_id, video);
      auto input_video = td_api::make_object<td_api::inputMessageVideo>(
          as_input_file(video), get_input_thumbnail(), get_input_cover(), start_timestamp_,
          get_added_sticker_file_ids(), 1, 2, 3, true, get_caption(), show_caption_above_media_,
          get_message_self_destruct_type(), has_spoiler_);
      if (!business_connection_id_.empty()) {
        send_request(td_api::make_object<td_api::editBusinessMessageMedia>(business_connection_id_, chat_id, message_id,
                                                                           nullptr, std::move(input_video)));
      } else {
        send_request(
            td_api::make_object<td_api::editMessageMedia>(chat_id, message_id, nullptr, std::move(input_video)));
      }
    } else if (op == "emll") {
      ChatId chat_id;
      MessageId message_id;
      string latitude;
      string longitude;
      int32 live_period;
      string accuracy;
      int32 heading;
      int32 proximity_alert_radius;
      get_args(args, chat_id, message_id, latitude, longitude, live_period, accuracy, heading, proximity_alert_radius);
      send_request(td_api::make_object<td_api::editMessageLiveLocation>(chat_id, message_id, nullptr,
                                                                        as_location(latitude, longitude, accuracy),
                                                                        live_period, heading, proximity_alert_radius));
    } else if (op == "emss") {
      ChatId chat_id;
      MessageId message_id;
      string date;
      get_args(args, chat_id, message_id, date);
      send_request(td_api::make_object<td_api::editMessageSchedulingState>(chat_id, message_id,
                                                                           as_message_scheduling_state(date)));
    } else if (op == "smfc") {
      ChatId chat_id;
      MessageId message_id;
      string message;
      get_args(args, chat_id, message_id, message);
      send_request(td_api::make_object<td_api::setMessageFactCheck>(chat_id, message_id, as_formatted_text(message)));
    } else {
      op_not_found_count++;
    }

    if (op == "cqrsn") {
      execute(td_api::make_object<td_api::checkQuickReplyShortcutName>(args));
    } else if (op == "lqrs") {
      send_request(td_api::make_object<td_api::loadQuickReplyShortcuts>());
    } else if (op == "dqrs") {
      ShortcutId shortcut_id;
      get_args(args, shortcut_id);
      send_request(td_api::make_object<td_api::deleteQuickReplyShortcut>(shortcut_id));
    } else if (op == "sqrsn") {
      ShortcutId shortcut_id;
      string name;
      get_args(args, shortcut_id, name);
      send_request(td_api::make_object<td_api::setQuickReplyShortcutName>(shortcut_id, name));
    } else if (op == "rqrs") {
      string shortcut_ids;
      get_args(args, shortcut_ids);
      send_request(td_api::make_object<td_api::reorderQuickReplyShortcuts>(as_shortcut_ids(shortcut_ids)));
    } else if (op == "lqrsm") {
      ShortcutId shortcut_id;
      get_args(args, shortcut_id);
      send_request(td_api::make_object<td_api::loadQuickReplyShortcutMessages>(shortcut_id));
    } else if (op == "dqrsm") {
      ShortcutId shortcut_id;
      string message_ids;
      get_args(args, shortcut_id, message_ids);
      send_request(
          td_api::make_object<td_api::deleteQuickReplyShortcutMessages>(shortcut_id, as_message_ids(message_ids)));
    } else if (op == "gftdi") {
      send_request(td_api::make_object<td_api::getForumTopicDefaultIcons>());
    } else if (op == "cft") {
      ChatId chat_id;
      string name;
      int32 icon_color;
      get_args(args, chat_id, name, icon_color);
      send_request(td_api::make_object<td_api::createForumTopic>(
          chat_id, name, td_api::make_object<td_api::forumTopicIcon>(icon_color, 0)));
    } else if (op == "eft") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      string name;
      bool edit_icon_custom_emoji;
      CustomEmojiId icon_custom_emoji_id;
      get_args(args, chat_id, message_thread_id, name, edit_icon_custom_emoji, icon_custom_emoji_id);
      send_request(td_api::make_object<td_api::editForumTopic>(chat_id, message_thread_id, name, edit_icon_custom_emoji,
                                                               icon_custom_emoji_id));
    } else if (op == "gft") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      get_args(args, chat_id, message_thread_id);
      send_request(td_api::make_object<td_api::getForumTopic>(chat_id, message_thread_id));
    } else if (op == "gftl") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      get_args(args, chat_id, message_thread_id);
      send_request(td_api::make_object<td_api::getForumTopicLink>(chat_id, message_thread_id));
    } else if (op == "gfts") {
      ChatId chat_id;
      string query;
      int32 offset_date;
      MessageId offset_message_id;
      MessageThreadId offset_message_thread_id;
      string limit;
      get_args(args, chat_id, query, offset_date, offset_message_id, offset_message_thread_id, limit);
      send_request(td_api::make_object<td_api::getForumTopics>(chat_id, query, offset_date, offset_message_id,
                                                               offset_message_thread_id, as_limit(limit)));
    } else if (op == "tftic") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      bool is_closed;
      get_args(args, chat_id, message_thread_id, is_closed);
      send_request(td_api::make_object<td_api::toggleForumTopicIsClosed>(chat_id, message_thread_id, is_closed));
    } else if (op == "tgftih") {
      ChatId chat_id;
      bool is_hidden;
      get_args(args, chat_id, is_hidden);
      send_request(td_api::make_object<td_api::toggleGeneralForumTopicIsHidden>(chat_id, is_hidden));
    } else if (op == "tftip") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      bool is_pinned;
      get_args(args, chat_id, message_thread_id, is_pinned);
      send_request(td_api::make_object<td_api::toggleForumTopicIsPinned>(chat_id, message_thread_id, is_pinned));
    } else if (op == "spft") {
      ChatId chat_id;
      string message_thread_ids;
      get_args(args, chat_id, message_thread_ids);
      send_request(
          td_api::make_object<td_api::setPinnedForumTopics>(chat_id, as_message_thread_ids(message_thread_ids)));
    } else if (op == "dft") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      get_args(args, chat_id, message_thread_id);
      send_request(td_api::make_object<td_api::deleteForumTopic>(chat_id, message_thread_id));
    } else if (op == "sbsm") {
      UserId bot_user_id;
      ChatId chat_id;
      string parameter;
      get_args(args, bot_user_id, chat_id, parameter);
      send_request(td_api::make_object<td_api::sendBotStartMessage>(bot_user_id, chat_id, parameter));
    } else if (op == "giqr") {
      string bot_id;
      string query;
      get_args(args, bot_id, query);
      send_request(td_api::make_object<td_api::getInlineQueryResults>(as_user_id(bot_id), as_chat_id(bot_id), nullptr,
                                                                      query, ""));
    } else if (op == "giqro") {
      UserId bot_user_id;
      string offset;
      string query;
      get_args(args, bot_user_id, offset, query);
      send_request(td_api::make_object<td_api::getInlineQueryResults>(bot_user_id, 0, nullptr, query, offset));
    } else if (op == "giqrl") {
      UserId bot_user_id;
      string query;
      get_args(args, bot_user_id, query);
      send_request(
          td_api::make_object<td_api::getInlineQueryResults>(bot_user_id, 0, as_location("1.1", "2.2", ""), query, ""));
    } else if (op == "gpim") {
      UserId bot_user_id;
      string prepared_message_id;
      get_args(args, bot_user_id, prepared_message_id);
      send_request(td_api::make_object<td_api::getPreparedInlineMessage>(bot_user_id, prepared_message_id));
    } else if (op == "siqr" || op == "siqrh") {
      ChatId chat_id;
      int64 query_id;
      string result_id;
      get_args(args, chat_id, query_id, result_id);
      if (quick_reply_shortcut_name_.empty()) {
        send_request(td_api::make_object<td_api::sendInlineQueryResultMessage>(
            chat_id, message_thread_id_, nullptr, default_message_send_options(), query_id, result_id, op == "siqrh"));
      } else {
        send_request(td_api::make_object<td_api::addQuickReplyShortcutInlineQueryResultMessage>(
            quick_reply_shortcut_name_, reply_message_id_, query_id, result_id, op == "siqrh"));
      }
    } else if (op == "gcqa") {
      ChatId chat_id;
      MessageId message_id;
      string data;
      get_args(args, chat_id, message_id, data);
      send_request(td_api::make_object<td_api::getCallbackQueryAnswer>(
          chat_id, message_id, td_api::make_object<td_api::callbackQueryPayloadData>(data)));
    } else if (op == "gcpqa") {
      ChatId chat_id;
      MessageId message_id;
      string password;
      string data;
      get_args(args, chat_id, message_id, password, data);
      send_request(td_api::make_object<td_api::getCallbackQueryAnswer>(
          chat_id, message_id, td_api::make_object<td_api::callbackQueryPayloadDataWithPassword>(password, data)));
    } else if (op == "gcgqa") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::getCallbackQueryAnswer>(
          chat_id, message_id, td_api::make_object<td_api::callbackQueryPayloadGame>("")));
    } else if (op == "acq" || op == "acqa") {
      int64 callback_query_id;
      string text;
      get_args(args, callback_query_id, text);
      send_request(
          td_api::make_object<td_api::answerCallbackQuery>(callback_query_id, text, op == "acqa", string(), 0));
    } else {
      op_not_found_count++;
    }

    if (op == "san") {
      ChatId chat_id;
      string animation;
      int32 width;
      int32 height;
      get_args(args, chat_id, animation, width, height);
      send_message(chat_id, td_api::make_object<td_api::inputMessageAnimation>(
                                as_input_file(animation), get_input_thumbnail(), get_added_sticker_file_ids(), 60,
                                width, height, get_caption(), show_caption_above_media_, has_spoiler_));
    } else if (op == "sanurl") {
      ChatId chat_id;
      string url;
      get_args(args, chat_id, url);
      send_message(chat_id, td_api::make_object<td_api::inputMessageAnimation>(
                                as_generated_file(url, "#url#"), get_input_thumbnail(), get_added_sticker_file_ids(), 0,
                                0, 0, get_caption(), show_caption_above_media_, has_spoiler_));
    } else if (op == "sau") {
      ChatId chat_id;
      string audio;
      int32 duration;
      string title;
      string performer;
      get_args(args, chat_id, audio, duration, title, performer);
      send_message(chat_id, td_api::make_object<td_api::inputMessageAudio>(as_input_file(audio), get_input_thumbnail(),
                                                                           duration, title, performer, get_caption()));
    } else if (op == "svoice") {
      ChatId chat_id;
      string voice;
      get_args(args, chat_id, voice);
      send_message(chat_id, td_api::make_object<td_api::inputMessageVoiceNote>(
                                as_input_file(voice), 0, "abacaba", get_caption(), get_message_self_destruct_type()));
    } else if (op == "scontact") {
      ChatId chat_id;
      string phone_number;
      string first_name;
      string last_name;
      UserId user_id;
      get_args(args, chat_id, phone_number, first_name, last_name, user_id);
      send_message(chat_id, td_api::make_object<td_api::inputMessageContact>(td_api::make_object<td_api::contact>(
                                phone_number, first_name, last_name, string(), user_id)));
    } else if (op == "sf" || op == "scopy") {
      ChatId chat_id;
      ChatId from_chat_id;
      MessageId from_message_id;
      bool replace_video_start_timestamp;
      get_args(args, chat_id, from_chat_id, from_message_id, replace_video_start_timestamp);
      td_api::object_ptr<td_api::messageCopyOptions> copy_options;
      if (op == "scopy") {
        copy_options = td_api::make_object<td_api::messageCopyOptions>(true, rand_bool(), get_caption(),
                                                                       show_caption_above_media_);
      }
      send_message(chat_id, td_api::make_object<td_api::inputMessageForwarded>(
                                from_chat_id, from_message_id, true, replace_video_start_timestamp, start_timestamp_,
                                std::move(copy_options)));
    } else if (op == "sdice" || op == "sdicecd") {
      ChatId chat_id;
      string emoji;
      get_args(args, chat_id, emoji);
      send_message(chat_id, td_api::make_object<td_api::inputMessageDice>(emoji, op == "sdicecd"));
    } else if (op == "sd" || op == "sdf") {
      ChatId chat_id;
      string document;
      get_args(args, chat_id, document);
      send_message(chat_id, td_api::make_object<td_api::inputMessageDocument>(
                                as_input_file(document), get_input_thumbnail(), op == "sdf", get_caption()));
    } else if (op == "sdgu") {
      ChatId chat_id;
      string document_path;
      string document_conversion;
      get_args(args, chat_id, document_path, document_conversion);
      send_request(td_api::make_object<td_api::preliminaryUploadFile>(
          as_generated_file(document_path, document_conversion), nullptr, 1));
      send_message(chat_id, td_api::make_object<td_api::inputMessageDocument>(
                                as_generated_file(document_path, document_conversion), nullptr, false, get_caption()));
    } else if (op == "sg") {
      ChatId chat_id;
      UserId bot_user_id;
      string game_short_name;
      get_args(args, chat_id, bot_user_id, game_short_name);
      send_message(chat_id, td_api::make_object<td_api::inputMessageGame>(bot_user_id, game_short_name));
    } else if (op == "sl") {
      ChatId chat_id;
      string latitude;
      string longitude;
      string accuracy;
      get_args(args, chat_id, latitude, longitude, accuracy);
      send_message(chat_id, td_api::make_object<td_api::inputMessageLocation>(
                                as_location(latitude, longitude, accuracy), 0, 0, 0));
    } else if (op == "sll") {
      ChatId chat_id;
      int32 period;
      string latitude;
      string longitude;
      string accuracy;
      int32 heading;
      int32 proximity_alert_radius;
      get_args(args, chat_id, period, latitude, longitude, accuracy, heading, proximity_alert_radius);
      send_message(chat_id, td_api::make_object<td_api::inputMessageLocation>(
                                as_location(latitude, longitude, accuracy), period, heading, proximity_alert_radius));
    } else if (op == "spoll" || op == "spollm" || op == "spollp" || op == "squiz") {
      ChatId chat_id;
      string question;
      get_args(args, chat_id, question, args);
      auto options = transform(autosplit_str(args), [](const string &option) { return as_formatted_text(option); });
      td_api::object_ptr<td_api::PollType> poll_type;
      if (op == "squiz") {
        poll_type = td_api::make_object<td_api::pollTypeQuiz>(narrow_cast<int32>(options.size() - 1),
                                                              as_formatted_text("_te*st*_"));
      } else {
        poll_type = td_api::make_object<td_api::pollTypeRegular>(op == "spollm");
      }
      send_message(chat_id,
                   td_api::make_object<td_api::inputMessagePoll>(as_formatted_text(question), std::move(options),
                                                                 op != "spollp", std::move(poll_type), 0, 0, false));
    } else if (op == "sp") {
      ChatId chat_id;
      string photo;
      get_args(args, chat_id, photo);
      send_message(chat_id,
                   td_api::make_object<td_api::inputMessagePhoto>(
                       as_input_file(photo), get_input_thumbnail(), get_added_sticker_file_ids(), 0, 0, get_caption(),
                       show_caption_above_media_, get_message_self_destruct_type(), has_spoiler_));
    } else if (op == "ss") {
      ChatId chat_id;
      string sticker;
      string emoji;
      get_args(args, chat_id, sticker, emoji);
      send_message(chat_id, td_api::make_object<td_api::inputMessageSticker>(as_input_file(sticker),
                                                                             get_input_thumbnail(), 0, 0, emoji));
    } else if (op == "sstory") {
      ChatId chat_id;
      ChatId story_sender_chat_id;
      StoryId story_id;
      get_args(args, chat_id, story_sender_chat_id, story_id);
      send_message(chat_id, td_api::make_object<td_api::inputMessageStory>(story_sender_chat_id, story_id));
    } else if (op == "sv") {
      ChatId chat_id;
      string video;
      get_args(args, chat_id, video);
      send_message(chat_id, td_api::make_object<td_api::inputMessageVideo>(
                                as_input_file(video), get_input_thumbnail(), get_input_cover(), start_timestamp_,
                                get_added_sticker_file_ids(), 1, 2, 3, true, get_caption(), show_caption_above_media_,
                                get_message_self_destruct_type(), has_spoiler_));
    } else if (op == "svn") {
      ChatId chat_id;
      string video_note;
      get_args(args, chat_id, video_note);
      send_message(chat_id,
                   td_api::make_object<td_api::inputMessageVideoNote>(as_input_file(video_note), get_input_thumbnail(),
                                                                      10, 5, get_message_self_destruct_type()));
    } else if (op == "svenue") {
      ChatId chat_id;
      string latitude;
      string longitude;
      string accuracy;
      string title;
      string address;
      string provider;
      string venue_id;
      string venue_type;
      get_args(args, chat_id, latitude, longitude, accuracy, title, address, provider, venue_id, venue_type);
      send_message(chat_id,
                   td_api::make_object<td_api::inputMessageVenue>(td_api::make_object<td_api::venue>(
                       as_location(latitude, longitude, accuracy), title, address, provider, venue_id, venue_type)));
    } else {
      op_not_found_count++;
    }

    if (op == "test") {
      send_request(td_api::make_object<td_api::testNetwork>());
    } else if (op == "alarm") {
      send_request(td_api::make_object<td_api::setAlarm>(to_double(args)));
    } else if (op == "delete") {
      ChatId chat_id;
      bool remove_from_the_chat_list;
      bool revoke;
      get_args(args, chat_id, remove_from_the_chat_list, revoke);
      send_request(td_api::make_object<td_api::deleteChatHistory>(chat_id, remove_from_the_chat_list, revoke));
    } else if (op == "dcmbd") {
      ChatId chat_id;
      int32 min_date;
      int32 max_date;
      bool revoke;
      get_args(args, chat_id, min_date, max_date, revoke);
      send_request(td_api::make_object<td_api::deleteChatMessagesByDate>(chat_id, min_date, max_date, revoke));
    } else if (op == "dcmbs") {
      ChatId chat_id;
      string sender_id;
      get_args(args, chat_id, sender_id);
      send_request(td_api::make_object<td_api::deleteChatMessagesBySender>(chat_id, as_message_sender(sender_id)));
    } else if (op == "cnbgc") {
      string user_ids_string;
      string title;
      int32 message_auto_delete_time;
      get_args(args, user_ids_string, title, message_auto_delete_time);
      send_request(td_api::make_object<td_api::createNewBasicGroupChat>(as_user_ids(user_ids_string), title,
                                                                        message_auto_delete_time));
    } else if (op == "cnchc" || op == "cnchcadt") {
      send_request(td_api::make_object<td_api::createNewSupergroupChat>(args, false, true, "Description", nullptr,
                                                                        op == "cnchcadt" ? 86400 : 0, false));
    } else if (op == "cnsgc" || op == "cnsgcadt") {
      send_request(td_api::make_object<td_api::createNewSupergroupChat>(args, false, false, "Description", nullptr,
                                                                        op == "cnsgcadt" ? 86400 : 0, false));
    } else if (op == "cnfc" || op == "cnfcadt") {
      send_request(td_api::make_object<td_api::createNewSupergroupChat>(args, true, true, "Description", nullptr,
                                                                        op == "cnfcadt" ? 86400 : 0, false));
    } else if (op == "cnsgcloc") {
      send_request(td_api::make_object<td_api::createNewSupergroupChat>(
          args, false, false, "Description",
          td_api::make_object<td_api::chatLocation>(as_location("40.0", "60.0", ""), "address"), 0, false));
    } else if (op == "cnsgcimport") {
      send_request(
          td_api::make_object<td_api::createNewSupergroupChat>(args, false, false, "Description", nullptr, 0, true));
    } else if (op == "ubgctsc") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::upgradeBasicGroupChatToSupergroupChat>(chat_id));
    } else if (op == "DeleteChat") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::deleteChat>(chat_id));
    } else if (op == "grc") {
      send_request(td_api::make_object<td_api::getRecommendedChats>());
    } else if (op == "gcsc") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatSimilarChats>(chat_id));
    } else if (op == "gcscc") {
      ChatId chat_id;
      bool return_local;
      get_args(args, chat_id, return_local);
      send_request(td_api::make_object<td_api::getChatSimilarChatCount>(chat_id, return_local));
    } else if (op == "ocsc") {
      ChatId chat_id;
      ChatId similar_chat_id;
      get_args(args, chat_id, similar_chat_id);
      send_request(td_api::make_object<td_api::openChatSimilarChat>(chat_id, similar_chat_id));
    } else if (op == "gbsb") {
      UserId bot_user_id;
      get_args(args, bot_user_id);
      send_request(td_api::make_object<td_api::getBotSimilarBots>(bot_user_id));
    } else if (op == "gbsbc") {
      UserId bot_user_id;
      bool return_local;
      get_args(args, bot_user_id, return_local);
      send_request(td_api::make_object<td_api::getBotSimilarBotCount>(bot_user_id, return_local));
    } else if (op == "obsb") {
      UserId bot_user_id;
      UserId similar_bot_user_id;
      get_args(args, bot_user_id, similar_bot_user_id);
      send_request(td_api::make_object<td_api::openBotSimilarBot>(bot_user_id, similar_bot_user_id));
    } else if (op == "gcpc") {
      send_request(td_api::make_object<td_api::getCreatedPublicChats>());
    } else if (op == "gcpcl") {
      send_request(td_api::make_object<td_api::getCreatedPublicChats>(
          td_api::make_object<td_api::publicChatTypeIsLocationBased>()));
    } else if (op == "ccpcl") {
      send_request(td_api::make_object<td_api::checkCreatedPublicChatsLimit>());
    } else if (op == "ccpcll") {
      send_request(td_api::make_object<td_api::checkCreatedPublicChatsLimit>(
          td_api::make_object<td_api::publicChatTypeIsLocationBased>()));
    } else if (op == "gsdc") {
      send_request(td_api::make_object<td_api::getSuitableDiscussionChats>());
    } else if (op == "gisc") {
      send_request(td_api::make_object<td_api::getInactiveSupergroupChats>());
    } else if (op == "gspc") {
      send_request(td_api::make_object<td_api::getSuitablePersonalChats>());
    } else if (op == "cpc") {
      UserId user_id;
      bool force;
      get_args(args, user_id, force);
      send_request(td_api::make_object<td_api::createPrivateChat>(user_id, force));
    } else if (op == "cbgc") {
      string basic_group_id;
      bool force;
      get_args(args, basic_group_id, force);
      send_request(td_api::make_object<td_api::createBasicGroupChat>(as_basic_group_id(basic_group_id), force));
    } else if (op == "csgc" || op == "cchc") {
      string supergroup_id;
      bool force;
      get_args(args, supergroup_id, force);
      send_request(td_api::make_object<td_api::createSupergroupChat>(as_supergroup_id(supergroup_id), force));
    } else {
      op_not_found_count++;
    }

    if (op == "gcltac") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::getChatListsToAddChat>(chat_id));
    } else if (op == "actl" || op == "actla" || begins_with(op, "actl-")) {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::addChatToList>(chat_id, as_chat_list(op)));
    } else if (op == "gcf") {
      ChatFolderId chat_folder_id;
      get_args(args, chat_folder_id);
      send_request(td_api::make_object<td_api::getChatFolder>(chat_folder_id));
    } else if (op == "ccf") {
      send_request(td_api::make_object<td_api::createChatFolder>(as_chat_folder(args)));
    } else if (op == "ccfe") {
      auto chat_folder = td_api::make_object<td_api::chatFolder>();
      chat_folder->name_ = td_api::make_object<td_api::chatFolderName>(
          td_api::make_object<td_api::formattedText>("empty", Auto()), true);
      chat_folder->included_chat_ids_ = as_chat_ids(args);
      send_request(td_api::make_object<td_api::createChatFolder>(std::move(chat_folder)));
    } else if (op == "ecf" || op == "ecfs") {
      ChatFolderId chat_folder_id;
      string filter;
      get_args(args, chat_folder_id, filter);
      send_request(td_api::make_object<td_api::editChatFolder>(chat_folder_id, as_chat_folder(filter, op == "ecfs")));
    } else if (op == "dcf") {
      ChatFolderId chat_folder_id;
      string chat_ids;
      get_args(args, chat_folder_id, chat_ids);
      send_request(td_api::make_object<td_api::deleteChatFolder>(chat_folder_id, as_chat_ids(chat_ids)));
    } else if (op == "gcfctl") {
      ChatFolderId chat_folder_id;
      get_args(args, chat_folder_id);
      send_request(td_api::make_object<td_api::getChatFolderChatsToLeave>(chat_folder_id));
    } else if (op == "gcfcc") {
      send_request(td_api::make_object<td_api::getChatFolderChatCount>(as_chat_folder(args)));
    } else if (op == "rcf") {
      int32 main_chat_list_position;
      string chat_folder_ids;
      get_args(args, main_chat_list_position, chat_folder_ids);
      send_request(td_api::make_object<td_api::reorderChatFolders>(as_chat_folder_ids(chat_folder_ids),
                                                                   main_chat_list_position));
    } else if (op == "tcft") {
      bool are_tags_enabled;
      get_args(args, are_tags_enabled);
      send_request(td_api::make_object<td_api::toggleChatFolderTags>(are_tags_enabled));
    } else if (op == "gcfcfil") {
      ChatFolderId chat_folder_id;
      get_args(args, chat_folder_id);
      send_request(td_api::make_object<td_api::getChatsForChatFolderInviteLink>(chat_folder_id));
    } else if (op == "crcfil") {
      ChatFolderId chat_folder_id;
      string name;
      string chat_ids;
      get_args(args, chat_folder_id, name, chat_ids);
      send_request(
          td_api::make_object<td_api::createChatFolderInviteLink>(chat_folder_id, name, as_chat_ids(chat_ids)));
    } else if (op == "gcfil") {
      ChatFolderId chat_folder_id;
      get_args(args, chat_folder_id);
      send_request(td_api::make_object<td_api::getChatFolderInviteLinks>(chat_folder_id));
    } else if (op == "ecfil") {
      ChatFolderId chat_folder_id;
      string invite_link;
      string name;
      string chat_ids;
      get_args(args, chat_folder_id, invite_link, name, chat_ids);
      send_request(td_api::make_object<td_api::editChatFolderInviteLink>(chat_folder_id, invite_link, name,
                                                                         as_chat_ids(chat_ids)));
    } else if (op == "dcfil") {
      ChatFolderId chat_folder_id;
      string invite_link;
      get_args(args, chat_folder_id, invite_link);
      send_request(td_api::make_object<td_api::deleteChatFolderInviteLink>(chat_folder_id, invite_link));
    } else if (op == "ccfil") {
      send_request(td_api::make_object<td_api::checkChatFolderInviteLink>(args));
    } else if (op == "acfbil") {
      string invite_link;
      string chat_ids;
      get_args(args, invite_link, chat_ids);
      send_request(td_api::make_object<td_api::addChatFolderByInviteLink>(invite_link, as_chat_ids(chat_ids)));
    } else if (op == "gcfnc") {
      ChatFolderId chat_folder_id;
      get_args(args, chat_folder_id);
      send_request(td_api::make_object<td_api::getChatFolderNewChats>(chat_folder_id));
    } else if (op == "pcfnc") {
      ChatFolderId chat_folder_id;
      string chat_ids;
      get_args(args, chat_folder_id, chat_ids);
      send_request(td_api::make_object<td_api::processChatFolderNewChats>(chat_folder_id, as_chat_ids(chat_ids)));
    } else if (op == "grcf") {
      send_request(td_api::make_object<td_api::getRecommendedChatFolders>());
    } else if (op == "gcfdin") {
      execute(td_api::make_object<td_api::getChatFolderDefaultIconName>(as_chat_folder(args)));
    } else if (op == "gacls") {
      send_request(td_api::make_object<td_api::getArchiveChatListSettings>());
    } else if (op == "sacls") {
      bool archive_and_mute_new_chats_from_unknown_users;
      bool keep_unmuted_chats_archived;
      bool keep_chats_from_folders_archived;
      get_args(args, archive_and_mute_new_chats_from_unknown_users, keep_unmuted_chats_archived,
               keep_chats_from_folders_archived);
      auto settings = td_api::make_object<td_api::archiveChatListSettings>(
          archive_and_mute_new_chats_from_unknown_users, keep_unmuted_chats_archived, keep_chats_from_folders_archived);
      send_request(td_api::make_object<td_api::setArchiveChatListSettings>(std::move(settings)));
    } else if (op == "grdps") {
      send_request(td_api::make_object<td_api::getReadDatePrivacySettings>());
    } else if (op == "srdps") {
      bool show_read_date;
      get_args(args, show_read_date);
      auto settings = td_api::make_object<td_api::readDatePrivacySettings>(show_read_date);
      send_request(td_api::make_object<td_api::setReadDatePrivacySettings>(std::move(settings)));
    } else if (op == "gncps") {
      send_request(td_api::make_object<td_api::getNewChatPrivacySettings>());
    } else if (op == "sncps") {
      bool allow_new_chats_from_unknown_users;
      int64 paid_message_star_count;
      get_args(args, allow_new_chats_from_unknown_users, paid_message_star_count);
      auto settings = td_api::make_object<td_api::newChatPrivacySettings>(allow_new_chats_from_unknown_users,
                                                                          paid_message_star_count);
      send_request(td_api::make_object<td_api::setNewChatPrivacySettings>(std::move(settings)));
    } else if (op == "gpmr") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::getPaidMessageRevenue>(user_id));
    } else if (op == "aumfu") {
      UserId user_id;
      bool refund_payments;
      get_args(args, user_id, refund_payments);
      send_request(td_api::make_object<td_api::allowUnpaidMessagesFromUser>(user_id, refund_payments));
    } else if (op == "scpmsc") {
      ChatId chat_id;
      int64 paid_message_star_count;
      get_args(args, chat_id, paid_message_star_count);
      send_request(td_api::make_object<td_api::setChatPaidMessageStarCount>(chat_id, paid_message_star_count));
    } else if (op == "csmtu" || op == "csmtul") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::canSendMessageToUser>(user_id, op == "csmtul"));
    } else if (op == "sct") {
      ChatId chat_id;
      string title;
      get_args(args, chat_id, title);
      send_request(td_api::make_object<td_api::setChatTitle>(chat_id, title));
    } else if (op == "scp") {
      ChatId chat_id;
      InputChatPhoto input_chat_photo;
      get_args(args, chat_id, input_chat_photo);
      send_request(td_api::make_object<td_api::setChatPhoto>(chat_id, input_chat_photo));
    } else if (op == "scac") {
      ChatId chat_id;
      int32 accent_color_id;
      CustomEmojiId background_custom_emoji_id;
      get_args(args, chat_id, accent_color_id, background_custom_emoji_id);
      send_request(
          td_api::make_object<td_api::setChatAccentColor>(chat_id, accent_color_id, background_custom_emoji_id));
    } else if (op == "scpac") {
      ChatId chat_id;
      int32 profile_accent_color_id;
      CustomEmojiId profile_background_custom_emoji_id;
      get_args(args, chat_id, profile_accent_color_id, profile_background_custom_emoji_id);
      send_request(td_api::make_object<td_api::setChatProfileAccentColor>(chat_id, profile_accent_color_id,
                                                                          profile_background_custom_emoji_id));
    } else if (op == "scmt") {
      ChatId chat_id;
      int32 auto_delete_time;
      get_args(args, chat_id, auto_delete_time);
      send_request(td_api::make_object<td_api::setChatMessageAutoDeleteTime>(chat_id, auto_delete_time));
    } else if (op == "sces") {
      ChatId chat_id;
      CustomEmojiId custom_emoji_id;
      int32 expiration_date;
      get_args(args, chat_id, custom_emoji_id, expiration_date);
      send_request(td_api::make_object<td_api::setChatEmojiStatus>(
          chat_id, td_api::make_object<td_api::emojiStatus>(
                       td_api::make_object<td_api::emojiStatusTypeCustomEmoji>(custom_emoji_id), expiration_date)));
    } else if (op == "scese") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::setChatEmojiStatus>(chat_id, nullptr));
    } else if (op == "scperm") {
      ChatId chat_id;
      string permissions;
      get_args(args, chat_id, permissions);
      constexpr size_t EXPECTED_SIZE = 14;
      if (permissions.size() == EXPECTED_SIZE) {
        auto &s = permissions;
        send_request(td_api::make_object<td_api::setChatPermissions>(
            chat_id, td_api::make_object<td_api::chatPermissions>(s[0] == '1', s[1] == '1', s[2] == '1', s[3] == '1',
                                                                  s[4] == '1', s[5] == '1', s[6] == '1', s[7] == '1',
                                                                  s[8] == '1', s[9] == '1', s[10] == '1', s[11] == '1',
                                                                  s[12] == '1', s[13] == '1')));
      } else {
        LOG(ERROR) << "Wrong permissions size, expected " << EXPECTED_SIZE;
      }
    } else if (op == "sctn") {
      ChatId chat_id;
      string theme_name;
      get_args(args, chat_id, theme_name);
      send_request(td_api::make_object<td_api::setChatTheme>(chat_id, theme_name));
    } else if (op == "sccd") {
      ChatId chat_id;
      string client_data;
      get_args(args, chat_id, client_data);
      send_request(td_api::make_object<td_api::setChatClientData>(chat_id, client_data));
    } else if (op == "acm") {
      ChatId chat_id;
      UserId user_id;
      int32 forward_limit;
      get_args(args, chat_id, user_id, forward_limit);
      send_request(td_api::make_object<td_api::addChatMember>(chat_id, user_id, forward_limit));
    } else if (op == "acms") {
      ChatId chat_id;
      string user_ids;
      get_args(args, chat_id, user_ids);
      send_request(td_api::make_object<td_api::addChatMembers>(chat_id, as_user_ids(user_ids)));
    } else if (op == "bcm") {
      ChatId chat_id;
      string member_id;
      int32 banned_until_date;
      bool revoke_messages;
      get_args(args, chat_id, member_id, banned_until_date, revoke_messages);
      send_request(td_api::make_object<td_api::banChatMember>(chat_id, as_message_sender(member_id), banned_until_date,
                                                              revoke_messages));
    } else if (op == "spolla") {
      ChatId chat_id;
      MessageId message_id;
      string option_ids;
      get_args(args, chat_id, message_id, option_ids);
      send_request(td_api::make_object<td_api::setPollAnswer>(chat_id, message_id, to_integers<int32>(option_ids)));
    } else if (op == "gpollv") {
      ChatId chat_id;
      MessageId message_id;
      int32 option_id;
      int32 offset;
      string limit;
      get_args(args, chat_id, message_id, option_id, offset, limit);
      send_request(td_api::make_object<td_api::getPollVoters>(chat_id, message_id, option_id, offset, as_limit(limit)));
    } else if (op == "stoppoll") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      if (!business_connection_id_.empty()) {
        send_request(
            td_api::make_object<td_api::stopBusinessPoll>(business_connection_id_, chat_id, message_id, nullptr));
      } else {
        send_request(td_api::make_object<td_api::stopPoll>(chat_id, message_id, nullptr));
      }
    } else {
      op_not_found_count++;
    }

    if (op == "scms") {
      ChatId chat_id;
      string member_id;
      string status_str;
      td_api::object_ptr<td_api::ChatMemberStatus> status;
      get_args(args, chat_id, member_id, status_str);
      if (status_str == "member") {
        status = td_api::make_object<td_api::chatMemberStatusMember>();
      } else if (status_str == "left") {
        status = td_api::make_object<td_api::chatMemberStatusLeft>();
      } else if (status_str == "banned") {
        status = td_api::make_object<td_api::chatMemberStatusBanned>(std::numeric_limits<int32>::max());
      } else if (status_str == "creator") {
        status = td_api::make_object<td_api::chatMemberStatusCreator>("", false, true);
      } else if (status_str == "creatortitle") {
        status = td_api::make_object<td_api::chatMemberStatusCreator>("owner", false, true);
      } else if (status_str == "creatoranon") {
        status = td_api::make_object<td_api::chatMemberStatusCreator>("", true, true);
      } else if (status_str == "uncreator") {
        status = td_api::make_object<td_api::chatMemberStatusCreator>("", false, false);
      } else if (status_str == "anonadmin") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>(
            "anon", true,
            as_chat_administrator_rights(true, true, true, true, true, true, true, true, true, true, true, true, true,
                                         true, true));
      } else if (status_str == "anon") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>(
            "anon", false,
            as_chat_administrator_rights(false, false, false, false, false, false, false, false, false, false, false,
                                         false, false, false, true));
      } else if (status_str == "addadmin") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>(
            "anon", false,
            as_chat_administrator_rights(false, false, false, false, false, false, false, false, false, true, false,
                                         false, false, false, false));
      } else if (status_str == "calladmin") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>(
            "anon", false,
            as_chat_administrator_rights(false, false, false, false, false, false, false, false, false, false, true,
                                         false, false, false, false));
      } else if (status_str == "admin") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>(
            "", true,
            as_chat_administrator_rights(false, true, true, true, true, true, true, true, true, true, true, true, true,
                                         true, false));
      } else if (status_str == "adminq") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>(
            "title", true,
            as_chat_administrator_rights(false, true, true, true, true, true, true, true, true, true, true, true, true,
                                         true, false));
      } else if (status_str == "minadmin") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>(
            "", true,
            as_chat_administrator_rights(true, false, false, false, false, false, false, false, false, false, false,
                                         false, false, false, false));
      } else if (status_str == "unadmin") {
        status = td_api::make_object<td_api::chatMemberStatusAdministrator>("", true, nullptr);
      } else if (status_str == "rest") {
        status = td_api::make_object<td_api::chatMemberStatusRestricted>(
            true, static_cast<int32>(120 + std::time(nullptr)),
            td_api::make_object<td_api::chatPermissions>(false, false, false, false, false, false, false, false, false,
                                                         false, false, false, false, false));
      } else if (status_str == "restkick") {
        status = td_api::make_object<td_api::chatMemberStatusRestricted>(
            false, static_cast<int32>(120 + std::time(nullptr)),
            td_api::make_object<td_api::chatPermissions>(true, false, false, false, false, false, false, false, false,
                                                         false, false, false, false, false));
      } else if (status_str == "restunkick") {
        status = td_api::make_object<td_api::chatMemberStatusRestricted>(
            true, static_cast<int32>(120 + std::time(nullptr)),
            td_api::make_object<td_api::chatPermissions>(true, false, false, false, false, false, false, false, false,
                                                         false, false, false, false, false));
      } else if (status_str == "unrest") {
        status = td_api::make_object<td_api::chatMemberStatusRestricted>(
            true, 0,
            td_api::make_object<td_api::chatPermissions>(true, true, true, true, true, true, true, true, true, true,
                                                         true, true, true, true));
      }
      if (status != nullptr) {
        send_request(
            td_api::make_object<td_api::setChatMemberStatus>(chat_id, as_message_sender(member_id), std::move(status)));
      } else {
        LOG(ERROR) << "Unknown status \"" << status_str << "\"";
      }
    } else if (op == "cto") {
      send_request(td_api::make_object<td_api::canTransferOwnership>());
    } else if (op == "transferChatOwnership") {
      ChatId chat_id;
      UserId user_id;
      string password;
      get_args(args, chat_id, user_id, password);
      send_request(td_api::make_object<td_api::transferChatOwnership>(chat_id, user_id, password));
    } else if (op == "log") {
      ChatId chat_id;
      string limit;
      string user_ids;
      get_args(args, chat_id, limit, user_ids);
      send_request(td_api::make_object<td_api::getChatEventLog>(chat_id, "", 0, as_limit(limit), nullptr,
                                                                as_user_ids(user_ids)));
    } else if (op == "logf") {
      get_log_chat_id_ = as_chat_id(args);
      send_request(td_api::make_object<td_api::getChatEventLog>(get_log_chat_id_, "", 0, 100, nullptr, Auto()));
    } else if (op == "gtz") {
      send_request(td_api::make_object<td_api::getTimeZones>());
    } else if (op == "join") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::joinChat>(chat_id));
    } else if (op == "leave") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::leaveChat>(chat_id));
    } else if (op == "dcm") {
      ChatId chat_id;
      string member_id;
      get_args(args, chat_id, member_id);
      td_api::object_ptr<td_api::ChatMemberStatus> status = td_api::make_object<td_api::chatMemberStatusBanned>();
      if (as_user_id(member_id) == my_id_) {
        status = td_api::make_object<td_api::chatMemberStatusLeft>();
      }
      send_request(
          td_api::make_object<td_api::setChatMemberStatus>(chat_id, as_message_sender(member_id), std::move(status)));
    } else if (op == "sn") {
      string first_name;
      string last_name;
      get_args(args, first_name, last_name);
      send_request(td_api::make_object<td_api::setName>(first_name, last_name));
    } else if (op == "sb") {
      send_request(td_api::make_object<td_api::setBio>("\n" + args + "\n" + args + "\n"));
    } else if (op == "sun") {
      send_request(td_api::make_object<td_api::setUsername>(args));
    } else if (op == "tunia") {
      string username;
      bool is_active;
      get_args(args, username, is_active);
      send_request(td_api::make_object<td_api::toggleUsernameIsActive>(username, is_active));
    } else if (op == "raun") {
      send_request(td_api::make_object<td_api::reorderActiveUsernames>(autosplit_str(args)));
    } else if (op == "sbd") {
      int32 day;
      int32 month;
      int32 year;
      get_args(args, day, month, year);
      if (day == 0) {
        send_request(td_api::make_object<td_api::setBirthdate>(nullptr));
      } else {
        send_request(
            td_api::make_object<td_api::setBirthdate>(td_api::make_object<td_api::birthdate>(day, month, year)));
      }
    } else if (op == "spec") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::setPersonalChat>(chat_id));
    } else if (op == "sese") {
      send_request(td_api::make_object<td_api::setEmojiStatus>(nullptr));
    } else if (op == "ses") {
      CustomEmojiId custom_emoji_id;
      int32 expiration_date;
      get_args(args, custom_emoji_id, expiration_date);
      send_request(td_api::make_object<td_api::setEmojiStatus>(td_api::make_object<td_api::emojiStatus>(
          td_api::make_object<td_api::emojiStatusTypeCustomEmoji>(custom_emoji_id), expiration_date)));
    } else if (op == "sesg") {
      int64 upgraded_gift_id;
      string title;
      string name;
      CustomEmojiId model_custom_emoji_id;
      CustomEmojiId symbol_custom_emoji_id;
      int32 center_color;
      int32 edge_color;
      int32 symbol_color;
      int32 text_color;
      int32 expiration_date;
      get_args(args, upgraded_gift_id, title, name, model_custom_emoji_id, symbol_custom_emoji_id, center_color,
               edge_color, symbol_color, text_color);
      send_request(td_api::make_object<td_api::setEmojiStatus>(td_api::make_object<td_api::emojiStatus>(
          td_api::make_object<td_api::emojiStatusTypeUpgradedGift>(
              upgraded_gift_id, title, name, model_custom_emoji_id, symbol_custom_emoji_id,
              td_api::make_object<td_api::upgradedGiftBackdropColors>(center_color, edge_color, symbol_color,
                                                                      text_color)),
          expiration_date)));
    } else if (op == "thsme") {
      send_request(td_api::make_object<td_api::toggleHasSponsoredMessagesEnabled>(as_bool(args)));
    } else if (op == "gtes") {
      send_request(td_api::make_object<td_api::getThemedEmojiStatuses>());
    } else if (op == "gdes") {
      send_request(td_api::make_object<td_api::getDefaultEmojiStatuses>());
    } else if (op == "gres") {
      send_request(td_api::make_object<td_api::getRecentEmojiStatuses>());
    } else if (op == "guges") {
      send_request(td_api::make_object<td_api::getUpgradedGiftEmojiStatuses>());
    } else if (op == "cres") {
      send_request(td_api::make_object<td_api::clearRecentEmojiStatuses>());
    } else if (op == "gtces") {
      send_request(td_api::make_object<td_api::getThemedChatEmojiStatuses>());
    } else if (op == "gdces") {
      send_request(td_api::make_object<td_api::getDefaultChatEmojiStatuses>());
    } else if (op == "gdices") {
      send_request(td_api::make_object<td_api::getDisallowedChatEmojiStatuses>());
    } else if (op == "ccun") {
      ChatId chat_id;
      string username;
      get_args(args, chat_id, username);
      send_request(td_api::make_object<td_api::checkChatUsername>(chat_id, username));
    } else if (op == "ssgun" || op == "schun") {
      string supergroup_id;
      string username;
      get_args(args, supergroup_id, username);
      send_request(td_api::make_object<td_api::setSupergroupUsername>(as_supergroup_id(supergroup_id), username));
    } else if (op == "tsgunia" || op == "tchunia") {
      string supergroup_id;
      string username;
      bool is_active;
      get_args(args, supergroup_id, username, is_active);
      send_request(td_api::make_object<td_api::toggleSupergroupUsernameIsActive>(as_supergroup_id(supergroup_id),
                                                                                 username, is_active));
    } else if (op == "dasgun" || op == "dachun") {
      string supergroup_id;
      get_args(args, supergroup_id);
      send_request(td_api::make_object<td_api::disableAllSupergroupUsernames>(as_supergroup_id(supergroup_id)));
    } else if (op == "rsgaun" || op == "rchaun") {
      string supergroup_id;
      get_args(args, supergroup_id, args);
      send_request(td_api::make_object<td_api::reorderSupergroupActiveUsernames>(as_supergroup_id(supergroup_id),
                                                                                 autosplit_str(args)));
    } else if (op == "ssgss") {
      string supergroup_id;
      int64 sticker_set_id;
      get_args(args, supergroup_id, sticker_set_id);
      send_request(
          td_api::make_object<td_api::setSupergroupStickerSet>(as_supergroup_id(supergroup_id), sticker_set_id));
    } else if (op == "ssgcess") {
      string supergroup_id;
      int64 sticker_set_id;
      get_args(args, supergroup_id, sticker_set_id);
      send_request(td_api::make_object<td_api::setSupergroupCustomEmojiStickerSet>(as_supergroup_id(supergroup_id),
                                                                                   sticker_set_id));
    } else if (op == "ssgubc") {
      string supergroup_id;
      int32 unrestrict_boost_count;
      get_args(args, supergroup_id, unrestrict_boost_count);
      send_request(td_api::make_object<td_api::setSupergroupUnrestrictBoostCount>(as_supergroup_id(supergroup_id),
                                                                                  unrestrict_boost_count));
    } else if (op == "tsgp") {
      string supergroup_id;
      bool is_all_history_available;
      get_args(args, supergroup_id, is_all_history_available);
      send_request(td_api::make_object<td_api::toggleSupergroupIsAllHistoryAvailable>(as_supergroup_id(supergroup_id),
                                                                                      is_all_history_available));
    } else if (op == "tsgchsm") {
      string supergroup_id;
      bool can_have_sponsored_messages;
      get_args(args, supergroup_id, can_have_sponsored_messages);
      send_request(td_api::make_object<td_api::toggleSupergroupCanHaveSponsoredMessages>(
          as_supergroup_id(supergroup_id), can_have_sponsored_messages));
    } else if (op == "tsghhm") {
      string supergroup_id;
      bool has_hidden_members;
      get_args(args, supergroup_id, has_hidden_members);
      send_request(td_api::make_object<td_api::toggleSupergroupHasHiddenMembers>(as_supergroup_id(supergroup_id),
                                                                                 has_hidden_members));
    } else if (op == "tsgas") {
      string supergroup_id;
      bool has_aggressive_anti_spam_enabled;
      get_args(args, supergroup_id, has_aggressive_anti_spam_enabled);
      send_request(td_api::make_object<td_api::toggleSupergroupHasAggressiveAntiSpamEnabled>(
          as_supergroup_id(supergroup_id), has_aggressive_anti_spam_enabled));
    } else if (op == "tsgif") {
      string supergroup_id;
      bool is_forum;
      get_args(args, supergroup_id, is_forum);
      send_request(td_api::make_object<td_api::toggleSupergroupIsForum>(as_supergroup_id(supergroup_id), is_forum));
    } else if (op == "tsibg") {
      string supergroup_id;
      get_args(args, supergroup_id);
      send_request(td_api::make_object<td_api::toggleSupergroupIsBroadcastGroup>(as_supergroup_id(supergroup_id)));
    } else if (op == "tsgsm") {
      string supergroup_id;
      bool sign_messages;
      bool show_message_sender;
      get_args(args, supergroup_id, sign_messages, show_message_sender);
      send_request(td_api::make_object<td_api::toggleSupergroupSignMessages>(as_supergroup_id(supergroup_id),
                                                                             sign_messages, show_message_sender));
    } else if (op == "tsgjtsm") {
      string supergroup_id;
      bool join_to_send_message;
      get_args(args, supergroup_id, join_to_send_message);
      send_request(td_api::make_object<td_api::toggleSupergroupJoinToSendMessages>(as_supergroup_id(supergroup_id),
                                                                                   join_to_send_message));
    } else if (op == "tsgjbr") {
      string supergroup_id;
      bool join_by_request;
      get_args(args, supergroup_id, join_by_request);
      send_request(
          td_api::make_object<td_api::toggleSupergroupJoinByRequest>(as_supergroup_id(supergroup_id), join_by_request));
    } else {
      op_not_found_count++;
    }

    if (op == "scar") {
      ChatId chat_id;
      int32 max_reaction_count;
      string available_reactions;
      get_args(args, chat_id, max_reaction_count, available_reactions);
      td_api::object_ptr<td_api::ChatAvailableReactions> chat_available_reactions;
      if (available_reactions == "all") {
        chat_available_reactions = td_api::make_object<td_api::chatAvailableReactionsAll>(max_reaction_count);
      } else if (!available_reactions.empty()) {
        auto reactions = transform(autosplit_str(available_reactions), as_reaction_type);
        chat_available_reactions =
            td_api::make_object<td_api::chatAvailableReactionsSome>(std::move(reactions), max_reaction_count);
      }
      send_request(
          td_api::make_object<td_api::setChatAvailableReactions>(chat_id, std::move(chat_available_reactions)));
    } else if (op == "scd") {
      ChatId chat_id;
      string description;
      get_args(args, chat_id, description);
      send_request(td_api::make_object<td_api::setChatDescription>(chat_id, description));
    } else if (op == "scdg") {
      ChatId chat_id;
      ChatId group_chat_id;
      get_args(args, chat_id, group_chat_id);
      send_request(td_api::make_object<td_api::setChatDiscussionGroup>(chat_id, group_chat_id));
    } else if (op == "scl") {
      ChatId chat_id;
      string latitude;
      string longitude;
      get_args(args, chat_id, latitude, longitude);
      send_request(td_api::make_object<td_api::setChatLocation>(
          chat_id, td_api::make_object<td_api::chatLocation>(as_location(latitude, longitude, string()), "address")));
    } else if (op == "scsmd") {
      ChatId chat_id;
      int32 slow_mode_delay;
      get_args(args, chat_id, slow_mode_delay);
      send_request(td_api::make_object<td_api::setChatSlowModeDelay>(chat_id, slow_mode_delay));
    } else if (op == "pcm" || op == "pcms" || op == "pcmo") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      if (!business_connection_id_.empty()) {
        send_request(td_api::make_object<td_api::setBusinessMessageIsPinned>(business_connection_id_, chat_id,
                                                                             message_id, true));
      } else {
        send_request(td_api::make_object<td_api::pinChatMessage>(chat_id, message_id, op == "pcms", op == "pcmo"));
      }
    } else if (op == "upcm") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      if (!business_connection_id_.empty()) {
        send_request(td_api::make_object<td_api::setBusinessMessageIsPinned>(business_connection_id_, chat_id,
                                                                             message_id, false));
      } else {
        send_request(td_api::make_object<td_api::unpinChatMessage>(chat_id, message_id));
      }
    } else if (op == "uacm") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::unpinAllChatMessages>(chat_id));
    } else if (op == "uamtm") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      get_args(args, chat_id, message_thread_id);
      send_request(td_api::make_object<td_api::unpinAllMessageThreadMessages>(chat_id, message_thread_id));
    } else if (op == "grib") {
      send_request(td_api::make_object<td_api::getRecentInlineBots>());
    } else if (op == "gob") {
      send_request(td_api::make_object<td_api::getOwnedBots>());
    } else if (op == "spc" || op == "su") {
      send_request(td_api::make_object<td_api::searchPublicChat>(args));
    } else if (op == "spcs") {
      send_request(td_api::make_object<td_api::searchPublicChats>(args));
    } else if (op == "sc") {
      SearchQuery query;
      get_args(args, query);
      send_request(td_api::make_object<td_api::searchChats>(query.query, query.limit));
    } else if (op == "scos") {
      SearchQuery query;
      get_args(args, query);
      send_request(td_api::make_object<td_api::searchChatsOnServer>(query.query, query.limit));
    } else if (op == "sbl") {
      string latitude;
      string longitude;
      get_args(args, latitude, longitude);
      if (latitude.empty()) {
        send_request(td_api::make_object<td_api::setBusinessLocation>(nullptr));
      } else {
        send_request(td_api::make_object<td_api::setBusinessLocation>(td_api::make_object<td_api::businessLocation>(
            longitude.empty() ? nullptr : as_location(latitude, longitude, string()), "business address")));
      }
    } else if (op == "sboh") {
      string time_zone_id;
      string opening_hours;
      get_args(args, time_zone_id, opening_hours);
      if (time_zone_id.empty()) {
        send_request(td_api::make_object<td_api::setBusinessOpeningHours>(nullptr));
      } else {
        auto minutes = to_integers<int32>(opening_hours);
        if (minutes.size() % 2 == 1) {
          minutes.push_back(8 * 24 * 60);
        }
        vector<td_api::object_ptr<td_api::businessOpeningHoursInterval>> intervals;
        for (size_t i = 0; i < minutes.size(); i += 2) {
          intervals.push_back(td_api::make_object<td_api::businessOpeningHoursInterval>(minutes[i], minutes[i + 1]));
        }
        send_request(td_api::make_object<td_api::setBusinessOpeningHours>(
            td_api::make_object<td_api::businessOpeningHours>(time_zone_id, std::move(intervals))));
      }
    } else if (op == "sbgms") {
      ShortcutId shortcut_id;
      string chat_ids;
      int32 inactivity_days;
      get_args(args, shortcut_id, chat_ids, inactivity_days);
      if (shortcut_id == 0) {
        send_request(td_api::make_object<td_api::setBusinessGreetingMessageSettings>(nullptr));
      } else {
        send_request(td_api::make_object<td_api::setBusinessGreetingMessageSettings>(
            td_api::make_object<td_api::businessGreetingMessageSettings>(shortcut_id, as_business_recipients(chat_ids),
                                                                         inactivity_days)));
      }
    } else if (op == "sbams" || op == "sbamso") {
      ShortcutId shortcut_id;
      string chat_ids;
      string schedule;
      get_args(args, shortcut_id, chat_ids, schedule);
      if (shortcut_id == 0) {
        send_request(td_api::make_object<td_api::setBusinessAwayMessageSettings>(nullptr));
      } else {
        td_api::object_ptr<td_api::BusinessAwayMessageSchedule> schedule_object;
        if (schedule[0] == 'a') {
          schedule_object = td_api::make_object<td_api::businessAwayMessageScheduleAlways>();
        } else if (schedule[0] == 'o') {
          schedule_object = td_api::make_object<td_api::businessAwayMessageScheduleOutsideOfOpeningHours>();
        } else {
          auto start_date = to_integer<int32>(schedule);
          schedule_object = td_api::make_object<td_api::businessAwayMessageScheduleCustom>(
              start_date, start_date + Random::fast(1000, 100000));
        }
        send_request(td_api::make_object<td_api::setBusinessAwayMessageSettings>(
            td_api::make_object<td_api::businessAwayMessageSettings>(shortcut_id, as_business_recipients(chat_ids),
                                                                     std::move(schedule_object), op == "sbamso")));
      }
    } else if (op == "sbsp") {
      string title;
      string message;
      string sticker;
      get_args(args, title, message, sticker);
      if (title.empty()) {
        send_request(td_api::make_object<td_api::setBusinessStartPage>(nullptr));
      } else {
        send_request(td_api::make_object<td_api::setBusinessStartPage>(
            td_api::make_object<td_api::inputBusinessStartPage>(title, message, as_input_file(sticker))));
      }
    } else if (op == "gbcb") {
      send_request(td_api::make_object<td_api::getBusinessConnectedBot>());
    } else if (op == "sbcb") {
      UserId bot_user_id;
      string chat_ids;
      bool can_reply;
      get_args(args, bot_user_id, chat_ids, can_reply);
      send_request(td_api::make_object<td_api::setBusinessConnectedBot>(
          td_api::make_object<td_api::businessConnectedBot>(bot_user_id, as_business_recipients(chat_ids), can_reply)));
    } else if (op == "tbcbcip") {
      ChatId chat_id;
      bool is_paused;
      get_args(args, chat_id, is_paused);
      send_request(td_api::make_object<td_api::toggleBusinessConnectedBotChatIsPaused>(chat_id, is_paused));
    } else if (op == "rbcbfc") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::removeBusinessConnectedBotFromChat>(chat_id));
    } else if (op == "dbcb") {
      UserId bot_user_id;
      get_args(args, bot_user_id);
      send_request(td_api::make_object<td_api::deleteBusinessConnectedBot>(bot_user_id));
    } else if (op == "gbcl") {
      send_request(td_api::make_object<td_api::getBusinessChatLinks>());
    } else if (op == "cbcl") {
      string text;
      string title;
      get_args(args, text, title);
      send_request(td_api::make_object<td_api::createBusinessChatLink>(
          td_api::make_object<td_api::inputBusinessChatLink>(as_formatted_text(text), title)));
    } else if (op == "ebcl") {
      string link;
      string text;
      string title;
      get_args(args, link, text, title);
      send_request(td_api::make_object<td_api::editBusinessChatLink>(
          link, td_api::make_object<td_api::inputBusinessChatLink>(as_formatted_text(text), title)));
    } else if (op == "dbcl") {
      send_request(td_api::make_object<td_api::deleteBusinessChatLink>(args));
    } else if (op == "gbcli") {
      send_request(td_api::make_object<td_api::getBusinessChatLinkInfo>(args));
    } else if (op == "gbc") {
      send_request(td_api::make_object<td_api::getBusinessConnection>(args.empty() ? business_connection_id_ : args));
    } else if (op == "sco") {
      SearchQuery query;
      get_args(args, query);
      send_request(td_api::make_object<td_api::searchContacts>(query.query, query.limit));
    } else if (op == "srfc") {
      SearchQuery query;
      get_args(args, query);
      send_request(td_api::make_object<td_api::searchRecentlyFoundChats>(query.query, query.limit));
    } else if (op == "arfc") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::addRecentlyFoundChat>(chat_id));
    } else if (op == "rrfc") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::removeRecentlyFoundChat>(chat_id));
    } else if (op == "crfcs") {
      send_request(td_api::make_object<td_api::clearRecentlyFoundChats>());
    } else if (op == "groc") {
      send_request(td_api::make_object<td_api::getRecentlyOpenedChats>(as_limit(args)));
    } else if (op == "glp") {
      send_request(td_api::make_object<td_api::getLinkPreview>(as_formatted_text(args), get_link_preview_options()));
    } else if (op == "gwpiv") {
      string url;
      bool only_local;
      get_args(args, url, only_local);
      send_request(td_api::make_object<td_api::getWebPageInstantView>(url, only_local));
    } else if (op == "spp" || op == "spppf") {
      InputChatPhoto input_chat_photo;
      get_args(args, input_chat_photo);
      send_request(td_api::make_object<td_api::setProfilePhoto>(input_chat_photo, op == "sppf"));
    } else if (op == "suppp") {
      UserId user_id;
      InputChatPhoto input_chat_photo;
      get_args(args, user_id, input_chat_photo);
      send_request(td_api::make_object<td_api::setUserPersonalProfilePhoto>(user_id, input_chat_photo));
    } else if (op == "supp") {
      UserId user_id;
      InputChatPhoto input_chat_photo;
      get_args(args, user_id, input_chat_photo);
      send_request(td_api::make_object<td_api::suggestUserProfilePhoto>(user_id, input_chat_photo));
    } else if (op == "tbcmes") {
      UserId user_id;
      bool can_manage_emoji_status;
      get_args(args, user_id, can_manage_emoji_status);
      send_request(td_api::make_object<td_api::toggleBotCanManageEmojiStatus>(user_id, can_manage_emoji_status));
    } else if (op == "cbsm") {
      UserId bot_user_id;
      get_args(args, bot_user_id);
      send_request(td_api::make_object<td_api::canBotSendMessages>(bot_user_id));
    } else if (op == "abtsm") {
      UserId bot_user_id;
      get_args(args, bot_user_id);
      send_request(td_api::make_object<td_api::allowBotToSendMessages>(bot_user_id));
    } else {
      op_not_found_count++;
    }

    if (op == "swacr") {
      UserId bot_user_id;
      string method;
      string parameters;
      get_args(args, bot_user_id, method, parameters);
      send_request(td_api::make_object<td_api::sendWebAppCustomRequest>(bot_user_id, method, parameters));
    } else if (op == "gbmp") {
      UserId bot_user_id;
      get_args(args, bot_user_id);
      send_request(td_api::make_object<td_api::getBotMediaPreviews>(bot_user_id));
    } else if (op == "gbmpi") {
      UserId bot_user_id;
      string language_code;
      get_args(args, bot_user_id, language_code);
      send_request(td_api::make_object<td_api::getBotMediaPreviewInfo>(bot_user_id, language_code));
    } else if (op == "abmpp") {
      UserId bot_user_id;
      string language_code;
      string photo;
      get_args(args, bot_user_id, language_code, photo);
      send_request(td_api::make_object<td_api::addBotMediaPreview>(
          bot_user_id, language_code,
          td_api::make_object<td_api::inputStoryContentPhoto>(as_input_file(photo), get_added_sticker_file_ids())));
    } else if (op == "abmpv") {
      UserId bot_user_id;
      string language_code;
      string video;
      get_args(args, bot_user_id, language_code, video);
      send_request(td_api::make_object<td_api::addBotMediaPreview>(
          bot_user_id, language_code,
          td_api::make_object<td_api::inputStoryContentVideo>(as_input_file(video), get_added_sticker_file_ids(), 0.0,
                                                              1.5, true)));
    } else if (op == "ebmpp") {
      UserId bot_user_id;
      string language_code;
      FileId file_id;
      string photo;
      get_args(args, bot_user_id, language_code, file_id, photo);
      send_request(td_api::make_object<td_api::editBotMediaPreview>(
          bot_user_id, language_code, file_id,
          td_api::make_object<td_api::inputStoryContentPhoto>(as_input_file(photo), get_added_sticker_file_ids())));
    } else if (op == "ebmpv") {
      UserId bot_user_id;
      string language_code;
      FileId file_id;
      string video;
      get_args(args, bot_user_id, language_code, file_id, video);
      send_request(td_api::make_object<td_api::editBotMediaPreview>(
          bot_user_id, language_code, file_id,
          td_api::make_object<td_api::inputStoryContentVideo>(as_input_file(video), get_added_sticker_file_ids(), 0.0,
                                                              1.5, true)));
    } else if (op == "rbmp") {
      UserId bot_user_id;
      string language_code;
      string file_ids;
      get_args(args, bot_user_id, language_code, file_ids);
      send_request(
          td_api::make_object<td_api::reorderBotMediaPreviews>(bot_user_id, language_code, as_file_ids(file_ids)));
    } else if (op == "dbmp") {
      UserId bot_user_id;
      string language_code;
      string file_ids;
      get_args(args, bot_user_id, language_code, file_ids);
      send_request(
          td_api::make_object<td_api::deleteBotMediaPreviews>(bot_user_id, language_code, as_file_ids(file_ids)));
    } else if (op == "gbi") {
      UserId bot_user_id;
      string language_code;
      get_args(args, bot_user_id, language_code);
      send_request(td_api::make_object<td_api::getBotName>(bot_user_id, language_code));
      send_request(td_api::make_object<td_api::getBotInfoDescription>(bot_user_id, language_code));
      send_request(td_api::make_object<td_api::getBotInfoShortDescription>(bot_user_id, language_code));
    } else if (op == "sbit") {
      UserId bot_user_id;
      string language_code;
      string name;
      string description;
      string short_description;
      get_args(args, bot_user_id, language_code, name, description, short_description);
      send_request(td_api::make_object<td_api::setBotName>(bot_user_id, language_code, name));
      send_request(td_api::make_object<td_api::setBotInfoDescription>(bot_user_id, language_code, description));
      send_request(
          td_api::make_object<td_api::setBotInfoShortDescription>(bot_user_id, language_code, short_description));
    } else if (op == "sbn") {
      UserId bot_user_id;
      string language_code;
      string name;
      get_args(args, bot_user_id, language_code, name);
      send_request(td_api::make_object<td_api::setBotName>(bot_user_id, language_code, name));
    } else if (op == "gbn") {
      UserId bot_user_id;
      string language_code;
      get_args(args, bot_user_id, language_code);
      send_request(td_api::make_object<td_api::getBotName>(bot_user_id, language_code));
    } else if (op == "sbpp") {
      UserId bot_user_id;
      InputChatPhoto input_chat_photo;
      get_args(args, bot_user_id, input_chat_photo);
      send_request(td_api::make_object<td_api::setBotProfilePhoto>(bot_user_id, input_chat_photo));
    } else if (op == "tbunia") {
      UserId bot_user_id;
      string username;
      bool is_active;
      get_args(args, bot_user_id, username, is_active);
      send_request(td_api::make_object<td_api::toggleBotUsernameIsActive>(bot_user_id, username, is_active));
    } else if (op == "rbaun") {
      UserId bot_user_id;
      string usernames;
      get_args(args, bot_user_id, usernames);
      send_request(td_api::make_object<td_api::reorderBotActiveUsernames>(bot_user_id, autosplit_str(usernames)));
    } else if (op == "sbid") {
      UserId bot_user_id;
      string language_code;
      string description;
      get_args(args, bot_user_id, language_code, description);
      send_request(td_api::make_object<td_api::setBotInfoDescription>(bot_user_id, language_code, description));
    } else if (op == "gbid") {
      UserId bot_user_id;
      string language_code;
      get_args(args, bot_user_id, language_code);
      send_request(td_api::make_object<td_api::getBotInfoDescription>(bot_user_id, language_code));
    } else if (op == "sbisd") {
      UserId bot_user_id;
      string language_code;
      string short_description;
      get_args(args, bot_user_id, language_code, short_description);
      send_request(
          td_api::make_object<td_api::setBotInfoShortDescription>(bot_user_id, language_code, short_description));
    } else if (op == "gbisd") {
      UserId bot_user_id;
      string language_code;
      get_args(args, bot_user_id, language_code);
      send_request(td_api::make_object<td_api::getBotInfoShortDescription>(bot_user_id, language_code));
    } else if (op == "smsbv") {
      UserId bot_user_id;
      string sender_id;
      string custom_description;
      get_args(args, bot_user_id, sender_id, custom_description);
      send_request(td_api::make_object<td_api::setMessageSenderBotVerification>(
          bot_user_id, as_message_sender(sender_id), custom_description));
    } else if (op == "rmsbv") {
      UserId bot_user_id;
      string sender_id;
      get_args(args, bot_user_id, sender_id);
      send_request(
          td_api::make_object<td_api::removeMessageSenderBotVerification>(bot_user_id, as_message_sender(sender_id)));
    } else if (op == "sh") {
      const string &prefix = args;
      send_request(td_api::make_object<td_api::searchHashtags>(prefix, 10));
    } else if (op == "rrh") {
      const string &hashtag = args;
      send_request(td_api::make_object<td_api::removeRecentHashtag>(hashtag));
    } else if (op == "view" || op == "viewh" || op == "viewt" || op == "views") {
      ChatId chat_id;
      string message_ids;
      get_args(args, chat_id, message_ids);
      td_api::object_ptr<td_api::MessageSource> source;
      if (op == "viewh") {
        source = td_api::make_object<td_api::messageSourceChatHistory>();
      } else if (op == "viewt") {
        source = td_api::make_object<td_api::messageSourceMessageThreadHistory>();
      } else if (op == "views") {
        source = td_api::make_object<td_api::messageSourceScreenshot>();
      }
      send_request(
          td_api::make_object<td_api::viewMessages>(chat_id, as_message_ids(message_ids), std::move(source), true));
    } else if (op == "omc") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::openMessageContent>(chat_id, message_id));
    } else if (op == "caem") {
      ChatId chat_id;
      MessageId message_id;
      get_args(args, chat_id, message_id);
      send_request(td_api::make_object<td_api::clickAnimatedEmojiMessage>(chat_id, message_id));
    } else if (op == "gilt") {
      const string &link = args;
      send_request(td_api::make_object<td_api::getInternalLinkType>(link));
    } else if (op == "geli") {
      const string &link = args;
      send_request(td_api::make_object<td_api::getExternalLinkInfo>(link));
    } else if (op == "gel" || op == "gelw") {
      const string &link = args;
      send_request(td_api::make_object<td_api::getExternalLink>(link, op == "gelw"));
    } else if (op == "racm") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::readAllChatMentions>(chat_id));
    } else if (op == "ramtm") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      get_args(args, chat_id, message_thread_id);
      send_request(td_api::make_object<td_api::readAllMessageThreadMentions>(chat_id, message_thread_id));
    } else if (op == "racr") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::readAllChatReactions>(chat_id));
    } else if (op == "ramtr") {
      ChatId chat_id;
      MessageThreadId message_thread_id;
      get_args(args, chat_id, message_thread_id);
      send_request(td_api::make_object<td_api::readAllMessageThreadReactions>(chat_id, message_thread_id));
    } else if (op == "tre") {
      send_request(td_api::make_object<td_api::testReturnError>(
          args.empty() ? nullptr : td_api::make_object<td_api::error>(-1, args)));
    } else if (op == "dpp") {
      int64 profile_photo_id;
      get_args(args, profile_photo_id);
      send_request(td_api::make_object<td_api::deleteProfilePhoto>(profile_photo_id));
    } else if (op == "sac") {
      int32 accent_color_id;
      CustomEmojiId background_custom_emoji_id;
      get_args(args, accent_color_id, background_custom_emoji_id);
      send_request(td_api::make_object<td_api::setAccentColor>(accent_color_id, background_custom_emoji_id));
    } else if (op == "spac") {
      int32 profile_accent_color_id;
      CustomEmojiId profile_background_custom_emoji_id;
      get_args(args, profile_accent_color_id, profile_background_custom_emoji_id);
      send_request(td_api::make_object<td_api::setProfileAccentColor>(profile_accent_color_id,
                                                                      profile_background_custom_emoji_id));
    } else if (op == "gns") {
      int64 notification_sound_id;
      get_args(args, notification_sound_id);
      send_request(td_api::make_object<td_api::getSavedNotificationSound>(notification_sound_id));
    } else if (op == "gnss") {
      send_request(td_api::make_object<td_api::getSavedNotificationSounds>());
    } else if (op == "asns") {
      string sound;
      get_args(args, sound);
      send_request(td_api::make_object<td_api::addSavedNotificationSound>(as_input_file(sound)));
    } else if (op == "rns") {
      int64 notification_sound_id;
      get_args(args, notification_sound_id);
      send_request(td_api::make_object<td_api::removeSavedNotificationSound>(notification_sound_id));
    } else if (op == "gcnse" || op == "gcnses") {
      send_request(td_api::make_object<td_api::getChatNotificationSettingsExceptions>(
          as_notification_settings_scope(args), op == "gcnses"));
    } else if (op == "gsns") {
      send_request(td_api::make_object<td_api::getScopeNotificationSettings>(as_notification_settings_scope(args)));
    } else if (op == "scns" || op == "ssns" || op == "sftns") {
      string scope;
      string mute_for;
      int64 sound_id;
      string show_preview;
      string mute_stories;
      int64 story_sound_id;
      string hide_story_sender;
      string disable_pinned_message_notifications;
      string disable_mention_notifications;
      get_args(args, scope, mute_for, sound_id, show_preview, mute_stories, story_sound_id, hide_story_sender,
               disable_pinned_message_notifications, disable_mention_notifications);
      if (op == "ssns") {
        send_request(td_api::make_object<td_api::setScopeNotificationSettings>(
            as_notification_settings_scope(scope),
            td_api::make_object<td_api::scopeNotificationSettings>(
                to_integer<int32>(mute_for), sound_id, as_bool(show_preview), mute_stories.empty(),
                as_bool(mute_stories), story_sound_id, as_bool(hide_story_sender),
                as_bool(disable_pinned_message_notifications), as_bool(disable_mention_notifications))));
      } else {
        auto settings = td_api::make_object<td_api::chatNotificationSettings>(
            mute_for.empty(), to_integer<int32>(mute_for), sound_id == -1, sound_id, show_preview.empty(),
            as_bool(show_preview), mute_stories.empty(), as_bool(mute_stories), story_sound_id == -1, story_sound_id,
            hide_story_sender.empty(), as_bool(hide_story_sender), disable_pinned_message_notifications.empty(),
            as_bool(disable_pinned_message_notifications), disable_mention_notifications.empty(),
            as_bool(disable_mention_notifications));
        if (op == "scns") {
          send_request(
              td_api::make_object<td_api::setChatNotificationSettings>(as_chat_id(scope), std::move(settings)));
        } else {
          string chat_id;
          string message_id;
          std::tie(chat_id, message_id) = split(scope, ',');
          send_request(td_api::make_object<td_api::setForumTopicNotificationSettings>(
              as_chat_id(chat_id), as_message_id(message_id), std::move(settings)));
        }
      }
    } else if (op == "srns") {
      ReactionNotificationSource message_reactions;
      ReactionNotificationSource story_reactions;
      int64 sound_id;
      bool show_preview;
      get_args(args, message_reactions, story_reactions, sound_id, show_preview);
      send_request(td_api::make_object<td_api::setReactionNotificationSettings>(
          td_api::make_object<td_api::reactionNotificationSettings>(message_reactions, story_reactions, sound_id,
                                                                    show_preview)));
    } else if (op == "rans") {
      send_request(td_api::make_object<td_api::resetAllNotificationSettings>());
    } else if (op == "rn") {
      int32 group_id;
      string notification_ids;
      get_args(args, group_id, notification_ids);
      for (auto notification_id : to_integers<int32>(notification_ids)) {
        send_request(td_api::make_object<td_api::removeNotification>(group_id, notification_id));
      }
    } else if (op == "rng") {
      int32 group_id;
      int32 max_notification_id;
      get_args(args, group_id, max_notification_id);
      send_request(td_api::make_object<td_api::removeNotificationGroup>(group_id, max_notification_id));
    } else if (op == "rcab") {
      ChatId chat_id;
      get_args(args, chat_id);
      send_request(td_api::make_object<td_api::removeChatActionBar>(chat_id));
    } else if (op == "rc") {
      ChatId chat_id;
      string option_id;
      string message_ids;
      string text;
      get_args(args, chat_id, option_id, message_ids, text);
      send_request(td_api::make_object<td_api::reportChat>(chat_id, option_id, as_message_ids(message_ids), text));
    } else if (op == "rcp") {
      ChatId chat_id;
      FileId file_id;
      ReportReason reason;
      string text;
      get_args(args, chat_id, file_id, reason, text);
      send_request(td_api::make_object<td_api::reportChatPhoto>(chat_id, file_id, reason, text));
    } else if (op == "reportmr") {
      ChatId chat_id;
      MessageId message_id;
      string sender_id;
      get_args(args, chat_id, message_id, sender_id);
      send_request(
          td_api::make_object<td_api::reportMessageReactions>(chat_id, message_id, as_message_sender(sender_id)));
    } else if (op == "gcst") {
      ChatId chat_id;
      bool is_dark;
      get_args(args, chat_id, is_dark);
      send_request(td_api::make_object<td_api::getChatStatistics>(chat_id, is_dark));
    } else if (op == "gcrst") {
      ChatId chat_id;
      bool is_dark;
      get_args(args, chat_id, is_dark);
      send_request(td_api::make_object<td_api::getChatRevenueStatistics>(chat_id, is_dark));
    } else if (op == "gcrwu") {
      ChatId chat_id;
      string password;
      get_args(args, chat_id, password);
      send_request(td_api::make_object<td_api::getChatRevenueWithdrawalUrl>(chat_id, password));
    } else if (op == "gcrt") {
      ChatId chat_id;
      int32 offset;
      string limit;
      get_args(args, chat_id, offset, limit);
      send_request(td_api::make_object<td_api::getChatRevenueTransactions>(chat_id, offset, as_limit(limit)));
    } else if (op == "gsrs") {
      string owner_id;
      bool is_dark;
      get_args(args, owner_id, is_dark);
      send_request(td_api::make_object<td_api::getStarRevenueStatistics>(as_message_sender(owner_id), is_dark));
    } else if (op == "gswu") {
      string owner_id;
      int32 star_count;
      string password;
      get_args(args, owner_id, star_count, password);
      send_request(
          td_api::make_object<td_api::getStarWithdrawalUrl>(as_message_sender(owner_id), star_count, password));
    } else if (op == "gsaau") {
      string owner_id;
      get_args(args, owner_id);
      send_request(td_api::make_object<td_api::getStarAdAccountUrl>(as_message_sender(owner_id)));
    } else {
      op_not_found_count++;
    }

    if (op == "sgs") {
      ChatId chat_id;
      MessageId message_id;
      UserId user_id;
      int32 score;
      get_args(args, chat_id, message_id, user_id, score);
      send_request(td_api::make_object<td_api::setGameScore>(chat_id, message_id, true, user_id, score, true));
    } else if (op == "gghs") {
      ChatId chat_id;
      MessageId message_id;
      UserId user_id;
      get_args(args, chat_id, message_id, user_id);
      send_request(td_api::make_object<td_api::getGameHighScores>(chat_id, message_id, user_id));
    } else if (op == "gmst") {
      ChatId chat_id;
      MessageId message_id;
      bool is_dark;
      get_args(args, chat_id, message_id, is_dark);
      send_request(td_api::make_object<td_api::getMessageStatistics>(chat_id, message_id, is_dark));
    } else if (op == "gsst") {
      ChatId chat_id;
      StoryId story_id;
      bool is_dark;
      get_args(args, chat_id, story_id, is_dark);
      send_request(td_api::make_object<td_api::getStoryStatistics>(chat_id, story_id, is_dark));
    } else if (op == "gstg") {
      ChatId chat_id;
      string token;
      int64 x;
      get_args(args, chat_id, token, x);
      send_request(td_api::make_object<td_api::getStatisticalGraph>(chat_id, token, x));
    } else if (op == "hsa") {
      send_request(td_api::make_object<td_api::hideSuggestedAction>(as_suggested_action(args)));
    } else if (op == "hccb") {
      send_request(td_api::make_object<td_api::hideContactCloseBirthdays>());
    } else if (op == "glui" || op == "glu" || op == "glua") {
      ChatId chat_id;
      MessageId message_id;
      int32 button_id;
      get_args(args, chat_id, message_id, button_id);
      if (op == "glui") {
        send_request(td_api::make_object<td_api::getLoginUrlInfo>(chat_id, message_id, button_id));
      } else {
        send_request(td_api::make_object<td_api::getLoginUrl>(chat_id, message_id, button_id, op == "glua"));
      }
    } else if (op == "suwb" || op == "suwbc") {
      ChatId chat_id;
      MessageId message_id;
      int32 button_id;
      string shared_user_ids;
      get_args(args, chat_id, message_id, button_id, shared_user_ids);
      send_request(td_api::make_object<td_api::shareUsersWithBot>(chat_id, message_id, button_id,
                                                                  as_user_ids(shared_user_ids), op == "suwbc"));
    } else if (op == "scwb" || op == "scwbc") {
      ChatId chat_id;
      MessageId message_id;
      int32 button_id;
      ChatId shared_chat_id;
      get_args(args, chat_id, message_id, button_id, shared_chat_id);
      send_request(
          td_api::make_object<td_api::shareChatWithBot>(chat_id, message_id, button_id, shared_chat_id, op == "scwbc"));
    } else if (op == "rsgs") {
      string supergroup_id;
      string message_ids;
      get_args(args, supergroup_id, message_ids);
      send_request(td_api::make_object<td_api::reportSupergroupSpam>(as_supergroup_id(supergroup_id),
                                                                     as_message_ids(message_ids)));
    } else if (op == "rsgasfp") {
      string supergroup_id;
      MessageId message_id;
      get_args(args, supergroup_id, message_id);
      send_request(td_api::make_object<td_api::reportSupergroupAntiSpamFalsePositive>(as_supergroup_id(supergroup_id),
                                                                                      message_id));
    } else if (op == "gdiff") {
      send_request(td_api::make_object<td_api::testGetDifference>());
    } else if (op == "dproxy") {
      send_request(td_api::make_object<td_api::disableProxy>());
    } else if (op == "eproxy") {
      send_request(td_api::make_object<td_api::enableProxy>(as_proxy_id(args)));
    } else if (op == "rproxy") {
      send_request(td_api::make_object<td_api::removeProxy>(as_proxy_id(args)));
    } else if (op == "aproxy" || op == "aeproxy" || op == "aeproxytcp" || op == "editproxy" || op == "editeproxy" ||
               op == "editeproxytcp" || op == "tproxy") {
      string proxy_id;
      string server;
      int32 port;
      string user;
      string password;
      if (op[0] == 'e') {
        get_args(args, proxy_id, args);
      }
      get_args(args, server, port, user, password);
      bool enable = op != "aproxy" && op != "editproxy";
      td_api::object_ptr<td_api::ProxyType> type;
      if (!user.empty() && password.empty()) {
        type = td_api::make_object<td_api::proxyTypeMtproto>(user);
      } else {
        if (port == 80 || port == 8080) {
          type = td_api::make_object<td_api::proxyTypeHttp>(user, password, op.back() != 'p');
        } else {
          type = td_api::make_object<td_api::proxyTypeSocks5>(user, password);
        }
      }
      if (op[0] == 'e') {
        send_request(
            td_api::make_object<td_api::editProxy>(as_proxy_id(proxy_id), server, port, enable, std::move(type)));
      } else if (op == "tproxy") {
        send_request(td_api::make_object<td_api::testProxy>(server, port, std::move(type), 2, 10.0));
      } else {
        send_request(td_api::make_object<td_api::addProxy>(server, port, enable, std::move(type)));
      }
    } else if (op == "gproxy" || op == "gproxies") {
      send_request(td_api::make_object<td_api::getProxies>());
    } else if (op == "gproxyl" || op == "gpl") {
      send_request(td_api::make_object<td_api::getProxyLink>(as_proxy_id(args)));
    } else if (op == "pproxy") {
      send_request(td_api::make_object<td_api::pingProxy>(as_proxy_id(args)));
    } else if (op == "gusi") {
      UserId user_id;
      get_args(args, user_id);
      send_request(td_api::make_object<td_api::getUserSupportInfo>(user_id));
    } else if (op == "susi") {
      UserId user_id;
      string text;
      get_args(args, user_id, text);
      send_request(td_api::make_object<td_api::setUserSupportInfo>(user_id, as_formatted_text(text)));
    } else if (op == "gsn") {
      send_request(td_api::make_object<td_api::getSupportName>());
    } else if (op == "touch") {
      auto r_fd = FileFd::open(args, FileFd::Read | FileFd::Write);
      if (r_fd.is_error()) {
        LOG(ERROR) << r_fd.error();
        return;
      }

      auto fd = r_fd.move_as_ok();
      auto size = fd.get_size().move_as_ok();
      fd.seek(size).ignore();
      fd.write("a").ignore();
      fd.seek(size).ignore();
      fd.truncate_to_current_position(size).ignore();
    } else if (op == "mem") {
      auto r_mem_stats = mem_stat();
      if (r_mem_stats.is_error()) {
        LOG(ERROR) << r_mem_stats.error();
      } else {
        auto stats = r_mem_stats.move_as_ok();
        LOG(ERROR) << "RSS = " << stats.resident_size_ << ", peak RSS = " << stats.resident_size_peak_ << ", VSZ "
                   << stats.virtual_size_ << ", peak VSZ = " << stats.virtual_size_peak_;
      }
    } else if (op == "cpu") {
      auto inc_count = to_integer<uint32>(args);
      while (inc_count-- > 0) {
        cpu_counter_++;
      }
      auto r_cpu_stats = cpu_stat();
      if (r_cpu_stats.is_error()) {
        LOG(ERROR) << r_cpu_stats.error();
      } else {
        auto stats = r_cpu_stats.move_as_ok();
        LOG(ERROR) << cpu_counter_.load() << ", total ticks = " << stats.total_ticks_
                   << ", user ticks = " << stats.process_user_ticks_
                   << ", system ticks = " << stats.process_system_ticks_;
      }
    } else if (op[0] == 'v' && (op[1] == 'v' || is_digit(op[1]))) {
      int new_verbosity_level = op[1] == 'v' ? static_cast<int>(op.size()) : to_integer<int>(op.substr(1));
      SET_VERBOSITY_LEVEL(td::max(new_verbosity_level, VERBOSITY_NAME(DEBUG)));
      combined_log.set_first_verbosity_level(new_verbosity_level);
    } else if (op == "slse") {
      execute(td_api::make_object<td_api::setLogStream>(td_api::make_object<td_api::logStreamEmpty>()));
    } else if (op == "slsd") {
      execute(td_api::make_object<td_api::setLogStream>(td_api::make_object<td_api::logStreamDefault>()));
    } else if (op == "gls") {
      execute(td_api::make_object<td_api::getLogStream>());
    } else if (op == "slvl") {
      int32 new_verbosity_level;
      get_args(args, new_verbosity_level);
      execute(td_api::make_object<td_api::setLogVerbosityLevel>(new_verbosity_level));
    } else if (op == "glvl") {
      execute(td_api::make_object<td_api::getLogVerbosityLevel>());
    } else if (op == "gtags" || op == "glt") {
      execute(td_api::make_object<td_api::getLogTags>());
    } else if (op == "sltvl" || op == "sltvle" || op == "tag") {
      string tag;
      int32 level;
      get_args(args, tag, level);
      auto request = td_api::make_object<td_api::setLogTagVerbosityLevel>(tag, level);
      if (op == "sltvl") {
        send_request(std::move(request));
      } else {
        execute(std::move(request));
      }
    } else if (op == "gltvl" || op == "gltvle" || op == "gtag") {
      const string &tag = args;
      auto request = td_api::make_object<td_api::getLogTagVerbosityLevel>(tag);
      if (op == "gltvl") {
        send_request(std::move(request));
      } else {
        execute(std::move(request));
      }
    } else if (op == "alog" || op == "aloge") {
      int32 level;
      string text;
      get_args(args, level, text);
      auto request = td_api::make_object<td_api::addLogMessage>(level, text);
      if (op == "alog") {
        send_request(std::move(request));
      } else {
        execute(std::move(request));
      }
    } else if (op == "q") {
      quit();
    } else if (op == "dnq") {
      dump_pending_network_queries(*net_query_stats_);
    } else if (op == "fatal") {
      LOG(FATAL) << "Fatal!";
    } else if (op == "unreachable") {
      UNREACHABLE();
    } else {
      op_not_found_count++;
    }

    if (op_not_found_count == OP_BLOCK_COUNT && !cmd.empty()) {
      LOG(ERROR) << "Unknown command \"" << cmd << "\" of length " << cmd.size();
    }
  }

  bool is_inited_ = false;
  void loop() final {
    if (!is_inited_) {
      is_inited_ = true;
      init();
    }
    stdin_.flush_read().ensure();
#ifdef USE_READLINE
    while (!stdin_.input_buffer().empty()) {
      rl_callback_read_char();
    }
#else
    while (true) {
      auto cmd = process_stdin(&stdin_.input_buffer());
      if (cmd.is_error()) {
        break;
      }
      add_cmd(cmd.ok().as_slice().str());
    }
#endif

    while (!cmd_queue_.empty() && !close_flag_) {
      auto cmd = std::move(cmd_queue_.front());
      cmd_queue_.pop();
      on_cmd(std::move(cmd));
    }

    if (ready_to_stop_ && close_flag_ && is_stdin_reader_stopped_) {
#ifdef USE_READLINE
      rl_callback_handler_remove();
#endif
      Scheduler::instance()->finish();
      stop();
    }
  }

  void timeout_expired() final {
    if (close_flag_) {
      return;
    }

    for (auto it = pending_file_generations_.begin(); it != pending_file_generations_.end();) {
      auto left_size = it->size - it->local_size;
      CHECK(left_size > 0);
      if (it->part_size > left_size) {
        it->part_size = left_size;
      }
      BufferSlice block(narrow_cast<size_t>(it->part_size));
      FileFd::open(it->source, FileFd::Flags::Read)
          .move_as_ok()
          .pread(block.as_mutable_slice(), it->local_size)
          .ensure();
      if (rand_bool()) {
        auto open_flags = FileFd::Flags::Write | (it->local_size ? 0 : FileFd::Flags::Truncate | FileFd::Flags::Create);
        FileFd::open(it->destination, open_flags).move_as_ok().pwrite(block.as_slice(), it->local_size).ensure();
      } else {
        send_request(
            td_api::make_object<td_api::writeGeneratedFilePart>(it->id, it->local_size, block.as_slice().str()));
      }
      it->local_size += it->part_size;
      if (it->local_size == it->size) {
        send_request(td_api::make_object<td_api::setFileGenerationProgress>(it->id, it->size, it->size));
        send_request(td_api::make_object<td_api::finishFileGeneration>(it->id, nullptr));
        it = pending_file_generations_.erase(it);
      } else {
        auto local_size = it->local_size;
        if (it->test_local_size_decrease && local_size > it->size / 2) {
          local_size = local_size * 2 - it->size;
        }
        send_request(td_api::make_object<td_api::setFileGenerationProgress>(it->id, (it->size + 3 * it->local_size) / 4,
                                                                            local_size));
        ++it;
      }
    }

    if (!pending_file_generations_.empty()) {
      set_timeout_in(0.01);
    }
  }

  void notify() final {
    auto guard = scheduler_->get_send_guard();
    send_event_later(actor_id(), Event::yield());
  }

  void hangup_shared() final {
    CHECK(get_link_token() == 1);
    LOG(INFO) << "StdinReader stopped";
    is_stdin_reader_stopped_ = true;
    yield();
  }

  void add_cmd(string cmd) {
    cmd_queue_.push(std::move(cmd));
  }
  int stdin_getc() {
    auto slice = stdin_.input_buffer().prepare_read();
    if (slice.empty()) {
      return EOF;
    }
    int res = static_cast<unsigned char>(slice[0]);
    stdin_.input_buffer().confirm_read(1);
    return res;
  }

  FlatHashMap<int32, double> being_downloaded_files_;

  int64 my_id_ = 0;
  td_api::object_ptr<td_api::AuthorizationState> authorization_state_;
  string schedule_date_;
  int64 paid_message_star_count_ = 0;
  int64 message_effect_id_ = 0;
  bool only_preview_ = false;
  MessageThreadId message_thread_id_;
  string business_connection_id_;
  bool has_spoiler_ = false;
  int32 message_self_destruct_time_ = 0;
  int64 opened_chat_id_ = 0;

  ChatId reply_chat_id_;
  MessageId reply_message_id_;
  string reply_quote_;
  int32 reply_quote_position_ = 0;
  ChatId reply_story_chat_id_;
  StoryId reply_story_id_;
  ChatId reposted_story_chat_id_;
  StoryId reposted_story_id_;
  string link_preview_url_;
  bool link_preview_is_disabled_ = false;
  bool link_preview_force_small_media_ = false;
  bool link_preview_force_large_media_ = false;
  bool link_preview_show_above_text_ = false;
  bool show_caption_above_media_ = false;
  int64 saved_messages_topic_id_ = 0;
  string quick_reply_shortcut_name_;
  vector<int32> added_sticker_file_ids_;
  string caption_;
  string cover_;
  string thumbnail_;
  int32 start_timestamp_ = 0;

  ConcurrentScheduler *scheduler_{nullptr};

  bool use_test_dc_ = false;
  std::shared_ptr<NetQueryStats> net_query_stats_ = create_net_query_stats();
  ActorOwn<ClientActor> td_client_;
  std::queue<string> cmd_queue_;
  bool close_flag_ = false;
  bool ready_to_stop_ = false;
  bool is_stdin_reader_stopped_ = false;

  bool get_chat_list_ = false;
  bool disable_network_ = false;
  int api_id_ = 0;
  std::string api_hash_;

  int32 group_call_source_ = Random::fast(1, 1000000000);

  static std::atomic<uint64> cpu_counter_;
};
CliClient *CliClient::instance_ = nullptr;
std::atomic<uint64> CliClient::cpu_counter_;

void quit() {
  CliClient::quit_instance();
}

static void fail_signal(int sig) {
  signal_safe_write_signal_number(sig);
  while (true) {
    // spin forever to allow debugger to attach
  }
}

static void on_log_message(int verbosity_level, const char *message) {
  if (verbosity_level == 0) {
    std::cerr << "Fatal error: " << message;
  }
  // std::cerr << "Log message: " << message;
}

void main(int argc, char **argv) {
  ExitGuard exit_guard;
  detail::ThreadIdGuard thread_id_guard;
  ignore_signal(SignalType::HangUp).ensure();
  ignore_signal(SignalType::Pipe).ensure();
  set_signal_handler(SignalType::Error, fail_signal).ensure();
  set_signal_handler(SignalType::Abort, fail_signal).ensure();
  ClientManager::set_log_message_callback(0, on_log_message);
  init_openssl_threads();

  std::locale new_locale("C");
  std::locale::global(new_locale);
  SCOPE_EXIT {
    std::locale::global(std::locale::classic());
    static NullLog null_log;
    log_interface = &null_log;
  };

  CliLog cli_log;

  FileLog file_log;
  TsLog ts_log(&file_log);

  combined_log.set_first(&cli_log);

  log_interface = &combined_log;

  int new_verbosity_level = VERBOSITY_NAME(INFO);
  bool use_test_dc = false;
  bool get_chat_list = false;
  bool disable_network = false;
  auto api_id = [](auto x) -> int32 {
    if (x) {
      return to_integer<int32>(Slice(x));
    }
    return 0;
  }(std::getenv("TD_API_ID"));
  auto api_hash = [](auto x) -> std::string {
    if (x) {
      return x;
    }
    return std::string();
  }(std::getenv("TD_API_HASH"));

  OptionParser options;
  options.set_description("TDLib test client");
  options.add_option('\0', "test", "Use test DC", [&] { use_test_dc = true; });
  options.add_option('v', "verbosity", "Set verbosity level", [&](Slice level) {
    int new_verbosity = 1;
    while (begins_with(level, "v")) {
      new_verbosity++;
      level.remove_prefix(1);
    }
    if (!level.empty()) {
      new_verbosity += to_integer<int>(level) - (new_verbosity == 1);
    }
    new_verbosity_level = VERBOSITY_NAME(FATAL) + new_verbosity;
  });
  options.add_option('l', "log", "Log to file", [&](Slice file_name) {
    if (file_log.init(file_name.str()).is_ok() && file_log.init(file_name.str()).is_ok() &&
        file_log.init(file_name.str(), 1000 << 20).is_ok()) {
      combined_log.set_first(&ts_log);
    }
  });
  options.add_option('W', "", "Preload chat list", [&] { get_chat_list = true; });
  options.add_option('n', "disable-network", "Disable network", [&] { disable_network = true; });
  options.add_checked_option('\0', "api-id", "Set Telegram API ID", OptionParser::parse_integer(api_id));
  options.add_option('\0', "api-hash", "Set Telegram API hash", OptionParser::parse_string(api_hash));
  options.add_check([&] {
    if (api_id == 0 || api_hash.empty()) {
      return Status::Error("You must provide valid api-id and api-hash obtained at https://my.telegram.org");
    }
    return Status::OK();
  });
  auto r_non_options = options.run(argc, argv, 0);
  if (r_non_options.is_error()) {
    LOG(PLAIN) << argv[0] << ": " << r_non_options.error().message();
    LOG(PLAIN) << options;
    return;
  }

  SET_VERBOSITY_LEVEL(td::max(new_verbosity_level, VERBOSITY_NAME(DEBUG)));
  combined_log.set_first_verbosity_level(new_verbosity_level);

  if (combined_log.get_first() == &cli_log) {
    file_log.init("tg_cli.log", 1000 << 20, false).ensure();
    file_log.lazy_rotate();
    combined_log.set_second(&ts_log);
    combined_log.set_second_verbosity_level(VERBOSITY_NAME(DEBUG));
  }

  {
    ConcurrentScheduler scheduler(3, 0);

    class CreateClient final : public Actor {
     public:
      CreateClient(ConcurrentScheduler *scheduler, bool use_test_dc, bool get_chat_list, bool disable_network,
                   int32 api_id, std::string api_hash)
          : scheduler_(scheduler)
          , use_test_dc_(use_test_dc)
          , get_chat_list_(get_chat_list)
          , disable_network_(disable_network)
          , api_id_(api_id)
          , api_hash_(std::move(api_hash)) {
      }

     private:
      void start_up() final {
        create_actor<CliClient>("CliClient", scheduler_, use_test_dc_, get_chat_list_, disable_network_, api_id_,
                                api_hash_)
            .release();
      }

      ConcurrentScheduler *scheduler_;
      bool use_test_dc_;
      bool get_chat_list_;
      bool disable_network_;
      int32 api_id_;
      std::string api_hash_;
    };
    scheduler
        .create_actor_unsafe<CreateClient>(0, "CreateClient", &scheduler, use_test_dc, get_chat_list, disable_network,
                                           api_id, api_hash)
        .release();

    scheduler.start();
    while (scheduler.run_main(Timestamp::in(100))) {
    }
    scheduler.finish();
  }

  dump_memory_usage();
}

}  // namespace td

int main(int argc, char **argv) {
  td::main(argc, argv);
}
