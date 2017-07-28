//
//  NSMutableArray+STKAudioPlayer.h
//  StreamingKit
//
//  Created by Thong Nguyen on 30/01/2014.
//  Copyright (c) 2014 Thong Nguyen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (STKAudioPlayer)
-(void) enqueue:(id)obj;
-(void) skipQueue:(id)obj;
-(void) skipQueueWithQueue:(NSMutableArray*)queue;
-(id) dequeue;
-(id) peek;
@end
