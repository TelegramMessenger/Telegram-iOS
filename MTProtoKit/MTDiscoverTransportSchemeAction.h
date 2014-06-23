/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@class MTContext;
@class MTDiscoverTransportSchemeAction;
@class MTTransportScheme;

@protocol MTDiscoverTransportSchemeActionDelegate <NSObject>

@optional

- (void)discoverTransportSchemeActionCompleted:(MTDiscoverTransportSchemeAction *)action;

@end

@interface MTDiscoverTransportSchemeAction : NSObject

@property (nonatomic, weak) id<MTDiscoverTransportSchemeActionDelegate> delegate;

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId;

- (void)discoverScheme;
- (void)discoverMoreOptimalSchemeThan:(MTTransportScheme *)scheme;
- (void)invalidateScheme:(MTTransportScheme *)scheme beginWithHttp:(bool)beginWithHttp;
- (void)validateScheme:(MTTransportScheme *)scheme;
- (void)cancel;

@end
