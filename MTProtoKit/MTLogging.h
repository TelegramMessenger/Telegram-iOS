

#ifndef MTLogging_H
#define MTLogging_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

bool MTLogEnabled();
void MTLog(NSString *format, ...);
void MTShortLog(NSString *format, ...);
void MTLogSetLoggingFunction(void (*function)(NSString *, va_list args));
void MTLogSetShortLoggingFunction(void (*function)(NSString *, va_list args));
void MTLogSetEnabled(bool);

#ifdef __cplusplus
}
#endif

#endif
