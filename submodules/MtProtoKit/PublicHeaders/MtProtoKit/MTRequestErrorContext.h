

#import <Foundation/Foundation.h>

@interface MTRequestErrorContext : NSObject

@property (nonatomic) CFAbsoluteTime minimalExecuteTime;

@property (nonatomic) NSUInteger internalServerErrorCount;
@property (nonatomic) NSUInteger floodWaitSeconds;
@property (nonatomic, strong) NSString *floodWaitErrorText;

@property (nonatomic) bool waitingForTokenExport;
@property (nonatomic, strong) id waitingForRequestToComplete;

@end
