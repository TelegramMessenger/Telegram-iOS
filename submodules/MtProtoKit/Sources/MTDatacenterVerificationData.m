#import <MtProtoKit/MTDatacenterVerificationData.h>

@implementation MTDatacenterVerificationData

- (instancetype _Nonnull)initWithDatacenterId:(NSInteger)datacenterId isTestingEnvironment:(bool)isTestingEnvironment {
    self = [super init];
    if (self != nil) {
        _datacenterId = datacenterId;
        _isTestingEnvironment = isTestingEnvironment;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"datacenterId: %d, isTestingEnvironment: %d", (int)_datacenterId, _isTestingEnvironment ? 1 : 0];
}

@end
