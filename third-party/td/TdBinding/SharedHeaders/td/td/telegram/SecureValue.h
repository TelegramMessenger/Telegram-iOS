//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/SecureStorage.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/optional.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <utility>

namespace td {

class FileManager;

enum class SecureValueType : int32 {
  None,
  PersonalDetails,
  Passport,
  DriverLicense,
  IdentityCard,
  InternalPassport,
  Address,
  UtilityBill,
  BankStatement,
  RentalAgreement,
  PassportRegistration,
  TemporaryRegistration,
  PhoneNumber,
  EmailAddress
};

StringBuilder &operator<<(StringBuilder &string_builder, const SecureValueType &type);

vector<SecureValueType> unique_secure_value_types(vector<SecureValueType> types);

SecureValueType get_secure_value_type(const tl_object_ptr<telegram_api::SecureValueType> &secure_value_type);
SecureValueType get_secure_value_type_td_api(const tl_object_ptr<td_api::PassportElementType> &passport_element_type);

vector<SecureValueType> get_secure_value_types(
    const vector<tl_object_ptr<telegram_api::SecureValueType>> &secure_value_types);
vector<SecureValueType> get_secure_value_types_td_api(
    const vector<tl_object_ptr<td_api::PassportElementType>> &secure_value_types);

td_api::object_ptr<td_api::PassportElementType> get_passport_element_type_object(SecureValueType type);
td_api::object_ptr<telegram_api::SecureValueType> get_input_secure_value_type(SecureValueType type);

vector<td_api::object_ptr<td_api::PassportElementType>> get_passport_element_types_object(
    const vector<SecureValueType> &types);

struct SuitableSecureValue {
  SecureValueType type;
  bool is_selfie_required;
  bool is_translation_required;
  bool is_native_name_required;
};

SuitableSecureValue get_suitable_secure_value(
    const tl_object_ptr<telegram_api::secureRequiredType> &secure_required_type);

td_api::object_ptr<td_api::passportSuitableElement> get_passport_suitable_element_object(
    const SuitableSecureValue &required_element);

td_api::object_ptr<td_api::passportRequiredElement> get_passport_required_element_object(
    const vector<SuitableSecureValue> &required_element);

vector<td_api::object_ptr<td_api::passportRequiredElement>> get_passport_required_elements_object(
    const vector<vector<SuitableSecureValue>> &required_elements);

string get_secure_value_data_field_name(SecureValueType type, string field_name);

struct DatedFile {
  FileId file_id;
  int32 date = 0;
};

bool operator==(const DatedFile &lhs, const DatedFile &rhs);
bool operator!=(const DatedFile &lhs, const DatedFile &rhs);

struct EncryptedSecureFile {
  DatedFile file;
  string file_hash;
  string encrypted_secret;
};

bool operator==(const EncryptedSecureFile &lhs, const EncryptedSecureFile &rhs);
bool operator!=(const EncryptedSecureFile &lhs, const EncryptedSecureFile &rhs);

EncryptedSecureFile get_encrypted_secure_file(FileManager *file_manager,
                                              tl_object_ptr<telegram_api::SecureFile> &&secure_file_ptr);

vector<EncryptedSecureFile> get_encrypted_secure_files(FileManager *file_manager,
                                                       vector<tl_object_ptr<telegram_api::SecureFile>> &&secure_files);

struct SecureInputFile {
  FileUploadId file_upload_id;
  telegram_api::object_ptr<telegram_api::InputSecureFile> input_file;
};
telegram_api::object_ptr<telegram_api::InputSecureFile> get_input_secure_file_object(FileManager *file_manager,
                                                                                     const EncryptedSecureFile &file,
                                                                                     SecureInputFile &input_file);

vector<telegram_api::object_ptr<telegram_api::InputSecureFile>> get_input_secure_files_object(
    FileManager *file_manager, const vector<EncryptedSecureFile> &file, vector<SecureInputFile> &input_files);

struct EncryptedSecureData {
  string data;
  string hash;
  string encrypted_secret;
};

bool operator==(const EncryptedSecureData &lhs, const EncryptedSecureData &rhs);
bool operator!=(const EncryptedSecureData &lhs, const EncryptedSecureData &rhs);

EncryptedSecureData get_encrypted_secure_data(tl_object_ptr<telegram_api::secureData> &&secure_data);

telegram_api::object_ptr<telegram_api::secureData> get_secure_data_object(const EncryptedSecureData &data);

struct EncryptedSecureValue {
  SecureValueType type = SecureValueType::None;
  EncryptedSecureData data;
  vector<EncryptedSecureFile> files;
  EncryptedSecureFile front_side;
  EncryptedSecureFile reverse_side;
  EncryptedSecureFile selfie;
  vector<EncryptedSecureFile> translations;
  string hash;
};

bool operator==(const EncryptedSecureValue &lhs, const EncryptedSecureValue &rhs);
bool operator!=(const EncryptedSecureValue &lhs, const EncryptedSecureValue &rhs);

EncryptedSecureValue get_encrypted_secure_value(FileManager *file_manager,
                                                tl_object_ptr<telegram_api::secureValue> &&secure_value);

vector<EncryptedSecureValue> get_encrypted_secure_values(
    FileManager *file_manager, vector<tl_object_ptr<telegram_api::secureValue>> &&secure_values);

td_api::object_ptr<td_api::encryptedPassportElement> get_encrypted_passport_element_object(
    FileManager *file_manager, const EncryptedSecureValue &value);
telegram_api::object_ptr<telegram_api::inputSecureValue> get_input_secure_value_object(
    FileManager *file_manager, const EncryptedSecureValue &value, vector<SecureInputFile> &files,
    optional<SecureInputFile> &front_side, optional<SecureInputFile> &reverse_side, optional<SecureInputFile> &selfie,
    vector<SecureInputFile> &translations);

vector<td_api::object_ptr<td_api::encryptedPassportElement>> get_encrypted_passport_element_object(
    FileManager *file_manager, const vector<EncryptedSecureValue> &values);

struct EncryptedSecureCredentials {
  string data;
  string hash;
  string encrypted_secret;
};

bool operator==(const EncryptedSecureCredentials &lhs, const EncryptedSecureCredentials &rhs);
bool operator!=(const EncryptedSecureCredentials &lhs, const EncryptedSecureCredentials &rhs);

EncryptedSecureCredentials get_encrypted_secure_credentials(
    tl_object_ptr<telegram_api::secureCredentialsEncrypted> &&credentials);

telegram_api::object_ptr<telegram_api::secureCredentialsEncrypted> get_secure_credentials_encrypted_object(
    const EncryptedSecureCredentials &credentials);
td_api::object_ptr<td_api::encryptedCredentials> get_encrypted_credentials_object(
    const EncryptedSecureCredentials &credentials);

struct SecureDataCredentials {
  string secret;
  string hash;
};
struct SecureFileCredentials {
  string secret;
  string hash;
};

struct SecureValueCredentials {
  SecureValueType type = SecureValueType::None;
  string hash;
  optional<SecureDataCredentials> data;
  std::vector<SecureFileCredentials> files;
  optional<SecureFileCredentials> front_side;
  optional<SecureFileCredentials> reverse_side;
  optional<SecureFileCredentials> selfie;
  std::vector<SecureFileCredentials> translations;
};

Result<EncryptedSecureCredentials> get_encrypted_credentials(const std::vector<SecureValueCredentials> &credentials,
                                                             Slice nonce, Slice public_key,
                                                             bool rename_payload_to_nonce);

class SecureValue {
 public:
  SecureValueType type = SecureValueType::None;
  string data;
  vector<DatedFile> files;
  DatedFile front_side;
  DatedFile reverse_side;
  DatedFile selfie;
  vector<DatedFile> translations;
};

struct SecureValueWithCredentials {
  SecureValue value;
  SecureValueCredentials credentials;
};

Result<SecureValue> get_secure_value(FileManager *file_manager,
                                     td_api::object_ptr<td_api::InputPassportElement> &&input_passport_element);

Result<td_api::object_ptr<td_api::PassportElement>> get_passport_element_object(FileManager *file_manager,
                                                                                const SecureValue &value);

td_api::object_ptr<td_api::passportElements> get_passport_elements_object(FileManager *file_manager,
                                                                          const vector<SecureValue> &values);

Result<SecureValueWithCredentials> decrypt_secure_value(FileManager *file_manager, const secure_storage::Secret &secret,
                                                        const EncryptedSecureValue &encrypted_secure_value);
Result<vector<SecureValueWithCredentials>> decrypt_secure_values(
    FileManager *file_manager, const secure_storage::Secret &secret,
    const vector<EncryptedSecureValue> &encrypted_secure_values);

EncryptedSecureValue encrypt_secure_value(FileManager *file_manager, const secure_storage::Secret &master_secret,
                                          const SecureValue &secure_value);

}  // namespace td
