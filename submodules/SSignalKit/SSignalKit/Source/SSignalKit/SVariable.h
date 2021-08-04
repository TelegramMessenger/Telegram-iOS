#import <Foundation/Foundation.h>

@class SSignal;

@interface SVariable : NSObject

- (instancetype _Nonnull)init;

- (void)set:(SSignal * _Nonnull)signal;
- (SSignal * _Nonnull)signal;

@end
