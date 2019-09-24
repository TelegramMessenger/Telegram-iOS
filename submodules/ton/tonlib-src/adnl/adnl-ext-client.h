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

#include "adnl-node-id.hpp"
#include "td/utils/port/IPAddress.h"

namespace ton {

namespace adnl {

class AdnlExtClient : public td::actor::Actor {
 public:
  class Callback {
   public:
    virtual ~Callback() = default;
    virtual void on_ready() = 0;
    virtual void on_stop_ready() = 0;
  };
  virtual ~AdnlExtClient() = default;
  virtual void check_ready(td::Promise<td::Unit> promise) = 0;
  virtual void send_query(std::string name, td::BufferSlice data, td::Timestamp timeout,
                          td::Promise<td::BufferSlice> promise) = 0;
  static td::actor::ActorOwn<AdnlExtClient> create(AdnlNodeIdFull dst, td::IPAddress dst_addr,
                                                   std::unique_ptr<AdnlExtClient::Callback> callback);
  static td::actor::ActorOwn<AdnlExtClient> create(AdnlNodeIdFull dst, PrivateKey local_id, td::IPAddress dst_addr,
                                                   std::unique_ptr<AdnlExtClient::Callback> callback);
};

class AdnlExtMultiClient : public AdnlExtClient {
 public:
  virtual void add_server(AdnlNodeIdFull dst, td::IPAddress dst_addr, td::Promise<td::Unit> promise) = 0;
  virtual void del_server(td::IPAddress dst_addr, td::Promise<td::Unit> promise) = 0;
  static td::actor::ActorOwn<AdnlExtMultiClient> create(std::vector<std::pair<AdnlNodeIdFull, td::IPAddress>> ids,
                                                        std::unique_ptr<AdnlExtClient::Callback> callback);
};

}  // namespace adnl

}  // namespace ton
