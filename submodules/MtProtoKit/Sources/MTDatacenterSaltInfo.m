#import <MtProtoKit/MTDatacenterSaltInfo.h>

@implementation MTDatacenterSaltInfo

- (instancetype)initWithSalt:(int64_t)salt firstValidMessageId:(int64_t)firstValidMessageId lastValidMessageId:(int64_t)lastValidMessageId
{
    self = [super init];
    if (self != nil)
    {
        _salt = salt;
        _firstValidMessageId = firstValidMessageId;
        _lastValidMessageId = lastValidMessageId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _salt = [aDecoder decodeInt64ForKey:@"salt"];
        _firstValidMessageId = [aDecoder decodeInt64ForKey:@"firstValidMessageId"];
        _lastValidMessageId = [aDecoder decodeInt64ForKey:@"lastValidMessageId"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:_salt forKey:@"salt"];
    [aCoder encodeInt64:_firstValidMessageId forKey:@"firstValidMessageId"];
    [aCoder encodeInt64:_lastValidMessageId forKey:@"lastValidMessageId"];
}

- (int64_t)validMessageCountAfterId:(int64_t)messageId
{
    if (messageId < _firstValidMessageId)
        return 0;
    
    return MAX(0, _lastValidMessageId - messageId);
}

- (bool)isValidFutureSaltForMessageId:(int64_t)messageId
{
    return _lastValidMessageId > messageId;
}

@end
