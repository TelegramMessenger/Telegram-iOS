//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt
//  Contribution by Kevin Lundberg

#import "MKTProtocolMock.h"


/*!
 * @abstract Mock object of a given class that also implements a given protocol.
 */
@interface MKTObjectAndProtocolMock : MKTProtocolMock

+ (instancetype)mockForClass:(Class)aClass protocol:(Protocol *)protocol;
- (instancetype)initWithClass:(Class)aClass protocol:(Protocol *)protocol;

@end
