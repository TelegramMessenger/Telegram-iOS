#import "NetworkLogging.h"

#import <Foundation/Foundation.h>

#if TARGET_OS_MAC || TARGET_OS_OSX
#   import <MTProtoKitMac/MTLogging.h>
#else
#   import <MTProtoKitDynamic/MTLogging.h>
#endif

static void (*bridgingTrace)(NSString *, NSString *);
void setBridgingTraceFunction(void (*f)(NSString *, NSString *)) {
    bridgingTrace = f;
}

#if TARGET_IPHONE_SIMULATOR
static bool loggingEnabled = false;
#else
static bool loggingEnabled = false;
#endif

static void TGTelegramLoggingFunction(NSString *format, va_list args) {
    if (bridgingTrace) {
        bridgingTrace(@"MT", [[NSString alloc] initWithFormat:format arguments:args]);
    }
}

void NetworkRegisterLoggingFunction() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (loggingEnabled) {
            MTLogSetLoggingFunction(&TGTelegramLoggingFunction);
        }
    });
}
