#import <SSignalKit/SDisposable.h>

@interface SDisposableSet : NSObject <SDisposable>

- (void)add:(id<SDisposable>)disposable;

@end
