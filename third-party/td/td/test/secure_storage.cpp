//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SecureStorage.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tests.h"

TEST(SecureStorage, secret) {
  auto secret = td::secure_storage::Secret::create_new();
  td::string key = "cucumber";
  auto encrypted_secret = secret.encrypt(key, "", td::secure_storage::EnryptionAlgorithm::Sha512);
  ASSERT_TRUE(encrypted_secret.as_slice() != secret.as_slice());
  auto decrypted_secret = encrypted_secret.decrypt(key, "", td::secure_storage::EnryptionAlgorithm::Sha512).ok();
  ASSERT_TRUE(secret.as_slice() == decrypted_secret.as_slice());
  ASSERT_TRUE(encrypted_secret.decrypt("notcucumber", "", td::secure_storage::EnryptionAlgorithm::Sha512).is_error());
}

TEST(SecureStorage, simple) {
  td::BufferSlice value("Small tale about cucumbers");
  auto value_secret = td::secure_storage::Secret::create_new();

  {
    td::secure_storage::BufferSliceDataView value_view(value.copy());
    td::BufferSlice prefix = td::secure_storage::gen_random_prefix(value_view.size());
    td::secure_storage::BufferSliceDataView prefix_view(std::move(prefix));
    td::secure_storage::ConcatDataView full_value_view(prefix_view, value_view);
    auto hash = td::secure_storage::calc_value_hash(full_value_view).move_as_ok();

    td::secure_storage::Encryptor encryptor(
        td::secure_storage::calc_aes_cbc_state_sha512(PSLICE() << value_secret.as_slice() << hash.as_slice()),
        full_value_view);
    auto encrypted_value = encryptor.pread(0, encryptor.size()).move_as_ok();

    td::secure_storage::Decryptor decryptor(
        td::secure_storage::calc_aes_cbc_state_sha512(PSLICE() << value_secret.as_slice() << hash.as_slice()));
    auto res = decryptor.append(encrypted_value.copy()).move_as_ok();
    auto decrypted_hash = decryptor.finish().ok();
    ASSERT_TRUE(decrypted_hash.as_slice() == hash.as_slice());
    ASSERT_TRUE(res.as_slice() == value.as_slice());
  }

  {
    auto encrypted_value = td::secure_storage::encrypt_value(value_secret, value.as_slice()).move_as_ok();
    auto decrypted_value =
        td::secure_storage::decrypt_value(value_secret, encrypted_value.hash, encrypted_value.data.as_slice())
            .move_as_ok();
    ASSERT_TRUE(decrypted_value.as_slice() == value.as_slice());
  }

  {
    td::string value_path = "value.txt";
    td::string encrypted_path = "encrypted.txt";
    td::string decrypted_path = "decrypted.txt";
    td::unlink(value_path).ignore();
    td::unlink(encrypted_path).ignore();
    td::unlink(decrypted_path).ignore();
    td::string file_value(100000, 'a');
    td::write_file(value_path, file_value).ensure();
    auto hash = td::secure_storage::encrypt_file(value_secret, value_path, encrypted_path).move_as_ok();
    td::secure_storage::decrypt_file(value_secret, hash, encrypted_path, decrypted_path).ensure();
    ASSERT_TRUE(td::read_file(decrypted_path).move_as_ok().as_slice() == file_value);
    td::unlink(value_path).ignore();
    td::unlink(encrypted_path).ignore();
    td::unlink(decrypted_path).ignore();
  }
}
