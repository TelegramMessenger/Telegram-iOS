#import "SDisposable.h"

@interface SCompositeDisposable : NSObject <SDisposable>

- (void)add:(id<SDisposable>)disposable;

@end
