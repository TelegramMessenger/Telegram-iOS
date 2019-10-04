#pragma once
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <functional>

namespace tonlib {
class KeyValue {
 public:
  virtual ~KeyValue() = default;
  virtual td::Status add(td::Slice key, td::Slice value) = 0;
  virtual td::Status set(td::Slice key, td::Slice value) = 0;
  virtual td::Status erase(td::Slice key) = 0;
  virtual td::Result<td::SecureString> get(td::Slice key) = 0;
  virtual void foreach_key(std::function<void(td::Slice)> f) = 0;

  static td::Result<td::unique_ptr<KeyValue>> create_dir(td::CSlice dir);
  static td::Result<td::unique_ptr<KeyValue>> create_inmemory();
};
}  // namespace tonlib
