#import "TGUserHandle.h"
#import "TGStringUtils.h"

@implementation TGUserHandle

- (instancetype)initWithHandle:(NSString *)handle type:(NSString *)type handleType:(TGUserHandleType)handleType data:(NSString *)data
{
    self = [super init];
    if (self != nil)
    {
        _handle = handle;
        _type = type;
        _handleType = handleType;
        _data = data;
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return [TGStringUtils md5WithString:[NSString stringWithFormat:@"%@,%@,%zu", self.handle, self.type, (unsigned long)self.handleType]];
}

@end