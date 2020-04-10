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

#include "auto/tl/tonlib_api.h"

namespace tonlib_api = ton::tonlib_api;
namespace tonlib {

class TonlibCallback {
 public:
  virtual void on_result(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::Object> result) = 0;
  virtual void on_error(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::error> error) = 0;
  virtual ~TonlibCallback() = default;
};
}  // namespace tonlib
