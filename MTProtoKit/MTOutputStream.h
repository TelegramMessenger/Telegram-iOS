/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTOutputStream : NSObject

- (NSOutputStream *)wrappedOutputStream;

- (NSData *)currentBytes;

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
- (void)writeInt32:(int32_t)value;
- (void)writeInt64:(int64_t)value;
- (void)writeDouble:(double)value;
- (void)writeData:(NSData *)data;
- (void)writeString:(NSString *)data;
- (void)writeBytes:(NSData *)data;

@end
