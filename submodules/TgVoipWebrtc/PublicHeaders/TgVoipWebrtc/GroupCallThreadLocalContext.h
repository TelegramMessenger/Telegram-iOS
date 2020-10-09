#ifndef GroupCallThreadLocalContext_h
#define GroupCallThreadLocalContext_h

#import <Foundation/Foundation.h>

#import <TgVoipWebrtc/OngoingCallThreadLocalContext.h>

@interface GroupCallThreadLocalContext : NSObject

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue relaySdpAnswer:(void (^ _Nonnull)(NSString * _Nonnull))relaySdpAnswer;

- (void)setOfferSdp:(NSString * _Nonnull)offerSdp;

@end

#endif
