#import <FFMpegBinding/FFMpegOpusTrimmer.h>

#import "libavformat/avformat.h"
#import "libavutil/avutil.h"

@implementation FFMpegOpusTrimmer

+ (bool)trim:(NSString * _Nonnull)inputPath
          to:(NSString * _Nonnull)outputPath
       start:(double)start
         end:(double)end
{
    AVFormatContext *inCtx = NULL;
    int ret;
    if ((ret = avformat_open_input(&inCtx, inputPath.UTF8String, NULL, NULL)) < 0) {
        return false;
    }
    
    if ((ret = avformat_find_stream_info(inCtx, NULL)) < 0) {
        return false;
    }
    
    int audioIdx = -1;
    for (unsigned i = 0; i < inCtx->nb_streams; ++i) {
        if (inCtx->streams[i]->codecpar->codec_id == AV_CODEC_ID_OPUS) {
            audioIdx = (int)i; break;
        }
    }
    if (audioIdx == -1) {
        avformat_close_input(&inCtx);
        return false;
    }
    AVStream *inSt = inCtx->streams[audioIdx];
    AVRational tb = inSt->time_base;
    
    AVFormatContext *outCtx = NULL;
    avformat_alloc_output_context2(&outCtx, NULL, "ogg",
                                   outputPath.UTF8String);
    if (!outCtx) {
        avformat_close_input(&inCtx);
        return false;
    }
    
    AVStream *outSt = avformat_new_stream(outCtx, NULL);
    avcodec_parameters_copy(outSt->codecpar, inSt->codecpar);
    outSt->time_base = tb;
    
    if (!(outCtx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&outCtx->pb, outputPath.UTF8String, AVIO_FLAG_WRITE) < 0) {
            avformat_free_context(outCtx);
            avformat_close_input(&inCtx);
            return false;
        }
    }
    
    ret = avformat_write_header(outCtx, NULL);
    
    int64_t startTs = (int64_t)(start / av_q2d(tb));
    int64_t endTs   = (int64_t)(end   / av_q2d(tb));
    //int64_t span    = MAX(endTs - startTs, 1);
    av_seek_frame(inCtx, audioIdx, startTs, AVSEEK_FLAG_BACKWARD);
    
    AVPacket *pkt = nil;
    pkt = av_packet_alloc();
    //double lastPct = 0.0;
    
    int64_t firstPts = startTs;
    
    while (av_read_frame(inCtx, pkt) >= 0) {
        if (pkt->stream_index != audioIdx) { av_packet_unref(pkt); continue; }
        if (pkt->pts < startTs) { av_packet_unref(pkt); continue; }
        if (pkt->pts > endTs)  { av_packet_unref(pkt); break; }
        
        //double pct = (double)(pkt.pts - startTs) / (double)span;
        //if (pct - lastPct >= 0.01 && progress) {
        //    lastPct = pct;
            //dispatch_async(dispatch_get_main_queue(), ^{ progress(pct); });
        //}
        
        pkt->pts = av_rescale_q(pkt->pts - firstPts, tb, outSt->time_base);
        pkt->dts = av_rescale_q(pkt->dts - firstPts, tb, outSt->time_base);
        pkt->duration = av_rescale_q(pkt->duration, tb, outSt->time_base);
        pkt->pos = -1;
        pkt->stream_index = 0;
        
        if (av_interleaved_write_frame(outCtx, pkt) != 0) {
            av_packet_unref(pkt);
            av_write_trailer(outCtx);
            avio_closep(&outCtx->pb);
            avformat_free_context(outCtx);
            avformat_close_input(&inCtx);
            return false;
        }
        av_packet_unref(pkt);
    }
    
    av_write_trailer(outCtx);
    avio_closep(&outCtx->pb);
    avformat_free_context(outCtx);
    avformat_close_input(&inCtx);
    
    return true;
    //    if (progress) {
    //        dispatch_async(dispatch_get_main_queue(), ^{ progress(1.0); });
    //    }
}

@end
