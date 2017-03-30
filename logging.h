//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef __LOGGING_H
#define __LOGGING_H
#define LSTR_INT(x) LSTR_DO_INT(x)
#define LSTR_DO_INT(x) #x

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

void tgvoip_log_file_printf(char level, const char* msg, ...);

#if defined(__ANDROID__)

#include <android/log.h>

//#define _LOG_WRAP(...) __BASE_FILE__":"LSTR_INT(__LINE__)": "__VA_ARGS__
#define _LOG_WRAP(...) __VA_ARGS__
#define TAG "tg-voip-native"
#define LOGV(...) {__android_log_print(ANDROID_LOG_VERBOSE, TAG, _LOG_WRAP(__VA_ARGS__)); tgvoip_log_file_printf('V', __VA_ARGS__);}
#define LOGD(...) {__android_log_print(ANDROID_LOG_DEBUG, TAG, _LOG_WRAP(__VA_ARGS__)); tgvoip_log_file_printf('D', __VA_ARGS__);}
#define LOGI(...) {__android_log_print(ANDROID_LOG_INFO, TAG, _LOG_WRAP(__VA_ARGS__)); tgvoip_log_file_printf('I', __VA_ARGS__);}
#define LOGW(...) {__android_log_print(ANDROID_LOG_WARN, TAG, _LOG_WRAP(__VA_ARGS__)); tgvoip_log_file_printf('W', __VA_ARGS__);}
#define LOGE(...) {__android_log_print(ANDROID_LOG_ERROR, TAG, _LOG_WRAP(__VA_ARGS__)); tgvoip_log_file_printf('E', __VA_ARGS__);}

#elif defined(__APPLE__) && TARGET_OS_IPHONE

#include "os/darwin/TGLogWrapper.h"

#define LOGV(msg, ...) __tgvoip_call_tglog("V/tgvoip: " msg, ##__VA_ARGS__)
#define LOGD(msg, ...) __tgvoip_call_tglog("D/tgvoip: " msg, ##__VA_ARGS__)
#define LOGI(msg, ...) __tgvoip_call_tglog("I/tgvoip: " msg, ##__VA_ARGS__)
#define LOGW(msg, ...) __tgvoip_call_tglog("W/tgvoip: " msg, ##__VA_ARGS__)
#define LOGE(msg, ...) __tgvoip_call_tglog("E/tgvoip: " msg, ##__VA_ARGS__)

#else

#include <stdio.h>

#define LOGV(msg, ...) printf("V/tgvoip: " msg "\n", ##__VA_ARGS__)
#define LOGD(msg, ...) printf("D/tgvoip: " msg "\n", ##__VA_ARGS__)
#define LOGI(msg, ...) printf("I/tgvoip: " msg "\n", ##__VA_ARGS__)
#define LOGW(msg, ...) printf("W/tgvoip: " msg "\n", ##__VA_ARGS__)
#define LOGE(msg, ...) printf("E/tgvoip: " msg "\n", ##__VA_ARGS__)

#endif

#endif //__LOGGING_H
