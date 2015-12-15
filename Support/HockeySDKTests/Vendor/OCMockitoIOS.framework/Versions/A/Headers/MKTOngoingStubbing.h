//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>
#import "MKTNonObjectArgumentMatching.h"

@class MKTInvocationContainer;


/*!
 * @abstract Methods to invoke on <code>given(methodCall)</code> to return stubbed values.
 * @discussion The methods return <code>self</code> to allow stubbing consecutive calls.
 */
@interface MKTOngoingStubbing : NSObject <MKTNonObjectArgumentMatching>

- (instancetype)initWithInvocationContainer:(MKTInvocationContainer *)invocationContainer;

/*! @abstract Sets an object to return when the method is called. */
- (MKTOngoingStubbing *)willReturn:(id)object;

/*!
 * @abstract Sets a struct to return when the method is called.
 * @param value Pointer to struct.
 * @param type \@encode() compiler directive called on the struct.
*/
- (MKTOngoingStubbing *)willReturnStruct:(const void *)value objCType:(const char *)type;

/*! @abstract Sets a BOOL to return when the method is called. */
- (MKTOngoingStubbing *)willReturnBool:(BOOL)value;

/*! @abstract Sets a char to return when the method is called. */
- (MKTOngoingStubbing *)willReturnChar:(char)value;

/*! @abstract Sets an int to return when the method is called. */
- (MKTOngoingStubbing *)willReturnInt:(int)value;

/*! @abstract Sets a short to return when the method is called. */
- (MKTOngoingStubbing *)willReturnShort:(short)value;

/*! @abstract Sets a long to return when the method is called. */
- (MKTOngoingStubbing *)willReturnLong:(long)value;

/*! @abstract Sets a long long to return when the method is called. */
- (MKTOngoingStubbing *)willReturnLongLong:(long long)value;

/*! @abstract Sets an NSInteger to return when the method is called. */
- (MKTOngoingStubbing *)willReturnInteger:(NSInteger)value;

/*! @abstract Sets an unsigned char to return when the method is called. */
- (MKTOngoingStubbing *)willReturnUnsignedChar:(unsigned char)value;

/*! @abstract Sets an unsigned int to return when the method is called. */
- (MKTOngoingStubbing *)willReturnUnsignedInt:(unsigned int)value;

/*! @abstract Sets an unsigned short to return when the method is called. */
- (MKTOngoingStubbing *)willReturnUnsignedShort:(unsigned short)value;

/*! @abstract Sets an unsigned long to return when the method is called. */
- (MKTOngoingStubbing *)willReturnUnsignedLong:(unsigned long)value;

/*! @abstract Sets an unsigned long long to return when the method is called. */
- (MKTOngoingStubbing *)willReturnUnsignedLongLong:(unsigned long long)value;

/*! @abstract Sets an NSUInteger to return when the method is called. */
- (MKTOngoingStubbing *)willReturnUnsignedInteger:(NSUInteger)value;

/*! @abstract Sets a float to return when the method is called. */
- (MKTOngoingStubbing *)willReturnFloat:(float)value;

/*! @abstract Sets a double to return when the method is called. */
- (MKTOngoingStubbing *)willReturnDouble:(double)value;

/*! @abstract Sets an NSException to be thrown when the method is called. */
- (MKTOngoingStubbing *)willThrow:(NSException *)exception;

/*!
 * @abstract Sets block to be executed when the method is called.
 * @discussion The block is evaluated when the method is called. The block can easily access
 * invocation arguments by calling @ref mkt_arguments. Whatever the block returns will be used as
 * the stubbed return value.
 */
- (MKTOngoingStubbing *)willDo:(id (^)(NSInvocation *))block;

@end
