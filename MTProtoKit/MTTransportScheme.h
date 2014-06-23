/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@class MTContext;
@class MTTransport;
@class MTDatacenterAddress;
@protocol MTTransportDelegate;

@interface MTTransportScheme : NSObject <NSCoding>

@property (nonatomic, strong, readonly) Class transportClass;
@property (nonatomic, strong, readonly) MTDatacenterAddress *address;

- (instancetype)initWithTransportClass:(Class)transportClass address:(MTDatacenterAddress *)address;

- (BOOL)isEqualToScheme:(MTTransportScheme *)other;
- (BOOL)isOptimal;
- (NSComparisonResult)compareToScheme:(MTTransportScheme *)other;

- (MTTransport *)createTransportWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId delegate:(id<MTTransportDelegate>)delegate;

@end
