#import "MTDestroySessionResponseMessage.h"

@implementation MTDestroySessionResponseMessage

@end

@implementation MTDestroySessionResponseOkMessage

- (instancetype)initWithSessionId:(int64_t)sessionId
{
    self = [super init];
    if (self != nil)
    {
        _sessionId = sessionId;
    }
    return self;
}

@end

@implementation MTDestroySessionResponseNoneMessage

- (instancetype)initWithSessionId:(int64_t)sessionId
{
    self = [super init];
    if (self != nil)
    {
        _sessionId = sessionId;
    }
    return self;
}

@end

@implementation MTDestroySessionMultipleResponseMessage

- (instancetype)initWithResponses:(NSData *)responsesData
{
    self = [super init];
    if (self != nil)
    {
        _responsesData = responsesData;
    }
    return self;
}

@end
