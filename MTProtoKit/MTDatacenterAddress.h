/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTDatacenterAddress : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *host;
@property (nonatomic, strong, readonly) NSString *ip;
@property (nonatomic, readonly) uint16_t port;

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port;

- (BOOL)isEqualToAddress:(MTDatacenterAddress *)other;

@end
