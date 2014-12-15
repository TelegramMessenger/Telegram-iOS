#import "MTMsgDetailedInfoMessage.h"

@implementation MTMsgDetailedInfoMessage

- (instancetype)initWithResponseMessageId:(int64_t)responseMessageId responseLength:(int32_t)responseLength status:(int32_t)status
{
    self = [super init];
    if (self != nil)
    {
        _responseMessageId = responseMessageId;
        _responseLength = responseLength;
        _status = status;
    }
    return self;
}

@end

@implementation MTMsgDetailedResponseInfoMessage

- (instancetype)initWithRequestMessageId:(int64_t)requestMessageId responseMessageId:(int64_t)responseMessageId responseLength:(int32_t)responseLength status:(int32_t)status
{
    self = [super initWithResponseMessageId:responseMessageId responseLength:responseLength status:status];
    if (self != nil)
    {
        _requestMessageId = requestMessageId;
    }
    return self;
}

@end