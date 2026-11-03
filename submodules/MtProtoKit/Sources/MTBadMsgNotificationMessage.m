#import "MTBadMsgNotificationMessage.h"

@implementation MTBadMsgNotificationMessage

- (instancetype)initWithBadMessageId:(int64_t)badMessageId badMessageSeqNo:(int32_t)badMessageSeqNo errorCode:(int32_t)errorCode
{
    self = [super init];
    if (self != nil)
    {
        _badMessageId = badMessageId;
        _badMessageSeqNo = badMessageSeqNo;
        _errorCode = errorCode;
    }
    return self;
}

@end

@implementation MTBadServerSaltNotificationMessage

- (instancetype)initWithBadMessageId:(int64_t)badMessageId badMessageSeqNo:(int32_t)badMessageSeqNo errorCode:(int32_t)errorCode nextServerSalt:(int64_t)nextServerSalt
{
    self = [super initWithBadMessageId:badMessageId badMessageSeqNo:badMessageSeqNo errorCode:errorCode];
    if (self != nil)
    {
        _nextServerSalt = nextServerSalt;
    }
    return self;
}

@end