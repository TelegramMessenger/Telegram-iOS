//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileHashUploader.h"

#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/MimeType.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/Status.h"

namespace td {

void FileHashUploader::start_up() {
  auto status = init();
  if (status.is_error()) {
    callback_->on_error(std::move(status));
    stop_flag_ = true;
    return;
  }
}

Status FileHashUploader::init() {
  TRY_RESULT(fd, FileFd::open(local_.path_, FileFd::Read));
  TRY_RESULT(file_size, fd.get_size());
  if (file_size != size_) {
    return Status::Error("Size mismatch");
  }
  fd_ = BufferedFd<FileFd>(std::move(fd));
  sha256_state_.init();

  resource_state_.set_unit_size(1024);
  resource_state_.update_estimated_limit(size_);
  return Status::OK();
}

void FileHashUploader::loop() {
  if (stop_flag_) {
    return;
  }

  auto status = loop_impl();
  if (status.is_error()) {
    callback_->on_error(std::move(status));
    stop_flag_ = true;
    return;
  }
}

Status FileHashUploader::loop_impl() {
  if (state_ == State::CalcSha) {
    TRY_STATUS(loop_sha());
  }
  if (state_ == State::NetRequest) {
    // messages.getDocumentByHash#338e2464 sha256:bytes size:long mime_type:string = Document;
    auto hash = BufferSlice(32);
    sha256_state_.extract(hash.as_mutable_slice(), true);
    auto mime_type = MimeType::from_extension(PathView(local_.path_).extension(), "image/gif");
    auto query = telegram_api::messages_getDocumentByHash(std::move(hash), size_, std::move(mime_type));
    LOG(INFO) << "Send getDocumentByHash request: " << to_string(query);
    auto ptr = G()->net_query_creator().create(query);
    G()->net_query_dispatcher().dispatch_with_callback(std::move(ptr), actor_shared(this));
    state_ = State::WaitNetResult;
  }
  return Status::OK();
}

Status FileHashUploader::loop_sha() {
  auto limit = resource_state_.unused();
  if (limit == 0) {
    return Status::OK();
  }
  if (limit > size_left_) {
    limit = size_left_;
  }
  resource_state_.start_use(limit);

  fd_.get_poll_info().add_flags(PollFlags::Read());
  TRY_RESULT(read_size, fd_.flush_read(static_cast<size_t>(limit)));
  if (read_size != static_cast<size_t>(limit)) {
    return Status::Error("Unexpected end of file");
  }
  while (true) {
    auto ready = fd_.input_buffer().prepare_read();
    if (ready.empty()) {
      break;
    }
    sha256_state_.feed(ready);
    fd_.input_buffer().confirm_read(ready.size());
  }
  resource_state_.stop_use(limit);

  size_left_ -= narrow_cast<int64>(read_size);
  CHECK(size_left_ >= 0);
  if (size_left_ == 0) {
    state_ = State::NetRequest;
    return Status::OK();
  }
  return Status::OK();
}

void FileHashUploader::on_result(NetQueryPtr net_query) {
  auto status = on_result_impl(std::move(net_query));
  if (status.is_error()) {
    callback_->on_error(std::move(status));
    stop_flag_ = true;
    return;
  }
}

Status FileHashUploader::on_result_impl(NetQueryPtr net_query) {
  TRY_RESULT(res, fetch_result<telegram_api::messages_getDocumentByHash>(std::move(net_query)));

  switch (res->get_id()) {
    case telegram_api::documentEmpty::ID:
      return Status::Error("Document is not found by hash");
    case telegram_api::document::ID: {
      auto document = move_tl_object_as<telegram_api::document>(res);
      if (!DcId::is_valid(document->dc_id_)) {
        return Status::Error("Found document has invalid DcId");
      }
      callback_->on_ok(FullRemoteFileLocation(FileType::Document, document->id_, document->access_hash_,
                                              DcId::internal(document->dc_id_),
                                              document->file_reference_.as_slice().str()));

      stop_flag_ = true;
      return Status::OK();
    }
    default:
      UNREACHABLE();
      return Status::Error("UNREACHABLE");
  }
}

}  // namespace td
