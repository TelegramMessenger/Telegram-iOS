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
@property (nonatomic, readonly) bool preferForMedia;
@property (nonatomic, readonly) bool restrictToTcp;

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port preferForMedia:(bool)preferForMedia restrictToTcp:(bool)restrictToTcp;

- (BOOL)isEqualToAddress:(MTDatacenterAddress *)other;
- (BOOL)isIpv6;

@end
