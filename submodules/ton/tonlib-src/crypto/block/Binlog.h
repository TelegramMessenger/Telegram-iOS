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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/Status.h"
#include "td/utils/port/FileFd.h"

namespace block {
/*
 * 
 *   BINLOG (BUFFERS) -- move to separate file
 * 
 */

class BinlogBuffer;

class BinlogCallback {
 public:
  virtual ~BinlogCallback() = default;
  virtual td::Status init_new_binlog(BinlogBuffer& bb) = 0;
  virtual int replay_log_event(BinlogBuffer& bb, const unsigned* ptr, std::size_t len, unsigned long long pos) = 0;
};

class BinlogBuffer {
  static constexpr std::size_t max_event_size = 0xfffc;
  std::unique_ptr<BinlogCallback> cb;
  std::size_t max_size;
  std::size_t need_more_bytes;
  unsigned char *start, *rptr, *cptr, *wptr, *eptr, *end;
  unsigned long long log_rpos, log_cpos, log_wpos;
  std::string binlog_name;
  td::FileFd fd;
  bool replica;
  bool writing;
  bool dirty;
  bool created;
  bool ok;
  td::Result<int> read_file();
  td::Result<long long> replay_binlog(bool allow_partial);
  unsigned char* try_alloc_log_event(std::size_t size);
  int replay_pending(bool allow_partial = false);
  void replay_range(unsigned char* ptr, unsigned long long pos_start, unsigned long long pos_end);
  td::Status set_fd(td::FileFd fd);

 public:
  struct LevAllocError {
    std::size_t size;
    explicit LevAllocError(std::size_t _size) : size(_size) {
    }
  };
  struct InterpretError {
    std::string msg;
    explicit InterpretError(std::string _msg) : msg(_msg) {
    }
  };
  struct BinlogError {
    std::string msg;
    explicit BinlogError(std::string _msg) : msg(_msg) {
    }
  };
  BinlogBuffer(std::unique_ptr<BinlogCallback> _cb, std::size_t _max_size = (1 << 24), td::FileFd fd = {});
  BinlogBuffer(const BinlogBuffer&) = delete;
  BinlogBuffer& operator=(const BinlogBuffer&) = delete;
  BinlogBuffer(BinlogBuffer&&) = delete;
  BinlogBuffer& operator=(BinlogBuffer&&) = delete;
  ~BinlogBuffer();
  td::Status set_binlog(std::string _binlog_name, int mode = 0);
  unsigned char* alloc_log_event(std::size_t size);
  unsigned char* alloc_log_event_force(std::size_t size);
  bool flush(int mode = 0);
  td::Result<bool> try_flush(int mode);
  unsigned long long get_rpos() const {
    return log_rpos;
  }
  //
  class NewBinlogEvent {
   protected:
    BinlogBuffer& bb;
    unsigned long long pos;
    unsigned size;
    int status;

   public:
    NewBinlogEvent(BinlogBuffer& _bb, unsigned long long _pos, unsigned _size)
        : bb(_bb), pos(_pos), size(_size), status(4) {
    }
    ~NewBinlogEvent();
    unsigned long long get_log_pos() const {
      return pos;
    }
    void commit();
    void commit_later() {
      if (status & 4) {
        status = 5;
      }
    }
    void rollback();
    void rollback_later() {
      if (status & 4) {
        status = 6;
      }
    };
  };
  template <typename T>
  class NewEvent : public NewBinlogEvent {
    T* ptr;

   protected:
    friend class BinlogBuffer;
    NewEvent(BinlogBuffer& _bb, unsigned long long _pos, unsigned _size, T* _ptr)
        : NewBinlogEvent(_bb, _pos, _size), ptr(_ptr) {
    }

   public:
    T* operator->() const {
      return ptr;
    }
    T& operator*() const {
      return *ptr;
    }
    void commit() {
      NewBinlogEvent::commit();
      ptr = nullptr;
    }
    void rollback() {
      NewBinlogEvent::rollback();
      ptr = nullptr;
    }
  };
  template <typename T, typename... Args>
  NewEvent<T> alloc(Args... args) {
    unsigned long long pos = log_wpos;
    return NewEvent<T>(*this, pos, sizeof(T), new (alloc_log_event_force(sizeof(T))) T(args...));
  }

 protected:
  friend class NewBinlogEvent;
  bool commit_range(unsigned long long pos_start, unsigned long long pos_end);
  bool rollback_range(unsigned long long pos_start, unsigned long long pos_end);
};
}  // namespace block
