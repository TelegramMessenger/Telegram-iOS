#import <MtProtoKit/MTLogging.h>

static void (*loggingFunction)(NSString *, va_list args) = NULL;
static void (*shortLoggingFunction)(NSString *, va_list args) = NULL;
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

void MTShortLog(NSString *format, ...) {
    va_list L;
    va_start(L, format);
    if (shortLoggingFunction != NULL) {
        shortLoggingFunction(format, L);
    }
    va_end(L);
}

void MTLogSetLoggingFunction(void (*function)(NSString *, va_list args)) {
    loggingFunction = function;
}

void MTLogSetShortLoggingFunction(void (*function)(NSString *, va_list args)) {
    shortLoggingFunction = function;
}

void MTLogSetEnabled(bool enabled) {
    MTLogEnabledValue = enabled;
}
