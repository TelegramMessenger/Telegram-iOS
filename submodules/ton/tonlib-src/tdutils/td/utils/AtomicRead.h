/*
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission
    to link the code of portions of this program with the OpenSSL library.
    You must obey the GNU General Public License in all respects for all
    of the code used other than OpenSSL. If you modify file(s) with this
    exception, you may extend this exception to your version of the file(s),
    but you are not obligated to do so. If you do not wish to do so, delete this
    exception statement from your version. If you delete this exception statement
    from all source files in the program, then also delete it here.

    Copyright 2019-2020 Telegram Systems LLP
*/
#include <atomic>

#include "td/utils/common.h"
#include "td/utils/port/thread.h"
namespace td {
template <class T>

class AtomicRead {
 public:
  void read(T &dest) const {
    while (true) {
      static_assert(std::is_trivially_copyable<T>::value, "T must be trivially copyable");
      auto version_before = version.load();
      memcpy(&dest, &value, sizeof(dest));
      auto version_after = version.load();
      if (version_before == version_after && version_before % 2 == 0) {
        break;
      }
      td::this_thread::yield();
    }
  }

  friend struct Write;
  struct Write {
    explicit Write(AtomicRead *read) {
      read->do_lock();
      ptr.reset(read);
    }
    struct Destructor {
      void operator()(AtomicRead *read) const {
        read->do_unlock();
      }
    };
    T &operator*() {
      return value();
    }
    T *operator->() {
      return &value();
    }
    T &value() {
      CHECK(ptr);
      return ptr->value;
    }

   private:
    std::unique_ptr<AtomicRead, Destructor> ptr;
  };
  Write lock() {
    return Write(this);
  }

 private:
  std::atomic<td::uint64> version{0};
  T value;

  void do_lock() {
    CHECK(++version % 2 == 1);
  }
  void do_unlock() {
    CHECK(++version % 2 == 0);
  }
};
};  // namespace td
