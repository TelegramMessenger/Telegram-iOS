#import "Initialize.h"

#import "libavformat/avformat.h"

@implementation InitializeFFMPEG

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        av_register_all();
    }
    return self;
}

@end
