#import <FFMpegBinding/FFMpegAVFormatContext.h>

#import <FFMpegBinding/FFMpegAVIOContext.h>
#import <FFMpegBinding/FFMpegPacket.h>
#import <FFMpegBinding/FFMpegAVCodecContext.h>

#import "libavformat/avformat.h"

int FFMpegCodecIdH264 = AV_CODEC_ID_H264;
int FFMpegCodecIdHEVC = AV_CODEC_ID_HEVC;
int FFMpegCodecIdMPEG4 = AV_CODEC_ID_MPEG4;
int FFMpegCodecIdVP9 = AV_CODEC_ID_VP9;

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

- (bool)openInput {
    AVDictionary *options = nil;
    av_dict_set(&options, "usetoc", "1", 0);
    int result = avformat_open_input(&_impl, "file", nil, &options);
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

- (bool)readFrameIntoPacket:(FFMpegPacket *)packet {
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

- (int64_t)durationAtStreamIndex:(int32_t)streamIndex {
    return _impl->streams[streamIndex]->duration;
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
    } else if (stream->codec->time_base.den != 0 && stream->codec->time_base.num != 0) {
        timebase = CMTimeMake((int64_t)stream->codec->time_base.num, stream->codec->time_base.den);
    } else {
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
    double rotationAngle = 0.0;
    AVDictionaryEntry *entry = av_dict_get(_impl->streams[streamIndex]->metadata, "rotate", nil, 0);
    if (entry && entry->value) {
        if (strcmp(entry->value, "0") != 0) {
            double angle = [[[NSString alloc] initWithCString:entry->value encoding:NSUTF8StringEncoding] doubleValue];
            rotationAngle = angle * M_PI / 180.0;
        }
    }
    
    return (FFMpegStreamMetrics){ .width = _impl->streams[streamIndex]->codecpar->width, .height = _impl->streams[streamIndex]->codecpar->height, .rotationAngle = rotationAngle, .extradata = _impl->streams[streamIndex]->codecpar->extradata, .extradataSize = _impl->streams[streamIndex]->codecpar->extradata_size };
}

- (void)forceVideoCodecId:(int)videoCodecId {
    _impl->video_codec_id = videoCodecId;
    _impl->video_codec = avcodec_find_decoder(videoCodecId);
}

@end
