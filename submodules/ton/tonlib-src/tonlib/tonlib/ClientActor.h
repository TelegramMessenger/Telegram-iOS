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

#include "tonlib/TonlibCallback.h"
#include "tonlib/TonlibClient.h"
#include "auto/tl/tonlib_api.h"

namespace tonlinb {
class ClientActor : public td::actor::Actor {
 public:
  explicit ClientActor(td::unique_ptr<TonlibCallback> callback);
  void request(td::uint64 id, tonlib_api::object_ptr<tonlib_api::Function> request);
  static tonlib_api::object_ptr<tonlib_api::Object> execute(tonlib_api::object_ptr<tonlib_api::Function> request);
  ~ClientActor();
  ClientActor(ClientActor&& other);
  ClientActor& operator=(ClientActor&& other);

  ClientActor(const ClientActor& other) = delete;
  ClientActor& operator=(const ClientActor& other) = delete;

 private:
  td::actor::ActorOwn<TonlibClient> tonlib_;
};
}  // namespace tonlinb
