//
//  ASRunLoopQueue.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASLocking.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASCATransactionQueueObserving <NSObject>
- (void)prepareForCATransactionCommit;
@end

@interface ASAbstractRunLoopQueue : NSObject
@end

AS_SUBCLASSING_RESTRICTED
@interface ASRunLoopQueue<ObjectType> : ASAbstractRunLoopQueue <ASLocking>

/**
 * Create a new queue with the given run loop and handler.
 *
 * @param runloop The run loop that will drive this queue.
 * @param retainsObjects Whether the queue should retain its objects.
 * @param handlerBlock An optional block to be run for each enqueued object.
 *
 * @discussion You may pass @c nil for the handler if you simply want the objects to
 * be retained at enqueue time, and released during the run loop step. This is useful
 * for creating a "main deallocation queue", as @c ASDeallocQueue creates its own 
 * worker thread with its own run loop.
 */
- (instancetype)initWithRunLoop:(CFRunLoopRef)runloop
                  retainObjects:(BOOL)retainsObjects
                        handler:(nullable void(^)(ObjectType dequeuedItem, BOOL isQueueDrained))handlerBlock;

- (void)enqueue:(ObjectType)object;

@property (readonly) BOOL isEmpty;

@property (nonatomic) NSUInteger batchSize;           // Default == 1.
@property (nonatomic) BOOL ensureExclusiveMembership; // Default == YES.  Set-like behavior.

@end



/**
 * The queue to run on main run loop before CATransaction commit.
 *
 * @discussion this queue will run after ASRunLoopQueue and before CATransaction commit
 * to get last chance of updating/coalesce info like interface state.
 * Each node will only be called once per transaction commit to reflect interface change.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASCATransactionQueue : ASAbstractRunLoopQueue

@property (readonly) BOOL isEmpty;

@property (readonly, getter=isEnabled) BOOL enabled;

- (void)enqueue:(id<ASCATransactionQueueObserving>)object;

@end

extern ASCATransactionQueue *_ASSharedCATransactionQueue;
extern dispatch_once_t _ASSharedCATransactionQueueOnceToken;

NS_INLINE ASCATransactionQueue *ASCATransactionQueueGet(void) {
  dispatch_once(&_ASSharedCATransactionQueueOnceToken, ^{
    _ASSharedCATransactionQueue = [[ASCATransactionQueue alloc] init];
  });
  return _ASSharedCATransactionQueue;
}

@interface ASDeallocQueue : NSObject

@property (class, readonly) ASDeallocQueue *sharedDeallocationQueue;
+ (ASDeallocQueue *)sharedDeallocationQueue NS_RETURNS_RETAINED;

- (void)drain;

- (void)releaseObjectInBackground:(id __strong _Nullable * _Nonnull)objectPtr;

@end

NS_ASSUME_NONNULL_END
