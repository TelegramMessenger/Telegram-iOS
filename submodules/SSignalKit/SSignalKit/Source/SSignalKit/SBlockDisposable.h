#import <SSignalKit/SDisposable.h>

@interface SBlockDisposable : NSObject <SDisposable>

- (instancetype _Nonnull)initWithBlock:(void (^ _Nullable)())block;

@end
