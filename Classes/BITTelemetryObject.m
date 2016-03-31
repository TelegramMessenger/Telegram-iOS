#import "BITTelemetryObject.h"

@implementation BITTelemetryObject

// empty implementation for the base class
- (NSDictionary *)serializeToDictionary{
  return [NSDictionary dictionary];
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  return [super init];
}


@end
