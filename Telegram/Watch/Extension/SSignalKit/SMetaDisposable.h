#import <SSignalKit/SDisposable.h>

@interface SMetaDisposable : NSObject <SDisposable>

- (void)setDisposable:(id<SDisposable>)disposable;

@end
