#import "TGChatTimestamp.h"

@interface TGChatTimestamp ()
{
    NSString *_cachedIdentifier;
}
@end

@implementation TGChatTimestamp

- (instancetype)initWithDate:(NSTimeInterval)date string:(NSString *)string
{
    self = [super init];
    if (self != nil)
    {
        _date = date;
        _string = string;
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    if (_cachedIdentifier == nil)
        _cachedIdentifier = [NSString stringWithFormat:@"ts-%ld", (long)_date];
    
    return _cachedIdentifier;
}

@end
