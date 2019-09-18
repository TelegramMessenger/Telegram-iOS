#pragma once

#include "tonlibjson_export.h"

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
