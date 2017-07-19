/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface TGVideoInfo : NSObject <NSCoding>

- (void)addVideoWithQuality:(int)quality url:(NSString *)url size:(int)size;
- (NSString *)urlWithQuality:(int)quality actualQuality:(int *)actualQuality actualSize:(int *)actualSize;

- (void)serialize:(NSMutableData *)data;
+ (TGVideoInfo *)deserialize:(NSInputStream *)is;

@end
