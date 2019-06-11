

#import <Foundation/Foundation.h>

@interface MTRequestErrorContext : NSObject

@property (nonatomic) CFAbsoluteTime minimalExecuteTime;

@property (nonatomic) NSUInteger internalServerErrorCount;
@property (nonatomic) NSUInteger floodWaitSeconds;

@property (nonatomic) bool waitingForTokenExport;

@end
