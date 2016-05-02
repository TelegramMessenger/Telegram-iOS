// Adapted from 0xced’s post at http://stackoverflow.com/questions/34732814/how-should-i-handle-logs-in-an-objective-c-library/34732815#34732815

#import <Foundation/Foundation.h>
#import "HockeySDKEnums.h"

#define BITHockeyLog(_level, _message) [BITHockeyLogger logMessage:_message level:_level file:__FILE__ function:__PRETTY_FUNCTION__ line:__LINE__]

#define BITHockeyLogError(format, ...)   BITHockeyLog(BITLogLevelError,   (^{ return [NSString stringWithFormat:(format), ##__VA_ARGS__]; }))
#define BITHockeyLogWarning(format, ...) BITHockeyLog(BITLogLevelWarning, (^{ return [NSString stringWithFormat:(format), ##__VA_ARGS__]; }))
#define BITHockeyLogDebug(format, ...)   BITHockeyLog(BITLogLevelDebug,   (^{ return [NSString stringWithFormat:(format), ##__VA_ARGS__]; }))
#define BITHockeyLogVerbose(format, ...) BITHockeyLog(BITLogLevelVerbose, (^{ return [NSString stringWithFormat:(format), ##__VA_ARGS__]; }))

@interface BITHockeyLogger : NSObject

+ (BITLogLevel)currentLogLevel;
+ (void)setCurrentLogLevel:(BITLogLevel)currentLogLevel;
+ (void)setLogHandler:(BITLogHandler)logHandler;

+ (void)logMessage:(BITLogMessageProvider)messageProvider level:(BITLogLevel)loglevel file:(const char *)file function:(const char *)function line:(uint)line;

@end
