#import "BITTelemetryObject.h"

@interface BITInternal : BITTelemetryObject <NSCoding>

@property (nonatomic, copy) NSString *sdkVersion;
@property (nonatomic, copy) NSString *agentVersion;

@end
