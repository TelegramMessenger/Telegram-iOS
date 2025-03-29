//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SecureManager.h"

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/Global.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/PasswordManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/optional.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

#include <limits>
#include <memory>

namespace td {

class GetSecureValue final : public NetQueryCallback {
 public:
  GetSecureValue(ActorShared<SecureManager> parent, std::string password, SecureValueType type,
                 Promise<SecureValueWithCredentials> promise);

 private:
  ActorShared<SecureManager> parent_;
  string password_;
  SecureValueType type_;
  Promise<SecureValueWithCredentials> promise_;
  optional<EncryptedSecureValue> encrypted_secure_value_;
  optional<secure_storage::Secret> secret_;

  void on_error(Status error);
  void on_secret(Result<secure_storage::Secret> r_secret, bool dummy);
  void loop() final;
  void start_up() final;

  void on_result(NetQueryPtr query) final;
};

class GetAllSecureValues final : public NetQueryCallback {
 public:
  GetAllSecureValues(ActorShared<SecureManager> parent, std::string password, Promise<TdApiSecureValues> promise);

 private:
  ActorShared<SecureManager> parent_;
  string password_;
  Promise<TdApiSecureValues> promise_;
  optional<vector<EncryptedSecureValue>> encrypted_secure_values_;
  optional<secure_storage::Secret> secret_;

  void on_error(Status error);
  void on_secret(Result<secure_storage::Secret> r_secret, bool dummy);
  void loop() final;
  void start_up() final;

  void on_result(NetQueryPtr query) final;
};

class SetSecureValue final : public NetQueryCallback {
 public:
  SetSecureValue(ActorShared<SecureManager> parent, string password, SecureValue secure_value,
                 Promise<SecureValueWithCredentials> promise);

 private:
  ActorShared<SecureManager> parent_;
  string password_;
  SecureValue secure_value_;
  Promise<SecureValueWithCredentials> promise_;
  optional<secure_storage::Secret> secret_;

  size_t files_left_to_upload_ = 0;
  uint32 upload_generation_{0};
  vector<SecureInputFile> files_to_upload_;
  vector<SecureInputFile> translations_to_upload_;
  optional<SecureInputFile> front_side_;
  optional<SecureInputFile> reverse_side_;
  optional<SecureInputFile> selfie_;

  class UploadCallback;
  std::shared_ptr<UploadCallback> upload_callback_;

  enum class State : int32 { WaitSecret, WaitSetValue } state_ = State::WaitSecret;

  class UploadCallback final : public FileManager::UploadCallback {
   public:
    UploadCallback(ActorId<SetSecureValue> actor_id, uint32 upload_generation);

   private:
    ActorId<SetSecureValue> actor_id_;
    uint32 upload_generation_;

    void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final;

    void on_upload_secure_ok(FileUploadId file_upload_id,
                             telegram_api::object_ptr<telegram_api::InputSecureFile> input_file) final;

    void on_upload_error(FileUploadId file_upload_id, Status error) final;
  };

  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputSecureFile> input_file,
                    uint32 upload_generation);

  void on_upload_error(FileUploadId file_upload_id, Status error, uint32 upload_generation);

  void on_error(Status error);

  void on_secret(Result<secure_storage::Secret> r_secret, bool x);

  void start_up() final;
  void hangup() final;
  void tear_down() final;

  void loop() final;
  void on_result(NetQueryPtr query) final;

  void load_secret();
  void cancel_upload();
  void start_upload_all();
  void start_upload(FileManager *file_manager, FileId &file_id, SecureInputFile &info);
  static void merge(FileManager *file_manager, FileId file_id, EncryptedSecureFile &encrypted_file);
};

class SetSecureValueErrorsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetSecureValueErrorsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(tl_object_ptr<telegram_api::InputUser> input_user,
            vector<tl_object_ptr<telegram_api::SecureValueError>> input_errors) {
    send_query(G()->net_query_creator().create(
        telegram_api::users_setSecureValueErrors(std::move(input_user), std::move(input_errors))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::users_setSecureValueErrors>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for SetSecureValueErrorsQuery: " << ptr;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.code() != 0) {
      promise_.set_error(std::move(status));
    } else {
      promise_.set_error(Status::Error(400, status.message()));
    }
  }
};

GetSecureValue::GetSecureValue(ActorShared<SecureManager> parent, std::string password, SecureValueType type,
                               Promise<SecureValueWithCredentials> promise)
    : parent_(std::move(parent)), password_(std::move(password)), type_(type), promise_(std::move(promise)) {
}

void GetSecureValue::on_error(Status error) {
  if (error.message() == "SECURE_SECRET_REQUIRED") {
    send_closure(G()->password_manager(), &PasswordManager::drop_cached_secret);
  }
  if (error.code() > 0) {
    promise_.set_error(std::move(error));
  } else {
    promise_.set_error(Status::Error(400, error.message()));
  }
  stop();
}

void GetSecureValue::on_secret(Result<secure_storage::Secret> r_secret, bool dummy) {
  if (r_secret.is_error()) {
    if (!G()->is_expected_error(r_secret.error())) {
      LOG(ERROR) << "Receive error instead of secret: " << r_secret.error();
    }
    return on_error(r_secret.move_as_error());
  }
  secret_ = r_secret.move_as_ok();
  loop();
}

void GetSecureValue::loop() {
  if (!encrypted_secure_value_ || !secret_) {
    return;
  }

  auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
  auto r_secure_value = decrypt_secure_value(file_manager, *secret_, *encrypted_secure_value_);
  if (r_secure_value.is_error()) {
    return on_error(r_secure_value.move_as_error());
  }

  send_closure(parent_, &SecureManager::on_get_secure_value, r_secure_value.ok());

  promise_.set_value(r_secure_value.move_as_ok());
  stop();
}

void GetSecureValue::start_up() {
  std::vector<telegram_api::object_ptr<telegram_api::SecureValueType>> types;
  types.push_back(get_input_secure_value_type(type_));

  auto query = G()->net_query_creator().create(telegram_api::account_getSecureValue(std::move(types)));

  G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this));

  send_closure(G()->password_manager(), &PasswordManager::get_secure_secret, password_,
               PromiseCreator::lambda([actor_id = actor_id(this)](Result<secure_storage::Secret> r_secret) {
                 send_closure(actor_id, &GetSecureValue::on_secret, std::move(r_secret), true);
               }));
}

void GetSecureValue::on_result(NetQueryPtr query) {
  auto r_result = fetch_result<telegram_api::account_getSecureValue>(std::move(query));
  if (r_result.is_error()) {
    return on_error(r_result.move_as_error());
  }
  auto result = r_result.move_as_ok();
  if (result.empty()) {
    return on_error(Status::Error(404, "Not Found"));
  }
  if (result.size() != 1) {
    return on_error(Status::Error(PSLICE() << "Expected result of size 1, but receive of size " << result.size()));
  }
  encrypted_secure_value_ =
      get_encrypted_secure_value(G()->td().get_actor_unsafe()->file_manager_.get(), std::move(result[0]));
  if (encrypted_secure_value_.value().type == SecureValueType::None) {
    return on_error(Status::Error(404, "Not Found"));
  }
  loop();
}

GetAllSecureValues::GetAllSecureValues(ActorShared<SecureManager> parent, std::string password,
                                       Promise<TdApiSecureValues> promise)
    : parent_(std::move(parent)), password_(std::move(password)), promise_(std::move(promise)) {
}

void GetAllSecureValues::on_error(Status error) {
  if (error.message() == "SECURE_SECRET_REQUIRED") {
    send_closure(G()->password_manager(), &PasswordManager::drop_cached_secret);
  }
  if (error.code() > 0) {
    promise_.set_error(std::move(error));
  } else {
    promise_.set_error(Status::Error(400, error.message()));
  }
  stop();
}

void GetAllSecureValues::on_secret(Result<secure_storage::Secret> r_secret, bool dummy) {
  if (r_secret.is_error()) {
    if (!G()->is_expected_error(r_secret.error())) {
      LOG(ERROR) << "Receive error instead of secret: " << r_secret.error();
    }
    return on_error(r_secret.move_as_error());
  }
  secret_ = r_secret.move_as_ok();
  loop();
}

void GetAllSecureValues::loop() {
  if (!encrypted_secure_values_ || !secret_) {
    return;
  }

  auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
  auto r_secure_values = decrypt_secure_values(file_manager, *secret_, *encrypted_secure_values_);
  if (r_secure_values.is_error()) {
    return on_error(r_secure_values.move_as_error());
  }

  for (auto &secure_value : r_secure_values.ok()) {
    send_closure(parent_, &SecureManager::on_get_secure_value, secure_value);
  }

  auto secure_values = transform(r_secure_values.move_as_ok(),
                                 [](SecureValueWithCredentials &&value) { return std::move(value.value); });
  promise_.set_value(get_passport_elements_object(file_manager, secure_values));
  stop();
}

void GetAllSecureValues::start_up() {
  auto query = G()->net_query_creator().create(telegram_api::account_getAllSecureValues());

  G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this));

  send_closure(G()->password_manager(), &PasswordManager::get_secure_secret, password_,
               PromiseCreator::lambda([actor_id = actor_id(this)](Result<secure_storage::Secret> r_secret) {
                 send_closure(actor_id, &GetAllSecureValues::on_secret, std::move(r_secret), true);
               }));
}

void GetAllSecureValues::on_result(NetQueryPtr query) {
  auto r_result = fetch_result<telegram_api::account_getAllSecureValues>(std::move(query));
  if (r_result.is_error()) {
    return on_error(r_result.move_as_error());
  }
  encrypted_secure_values_ =
      get_encrypted_secure_values(G()->td().get_actor_unsafe()->file_manager_.get(), r_result.move_as_ok());
  loop();
}

SetSecureValue::SetSecureValue(ActorShared<SecureManager> parent, string password, SecureValue secure_value,
                               Promise<SecureValueWithCredentials> promise)
    : parent_(std::move(parent))
    , password_(std::move(password))
    , secure_value_(std::move(secure_value))
    , promise_(std::move(promise)) {
}

SetSecureValue::UploadCallback::UploadCallback(ActorId<SetSecureValue> actor_id, uint32 upload_generation)
    : actor_id_(actor_id), upload_generation_(upload_generation) {
}

void SetSecureValue::UploadCallback::on_upload_ok(FileUploadId file_upload_id,
                                                  telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  CHECK(input_file == nullptr);
  send_closure_later(actor_id_, &SetSecureValue::on_upload_ok, file_upload_id, nullptr, upload_generation_);
}

void SetSecureValue::UploadCallback::on_upload_secure_ok(
    FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputSecureFile> input_file) {
  send_closure_later(actor_id_, &SetSecureValue::on_upload_ok, file_upload_id, std::move(input_file),
                     upload_generation_);
}

void SetSecureValue::UploadCallback::on_upload_error(FileUploadId file_upload_id, Status error) {
  send_closure_later(actor_id_, &SetSecureValue::on_upload_error, file_upload_id, std::move(error), upload_generation_);
}

void SetSecureValue::on_upload_ok(FileUploadId file_upload_id,
                                  telegram_api::object_ptr<telegram_api::InputSecureFile> input_file,
                                  uint32 upload_generation) {
  if (upload_generation_ != upload_generation) {
    send_closure(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    return;
  }
  SecureInputFile *info_ptr = nullptr;
  for (auto &info : files_to_upload_) {
    if (info.file_upload_id == file_upload_id) {
      info_ptr = &info;
      break;
    }
  }
  for (auto &info : translations_to_upload_) {
    if (info.file_upload_id == file_upload_id) {
      info_ptr = &info;
      break;
    }
  }
  if (front_side_ && front_side_.value().file_upload_id == file_upload_id) {
    info_ptr = &front_side_.value();
  }
  if (reverse_side_ && reverse_side_.value().file_upload_id == file_upload_id) {
    info_ptr = &reverse_side_.value();
  }
  if (selfie_ && selfie_.value().file_upload_id == file_upload_id) {
    info_ptr = &selfie_.value();
  }
  CHECK(info_ptr);
  auto &info = *info_ptr;
  CHECK(!info.input_file);
  info.input_file = std::move(input_file);
  CHECK(files_left_to_upload_ != 0);
  files_left_to_upload_--;
  loop();
}

void SetSecureValue::on_upload_error(FileUploadId file_upload_id, Status error, uint32 upload_generation) {
  if (upload_generation_ != upload_generation) {
    return;
  }
  on_error(std::move(error));
}

void SetSecureValue::on_error(Status error) {
  if (error.code() > 0) {
    promise_.set_error(std::move(error));
  } else {
    promise_.set_error(Status::Error(400, error.message()));
  }
  stop();
}

void SetSecureValue::on_secret(Result<secure_storage::Secret> r_secret, bool x) {
  if (r_secret.is_error()) {
    if (!G()->is_expected_error(r_secret.error())) {
      LOG(ERROR) << "Receive error instead of secret: " << r_secret.error();
    }
    return on_error(r_secret.move_as_error());
  }
  secret_ = r_secret.move_as_ok();
  loop();
}

void SetSecureValue::start_up() {
  load_secret();
  auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();

  // Remove duplicate files
  FileId front_side_file_id;
  if (secure_value_.front_side.file_id.is_valid()) {
    front_side_file_id = file_manager->get_file_view(secure_value_.front_side.file_id).get_main_file_id();
    front_side_ = SecureInputFile();
  }
  FileId reverse_side_file_id;
  if (secure_value_.reverse_side.file_id.is_valid()) {
    reverse_side_file_id = file_manager->get_file_view(secure_value_.reverse_side.file_id).get_main_file_id();
    reverse_side_ = SecureInputFile();
    if (front_side_file_id == reverse_side_file_id) {
      return on_error(Status::Error(400, "Front side and reverse side must be different"));
    }
  }
  FileId selfie_file_id;
  if (secure_value_.selfie.file_id.is_valid()) {
    selfie_file_id = file_manager->get_file_view(secure_value_.selfie.file_id).get_main_file_id();
    selfie_ = SecureInputFile();
    if (front_side_file_id == selfie_file_id) {
      return on_error(Status::Error(400, "Front side and selfie must be different"));
    }
    if (reverse_side_file_id == selfie_file_id) {
      return on_error(Status::Error(400, "Reverse side and selfie must be different"));
    }
  }

  if (!secure_value_.files.empty()) {
    CHECK(!front_side_file_id.is_valid());
    CHECK(!reverse_side_file_id.is_valid());
    CHECK(!selfie_file_id.is_valid());
    for (auto it = secure_value_.files.begin(); it != secure_value_.files.end();) {
      auto file_id = file_manager->get_file_view(it->file_id).get_main_file_id();
      bool is_duplicate = false;
      for (auto other_it = secure_value_.files.begin(); other_it != it; ++other_it) {
        if (file_id == file_manager->get_file_view(other_it->file_id).get_main_file_id()) {
          is_duplicate = true;
          break;
        }
      }
      if (is_duplicate) {
        it = secure_value_.files.erase(it);
      } else {
        ++it;
      }
    }
  }
  if (!secure_value_.translations.empty()) {
    for (auto it = secure_value_.translations.begin(); it != secure_value_.translations.end();) {
      auto file_id = file_manager->get_file_view(it->file_id).get_main_file_id();
      bool is_duplicate = file_id == front_side_file_id || file_id == reverse_side_file_id || file_id == selfie_file_id;
      for (auto other_it = secure_value_.translations.begin(); other_it != it; ++other_it) {
        if (file_id == file_manager->get_file_view(other_it->file_id).get_main_file_id()) {
          is_duplicate = true;
          break;
        }
      }
      for (auto &dated_file : secure_value_.files) {
        if (file_id == file_manager->get_file_view(dated_file.file_id).get_main_file_id()) {
          is_duplicate = true;
          break;
        }
      }
      if (is_duplicate) {
        it = secure_value_.translations.erase(it);
      } else {
        ++it;
      }
    }
  }

  start_upload_all();
}

void SetSecureValue::load_secret() {
  secret_ = {};
  send_closure(G()->password_manager(), &PasswordManager::get_secure_secret, password_,
               PromiseCreator::lambda([actor_id = actor_id(this)](Result<secure_storage::Secret> r_secret) {
                 send_closure(actor_id, &SetSecureValue::on_secret, std::move(r_secret), true);
               }));
}

void SetSecureValue::cancel_upload() {
  upload_generation_++;
  auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
  if (file_manager == nullptr) {
    return;
  }
  for (auto &file_info : files_to_upload_) {
    file_manager->cancel_upload(file_info.file_upload_id);
  }
  for (auto &file_info : translations_to_upload_) {
    file_manager->cancel_upload(file_info.file_upload_id);
  }
  if (front_side_) {
    file_manager->cancel_upload(front_side_.value().file_upload_id);
  }
  if (reverse_side_) {
    file_manager->cancel_upload(reverse_side_.value().file_upload_id);
  }
  if (selfie_) {
    file_manager->cancel_upload(selfie_.value().file_upload_id);
  }
  files_left_to_upload_ = 0;
}

void SetSecureValue::start_upload_all() {
  if (files_left_to_upload_ != 0) {
    cancel_upload();
  }
  upload_generation_++;
  upload_callback_ = std::make_shared<UploadCallback>(actor_id(this), upload_generation_);

  auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
  files_to_upload_.resize(secure_value_.files.size());
  for (size_t i = 0; i < files_to_upload_.size(); i++) {
    start_upload(file_manager, secure_value_.files[i].file_id, files_to_upload_[i]);
  }
  translations_to_upload_.resize(secure_value_.translations.size());
  for (size_t i = 0; i < translations_to_upload_.size(); i++) {
    start_upload(file_manager, secure_value_.translations[i].file_id, translations_to_upload_[i]);
  }
  if (front_side_) {
    start_upload(file_manager, secure_value_.front_side.file_id, front_side_.value());
  }
  if (reverse_side_) {
    start_upload(file_manager, secure_value_.reverse_side.file_id, reverse_side_.value());
  }
  if (selfie_) {
    start_upload(file_manager, secure_value_.selfie.file_id, selfie_.value());
  }
}

void SetSecureValue::start_upload(FileManager *file_manager, FileId &file_id, SecureInputFile &info) {
  auto file_view = file_manager->get_file_view(file_id);
  bool force = false;
  if (!info.file_upload_id.is_valid()) {
    if (!file_view.is_encrypted_secure()) {
      file_id = file_manager->copy_file_id(file_id, FileType::SecureEncrypted, DialogId(), "SetSecureValue");
    }

    info.file_upload_id = {file_id, FileManager::get_internal_upload_id()};
  } else {
    force = true;
  }
  file_manager->resume_upload(info.file_upload_id, {}, upload_callback_, 1, 0, force);
  files_left_to_upload_++;
}

void SetSecureValue::loop() {
  if (state_ == State::WaitSecret) {
    if (!secret_) {
      return;
    }
    if (files_left_to_upload_ != 0) {
      return;
    }
    auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
    auto input_secure_value =
        get_input_secure_value_object(file_manager, encrypt_secure_value(file_manager, *secret_, secure_value_),
                                      files_to_upload_, front_side_, reverse_side_, selfie_, translations_to_upload_);
    auto save_secure_value =
        telegram_api::account_saveSecureValue(std::move(input_secure_value), secret_.value().get_hash());
    auto query = G()->net_query_creator().create(save_secure_value);

    G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this));
    state_ = State::WaitSetValue;
  }
}

void SetSecureValue::hangup() {
  on_error(Status::Error(406, "Request canceled"));
}

void SetSecureValue::tear_down() {
  cancel_upload();
}

void SetSecureValue::on_result(NetQueryPtr query) {
  auto r_result = fetch_result<telegram_api::account_saveSecureValue>(std::move(query));
  if (r_result.is_error()) {
    if (r_result.error().message() == "SECURE_SECRET_REQUIRED") {
      state_ = State::WaitSecret;
      send_closure(G()->password_manager(), &PasswordManager::drop_cached_secret);
      load_secret();
      return loop();
    }
    if (r_result.error().message() == "SECURE_SECRET_INVALID") {
      state_ = State::WaitSecret;
      start_upload_all();
      return loop();
    }
    return on_error(r_result.move_as_error());
  }
  auto result = r_result.move_as_ok();
  auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
  auto encrypted_secure_value = get_encrypted_secure_value(file_manager, std::move(result));
  if (encrypted_secure_value.type == SecureValueType::None) {
    return on_error(Status::Error(500, "Receive invalid Telegram Passport element"));
  }
  if (secure_value_.files.size() != encrypted_secure_value.files.size()) {
    return on_error(Status::Error(500, "Different file count"));
  }
  if (secure_value_.translations.size() != encrypted_secure_value.translations.size()) {
    return on_error(Status::Error(500, "Different translation count"));
  }
  for (size_t i = 0; i < secure_value_.files.size(); i++) {
    merge(file_manager, secure_value_.files[i].file_id, encrypted_secure_value.files[i]);
  }
  if (secure_value_.front_side.file_id.is_valid() && encrypted_secure_value.front_side.file.file_id.is_valid()) {
    merge(file_manager, secure_value_.front_side.file_id, encrypted_secure_value.front_side);
  }
  if (secure_value_.reverse_side.file_id.is_valid() && encrypted_secure_value.reverse_side.file.file_id.is_valid()) {
    merge(file_manager, secure_value_.reverse_side.file_id, encrypted_secure_value.reverse_side);
  }
  if (secure_value_.selfie.file_id.is_valid() && encrypted_secure_value.selfie.file.file_id.is_valid()) {
    merge(file_manager, secure_value_.selfie.file_id, encrypted_secure_value.selfie);
  }
  for (size_t i = 0; i < secure_value_.translations.size(); i++) {
    merge(file_manager, secure_value_.translations[i].file_id, encrypted_secure_value.translations[i]);
  }
  auto r_secure_value = decrypt_secure_value(file_manager, *secret_, encrypted_secure_value);
  if (r_secure_value.is_error()) {
    return on_error(r_secure_value.move_as_error());
  }

  send_closure(parent_, &SecureManager::on_get_secure_value, r_secure_value.ok());

  promise_.set_value(r_secure_value.move_as_ok());
  stop();
}

void SetSecureValue::merge(FileManager *file_manager, FileId file_id, EncryptedSecureFile &encrypted_file) {
  auto file_view = file_manager->get_file_view(file_id);
  CHECK(!file_view.empty());
  CHECK(file_view.encryption_key().has_value_hash());
  if (file_view.encryption_key().value_hash().as_slice() != encrypted_file.file_hash) {
    LOG(ERROR) << "Hash mismatch";
    return;
  }
  LOG_STATUS(file_manager->merge(encrypted_file.file.file_id, file_id));
}

class DeleteSecureValue final : public NetQueryCallback {
 public:
  DeleteSecureValue(ActorShared<SecureManager> parent, SecureValueType type, Promise<Unit> promise)
      : parent_(std::move(parent)), type_(std::move(type)), promise_(std::move(promise)) {
  }

 private:
  ActorShared<SecureManager> parent_;
  SecureValueType type_;
  Promise<Unit> promise_;

  void start_up() final {
    std::vector<telegram_api::object_ptr<telegram_api::SecureValueType>> types;
    types.push_back(get_input_secure_value_type(type_));
    auto query = G()->net_query_creator().create(telegram_api::account_deleteSecureValue(std::move(types)));
    G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this));
  }

  void on_result(NetQueryPtr query) final {
    auto r_result = fetch_result<telegram_api::account_deleteSecureValue>(std::move(query));
    if (r_result.is_error()) {
      promise_.set_error(r_result.move_as_error());
    } else {
      promise_.set_value(Unit());
    }
    stop();
  }
};

class GetPassportAuthorizationForm final : public NetQueryCallback {
 public:
  GetPassportAuthorizationForm(ActorShared<SecureManager> parent, UserId bot_user_id, string scope, string public_key,
                               Promise<telegram_api::object_ptr<telegram_api::account_authorizationForm>> promise)
      : parent_(std::move(parent))
      , bot_user_id_(bot_user_id)
      , scope_(std::move(scope))
      , public_key_(std::move(public_key))
      , promise_(std::move(promise)) {
  }

 private:
  ActorShared<SecureManager> parent_;
  UserId bot_user_id_;
  string scope_;
  string public_key_;
  Promise<telegram_api::object_ptr<telegram_api::account_authorizationForm>> promise_;

  void on_error(Status error) {
    if (error.code() > 0) {
      promise_.set_error(std::move(error));
    } else {
      promise_.set_error(Status::Error(400, error.message()));
    }
    stop();
  }

  void start_up() final {
    auto account_get_authorization_form =
        telegram_api::account_getAuthorizationForm(bot_user_id_.get(), std::move(scope_), std::move(public_key_));
    auto query = G()->net_query_creator().create(account_get_authorization_form);
    G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this));
  }

  void on_result(NetQueryPtr query) final {
    auto r_result = fetch_result<telegram_api::account_getAuthorizationForm>(std::move(query));
    if (r_result.is_error()) {
      return on_error(r_result.move_as_error());
    }
    promise_.set_value(r_result.move_as_ok());
    stop();
  }
};

SecureManager::SecureManager(ActorShared<> parent) : parent_(std::move(parent)) {
}

void SecureManager::get_secure_value(std::string password, SecureValueType type, Promise<TdApiSecureValue> promise) {
  auto new_promise =
      PromiseCreator::lambda([promise = std::move(promise)](Result<SecureValueWithCredentials> r_secure_value) mutable {
        if (r_secure_value.is_error()) {
          return promise.set_error(r_secure_value.move_as_error());
        }

        auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
        if (file_manager == nullptr) {
          return promise.set_value(nullptr);
        }
        auto r_passport_element = get_passport_element_object(file_manager, r_secure_value.move_as_ok().value);
        if (r_passport_element.is_error()) {
          LOG(ERROR) << "Failed to get passport element object: " << r_passport_element.error();
          return promise.set_value(nullptr);
        }
        promise.set_value(r_passport_element.move_as_ok());
      });

  refcnt_++;
  create_actor<GetSecureValue>("GetSecureValue", actor_shared(this), std::move(password), type, std::move(new_promise))
      .release();
}

class GetPassportConfig final : public NetQueryCallback {
 public:
  GetPassportConfig(ActorShared<SecureManager> parent, string country_code,
                    Promise<td_api::object_ptr<td_api::text>> promise)
      : parent_(std::move(parent)), country_code_(std::move(country_code)), promise_(std::move(promise)) {
  }

 private:
  ActorShared<SecureManager> parent_;
  string country_code_;
  Promise<td_api::object_ptr<td_api::text>> promise_;

  void start_up() final {
    auto query = G()->net_query_creator().create(telegram_api::help_getPassportConfig(0));
    G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this));
  }

  void on_result(NetQueryPtr query) final {
    auto r_result = fetch_result<telegram_api::help_getPassportConfig>(std::move(query));
    if (r_result.is_error()) {
      promise_.set_error(r_result.move_as_error());
      stop();
      return;
    }

    auto config = r_result.move_as_ok();
    switch (config->get_id()) {
      case telegram_api::help_passportConfigNotModified::ID:
        promise_.set_error(Status::Error(500, "Wrong server response"));
        break;
      case telegram_api::help_passportConfig::ID: {
        const string &data =
            static_cast<const telegram_api::help_passportConfig *>(config.get())->countries_langs_->data_;
        auto begin_pos = data.find((PSLICE() << '"' << country_code_ << "\":\"").c_str());
        if (begin_pos == string::npos) {
          promise_.set_value(nullptr);
          break;
        }

        begin_pos += 4 + country_code_.size();
        auto end_pos = data.find('"', begin_pos);
        if (end_pos == string::npos) {
          return promise_.set_error(Status::Error(500, "Wrong server response"));
        }
        promise_.set_value(td_api::make_object<td_api::text>(data.substr(begin_pos, end_pos - begin_pos)));
        break;
      }
      default:
        UNREACHABLE();
    }
    stop();
  }
};

void SecureManager::on_get_secure_value(SecureValueWithCredentials value) {
  auto type = value.value.type;
  secure_value_cache_[type] = std::move(value);
}

void SecureManager::get_all_secure_values(std::string password, Promise<TdApiSecureValues> promise) {
  refcnt_++;
  create_actor<GetAllSecureValues>("GetAllSecureValues", actor_shared(this), std::move(password), std::move(promise))
      .release();
}

void SecureManager::set_secure_value(string password, SecureValue secure_value, Promise<TdApiSecureValue> promise) {
  refcnt_++;
  auto type = secure_value.type;
  auto new_promise =
      PromiseCreator::lambda([promise = std::move(promise)](Result<SecureValueWithCredentials> r_secure_value) mutable {
        if (r_secure_value.is_error()) {
          return promise.set_error(r_secure_value.move_as_error());
        }
        auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
        auto r_passport_element = get_passport_element_object(file_manager, r_secure_value.move_as_ok().value);
        if (r_passport_element.is_error()) {
          LOG(ERROR) << "Failed to get passport element object: " << r_passport_element.error();
          return promise.set_error(Status::Error(500, "Failed to get passport element object"));
        }
        promise.set_value(r_passport_element.move_as_ok());
      });
  set_secure_value_queries_[type] = create_actor<SetSecureValue>(
      "SetSecureValue", actor_shared(this), std::move(password), std::move(secure_value), std::move(new_promise));
}

void SecureManager::delete_secure_value(SecureValueType type, Promise<Unit> promise) {
  refcnt_++;
  auto new_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), type, promise = std::move(promise)](Result<Unit> result) mutable {
        send_closure(actor_id, &SecureManager::on_delete_secure_value, type, std::move(promise), std::move(result));
      });
  create_actor<DeleteSecureValue>("DeleteSecureValue", actor_shared(this), type, std::move(new_promise)).release();
}

void SecureManager::on_delete_secure_value(SecureValueType type, Promise<Unit> promise, Result<Unit> result) {
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }

  secure_value_cache_.erase(type);
  promise.set_value(Unit());
}

void SecureManager::set_secure_value_errors(Td *td, tl_object_ptr<telegram_api::InputUser> input_user,
                                            vector<tl_object_ptr<td_api::inputPassportElementError>> errors,
                                            Promise<Unit> promise) {
  CHECK(td != nullptr);
  CHECK(input_user != nullptr);
  vector<tl_object_ptr<telegram_api::SecureValueError>> input_errors;
  for (auto &error : errors) {
    if (error == nullptr) {
      return promise.set_error(Status::Error(400, "Error must be non-empty"));
    }
    if (error->type_ == nullptr) {
      return promise.set_error(Status::Error(400, "Type must be non-empty"));
    }
    if (!clean_input_string(error->message_)) {
      return promise.set_error(Status::Error(400, "Error message must be encoded in UTF-8"));
    }
    if (error->source_ == nullptr) {
      return promise.set_error(Status::Error(400, "Error source must be non-empty"));
    }

    auto type = get_input_secure_value_type(get_secure_value_type_td_api(error->type_));
    switch (error->source_->get_id()) {
      case td_api::inputPassportElementErrorSourceUnspecified::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceUnspecified>(error->source_);
        input_errors.push_back(make_tl_object<telegram_api::secureValueError>(
            std::move(type), BufferSlice(source->element_hash_), error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceDataField::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceDataField>(error->source_);
        if (!clean_input_string(source->field_name_)) {
          return promise.set_error(Status::Error(400, "Field name must be encoded in UTF-8"));
        }

        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorData>(
            std::move(type), BufferSlice(source->data_hash_), source->field_name_, error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceFrontSide::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceFrontSide>(error->source_);
        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorFrontSide>(
            std::move(type), BufferSlice(source->file_hash_), error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceReverseSide::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceReverseSide>(error->source_);
        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorReverseSide>(
            std::move(type), BufferSlice(source->file_hash_), error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceSelfie::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceSelfie>(error->source_);
        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorSelfie>(
            std::move(type), BufferSlice(source->file_hash_), error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceTranslationFile::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceTranslationFile>(error->source_);
        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorTranslationFile>(
            std::move(type), BufferSlice(source->file_hash_), error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceTranslationFiles::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceTranslationFiles>(error->source_);
        if (source->file_hashes_.empty()) {
          return promise.set_error(Status::Error(400, "File hashes must be non-empty"));
        }
        auto file_hashes = transform(source->file_hashes_, [](Slice hash) { return BufferSlice(hash); });
        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorTranslationFiles>(
            std::move(type), std::move(file_hashes), error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceFile::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceFile>(error->source_);
        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorFile>(
            std::move(type), BufferSlice(source->file_hash_), error->message_));
        break;
      }
      case td_api::inputPassportElementErrorSourceFiles::ID: {
        auto source = td_api::move_object_as<td_api::inputPassportElementErrorSourceFiles>(error->source_);
        if (source->file_hashes_.empty()) {
          return promise.set_error(Status::Error(400, "File hashes must be non-empty"));
        }
        auto file_hashes = transform(source->file_hashes_, [](Slice hash) { return BufferSlice(hash); });
        input_errors.push_back(make_tl_object<telegram_api::secureValueErrorFiles>(
            std::move(type), std::move(file_hashes), error->message_));
        break;
      }
      default:
        UNREACHABLE();
    }
  }
  td->create_handler<SetSecureValueErrorsQuery>(std::move(promise))
      ->send(std::move(input_user), std::move(input_errors));
}

void SecureManager::get_passport_authorization_form(UserId bot_user_id, string scope, string public_key, string nonce,
                                                    Promise<TdApiAuthorizationForm> promise) {
  refcnt_++;
  CHECK(max_authorization_form_id_ < std::numeric_limits<int32>::max());
  auto authorization_form_id = ++max_authorization_form_id_;
  auto &form_ptr = authorization_forms_[authorization_form_id];
  if (form_ptr == nullptr) {
    form_ptr = make_unique<AuthorizationForm>();
  }
  auto &form = *form_ptr;
  form.bot_user_id = bot_user_id;
  form.scope = scope;
  form.public_key = public_key;
  form.nonce = std::move(nonce);
  auto new_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), authorization_form_id, promise = std::move(promise)](
          Result<telegram_api::object_ptr<telegram_api::account_authorizationForm>> r_authorization_form) mutable {
        send_closure(actor_id, &SecureManager::on_get_passport_authorization_form, authorization_form_id,
                     std::move(promise), std::move(r_authorization_form));
      });
  create_actor<GetPassportAuthorizationForm>("GetPassportAuthorizationForm", actor_shared(this), bot_user_id,
                                             std::move(scope), std::move(public_key), std::move(new_promise))
      .release();
}

void SecureManager::on_get_passport_authorization_form(
    int32 authorization_form_id, Promise<TdApiAuthorizationForm> promise,
    Result<telegram_api::object_ptr<telegram_api::account_authorizationForm>> r_authorization_form) {
  auto it = authorization_forms_.find(authorization_form_id);
  CHECK(it != authorization_forms_.end());
  CHECK(it->second != nullptr);
  CHECK(!it->second->is_received);
  if (r_authorization_form.is_error()) {
    authorization_forms_.erase(it);
    return promise.set_error(r_authorization_form.move_as_error());
  }

  auto authorization_form = r_authorization_form.move_as_ok();
  LOG(INFO) << "Receive " << to_string(authorization_form);
  G()->td().get_actor_unsafe()->user_manager_->on_get_users(std::move(authorization_form->users_),
                                                            "on_get_passport_authorization_form");

  vector<vector<SuitableSecureValue>> required_types;
  std::map<SecureValueType, SuitableSecureValue> all_types;
  for (auto &type_ptr : authorization_form->required_types_) {
    CHECK(type_ptr != nullptr);
    vector<SuitableSecureValue> required_type;
    switch (type_ptr->get_id()) {
      case telegram_api::secureRequiredType::ID: {
        auto value = get_suitable_secure_value(move_tl_object_as<telegram_api::secureRequiredType>(type_ptr));
        all_types.emplace(value.type, value);
        required_type.push_back(std::move(value));
        break;
      }
      case telegram_api::secureRequiredTypeOneOf::ID: {
        auto type_one_of = move_tl_object_as<telegram_api::secureRequiredTypeOneOf>(type_ptr);
        for (auto &type : type_one_of->types_) {
          if (type->get_id() == telegram_api::secureRequiredType::ID) {
            auto value = get_suitable_secure_value(move_tl_object_as<telegram_api::secureRequiredType>(type));
            all_types.emplace(value.type, value);
            required_type.push_back(std::move(value));
          } else {
            LOG(ERROR) << to_string(type);
          }
        }
        break;
      }
      default:
        UNREACHABLE();
    }
    if (!required_type.empty()) {
      required_types.push_back(required_type);
    }
  }

  it->second->options = std::move(all_types);
  it->second->values = std::move(authorization_form->values_);
  it->second->errors = std::move(authorization_form->errors_);
  it->second->is_received = true;

  promise.set_value(td_api::make_object<td_api::passportAuthorizationForm>(
      authorization_form_id, get_passport_required_elements_object(required_types),
      authorization_form->privacy_policy_url_));
}

void SecureManager::get_passport_authorization_form_available_elements(int32 authorization_form_id, string password,
                                                                       Promise<TdApiSecureValuesWithErrors> promise) {
  auto it = authorization_forms_.find(authorization_form_id);
  if (it == authorization_forms_.end()) {
    return promise.set_error(Status::Error(400, "Unknown authorization_form_id"));
  }
  CHECK(it->second != nullptr);
  if (!it->second->is_received) {
    return promise.set_error(Status::Error(400, "Authorization form isn't received yet"));
  }

  refcnt_++;
  send_closure(G()->password_manager(), &PasswordManager::get_secure_secret, password,
               PromiseCreator::lambda([self = actor_shared(this), authorization_form_id,
                                       promise = std::move(promise)](Result<secure_storage::Secret> r_secret) mutable {
                 send_closure(self, &SecureManager::on_get_passport_authorization_form_secret, authorization_form_id,
                              std::move(promise), std::move(r_secret));
               }));
}

void SecureManager::on_get_passport_authorization_form_secret(int32 authorization_form_id,
                                                              Promise<TdApiSecureValuesWithErrors> promise,
                                                              Result<secure_storage::Secret> r_secret) {
  auto it = authorization_forms_.find(authorization_form_id);
  if (it == authorization_forms_.end()) {
    return promise.set_error(Status::Error(400, "Authorization form has already been sent"));
  }
  CHECK(it->second != nullptr);
  CHECK(it->second->is_received);
  if (it->second->is_decrypted) {
    return promise.set_error(Status::Error(400, "Authorization form has already been decrypted"));
  }

  if (r_secret.is_error()) {
    auto error = r_secret.move_as_error();
    if (!G()->is_expected_error(error)) {
      LOG(ERROR) << "Receive error instead of secret: " << error;
    }
    if (error.code() <= 0) {
      error = Status::Error(400, error.message());  // TODO error.set_code(400) ?
    }
    return promise.set_error(std::move(error));
  }
  auto secret = r_secret.move_as_ok();

  it->second->is_decrypted = true;

  auto *file_manager = G()->td().get_actor_unsafe()->file_manager_.get();
  std::vector<TdApiSecureValue> values;
  std::map<SecureValueType, SecureValueCredentials> all_credentials;
  for (const auto &suitable_type : it->second->options) {
    auto type = suitable_type.first;
    for (auto &value : it->second->values) {
      if (value == nullptr) {
        continue;
      }
      auto value_type = get_secure_value_type(value->type_);
      if (value_type != type) {
        continue;
      }

      auto r_secure_value =
          decrypt_secure_value(file_manager, secret, get_encrypted_secure_value(file_manager, std::move(value)));
      value = nullptr;
      if (r_secure_value.is_error()) {
        LOG(ERROR) << "Failed to decrypt secure value: " << r_secure_value.error();
        break;
      }

      on_get_secure_value(r_secure_value.ok());

      auto secure_value = r_secure_value.move_as_ok();
      auto r_passport_element = get_passport_element_object(file_manager, secure_value.value);
      if (r_passport_element.is_error()) {
        LOG(ERROR) << "Failed to get passport element object: " << r_passport_element.error();
        break;
      }
      values.push_back(r_passport_element.move_as_ok());
      all_credentials.emplace(type, std::move(secure_value.credentials));

      break;
    }
  }

  auto get_file_index = [](const vector<SecureFileCredentials> &file_credentials, Slice file_hash) -> int32 {
    for (size_t i = 0; i < file_credentials.size(); i++) {
      if (file_credentials[i].hash == file_hash) {
        return narrow_cast<int32>(i);
      }
    }
    return -1;
  };

  vector<td_api::object_ptr<td_api::passportElementError>> errors;
  for (auto &error_ptr : it->second->errors) {
    CHECK(error_ptr != nullptr);
    SecureValueType type = SecureValueType::None;
    td_api::object_ptr<td_api::PassportElementErrorSource> source;
    string message;
    switch (error_ptr->get_id()) {
      case telegram_api::secureValueError::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueError>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        source = td_api::make_object<td_api::passportElementErrorSourceUnspecified>();
        break;
      }
      case telegram_api::secureValueErrorData::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorData>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        string field_name = get_secure_value_data_field_name(type, error->field_);
        if (field_name.empty()) {
          break;
        }
        source = td_api::make_object<td_api::passportElementErrorSourceDataField>(std::move(field_name));
        break;
      }
      case telegram_api::secureValueErrorFile::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorFile>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        int32 file_index = get_file_index(all_credentials[type].files, error->file_hash_.as_slice());
        if (file_index == -1) {
          LOG(ERROR) << "Can't find file with error";
          break;
        }
        source = td_api::make_object<td_api::passportElementErrorSourceFile>(file_index);
        break;
      }
      case telegram_api::secureValueErrorFiles::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorFiles>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        source = td_api::make_object<td_api::passportElementErrorSourceFiles>();
        break;
      }
      case telegram_api::secureValueErrorFrontSide::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorFrontSide>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        source = td_api::make_object<td_api::passportElementErrorSourceFrontSide>();
        break;
      }
      case telegram_api::secureValueErrorReverseSide::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorReverseSide>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        source = td_api::make_object<td_api::passportElementErrorSourceReverseSide>();
        break;
      }
      case telegram_api::secureValueErrorSelfie::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorSelfie>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        source = td_api::make_object<td_api::passportElementErrorSourceSelfie>();
        break;
      }
      case telegram_api::secureValueErrorTranslationFile::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorTranslationFile>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        int32 file_index = get_file_index(all_credentials[type].translations, error->file_hash_.as_slice());
        if (file_index == -1) {
          LOG(ERROR) << "Can't find translation file with error";
          break;
        }
        source = td_api::make_object<td_api::passportElementErrorSourceTranslationFile>(file_index);
        break;
      }
      case telegram_api::secureValueErrorTranslationFiles::ID: {
        auto error = move_tl_object_as<telegram_api::secureValueErrorTranslationFiles>(error_ptr);
        type = get_secure_value_type(error->type_);
        message = std::move(error->text_);
        source = td_api::make_object<td_api::passportElementErrorSourceTranslationFiles>();
        break;
      }
      default:
        UNREACHABLE();
    }
    if (source == nullptr) {
      continue;
    }

    errors.push_back(td_api::make_object<td_api::passportElementError>(get_passport_element_type_object(type), message,
                                                                       std::move(source)));
  }

  promise.set_value(td_api::make_object<td_api::passportElementsWithErrors>(std::move(values), std::move(errors)));
}

void SecureManager::send_passport_authorization_form(int32 authorization_form_id, std::vector<SecureValueType> types,
                                                     Promise<> promise) {
  auto it = authorization_forms_.find(authorization_form_id);
  if (it == authorization_forms_.end()) {
    return promise.set_error(Status::Error(400, "Unknown authorization_form_id"));
  }
  CHECK(it->second != nullptr);
  if (!it->second->is_received) {
    return promise.set_error(Status::Error(400, "Authorization form isn't received yet"));
  }
  // there is no need to check for is_decrypted
  if (types.empty()) {
    return promise.set_error(Status::Error(400, "Types must be non-empty"));
  }

  std::vector<SecureValueCredentials> credentials;
  credentials.reserve(types.size());
  for (auto type : types) {
    auto value_it = secure_value_cache_.find(type);
    if (value_it == secure_value_cache_.end()) {
      return promise.set_error(Status::Error(400, "Passport Element with the specified type is not found"));
    }
    credentials.push_back(value_it->second.credentials);
  }

  std::vector<telegram_api::object_ptr<telegram_api::secureValueHash>> hashes;
  for (auto &c : credentials) {
    hashes.push_back(telegram_api::make_object<telegram_api::secureValueHash>(get_input_secure_value_type(c.type),
                                                                              BufferSlice(c.hash)));
    auto options_it = it->second->options.find(c.type);
    if (options_it == it->second->options.end()) {
      return promise.set_error(Status::Error(400, "Passport Element with the specified type was not requested"));
    }
    auto &options = options_it->second;
    if (!options.is_selfie_required) {
      c.selfie = optional<SecureFileCredentials>();
    }
    if (!options.is_translation_required) {
      c.translations.clear();
    }
  }

  auto r_encrypted_credentials =
      get_encrypted_credentials(credentials, it->second->nonce, it->second->public_key,
                                it->second->scope[0] == '{' && it->second->scope.back() == '}');
  if (r_encrypted_credentials.is_error()) {
    return promise.set_error(r_encrypted_credentials.move_as_error());
  }

  auto td_query = telegram_api::account_acceptAuthorization(
      it->second->bot_user_id.get(), it->second->scope, it->second->public_key, std::move(hashes),
      get_secure_credentials_encrypted_object(r_encrypted_credentials.move_as_ok()));
  auto query = G()->net_query_creator().create(td_query);
  auto new_promise = PromiseCreator::lambda([promise =
                                                 std::move(promise)](Result<NetQueryPtr> r_net_query_ptr) mutable {
    TRY_STATUS_PROMISE(promise, fetch_result<telegram_api::account_acceptAuthorization>(std::move(r_net_query_ptr)));
    promise.set_value(Unit());
  });
  send_with_promise(std::move(query), std::move(new_promise));
}

void SecureManager::get_preferred_country_language(string country_code,
                                                   Promise<td_api::object_ptr<td_api::text>> promise) {
  refcnt_++;
  for (auto &c : country_code) {
    c = to_upper(c);
  }
  create_actor<GetPassportConfig>("GetPassportConfig", actor_shared(this), std::move(country_code), std::move(promise))
      .release();
}

void SecureManager::hangup() {
  container_.for_each(
      [](auto id, Promise<NetQueryPtr> &promise) { promise.set_error(Global::request_aborted_error()); });
  dec_refcnt();
}

void SecureManager::hangup_shared() {
  dec_refcnt();
}

void SecureManager::dec_refcnt() {
  refcnt_--;
  if (refcnt_ == 0) {
    stop();
  }
}

void SecureManager::on_result(NetQueryPtr query) {
  auto token = get_link_token();
  container_.extract(token).set_value(std::move(query));
}

void SecureManager::send_with_promise(NetQueryPtr query, Promise<NetQueryPtr> promise) {
  auto id = container_.create(std::move(promise));
  G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this, id));
}

}  // namespace td
