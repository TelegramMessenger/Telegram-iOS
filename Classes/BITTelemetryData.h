#import "BITTelemetryObject.h"

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

///Data contract class for type BITTelemetryData.
@interface BITTelemetryData : BITTelemetryObject <NSCoding>

@property (nonatomic, readonly, copy) NSString *envelopeTypeName;
@property (nonatomic, readonly, copy) NSString *dataTypeName;

@property (nonatomic, copy) NSNumber *version;
@property (nonatomic, copy) NSString *name;

@end

NS_ASSUME_NONNULL_END
