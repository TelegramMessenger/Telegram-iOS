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
#include "td/utils/StringBuilder.h"

#include "td/utils/misc.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"

#include <cstdio>
#include <cstring>
#include <limits>
#include <locale>
#include <memory>
#include <sstream>
#include <utility>

namespace td {

StringBuilder::StringBuilder(MutableSlice slice, bool use_buffer)
    : begin_ptr_(slice.begin()), current_ptr_(begin_ptr_), use_buffer_(use_buffer) {
  if (slice.size() <= reserved_size) {
    auto buffer_size = reserved_size + 100;
    buffer_ = std::make_unique<char[]>(buffer_size);
    begin_ptr_ = buffer_.get();
    current_ptr_ = begin_ptr_;
    end_ptr_ = begin_ptr_ + buffer_size - reserved_size;
  } else {
    end_ptr_ = slice.end() - reserved_size;
  }
}

StringBuilder &StringBuilder::operator<<(Slice slice) {
  size_t size = slice.size();
  if (unlikely(!reserve(size))) {
    if (end_ptr_ < current_ptr_) {
      return on_error();
    }
    auto available_size = static_cast<size_t>(end_ptr_ + reserved_size - 1 - current_ptr_);
    if (size > available_size) {
      error_flag_ = true;
      size = available_size;
    }
  }

  std::memcpy(current_ptr_, slice.begin(), size);
  current_ptr_ += size;
  return *this;
}

template <class T>
static char *print_uint(char *current_ptr, T x) {
  if (x < 100) {
    if (x < 10) {
      *current_ptr++ = static_cast<char>('0' + x);
    } else {
      *current_ptr++ = static_cast<char>('0' + x / 10);
      *current_ptr++ = static_cast<char>('0' + x % 10);
    }
    return current_ptr;
  }

  auto begin_ptr = current_ptr;
  do {
    *current_ptr++ = static_cast<char>('0' + x % 10);
    x /= 10;
  } while (x > 0);

  auto end_ptr = current_ptr - 1;
  while (begin_ptr < end_ptr) {
    std::swap(*begin_ptr++, *end_ptr--);
  }

  return current_ptr;
}

template <class T>
static char *print_int(char *current_ptr, T x) {
  if (x < 0) {
    if (x == std::numeric_limits<T>::min()) {
      std::stringstream ss;
      ss << x;
      auto len = narrow_cast<int>(static_cast<std::streamoff>(ss.tellp()));
      ss.read(current_ptr, len);
      return current_ptr + len;
    }

    *current_ptr++ = '-';
    x = -x;
  }

  return print_uint(current_ptr, x);
}

bool StringBuilder::reserve_inner(size_t size) {
  if (!use_buffer_) {
    return false;
  }

  size_t old_data_size = current_ptr_ - begin_ptr_;
  if (size >= std::numeric_limits<size_t>::max() - reserved_size - old_data_size - 1) {
    return false;
  }
  size_t need_data_size = old_data_size + size;
  size_t old_buffer_size = end_ptr_ - begin_ptr_;
  if (old_buffer_size >= (std::numeric_limits<size_t>::max() - reserved_size) / 2 - 2) {
    return false;
  }
  size_t new_buffer_size = (old_buffer_size + 1) * 2;
  if (new_buffer_size < need_data_size) {
    new_buffer_size = need_data_size;
  }
  if (new_buffer_size < 100) {
    new_buffer_size = 100;
  }
  new_buffer_size += reserved_size;
  auto new_buffer = std::make_unique<char[]>(new_buffer_size);
  std::memcpy(new_buffer.get(), begin_ptr_, old_data_size);
  buffer_ = std::move(new_buffer);
  begin_ptr_ = buffer_.get();
  current_ptr_ = begin_ptr_ + old_data_size;
  end_ptr_ = begin_ptr_ + new_buffer_size - reserved_size;
  CHECK(end_ptr_ > current_ptr_);
  CHECK(static_cast<size_t>(end_ptr_ - current_ptr_) >= size);
  return true;
}

StringBuilder &StringBuilder::operator<<(int x) {
  if (unlikely(!reserve())) {
    return on_error();
  }
  current_ptr_ = print_int(current_ptr_, x);
  return *this;
}

StringBuilder &StringBuilder::operator<<(unsigned int x) {
  if (unlikely(!reserve())) {
    return on_error();
  }
  current_ptr_ = print_uint(current_ptr_, x);
  return *this;
}

StringBuilder &StringBuilder::operator<<(long int x) {
  if (unlikely(!reserve())) {
    return on_error();
  }
  current_ptr_ = print_int(current_ptr_, x);
  return *this;
}

StringBuilder &StringBuilder::operator<<(long unsigned int x) {
  if (unlikely(!reserve())) {
    return on_error();
  }
  current_ptr_ = print_uint(current_ptr_, x);
  return *this;
}

StringBuilder &StringBuilder::operator<<(long long int x) {
  if (unlikely(!reserve())) {
    return on_error();
  }
  current_ptr_ = print_int(current_ptr_, x);
  return *this;
}

StringBuilder &StringBuilder::operator<<(long long unsigned int x) {
  if (unlikely(!reserve())) {
    return on_error();
  }
  current_ptr_ = print_uint(current_ptr_, x);
  return *this;
}

StringBuilder &StringBuilder::operator<<(FixedDouble x) {
  if (unlikely(!reserve(std::numeric_limits<double>::max_exponent10 + x.precision + 4))) {
    return on_error();
  }

  static TD_THREAD_LOCAL std::stringstream *ss;
  if (init_thread_local<std::stringstream>(ss)) {
    auto previous_locale = ss->imbue(std::locale::classic());
    ss->setf(std::ios_base::fixed, std::ios_base::floatfield);
  } else {
    ss->str(std::string());
    ss->clear();
  }
  ss->precision(x.precision);
  *ss << x.d;

  int len = narrow_cast<int>(static_cast<std::streamoff>(ss->tellp()));
  auto left = end_ptr_ + reserved_size - current_ptr_;
  if (unlikely(len >= left)) {
    error_flag_ = true;
    len = left ? narrow_cast<int>(left - 1) : 0;
  }
  ss->read(current_ptr_, len);
  current_ptr_ += len;
  return *this;
}

StringBuilder &StringBuilder::operator<<(const void *ptr) {
  if (unlikely(!reserve())) {
    return on_error();
  }
  current_ptr_ += std::snprintf(current_ptr_, reserved_size, "%p", ptr);
  return *this;
}

}  // namespace td
