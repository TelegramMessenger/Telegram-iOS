
#import <TgVoipWebrtc/GroupCallThreadLocalContext.h>

#import "group/GroupInstanceImpl.h"

@interface GroupCallThreadLocalContext () {
    id<OngoingCallThreadLocalContextQueueWebrtc> _queue;
    
    std::unique_ptr<tgcalls::GroupInstanceImpl> _instance;
}

@end

@implementation GroupCallThreadLocalContext

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue relaySdpAnswer:(void (^ _Nonnull)(NSString * _Nonnull))relaySdpAnswer {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        
        tgcalls::GroupInstanceDescriptor descriptor;
        __weak GroupCallThreadLocalContext *weakSelf = self;
        descriptor.sdpAnswerEmitted = [weakSelf, queue, relaySdpAnswer](std::string const &sdpAnswer) {
            NSString *string = [NSString stringWithUTF8String:sdpAnswer.c_str()];
            [queue dispatch:^{
                __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                relaySdpAnswer(string);
            }];
        };
        
        _instance.reset(new tgcalls::GroupInstanceImpl(std::move(descriptor)));
    }
    return self;
}

- (void)emitOffer {
    if (_instance) {
        _instance->emitOffer();
    }
}

- (void)setOfferSdp:(NSString * _Nonnull)offerSdp isPartial:(bool)isPartial {
    if (_instance) {
        _instance->setOfferSdp([offerSdp UTF8String], isPartial);
    }
}

- (void)setIsMuted:(bool)isMuted {
    if (_instance) {
        _instance->setIsMuted(isMuted);
    }
}

@end

