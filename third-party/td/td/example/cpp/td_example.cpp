//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include <td/telegram/Client.h>
#include <td/telegram/td_api.h>
#include <td/telegram/td_api.hpp>

#include <cstdint>
#include <functional>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

// Simple single-threaded example of TDLib usage.
// Real world programs should use separate thread for the user input.
// Example includes user authentication, receiving updates, getting chat list and sending text messages.

// overloaded
namespace detail {
template <class... Fs>
struct overload;

template <class F>
struct overload<F> : public F {
  explicit overload(F f) : F(f) {
  }
};
template <class F, class... Fs>
struct overload<F, Fs...>
    : public overload<F>
    , public overload<Fs...> {
  overload(F f, Fs... fs) : overload<F>(f), overload<Fs...>(fs...) {
  }
  using overload<F>::operator();
  using overload<Fs...>::operator();
};
}  // namespace detail

template <class... F>
auto overloaded(F... f) {
  return detail::overload<F...>(f...);
}

namespace td_api = td::td_api;

class TdExample {
 public:
  TdExample() {
    td::ClientManager::execute(td_api::make_object<td_api::setLogVerbosityLevel>(1));
    client_manager_ = std::make_unique<td::ClientManager>();
    client_id_ = client_manager_->create_client_id();
    send_query(td_api::make_object<td_api::getOption>("version"), {});
  }

  void loop() {
    while (true) {
      if (need_restart_) {
        restart();
      } else if (!are_authorized_) {
        process_response(client_manager_->receive(10));
      } else {
        std::cout << "Enter action [q] quit [u] check for updates and request results [c] show chats [m <chat_id> "
                     "<text>] send message [me] show self [l] logout: "
                  << std::endl;
        std::string line;
        std::getline(std::cin, line);
        std::istringstream ss(line);
        std::string action;
        if (!(ss >> action)) {
          continue;
        }
        if (action == "q") {
          return;
        }
        if (action == "u") {
          std::cout << "Checking for updates..." << std::endl;
          while (true) {
            auto response = client_manager_->receive(0);
            if (response.object) {
              process_response(std::move(response));
            } else {
              break;
            }
          }
        } else if (action == "close") {
          std::cout << "Closing..." << std::endl;
          send_query(td_api::make_object<td_api::close>(), {});
        } else if (action == "me") {
          send_query(td_api::make_object<td_api::getMe>(),
                     [this](Object object) { std::cout << to_string(object) << std::endl; });
        } else if (action == "l") {
          std::cout << "Logging out..." << std::endl;
          send_query(td_api::make_object<td_api::logOut>(), {});
        } else if (action == "m") {
          std::int64_t chat_id;
          ss >> chat_id;
          ss.get();
          std::string text;
          std::getline(ss, text);

          std::cout << "Sending message to chat " << chat_id << "..." << std::endl;
          auto send_message = td_api::make_object<td_api::sendMessage>();
          send_message->chat_id_ = chat_id;
          auto message_content = td_api::make_object<td_api::inputMessageText>();
          message_content->text_ = td_api::make_object<td_api::formattedText>();
          message_content->text_->text_ = std::move(text);
          send_message->input_message_content_ = std::move(message_content);

          send_query(std::move(send_message), {});
        } else if (action == "c") {
          std::cout << "Loading chat list..." << std::endl;
          send_query(td_api::make_object<td_api::getChats>(nullptr, 20), [this](Object object) {
            if (object->get_id() == td_api::error::ID) {
              return;
            }
            auto chats = td::move_tl_object_as<td_api::chats>(object);
            for (auto chat_id : chats->chat_ids_) {
              std::cout << "[chat_id:" << chat_id << "] [title:" << chat_title_[chat_id] << "]" << std::endl;
            }
          });
        }
      }
    }
  }

 private:
  using Object = td_api::object_ptr<td_api::Object>;
  std::unique_ptr<td::ClientManager> client_manager_;
  std::int32_t client_id_{0};

  td_api::object_ptr<td_api::AuthorizationState> authorization_state_;
  bool are_authorized_{false};
  bool need_restart_{false};
  std::uint64_t current_query_id_{0};
  std::uint64_t authentication_query_id_{0};

  std::map<std::uint64_t, std::function<void(Object)>> handlers_;

  std::map<std::int64_t, td_api::object_ptr<td_api::user>> users_;

  std::map<std::int64_t, std::string> chat_title_;

  void restart() {
    client_manager_.reset();
    *this = TdExample();
  }

  void send_query(td_api::object_ptr<td_api::Function> f, std::function<void(Object)> handler) {
    auto query_id = next_query_id();
    if (handler) {
      handlers_.emplace(query_id, std::move(handler));
    }
    client_manager_->send(client_id_, query_id, std::move(f));
  }

  void process_response(td::ClientManager::Response response) {
    if (!response.object) {
      return;
    }
    //std::cout << response.request_id << " " << to_string(response.object) << std::endl;
    if (response.request_id == 0) {
      return process_update(std::move(response.object));
    }
    auto it = handlers_.find(response.request_id);
    if (it != handlers_.end()) {
      it->second(std::move(response.object));
      handlers_.erase(it);
    }
  }

  std::string get_user_name(std::int64_t user_id) const {
    auto it = users_.find(user_id);
    if (it == users_.end()) {
      return "unknown user";
    }
    return it->second->first_name_ + " " + it->second->last_name_;
  }

  std::string get_chat_title(std::int64_t chat_id) const {
    auto it = chat_title_.find(chat_id);
    if (it == chat_title_.end()) {
      return "unknown chat";
    }
    return it->second;
  }

  void process_update(td_api::object_ptr<td_api::Object> update) {
    td_api::downcast_call(
        *update, overloaded(
                     [this](td_api::updateAuthorizationState &update_authorization_state) {
                       authorization_state_ = std::move(update_authorization_state.authorization_state_);
                       on_authorization_state_update();
                     },
                     [this](td_api::updateNewChat &update_new_chat) {
                       chat_title_[update_new_chat.chat_->id_] = update_new_chat.chat_->title_;
                     },
                     [this](td_api::updateChatTitle &update_chat_title) {
                       chat_title_[update_chat_title.chat_id_] = update_chat_title.title_;
                     },
                     [this](td_api::updateUser &update_user) {
                       auto user_id = update_user.user_->id_;
                       users_[user_id] = std::move(update_user.user_);
                     },
                     [this](td_api::updateNewMessage &update_new_message) {
                       auto chat_id = update_new_message.message_->chat_id_;
                       std::string sender_name;
                       td_api::downcast_call(*update_new_message.message_->sender_id_,
                                             overloaded(
                                                 [this, &sender_name](td_api::messageSenderUser &user) {
                                                   sender_name = get_user_name(user.user_id_);
                                                 },
                                                 [this, &sender_name](td_api::messageSenderChat &chat) {
                                                   sender_name = get_chat_title(chat.chat_id_);
                                                 }));
                       std::string text;
                       if (update_new_message.message_->content_->get_id() == td_api::messageText::ID) {
                         text = static_cast<td_api::messageText &>(*update_new_message.message_->content_).text_->text_;
                       }
                       std::cout << "Receive message: [chat_id:" << chat_id << "] [from:" << sender_name << "] ["
                                 << text << "]" << std::endl;
                     },
                     [](auto &update) {}));
  }

  auto create_authentication_query_handler() {
    return [this, id = authentication_query_id_](Object object) {
      if (id == authentication_query_id_) {
        check_authentication_error(std::move(object));
      }
    };
  }

  void on_authorization_state_update() {
    authentication_query_id_++;
    td_api::downcast_call(*authorization_state_,
                          overloaded(
                              [this](td_api::authorizationStateReady &) {
                                are_authorized_ = true;
                                std::cout << "Authorization is completed" << std::endl;
                              },
                              [this](td_api::authorizationStateLoggingOut &) {
                                are_authorized_ = false;
                                std::cout << "Logging out" << std::endl;
                              },
                              [this](td_api::authorizationStateClosing &) { std::cout << "Closing" << std::endl; },
                              [this](td_api::authorizationStateClosed &) {
                                are_authorized_ = false;
                                need_restart_ = true;
                                std::cout << "Terminated" << std::endl;
                              },
                              [this](td_api::authorizationStateWaitPhoneNumber &) {
                                std::cout << "Enter phone number: " << std::flush;
                                std::string phone_number;
                                std::cin >> phone_number;
                                send_query(
                                    td_api::make_object<td_api::setAuthenticationPhoneNumber>(phone_number, nullptr),
                                    create_authentication_query_handler());
                              },
                              [this](td_api::authorizationStateWaitEmailAddress &) {
                                std::cout << "Enter email address: " << std::flush;
                                std::string email_address;
                                std::cin >> email_address;
                                send_query(td_api::make_object<td_api::setAuthenticationEmailAddress>(email_address),
                                           create_authentication_query_handler());
                              },
                              [this](td_api::authorizationStateWaitEmailCode &) {
                                std::cout << "Enter email authentication code: " << std::flush;
                                std::string code;
                                std::cin >> code;
                                send_query(td_api::make_object<td_api::checkAuthenticationEmailCode>(
                                               td_api::make_object<td_api::emailAddressAuthenticationCode>(code)),
                                           create_authentication_query_handler());
                              },
                              [this](td_api::authorizationStateWaitCode &) {
                                std::cout << "Enter authentication code: " << std::flush;
                                std::string code;
                                std::cin >> code;
                                send_query(td_api::make_object<td_api::checkAuthenticationCode>(code),
                                           create_authentication_query_handler());
                              },
                              [this](td_api::authorizationStateWaitRegistration &) {
                                std::string first_name;
                                std::string last_name;
                                std::cout << "Enter your first name: " << std::flush;
                                std::cin >> first_name;
                                std::cout << "Enter your last name: " << std::flush;
                                std::cin >> last_name;
                                send_query(td_api::make_object<td_api::registerUser>(first_name, last_name, false),
                                           create_authentication_query_handler());
                              },
                              [this](td_api::authorizationStateWaitPassword &) {
                                std::cout << "Enter authentication password: " << std::flush;
                                std::string password;
                                std::getline(std::cin, password);
                                send_query(td_api::make_object<td_api::checkAuthenticationPassword>(password),
                                           create_authentication_query_handler());
                              },
                              [this](td_api::authorizationStateWaitOtherDeviceConfirmation &state) {
                                std::cout << "Confirm this login link on another device: " << state.link_ << std::endl;
                              },
                              [this](td_api::authorizationStateWaitTdlibParameters &) {
                                auto request = td_api::make_object<td_api::setTdlibParameters>();
                                request->database_directory_ = "tdlib";
                                request->use_message_database_ = true;
                                request->use_secret_chats_ = true;
                                request->api_id_ = 94575;
                                request->api_hash_ = "a3406de8d171bb422bb6ddf3bbd800e2";
                                request->system_language_code_ = "en";
                                request->device_model_ = "Desktop";
                                request->application_version_ = "1.0";
                                send_query(std::move(request), create_authentication_query_handler());
                              }));
  }

  void check_authentication_error(Object object) {
    if (object->get_id() == td_api::error::ID) {
      auto error = td::move_tl_object_as<td_api::error>(object);
      std::cout << "Error: " << to_string(error) << std::flush;
      on_authorization_state_update();
    }
  }

  std::uint64_t next_query_id() {
    return ++current_query_id_;
  }
};

int main() {
  TdExample example;
  example.loop();
}
