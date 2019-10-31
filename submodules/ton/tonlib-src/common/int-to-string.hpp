#pragma once

#include "td/utils/int_types.h"
#include "td/utils/Slice.h"

namespace ton {

template <typename T>
typename std::enable_if_t<std::is_integral<T>::value, td::MutableSlice> store_int_to_slice(td::MutableSlice S,
                                                                                           const T &v) {
  CHECK(S.size() >= sizeof(T));
  S.copy_from(td::Slice(reinterpret_cast<const td::uint8 *>(&v), sizeof(T)));
  return S.remove_prefix(sizeof(T));
}

template <typename T>
typename std::enable_if_t<std::is_integral<T>::value, T> fetch_int_from_slice(td::Slice S) {
  CHECK(S.size() >= sizeof(T));
  T v;
  td::MutableSlice(reinterpret_cast<td::uint8 *>(&v), sizeof(T)).copy_from(S.truncate(sizeof(T)));
  return v;
}

}  // namespace ton
