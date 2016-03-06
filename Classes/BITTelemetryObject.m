#import "BITTelemetryObject.h"

@implementation BITTelemetryObject

// empty implementation for the base class
- (NSDictionary *)serializeToDictionary{
  return [NSDictionary dictionary];
}

- (NSString *)serializeToString {
  NSDictionary *dict = [self serializeToDictionary];
  NSMutableString  *jsonString;
  NSError *error = nil;
  NSData *json;
  json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
  jsonString = [[NSMutableString alloc] initWithData:json encoding:NSUTF8StringEncoding];
  NSString *returnString = [[jsonString stringByReplacingOccurrencesOfString:@"\"true\"" withString:@"true"] stringByReplacingOccurrencesOfString:@"\"false\"" withString:@"false"];
  return returnString;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  return [super init];
}


@end
