//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/td_c_client.h"

#include "td/telegram/Client.h"
#include "td/telegram/Log.h"
#include "td/telegram/td_tdc_api_inner.h"

#include <cstring>

static td::ClientManager *GetClientManager() {
  return td::ClientManager::get_manager_singleton();
}

int TdCClientCreateId() {
  return GetClientManager()->create_client_id();
}

void TdCClientSend(int client_id, struct TdRequest request) {
  GetClientManager()->send(client_id, request.request_id, TdConvertToInternal(request.function));
  TdDestroyObjectFunction(request.function);
}

TdResponse TdCClientReceive(double timeout) {
  auto response = GetClientManager()->receive(timeout);
  TdResponse c_response;
  c_response.client_id = response.client_id;
  c_response.request_id = response.request_id;
  c_response.object = response.object == nullptr ? nullptr : TdConvertFromInternal(*response.object);
  return c_response;
}

TdObject *TdCClientExecute(TdFunction *function) {
  auto result = td::ClientManager::execute(TdConvertToInternal(function));
  TdDestroyObjectFunction(function);
  return TdConvertFromInternal(*result);
}

TdVectorInt *TdCreateObjectVectorInt(int size, int *data) {
  auto res = new TdVectorInt();
  res->len = size;
  res->data = new int[size];
  std::memcpy(res->data, data, sizeof(int) * size);
  return res;
}

TdVectorLong *TdCreateObjectVectorLong(int size, long long *data) {
  auto res = new TdVectorLong();
  res->len = size;
  res->data = new long long[size];
  std::memcpy(res->data, data, sizeof(long long) * size);
  return res;
}

TdVectorObject *TdCreateObjectVectorObject(int size, TdObject **data) {
  auto res = new TdVectorObject();
  res->len = size;
  res->data = new TdObject *[size];
  std::memcpy(res->data, data, sizeof(TdObject *) * size);
  return res;
}

TdBytes TdCreateObjectBytes(unsigned char *data, int len) {
  TdBytes res;
  res.len = len;
  res.data = new unsigned char[len];
  std::memcpy(res.data, data, len);
  return res;
}
