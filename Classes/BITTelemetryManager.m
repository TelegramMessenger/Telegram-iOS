#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_TELEMETRY

#import "BITTelemetryManager.h"
#import "BITTelemetryManagerPrivate.h"

static char *const kBITTelemetryEventQueue =
"com.microsoft.ApplicationInsights.telemetryEventQueue";

@implementation BITTelemetryManager {
  id _appDidEnterBackgroundObserver;
  id _appWillResignActiveObserver;
  id _sessionStartedObserver;
  id _sessionEndedObserver;
}

- (instancetype)init {
  if((self = [super init])) {
    _telemetryEventQueue = dispatch_queue_create(kBITTelemetryEventQueue, DISPATCH_QUEUE_CONCURRENT);
  }
  return self;
}

- (void)startManager {
}

@end

#endif /* HOCKEYSDK_FEATURE_TELEMETRY */
