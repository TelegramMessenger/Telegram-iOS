#import <MtProtoKit/MTDropResponseContext.h>

@implementation MTDropResponseContext

- (instancetype)initWithDropMessageId:(int64_t)dropMessageId
{
    self = [super init];
    if (self != nil)
    {
        _dropMessageId = dropMessageId;
    }
    return self;
}

@end
