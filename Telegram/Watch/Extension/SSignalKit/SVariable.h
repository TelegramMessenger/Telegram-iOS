#import <Foundation/Foundation.h>

@class SSignal;

@interface SVariable : NSObject

- (instancetype)init;

- (void)set:(SSignal *)signal;
- (SSignal *)signal;

@end
