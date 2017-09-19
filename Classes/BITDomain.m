#import "BITDomain.h"
/// Data contract class for type Domain.
@implementation BITDomain
@synthesize envelopeTypeName = _envelopeTypeName;
@synthesize dataTypeName = _dataTypeName;
@synthesize properties = _properties;

/// Initializes a new instance of the class.
- (instancetype)init {
    if ((self = [super init])) {
        _envelopeTypeName = @"Microsoft.ApplicationInsights.Domain";
        _dataTypeName = @"Domain";
    }
    return self;
}

///
/// Adds all members of this class to a dictionary
/// @returns dictionary to which the members of this class will be added.
///
- (NSDictionary *)serializeToDictionary {
    NSMutableDictionary *dict = [super serializeToDictionary].mutableCopy;
    return dict;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if(self) {
    _envelopeTypeName = (NSString *)[coder decodeObjectForKey:@"_envelopeTypeName"];
    _dataTypeName = (NSString *)[coder decodeObjectForKey:@"_dataTypeName"];
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.envelopeTypeName forKey:@"_envelopeTypeName"];
  [coder encodeObject:self.dataTypeName forKey:@"_dataTypeName"];
}


@end
