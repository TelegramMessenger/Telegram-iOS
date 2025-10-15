#import <Foundation/Foundation.h>

#import "MTSubscriber.h"

@class MTQueue;

@interface MTSignal : NSObject
{
@public
    id<MTDisposable> (^_generator)(MTSubscriber *);
}

- (instancetype)initWithGenerator:(id<MTDisposable> (^)(MTSubscriber *))generator;

- (id<MTDisposable>)startWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed;
- (id<MTDisposable>)startWithNextStrict:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed file:(const char *)file line:(int)line;

- (id<MTDisposable>)startWithNext:(void (^)(id next))next;
- (id<MTDisposable>)startWithNextStrict:(void (^)(id next))next file:(const char *)file line:(int)line;

- (id<MTDisposable>)startWithNext:(void (^)(id next))next completed:(void (^)())completed;
- (id<MTDisposable>)startWithNextStrict:(void (^)(id next))next completed:(void (^)())completed file:(const char *)file line:(int)line;

+ (MTSignal *)single:(id)next;
+ (MTSignal *)fail:(id)error;
+ (MTSignal *)never;
+ (MTSignal *)complete;

- (MTSignal *)then:(MTSignal *)signal;

- (MTSignal *)delay:(NSTimeInterval)seconds onQueue:(MTQueue *)queue;
- (MTSignal *)timeout:(NSTimeInterval)seconds onQueue:(MTQueue *)queue orSignal:(MTSignal *)signal;

- (MTSignal *)catch:(MTSignal *(^)(id error))f;

+ (MTSignal *)mergeSignals:(NSArray *)signals;
+ (MTSignal *)combineSignals:(NSArray *)signals;

- (MTSignal *)restart;

- (MTSignal *)take:(NSUInteger)count;

- (MTSignal *)switchToLatest;

- (MTSignal *)map:(id (^)(id))f;
- (MTSignal *)filter:(bool (^)(id))f;
- (MTSignal *)mapToSignal:(MTSignal *(^)(id))f;

- (MTSignal *)onDispose:(void (^)())f;

- (MTSignal *)deliverOn:(MTQueue *)queue;
- (MTSignal *)startOn:(MTQueue *)queue;

- (MTSignal *)takeLast;

- (MTSignal *)reduceLeft:(id)value with:(id (^)(id, id))f;

@end
