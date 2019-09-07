#import "OggOpusReader.h"

#import "opusfile/opusfile.h"

@interface OggOpusReader () {
    OggOpusFile *_opusFile;
}

@end

@implementation OggOpusReader

- (instancetype _Nullable)initWithPath:(NSString *)path {
    self = [super init];
    if (self != nil) {
        int error = OPUS_OK;
        _opusFile = op_open_file(path.UTF8String, &error);
        if (_opusFile == NULL || error != OPUS_OK) {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    if (_opusFile) {
        op_free(_opusFile);
    }
}

- (int32_t)read:(void *)pcmData bufSize:(int)bufSize {
    return op_read(_opusFile, pcmData, bufSize, NULL);
}

@end
