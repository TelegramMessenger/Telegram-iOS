//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@protocol HCMatcher;

/*!
 * @header
 * Assertion macros for using matchers in testing frameworks.
 * Unmet assertions are reported to the HCTestFailureReporterChain.
 */


FOUNDATION_EXPORT void HC_assertThatWithLocation(id testCase, id actual, id <HCMatcher> matcher,
                                                 const char *fileName, int lineNumber);

#define HC_assertThat(actual, matcher)  \
    HC_assertThatWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThat(actual, matcher) -
 * Asserts that actual value satisfies matcher.
 * @param actual The object to evaluate as the actual value.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion assertThat passes the actual value to the matcher for evaluation. If the matcher is
 * not satisfied, it is reported to the HCTestFailureReporterChain.
 *
 * Use assertThat in test case methods. It's designed to integrate with XCTest and other testing
 * frameworks where individual tests are executed as methods.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThat instead.
 */
#define assertThat(actual, matcher) HC_assertThat(actual, matcher)
#endif


typedef id (^HCFutureValue)();

FOUNDATION_EXPORT void HC_assertWithTimeoutAndLocation(id testCase, NSTimeInterval timeout,
        HCFutureValue actualBlock, id <HCMatcher> matcher,
        const char *fileName, int lineNumber);

#define HC_assertWithTimeout(timeout, actualBlock, matcher)  \
    HC_assertWithTimeoutAndLocation(self, timeout, actualBlock, matcher, __FILE__, __LINE__)

#define HC_thatEventually(actual) ^{ return actual; }

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertWithTimeout(timeout, actualBlock, matcher) -
 * Asserts that a value provided by a block will satisfy matcher within the specified time.
 * @param timeout Maximum time to wait for passing behavior, specified in seconds.
 * @param actualBlock A block providing the object to repeatedly evaluate as the actual value.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion <em>assertWithTimeout</em> polls a value provided by a block to asynchronously
 * satisfy the matcher. The block is evaluated repeatedly for an actual value, which is passed to
 * the matcher for evaluation. If the matcher is not satisfied within the timeout, it is reported to
 * the HCTestFailureReporterChain.
 *
 * An easy way of providing the <em>actualBlock</em> is to use the macro <code>thatEventually</code>.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertWithTimeout instead.
*/
#define assertWithTimeout(timeout, actualBlock, matcher) HC_assertWithTimeout(timeout, actualBlock, matcher)


/*!
 * @abstract thatEventually(actual) -
 * Evaluates actual value at future time.
 * @param actual The object to evaluate as the actual value.
 * @discussion Wraps <em>actual</em> in a block so that it can be repeatedly evaluated by
 * <code>assertWithTimeout</code>.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_thatEventually instead.
 */
#define thatEventually(actual) HC_thatEventually(actual)
#endif


/*!
 * @abstract "Expected <matcher description>, but <mismatch description>"
 * @discussion Helper function to let you describe mismatches the way <tt>assertThat</tt> does.
 */
FOUNDATION_EXPORT NSString *HCDescribeMismatch(id <HCMatcher> matcher, id actual);
