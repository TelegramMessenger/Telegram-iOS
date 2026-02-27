

#ifndef MTLogging_H
#define MTLogging_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

bool MTLogEnabled();
void MTLog(NSString *format, ...);
void MTLogWithPrefix(NSString *(^getLogPrefix)(), NSString *format, ...);
void MTShortLog(NSString *format, ...);
void MTLogSetLoggingFunction(void (*function)(NSString *));
void MTLogSetShortLoggingFunction(void (*function)(NSString *));
void MTLogSetEnabled(bool);

#ifdef __cplusplus
}
#endif

#endif
