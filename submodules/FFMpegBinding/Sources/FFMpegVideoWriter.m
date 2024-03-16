#import <FFMpegBinding/FFMpegVideoWriter.h>

#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"

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
        _framePts = 0;
    }
    return self;
}

- (void)setupWithOutputPath:(NSString *)outputPath width:(int)width height:(int)height {    
    AVOutputFormat *outFmt = av_guess_format("webm", NULL, NULL);
    
    const AVOutputFormat *oformat;
    void *opaque = NULL;
    while ((oformat = av_muxer_iterate(&opaque))) {
        NSLog(@"%s", oformat->long_name);
    }
    
    int error = avformat_alloc_output_context2(&_formatContext, outFmt, NULL, [outputPath UTF8String]);
    NSLog(@"%d", error);
    
    if (!_formatContext) return;
    
    AVCodec *codec = avcodec_find_encoder_by_name("libvpx-vp9");
    if (!codec) return;
    
    _stream = avformat_new_stream(_formatContext, codec);
    if (!_stream) return;
    
    _codecContext = avcodec_alloc_context3(codec);
    if (!_codecContext) return;
    
    _codecContext->bit_rate = 400000;
    _codecContext->width = width;
    _codecContext->height = height;
    _codecContext->time_base = (AVRational){1, 30};
    _codecContext->gop_size = 10;
    _codecContext->max_b_frames = 1;
    _codecContext->pix_fmt = AV_PIX_FMT_YUVA420P;
    
    if (_formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
        _codecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    
    avcodec_open2(_codecContext, codec, NULL);
    
    av_dump_format(_formatContext, 0, [outputPath UTF8String], 1);
    
    if (!(_formatContext->oformat->flags & AVFMT_NOFILE)) {
        avio_open(&_formatContext->pb, [outputPath UTF8String], AVIO_FLAG_WRITE);
    }
    
    __unused int result = avformat_write_header(_formatContext, NULL);
}

- (void)encodeFrame:(CVPixelBufferRef)pixelBuffer {
    if (!_codecContext || !_stream) return;
    
    AVFrame *frame = av_frame_alloc();
    if (!frame) return;
    
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    frame->format = AV_PIX_FMT_YUV420P;
    frame->width = width;
    frame->height = height;
    
    av_frame_get_buffer(frame, 0);
    
//    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
//    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
//    AVPixelFormat srcPixFmt = AV_PIX_FMT_BGRA;
//    AVPixelFormat dstPixFmt = AV_PIX_FMT_YUV420P;
//    struct SwsContext *swsCtx = sws_getContext(width, height, srcPixFmt,
//                                               width, height, dstPixFmt,
//                                               SWS_BICUBIC, NULL, NULL, NULL);
//    if (swsCtx) {
//        const uint8_t *const srcSlice[] = { baseAddress };
//        int srcStride[] = { CVPixelBufferGetBytesPerRow(pixelBuffer) };
//        sws_scale(swsCtx, srcSlice, srcStride, 0, height, frame->data, frame->linesize);
//        sws_freeContext(swsCtx);
//    }
    
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    frame->pts = self.framePts++;
    
    int sendRet = avcodec_send_frame(_codecContext, frame);
    if (sendRet < 0) {
        // Error sending frame
        av_frame_free(&frame);
        return;
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
        
        av_interleaved_write_frame(_formatContext, &pkt);
        av_packet_unref(&pkt);
    }
    
    av_frame_free(&frame);
}

- (void)finalizeVideo {
    av_write_trailer(_formatContext);
    
    if (!(_formatContext->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&_formatContext->pb);
    }
    
    avcodec_free_context(&_codecContext);
    avformat_free_context(_formatContext);
}

@end
