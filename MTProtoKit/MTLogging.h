/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#ifndef MTLogging_H
#define MTLogging_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

bool MTLogEnabled();
void MTLog(NSString *format, ...);
void MTLogSetLoggingFunction(void (*function)(NSString *, va_list args));
void MTLogSetEnabled(bool);

#ifdef __cplusplus
}
#endif

#endif
