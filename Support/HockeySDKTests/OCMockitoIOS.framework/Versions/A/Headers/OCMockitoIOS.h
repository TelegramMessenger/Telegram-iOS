//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>

#import "MKTArgumentCaptor.h"
#import "MKTClassObjectMock.h"
#import "MKTObjectMock.h"
#import "MKTObjectAndProtocolMock.h"
#import "MKTOngoingStubbing.h"
#import "MKTProtocolMock.h"
#import "NSInvocation+OCMockito.h"


#define MKTMock(aClass) (id)[MKTObjectMock mockForClass:aClass]

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Returns a mock object of a given class.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTMock instead.
 */
#define mock(aClass) MKTMock(aClass)
#endif


#define MKTMockClass(aClass) (id)[MKTClassObjectMock mockForClass:aClass]

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Returns a mock class object of a given class.
 * 
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTMockClass instead.
 */
#define mockClass(aClass) MKTMockClass(aClass)
#endif


#define MKTMockProtocol(aProtocol) (id)[MKTProtocolMock mockForProtocol:aProtocol]

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Returns a mock object implementing a given protocol.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTMockProtocol instead.
 */
#define mockProtocol(aProtocol) MKTMockProtocol(aProtocol)
#endif


#define MKTMockProtocolWithoutOptionals(aProtocol) (id)[MKTProtocolMock mockForProtocol:aProtocol includeOptionalMethods:NO]

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Returns a mock object implementing a given protocol, but with no optional methods.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTMockProtocolWithoutOptionals instead.
*/
#define mockProtocolWithoutOptionals(aProtocol) MKTMockProtocolWithoutOptionals(aProtocol)
#endif


#define MKTMockObjectAndProtocol(aClass, aProtocol) (id)[MKTObjectAndProtocolMock mockForClass:aClass protocol:aProtocol]

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Returns a mock object of a given class that also implements a given protocol.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTMockObjectAndProtocol instead.
 */
#define mockObjectAndProtocol(aClass, aProtocol) (id)MKTMockObjectAndProtocol(aClass, aProtocol)
#endif


FOUNDATION_EXPORT MKTOngoingStubbing *MKTGivenWithLocation(id testCase, const char *fileName, int lineNumber, ...);
#define MKTGiven(methodCall) MKTGivenWithLocation(self, __FILE__, __LINE__, methodCall)

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Enables method stubbing.
 * @discussion Use "given" when you want the mock to return particular value when particular method
 * is called.
 *
 * Example:
 * <ul>
 *   <li><code>[given([mockObject methodReturningString]) willReturn:@"foo"];</code></li>
 * </ul>
 *
 * See @ref MKTOngoingStubbing for other methods to stub different types of return values.
 *
 * See @ref givenVoid for stubbing methods returning void.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTGiven instead.
 */
#define given(methodCall) MKTGiven(methodCall)
#endif


FOUNDATION_EXPORT MKTOngoingStubbing *MKTGivenVoidWithLocation(id testCase, const char *fileName, int lineNumber, void(^methodCallWrapper)());
#define MKTGivenVoid(methodCall) MKTGivenVoidWithLocation(self, __FILE__, __LINE__, ^{ methodCall; })

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Enables method stubbing of methods returning <code>void</code>.
 * @discussion Use "givenVoid" in combination with <code>willDo:</code> when you want the mock to
 * execute arbitrary code when a method is called.
 *
 * Example:
 * <ul>
 *   <li><code>[givenVoid([mockObject methodReturningVoid]) willDo:^{ magic(); }];</code></li>
 * </ul>
 *
 * See @ref given for stubbing non-void methods in order to return a particular value.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTGiven instead.
 */
#define givenVoid(methodCall) MKTGivenVoid(methodCall)
#endif


#define MKTStubProperty(instance, property, value)                          \
    do {                                                                    \
        [MKTGiven([instance property]) willReturn:value];                   \
        [MKTGiven([instance valueForKey:@#property]) willReturn:value];     \
        [MKTGiven([instance valueForKeyPath:@#property]) willReturn:value]; \
    } while(0)

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Stubs given property and its related KVO methods.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTStubProperty instead.
 */
#define stubProperty(instance, property, value) MKTStubProperty(instance, property, value)
#endif


FOUNDATION_EXPORT id MKTVerifyWithLocation(id mock, id testCase, const char *fileName, int lineNumber);
#define MKTVerify(mock) MKTVerifyWithLocation(mock, self, __FILE__, __LINE__)

#ifdef MOCKITO_SHORTHAND
#undef verify
/*!
 * @abstract Verifies certain behavior happened once.
 * @discussion verify checks that a method was invoked once, with arguments that match given
 * OCHamcrest matchers. If an argument is not a matcher, it is implicitly wrapped in an
 * <code>equalTo</code> matcher to check for equality.
 *
 * Examples:
 * <ul>
 *   <li><code>[verify(mockObject) someMethod:startsWith(@"foo")];</code></li>
 *   <li><code>[verify(mockObject) someMethod:@"bar"];</code></li>
 * </ul>
 *
 * <code>verify(mockObject)</code> is equivalent to <code>verifyCount(mockObject, times(1))</code>
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTVerify instead.
 */
#define verify(mock) MKTVerify(mock)
#endif


FOUNDATION_EXPORT id MKTVerifyCountWithLocation(id mock, id mode, id testCase, const char *fileName, int lineNumber);
#define MKTVerifyCount(mock, mode) MKTVerifyCountWithLocation(mock, mode, self, __FILE__, __LINE__)

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Verifies certain behavior happened a given number of times.
 * @discussion Examples:
 * <ul>
 *   <li><code>[verifyCount(mockObject, times(5)) someMethod:@"was called five times"];</code></li>
 *   <li><code>[verifyCount(mockObject, never()) someMethod:@"was never called"];<code></li>
 * </ul>
 * verifyCount checks that a method was invoked a given number of times, with arguments that match
 * given OCHamcrest matchers. If an argument is not a matcher, it is implicitly wrapped in an
 * <code>equalTo</code> matcher to check for equality.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTVerifyCount instead.
 */
#define verifyCount(mock, mode) MKTVerifyCount(mock, mode)
#endif


FOUNDATION_EXPORT id MKTTimes(NSUInteger wantedNumberOfInvocations);

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Verifies exact number of invocations.
 * @discussion Example:
 * <ul>
 *   <li><code>[verifyCount(mockObject, times(2)) someMethod:@"some arg"];</code></li>
 * </ul>
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTTimes instead.
 */
#define times(wantedNumberOfInvocations) MKTTimes(wantedNumberOfInvocations)
#endif


FOUNDATION_EXPORT id MKTNever(void);

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Verifies that interaction did not happen.
 * @discussion Example:
 * <ul>
 *   <li><code>[verifyCount(mockObject, never()) someMethod:@"some arg"];</code></li>
 * </ul>
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTNever instead.
 */
#define never() MKTNever()
#endif


FOUNDATION_EXPORT id MKTAtLeast(NSUInteger minNumberOfInvocations);

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Verifies minimum number of invocations.
 * @discussion The verification will succeed if the specified invocation happened the number of
 * times specified or more.
 *
 * Example:
 * <ul>
 *   <li><code>[verifyCount(mockObject, atLeast(2)) someMethod:@"some arg"];</code></li>
 * </ul>
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTAtLeast instead.
 */
#define atLeast(minNumberOfInvocations) MKTAtLeast(minNumberOfInvocations)
#endif


FOUNDATION_EXPORT id MKTAtLeastOnce(void);

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Verifies that interaction happened once or more.
 * @discussion Example:
 * <ul>
 *   <li><code>[verifyCount(mockObject, atLeastOnce()) someMethod:@"some arg"];</code></li>
 * </ul>
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTAtLeastOnce instead.
 */
#define atLeastOnce() MKTAtLeastOnce()
#endif


FOUNDATION_EXPORT id MKTAtMost(NSUInteger maxNumberOfInvocations);

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Verifies maximum number of invocations.
 * @discussion The verification will succeed if the specified invocation happened the number of
 * times specified or less.
 *
 * Example:
 * <ul>
 *   <li><code>[verifyCount(mockObject, atMost(2)) someMethod:@"some arg"];</code></li>
 * </ul>
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTAtLeast instead.
 */
#define atMost(maxNumberOfInvocations) MKTAtMost(maxNumberOfInvocations)
#endif


FOUNDATION_EXPORT void MKTStopMockingWithLocation(id mock, id testCase, const char *fileName, int lineNumber);
#define MKTStopMocking(mock) MKTStopMockingWithLocation(mock, self, __FILE__, __LINE__)

#ifdef MOCKITO_SHORTHAND
/*!
 * @abstract Stops mocking and releases arguments.
 * @discussion Mock objects normally retain all message arguments. This is not a problem for most
 * tests, but can sometimes cause retain cycles. In such cases, call stopMocking to tell the mock
 * to release its arguments, and to stop accepting messages. See StopMockingTests.m for an example.
 *
 * @attribute Name Clash
 * In the event of a name clash, don't <code>#define MOCKITO_SHORTHAND</code> and use the synonym
 * MKTStopMocking instead.
 */
#define stopMocking(mock) MKTStopMocking(mock)
#endif
