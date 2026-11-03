#import <SSignalKit/SDisposable.h>

@interface SBlockDisposable : NSObject <SDisposable>

- (instancetype)initWithBlock:(void (^)())block;

@end
