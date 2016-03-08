//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt
//  Contribution by David Hart

#import "MKTBaseMockObject.h"


/*!
 * @abstract Mock object of a given class object.
 */
@interface MKTClassObjectMock : MKTBaseMockObject

+ (instancetype)mockForClass:(Class)aClass;
- (instancetype)initWithClass:(Class)aClass;

@end
