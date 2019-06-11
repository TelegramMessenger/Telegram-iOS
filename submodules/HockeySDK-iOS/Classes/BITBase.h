#import "BITTelemetryObject.h"
#import "BITTelemetryData.h"

@interface BITBase : BITTelemetryData <NSCoding>

@property (nonatomic, copy) NSString *baseType;

- (instancetype)initWithCoder:(NSCoder *)coder;

- (void)encodeWithCoder:(NSCoder *)coder;


@end
