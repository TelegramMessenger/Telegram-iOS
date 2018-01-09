#import <Foundation/Foundation.h>

@interface DeviceProximityManager : NSObject

+ (DeviceProximityManager * _Nonnull)shared;

- (bool)currentValue;

- (void)setGloballyEnabled:(bool)value;

- (NSInteger)add:(void (^ _Nonnull)(bool))f;
- (void)remove:(NSInteger)index;

@end
