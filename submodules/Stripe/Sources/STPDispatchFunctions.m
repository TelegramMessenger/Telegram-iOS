//
//  STPDispatchFunctions.m
//  Stripe
//
//  Created by Brian Dorfman on 10/24/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#include "STPDispatchFunctions.h"

void stpDispatchToMainThreadIfNecessary(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}
