#import <SSignalKit/SDisposable.h>

@interface SMetaDisposable : NSObject <SDisposable>

- (void)setDisposable:(id<SDisposable> _Nullable)disposable;

@end
