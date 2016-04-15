// Adapted from 0xced’s post at http://stackoverflow.com/questions/34732814/how-should-i-handle-logs-in-an-objective-c-library/34732815#34732815

#import <Foundation/Foundation.h>
#import "HockeySDKEnums.h"

#define BITHockeyLog(_level, _message, ...) [BITHockeyLogger logLevel:_level file:__FILE__ function:__PRETTY_FUNCTION__ line:__LINE__ message:_message, ##__VA_ARGS__]

#define BITHockeyLogError(format, ...)   BITHockeyLog(BITLogLevelError,   format, ##__VA_ARGS__)
#define BITHockeyLogWarning(format, ...) BITHockeyLog(BITLogLevelWarning, format, ##__VA_ARGS__)
#define BITHockeyLogDebug(format, ...)   BITHockeyLog(BITLogLevelDebug,   format, ##__VA_ARGS__)
#define BITHockeyLogVerbose(format, ...) BITHockeyLog(BITLogLevelVerbose, format, ##__VA_ARGS__)

typedef void (^BITLogHandler)(BITLogLevel, const char *, const char *, uint, NSString *);

@interface BITHockeyLogger : NSObject

+ (BITLogLevel)currentLogLevel;
+ (void)setCurrentLogLevel:(BITLogLevel)currentLogLevel;

+ (void)setLogHandler:(BITLogHandler)logHandler;

+ (void)logLevel:(BITLogLevel)loglevel file:(const char *)file function:(const char *)function line:(uint)line message:(NSString *)message, ...;

@end
