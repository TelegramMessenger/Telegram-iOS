//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/UInt.h"

namespace td {

class TlStorerToString {
  decltype(StackAllocator::alloc(0)) buffer_ = StackAllocator::alloc(1 << 14);
  StringBuilder sb_ = StringBuilder(buffer_.as_slice(), true);
  size_t shift_ = 0;

  void store_field_begin(Slice name) {
    sb_.append_char(shift_, ' ');
    if (!name.empty()) {
      sb_ << name << " = ";
    }
  }

  void store_field_end() {
    sb_.push_back('\n');
  }

  void store_binary(Slice data) {
    static const char *hex = "0123456789ABCDEF";

    sb_ << "{ ";
    for (auto c : data) {
      unsigned char byte = c;
      sb_.push_back(hex[byte >> 4]);
      sb_.push_back(hex[byte & 15]);
      sb_.push_back(' ');
    }
    sb_.push_back('}');
  }

 public:
  TlStorerToString() = default;
  TlStorerToString(const TlStorerToString &) = delete;
  TlStorerToString &operator=(const TlStorerToString &) = delete;
  TlStorerToString(TlStorerToString &&) = delete;
  TlStorerToString &operator=(TlStorerToString &&) = delete;

  void store_field(Slice name, const string &value) {
    store_field_begin(name);
    sb_.push_back('"');
    sb_ << value;
    sb_.push_back('"');
    store_field_end();
  }

  void store_field(Slice name, const SecureString &value) {
    store_field_begin(name);
    sb_ << "<secret>";
    store_field_end();
  }

  template <class T>
  void store_field(Slice name, const T &value) {
    store_field_begin(name);
    sb_ << value;
    store_field_end();
  }

  void store_bytes_field(Slice name, const SecureString &value) {
    store_field_begin(name);
    sb_ << "<secret>";
    store_field_end();
  }

  template <class BytesT>
  void store_bytes_field(Slice name, const BytesT &value) {
    static const char *hex = "0123456789ABCDEF";

    store_field_begin(name);
    sb_ << "bytes [" << value.size() << "] { ";
    size_t len = min(static_cast<size_t>(64), value.size());
    for (size_t i = 0; i < len; i++) {
      int b = value[static_cast<int>(i)] & 0xff;
      sb_.push_back(hex[b >> 4]);
      sb_.push_back(hex[b & 15]);
      sb_.push_back(' ');
    }
    if (len < value.size()) {
      sb_ << "...";
    }
    sb_.push_back('}');
    store_field_end();
  }

  template <class ObjectT>
  void store_object_field(CSlice name, const ObjectT *value) {
    if (value == nullptr) {
      store_field(name, Slice("null"));
    } else {
      value->store(*this, name.c_str());
    }
  }

  void store_field(Slice name, const UInt128 &value) {
    store_field_begin(name);
    store_binary(as_slice(value));
    store_field_end();
  }

  void store_field(Slice name, const UInt256 &value) {
    store_field_begin(name);
    store_binary(as_slice(value));
    store_field_end();
  }

  void store_field(Slice name, const UInt512 &value) {
    store_field_begin(name);
    store_binary(as_slice(value));
    store_field_end();
  }

  void store_vector_begin(Slice field_name, size_t vector_size) {
    store_field_begin(field_name);
    sb_ << "vector[" << vector_size << "] {\n";
    shift_ += 2;
  }

  void store_class_begin(const char *field_name, Slice class_name) {
    store_field_begin(Slice(field_name));
    sb_ << class_name << " {\n";
    shift_ += 2;
  }

  void store_class_end() {
    CHECK(shift_ >= 2);
    shift_ -= 2;
    sb_.append_char(shift_, ' ');
    sb_ << "}\n";
  }

  string move_as_string() {
    return sb_.as_cslice().str();
  }
};

}  // namespace td
