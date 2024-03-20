#import <FFMpegBinding/FFMpegVideoWriter.h>
#import <FFMpegBinding/FrameConverter.h>

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

- (bool)setupWithOutputPath:(NSString *)outputPath width:(int)width height:(int)height {
    avformat_alloc_output_context2(&_formatContext, NULL, "matroska", [outputPath UTF8String]);
    if (!_formatContext) {
        return false;
    }
    
    if (avio_open(&_formatContext->pb, [outputPath UTF8String], AVIO_FLAG_WRITE) < 0) {
        return false;
    }
    
    const AVCodec *codec = avcodec_find_encoder(AV_CODEC_ID_VP9);
    if (!codec) {
        return false;
    }
    
    _codecContext = avcodec_alloc_context3(codec);
    if (!_codecContext) {
        return false;
    }
    
    _codecContext->codec_id = AV_CODEC_ID_VP9;
    _codecContext->codec_type = AVMEDIA_TYPE_VIDEO;
    _codecContext->pix_fmt = AV_PIX_FMT_YUVA420P;
    _codecContext->width = width;
    _codecContext->height = height;
    _codecContext->time_base = (AVRational){1, 30};
    _codecContext->framerate = (AVRational){30, 1};
    _codecContext->bit_rate = 200000;
//    _codecContext->gop_size = 10;
//    _codecContext->max_b_frames = 1;
    
    if (_formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
        _codecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    
    if (avcodec_open2(_codecContext, codec, NULL) < 0) {
        return false;
    }
    
    _stream = avformat_new_stream(_formatContext, codec);
    if (!_stream) {
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
        return false;
    }
    
    ret = avformat_write_header(_formatContext, NULL);
    if (ret < 0) {
        return false;
    }
    
    return true;
}

- (bool)encodeFrame:(CVPixelBufferRef)pixelBuffer {
    if (!_codecContext || !_stream) {
        return false;
    }

    self.framePts++;
    
    AVFrame *frame = av_frame_alloc();
    if (!frame) {
        return false;
    }
    
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);

    frame->format = _codecContext->pix_fmt;
    frame->width = width;
    frame->height = height;
    
    if (av_frame_get_buffer(frame, 0) < 0) {
        return false;
    }
        
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        
    uint8_t *yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    size_t yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    
    uint8_t *uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    size_t uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    
    uint8_t *aBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);
    size_t aStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 2);
    
    for (int i = 0; i < height; i++) {
        memcpy(frame->data[0] + i * frame->linesize[0], yBaseAddress + i * yStride, width);
    }

    for (int i = 0; i < height / 2; i++) {
        for (int j = 0; j < width / 2; j++) {
            frame->data[1][i * frame->linesize[1] + j] = uvBaseAddress[i * uvStride + 2 * j];
            frame->data[2][i * frame->linesize[2] + j] = uvBaseAddress[i * uvStride + 2 * j + 1];
        }
    }
    
    for (int i = 0; i < height; i++) {
        memcpy(frame->data[3] + i * frame->linesize[3], aBaseAddress + i * aStride, width);
    }
        
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        
    frame->pts = self.framePts;
    
    int sendRet = avcodec_send_frame(_codecContext, frame);
    if (sendRet < 0) {
        av_frame_free(&frame);
        return false;
    }
    
    AVPacket pkt;
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    
    while (sendRet >= 0) {
        int recvRet = avcodec_receive_packet(_codecContext, &pkt);
        if (recvRet == AVERROR(EAGAIN) || recvRet == AVERROR_EOF) {
            break;
        } else if (recvRet < 0) {
            break;
        }
        
        av_packet_rescale_ts(&pkt, _codecContext->time_base, _stream->time_base);
        pkt.stream_index = _stream->index;
        
        int ret = av_interleaved_write_frame(_formatContext, &pkt);
        av_packet_unref(&pkt);
        if (ret < 0) {
            return false;
        }
    }
    
    av_frame_free(&frame);
    return true;
}

- (bool)finalizeVideo {
    av_write_trailer(_formatContext);
    
    avio_closep(&_formatContext->pb);
   
    avcodec_close(_codecContext);
    
    avcodec_free_context(&_codecContext);
    avformat_free_context(_formatContext);
    return true;
}

@end
