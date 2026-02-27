#import <FFMpegBinding/FFMpegAVFormatContext.h>

#import <FFMpegBinding/FFMpegAVIOContext.h>
#import <FFMpegBinding/FFMpegPacket.h>
#import <FFMpegBinding/FFMpegAVCodecContext.h>

#import "libavcodec/avcodec.h"
#import "libavformat/avformat.h"
#import "libavutil/display.h"

int FFMpegCodecIdH264 = AV_CODEC_ID_H264;
int FFMpegCodecIdHEVC = AV_CODEC_ID_HEVC;
int FFMpegCodecIdMPEG4 = AV_CODEC_ID_MPEG4;
int FFMpegCodecIdVP9 = AV_CODEC_ID_VP9;
int FFMpegCodecIdVP8 = AV_CODEC_ID_VP8;
int FFMpegCodecIdAV1 = AV_CODEC_ID_AV1;

static int get_stream_rotation(const AVStream *stream) {
    AVDictionaryEntry *e = av_dict_get (stream->metadata, "rotate", NULL, 0);
    if (e && e->value) {
        if (!strcmp (e->value, "90") || !strcmp (e->value, "-270")) {
            return 90;
        } else if (!strcmp (e->value, "270") || !strcmp (e->value, "-90")) {
            return 270;
        } else if (!strcmp (e->value, "180") || !strcmp (e->value, "-180")) {
            return 180;
        } else if (!strcmp (e->value, "0")) {
            return 0;
        }
    }
    
    const AVPacketSideData *displaymatrix = av_packet_side_data_get(stream->codecpar->coded_side_data, stream->codecpar->nb_coded_side_data, AV_PKT_DATA_DISPLAYMATRIX);
    if (displaymatrix) {
        return ((int)-av_display_rotation_get((int32_t *)displaymatrix->data) + 360) % 360;
    }
    
    return 0;
}

@interface FFMpegAVFormatContext () {
    AVFormatContext *_impl;
}

@end

@implementation FFMpegAVFormatContext

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _impl = avformat_alloc_context();
    }
    return self;
}

- (void)dealloc {
    if (_impl != nil) {
        avformat_close_input(&_impl);
    }
}

- (void)setIOContext:(FFMpegAVIOContext *)ioContext {
    _impl->pb = [ioContext impl];
}

- (bool)openInputWithDirectFilePath:(NSString * _Nullable)directFilePath {
    AVDictionary *options = nil;
    av_dict_set(&options, "usetoc", "1", 0);
    
    const char *url = "file";
    if (directFilePath) {
        url = [directFilePath UTF8String];
    }
    int result = avformat_open_input(&_impl, url, nil, &options);
    av_dict_free(&options);
    if (_impl != nil) {
        _impl->flags |= AVFMT_FLAG_FAST_SEEK;
        _impl->flags |= AVFMT_FLAG_NOBUFFER;
    }
    
    return result >= 0;
}

- (bool)findStreamInfo {
    int result = avformat_find_stream_info(_impl, nil);
    return result >= 0;
}

- (void)seekFrameForStreamIndex:(int32_t)streamIndex pts:(int64_t)pts positionOnKeyframe:(bool)positionOnKeyframe {
    int options = AVSEEK_FLAG_FRAME | AVSEEK_FLAG_BACKWARD;
    if (!positionOnKeyframe) {
        options |= AVSEEK_FLAG_ANY;
    }
    av_seek_frame(_impl, streamIndex, pts, options);
}

- (void)seekFrameForStreamIndex:(int32_t)streamIndex byteOffset:(int64_t)byteOffset {
    int options = AVSEEK_FLAG_BYTE;
    av_seek_frame(_impl, streamIndex, byteOffset, options);
}

- (bool)readFrameIntoPacket:(FFMpegPacket *)packet {
    [packet reuse];
    int result = av_read_frame(_impl, (AVPacket *)[packet impl]);
    return result >= 0;
}

- (NSArray<NSNumber *> *)streamIndicesForType:(FFMpegAVFormatStreamType)type {
    NSMutableArray<NSNumber *> *indices = [[NSMutableArray alloc] init];
    enum AVMediaType mediaType;
    switch(type) {
        case FFMpegAVFormatStreamTypeAudio:
            mediaType = AVMEDIA_TYPE_AUDIO;
            break;
        case FFMpegAVFormatStreamTypeVideo:
            mediaType = AVMEDIA_TYPE_VIDEO;
            break;
        default:
            mediaType = AVMEDIA_TYPE_VIDEO;
            break;
    }
    for (unsigned int i = 0; i < _impl->nb_streams; i++) {
        if (mediaType == _impl->streams[i]->codecpar->codec_type) {
            [indices addObject:@(i)];
        }
    }
    return indices;
}

- (bool)isAttachedPicAtStreamIndex:(int32_t)streamIndex {
    return ((_impl->streams[streamIndex]->disposition) & AV_DISPOSITION_ATTACHED_PIC) != 0;
}

- (int)codecIdAtStreamIndex:(int32_t)streamIndex {
    return _impl->streams[streamIndex]->codecpar->codec_id;
}

- (double)duration {
    return (double)_impl->duration / AV_TIME_BASE;
}

- (int64_t)startTimeAtStreamIndex:(int32_t)streamIndex {
    return _impl->streams[streamIndex]->start_time;
}

- (int64_t)durationAtStreamIndex:(int32_t)streamIndex {
    return _impl->streams[streamIndex]->duration;
}

- (int)numberOfIndexEntriesAtStreamIndex:(int32_t)streamIndex {
    return avformat_index_get_entries_count(_impl->streams[streamIndex]);
}

- (bool)fillIndexEntryAtStreamIndex:(int32_t)streamIndex entryIndex:(int32_t)entryIndex outEntry:(FFMpegAVIndexEntry * _Nonnull)outEntry {
    const AVIndexEntry *entry = avformat_index_get_entry(_impl->streams[streamIndex], entryIndex);
    if (!entry) {
        outEntry->pos = -1;
        outEntry->timestamp = 0;
        outEntry->isKeyframe = false;
        outEntry->size = 0;
        return false;
    }
    
    outEntry->pos = entry->pos;
    outEntry->timestamp = entry->timestamp;
    outEntry->isKeyframe = (entry->flags & AVINDEX_KEYFRAME) != 0;
    outEntry->size = entry->size;
    
    return true;
}

- (bool)codecParamsAtStreamIndex:(int32_t)streamIndex toContext:(FFMpegAVCodecContext *)context {
    int result = avcodec_parameters_to_context((AVCodecContext *)[context impl], _impl->streams[streamIndex]->codecpar);
    return result >= 0;
}

- (FFMpegFpsAndTimebase)fpsAndTimebaseForStreamIndex:(int32_t)streamIndex defaultTimeBase:(CMTime)defaultTimeBase {
    CMTime timebase;
    CMTime fps;
    
    AVStream *stream = _impl->streams[streamIndex];
    
    if (stream->time_base.den != 0 && stream->time_base.num != 0) {
        timebase = CMTimeMake((int64_t)stream->time_base.num, stream->time_base.den);
    }/* else if (stream->codec->time_base.den != 0 && stream->codec->time_base.num != 0) {
        timebase = CMTimeMake((int64_t)stream->codec->time_base.num, stream->codec->time_base.den);
    }*/ else {
        timebase = defaultTimeBase;
    }
    
    if (stream->avg_frame_rate.den != 0 && stream->avg_frame_rate.num != 0) {
        fps = CMTimeMake((int64_t)stream->avg_frame_rate.num, stream->avg_frame_rate.den);
    } else if (stream->r_frame_rate.den != 0 && stream->r_frame_rate.num != 0) {
        fps = CMTimeMake((int64_t)stream->r_frame_rate.num, stream->r_frame_rate.den);
    } else {
        fps = CMTimeMake(1, 24);
    }
    
    return (FFMpegFpsAndTimebase){ .fps = fps, .timebase = timebase };
}

- (FFMpegStreamMetrics)metricsForStreamAtIndex:(int32_t)streamIndex {
    int angleDegrees = get_stream_rotation(_impl->streams[streamIndex]);
    
    double rotationAngle = 0.0;
    rotationAngle = ((double)angleDegrees) * M_PI / 180.0;
    
    return (FFMpegStreamMetrics){ .width = _impl->streams[streamIndex]->codecpar->width, .height = _impl->streams[streamIndex]->codecpar->height, .rotationAngle = rotationAngle, .extradata = _impl->streams[streamIndex]->codecpar->extradata, .extradataSize = _impl->streams[streamIndex]->codecpar->extradata_size };
}

- (void)forceVideoCodecId:(int)videoCodecId {
    _impl->video_codec_id = videoCodecId;
    _impl->video_codec = avcodec_find_decoder(videoCodecId);
}

@end
