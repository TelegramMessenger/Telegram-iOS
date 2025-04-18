#import "MTFutureSaltsMessage.h"

@implementation MTFutureSalt

- (instancetype)initWithValidSince:(int32_t)validSince validUntil:(int32_t)validUntil salt:(int64_t)salt
{
    self = [super init];
    if (self != nil)
    {
        _validSince = validSince;
        _validUntil = validUntil;
        _salt = salt;
    }
    return self;
}

@end

@implementation MTFutureSaltsMessage

- (instancetype)initWithRequestMessageId:(int64_t)requestMessageId now:(int32_t)now salts:(NSArray *)salts
{
    self = [super init];
    if (self != nil)
    {
        _requestMessageId = requestMessageId;
        _now = now;
        _salts = salts;
    }
    return self;
}

@end
