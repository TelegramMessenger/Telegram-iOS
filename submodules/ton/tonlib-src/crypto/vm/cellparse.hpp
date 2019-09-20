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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once
#include "vm/cells.h"
#include "vm/cellslice.h"

namespace vm {

class CellRefParser {
  Ref<CellSlice> cs;
  bool state;

 public:
  CellRefParser(Ref<CellSlice> _cs) : cs(std::move(_cs)), state(cs.not_null()) {
  }
  bool ok() const {
    return state;
  }
  operator bool() const {
    return state;
  }
  template <class T>
  CellRefParser& deserialize(T& val) {
    state = (state && val.deserialize(cs.write()));
    return *this;
  }
  //template <class T>
  //CellRefParser& deserialize(T& val) {
  //  state = val.deserialize_ext(cs.write(), state);
  //  return *this;
  //}
  template <class T>
  CellRefParser& deserialize(const T& val) {
    state = (state && val.deserialize(cs.write()));
    return *this;
  }
  //template <class T>
  //CellRefParser& deserialize(const T& val) {
  //  state = val.deserialize_ext(cs.write(), state);
  //  return *this;
  //}
};

class CellParser {
  CellSlice& cs;
  bool state;

 public:
  CellParser(CellSlice& _cs) : cs(_cs), state(true) {
  }
  bool ok() const {
    return state;
  }
  operator bool() const {
    return state;
  }
  template <class T>
  CellParser& deserialize(T& val) {
    state = (state && val.deserialize(cs));
    return *this;
  }
  // template <class T>
  // CellParser& deserialize(T& val) {
  //  state = val.deserialize_ext(cs, state);
  //  return *this;
  // }
  template <class T>
  CellParser& deserialize(const T& val) {
    state = (state && val.deserialize(cs));
    return *this;
  }
  // template <class T>
  // CellParser& deserialize(const T& val) {
  //  state = val.deserialize_ext(cs, state);
  //  return *this;
  // }
};

template <class P, class T>
P& operator>>(P& cp, T& val) {
  return cp.deserialize(val);
}

template <class P, class T>
P& operator>>(P& cp, const T& val) {
  return cp.deserialize(val);
}

}  // namespace vm
