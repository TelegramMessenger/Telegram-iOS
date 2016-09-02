#import "BITEventData.h"

/// Data contract class for type EventData.
@implementation BITEventData
@synthesize envelopeTypeName = _envelopeTypeName;
@synthesize dataTypeName = _dataTypeName;
@synthesize version = _version;
@synthesize properties = _properties;
@synthesize measurements = _measurements;

/// Initializes a new instance of the class.
- (instancetype)init {
  if (self = [super init]) {
    _envelopeTypeName = @"Microsoft.ApplicationInsights.Event";
    _dataTypeName = @"EventData";
    _version = @2;
    _properties = [NSDictionary new];
    _measurements = [NSDictionary new];
  }
  return self;
}

///
/// Adds all members of this class to a dictionary
/// @param dictionary to which the members of this class will be added.
///
- (NSDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary].mutableCopy;
  if (self.name != nil) {
    [dict setObject:self.name forKey:@"name"];
  }
  if (self.properties !=nil) {
    [dict setObject:self.properties forKey:@"properties"];
  }
  if (self.measurements) {
    [dict setObject:self.measurements forKey:@"measurements"];
  }
  
  return dict;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if(self) {
    _envelopeTypeName = [coder decodeObjectForKey:@"self.envelopeTypeName"];
    _dataTypeName = [coder decodeObjectForKey:@"self.dataTypeName"];
    _version = [coder decodeObjectForKey:@"self.version"];
    _properties = [coder decodeObjectForKey:@"self.properties"];
    _measurements = [coder decodeObjectForKey:@"self.measurements"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.envelopeTypeName forKey:@"self.envelopeTypeName"];
  [coder encodeObject:self.dataTypeName forKey:@"self.dataTypeName"];
  [coder encodeObject:self.version forKey:@"self.version"];
  [coder encodeObject:self.properties forKey:@"self.properties"];
  [coder encodeObject:self.measurements forKey:@"self.measurements"];
}


@end
