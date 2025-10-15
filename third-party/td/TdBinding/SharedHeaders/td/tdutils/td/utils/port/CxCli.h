//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#pragma managed(push, off)
#include "td/utils/port/config.h"
#pragma managed(pop)

#include "td/utils/common.h"

#if TD_WINRT

#pragma managed(push, off)
#include "td/utils/port/wstring_convert.h"
#pragma managed(pop)

#include "collection.h"

#pragma managed(push, off)
#include <cstdint>
#include <map>
#include <mutex>
#pragma managed(pop)

#undef small

#define REF_NEW ref new
#define CLRCALL
#define DEPRECATED_ATTRIBUTE(message) \
  ::Windows::Foundation::Metadata::Deprecated(message, ::Windows::Foundation::Metadata::DeprecationType::Deprecate, 0x0)

namespace CxCli {

using Windows::Foundation::Collections::IVector;
#define Array IVector
using Platform::Collections::Vector;
#define ArraySize(arr) ((arr)->Size)
#define ArrayGet(arr, index) ((arr)->GetAt(index))
#define ArraySet(arr, index, value) ((arr)->SetAt((index), (value)))
#define ArrayIndexType unsigned

using Platform::String;

using Platform::NullReferenceException;

template <class Key, class Value>
class ConcurrentDictionary {
 public:
  bool TryGetValue(Key key, Value &value) {
    std::lock_guard<std::mutex> guard(mutex_);
    auto it = impl_.find(key);
    if (it == impl_.end()) {
      return false;
    }
    value = it->second;
    return true;
  }
  bool TryRemove(Key key, Value &value) {
    std::lock_guard<std::mutex> guard(mutex_);
    auto it = impl_.find(key);
    if (it == impl_.end()) {
      return false;
    }
    value = std::move(it->second);
    impl_.erase(it);
    return true;
  }
  Value &operator[](Key key) {
    std::lock_guard<std::mutex> guard(mutex_);
    return impl_[key];
  }

 private:
  std::mutex mutex_;
  std::map<Key, Value> impl_;
};

inline std::int64_t Increment(volatile std::int64_t &value) {
  return InterlockedIncrement64(&value);
}

inline std::string string_to_unmanaged(String ^ str) {
  if (!str) {
    return std::string();
  }
  auto r_unmanaged_str = td::from_wstring(str->Data(), str->Length());
  if (r_unmanaged_str.is_error()) {
    return std::string();
  }
  return r_unmanaged_str.move_as_ok();
}

inline String ^ string_from_unmanaged(const std::string &from) {
  auto tmp = td::to_wstring(from).ok();
  return REF_NEW String(tmp.c_str(), static_cast<unsigned>(tmp.size()));
}

}  // namespace CxCli

#elif TD_CLI

#undef small

#define REF_NEW gcnew
#define CLRCALL __clrcall
#define DEPRECATED_ATTRIBUTE(message) System::ObsoleteAttribute(message)

namespace CxCli {

using uint8 = td::uint8;
using int32 = td::int32;
using int64 = td::int64;
using float64 = double;

#define Array array
#define Vector array
#define ArraySize(arr) ((arr)->Length)
#define ArrayGet(arr, index) ((arr)[index])
#define ArraySet(arr, index, value) ((arr)[index] = (value))
#define ArrayIndexType int

using System::String;

using System::NullReferenceException;

using System::Collections::Concurrent::ConcurrentDictionary;

inline std::int64_t Increment(std::int64_t % value) {
  return System::Threading::Interlocked::Increment(value);
}

inline std::string string_to_unmanaged(String ^ str) {
  if (!str || str->Length == 0) {
    return std::string();
  }

  Array<System::Byte> ^ bytes = System::Text::Encoding::UTF8->GetBytes(str);
  cli::pin_ptr<System::Byte> pinned_ptr = &bytes[0];
  std::string result(reinterpret_cast<const char *>(&pinned_ptr[0]), bytes->Length);
  return result;
}

inline String ^ string_from_unmanaged(const std::string &from) {
  if (from.empty()) {
    return String::Empty;
  }

  Array<System::Byte> ^ bytes = REF_NEW Vector<System::Byte>(static_cast<ArrayIndexType>(from.size()));
  cli::pin_ptr<System::Byte> pinned_ptr = &bytes[0];
  for (size_t i = 0; i < from.size(); ++i) {
    pinned_ptr[i] = from[i];
  }
  return System::Text::Encoding::UTF8->GetString(bytes);
}

}  // namespace CxCli

#endif
