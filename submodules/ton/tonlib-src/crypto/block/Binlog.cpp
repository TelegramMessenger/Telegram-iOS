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
#include "crypto/block/Binlog.h"

#include "td/utils/as.h"
#include "td/utils/misc.h"
#include "td/utils/port/path.h"

#include <sstream>

namespace block {
/*
 * 
 *    GENERIC BINLOG (move to separate file)
 * 
 */

BinlogBuffer::BinlogBuffer(std::unique_ptr<BinlogCallback> cb, std::size_t _max_size, td::FileFd fd)
    : cb(std::move(cb))
    , need_more_bytes(0)
    , eptr(nullptr)
    , log_rpos(0)
    , log_cpos(0)
    , log_wpos(0)
    , fd(std::move(fd))
    , replica(false)
    , writing(false)
    , dirty(false)
    , created(false)
    , ok(false) {
  max_size = _max_size;
  start = static_cast<unsigned char*>(std::malloc(max_size));
  DCHECK(start);
  rptr = wptr = cptr = start;
  end = start + max_size;
}

unsigned char* BinlogBuffer::alloc_log_event_force(std::size_t size) {
  unsigned char* res = alloc_log_event(size);
  if (!res) {
    throw LevAllocError{size};
  }
  return res;
}

unsigned char* BinlogBuffer::try_alloc_log_event(std::size_t size) {
  if (!eptr) {
    if (end - wptr >= (long)size) {
      unsigned char* res = wptr;
      wptr += size;
      log_wpos += size;
      return res;
    }
    eptr = wptr;
    wptr = start;
    if (rptr == eptr) {
      rptr = start;
    }
    if (cptr == eptr) {
      cptr = start;
    }
  }
  if (rptr - wptr > (long)size) {
    unsigned char* res = wptr;
    wptr += size;
    log_wpos += size;
    return res;
  }
  return nullptr;
}

bool BinlogBuffer::flush(int mode) {
  auto r_res = try_flush(mode);
  if (r_res.is_ok()) {
    return r_res.ok();
  }
  std::string msg = PSTRING() << "cannot flush binlog file " << binlog_name << " at position " << log_rpos << " "
                              << r_res.error();
  LOG(ERROR) << msg;
  throw BinlogError{msg};
}

td::Result<bool> BinlogBuffer::try_flush(int mode) {
  LOG(DEBUG) << "in flush: writing=" << writing << " r=" << rptr - start << " c=" << cptr - start
             << " w=" << wptr - start << "; rp=" << log_rpos << " cp=" << log_cpos << " wp=" << log_wpos;
  if (!writing || rptr == cptr) {
    return false;  // nothing to flush
  }
  DCHECK(!fd.empty());  // must have an open binlog file
  while (rptr != cptr) {
    unsigned char* tptr = (cptr >= rptr ? cptr : eptr);
    DCHECK(rptr <= tptr);
    auto sz = tptr - rptr;
    if (sz) {
      LOG(INFO) << "writing " << sz << " bytes to binlog " << binlog_name << " at position " << log_rpos;
      TRY_RESULT(res, fd.pwrite(td::Slice(rptr, sz), log_rpos));
      if (static_cast<td::int64>(res) != sz) {
        return td::Status::Error(PSLICE() << "written " << res << " bytes instead of " << sz);
      }
      log_rpos += sz;
      rptr += sz;
    }
    if (rptr == eptr) {
      rptr = start;
      eptr = nullptr;
    }
  }
  if (mode >= 3) {
    LOG(INFO) << "syncing binlog " << binlog_name << " (position " << log_rpos << ")";
    TRY_STATUS(fd.sync());
  }
  return true;
}

unsigned char* BinlogBuffer::alloc_log_event(std::size_t size) {
  if (!writing) {
    throw BinlogError{"cannot create new binlog event: binlog not open for writing"};
  }
  if (size >= max_size || size > max_event_size) {
    return nullptr;
  }
  size = (size + 3) & -4;
  unsigned char* res = try_alloc_log_event(size);
  if (!res) {
    flush();
    return try_alloc_log_event(size);
  } else {
    return res;
  }
}

bool BinlogBuffer::commit_range(unsigned long long pos_start, unsigned long long pos_end) {
  // TODO: make something more clever, with partially committed/uncommitted segments in [cpos..wpos] range
  if (pos_start != log_cpos || pos_end < pos_start || pos_end > log_wpos) {
    return false;
  }
  if (!pos_start && pos_end >= pos_start + 4 && td::as<unsigned>(cptr) != 0x0442446b) {
    throw BinlogError{"incorrect magic"};
  }
  long long size = pos_end - pos_start;
  replay_range(cptr, pos_start, pos_end);
  log_cpos = pos_end;
  cptr += size;
  if (eptr && cptr >= eptr) {
    cptr -= eptr - start;
  }
  return true;
}

bool BinlogBuffer::rollback_range(unsigned long long pos_start, unsigned long long pos_end) {
  if (pos_start < log_cpos || pos_end < pos_start || pos_end != log_wpos) {
    return false;
  }
  long long size = pos_end - pos_start;
  log_wpos = pos_end;
  if (size >= wptr - start) {
    wptr -= size;
  } else {
    DCHECK(eptr);
    wptr += eptr - start - size;
  }
  return true;
}

void BinlogBuffer::NewBinlogEvent::commit() {
  //LOG(DEBUG) << "in NewBinlogEvent::commit (status = " << status << ")";
  if (!(status & 4)) {
    throw BinlogError{"cannot commit new binlog event: already committed or rolled back"};
  }
  if (!bb.commit_range(pos, pos + size)) {
    throw BinlogError{"cannot commit new binlog event: possibly some earlier log events are not committed yet"};
  }
  status = 1;
  //LOG(DEBUG) << "after NewBinlogEvent::commit (status = " << status << ")";
}

void BinlogBuffer::NewBinlogEvent::rollback() {
  if (!(status & 4)) {
    throw BinlogError{"cannot roll back new binlog event: already committed or rolled back"};
  }
  if (!bb.rollback_range(pos, pos + size)) {
    throw BinlogError{"cannot roll back new binlog event: possibly some later log event are already committed"};
  }
  status = 2;
}

BinlogBuffer::NewBinlogEvent::~NewBinlogEvent() {
  if (status & 4) {
    if (status == 5) {
      status = 4;
      commit();
    } else if (status == 6) {
      status = 4;
      rollback();
    } else {
      LOG(ERROR) << "newly-allocated binlog event is neither committed nor rolled back (automatically rolling back)";
      rollback();
    }
  }
}

void BinlogBuffer::replay_range(unsigned char* ptr, unsigned long long pos_start, unsigned long long pos_end) {
  unsigned char* tptr = (ptr <= wptr ? wptr : eptr);
  long long avail = tptr - ptr;
  while (pos_start < pos_end) {
    if (ptr == eptr) {
      ptr = start;
      tptr = wptr;
      avail = tptr - ptr;
      if (avail > (long long)(pos_end - pos_start)) {
        avail = pos_end - pos_start;
      }
    }
    int res = (avail >= 4 ? cb->replay_log_event(*this, reinterpret_cast<const unsigned*>(ptr),
                                                 td::narrow_cast<size_t>(avail), pos_start)
                          : -0x7ffffffc);
    if (res <= 0 || res > avail) {
      std::ostringstream ss;
      ss << "cannot interpret newly-committed binlog event 0x" << std::hex
         << (avail >= 4 ? (unsigned)td::as<unsigned>(ptr) : 0u) << std::dec << ": error " << res;
      throw BinlogError{ss.str()};
    }
    ptr += res;
    pos_start += res;
    avail -= res;
  }
}

int BinlogBuffer::replay_pending(bool allow_partial) {
  if (rptr == cptr) {
    return 0;
  }
  unsigned char* tptr = (rptr <= cptr ? cptr : eptr);
  long long avail = tptr - rptr;
  DCHECK(tptr && avail >= 0);
  while (rptr != cptr) {
    int res = (avail >= 4 ? cb->replay_log_event(*this, reinterpret_cast<const unsigned*>(rptr),
                                                 td::narrow_cast<size_t>(avail), log_rpos)
                          : -0x7ffffffc);
    if (res > 0) {
      if (res > avail) {
        throw BinlogError{"binlog event used more bytes than available"};
      }
      avail -= res;
      log_rpos += res;
      rptr += res;
      if (rptr != eptr) {
        continue;
      }
      rptr = start;
      tptr = cptr;
      avail = tptr - rptr;
      continue;
    }
    long long prev_need = 0;
    while (res < -0x40000000) {
      long long need = res - 0x80000000;
      need = (need + 3) & -4;
      if (need > (long long)max_event_size) {
        throw BinlogError{"binlog event requires too many bytes"};
      }
      if (need <= avail) {
        throw BinlogError{"binlog event requires more bytes, but we already had them"};
      }
      if (need <= prev_need) {
        throw BinlogError{"binlog event requires more bytes, but we already had them"};
      }
      prev_need = need;
      long long total_avail = avail + (rptr > cptr ? cptr - start : 0);
      if (need > total_avail) {
        if (allow_partial) {
          need_more_bytes = td::narrow_cast<size_t>(need - total_avail);
          return 2;
        } else {
          throw BinlogError{"binlog event extends past end of buffer"};
        }
      }
      if (need <= 1024) {
        unsigned char tmp[1024];
        std::memcpy(tmp, rptr, td::narrow_cast<size_t>(avail));
        std::memcpy(tmp + avail, start, td::narrow_cast<size_t>(need - avail));
        res = cb->replay_log_event(*this, reinterpret_cast<const unsigned*>(tmp), td::narrow_cast<size_t>(need),
                                   log_rpos);
      } else {
        unsigned char* tmp = static_cast<unsigned char*>(std::malloc(td::narrow_cast<size_t>(need)));
        std::memcpy(tmp, rptr, td::narrow_cast<size_t>(avail));
        std::memcpy(tmp + avail, start, td::narrow_cast<size_t>(need - avail));
        res = cb->replay_log_event(*this, reinterpret_cast<const unsigned*>(tmp), td::narrow_cast<size_t>(need),
                                   log_rpos);
        std::free(tmp);
      }
      if (res > need) {
        throw BinlogError{"binlog event used more bytes than available"};
      }
    }
    if (res < 0) {
      return res;
    }
    if (!res) {
      throw BinlogError{"unknown error while interpreting binlog event"};
    }
    if (res < avail) {
      avail -= res;
      log_rpos += res;
      rptr += res;
      continue;
    }
    DCHECK(eptr);
    log_rpos += res;
    rptr += res;
    rptr = start + (rptr - eptr);
    eptr = nullptr;
    DCHECK(start <= rptr && rptr <= cptr && cptr <= wptr && wptr <= end);
  }
  return 1;
}

BinlogBuffer::~BinlogBuffer() {
  if (start) {
    if (writing) {
      flush(2);
    }
    std::free(start);
  }
}

td::Status BinlogBuffer::set_binlog(std::string new_binlog_name, int mode) {
  if (!binlog_name.empty() || !fd.empty()) {
    return td::Status::Error("binlog buffer already attached to a file");
  }
  td::int32 flags = td::FileFd::Read;
  if ((mode & 1) != 0) {
    flags |= td::FileFd::Write;
  }
  auto r_fd = td::FileFd::open(new_binlog_name, flags, 0640);
  if (r_fd.is_error()) {
    if (!(~mode & 3)) {
      TRY_RESULT(new_fd, td::FileFd::open(new_binlog_name, flags | td::FileFd::CreateNew, 0640));
      fd = std::move(new_fd);
      created = true;
    } else {
      return r_fd.move_as_error();
    }
  } else {
    fd = r_fd.move_as_ok();
  }
  replica = !(mode & 1);
  if (!replica) {
    TRY_STATUS(fd.lock(td::FileFd::LockFlags::Write, new_binlog_name, 100));
  }
  if (created) {
    writing = true;
    td::Status res;
    try {
      res = cb->init_new_binlog(*this);
    } catch (BinlogBuffer::BinlogError& err) {
      res = td::Status::Error(err.msg);
    }
    if (res.is_error()) {
      fd.close();
      td::unlink(new_binlog_name).ignore();
      writing = false;
      return res;
    }
    binlog_name = new_binlog_name;
    ok = true;
    return td::Status::OK();
  }
  binlog_name = new_binlog_name;
  auto res = replay_binlog(replica);
  if (res.is_error()) {
    return res.move_as_error();
  }
  if (!replica) {
    if (log_rpos != log_wpos || log_rpos != log_cpos || rptr != wptr || rptr != cptr) {
      std::string msg = (PSLICE() << "error while interpreting binlog `" << binlog_name << "`: " << log_wpos - log_rpos
                                  << " bytes left uninterpreted at position " << log_rpos << ", truncated binlog?")
                            .c_str();
      LOG(ERROR) << msg;
      return td::Status::Error(msg);
    }
    //rptr = wptr = cptr = start;
    //eptr = nullptr;
    LOG(INFO) << "read and interpreted " << res.move_as_ok() << " bytes from binlog `" << binlog_name
              << "`, final position " << log_rpos << ", reopening in write mode";
    writing = true;
    if (!log_rpos) {
      td::Status status;
      try {
        status = cb->init_new_binlog(*this);
      } catch (BinlogBuffer::BinlogError& err) {
        status = td::Status::Error(err.msg);
      }
      if (status.is_error()) {
        fd.close();
        td::unlink(new_binlog_name).ignore();
        writing = false;
        return status;
      }
    }
  }
  ok = true;
  return td::Status::OK();
}

td::Result<long long> BinlogBuffer::replay_binlog(bool allow_partial) {
  if (writing) {
    return 0;
  }
  long long total = 0;
  while (true) {
    auto res = read_file();
    if (res.is_error()) {
      return res.move_as_error();
    }
    long long sz = res.move_as_ok();
    total += sz;
    try {
      cptr = wptr;
      log_cpos = log_wpos;
      if (!log_rpos && rptr == start && wptr >= rptr + 4 && td::as<unsigned>(rptr) != 0x0442446b) {
        throw BinlogError{"incorrect magic"};
      }
      int r = replay_pending(allow_partial || sz != 0);
      if (r < 0 && r >= -0x40000000) {
        throw InterpretError{(PSLICE() << "binlog error " << r).c_str()};
      }
    } catch (BinlogError err) {
      LOG(ERROR) << "error reading binlog " << binlog_name << ": " << err.msg << " at position " << log_rpos;
      return td::Status::Error(PSLICE() << "error reading binlog " << binlog_name << ": " << err.msg << " at position "
                                        << log_rpos);
    } catch (InterpretError err) {
      LOG(ERROR) << "error interpreting binlog " << binlog_name << ": " << err.msg << " at position " << log_rpos;
      return td::Status::Error(PSLICE() << "error interpreting binlog " << binlog_name << ": " << err.msg
                                        << " at position " << log_rpos);
    }
    if (!sz) {
      break;
    }
  };
  return total;
}

td::Result<int> BinlogBuffer::read_file() {
  unsigned char* ptr = wptr;
  std::size_t sz = end - wptr;
  if (rptr > wptr) {
    DCHECK(eptr);
    sz = rptr - wptr;
    if (sz <= 4) {
      return 0;  // buffer full
    }
    sz -= 4;
  } else if (!sz) {
    DCHECK(!eptr);
    if (rptr <= start + 4) {
      return 0;  // buffer full
    }
    eptr = end;
    ptr = wptr = start;
    sz = rptr - start - 4;
  }
  auto r_res = fd.pread(td::MutableSlice(ptr, sz), log_wpos);
  if (r_res.is_error()) {
    std::string msg = PSTRING() << "error reading binlog file `" << binlog_name << "` at position " << log_wpos << " : "
                                << r_res.error();
    LOG(ERROR) << msg;
    return td::Status::Error(msg);
  }
  auto res = r_res.move_as_ok();
  DCHECK(std::size_t(res) <= sz);
  LOG(INFO) << "read " << res << " bytes from binlog `" << binlog_name << "` at position " << log_wpos;
  log_wpos += res;
  wptr += res;
  return (int)res;
}
}  // namespace block
