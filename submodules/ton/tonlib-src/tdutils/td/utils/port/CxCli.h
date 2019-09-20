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

#include "td/utils/port/config.h"

#include "td/utils/common.h"
#undef small

#if TD_WINRT

#include "td/utils/port/wstring_convert.h"

#include "collection.h"

#include <cstdint>
#include <map>
#include <mutex>

#define REF_NEW ref new
#define CLRCALL
#define DEPRECATED_ATTRIBUTE(message) ::Windows::Foundation::Metadata::Deprecated(message,\
                                      ::Windows::Foundation::Metadata::DeprecationType::Deprecate, 0x0)

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

template <class Key, class Value> class ConcurrentDictionary {
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
  Value &operator [] (Key key) {
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

inline std::string string_to_unmanaged(String^ str) {
  if (!str) {
    return std::string();
  }
  return td::from_wstring(str->Data(), str->Length()).ok();
}

inline String^ string_from_unmanaged(const std::string &from) {
  auto tmp = td::to_wstring(from).ok();
  return REF_NEW String(tmp.c_str(), static_cast<unsigned>(tmp.size()));
}

} // namespace CxCli

#elif TD_CLI

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

inline std::int64_t Increment(std::int64_t %value) {
  return System::Threading::Interlocked::Increment(value);
}

inline std::string string_to_unmanaged(String^ str) {
  if (!str || str->Length == 0) {
    return std::string();
  }

  Array<System::Byte>^ bytes = System::Text::Encoding::UTF8->GetBytes(str);
  cli::pin_ptr<System::Byte> pinned_ptr = &bytes[0];
  std::string result(reinterpret_cast<const char *>(&pinned_ptr[0]), bytes->Length);
  return result;
}

inline String^ string_from_unmanaged(const std::string &from) {
  if (from.empty()) {
    return String::Empty;
  }

  Array<System::Byte>^ bytes = REF_NEW Vector<System::Byte>(static_cast<ArrayIndexType>(from.size()));
  cli::pin_ptr<System::Byte> pinned_ptr = &bytes[0];
  for (size_t i = 0; i < from.size(); ++i) {
    pinned_ptr[i] = from[i];
  }
  return System::Text::Encoding::UTF8->GetString(bytes);
}

} // namespace CxCli

#endif
