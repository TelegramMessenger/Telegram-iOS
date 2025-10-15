//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/TlObject.h"

#include "td/utils/SliceBuilder.h"
#include "td/utils/UInt.h"

#include <cstdint>
#include <string>
#include <vector>

namespace td {

template <class Func, std::int32_t constructor_id>
class TlFetchBoxed {
 public:
  template <class ParserT>
  static auto parse(ParserT &parser) -> decltype(Func::parse(parser)) {
    auto parsed_constructor_id = parser.fetch_int();
    if (parsed_constructor_id != constructor_id) {
      parser.set_error(PSTRING() << "Wrong constructor " << parsed_constructor_id << " found instead of "
                                 << constructor_id);
      return decltype(Func::parse(parser))();
    }
    return Func::parse(parser);
  }
};

class TlFetchBool {
 public:
  template <class ParserT>
  static bool parse(ParserT &parser) {
    constexpr std::int32_t ID_BOOL_FALSE = 0xbc799737;
    constexpr std::int32_t ID_BOOL_TRUE = 0x997275b5;

    std::int32_t c = parser.fetch_int();
    if (c == ID_BOOL_TRUE) {
      return true;
    }
    if (c != ID_BOOL_FALSE) {
      parser.set_error("Bool expected");
    }
    return false;
  }
};

class TlFetchInt {
 public:
  template <class ParserT>
  static std::int32_t parse(ParserT &parser) {
    return parser.fetch_int();
  }
};

class TlFetchLong {
 public:
  template <class ParserT>
  static std::int64_t parse(ParserT &parser) {
    return parser.fetch_long();
  }
};

class TlFetchDouble {
 public:
  template <class ParserT>
  static double parse(ParserT &parser) {
    return parser.fetch_double();
  }
};

class TlFetchInt128 {
 public:
  template <class ParserT>
  static UInt128 parse(ParserT &parser) {
    return parser.template fetch_binary<UInt128>();
  }
};

class TlFetchInt256 {
 public:
  template <class ParserT>
  static UInt256 parse(ParserT &parser) {
    return parser.template fetch_binary<UInt256>();
  }
};

class TlFetchInt512 {
 public:
  template <class ParserT>
  static UInt512 parse(ParserT &parser) {
    return parser.template fetch_binary<UInt512>();
  }
};

template <class T>
class TlFetchString {
 public:
  template <class ParserT>
  static T parse(ParserT &parser) {
    return parser.template fetch_string<T>();
  }
};

template <class T>
class TlFetchBytes {
 public:
  template <class ParserT>
  static T parse(ParserT &parser) {
    return parser.template fetch_string<T>();
  }
};

template <class Func>
class TlFetchVector {
 public:
  template <class ParserT>
  static auto parse(ParserT &parser) -> std::vector<decltype(Func::parse(parser))> {
    const std::uint32_t multiplicity = parser.fetch_int();
    std::vector<decltype(Func::parse(parser))> v;
    if (parser.get_left_len() < multiplicity) {
      parser.set_error("Wrong vector length");
    } else {
      v.reserve(multiplicity);
      for (std::uint32_t i = 0; i < multiplicity; i++) {
        v.push_back(Func::parse(parser));
      }
    }
    return v;
  }
};

template <class T>
class TlFetchObject {
 public:
  template <class ParserT>
  static tl_object_ptr<T> parse(ParserT &parser) {
    return T::fetch(parser);
  }
};

}  // namespace td
