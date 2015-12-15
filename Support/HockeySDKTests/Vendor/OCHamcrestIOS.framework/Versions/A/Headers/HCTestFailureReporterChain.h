//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@class HCTestFailureReporter;


/*!
 * @abstract Manage chain-of-responsibility for reporting test failures.
 * @discussion This provides a generic way of reporting test failures without knowing about the
 * underlying test framework. By default, we try XCTest first, then SenTestingKit. If we run out of
 * options, the final catch-all is to throw an NSException describing the test failure.
 */
@interface HCTestFailureReporterChain : NSObject

/*!
 * @abstract Returns current chain of test failure reporters.
 */
+ (HCTestFailureReporter *)reporterChain;

/*!
 * @abstract Adds specified test failure reporter to head of chain-of-responsibility.
 */
+ (void)addReporter:(HCTestFailureReporter *)reporter;

/*!
 * @abstract Resets chain-of-responsibility to default.
 */
+ (void)reset;

@end
