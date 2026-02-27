#import <Foundation/Foundation.h>

@interface DeviceProximityManager : NSObject

@property (nonatomic, copy) void(^ _Nullable proximityChanged)(bool);

+ (DeviceProximityManager * _Nonnull)shared;

- (bool)currentValue;

- (void)setGloballyEnabled:(bool)value;

- (NSInteger)add:(void (^ _Nonnull)(bool))f;
- (void)remove:(NSInteger)index;

@end
