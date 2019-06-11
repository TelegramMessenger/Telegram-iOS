#import "BITTelemetryObject.h"

@interface BITApplication : BITTelemetryObject <NSCoding>

@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *build;
@property (nonatomic, copy) NSString *typeId;

- (instancetype)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

@end
