//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "td/telegram/td_tdc_api.h"

struct TdVectorInt *TdCreateObjectVectorInt(int size, int *data);
struct TdVectorLong *TdCreateObjectVectorLong(int size, long long *data);
struct TdVectorObject *TdCreateObjectVectorObject(int size, struct TdObject **data);
struct TdBytes TdCreateObjectBytes(unsigned char *data, int len);

struct TdRequest {
  long long request_id;
  struct TdFunction *function;
};

struct TdResponse {
  long long request_id;
  int client_id;
  struct TdObject *object;
};

int TdCClientCreateId();

void TdCClientSend(int client_id, struct TdRequest request);

struct TdResponse TdCClientReceive(double timeout);

struct TdObject *TdCClientExecute(struct TdFunction *function);

#ifdef __cplusplus
}
#endif
