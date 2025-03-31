//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Usernames.h"

#include "td/utils/algorithm.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/utf8.h"

namespace td {

Usernames::Usernames(string &&first_username, vector<telegram_api::object_ptr<telegram_api::username>> &&usernames) {
  if (usernames.empty()) {
    if (!first_username.empty()) {
      active_usernames_.push_back(std::move(first_username));
      editable_username_pos_ = 0;
    }
    return;
  }

  if (!first_username.empty()) {
    LOG(ERROR) << "Receive first username " << first_username << " with " << to_string(usernames);
    return;
  }
  bool was_editable = false;
  for (auto &username : usernames) {
    if (username->username_.empty()) {
      LOG(ERROR) << "Receive empty username in " << to_string(usernames);
      return;
    }
    if (username->editable_) {
      if (was_editable) {
        LOG(ERROR) << "Receive two editable usernames in " << to_string(usernames);
        return;
      }
      if (!username->active_) {
        LOG(ERROR) << "Receive disabled editable usernames in " << to_string(usernames);
        return;
      }
      was_editable = true;
    }
  }

  for (size_t i = 0; i < usernames.size(); i++) {
    if (usernames[i]->active_) {
      active_usernames_.push_back(std::move(usernames[i]->username_));
      if (usernames[i]->editable_) {
        editable_username_pos_ = narrow_cast<int32>(i);
      }
    } else {
      disabled_usernames_.push_back(std::move(usernames[i]->username_));
    }
  }
  CHECK(has_editable_username() == was_editable);
}

tl_object_ptr<td_api::usernames> Usernames::get_usernames_object() const {
  if (is_empty()) {
    return nullptr;
  }
  return make_tl_object<td_api::usernames>(
      vector<string>(active_usernames_), vector<string>(disabled_usernames_),
      has_editable_username() ? active_usernames_[editable_username_pos_] : string());
}

Usernames Usernames::change_editable_username(string &&new_username) const {
  Usernames result = *this;
  if (has_editable_username()) {
    if (new_username.empty()) {
      result.active_usernames_.erase(result.active_usernames_.begin() + editable_username_pos_);
      result.editable_username_pos_ = -1;
    } else {
      // keep position
      result.active_usernames_[editable_username_pos_] = std::move(new_username);
    }
  } else if (!new_username.empty()) {
    // add to the beginning
    result.active_usernames_.insert(result.active_usernames_.begin(), std::move(new_username));
    result.editable_username_pos_ = 0;
  }
  return result;
}

bool Usernames::can_toggle(const string &username) const {
  if (td::contains(active_usernames_, username)) {
    return !has_editable_username() || active_usernames_[editable_username_pos_] != username;
  }
  if (td::contains(disabled_usernames_, username)) {
    return true;
  }
  return false;
}

Usernames Usernames::toggle(const string &username, bool is_active) const {
  Usernames result = *this;
  for (size_t i = 0; i < disabled_usernames_.size(); i++) {
    if (disabled_usernames_[i] == username) {
      if (is_active) {
        // activate the username
        result.disabled_usernames_.erase(result.disabled_usernames_.begin() + i);
        result.active_usernames_.push_back(username);
        // editable username position wasn't changed
      }
      return result;
    }
  }
  for (size_t i = 0; i < active_usernames_.size(); i++) {
    if (active_usernames_[i] == username) {
      if (!is_active) {
        // disable the username
        result.active_usernames_.erase(result.active_usernames_.begin() + i);
        result.disabled_usernames_.insert(result.disabled_usernames_.begin(), username);
        if (result.has_editable_username() && i <= static_cast<size_t>(result.editable_username_pos_)) {
          CHECK(i != static_cast<size_t>(result.editable_username_pos_));
          CHECK(result.editable_username_pos_ > 0);
          result.editable_username_pos_--;
        }
      }
      return result;
    }
  }
  UNREACHABLE();
  return result;
}

Usernames Usernames::deactivate_all() const {
  Usernames result;
  for (size_t i = 0; i < active_usernames_.size(); i++) {
    if (i == static_cast<size_t>(editable_username_pos_)) {
      result.active_usernames_.push_back(active_usernames_[i]);
      result.editable_username_pos_ = 0;
    } else {
      result.disabled_usernames_.push_back(active_usernames_[i]);
    }
  }
  append(result.disabled_usernames_, disabled_usernames_);
  CHECK(result.has_editable_username() == has_editable_username());
  return result;
}

bool Usernames::can_reorder_to(const vector<string> &new_username_order) const {
  if (new_username_order.size() != active_usernames_.size()) {
    return false;
  }
  FlatHashSet<string> active_usernames;
  for (auto &username : active_usernames_) {
    active_usernames.insert(username);
  }
  for (auto &username : new_username_order) {
    auto it = active_usernames.find(username);
    if (it == active_usernames.end()) {
      return false;
    }
    active_usernames.erase(it);
  }
  CHECK(active_usernames.empty());
  return true;
}

Usernames Usernames::reorder_to(vector<string> &&new_username_order) const {
  Usernames result;
  result.active_usernames_ = std::move(new_username_order);
  result.disabled_usernames_ = disabled_usernames_;
  if (has_editable_username()) {
    const string &editable_username = active_usernames_[editable_username_pos_];
    for (size_t i = 0; i < result.active_usernames_.size(); i++) {
      if (result.active_usernames_[i] == editable_username) {
        result.editable_username_pos_ = narrow_cast<int32>(i);
        break;
      }
    }
    CHECK(result.has_editable_username());
  }
  return result;
}

void Usernames::check_utf8_validness() {
  for (auto &username : active_usernames_) {
    if (!check_utf8(username)) {
      LOG(ERROR) << "Have invalid active username \"" << username << '"';
      *this = Usernames();
      return;
    }
  }
  for (auto &username : disabled_usernames_) {
    if (!check_utf8(username)) {
      LOG(ERROR) << "Have invalid disabled username \"" << username << '"';
      *this = Usernames();
      return;
    }
  }
}

bool operator==(const Usernames &lhs, const Usernames &rhs) {
  return lhs.active_usernames_ == rhs.active_usernames_ && lhs.disabled_usernames_ == rhs.disabled_usernames_ &&
         lhs.editable_username_pos_ == rhs.editable_username_pos_;
}

bool operator!=(const Usernames &lhs, const Usernames &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const Usernames &usernames) {
  string_builder << "Usernames[";
  if (usernames.has_editable_username()) {
    string_builder << usernames.active_usernames_[usernames.editable_username_pos_];
  }
  if (!usernames.active_usernames_.empty()) {
    string_builder << ", active " << usernames.active_usernames_;
  }
  if (!usernames.disabled_usernames_.empty()) {
    string_builder << ", disabled " << usernames.disabled_usernames_;
  }
  return string_builder << ']';
}

}  // namespace td
