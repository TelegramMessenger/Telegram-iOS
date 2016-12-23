#import "MTNetworkUsageCalculationInfo.h"

@implementation MTNetworkUsageCalculationInfo

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self != nil) {
        _filePath = filePath;
    }
    return self;
}

@end
