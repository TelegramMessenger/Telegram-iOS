//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/Document.h"
#include "td/telegram/EncryptedFile.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/PhotoFormat.h"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/WaitFreeHashMap.h"

#include <utility>

namespace td {

class MultiPromiseActor;
class Td;

class DocumentsManager {
 public:
  explicit DocumentsManager(Td *td);
  DocumentsManager(const DocumentsManager &) = delete;
  DocumentsManager &operator=(const DocumentsManager &) = delete;
  DocumentsManager(DocumentsManager &&) = delete;
  DocumentsManager &operator=(DocumentsManager &&) = delete;
  ~DocumentsManager();

  class RemoteDocument {
   public:
    tl_object_ptr<telegram_api::document> document;
    // or
    unique_ptr<EncryptedFile> secret_file;
    tl_object_ptr<secret_api::decryptedMessageMediaDocument> secret_document;
    // or
    tl_object_ptr<telegram_api::WebDocument> web_document;
    PhotoSize thumbnail;

    vector<tl_object_ptr<telegram_api::DocumentAttribute>> attributes;

    RemoteDocument(tl_object_ptr<telegram_api::document> &&server_document)
        : document(std::move(server_document))
        , secret_file(nullptr)
        , secret_document(nullptr)
        , web_document(nullptr)
        , thumbnail()
        , attributes(std::move(document->attributes_)) {
    }

    RemoteDocument(tl_object_ptr<telegram_api::WebDocument> &&web_document, PhotoSize thumbnail,
                   vector<tl_object_ptr<telegram_api::DocumentAttribute>> &&attributes)
        : document(nullptr)
        , secret_file(nullptr)
        , secret_document(nullptr)
        , web_document(std::move(web_document))
        , thumbnail(std::move(thumbnail))
        , attributes(std::move(attributes)) {
    }

    RemoteDocument(unique_ptr<EncryptedFile> &&secret_file,
                   tl_object_ptr<secret_api::decryptedMessageMediaDocument> &&secret_document,
                   vector<tl_object_ptr<telegram_api::DocumentAttribute>> &&attributes)
        : document(nullptr)
        , secret_file(std::move(secret_file))
        , secret_document(std::move(secret_document))
        , web_document(nullptr)
        , thumbnail()
        , attributes(std::move(attributes)) {
    }
  };

  tl_object_ptr<td_api::document> get_document_object(FileId file_id, PhotoFormat thumbnail_format) const;

  enum class Subtype : int32 { Background, Pattern, Ringtone, Story, Other };

  Document on_get_document(RemoteDocument remote_document, DialogId owner_dialog_id, bool is_self_destructing,
                           MultiPromiseActor *load_data_multipromise_ptr = nullptr,
                           Document::Type default_document_type = Document::Type::General,
                           Subtype document_subtype = Subtype::Other);

  void create_document(FileId file_id, string minithumbnail, PhotoSize thumbnail, string file_name, string mime_type,
                       bool replace);

  SecretInputMedia get_secret_input_media(FileId document_file_id,
                                          telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
                                          const string &caption, BufferSlice thumbnail, int32 layer) const;

  tl_object_ptr<telegram_api::InputMedia> get_input_media(
      FileId file_id, telegram_api::object_ptr<telegram_api::InputFile> input_file,
      telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail) const;

  FileId get_document_thumbnail_file_id(FileId file_id) const;

  void delete_document_thumbnail(FileId file_id);

  Slice get_document_file_name(FileId file_id) const;

  Slice get_document_mime_type(FileId file_id) const;

  FileId dup_document(FileId new_id, FileId old_id);

  void merge_documents(FileId new_id, FileId old_id);

  template <class StorerT>
  void store_document(FileId file_id, StorerT &storer) const;

  template <class ParserT>
  FileId parse_document(ParserT &parser);

  string get_document_search_text(FileId file_id) const;

 private:
  class GeneralDocument {
   public:
    string file_name;
    string mime_type;
    string minithumbnail;
    PhotoSize thumbnail;
    FileId file_id;
  };

  const GeneralDocument *get_document(FileId file_id) const;

  FileId on_get_document(unique_ptr<GeneralDocument> new_document, bool replace);

  Td *td_;
  WaitFreeHashMap<FileId, unique_ptr<GeneralDocument>, FileIdHash> documents_;
};

}  // namespace td
