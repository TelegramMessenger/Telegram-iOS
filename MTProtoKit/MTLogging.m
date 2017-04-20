/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTLogging.h"

static void (*loggingFunction)(NSString *, va_list args) = NULL;
static bool MTLogEnabledValue = true;

bool MTLogEnabled() {
    return loggingFunction != NULL && MTLogEnabledValue;
}

void MTLog(NSString *format, ...) {
    va_list L;
    va_start(L, format);
    if (loggingFunction != NULL) {
        loggingFunction(format, L);
    }
    va_end(L);
}

void MTLogSetLoggingFunction(void (*function)(NSString *, va_list args)) {
    loggingFunction = function;
}

void MTLogSetEnabled(bool enabled) {
    MTLogEnabledValue = enabled;
}
