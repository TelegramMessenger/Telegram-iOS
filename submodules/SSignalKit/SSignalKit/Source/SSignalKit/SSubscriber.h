#import <SSignalKit/SDisposable.h>

@interface SSubscriber : NSObject <SDisposable>
{
}

- (instancetype _Nonnull)initWithNext:(void (^ _Nullable)(id _Nullable))next error:(void (^ _Nullable)(id _Nullable))error completed:(void (^ _Nullable)())completed;

- (void)_assignDisposable:(id<SDisposable> _Nullable)disposable;
- (void)_markTerminatedWithoutDisposal;

- (void)putNext:(id _Nullable)next;
- (void)putError:(id _Nullable)error;
- (void)putCompletion;

@end

@interface STracingSubscriber : SSubscriber

- (instancetype _Nonnull)initWithName:(NSString * _Nonnull)name next:(void (^ _Nullable)(id _Nullable))next error:(void (^ _Nullable)(id _Nullable))error completed:(void (^ _Nullable)())completed;

@end
