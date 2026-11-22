#import <FFMpegBinding/FFMpegVideoWriter.h>
#import <FFMpegBinding/FFMpegAVFrame.h>

#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/imgutils.h"

@interface FFMpegVideoWriter ()

@property (nonatomic) AVFormatContext *formatContext;
@property (nonatomic) AVCodecContext *codecContext;
@property (nonatomic) AVStream *stream;
@property (nonatomic) int64_t framePts;

@end

@implementation FFMpegVideoWriter

- (instancetype)init {
    self = [super init];
    if (self) {
        _framePts = -1;
    }
    return self;
}

- (bool)setupWithOutputPath:(NSString *)outputPath width:(int)width height:(int)height bitrate:(int64_t)bitrate framerate:(int32_t)framerate {
    avformat_alloc_output_context2(&_formatContext, nil, "matroska", [outputPath UTF8String]);
    if (!_formatContext) {
        return false;
    }
    
    if (avio_open(&_formatContext->pb, [outputPath UTF8String], AVIO_FLAG_WRITE) < 0) {
        avformat_free_context(_formatContext);
        _formatContext = nil;
        return false;
    }
    
    const AVCodec *codec = avcodec_find_encoder(AV_CODEC_ID_VP9);
    if (!codec) {
        avio_closep(&_formatContext->pb);
        avformat_free_context(_formatContext);
        _formatContext = nil;
        return false;
    }
    
    _codecContext = avcodec_alloc_context3(codec);
    if (!_codecContext) {
        avio_closep(&_formatContext->pb);
        avformat_free_context(_formatContext);
        _formatContext = nil;
        return false;
    }
    
    _codecContext->codec_id = AV_CODEC_ID_VP9;
    _codecContext->codec_type = AVMEDIA_TYPE_VIDEO;
    _codecContext->pix_fmt = AV_PIX_FMT_YUVA420P;
    _codecContext->color_range = AVCOL_RANGE_MPEG;
    _codecContext->color_primaries = AVCOL_PRI_BT709;
    _codecContext->colorspace = AVCOL_SPC_BT709;
    _codecContext->width = width;
    _codecContext->height = height;
    _codecContext->time_base = (AVRational){1, framerate};
    _codecContext->framerate = (AVRational){framerate, 1};
    _codecContext->bit_rate = bitrate;
    
    if (_formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
        _codecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    
    if (avcodec_open2(_codecContext, codec, NULL) < 0) {
        avcodec_free_context(&_codecContext);
        _codecContext = nil;
        avio_closep(&_formatContext->pb);
        avformat_free_context(_formatContext);
        _formatContext = nil;
        return false;
    }
    
    _stream = avformat_new_stream(_formatContext, codec);
    if (!_stream) {
        #if LIBAVFORMAT_VERSION_MAJOR >= 59
        #else
        avcodec_close(_codecContext);
        #endif
        avcodec_free_context(&_codecContext);
        _codecContext = nil;
        avio_closep(&_formatContext->pb);
        avformat_free_context(_formatContext);
        _formatContext = nil;
        return false;
    }
    
    _stream->codecpar->codec_id = _codecContext->codec_id;
    _stream->codecpar->codec_type = _codecContext->codec_type;
    _stream->codecpar->width = _codecContext->width;
    _stream->codecpar->height = _codecContext->height;
    _stream->codecpar->format = _codecContext->pix_fmt;
    _stream->time_base = _codecContext->time_base;
    
    int ret = avcodec_parameters_from_context(_stream->codecpar, _codecContext);
    if (ret < 0) {
        #if LIBAVFORMAT_VERSION_MAJOR >= 59
        #else
        avcodec_close(_codecContext);
        #endif
        avcodec_free_context(&_codecContext);
        _codecContext = nil;
        avio_closep(&_formatContext->pb);
        avformat_free_context(_formatContext);
        _formatContext = nil;
        return false;
    }
    
    ret = avformat_write_header(_formatContext, nil);
    if (ret < 0) {
        #if LIBAVFORMAT_VERSION_MAJOR >= 59
        #else
        avcodec_close(_codecContext);
        #endif
        avcodec_free_context(&_codecContext);
        _codecContext = nil;
        avio_closep(&_formatContext->pb);
        avformat_free_context(_formatContext);
        _formatContext = nil;
        return false;
    }
    
    return true;
}

- (bool)encodeFrame:(FFMpegAVFrame *)frame {
    if (!_codecContext || !_stream) {
        return false;
    }

    self.framePts++;
    
    AVFrame *frameImpl = (AVFrame *)[frame impl];
    
    frameImpl->pts = self.framePts;
    frameImpl->color_range = AVCOL_RANGE_MPEG;
    frameImpl->color_primaries = AVCOL_PRI_BT709;
    frameImpl->colorspace = AVCOL_SPC_BT709;
    
    int sendRet = avcodec_send_frame(_codecContext, frameImpl);
    if (sendRet < 0) {
        return false;
    }
    
    AVPacket *pkt = nil;
    pkt = av_packet_alloc();
    pkt->data = nil;
    pkt->size = 0;
    
    while (sendRet >= 0) {
        int recvRet = avcodec_receive_packet(_codecContext, pkt);
        if (recvRet == AVERROR(EAGAIN) || recvRet == AVERROR_EOF) {
            break;
        } else if (recvRet < 0) {
            av_packet_unref(pkt);
            break;
        }
        
        av_packet_rescale_ts(pkt, _codecContext->time_base, _stream->time_base);
        pkt->stream_index = _stream->index;
        
        int ret = av_interleaved_write_frame(_formatContext, pkt);
        av_packet_unref(pkt);
        if (ret < 0) {
            return false;
        }
    }
    av_packet_free(&pkt);
    
    return true;
}

- (bool)finalizeVideo {
    if (!_codecContext) {
        return false;
    }
    
    int sendRet = avcodec_send_frame(_codecContext, NULL);
    if (sendRet >= 0) {
        AVPacket *pkt = nil;
        pkt = av_packet_alloc();
        pkt->data = nil;
        pkt->size = 0;
        
        while (avcodec_receive_packet(_codecContext, pkt) == 0) {
            av_packet_rescale_ts(pkt, _codecContext->time_base, _stream->time_base);
            pkt->stream_index = _stream->index;

            av_interleaved_write_frame(_formatContext, pkt);
            av_packet_unref(pkt);
        }
        
        av_packet_free(&pkt);
    }
    
    if (_formatContext) {
        av_write_trailer(_formatContext);
    }
    
    if (_formatContext && _formatContext->pb) {
        avio_closep(&_formatContext->pb);
    }
    
    if (_codecContext) {
        #if LIBAVFORMAT_VERSION_MAJOR >= 59
        #else
        avcodec_close(_codecContext);
        #endif
        avcodec_free_context(&_codecContext);
        _codecContext = nil;
    }
    
    if (_formatContext) {
        avformat_free_context(_formatContext);
        _formatContext = nil;
    }
    
    return true;
}

@end
