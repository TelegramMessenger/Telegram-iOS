#import "BITLocation.h"
#import "BITOrderedDictionary.h"

/// Data contract class for type Location.
@implementation BITLocation

///
/// Adds all members of this class to a dictionary
/// @param dictionary to which the members of this class will be added.
///
- (BITOrderedDictionary *)serializeToDictionary {
    BITOrderedDictionary *dict = [super serializeToDictionary];
    if (self.ip != nil) {
        [dict setObject:self.ip forKey:@"ai.location.ip"];
    }
    return dict;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super init];
  if(self) {
    _ip = [coder decodeObjectForKey:@"self.ip"];
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.ip forKey:@"self.ip"];
}


@end
