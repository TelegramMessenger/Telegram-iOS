#import "FFMpegGlobals.h"

#import "libavformat/avformat.h"

@implementation FFMpegGlobals

+ (void)initializeGlobals {
#if DEBUG
    av_log_set_level(AV_LOG_VERBOSE);
#else
    av_log_set_level(AV_LOG_QUIET);
#endif
    av_register_all();
}

@end
