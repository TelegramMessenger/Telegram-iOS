//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>

#import "MKTOngoingStubbing.h"
#import "NSInvocation+OCMockito.h"

@protocol MKTVerificationMode;


FOUNDATION_EXPORT id MKTMock(Class classToMock);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates mock object of given class.
 * @param classToMock The class for which to mock instance methods.
 * @discussion The mock object will handle all instance methods of <code>classToMock</code>. Methods
 * return 0 by default.<br />
 * Use <code>given</code> to stub different return values or behaviors.<br />
 * Use <code>givenVoid</code> to stub behaviors of void methods.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTMock instead.
 */
static inline id mock(Class classToMock)
{
    return MKTMock(classToMock);
}
#endif


FOUNDATION_EXPORT id MKTMockClass(Class classToMock);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates mock class object of given class.
 * @param classToMock The class for which to mock class methods.
 * @discussion The mock object will handle all class methods of <code>classToMock</code>. Methods
 * return 0 by default.<br />
 * Use <code>given</code> to stub different return values or behaviors.<br />
 * Use <code>givenVoid</code> to stub behaviors of void methods.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTMockClass instead.
 */
static inline id mockClass(Class classToMock)
{
    return MKTMockClass(classToMock);
}
#endif


FOUNDATION_EXPORT id MKTMockProtocol(Protocol *protocolToMock);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates mock object of given protocol.
 * @param protocolToMock The protocol to mock.
 * @discussion The mock object will handle all methods of <code>protocolToMock</code>. Methods
 * return 0 by default.<br />
 * Use <code>given</code> to stub different return values or behaviors.<br />
 * Use <code>givenVoid</code> to stub behaviors of void methods.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTMockProtocol instead.
 */
static inline id mockProtocol(Protocol *protocolToMock)
{
    return MKTMockProtocol(protocolToMock);
}
#endif


FOUNDATION_EXPORT id MKTMockProtocolWithoutOptionals(Protocol *protocolToMock);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates mock object of given protocol, but without optional methods.
 * @param protocolToMock The protocol to mock.
 * @discussion The mock object will handle only required methods of <code>protocolToMock</code>. It
 * will <b>not</b> respond to the protocol's optional methods. Methods return 0 by default.<br />
 * Use <code>given</code> to stub different return values or behaviors.<br />
 * Use <code>givenVoid</code> to stub behaviors of void methods.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTMockProtocolWithoutOptionals instead.
*/
static inline id mockProtocolWithoutOptionals(Protocol *protocolToMock)
{
    return MKTMockProtocolWithoutOptionals(protocolToMock);
}
#endif


FOUNDATION_EXPORT id MKTMockObjectAndProtocol(Class classToMock, Protocol *protocolToMock);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates mock object of given class that also implements given protocol.
 * @param classToMock The class to mock.
 * @param protocolToMock The protocol to mock.
 * @discussion The mock object will handle all instance methods of <code>classToMock</code>, along
 * with all methods of <code>protocolToMock</code>. Methods return 0 by default.<br />
 * Use <code>given</code> to stub different return values or behaviors.<br />
 * Use <code>givenVoid</code> to stub behaviors of void methods.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTMockObjectAndProtocol instead.
 */
static inline id mockObjectAndProtocol(Class classToMock, Protocol *protocolToMock)
{
    return MKTMockObjectAndProtocol(classToMock, protocolToMock);
}
#endif


FOUNDATION_EXPORT MKTOngoingStubbing *MKTGivenWithLocation(id testCase, const char *fileName, int lineNumber, ...);
#define MKTGiven(methodCall) MKTGivenWithLocation(self, __FILE__, __LINE__, methodCall)

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Stubs a method call.
 * @discussion Creates an MKTOngoingStubbing used for any matching method calls. Call
 * MKTOngoingStubbing methods to define the stub's return value or behavior.
 *
 * Method arguments are matched with specified OCHamcrest matchers. Any argument that is not a
 * matcher is implicitly wrapped in <code>equalTo</code> to match for equality.
 *
 * Example:
 * <pre>[given([mockObject transform:\@"FOO"]) willReturn:\@"BAR"];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTGiven instead.
 */
#define given(methodCall) MKTGiven(methodCall)
#endif


FOUNDATION_EXPORT MKTOngoingStubbing *MKTGivenVoidWithLocation(id testCase, const char *fileName, int lineNumber, void(^methodCallWrapper)());
#define MKTGivenVoid(methodCall) MKTGivenVoidWithLocation(self, __FILE__, __LINE__, ^{ methodCall; })

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Stubs a call to a <code>void</code> method.
 * @discussion Creates an MKTOngoingStubbing used for any matching method calls. Call
 * MKTOngoingStubbing methods to define the stub's behavior.
 *
 * Method arguments are matched with specified OCHamcrest matchers. Any argument that is not a
 * matcher is implicitly wrapped in <code>equalTo</code> to match for equality.
 *
 * Example:
 * <pre>[givenVoid([mockObject methodReturningVoid]) willDo:^{ magic(); }];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
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

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Stubs a property and its related KVO methods to return a given value.
 * @discussion
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTStubProperty instead.
 */
#define stubProperty(instance, property, value) MKTStubProperty(instance, property, value)
#endif


FOUNDATION_EXPORT id MKTVerifyWithLocation(id mock, id testCase, const char *fileName, int lineNumber);
#define MKTVerify(mock) MKTVerifyWithLocation(mock, self, __FILE__, __LINE__)

#ifndef MKT_DISABLE_SHORT_SYNTAX
#undef verify
/*!
 * @abstract Verifies certain behavior happened once.
 * @discussion Equivalent to <code>verifyCount(mock, times(1))</code>.
 *
 * Method arguments are matched with specified OCHamcrest matchers. Any argument that is
 * not a matcher is implicitly wrapped in <code>equalTo</code> to match for equality.
 *
 * Examples:
 * <pre>[verify(mockObject) someMethod:startsWith(\@"foo")];</pre>
 * <pre>[verify(mockObject) someMethod:\@"bar"];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTVerify instead.
 */
#define verify(mock) MKTVerify(mock)
#endif


FOUNDATION_EXPORT id MKTVerifyCountWithLocation(id mock, id <MKTVerificationMode> mode, id testCase, const char *fileName, int lineNumber);
#define MKTVerifyCount(mock, mode) MKTVerifyCountWithLocation(mock, mode, self, __FILE__, __LINE__)

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Verifies certain behavior happened a given number of times.
 * @discussion Method arguments are matched with specified OCHamcrest matchers. Any argument that is
 * not a matcher is implicitly wrapped in <code>equalTo</code> to match for equality.
 * Examples:
 * <pre>[verifyCount(mockObject, times(5)) someMethod:\@"was called five times"];</pre>
 * <pre>[verifyCount(mockObject, never()) someMethod:\@"was never called"];</pre>
 * verifyCount checks that a method was invoked the given number of times, with arguments that
 * match given OCHamcrest matchers. If an argument is not a matcher, it is implicitly wrapped in an
 * <code>equalTo</code> matcher to check for equality.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTVerifyCount instead.
 */
#define verifyCount(mock, mode) MKTVerifyCount(mock, mode)
#endif


FOUNDATION_EXPORT id <MKTVerificationMode> MKTTimes(NSUInteger wantedNumberOfInvocations);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates <code>verifyCount</code> mode verifying an exact number of invocations.
 * @discussion Example:
 * <pre>[verifyCount(mockObject, times(2)) someMethod:\@"some arg"];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTTimes instead.
 */
static inline id <MKTVerificationMode> times(NSUInteger wantedNumberOfInvocations)
{
    return MKTTimes(wantedNumberOfInvocations);
}
#endif


FOUNDATION_EXPORT id <MKTVerificationMode> MKTNever(void);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates <code>verifyCount</code> mode verifying that an interaction did not happen.
 * @discussion Example:
 * <pre>[verifyCount(mockObject, never()) someMethod:\@"some arg"];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTNever instead.
 */
static inline id <MKTVerificationMode> never(void)
{
    return MKTNever();
}
#endif


FOUNDATION_EXPORT id <MKTVerificationMode> MKTAtLeast(NSUInteger minNumberOfInvocations);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates <code>verifyCount</code> mode verifying that an interaction happened at least
 * the given number of times.
 * @discussion
 * Example:
 * <pre>[verifyCount(mockObject, atLeast(2)) someMethod:\@"some arg"];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTAtLeast instead.
 */
static inline id <MKTVerificationMode> atLeast(NSUInteger minNumberOfInvocations)
{
    return MKTAtLeast(minNumberOfInvocations);
}
#endif


FOUNDATION_EXPORT id <MKTVerificationMode> MKTAtLeastOnce(void);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates <code>verifyCount</code> mode verifying that an interaction happened at least
 * once.
 * @discussion Same as <code>atLeast(1)</code>.
 *
 * Example:
 * <pre>[verifyCount(mockObject, atLeastOnce()) someMethod:\@"some arg"];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTAtLeastOnce instead.
 */
static inline id <MKTVerificationMode> atLeastOnce(void)
{
    return MKTAtLeastOnce();
}
#endif


FOUNDATION_EXPORT id <MKTVerificationMode> MKTAtMost(NSUInteger maxNumberOfInvocations);

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates <code>verifyCount</code> mode verifying that an interaction happened at most
 * the given number of times.
 * @discussion
 * Example:
 * <pre>[verifyCount(mockObject, atMost(2)) someMethod:\@"some arg"];</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTAtLeast instead.
 */
static inline id <MKTVerificationMode> atMost(NSUInteger maxNumberOfInvocations)
{
    return MKTAtMost(maxNumberOfInvocations);
}
#endif


FOUNDATION_EXPORT void MKTStopMockingWithLocation(id mock, id testCase, const char *fileName, int lineNumber);
#define MKTStopMocking(mock) MKTStopMockingWithLocation(mock, self, __FILE__, __LINE__)

#ifndef MKT_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Stops mocking and releases arguments.
 * @discussion Mock objects normally retain all message arguments. This is not a problem for most
 * tests, but can sometimes cause retain cycles. In such cases, call stopMocking to tell the mock
 * to release its arguments, and to stop accepting messages. See StopMockingTests.m for an example.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define MKT_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * MKTStopMocking instead.
 */
#define stopMocking(mock) MKTStopMocking(mock)
#endif
