#import <MtProtoKit/MTRpcError.h>

@implementation MTRpcError

- (instancetype)initWithErrorCode:(int32_t)errorCode errorDescription:(NSString *)errorDescription
{
    self = [super init];
    if (self != nil)
    {
        _errorCode = errorCode;
        _errorDescription = errorDescription;
    }
    return self;
}

- (NSString *)description {
    return [[NSString alloc] initWithFormat:@"%d: %@", _errorCode, _errorDescription];
}

@end
