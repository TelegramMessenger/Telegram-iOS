#import <Foundation/Foundation.h>

@interface RaiseToListenActivator : NSObject

@property (nonatomic) bool enabled;
@property (nonatomic, readonly) bool activated;

- (instancetype)initWithShouldActivate:(bool (^)(void))shouldActivate activate:(void (^)(void))activate deactivate:(void (^)(void))deactivate;

- (void)activateBasedOnProximityWithDelay:(double)delay;
- (void)applicationResignedActive;

@end

