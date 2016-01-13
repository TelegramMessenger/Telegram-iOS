//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>
#import "MKTNonObjectArgumentMatching.h"


@interface MKTBaseMockObject : NSProxy <MKTNonObjectArgumentMatching>

- (instancetype)init;
- (void)mkt_stopMocking;

@end
