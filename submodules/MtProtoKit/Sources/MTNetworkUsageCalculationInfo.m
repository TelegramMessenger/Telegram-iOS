#import <MtProtoKit/MTNetworkUsageCalculationInfo.h>

@implementation MTNetworkUsageCalculationInfo

- (instancetype)initWithFilePath:(NSString *)filePath incomingWWANKey:(int32_t)incomingWWANKey outgoingWWANKey:(int32_t)outgoingWWANKey incomingOtherKey:(int32_t)incomingOtherKey outgoingOtherKey:(int32_t)outgoingOtherKey {
    self = [super init];
    if (self != nil) {
        _filePath = filePath;
        _incomingWWANKey = incomingWWANKey;
        _outgoingWWANKey = outgoingWWANKey;
        _incomingOtherKey = incomingOtherKey;
        _outgoingOtherKey = outgoingOtherKey;
    }
    return self;
}

@end
