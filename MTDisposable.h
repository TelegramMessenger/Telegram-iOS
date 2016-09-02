#import <Foundation/Foundation.h>

@protocol MTDisposable <NSObject>

- (void)dispose;

@end

@interface MTBlockDisposable : NSObject <MTDisposable>

- (instancetype)initWithBlock:(void (^)())block;

@end

@interface MTMetaDisposable : NSObject <MTDisposable>

- (void)setDisposable:(id<MTDisposable>)disposable;

@end

@interface MTDisposableSet : NSObject <MTDisposable>

- (void)add:(id<MTDisposable>)disposable;
- (void)remove:(id<MTDisposable>)disposable;

@end
