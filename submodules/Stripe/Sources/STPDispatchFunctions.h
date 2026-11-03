//
//  STPDispatchFunctions.h
//  Stripe
//
//  Created by Brian Dorfman on 10/24/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#include <Foundation/Foundation.h>

void stpDispatchToMainThreadIfNecessary(dispatch_block_t block);
