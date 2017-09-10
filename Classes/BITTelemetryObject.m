#import "BITTelemetryObject.h"

@implementation BITTelemetryObject

// empty implementation for the base class
- (NSDictionary *)serializeToDictionary{
  return [NSDictionary dictionary];
}

- (void)encodeWithCoder:(NSCoder *) __unused coder {
}

- (instancetype)initWithCoder:(NSCoder *) __unused coder {
  return [super init];
}


@end
