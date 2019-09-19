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

#include "tonlib/tonlibjson_export.h"

#ifdef __cplusplus
extern "C" {
#endif

TONLIBJSON_EXPORT void *tonlib_client_json_create();

TONLIBJSON_EXPORT void tonlib_client_json_send(void *client, const char *request);

TONLIBJSON_EXPORT const char *tonlib_client_json_receive(void *client, double timeout);

TONLIBJSON_EXPORT const char *tonlib_client_json_execute(void *client, const char *request);

TONLIBJSON_EXPORT void tonlib_client_json_destroy(void *client);

#ifdef __cplusplus
}  // extern "C"
#endif
