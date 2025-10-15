#import <MtProtoKit/MTLogging.h>

static void (*loggingFunction)(NSString *) = NULL;
static void (*shortLoggingFunction)(NSString *) = NULL;
static bool MTLogEnabledValue = true;

bool MTLogEnabled() {
    return loggingFunction != NULL && MTLogEnabledValue;
}

void MTLog(NSString *format, ...) {
    va_list L;
    va_start(L, format);
    if (loggingFunction != NULL) {
        NSString *string = [[NSString alloc] initWithFormat:format arguments:L];
        loggingFunction(string);
    }
    va_end(L);
}

void MTLogWithPrefix(NSString *(^getLogPrefix)(), NSString *format, ...) {
    va_list L;
    va_start(L, format);
    if (loggingFunction != NULL) {
        NSString *string = [[NSString alloc] initWithFormat:format arguments:L];
        if (getLogPrefix) {
            NSString *prefix = getLogPrefix();
            if (prefix) {
                string = [prefix stringByAppendingString:string];
            }
        }
        loggingFunction(string);
    }
    va_end(L);
}

void MTShortLog(NSString *format, ...) {
    va_list L;
    va_start(L, format);
    if (shortLoggingFunction != NULL) {
        NSString *string = [[NSString alloc] initWithFormat:format arguments:L];
        shortLoggingFunction(string);
    }
    va_end(L);
}

void MTLogSetLoggingFunction(void (*function)(NSString *)) {
    loggingFunction = function;
}

void MTLogSetShortLoggingFunction(void (*function)(NSString *)) {
    shortLoggingFunction = function;
}

void MTLogSetEnabled(bool enabled) {
    MTLogEnabledValue = enabled;
}
