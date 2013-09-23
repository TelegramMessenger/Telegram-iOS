//
//  OCMockito - MKTBaseMockObject.h
//  Copyright 2013 Jonathan M. Reid. See LICENSE.txt
//
//  Created by: Jon Reid, http://qualitycoding.org/
//  Source: https://github.com/jonreid/OCMockito
//

#import <Foundation/Foundation.h>
#import "MKTPrimitiveArgumentMatching.h"


@interface MKTBaseMockObject : NSProxy <MKTPrimitiveArgumentMatching>

- (id)init;

@end
