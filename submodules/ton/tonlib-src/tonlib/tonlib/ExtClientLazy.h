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
class ExtClientLazy {
 public:
  class Callback {
   public:
    virtual ~Callback() {
    }
  };
  static td::actor::ActorOwn<ton::adnl::AdnlExtClient> create(ton::adnl::AdnlNodeIdFull dst, td::IPAddress dst_addr,
                                                              td::unique_ptr<Callback> callback);
};

}  // namespace tonlib
