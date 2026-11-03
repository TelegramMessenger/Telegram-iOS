#pragma once

#include "td/tl/TlObject.h"

#include "td/utils/buffer.h"

#include <cstdint>
#include <utility>
#include <vector>

namespace td {
class TlStorerCalcLength;
class TlStorerUnsafe;
class TlStorerToString;
class TlParser;

namespace secret_api {

using int32 = std::int32_t;
using int53 = std::int64_t;
using int64 = std::int64_t;

using string = std::string;

using bytes = BufferSlice;

using secure_string = std::string;

using secure_bytes = BufferSlice;

template <class Type>
using array = std::vector<Type>;

using BaseObject = ::td::TlObject;

template <class Type>
using object_ptr = ::td::tl_object_ptr<Type>;

template <class Type, class... Args>
object_ptr<Type> make_object(Args &&... args) {
  return object_ptr<Type>(new Type(std::forward<Args>(args)...));
}

template <class ToType, class FromType>
object_ptr<ToType> move_object_as(FromType &&from) {
  return object_ptr<ToType>(static_cast<ToType *>(from.release()));
}

std::string to_string(const BaseObject &value);

template <class T>
std::string to_string(const object_ptr<T> &value) {
  if (value == nullptr) {
    return "null";
  }

  return to_string(*value);
}

template <class T>
std::string to_string(const std::vector<object_ptr<T>> &values) {
  std::string result = "{\n";
  for (const auto &value : values) {
    if (value == nullptr) {
      result += "null\n";
    } else {
      result += to_string(*value);
    }
  }
  result += "}\n";
  return result;
}

class Object: public TlObject {
 public:

  static object_ptr<Object> fetch(TlParser &p);
};

class Function: public TlObject {
 public:

  static object_ptr<Function> fetch(TlParser &p);
};

class DecryptedMessageAction;

class DecryptedMessageMedia;

class MessageEntity;

class DecryptedMessage: public Object {
 public:

  static object_ptr<DecryptedMessage> fetch(TlParser &p);
};

class decryptedMessage8 final : public DecryptedMessage {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 random_id_;
  bytes random_bytes_;
  string message_;
  object_ptr<DecryptedMessageMedia> media_;

  decryptedMessage8(int64 random_id_, bytes &&random_bytes_, string const &message_, object_ptr<DecryptedMessageMedia> &&media_);

  static const std::int32_t ID = 528568095;

  static object_ptr<DecryptedMessage> fetch(TlParser &p);

  explicit decryptedMessage8(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageService8 final : public DecryptedMessage {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 random_id_;
  bytes random_bytes_;
  object_ptr<DecryptedMessageAction> action_;

  decryptedMessageService8(int64 random_id_, bytes &&random_bytes_, object_ptr<DecryptedMessageAction> &&action_);

  static const std::int32_t ID = -1438109059;

  static object_ptr<DecryptedMessage> fetch(TlParser &p);

  explicit decryptedMessageService8(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessage23 final : public DecryptedMessage {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 random_id_;
  int32 ttl_;
  string message_;
  object_ptr<DecryptedMessageMedia> media_;

  decryptedMessage23(int64 random_id_, int32 ttl_, string const &message_, object_ptr<DecryptedMessageMedia> &&media_);

  static const std::int32_t ID = 541931640;

  static object_ptr<DecryptedMessage> fetch(TlParser &p);

  explicit decryptedMessage23(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageService final : public DecryptedMessage {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 random_id_;
  object_ptr<DecryptedMessageAction> action_;

  decryptedMessageService(int64 random_id_, object_ptr<DecryptedMessageAction> &&action_);

  static const std::int32_t ID = 1930838368;

  static object_ptr<DecryptedMessage> fetch(TlParser &p);

  explicit decryptedMessageService(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessage46 final : public DecryptedMessage {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 flags_;
  int64 random_id_;
  int32 ttl_;
  string message_;
  object_ptr<DecryptedMessageMedia> media_;
  array<object_ptr<MessageEntity>> entities_;
  string via_bot_name_;
  int64 reply_to_random_id_;
  enum Flags : std::int32_t { MEDIA_MASK = 512, ENTITIES_MASK = 128, VIA_BOT_NAME_MASK = 2048, REPLY_TO_RANDOM_ID_MASK = 8 };

  decryptedMessage46();

  decryptedMessage46(int32 flags_, int64 random_id_, int32 ttl_, string const &message_, object_ptr<DecryptedMessageMedia> &&media_, array<object_ptr<MessageEntity>> &&entities_, string const &via_bot_name_, int64 reply_to_random_id_);

  static const std::int32_t ID = 917541342;

  static object_ptr<DecryptedMessage> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessage final : public DecryptedMessage {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 flags_;
  bool silent_;
  int64 random_id_;
  int32 ttl_;
  string message_;
  object_ptr<DecryptedMessageMedia> media_;
  array<object_ptr<MessageEntity>> entities_;
  string via_bot_name_;
  int64 reply_to_random_id_;
  int64 grouped_id_;
  enum Flags : std::int32_t { MEDIA_MASK = 512, ENTITIES_MASK = 128, VIA_BOT_NAME_MASK = 2048, REPLY_TO_RANDOM_ID_MASK = 8, GROUPED_ID_MASK = 131072 };

  decryptedMessage();

  decryptedMessage(int32 flags_, bool silent_, int64 random_id_, int32 ttl_, string const &message_, object_ptr<DecryptedMessageMedia> &&media_, array<object_ptr<MessageEntity>> &&entities_, string const &via_bot_name_, int64 reply_to_random_id_, int64 grouped_id_);

  static const std::int32_t ID = -1848883596;

  static object_ptr<DecryptedMessage> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class SendMessageAction;

class DecryptedMessageAction: public Object {
 public:

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);
};

class decryptedMessageActionSetMessageTTL final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 ttl_seconds_;

  explicit decryptedMessageActionSetMessageTTL(int32 ttl_seconds_);

  static const std::int32_t ID = -1586283796;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionSetMessageTTL(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionReadMessages final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<int64> random_ids_;

  explicit decryptedMessageActionReadMessages(array<int64> &&random_ids_);

  static const std::int32_t ID = 206520510;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionReadMessages(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionDeleteMessages final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<int64> random_ids_;

  explicit decryptedMessageActionDeleteMessages(array<int64> &&random_ids_);

  static const std::int32_t ID = 1700872964;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionDeleteMessages(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionScreenshotMessages final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<int64> random_ids_;

  explicit decryptedMessageActionScreenshotMessages(array<int64> &&random_ids_);

  static const std::int32_t ID = -1967000459;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionScreenshotMessages(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionFlushHistory final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 1729750108;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionResend final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 start_seq_no_;
  int32 end_seq_no_;

  decryptedMessageActionResend(int32 start_seq_no_, int32 end_seq_no_);

  static const std::int32_t ID = 1360072880;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionResend(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionNotifyLayer final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 layer_;

  explicit decryptedMessageActionNotifyLayer(int32 layer_);

  static const std::int32_t ID = -217806717;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionNotifyLayer(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionTyping final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  object_ptr<SendMessageAction> action_;

  explicit decryptedMessageActionTyping(object_ptr<SendMessageAction> &&action_);

  static const std::int32_t ID = -860719551;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionTyping(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionRequestKey final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 exchange_id_;
  bytes g_a_;

  decryptedMessageActionRequestKey(int64 exchange_id_, bytes &&g_a_);

  static const std::int32_t ID = -204906213;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionRequestKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionAcceptKey final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 exchange_id_;
  bytes g_b_;
  int64 key_fingerprint_;

  decryptedMessageActionAcceptKey(int64 exchange_id_, bytes &&g_b_, int64 key_fingerprint_);

  static const std::int32_t ID = 1877046107;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionAcceptKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionAbortKey final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 exchange_id_;

  explicit decryptedMessageActionAbortKey(int64 exchange_id_);

  static const std::int32_t ID = -586814357;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionAbortKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionCommitKey final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 exchange_id_;
  int64 key_fingerprint_;

  decryptedMessageActionCommitKey(int64 exchange_id_, int64 key_fingerprint_);

  static const std::int32_t ID = -332526693;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  explicit decryptedMessageActionCommitKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageActionNoop final : public DecryptedMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -1473258141;

  static object_ptr<DecryptedMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class DecryptedMessage;

class decryptedMessageLayer final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes random_bytes_;
  int32 layer_;
  int32 in_seq_no_;
  int32 out_seq_no_;
  object_ptr<DecryptedMessage> message_;

  decryptedMessageLayer(bytes &&random_bytes_, int32 layer_, int32 in_seq_no_, int32 out_seq_no_, object_ptr<DecryptedMessage> &&message_);

  static const std::int32_t ID = 467867529;

  static object_ptr<decryptedMessageLayer> fetch(TlParser &p);

  explicit decryptedMessageLayer(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class DocumentAttribute;

class PhotoSize;

class DecryptedMessageMedia: public Object {
 public:

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);
};

class decryptedMessageMediaEmpty final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 144661578;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaPhoto8 final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  int32 w_;
  int32 h_;
  int32 size_;
  bytes key_;
  bytes iv_;

  decryptedMessageMediaPhoto8(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, int32 w_, int32 h_, int32 size_, bytes &&key_, bytes &&iv_);

  static const std::int32_t ID = 846826124;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaPhoto8(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaVideo8 final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  int32 duration_;
  int32 w_;
  int32 h_;
  int32 size_;
  bytes key_;
  bytes iv_;

  decryptedMessageMediaVideo8(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, int32 duration_, int32 w_, int32 h_, int32 size_, bytes &&key_, bytes &&iv_);

  static const std::int32_t ID = 1290694387;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaVideo8(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaGeoPoint final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  double lat_;
  double long_;

  decryptedMessageMediaGeoPoint(double lat_, double long_);

  static const std::int32_t ID = 893913689;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaGeoPoint(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaContact final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string phone_number_;
  string first_name_;
  string last_name_;
  int32 user_id_;

  decryptedMessageMediaContact(string const &phone_number_, string const &first_name_, string const &last_name_, int32 user_id_);

  static const std::int32_t ID = 1485441687;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaContact(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaDocument8 final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  string file_name_;
  string mime_type_;
  int32 size_;
  bytes key_;
  bytes iv_;

  decryptedMessageMediaDocument8(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, string const &file_name_, string const &mime_type_, int32 size_, bytes &&key_, bytes &&iv_);

  static const std::int32_t ID = -1332395189;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaDocument8(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaAudio8 final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 duration_;
  int32 size_;
  bytes key_;
  bytes iv_;

  decryptedMessageMediaAudio8(int32 duration_, int32 size_, bytes &&key_, bytes &&iv_);

  static const std::int32_t ID = 1619031439;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaAudio8(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaVideo23 final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  int32 duration_;
  string mime_type_;
  int32 w_;
  int32 h_;
  int32 size_;
  bytes key_;
  bytes iv_;

  decryptedMessageMediaVideo23(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, int32 duration_, string const &mime_type_, int32 w_, int32 h_, int32 size_, bytes &&key_, bytes &&iv_);

  static const std::int32_t ID = 1380598109;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaVideo23(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaAudio final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 duration_;
  string mime_type_;
  int32 size_;
  bytes key_;
  bytes iv_;

  decryptedMessageMediaAudio(int32 duration_, string const &mime_type_, int32 size_, bytes &&key_, bytes &&iv_);

  static const std::int32_t ID = 1474341323;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaAudio(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaExternalDocument final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 id_;
  int64 access_hash_;
  int32 date_;
  string mime_type_;
  int32 size_;
  object_ptr<PhotoSize> thumb_;
  int32 dc_id_;
  array<object_ptr<DocumentAttribute>> attributes_;

  decryptedMessageMediaExternalDocument(int64 id_, int64 access_hash_, int32 date_, string const &mime_type_, int32 size_, object_ptr<PhotoSize> &&thumb_, int32 dc_id_, array<object_ptr<DocumentAttribute>> &&attributes_);

  static const std::int32_t ID = -90853155;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaExternalDocument(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaPhoto final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  int32 w_;
  int32 h_;
  int32 size_;
  bytes key_;
  bytes iv_;
  string caption_;

  decryptedMessageMediaPhoto(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, int32 w_, int32 h_, int32 size_, bytes &&key_, bytes &&iv_, string const &caption_);

  static const std::int32_t ID = -235238024;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaPhoto(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaVideo final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  int32 duration_;
  string mime_type_;
  int32 w_;
  int32 h_;
  int32 size_;
  bytes key_;
  bytes iv_;
  string caption_;

  decryptedMessageMediaVideo(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, int32 duration_, string const &mime_type_, int32 w_, int32 h_, int32 size_, bytes &&key_, bytes &&iv_, string const &caption_);

  static const std::int32_t ID = -1760785394;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaVideo(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaDocument46 final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  string mime_type_;
  int32 size_;
  bytes key_;
  bytes iv_;
  array<object_ptr<DocumentAttribute>> attributes_;
  string caption_;

  decryptedMessageMediaDocument46(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, string const &mime_type_, int32 size_, bytes &&key_, bytes &&iv_, array<object_ptr<DocumentAttribute>> &&attributes_, string const &caption_);

  static const std::int32_t ID = 2063502050;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaDocument46(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaVenue final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  double lat_;
  double long_;
  string title_;
  string address_;
  string provider_;
  string venue_id_;

  decryptedMessageMediaVenue(double lat_, double long_, string const &title_, string const &address_, string const &provider_, string const &venue_id_);

  static const std::int32_t ID = -1978796689;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaVenue(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaWebPage final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string url_;

  explicit decryptedMessageMediaWebPage(string const &url_);

  static const std::int32_t ID = -452652584;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaWebPage(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class decryptedMessageMediaDocument final : public DecryptedMessageMedia {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes thumb_;
  int32 thumb_w_;
  int32 thumb_h_;
  string mime_type_;
  int64 size_;
  bytes key_;
  bytes iv_;
  array<object_ptr<DocumentAttribute>> attributes_;
  string caption_;

  decryptedMessageMediaDocument(bytes &&thumb_, int32 thumb_w_, int32 thumb_h_, string const &mime_type_, int64 size_, bytes &&key_, bytes &&iv_, array<object_ptr<DocumentAttribute>> &&attributes_, string const &caption_);

  static const std::int32_t ID = 1790809986;

  static object_ptr<DecryptedMessageMedia> fetch(TlParser &p);

  explicit decryptedMessageMediaDocument(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class InputStickerSet;

class DocumentAttribute: public Object {
 public:

  static object_ptr<DocumentAttribute> fetch(TlParser &p);
};

class documentAttributeImageSize final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 w_;
  int32 h_;

  documentAttributeImageSize(int32 w_, int32 h_);

  static const std::int32_t ID = 1815593308;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  explicit documentAttributeImageSize(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeAnimated final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 297109817;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeSticker23 final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -83208409;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeVideo23 final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 duration_;
  int32 w_;
  int32 h_;

  documentAttributeVideo23(int32 duration_, int32 w_, int32 h_);

  static const std::int32_t ID = 1494273227;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  explicit documentAttributeVideo23(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeAudio23 final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 duration_;

  explicit documentAttributeAudio23(int32 duration_);

  static const std::int32_t ID = 85215461;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  explicit documentAttributeAudio23(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeFilename final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string file_name_;

  explicit documentAttributeFilename(string const &file_name_);

  static const std::int32_t ID = 358154344;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  explicit documentAttributeFilename(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeAudio45 final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 duration_;
  string title_;
  string performer_;

  documentAttributeAudio45(int32 duration_, string const &title_, string const &performer_);

  static const std::int32_t ID = -556656416;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  explicit documentAttributeAudio45(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeSticker final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string alt_;
  object_ptr<InputStickerSet> stickerset_;

  documentAttributeSticker(string const &alt_, object_ptr<InputStickerSet> &&stickerset_);

  static const std::int32_t ID = 978674434;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  explicit documentAttributeSticker(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeAudio final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 flags_;
  bool voice_;
  int32 duration_;
  string title_;
  string performer_;
  bytes waveform_;
  enum Flags : std::int32_t { TITLE_MASK = 1, PERFORMER_MASK = 2, WAVEFORM_MASK = 4 };

  documentAttributeAudio();

  documentAttributeAudio(int32 flags_, bool voice_, int32 duration_, string const &title_, string const &performer_, bytes &&waveform_);

  static const std::int32_t ID = -1739392570;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class documentAttributeVideo final : public DocumentAttribute {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 flags_;
  bool round_message_;
  int32 duration_;
  int32 w_;
  int32 h_;

  documentAttributeVideo();

  documentAttributeVideo(int32 flags_, bool round_message_, int32 duration_, int32 w_, int32 h_);

  static const std::int32_t ID = 250621158;

  static object_ptr<DocumentAttribute> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class FileLocation: public Object {
 public:

  static object_ptr<FileLocation> fetch(TlParser &p);
};

class fileLocationUnavailable final : public FileLocation {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 volume_id_;
  int32 local_id_;
  int64 secret_;

  fileLocationUnavailable(int64 volume_id_, int32 local_id_, int64 secret_);

  static const std::int32_t ID = 2086234950;

  static object_ptr<FileLocation> fetch(TlParser &p);

  explicit fileLocationUnavailable(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class fileLocation final : public FileLocation {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 dc_id_;
  int64 volume_id_;
  int32 local_id_;
  int64 secret_;

  fileLocation(int32 dc_id_, int64 volume_id_, int32 local_id_, int64 secret_);

  static const std::int32_t ID = 1406570614;

  static object_ptr<FileLocation> fetch(TlParser &p);

  explicit fileLocation(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class InputStickerSet: public Object {
 public:

  static object_ptr<InputStickerSet> fetch(TlParser &p);
};

class inputStickerSetShortName final : public InputStickerSet {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string short_name_;

  explicit inputStickerSetShortName(string const &short_name_);

  static const std::int32_t ID = -2044933984;

  static object_ptr<InputStickerSet> fetch(TlParser &p);

  explicit inputStickerSetShortName(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class inputStickerSetEmpty final : public InputStickerSet {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -4838507;

  static object_ptr<InputStickerSet> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class MessageEntity: public Object {
 public:

  static object_ptr<MessageEntity> fetch(TlParser &p);
};

class messageEntityUnknown final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityUnknown(int32 offset_, int32 length_);

  static const std::int32_t ID = -1148011883;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityUnknown(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityMention final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityMention(int32 offset_, int32 length_);

  static const std::int32_t ID = -100378723;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityMention(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityHashtag final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityHashtag(int32 offset_, int32 length_);

  static const std::int32_t ID = 1868782349;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityHashtag(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityBotCommand final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityBotCommand(int32 offset_, int32 length_);

  static const std::int32_t ID = 1827637959;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityBotCommand(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityUrl final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityUrl(int32 offset_, int32 length_);

  static const std::int32_t ID = 1859134776;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityUrl(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityEmail final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityEmail(int32 offset_, int32 length_);

  static const std::int32_t ID = 1692693954;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityEmail(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityBold final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityBold(int32 offset_, int32 length_);

  static const std::int32_t ID = -1117713463;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityBold(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityItalic final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityItalic(int32 offset_, int32 length_);

  static const std::int32_t ID = -2106619040;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityItalic(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityCode final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityCode(int32 offset_, int32 length_);

  static const std::int32_t ID = 681706865;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityCode(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityPre final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;
  string language_;

  messageEntityPre(int32 offset_, int32 length_, string const &language_);

  static const std::int32_t ID = 1938967520;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityPre(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityTextUrl final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;
  string url_;

  messageEntityTextUrl(int32 offset_, int32 length_, string const &url_);

  static const std::int32_t ID = 1990644519;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityTextUrl(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityMentionName final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;
  int32 user_id_;

  messageEntityMentionName(int32 offset_, int32 length_, int32 user_id_);

  static const std::int32_t ID = 892193368;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityMentionName(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityPhone final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityPhone(int32 offset_, int32 length_);

  static const std::int32_t ID = -1687559349;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityPhone(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityCashtag final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityCashtag(int32 offset_, int32 length_);

  static const std::int32_t ID = 1280209983;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityCashtag(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityBankCard final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityBankCard(int32 offset_, int32 length_);

  static const std::int32_t ID = 1981704948;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityBankCard(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityUnderline final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityUnderline(int32 offset_, int32 length_);

  static const std::int32_t ID = -1672577397;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityUnderline(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityStrike final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityStrike(int32 offset_, int32 length_);

  static const std::int32_t ID = -1090087980;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityStrike(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityBlockquote final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntityBlockquote(int32 offset_, int32 length_);

  static const std::int32_t ID = 34469328;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityBlockquote(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntitySpoiler final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;

  messageEntitySpoiler(int32 offset_, int32 length_);

  static const std::int32_t ID = 852137487;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntitySpoiler(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class messageEntityCustomEmoji final : public MessageEntity {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 offset_;
  int32 length_;
  int64 document_id_;

  messageEntityCustomEmoji(int32 offset_, int32 length_, int64 document_id_);

  static const std::int32_t ID = -925956616;

  static object_ptr<MessageEntity> fetch(TlParser &p);

  explicit messageEntityCustomEmoji(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class FileLocation;

class PhotoSize: public Object {
 public:

  static object_ptr<PhotoSize> fetch(TlParser &p);
};

class photoSizeEmpty final : public PhotoSize {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string type_;

  explicit photoSizeEmpty(string const &type_);

  static const std::int32_t ID = 236446268;

  static object_ptr<PhotoSize> fetch(TlParser &p);

  explicit photoSizeEmpty(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class photoSize final : public PhotoSize {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string type_;
  object_ptr<FileLocation> location_;
  int32 w_;
  int32 h_;
  int32 size_;

  photoSize(string const &type_, object_ptr<FileLocation> &&location_, int32 w_, int32 h_, int32 size_);

  static const std::int32_t ID = 2009052699;

  static object_ptr<PhotoSize> fetch(TlParser &p);

  explicit photoSize(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class photoCachedSize final : public PhotoSize {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string type_;
  object_ptr<FileLocation> location_;
  int32 w_;
  int32 h_;
  bytes bytes_;

  photoCachedSize(string const &type_, object_ptr<FileLocation> &&location_, int32 w_, int32 h_, bytes &&bytes_);

  static const std::int32_t ID = -374917894;

  static object_ptr<PhotoSize> fetch(TlParser &p);

  explicit photoCachedSize(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class SendMessageAction: public Object {
 public:

  static object_ptr<SendMessageAction> fetch(TlParser &p);
};

class sendMessageTypingAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 381645902;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageCancelAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -44119819;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageRecordVideoAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -1584933265;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageUploadVideoAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -1845219337;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageRecordAudioAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -718310409;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageUploadAudioAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -424899985;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageUploadPhotoAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -1727382502;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageUploadDocumentAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -1884362354;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageGeoLocationAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 393186209;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageChooseContactAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 1653390447;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageRecordRoundAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -1997373508;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class sendMessageUploadRoundAction final : public SendMessageAction {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -1150187996;

  static object_ptr<SendMessageAction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class test_dummyFunction final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -936020215;

  using ReturnType = bool;

  static object_ptr<test_dummyFunction> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

}  // namespace secret_api
}  // namespace td
