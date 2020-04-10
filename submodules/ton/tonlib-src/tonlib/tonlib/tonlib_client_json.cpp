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
#include "tonlib/tonlib_client_json.h"

#include "tonlib/ClientJson.h"

#include "td/utils/Slice.h"

extern "C" int tonlib_client_json_square(int x, const char *str) {
  return x * x;
}

void *tonlib_client_json_create() {
  return new tonlib::ClientJson();
}

void tonlib_client_json_destroy(void *client) {
  delete static_cast<tonlib::ClientJson *>(client);
}

void tonlib_client_json_send(void *client, const char *request) {
  static_cast<tonlib::ClientJson *>(client)->send(td::Slice(request == nullptr ? "" : request));
}

const char *tonlib_client_json_receive(void *client, double timeout) {
  auto slice = static_cast<tonlib::ClientJson *>(client)->receive(timeout);
  if (slice.empty()) {
    return nullptr;
  } else {
    return slice.c_str();
  }
}

const char *tonlib_client_json_execute(void *client, const char *request) {
  auto slice = tonlib::ClientJson::execute(td::Slice(request == nullptr ? "" : request));
  if (slice.empty()) {
    return nullptr;
  } else {
    return slice.c_str();
  }
}
