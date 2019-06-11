#import "BITBase.h"
@class BITTelemetryData;

@interface BITData : BITBase <NSCoding>

@property (nonatomic, strong) BITTelemetryData *baseData;

- (instancetype)initWithCoder:(NSCoder *)coder;

- (void)encodeWithCoder:(NSCoder *)coder;


@end
