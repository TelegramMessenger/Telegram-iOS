//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@protocol HCMatcher;


/*!
 * @abstract Wraps argument in a matcher, if necessary.
 * @return The argument as-is if it is already a matcher, otherwise wrapped in an <em>equalTo</em> matcher.
 */
FOUNDATION_EXPORT id <HCMatcher> HCWrapInMatcher(id matcherOrValue);
