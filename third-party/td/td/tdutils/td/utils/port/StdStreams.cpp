//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/StdStreams.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/Iocp.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/port/thread.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

#include <atomic>

namespace td {

#if TD_PORT_POSIX
template <int id>
static FileFd &get_file_fd() {
  static FileFd result = FileFd::from_native_fd(NativeFd(id, true));
  static auto guard = ScopeExit() + [&] {
    result.move_as_native_fd().release();
  };
  return result;
}

FileFd &Stdin() {
  return get_file_fd<0>();
}
FileFd &Stdout() {
  return get_file_fd<1>();
}
FileFd &Stderr() {
  return get_file_fd<2>();
}
#elif TD_PORT_WINDOWS
template <DWORD id>
static FileFd &get_file_fd() {
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
  static auto handle = GetStdHandle(id);
  LOG_IF(FATAL, handle == INVALID_HANDLE_VALUE) << "Failed to GetStdHandle " << id;
  static FileFd result = handle == nullptr ? FileFd() : FileFd::from_native_fd(NativeFd(handle, true));
  static auto guard = ScopeExit() + [&] {
    if (handle != nullptr) {
      result.move_as_native_fd().release();
    }
  };
#else
  static FileFd result;
#endif
  return result;
}

FileFd &Stdin() {
  return get_file_fd<STD_INPUT_HANDLE>();
}
FileFd &Stdout() {
  return get_file_fd<STD_OUTPUT_HANDLE>();
}
FileFd &Stderr() {
  return get_file_fd<STD_ERROR_HANDLE>();
}
#endif

#if TD_PORT_WINDOWS
namespace detail {
class BufferedStdinImpl final : private Iocp::Callback {
 public:
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
  BufferedStdinImpl() : info_(NativeFd(GetStdHandle(STD_INPUT_HANDLE), true)) {
    iocp_ref_ = Iocp::get()->get_ref();
    read_thread_ = thread([this] { this->read_loop(); });
  }
#else
  BufferedStdinImpl() {
    close();
  }
#endif
  BufferedStdinImpl(const BufferedStdinImpl &) = delete;
  BufferedStdinImpl &operator=(const BufferedStdinImpl &) = delete;
  BufferedStdinImpl(BufferedStdinImpl &&) = delete;
  BufferedStdinImpl &operator=(BufferedStdinImpl &&) = delete;
  ~BufferedStdinImpl() {
    info_.move_as_native_fd().release();
  }
  void close() {
    close_flag_ = true;
  }

  ChainBufferReader &input_buffer() {
    return reader_;
  }

  PollableFdInfo &get_poll_info() {
    return info_;
  }
  const PollableFdInfo &get_poll_info() const {
    return info_;
  }

  Result<size_t> flush_read(size_t max_read = std::numeric_limits<size_t>::max()) TD_WARN_UNUSED_RESULT {
    info_.sync_with_poll();
    info_.clear_flags(PollFlags::Read());
    reader_.sync_with_writer();
    return reader_.size();
  }

 private:
  PollableFdInfo info_;
  ChainBufferWriter writer_;
  ChainBufferReader reader_ = writer_.extract_reader();
  thread read_thread_;
  std::atomic<bool> close_flag_{false};
  IocpRef iocp_ref_;
  std::atomic<int> refcnt_{1};

  void read_loop() {
    while (!close_flag_) {
      auto slice = writer_.prepare_append();
      auto r_size = read(slice);
      if (r_size.is_error()) {
        LOG(ERROR) << "Stop read stdin loop: " << r_size.error();
        break;
      }
      writer_.confirm_append(r_size.ok());
      inc_refcnt();
      if (!iocp_ref_.post(0, this, nullptr)) {
        dec_refcnt();
      }
    }
    if (!iocp_ref_.post(0, this, nullptr)) {
      read_thread_.detach();
      dec_refcnt();
    }
  }
  void on_iocp(Result<size_t> r_size, WSAOVERLAPPED *overlapped) final {
    info_.add_flags_from_poll(PollFlags::Read());
    dec_refcnt();
  }

  bool dec_refcnt() {
    if (--refcnt_ == 0) {
      delete this;
      return true;
    }
    return false;
  }
  void inc_refcnt() {
    CHECK(refcnt_ != 0);
    refcnt_++;
  }

  Result<size_t> read(MutableSlice slice) {
    auto native_fd = info_.native_fd().fd();
    DWORD bytes_read = 0;
    auto res = ReadFile(native_fd, slice.data(), narrow_cast<DWORD>(slice.size()), &bytes_read, nullptr);
    if (res) {
      return static_cast<size_t>(bytes_read);
    }
    return OS_ERROR(PSLICE() << "Read from " << info_.native_fd() << " has failed");
  }
};
void BufferedStdinImplDeleter::operator()(BufferedStdinImpl *impl) {
  //  LOG(ERROR) << "Close";
  impl->close();
}
}  // namespace detail
#elif TD_PORT_POSIX
namespace detail {
class BufferedStdinImpl {
 public:
  BufferedStdinImpl() {
    file_fd_ = FileFd::from_native_fd(NativeFd(Stdin().get_native_fd().fd()));
    file_fd_.get_native_fd().set_is_blocking(false);
  }
  BufferedStdinImpl(const BufferedStdinImpl &) = delete;
  BufferedStdinImpl &operator=(const BufferedStdinImpl &) = delete;
  BufferedStdinImpl(BufferedStdinImpl &&) = delete;
  BufferedStdinImpl &operator=(BufferedStdinImpl &&) = delete;
  ~BufferedStdinImpl() {
    file_fd_.get_native_fd().set_is_blocking(true);
    file_fd_.move_as_native_fd().release();
  }

  ChainBufferReader &input_buffer() {
    return reader_;
  }

  PollableFdInfo &get_poll_info() {
    return file_fd_.get_poll_info();
  }
  const PollableFdInfo &get_poll_info() const {
    return file_fd_.get_poll_info();
  }

  Result<size_t> flush_read(size_t max_read = std::numeric_limits<size_t>::max()) TD_WARN_UNUSED_RESULT {
    size_t result = 0;
    ::td::sync_with_poll(*this);
    while (::td::can_read_local(*this) && max_read) {
      MutableSlice slice = writer_.prepare_append();
      slice.truncate(max_read);
      TRY_RESULT(x, file_fd_.read(slice));
      slice.truncate(x);
      writer_.confirm_append(x);
      result += x;
      max_read -= x;
    }
    if (result) {
      reader_.sync_with_writer();
    }
    return result;
  }

 private:
  FileFd file_fd_;
  ChainBufferWriter writer_;
  ChainBufferReader reader_ = writer_.extract_reader();
};
void BufferedStdinImplDeleter::operator()(BufferedStdinImpl *impl) {
  delete impl;
}
}  // namespace detail
#endif

BufferedStdin::BufferedStdin() : impl_(make_unique<detail::BufferedStdinImpl>().release()) {
}
BufferedStdin::BufferedStdin(BufferedStdin &&) noexcept = default;
BufferedStdin &BufferedStdin::operator=(BufferedStdin &&) noexcept = default;
BufferedStdin::~BufferedStdin() = default;

ChainBufferReader &BufferedStdin::input_buffer() {
  return impl_->input_buffer();
}
PollableFdInfo &BufferedStdin::get_poll_info() {
  return impl_->get_poll_info();
}
const PollableFdInfo &BufferedStdin::get_poll_info() const {
  return impl_->get_poll_info();
}
Result<size_t> BufferedStdin::flush_read(size_t max_read) {
  return impl_->flush_read(max_read);
}

}  // namespace td
