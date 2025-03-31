//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SecretInputMedia.h"

#include "td/telegram/files/FileManager.h"
#include "td/telegram/SecretChatLayer.h"

#include "td/utils/misc.h"

namespace td {

SecretInputMedia::SecretInputMedia(telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
                                   BufferSlice &&thumbnail, Dimensions thumbnail_dimensions, const string &mime_type,
                                   const FileView &file_view,
                                   vector<tl_object_ptr<secret_api::DocumentAttribute>> &&attributes,
                                   const string &caption, int32 layer)
    : input_file_(std::move(input_file)) {
  auto &encryption_key = file_view.encryption_key();
  auto size = file_view.size();
  if (layer >= static_cast<int32>(SecretChatLayer::SupportBigFiles)) {
    decrypted_media_ = secret_api::make_object<secret_api::decryptedMessageMediaDocument>(
        std::move(thumbnail), thumbnail_dimensions.width, thumbnail_dimensions.height, mime_type, size,
        BufferSlice(encryption_key.key_slice()), BufferSlice(encryption_key.iv_slice()), std::move(attributes),
        caption);
    return;
  }
  if (size <= (2000 << 20)) {
    decrypted_media_ = secret_api::make_object<secret_api::decryptedMessageMediaDocument46>(
        std::move(thumbnail), thumbnail_dimensions.width, thumbnail_dimensions.height, mime_type,
        narrow_cast<int32>(size), BufferSlice(encryption_key.key_slice()), BufferSlice(encryption_key.iv_slice()),
        std::move(attributes), caption);
    return;
  }
  input_file_ = nullptr;
}

}  // namespace td
