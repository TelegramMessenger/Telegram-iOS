#import "BITHockeyLogger.h"
#import "HockeySDK.h"

@implementation BITHockeyLogger

static BITLogLevel _currentLogLevel = BITLogLevelWarning;

+ (BITLogLevel)currentLogLevel {
  return _currentLogLevel;
}

+ (void)setCurrentLogLevel:(BITLogLevel)currentLogLevel {
  _currentLogLevel = currentLogLevel;
}

static BITLogHandler currentLogHandler = ^(BITLogLevel logLevel, const char *file, const char *function, uint line, NSString *message) {
  if (message) {
    if (_currentLogLevel < logLevel) {
      return;
    }
    NSLog((@"[HockeySDK] %s/%d %@"), function, line, message);
  }
};

+ (void)setLogHandler:(BITLogHandler)logHandler {
  currentLogHandler = logHandler;
}

+ (void)logLevel:(BITLogLevel)loglevel file:(const char *)file function:(const char *)function line:(uint)line message:(NSString *)message, ... {
  if (currentLogHandler) {
    va_list args;
    va_start(args, message);
    currentLogHandler(loglevel, file, function, line, [[NSString alloc] initWithFormat:message arguments:args]);
    va_end(args);
  }
}

@end
