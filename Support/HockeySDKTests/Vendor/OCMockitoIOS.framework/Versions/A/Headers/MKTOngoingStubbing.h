//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>
#import "MKTNonObjectArgumentMatching.h"

@class MKTInvocationContainer;


/*!
 * @abstract Methods to invoke on <code>given(methodCall)</code> to stub return values or behaviors.
 * @discussion The methods return <code>self</code> to allow stubbing consecutive calls. The last
 * stub determines the behavior of further consecutive calls.
 */
@interface MKTOngoingStubbing : NSObject <MKTNonObjectArgumentMatching>

- (instancetype)initWithInvocationContainer:(MKTInvocationContainer *)invocationContainer;

/*!
 * @abstract Sets an object to return when the method is called.
 * @discussion Example:
 * <pre>[given([mock someMethod]) willReturn:@"FOO"];</pre>
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturn:(id)object;

/*!
 * @abstract Sets a struct to return when the method is called.
 * @param value Pointer to struct.
 * @param type \@encode() compiler directive called on the struct.
 * @discussion
 * Example:
 * <pre>[given([mock someMethod]) willReturnStruct:&myStruct objCType:\@encode(MyStructType)];</pre>
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnStruct:(const void *)value objCType:(const char *)type;

/*!
 * @abstract Sets a BOOL to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnBool:(BOOL)value;

/*!
 * @abstract Sets a char to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnChar:(char)value;

/*!
 * @abstract Sets an int to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnInt:(int)value;

/*!
 * @abstract Sets a short to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnShort:(short)value;

/*!
 * @abstract Sets a long to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnLong:(long)value;

/*!
 * @abstract Sets a long long to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnLongLong:(long long)value;

/*!
 * @abstract Sets an NSInteger to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnInteger:(NSInteger)value;

/*!
 * @abstract Sets an unsigned char to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnUnsignedChar:(unsigned char)value;

/*!
 * @abstract Sets an unsigned int to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnUnsignedInt:(unsigned int)value;

/*!
 * @abstract Sets an unsigned short to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnUnsignedShort:(unsigned short)value;

/*!
 * @abstract Sets an unsigned long to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnUnsignedLong:(unsigned long)value;

/*!
 * @abstract Sets an unsigned long long to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnUnsignedLongLong:(unsigned long long)value;

/*!
 * @abstract Sets an NSUInteger to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnUnsignedInteger:(NSUInteger)value;

/*!
 * @abstract Sets a float to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnFloat:(float)value;

/*!
 * @abstract Sets a double to return when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willReturnDouble:(double)value;

/*!
 * @abstract Sets an NSException to be thrown when the method is called.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 * @discussion
 * Example:
 * <pre>[given([mock someMethod]) willThrow:exception];</pre>
 */
- (MKTOngoingStubbing *)willThrow:(NSException *)exception;

/*!
 * @abstract Sets a block to be executed when the method is called.
 * @discussion The block is evaluated when the method is called. The block can easily access
 * invocation arguments by calling <code>mkt_arguments</code>. Whatever the block returns will be
 * used as the stubbed return value.
 * @return MKTOngoingStubbing object to allow stubbing consecutive calls
 */
- (MKTOngoingStubbing *)willDo:(id (^)(NSInvocation *))block;

@end
