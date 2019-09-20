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
#include "td/actor/actor.h"

#include "adnl/adnl-ext-client.h"

namespace tonlib {
class ExtClientOutbound : public ton::adnl::AdnlExtClient {
 public:
  class Callback {
   public:
    virtual ~Callback() {
    }
    virtual void request(td::int64 id, std::string data) = 0;
  };
  virtual void on_query_result(td::int64 id, td::Result<td::BufferSlice> r_data, td::Promise<td::Unit> promise) = 0;
  static td::actor::ActorOwn<ExtClientOutbound> create(td::unique_ptr<Callback> callback);
};

}  // namespace tonlib
