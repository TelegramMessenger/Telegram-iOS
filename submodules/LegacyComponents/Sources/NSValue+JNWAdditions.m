/*
 Copyright (c) 2013, Jonathan Willing. All rights reserved.
 Licensed under the MIT license <http://opensource.org/licenses/MIT>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 documentation files (the "Software"), to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
 to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
 TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 IN THE SOFTWARE.
 */

#import "NSValue+JNWAdditions.h"

@implementation NSValue (JNWAdditions)

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

- (CGRect)jnw_rectValue {
	return [self CGRectValue];
}

- (CGSize)jnw_sizeValue {
	return [self CGSizeValue];
}

- (CGPoint)jnw_pointValue {
	return [self CGPointValue];
}

- (CGAffineTransform)jnw_affineTransformValue {
	return [self CGAffineTransformValue];
}

+ (NSValue *)jnw_valueWithRect:(CGRect)rect {
	return [self valueWithCGRect:rect];
}

+ (NSValue *)jnw_valueWithPoint:(CGPoint)point {
	return [self valueWithCGPoint:point];
}

+ (NSValue *)jnw_valueWithSize:(CGSize)size {
	return [self valueWithCGSize:size];
}

+ (NSValue *)jnw_valueWithAffineTransform:(CGAffineTransform)transform {
	return [self valueWithCGAffineTransform:transform];
}

#elif TARGET_OS_MAC

- (CGRect)jnw_rectValue {
	return [self rectValue];
}

- (CGSize)jnw_sizeValue {
	return [self sizeValue];
}

- (CGPoint)jnw_pointValue {
	return [self pointValue];
}

- (CGAffineTransform)jnw_affineTransformValue {
	CGAffineTransform transform;
	[self getValue:&transform];
	return transform;
}

+ (NSValue *)jnw_valueWithRect:(CGRect)rect {
	return [self valueWithRect:rect];
}

+ (NSValue *)jnw_valueWithPoint:(CGPoint)point {
	return [self valueWithPoint:point];
}

+ (NSValue *)jnw_valueWithSize:(CGSize)size {
	return [self valueWithSize:size];
}

+ (NSValue *)jnw_valueWithAffineTransform:(CGAffineTransform)transform {
	return [NSValue valueWithBytes:&transform objCType:@encode(CGAffineTransform)];
}

#endif

- (JNWValueType)jnw_type {
	const char *type = self.objCType;
	
	static const NSInteger numberofNumberTypes = 10;
	static const char *numberTypes[numberofNumberTypes] = { "i", "s", "l", "q", "I", "S", "L", "Q", "f", "d" };
	
	for (NSInteger i = 0; i < numberofNumberTypes; i++) {
		if (strcmp(type, numberTypes[i]) == 0) {
			return JNWValueTypeNumber;
		}
	}
	if (strcmp(type, @encode(CGPoint)) == 0) {
		return JNWValueTypePoint;
	} else if (strcmp(type, @encode(CGSize)) == 0) {
		return JNWValueTypeSize;
	} else if (strcmp(type, @encode(CGRect)) == 0) {
		return JNWValueTypeRect;
	} else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
		return JNWValueTypeAffineTransform;
	} else if (strcmp(type, @encode(CATransform3D)) == 0) {
		return JNWValueTypeTransform3D;
	} else {
		return JNWValueTypeUnknown;
	}
}

@end
