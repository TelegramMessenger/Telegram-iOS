#import "BITSessionStateData.h"

/// Data contract class for type SessionStateData.
@implementation BITSessionStateData
@synthesize envelopeTypeName = _envelopeTypeName;
@synthesize dataTypeName = _dataTypeName;
@synthesize version = _version;

/// Initializes a new instance of the class.
- (instancetype)init {
  if((self = [super init])) {
    _envelopeTypeName = @"Microsoft.ApplicationInsights.SessionState";
    _dataTypeName = @"SessionStateData";
    _version = @2;
    _state = BITSessionState_start;
  }
  return self;
}

///
/// Adds all members of this class to a dictionary
/// @returns dictionary to which the members of this class will be added.
///
- (NSDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary].mutableCopy;
  [dict setObject:[NSNumber numberWithInt:(int)self.state] forKey:@"state"];
  return dict;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if(self) {
    _envelopeTypeName =[coder decodeObjectForKey:@"envelopeTypeName"];
    _dataTypeName = [coder decodeObjectForKey:@"dataTypeName"];
    _state = (BITSessionState)[coder decodeIntForKey:@"self.state"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.envelopeTypeName forKey:@"envelopeTypeName"];
  [coder encodeObject:self.dataTypeName forKey:@"dataTypeName"];
  [coder encodeInt:self.state forKey:@"self.state"];
}

@end
