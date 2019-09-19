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

namespace td {

template <class FunctionT>
struct member_function_class;

template <class ReturnType, class Type, class... Args>
struct member_function_class<ReturnType (Type::*)(Args...)> {
  using type = Type;
  static constexpr size_t argument_count() {
    return sizeof...(Args);
  }
};

template <class FunctionT>
using member_function_class_t = typename member_function_class<FunctionT>::type;

template <class FunctionT>
constexpr size_t member_function_argument_count() {
  return member_function_class<FunctionT>::argument_count();
}

}  // namespace td
