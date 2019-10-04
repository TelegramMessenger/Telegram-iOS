#include "KeyValue.h"

#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"

#include <map>
#include <utility>

namespace tonlib {
namespace detail {
class KeyValueDir : public KeyValue {
 public:
  static td::Result<td::unique_ptr<KeyValueDir>> create(td::CSlice directory) {
    TRY_RESULT(path, td::realpath(directory));
    TRY_RESULT(stat, td::stat(path));
    if (!stat.is_dir_) {
      return td::Status::Error("not a directory");
    }
    return td::make_unique<KeyValueDir>(path);
  }

  KeyValueDir(std::string directory) : directory_(std::move(directory)) {
  }

  td::Status add(td::Slice key, td::Slice value) override {
    auto path = to_file_path(key.str());
    if (td::stat(path).is_ok()) {
      return td::Status::Error(PSLICE() << "File " << path << "already exists");
    }
    return td::atomic_write_file(path, value);
  }

  td::Status set(td::Slice key, td::Slice value) override {
    return td::atomic_write_file(to_file_path(key.str()), value);
  }

  td::Result<td::SecureString> get(td::Slice key) override {
    return td::read_file_secure(to_file_path(key.str()));
  }

  td::Status erase(td::Slice key) override {
    return td::unlink(to_file_path(key.str()));
  }

  void foreach_key(std::function<void(td::Slice)> f) override {
    int cnt = 0;
    td::WalkPath::run(directory_, [&](td::Slice path, td::WalkPath::Type type) {
      cnt++;
      if (type == td::WalkPath::Type::EnterDir) {
        if (cnt != 1) {
          return td::WalkPath::Action::SkipDir;
        }
      } else if (type == td::WalkPath::Type::NotDir) {
        f(path);
      }

      return td::WalkPath::Action::Continue;
    }).ignore();
  }

 private:
  std::string directory_;

  std::string to_file_path(std::string key) {
    return directory_ + TD_DIR_SLASH + key;
  }
};

class KeyValueInmemory : public KeyValue {
 public:
  td::Status add(td::Slice key, td::Slice value) override {
    auto res = map_.insert(std::make_pair(key.str(), td::SecureString(value)));
    if (!res.second) {
      return td::Status::Error(PSLICE() << "Add failed: value with key=`" << key << "` already exists");
    }
    return td::Status::OK();
  }

  td::Status set(td::Slice key, td::Slice value) override {
    map_[key.str()] = td::SecureString(value);
    return td::Status::OK();
  }
  td::Result<td::SecureString> get(td::Slice key) override {
    auto it = map_.find(key);
    if (it == map_.end()) {
      return td::Status::Error("Unknown key");
    }
    return it->second.copy();
  }
  static td::Result<td::unique_ptr<KeyValueInmemory>> create() {
    return td::make_unique<KeyValueInmemory>();
  }
  td::Status erase(td::Slice key) override {
    auto it = map_.find(key);
    if (it == map_.end()) {
      return td::Status::Error("Unknown key");
    }
    map_.erase(it);
    return td::Status::OK();
  }
  void foreach_key(std::function<void(td::Slice)> f) override {
    for (auto &it : map_) {
      f(it.first);
    }
  }

 private:
  class Cmp : public std::less<> {
   public:
    using is_transparent = void;
  };
  std::map<std::string, td::SecureString, Cmp> map_;
};
}  // namespace detail

td::Result<td::unique_ptr<KeyValue>> KeyValue::create_dir(td::CSlice dir) {
  TRY_RESULT(res, detail::KeyValueDir::create(dir.str()));
  return std::move(res);
}
td::Result<td::unique_ptr<KeyValue>> KeyValue::create_inmemory() {
  TRY_RESULT(res, detail::KeyValueInmemory::create());
  return std::move(res);
}
}  // namespace tonlib
