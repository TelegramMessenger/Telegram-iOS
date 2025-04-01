//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Dimensions.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"

namespace td {

class FileView;

struct SecretInputMedia {
  telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file_;
  tl_object_ptr<secret_api::DecryptedMessageMedia> decrypted_media_;

  SecretInputMedia() = default;

  SecretInputMedia(telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
                   tl_object_ptr<secret_api::DecryptedMessageMedia> decrypted_media)
      : input_file_(std::move(input_file)), decrypted_media_(std::move(decrypted_media)) {
  }

  SecretInputMedia(telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file, BufferSlice &&thumbnail,
                   Dimensions thumbnail_dimensions, const string &mime_type, const FileView &file_view,
                   vector<tl_object_ptr<secret_api::DocumentAttribute>> &&attributes, const string &caption,
                   int32 layer);

  bool empty() const {
    return decrypted_media_ == nullptr;
  }
};

}  // namespace td
