//
//  SQueueLocalObject.m
//  SSignalKit
//
//  Created by Mikhail Filimonov on 13.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

#import "SQueueLocalObject.h"

@implementation SQueueLocalObject {
    SQueue *queue;
    id valueRef;
}
-(id)initWithQueue:(SQueue *)queue generate:(id  _Nonnull (^)(void))next {
    if (self = [super init]) {
        self->queue = queue;
        [queue dispatch:^{
            self->valueRef = next();
        }];
    }
    return self;
}

-(void)with:(void (^)(id object))f {
    [self->queue dispatch:^{
        f(self->valueRef);
    }];
}

-(void)dealloc {
    __block id value = self->valueRef;
    self->valueRef = nil;
    [queue dispatch:^{
        value = nil;
    }];
}

@end

