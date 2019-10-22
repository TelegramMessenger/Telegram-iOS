/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/Status.h"
#include "td/utils/SharedSlice.h"

#include "KeyValue.h"

#include <string>

namespace tonlib {
struct DecryptedKey;
class KeyStorage {
 public:
  struct Key {
    td::SecureString public_key;
    td::SecureString secret;
  };
  struct InputKey {
    Key key;
    td::SecureString local_password;
  };
  struct ExportedKey {
    std::vector<td::SecureString> mnemonic_words;
  };
  struct ExportedPemKey {
    td::SecureString pem;
  };
  struct ExportedEncryptedKey {
    td::SecureString data;
  };
  struct PrivateKey {
    td::SecureString private_key;
  };

  void set_key_value(std::shared_ptr<KeyValue> kv);

  td::Result<Key> create_new_key(td::Slice local_password, td::Slice key_password, td::Slice entropy);

  td::Result<ExportedKey> export_key(InputKey input_key);
  td::Result<ExportedPemKey> export_pem_key(InputKey input_key, td::Slice key_password);
  td::Result<ExportedEncryptedKey> export_encrypted_key(InputKey input_key, td::Slice key_password);
  td::Result<Key> change_local_password(InputKey input_key, td::Slice new_local_password);

  td::Status delete_key(const Key& key);
  td::Status delete_all_keys();

  td::Result<Key> import_key(td::Slice local_password, td::Slice mnemonic_password, ExportedKey exported_key);
  td::Result<Key> import_pem_key(td::Slice local_password, td::Slice key_password, ExportedPemKey exported_key);
  td::Result<Key> import_encrypted_key(td::Slice local_password, td::Slice key_password,
                                       ExportedEncryptedKey exported_key);

  td::Result<PrivateKey> load_private_key(InputKey input_key);

  static PrivateKey fake_private_key();
  static InputKey fake_input_key();
  static bool is_fake_input_key(InputKey& input_key);

 private:
  std::shared_ptr<KeyValue> kv_;

  td::Result<Key> save_key(const DecryptedKey& mnemonic, td::Slice local_password);
  td::Result<DecryptedKey> export_decrypted_key(InputKey input_key);
};
}  // namespace tonlib
