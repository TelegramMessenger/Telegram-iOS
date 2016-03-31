#import "BITTelemetryData.h"
#import "BITOrderedDictionary.h"

@implementation BITTelemetryData

- (BITOrderedDictionary *)serializeToDictionary {
  BITOrderedDictionary *dict = [super serializeToDictionary];
  if (self.version != nil) {
    [dict setObject:self.version forKey:@"ver"];
  }
  
  return dict;	
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if(self) {
    _version = [coder decodeObjectForKey:@"self.version"];
    _name = [coder decodeObjectForKey:@"self.name"];
    _properties = [coder decodeObjectForKey:@"self.properties"];
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.version forKey:@"self.version"];
  [coder encodeObject:self.name forKey:@"self.name"];
  [coder encodeObject:self.properties forKey:@"self.properties"];
}


@end
