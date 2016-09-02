//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


@interface HCClassMatcher : HCBaseMatcher

@property (nonatomic, strong, readonly) Class theClass;

- (instancetype)initWithClass:(Class)aClass;

@end
