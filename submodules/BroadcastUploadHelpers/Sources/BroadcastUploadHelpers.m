#import <BroadcastUploadHelpers/BroadcastUploadHelpers.h>

void finishBroadcastGracefully(RPBroadcastSampleHandler * _Nonnull broadcastSampleHandler) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [broadcastSampleHandler finishBroadcastWithError:nil];
#pragma clang diagnostic pop
}
